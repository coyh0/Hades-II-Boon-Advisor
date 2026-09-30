local Engine = assert(loadfile("src/ScoringEngine.lua"))()
local source = assert(loadfile("data/builds/argent_skull_medea_mobalytics.lua"))()
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local profile = copy(source)
profile.id = "synthetic_attack_branches"
profile.slots.Attack = { core = {}, alternatives = {}, preferred = {}, slotPolicy = "open",
    branches = {
        { traitId = "HeraWeaponBoon", classification = "alternative", priority = 1 },
        { traitId = "AphroditeWeaponBoon", classification = "conditional", priority = 2,
            condition = { state = "unresolved", code = "WOUNDS_ACCESS" } },
    } }
assert(Engine.validateProfile(profile), "synthetic branch profile failed schema validation")
assert(Engine.getBuildAlignment(profile, "Attack", "HeraWeaponBoon") == "ALTERNATIVE")
assert(Engine.getBuildAlignment(profile, "Attack", "AphroditeWeaponBoon") == "ALTERNATIVE")
assert(Engine.getBuildAlignment(profile, "Attack", "UnknownWeaponBoon") == "NON_TARGET")
local duplicate = copy(profile)
duplicate.slots.Attack.branches[2].traitId = "HeraWeaponBoon"
assert(not Engine.validateProfile(duplicate), "duplicate Attack branch was accepted")
local invalidCondition = copy(profile)
invalidCondition.slots.Attack.branches[2].condition.code = "UNKNOWN"
assert(not Engine.validateProfile(invalidCondition), "unknown Attack branch condition was accepted")
local offer = Engine.scoreOffers({ weapon = profile.weapon, aspect = profile.aspect,
    godTraits = {}, hammers = {}, activeArcana = {}, offers = {
        { originalIndex = 1, ItemName = "AphroditeWeaponBoon", Rarity = "Common" },
    } }, profile)[1]
local unresolved = false
for _, reason in ipairs(offer.reasons) do
    if reason.code == "ATTACK_BRANCH_UNRESOLVED" then unresolved = true end
end
assert(unresolved and not offer.scoreComplete,
    "conditional Attack branch became a complete scoring recommendation")
print("PASS: synthetic Attack branch alignment, validation and unresolved scoring")
