local function check(value, message) assert(value, message) end
local Snapshot = assert(loadfile("src/GameState.lua"))()
local Advisory = assert(loadfile("src/CoreAdvisory.lua"))()
local Context = assert(loadfile("src/GodPoolContext.lua"))()
local Scoring = assert(loadfile("src/ScoringEngine.lua"))()
local UI = assert(loadfile("src/UI.lua"))()
local Localization = assert(loadfile("src/Localization.lua"))()
local profile = assert(loadfile("data/builds/argent_skull_medea_mobalytics.lua"))()

local lootData = {}
for _, source in ipairs({ "ZeusUpgrade", "HeraUpgrade", "AresUpgrade",
    "DemeterUpgrade", "AphroditeUpgrade", "PoseidonUpgrade" }) do
    lootData[source] = { GodLoot = true }
end
lootData.WeaponUpgrade = { GodLoot = false }
local function capture(source, history, max, data)
    local run = { Hero = { Traits = {} }, LootTypeHistory = history, MaxGodsPerRun = max }
    local snapshot = Snapshot.capture({ CurrentRun = run, LootData = data or lootData,
        HeroData = { MaxGodsPerRun = 4 }, OfferSource = source })
    snapshot.offerSource, snapshot.offerKind = source, "boon"
    return snapshot, run
end
local function evaluate(snapshot, selected)
    return Context.evaluate(Advisory.godPoolMembership(selected or profile, snapshot), snapshot)
end

local recommended, run = capture("ZeusUpgrade", { ZeusUpgrade = 1 }, 4)
local result = evaluate(recommended)
check(result.recommendedByBuild == "Yes" and result.observedInRuntimePool == "Yes",
    "encountered recommended god lost either independent status")
check(recommended.nativeGodPool.registered.ZeusUpgrade == true and run.Hero.MetGods == nil,
    "run history was replaced by the currently owned boon inventory")
recommended.nativeGodPool.registered.ZeusUpgrade = false
check(run.LootTypeHistory.ZeusUpgrade == 1, "snapshot aliases mutable native run history")

local open = capture("HeraUpgrade", { ZeusUpgrade = 1 }, 4)
result = evaluate(open)
check(result.recommendedByBuild == "Yes" and result.observedInRuntimePool == "Unknown",
    "an unencountered recommended god in an open pool was declared absent")
local outside = capture("AphroditeUpgrade", { ZeusUpgrade = 1, AphroditeUpgrade = 1 }, 4)
result = evaluate(outside)
check(result.recommendedByBuild == "No" and result.observedInRuntimePool == "Yes",
    "outside recommendation was confused with observed runtime presence")
local switchedProfile = { godPool = { { offerSource = "AphroditeUpgrade" } } }
check(evaluate(recommended, switchedProfile).recommendedByBuild == "No"
    and evaluate(recommended).recommendedByBuild == "Yes",
    "profile switch reused a previous build's recommendation")
local closed = capture("AphroditeUpgrade", { ZeusUpgrade = 1, HeraUpgrade = 1,
    AresUpgrade = 1, DemeterUpgrade = 1 }, 4)
result = evaluate(closed)
check(result.recommendedByBuild == "No" and result.observedInRuntimePool == "No",
    "complete native history at the native limit did not prove absence")
local bountyLimit = capture("AphroditeUpgrade", { ZeusUpgrade = 1, HeraUpgrade = 1 }, 2)
check(evaluate(bountyLimit).observedInRuntimePool == "No",
    "run-specific native max-god override was ignored")

local replaced = capture("ZeusUpgrade", { ZeusUpgrade = 1, HeraUpgrade = 1 }, 4)
check(evaluate(replaced).observedInRuntimePool == "Yes",
    "replaced or removed owned boon erased an interacted god")
local newRun = capture("ZeusUpgrade", {}, 4)
check(evaluate(newRun).observedInRuntimePool == "Unknown",
    "new run inherited God Pool state from the previous run")
local reloaded = capture("ZeusUpgrade", { ZeusUpgrade = 1 }, 4)
check(evaluate(reloaded).observedInRuntimePool == "Yes",
    "reloaded run was not reconstructed from native history")
local rerolled = capture("ZeusUpgrade", { ZeusUpgrade = 1 }, 4)
check(evaluate(rerolled).observedInRuntimePool == "Yes",
    "reroll of the same source lost observed status")

local unknownProfile = capture("ZeusUpgrade", { ZeusUpgrade = 1 }, 4)
result = Context.evaluate(Advisory.godPoolMembership({}, unknownProfile), unknownProfile)
check(result.recommendedByBuild == "Unknown" and result.observedInRuntimePool == "Yes",
    "unknown build metadata incorrectly hid an independently observed god")
local noHistory = capture("ZeusUpgrade", nil, 4)
check(evaluate(noHistory).observedInRuntimePool == "Unknown", "missing history was guessed")
local badMetadata = capture("AphroditeUpgrade", { ZeusUpgrade = 1, MissingLoot = 1,
    HeraUpgrade = 1, AresUpgrade = 1, DemeterUpgrade = 1 }, 4)
check(evaluate(badMetadata).observedInRuntimePool == "Unknown",
    "incomplete source metadata falsely proved a closed pool")
local unknownSource = capture("UnknownUpgrade", { ZeusUpgrade = 1 }, 4)
check(evaluate(unknownSource).recommendedByBuild == "Unknown"
    and evaluate(unknownSource).observedInRuntimePool == "Unknown",
    "unknown native source received a God Pool verdict")
local special = capture("WeaponUpgrade", { ZeusUpgrade = 1 }, 4)
check(evaluate(special).observedInRuntimePool == "Unknown",
    "a non-god source was treated as an Olympian")
local unknownLimit = capture("AphroditeUpgrade", { ZeusUpgrade = 1 }, nil)
unknownLimit.nativeGodPool.maxGods = nil
check(evaluate(unknownLimit).observedInRuntimePool == "Unknown",
    "missing native god limit produced an absence claim")
local invalidLimit = capture("AphroditeUpgrade", { ZeusUpgrade = 1,
    HeraUpgrade = 1, AresUpgrade = 1, DemeterUpgrade = 1 }, "invalid")
check(evaluate(invalidLimit).observedInRuntimePool == "Unknown",
    "invalid run-specific limit fell back to a guessed global limit")
local excludedButOpen = capture("AphroditeUpgrade", { ZeusUpgrade = 1,
    HeraUpgrade = 1, AresUpgrade = 1 }, 4)
check(evaluate(excludedButOpen).observedInRuntimePool == "Unknown",
    "an excluded or forced fourth source was mistaken for an observed fourth god")

-- This context must never enter the ranking engine or change a Core notice.
local offer = capture("ZeusUpgrade", { ZeusUpgrade = 1 }, 4)
offer.weapon, offer.aspect = profile.weapon, profile.aspect
offer.offers = { { originalIndex = 1, ItemName = "ZeusSpecialBoon",
    Rarity = "Common", raritySource = "upgrade_option" } }
local before = Scoring.scoreOffers(offer, profile)
local decision = Scoring.getRankingDecision(before, Scoring.isProfileSupported(offer, profile))
local advisory = Advisory.shouldShow(profile, offer, true)
evaluate(offer)
offer.nativeGodPool.registered.ZeusUpgrade = false
local after = Scoring.scoreOffers(offer, profile)
local afterDecision = Scoring.getRankingDecision(after, Scoring.isProfileSupported(offer, profile))
check(before[1].score == after[1].score and decision.mode == afterDecision.mode
    and advisory == Advisory.shouldShow(profile, offer, true),
    "informational runtime pool altered score, ranking, or Core Advisory")

UI.setLocalization(Localization)
UI.setLanguage("en")
ScreenCenterX, ScreenCenterY = 960, 540
local created, texts, destroyed = {}, {}, {}
local api = {
    CreateScreenComponent = function(data)
        local component = { Id = #created + 1, X = data.X, Y = data.Y }
        created[#created + 1] = component
        return component
    end,
    CreateTextBox = function(data) texts[#texts + 1] = data end,
    Destroy = function(data) destroyed[#destroyed + 1] = data end,
}
local screen = { Components = {} }
UI.renderGodPoolContext(screen, { recommendedByBuild = "Yes",
    observedInRuntimePool = "Unknown" }, api)
check(#created == 2 and texts[1].RawText == "Build God Pool: Recommended"
    and texts[2].RawText == "Run God Pool: Unknown"
    and created[1].X > ScreenCenterX and created[2].Y > created[1].Y,
    "independent God Pool facts were not rendered under the build identity")
UI.clearRanks(screen, api)
check(#destroyed == 1 and #destroyed[1].Ids == 2
    and screen.Components.BoonAdvisorGodPoolBuild == nil,
    "God Pool UI was not cleaned up on offer close or reroll")

print("PASS: God Pool recommendation, native history, unknowns, non-interference, and UI")
