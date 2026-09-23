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
local generatedStarter = assert(loadfile(output .. separator .. "sister_blades_melinoe_starter.lua"))()
local generatedMorrigan = assert(loadfile(output .. separator .. "sister_blades_morrigan_meta.lua"))()
local generatedCoat = assert(loadfile(output .. separator .. "black_coat_melinoe_intermediate.lua"))()
local registry = assert(loadfile(output .. separator .. "registry.lua"))()
local intermediate = assert(loadfile("data/builds/sister_blades_melinoe_intermediate.lua"))()
local starter = assert(loadfile("data/builds/sister_blades_melinoe_starter.lua"))()
local morrigan = assert(loadfile("data/builds/sister_blades_morrigan_meta.lua"))()
local coat = assert(loadfile("data/builds/black_coat_melinoe_intermediate.lua"))()
local runtimeRegistry = assert(loadfile("data/builds/registry.lua"))()
local ScoringEngine = assert(loadfile("src/ScoringEngine.lua"))()
check(equal(generatedIntermediate, intermediate), "generated Intermediate semantics differ")
check(equal(generatedStarter, starter), "generated Starter semantics differ")
check(equal(generatedCoat, coat) and ScoringEngine.validateProfile(generatedCoat), "generated Black Coat semantics differ")
check(ScoringEngine.validateProfile(generatedIntermediate) and ScoringEngine.validateProfile(generatedStarter) and ScoringEngine.validateProfile(generatedMorrigan),
    "generated profiles fail runtime schema validation")
check(registry.intermediate.selectionKey == "intermediate"
    and registry.intermediate.id == "sister_blades_melinoe_intermediate"
    and registry.intermediate.module == "data/builds/sister_blades_melinoe_intermediate.lua"
    and registry.starter.selectionKey == "starter"
    and registry.starter.id == "sister_blades_melinoe_starter"
    and registry.starter.module == "data/builds/sister_blades_melinoe_starter.lua"
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
check(sameScores(ScoringEngine.scoreOffers(snapshot, generatedStarter), ScoringEngine.scoreOffers(snapshot, starter)),
    "generated Starter scoring differs")
generatedIntermediate.weights.BUILD_CORE_PRIORITY = 999
check(generatedStarter.weights.BUILD_CORE_PRIORITY ~= 999, "generated profiles share mutable mechanics tables")
print("PASS: canonical generated profiles load, validate, and match profile semantics/scoring")
