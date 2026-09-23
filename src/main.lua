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
state.log = import("Logger.lua").new(settings.DEBUG, function(message)
    rom.log.info(message)
end)
local GameStateSnapshot = import("GameState.lua")
local OfferSnapshot = import("OfferSnapshot.lua")
local ScoringEngine = import("ScoringEngine.lua")
local UI = import("UI.lua")
local ProfileResolver = import("ProfileResolver.lua")
UI.setLogger(function(message) state.log(message) end)

local function getUIApi()
    local gameGlobals = rom and rom.game
    return {
        CreateScreenComponent = type(gameGlobals) == "table" and gameGlobals.CreateScreenComponent or nil,
        Attach = type(gameGlobals) == "table" and gameGlobals.Attach or nil,
        CreateTextBox = type(gameGlobals) == "table" and gameGlobals.CreateTextBox or nil,
        Destroy = type(gameGlobals) == "table" and gameGlobals.Destroy or nil,
    }
end
local buildProfileRegistry = import("data/builds/registry.lua")
local configuredProfileKey = settings.BUILD_PROFILE
local preferredProfileKey = configuredProfileKey ~= "auto" and configuredProfileKey or nil
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

local function diagnose(screen, lootData)
    if type(screen) ~= "table" or type(lootData) ~= "table" then return end
    if screen.Source ~= lootData or screen.KeepOpen ~= true then return end
    if not supportedSources[lootData.Name] or lootData.GodLoot ~= true then return end
    if lootData.DebugOnly or lootData.StackOnly or lootData.TransformingTraits then return end
    state.log("CreateBoonLootButtons detected")
    state.log("Source=" .. lootData.Name)
    local gameGlobals = rom and rom.game
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
    local profileSelectionWarning = selectedProfile == nil
        and ("Profile resolution=" .. tostring(selectionReason)) or nil
    snapshot.offers = OfferSnapshot.capture(screen, lootData)
    state.lastSnapshot = snapshot
    local scores = selectedProfile and ScoringEngine.scoreOffers(snapshot, selectedProfile) or {}
    state.lastScores = scores
    local profileValid, profileValidationError = false, "no compatible profile"
    if selectedProfile ~= nil then profileValid, profileValidationError = ScoringEngine.validateProfile(selectedProfile) end
    local profileSupported = profileValid and ScoringEngine.isProfileSupported(snapshot, selectedProfile)
    local rankingContext = ScoringEngine.getRankingContext(scores, profileSupported)
    local rankingReady = ScoringEngine.isRankingReady(scores, rankingContext)
    state.lastRankingReady = rankingReady
    state.lastRankedScores = rankingReady and ScoringEngine.rank(scores) or nil
    local function renderUI(ranks)
        UI.clearFallback(screen, getUIApi())
        state.log("UI calling renderRanks mode=" .. (rankingReady and "real" or "synthetic")
            .. " count=" .. tostring(#ranks))
        local ok, err = pcall(UI.renderRanks, screen, ranks, getUIApi())
        state.log("UI renderRanks pcall success=" .. tostring(ok))
        if not ok then state.log("UI ERROR renderRanks: " .. tostring(err)) end
    end
    local function renderFallback(data)
        local ok, err = pcall(UI.renderFallback, screen, data, getUIApi())
        if not ok then state.log("UI ERROR renderFallback: " .. tostring(err)) end
    end
    UI.clearFallback(screen, getUIApi())
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
    elseif not profileSupported then
        if selectionReason == "ambiguous" then
            renderFallback({ code = "AMBIGUOUS_PROFILE", title = "PROFIL À CHOISIR" })
        else
            renderFallback({ code = "UNSUPPORTED_PROFILE", title = "PROFIL NON PRIS EN CHARGE" })
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
                    reasons = {},
                }
                local partial = partialOffers[#partialOffers]
                if partial.evaluated then
                    local seenLabels = {}
                    local labelOrder = { "Conflit", "Core", "Utilitaire", "Build", "Aspect", "Positionnement", "Origination", "Marteau", "Statut", "Synergie", "Survie", "Rareté" }
                    local labelByCode = { FILL_EMPTY_PRIMARY_CORE = "Core",
                        FILL_EMPTY_UTILITY_CORE = "Utilitaire", ASPECT_COMPATIBLE = "Aspect",
                        ASPECT_DIRECT_SYNERGY = "Aspect", BACKSTAB_SETUP = "Positionnement",
                        BUILD_CORE_PRIORITY = "Build", BUILD_PREFERRED = "Build",
                        RARITY = "Rareté", RARITY_DELTA = "Rareté",
                        BUILD_STATUS_SYNERGY = "Statut", BLOOD_DROP_ENGINE_SYNERGY = "Synergie",
                        SURVIVAL_SUPPORT = "Survie", BUILD_SLOT_POLICY_DELTA = "Build",
                        ORIGINATION_ENABLE = "Origination", EXISTING_HAMMER_SYNERGY = "Marteau" }
                    for _, reason in ipairs(result.reasons or {}) do
                        if reason.delta ~= 0 then
                            local label = labelByCode[reason.code]
                            if reason.code == "BUILD_SLOT_POLICY_DELTA" and reason.delta < 0 then
                                label = "Conflit"
                            end
                            if label then seenLabels[label] = true end
                        end
                    end
                    for _, label in ipairs(labelOrder) do
                        if seenLabels[label] then partial.reasons[#partial.reasons + 1] = label end
                        if #partial.reasons == 2 then break end
                    end
                end
            end
        end
        if replacement then
            renderFallback({ code = "REPLACEMENT_UNRESOLVED", title = "REMPLACEMENT NON ÉVALUÉ",
                subtitle = "Classement non fiable" })
        elseif incomplete > 0 then
            UI.renderPartial(screen, partialOffers, getUIApi())
            renderFallback({ code = "INCOMPLETE_ANALYSIS", title = "ANALYSE INCOMPLÈTE",
                subtitle = "Classement global indisponible",
                incompleteCount = incomplete })
        elseif eligible > 0 then
            renderFallback({ code = "NO_RELIABLE_PREFERENCE", title = "PAS DE PRÉFÉRENCE FIABLE",
                subtitle = "Choix équivalents avec les règles actuelles" })
        end
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
    if not profileValid then state.log("Profile validation failed: " .. tostring(profileValidationError)) end
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

local function install()
    if state.installed then return end
    if type(game.CreateBoonLootButtons) ~= "function"
        or type(table.pack) ~= "function" or type(table.unpack) ~= "function" then
        state.log("Probe unavailable: expected function or Lua 5.2 table API missing")
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
        end)
        if not clearOk then state.log("UI ERROR clearRanks: " .. tostring(clearErr)) end
        local diagnostic = state.diagnose
        if type(diagnostic) == "function" then
            local ok = pcall(diagnostic, ...)
            if not ok then state.log("Diagnostic failed; native result preserved") end
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
                if not ok then state.log("UI ERROR TryUpgradeBoon refresh: " .. tostring(err)) end
            end
            return table.unpack(results, 1, results.n)
        end)
    end
    state.installed = true
    state.log("Hook installed: CreateBoonLootButtons")
end

local function continueLoading()
    modutil = mods["SGG_Modding-ModUtil"]
    modutil.once_loaded.game(function()
        loader.load(install, function()
            if state.installed then
                state.log("Probe ready; hook count=1")
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
