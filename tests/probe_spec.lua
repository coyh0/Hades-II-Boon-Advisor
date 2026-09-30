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

local function runFor(weapon, aspect, configuredProfile)
    local run = { Hero = { SlottedTraits = { Aspect = aspect }, Traits = {
        { Name = aspect, Slot = "Aspect", IsWeaponEnchantment = true },
    }, Weapons = {} } }
    local offer = { Name = "ZeusUpgrade", GodLoot = true, UpgradeOptions = {
        { ItemName = "ZeusSpecialBoon", Rarity = "Common" },
    } }
    local screen = { Source = offer, KeepOpen = true, Components = {} }
    local game, messages, start, _, private = fixture(function() end, nil, true, {
        CurrentRun = run, GetEquippedWeapon = function() return weapon end,
        LootData = {}, IsGodTrait = function() return false end,
    }, false, configuredProfile)
    start()
    game.CreateBoonLootButtons(screen, offer)
    return messages, private.probeState
end
local function contains(messages, fragment)
    for _, message in ipairs(messages) do
        if message:find(fragment, 1, true) then return true end
    end
    return false
end
local medeaLogs, medeaState = runFor("WeaponLob", "LobCloseAttackAspect", "auto")
check(contains(medeaLogs, "BuildId=argent_skull_medea_mobalytics")
    and medeaState.lastScores[1].supported, "active Medea profile was not resolved and scored")
local moonstoneLogs, moonstoneState = runFor("WeaponAxe", "AxeRecoveryAspect", "auto")
check(contains(moonstoneLogs, "BuildId=moonstone_axe_melinoe_mobalytics")
    and moonstoneState.lastScores[1].supported, "active Moonstone profile was not resolved")
local fallbackLogs, fallbackState = runFor("WeaponLob", "LobCloseAttackAspect", "retired_preference")
check(contains(fallbackLogs, "WARN CONFIGURED_PROFILE_UNAVAILABLE")
    and contains(fallbackLogs, "BuildId=argent_skull_medea_mobalytics")
    and fallbackState.lastScores[1].supported,
    "invalid preference did not warn and fall back to active compatible profile")
local unsupportedLogs, unsupportedState = runFor("WeaponDagger", "DaggerBackstabAspect", "auto")
check(not contains(unsupportedLogs, "Supported=true") and unsupportedState.lastRankingReady == false,
    "retired weapon/aspect was treated as an active build")
print("PASS: active profile resolution, invalid preference fallback and retired-weapon fail-safe")
