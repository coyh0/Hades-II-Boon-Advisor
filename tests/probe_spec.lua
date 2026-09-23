-- Run from the repository root. Framework doubles do not validate integration.
local function check(value, message) assert(value, message) end
local function pack(...) return table.pack(...) end
local function fixture(native, sink, debugEnabled, runtime, uiTestMode, buildProfile)
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
        local component = { Id = id, X = data.X, Y = data.Y }
        uiCreated[#uiCreated + 1] = component
        return component
    end
    game.CreateTextBox = function(data) uiText[#uiText + 1] = data end
    game.Attach = function(data) uiAttached[#uiAttached + 1] = data end
    game.Destroy = function(data) uiDestroyed[#uiDestroyed + 1] = data end
    env.import = function(path)
        if path == "config/settings.lua" then
            return {
                DEBUG = debugEnabled ~= false,
                UI_TEST_MODE = uiTestMode == true,
    BUILD_PROFILE = buildProfile or "auto",
            }
        end
        if path == "Logger.lua" or path == "Localization.lua" or path == "GameState.lua" or path == "OfferSnapshot.lua"
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
    { Name = "WeaponUpgrade", GodLoot = false },
    { Name = "StackUpgrade", GodLoot = false, StackOnly = true },
    { Name = "UnknownTestSource", GodLoot = true },
    { Name = "ZeusUpgrade", GodLoot = true, DebugOnly = true },
}) do
    local g, l, start = fixture(function() end)
    start(); local n = #l
    check(pack(g.CreateBoonLootButtons({ Source = bad, KeepOpen = true }, bad)).n == 0, "zero returns lost")
    check(#l == n, "unsupported menu logged")
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
check(#bl == 2 and bl[1] == "[BoonAdvisor] Hook installed: CreateBoonLootButtons"
    and bl[2] == "[BoonAdvisor] Probe ready; hook count=1", "initial useful logs changed")
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
check(#bl == logCount + 1 and bl[#bl] == "[BoonAdvisor] Probe ready; hook count=1",
    "hot reload did not emit only probe-ready")
barrierStart()
check(barrierInstalls() == 1 and bg.CreateBoonLootButtons == barrierWrapper,
    "repeated load installed another wrapper")
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
    "[BoonAdvisor] Context originalIndex=1 StatusFamily=Burn StatusKnowledge=mapped OriginationEnable=true CoreRole=Attack Alignment=NON_TARGET SlotPolicy=reserved SlotConflict=true CurrentSlotTrait=AresWeaponBoon SlotStateBefore=CORE SlotStateAfter=NON_TARGET ConflictIntroduced=true ConflictResolved=false CoreSacrificed=false FillsEmpty=false Replaces=false AspectInteraction=ASPECT_COMPATIBLE",
    "[BoonAdvisor] Context originalIndex=2 StatusFamily=nil StatusKnowledge=known_non_status OriginationEnable=false CoreRole=Sprint Alignment=NON_TARGET SlotPolicy=preferred SlotConflict=false CurrentSlotTrait=nil SlotStateBefore=EMPTY SlotStateAfter=NON_TARGET ConflictIntroduced=false ConflictResolved=false CoreSacrificed=false FillsEmpty=true Replaces=false AspectInteraction=nil",
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

local rankLoot = { Name = "AresUpgrade", GodLoot = true, UpgradeOptions = {
    { ItemName = "AresWeaponBoon" },
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
check(rankState.lastRankedScores[1].itemName == "AresWeaponBoon"
    and rankState.lastRankedScores[1].score == 20
    and rankState.lastRankedScores[2].originalIndex == 2
    and rankState.lastRankedScores[3].originalIndex == 3,
    "runtime ranking order or tie-break wrong")
local sawReady, sawRank, sawTie = false, false, false
for _, line in ipairs(rl) do
    if line == "[BoonAdvisor] RankingReady=true" then sawReady = true end
    if line == "[BoonAdvisor] Rank=1 originalIndex=1 ItemName=AresWeaponBoon Score=20 Tied=false" then
        sawRank = true
    end
    if line == "[BoonAdvisor] Rank=2 originalIndex=2 ItemName=ZeusSpecialBoon Score=16 Tied=true"
        or line == "[BoonAdvisor] Rank=2 originalIndex=3 ItemName=DemeterCastBoon Score=16 Tied=true" then
        sawTie = true
    end
end
check(sawReady and sawRank and sawTie, "ready ranking diagnostics missing or tie not explicit")
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
    { ItemName = "AresWeaponBoon" }, { ItemName = "AresSpecialBoon" }, { ItemName = "AresSprintBoon" },
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
    and #testCreated == 6 and testText[1].RawText == "RANG 1"
    and testText[3].RawText == "RANG 1" and testText[5].RawText == "RANG 3"
    and testText[2].RawText == "Core · Aspect" and testText[4].RawText == "Origination"
    and testText[6].RawText == "Utilitaire",
    "UI_TEST_MODE did not render synthetic 1/1/3 without changing ranking state")
local sawSynthetic = false
for _, line in ipairs(tl) do if line == "[BoonAdvisor] UI TEST MODE rendering synthetic ranks 1/1/3" then sawSynthetic = true end end
check(sawSynthetic, "synthetic UI test log missing")
tg.CreateBoonLootButtons(testScreen, testLoot)
check(#testDestroyed == 1 and #testDestroyed[1].Ids == 6 and #testCreated == 12,
    "synthetic reroll did not clear and recreate ranks")
local fg, fl, falseStart, _, falsePrivate, _, _, _, _, falseCreated = fixture(
    function() end, nil, true, {
        CurrentRun = { Hero = { SlottedTraits = { Aspect = "DaggerBackstabAspect" }, Traits = {} } },
        GetEquippedWeapon = function() return "WeaponDagger" end, LootData = {}, IsGodTrait = function() return false end,
    }, false, "intermediate")
falseStart(); fg.CreateBoonLootButtons(testScreen, testLoot)
check(#falseCreated == 1 and falsePrivate.probeState.lastRankingReady == false,
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
check(realPrivate.probeState.lastRankingReady == true and #realCreated == 6,
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
    local function unsupportedScreen(aspect, expected)
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
        }, false, "auto")
        start(); game.CreateBoonLootButtons(screen, loot)
        check(private.probeState.lastRankingReady == false
            and private.probeState.lastRankedScores == nil and #screen.BoonAdvisorRanks == 0,
            "unresolved profile displayed a partial or full rank")
        local found = false
        for _, entry in ipairs(text) do if entry.RawText == expected then found = true end end
        check(found, "profile fallback changed: " .. expected)
    end
    unsupportedScreen("DaggerBackstabAspect", "PROFIL À CHOISIR")
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
local starterGame, starterLogs, starterStart = fixture(function() end, nil, true, {
    CurrentRun = selectorRun, GetEquippedWeapon = function() return "WeaponDagger" end,
    LootData = {}, IsGodTrait = function() return false end,
}, false, "starter")
starterStart()
starterGame.CreateBoonLootButtons(selectorScreen, selectorLoot)
check(hasLog(starterLogs, "BuildId=sister_blades_melinoe_starter ProfileMode=starter SchemaVersion=1"),
    "configured Starter profile was not selected or logged")
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
check(hasLog(autoMelinoeLogs, "Profile resolution=ambiguous")
    and hasLog(autoMelinoeLogs, "Supported=false")
    and not hasLog(autoMelinoeLogs, "BuildId=sister_blades_melinoe_intermediate"),
    "auto Melinoe did not remain ambiguous without a selected BuildId")
local invalidGame, invalidLogs, invalidStart = fixture(function() end, nil, true, {
    CurrentRun = selectorRun, GetEquippedWeapon = function() return "WeaponDagger" end,
    LootData = {}, IsGodTrait = function() return false end,
}, false, "not-a-profile")
invalidStart()
invalidGame.CreateBoonLootButtons(selectorScreen, selectorLoot)
check(hasLog(invalidLogs, "Profile resolution=ambiguous")
    and hasLog(invalidLogs, "Supported=false"),
    "invalid profile did not fail safely on ambiguous compatible profiles")
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
print("PASS: build profile resolver defaults, exact aspect selection, singleton fallback, and ambiguity safety")
