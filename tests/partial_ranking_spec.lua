local Engine = assert(loadfile("src/ScoringEngine.lua"))()
local function check(ok, message) assert(ok, message) end
local function result(index, score, code, covered, complete, eligible)
    return {
        originalIndex = index, score = score, supported = true,
        eligible = eligible ~= false, covered = covered == true,
        scoreComplete = complete == true,
        reasons = code and { { code = code, delta = score } } or {},
    }
end
local function decide(scores, supported)
    return Engine.getRankingDecision(scores, supported ~= false)
end
local full = { result(1, 12, "BUILD_CORE_PRIORITY", true, true),
    result(2, 12, "BUILD_CORE_PRIORITY", true, true),
    result(3, 4, "FILL_EMPTY_UTILITY_CORE", true, true) }
local decision = decide(full)
check(decision.mode == "full" and Engine.isRankingReady(full, decision.context), "full gate changed")
local ranked = Engine.rank(full)
check(ranked[1].rank == 1 and ranked[2].rank == 1 and ranked[3].rank == 3,
    "full competition ties changed")

local unknown = result(3, 99, "BUILD_CORE_PRIORITY", false, false)
local partial = { result(1, 12, "BUILD_CORE_PRIORITY", true, true),
    result(2, 4, "FILL_EMPTY_UTILITY_CORE", true, true), unknown }
decision = decide(partial)
check(decision.mode == "partial" and #decision.rankEligible == 2
    and decision.rankEligible[1].originalIndex == 1 and decision.rankEligible[2].originalIndex == 2
    and not Engine.isRankingReady(partial, decision.context), "2/3 partial eligibility failed")
ranked = Engine.rank(decision.rankEligible)
check(ranked[1].rank == 1 and ranked[2].rank == 2, "partial 1/2 and 2/2 ranks changed")
for _, unresolvedCode in ipairs({ "RARITY_UNRESOLVED", "REPLACEMENT_UNRESOLVED", "ORIGINATION_UNRESOLVED" }) do
    local incompleteThird = result(3, 99, unresolvedCode, true, false)
    local knownPair = {
        result(1, 12, "BUILD_CORE_PRIORITY", true, true),
        result(2, 4, "FILL_EMPTY_UTILITY_CORE", true, true),
        incompleteThird,
    }
    local pairDecision = decide(knownPair)
    check(pairDecision.mode == "partial", unresolvedCode .. " on third offer blocked valid partial ranking")
    check(#pairDecision.rankEligible == 2, unresolvedCode .. " changed rank-eligible count")
    check(pairDecision.rankEligible[1].originalIndex ~= incompleteThird.originalIndex
        and pairDecision.rankEligible[2].originalIndex ~= incompleteThird.originalIndex,
        unresolvedCode .. " incomplete offer entered rankEligible")
    local pairRanks = Engine.rank(pairDecision.rankEligible)
    check(#pairRanks == 2 and pairRanks[1].originalIndex == 1 and pairRanks[1].rank == 1
        and pairRanks[2].originalIndex == 2 and pairRanks[2].rank == 2,
        unresolvedCode .. " did not rank the two complete offers as 1 and 2")
end
partial[2] = result(2, 12, "BUILD_CORE_PRIORITY", true, true)
check(decide(partial).mode == "none", "tied partial choices were ranked")
partial[2] = result(2, 4, "BUILD_CORE_PRIORITY", true, true)
partial[1].reasons = {}
partial[2].reasons = {}
check(decide(partial).mode == "none", "partial scores without a verified rule were ranked")
partial[1].reasons = { { code = "BUILD_CORE_PRIORITY", delta = 12 } }
partial[2].reasons = {}
check(decide(partial).mode == "partial", "verified difference among eligible pair was lost")
partial[1].reasons = {}
unknown.reasons = { { code = "BUILD_CORE_PRIORITY", delta = 99 } }
check(decide(partial).mode == "none", "unknown offer supplied differentiating evidence")

for _, code in ipairs({ "RARITY_UNRESOLVED", "REPLACEMENT_UNRESOLVED", "ORIGINATION_UNRESOLVED" }) do
    local incomplete = result(2, 4, code, true, false)
    local case = { result(1, 12, "BUILD_CORE_PRIORITY", true, true), incomplete,
        result(3, 0, nil, false, false) }
    check(decide(case).mode == "none", code .. " became rank-eligible")
end
check(decide({ result(1, 12, "BUILD_CORE_PRIORITY", true, true),
    result(2, 4, "FILL_EMPTY_UTILITY_CORE", true, true),
    result(3, 0, nil, false, false) }, false).mode == "none", "unsupported profile ranked")
check(decide({ result(1, 12, "BUILD_CORE_PRIORITY", true, true),
    result(2, 4, "FILL_EMPTY_UTILITY_CORE", true, true),
    result(3, 0, nil, false, false, false) }).mode == "full", "blocked offer was counted as unknown")
check(decide({ result(1, 12, "BUILD_CORE_PRIORITY", true, true),
    result(2, 0, nil, false, false), result(3, 0, nil, false, false) }).mode == "none",
    "1/3 evaluated was ranked")
check(decide({ result(1, 0, nil, false, false), result(2, 0, nil, false, false),
    result(3, 0, nil, false, false) }).mode == "none", "0/3 evaluated was ranked")

local coat = assert(loadfile("data/builds/black_coat_melinoe_intermediate.lua"))()
local blackCoatScores = Engine.scoreOffers({ weapon = "WeaponSuit", aspect = "BaseSuitAspect",
    godTraits = {}, hammers = {}, activeArcana = {}, offers = {
        { originalIndex = 1, ItemName = "PoseidonWeaponBoon", Rarity = "Common" },
        { originalIndex = 2, ItemName = "PoseidonManaBoon", Rarity = "Common" },
        { originalIndex = 3, ItemName = "RoomRewardBonusBoon", Rarity = "Common" },
    } }, coat)
check(blackCoatScores[1].covered and blackCoatScores[1].scoreComplete
    and blackCoatScores[2].covered and blackCoatScores[2].scoreComplete
    and not blackCoatScores[3].covered and not blackCoatScores[3].scoreComplete,
    "observed Black Coat offer coverage changed")
decision = decide(blackCoatScores)
check(decision.mode == "partial" and #decision.rankEligible == 2,
    "observed Black Coat offer did not enter safe partial mode")
print("PASS: full/partial/none decision, subset-only evidence, blocked/incomplete exclusions, Black Coat pilot")
