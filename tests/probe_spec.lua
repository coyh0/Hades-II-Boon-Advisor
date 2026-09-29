-- Run from the repository root. Framework doubles do not validate integration.
local function check(value, message) assert(value, message) end
local function pack(...) return table.pack(...) end
local function fixture(native, sink, debugEnabled, runtime, uiTestMode, buildProfile, registryOverride)
    local logs, installs, modCallbacks, gameCallbacks = {}, 0, {}, {}
    local reloadLoaded, allModsLoaded, gameLoaded = false, false, false
    local allModsRegistrations = 0
    local importing, inCallback, autoSingleCalls, infoLookups = false, false, 0, 0
    local uiCreated, uiText, uiDestroyed, uiAttached = {}, {}, {}, {}
    local readyCalls, reloadCalls = 0, 0
    local game = { CreateBoonLootButtons = native, GetLanguage = function() return "fr" end }
    local env = setmetatable({ private = {} }, { __index = _G })
    local mods = {}
    for key, value in pairs(runtime or {}) do
        game[key] = value
        check(rawget(env, key) == nil, "runtime game global leaked into plugin environment")
    end
    local info = sink or function(s)
        logs[#logs + 1] = s
    end
    local log = setmetatable({}, { __index = function(_, key)
        if key == "info" then
            infoLookups = infoLookups + 1
            return info
        end
    end })
    env.rom = { game = game, mods = mods, log = log }
    mods["LuaENVY-ENVY"] = { auto = function() end }
    mods.on_all_mods_loaded = function(fn)
        allModsRegistrations = allModsRegistrations + 1
        if not allModsLoaded then modCallbacks[#modCallbacks + 1] = fn end
    end
    mods["SGG_Modding-ReLoad"] = { auto_single = function()
        check(importing and not inCallback, "auto_single must run in direct entry context")
        autoSingleCalls = autoSingleCalls + 1
        return { load = function(ready, reload)
            if not reloadLoaded then
                reloadLoaded = true
                readyCalls = readyCalls + 1
                ready()
            end
            reloadCalls = reloadCalls + 1
            reload()
        end }
    end }
    mods["SGG_Modding-ModUtil"] = {
        once_loaded = { game = function(fn)
            if gameLoaded then fn() else gameCallbacks[#gameCallbacks + 1] = fn end
        end },
        mod = { Path = { Wrap = function(name, fn)
            installs = installs + 1
            local base = game[name]
            game[name] = function(...) return fn(base, ...) end
        end } },
    }
    game.CreateScreenComponent = function(data)
        local id = "BoonAdvisorTest" .. tostring(#uiCreated + 1)
        local component = { Id = id, X = data.X, Y = data.Y, Data = data }
        uiCreated[#uiCreated + 1] = component
        return component
    end
    game.CreateTextBox = function(data) uiText[#uiText + 1] = data end
    game.Attach = function(data) uiAttached[#uiAttached + 1] = data end
    game.Destroy = function(data) uiDestroyed[#uiDestroyed + 1] = data end
    env.import = function(path)
        if path == "data/builds/registry.lua" and registryOverride then return registryOverride end
        if path == "config/settings.lua" then
            return {
                DEBUG = debugEnabled ~= false,
                UI_TEST_MODE = uiTestMode == true,
    BUILD_PROFILE = buildProfile or "auto",
            }
        end
        if path == "Logger.lua" or path == "Localization.lua" or path == "GameState.lua" or path == "LobbyProbe.lua"
            or path == "OfferSnapshot.lua"
            or path == "CoreAdvisory.lua" or path == "GodPoolContext.lua"
            or path == "PomAdvisor.lua" or path == "FocusState.lua"
            or path == "ScoringEngine.lua" or path == "UI.lua" or path == "ProfileResolver.lua" then
            path = "src/" .. path
        end
        return assert(loadfile(path, "t", env))()
    end
    local function loadMain()
        importing = true
        local ok, err = pcall(assert(loadfile("src/main.lua", "t", env)))
        importing = false
        if not ok then error(err, 0) end
    end
    local function fireAllModsLoaded()
        allModsLoaded = true
        local queued = modCallbacks
        modCallbacks = {}
        for _, fn in ipairs(queued) do
            inCallback = true
            fn()
            inCallback = false
        end
    end
    local function fireGameLoaded()
        gameLoaded = true
        local queued = gameCallbacks
        gameCallbacks = {}
        for _, fn in ipairs(queued) do
            inCallback = true
            fn()
            inCallback = false
        end
    end
    local function start()
        loadMain()
        fireAllModsLoaded()
        fireGameLoaded()
    end
    return game, logs, start, function() return installs end, env.private,
            loadMain, fireAllModsLoaded, fireGameLoaded, function()
            return autoSingleCalls, infoLookups, allModsRegistrations, readyCalls, reloadCalls
        end, uiCreated, uiText, uiDestroyed, uiAttached
end

local loot = { Name = "AphroditeUpgrade", GodLoot = true }
local screen = { Source = loot, KeepOpen = true }
local calls = 0
local game, logs, reload, installs = fixture(function(...)
    calls = calls + 1
    local args = pack(...)
    check(args.n == 5 and args[1] == screen and args[2] == loot
        and args[3] == nil and args[4] == false and args[5] == nil, "arguments changed")
    return "first", nil, false, nil
end)
reload()
local before = #logs
local result = pack(game.CreateBoonLootButtons(screen, loot, nil, false, nil))
check(calls == 1 and result.n == 4 and result[1] == "first"
    and result[2] == nil and result[3] == false and result[4] == nil, "return values changed")
check(#logs == before + 11 and logs[before + 2] == "[BoonAdvisor] Source=AphroditeUpgrade", "missing diagnostic")
reload(); reload()
check(installs() == 1, "double wrapper")
before = #logs
game.CreateBoonLootButtons(screen, loot, nil, false, nil)
check(calls == 2 and #logs == before + 11, "reroll/reload duplicated diagnostics")
local keys = 0; for _ in pairs(loot) do keys = keys + 1 end
check(keys == 2 and loot.Name == "AphroditeUpgrade" and loot.GodLoot == true, "mutation")

for _, bad in ipairs({
    { Name = "HermesUpgrade", GodLoot = false },
    { Name = "TrialUpgrade", GodLoot = false },
    { Name = "UnknownTestSource", GodLoot = true },
    { Name = "ZeusUpgrade", GodLoot = true, DebugOnly = true },
}) do
    local g, l, start, _, private = fixture(function() end)
    start(); local n = #l
    check(pack(g.CreateBoonLootButtons({ Source = bad, KeepOpen = true }, bad)).n == 0, "zero returns lost")
    if bad.Name == "UnknownTestSource" and bad.GodLoot == true then
        check(#l > n and private.probeState.lastSnapshot.offerSource == bad.Name
            and private.probeState.lastCoreAdvisory == true and private.probeState.lastRankingReady == false,
            "unknown GodLoot source did not follow the conservative unranked advisory path")
    else
        check(#l == n, "unsupported non-boon menu logged")
    end
end

local nativeError = {}
local g, l, start = fixture(function() error(nativeError) end)
start(); before = #l
local ok, err = pcall(g.CreateBoonLootButtons, screen, loot)
check(not ok and err == nativeError and #l == before, "native error swallowed or diagnostic ran early")

g, l, start = fixture(function() return nil end, function() error("broken logger") end)
start()
check(pack(g.CreateBoonLootButtons(screen, loot)).n == 1, "logger broke native result")
local hostile = setmetatable({}, { __index = function() error("diagnostic failure") end })
check(pack(g.CreateBoonLootButtons(hostile, loot)).n == 1, "diagnostic error escaped")

g, l, start = fixture(function() coroutine.yield("native wait"); return 7, nil end)
start(); before = #l
local co = coroutine.create(function() return g.CreateBoonLootButtons(screen, loot) end)
local first = pack(coroutine.resume(co))
check(first[1] and first[2] == "native wait" and #l == before, "diagnostic ran before native completion")
local last = pack(coroutine.resume(co))
check(last.n == 3 and last[1] and last[2] == 7 and last[3] == nil and #l == before + 11, "yield/return broken")

local Logger = assert(loadfile("src/Logger.lua"))()
local loggerCalls = 0
testLogger = Logger.new(true, function(message)
    loggerCalls = loggerCalls + 1
    check(message == "[BoonAdvisor] enabled", "logger prefix changed")
end)
testLogger.debug("enabled")
Logger.new(false, function() loggerCalls = loggerCalls + 1 end).debug("disabled")
Logger.new(true, nil).debug("missing")
check(loggerCalls == 1, "logger DEBUG true/false behavior changed")
levelLogs, levelState = {}, {}
leveled = Logger.new(false, function(message) levelLogs[#levelLogs + 1] = message end, levelState)
leveled.error("TEST_ERROR", "failure")
leveled.error("TEST_ERROR", "changed failure")
leveled.warn("TEST_WARN", "warning")
leveled.warn("TEST_WARN", "warning again")
leveled.info("TEST_INFO", "hidden")
check(#levelLogs == 2 and levelLogs[1]:find("ERROR TEST_ERROR", 1, true)
    and levelLogs[2]:find("WARN TEST_WARN", 1, true)
    and levelState.suppressed["ERROR:TEST_ERROR"] == 1
    and levelState.suppressed["WARN:TEST_WARN"] == 1,
    "leveled logger visibility or deduplication failed")
rebuilt = Logger.new(false, function(message) levelLogs[#levelLogs + 1] = message end, levelState)
rebuilt.error("TEST_ERROR", "third failure")
check(#levelLogs == 2, "persistent logger state did not deduplicate after reconstruction")
broken = Logger.new(false, function() error("sink failed") end)
check(pcall(broken.error, "BROKEN_SINK", "safe") and pcall(broken.warn, "BROKEN_WARN", 42),
    "broken sink or non-string message escaped")
failureState = {}
failingLogger = Logger.new(false, function() error("first sink failure") end, failureState)
check(pcall(failingLogger.error, "RETRY_ERROR", "first")
    and failureState.seen["ERROR:RETRY_ERROR"] == nil
    and failureState.suppressed["ERROR:RETRY_ERROR"] == nil,
    "failed sink incorrectly consumed the error key")
levelLogs = {}
recoverLogger = Logger.new(false, function(message) levelLogs[#levelLogs + 1] = message end, failureState)
recoverLogger.error("RETRY_ERROR", "second")
recoverLogger.error("RETRY_ERROR", "third")
check(#levelLogs == 1 and failureState.seen["ERROR:RETRY_ERROR"] == true
    and failureState.suppressed["ERROR:RETRY_ERROR"] == 1,
    "failed sink retry or post-success suppression was incorrect")
print("PASS: arguments, nil/multiple/zero returns, native errors, diagnostics, filtering, reload guard, yield, logger")

local hotCalls = 0
local hg, hl, hotReload, hookCount, privateState = fixture(function()
    hotCalls = hotCalls + 1
    return "native", nil
end)
hotReload()
local permanentWrapper = hg.CreateBoonLootButtons
local state = privateState.probeState
local initialDiagnostic = state.diagnose
before = #hl
permanentWrapper(screen, loot)
check(#hl == before + 11, "initial diagnostic not called")
local replacementCalls = 0
state.diagnose = function(s, source)
    check(s == screen and source == loot, "replacement arguments changed")
    replacementCalls = replacementCalls + 1
end
result = pack(hg.CreateBoonLootButtons(screen, loot))
check(replacementCalls == 1 and #hl == before + 11, "replacement diagnostic not used")
check(result.n == 2 and result[1] == "native" and result[2] == nil, "replacement changed native returns")
check(hg.CreateBoonLootButtons == permanentWrapper and hookCount() == 1, "wrapper replaced or installed twice")
hotReload()
check(state == privateState.probeState and state.diagnose ~= initialDiagnostic,
    "reload did not refresh diagnostic in persistent state")
before = #hl
hg.CreateBoonLootButtons(screen, loot)
check(#hl == before + 11 and replacementCalls == 1, "reloaded diagnostic not used")
for _, missing in ipairs({ false, "not callable" }) do
    state.diagnose = missing
    check(pack(permanentWrapper(screen, loot)).n == 2, "non-function diagnostic changed returns")
end
state.diagnose = nil
check(pack(permanentWrapper(screen, loot)).n == 2, "absent diagnostic changed returns")
state.diagnose = function() error("replacement failed") end
result = pack(permanentWrapper(screen, loot))
check(result.n == 2 and result[1] == "native" and result[2] == nil, "replacement error escaped")
check(hotCalls == 7 and hookCount() == 1 and hg.CreateBoonLootButtons == permanentWrapper,
    "native call count or permanent wrapper changed")
print("PASS: hot reload replaces diagnostic; same wrapper; installations=1; native calls=7; absent/failing diagnostic safe")

local bg, bl, barrierStart, barrierInstalls, _, loadEntry, fireMods, fireGame, metrics = fixture(function() end)
loadEntry()
local autoCalls = metrics()
check(autoCalls == 1, "auto_single was not called exactly once in direct entry context")
check(barrierInstalls() == 0 and #bl == 0, "work occurred before all-mods barrier")
fireMods()
autoCalls = metrics()
check(autoCalls == 1, "on_all_mods_loaded called auto_single again")
check(barrierInstalls() == 0 and #bl == 0, "work occurred before game-ready barrier")
fireGame()
check(barrierInstalls() == 1, "hook not installed after both barriers")
do
local lobbyProbeLog = "[BoonAdvisor] LOBBY_PROBE stage=plugin_loaded hub=unknown room=unknown"
    .. " run=false hero=false primaryCount=0 weapon=none activeAspect=unknown storedAspect=unknown"
local hookInstalledLog = "[BoonAdvisor] Hook installed: CreateBoonLootButtons"
local probeReadyLog = "[BoonAdvisor] Probe ready; hook count=1"
local function countLog(message, first)
    local count = 0
    for index = first or 1, #bl do
        if bl[index] == message then count = count + 1 end
    end
    return count
end
check(countLog(lobbyProbeLog) == 1, "initial LOBBY_PROBE content changed")
check(countLog(hookInstalledLog) == 1, "initial hook-installed log changed")
check(countLog(probeReadyLog) == 1, "initial probe-ready log changed")
local barrierWrapper = bg.CreateBoonLootButtons
local logCount = #bl
loadEntry()
local _, _, registrations, readyCalls, reloadCalls = metrics()
autoCalls = select(1, metrics())
check(autoCalls == 2, "hot reload did not obtain one fresh loader in direct entry context")
check(registrations == 1, "hot reload registered another all-mods callback")
check(readyCalls == 1 and reloadCalls == 2, "hot reload called install or missed reload callback")
check(barrierInstalls() == 1 and bg.CreateBoonLootButtons == barrierWrapper,
    "immediate hot reload installed another wrapper")
check(countLog(probeReadyLog, logCount + 1) == 1
    and countLog(hookInstalledLog, logCount + 1) == 0
    and countLog(lobbyProbeLog, logCount + 1) == 0,
    "hot reload duplicated installation or initial probe logs")
barrierStart()
check(barrierInstalls() == 1 and bg.CreateBoonLootButtons == barrierWrapper,
    "repeated load installed another wrapper")
end
local beforeDiagnosticLookups = select(2, metrics())
bg.CreateBoonLootButtons(screen, loot)
local afterDiagnosticLookups = select(2, metrics())
check(afterDiagnosticLookups == beforeDiagnosticLookups + 11,
    "logger did not resolve rom.log.info inside the Lua closure")
print("PASS: initial all-mods/game gates; hot reload bypasses spent all-mods event; game/probe ready repeated; install not repeated; same wrapper; Path.Wrap=1; closure logger")

local dg, dl, debugOff, debugOffInstalls = fixture(function() return "native", nil end, nil, false)
debugOff()
local debugOffWrapper = dg.CreateBoonLootButtons
local debugOffResult = pack(debugOffWrapper(screen, loot))
debugOff()
check(#dl == 0, "DEBUG=false produced BoonAdvisor logs")
check(debugOffResult.n == 2 and debugOffResult[1] == "native" and debugOffResult[2] == nil,
    "DEBUG=false changed native returns")
check(debugOffInstalls() == 1 and dg.CreateBoonLootButtons == debugOffWrapper,
    "DEBUG=false changed wrapper lifecycle")
print("PASS: DEBUG=true useful logs only; DEBUG=false zero BoonAdvisor logs; wrapper lifecycle unchanged")

local phaseLoot = { Name = "HestiaUpgrade", GodLoot = true, UpgradeOptions = {
    { ItemName = "HestiaWeaponBoon", Type = "Trait", Rarity = "Rare" },
    { ItemName = "HestiaSprintBoon", Type = "Trait", Rarity = "Epic", StackNum = 2 },
} }
local phaseScreen = { Source = phaseLoot, KeepOpen = true, BlockedIndexes = { 2 } }
local phaseRun = { Hero = {
    SlottedTraits = { Aspect = "DaggerBackstabAspect" },
    Traits = {
        { Name = "DaggerBackstabAspect", Rarity = "Common", Slot = "Aspect", IsWeaponEnchantment = true },
        { Name = "DaggerRapidAttackTrait", Rarity = "Common" },
        { Name = "AresWeaponBoon", Rarity = "Common", Slot = "Melee" },
        { Name = "EffectVulnerabilityMetaUpgrade", Rarity = "Rare" },
    },
} }
local pg, pl, phaseStart, _, phasePrivate = fixture(function() end, nil, true, {
    CurrentRun = phaseRun,
    GetEquippedWeapon = function() return "WeaponDagger" end,
    LootData = { WeaponUpgrade = { TraitIndex = { DaggerRapidAttackTrait = true } } },
    IsGodTrait = function(name) return name == "AresWeaponBoon" end,
}, false, "intermediate")
phaseStart()
pg.CreateBoonLootButtons(phaseScreen, phaseLoot)
local expectedPhaseLogs = {
    "[BoonAdvisor] Source=HestiaUpgrade",
    "[BoonAdvisor] Weapon=WeaponDagger",
    "[BoonAdvisor] Aspect=DaggerBackstabAspect",
    "[BoonAdvisor] TraitCount=4",
    "[BoonAdvisor] HammerCount=1",
    "[BoonAdvisor] GodTraitCount=1",
    "[BoonAdvisor] OfferCount=2",
    "[BoonAdvisor] Offer[2] originalIndex=2 ItemName=HestiaSprintBoon Type=Trait Rarity=Epic Blocked=true StackNum=2",
    "[BoonAdvisor] Arcana Origination Active=true Rarity=Rare",
    "[BoonAdvisor] OwnedStatusFamilies=Curse",
    "[BoonAdvisor] Context originalIndex=1 StatusFamily=Burn StatusKnowledge=mapped OriginationEnable=true CoreRole=Attack Alignment=ALTERNATIVE SlotPolicy=reserved SlotConflict=false CurrentSlotTrait=AresWeaponBoon SlotStateBefore=ALTERNATIVE SlotStateAfter=ALTERNATIVE ConflictIntroduced=false ConflictResolved=false CoreSacrificed=false FillsEmpty=false Replaces=false AspectInteraction=ASPECT_COMPATIBLE",
    "[BoonAdvisor] Context originalIndex=2 StatusFamily=nil StatusKnowledge=known_non_status OriginationEnable=false CoreRole=Sprint Alignment=NO_PLAN SlotPolicy=nil SlotConflict=false CurrentSlotTrait=nil SlotStateBefore=EMPTY SlotStateAfter=NO_PLAN ConflictIntroduced=false ConflictResolved=false CoreSacrificed=false FillsEmpty=true Replaces=false AspectInteraction=nil",
}
for _, expected in ipairs(expectedPhaseLogs) do
    local found = false
    for _, actual in ipairs(pl) do
        if actual == expected then found = true; break end
    end
    check(found, "missing deterministic Phase 2 log: " .. expected)
end
check(phasePrivate.probeState.lastSnapshot.weapon == "WeaponDagger"
    and phasePrivate.probeState.lastSnapshot.offers[2].Blocked == true,
    "rom.game-backed private snapshot missing")
check(phasePrivate.probeState.lastRankingReady == false
    and phasePrivate.probeState.lastRankedScores == nil,
    "non-ready runtime screen exposed a ranking")
print("PASS: plugin globals absent; dynamic rom.game snapshot uses internal IDs; Sister Blades weapon/aspect; hammer/god/offer counts; blocked offer")

do
    local function npcScore(source, itemName)
        local loot = { Name = source, Traits = { itemName }, UpgradeOptions = {
            { ItemName = itemName, Rarity = "Common" },
        } }
        local screen = { Source = loot, KeepOpen = true, Components = {
            PurchaseButton1 = { Id = "npc-offer-1" },
        } }
        local npcGame, _, npcStart, _, npcPrivate = fixture(function() end, nil, true, {
            CurrentRun = { Hero = { SlottedTraits = { Aspect = "LobCloseAttackAspect" }, Traits = {
                { Name = "LobCloseAttackAspect", IsWeaponEnchantment = true },
            } } },
            GetEquippedWeapon = function() return "WeaponLob" end,
            LootData = {}, IsGodTrait = function() return false end,
        }, false, "auto")
        npcStart()
        npcGame.CreateBoonLootButtons(screen, loot)
        return npcPrivate.probeState.lastScores[1], npcPrivate.probeState.lastSnapshot.offerKind
    end
    local renewedFaith, athenaKind = npcScore("NPC_Athena_01", "DeathDefianceRefillBoon")
    local lastGasp, hadesKind = npcScore("NPC_Hades_Field_01", "HadesDeathDefianceDamageBoon")
    check(athenaKind == "boon" and renewedFaith.score == 200 and renewedFaith.sourceGroup == "NPC Offerings",
        "Athena NPC Renewed Faith source was not recognized and scored 200")
    check(hadesKind == "boon" and lastGasp.score == 200 and lastGasp.sourceGroup == "NPC Offerings",
        "Hades NPC Last Gasp source was not recognized and scored 200")
end
print("PASS: Athena/Hades NPC reward sources recognized and Mobalytics NPC Offerings score 200")

do
    local hero = { SlottedTraits = { Aspect = "LobCloseAttackAspect" }, Traits = {
        { Name = "LobCloseAttackAspect", IsWeaponEnchantment = true },
    } }
    local run = { Hero = hero }
    local loot = { Name = "AphroditeUpgrade", GodLoot = true, UpgradeOptions = {
        { ItemName = "AphroditeWeaponBoon", Rarity = "Common" },
        { ItemName = "AphroditeSprintBoon", Rarity = "Common" },
        { ItemName = "AphroditeManaBoon", Rarity = "Common" },
    } }
    local screen = { Source = loot, KeepOpen = true, Components = {
        PurchaseButton1 = { Id = "aphrodite-1" }, PurchaseButton2 = { Id = "aphrodite-2" },
        PurchaseButton3 = { Id = "aphrodite-3" },
    } }
    local game, _, start, _, private, _, _, _, _, _, labels, destroyed = fixture(
        function() end, nil, true, {
            CurrentRun = run, GetEquippedWeapon = function() return "WeaponLob" end,
            GetLanguage = function() return "en" end,
            LootData = {}, IsGodTrait = function() return false end,
        }, false, "auto")
    start()
    game.CreateBoonLootButtons(screen, loot)
    local firstId = screen.BoonAdvisorCoreAdvisory and screen.BoonAdvisorCoreAdvisory.id
    local notices, noReliablePreference = 0, false
    for _, label in ipairs(labels) do
        if label.RawText == "Boon Core Build Missing" then notices = notices + 1 end
        if label.RawText == "NO RELIABLE PREFERENCE" then noReliablePreference = true end
    end
    check(private.probeState.lastCoreAdvisory == true and firstId ~= nil
        and private.probeState.lastRankingReady == false and screen.BoonAdvisorFallback ~= nil
        and #screen.BoonAdvisorRanks == 0 and notices == 1 and noReliablePreference,
        "unranked Aphrodite offer did not show one immediate Core notice")
    game.CreateBoonLootButtons(screen, loot)
    check(screen.BoonAdvisorCoreAdvisory.id ~= firstId and #destroyed > 0,
        "reroll retained the previous Core notice component")
    for _, name in ipairs({ "HeraWeaponBoon", "ZeusSpecialBoon", "DemeterCastBoon" }) do
        hero.Traits[#hero.Traits + 1] = { Name = name }
    end
    game.CreateBoonLootButtons(screen, loot)
    check(private.probeState.lastCoreAdvisory == false
        and screen.BoonAdvisorCoreAdvisory == nil and screen.BoonAdvisorFallback ~= nil,
        "three acquired slot Cores did not remove the notice while Mana remained absent")
    local demeter = { Name = "DemeterUpgrade", GodLoot = true, UpgradeOptions = {
        { ItemName = "DemeterWeaponBoon", Rarity = "Rare" },
        { ItemName = "DemeterSprintBoon", Rarity = "Common" },
        { ItemName = "DemeterManaBoon", Rarity = "Common" },
    } }
    local demeterScreen = { Source = demeter, KeepOpen = true, Components = {
        PurchaseButton1 = { Id = "demeter-1" }, PurchaseButton2 = { Id = "demeter-2" },
        PurchaseButton3 = { Id = "demeter-3" },
    } }
    game.CreateBoonLootButtons(demeterScreen, demeter)
    check(private.probeState.lastCoreAdvisory == false
        and demeterScreen.BoonAdvisorCoreAdvisory == nil,
        "in-pool Demeter offer showed a notice after the three slot Cores were acquired")
    table.remove(hero.Traits, 2) -- Hera Attack Core is no longer owned.
    game.CreateBoonLootButtons(demeterScreen, demeter)
    check(private.probeState.lastCoreAdvisory == true
        and demeterScreen.BoonAdvisorCoreAdvisory ~= nil,
        "Demeter reroll did not refresh the missing Attack Core notice")
    local hephaestus = { Name = "HephaestusUpgrade", GodLoot = true, UpgradeOptions = {
        { ItemName = "HephaestusCastBoon", Rarity = "Common" },
        { ItemName = "HephaestusWeaponBoon", Rarity = "Common" },
        { ItemName = "HephaestusManaBoon", Rarity = "Common" },
    } }
    local nextScreen = { Source = hephaestus, KeepOpen = true, Components = {
        PurchaseButton1 = { Id = "hephaestus-1" }, PurchaseButton2 = { Id = "hephaestus-2" },
        PurchaseButton3 = { Id = "hephaestus-3" },
    } }
    game.CreateBoonLootButtons(nextScreen, hephaestus)
    check(private.probeState.lastCoreAdvisory == true
        and nextScreen.BoonAdvisorCoreAdvisory ~= nil,
        "Hephaestus offer did not recompute the missing Core from the run inventory")
end
print("PASS: Aphrodite, Demeter, and Hephaestus offers refresh the three-role Core notice independently of ranking")

do
    local history = { ZeusUpgrade = 1 }
    local run = { Hero = { SlottedTraits = { Aspect = "LobCloseAttackAspect" },
        Traits = { { Name = "LobCloseAttackAspect", IsWeaponEnchantment = true } } },
        LootTypeHistory = history }
    local lootData = { ZeusUpgrade = { GodLoot = true },
        AphroditeUpgrade = { GodLoot = true } }
    local loot = { Name = "ZeusUpgrade", GodLoot = true, UpgradeOptions = {
        { ItemName = "ZeusSpecialBoon", Rarity = "Common" },
        { ItemName = "ZeusSprintBoon", Rarity = "Common" },
        { ItemName = "ZeusManaBoon", Rarity = "Common" },
    } }
    local screen = { Source = loot, KeepOpen = true, Components = {
        PurchaseButton1 = { Id = "pool-1" }, PurchaseButton2 = { Id = "pool-2" },
        PurchaseButton3 = { Id = "pool-3" },
    } }
    local game, _, start, _, private, _, _, _, _, _, labels = fixture(function() end, nil, true, {
        CurrentRun = run, GetEquippedWeapon = function() return "WeaponLob" end,
        GetLanguage = function() return "en" end, LootData = lootData,
        HeroData = { MaxGodsPerRun = 4 }, IsGodTrait = function() return false end,
    }, false, "auto")
    start()
    game.CreateBoonLootButtons(screen, loot)
    local recommended, present = false, false
    for _, label in ipairs(labels) do
        if label.RawText == "Build God Pool: Recommended" then recommended = true end
        if label.RawText == "Run God Pool: Present" then present = true end
    end
    check(recommended and present and screen.BoonAdvisorGodPoolContext ~= nil,
        "runtime offer did not render independently verified God Pool facts")
    local scores = private.probeState.lastScores
    local core = private.probeState.lastCoreAdvisory
    history.ZeusUpgrade = nil
    game.CreateBoonLootButtons(screen, loot)
    check(private.probeState.lastCoreAdvisory == core
        and private.probeState.lastScores[1].score == scores[1].score
        and labels[#labels].RawText == "Run God Pool: Unknown",
        "run-history refresh altered scoring/Core or failed to refresh God Pool context")
end
print("PASS: God Pool runtime offer rendering and reroll refresh are informational")

do
    local owned = {
        HeraWeaponBoon = true, ZeusSpecialBoon = true, DemeterCastBoon = true,
        DoubleBoltBoon = true, FocusLightningBoon = true, CastNovaBoon = true,
    }
    local hero = { SlottedTraits = { Aspect = "LobCloseAttackAspect" }, Traits = {
        { Name = "LobCloseAttackAspect", IsWeaponEnchantment = true },
    } }
    for name in pairs(owned) do hero.Traits[#hero.Traits + 1] = { Name = name } end
    local run = { Hero = hero }
    local loot = { Name = "StackUpgrade", StackOnly = true, UpgradeOptions = {
        { ItemName = "HeraWeaponBoon", Rarity = "Common" },
        { ItemName = "ZeusSpecialBoon", Rarity = "Common" },
        { ItemName = "DemeterCastBoon", Rarity = "Common" },
    } }
    local screen = { Source = loot, KeepOpen = true, Components = {
        PurchaseButton1 = { Id = "pom-core-1" }, PurchaseButton2 = { Id = "pom-core-2" },
        PurchaseButton3 = { Id = "pom-core-3" },
    } }
    local game, _, start, _, private, _, _, _, _, _, labels, destroyed = fixture(function() end,
        nil, true, {
            CurrentRun = run,
            GetEquippedWeapon = function() return "WeaponLob" end,
            GetLanguage = function() return "en" end,
            LootData = {}, IsGodTrait = function(name) return owned[name] == true end,
        })
    start()
    game.CreateBoonLootButtons(screen, loot)
    check(private.probeState.lastSnapshot.aspect == "LobCloseAttackAspect"
        and private.probeState.lastSnapshot.offerKind == "pom"
        and private.probeState.lastRankingReady == false
        and screen.BoonAdvisorFallback ~= nil and #screen.BoonAdvisorPomStatuses == 3,
        "complete tied Medea Pom offer did not enter the status-only UI path")
    check(#private.probeState.lastScores == 3
        and private.probeState.lastScores[1].score == 200
        and private.probeState.lastScores[2].score == 200
        and private.probeState.lastScores[3].score == 200,
        "Pom status rendering changed the equal source scores")
    check(labels[#labels - 2].RawText == "Core Boon · Build"
        and labels[#labels - 1].RawText == "Core Boon · Build"
        and labels[#labels].RawText == "Core Boon · Build"
        and labels[#labels - 4].RawText == "NO RELIABLE PREFERENCE"
        and screen.BoonAdvisorRanks ~= nil and #screen.BoonAdvisorRanks == 0,
        "Medea Core Pom tie showed a false rank or incorrect source status")
    local oldStatusIds = {}
    for _, entry in ipairs(screen.BoonAdvisorPomStatuses) do oldStatusIds[#oldStatusIds + 1] = entry.id end

    loot.UpgradeOptions = {
        { ItemName = "DoubleBoltBoon", Rarity = "Common" },
        { ItemName = "FocusLightningBoon", Rarity = "Common" },
        { ItemName = "CastNovaBoon", Rarity = "Common" },
    }
    screen.Components.PurchaseButton1 = { Id = "pom-noncore-1" }
    screen.Components.PurchaseButton2 = { Id = "pom-noncore-2" }
    screen.Components.PurchaseButton3 = { Id = "pom-noncore-3" }
    game.CreateBoonLootButtons(screen, loot)
    local destroyedIds = {}
    for _, batch in ipairs(destroyed) do
        for _, id in ipairs(batch.Ids or {}) do destroyedIds[id] = true end
    end
    check(#screen.BoonAdvisorPomStatuses == 3
        and destroyedIds[oldStatusIds[1]] and destroyedIds[oldStatusIds[2]]
        and destroyedIds[oldStatusIds[3]],
        "Pom reroll retained previous Core status components")
    check(labels[#labels - 2].RawText == "Build" and labels[#labels - 1].RawText == "Build"
        and labels[#labels].RawText == "Build"
        and labels[#labels - 4].RawText == "NO RELIABLE PREFERENCE"
        and private.probeState.lastRankingReady == false
        and screen.BoonAdvisorFallback ~= nil and #screen.BoonAdvisorRanks == 0
        and private.probeState.lastScores[1].score == 100
        and private.probeState.lastScores[2].score == 100
        and private.probeState.lastScores[3].score == 100,
        "Pom reroll did not refresh to Build statuses while preserving scores and tie state")

    loot.UpgradeOptions = {
        { ItemName = "HeraWeaponBoon", Rarity = "Common" },
        { ItemName = "DoubleBoltBoon", Rarity = "Rare" },
        { ItemName = "CastNovaBoon", Rarity = "Epic" },
    }
    screen.Components.PurchaseButton1 = { Id = "pom-ranked-1" }
    screen.Components.PurchaseButton2 = { Id = "pom-ranked-2" }
    screen.Components.PurchaseButton3 = { Id = "pom-ranked-3" }
    local beforeRankedPomLabels = #labels
    game.CreateBoonLootButtons(screen, loot)
    local pomRankDebug = {}
    for _, result in ipairs(private.probeState.lastScores or {}) do
        pomRankDebug[#pomRankDebug + 1] = tostring(result.score) .. "/" .. tostring(result.scoreComplete)
    end
    check(private.probeState.lastRankingReady == true
        and screen.BoonAdvisorPomStatuses == nil
        and labels[beforeRankedPomLabels + 1].RawText == "RANK 1"
        and labels[beforeRankedPomLabels + 3].RawText == "RANK 2"
        and labels[beforeRankedPomLabels + 5].RawText == "RANK 3",
        "distinct-score Pom offer did not retain its normal rank rendering: ready="
            .. tostring(private.probeState.lastRankingReady) .. " scores=" .. table.concat(pomRankDebug, ",")
            .. " labels=" .. tostring(labels[beforeRankedPomLabels + 1] and labels[beforeRankedPomLabels + 1].RawText)
            .. "," .. tostring(labels[beforeRankedPomLabels + 3] and labels[beforeRankedPomLabels + 3].RawText)
            .. "," .. tostring(labels[beforeRankedPomLabels + 5] and labels[beforeRankedPomLabels + 5].RawText))
end
print("PASS: Medea Pom ties show source-derived statuses, rerolls clear them, ranked Pom offers retain ranks")

do
    local unknownLoot = { Name = "UnverifiedOlympianUpgrade", GodLoot = true, UpgradeOptions = {
        { ItemName = "UnknownOlympianBoon", Rarity = "Common" },
    } }
    local unknownScreen = { Source = unknownLoot, KeepOpen = true, Components = {
        PurchaseButton1 = { Id = "unknown-god-offer" },
    } }
    local unknownGame, _, unknownStart, _, unknownPrivate, _, _, _, _, _, unknownLabels = fixture(
        function() end, nil, true, {
            CurrentRun = { Hero = { SlottedTraits = { Aspect = "LobCloseAttackAspect" }, Traits = {
                { Name = "LobCloseAttackAspect", IsWeaponEnchantment = true },
            } } },
            GetEquippedWeapon = function() return "WeaponLob" end,
            GetLanguage = function() return "en" end,
            LootData = {}, IsGodTrait = function() return false end,
        }, false, "auto")
    unknownStart()
    unknownGame.CreateBoonLootButtons(unknownScreen, unknownLoot)
    local notices = 0
    for _, label in ipairs(unknownLabels) do
        if label.RawText == "Boon Core Build Missing" then notices = notices + 1 end
    end
    check(unknownPrivate.probeState.lastSnapshot.offerSource == "UnverifiedOlympianUpgrade"
        and unknownPrivate.probeState.lastCoreAdvisory == true and notices == 1
        and unknownPrivate.probeState.lastRankingReady == false
        and #(unknownPrivate.probeState.lastScores or {}) == 0
        and #(unknownScreen.BoonAdvisorRanks or {}) == 0,
        "unknown GodLoot identity did not conservatively show advice without ranking it: source="
            .. tostring(unknownPrivate.probeState.lastSnapshot.offerSource) .. " advice="
            .. tostring(unknownPrivate.probeState.lastCoreAdvisory) .. " notices=" .. tostring(notices)
            .. " ranking=" .. tostring(unknownPrivate.probeState.lastRankingReady) .. " ranks="
            .. tostring(unknownScreen.BoonAdvisorRanks and #unknownScreen.BoonAdvisorRanks or "nil"))
end
print("PASS: unknown GodLoot source shows conservative advice and remains unrated")

local rankLoot = { Name = "AresUpgrade", GodLoot = true, UpgradeOptions = {
    { ItemName = "AphroditeWeaponBoon", Rarity = "Heroic" },
    { ItemName = "ZeusSpecialBoon" },
    { ItemName = "DemeterCastBoon" },
} }
local rankScreen = { Source = rankLoot, KeepOpen = true }
local rankRun = { Hero = {
    SlottedTraits = { Aspect = "DaggerBackstabAspect" },
    Traits = {
        { Name = "DaggerBackstabAspect", IsWeaponEnchantment = true },
        { Name = "DaggerRapidAttackTrait" },
    },
} }
local rg, rl, rankStart, _, rankPrivate = fixture(function() end, nil, true, {
    CurrentRun = rankRun,
    GetEquippedWeapon = function() return "WeaponDagger" end,
    LootData = { WeaponUpgrade = { TraitIndex = { DaggerRapidAttackTrait = true } } },
    IsGodTrait = function() return false end,
}, false, "intermediate")
rankStart(); rg.CreateBoonLootButtons(rankScreen, rankLoot)
local rankState = rankPrivate.probeState
check(rankState.lastRankingReady == true and #rankState.lastRankedScores == 3,
    "ready runtime screen did not expose internal ranking")
check(rankState.lastRankedScores[1].itemName == "AphroditeWeaponBoon"
    and rankState.lastRankedScores[1].score == 19
    and rankState.lastRankedScores[2].originalIndex == 2
    and rankState.lastRankedScores[3].originalIndex == 3,
    "runtime ranking order or tie-break wrong")
local sawReady, sawRank, sawTie = false, false, false
for _, line in ipairs(rl) do
    if line == "[BoonAdvisor] RankingReady=true" then sawReady = true end
    if line == "[BoonAdvisor] Rank=1 originalIndex=1 ItemName=AphroditeWeaponBoon Score=19 Tied=false" then
        sawRank = true
    end
    if line == "[BoonAdvisor] Rank=2 originalIndex=2 ItemName=ZeusSpecialBoon Score=16 Tied=false" then
        sawTie = true
    end
end
check(sawReady and sawRank and sawTie, "ready ranking diagnostics missing")
local englishRankScreen = { Source = rankLoot, KeepOpen = true }
local englishRankGame, _, englishRankStart, _, englishRankPrivate = fixture(function() end, nil, true, {
    CurrentRun = rankRun,
    GetEquippedWeapon = function() return "WeaponDagger" end,
    GetLanguage = function() return "en" end,
    LootData = { WeaponUpgrade = { TraitIndex = { DaggerRapidAttackTrait = true } } },
    IsGodTrait = function() return false end,
}, false, "intermediate")
englishRankStart(); englishRankGame.CreateBoonLootButtons(englishRankScreen, rankLoot)
local englishRankState = englishRankPrivate.probeState
check(englishRankState.lastRankingReady == rankState.lastRankingReady
    and #englishRankState.lastScores == #rankState.lastScores
    and #englishRankState.lastRankedScores == #rankState.lastRankedScores,
    "language changed ranking state")
for index, result in ipairs(rankState.lastScores) do
    local translated = englishRankState.lastScores[index]
    check(translated.itemName == result.itemName and translated.score == result.score
        and translated.covered == result.covered and translated.scoreComplete == result.scoreComplete,
        "language changed a score object")
end
for index, result in ipairs(rankState.lastRankedScores) do
    local translated = englishRankState.lastRankedScores[index]
    check(translated.originalIndex == result.originalIndex and translated.rank == result.rank,
        "language changed rank ordering")
end
print("PASS: runtime ranking gate keeps nil when false and ranks internally when true; no UI")

local testLoot = { Name = "AresUpgrade", GodLoot = true, UpgradeOptions = {
    { ItemName = "AphroditeWeaponBoon" }, { ItemName = "AresSpecialBoon" }, { ItemName = "AresSprintBoon" },
} }
local testScreen = {
    Source = testLoot, KeepOpen = true,
    Components = {
        PurchaseButton1 = { Id = "native1", X = 100, Y = 200 },
        PurchaseButton2 = { Id = "native2", X = 300, Y = 200 },
        PurchaseButton3 = { Id = "native3", X = 500, Y = 200 },
    },
}
local tg, tl, testStart, _, testPrivate, _, _, _, _, testCreated, testText, testDestroyed = fixture(
    function() end, nil, true, {
        CurrentRun = { Hero = { SlottedTraits = { Aspect = "DaggerBackstabAspect" }, Traits = {} } },
        GetEquippedWeapon = function() return "WeaponDagger" end,
        LootData = {}, IsGodTrait = function() return false end,
    }, true, "intermediate")
testStart(); tg.CreateBoonLootButtons(testScreen, testLoot)
check(testPrivate.probeState.lastRankingReady == false
    and testPrivate.probeState.lastRankedScores == nil
    and #testCreated == 9 and testText[1].RawText == "RANG 1"
    and testText[3].RawText == "RANG 1" and testText[5].RawText == "RANG 3"
    and testText[2].RawText == "Core · Aspect" and testText[4].RawText == "Origination"
    and testText[6].RawText == "Utilitaire"
    and testText[7].RawText == "Boon Core Build Missing",
    "UI_TEST_MODE did not render synthetic 1/1/3 without changing ranking state: ready="
        .. tostring(testPrivate.probeState.lastRankingReady) .. " created=" .. tostring(#testCreated)
        .. " first=" .. tostring(testText[1] and testText[1].RawText) .. " last="
        .. tostring(testText[6] and testText[6].RawText) .. " advisory="
        .. tostring(testPrivate.probeState.lastCoreAdvisory))
local sawSynthetic = false
for _, line in ipairs(tl) do if line == "[BoonAdvisor] UI TEST MODE rendering synthetic ranks 1/1/3" then sawSynthetic = true end end
check(sawSynthetic, "synthetic UI test log missing")
tg.CreateBoonLootButtons(testScreen, testLoot)
check(#testDestroyed == 3 and #testDestroyed[1].Ids == 1
    and #testDestroyed[2].Ids == 2 and #testDestroyed[3].Ids == 6
    and #testCreated == 18 and testText[#testText - 2].RawText == "Boon Core Build Missing",
    "synthetic reroll did not clear and recreate ranks plus the single Core advisory")
local fg, fl, falseStart, _, falsePrivate, _, _, _, _, falseCreated = fixture(
    function() end, nil, true, {
        CurrentRun = { Hero = { SlottedTraits = { Aspect = "DaggerBackstabAspect" }, Traits = {} } },
        GetEquippedWeapon = function() return "WeaponDagger" end, LootData = {}, IsGodTrait = function() return false end,
    }, false, "intermediate")
falseStart(); fg.CreateBoonLootButtons(testScreen, testLoot)
check(#falseCreated == 4 and falsePrivate.probeState.lastRankingReady == false,
    "UI_TEST_MODE=false did not render analysis fallback")
local partialLoot = { Name = "AresUpgrade", GodLoot = true, UpgradeOptions = {
    { ItemName = "AresSpecialBoon" }, { ItemName = "FocusRawDamageBoon" },
    { ItemName = "AresManaBoon" },
} }
local partialScreen = {
    Source = partialLoot, KeepOpen = true,
    Components = {
        PurchaseButton1 = { Id = "partial1", X = 100, Y = 200 },
        PurchaseButton2 = { Id = "partial2", X = 300, Y = 200 },
        PurchaseButton3 = { Id = "partial3", X = 500, Y = 200 },
    },
}
local partialGame, _, partialStart, _, _, _, _, _, _, _, partialText = fixture(
    function() end, nil, true, {
        CurrentRun = { Hero = { SlottedTraits = { Aspect = "DaggerBackstabAspect" }, Traits = {
            { Name = "DaggerBackstabAspect", Slot = "Aspect", IsWeaponEnchantment = true },
        } } },
        GetEquippedWeapon = function() return "WeaponDagger" end, LootData = {}, IsGodTrait = function() return false end,
    }, false, "intermediate")
partialStart(); partialGame.CreateBoonLootButtons(partialScreen, partialLoot)
local sawPartialConflict = false
for _, text in ipairs(partialText) do if text.RawText == "Conflit · Aspect" then sawPartialConflict = true end end
check(sawPartialConflict, "partial analysis did not expose negative slot policy as Conflit")
local realScreen = {
    Source = testLoot, KeepOpen = true,
    Components = {
        PurchaseButton1 = { Id = "real1", X = 100, Y = 200 },
        PurchaseButton2 = { Id = "real2", X = 300, Y = 200 },
        PurchaseButton3 = { Id = "real3", X = 500, Y = 200 },
    },
}
local rg2, rl2, realStart, _, realPrivate, _, _, _, _, realCreated = fixture(
    function() end, nil, true, {
        CurrentRun = rankRun,
        GetEquippedWeapon = function() return "WeaponDagger" end, LootData = {}, IsGodTrait = function() return false end,
    }, true, "intermediate")
realStart(); rg2.CreateBoonLootButtons(realScreen, testLoot)
check(realPrivate.probeState.lastRankingReady == true and #realCreated == 9
    and realScreen.BoonAdvisorCoreAdvisory ~= nil,
    "UI_TEST_MODE did not preserve real ready UI")
for _, line in ipairs(rl2) do
    check(line ~= "[BoonAdvisor] UI TEST MODE rendering synthetic ranks 1/1/3",
        "synthetic UI rendered over a real ranking")
end
print("PASS: UI_TEST_MODE false/true, synthetic 1/1/3, state isolation, reroll cleanup")

-- TryUpgradeBoon wrapper: one native call, exact returns, refresh only after a new button.
local tryCalls, tryMode = 0, "button"
local tryGame, tryLogs, tryStart, tryInstalls, tryPrivate, tryLoadMain, _, _, tryStats = fixture(
    function() end, nil, true, {
        CurrentRun = rankRun,
        GetEquippedWeapon = function() return "WeaponDagger" end,
        LootData = {}, IsGodTrait = function() return false end,
        TryUpgradeBoon = function(lootData, screenArg, buttonArg, ...)
            tryCalls = tryCalls + 1
            check(screenArg == testScreen and lootData == testLoot and buttonArg == "oldButton",
                "TryUpgradeBoon arguments changed")
            if tryMode == "nil" then return nil end
            if tryMode == "error" then error("native TryUpgradeBoon failure") end
            return { Id = "newButton" }, nil, "tail"
        end,
    }, true, "intermediate")
tryStart()
local tryResult = pack(tryGame.TryUpgradeBoon(testLoot, testScreen, "oldButton"))
check(tryCalls == 1 and tryResult.n == 3 and tryResult[1].Id == "newButton"
    and tryResult[2] == nil and tryResult[3] == "tail", "TryUpgradeBoon returns changed")
local tryInstallCount = tryInstalls()
tryLoadMain()
check(tryInstalls() == tryInstallCount, "TryUpgradeBoon wrapper duplicated on hot reload")
local beforeTryLogs = #tryLogs
tryMode = "nil"
local nilResult = pack(tryGame.TryUpgradeBoon(testLoot, testScreen, "oldButton"))
local sawNilRefresh = false
for index = beforeTryLogs + 1, #tryLogs do
    if tryLogs[index] == "[BoonAdvisor] UI refresh after TryUpgradeBoon" then sawNilRefresh = true end
end
check(nilResult.n == 1 and nilResult[1] == nil and not sawNilRefresh,
    "nil TryUpgradeBoon incorrectly refreshed UI")
tryMode = "error"
local okTry = pcall(tryGame.TryUpgradeBoon, testLoot, testScreen, "oldButton")
check(not okTry and tryCalls == 3, "native TryUpgradeBoon error was swallowed")
print("PASS: TryUpgradeBoon wrapper single call, exact returns/errors, refresh only on new button")

-- Successful sublimation integration: stale components are removed and new UI targets the new button.
local integrationScreen = {
    Source = testLoot, KeepOpen = true,
    Components = {
        PurchaseButton1 = { Id = "old1" },
        PurchaseButton2 = { Id = "old2" },
        PurchaseButton3 = { Id = "old3" },
    },
}
local integrationTryCalls = 0
testLoot.UpgradeOptions[1].Rarity = "Epic"
testLoot.UpgradeOptions[2].Rarity = "Common"
testLoot.UpgradeOptions[3].Rarity = "Common"
local ig, il, igStart, _, igPrivate, _, _, _, _, igCreated, igText, igDestroyed, igAttached = fixture(
    function() end, nil, true, {
        CurrentRun = rankRun,
        GetEquippedWeapon = function() return "WeaponDagger" end,
        LootData = {}, IsGodTrait = function() return false end,
        TryUpgradeBoon = function(_, screenArg)
            integrationTryCalls = integrationTryCalls + 1
            screenArg.Components.PurchaseButton1 = { Id = "new1" }
            testLoot.UpgradeOptions[1].Rarity = "Heroic"
            return { Id = "new1" }
        end,
    }, true, "intermediate")
igStart()
-- Initial render creates the old annotations; sublimation must replace them exactly once.
ig.CreateBoonLootButtons(integrationScreen, testLoot)
local oldCreated = #igCreated
local oldStateReady = igPrivate.probeState.lastRankingReady
local oldScore = igPrivate.probeState.lastScores[1].score
ig.TryUpgradeBoon(testLoot, integrationScreen, "oldButton")
check(integrationTryCalls == 1 and integrationScreen.Components.PurchaseButton1.Id == "new1",
    "integration sublimation did not replace PurchaseButton1")
check(#igDestroyed > 0 and #igCreated > oldCreated,
    "successful sublimation did not clear and recreate Advisor UI")
local sawNewTarget = false
for _, attach in ipairs(igAttached) do
    if attach.DestinationId == "new1" then sawNewTarget = true end
end
for _, line in ipairs(il) do
    if line == "[BoonAdvisor] UI refresh after TryUpgradeBoon" then end
end
check(sawNewTarget, "refreshed UI was not attached to the new PurchaseButton1")
check(igPrivate.probeState.lastRankingReady == oldStateReady,
    "integration refresh changed ranking state unexpectedly")
check(igPrivate.probeState.lastScores[1].score == oldScore + 1,
    "sublimation did not trigger global rarity rescore")
-- A subsequent reroll clears the refreshed UI; another sublimation recreates it without stale entries.
ig.CreateBoonLootButtons(integrationScreen, testLoot)
ig.TryUpgradeBoon(testLoot, integrationScreen, "oldButton")
check(integrationTryCalls == 2 and #igDestroyed >= 2, "reroll/sublimation cleanup regressed")
print("PASS: TryUpgradeBoon successful refresh targets new button; reroll cleanup has no stale UI")

do
    local loot = { Name = "PoseidonUpgrade", GodLoot = true, UpgradeOptions = {
        { ItemName = "PoseidonWeaponBoon", Rarity = "Common" },
        { ItemName = "PoseidonManaBoon", Rarity = "Common" },
        { ItemName = "RoomRewardBonusBoon", Rarity = "Common" },
    } }
    local screen = { Source = loot, KeepOpen = true, Components = {
        PurchaseButton1 = { Id = "coat1" }, PurchaseButton2 = { Id = "coat2" },
        PurchaseButton3 = { Id = "coat3" },
    } }
    local game, _, start, _, private, _, _, _, _, created, texts, destroyed, attached = fixture(
        function() end, nil, true, {
            CurrentRun = { Hero = { SlottedTraits = { Aspect = "BaseSuitAspect" }, Traits = {
                { Name = "BaseSuitAspect", Slot = "Aspect", IsWeaponEnchantment = true },
            } } },
            GetEquippedWeapon = function() return "WeaponSuit" end,
            LootData = {}, IsGodTrait = function() return false end,
            TryUpgradeBoon = function(_, target)
                target.Components.PurchaseButton1 = { Id = "coat1-new" }
                loot.UpgradeOptions[1].Rarity = "Rare"
                return { Id = "coat1-new" }
            end,
        }, false, "auto")
    start()
    game.CreateBoonLootButtons(screen, loot)
    check(private.probeState.lastRankingReady == false
        and private.probeState.lastRankedScores == nil and #screen.BoonAdvisorRanks == 3
        and screen.BoonAdvisorFallback ~= nil, "Black Coat partial UI state missing")
    local function hasText(value)
        for _, entry in ipairs(texts) do if entry.RawText == value then return true end end
        return false
    end
    check(hasText("RANG 1/2") and hasText("RANG 2/2") and hasText("NON ÉVALUÉ")
        and hasText("CLASSEMENT PARTIEL"), "Black Coat partial labels missing")
    local beforeReroll = #created
    game.CreateBoonLootButtons(screen, loot)
    check(#destroyed >= 2 and #created > beforeReroll and #screen.BoonAdvisorRanks == 3,
        "partial reroll left stale annotations")
    local beforeSublime = #created
    game.TryUpgradeBoon(loot, screen, "coat1")
    check(#created > beforeSublime and #screen.BoonAdvisorRanks == 3
        and private.probeState.lastRankingReady == false, "partial Sublime refresh changed ranking gate")
    local attachedNew = false
    for _, entry in ipairs(attached) do
        if entry.DestinationId == "coat1-new" then attachedNew = true end
    end
    check(attachedNew, "partial Sublime refresh did not attach to the new native button")
end
print("PASS: Black Coat partial UI, reroll, and Sublime refresh preserve unknown choice")

do
    local loot = { Name = "WeaponUpgrade", GodLoot = false, DebugOnly = true, UpgradeOptions = {
        { ItemName = "SuitDashAttackTrait", Rarity = "Common" },
        { ItemName = "SuitAttackSpeedTrait", Rarity = "Common" },
        { ItemName = "SuitSpecialAutoTrait", Rarity = "Common" },
    } }
    local screen = { Source = loot, KeepOpen = true, Components = {
        PurchaseButton1 = { Id = "hammer1" }, PurchaseButton2 = { Id = "hammer2" },
        PurchaseButton3 = { Id = "hammer3" },
    } }
    local game, _, start, _, private, _, _, _, _, created, texts, destroyed = fixture(
        function() end, nil, true, {
            CurrentRun = { Hero = { SlottedTraits = { Aspect = "BaseSuitAspect" }, Traits = {
                { Name = "BaseSuitAspect", Slot = "Aspect", IsWeaponEnchantment = true },
            } } },
            GetEquippedWeapon = function() return "WeaponSuit" end,
            LootData = {}, IsGodTrait = function() return false end,
        }, false, "auto")
    start()
    private.probeState.focusState.run = game.CurrentRun
    private.probeState.focusState.focus = "attack"
    game.CreateBoonLootButtons(screen, loot)
    local snapshot = private.probeState.lastSnapshot
    local scores = private.probeState.lastScores
    check(snapshot.offerKind == "hammer" and snapshot.offerSource == "WeaponUpgrade",
        "WeaponUpgrade source discriminator was not preserved")
    check(snapshot.offers[1].ItemName == "SuitDashAttackTrait"
        and snapshot.offers[2].ItemName == "SuitAttackSpeedTrait"
        and snapshot.offers[3].ItemName == "SuitSpecialAutoTrait",
        "Hammer Trait IDs were not captured from UpgradeOptions")
    check(scores[1].score == -1 and scores[1].covered and scores[1].scoreComplete
        and scores[2].score == -2 and scores[2].covered and scores[2].scoreComplete,
        "known unconditional Hammers were not evaluated from hammerPlan")
    check(scores[3].score == -3 and scores[3].covered and not scores[3].scoreComplete,
        "conditional Hammer was not kept incomplete")
    check(private.probeState.lastRankingReady == false and private.probeState.lastRankedScores == nil,
        "partial Hammer comparison changed the full-ranking contract")
    local function hasText(value)
        for _, entry in ipairs(texts) do if entry.RawText == value then return true end end
        return false
    end
    check(hasText("RANG 1/2") and hasText("RANG 2/2") and hasText("NON ÉVALUÉ")
        and hasText("CLASSEMENT PARTIEL") and hasText("Plan Marteau"),
        "Hammer partial ranking UI was not rendered")
    local createdBeforeReroll = #created
    game.CreateBoonLootButtons(screen, loot)
    check(#destroyed >= 2 and #created > createdBeforeReroll and #screen.BoonAdvisorRanks == 3,
        "Hammer offer refresh left stale or duplicate Advisor components")
end
print("PASS: WeaponUpgrade Hammer offers use the profile hammerPlan and partial UI")

do
    local function unsupportedScreen(aspect, expected, registryOverride)
        local loot = { Name = "AresUpgrade", GodLoot = true, UpgradeOptions = {
            { ItemName = "AresWeaponBoon" }, { ItemName = "AresSpecialBoon" },
            { ItemName = "AresSprintBoon" },
        } }
        local screen = { Source = loot, KeepOpen = true, Components = {
            PurchaseButton1 = { Id = "unsupported1" }, PurchaseButton2 = { Id = "unsupported2" },
            PurchaseButton3 = { Id = "unsupported3" },
        } }
        local game, _, start, _, private, _, _, _, _, _, text = fixture(function() end, nil, true, {
            CurrentRun = { Hero = { SlottedTraits = { Aspect = aspect }, Traits = {
                { Name = aspect, Slot = "Aspect", IsWeaponEnchantment = true },
            } } },
            GetEquippedWeapon = function() return "WeaponDagger" end,
            LootData = {}, IsGodTrait = function() return false end,
        }, false, "auto", registryOverride)
        start(); game.CreateBoonLootButtons(screen, loot)
        check(private.probeState.lastRankingReady == false
            and private.probeState.lastRankedScores == nil and #screen.BoonAdvisorRanks == 0,
            "unresolved profile displayed a partial or full rank")
        local found = false
        for _, entry in ipairs(text) do if entry.RawText == expected then found = true end end
        check(found, "profile fallback changed: " .. expected)
    end
    local ambiguousRegistry = assert(loadfile("data/builds/registry.lua"))()
    ambiguousRegistry.synthetic_tie = {
        weapon = "WeaponDagger", aspect = "DaggerBackstabAspect",
        module = "data/builds/sister_blades_melinoe_intermediate.lua",
    }
    unsupportedScreen("DaggerBackstabAspect", "PROFIL À CHOISIR", ambiguousRegistry)
    unsupportedScreen("DaggerBlockAspect", "PROFIL NON PRIS EN CHARGE")
end
print("PASS: ambiguous and unsupported profiles remain unranked with distinct fallbacks")

-- Phase 5J-A: selector defaults safely and exposes the active real profile in DEBUG logs.
local function hasLog(lines, fragment)
    for _, line in ipairs(lines) do if line:find(fragment, 1, true) then return true end end
    return false
end
local selectorLoot = { Name = "AphroditeUpgrade", GodLoot = true, UpgradeOptions = {
    { ItemName = "AphroditeWeaponBoon" },
} }
local selectorScreen = { Source = selectorLoot, KeepOpen = true, Components = {} }
local selectorRun = { Hero = { SlottedTraits = { Aspect = "DaggerBackstabAspect" },
    Traits = { { Name = "DaggerBackstabAspect", IsWeaponEnchantment = true } }, Weapons = {} } }
do
local legacyGame, legacyLogs, legacyStart, _, legacyPrivate, legacyReload = fixture(function() end, nil, true, {
    CurrentRun = selectorRun, GetEquippedWeapon = function() return "WeaponDagger" end,
    LootData = {}, IsGodTrait = function() return false end,
}, false, "starter")
legacyStart()
legacyGame.CreateBoonLootButtons(selectorScreen, selectorLoot)
check(hasLog(legacyLogs, "WARN CONFIGURED_PROFILE_UNAVAILABLE: Configured BUILD_PROFILE=starter is unavailable; using auto for this session. settings.lua was not changed.")
    and hasLog(legacyLogs, "BuildId=sister_blades_melinoe_intermediate ProfileMode=intermediate SchemaVersion=1 Supported=true"),
    "retired Starter setting did not warn and resolve via auto")
local function legacyWarnCount()
    local count = 0
    for _, line in ipairs(legacyLogs) do
        if line:find("WARN CONFIGURED_PROFILE_UNAVAILABLE:", 1, true) then count = count + 1 end
    end
    return count
end
check(legacyWarnCount() == 1, "retired Starter setting warning count changed")
legacyReload()
legacyGame.CreateBoonLootButtons(selectorScreen, selectorLoot)
check(legacyWarnCount() == 1 and legacyPrivate.probeState.logState.suppressed["WARN:CONFIGURED_PROFILE_UNAVAILABLE"] == 1,
    "retired Starter setting warned twice after hot reload")
end
do
    local quietGame, quietLogs, quietStart, _, quietPrivate, quietReload = fixture(function() end, nil, false, {
        CurrentRun = selectorRun, GetEquippedWeapon = function() return "WeaponDagger" end,
        LootData = {}, IsGodTrait = function() return false end,
    }, false, "starter")
    quietStart()
    quietGame.CreateBoonLootButtons(selectorScreen, selectorLoot)
    check(#quietLogs == 1 and quietLogs[1]:find("WARN CONFIGURED_PROFILE_UNAVAILABLE:", 1, true)
        and quietPrivate.probeState.lastScores[1].supported,
        "retired Starter warning was hidden by DEBUG=false or stopped scoring")
    quietReload()
    quietGame.CreateBoonLootButtons(selectorScreen, selectorLoot)
    check(#quietLogs == 1, "retired Starter warning repeated in normal-release mode")
end
local defaultGame, defaultLogs, defaultStart = fixture(function() end, nil, true, {
    CurrentRun = selectorRun, GetEquippedWeapon = function() return "WeaponDagger" end,
    LootData = {}, IsGodTrait = function() return false end,
}, false, "intermediate")
defaultStart()
defaultGame.CreateBoonLootButtons(selectorScreen, selectorLoot)
check(hasLog(defaultLogs, "BuildId=sister_blades_melinoe_intermediate ProfileMode=intermediate SchemaVersion=1"),
    "explicit Intermediate profile was not preserved")
local autoMorriganGame, autoMorriganLogs, autoMorriganStart = fixture(function() end, nil, true, {
    CurrentRun = { Hero = { SlottedTraits = { Aspect = "DaggerTripleAspect" }, Traits = {
        { Name = "DaggerTripleAspect", IsWeaponEnchantment = true },
    }, Weapons = {} } },
    GetEquippedWeapon = function() return "WeaponDagger" end,
    LootData = {}, IsGodTrait = function() return false end,
})
autoMorriganStart()
autoMorriganGame.CreateBoonLootButtons(selectorScreen, selectorLoot)
check(hasLog(autoMorriganLogs, "BuildId=sister_blades_morrigan_meta ProfileMode=meta SchemaVersion=1 Supported=true"),
    "auto mode did not resolve the singleton Morrigan profile")
local autoMelinoeGame, autoMelinoeLogs, autoMelinoeStart = fixture(function() end, nil, true, {
    CurrentRun = selectorRun, GetEquippedWeapon = function() return "WeaponDagger" end,
    LootData = {}, IsGodTrait = function() return false end,
})
autoMelinoeStart()
autoMelinoeGame.CreateBoonLootButtons(selectorScreen, selectorLoot)
check(hasLog(autoMelinoeLogs, "BuildId=sister_blades_melinoe_intermediate ProfileMode=intermediate SchemaVersion=1 Supported=true"),
    "auto Melinoe did not resolve the sole Intermediate profile")
local invalidGame, invalidLogs, invalidStart = fixture(function() end, nil, true, {
    CurrentRun = selectorRun, GetEquippedWeapon = function() return "WeaponDagger" end,
    LootData = {}, IsGodTrait = function() return false end,
}, false, "not-a-profile")
invalidStart()
invalidGame.CreateBoonLootButtons(selectorScreen, selectorLoot)
check(hasLog(invalidLogs, "WARN CONFIGURED_PROFILE_UNAVAILABLE")
    and hasLog(invalidLogs, "BuildId=sister_blades_melinoe_intermediate ProfileMode=intermediate SchemaVersion=1 Supported=true"),
    "invalid preference did not warn and fall back to sole compatible profile")
local morriganGame, morriganLogs, morriganStart = fixture(function() end, nil, true, {
    CurrentRun = { Hero = { SlottedTraits = { Aspect = "DaggerTripleAspect" }, Traits = {
        { Name = "DaggerTripleAspect", Slot = "Aspect", IsWeaponEnchantment = true },
    }, Weapons = {} } },
    GetEquippedWeapon = function() return "WeaponDagger" end,
    LootData = {}, IsGodTrait = function() return false end,
}, false, "intermediate")
morriganStart()
morriganGame.CreateBoonLootButtons(selectorScreen, selectorLoot)
check(hasLog(morriganLogs, "BuildId=sister_blades_morrigan_meta ProfileMode=meta SchemaVersion=1 Supported=true"),
    "Morrigan did not auto-select morrigan_meta")
local invalidMorriganGame, invalidMorriganLogs, invalidMorriganStart = fixture(function() end, nil, true, {
    CurrentRun = { Hero = { SlottedTraits = { Aspect = "DaggerTripleAspect" }, Traits = {
        { Name = "DaggerTripleAspect", Slot = "Aspect", IsWeaponEnchantment = true },
    }, Weapons = {} } },
    GetEquippedWeapon = function() return "WeaponDagger" end,
    LootData = {}, IsGodTrait = function() return false end,
}, false, "not-a-profile")
invalidMorriganStart()
invalidMorriganGame.CreateBoonLootButtons(selectorScreen, selectorLoot)
check(hasLog(invalidMorriganLogs, "BuildId=sister_blades_morrigan_meta ProfileMode=meta SchemaVersion=1 Supported=true"),
    "invalid preference incorrectly rejected the sole Morrigan candidate")
local function checkRetiredStarter(aspect, weapon, expected)
    local legacy = { fixture(function() end, nil, true, {
            CurrentRun = { Hero = { SlottedTraits = { Aspect = aspect }, Traits = {
                { Name = aspect, Slot = "Aspect", IsWeaponEnchantment = true },
            }, Weapons = {} } },
            GetEquippedWeapon = function() return weapon end,
            LootData = {}, IsGodTrait = function() return false end,
        }, false, "starter") }
    legacy[3]()
    legacy[1].CreateBoonLootButtons(selectorScreen, selectorLoot)
    check(hasLog(legacy[2], "WARN CONFIGURED_PROFILE_UNAVAILABLE: Configured BUILD_PROFILE=starter")
        and hasLog(legacy[2], "BuildId=" .. expected)
        and hasLog(legacy[2], "Supported=true")
        and legacy[5].probeState.logState.suppressed["WARN:CONFIGURED_PROFILE_UNAVAILABLE"] == nil,
        "retired Starter setting did not fall back to the compatible profile with one warning")
    legacy[6]()
    legacy[1].CreateBoonLootButtons(selectorScreen, selectorLoot)
    local warningCount = 0
    for _, line in ipairs(legacy[2]) do
        if line:find("WARN CONFIGURED_PROFILE_UNAVAILABLE:", 1, true) then warningCount = warningCount + 1 end
    end
    check(warningCount == 1 and legacy[5].probeState.logState.suppressed["WARN:CONFIGURED_PROFILE_UNAVAILABLE"] == 1,
        "retired Starter warning was not deduplicated")
end
checkRetiredStarter("DaggerTripleAspect", "WeaponDagger", "sister_blades_morrigan_meta")
checkRetiredStarter("BaseSuitAspect", "WeaponSuit", "black_coat_melinoe_intermediate")
print("PASS: build profile resolver defaults, exact aspect selection, singleton fallback, and ambiguity safety")

; (function()
    local run = { Hero = { SlottedTraits = { Aspect = "BaseSuitAspect" }, Traits = {
        { Name = "BaseSuitAspect", Slot = "Aspect", IsWeaponEnchantment = true },
    } } }
    local loot = { Name = "WeaponUpgrade", UpgradeOptions = {
        { ItemName = "SuitDashAttackTrait", Rarity = "Common" },
        { ItemName = "SuitSpecialAutoTrait", Rarity = "Common" },
    } }
    local screen = { Source = loot, KeepOpen = true, Components = {
        PurchaseButton1 = { Id = "focus-hammer-1" },
        PurchaseButton2 = { Id = "focus-hammer-2" },
    } }
    local game, _, start, _, private = fixture(function() end, nil, true, {
        CurrentRun = run,
        GetEquippedWeapon = function() return "WeaponSuit" end,
        LootData = {}, IsGodTrait = function() return false end,
        AttachLua = function() end,
        StartRoom = function(currentRun, currentRoom)
            check((currentRun == run and currentRoom.Name == "TestRoom")
                or (currentRun ~= run and currentRoom.Name == "NextRunRoom"),
                "room wrapper arguments changed")
            return "native-room-result", nil, "tail"
        end,
    }, false, "auto")
    start()
    game.CreateBoonLootButtons(screen, loot)
    check(screen.Components.BoonAdvisorFocusTile ~= nil
        and not private.probeState.lastScores[2].scoreComplete,
        "Black Coat focus tile was absent or undecided Launcher was evaluated")
    game.BoonAdvisorSelectFocus(screen, screen.Components.BoonAdvisorFocusTile)
    check(screen.Components.BoonAdvisorFocusSpecial ~= nil, "focus menu did not open")
    game.BoonAdvisorSelectFocus(screen, screen.Components.BoonAdvisorFocusSpecial)
    check(screen.Components.BoonAdvisorRouteZeus ~= nil
        and private.probeState.focusState.focus == "special", "route menu did not open")
    game.BoonAdvisorSelectFocus(screen, screen.Components.BoonAdvisorRouteZeus)
    check(private.probeState.focusState.route == "zeus"
        and private.probeState.focusState.locked
        and private.probeState.lastScores[1].scoreComplete
        and private.probeState.lastScores[2].scoreComplete,
        "route click did not lock focus and refresh the Hammer analysis")
    local selectedRoute = private.probeState.focusState.route
    game.BoonAdvisorSelectFocus(screen, { BoonAdvisorChoice = "route:ares" })
    check(private.probeState.focusState.route == selectedRoute,
        "locked focus accepted a stale/direct callback")
    local beforeRoomReminder = private.probeState.focusHud.id
    local roomResult = pack(game.StartRoom(run, { Name = "TestRoom" }))
    check(roomResult.n == 3 and roomResult[1] == "native-room-result"
        and roomResult[2] == nil and roomResult[3] == "tail",
        "room wrapper changed the native return values")
    check(private.probeState.focusState.locked
        and private.probeState.focusHud.id ~= nil
        and private.probeState.focusHud.id ~= beforeRoomReminder,
        "passive reminder was not recreated at the next room")
    local nextRun = { Hero = {} }
    game.StartRoom(nextRun, { Name = "NextRunRoom" })
    check(not private.probeState.focusState.locked
        and private.probeState.focusHud.id == nil,
        "focus reminder did not reset for a new run")
end)()
print("PASS: focus locks route, rejects later changes, persists across rooms, resets on new runs")

; (function()
    local run = {
        Hero = { Weapons = { WeaponDagger = true }, SlottedTraits = { Aspect = "DaggerBackstabAspect" } },
        CurrentRoom = { Name = "Hub_Main" },
    }
    local hub = { Name = "Hub_Main" }
    local game, logs, start, _, private, _, _, _, _, overviewCreated, overviewText = fixture(function() end, nil, true, {
        CurrentRun = run,
        CurrentHubRoom = hub,
        AttachLua = function() end,
        GameState = { LastWeaponUpgradeName = {
            WeaponDagger = "DaggerBackstabAspect", WeaponSuit = "BaseSuitAspect",
        } },
        WeaponSets = { HeroPrimaryWeapons = { "WeaponDagger", "WeaponSuit" } },
        UseWeaponKit = function()
            run.Hero.Weapons = { WeaponSuit = true }
            return "weapon-result", nil
        end,
        SelectWeaponUpgrade = function()
            run.Hero.SlottedTraits.Aspect = "BaseSuitAspect"
            return "aspect-result", nil
        end,
        StartNewRun = function()
            run.CurrentRoom = { Name = "F_StartingRoom" }
            return run
        end,
        StartRoom = function(currentRun, currentRoom)
            currentRun.CurrentRoom = currentRoom
            return "room-result", nil
        end,
        ShowCombatUI = function(value)
            return value, nil, "hud-result"
        end,
        CreateMetaUpgradeCards = function(screen)
            return "native-cards", nil
        end,
        DeathAreaRoomTransition = function() hub.Name = "Hub_Main" end,
        HubPostBountyLoad = function() end,
        HubPostDreamLoad = function() end,
    }, false, "auto")
    start()
    check(private.probeState.hookCount == 9, "lifecycle hooks were not installed")
    check(private.probeState.buildHud.key ~= nil and #overviewCreated == 1
        and overviewText[1].RawText == "Build : Lames Sœurs · Melinoë",
        "resolved lobby identity was not displayed")
    local arcanaScreen = { Components = {}, KeepOpen = true }
    local cardsResult = pack(game.CreateMetaUpgradeCards(arcanaScreen))
    check(cardsResult.n == 2 and cardsResult[1] == "native-cards"
        and cardsResult[2] == nil
        and next(arcanaScreen.Components) == nil,
        "native Arcana screen was unexpectedly modified")
    local function hasProbe(stage, needle)
        for _, line in ipairs(logs) do
            if line:find("LOBBY_PROBE stage=" .. stage, 1, true)
                and (needle == nil or line:find(needle, 1, true)) then return true end
        end
        return false
    end
    check(hasProbe("plugin_loaded", "hub=Hub_Main"), "initial hub snapshot not logged")
    local weaponResult = pack(game.UseWeaponKit())
    check(weaponResult.n == 2 and weaponResult[1] == "weapon-result" and weaponResult[2] == nil,
        "weapon-kit wrapper changed returns")
    check(hasProbe("UseWeaponKit", "primaryCount=1 weapon=WeaponSuit"), "weapon change not observed")
    local aspectResult = pack(game.SelectWeaponUpgrade())
    check(aspectResult.n == 2 and aspectResult[1] == "aspect-result" and aspectResult[2] == nil,
        "Aspect wrapper changed returns")
    check(hasProbe("SelectWeaponUpgrade", "activeAspect=BaseSuitAspect"), "Aspect change not observed")
    game.DeathAreaRoomTransition()
    check(hasProbe("HubRoomTransition", "hub=Hub_Main"), "hub transition not observed")
    game.StartNewRun()
    check(hasProbe("StartNewRun", "room=F_StartingRoom"), "new run not observed")
    check(private.probeState.buildHud.key ~= nil and #private.probeState.buildHud.items == 1
        and overviewText[#overviewText].RawText == "Build : Manteau Noir · Melinoë",
        "build identity did not persist at run start")
    run.Hero.Weapons = { WeaponDagger = true }
    run.Hero.SlottedTraits.Aspect = "DaggerBackstabAspect"
    local roomResult = pack(game.StartRoom(run, { Name = "F_FirstRoom" }))
    check(roomResult.n == 2 and roomResult[1] == "room-result" and roomResult[2] == nil,
        "room probe wrapper changed native returns")
    check(hasProbe("StartRoom", "room=F_FirstRoom"), "run room not observed")
    local beforeHudRefresh = #overviewCreated
    local hudResult = pack(game.ShowCombatUI("combat-hud"))
    check(hudResult.n == 3 and hudResult[1] == "combat-hud"
        and hudResult[2] == nil and hudResult[3] == "hud-result",
        "ShowCombatUI wrapper changed native return values")
    check(#overviewCreated == beforeHudRefresh + 1
        and private.probeState.buildHud.key ~= nil
        and #private.probeState.buildHud.items == 1
        and overviewText[#overviewText].RawText == "Build : Manteau Noir · Melinoë",
        "run-scoped build identity changed or was not refreshed after native combat HUD setup")
    local stableHudCount = #overviewCreated
    game.ShowCombatUI("movement-hud")
    game.ShowCombatUI("dash-hud")
    check(#overviewCreated == stableHudCount,
        "repeated combat HUD calls recreated the unchanged build label")
    game.DeathAreaRoomTransition()
    check(private.probeState.buildHud.run == nil and private.probeState.buildHud.runName == nil,
        "run-scoped build identity was not cleared after returning to the hub")
    game.HubPostBountyLoad()
    check(overviewText[#overviewText].RawText == "Build : Lames Sœurs · Melinoë"
        and private.probeState.buildHud.run == nil,
        "lobby identity was not re-detected after the run-scoped lock was reset: "
            .. tostring(overviewText[#overviewText] and overviewText[#overviewText].RawText)
            .. " / " .. tostring(private.probeState.buildHud.key))
    local lobbyComponentCount = #overviewCreated
    game.HubPostDreamLoad()
    check(#overviewCreated == lobbyComponentCount,
        "duplicate lobby load callback recreated the unchanged build label")
    hub.Name = "Hub_PreRun"
    game.HubPostBountyLoad()
    check(#overviewCreated == lobbyComponentCount + 1
        and overviewText[#overviewText].RawText == "Build : Lames Sœurs · Melinoë",
        "build label was not refreshed once after changing hub rooms")
end)()
print("PASS: read-only lifecycle hooks observe hub, weapon, Aspect and run rooms while preserving native returns")
