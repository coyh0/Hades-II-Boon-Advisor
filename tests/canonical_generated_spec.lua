local function check(value, message) assert(value, message) end
local function equal(left, right, seen)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right
    for key, value in pairs(left) do if not equal(value, right[key], seen) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end
local output = assert(os.getenv("BOON_CANONICAL_OUTPUT"), "missing canonical output path")
local separator = package.config:sub(1, 1)
local generatedIntermediate = assert(loadfile(output .. separator .. "sister_blades_melinoe_intermediate.lua"))()
local generatedMorrigan = assert(loadfile(output .. separator .. "sister_blades_morrigan_meta.lua"))()
local generatedCoat = assert(loadfile(output .. separator .. "black_coat_melinoe_intermediate.lua"))()
local registry = assert(loadfile(output .. separator .. "registry.lua"))()
local intermediate = assert(loadfile("data/builds/sister_blades_melinoe_intermediate.lua"))()
local morrigan = assert(loadfile("data/builds/sister_blades_morrigan_meta.lua"))()
local expectedMelinoeHammerPlan = {
    { traitId = "DaggerDashAttackTripleTrait", priority = 1, classification = "priority" },
    { traitId = "DaggerFinalHitTrait", priority = 2, classification = "alternative" },
    { traitId = "DaggerRapidAttackTrait", priority = 2, classification = "alternative" },
    { traitId = "DaggerSpecialReturnTrait", priority = 2, classification = "alternative" },
    { traitId = "DaggerAttackFinisherTrait", priority = 3, classification = "alternative" },
}
local expectedMorriganHammerPlan = {
    { traitId = "DaggerTripleBuffTrait", priority = 1, classification = "priority" },
    { traitId = "DaggerAttackFinisherTrait", priority = 2, classification = "alternative" },
}
local expectedCoatHammerPlan = {
    { traitId = "SuitDashAttackTrait", priority = 1, classification = "priority" },
    { traitId = "SuitAttackSpeedTrait", priority = 2, classification = "priority" },
    { traitId = "SuitSpecialAutoTrait", priority = 3, classification = "alternative", condition = "Special branch" },
    { traitId = "SuitAttackSizeTrait", priority = 3, classification = "alternative" },
}
local function assertPlan(profile, expected, label)
    assert(#profile.hammerPlan == #expected, label .. " Hammer plan count mismatch")
    for index, spec in ipairs(expected) do
        local actual = profile.hammerPlan[index]
        assert(actual.traitId == spec.traitId and actual.priority == spec.priority
            and actual.classification == spec.classification and actual.condition == spec.condition,
            label .. " Hammer plan mismatch at " .. index)
    end
end
local function assertMelinoeHammerPlan(profile, label)
    assert(#profile.hammerPlan == #expectedMelinoeHammerPlan, label .. " Hammer plan count mismatch")
    for index, expected in ipairs(expectedMelinoeHammerPlan) do
        local actual = profile.hammerPlan[index]
        assert(actual.traitId == expected.traitId and actual.priority == expected.priority
            and actual.classification == expected.classification and actual.condition == nil,
            label .. " Hammer plan mismatch at " .. index)
    end
    for _, entry in ipairs(profile.hammerPlan) do
        assert(entry.traitId ~= "DaggerSpecialJumpTrait", label .. " made Dancing Knives evaluable")
    end
end
assertMelinoeHammerPlan(intermediate, "Intermediate")
local coat = assert(loadfile("data/builds/black_coat_melinoe_intermediate.lua"))()
assertPlan(morrigan, expectedMorriganHammerPlan, "Morrigan")
assertPlan(coat, expectedCoatHammerPlan, "Black Coat")
assert(#coat.slots.Attack.alternatives == 2
    and coat.slots.Attack.alternatives[1] == "HestiaWeaponBoon"
    and coat.slots.Attack.alternatives[2] == "ZeusWeaponBoon",
    "Black Coat Attack alternatives differ")
local runtimeRegistry = assert(loadfile("data/builds/registry.lua"))()
local ScoringEngine = assert(loadfile("src/ScoringEngine.lua"))()
check(equal(generatedIntermediate, intermediate), "generated Intermediate semantics differ")
check(equal(generatedCoat, coat) and ScoringEngine.validateProfile(generatedCoat), "generated Black Coat semantics differ")
check(ScoringEngine.validateProfile(generatedIntermediate) and ScoringEngine.validateProfile(generatedMorrigan),
    "generated profiles fail runtime schema validation")
check(registry.intermediate.selectionKey == "intermediate"
    and registry.intermediate.id == "sister_blades_melinoe_intermediate"
    and registry.intermediate.module == "data/builds/sister_blades_melinoe_intermediate.lua"
    and registry.starter == nil
    and registry.morrigan_meta.selectionKey == "morrigan_meta"
    and registry.morrigan_meta.aspect == "DaggerTripleAspect"
    and registry.morrigan_meta.module == "data/builds/sister_blades_morrigan_meta.lua", "generated registry mapping changed")
check(registry.coat_melinoe_intermediate.selectionKey == "coat_melinoe_intermediate"
    and registry.coat_melinoe_intermediate.id == "black_coat_melinoe_intermediate"
    and registry.coat_melinoe_intermediate.profileMode == "intermediate"
    and registry.coat_melinoe_intermediate.weapon == "WeaponSuit"
    and registry.coat_melinoe_intermediate.aspect == "BaseSuitAspect"
    and registry.coat_melinoe_intermediate.module == "data/builds/black_coat_melinoe_intermediate.lua",
    "generated Black Coat registry mapping differs")
check(equal(registry, runtimeRegistry), "generated runtime registry differs")
check(equal(generatedMorrigan, morrigan), "generated Morrigan semantics differ")
do
    for key, descriptor in pairs(registry) do
        check(type(descriptor) == "table" and descriptor.selectionKey == key,
            "registry key/selectionKey mismatch for " .. tostring(key))
        check(type(descriptor.id) == "string" and descriptor.id:match("^[a-z][a-z0-9_]*$"),
            "registry has invalid canonical id for " .. tostring(key))
        local expectedModule = "data/builds/" .. descriptor.id .. ".lua"
        check(descriptor.module == expectedModule, "registry module path mismatch for " .. tostring(key))
        local generatedProfile = assert(loadfile(output .. separator .. descriptor.id .. ".lua"))()
        check(type(generatedProfile) == "table" and generatedProfile.id == descriptor.id
            and generatedProfile.weapon == descriptor.weapon and generatedProfile.aspect == descriptor.aspect
            and generatedProfile.profileMode == descriptor.profileMode,
            "registry/generated profile identity mismatch for " .. tostring(key))
    end
end
local snapshot = {
    weapon = "WeaponDagger", aspect = "DaggerBackstabAspect", godTraits = {}, hammers = {}, activeArcana = {},
    offers = {
        { originalIndex = 1, ItemName = "AresWeaponBoon" },
        { originalIndex = 2, ItemName = "AphroditeWeaponBoon" },
        { originalIndex = 3, ItemName = "AresSprintBoon" },
    },
}
local function sameScores(left, right)
    if #left ~= #right then return false end
    for i = 1, #left do
        if left[i].score ~= right[i].score or left[i].covered ~= right[i].covered
            or left[i].scoreComplete ~= right[i].scoreComplete then return false end
    end
    return true
end
check(sameScores(ScoringEngine.scoreOffers(snapshot, generatedIntermediate), ScoringEngine.scoreOffers(snapshot, intermediate)),
    "generated Intermediate scoring differs")
generatedIntermediate.weights.BUILD_CORE_PRIORITY = 999
check(generatedMorrigan.weights.BUILD_CORE_PRIORITY ~= 999, "generated profiles share mutable mechanics tables")
print("PASS: canonical generated profiles load, validate, and match profile semantics/scoring")
