local Engine = assert(loadfile("src/ScoringEngine.lua"))()
local medea = assert(loadfile("data/builds/argent_skull_medea_mobalytics.lua"))()
local moonstone = assert(loadfile("data/builds/moonstone_axe_melinoe_mobalytics.lua"))()
local function check(value, message) assert(value, message) end
local function score(profile, names, source)
    local offers = {}
    for index, name in ipairs(names) do
        offers[index] = { originalIndex = index, ItemName = name, Rarity = "Common",
            raritySource = "upgrade_option" }
    end
    return Engine.scoreOffers({ weapon = profile.weapon, aspect = profile.aspect,
        offerKind = "boon", offerSource = source,
        godTraits = {}, hammers = {}, activeArcana = {}, offers = offers }, profile)
end

for _, profile in ipairs({ medea, moonstone }) do
    check(Engine.validateProfile(profile), "active profile failed runtime validation")
    check(Engine.isProfileSupported({ weapon = profile.weapon, aspect = profile.aspect }, profile),
        "active profile rejected its own weapon and aspect")
    check(not Engine.isProfileSupported({ weapon = profile.weapon, aspect = "UnknownAspect" }, profile),
        "active profile accepted an unknown aspect")
    local unknown = score(profile, { "UnknownTestBoon" })[1]
    check(not unknown.scoreComplete and Engine.getRankingDecision({ unknown }, true).mode == "none",
        "unknown offer became rankable for " .. profile.id)
end
local medeaScores = score(medea, { "ZeusSpecialBoon", "UnknownTestBoon" }, "ZeusUpgrade")
check(medeaScores[1].covered and medeaScores[1].scoreComplete
    and medeaScores[1].score > medeaScores[2].score,
    "Medea Core/unknown coverage changed")
local moonstoneScores = score(moonstone, { "PoseidonSprintBoon", "UnknownTestBoon" }, "PoseidonUpgrade")
check(moonstoneScores[1].covered and moonstoneScores[1].scoreComplete
    and moonstoneScores[1].score > moonstoneScores[2].score,
    "Moonstone active source scoring changed")
print("PASS: active profile schema, exact identity, source scoring and unknown-offer fallback")
