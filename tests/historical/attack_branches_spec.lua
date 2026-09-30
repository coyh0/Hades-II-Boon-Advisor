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
        check(branch.classification == "alternative" and branch.condition == nil,
            "base Attack branch gained an unsupported prerequisite")
    end
    check(Engine.getBuildAlignment(profile, "Attack", "ZeusWeaponBoon") == "NON_TARGET",
        "unknown Attack was treated as a viable branch")
    local results = Engine.scoreOffers(snapshot({ offer(1, "AphroditeWeaponBoon"),
        offer(2, "ApolloWeaponBoon"), offer(3, "AresWeaponBoon") }), profile)
    for _, result in ipairs(results) do
        check(result.score == 12 and result.covered and result.scoreComplete
            and reason(result, "ATTACK_BRANCH_UNRESOLVED") == nil,
            "valid Attack branch became incomplete or gained an ordinal score")
    end
    check(Engine.getRankingDecision(results, true).mode == "none",
        "tied complete branches were ranked")
    local full = Engine.scoreOffers(snapshot({ offer(1, "AresWeaponBoon", "Heroic"),
        offer(2, "ApolloWeaponBoon", "Epic"), offer(3, "AphroditeWeaponBoon") }), profile)
    local fullDecision = Engine.getRankingDecision(full, true)
    check(fullDecision.mode == "full" and #fullDecision.rankEligible == 3,
        "three complete Attack branches did not permit full ranking")
    local fullRanks = Engine.rank(fullDecision.rankEligible)
    check(fullRanks[1].originalIndex == 1 and fullRanks[1].rank == 1
        and fullRanks[2].originalIndex == 2 and fullRanks[2].rank == 2
        and fullRanks[3].originalIndex == 3 and fullRanks[3].rank == 3,
        "Ares, Apollo and Aphrodite ranks changed")
    local partial = Engine.scoreOffers(snapshot({ offer(1, "AresWeaponBoon", "Heroic"),
        offer(2, "ApolloWeaponBoon"), offer(3, "UnknownAttackBoon") }), profile)
    local decision = Engine.getRankingDecision(partial, true)
    check(decision.mode == "partial" and #decision.rankEligible == 2
        and not partial[3].covered and not partial[3].scoreComplete,
        "unknown Attack offer prevented safe partial ranking")
    local ranked = Engine.rank(decision.rankEligible)
    check(ranked[1].originalIndex == 1 and ranked[1].rank == 1
        and ranked[2].originalIndex == 2 and ranked[2].rank == 2,
        "partial ranking included the unknown Attack")
    local tiedPartial = Engine.scoreOffers(snapshot({ offer(1, "AresWeaponBoon"),
        offer(2, "ApolloWeaponBoon"), offer(3, "UnknownAttackBoon") }), profile)
    check(Engine.getRankingDecision(tiedPartial, true).mode == "none",
        "tied complete branches were partially ranked")
    local hestia = Engine.scoreOffers(snapshot({ offer(1, "HestiaWeaponBoon") }), profile)[1]
    check(hestia.score == 12 and hestia.covered and hestia.scoreComplete,
        "Hestia branch ordinal priority changed its score or completeness")

    local aresToAphroditeOffer = offer(1, "AphroditeWeaponBoon", "Common", "AresWeaponBoon")
    local aphroditeToAresOffer = offer(1, "AresWeaponBoon", "Common", "AphroditeWeaponBoon")
    local aresToAresOffer = offer(1, "AresWeaponBoon", "Common", "AresWeaponBoon")
    local aresToAphroditeSnapshot = snapshot({ aresToAphroditeOffer },
        { { Name = "AresWeaponBoon", Slot = "Melee" } })
    local aphroditeToAresSnapshot = snapshot({ aphroditeToAresOffer },
        { { Name = "AphroditeWeaponBoon", Slot = "Melee" } })
    local aresToAresSnapshot = snapshot({ aresToAresOffer },
        { { Name = "AresWeaponBoon", Slot = "Melee" } })
    for _, replacementCase in ipairs({
        { aresToAphroditeSnapshot, aresToAphroditeOffer },
        { aphroditeToAresSnapshot, aphroditeToAresOffer },
        { aresToAresSnapshot, aresToAresOffer },
    }) do
        local replacement = Engine.scoreOffers(replacementCase[1], profile)[1]
        local context = Engine.getCoreSlotContext(replacementCase[1], profile, replacementCase[2])
        local delta = reason(replacement, "CORE_REPLACEMENT_DELTA")
        check(replacement.covered and replacement.scoreComplete and replacement.score == 0
            and delta ~= nil and delta.delta == 0
            and reason(replacement, "REPLACEMENT_UNRESOLVED") == nil
            and reason(replacement, "BUILD_SLOT_POLICY_DELTA") == nil
            and not context.conditionUnresolved and not context.conflictResolved,
            "complete Attack-to-Attack replacement gained an unsupported delta")
    end
    local uncertainProfile = copy(profile)
    uncertainProfile.potentialStatusTraits.UnverifiedStatusBoon = true
    local uncertainSnapshot = snapshot({ offer(1, "AresWeaponBoon") },
        { { Name = "UnverifiedStatusBoon" } })
    uncertainSnapshot.activeArcana.EffectVulnerabilityMetaUpgrade = { Rarity = "Common" }
    local uncertain = Engine.scoreOffers(uncertainSnapshot, uncertainProfile)[1]
    check(Engine.getOriginationContext(uncertainSnapshot, uncertainProfile,
        "AresWeaponBoon").offerEnablesOrigination == nil
        and uncertain.covered and not uncertain.scoreComplete
        and reason(uncertain, "ORIGINATION_UNRESOLVED") ~= nil
        and reason(uncertain, "ORIGINATION_ENABLE") == nil,
        "unverified Origination interaction became a confirmed synergy")
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
    local zeusToAresOffer = offer(1, "AresWeaponBoon", "Common", "ZeusWeaponBoon")
    local zeusToAresSnapshot = snapshot({ zeusToAresOffer },
        { { Name = "ZeusWeaponBoon", Slot = "Melee" } })
    local zeusToAres = Engine.scoreOffers(zeusToAresSnapshot, profile)[1]
    local zeusToAresContext = Engine.getCoreSlotContext(zeusToAresSnapshot, profile, zeusToAresOffer)
    check(zeusToAres.covered and zeusToAres.scoreComplete
        and reason(zeusToAres, "BUILD_SLOT_POLICY_DELTA").delta == 4
        and zeusToAresContext.conflictResolved,
        "real NON_TARGET-to-Ares transition did not resolve reserved-slot conflict")
    local aresToZeusOffer = offer(1, "ZeusWeaponBoon", "Common", "AresWeaponBoon")
    local aresToZeusSnapshot = snapshot({ aresToZeusOffer },
        { { Name = "AresWeaponBoon", Slot = "Melee" } })
    local aresToZeus = Engine.scoreOffers(aresToZeusSnapshot, profile)[1]
    local aresToZeusContext = Engine.getCoreSlotContext(aresToZeusSnapshot, profile, aresToZeusOffer)
    check(aresToZeus.covered and aresToZeus.scoreComplete
        and reason(aresToZeus, "BUILD_SLOT_POLICY_DELTA").delta == -4
        and aresToZeusContext.conflictIntroduced and not aresToZeusContext.conflictResolved,
        "real Ares-to-NON_TARGET transition lost reserved-slot conflict")
    -- Synthetic conditional profile verifies the engine's generic unresolved guard;
    -- the production Ares Attack has no such condition.
    local conditionalProfile = copy(profile)
    conditionalProfile.slots.Attack.branches[4].classification = "conditional"
    conditionalProfile.slots.Attack.branches[4].condition =
        { state = "unresolved", code = "WOUNDS_ACCESS" }
    check(Engine.validateProfile(conditionalProfile), "synthetic conditional profile invalid")
    local unresolved = Engine.scoreOffers(zeusToAresSnapshot, conditionalProfile)[1]
    local unresolvedContext = Engine.getCoreSlotContext(zeusToAresSnapshot,
        conditionalProfile, zeusToAresOffer)
    check(not unresolved.scoreComplete
        and reason(unresolved, "REPLACEMENT_UNRESOLVED") ~= nil
        and reason(unresolved, "BUILD_SLOT_POLICY_DELTA") == nil
        and unresolvedContext.conditionUnresolved and not unresolvedContext.conflictResolved,
        "generic unresolved-branch protection changed")
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
    invalid.slots.Attack.branches[4].classification = "conditional"
    invalid.slots.Attack.branches[4].condition =
        { state = "unresolved", code = "UNVERIFIED_CONDITION" }
    check(not Engine.validateProfile(invalid), "unknown condition accepted")
    invalid = copy(profile)
    invalid.slots.Attack.branches[4].classification = "conditional"
    invalid.slots.Attack.branches[4].condition =
        { state = "unresolved", code = "WOUNDS_ACCESS", predicate = "free text" }
    check(not Engine.validateProfile(invalid), "free-text condition was accepted")
end
check(morrigan.slots.Attack.branches == nil and coat.slots.Attack.branches == nil,
    "non-migrated profiles gained branches")
print("PASS: native Ares Attack, ordinal-only priorities, full/partial/none, replacements, Origination uncertainty and schema safety")
