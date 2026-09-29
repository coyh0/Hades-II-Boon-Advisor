local Scoring = assert(loadfile("src/ScoringEngine.lua"))()
local Advisory = assert(loadfile("src/CoreAdvisory.lua"))()
local Context = assert(loadfile("src/GodPoolContext.lua"))()
local Localization = assert(loadfile("src/Localization.lua"))()
local profile = assert(loadfile("data/builds/moonstone_axe_melinoe_mobalytics.lua"))()
assert(Scoring.validateProfile(profile))
assert(profile.weapon == "WeaponAxe" and profile.aspect == "AxeRecoveryAspect")
assert(Localization.buildName("en", profile.id) == "Moonstone Axe · Aspect of Melinoë")
assert(Localization.buildName("fr", profile.id) == "Hache Sélénique · Aspect de Mélinoé")

local function score(kind, source, entries, owned)
    local offers = {}
    for index, entry in ipairs(entries) do
        offers[index] = { originalIndex = index, ItemName = entry[1], Rarity = entry[2],
            raritySource = entry[2] and "upgrade_option" or nil }
    end
    local snapshot = { offerKind = kind, offerSource = source, weapon = profile.weapon,
        aspect = profile.aspect, offers = offers, godTraits = owned or {},
        slottedTraits = {}, hammers = {} }
    return Scoring.scoreOffers(snapshot, profile), snapshot
end

local coreIds = { "ApolloWeaponBoon", "HephaestusSpecialBoon", "DemeterCastBoon",
    "PoseidonSprintBoon", "HephaestusManaBoon" }
local nonCoreIds = { "DoubleStrikeChanceBoon", "CastNovaBoon",
    "EncounterStartDefenseBuffBoon", "FocusDamageShaveBoon",
    "EncounterStartOffenseBuffBoon", "RootDurationBoon" }
for _, id in ipairs(coreIds) do
    assert(profile.sourceScoring.boons[id] == "Core Boons" and profile.corePlan[id])
end
for _, id in ipairs(nonCoreIds) do
    assert(profile.sourceScoring.boons[id] == "Non-Core Boons" and not profile.corePlan[id])
end
assert(profile.corePlan.HephaestusManaBoon.role == "Mana")
assert(profile.corePlan.PoseidonSprintBoon.role == "Sprint")
local checklist = Advisory.getChecklist(profile, { godTraits = {} })
assert(#checklist == 5 and Advisory.hasMissingCore(profile, { godTraits = {} }))
local threeOwned = { godTraits = { { Name = "ApolloWeaponBoon" },
    { Name = "HephaestusSpecialBoon" }, { Name = "DemeterCastBoon" } } }
assert(not Advisory.hasMissingCore(profile, threeOwned),
    "Sprint or Mana improperly kept the three-role missing-Core notice visible")
assert(next(profile.sourceScoring.hammers) == nil and profile.hammerPlan == nil,
    "unprioritized Hammers acquired a fabricated score or order")
assert(next(profile.sourceScoring.deferred) == nil,
    "documentary Duo/Legendary entries entered active scoring")

local ordinary = score("boon", "ApolloUpgrade", {
    { "ApolloWeaponBoon", "Common" }, { "DoubleStrikeChanceBoon", "Heroic" },
    { "UnknownApolloBoon", "Heroic" },
})
local ordered = Scoring.rank(ordinary)
assert(ordered[1].score == 200 and ordered[1].rank == 1
    and ordered[2].score == 103 and ordered[2].rank == 2
    and ordered[3].score == 3 and ordered[3].rank == 3)
local tied = Scoring.rank(score("boon", "HephaestusUpgrade", {
    { "HephaestusSpecialBoon", "Rare" }, { "HephaestusManaBoon", "Rare" },
}))
assert(tied[1].rank == 1 and tied[2].rank == 1 and tied[1].tied and tied[2].tied)
local mana = score("boon", "HephaestusUpgrade", { { "HephaestusManaBoon", "Common" } })[1]
assert(mana.score == 200 and mana.sourceGroup == "Core Boons" and mana.scoreComplete)
local support = score("boon", "HephaestusUpgrade", { { "EncounterStartDefenseBuffBoon", "Common" } })[1]
assert(support.score == 100 and support.sourceGroup == "Non-Core Boons" and support.scoreComplete)

local pom = score("pom", "StackUpgrade", { { "ApolloWeaponBoon", nil } },
    { { Name = "ApolloWeaponBoon" } })[1]
assert(pom.score == 200 and pom.scoreComplete and pom.sourceGroup == "Core Boons")
local offerPairs = {
    { "InsideCastCritBoon", "NPC_Artemis_Field_01" },
    { "ChaosWeaponBlessing", "TrialUpgrade" },
    { "ChaosHealthBlessing", "TrialUpgrade" },
}
for _, pair in ipairs(offerPairs) do
    local matched = score("boon", pair[2], { { pair[1], nil } })[1]
    assert(matched.score == 200 and matched.scoreComplete and matched.sourceGroup == "Offerings")
    local mismatchSource = pair[2] == "TrialUpgrade" and "NPC_Artemis_Field_01" or "TrialUpgrade"
    local mismatch = score("boon", mismatchSource, { { pair[1], nil } })[1]
    assert(mismatch.score == 0 and not mismatch.scoreComplete)
end

local pool = {}
for _, entry in ipairs(profile.godPool) do pool[entry.offerSource] = true end
assert(pool.ApolloUpgrade and pool.DemeterUpgrade and pool.HephaestusUpgrade
    and pool.PoseidonUpgrade and not pool.AphroditeUpgrade)
local snapshot = { offerSource = "ApolloUpgrade",
    nativeGodPool = { offerIsGodLoot = true, registered = { ApolloUpgrade = true } } }
local membership = Advisory.godPoolMembership(profile, snapshot)
local context = Context.evaluate(membership, snapshot)
assert(context.recommendedByBuild == "Yes" and context.observedInRuntimePool == "Yes")
snapshot.offerSource = "AphroditeUpgrade"
snapshot.nativeGodPool.registered.AphroditeUpgrade = true
context = Context.evaluate(Advisory.godPoolMembership(profile, snapshot), snapshot)
assert(context.recommendedByBuild == "No" and context.observedInRuntimePool == "Yes")
print("PASS: Moonstone Axe Core/Non-Core, Mana/Sprint, Pom, offerings, ties, God Pool and localization")
