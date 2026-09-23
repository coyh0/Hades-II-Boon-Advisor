local function check(value, message) assert(value, message) end
local ScoringEngine = assert(loadfile("src/ScoringEngine.lua"))()
local OfferSnapshot = assert(loadfile("src/OfferSnapshot.lua"))()
local productionProfile = assert(loadfile("data/builds/sister_blades_melinoe_intermediate.lua"))()
local starterProfile = assert(loadfile("data/builds/sister_blades_melinoe_starter.lua"))()
local morriganProfile = assert(loadfile("data/builds/sister_blades_morrigan_meta.lua"))()

do
    local poseidonEx = {
        weapon = "WeaponDagger", aspect = "DaggerTripleAspect", godTraits = {}, hammers = {},
        activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" } },
        offers = { { originalIndex = 1, ItemName = "PoseidonExCastBoon", Rarity = "Common" } },
    }
    local function assertPoseidonEx(profile, label)
        local result = ScoringEngine.scoreOffers(poseidonEx, profile)[1]
        local context = ScoringEngine.getOriginationContext(poseidonEx, profile, "PoseidonExCastBoon")
        local forbidden = {
            BUILD_STATUS_SYNERGY = true, BUILD_PREFERRED = true, BUILD_CORE_PRIORITY = true,
            ASPECT_COMPATIBLE = true, ASPECT_SETUP_SYNERGY = true, ASPECT_DIRECT_SYNERGY = true,
            EXISTING_HAMMER_SYNERGY = true, BLOOD_DROP_ENGINE_SYNERGY = true, WOMBO = true,
            BLOOD_TRIAD = true, ORIGINATION_ENABLE = true,
        }
        for _, reason in ipairs(result.reasons) do
            check(not forbidden[reason.code], label .. " produced an unrelated reason")
        end
        check(context.status.statusKnowledge == "known_non_status"
            and context.status.offeredStatusFamily == nil
            and context.offerEnablesOrigination == false
            and result.score == 0 and not result.covered and not result.scoreComplete
            and #result.reasons == 0,
            label .. " status-only representation changed")
    end
    check(morriganProfile.knownNonStatusTraits.PoseidonExCastBoon
        and productionProfile.knownNonStatusTraits.PoseidonExCastBoon
        and starterProfile.knownNonStatusTraits.PoseidonExCastBoon,
        "Poseidon Ex Cast known-non-status data missing")
    local function countSet(set)
        local count = 0
        for _ in pairs(set) do count = count + 1 end
        return count
    end
    check(countSet(morriganProfile.knownNonStatusTraits) == 38
        and countSet(productionProfile.knownNonStatusTraits) == 38
        and countSet(starterProfile.knownNonStatusTraits) == 38,
        "known-non-status counts changed")
    assertPoseidonEx(morriganProfile, "Morrigan Poseidon Ex Cast")
    assertPoseidonEx(productionProfile, "Melinoe Poseidon Ex Cast")
    assertPoseidonEx(starterProfile, "Starter Poseidon Ex Cast")
end

do
    local expected = { Common = 2, Rare = 3, Epic = 4, Heroic = 5 }
    for rarity, score in pairs(expected) do
        local result = ScoringEngine.scoreOffers({
            weapon = "WeaponDagger", aspect = "DaggerBackstabAspect", godTraits = {}, hammers = {},
            activeArcana = {}, offers = {{ originalIndex = 1, ItemName = "HealthRewardBonusBoon", Rarity = rarity }},
        }, productionProfile)[1]
        check(result.score == score and result.covered and result.scoreComplete,
            "HealthRewardBonusBoon " .. rarity .. " semantic score changed")
        check(#result.reasons == (rarity == "Common" and 1 or 2),
            "HealthRewardBonusBoon reason count changed for " .. rarity)
        check(result.reasons[1].code == "MAX_RESOURCE_SUPPORT" and result.reasons[1].delta == 2,
            "HealthRewardBonusBoon semantic reason missing for " .. rarity)
        local total = 0
        for _, reason in ipairs(result.reasons) do total = total + reason.delta end
        check(total == result.score, "HealthRewardBonusBoon score is not reason sum")
    end
    check(productionProfile.traitSemantics.HealthRewardBonusBoon.kind == "max_resource_support"
        and starterProfile.traitSemantics.HealthRewardBonusBoon.kind == "max_resource_support"
        and morriganProfile.traitSemantics.HealthRewardBonusBoon.kind == "max_resource_support",
        "shared HealthRewardBonusBoon semantic missing")
    local unknown = ScoringEngine.scoreOffers({
        weapon = "WeaponDagger", aspect = "DaggerBackstabAspect", godTraits = {}, hammers = {},
        activeArcana = {}, offers = {{ originalIndex = 1, ItemName = "FocusRawDamageBoon", Rarity = "Common" }},
    }, productionProfile)[1]
    check(not unknown.covered and not unknown.scoreComplete and unknown.score == 0,
        "FocusRawDamageBoon was unexpectedly covered")
end

do
    local offers = {
        { "ZeusSpecialBoon", 10, "BUILD_PREFERRED" },
        { "AresSpecialBoon", 10, "BUILD_PREFERRED" },
        { "HephaestusSpecialBoon", 10, "BUILD_PREFERRED" },
        { "PoseidonSpecialBoon", 8, nil },
        { "HeraSpecialBoon", 8, nil },
        { "ApolloSpecialBoon", 6, "BUILD_DISCOURAGED" },
        { "AphroditeSpecialBoon", 6, "BUILD_DISCOURAGED" },
    }
    local snapshot = { weapon = "WeaponDagger", aspect = "DaggerTripleAspect", godTraits = {}, hammers = {},
        activeArcana = {}, offers = {} }
    for index, entry in ipairs(offers) do
        snapshot.offers[1] = { originalIndex = 1, ItemName = entry[1], Rarity = "Common" }
        local result = ScoringEngine.scoreOffers(snapshot, morriganProfile)[1]
        check(result.score == entry[2] and result.covered and result.scoreComplete,
            "Morrigan open Special score changed for " .. entry[1])
        check(result.reasons[1].code == "FILL_EMPTY_PRIMARY_CORE",
            "Morrigan open Special fill reason missing for " .. entry[1])
        if entry[3] == nil then
            check(#result.reasons == 1, "ordinary Morrigan Special gained an extra reason")
        else
            check(result.reasons[2].code == entry[3], "Morrigan Special alignment reason changed")
        end
    end
    local rarityOffers = { "Common", "Rare", "Epic", "Heroic" }
    local expectedScores = { 8, 9, 10, 11 }
    for index, rarity in ipairs(rarityOffers) do
        snapshot.offers[1] = { originalIndex = 1, ItemName = "PoseidonSpecialBoon", Rarity = rarity }
        local result = ScoringEngine.scoreOffers(snapshot, morriganProfile)[1]
        check(result.score == expectedScores[index] and result.scoreComplete,
            "Poseidon open Special rarity score changed")
    end
    local sprintSnapshot = { weapon = "WeaponDagger", aspect = "DaggerTripleAspect", godTraits = {}, hammers = {},
        activeArcana = {}, offers = {{ originalIndex = 1, ItemName = "AresSprintBoon", Rarity = "Common" }} }
    local ordinarySprint = ScoringEngine.scoreOffers(sprintSnapshot, morriganProfile)[1]
    check(ordinarySprint.score == 0 and ordinarySprint.covered and ordinarySprint.scoreComplete,
        "Morrigan preferred-policy ordinary Sprint was treated as open")
    sprintSnapshot.offers[1].ItemName = "ApolloSprintBoon"
    local preferredSprint = ScoringEngine.scoreOffers(sprintSnapshot, morriganProfile)[1]
    check(preferredSprint.score == 6 and preferredSprint.reasons[1].code == "FILL_EMPTY_UTILITY_CORE"
        and preferredSprint.reasons[2].code == "BUILD_PREFERRED",
        "Morrigan preferred Sprint score changed")
end

do
    local expected = { Common = 2, Rare = 3, Epic = 4, Heroic = 5 }
    for rarity, score in pairs(expected) do
        local result = ScoringEngine.scoreOffers({
            weapon = "WeaponDagger", aspect = "DaggerBackstabAspect", godTraits = {}, hammers = {},
            activeArcana = {}, offers = {{ originalIndex = 1, ItemName = "HighHealthOffenseBoon", Rarity = rarity }},
        }, productionProfile)[1]
        check(result.score == score and result.covered and result.scoreComplete,
            "HighHealthOffenseBoon " .. rarity .. " score changed")
        check(result.reasons[1].code == "HIGH_HEALTH_OFFENSE" and result.reasons[1].delta == 2,
            "HighHealthOffenseBoon reason missing")
    end
    local function healthResult(current, maximum, profile)
        return ScoringEngine.scoreOffers({
            weapon = "WeaponDagger", aspect = profile.aspect, godTraits = {}, hammers = {},
            combatContext = { health = { current = current, max = maximum } }, activeArcana = {},
            offers = {{ originalIndex = 1, ItemName = "HighHealthOffenseBoon", Rarity = "Common" }},
        }, profile)[1]
    end
    check(healthResult(79, 100, productionProfile).condition.currentlyActive == false,
        "79% high-health diagnostic changed")
    check(healthResult(79, 100, productionProfile).score == 2, "79% changed semantic score")
    check(healthResult(80, 100, productionProfile).condition.currentlyActive == true,
        "80% high-health boundary is not inclusive")
    check(healthResult(81, 100, productionProfile).condition.currentlyActive == true,
        "81% high-health diagnostic changed")
    local missing = healthResult(nil, nil, productionProfile)
    check(missing.condition.currentlyActive == nil and missing.score == 2,
        "missing health did not remain diagnostic-only")
    local origination = healthResult(80, 100, productionProfile)
    origination = ScoringEngine.scoreOffers({
        weapon = "WeaponDagger", aspect = "DaggerBackstabAspect", godTraits = {}, hammers = {},
        combatContext = { health = { current = 80, max = 100 } },
        activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" } },
        offers = {{ originalIndex = 1, ItemName = "HighHealthOffenseBoon", Rarity = "Common" }},
    }, productionProfile)[1]
    check(origination.scoreComplete and origination.covered,
        "HighHealth Origination completion changed")
    for _, reason in ipairs(origination.reasons) do
        check(reason.code ~= "ORIGINATION_UNRESOLVED", "HighHealth Origination remained unresolved")
    end
    local morrigan = healthResult(80, 100, morriganProfile)
    check(morrigan.score == 2 and morrigan.covered and morrigan.scoreComplete,
        "Morrigan HighHealth semantic changed")
    check(morrigan.reasons[1].code == "HIGH_HEALTH_OFFENSE",
        "Morrigan received an unintended aspect/Wombo reason")
    check(morriganProfile.traitSemantics.HighHealthOffenseBoon.excludesIgnoreAllModifiers == true,
        "Wombo exclusion metadata missing")
end

check(ScoringEngine.validateProfile(productionProfile), "schemaVersion=1 production profile rejected")
check(ScoringEngine.validateProfile(starterProfile), "schemaVersion=1 Starter profile rejected")
check(starterProfile.id == "sister_blades_melinoe_starter" and starterProfile.profileMode == "starter"
    and starterProfile.source.type == "sheet" and starterProfile.source.profile == "Starter",
    "Starter identity/source changed")

local effectiveSnapshot = OfferSnapshot.capture({ UpgradeButtons = {
    [1] = { Data = { Name = "AresWeaponBoon", Rarity = "Common" } },
    [2] = { Data = { Name = "AresCastBoon", Rarity = "Common" } },
    [3] = { Data = { Name = "AresManaBoon", Rarity = "Heroic" } },
} }, { UpgradeOptions = {
    [1] = { ItemName = "AresWeaponBoon", Rarity = "Rare" },
    [2] = { ItemName = "AresCastBoon", Rarity = "Rare" },
    [3] = { ItemName = "AresManaBoon", Rarity = "Heroic" },
} })
check(effectiveSnapshot[1].Rarity == "Common" and effectiveSnapshot[2].Rarity == "Common"
    and effectiveSnapshot[3].Rarity == "Heroic"
    and effectiveSnapshot[1].rawRarity == "Rare"
    and effectiveSnapshot[1].raritySource == "button",
    "effective button rarity source was not selected")
local fallbackSnapshot = OfferSnapshot.capture({}, { UpgradeOptions = {
    [1] = { ItemName = "AresWeaponBoon", Rarity = "Rare" },
} })
check(fallbackSnapshot[1].Rarity == "Rare" and fallbackSnapshot[1].raritySource == "upgrade_option",
    "option rarity fallback was not preserved")
local mismatchSnapshot = OfferSnapshot.capture({ UpgradeButtons = {
    [1] = { Data = { Name = "OtherBoon", Rarity = "Heroic" } },
} }, { UpgradeOptions = {
    [1] = { ItemName = "AresWeaponBoon", Rarity = "Rare" },
} })
check(mismatchSnapshot[1].Rarity == "Rare" and mismatchSnapshot[1].raritySource == "upgrade_option",
    "mismatched button rarity contaminated the offer")

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}; seen[value] = copy
    for key, child in pairs(value) do copy[deepCopy(key, seen)] = deepCopy(child, seen) end
    return copy
end

local function deepEqual(left, right, seen)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right
    for key, value in pairs(left) do if not deepEqual(value, right[key], seen) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

local unsupportedSchema = deepCopy(productionProfile); unsupportedSchema.schemaVersion = 2
check(not ScoringEngine.validateProfile(unsupportedSchema)
    and not ScoringEngine.isProfileSupported({ weapon = "WeaponDagger", aspect = "DaggerBackstabAspect" }, unsupportedSchema),
    "unsupported schemaVersion was accepted")
local missingSchema = deepCopy(productionProfile); missingSchema.schemaVersion = nil
check(not ScoringEngine.validateProfile(missingSchema), "missing schemaVersion was accepted")
local invalidPolicy = deepCopy(productionProfile); invalidPolicy.slots.Attack.slotPolicy = "core"
check(not ScoringEngine.validateProfile(invalidPolicy), "invalid slotPolicy was accepted")
local invalidRole = deepCopy(productionProfile); invalidRole.slots.Invalid = { core = {}, alternatives = {}, preferred = {}, slotPolicy = "open" }
check(not ScoringEngine.validateProfile(invalidRole), "invalid slot role was accepted")
local duplicateRole = deepCopy(productionProfile); duplicateRole.slots.Attack.alternatives = { "AresWeaponBoon" }
check(not ScoringEngine.validateProfile(duplicateRole), "contradictory role definition was accepted")

local supported = { weapon = "WeaponDagger", aspect = "DaggerBackstabAspect" }
check(ScoringEngine.isProfileSupported(supported, productionProfile), "exact profile rejected")
check(not ScoringEngine.isProfileSupported({ weapon = "WeaponStaffSwing", aspect = "DaggerBackstabAspect" }, productionProfile), "wrong weapon supported")
check(not ScoringEngine.isProfileSupported({ weapon = "WeaponDagger" }, productionProfile), "nil aspect supported")
check(not ScoringEngine.isProfileSupported({ weapon = "WeaponDagger", aspect = "DummyWeaponDagger" }, productionProfile), "dummy aspect supported")
check(ScoringEngine.isProfileSupported({ weapon = "WeaponDagger", aspect = "DaggerTripleAspect" }, morriganProfile)
    and not ScoringEngine.isProfileSupported({ weapon = "WeaponDagger", aspect = "DaggerBackstabAspect" }, morriganProfile),
    "Morrigan profile support boundary was wrong")
local morriganPlanScores = ScoringEngine.scoreOffers({ weapon = "WeaponDagger", aspect = "DaggerTripleAspect", godTraits = {}, hammers = {}, activeArcana = {}, offers = {
    { originalIndex = 1, ItemName = "HeraWeaponBoon" }, { originalIndex = 2, ItemName = "ApolloWeaponBoon" },
    { originalIndex = 3, ItemName = "ZeusWeaponBoon" }, { originalIndex = 4, ItemName = "ZeusSpecialBoon" },
    { originalIndex = 5, ItemName = "PoseidonCastBoon" }, { originalIndex = 6, ItemName = "ApolloSprintBoon" },
    { originalIndex = 7, ItemName = "HeraManaBoon" }, { originalIndex = 8, ItemName = "ApolloManaBoon" },
    { originalIndex = 9, ItemName = "WeaponUpgradeBoon" },
} }, morriganProfile)
check(morriganPlanScores[1].score > morriganPlanScores[2].score and morriganPlanScores[2].score > morriganPlanScores[3].score
    and morriganPlanScores[4].score > 0 and morriganPlanScores[5].score > 0 and morriganPlanScores[6].score > 0
    and morriganPlanScores[7].score > morriganPlanScores[8].score and morriganPlanScores[9].score == 8,
    "Morrigan build-plan scoring changed")
morriganSpecial = ScoringEngine.scoreOffers({ weapon = "WeaponDagger", aspect = "DaggerTripleAspect", godTraits = {}, hammers = {}, activeArcana = {}, offers = {
    { originalIndex = 1, ItemName = "ZeusSpecialBoon" }, { originalIndex = 2, ItemName = "AresSpecialBoon" },
    { originalIndex = 3, ItemName = "HephaestusSpecialBoon" }, { originalIndex = 4, ItemName = "ApolloSpecialBoon" },
    { originalIndex = 5, ItemName = "AphroditeSpecialBoon" }, { originalIndex = 6, ItemName = "HeraSpecialBoon" },
} }, morriganProfile)
check(morriganSpecial[1].score == morriganSpecial[2].score and morriganSpecial[2].score == morriganSpecial[3].score
    and morriganSpecial[4].score == morriganSpecial[5].score and morriganSpecial[4].score < morriganSpecial[1].score
    and morriganSpecial[4].covered and morriganSpecial[4].scoreComplete,
    "Morrigan flexible Special discouraged scoring changed")
do
local poseidonSpecial = ScoringEngine.scoreOffers({
    weapon = "WeaponDagger", aspect = "DaggerTripleAspect", godTraits = {}, hammers = {},
    activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" } },
    offers = {{ originalIndex = 1, ItemName = "PoseidonSpecialBoon", Rarity = "Common" }},
}, morriganProfile)[1]
check(poseidonSpecial.covered and poseidonSpecial.scoreComplete and poseidonSpecial.score == 8
    and #poseidonSpecial.reasons == 1 and poseidonSpecial.reasons[1].code == "FILL_EMPTY_PRIMARY_CORE",
    "Morrigan Poseidon Special open-slot fill score changed")
for _, reason in ipairs(poseidonSpecial.reasons) do
    check(reason.code ~= "ASPECT_SETUP_SYNERGY" and reason.code ~= "ASPECT_DIRECT_SYNERGY"
        and reason.code ~= "ASPECT_COMPATIBLE" and reason.code ~= "BUILD_PREFERRED"
        and reason.code ~= "BUILD_DISCOURAGED" and reason.code ~= "EXISTING_HAMMER_SYNERGY",
        "Poseidon Special received an unrequested Morrigan reason")
end
end

do
local auditedNonStatus = {
    "AphroditeWeaponBoon", "ApolloWeaponBoon", "ApolloSpecialBoon",
    "AphroditeSpecialBoon", "HephaestusSpecialBoon", "HeraManaBoon",
    "ApolloManaBoon", "WeaponUpgradeBoon", "HestiaSprintBoon",
    "BurnExplodeBoon", "FireballManaSpecialBoon", "HephaestusCastBoon",
    "ArmorBoon", "ManaBurstBoon", "HealthRewardBonusBoon",
    "PoseidonSpecialBoon", "ManaRestoreDamageBoon", "BoonDecayBoon",
    "FocusLightningBoon",
}
local seenAudited = {}
for _, traitName in ipairs(auditedNonStatus) do
    check(not seenAudited[traitName], "audited known-non-status list contains a duplicate")
    seenAudited[traitName] = true
    check(productionProfile.knownNonStatusTraits[traitName]
        and starterProfile.knownNonStatusTraits[traitName]
        and morriganProfile.knownNonStatusTraits[traitName],
        "audited known-non-status trait missing from a mechanics template: " .. traitName)
end
check(#auditedNonStatus == 19, "audited known-non-status inventory changed")
local morriganCoreKnownNonStatus = { "ZeusCastBoon", "ZeusManaBoon", "ZeusSprintBoon" }
for _, traitName in ipairs(morriganCoreKnownNonStatus) do
    check(productionProfile.knownNonStatusTraits[traitName]
        and starterProfile.knownNonStatusTraits[traitName]
        and morriganProfile.knownNonStatusTraits[traitName],
        "Morrigan core known-non-status trait missing from a mechanics template: " .. traitName)
end
check(morriganProfile.knownNonStatusTraits.PoseidonSpecialBoon
    and productionProfile.knownNonStatusTraits.PoseidonSpecialBoon
    and starterProfile.knownNonStatusTraits.PoseidonSpecialBoon,
    "Poseidon Special known-non-status data missing")
for traitName in pairs(productionProfile.knownNonStatusTraits) do
    check(starterProfile.knownNonStatusTraits[traitName]
        and morriganProfile.knownNonStatusTraits[traitName],
        "shared known-non-status mechanics diverged: " .. traitName)
end
for traitName in pairs(morriganProfile.knownNonStatusTraits) do
    check(productionProfile.knownNonStatusTraits[traitName]
        and starterProfile.knownNonStatusTraits[traitName],
        "shared known-non-status mechanics diverged: " .. traitName)
end

local activeOrigination = { EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" } }
local function statusKnowledge(profile, traitName)
    local context = ScoringEngine.getOriginationContext({
        activeArcana = activeOrigination, godTraits = {},
    }, profile, traitName)
    check(context.status.statusKnowledge == "known_non_status"
        and context.offerEnablesOrigination == false,
        "audited trait did not resolve as known non-status: " .. traitName)
end
for _, traitName in ipairs(auditedNonStatus) do statusKnowledge(morriganProfile, traitName) end
for _, traitName in ipairs(morriganCoreKnownNonStatus) do statusKnowledge(morriganProfile, traitName) end

do
    local focus = ScoringEngine.scoreOffers({
        weapon = "WeaponDagger", aspect = "DaggerTripleAspect", godTraits = {}, hammers = {},
        activeArcana = activeOrigination,
        offers = { { originalIndex = 1, ItemName = "FocusLightningBoon", Rarity = "Common" } },
    }, morriganProfile)[1]
    local context = ScoringEngine.getOriginationContext({
        activeArcana = activeOrigination, godTraits = {},
    }, morriganProfile, "FocusLightningBoon")
    local sum = 0
    for _, reason in ipairs(focus.reasons) do sum = sum + reason.delta end
    check(context.status.statusKnowledge == "known_non_status"
        and context.status.offeredStatusFamily == nil
        and context.offerEnablesOrigination == false
        and focus.score == 0 and sum == 0
        and not focus.covered and not focus.scoreComplete
        and #focus.reasons == 0,
        "Focus Lightning was not preserved as known non-status without scoring")
end

do
    local echoOfferBase = {
        weapon = "WeaponDagger", aspect = "DaggerTripleAspect", hammers = {},
        activeArcana = {}, offers = {
            { originalIndex = 1, ItemName = "EchoExpirationBoon", Rarity = "Common" },
        },
    }
    local function echoScore(owned, profile)
        local snapshot = deepCopy(echoOfferBase)
        snapshot.godTraits = owned
        return ScoringEngine.scoreOffers(snapshot, profile or morriganProfile)[1]
    end
    local function assertEchoReasons(result, expectedScore, expectedCovered, label)
        local sum, synergyCount = 0, 0
        for _, reason in ipairs(result.reasons) do
            sum = sum + reason.delta
            if reason.code == "BUILD_STATUS_SYNERGY" then synergyCount = synergyCount + 1 end
            check(reason.code ~= "ORIGINATION_ENABLE" and reason.code ~= "ORIGINATION_UNRESOLVED"
                and reason.code ~= "ASPECT_COMPATIBLE" and reason.code ~= "ASPECT_SETUP_SYNERGY"
                and reason.code ~= "ASPECT_DIRECT_SYNERGY" and reason.code ~= "EXISTING_HAMMER_SYNERGY"
                and reason.code ~= "BLOOD_DROP_ENGINE_SYNERGY" and reason.code ~= "WOMBO"
                and reason.code ~= "BLOOD_TRIAD",
                label .. " produced an unrelated reason")
        end
        check(result.score == expectedScore and result.covered == expectedCovered
            and result.scoreComplete == expectedCovered and result.score == sum
            and synergyCount == (expectedCovered and 1 or 0)
            and #result.reasons == (expectedCovered and 1 or 0),
            label .. " Echo Expiration payoff result changed")
    end
    local echoContext = ScoringEngine.getOriginationContext({
        activeArcana = activeOrigination, godTraits = {},
    }, morriganProfile, "EchoExpirationBoon")
    check(echoContext.status.statusKnowledge == "known_non_status"
        and echoContext.status.offeredStatusFamily == nil
        and echoContext.offerEnablesOrigination == false,
        "Echo Expiration status knowledge changed")
    assertEchoReasons(echoScore({}, morriganProfile), 0, false, "no Echo producer")
    assertEchoReasons(echoScore({ { Name = "ZeusWeaponBoon" } }), 4, true, "Zeus Weapon producer")
    assertEchoReasons(echoScore({ { Name = "ZeusSpecialBoon" } }), 4, true, "Zeus Special producer")
    assertEchoReasons(echoScore({ { Name = "ZeusWeaponBoon" }, { Name = "ZeusSpecialBoon" } }), 4, true, "both Echo producers")
    assertEchoReasons(echoScore({ { Name = "ZeusCastBoon" } }), 0, false, "unrelated Zeus trait")
    assertEchoReasons(echoScore({}, productionProfile), 0, false, "Melinoe isolation")
    local plannedOnly = echoScore({}, morriganProfile)
    check(plannedOnly.score == 0 and not plannedOnly.covered and not plannedOnly.scoreComplete,
        "Morrigan Special preference incorrectly activated Echo payoff")
end

do
local damageShareOfferBase = {
        weapon = "WeaponDagger", aspect = "DaggerTripleAspect", hammers = {},
        activeArcana = {}, offers = {
            { originalIndex = 1, ItemName = "DamageSharePotencyBoon", Rarity = "Common" },
        },
    }
    local producers = { "HeraWeaponBoon", "HeraSpecialBoon", "HeraCastBoon", "HeraSprintBoon" }
    local function damageShareScore(owned)
        local snapshot = deepCopy(damageShareOfferBase)
        snapshot.godTraits = owned
        return ScoringEngine.scoreOffers(snapshot, morriganProfile)[1]
    end
    local function assertDamageShareResult(owned, expectedScore, expectedCovered, label)
        local result = damageShareScore(owned)
        local sum = 0
        local synergyCount = 0
        for _, reason in ipairs(result.reasons) do
            sum = sum + reason.delta
            if reason.code == "BUILD_STATUS_SYNERGY" then synergyCount = synergyCount + 1 end
            check(reason.code ~= "ORIGINATION_ENABLE" and reason.code ~= "ORIGINATION_UNRESOLVED"
                and reason.code ~= "ASPECT_COMPATIBLE" and reason.code ~= "ASPECT_SETUP_SYNERGY"
                and reason.code ~= "ASPECT_DIRECT_SYNERGY" and reason.code ~= "EXISTING_HAMMER_SYNERGY"
                and reason.code ~= "BLOOD_DROP_ENGINE_SYNERGY",
                label .. " produced an unrelated reason")
        end
        check(result.score == expectedScore and result.covered == expectedCovered
            and result.scoreComplete == expectedCovered and result.score == sum
            and synergyCount == (expectedCovered and 1 or 0),
            label .. " Damage Share payoff result changed")
    end
    assertDamageShareResult({}, 0, false, "no producer")
    for _, producer in ipairs(producers) do
        assertDamageShareResult({ { Name = producer } }, 4, true, producer)
    end
    assertDamageShareResult({ { Name = "HeraWeaponBoon" }, { Name = "HeraSpecialBoon" } }, 4, true,
        "two producers")
    local allProducers = {}
    for _, producer in ipairs(producers) do table.insert(allProducers, { Name = producer }) end
    assertDamageShareResult(allProducers, 4, true, "all producers")
    assertDamageShareResult({ { Name = "HeraManaBoon" } }, 0, false, "Hera Mana only")
    assertDamageShareResult({ { Name = "HeraWeaponBoon" } }, 4, true, "profile plan versus ownership")
    local melinoe = deepCopy(damageShareOfferBase)
    melinoe.godTraits = { { Name = "HeraWeaponBoon" } }
    local melinoeResult = ScoringEngine.scoreOffers(melinoe, productionProfile)[1]
    check(melinoeResult.score == 0 and not melinoeResult.covered and not melinoeResult.scoreComplete,
        "Damage Share Morrigan rule leaked into Melinoe")
end

local heraMana = ScoringEngine.scoreOffers({
    weapon = "WeaponDagger", aspect = "DaggerTripleAspect", godTraits = {}, hammers = {},
    activeArcana = activeOrigination,
    offers = { { originalIndex = 1, ItemName = "HeraManaBoon", Blocked = false } },
}, morriganProfile)[1]
check(heraMana.score == 8 and heraMana.covered and heraMana.scoreComplete
    and heraMana.reasons[1].code == "FILL_EMPTY_UTILITY_CORE"
    and heraMana.reasons[2].code == "BUILD_CORE_PRIORITY",
    "Hera Mana known non-status completion or base score changed")
for _, reason in ipairs(heraMana.reasons) do
    check(reason.code ~= "ORIGINATION_UNRESOLVED", "Hera Mana remained Origination-unresolved")
end

local apolloMana = ScoringEngine.scoreOffers({
    weapon = "WeaponDagger", aspect = "DaggerTripleAspect", godTraits = {}, hammers = {},
    activeArcana = activeOrigination,
    offers = { { originalIndex = 1, ItemName = "ApolloManaBoon", Blocked = false } },
}, morriganProfile)[1]
-- Apollo Mana is currently an alternative in the Morrigan Mana plan, so the
-- data-only change resolves Origination without inventing BUILD_PREFERRED:
-- its current-plan score is the utility fill value 4.
check(apolloMana.score == 4 and apolloMana.covered and apolloMana.scoreComplete,
    "Apollo Mana known non-status score or completion changed")

local hephSpecial = ScoringEngine.scoreOffers({
    weapon = "WeaponDagger", aspect = "DaggerTripleAspect", godTraits = {}, hammers = {},
    activeArcana = activeOrigination,
    offers = { { originalIndex = 1, ItemName = "HephaestusSpecialBoon", Blocked = false } },
}, morriganProfile)[1]
check(hephSpecial.score == 10 and hephSpecial.covered and hephSpecial.scoreComplete,
    "Hephaestus Special known non-status score or completion changed")
for _, reason in ipairs(hephSpecial.reasons) do
    check(reason.code ~= "ORIGINATION_UNRESOLVED", "Hephaestus Special remained Origination-unresolved")
end
local hestiaSprintContext = ScoringEngine.getOriginationContext({
    activeArcana = activeOrigination, godTraits = {},
}, morriganProfile, "HestiaSprintBoon")
check(hestiaSprintContext.status.statusKnowledge == "known_non_status"
    and hestiaSprintContext.offerEnablesOrigination == false,
    "Hestia Sprint known non-status classification changed")
end

local profile = deepCopy(productionProfile)
profile.weights = {
    daggerBackstabTrait = 11,
    apolloBlindBackstab = 7,
    apolloBlindPrerequisite = 5,
}
profile.rules = {
    DaggerBackstabTrait = {
        { code = "TEST_BACKSTAB", weight = "daggerBackstabTrait" },
    },
    ApolloBlindBoon = {
        { code = "TEST_BLIND", weight = "apolloBlindBackstab" },
        { code = "TEST_PREREQUISITE", weight = "apolloBlindPrerequisite",
            requiresAnyOwned = { "ApolloCastBoon" } },
    },
}
local snapshot = {
    weapon = "WeaponDagger",
    aspect = "DaggerBackstabAspect",
    godTraits = { { Name = "ApolloCastBoon" } },
    offers = {
        { originalIndex = 7, ItemName = "UnknownBoon", Rarity = "Common", StackNum = 3, Blocked = false },
        { originalIndex = 2, ItemName = "ApolloBlindBoon", TraitToReplace = "OldCoreBoon", OldRarity = "Rare", Blocked = false },
        { originalIndex = 4, ItemName = "DaggerBackstabTrait", Blocked = false },
        { originalIndex = 9, ItemName = "ApolloBlindBoon", Blocked = true },
    },
}
local beforeSnapshot, beforeProfile = deepCopy(snapshot), deepCopy(profile)
local results = ScoringEngine.scoreOffers(snapshot, profile)
check(#results == 4 and results[1].originalIndex == 7 and results[1].score == 0
    and #results[1].reasons == 0, "unknown offer handling changed")
check(results[2].score == 12 and #results[2].reasons == 2
    and results[2].reasons[2].with == "ApolloCastBoon", "verified owned-boon synergy missing")
check(results[2].traitToReplace == "OldCoreBoon" and results[2].oldRarity == "Rare",
    "replacement metadata not preserved")
check(results[1].stackNum == 3, "StackNum not preserved")
check(results[4].supported == false and results[4].eligible == false
    and results[4].reasons[1].code == "BLOCKED", "blocked offer remained recommendable")
for _, result in ipairs(results) do
    local sum = 0
    for _, reason in ipairs(result.reasons) do sum = sum + reason.delta end
    check(result.score == sum, "score differs from reason delta sum")
end
local withoutOwned = deepCopy(snapshot); withoutOwned.godTraits = {}
local withoutOwnedResults = ScoringEngine.scoreOffers(withoutOwned, profile)
check(withoutOwnedResults[2].score == 7 and #withoutOwnedResults[2].reasons == 1,
    "absent godTraits incorrectly enabled synergy")
local unsupportedResults = ScoringEngine.scoreOffers({
    weapon = "WeaponStaffSwing", aspect = nil, offers = snapshot.offers, godTraits = snapshot.godTraits,
}, profile)
check(unsupportedResults[1].supported == false and unsupportedResults[1].score == 0,
    "unsupported build received build score")
check(deepEqual(snapshot, beforeSnapshot) and deepEqual(profile, beforeProfile),
    "scoring mutated snapshot or profile")
print("PASS: exact profile support; known/unknown offers; multiple reasons; score=sum; godTrait synergy; blocked/replacement/stack metadata; no mutation")

local function makeResults(count)
    local values = {}
    for index = 1, count do
        values[index] = { originalIndex = index, score = index % 2, supported = true, eligible = true }
    end
    return values
end
for count = 0, 5 do
    local input = makeResults(count)
    local before = deepCopy(input)
    local ranked = ScoringEngine.rank(input)
    check(#ranked == count and deepEqual(input, before), "ranking count/mutation failed for " .. count)
    for index = 2, #ranked do
        check(ranked[index - 1].score > ranked[index].score
            or (ranked[index - 1].score == ranked[index].score
                and ranked[index - 1].originalIndex < ranked[index].originalIndex),
            "ranking order incorrect")
    end
end
local blockedRanking = ScoringEngine.rank({
    { originalIndex = 3, score = 100, supported = false, eligible = false },
    { originalIndex = 2, score = 4, supported = true, eligible = true },
    { originalIndex = 1, score = 4, supported = true, eligible = true },
})
check(#blockedRanking == 2 and blockedRanking[1].originalIndex == 1
    and blockedRanking[2].originalIndex == 2, "blocked exclusion or tie-break failed")
print("PASS: ranking 0/1/2/3/N; descending score; originalIndex tie-break; blocked excluded; input unchanged")

local contextSnapshot = {
    activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Rare" } },
    godTraits = { { Name = "AresWeaponBoon", Slot = "Melee" } },
}
local contextBefore, productionBefore = deepCopy(contextSnapshot), deepCopy(productionProfile)
local status = ScoringEngine.getStatusContext(contextSnapshot, productionProfile, "DemeterCastBoon")
check(status.ownedStatusFamilies.Curse and status.ownedStatusOlympians.Ares
    and status.offeredStatusFamily == "Root" and status.offeredStatusOlympian == "Demeter",
    "verified status context wrong")
local origination = ScoringEngine.getOriginationContext(contextSnapshot, productionProfile,
    "DemeterCastBoon")
check(origination.offerEnablesOrigination == true and origination.originationRarity == "Rare",
    "second family or Origination rarity not detected")
check(ScoringEngine.getOriginationContext(contextSnapshot, productionProfile,
    "AresSpecialBoon").offerEnablesOrigination == false, "same family enabled Origination")
check(ScoringEngine.getOriginationContext({
    activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Common" } }, godTraits = {} },
    productionProfile, "DemeterCastBoon").offerEnablesOrigination == false,
    "first status incorrectly enabled Origination")
check(ScoringEngine.getOriginationContext({ activeArcana = {}, godTraits = contextSnapshot.godTraits },
    productionProfile, "DemeterCastBoon").offerEnablesOrigination == false,
    "inactive Origination enabled")
check(ScoringEngine.getOriginationContext(contextSnapshot, productionProfile,
    "UnknownBoon").offerEnablesOrigination == nil, "unknown offer treated as false")
local unrelatedUnknown = { activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" } },
    godTraits = { { Name = "AresWeaponBoon" }, { Name = "UnknownOwnedBoon" } } }
check(ScoringEngine.getOriginationContext(unrelatedUnknown, productionProfile,
    "DemeterCastBoon").offerEnablesOrigination == true,
    "unrelated unknown boon contaminated a proven second family")
local potentialProfile = deepCopy(productionProfile)
potentialProfile.potentialStatusTraits.UnknownPotentialStatusBoon = true
local unknownPotential = { activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Common" } },
    godTraits = { { Name = "UnknownPotentialStatusBoon" } } }
check(ScoringEngine.getOriginationContext(unknownPotential, potentialProfile,
    "DemeterCastBoon").offerEnablesOrigination == nil,
    "unknown potential status was treated as absent")
local sameWithPotential = deepCopy(unknownPotential)
sameWithPotential.godTraits[#sameWithPotential.godTraits + 1] = { Name = "AresWeaponBoon" }
check(ScoringEngine.getOriginationContext(sameWithPotential, potentialProfile,
    "AresSpecialBoon").offerEnablesOrigination == nil,
    "same family with unknown potential status was treated as false")
local twoKnown = { activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Common" } },
    godTraits = { { Name = "AresWeaponBoon" }, { Name = "ZeusSpecialBoon" } } }
check(ScoringEngine.getOriginationContext(twoKnown, productionProfile,
    "DemeterCastBoon").offerEnablesOrigination == false,
    "already-enabled Origination was attributed to the offer")
check(ScoringEngine.getOriginationContext(twoKnown, productionProfile,
    "UnmappedOffer").offerEnablesOrigination == false,
    "unmapped offer hid two already-owned families")
local threeKnown = deepCopy(twoKnown)
threeKnown.godTraits[#threeKnown.godTraits + 1] = { Name = "AphroditeCastBoon" }
check(ScoringEngine.getOriginationContext(threeKnown, productionProfile,
    "FocusRawDamageBoon").offerEnablesOrigination == false,
    "unmapped offer hid three already-owned families")

local emptySlot = ScoringEngine.getCoreSlotContext({ godTraits = {} }, productionProfile,
    { ItemName = "ZeusSpecialBoon" })
check(emptySlot.coreRole == "Special" and emptySlot.coreSlot == "Secondary"
    and emptySlot.fillsEmptyCoreSlot and not emptySlot.replacesCoreSlot, "empty core slot wrong")
local replacement = ScoringEngine.getCoreSlotContext(contextSnapshot, productionProfile,
    { ItemName = "ZeusSpecialBoon", TraitToReplace = "AresSpecialBoon" })
check(replacement.replacesCoreSlot and not replacement.fillsEmptyCoreSlot,
    "TraitToReplace not authoritative")
local aphroditeReplacement = ScoringEngine.getCoreSlotContext(contextSnapshot, productionProfile,
    { ItemName = "AphroditeWeaponBoon", TraitToReplace = "AresWeaponBoon" })
check(aphroditeReplacement.coreRole == "Attack" and aphroditeReplacement.replacesCoreSlot
    and ScoringEngine.getAspectInteraction(productionProfile, "AphroditeWeaponBoon")
        == "ASPECT_COMPATIBLE", "Aphrodite Attack replacement context wrong")
local occupied = ScoringEngine.getCoreSlotContext(contextSnapshot, productionProfile,
    { ItemName = "ApolloWeaponBoon" })
check(not occupied.fillsEmptyCoreSlot and not occupied.replacesCoreSlot,
    "occupied slot incorrectly called empty or replacement")
local reservedNonTarget = ScoringEngine.getCoreSlotContext({ godTraits = {}, slottedTraits = {} },
    productionProfile, { ItemName = "AresSpecialBoon" })
check(reservedNonTarget.alignment == "NON_TARGET" and reservedNonTarget.slotPolicy == "reserved"
    and reservedNonTarget.slotConflict and reservedNonTarget.slotStateBefore == "EMPTY"
    and reservedNonTarget.conflictIntroduced,
    "reserved NON_TARGET did not expose a slot conflict")
local reservedCore = ScoringEngine.getCoreSlotContext({ godTraits = {}, slottedTraits = {} },
    productionProfile, { ItemName = "ZeusSpecialBoon" })
check(reservedCore.alignment == "CORE" and not reservedCore.slotConflict,
    "reserved core was marked as a slot conflict")
local slottedOccupancy = ScoringEngine.getCoreSlotContext({ godTraits = {},
    slottedTraits = { Secondary = "ZeusSpecialBoon" } }, productionProfile,
    { ItemName = "AresSpecialBoon" })
check(slottedOccupancy.currentSlotTrait == "ZeusSpecialBoon" and slottedOccupancy.slotStateBefore == "CORE",
    "authoritative SlottedTraits occupancy was not used")
local reservedAlternative = ScoringEngine.getCoreSlotContext({ godTraits = {}, slottedTraits = {} },
    productionProfile, { ItemName = "AphroditeWeaponBoon" })
check(reservedAlternative.alignment == "ALTERNATIVE" and not reservedAlternative.slotConflict,
    "reserved alternative was marked as a slot conflict")
local preferredNonTarget = ScoringEngine.getCoreSlotContext({ godTraits = {}, slottedTraits = {} },
    productionProfile, { ItemName = "PoseidonSprintBoon" })
check(preferredNonTarget.alignment == "NON_TARGET" and preferredNonTarget.slotPolicy == "preferred"
    and not preferredNonTarget.slotConflict,
    "preferred non-target was marked as a slot conflict")
local noSlot = ScoringEngine.getCoreSlotContext({ godTraits = {} }, productionProfile,
    { ItemName = "LowHealthLifestealBoon" })
check(noSlot.coreRole == nil and not noSlot.slotConflict, "support boon acquired a slot conflict")
local replacementResolution = ScoringEngine.getCoreSlotContext({ godTraits = {} }, productionProfile,
    { ItemName = "ZeusSpecialBoon", TraitToReplace = "AresSpecialBoon" })
check(replacementResolution.slotStateBefore == "NON_TARGET" and replacementResolution.slotStateAfter == "CORE"
    and replacementResolution.conflictResolved and not replacementResolution.coreSacrificed,
    "replacement conflict resolution metadata was wrong")
local replacementSacrifice = ScoringEngine.getCoreSlotContext({ godTraits = {} }, productionProfile,
    { ItemName = "AresSpecialBoon", TraitToReplace = "ZeusSpecialBoon" })
check(replacementSacrifice.slotStateBefore == "CORE" and replacementSacrifice.slotStateAfter == "NON_TARGET"
    and replacementSacrifice.slotConflict and replacementSacrifice.coreSacrificed,
    "replacement core sacrifice metadata was wrong")
check(ScoringEngine.getAspectInteraction(productionProfile, "AresWeaponBoon") == "ASPECT_COMPATIBLE"
    and ScoringEngine.getAspectInteraction(productionProfile, "AphroditeWeaponBoon") == "ASPECT_COMPATIBLE"
    and ScoringEngine.getAspectInteraction(productionProfile, "ApolloSpecialBoon") == "ASPECT_COMPATIBLE"
    and ScoringEngine.getAspectInteraction(productionProfile, "DaggerFinalHitTrait") == "ASPECT_DIRECT_SYNERGY"
    and ScoringEngine.getAspectInteraction(productionProfile, "DemeterCastBoon") == "BACKSTAB_SETUP"
    and ScoringEngine.getAspectInteraction(productionProfile, "ApolloCastBoon") == nil
    and ScoringEngine.getAspectInteraction(productionProfile, "AphroditeSprintBoon") == nil,
    "aspect interaction categories collapsed")
local setupProfile = deepCopy(productionProfile)
setupProfile.aspectInteractions.ExplicitSetupTrait = "ASPECT_SETUP_SYNERGY"
setupProfile.aspectInteractions.ExplicitBothTrait = {
    "ASPECT_DIRECT_SYNERGY", "ASPECT_SETUP_SYNERGY", "ASPECT_SETUP_SYNERGY",
}
local setupBefore = deepCopy(setupProfile)
local setupSnapshot = {
    weapon = "WeaponDagger", aspect = "DaggerBackstabAspect", godTraits = {}, hammers = {},
    activeArcana = {}, offers = {
        { originalIndex = 1, ItemName = "ExplicitSetupTrait", Blocked = false },
        { originalIndex = 2, ItemName = "ExplicitBothTrait", Blocked = false },
        { originalIndex = 3, ItemName = "AphroditeWeaponBoon", Blocked = false },
        { originalIndex = 4, ItemName = "ApolloSpecialBoon", Blocked = false },
        { originalIndex = 5, ItemName = "AresCastBoon", Blocked = false },
    },
}
local setupSnapshotBefore = deepCopy(setupSnapshot)
local setupScores = ScoringEngine.scoreOffers(setupSnapshot, setupProfile)
local function reasonCount(result, code)
    local count = 0
    for _, reason in ipairs(result.reasons) do if reason.code == code then count = count + 1 end end
    return count
end
check(setupScores[1].score == 4 and setupScores[1].covered and setupScores[1].scoreComplete
    and reasonCount(setupScores[1], "ASPECT_SETUP_SYNERGY") == 1,
    "explicit aspect setup interaction was not scored exactly once")
check(setupScores[2].score == 12 and setupScores[2].covered and setupScores[2].scoreComplete
    and reasonCount(setupScores[2], "ASPECT_DIRECT_SYNERGY") == 1
    and reasonCount(setupScores[2], "ASPECT_SETUP_SYNERGY") == 1,
    "explicit direct plus setup interactions were not kept distinct and deduplicated")
check(reasonCount(setupScores[3], "ASPECT_COMPATIBLE") == 1
    and reasonCount(setupScores[3], "ASPECT_SETUP_SYNERGY") == 0
    and reasonCount(setupScores[4], "ASPECT_COMPATIBLE") == 1
    and reasonCount(setupScores[4], "ASPECT_SETUP_SYNERGY") == 0
    and reasonCount(setupScores[5], "ASPECT_SETUP_SYNERGY") == 0,
    "unlisted action boons received generic aspect setup synergy")
local setupSum = 0
for _, reason in ipairs(setupScores[2].reasons) do setupSum = setupSum + reason.delta end
check(setupScores[2].score == setupSum, "aspect setup score differed from its reasons")
local bothInteractions = ScoringEngine.getAspectInteractions(setupProfile, "ExplicitBothTrait")
check(#bothInteractions == 2 and bothInteractions[1] == "ASPECT_DIRECT_SYNERGY"
    and bothInteractions[2] == "ASPECT_SETUP_SYNERGY"
    and ScoringEngine.getAspectInteraction(setupProfile, "ExplicitBothTrait") == "ASPECT_DIRECT_SYNERGY",
    "plural aspect interaction schema was not deterministic")
check(deepEqual(setupSnapshot, setupSnapshotBefore) and deepEqual(setupProfile, setupBefore),
    "aspect setup scoring mutated its snapshot or profile")
local fallbackProfile = deepCopy(productionProfile)
fallbackProfile.genericCoreAspectCompatibility = false
fallbackProfile.aspectInteractions.ExplicitFallbackDirect = "ASPECT_DIRECT_SYNERGY"
fallbackProfile.aspectInteractions.ExplicitFallbackSetup = "ASPECT_SETUP_SYNERGY"
local fallbackSnapshot = {
    weapon = "WeaponDagger", aspect = "DaggerBackstabAspect", godTraits = {}, hammers = {},
    activeArcana = {}, offers = {
        { originalIndex = 1, ItemName = "AphroditeWeaponBoon", Blocked = false },
        { originalIndex = 2, ItemName = "ApolloSpecialBoon", Blocked = false },
        { originalIndex = 3, ItemName = "ExplicitFallbackDirect", Blocked = false },
        { originalIndex = 4, ItemName = "ExplicitFallbackSetup", Blocked = false },
    },
}
local fallbackScores = ScoringEngine.scoreOffers(fallbackSnapshot, fallbackProfile)
check(reasonCount(fallbackScores[1], "ASPECT_COMPATIBLE") == 0
    and reasonCount(fallbackScores[2], "ASPECT_COMPATIBLE") == 0,
    "disabled generic core aspect compatibility still awarded Attack or Special")
check(reasonCount(fallbackScores[3], "ASPECT_DIRECT_SYNERGY") == 1
    and fallbackScores[3].score == 8
    and reasonCount(fallbackScores[4], "ASPECT_SETUP_SYNERGY") == 1
    and fallbackScores[4].score == 4,
    "explicit aspect interactions did not override disabled generic compatibility")
local enabledFallbackProfile = deepCopy(fallbackProfile)
enabledFallbackProfile.genericCoreAspectCompatibility = true
enabledFallbackProfile.aspectInteractions.ExplicitFallbackDirect = nil
enabledFallbackProfile.aspectInteractions.ExplicitFallbackSetup = nil
local enabledFallbackScores = ScoringEngine.scoreOffers(fallbackSnapshot, enabledFallbackProfile)
check(reasonCount(enabledFallbackScores[1], "ASPECT_COMPATIBLE") == 1
    and reasonCount(enabledFallbackScores[2], "ASPECT_COMPATIBLE") == 1,
    "enabled generic core aspect compatibility did not preserve Attack/Special fallback")
local morriganSynthetic = deepCopy(productionProfile)
morriganSynthetic.weapon = "WeaponDagger"
morriganSynthetic.aspect = "DaggerTripleAspect"
morriganSynthetic.genericCoreAspectCompatibility = false
morriganSynthetic.aspectInteractions = {
    WeaponUpgradeBoon = "ASPECT_DIRECT_SYNERGY",
    ExplicitMorriganSetup = "ASPECT_SETUP_SYNERGY",
    ExplicitMorriganBoth = { "ASPECT_DIRECT_SYNERGY", "ASPECT_SETUP_SYNERGY" },
}
local morriganScores = ScoringEngine.scoreOffers({
    weapon = "WeaponDagger", aspect = "DaggerTripleAspect", godTraits = {}, hammers = {}, activeArcana = {},
    offers = {
        { originalIndex = 1, ItemName = "WeaponUpgradeBoon", Blocked = false },
        { originalIndex = 2, ItemName = "AphroditeWeaponBoon", Blocked = false },
        { originalIndex = 3, ItemName = "ApolloSpecialBoon", Blocked = false },
        { originalIndex = 4, ItemName = "OmegaSyntheticBoon", Blocked = false },
        { originalIndex = 5, ItemName = "ExplicitMorriganSetup", Blocked = false },
        { originalIndex = 6, ItemName = "ExplicitMorriganBoth", Blocked = false },
    },
}, morriganSynthetic)
check(morriganScores[1].score == 8 and reasonCount(morriganScores[1], "ASPECT_DIRECT_SYNERGY") == 1
    and reasonCount(morriganScores[1], "ASPECT_SETUP_SYNERGY") == 0,
    "Morrigan Premium Service was not direct-only aspect amplification")
check(reasonCount(morriganScores[2], "ASPECT_COMPATIBLE") == 0 and reasonCount(morriganScores[2], "ASPECT_SETUP_SYNERGY") == 0
    and reasonCount(morriganScores[3], "ASPECT_COMPATIBLE") == 0 and reasonCount(morriganScores[3], "ASPECT_SETUP_SYNERGY") == 0
    and reasonCount(morriganScores[4], "ASPECT_SETUP_SYNERGY") == 0,
    "Morrigan contributing actions received an implicit aspect interaction")
check(morriganScores[5].score == 4 and reasonCount(morriganScores[5], "ASPECT_SETUP_SYNERGY") == 1
    and morriganScores[6].score == 12 and reasonCount(morriganScores[6], "ASPECT_DIRECT_SYNERGY") == 1
    and reasonCount(morriganScores[6], "ASPECT_SETUP_SYNERGY") == 1,
    "explicit Morrigan setup/direct interactions were not scored exactly as declared")
check(deepEqual(contextSnapshot, contextBefore) and deepEqual(productionProfile, productionBefore),
    "context helpers mutated snapshot or profile")
print("PASS: Arcana/status context; known/unknown families; Origination; core slots; aspect categories; no mutation")

local matrixSnapshot = {
    weapon = "WeaponDagger", aspect = "DaggerBackstabAspect",
    godTraits = {}, hammers = {}, activeArcana = {},
    offers = {
        { originalIndex = 1, ItemName = "AresWeaponBoon", Blocked = false },
        { originalIndex = 2, ItemName = "ZeusSpecialBoon", Blocked = false },
        { originalIndex = 3, ItemName = "DemeterCastBoon", Blocked = false },
        { originalIndex = 4, ItemName = "PoseidonSprintBoon", Blocked = false },
        { originalIndex = 5, ItemName = "ZeusManaBoon", Blocked = false },
    },
}
local matrixBefore = deepCopy(matrixSnapshot)
local matrix = ScoringEngine.scoreOffers(matrixSnapshot, productionProfile)
check(matrix[1].score == 16 and matrix[1].covered
    and matrix[1].reasons[1].code == "FILL_EMPTY_PRIMARY_CORE"
    and matrix[1].reasons[2].code == "ASPECT_COMPATIBLE", "empty Attack score wrong")
check(matrix[2].score == 16 and matrix[2].covered, "empty Special score wrong")
check(matrix[3].score == 16 and matrix[3].covered
    and matrix[3].reasons[2].code == "BACKSTAB_SETUP", "empty Cast score wrong")
check(matrix[4].score == 0 and matrix[4].covered and matrix[4].scoreComplete,
    "explicit non-target Sprint resolution wrong")
check(matrix[5].score == 4 and matrix[5].covered, "empty Mana score wrong")

local originSnapshot = deepCopy(matrixSnapshot)
originSnapshot.activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" } }
originSnapshot.godTraits = { { Name = "AresWeaponBoon", Slot = "Melee" } }
originSnapshot.offers = { { originalIndex = 1, ItemName = "DemeterCastBoon", Blocked = false } }
local originScore = ScoringEngine.scoreOffers(originSnapshot, productionProfile)[1]
check(originScore.score == 24 and originScore.reasons[4].code == "ORIGINATION_ENABLE"
    and originScore.reasons[4].delta == 8, "Origination enable score wrong")
originSnapshot.godTraits[#originSnapshot.godTraits + 1] = { Name = "ZeusSpecialBoon", Slot = "Secondary" }
local alreadyScore = ScoringEngine.scoreOffers(originSnapshot, productionProfile)[1]
check(alreadyScore.score == 16 and #alreadyScore.reasons == 3,
    "already-satisfied Origination received a bonus")

local hammerSnapshot = deepCopy(matrixSnapshot)
hammerSnapshot.hammers = {
    { Name = "DaggerRapidAttackTrait" }, { Name = "DaggerBackstabTrait" },
    { Name = "DaggerFinalHitTrait" },
}
hammerSnapshot.offers = { { originalIndex = 1, ItemName = "AphroditeWeaponBoon", Blocked = false } }
local hammerScore = ScoringEngine.scoreOffers(hammerSnapshot, productionProfile)[1]
local hammerReasons = 0
for _, reason in ipairs(hammerScore.reasons) do
    if reason.code == "EXISTING_HAMMER_SYNERGY" then
        hammerReasons = hammerReasons + 1
        check(reason.with == "DaggerBackstabTrait", "Hammer attribution is not deterministic")
    end
end
check(hammerScore.score == 16 and hammerReasons == 1, "Hammer synergy stacked or scored incorrectly")

local replacementSnapshot = deepCopy(hammerSnapshot)
replacementSnapshot.hammers = {}
replacementSnapshot.offers[1].TraitToReplace = "AresWeaponBoon"
local replacementScore = ScoringEngine.scoreOffers(replacementSnapshot, productionProfile)[1]
check(replacementScore.score == -4 and replacementScore.covered
    and replacementScore.scoreComplete
    and replacementScore.reasons[#replacementScore.reasons].code == "CORE_REPLACEMENT_DELTA"
    and replacementScore.reasons[#replacementScore.reasons].delta == -4,
    "known equal core replacement was not resolved conservatively")
local unknownSnapshot = deepCopy(matrixSnapshot)
unknownSnapshot.offers = { { originalIndex = 1, ItemName = "FocusRawDamageBoon", Blocked = false } }
local unknownScore = ScoringEngine.scoreOffers(unknownSnapshot, productionProfile)[1]
check(unknownScore.score == 0 and not unknownScore.covered and #unknownScore.reasons == 0,
    "unknown support boon was treated as covered")

local statusOnlySnapshot = {
    weapon = "WeaponDagger", aspect = "DaggerBackstabAspect", hammers = {},
    activeArcana = {}, godTraits = {},
    offers = { { originalIndex = 1, ItemName = "ApolloRetaliateBoon", Blocked = false } },
}
local statusOnly = ScoringEngine.scoreOffers(statusOnlySnapshot, productionProfile)[1]
check(statusOnly.score == 0 and not statusOnly.covered and #statusOnly.reasons == 0,
    "mapped status alone was treated as gameplay coverage")
local statusUnknownProfile = deepCopy(productionProfile)
statusUnknownProfile.potentialStatusTraits.UnknownPotentialStatusBoon = true
local statusUnknownSnapshot = deepCopy(statusOnlySnapshot)
statusUnknownSnapshot.activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Common" } }
statusUnknownSnapshot.godTraits = { { Name = "UnknownPotentialStatusBoon" } }
local statusUnknown = ScoringEngine.scoreOffers(statusUnknownSnapshot, statusUnknownProfile)[1]
check(statusUnknown.score == 0 and not statusUnknown.covered and not statusUnknown.scoreComplete
    and statusUnknown.reasons[1].code == "ORIGINATION_UNRESOLVED",
    "unknown Origination status context was treated as gameplay coverage")
local statusEnableSnapshot = deepCopy(statusOnlySnapshot)
statusEnableSnapshot.activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" } }
statusEnableSnapshot.godTraits = { { Name = "AresWeaponBoon", Slot = "Melee" } }
local statusEnable = ScoringEngine.scoreOffers(statusEnableSnapshot, productionProfile)[1]
check(statusEnable.score == 8 and statusEnable.covered
    and statusEnable.reasons[1].code == "ORIGINATION_ENABLE",
    "Origination enable did not create gameplay coverage")
local statusCoreSnapshot = deepCopy(statusOnlySnapshot)
statusCoreSnapshot.offers[1] = { originalIndex = 1, ItemName = "DemeterCastBoon", Blocked = false }
local statusCore = ScoringEngine.scoreOffers(statusCoreSnapshot, productionProfile)[1]
check(statusCore.covered and statusCore.score == 16,
    "mapped status plus core gameplay rule was not covered")
local statusReplacementSnapshot = deepCopy(statusCoreSnapshot)
statusReplacementSnapshot.offers[1].TraitToReplace = "OldCast"
local statusReplacement = ScoringEngine.scoreOffers(statusReplacementSnapshot, productionProfile)[1]
check(statusReplacement.score == 0 and not statusReplacement.covered
    and statusReplacement.reasons[#statusReplacement.reasons].code == "REPLACEMENT_UNRESOLVED",
    "unresolved replacement did not override gameplay coverage")

local castReplacementBase = {
    weapon = "WeaponDagger", aspect = "DaggerBackstabAspect", godTraits = {}, hammers = {},
    activeArcana = {}, offers = {},
}
local castUp = deepCopy(castReplacementBase)
castUp.offers = {{ originalIndex = 1, ItemName = "DemeterCastBoon",
    TraitToReplace = "AresCastBoon", Blocked = false }}
local upResult = ScoringEngine.scoreOffers(castUp, productionProfile)[1]
check(upResult.covered and upResult.scoreComplete and upResult.score == 12
    and upResult.reasons[1].code == "CORE_REPLACEMENT_DELTA"
    and upResult.reasons[1].delta == 8
    and upResult.reasons[2].code == "BUILD_SLOT_POLICY_DELTA"
    and upResult.reasons[2].delta == 4, "positive cast replacement delta wrong")
local castDown = deepCopy(castReplacementBase)
castDown.offers = {{ originalIndex = 1, ItemName = "AresCastBoon",
    TraitToReplace = "DemeterCastBoon", Blocked = false }}
local downResult = ScoringEngine.scoreOffers(castDown, productionProfile)[1]
check(downResult.covered and downResult.scoreComplete and downResult.score == -12
    and downResult.reasons[1].code == "CORE_REPLACEMENT_DELTA"
    and downResult.reasons[1].delta == -8
    and downResult.reasons[2].code == "BUILD_SLOT_POLICY_DELTA"
    and downResult.reasons[2].delta == -4, "negative cast replacement delta wrong")
local originReplace = deepCopy(castReplacementBase)
originReplace.activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" } }
originReplace.godTraits = { { Name = "AphroditeCastBoon", Slot = "Ranged" } }
originReplace.offers = {{ originalIndex = 1, ItemName = "DemeterCastBoon",
    TraitToReplace = "AresCastBoon", Blocked = false }}
local originUp = ScoringEngine.scoreOffers(originReplace, productionProfile)[1]
check(originUp.covered and originUp.scoreComplete and originUp.score == 20,
    "replacement Origination activation was not included")
local originDown = deepCopy(castReplacementBase)
originDown.activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" } }
originDown.godTraits = { { Name = "DemeterCastBoon", Slot = "Ranged" },
    { Name = "AphroditeCastBoon", Slot = "Ranged" } }
originDown.offers = {{ originalIndex = 1, ItemName = "AresCastBoon",
    TraitToReplace = "DemeterCastBoon", Blocked = false }}
local originDownResult = ScoringEngine.scoreOffers(originDown, productionProfile)[1]
check(originDownResult.covered and originDownResult.scoreComplete and originDownResult.score == -20,
    "replacement Origination loss was not included")
check(not ScoringEngine.isRankingReady({ statusOnly },
    ScoringEngine.getRankingContext({ statusOnly }, true)),
    "mapped-status-only eligible offer became rankable")
for _, result in ipairs(matrix) do
    local sum = 0
    for _, reason in ipairs(result.reasons) do sum = sum + reason.delta end
    check(result.score == sum, "production score contains an invisible delta")
end
check(deepEqual(matrixSnapshot, matrixBefore), "production scoring mutated its snapshot")
print("PASS: production matrix; core slots; Aspect; Origination; Hammer once; replacement unresolved; status-only uncovered; score=sum")

local ready = {
    { score = 4, eligible = true, covered = true, scoreComplete = true },
    { score = 1, eligible = true, covered = true, scoreComplete = true },
}
check(ScoringEngine.isRankingReady(ready,
    { profileSupported = true, activeDifferentiatingRuleCount = 1 }), "covered differential not ready")
check(not ScoringEngine.isRankingReady(ready,
    { profileSupported = false, activeDifferentiatingRuleCount = 1 }), "unsupported profile ready")
check(not ScoringEngine.isRankingReady({ ready[1] },
    { profileSupported = true, activeDifferentiatingRuleCount = 1 }), "single offer ready")
check(not ScoringEngine.isRankingReady({ ready[1], { score = 1, eligible = true, covered = false } },
    { profileSupported = true, activeDifferentiatingRuleCount = 1 }), "uncovered offer ready")
check(not ScoringEngine.isRankingReady({
    { score = 0, eligible = true, covered = true }, { score = 0, eligible = true, covered = true } },
    { profileSupported = true, activeDifferentiatingRuleCount = 1 }), "equal defaults ready")
check(not ScoringEngine.isRankingReady(ready,
    { profileSupported = true, activeDifferentiatingRuleCount = 0 }), "no active rule ready")
local unresolvedSnapshot = {
    weapon = "WeaponDagger", aspect = "DaggerBackstabAspect", godTraits = {}, hammers = {},
    activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" } },
    offers = {
        { originalIndex = 1, ItemName = "AresCastBoon", Blocked = false },
        { originalIndex = 2, ItemName = "AresManaBoon", Blocked = false },
    },
}
local unresolvedScores = ScoringEngine.scoreOffers(unresolvedSnapshot, productionProfile)
check(unresolvedScores[1].covered and unresolvedScores[1].scoreComplete
    and unresolvedScores[1].score == -4,
    "audited Ares Cast non-status was not complete")
check(unresolvedScores[2].covered and unresolvedScores[2].scoreComplete
    and unresolvedScores[2].score == 4,
    "audited Ares Mana non-status was not complete")
local inactiveComplete = ScoringEngine.scoreOffers({
    weapon = "WeaponDagger", aspect = "DaggerBackstabAspect", godTraits = {}, hammers = {},
    activeArcana = {},
    offers = { { originalIndex = 1, ItemName = "AresCastBoon", Blocked = false } },
}, productionProfile)[1]
check(inactiveComplete.covered and inactiveComplete.scoreComplete
    and inactiveComplete.score == -4,
    "explicit non-target Cast was not complete when Origination inactive")
local knownNonStatusComplete = ScoringEngine.scoreOffers({
    weapon = "WeaponDagger", aspect = "DaggerBackstabAspect", godTraits = {}, hammers = {},
    activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" } },
    offers = { { originalIndex = 1, ItemName = "AresSprintBoon", Blocked = false } },
}, productionProfile)[1]
check(knownNonStatusComplete.covered and knownNonStatusComplete.scoreComplete
    and knownNonStatusComplete.score == 6,
    "preferred Sprint did not produce a complete score")
local equalContext = ScoringEngine.getRankingContext({ matrix[1], matrix[2], matrix[3] }, true)
check(not ScoringEngine.isRankingReady({ matrix[1], matrix[2], matrix[3] }, equalContext),
    "three equal production scores became rankable")
local differentiated = ScoringEngine.scoreOffers(hammerSnapshot, productionProfile)
differentiated[2] = { originalIndex = 2, supported = true, score = 12, eligible = true, covered = true, scoreComplete = true,
    reasons = {{ code = "TEST_RULE_A", delta = 12 }} }
differentiated[3] = { originalIndex = 3, supported = true, score = 8, eligible = true, covered = true, scoreComplete = true,
    reasons = {{ code = "TEST_RULE_B", delta = 8 }} }
local differentiatedContext = ScoringEngine.getRankingContext(differentiated, true)
check(ScoringEngine.isRankingReady(differentiated, differentiatedContext),
    "different fully-covered production scores not ready")
local withUnknown = { differentiated[1], differentiated[2], unknownScore }
check(not ScoringEngine.isRankingReady(withUnknown,
    ScoringEngine.getRankingContext(withUnknown, true)), "uncovered eligible offer became rankable")
local rankedProduction = ScoringEngine.rank(differentiated)
check(rankedProduction[1].score == 16 and rankedProduction[1].originalIndex == 1
    and rankedProduction[2].score == 12 and rankedProduction[2].originalIndex == 2
    and rankedProduction[3].score == 8 and rankedProduction[3].originalIndex == 3,
    "production rank or post-difference tie-break wrong")
local tie124 = ScoringEngine.rank({
    { originalIndex = 1, score = 12, supported = true, eligible = true },
    { originalIndex = 2, score = 12, supported = true, eligible = true },
    { originalIndex = 3, score = 4, supported = true, eligible = true },
})
check(tie124[1].rank == 1 and tie124[2].rank == 1 and tie124[3].rank == 3
    and tie124[1].tied and tie124[2].tied and not tie124[3].tied,
    "competition ranks did not preserve a 12/12/4 tie")
local distinctRanks = ScoringEngine.rank({
    { originalIndex = 1, score = 12, supported = true, eligible = true },
    { originalIndex = 2, score = 8, supported = true, eligible = true },
    { originalIndex = 3, score = 4, supported = true, eligible = true },
})
check(distinctRanks[1].rank == 1 and distinctRanks[2].rank == 2 and distinctRanks[3].rank == 3,
    "distinct scores did not receive distinct gameplay ranks")
check(not ScoringEngine.isRankingReady({
    { score = 12, eligible = true, covered = true },
    { score = 12, eligible = true, covered = true },
    { score = 12, eligible = true, covered = true },
}, { profileSupported = true, activeDifferentiatingRuleCount = 1 }),
    "12/12/12 became ranking-ready")
local lowerTie = ScoringEngine.rank({
    { originalIndex = 1, score = 16, supported = true, eligible = true },
    { originalIndex = 2, score = 12, supported = true, eligible = true },
    { originalIndex = 3, score = 12, supported = true, eligible = true },
})
check(lowerTie[1].rank == 1 and lowerTie[2].rank == 2 and lowerTie[3].rank == 2,
    "16/12/12 did not share the lower gameplay rank")
local nonStatusContext = ScoringEngine.getOriginationContext({
    activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" } },
    godTraits = {},
}, productionProfile, "AresSprintBoon")
check(nonStatusContext.status.statusKnowledge == "known_non_status"
    and nonStatusContext.offerEnablesOrigination == false,
    "verified Ares Sprint non-status was treated as unknown")
local unknownStatusContext = ScoringEngine.getOriginationContext({
    activeArcana = { EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" } },
    godTraits = {},
}, productionProfile, "UnauditedStatusBoon")
check(unknownStatusContext.status.statusKnowledge == "unknown"
    and unknownStatusContext.offerEnablesOrigination == nil,
    "unaudited status was not tri-state unknown")

local planBase = { weapon = "WeaponDagger", aspect = "DaggerBackstabAspect",
    godTraits = {}, hammers = {}, activeArcana = {}, offers = {} }
local plan = deepCopy(planBase)
plan.offers = {
    { originalIndex = 1, ItemName = "AresWeaponBoon" },
    { originalIndex = 2, ItemName = "AphroditeWeaponBoon" },
    { originalIndex = 3, ItemName = "AresSpecialBoon" },
    { originalIndex = 4, ItemName = "ZeusSpecialBoon" },
    { originalIndex = 5, ItemName = "DemeterCastBoon" },
    { originalIndex = 6, ItemName = "AresSprintBoon" },
    { originalIndex = 7, ItemName = "AresManaBoon" },
}
local planned = ScoringEngine.scoreOffers(plan, productionProfile)
check(planned[1].score == 16 and planned[1].reasons[3].code == "BUILD_CORE_PRIORITY",
    "Ares Attack core priority missing")
check(planned[2].score == 12 and #planned[2].reasons == 2,
    "Aphrodite alternative incorrectly received core priority")
check(planned[3].score == 0 and #planned[3].reasons == 2,
    "Ares Special non-target incorrectly filled empty planned slot")
check(planned[4].score == 16 and planned[5].score == 16,
    "planned Zeus Special or Demeter Cast score wrong")
check(planned[6].score == 6 and planned[7].score == 4,
    "preferred Sprint or no-plan Mana score wrong")
local regressionScreen = deepCopy(planBase)
regressionScreen.offers = {
    { originalIndex = 1, ItemName = "AresWeaponBoon" },
    { originalIndex = 2, ItemName = "AresCastBoon" },
    { originalIndex = 3, ItemName = "AresManaBoon" },
}
local regressionScores = ScoringEngine.scoreOffers(regressionScreen, productionProfile)
check(regressionScores[1].score == 16 and regressionScores[1].covered
    and regressionScores[1].scoreComplete and #regressionScores[1].reasons == 3,
    "regression Attack coverage changed")
check(regressionScores[2].score == -4 and regressionScores[2].covered
    and regressionScores[2].scoreComplete and #regressionScores[2].reasons == 1
    and regressionScores[2].reasons[1].code == "BUILD_SLOT_POLICY_DELTA",
    "explicit NON_TARGET Cast was not resolved as zero-valued coverage")
check(regressionScores[3].score == 4 and regressionScores[3].covered
    and regressionScores[3].scoreComplete,
    "no-plan Mana generic coverage changed")
local regressionContext = ScoringEngine.getRankingContext(regressionScores, true)
check(ScoringEngine.isRankingReady(regressionScores, regressionContext),
    "fully resolved 16/0/4 regression screen was not rankable")
local regressionRank = ScoringEngine.rank(regressionScores)
check(regressionRank[1].rank == 1 and regressionRank[1].originalIndex == 1
    and regressionRank[2].rank == 2 and regressionRank[2].originalIndex == 3
    and regressionRank[3].rank == 3 and regressionRank[3].originalIndex == 2,
    "16/-4/4 regression competition ranking wrong")
local nonTargetReplacement = deepCopy(planBase)
nonTargetReplacement.offers = {{ originalIndex = 1, ItemName = "DemeterCastBoon",
    TraitToReplace = "AresCastBoon" }}
local nonTargetReplacementScore = ScoringEngine.scoreOffers(nonTargetReplacement, productionProfile)[1]
check(nonTargetReplacementScore.covered and nonTargetReplacementScore.scoreComplete
    and nonTargetReplacementScore.score == 12
    and nonTargetReplacementScore.reasons[2].code == "BUILD_SLOT_POLICY_DELTA"
    and nonTargetReplacementScore.reasons[2].delta == 4,
    "NON_TARGET old core was treated as unresolved replacement")
local noPlan = deepCopy(productionProfile); noPlan.slots = {}
local noPlanScores = ScoringEngine.scoreOffers(plan, noPlan)
check(noPlanScores[3].score == 12 and noPlanScores[3].covered,
    "profile without slot plan changed generic fill behavior")
local syntheticProfile = deepCopy(productionProfile)
syntheticProfile.id = "synthetic_second_profile"
syntheticProfile.slots = {
    Attack = { core = { "AphroditeWeaponBoon" }, alternatives = {}, preferred = {}, slotPolicy = "reserved" },
    Special = { core = { "AresSpecialBoon" }, alternatives = {}, preferred = {}, slotPolicy = "reserved" },
    Cast = { core = { "ApolloCastBoon" }, alternatives = {}, preferred = {}, slotPolicy = "reserved" },
    Sprint = { core = {}, alternatives = {}, preferred = {}, slotPolicy = "open" },
}
check(ScoringEngine.validateProfile(syntheticProfile), "synthetic second profile rejected")
check(ScoringEngine.getBuildAlignment(syntheticProfile, "Special", "AresSpecialBoon") == "CORE"
    and ScoringEngine.getBuildAlignment(syntheticProfile, "Special", "ZeusSpecialBoon") == "NON_TARGET"
    and ScoringEngine.getBuildAlignment(syntheticProfile, "Mana", "AresManaBoon") == "NO_PLAN",
    "second profile alignment used production-profile assumptions")
local syntheticCore = ScoringEngine.getCoreSlotContext({ godTraits = {} }, syntheticProfile,
    { ItemName = "AresSpecialBoon" })
local syntheticConflict = ScoringEngine.getCoreSlotContext({ godTraits = {} }, syntheticProfile,
    { ItemName = "ZeusSpecialBoon" })
check(not syntheticCore.slotConflict and syntheticConflict.slotConflict,
    "second profile slot conflict was not data-driven")
local tiePlan = { weapon = plan.weapon, aspect = plan.aspect, godTraits = {}, hammers = {},
    activeArcana = {}, offers = {
        { originalIndex = 1, ItemName = "AresSpecialBoon" },
        { originalIndex = 2, ItemName = "AresSprintBoon" },
        { originalIndex = 3, ItemName = "AresManaBoon" },
    }}
local tieScores = ScoringEngine.scoreOffers(tiePlan, productionProfile)
check(tieScores[2].score == 6 and tieScores[1].score == 0 and tieScores[3].score == 4,
    "6/4/4 build-plan calibration wrong")
for _, rarity in ipairs({ "Common", "Rare", "Epic", "Heroic" }) do
    local special = deepCopy(planBase)
    special.offers = {{ originalIndex = 1, ItemName = "AresSpecialBoon", Rarity = rarity }}
    local result = ScoringEngine.scoreOffers(special, productionProfile)[1]
    local expected = ({ Common = 0, Rare = 1, Epic = 2, Heroic = 3 })[rarity]
    check(result.score == expected and result.score == (function()
        local sum = 0 for _, reason in ipairs(result.reasons) do sum = sum + reason.delta end return sum end)(),
        "reserved Special conflict policy score wrong for " .. rarity)
end
for _, rarity in ipairs({ "Common", "Rare", "Epic", "Heroic" }) do
    local cast = deepCopy(planBase)
    cast.offers = {{ originalIndex = 1, ItemName = "AresCastBoon", Rarity = rarity }}
    local result = ScoringEngine.scoreOffers(cast, productionProfile)[1]
    local expected = ({ Common = -4, Rare = -3, Epic = -2, Heroic = -1 })[rarity]
    check(result.score == expected, "reserved Cast conflict policy score wrong for " .. rarity)
end
local replacementPriority = deepCopy(planBase)
replacementPriority.offers = {{ originalIndex = 1, ItemName = "ZeusSpecialBoon",
    TraitToReplace = "AresSpecialBoon" }}
local replacementPriorityScore = ScoringEngine.scoreOffers(replacementPriority, productionProfile)[1]
check(replacementPriorityScore.score == 8 and replacementPriorityScore.reasons[1].delta == 4
    and replacementPriorityScore.reasons[2].code == "BUILD_SLOT_POLICY_DELTA"
    and replacementPriorityScore.reasons[2].delta == 4,
    "build priority replacement delta was not +4")
local replacementPriorityDown = deepCopy(planBase)
replacementPriorityDown.offers = {{ originalIndex = 1, ItemName = "AresSpecialBoon",
    TraitToReplace = "ZeusSpecialBoon" }}
local replacementPriorityDownScore = ScoringEngine.scoreOffers(replacementPriorityDown, productionProfile)[1]
check(replacementPriorityDownScore.score == -8
    and replacementPriorityDownScore.reasons[2].code == "BUILD_SLOT_POLICY_DELTA"
    and replacementPriorityDownScore.reasons[2].delta == -4,
    "build priority replacement delta was not -4")
local coreToAlternative = deepCopy(planBase)
coreToAlternative.godTraits = { { Name = "AresWeaponBoon", Slot = "Melee" } }
coreToAlternative.offers = {{ originalIndex = 1, ItemName = "AphroditeWeaponBoon",
    TraitToReplace = "AresWeaponBoon" }}
local coreToAlternativeContext = ScoringEngine.getCoreSlotContext(coreToAlternative,
    productionProfile, coreToAlternative.offers[1])
local coreToAlternativeScore = ScoringEngine.scoreOffers(coreToAlternative, productionProfile)[1]
check(coreToAlternativeContext.alignment == "ALTERNATIVE"
    and coreToAlternativeContext.slotStateBefore == "CORE"
    and coreToAlternativeContext.slotStateAfter == "ALTERNATIVE"
    and not coreToAlternativeContext.slotConflict
    and not coreToAlternativeContext.conflictIntroduced
    and not coreToAlternativeContext.conflictResolved
    and not coreToAlternativeContext.coreSacrificed,
    "CORE to ALTERNATIVE transition metadata was wrong")
check(coreToAlternativeScore.covered and coreToAlternativeScore.scoreComplete
    and coreToAlternativeScore.score == -4,
    "audited CORE to ALTERNATIVE replacement was unresolved")
local coreToAlternativeOrigination = deepCopy(coreToAlternative)
coreToAlternativeOrigination.activeArcana = {
    EffectVulnerabilityMetaUpgrade = { Rarity = "Epic" },
}
local unresolvedAlternative = ScoringEngine.scoreOffers(coreToAlternativeOrigination,
    productionProfile)[1]
check(unresolvedAlternative.covered and unresolvedAlternative.scoreComplete
    and unresolvedAlternative.reasons[1].code ~= "REPLACEMENT_UNRESOLVED",
    "audited Aphrodite non-status replacement remained unresolved")
local alternativeToCore = deepCopy(planBase)
alternativeToCore.godTraits = { { Name = "AphroditeWeaponBoon", Slot = "Melee" } }
alternativeToCore.offers = {{ originalIndex = 1, ItemName = "AresWeaponBoon",
    TraitToReplace = "AphroditeWeaponBoon" }}
local alternativeToCoreContext = ScoringEngine.getCoreSlotContext(alternativeToCore,
    productionProfile, alternativeToCore.offers[1])
check(alternativeToCoreContext.slotStateBefore == "ALTERNATIVE"
    and alternativeToCoreContext.slotStateAfter == "CORE"
    and not alternativeToCoreContext.conflictResolved and not alternativeToCoreContext.slotConflict,
    "ALTERNATIVE to CORE transition metadata was wrong")
local coreToNonTarget = deepCopy(planBase)
coreToNonTarget.godTraits = { { Name = "AresWeaponBoon", Slot = "Melee" } }
coreToNonTarget.offers = {{ originalIndex = 1, ItemName = "ZeusWeaponBoon",
    TraitToReplace = "AresWeaponBoon" }}
local coreToNonTargetContext = ScoringEngine.getCoreSlotContext(coreToNonTarget,
    productionProfile, coreToNonTarget.offers[1])
check(coreToNonTargetContext.slotStateBefore == "CORE"
    and coreToNonTargetContext.slotStateAfter == "NON_TARGET"
    and coreToNonTargetContext.slotConflict and coreToNonTargetContext.conflictIntroduced
    and coreToNonTargetContext.coreSacrificed,
    "CORE to NON_TARGET transition metadata was wrong")
local nonTargetToCore = deepCopy(planBase)
nonTargetToCore.godTraits = { { Name = "ZeusWeaponBoon", Slot = "Melee" } }
nonTargetToCore.offers = {{ originalIndex = 1, ItemName = "AresWeaponBoon",
    TraitToReplace = "ZeusWeaponBoon" }}
local nonTargetToCoreContext = ScoringEngine.getCoreSlotContext(nonTargetToCore,
    productionProfile, nonTargetToCore.offers[1])
check(nonTargetToCoreContext.slotStateBefore == "NON_TARGET"
    and nonTargetToCoreContext.slotStateAfter == "CORE"
    and nonTargetToCoreContext.conflictResolved and not nonTargetToCoreContext.slotConflict,
    "NON_TARGET to CORE transition metadata was wrong")
local profileBeforePlan = deepCopy(productionProfile)
ScoringEngine.scoreOffers(plan, productionProfile)
check(deepEqual(profileBeforePlan, productionProfile), "build plan scoring mutated profile")
local rarityBase = { weapon = "WeaponDagger", aspect = "DaggerBackstabAspect",
    godTraits = {}, hammers = {}, activeArcana = {}, offers = {} }
local function rarityScore(name, rarity)
    local snapshot = deepCopy(rarityBase)
    snapshot.offers = {{ originalIndex = 1, ItemName = name, Rarity = rarity }}
    return ScoringEngine.scoreOffers(snapshot, productionProfile)[1]
end
local common = rarityScore("AresSpecialBoon", "Common")
local rare = rarityScore("AresSpecialBoon", "Rare")
local epic = rarityScore("AresSpecialBoon", "Epic")
local heroic = rarityScore("AresSpecialBoon", "Heroic")
check(common.score == 0 and #common.reasons == 2, "Common rarity/policy score changed")
check(rare.score == 1 and epic.score == 2 and heroic.score == 3,
    "Common/Rare/Epic/Heroic rarity policy wrong")
local duo = rarityScore("AresSpecialBoon", "Duo")
local legendary = rarityScore("AresSpecialBoon", "Legendary")
check(duo.score == 0 and legendary.score == 0 and duo.scoreComplete and legendary.scoreComplete,
    "Duo/Legendary incorrectly changed rarity score or completeness")
local unknownRarity = rarityScore("FocusRawDamageBoon", "Heroic")
check(not unknownRarity.covered and not unknownRarity.scoreComplete and unknownRarity.score == 0
    and #unknownRarity.reasons == 0, "unknown Heroic support received rarity coverage")
local nonTargetRarity = rarityScore("AresCastBoon", "Heroic")
check(nonTargetRarity.covered and nonTargetRarity.scoreComplete and nonTargetRarity.score == -1
    and nonTargetRarity.reasons[2].code == "RARITY", "NON_TARGET Heroic rarity was not applied")
local replacementRarity = deepCopy(rarityBase)
replacementRarity.godTraits = {{ Name = "AresSpecialBoon", Slot = "Secondary" }}
replacementRarity.offers = {{ originalIndex = 1, ItemName = "ZeusSpecialBoon",
    TraitToReplace = "AresSpecialBoon", OldRarity = "Epic", Rarity = "Heroic" }}
local replacementRarityScore = ScoringEngine.scoreOffers(replacementRarity, productionProfile)[1]
check(replacementRarityScore.score == 9 and replacementRarityScore.scoreComplete
    and replacementRarityScore.reasons[3].code == "RARITY_DELTA"
    and replacementRarityScore.reasons[3].delta == 1,
    "Epic to Heroic replacement rarity delta wrong")
local missingOldRarity = deepCopy(replacementRarity)
missingOldRarity.offers[1].OldRarity = nil
local missingOldResult = ScoringEngine.scoreOffers(missingOldRarity, productionProfile)[1]
check(not missingOldResult.scoreComplete and missingOldResult.reasons[#missingOldResult.reasons].code == "RARITY_UNRESOLVED",
    "missing OldRarity was not conservatively unresolved")
local noDoubleRarity = 0
for _, reason in ipairs(replacementRarityScore.reasons) do
    if reason.code == "RARITY" then noDoubleRarity = noDoubleRarity + 1 end
end
check(noDoubleRarity == 0, "replacement received absolute RARITY and RARITY_DELTA")
local statusSynergy = deepCopy(rarityBase)
statusSynergy.godTraits = {{ Name = "AresWeaponBoon" }}
statusSynergy.offers = {{ originalIndex = 1, ItemName = "AresStatusDoubleDamageBoon", Rarity = "Epic" }}
local statusSynergyScore = ScoringEngine.scoreOffers(statusSynergy, productionProfile)[1]
check(statusSynergyScore.score == 6 and statusSynergyScore.covered and statusSynergyScore.scoreComplete
    and statusSynergyScore.reasons[1].code == "BUILD_STATUS_SYNERGY"
    and statusSynergyScore.reasons[2].code == "RARITY",
    "Curse capability synergy was not scored")
do
local lightningBase = { weapon = "WeaponDagger", aspect = "DaggerTripleAspect",
    godTraits = {}, hammers = {}, activeArcana = {}, offers = {{ originalIndex = 1, ItemName = "LightningVulnerabilityBoon" }} }
local function lightningScore(traits, profile)
    local snapshot = deepCopy(lightningBase)
    snapshot.godTraits = traits
    return ScoringEngine.scoreOffers(snapshot, profile)[1]
end
for _, traits in ipairs({ {}, {{ Name = "PoseidonCastBoon" }}, {{ Name = "ZeusSpecialBoon" }} }) do
    local score = lightningScore(traits, morriganProfile)
    local context = ScoringEngine.getOriginationContext({
        activeArcana = {}, godTraits = traits,
    }, morriganProfile, "LightningVulnerabilityBoon")
    check(score.score == 0 and not score.covered and not score.scoreComplete
        and context.status.statusKnowledge == "known_non_status"
        and context.offerEnablesOrigination == false
        and #score.reasons == 0,
        "Lightning Duo incorrectly covered without both owned prerequisites")
end
local lightningBoth = lightningScore({ { Name = "ZeusSpecialBoon" }, { Name = "PoseidonCastBoon" } }, morriganProfile)
check(lightningBoth.score == 4 and lightningBoth.covered and lightningBoth.scoreComplete
    and #lightningBoth.reasons == 1 and lightningBoth.reasons[1].code == "BUILD_STATUS_SYNERGY"
    and lightningBoth.reasons[1].delta == 4,
    "Lightning Duo owned-build synergy was not scored exactly")
local melinoeLightningSnapshot = deepCopy(lightningBase)
melinoeLightningSnapshot.aspect = "DaggerBackstabAspect"
melinoeLightningSnapshot.godTraits = { { Name = "PoseidonCastBoon" }, { Name = "ZeusSpecialBoon" } }
local melinoeLightning = ScoringEngine.scoreOffers(melinoeLightningSnapshot, productionProfile)[1]
check(melinoeLightning.score == 0 and not melinoeLightning.covered and not melinoeLightning.scoreComplete,
    "Lightning Duo leaked Morrigan-only rule into Melinoe")
end
local noStatusSynergy = deepCopy(rarityBase)
noStatusSynergy.offers = {{ originalIndex = 1, ItemName = "AresStatusDoubleDamageBoon", Rarity = "Epic" }}
local noStatusSynergyScore = ScoringEngine.scoreOffers(noStatusSynergy, productionProfile)[1]
check(noStatusSynergyScore.score == 0 and not noStatusSynergyScore.covered
    and not noStatusSynergyScore.scoreComplete and #noStatusSynergyScore.reasons == 0,
    "Curse capability was invented without a producer")
local bloodDropSynergy = deepCopy(rarityBase)
bloodDropSynergy.godTraits = {{ Name = "AresManaBoon" }}
bloodDropSynergy.offers = {{ originalIndex = 1, ItemName = "DoubleBloodDropBoon", Rarity = "Common" }}
local bloodDropScore = ScoringEngine.scoreOffers(bloodDropSynergy, productionProfile)[1]
check(bloodDropScore.score == 4 and bloodDropScore.covered and bloodDropScore.scoreComplete
    and bloodDropScore.reasons[1].code == "BLOOD_DROP_ENGINE_SYNERGY",
    "BloodDrop producer/payoff synergy was not scored")
local revengeBloodDrop = deepCopy(rarityBase)
revengeBloodDrop.godTraits = {{ Name = "BloodDropRevengeBoon" }}
revengeBloodDrop.offers = {{ originalIndex = 1, ItemName = "RendBloodDropBoon", Rarity = "Common" }}
local revengeBloodDropScore = ScoringEngine.scoreOffers(revengeBloodDrop, productionProfile)[1]
check(revengeBloodDropScore.score == 4 and revengeBloodDropScore.covered
    and revengeBloodDropScore.scoreComplete,
    "BloodDropRevenge producer did not enable Rend payoff synergy")
local inverseBloodDrop = deepCopy(rarityBase)
inverseBloodDrop.godTraits = {{ Name = "DoubleBloodDropBoon" }}
inverseBloodDrop.offers = {{ originalIndex = 1, ItemName = "AresManaBoon", Rarity = "Common" }}
local inverseBloodDropScore = ScoringEngine.scoreOffers(inverseBloodDrop, productionProfile)[1]
check(inverseBloodDropScore.score == 4 and inverseBloodDropScore.covered
    and #inverseBloodDropScore.reasons == 1
    and inverseBloodDropScore.reasons[1].code == "FILL_EMPTY_UTILITY_CORE",
    "unsupported BloodDrop producer/payoff symmetry was introduced")
local inverseRevenge = deepCopy(rarityBase)
inverseRevenge.godTraits = {{ Name = "RendBloodDropBoon" }}
inverseRevenge.offers = {{ originalIndex = 1, ItemName = "BloodDropRevengeBoon", Rarity = "Common" }}
local inverseRevengeScore = ScoringEngine.scoreOffers(inverseRevenge, productionProfile)[1]
check(inverseRevengeScore.score == 0 and not inverseRevengeScore.covered,
    "unsupported BloodDrop producer symmetry was introduced")
local noBloodDrop = deepCopy(rarityBase)
noBloodDrop.offers = {{ originalIndex = 1, ItemName = "DoubleBloodDropBoon", Rarity = "Epic" }}
local noBloodDropScore = ScoringEngine.scoreOffers(noBloodDrop, productionProfile)[1]
check(noBloodDropScore.score == 0 and not noBloodDropScore.covered
    and not noBloodDropScore.scoreComplete,
    "BloodDrop payoff was scored without a producer")
for _, deferredName in ipairs({ "MissingHealthCritBoon",
    "OmegaDelayedDamageBoon", "AresExCastBoon" }) do
    local deferred = rarityScore(deferredName, "Heroic")
    check(deferred.score == 0 and not deferred.covered and not deferred.scoreComplete,
        deferredName .. " was no longer deferred")
end
for _, hp in ipairs({ 20, 39, 40, 80 }) do
    local lowHealth = deepCopy(rarityBase)
    lowHealth.combatContext = { health = { current = hp, max = 100 } }
    lowHealth.offers = {{ originalIndex = 1, ItemName = "LowHealthLifestealBoon", Rarity = "Common" }}
    local lowResult = ScoringEngine.scoreOffers(lowHealth, productionProfile)[1]
    check(lowResult.score == 2 and lowResult.covered and lowResult.scoreComplete
        and lowResult.condition.currentlyActive == (hp < 40)
        and #lowResult.reasons == 1 and lowResult.reasons[1].code == "SURVIVAL_SUPPORT",
        "LowHealth structural score or condition metadata changed at HP " .. tostring(hp))
end
local lowHealthMissing = deepCopy(rarityBase)
lowHealthMissing.offers = {{ originalIndex = 1, ItemName = "LowHealthLifestealBoon", Rarity = "Epic" }}
local lowMissingResult = ScoringEngine.scoreOffers(lowHealthMissing, productionProfile)[1]
check(lowMissingResult.score == 4 and lowMissingResult.covered and lowMissingResult.scoreComplete
    and lowMissingResult.condition.currentlyActive == nil,
    "missing health did not preserve LowHealth structural scoring")
for _, rarity in ipairs({ "Common", "Rare", "Epic", "Heroic" }) do
    local low = deepCopy(rarityBase)
    low.offers = {{ originalIndex = 1, ItemName = "LowHealthLifestealBoon", Rarity = rarity }}
    local result = ScoringEngine.scoreOffers(low, productionProfile)[1]
    local expected = ({ Common = 2, Rare = 3, Epic = 4, Heroic = 5 })[rarity]
    check(result.score == expected and result.scoreComplete and result.score == (function()
        local sum = 0 for _, reason in ipairs(result.reasons) do sum = sum + reason.delta end return sum end)(),
        "LowHealth rarity score wrong for " .. rarity)
end
print("PASS: rankingReady requires support, 2 eligible, full gameplay coverage, active rule, distinct scores")

-- Phase 5J-A: both real sheet profiles share mechanics but retain distinct plans.
local starterPlan = deepCopy(planBase)
starterPlan.offers = {
    { originalIndex = 1, ItemName = "AphroditeWeaponBoon" },
    { originalIndex = 2, ItemName = "ZeusSpecialBoon" },
    { originalIndex = 3, ItemName = "AresWeaponBoon" },
    { originalIndex = 4, ItemName = "AresCastBoon" },
    { originalIndex = 5, ItemName = "AresSprintBoon" },
    { originalIndex = 6, ItemName = "AresManaBoon" },
}
local starterScores = ScoringEngine.scoreOffers(starterPlan, starterProfile)
local intermediateScores = ScoringEngine.scoreOffers(starterPlan, productionProfile)
check(starterScores[1].score == 16 and starterScores[1].covered and starterScores[1].scoreComplete
    and starterScores[1].reasons[3].code == "BUILD_CORE_PRIORITY",
    "Starter Aphrodite Attack core plan was not applied")
check(starterScores[2].score == 16 and starterScores[2].covered and starterScores[2].scoreComplete
    and starterScores[2].reasons[3].code == "BUILD_CORE_PRIORITY",
    "Starter Zeus Special core plan was not applied")
check(ScoringEngine.getBuildAlignment(starterProfile, "Attack", "AresWeaponBoon") == "NON_TARGET"
    and ScoringEngine.getBuildAlignment(productionProfile, "Attack", "AresWeaponBoon") == "CORE",
    "same Attack offer did not differ by real profile plan")
check(starterScores[3].score == 0 and starterScores[3].covered and starterScores[3].scoreComplete,
    "Starter known Attack non-target was not resolved at zero")
local starterCast = ScoringEngine.getCoreSlotContext(starterPlan, starterProfile, starterPlan.offers[4])
check(starterCast.alignment == "NO_PLAN" and starterScores[4].score == 8,
    "omitted Starter Cast did not preserve no-plan behavior")
local starterSprint = ScoringEngine.getCoreSlotContext(starterPlan, starterProfile, starterPlan.offers[5])
check(starterSprint.alignment == "NON_TARGET" and starterSprint.slotPolicy == "open"
    and not starterSprint.slotConflict and starterScores[5].score == 4
    and starterScores[5].reasons[1].code == "FILL_EMPTY_UTILITY_CORE"
    and starterScores[5].covered and starterScores[5].scoreComplete,
    "flexible Starter Sprint was treated as a reserved conflict")
check(starterScores[6].score == intermediateScores[6].score and starterScores[6].covered
    and intermediateScores[6].covered,
    "shared no-plan Mana mechanics changed across profiles")
local starterReplacement = deepCopy(planBase)
starterReplacement.godTraits = {{ Name = "AresWeaponBoon", Slot = "Melee" }}
starterReplacement.offers = {{ originalIndex = 1, ItemName = "AphroditeWeaponBoon",
    TraitToReplace = "AresWeaponBoon" }}
local starterReplacementResult = ScoringEngine.scoreOffers(starterReplacement, starterProfile)[1]
check(starterReplacementResult.covered and starterReplacementResult.scoreComplete
    and starterReplacementResult.score == 8,
    "Starter non-target to Core replacement transition was not resolved")
for _, resultsForProfile in ipairs({ starterScores, intermediateScores, { starterReplacementResult } }) do
    for _, result in ipairs(resultsForProfile) do
        local sum = 0
        for _, reason in ipairs(result.reasons) do sum = sum + reason.delta end
        check(result.score == sum, "real profile score differs from reason sum")
    end
end
local starterBefore = deepCopy(starterProfile)
ScoringEngine.scoreOffers(starterPlan, starterProfile)
check(deepEqual(starterProfile, starterBefore), "Starter profile was mutated")
print("PASS: real Starter and Intermediate profiles validate; plan alignment, open Sprint, no-plan Cast, replacement, shared mechanics, and no mutation")
