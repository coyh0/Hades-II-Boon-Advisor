local function check(value, message) assert(value, message) end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

local ScoringEngine = assert(loadfile("src/ScoringEngine.lua"))()
local PomAdvisor = assert(loadfile("src/PomAdvisor.lua"))()
local profile = assert(loadfile("data/builds/argent_skull_medea_mobalytics.lua"))()
local valid, validationError = ScoringEngine.validateProfile(profile)
check(valid, validationError)
check(profile.source.type == "mobalytics", "Mobalytics source identity missing")
check(profile.weights.BUILD_PREFERRED == 2 and profile.weights.BUILD_NON_CORE == nil,
    "Medea retained an obsolete group weight instead of using the approved tier policy")
check(profile.sourceScoring.boons.ZeusSpecialBoon == "Core Boons"
    and profile.sourceScoring.boons.DoubleBoltBoon == "Non-Core Boons"
    and profile.sourceScoring.boons.DeathDefianceRefillBoon == "NPC Offerings",
    "Mobalytics boon groups were not projected")
check(profile.sourceScoring.npcOfferings.DeathDefianceRefillBoon == "NPC_Athena_01"
    and profile.sourceScoring.npcOfferings.HadesDeathDefianceDamageBoon == "NPC_Hades_Field_01",
    "verified NPC source/item pairs are missing")
check(ScoringEngine.getBuildAlignment(profile, "Special", "ZeusSpecialBoon") == "PREFERRED"
    and ScoringEngine.getBuildAlignment(profile, "Special", "PoseidonSpecialBoon") == "NON_TARGET",
    "existing role display classification changed")

local function score(kind, offers, source, owned, scoringProfile)
    scoringProfile = scoringProfile or profile
    for _, offer in ipairs(offers) do
        if offer.Rarity ~= nil and offer.raritySource == nil then offer.raritySource = "upgrade_option" end
    end
    local traits = owned
    if traits == nil and kind == "pom" then
        traits = {}
        for _, offer in ipairs(offers) do traits[#traits + 1] = { Name = offer.ItemName } end
    end
    local snapshot = {
        offerKind = kind,
        offerSource = source or (kind == "pom" and "StackUpgrade"
            or kind == "hammer" and "WeaponUpgrade" or "ZeusUpgrade"),
        weapon = scoringProfile.weapon,
        aspect = scoringProfile.aspect,
        godTraits = traits or {},
        hammers = {},
        slottedTraits = {},
        offers = offers,
    }
    return { ScoringEngine.scoreOffers(snapshot, scoringProfile), snapshot }
end

-- Core, Non-Core, and unlisted ordinary boon tiers remain strictly separated
-- at every ordinary rarity, including the worst cross-tier comparison.
local rarityCases = {
    { "Common", 0 }, { "Rare", 1 }, { "Epic", 2 }, { "Heroic", 3 },
}
for _, case in ipairs(rarityCases) do
    local rarity, bonus = case[1], case[2]
    local core = score("boon", { { originalIndex = 1, ItemName = "HeraWeaponBoon", Rarity = rarity } })[1][1]
    local nonCore = score("boon", { { originalIndex = 1, ItemName = "DoubleBoltBoon", Rarity = rarity } })[1][1]
    local unlisted = score("boon", { { originalIndex = 1, ItemName = "AphroditeWeaponBoon", Rarity = rarity } })[1][1]
    check(core.score == 200 + bonus and nonCore.score == 100 + bonus
        and unlisted.score == bonus, "wrong boon tier/rarity score for " .. rarity)
    check(core.covered and core.scoreComplete and nonCore.covered and nonCore.scoreComplete
        and unlisted.covered and unlisted.scoreComplete,
        "ordinary boon tier unexpectedly incomplete for " .. rarity)
end
local tierOrder = score("boon", {
    { originalIndex = 1, ItemName = "HeraWeaponBoon", Rarity = "Common" },
    { originalIndex = 2, ItemName = "DoubleBoltBoon", Rarity = "Heroic" },
    { originalIndex = 3, ItemName = "AphroditeWeaponBoon", Rarity = "Heroic" },
})[1]
local rankedTiers = ScoringEngine.rank(tierOrder)
check(rankedTiers[1].score == 200 and rankedTiers[2].score == 103 and rankedTiers[3].score == 3
    and rankedTiers[1].rank == 1 and rankedTiers[2].rank == 2 and rankedTiers[3].rank == 3,
    "rarity allowed Non-Core or unlisted boon to reach a higher source tier")

-- Snow Queen is the verified native ReserveManaHitShieldBoon and remains
-- an ordinary Non-Core recommendation; no ownership gate suppresses it.
check(profile.sourceScoring.boons.ReserveManaHitShieldBoon == "Non-Core Boons",
    "Snow Queen native boon ID lost its Medea Non-Core mapping")
local snowQueenCommon = score("boon", {
    { originalIndex = 1, ItemName = "ReserveManaHitShieldBoon", Rarity = "Common" },
})[1][1]
check(snowQueenCommon.score == 100 and snowQueenCommon.scoreComplete and snowQueenCommon.covered
    and snowQueenCommon.sourceGroup == "Non-Core Boons"
    and #snowQueenCommon.reasons == 1 and snowQueenCommon.reasons[1].code == "BUILD_NON_CORE",
    "Snow Queen no longer receives the approved Common Non-Core tier")
local snowQueenOfferWithoutCore = score("boon", {
    { originalIndex = 1, ItemName = "DemeterSprintBoon", Rarity = "Common" },
    { originalIndex = 2, ItemName = "ReserveManaHitShieldBoon", Rarity = "Common" },
}, "DemeterUpgrade")[1]
local snowQueenRank = ScoringEngine.rank(snowQueenOfferWithoutCore)
check(snowQueenRank[1].originalIndex == 2 and snowQueenRank[1].score == 100 and snowQueenRank[1].rank == 1,
    "Non-Core Snow Queen was gated despite no higher-scoring Core option in the offer")
-- Equal source tier/rarity is an honest tie; no arbitrary score is added.
local equalCores = score("boon", {
    { originalIndex = 1, ItemName = "HeraWeaponBoon", Rarity = "Rare" },
    { originalIndex = 2, ItemName = "DemeterCastBoon", Rarity = "Rare" },
})[1]
local tiedCores = ScoringEngine.rank(equalCores)
check(tiedCores[1].score == tiedCores[2].score and tiedCores[1].rank == 1
    and tiedCores[2].rank == 1 and tiedCores[1].tied and tiedCores[2].tied,
    "equal Mobalytics recommendations were not preserved as a tie")

-- An Epic rarity that is not verified cannot change the score or be called complete.
local unverifiedRarity = score("boon", {
    { originalIndex = 1, ItemName = "AphroditeWeaponBoon", Rarity = "Epic", raritySource = "debug_guess" },
})[1][1]
check(unverifiedRarity.score == 0 and not unverifiedRarity.scoreComplete,
    "unverified rarity altered or completed a source score")
local unknownRarity = score("boon", {
    { originalIndex = 1, ItemName = "HeraWeaponBoon", Rarity = "Mythic" },
})[1][1]
check(unknownRarity.score == 200 and not unknownRarity.scoreComplete,
    "unknown rarity falsely completed the Core tier")
local missingBoonRarity = score("boon", {
    { originalIndex = 1, ItemName = "AphroditeWeaponBoon" },
})[1][1]
check(missingBoonRarity.score == 0 and not missingBoonRarity.scoreComplete,
    "ordinary boon without the required rarity bonus was treated as complete")
local unknownBoonSource = score("boon", {
    { originalIndex = 1, ItemName = "HeraWeaponBoon", Rarity = "Common" },
}, "UnverifiedUpgradeSource")[1][1]
check(unknownBoonSource.score == 0 and not unknownBoonSource.scoreComplete,
    "unknown boon source identity was scored as a verified offer")

-- Hammer base scores and rarity are independent from boon rarity tiers.
local hammers = score("hammer", {
    { originalIndex = 1, ItemName = "LobPulseAmmoTrait", Rarity = "Heroic" },
    { originalIndex = 2, ItemName = "UnknownLobHammerTrait", Rarity = "Heroic" },
    { originalIndex = 3, ItemName = "LobSturdySpecialTrait" },
})[1]
check(hammers[1].score == 203 and hammers[1].scoreComplete
    and hammers[2].score == 3 and hammers[2].scoreComplete
    and hammers[3].score == 200 and hammers[3].scoreComplete,
    "Hammer list/rarity or missing-rarity policy changed")
local unverifiedHammer = score("hammer", {
    { originalIndex = 1, ItemName = "LobPulseAmmoTrait", Rarity = "Epic", raritySource = "guessed" },
})[1][1]
check(unverifiedHammer.score == 200 and not unverifiedHammer.scoreComplete,
    "unverified Hammer rarity was applied or treated as complete")

-- Legendary list entries receive the fixed maximum; Duo values stay visible but incomplete.
local legendaryProfile = copy(profile)
legendaryProfile.sourceScoring.deferred.TestLegendary = "Legendary / Duo Boons"
local listedLegendary = ScoringEngine.scoreOffers({ offerKind = "boon", offerSource = "ZeusUpgrade",
    weapon = profile.weapon, aspect = profile.aspect, offers = {
        { originalIndex = 1, ItemName = "TestLegendary", Rarity = "Legendary", raritySource = "button" },
    } }, legendaryProfile)[1]
local unlistedLegendary = score("boon", {
    { originalIndex = 1, ItemName = "UnlistedLegendary", Rarity = "Legendary" },
})[1][1]
check(listedLegendary.score == 203 and listedLegendary.scoreComplete
    and #listedLegendary.reasons == 1 and listedLegendary.reasons[1].code == "BUILD_PREFERRED"
    and unlistedLegendary.score == 0 and unlistedLegendary.scoreComplete,
    "Legendary list/max-score handling changed")
for _, itemName in ipairs({ "KeepsakeLevelBoon", "UnlistedDuo" }) do
    local duo = score("boon", {
        { originalIndex = 1, ItemName = itemName, Rarity = "Duo" },
    })[1][1]
    local expected = itemName == "KeepsakeLevelBoon" and 200 or 0
    check(duo.score == expected and not duo.scoreComplete,
        "Duo eligibility was treated as resolved for " .. itemName)
end
local deferredWithoutCategory = score("boon", {
    { originalIndex = 1, ItemName = "KeepsakeLevelBoon" },
})[1][1]
check(not deferredWithoutCategory.scoreComplete,
    "Legendary/Duo recommendation without a resolved offer category was complete")
local duoDecision = ScoringEngine.getRankingDecision(score("boon", {
    { originalIndex = 1, ItemName = "HeraWeaponBoon", Rarity = "Common" },
    { originalIndex = 2, ItemName = "KeepsakeLevelBoon", Rarity = "Duo" },
})[1], true)
check(duoDecision.mode == "none",
    "an offer with unresolved Duo eligibility entered a complete ranking")
local partialDuoDecision = ScoringEngine.getRankingDecision(score("boon", {
    { originalIndex = 1, ItemName = "HeraWeaponBoon", Rarity = "Common" },
    { originalIndex = 2, ItemName = "DoubleBoltBoon", Rarity = "Common" },
    { originalIndex = 3, ItemName = "KeepsakeLevelBoon", Rarity = "Duo" },
})[1], true)
check(partialDuoDecision.mode == "partial" and #partialDuoDecision.rankEligible == 2,
    "unresolved Duo offer was presented as full coverage or entered the partial subset")
local unverifiedLegendary = score("boon", {
    { originalIndex = 1, ItemName = "UnlistedLegendary", Rarity = "Legendary", raritySource = "guess" },
})[1][1]
check(not unverifiedLegendary.scoreComplete and unverifiedLegendary.score == 0,
    "unverified Legendary identity was accepted")

-- Poms use a single source tier and require visible ownership.
local corePom = score("pom", {
    { originalIndex = 1, ItemName = "ZeusSpecialBoon", Rarity = "Heroic" },
})[1][1]
check(corePom.score == 200 and corePom.scoreComplete and corePom.sourceGroup == "Core Boons"
    and #corePom.reasons == 1 and corePom.reasons[1].code == "BUILD_CORE_PRIORITY",
    "Core Pom was double-counted or received rarity")
local nonCorePom = score("pom", {
    { originalIndex = 1, ItemName = "DoubleBoltBoon", Rarity = "Epic" },
})[1][1]
check(nonCorePom.score == 102 and nonCorePom.scoreComplete and nonCorePom.sourceGroup == "Non-Core Boons",
    "Non-Core Pom did not use its known boon tier and rarity")
local missingNonCorePomRarity = score("pom", {
    { originalIndex = 1, ItemName = "DoubleBoltBoon" },
})[1][1]
check(missingNonCorePomRarity.score == 100 and not missingNonCorePomRarity.scoreComplete,
    "Non-Core Pom without rarity was treated as complete")
local pomsOnlyProfile = copy(profile)
pomsOnlyProfile.sourceScoring.poms.TestPom = "Poms of Power"
local listedPomOnly = ScoringEngine.scoreOffers({ offerKind = "pom", offerSource = "StackUpgrade",
    weapon = profile.weapon, aspect = profile.aspect, godTraits = { { Name = "TestPom" } },
    offers = { { originalIndex = 1, ItemName = "TestPom", Rarity = "Rare", raritySource = "button" } },
}, pomsOnlyProfile)[1]
check(listedPomOnly.score == 0 and not listedPomOnly.scoreComplete
    and listedPomOnly.sourceGroup == "Poms of Power",
    "Pom-only recommendation without a known boon tier was assigned an inferred score")
local missingOwnership = score("pom", {
    { originalIndex = 1, ItemName = "ZeusSpecialBoon", Rarity = "Common" },
}, "StackUpgrade", {})[1][1]
check(not missingOwnership.scoreComplete and missingOwnership.score == 0,
    "Pom without verifiable ownership was treated as evaluated")
local unlistedPom = score("pom", {
    { originalIndex = 1, ItemName = "UnlistedOwnedPom", Rarity = "Heroic" },
})[1][1]
check(unlistedPom.score == 0 and not unlistedPom.scoreComplete,
    "Pom without a known source tier was treated as evaluated")

-- NPC rewards are only preferred for the verified source/item pair.
local npc = score("boon", { { originalIndex = 1, ItemName = "DeathDefianceRefillBoon", Rarity = "Rare" } },
    "NPC_Athena_01")[1][1]
check(npc.score == 201 and npc.scoreComplete and npc.sourceGroup == "NPC Offerings",
    "verified NPC offering did not get the listed base and rarity")
local npcWithoutRarity = score("boon", {
    { originalIndex = 1, ItemName = "DeathDefianceRefillBoon" },
}, "NPC_Athena_01")[1][1]
check(npcWithoutRarity.score == 200 and npcWithoutRarity.scoreComplete,
    "verified NPC offering required an unapproved rarity bonus")
local mismatchedNpc = score("boon", {
    { originalIndex = 1, ItemName = "DeathDefianceRefillBoon", Rarity = "Heroic" },
}, "NPC_Hades_Field_01")[1][1]
check(mismatchedNpc.score == 0 and not mismatchedNpc.scoreComplete,
    "NPC reward with mismatched source/item pair was preferred")
local unlistedNpc = score("boon", {
    { originalIndex = 1, ItemName = "UnknownNpcBoon", Rarity = "Epic" },
}, "NPC_Athena_01")[1][1]
check(unlistedNpc.score == 2 and unlistedNpc.scoreComplete,
    "unlisted offer at a verified NPC source did not remain base zero")

-- Artemis uses the same generic exact source/item contract as other field NPCs.
local artemisProfile = copy(profile)
artemisProfile.sourceScoring.boons.InsideCastCritBoon = "NPC Offerings"
artemisProfile.sourceScoring.npcOfferings.InsideCastCritBoon = "NPC_Artemis_Field_01"
check(ScoringEngine.validateProfile(artemisProfile), "verified Artemis source/item mapping failed profile validation")
local artemisOffer = score("boon", {
    { originalIndex = 1, ItemName = "InsideCastCritBoon", Rarity = "Rare" },
}, "NPC_Artemis_Field_01", nil, artemisProfile)[1][1]
check(artemisOffer.score == 201 and artemisOffer.scoreComplete and artemisOffer.sourceGroup == "NPC Offerings",
    "verified Artemis source/item pair did not receive its listed score")
local mismatchedArtemisOffer = score("boon", {
    { originalIndex = 1, ItemName = "InsideCastCritBoon", Rarity = "Rare" },
}, "NPC_Athena_01", nil, artemisProfile)[1][1]
check(mismatchedArtemisOffer.score == 0 and not mismatchedArtemisOffer.scoreComplete,
    "Artemis offering at a mismatched NPC source was scored as listed")
local mismatchedArtemisProfile = copy(artemisProfile)
mismatchedArtemisProfile.sourceScoring.npcOfferings.InsideCastCritBoon = "NPC_Athena_01"
local wrongPairAtArtemis = score("boon", {
    { originalIndex = 1, ItemName = "InsideCastCritBoon", Rarity = "Rare" },
}, "NPC_Artemis_Field_01", nil, mismatchedArtemisProfile)[1][1]
check(wrongPairAtArtemis.score == 0 and not wrongPairAtArtemis.scoreComplete,
    "mismatched configured NPC source/item pair was scored as listed")

-- Generic offerings bind each boon to an exact attested native reward source.
local offeringProfile = copy(profile)
offeringProfile.sourceScoring.offerSources = {
    InsideCastCritBoon = "NPC_Artemis_Field_01",
    ChaosWeaponBlessing = "TrialUpgrade",
    ChaosHealthBlessing = "TrialUpgrade",
}
offeringProfile.sourceScoring.boons.InsideCastCritBoon = "Offerings"
offeringProfile.sourceScoring.boons.ChaosWeaponBlessing = "Offerings"
offeringProfile.sourceScoring.boons.ChaosHealthBlessing = "Offerings"
check(ScoringEngine.validateProfile(offeringProfile), "verified generic offering source/item mappings failed profile validation")
local genericArtemis = score("boon", {
    { originalIndex = 1, ItemName = "InsideCastCritBoon" },
}, "NPC_Artemis_Field_01", nil, offeringProfile)[1][1]
check(genericArtemis.score == 200 and genericArtemis.scoreComplete and genericArtemis.sourceGroup == "Offerings",
    "generic Artemis offering did not preserve its exact source mapping")
local strike = score("boon", {
    { originalIndex = 1, ItemName = "ChaosWeaponBlessing" },
}, "TrialUpgrade", nil, offeringProfile)[1][1]
check(strike.score == 200 and strike.scoreComplete and strike.sourceGroup == "Offerings",
    "verified TrialUpgrade Strike pair did not receive its listed offering score")
local soul = score("boon", {
    { originalIndex = 1, ItemName = "ChaosHealthBlessing" },
}, "TrialUpgrade", nil, offeringProfile)[1][1]
check(soul.score == 200 and soul.scoreComplete and soul.sourceGroup == "Offerings",
    "verified TrialUpgrade Soul pair did not receive its listed offering score")
local mismatchedTrialSource = score("boon", {
    { originalIndex = 1, ItemName = "ChaosWeaponBlessing" },
}, "NPC_Artemis_Field_01", nil, offeringProfile)[1][1]
check(mismatchedTrialSource.score == 0 and not mismatchedTrialSource.scoreComplete,
    "TrialUpgrade boon was preferred at a mismatched source")
local unknownTrialSource = score("boon", {
    { originalIndex = 1, ItemName = "ChaosWeaponBlessing" },
}, "ChaosUpgrade", nil, offeringProfile)[1][1]
check(unknownTrialSource.score == 0 and not unknownTrialSource.scoreComplete,
    "unattested offering source was treated as supported")
local misconfiguredOffering = copy(offeringProfile)
misconfiguredOffering.sourceScoring.offerSources.ChaosWeaponBlessing = "NPC_Artemis_Field_01"
local wrongConfiguredTrialPair = score("boon", {
    { originalIndex = 1, ItemName = "ChaosWeaponBlessing" },
}, "TrialUpgrade", nil, misconfiguredOffering)[1][1]
check(wrongConfiguredTrialPair.score == 0 and not wrongConfiguredTrialPair.scoreComplete,
    "mismatched configured source/item pair was scored as listed")
local missingOfferingPair = copy(offeringProfile)
missingOfferingPair.sourceScoring.offerSources.ChaosHealthBlessing = nil
check(not ScoringEngine.validateProfile(missingOfferingPair), "generic offering without a source mapping passed validation")
local unsupportedOfferingSource = copy(offeringProfile)
unsupportedOfferingSource.sourceScoring.offerSources.ChaosHealthBlessing = "ChaosUpgrade"
check(not ScoringEngine.validateProfile(unsupportedOfferingSource), "unattested generic offering source passed validation")

-- Replacement compares source base values and adds a rarity difference once.
local replacedCore = score("boon", { { originalIndex = 1, ItemName = "PoseidonSpecialBoon",
    TraitToReplace = "ZeusSpecialBoon", Rarity = "Common", OldRarity = "Common" } })[1][1]
check(replacedCore.score == -200 and replacedCore.scoreComplete
    and #replacedCore.reasons == 1 and replacedCore.reasons[1].code == "SOURCE_REPLACEMENT_DELTA",
    "unlisted replacement did not subtract the replaced Core tier exactly once")
local replacedWithNonCore = score("boon", { { originalIndex = 1, ItemName = "DoubleBoltBoon",
    TraitToReplace = "ZeusSpecialBoon", Rarity = "Heroic", OldRarity = "Rare" } })[1][1]
check(replacedWithNonCore.score == -98 and replacedWithNonCore.scoreComplete,
    "Core-to-Non-Core replacement did not include one rarity difference")
local missingOldRarity = score("boon", { { originalIndex = 1, ItemName = "DoubleBoltBoon",
    TraitToReplace = "ZeusSpecialBoon", Rarity = "Heroic" } })[1][1]
check(not missingOldRarity.scoreComplete and missingOldRarity.score == -100,
    "replacement with unknown old rarity was falsely complete")

-- The explicitly preferred Heaven Flourish Pom is one Core score, not a repeated +2.
local stackUpgrade = {
    offerKind = "pom", offerSource = "StackUpgrade", weapon = profile.weapon,
    aspect = profile.aspect, godTraits = { { Name = "ZeusSpecialBoon", Slot = "Secondary" } },
    slottedTraits = { Special = "ZeusSpecialBoon" },
    offers = { { originalIndex = 1, ItemName = "ZeusSpecialBoon", Rarity = "Common",
        raritySource = "upgrade_option", StackNum = 2 } },
}
check(not PomAdvisor.usesPomScoring(stackUpgrade, profile), "Medea StackUpgrade left source-based scoring")
local stackResult = ScoringEngine.scoreOffers(stackUpgrade, profile)[1]
check(stackResult.score == 200 and stackResult.scoreComplete and stackResult.traitToReplace == nil,
    "owned StackUpgrade did not receive the one-time Core Pom score")
check(PomAdvisor.usesPomScoring({ offerKind = "pom", offerSource = "StackUpgrade" },
    { id = "black_coat_melinoe_intermediate" }), "Pom behavior changed for another profile")

-- Unknown NPC source mappings and missing required pair metadata fail validation.
local invalidNpcProfile = copy(profile)
invalidNpcProfile.sourceScoring.npcOfferings.DeathDefianceRefillBoon = "NPC_Unknown"
check(not ScoringEngine.validateProfile(invalidNpcProfile), "invalid NPC source mapping passed validation")
invalidNpcProfile = copy(profile)
invalidNpcProfile.sourceScoring.npcOfferings.HadesDeathDefianceDamageBoon = nil
check(not ScoringEngine.validateProfile(invalidNpcProfile), "missing NPC source mapping passed validation")
local nonMobalyticsProfile = copy(profile)
nonMobalyticsProfile.source.type = "other-guide"
check(not ScoringEngine.validateProfile(nonMobalyticsProfile),
    "Mobalytics source scoring leaked to another guide profile")

-- Ordinary offer evaluation never mutates ownership by adding another copy.
local ordinary = {
    offerKind = "boon", offerSource = "ZeusUpgrade", weapon = profile.weapon,
    aspect = profile.aspect, godTraits = { { Name = "ZeusSpecialBoon", Slot = "Secondary" } },
    slottedTraits = { Special = "ZeusSpecialBoon" },
    offers = { { originalIndex = 1, ItemName = "ZeusSpecialBoon", Rarity = "Common",
        raritySource = "upgrade_option" } },
}
local originalOwned = ordinary.godTraits[1]
ScoringEngine.scoreOffers(ordinary, profile)
check(#ordinary.godTraits == 1 and ordinary.godTraits[1] == originalOwned,
    "ordinary scoring added a second owned copy of the boon")

print("PASS: Medea Mobalytics tiers, rarity, NPC identity, Hammers, Legendaries/Duos, Poms, replacements, and ties")
