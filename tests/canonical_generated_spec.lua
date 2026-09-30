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
local registry = assert(loadfile(output .. separator .. "registry.lua"))()
local runtimeRegistry = assert(loadfile("data/builds/registry.lua"))()
local ScoringEngine = assert(loadfile("src/ScoringEngine.lua"))()
local expected = {
    argent_skull_medea_mobalytics = { weapon = "WeaponLob", aspect = "LobCloseAttackAspect" },
    moonstone_axe_melinoe_mobalytics = { weapon = "WeaponAxe", aspect = "AxeRecoveryAspect" },
}

check(equal(registry, runtimeRegistry), "generated runtime registry differs")
for key in pairs(registry) do check(expected[key] ~= nil, "retired or unexpected registry entry: " .. key) end
for key, identity in pairs(expected) do
    local descriptor = assert(registry[key], "missing active registry entry: " .. key)
    local expectedModule = "data/builds/" .. key .. ".lua"
    check(descriptor.selectionKey == key and descriptor.id == key
        and descriptor.module == expectedModule and descriptor.weapon == identity.weapon
        and descriptor.aspect == identity.aspect, "registry mapping differs for " .. key)
    local generated = assert(loadfile(output .. separator .. key .. ".lua"))()
    local checkedIn = assert(loadfile(expectedModule))()
    check(equal(generated, checkedIn), "generated semantics differ for " .. key)
    check(ScoringEngine.validateProfile(generated), "generated profile invalid: " .. key)
    check(generated.id == descriptor.id and generated.profileMode == descriptor.profileMode
        and generated.weapon == descriptor.weapon and generated.aspect == descriptor.aspect,
        "registry/generated identity differs for " .. key)
    local snapshot = { weapon = identity.weapon, aspect = identity.aspect,
        godTraits = {}, hammers = {}, activeArcana = {}, offers = {
            { originalIndex = 1, ItemName = "ZeusSpecialBoon", Rarity = "Common" },
            { originalIndex = 2, ItemName = "UnknownTestBoon", Rarity = "Common" },
        } }
    local generatedScores = ScoringEngine.scoreOffers(snapshot, generated)
    local checkedInScores = ScoringEngine.scoreOffers(snapshot, checkedIn)
    check(#generatedScores == #checkedInScores, "generated scoring count differs for " .. key)
    for index, score in ipairs(generatedScores) do
        local reference = checkedInScores[index]
        check(score.score == reference.score and score.covered == reference.covered
            and score.scoreComplete == reference.scoreComplete,
            "generated scoring differs for " .. key .. " offer " .. index)
    end
end

local medea = assert(loadfile(output .. separator .. "argent_skull_medea_mobalytics.lua"))()
local moonstone = assert(loadfile(output .. separator .. "moonstone_axe_melinoe_mobalytics.lua"))()
medea.weights.BUILD_PREFERRED = 999
check(moonstone.weights.BUILD_PREFERRED ~= 999, "generated profiles share mutable mechanics tables")
print("PASS: active canonical profiles load, validate, and match generated semantics/scoring")
