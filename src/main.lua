-- Phase 3B internal scoring probe. ENVY imports are relative to the deployed plugin root.
local mods = rom.mods
mods["LuaENVY-ENVY"].auto()
local loader = mods["SGG_Modding-ReLoad"].auto_single()

local game = rom.game
local modutil = nil

-- ENVY retains the plugin-private environment across imports. ReLoad also
-- remembers this entry point's signature; neither guard belongs to the game.
private.probeState = private.probeState or { installed = false }
local state = private.probeState
state.allModsReady = state.allModsReady or false
local settings = import("config/settings.lua")
local Logger = import("Logger.lua")
state.logState = state.logState or {}
local logger = Logger.new(settings.DEBUG, function(message)
    rom.log.info(message)
end, state.logState)
state.logger = logger
state.log = logger.debug
local GameStateSnapshot = import("GameState.lua")
local LobbyProbe = import("LobbyProbe.lua")
local OfferSnapshot = import("OfferSnapshot.lua")
local CoreAdvisory = import("CoreAdvisory.lua")
local PomAdvisor = import("PomAdvisor.lua")
local FocusState = import("FocusState.lua")
local ScoringEngine = import("ScoringEngine.lua")
local UI = import("UI.lua")
local Localization = import("Localization.lua")
local ProfileResolver = import("ProfileResolver.lua")
UI.setLogger({ debug = logger.debug, error = logger.error })
UI.setLocalization(Localization)
state.focusState = state.focusState or FocusState.new()
state.focusHud = state.focusHud or { id = nil, label = nil }
state.buildHud = state.buildHud or { items = {}, key = nil }

local function getUIApi()
    local gameGlobals = rom and rom.game
    return {
        CreateScreenComponent = type(gameGlobals) == "table" and gameGlobals.CreateScreenComponent or nil,
        Attach = type(gameGlobals) == "table" and gameGlobals.Attach or nil,
        CreateTextBox = type(gameGlobals) == "table" and gameGlobals.CreateTextBox or nil,
        AttachLua = type(gameGlobals) == "table" and gameGlobals.AttachLua or nil,
        Destroy = type(gameGlobals) == "table" and gameGlobals.Destroy or nil,
    }
end

local function refreshFocusReminder(currentRun, forceNew)
    local runChanged = state.focusHud.run ~= currentRun
    if runChanged then
        state.focusMenu = nil
        state.focusHud.id, state.focusHud.label = nil, nil
    end
    state.focusHud.run = currentRun
    FocusState.sync(state.focusState, currentRun)
    local focus = currentRun and {
        focus = state.focusState.focus, route = state.focusState.route,
        locked = state.focusState.locked,
    } or nil
    UI.syncFocusReminder(state.focusHud, focus, getUIApi(), forceNew)
end

local buildProfileRegistry = import("data/builds/registry.lua")
local configuredProfileKey = settings.BUILD_PROFILE
local preferredProfileKey = nil
if type(configuredProfileKey) == "string" and configuredProfileKey ~= "auto" then
    if buildProfileRegistry[configuredProfileKey] then
        preferredProfileKey = configuredProfileKey
    else
        logger.warn("CONFIGURED_PROFILE_UNAVAILABLE",
            "Configured BUILD_PROFILE=" .. configuredProfileKey
            .. " is unavailable; using auto for this session. settings.lua was not changed.")
    end
end
local loadedProfiles = {}
for _, descriptor in pairs(buildProfileRegistry) do
    if type(descriptor) == "table" and type(descriptor.module) == "string"
        and loadedProfiles[descriptor.module] == nil then
        loadedProfiles[descriptor.module] = import(descriptor.module)
    end
end
local function getLoadedProfile(descriptor)
    if type(descriptor) ~= "table" then return nil end
    return loadedProfiles[descriptor.module]
end

local function selectedBuildInputs(gameGlobals)
    local run = type(gameGlobals) == "table" and gameGlobals.CurrentRun or nil
    local snapshot = GameStateSnapshot.capture({
        CurrentRun = run,
        GetEquippedWeapon = gameGlobals.GetEquippedWeapon,
        LootData = gameGlobals.LootData,
        IsGodTrait = gameGlobals.IsGodTrait,
    })
    local hero = type(run) == "table" and run.Hero or nil
    local weapon = snapshot.weapon
    if type(weapon) ~= "string" and type(gameGlobals.GetEquippedWeapon) == "function" then
        local ok, equipped = pcall(gameGlobals.GetEquippedWeapon)
        if ok and type(equipped) == "string" then weapon = equipped end
    end
    if type(weapon) ~= "string" and type(hero) == "table"
        and type(hero.Weapons) == "table" and type(gameGlobals.WeaponSets) == "table"
        and type(gameGlobals.WeaponSets.HeroPrimaryWeapons) == "table" then
        local matches = {}
        for _, candidate in ipairs(gameGlobals.WeaponSets.HeroPrimaryWeapons) do
            if type(candidate) == "string" and hero.Weapons[candidate] then
                matches[#matches + 1] = candidate
            end
        end
        if #matches == 1 then weapon = matches[1] end
    end
    local aspect = snapshot.aspect
    if type(aspect) ~= "string" and type(hero) == "table"
        and type(hero.SlottedTraits) == "table" then
        aspect = hero.SlottedTraits.Aspect
    end
    if type(aspect) ~= "string" and type(weapon) == "string"
        and type(gameGlobals.GameState) == "table"
        and type(gameGlobals.GameState.LastWeaponUpgradeName) == "table" then
        aspect = gameGlobals.GameState.LastWeaponUpgradeName[weapon]
    end
    return weapon, aspect, snapshot.traits, run
end

local function resolveBuildForOverview(gameGlobals, run)
    local weapon, aspect, traits = selectedBuildInputs(gameGlobals)
    local descriptor = ProfileResolver.resolve(buildProfileRegistry, weapon, aspect,
        preferredProfileKey, traits, loadedProfiles)
    local profile = getLoadedProfile(descriptor)
    local name = profile
        and Localization.buildName(Localization.resolveLanguage(gameGlobals), profile.id) or nil
    local ready = type(weapon) == "string" and type(aspect) == "string"
    return name, profile, ready, weapon, aspect
end

local function logBuildResolution(gameGlobals, stage, name, ready, weapon, aspect)
    local hub = type(gameGlobals.CurrentHubRoom) == "table"
        and gameGlobals.CurrentHubRoom.Name or nil
    local run = type(gameGlobals.CurrentRun) == "table" and gameGlobals.CurrentRun or nil
    local room = type(run) == "table" and type(run.CurrentRoom) == "table"
        and run.CurrentRoom.Name or nil
    state.log("BUILD_IDENTITY stage=" .. tostring(stage)
        .. " hub=" .. tostring(hub or "unknown")
        .. " room=" .. tostring(room or "unknown")
        .. " weapon=" .. tostring(weapon or "unknown")
        .. " aspect=" .. tostring(aspect or "unknown")
        .. " ready=" .. tostring(ready == true)
        .. " build=" .. tostring(name or "unrecognized"))
end

local function refreshBuildOverview(forceNew, lifecycle, detectBuild)
    local gameGlobals = rom and rom.game
    if type(gameGlobals) ~= "table" then
        UI.syncBuildOverview(state.buildHud, nil, getUIApi(), forceNew)
        return false
    end
    UI.setLanguage(Localization.resolveLanguage(gameGlobals))
    local runStarting = lifecycle == "run_start"
    local runReset = lifecycle == "run_reset"
    local run = type(gameGlobals.CurrentRun) == "table" and gameGlobals.CurrentRun or nil
    if runReset then state.buildHud.returnedRun = run end
    if runStarting then state.buildHud.returnedRun = nil end
    local hub = type(gameGlobals.CurrentHubRoom) == "table" and gameGlobals.CurrentHubRoom.Name or nil
    local hubPhase = hub == "Hub_Main" or hub == "Hub_PreRun"
    local runRoom = type(run) == "table" and run.CurrentRoom or nil
    local roomName = hubPhase and hub or type(runRoom) == "table" and runRoom.Name or nil
    if type(roomName) == "string" and roomName ~= state.buildHud.roomName then
        -- Recreate once when the actual room changes. Follow-up lifecycle
        -- callbacks in the same room must not destroy and redraw the label.
        forceNew = true
        state.buildHud.roomName = roomName
    end
    local returnedToHub = run ~= nil and state.buildHud.returnedRun == run and hubPhase
    -- CurrentRun can retain the previous room while the Crossroads room is
    -- already active. CurrentHubRoom is authoritative for both hub rooms.
    local beforeRun = hubPhase
    -- CurrentRun.CurrentRoom can still describe the previous run while the
    -- process is loading into the hub. Treat it as an active run only after
    -- StartNewRun established this mod's run-scoped lock.
    local inRun = not returnedToHub and state.buildHud.run ~= nil and state.buildHud.run == run
        and type(runRoom) == "table" and type(runRoom.Name) == "string"
        and runRoom.Name ~= "Hub_Main" and runRoom.Name ~= "Hub_PreRun"

    local name, profile
    if runReset then
        -- Only a transition from a tracked run reaches this branch. A normal
        -- Hub_Main <-> Hub_PreRun switch must retain the lobby selection.
        state.buildHud.run, state.buildHud.runName = nil, nil
        state.buildHud.lobbyName = nil
        state.buildHud.needsDetection = true
        if hubPhase and detectBuild == true then
            local detectionReady
            local weapon, aspect
            name, profile, detectionReady, weapon, aspect = resolveBuildForOverview(gameGlobals, run)
            logBuildResolution(gameGlobals, "hub_return", name, detectionReady, weapon, aspect)
            if detectionReady then
                state.buildHud.lobbyName = name
                state.buildHud.needsDetection = false
            end
        end
    elseif runStarting then
        local ready, weapon, aspect
        name, profile, ready, weapon, aspect = resolveBuildForOverview(gameGlobals, run)
        logBuildResolution(gameGlobals, "run_start", name, ready, weapon, aspect)
        state.buildHud.run, state.buildHud.runName = run, name
        state.buildHud.needsDetection = false
    elseif inRun and state.buildHud.run == run then
        -- Keep the lobby decision stable for the lifetime of this run. Room
        -- transitions must not re-resolve it from transient equipment state.
        name = state.buildHud.runName
    elseif inRun then
        -- Supports a reload while a run is already active: capture once, then
        -- retain the identity for subsequent rooms.
        local ready, weapon, aspect
        name, profile, ready, weapon, aspect = resolveBuildForOverview(gameGlobals, run)
        logBuildResolution(gameGlobals, "active_run_reload", name, ready, weapon, aspect)
        state.buildHud.run, state.buildHud.runName = run, name
        state.buildHud.needsDetection = false
    else
        state.buildHud.run, state.buildHud.runName = nil, nil
        local detectionReady = true
        if beforeRun and detectBuild == true then
            local weapon, aspect
            name, profile, detectionReady, weapon, aspect = resolveBuildForOverview(gameGlobals, run)
            logBuildResolution(gameGlobals, "lobby", name, detectionReady, weapon, aspect)
            if detectionReady then
                state.buildHud.lobbyName = name
                state.buildHud.needsDetection = false
            else
                state.buildHud.needsDetection = true
            end
        else
            name = state.buildHud.lobbyName
        end
        if not beforeRun then name = nil end
    end

    local displayContext = beforeRun or inRun
    if not displayContext or runReset then name = nil end
    UI.syncBuildOverview(state.buildHud, {
        buildName = name,
    }, getUIApi(), forceNew)
    return state.buildHud.needsDetection ~= true
end

local function joinedKeys(values)
    local keys = {}
    for key, present in pairs(type(values) == "table" and values or {}) do
        if present == true then keys[#keys + 1] = key end
    end
    table.sort(keys)
    return #keys > 0 and table.concat(keys, ",") or "none"
end

local function triState(value)
    if value == nil then return "unknown" end
    return tostring(value)
end

local function logLobbyProbe(stage)
    if settings.DEBUG ~= true then return end
    local gameGlobals = rom and rom.game
    logger.debug(LobbyProbe.describe(stage,
        type(gameGlobals) == "table" and gameGlobals or {}))
end

-- IDs from the audited LootData_*.lua files, never from display names.
local supportedSources = {
    AphroditeUpgrade = true,
    ApolloUpgrade = true,
    AresUpgrade = true,
    DemeterUpgrade = true,
    HephaestusUpgrade = true,
    HeraUpgrade = true,
    HestiaUpgrade = true,
    PoseidonUpgrade = true,
    ZeusUpgrade = true,
}

-- These two NPC reward screens use the same native boon-choice callback but
-- are not GodLoot sources. Keep the list closed to verified NPC identities.
local supportedNpcSources = {
    NPC_Athena_01 = true,
    NPC_Hades_Field_01 = true,
}

local supportedPomSources = {
    StackUpgrade = true,
    StackUpgradeBig = true,
    StackUpgradeTriple = true,
}

local function diagnose(screen, lootData)
    if type(screen) ~= "table" or type(lootData) ~= "table" then return end
    if screen.Source ~= lootData or screen.KeepOpen ~= true then return end
    local offerKind = nil
    if supportedSources[lootData.Name] then
        if lootData.GodLoot ~= true then return end
        if lootData.DebugOnly or lootData.StackOnly or lootData.TransformingTraits then return end
        offerKind = "boon"
    elseif supportedNpcSources[lootData.Name] then
        if type(lootData.Traits) ~= "table" then return end
        offerKind = "boon"
    elseif lootData.Name == "WeaponUpgrade" then
        offerKind = "hammer"
    elseif supportedPomSources[lootData.Name] then
        if lootData.StackOnly ~= true then return end
        offerKind = "pom"
    else
        -- Future/unrecognized GodLoot identities are not rankable, but still
        -- reach the fail-closed informational advisory path. Never infer their
        -- God Pool membership from the offered trait.
        if lootData.GodLoot ~= true or lootData.DebugOnly or lootData.StackOnly
            or lootData.TransformingTraits then return end
        offerKind = "boon"
    end
    local offerSourceVerified = supportedSources[lootData.Name] == true
        or supportedNpcSources[lootData.Name] == true or lootData.Name == "WeaponUpgrade"
        or supportedPomSources[lootData.Name] == true
    state.log("CreateBoonLootButtons detected")
    state.log("Source=" .. lootData.Name)
    local gameGlobals = rom and rom.game
    UI.setLanguage(Localization.resolveLanguage(gameGlobals))
    local snapshot = GameStateSnapshot.capture({
        CurrentRun = type(gameGlobals) == "table" and gameGlobals.CurrentRun or nil,
        GetEquippedWeapon = type(gameGlobals) == "table" and gameGlobals.GetEquippedWeapon or nil,
        LootData = type(gameGlobals) == "table" and gameGlobals.LootData or nil,
        IsGodTrait = type(gameGlobals) == "table" and gameGlobals.IsGodTrait or nil,
    })
    local selectedDescriptor, selectionReason = ProfileResolver.resolve(
        buildProfileRegistry, snapshot.weapon, snapshot.aspect, preferredProfileKey,
        snapshot.traits, loadedProfiles)
    local selectedProfile = getLoadedProfile(selectedDescriptor)
    refreshFocusReminder(type(gameGlobals) == "table" and gameGlobals.CurrentRun or nil)
    snapshot.playerFocus = FocusState.forProfile(state.focusState, selectedProfile)
    local profileSelectionWarning = selectedProfile == nil
        and ("Profile resolution=" .. tostring(selectionReason)) or nil
    snapshot.offers = OfferSnapshot.capture(screen, lootData)
    snapshot.offerKind = offerKind
    snapshot.offerSource = lootData.Name
    state.lastSnapshot = snapshot
    local scores = {}
    if selectedProfile ~= nil and offerSourceVerified then
        if PomAdvisor.usesPomScoring(snapshot, selectedProfile) then
            scores = PomAdvisor.scoreOffers(snapshot, selectedProfile)
        else
            scores = ScoringEngine.scoreOffers(snapshot, selectedProfile)
        end
    end
    state.lastScores = scores
    local profileValid, profileValidationError = false, "no compatible profile"
    if selectedProfile ~= nil then profileValid, profileValidationError = ScoringEngine.validateProfile(selectedProfile) end
    local profileSupported = offerSourceVerified and profileValid
        and ScoringEngine.isProfileSupported(snapshot, selectedProfile)
    local rankingDecision = ScoringEngine.getRankingDecision(scores, profileSupported)
    local rankingReady = rankingDecision.mode == "full"
    state.lastRankingReady = rankingReady
    state.lastRankedScores = rankingReady and ScoringEngine.rank(rankingDecision.rankEligible) or nil
    local partialRankedScores = rankingDecision.mode == "partial"
        and ScoringEngine.rank(rankingDecision.rankEligible) or nil
    local showCoreAdvisory = CoreAdvisory.shouldShow(
        ScoringEngine.effectiveProfile(snapshot, selectedProfile), snapshot, profileSupported)
    state.lastCoreAdvisory = showCoreAdvisory
    local function renderUI(ranks)
        UI.clearFallback(screen, getUIApi())
        state.log("UI calling renderRanks mode=" .. (rankingReady and "real" or "synthetic")
            .. " count=" .. tostring(#ranks))
        local ok, err = pcall(UI.renderRanks, screen, ranks, getUIApi())
        state.log("UI renderRanks pcall success=" .. tostring(ok))
        if not ok then logger.error("UI_RENDER_RANKS_FAILED", "UI rank rendering failed") end
    end
    local function renderFallback(data)
        local ok, err = pcall(UI.renderFallback, screen, data, getUIApi())
        if not ok then logger.error("UI_RENDER_FALLBACK_FAILED", "UI fallback rendering failed") end
    end
    UI.clearFallback(screen, getUIApi())
    UI.clearFocus(screen, getUIApi())
    if rankingReady then
        renderUI(state.lastRankedScores)
    elseif settings.UI_TEST_MODE
        and type(screen.Components) == "table"
        and screen.Components.PurchaseButton1 ~= nil
        and screen.Components.PurchaseButton2 ~= nil
        and screen.Components.PurchaseButton3 ~= nil then
        state.log("UI TEST MODE rendering synthetic ranks 1/1/3")
        renderUI({
            { originalIndex = 1, rank = 1, reasons = {
                { code = "FILL_EMPTY_PRIMARY_CORE", delta = 8 },
                { code = "ASPECT_COMPATIBLE", delta = 4 },
            } },
            { originalIndex = 2, rank = 1, reasons = {
                { code = "ORIGINATION_ENABLE", delta = 8 },
            } },
            { originalIndex = 3, rank = 3, reasons = {
                { code = "FILL_EMPTY_UTILITY_CORE", delta = 4 },
            } },
        })
    elseif not offerSourceVerified then
        UI.clearRanks(screen, getUIApi())
        renderFallback({ code = "NO_RELIABLE_PREFERENCE" })
    elseif not profileSupported then
        if selectionReason == "ambiguous" then
            renderFallback({ code = "AMBIGUOUS_PROFILE" })
        else
            renderFallback({ code = "UNSUPPORTED_PROFILE" })
        end
    else
        local replacement = false
        local incomplete = 0
        local eligible = 0
        local partialOffers = {}
        for _, result in ipairs(scores) do
            if result.eligible then
                eligible = eligible + 1
                for _, reason in ipairs(result.reasons or {}) do
                    if reason.code == "REPLACEMENT_UNRESOLVED" then replacement = true end
                end
                if not result.covered or not result.scoreComplete then incomplete = incomplete + 1 end
                partialOffers[#partialOffers + 1] = {
                    originalIndex = result.originalIndex,
                    evaluated = result.covered == true and result.scoreComplete == true,
                    reasons = result.reasons,
                }
            end
        end
        if rankingDecision.mode == "partial" then
        local partialRanks = partialRankedScores or {}
            local ranksByIndex = {}
            for _, ranked in ipairs(partialRanks) do ranksByIndex[ranked.originalIndex] = ranked.rank end
            for _, offer in ipairs(partialOffers) do
                offer.rank = ranksByIndex[offer.originalIndex]
                if offer.rank then offer.rankTotal = #partialRanks end
            end
            UI.renderPartial(screen, partialOffers, getUIApi())
            renderFallback({ code = "PARTIAL_RANKING" })
        elseif replacement then
            UI.renderPartial(screen, partialOffers, getUIApi())
            renderFallback({ code = "REPLACEMENT_UNRESOLVED" })
        elseif incomplete > 0 then
            UI.renderPartial(screen, partialOffers, getUIApi())
            renderFallback({ code = "INCOMPLETE_ANALYSIS", incompleteCount = incomplete })
        elseif eligible > 0 then
            renderFallback({ code = "NO_RELIABLE_PREFERENCE" })
            if offerKind == "pom" then
                local ok, err = pcall(UI.renderPomTieStatuses,
                    screen, scores, selectedProfile, getUIApi())
                if not ok then
                    logger.error("UI_POM_STATUS_FAILED", "Pom status rendering failed")
                end
            end
        end
    end

    -- This is a build/inventory fact about the whole boon offer, independent
    -- of which choices are listed, evaluated, eligible, or ranked.
    local advisoryOk, advisoryErr = pcall(UI.renderCoreAdvisory, screen, showCoreAdvisory, getUIApi())
    if not advisoryOk then
        logger.error("UI_CORE_ADVISORY_FAILED", "Core advisory rendering failed: " .. tostring(advisoryErr))
    end

    if snapshot.playerFocus ~= nil then
        if state.focusMenuScreen ~= screen then
            state.focusMenuScreen, state.focusMenu = screen, nil
        end
        UI.renderFocus(screen, snapshot.playerFocus, getUIApi(), state.focusMenu)
    end

    state.log("Weapon=" .. tostring(snapshot.weapon))
    state.log("Aspect=" .. tostring(snapshot.aspect))
    state.log("TraitCount=" .. #snapshot.traits)
    for index, trait in ipairs(snapshot.traits) do
        state.log("Trait[" .. index .. "] Name=" .. tostring(trait.Name)
            .. " Rarity=" .. tostring(trait.Rarity) .. " StackNum=" .. tostring(trait.StackNum)
            .. " Slot=" .. tostring(trait.Slot))
    end
    state.log("HammerCount=" .. #snapshot.hammers)
    for index, hammer in ipairs(snapshot.hammers) do
        state.log("Hammer[" .. index .. "]=" .. tostring(hammer.Name))
    end
    state.log("GodTraitCount=" .. #snapshot.godTraits)
    for index, trait in ipairs(snapshot.godTraits) do
        state.log("GodTrait[" .. index .. "]=" .. tostring(trait.Name))
    end
    state.log("OfferCount=" .. #snapshot.offers)
    for index, offer in ipairs(snapshot.offers) do
        local message = "Offer[" .. index .. "] originalIndex=" .. offer.originalIndex
            .. " ItemName=" .. tostring(offer.ItemName) .. " Type=" .. tostring(offer.Type)
            .. " Rarity=" .. tostring(offer.Rarity) .. " Blocked=" .. tostring(offer.Blocked)
        if offer.TraitToReplace ~= nil then message = message .. " TraitToReplace=" .. tostring(offer.TraitToReplace) end
        if offer.OldRarity ~= nil then message = message .. " OldRarity=" .. tostring(offer.OldRarity) end
        if offer.SecondaryItemName ~= nil then message = message .. " SecondaryItemName=" .. tostring(offer.SecondaryItemName) end
        if offer.StackNum ~= nil then message = message .. " StackNum=" .. tostring(offer.StackNum) end
        state.log(message)
    end

    if profileSelectionWarning ~= nil then state.log(profileSelectionWarning) end
    state.log("BuildId=" .. tostring(selectedProfile and selectedProfile.id or nil)
        .. " ProfileMode=" .. tostring(selectedProfile and selectedProfile.profileMode or nil)
        .. " SchemaVersion=" .. tostring(selectedProfile and selectedProfile.schemaVersion or nil)
        .. " Supported=" .. tostring(profileSupported))
    if selectedProfile == nil then
        state.log("Profile validation failed: no compatible profile")
    elseif not profileValid then
        logger.error("PROFILE_VALIDATION_FAILED", "Profile validation failed")
    end
    if profileSupported then
        local arcana = snapshot.activeArcana.EffectVulnerabilityMetaUpgrade
        state.log("Arcana Origination Active=" .. tostring(type(arcana) == "table")
            .. " Rarity=" .. tostring(type(arcana) == "table" and arcana.Rarity or nil))
        local ownedContext = ScoringEngine.getStatusContext(snapshot, selectedProfile)
        state.log("OwnedStatusFamilies=" .. joinedKeys(ownedContext.ownedStatusFamilies))
        for _, offer in ipairs(snapshot.offers) do
            local origination = ScoringEngine.getOriginationContext(
                snapshot, selectedProfile, offer.ItemName)
            local core = ScoringEngine.getCoreSlotContext(snapshot, selectedProfile, offer)
            local interaction = ScoringEngine.getAspectInteraction(
                selectedProfile, offer.ItemName)
            state.log("Context originalIndex=" .. tostring(offer.originalIndex)
                .. " StatusFamily=" .. tostring(origination.status.offeredStatusFamily)
                .. " StatusKnowledge=" .. tostring(origination.status.statusKnowledge)
                .. " OriginationEnable=" .. triState(origination.offerEnablesOrigination)
                .. " CoreRole=" .. tostring(core.coreRole)
                .. " Alignment=" .. tostring(core.alignment)
                .. " SlotPolicy=" .. tostring(core.slotPolicy)
                .. " SlotConflict=" .. tostring(core.slotConflict)
                .. " CurrentSlotTrait=" .. tostring(core.currentSlotTrait)
                .. " SlotStateBefore=" .. tostring(core.slotStateBefore)
                .. " SlotStateAfter=" .. tostring(core.slotStateAfter)
                .. " ConflictIntroduced=" .. tostring(core.conflictIntroduced)
                .. " ConflictResolved=" .. tostring(core.conflictResolved)
                .. " CoreSacrificed=" .. tostring(core.coreSacrificed)
                .. " FillsEmpty=" .. tostring(core.fillsEmptyCoreSlot)
                .. " Replaces=" .. tostring(core.replacesCoreSlot)
                .. " AspectInteraction=" .. tostring(interaction))
        end
        state.log("RankingReady=" .. tostring(rankingReady))
        state.log("RankingMode=" .. rankingDecision.mode)
        for _, result in ipairs(scores) do
            state.log("Score originalIndex=" .. tostring(result.originalIndex)
                .. " ItemName=" .. tostring(result.itemName) .. " Score=" .. result.score
                    .. " Eligible=" .. tostring(result.eligible)
                .. " Covered=" .. tostring(result.covered)
                .. " Complete=" .. tostring(result.scoreComplete))
            for _, reason in ipairs(result.reasons) do
                local message = "Reason originalIndex=" .. tostring(result.originalIndex)
                    .. " Code=" .. reason.code .. " Delta=" .. reason.delta
                if reason.with ~= nil then message = message .. " With=" .. reason.with end
                state.log(message)
            end
            if type(result.condition) == "table" then
                state.log("Condition kind=" .. tostring(result.condition.kind)
                    .. " Threshold=" .. tostring(result.condition.threshold)
                    .. " CurrentlyActive=" .. tostring(result.condition.currentlyActive))
            end
        end
        if rankingReady then
            for _, result in ipairs(state.lastRankedScores) do
                state.log("Rank=" .. result.rank .. " originalIndex=" .. tostring(result.originalIndex)
                    .. " ItemName=" .. tostring(result.itemName) .. " Score=" .. result.score
                    .. " Tied=" .. tostring(result.tied))
            end
        end
    end
end

-- Refresh the implementation on every reload without replacing the wrapper.
state.diagnose = diagnose

game.BoonAdvisorSelectFocus = function(screen, button)
    if type(screen) ~= "table" or type(button) ~= "table"
        or type(screen.BoonAdvisorFocus) ~= "table"
        or screen.KeepOpen ~= true or state.focusState.locked then return end
    local choice = button.BoonAdvisorChoice
    if choice == "open" then
        state.focusMenu = state.focusMenu == "focus" and nil or "focus"
    elseif choice == "focus:none" then
        if not FocusState.selectFocus(state.focusState, "none") then return end
        FocusState.lock(state.focusState)
        state.focusMenu = nil
    elseif choice == "focus:attack" then
        if not FocusState.selectFocus(state.focusState, "attack") then return end
        FocusState.lock(state.focusState)
        state.focusMenu = nil
    elseif choice == "focus:special" then
        if not FocusState.selectFocus(state.focusState, "special") then return end
        state.focusMenu = "route"
    elseif choice == "route:none" or choice == "route:ares" or choice == "route:zeus" then
        if not FocusState.selectRoute(state.focusState, choice:sub(7)) then return end
        FocusState.lock(state.focusState)
        state.focusMenu = nil
    else
        return
    end
    local gameGlobals = rom and rom.game
    refreshFocusReminder(type(gameGlobals) == "table" and gameGlobals.CurrentRun or nil)
    local ok = pcall(state.diagnose, screen, screen.Source)
    if not ok then logger.error("FOCUS_REFRESH_FAILED", "Focus refresh failed") end
end

local function install()
    if state.installed then return end
    if type(game.CreateBoonLootButtons) ~= "function"
        or type(table.pack) ~= "function" or type(table.unpack) ~= "function" then
        logger.error("PROBE_UNAVAILABLE", "Required native API unavailable")
        return
    end

    modutil.mod.Path.Wrap("CreateBoonLootButtons", function(base, ...)
        -- Native errors propagate. Explicit n preserves trailing and interior nils.
        -- Only our post-call diagnostic is protected, never the native call.
        local results = table.pack(base(...))
        local targetScreen = select(1, ...)
        local clearOk, clearErr = pcall(function()
            UI.clearRanks(targetScreen, getUIApi())
            UI.clearFallback(targetScreen, getUIApi())
            UI.clearFocus(targetScreen, getUIApi())
        end)
        if not clearOk then logger.error("UI_CLEAR_RANKS_FAILED", "UI cleanup failed") end
        local diagnostic = state.diagnose
        if type(diagnostic) == "function" then
            local ok = pcall(diagnostic, ...)
            if not ok then logger.error("DIAGNOSTIC_FAILED", "Diagnostic failed; native result preserved") end
        end
        return table.unpack(results, 1, results.n)
    end)
    if type(game.TryUpgradeBoon) == "function" then
        modutil.mod.Path.Wrap("TryUpgradeBoon", function(base, lootData, screen, button, ...)
            local results = table.pack(base(lootData, screen, button, ...))
            if results[1] ~= nil then
                local ok, err = pcall(function()
                    state.log("TryUpgradeBoon detected")
                    UI.clearRanks(screen, getUIApi())
                    diagnose(screen, lootData)
                    state.log("UI refresh after TryUpgradeBoon")
                end)
                if not ok then logger.error("TRY_UPGRADE_REFRESH_FAILED", "TryUpgradeBoon refresh failed") end
            end
            return table.unpack(results, 1, results.n)
        end)
    end
    state.hookCount = 1
    if type(game.StartRoom) == "function" then
        modutil.mod.Path.Wrap("StartRoom", function(base, currentRun, currentRoom, ...)
            -- Map loads discard screen obstacles. Recreate the locked reminder
            -- at the beginning of each room, before the native encounter starts.
            local ok = pcall(refreshFocusReminder, currentRun, true)
            if not ok then logger.error("FOCUS_ROOM_REFRESH_FAILED", "Room focus reminder refresh failed") end
            local results = table.pack(base(currentRun, currentRoom, ...))
            -- The map load discards Combat_UI components. Defer recreation
            -- until the native HUD is ready, then consume this flag once.
            state.buildHud.needsRefresh = true
            local probeOk = pcall(logLobbyProbe, "StartRoom")
            if not probeOk then logger.error("LOBBY_PROBE_FAILED", "Read-only room probe failed") end
            return table.unpack(results, 1, results.n)
        end)
        state.hookCount = state.hookCount + 1
        state.log("Hook installed: StartRoom focus reminder")
    end

    -- StartRoom's post-call point can precede the final combat-HUD setup.
    -- Recreate the passive reminder after the native HUD is shown so it
    -- survives room loads that clear Combat_UI screen components.
    if type(game.ShowCombatUI) == "function" then
        modutil.mod.Path.Wrap("ShowCombatUI", function(base, ...)
            local results = table.pack(base(...))
            local forceOverviewRefresh = state.buildHud.needsRefresh == true
            local detectBuild = state.buildHud.needsDetection == true
            local overviewOk, detectionReady = pcall(refreshBuildOverview,
                forceOverviewRefresh, nil, detectBuild)
            if overviewOk then
                state.buildHud.needsRefresh = false
                if detectBuild and detectionReady then state.buildHud.needsDetection = false end
            end
            if not overviewOk then
                logger.error("BUILD_OVERVIEW_REFRESH_FAILED", "Combat HUD build reminder refresh failed")
            end
            return table.unpack(results, 1, results.n)
        end)
        state.hookCount = state.hookCount + 1
        state.log("Hook installed: build reminder after ShowCombatUI")
    end

    local probeHooks = {
        { "StartNewRun", "StartNewRun" },
        { "UseWeaponKit", "UseWeaponKit" },
        { "SelectWeaponUpgrade", "SelectWeaponUpgrade" },
        { "DeathAreaRoomTransition", "HubRoomTransition" },
        { "HubPostBountyLoad", "HubPostBountyLoad" },
        { "HubPostDreamLoad", "HubPostDreamLoad" },
    }
    for _, hook in ipairs(probeHooks) do
        local functionName, stage = hook[1], hook[2]
        if type(game[functionName]) == "function" then
            local wrappedName, probeStage = functionName, stage
            modutil.mod.Path.Wrap(wrappedName, function(base, ...)
                local results = table.pack(base(...))
                local leavingTrackedRun = wrappedName == "DeathAreaRoomTransition"
                    and state.buildHud.run ~= nil
                local lifecycle = wrappedName == "StartNewRun" and "run_start"
                    or leavingTrackedRun and "run_reset" or nil
                -- Hub load callbacks can fire more than once across the two
                -- Crossroads rooms. Keep the existing HUD component when the
                -- resolved build is unchanged to avoid a visible blink.
                local forceOverviewRefresh = wrappedName == "StartNewRun"
                    or wrappedName == "DeathAreaRoomTransition"
                    or state.buildHud.needsRefresh == true
                local detectBuild = wrappedName == "StartNewRun"
                    or wrappedName == "UseWeaponKit"
                    or wrappedName == "SelectWeaponUpgrade"
                    or state.buildHud.needsDetection == true
                if leavingTrackedRun then
                    local gameGlobals = rom and rom.game
                    local hub = type(gameGlobals) == "table"
                        and type(gameGlobals.CurrentHubRoom) == "table"
                        and gameGlobals.CurrentHubRoom.Name or nil
                    if hub == "Hub_Main" or hub == "Hub_PreRun" then detectBuild = true end
                end
                local overviewOk, detectionReady = pcall(refreshBuildOverview,
                    forceOverviewRefresh, lifecycle, detectBuild)
                if overviewOk then
                    state.buildHud.needsRefresh = false
                    if detectBuild and detectionReady then state.buildHud.needsDetection = false end
                end
                if not overviewOk then logger.error("BUILD_OVERVIEW_REFRESH_FAILED", "Build overview refresh failed") end
                local probeOk = pcall(logLobbyProbe, probeStage)
                if not probeOk then logger.error("LOBBY_PROBE_FAILED", "Read-only event probe failed") end
                return table.unpack(results, 1, results.n)
            end)
            state.hookCount = state.hookCount + 1
            state.log("Hook installed: read-only lobby probe " .. wrappedName)
        end
    end
    state.buildHud.needsDetection = true
    local overviewOk, detectionReady = pcall(refreshBuildOverview, true, nil, true)
    if overviewOk and detectionReady then state.buildHud.needsDetection = false end
    if not overviewOk then logger.error("BUILD_OVERVIEW_REFRESH_FAILED", "Initial build overview refresh failed") end
    -- Plugin initialization can precede the game's final HUD construction.
    -- Recreate once on the first reliable HUD or hub lifecycle callback.
    state.buildHud.needsRefresh = true
    local probeOk = pcall(logLobbyProbe, "plugin_loaded")
    if not probeOk then logger.error("LOBBY_PROBE_FAILED", "Initial read-only probe failed") end
    state.installed = true
    state.log("Hook installed: CreateBoonLootButtons")
end

local function continueLoading()
    modutil = mods["SGG_Modding-ModUtil"]
    modutil.once_loaded.game(function()
        loader.load(install, function()
            if state.installed then
                state.log("Probe ready; hook count=" .. tostring(state.hookCount or 1))
            end
        end)
    end)
end

if state.allModsReady then
    continueLoading()
else
    mods.on_all_mods_loaded(function()
        state.allModsReady = true
        continueLoading()
    end)
end
