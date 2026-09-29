local function check(value, message) assert(value, message) end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end
local function equal(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do if not equal(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

local Engine = assert(loadfile("src/ScoringEngine.lua"))()
local CoreAdvisory = assert(loadfile("src/CoreAdvisory.lua"))()
local UI = assert(loadfile("src/UI.lua"))()
local Localization = assert(loadfile("src/Localization.lua"))()
UI.setLocalization(Localization)
UI.setLanguage("en")
local profile = assert(loadfile("data/builds/argent_skull_medea_mobalytics.lua"))()
check(Engine.validateProfile(profile), "Medea profile is invalid")
local expectedGodPool = {
    { "mobalytics_skull_medea_fullbuild_god_pool_zeus_01", "Zeus", "ZeusUpgrade" },
    { "mobalytics_skull_medea_fullbuild_god_pool_hera_01", "Hera", "HeraUpgrade" },
    { "mobalytics_skull_medea_fullbuild_god_pool_ares_01", "Ares", "AresUpgrade" },
    { "mobalytics_skull_medea_fullbuild_god_pool_demeter_01", "Demeter", "DemeterUpgrade" },
}
check(#(profile.godPool or {}) == #expectedGodPool, "generated Medea profile omitted God Pool data")
for index, expected in ipairs(expectedGodPool) do
    local actual = profile.godPool[index]
    check(actual.recommendationId == expected[1] and actual.sourceGod == expected[2]
        and actual.offerSource == expected[3], "generated God Pool mapping changed at index " .. index)
end

local function snapshot(source, offers, traits, slotted)
    return {
        offerKind = "boon", offerSource = source,
        weapon = profile.weapon, aspect = profile.aspect,
        traits = traits or {}, godTraits = traits or {}, slottedTraits = slotted or {},
        offers = offers,
    }
end
local function option(index, name, rarity)
    return { originalIndex = index, ItemName = name, Rarity = rarity or "Common",
        raritySource = "upgrade_option" }
end
local function scoresUnchanged(run, expectedNotice)
    local before = Engine.scoreOffers(run, profile)
    local rankedBefore = Engine.rank(before)
    local decisionBefore = Engine.getRankingDecision(before, Engine.isProfileSupported(run, profile))
    local savedRun, savedResults, savedRanks = copy(run), copy(before), copy(rankedBefore)
    check(CoreAdvisory.shouldShow(profile, run, true) == (expectedNotice ~= false),
        "Core notice did not reflect Attack/Special/Cast ownership")
    local after = Engine.scoreOffers(run, profile)
    local rankedAfter = Engine.rank(after)
    local decisionAfter = Engine.getRankingDecision(after, Engine.isProfileSupported(run, profile))
    check(equal(run, savedRun) and equal(before, savedResults) and equal(after, savedResults)
        and equal(rankedBefore, savedRanks) and equal(rankedAfter, savedRanks)
        and decisionBefore.mode == decisionAfter.mode,
        "advice changed input, scores, reasons, ranks, ties, eligibility, coverage, or choice order")
    return before, decisionBefore
end

local checklist = CoreAdvisory.getChecklist(profile, snapshot("ZeusUpgrade", {}))
check(#checklist == 4 and CoreAdvisory.hasMissingCore(profile, snapshot("ZeusUpgrade", {})),
    "Medea must have four source-declared missing Core boons")
local byId = {}
for _, item in ipairs(checklist) do byId[item.traitId] = item end
check(byId.HeraWeaponBoon.role == "Attack" and byId.DemeterCastBoon.role == "Cast"
    and byId.ZeusSpecialBoon.role == "Special" and byId.AresManaBoon.role == "Mana",
    "Core roles were inferred from an offer instead of the profile")

-- God Pool membership remains source metadata, but cannot hide an unowned Core.
for _, expected in ipairs(expectedGodPool) do
    local offer = snapshot(expected[3], { option(1, "UnlistedOfferFromPoolGod") })
    check(CoreAdvisory.godPoolMembership(profile, offer) == true
        and CoreAdvisory.shouldShow(profile, offer, true),
        "a God Pool offer hid an unowned Core for " .. expected[2])
end
local outsidePool = snapshot("AphroditeUpgrade", { option(1, "AphroditeWeaponBoon") })
check(CoreAdvisory.godPoolMembership(profile, outsidePool) == false
    and CoreAdvisory.shouldShow(profile, outsidePool, true),
    "a god outside the God Pool hid an unowned Core")
local unknownGod = snapshot("UnverifiedOlympianUpgrade", { option(1, "UnknownBoon") })
check(CoreAdvisory.godPoolMembership(profile, unknownGod) == nil
    and CoreAdvisory.shouldShow(profile, unknownGod, true),
    "an unknown offer-source identity suppressed the notice")
check(CoreAdvisory.shouldShow(nil, outsidePool, false)
    and CoreAdvisory.shouldShow({}, unknownGod, false),
    "an unresolved profile did not keep the notice conservatively")
local withoutGodPool = copy(profile)
withoutGodPool.godPool = nil
check(CoreAdvisory.shouldShow(withoutGodPool, snapshot("ZeusUpgrade", {}), true),
    "missing God Pool metadata hid an unowned Core")
check(not CoreAdvisory.shouldShow(profile, snapshot("AphroditeUpgrade", {}, {
    { Name = "ZeusSpecialBoon" }, { Name = "HeraWeaponBoon" },
    { Name = "DemeterCastBoon" }, { Name = "AresManaBoon" },
}), true),
    "all-acquired Core still showed an advisory for a god outside the pool")

-- The metadata path is generic: a separate Mobalytics profile with one
-- verified Poseidon recommendation follows the same exact-source rule.
local genericPoolProfile = copy(profile)
genericPoolProfile.id = "generic_mobalytics_pool_fixture"
genericPoolProfile.godPool = { {
    recommendationId = "mobalytics_generic_fixture_fullbuild_god_pool_poseidon_01",
    sourceGod = "Poseidon", offerSource = "PoseidonUpgrade",
} }
local genericPoolOffer = snapshot("PoseidonUpgrade", { option(1, "UnknownPoseidonOffer") })
check(Engine.validateProfile(genericPoolProfile)
    and CoreAdvisory.shouldShow(genericPoolProfile, genericPoolOffer, true),
    "generic God Pool metadata hid an unowned Core")
local invalidPool = copy(genericPoolProfile)
invalidPool.godPool[1].offerSource = "ZeusUpgrade"
check(not Engine.validateProfile(invalidPool)
    and CoreAdvisory.shouldShow(invalidPool, genericPoolOffer, false),
    "a mismatched mapping passed validation or silently suppressed the notice")
invalidPool = copy(genericPoolProfile)
invalidPool.godPool[2] = copy(invalidPool.godPool[1])
check(not Engine.validateProfile(invalidPool), "a duplicated God Pool mapping passed validation")
invalidPool = copy(genericPoolProfile)
invalidPool.godPool[1].recommendationId = "mobalytics_generic_fixture_fullbuild_god_pool_zeus_01"
check(not Engine.validateProfile(invalidPool), "source recommendation ID/god mismatch passed validation")

-- God Pool metadata and notice computation remain outside the scorer.
local poolIndependent = copy(profile)
poolIndependent.godPool = nil
for _, owned in ipairs({ {}, {
    { Name = "ZeusSpecialBoon" }, { Name = "HeraWeaponBoon" },
    { Name = "DemeterCastBoon" }, { Name = "AresManaBoon" },
} }) do
    local run = snapshot("ZeusUpgrade", {
        option(1, "ZeusSpecialBoon"), option(2, "DoubleBoltBoon"), option(3, "AphroditeWeaponBoon"),
    }, owned)
    local withPool = Engine.rank(Engine.scoreOffers(run, profile))
    local withoutPool = Engine.rank(Engine.scoreOffers(run, poolIndependent))
    check(equal(withPool, withoutPool), "God Pool metadata or Core ownership changed the ranking")
end

-- Normal ranks, an unranked Aphrodite offer, and rarity-only unlisted choices
-- must all show the same build-level fact without changing the scorer.
local normal = snapshot("ZeusUpgrade", {
    option(1, "ZeusSpecialBoon"), option(2, "ReserveManaHitShieldBoon"),
    option(3, "AphroditeWeaponBoon"),
})
local normalScores, normalDecision = scoresUnchanged(normal)
check(normalDecision.mode == "full" and normalScores[1].score > normalScores[2].score,
    "normal Core > Non-Core > unlisted offer did not retain its ranking")
local noPreference = snapshot("AphroditeUpgrade", {
    option(1, "AphroditeWeaponBoon"), option(2, "AphroditeSprintBoon"),
    option(3, "AphroditeManaBoon"),
})
local _, noPreferenceDecision = scoresUnchanged(noPreference)
check(noPreferenceDecision.mode == "none", "unranked Aphrodite offer unexpectedly gained a rank")
local rarityOnly = snapshot("AphroditeUpgrade", {
    option(1, "AphroditeWeaponBoon", "Common"),
    option(2, "AphroditeSprintBoon", "Rare"),
    option(3, "AphroditeManaBoon", "Epic"),
})
local rarityScores = scoresUnchanged(rarityOnly)
check(rarityScores[1].score == 0 and rarityScores[2].score == 1 and rarityScores[3].score == 2,
    "rarity-only scores changed")
scoresUnchanged(snapshot("HephaestusUpgrade", {
    option(1, "HephaestusCastBoon"), option(2, "HephaestusWeaponBoon"),
    option(3, "HephaestusManaBoon"),
}))

local allOwned = {
    { Name = "HeraWeaponBoon" }, { Name = "ZeusSpecialBoon" }, { Name = "DemeterCastBoon" },
}
local allOwnedSnapshot = snapshot("HephaestusUpgrade", {
    option(1, "HephaestusCastBoon"),
}, allOwned)
check(not CoreAdvisory.hasMissingCore(profile, allOwnedSnapshot),
    "missing Mana alone kept the Attack/Special/Cast notice visible")
check(not CoreAdvisory.shouldShow(profile, allOwnedSnapshot, true),
    "missing Mana alone kept the offer-level notice visible")
for mask = 0, 7 do
    local owned = {}
    if mask % 2 == 1 then owned[#owned + 1] = { Name = "HeraWeaponBoon" } end
    if math.floor(mask / 2) % 2 == 1 then owned[#owned + 1] = { Name = "ZeusSpecialBoon" } end
    if math.floor(mask / 4) % 2 == 1 then owned[#owned + 1] = { Name = "DemeterCastBoon" } end
    local expectedNotice = mask ~= 7
    for _, source in ipairs({ "ZeusUpgrade", "DemeterUpgrade", "HephaestusUpgrade" }) do
        local offer = snapshot(source, {
            option(1, "DemeterWeaponBoon", "Rare"),
            option(2, "DemeterSprintBoon"),
            option(3, "DemeterManaBoon"),
        }, owned)
        check(CoreAdvisory.hasMissingCore(profile, offer) == expectedNotice,
            "required-role ownership mask failed: " .. mask)
        scoresUnchanged(offer, expectedNotice)
        owned[#owned + 1] = { Name = "AresManaBoon" }
        check(CoreAdvisory.shouldShow(profile, offer, true) == expectedNotice,
            "Mana changed the notice for role mask " .. mask .. " source " .. source)
        owned[#owned] = nil
    end
end
local acquiredCast = snapshot("AphroditeUpgrade", {
    option(1, "AphroditeCastBoon"),
}, { { Name = "DemeterCastBoon" } }, { Ranged = "DemeterCastBoon" })
check(byId.DemeterCastBoon.acquired == false
    and (function()
        for _, item in ipairs(CoreAdvisory.getChecklist(profile, acquiredCast)) do
            if item.traitId == "DemeterCastBoon" then return item.acquired end
        end
        return false
    end)(), "fresh inventory did not detect an acquired Cast Core")
check(CoreAdvisory.hasMissingCore(profile, acquiredCast),
    "other missing Core boons were hidden when Cast became acquired")

local withoutCore = { slots = { Attack = { core = {} }, Sprint = { core = {} } } }
check(not CoreAdvisory.hasMissingCore(withoutCore, noPreference),
    "a profile without declared Core boons showed advice")
local ambiguousSlot = { slots = { Attack = {
    core = { "FirstAttackCore", "SecondAttackCore" },
} } }
check(not CoreAdvisory.hasMissingCore(ambiguousSlot, noPreference),
    "multiple Core candidates in one slot were treated as a proven requirement")
local sprint = copy(profile)
sprint.verifiedIds.coreSprint.DemeterSprintBoon = true
sprint.sourceScoring.boons.DemeterSprintBoon = "Non-Core Boons"
check(#CoreAdvisory.getChecklist(sprint, noPreference) == 4,
    "Sprint verification or Non-Core classification created a required Core")
sprint.sourceScoring.boons.DemeterSprintBoon = "Core Boons"
sprint.corePlan.DemeterSprintBoon = { role = "Sprint", displayName = { en = "Sprint", fr = "Élan" } }
check(Engine.validateProfile(sprint) and #CoreAdvisory.getChecklist(sprint, noPreference) == 5,
    "explicitly declared Sprint Core was not included")
check(not CoreAdvisory.hasMissingCore(sprint, allOwnedSnapshot),
    "a Sprint Core unexpectedly became required by the three-role notice")

local coat = assert(loadfile("data/builds/black_coat_melinoe_intermediate.lua"))()
local coatRun = { traits = { { Name = "PoseidonWeaponBoon" }, { Name = "PoseidonSprintBoon" } },
    slottedTraits = { Melee = "PoseidonWeaponBoon", Rush = "PoseidonSprintBoon" },
    playerFocus = { focus = "special", route = "zeus", locked = true } }
check(not CoreAdvisory.hasMissingCore(Engine.effectiveProfile(coatRun, coat), coatRun),
    "Zeus route incorrectly required the Black Coat Ares Special Core")
coatRun.playerFocus.route = "ares"
check(CoreAdvisory.hasMissingCore(Engine.effectiveProfile(coatRun, coat), coatRun),
    "Ares route lost its declared Special Core")

local ids, labels, attaches, destroyed = 0, {}, {}, {}
local api = {
    CreateScreenComponent = function()
        ids = ids + 1
        return { Id = "advice-component-" .. ids }
    end,
    Attach = function(data) attaches[#attaches + 1] = data end,
    CreateTextBox = function(data) labels[#labels + 1] = data end,
    Destroy = function(data) destroyed[#destroyed + 1] = data end,
}
local screen = { Components = { PurchaseButton1 = { Id = "native-first-card" } } }
UI.renderFallback(screen, { code = "NO_RELIABLE_PREFERENCE" }, api)
UI.renderCoreAdvisory(screen, CoreAdvisory.hasMissingCore(profile, noPreference), api)
check(screen.BoonAdvisorFallback ~= nil and screen.BoonAdvisorCoreAdvisory ~= nil,
    "offer-level advice was omitted beside NO RELIABLE PREFERENCE")
local noticeCount = 0
for _, text in ipairs(labels) do
    if text.RawText == "Boon Core Build Missing" then noticeCount = noticeCount + 1 end
end
check(noticeCount == 1 and attaches[#attaches].DestinationId == "native-first-card"
    and attaches[#attaches].OffsetX == -315 and attaches[#attaches].OffsetY == -120
    and labels[#labels].Width == 250
    and labels[#labels].FontSize == 15,
    "multiple notices appeared or the single notice lost its offer-level position")
local fallbackPosition, noticePosition = attaches[1], attaches[#attaches]
local fallbackBox, noticeBox = labels[1], labels[#labels]
check(noticePosition.OffsetX + noticeBox.Width / 2
    < fallbackPosition.OffsetX - fallbackBox.Width / 2,
    "the offer notice overlaps the NO RELIABLE PREFERENCE banner")
local oldAdviceId = screen.BoonAdvisorCoreAdvisory.id
UI.renderCoreAdvisory(screen, CoreAdvisory.hasMissingCore(profile, allOwnedSnapshot), api)
check(screen.BoonAdvisorCoreAdvisory == nil and screen.Components.BoonAdvisorCoreAdvisory == nil
    and destroyed[#destroyed].Ids[1] == oldAdviceId,
    "acquiring the final Core did not remove the stale notice on refresh")
UI.renderCoreAdvisory(screen, true, api)
UI.renderCoreAdvisory(screen, true, api)
check(screen.BoonAdvisorCoreAdvisory ~= nil and destroyed[#destroyed].Ids[1] ~= nil,
    "reroll did not replace the previous notice")
UI.clearRanks(screen, api)
check(screen.BoonAdvisorCoreAdvisory == nil,
    "offer cleanup left an old Core notice visible")
local sparse = { Components = { PurchaseButton3 = { Id = "only-visible-card" } } }
UI.renderCoreAdvisory(sparse, true, api)
check(sparse.BoonAdvisorCoreAdvisory ~= nil
    and attaches[#attaches].DestinationId == "only-visible-card",
    "sparse offer did not anchor the notice to its first available card")
UI.clearRanks(sparse, api)

print("PASS: Core ownership, all gods and ranking modes, one offer notice, route projection, refresh, and unchanged scores/ranks")
