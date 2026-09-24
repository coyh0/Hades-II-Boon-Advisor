local Engine = assert(loadfile("src/ScoringEngine.lua"))()
local intermediate = assert(loadfile("data/builds/sister_blades_melinoe_intermediate.lua"))()
local morrigan = assert(loadfile("data/builds/sister_blades_morrigan_meta.lua"))()
local coat = assert(loadfile("data/builds/black_coat_melinoe_intermediate.lua"))()
local function check(value, message) assert(value, message) end
local function snapshot(offers, owned)
    return { weapon = "WeaponDagger", aspect = "DaggerBackstabAspect",
        godTraits = owned or {}, hammers = {}, activeArcana = {}, offers = offers }
end
local function offer(index, name, rarity, old)
    return { originalIndex = index, ItemName = name, Rarity = rarity or "Common",
        TraitToReplace = old, OldRarity = old and "Common" or nil }
end
local function reason(result, code)
    for _, entry in ipairs(result.reasons) do if entry.code == code then return entry end end
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

for _, profile in ipairs({ intermediate }) do
    check(Engine.validateProfile(profile), "migrated profile invalid")
    check(profile.selectionEvidence == nil, "unused selection evidence was retained")
    local expected = { AphroditeWeaponBoon = 1, ApolloWeaponBoon = 1,
        HestiaWeaponBoon = 1, AresWeaponBoon = 2 }
    check(#profile.slots.Attack.branches == 4, "Attack branch inventory changed")
    for _, branch in ipairs(profile.slots.Attack.branches) do
        check(expected[branch.traitId] == branch.priority
            and Engine.getBuildAlignment(profile, "Attack", branch.traitId) == "ALTERNATIVE",
            "Attack priority or alignment changed")
        if branch.traitId == "AresWeaponBoon" then
            check(branch.classification == "conditional" and branch.condition.state == "unresolved"
                and branch.condition.code == "WOUNDS_ACCESS", "Wounds prerequisite was guessed")
        else
            check(branch.classification == "alternative" and branch.condition == nil,
                "unconditional branch gained a condition")
        end
    end
    check(Engine.getBuildAlignment(profile, "Attack", "ZeusWeaponBoon") == "NON_TARGET",
        "unknown Attack was treated as a viable branch")
    local results = Engine.scoreOffers(snapshot({ offer(1, "AphroditeWeaponBoon"),
        offer(2, "ApolloWeaponBoon"), offer(3, "AresWeaponBoon") }), profile)
    check(results[1].covered and results[1].scoreComplete and results[1].score == 12
        and results[2].covered and results[2].scoreComplete and results[2].score == 12,
        "branch priority added uncalibrated score")
    check(results[3].covered and not results[3].scoreComplete
        and reason(results[3], "ATTACK_BRANCH_UNRESOLVED") ~= nil,
        "unresolved Wounds branch became rank eligible")
    check(Engine.getRankingDecision(results, true).mode == "none",
        "tied complete branches were ranked")
    local partial = Engine.scoreOffers(snapshot({ offer(1, "AphroditeWeaponBoon", "Heroic"),
        offer(2, "ApolloWeaponBoon"), offer(3, "AresWeaponBoon") }), profile)
    local decision = Engine.getRankingDecision(partial, true)
    check(decision.mode == "partial" and #decision.rankEligible == 2,
        "unresolved Wounds blocked justified partial ranking")
    local ranked = Engine.rank(decision.rankEligible)
    check(ranked[1].originalIndex == 1 and ranked[1].rank == 1
        and ranked[2].originalIndex == 2 and ranked[2].rank == 2,
        "partial ranking included the unresolved Attack")
    local full = Engine.scoreOffers(snapshot({ offer(1, "AphroditeWeaponBoon", "Heroic"),
        offer(2, "ApolloWeaponBoon", "Epic"), offer(3, "HestiaWeaponBoon") }), profile)
    check(full[3].score == 12 and full[3].covered and full[3].scoreComplete,
        "Hestia branch ordinal priority changed its score or completeness")
    check(Engine.getRankingDecision(full, true).mode == "full", "three known Attack branches did not rank")
    local unknown = Engine.scoreOffers(snapshot({ offer(1, "AphroditeWeaponBoon"),
        offer(2, "ApolloWeaponBoon"), offer(3, "UnknownAttackBoon") }), profile)
    check(not unknown[3].scoreComplete and Engine.getRankingDecision(unknown, true).mode == "none",
        "unknown offer or tied known branches were ranked")
    local oldWounds = Engine.scoreOffers(snapshot({ offer(1, "AphroditeWeaponBoon", "Common", "AresWeaponBoon") },
        { { Name = "AresWeaponBoon", Slot = "Melee" } }), profile)[1]
    check(not oldWounds.scoreComplete and reason(oldWounds, "REPLACEMENT_UNRESOLVED") ~= nil
        and reason(oldWounds, "BUILD_SLOT_POLICY_DELTA") == nil,
        "replacement of unresolved Wounds branch was completed")
    local newWounds = Engine.scoreOffers(snapshot({ offer(1, "AresWeaponBoon", "Common", "AphroditeWeaponBoon") },
        { { Name = "AphroditeWeaponBoon", Slot = "Melee" } }), profile)[1]
    check(not newWounds.scoreComplete and reason(newWounds, "REPLACEMENT_UNRESOLVED") ~= nil
        and reason(newWounds, "BUILD_SLOT_POLICY_DELTA") == nil,
        "replacement into unresolved Wounds branch was completed")
    local sameWounds = Engine.scoreOffers(snapshot({ offer(1, "AresWeaponBoon", "Common", "AresWeaponBoon") },
        { { Name = "AresWeaponBoon", Slot = "Melee" } }), profile)[1]
    check(not sameWounds.scoreComplete and reason(sameWounds, "REPLACEMENT_UNRESOLVED") ~= nil
        and reason(sameWounds, "BUILD_SLOT_POLICY_DELTA") == nil,
        "Ares-to-Ares replacement resolved the unknown Wounds condition")
    local oldWoundsContext = Engine.getCoreSlotContext(snapshot({}, {
        { Name = "AresWeaponBoon", Slot = "Melee" } }), profile,
        offer(1, "AphroditeWeaponBoon", "Common", "AresWeaponBoon"))
    local newWoundsContext = Engine.getCoreSlotContext(snapshot({}, {
        { Name = "AphroditeWeaponBoon", Slot = "Melee" } }), profile,
        offer(1, "AresWeaponBoon", "Common", "AphroditeWeaponBoon"))
    local sameWoundsContext = Engine.getCoreSlotContext(snapshot({}, {
        { Name = "AresWeaponBoon", Slot = "Melee" } }), profile,
        offer(1, "AresWeaponBoon", "Common", "AresWeaponBoon"))
    check(oldWoundsContext.conditionUnresolved and not oldWoundsContext.conflictResolved
        and newWoundsContext.conditionUnresolved and not newWoundsContext.conflictResolved
        and sameWoundsContext.conditionUnresolved and not sameWoundsContext.conflictResolved,
        "unresolved Attack condition was exposed as a resolved conflict")
    local nonTargetToBranch = Engine.scoreOffers(snapshot({
        offer(1, "AphroditeWeaponBoon", "Common", "ZeusWeaponBoon") },
        { { Name = "ZeusWeaponBoon", Slot = "Melee" } }), profile)[1]
    check(Engine.getBuildAlignment(profile, "Attack", "ZeusWeaponBoon") == "NON_TARGET"
        and nonTargetToBranch.covered and nonTargetToBranch.scoreComplete
        and reason(nonTargetToBranch, "CORE_REPLACEMENT_DELTA") ~= nil
        and reason(nonTargetToBranch, "BUILD_SLOT_POLICY_DELTA") ~= nil,
        "known non-target to complete Attack branch did not resolve")
    local branchToNonTarget = Engine.scoreOffers(snapshot({
        offer(1, "ZeusWeaponBoon", "Common", "AphroditeWeaponBoon") },
        { { Name = "AphroditeWeaponBoon", Slot = "Melee" } }), profile)[1]
    check(branchToNonTarget.covered and branchToNonTarget.scoreComplete
        and reason(branchToNonTarget, "CORE_REPLACEMENT_DELTA") ~= nil
        and reason(branchToNonTarget, "BUILD_SLOT_POLICY_DELTA") ~= nil,
        "complete Attack branch to non-target replacement changed")
    local knownReplacement = Engine.scoreOffers(snapshot({ offer(1, "HestiaWeaponBoon", "Common", "AphroditeWeaponBoon") },
        { { Name = "AphroditeWeaponBoon", Slot = "Melee" } }), profile)[1]
    check(knownReplacement.covered and knownReplacement.scoreComplete
        and reason(knownReplacement, "CORE_REPLACEMENT_DELTA") ~= nil,
        "known Attack branch replacement was not evaluated")
    local invalid = copy(profile)
    invalid.slots.Attack.branches[2].traitId = "AphroditeWeaponBoon"
    check(not Engine.validateProfile(invalid), "duplicate Attack branch accepted")
    invalid = copy(profile)
    invalid.slots.Attack.core = { "AphroditeWeaponBoon" }
    check(not Engine.validateProfile(invalid), "contradictory legacy/branch entry accepted")
    invalid = copy(profile)
    invalid.slots.Attack.branches[4].condition.code = "UNVERIFIED_CONDITION"
    check(not Engine.validateProfile(invalid), "unknown condition accepted")
    invalid = copy(profile)
    invalid.slots.Attack.branches[4].condition.predicate = "free text"
    check(not Engine.validateProfile(invalid), "free-text condition was accepted")
end
check(morrigan.slots.Attack.branches == nil and coat.slots.Attack.branches == nil,
    "non-migrated profiles gained branches")
print("PASS: Attack branches, ordinal-only priorities, unresolved Wounds, full/partial/none, replacement and schema safety")
