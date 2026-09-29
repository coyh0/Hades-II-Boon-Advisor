local ScoringEngine = {}

local coreRoles = {
    coreAttack = { slot = "Melee", role = "Attack" },
    coreSpecial = { slot = "Secondary", role = "Special" },
    coreCast = { slot = "Ranged", role = "Cast" },
    coreSprint = { slot = "Rush", role = "Sprint" },
    coreMana = { slot = "Mana", role = "Mana" },
}
local recognizedRoles = { Attack = true, Special = true, Cast = true, Sprint = true, Mana = true }
local slotPolicies = { reserved = true, preferred = true, open = true }
local verifiedGodOfferSources = {
    Aphrodite = "AphroditeUpgrade", Apollo = "ApolloUpgrade", Ares = "AresUpgrade",
    Demeter = "DemeterUpgrade", Hephaestus = "HephaestusUpgrade", Hera = "HeraUpgrade",
    Hestia = "HestiaUpgrade", Poseidon = "PoseidonUpgrade", Zeus = "ZeusUpgrade",
}

local function profileSlots(profile)
    return type(profile) == "table" and type(profile.slots) == "table" and profile.slots or nil
end

function ScoringEngine.validateProfile(profile)
    if type(profile) ~= "table" then return false, "profile must be a table" end
    if profile.schemaVersion ~= 1 then return false, "unsupported schemaVersion" end
    for _, field in ipairs({ "id", "weapon", "aspect", "profileMode" }) do
        if type(profile[field]) ~= "string" or profile[field] == "" then
            return false, field .. " must be a non-empty string"
        end
    end
    local slots = profileSlots(profile)
    if slots == nil then return false, "slots must be a table" end
    for role, definition in pairs(slots) do
        if not recognizedRoles[role] then return false, "unknown slot role " .. tostring(role) end
        if type(definition) ~= "table" then return false, "slot " .. role .. " must be a table" end
        if not slotPolicies[definition.slotPolicy] then
            return false, "invalid slotPolicy for " .. role
        end
        local seen = {}
        for _, listName in ipairs({ "core", "alternatives", "preferred", "discouraged" }) do
            local list = definition[listName]
            if listName == "discouraged" and list == nil then list = {} end
            if type(list) ~= "table" then return false, role .. "." .. listName .. " must be a table" end
            for _, traitName in ipairs(list) do
                if type(traitName) ~= "string" or traitName == "" then
                    return false, role .. "." .. listName .. " has invalid trait ID"
                end
                if seen[traitName] then return false, role .. " repeats " .. traitName end
                seen[traitName] = true
            end
        end
        if definition.branches ~= nil then
            if role ~= "Attack" or type(definition.branches) ~= "table" or #definition.branches == 0 then
                return false, "branches must be a non-empty Attack array"
            end
            for _, branch in ipairs(definition.branches) do
                if type(branch) ~= "table" or type(branch.traitId) ~= "string" or branch.traitId == ""
                    or seen[branch.traitId] then return false, "duplicate or invalid Attack branch" end
                for key in pairs(branch) do
                    if key ~= "traitId" and key ~= "classification" and key ~= "priority"
                        and key ~= "condition" then return false, "unknown Attack branch field" end
                end
                seen[branch.traitId] = true
                if branch.classification ~= "alternative" and branch.classification ~= "conditional" then
                    return false, "unknown Attack branch classification"
                end
                if type(branch.priority) ~= "number" or branch.priority <= 0
                    or branch.priority % 1 ~= 0 then return false, "invalid Attack branch priority" end
                if branch.classification == "conditional" then
                    if type(branch.condition) ~= "table" or branch.condition.state ~= "unresolved"
                        or branch.condition.code ~= "WOUNDS_ACCESS" then
                        return false, "unknown Attack branch condition"
                    end
                    for key in pairs(branch.condition) do
                        if key ~= "state" and key ~= "code" then
                            return false, "unknown Attack branch condition field"
                        end
                    end
                elseif branch.condition ~= nil then return false, "unexpected Attack branch condition" end
            end
        end
    end
    if profile.hammerPlan ~= nil then
        if type(profile.hammerPlan) ~= "table" then return false, "hammerPlan must be a table" end
        local seen = {}
        for _, entry in ipairs(profile.hammerPlan) do
            if type(entry) ~= "table" then return false, "hammerPlan entry must be a table" end
            if type(entry.traitId) ~= "string" or entry.traitId == "" then
                return false, "hammerPlan entry has invalid trait ID"
            end
            if seen[entry.traitId] then return false, "hammerPlan repeats " .. entry.traitId end
            seen[entry.traitId] = true
            if type(entry.priority) ~= "number" or entry.priority <= 0 or entry.priority % 1 ~= 0 then
                return false, "hammerPlan entry has invalid priority"
            end
            if entry.classification ~= "priority" and entry.classification ~= "alternative" then
                return false, "hammerPlan entry has invalid classification"
            end
            if entry.condition ~= nil and (type(entry.condition) ~= "string" or entry.condition == "") then
                return false, "hammerPlan entry has invalid condition metadata"
            end
        end
    end
    if profile.sourceScoring ~= nil then
        local sourceScoring = profile.sourceScoring
        if type(sourceScoring) ~= "table" then return false, "sourceScoring must be a table" end
        if type(profile.source) ~= "table" or profile.source.type ~= "mobalytics" then
            return false, "sourceScoring is restricted to Mobalytics profiles"
        end
        local allowed = {
            boons = { ["Core Boons"] = true, ["Non-Core Boons"] = true, ["NPC Offerings"] = true },
            hammers = { ["Daedalus Hammer Upgrades"] = true },
            poms = { ["Poms of Power"] = true },
            deferred = { ["Legendary / Duo Boons"] = true },
        }
        for kind, groups in pairs(allowed) do
            if type(sourceScoring[kind]) ~= "table" then return false, "sourceScoring." .. kind .. " must be a table" end
            for traitName, group in pairs(sourceScoring[kind]) do
                if type(traitName) ~= "string" or traitName == "" or not groups[group] then
                    return false, "invalid sourceScoring." .. kind .. " entry"
                end
            end
        end
        for traitName in pairs(sourceScoring.deferred) do
            if sourceScoring.boons[traitName] or sourceScoring.hammers[traitName]
                or sourceScoring.poms[traitName] then
                return false, "deferred source recommendation also has an active score"
            end
        end
        if type(sourceScoring.npcOfferings) ~= "table" then
            return false, "sourceScoring.npcOfferings must be a table"
        end
        local verifiedNpcSources = { NPC_Athena_01 = true, NPC_Hades_Field_01 = true }
        for traitName, sourceName in pairs(sourceScoring.npcOfferings) do
            if type(traitName) ~= "string" or traitName == ""
                or sourceScoring.boons[traitName] ~= "NPC Offerings"
                or not verifiedNpcSources[sourceName] then
                return false, "invalid sourceScoring.npcOfferings entry"
            end
        end
        for traitName, group in pairs(sourceScoring.boons) do
            if group == "NPC Offerings" and sourceScoring.npcOfferings[traitName] == nil then
                return false, "NPC Offering requires a verified source/item mapping"
            end
        end
        local corePlan = profile.corePlan
        local nonCoreContext = profile.nonCoreContext
        if type(corePlan) ~= "table" or type(nonCoreContext) ~= "table" then
            return false, "sourceScoring profiles require corePlan and nonCoreContext tables"
        end
        local expectedCoreCount = 0
        for traitId, group in pairs(sourceScoring.boons) do
            if group == "Core Boons" then
                expectedCoreCount = expectedCoreCount + 1
                local entry = corePlan[traitId]
                if type(entry) ~= "table" then return false, "Core boon missing from corePlan: " .. traitId end
                if not recognizedRoles[entry.role] then return false, "invalid corePlan role for " .. traitId end
                if type(entry.displayName) ~= "table"
                    or type(entry.displayName.en) ~= "string" or entry.displayName.en == ""
                    or type(entry.displayName.fr) ~= "string" or entry.displayName.fr == "" then
                    return false, "corePlan requires English and French displayName for " .. traitId
                end
                for key in pairs(entry) do
                    if key ~= "role" and key ~= "displayName" then
                        return false, "unknown corePlan field for " .. traitId
                    end
                end
                for language in pairs(entry.displayName) do
                    if language ~= "en" and language ~= "fr" then
                        return false, "unknown corePlan displayName language for " .. traitId
                    end
                end
            end
        end
        local actualCoreCount = 0
        for traitId in pairs(corePlan) do
            actualCoreCount = actualCoreCount + 1
            if sourceScoring.boons[traitId] ~= "Core Boons" then
                return false, "corePlan trait is not classified Core Boons: " .. tostring(traitId)
            end
        end
        if actualCoreCount ~= expectedCoreCount then return false, "corePlan does not match Core Boons source map" end
        for traitId, entry in pairs(nonCoreContext) do
            if sourceScoring.boons[traitId] ~= "Non-Core Boons" or type(entry) ~= "table"
                or type(entry.recommendedCore) ~= "table" or #entry.recommendedCore == 0 then
                return false, "invalid nonCoreContext entry for " .. tostring(traitId)
            end
            for key in pairs(entry) do
                if key ~= "recommendedCore" then return false, "unknown nonCoreContext field for " .. traitId end
            end
            local seenCore = {}
            local targetCount = 0
            for _ in pairs(entry.recommendedCore) do targetCount = targetCount + 1 end
            if targetCount ~= #entry.recommendedCore then
                return false, "nonCoreContext targets must be a dense array for " .. traitId
            end
            for _, coreId in ipairs(entry.recommendedCore) do
                if type(coreId) ~= "string" or corePlan[coreId] == nil or seenCore[coreId] then
                    return false, "nonCoreContext target must be a unique declared Core: " .. tostring(coreId)
                end
                seenCore[coreId] = true
            end
        end
    end
    if profile.godPool ~= nil then
        if type(profile.source) ~= "table" or profile.source.type ~= "mobalytics"
            or type(profile.godPool) ~= "table" then
            return false, "godPool requires a Mobalytics profile and an array"
        end
        local seenRecommendations, seenGods, seenSources, count = {}, {}, {}, 0
        for index, entry in pairs(profile.godPool) do
            if type(index) ~= "number" or index < 1 or index % 1 ~= 0 or type(entry) ~= "table" then
                return false, "godPool must be a dense array of mappings"
            end
            count = count + 1
            if type(entry.recommendationId) ~= "string" or entry.recommendationId == ""
                or type(entry.sourceGod) ~= "string" or type(entry.offerSource) ~= "string" then
                return false, "godPool mapping requires recommendationId, sourceGod, and offerSource"
            end
            if not entry.recommendationId:match("^mobalytics_[a-z0-9_]+_fullbuild_god_pool_[a-z0-9_]+_[0-9][0-9]$") then
                return false, "godPool mapping has an invalid stable Mobalytics recommendation ID"
            end
            if seenRecommendations[entry.recommendationId] or seenGods[entry.sourceGod]
                or seenSources[entry.offerSource] then
                return false, "godPool contains a duplicate recommendation, god, or offer source"
            end
            if verifiedGodOfferSources[entry.sourceGod] ~= entry.offerSource then
                return false, "godPool contains an unknown or mismatched verified god offer source"
            end
            local idGod = entry.recommendationId:match("_fullbuild_god_pool_([a-z]+)_[0-9][0-9]$")
            if idGod ~= string.lower(entry.sourceGod) then
                return false, "godPool recommendation ID does not match its source god"
            end
            for key in pairs(entry) do
                if key ~= "recommendationId" and key ~= "sourceGod" and key ~= "offerSource" then
                    return false, "unknown godPool mapping field: " .. tostring(key)
                end
            end
            seenRecommendations[entry.recommendationId] = true
            seenGods[entry.sourceGod] = true
            seenSources[entry.offerSource] = true
        end
        if count ~= #profile.godPool then return false, "godPool must be dense" end
    end
    return true
end
local function addReason(result, code, delta, with)
    local reason = { code = code, delta = delta }
    if with ~= nil then reason.with = with end
    result.reasons[#result.reasons + 1] = reason
    result.score = result.score + delta
end

local rarityValues = { Common = 0, Rare = 1, Epic = 2, Heroic = 3 }
local nonComparableRarities = { Duo = true, Legendary = true }

local function rarityValue(value)
    return rarityValues[value]
end

local function rarityDelta(result, newRarity, oldRarity, replacement)
    if newRarity == nil then return true end
    if nonComparableRarities[newRarity] then return true end
    local newValue = rarityValue(newRarity)
    if newValue == nil then
        addReason(result, "RARITY_UNRESOLVED", 0)
        return false
    end
    if replacement then
        if oldRarity == nil or nonComparableRarities[oldRarity] then
            if oldRarity == nil then addReason(result, "RARITY_UNRESOLVED", 0) end
            return oldRarity ~= nil
        end
        local oldValue = rarityValue(oldRarity)
        if oldValue == nil then
            addReason(result, "RARITY_UNRESOLVED", 0)
            return false
        end
        local delta = newValue - oldValue
        if delta ~= 0 then addReason(result, "RARITY_DELTA", delta) end
    else
        if newValue ~= 0 then addReason(result, "RARITY", newValue) end
    end
    return true
end

local function ownedGodTraits(snapshot)
    local owned = {}
    for _, trait in ipairs(type(snapshot.godTraits) == "table" and snapshot.godTraits or {}) do
        if type(trait) == "table" and type(trait.Name) == "string" then
            owned[trait.Name] = true
        end
    end
    return owned
end

local function buildCanProduceStatus(snapshot, profile, family)
    local capability = type(profile.statusCapabilityTraits) == "table"
        and profile.statusCapabilityTraits[family] or nil
    if type(capability) ~= "table" then return false end
    local owned = ownedGodTraits(snapshot)
    for traitName in pairs(capability) do
        if owned[traitName] then return true end
    end
    return false
end

local function hasBloodDropProducer(snapshot, profile)
    local engine = type(profile.bloodDropEngine) == "table" and profile.bloodDropEngine or nil
    local producers = engine and engine.producers or nil
    if type(producers) ~= "table" then return false end
    local owned = ownedGodTraits(snapshot)
    for traitName in pairs(producers) do
        if owned[traitName] then return true end
    end
    return false
end

local function firstOwned(owned, names)
    for _, name in ipairs(type(names) == "table" and names or {}) do
        if owned[name] then return name end
    end
end

local function ownedHammers(snapshot)
    local owned = {}
    for _, trait in ipairs(type(snapshot.hammers) == "table" and snapshot.hammers or {}) do
        if type(trait) == "table" and type(trait.Name) == "string" then
            owned[trait.Name] = true
        end
    end
    return owned
end

local function weight(profile, code)
    local value = type(profile.weights) == "table" and profile.weights[code] or nil
    return type(value) == "number" and value or nil
end

local function sourceGroup(profile, kind, itemName)
    local scoring = type(profile) == "table" and profile.sourceScoring or nil
    local entries = type(scoring) == "table" and scoring[kind] or nil
    return type(entries) == "table" and entries[itemName] or nil
end

local function sourceScore(group)
    if group == "Core Boons" then return 200, "BUILD_CORE_PRIORITY" end
    if group == "Non-Core Boons" then return 100, "BUILD_NON_CORE" end
    if group == "NPC Offerings" or group == "Daedalus Hammer Upgrades" then
        return 200, "BUILD_PREFERRED"
    end
    return 0, nil
end

local function traitSemantic(profile, itemName)
    local semantics = type(profile.traitSemantics) == "table" and profile.traitSemantics or nil
    local semantic = semantics and semantics[itemName] or nil
    return type(semantic) == "table" and semantic or nil
end

local function semanticCondition(snapshot, semantic)
    if semantic.kind ~= "conditional_outgoing_damage" then return nil end
    local combat = type(snapshot.combatContext) == "table" and snapshot.combatContext or nil
    local health = type(combat) == "table" and combat.health or nil
    local current = type(health) == "table" and health.current or nil
    local maximum = type(health) == "table" and health.max or nil
    if type(current) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then return nil end
    return current / maximum >= semantic.healthThreshold
end

local function conflictValue(profile, state, slotPolicy)
    if slotPolicy == "reserved" and state == "NON_TARGET" then
        return -(weight(profile, "BUILD_SLOT_POLICY") or 0)
    end
    return 0
end

local function slotPolicyDelta(profile, core)
    if type(core) ~= "table" or core.slotPolicy == nil then return 0 end
    if not core.replacesCoreSlot and not core.fillsEmptyCoreSlot then return 0 end
    if core.replacesCoreSlot and core.slotStateBefore == "UNKNOWN" then return 0 end
    local before = core.replacesCoreSlot and core.slotStateBefore or "EMPTY"
    return conflictValue(profile, core.slotStateAfter, core.slotPolicy)
        - conflictValue(profile, before, core.slotPolicy)
end

local function isDiscouraged(profile, role, itemName)
    local slot = profileSlots(profile) and profile.slots[role] or nil
    for _, name in ipairs(type(slot) == "table" and slot.discouraged or {}) do
        if name == itemName then return true end
    end
    return false
end

function ScoringEngine.getBuildAlignment(profile, role, itemName)
    local slot = profileSlots(profile) and profile.slots[role] or nil
    if type(slot) ~= "table" then return "NO_PLAN" end
    local function contains(list)
        for _, name in ipairs(type(list) == "table" and list or {}) do
            if name == itemName then return true end
        end
        return false
    end
    if contains(slot.core) then return "CORE" end
    if contains(slot.alternatives) then return "ALTERNATIVE" end
    if contains(slot.preferred) then return "PREFERRED" end
    if role == "Attack" then
        for _, branch in ipairs(type(slot.branches) == "table" and slot.branches or {}) do
            if branch.traitId == itemName then return "ALTERNATIVE" end
        end
    end
    return "NON_TARGET"
end

local function unresolvedAttackBranch(profile, traitName)
    local slots = profileSlots(profile)
    local attack = slots and slots.Attack
    for _, branch in ipairs(type(attack) == "table" and type(attack.branches) == "table"
        and attack.branches or {}) do
        if branch.traitId == traitName and type(branch.condition) == "table"
            and branch.condition.state == "unresolved" then return true end
    end
    return false
end

function ScoringEngine.isProfileSupported(snapshot, profile)
    local valid = ScoringEngine.validateProfile(profile)
    return valid and type(snapshot) == "table"
        and snapshot.weapon == profile.weapon and snapshot.aspect == profile.aspect
end

local function mappedStatus(profile, traitName)
    local mappings = type(profile) == "table" and profile.statusMappings or nil
    return type(mappings) == "table" and mappings[traitName] or nil
end

function ScoringEngine.getStatusContext(snapshot, profile, offeredTraitName)
    snapshot = type(snapshot) == "table" and snapshot or {}
    local context = {
        ownedStatusFamilies = {},
        ownedStatusOlympians = {},
        unknownGodTraits = {},
        unknownPotentialStatusTraits = {},
    }
    for _, trait in ipairs(type(snapshot.godTraits) == "table" and snapshot.godTraits or {}) do
        if type(trait) == "table" and type(trait.Name) == "string" then
            local status = mappedStatus(profile, trait.Name)
            if type(status) == "table" and type(status.family) == "string"
                and type(status.olympian) == "string" then
                context.ownedStatusFamilies[status.family] = true
                context.ownedStatusOlympians[status.olympian] = true
            else
                context.unknownGodTraits[trait.Name] = true
                if type(profile.potentialStatusTraits) == "table"
                    and profile.potentialStatusTraits[trait.Name] == true then
                    context.unknownPotentialStatusTraits[trait.Name] = true
                end
            end
        end
    end
    local offered = mappedStatus(profile, offeredTraitName)
    if type(offered) == "table" then
        context.statusKnowledge = "mapped"
        context.offeredStatusFamily = offered.family
        context.offeredStatusOlympian = offered.olympian
        context.offeredStatusEffect = offered.effect
    elseif type(profile.knownNonStatusTraits) == "table"
        and profile.knownNonStatusTraits[offeredTraitName] == true then
        context.statusKnowledge = "known_non_status"
    else
        context.statusKnowledge = "unknown"
    end
    return context
end

function ScoringEngine.getOriginationContext(snapshot, profile, offeredTraitName)
    snapshot = type(snapshot) == "table" and snapshot or {}
    local arcana = type(snapshot.activeArcana) == "table"
        and snapshot.activeArcana.EffectVulnerabilityMetaUpgrade or nil
    local active = type(arcana) == "table"
    local status = ScoringEngine.getStatusContext(snapshot, profile, offeredTraitName)
    local result = {
        originationActive = active,
        originationRarity = active and arcana.Rarity or nil,
        offerEnablesOrigination = false,
        status = status,
    }
    if not active then return result end
    local ownedCount = 0
    for _ in pairs(status.ownedStatusFamilies) do ownedCount = ownedCount + 1 end
    if ownedCount >= 2 then return result end
    if status.statusKnowledge == "known_non_status" then
        result.offerEnablesOrigination = false
        return result
    end
    if status.statusKnowledge == "unknown" then
        result.offerEnablesOrigination = nil
        return result
    end
    if ownedCount == 1 and not status.ownedStatusFamilies[status.offeredStatusFamily] then
        result.offerEnablesOrigination = true
    elseif next(status.unknownPotentialStatusTraits) ~= nil then
        result.offerEnablesOrigination = nil
    end
    return result
end

local function offerCoreData(profile, itemName)
    local verified = type(profile) == "table" and profile.verifiedIds or nil
    for groupName, data in pairs(coreRoles) do
        for _, name in ipairs(type(verified) == "table" and verified[groupName] or {}) do
            if name == itemName then return data end
        end
    end
end

local function currentSlotTrait(snapshot, slot)
    local slotted = type(snapshot) == "table" and snapshot.slottedTraits or nil
    local direct = type(slotted) == "table" and slotted[slot] or nil
    if type(direct) == "string" then return direct end
    for _, trait in ipairs(type(snapshot) == "table" and snapshot.godTraits or {}) do
        if type(trait) == "table" and trait.Slot == slot and type(trait.Name) == "string" then
            return trait.Name
        end
    end
end

local function slotState(profile, role, traitName)
    if traitName == nil then return "EMPTY" end
    if offerCoreData(profile, traitName) == nil then return "UNKNOWN" end
    local alignment = ScoringEngine.getBuildAlignment(profile, role, traitName)
    return alignment == "NO_PLAN" and "NO_PLAN" or alignment
end

function ScoringEngine.getCoreSlotContext(snapshot, profile, offer)
    snapshot = type(snapshot) == "table" and snapshot or {}
    offer = type(offer) == "table" and offer or {}
    local data = offerCoreData(profile, offer.ItemName)
    local result = {
        coreRole = data and data.role or nil,
        coreSlot = data and data.slot or nil,
        fillsEmptyCoreSlot = false,
        replacesCoreSlot = data ~= nil and type(offer.TraitToReplace) == "string",
        slotPolicy = nil,
        alignment = "NO_PLAN",
        currentSlotTrait = nil,
        slotStateBefore = nil,
        slotStateAfter = nil,
        slotConflict = false,
        conflictIntroduced = false,
        conflictResolved = false,
        coreSacrificed = false,
        conditionUnresolved = false,
    }
    if data == nil then return result end
    local definition = profileSlots(profile) and profile.slots[data.role] or nil
    result.slotPolicy = type(definition) == "table" and definition.slotPolicy or nil
    result.alignment = ScoringEngine.getBuildAlignment(profile, data.role, offer.ItemName)
    result.currentSlotTrait = result.replacesCoreSlot and offer.TraitToReplace
        or currentSlotTrait(snapshot, data.slot)
    result.conditionUnresolved = unresolvedAttackBranch(profile, result.currentSlotTrait)
        or unresolvedAttackBranch(profile, offer.ItemName)
    result.slotStateBefore = slotState(profile, data.role, result.currentSlotTrait)
    result.slotStateAfter = result.alignment
    result.slotConflict = result.slotPolicy == "reserved" and result.alignment == "NON_TARGET"
    result.conflictIntroduced = result.slotConflict and result.slotStateBefore ~= "NON_TARGET"
    result.conflictResolved = not result.conditionUnresolved
        and result.slotStateBefore == "NON_TARGET"
        and (result.alignment == "CORE" or result.alignment == "ALTERNATIVE")
    result.coreSacrificed = result.replacesCoreSlot
        and result.slotStateBefore == "CORE" and result.slotStateAfter == "NON_TARGET"
    if result.replacesCoreSlot then return result end
    result.fillsEmptyCoreSlot = result.currentSlotTrait == nil
    return result
end

local function coreTraitContext(snapshot, profile, traitName)
    local data = offerCoreData(profile, traitName)
    if data == nil then return nil end
    local status = ScoringEngine.getStatusContext(snapshot, profile, traitName)
    local interactions = ScoringEngine.getAspectInteractions(profile, traitName)
    local value = 0
    local reasons = {}
    for _, interaction in ipairs(interactions) do
        local delta = weight(profile, interaction)
        if delta ~= nil then value = value + delta; reasons[#reasons + 1] = { code = interaction, delta = delta } end
    end
    local hammer = firstOwned(ownedHammers(snapshot), profile.hammerRoles and profile.hammerRoles[data.role])
    local hammerDelta = weight(profile, "EXISTING_HAMMER_SYNERGY")
    if hammer ~= nil and hammerDelta ~= nil then
        value = value + hammerDelta
        reasons[#reasons + 1] = { code = "EXISTING_HAMMER_SYNERGY", delta = hammerDelta, with = hammer }
    end
    local alignment = ScoringEngine.getBuildAlignment(profile, data.role, traitName)
    local priorityCode = alignment == "CORE" and "BUILD_CORE_PRIORITY"
        or alignment == "PREFERRED" and "BUILD_PREFERRED" or nil
    local priorityDelta = priorityCode and weight(profile, priorityCode) or nil
    if priorityDelta ~= nil then
        value = value + priorityDelta
        reasons[#reasons + 1] = { code = priorityCode, delta = priorityDelta }
    end
    return { slot = data.slot, role = data.role, value = value, reasons = reasons,
        alignment = alignment,
        statusKnowledge = status.statusKnowledge, statusFamily = status.offeredStatusFamily }
end

local function replacementSnapshot(snapshot, oldName, newName)
    local copy = {}
    for key, value in pairs(snapshot) do copy[key] = value end
    copy.godTraits = {}
    for _, trait in ipairs(type(snapshot.godTraits) == "table" and snapshot.godTraits or {}) do
        if type(trait) ~= "table" or trait.Name ~= oldName then
            copy.godTraits[#copy.godTraits + 1] = trait
        end
    end
    copy.godTraits[#copy.godTraits + 1] = { Name = newName }
    return copy
end

local function originationValue(snapshot, profile)
    local arcana = type(snapshot.activeArcana) == "table"
        and snapshot.activeArcana.EffectVulnerabilityMetaUpgrade or nil
    if type(arcana) ~= "table" then return 0 end
    local context = ScoringEngine.getStatusContext(snapshot, profile)
    if next(context.unknownPotentialStatusTraits) ~= nil then return nil end
    local count = 0
    for _ in pairs(context.ownedStatusFamilies) do count = count + 1 end
    if count >= 2 then return weight(profile, "ORIGINATION_ENABLE") or 0 end
    return 0
end

function ScoringEngine.evaluateCoreReplacement(snapshot, profile, offer)
    local oldName = type(offer) == "table" and offer.TraitToReplace or nil
    local newName = type(offer) == "table" and offer.ItemName or nil
    if unresolvedAttackBranch(profile, oldName) or unresolvedAttackBranch(profile, newName) then return nil end
    local newSnapshot = replacementSnapshot(snapshot, oldName, newName)
    local newData = coreTraitContext(newSnapshot, profile, newName)
    local oldData = coreTraitContext(snapshot, profile, oldName)
    if newData == nil or oldData == nil or newData.slot ~= oldData.slot then return nil end
    -- A status transition can change Origination; resolve it only when both
    -- sides are explicitly known and no unknown potential status exists.
    local arcana = type(snapshot.activeArcana) == "table"
        and snapshot.activeArcana.EffectVulnerabilityMetaUpgrade or nil
    if type(arcana) == "table" then
        if oldData.statusKnowledge == "unknown" or newData.statusKnowledge == "unknown" then return nil end
        local context = ScoringEngine.getStatusContext(newSnapshot, profile)
        if next(context.unknownPotentialStatusTraits) ~= nil then return nil end
    end
    local oldOrigination = originationValue(snapshot, profile)
    local newOrigination = originationValue(newSnapshot, profile)
    if oldOrigination == nil or newOrigination == nil then return nil end
    return { delta = (newData.value + newOrigination) - (oldData.value + oldOrigination),
        old = oldData, new = newData }
end

function ScoringEngine.getAspectInteractions(profile, itemName)
    local interactions = type(profile) == "table" and profile.aspectInteractions or nil
    local explicit = type(interactions) == "table" and interactions[itemName] or nil
    local result, seen = {}, {}
    local function add(code)
        if type(code) == "string" and code ~= "" and not seen[code] then
            seen[code] = true
            result[#result + 1] = code
        end
    end
    if type(explicit) == "string" then
        add(explicit)
    elseif type(explicit) == "table" then
        for _, code in ipairs(explicit) do add(code) end
    end
    if #result > 0 then return result end
    local core = offerCoreData(profile, itemName)
    if type(profile) == "table" and profile.genericCoreAspectCompatibility == true
        and core ~= nil and (core.role == "Attack" or core.role == "Special") then
        return { "ASPECT_COMPATIBLE" }
    end
    return result
end

function ScoringEngine.getAspectInteraction(profile, itemName)
    return ScoringEngine.getAspectInteractions(profile, itemName)[1]
end

function ScoringEngine.isRankingReady(results, context)
    context = type(context) == "table" and context or {}
    if context.profileSupported ~= true then return false end
    local eligible, covered, complete, minimum, maximum = 0, 0, 0, nil, nil
    for _, result in ipairs(type(results) == "table" and results or {}) do
        if type(result) == "table" and result.eligible == true then
            eligible = eligible + 1
            if result.covered == true then covered = covered + 1 end
            if result.scoreComplete == true then complete = complete + 1 end
            if type(result.score) == "number" then
                minimum = minimum == nil and result.score or math.min(minimum, result.score)
                maximum = maximum == nil and result.score or math.max(maximum, result.score)
            end
        end
    end
    return eligible >= 2 and covered == eligible and complete == eligible
        and type(context.activeDifferentiatingRuleCount) == "number"
        and context.activeDifferentiatingRuleCount >= 1
        and minimum ~= nil and maximum ~= nil and minimum < maximum
end

function ScoringEngine.getRankingContext(results, profileSupported)
    local eligible = {}
    for _, result in ipairs(type(results) == "table" and results or {}) do
        if type(result) == "table" and result.eligible == true then
            eligible[#eligible + 1] = result
        end
    end
    local codes = {}
    for _, result in ipairs(eligible) do
        for _, reason in ipairs(type(result.reasons) == "table" and result.reasons or {}) do
            if type(reason.code) == "string" and type(reason.delta) == "number"
                and reason.delta ~= 0 then
                codes[reason.code] = true
            end
        end
    end
    local differing = 0
    for code in pairs(codes) do
        local first = nil
        local differs = false
        for index, result in ipairs(eligible) do
            local total = 0
            for _, reason in ipairs(type(result.reasons) == "table" and result.reasons or {}) do
                if reason.code == code and type(reason.delta) == "number" then
                    total = total + reason.delta
                end
            end
            if index == 1 then first = total elseif total ~= first then differs = true end
        end
        if differs then differing = differing + 1 end
    end
    return {
        profileSupported = profileSupported == true,
        activeDifferentiatingRuleCount = differing,
    }
end

function ScoringEngine.getRankingDecision(results, profileSupported)
    local fullContext = ScoringEngine.getRankingContext(results, profileSupported)
    local eligibleCount, complete = 0, {}
    for _, result in ipairs(type(results) == "table" and results or {}) do
        if type(result) == "table" and result.eligible == true then
            eligibleCount = eligibleCount + 1
            if result.supported == true and result.covered == true
                and result.scoreComplete == true and type(result.score) == "number" then
                complete[#complete + 1] = result
            end
        end
    end
    if ScoringEngine.isRankingReady(results, fullContext) then
        return { mode = "full", rankEligible = complete, context = fullContext }
    end
    if profileSupported == true and eligibleCount == 3 and #complete == 2 then
        local partialContext = ScoringEngine.getRankingContext(complete, true)
        if ScoringEngine.isRankingReady(complete, partialContext) then
            return { mode = "partial", rankEligible = complete, context = partialContext }
        end
    end
    return { mode = "none", rankEligible = {}, context = fullContext }
end

local verifiedRaritySources = { button = true, upgrade_option = true }
local verifiedNpcSources = { NPC_Athena_01 = true, NPC_Hades_Field_01 = true }
local verifiedBoonSources = {
    AphroditeUpgrade = true, ApolloUpgrade = true, AresUpgrade = true,
    DemeterUpgrade = true, HephaestusUpgrade = true, HeraUpgrade = true,
    HestiaUpgrade = true, PoseidonUpgrade = true, ZeusUpgrade = true,
    NPC_Athena_01 = true, NPC_Hades_Field_01 = true,
}

local function sourceRarityBonus(result, offer, replacement, required)
    if offer.Rarity == nil then
        if required then addReason(result, "RARITY_UNRESOLVED", 0) end
        return not required
    end
    if not verifiedRaritySources[offer.raritySource] then
        addReason(result, "RARITY_UNRESOLVED", 0)
        return false
    end
    local newValue = rarityValue(offer.Rarity)
    if newValue == nil then
        addReason(result, "RARITY_UNRESOLVED", 0)
        return false
    end
    if replacement then
        local oldValue = rarityValue(offer.OldRarity)
        if oldValue == nil then
            addReason(result, "RARITY_UNRESOLVED", 0)
            return false
        end
        local delta = newValue - oldValue
        if delta ~= 0 then addReason(result, "RARITY_DELTA", delta) end
    elseif newValue ~= 0 then
        addReason(result, "RARITY", newValue)
    end
    return true
end

local function scoreSourceRecommendations(snapshot, profile, profileSupported, kind)
    local results = {}
    for _, offer in ipairs(type(snapshot.offers) == "table" and snapshot.offers or {}) do
        if type(offer) == "table" then
            local result = {
                originalIndex = offer.originalIndex,
                itemName = offer.ItemName,
                supported = profileSupported,
                eligible = profileSupported and offer.Blocked ~= true,
                score = 0,
                reasons = {},
                covered = false,
                scoreComplete = false,
                rarity = offer.Rarity,
                traitToReplace = offer.TraitToReplace,
                oldRarity = offer.OldRarity,
                stackNum = offer.StackNum,
            }
            if offer.Blocked == true then
                result.supported = false
                result.eligible = false
                addReason(result, "BLOCKED", 0)
            elseif profileSupported and type(offer.ItemName) == "string" and offer.ItemName ~= "" then
                result.covered = true
                local deferred = sourceGroup(profile, "deferred", offer.ItemName)
                local boonGroup = sourceGroup(profile, "boons", offer.ItemName)
                local group = sourceGroup(profile, kind, offer.ItemName)
                if kind == "boons" and (offer.Rarity == "Duo" or offer.Rarity == "Legendary") then
                    local listed = deferred ~= nil or boonGroup ~= nil
                    local score, reasonCode = 0, nil
                    if offer.Rarity == "Legendary" then
                        if not verifiedRaritySources[offer.raritySource] then
                            addReason(result, "RARITY_UNRESOLVED", 0)
                            result.scoreComplete = false
                        else
                            score = listed and 203 or 0
                            reasonCode = listed and "BUILD_PREFERRED" or nil
                            result.scoreComplete = true
                        end
                    else
                        if verifiedRaritySources[offer.raritySource] then
                            score = listed and 200 or 0
                            reasonCode = listed and "BUILD_PREFERRED" or nil
                        else
                            addReason(result, "RARITY_UNRESOLVED", 0)
                        end
                        addReason(result, "SOURCE_REQUIREMENTS_UNRESOLVED", 0)
                        result.scoreComplete = false
                    end
                    result.sourceGroup = deferred or boonGroup
                    if score ~= 0 then addReason(result, reasonCode, score) end
                elseif kind == "boons" and deferred ~= nil then
                    result.sourceGroup = deferred
                    addReason(result, "RARITY_UNRESOLVED", 0)
                    addReason(result, "SOURCE_REQUIREMENTS_UNRESOLVED", 0)
                else
                    local replacement = kind == "boons" and type(offer.TraitToReplace) == "string"
                    local delta, reasonCode = 0, nil
                    local sourceResolved = true
                    if kind == "boons" then
                        result.sourceGroup = boonGroup
                        if not verifiedBoonSources[snapshot.offerSource] then
                            result.scoreComplete = false
                            sourceResolved = false
                            addReason(result, "SOURCE_REQUIREMENTS_UNRESOLVED", 0)
                        end
                        delta, reasonCode = sourceScore(boonGroup)
                        if sourceResolved and boonGroup == "NPC Offerings" then
                            local expectedSource = profile.sourceScoring.npcOfferings[offer.ItemName]
                            if not verifiedNpcSources[snapshot.offerSource]
                                or expectedSource ~= snapshot.offerSource then
                                result.scoreComplete = false
                                sourceResolved = false
                                addReason(result, "SOURCE_REQUIREMENTS_UNRESOLVED", 0)
                            end
                        end
                        if replacement and sourceResolved then
                            local replaced = offer.TraitToReplace
                            local oldDeferred = sourceGroup(profile, "deferred", replaced)
                            if oldDeferred ~= nil then
                                result.sourceGroup = oldDeferred
                                addReason(result, "SOURCE_REQUIREMENTS_UNRESOLVED", 0)
                                sourceResolved = false
                            else
                                local oldGroup = sourceGroup(profile, "boons", replaced)
                                local oldScore = sourceScore(oldGroup)
                                delta = delta - oldScore
                                if delta ~= 0 then
                                    addReason(result, "SOURCE_REPLACEMENT_DELTA", delta, replaced)
                                end
                            end
                        elseif sourceResolved and delta ~= 0 and reasonCode ~= nil then
                            addReason(result, reasonCode, delta)
                        end
                        if sourceResolved then
                            result.scoreComplete = sourceRarityBonus(result, offer, replacement,
                                boonGroup ~= "NPC Offerings")
                        end
                    elseif kind == "hammers" then
                        result.sourceGroup = group
                        delta, reasonCode = sourceScore(group)
                        if delta ~= 0 then addReason(result, reasonCode, delta) end
                        result.scoreComplete = sourceRarityBonus(result, offer, false, false)
                    elseif kind == "poms" then
                        local owned = ownedGodTraits(snapshot)[offer.ItemName] == true
                        result.sourceGroup = boonGroup or group
                        if not owned then
                            addReason(result, "SOURCE_REQUIREMENTS_UNRESOLVED", 0)
                        elseif boonGroup == "Core Boons" then
                            delta, reasonCode = 200, "BUILD_CORE_PRIORITY"
                            addReason(result, reasonCode, delta)
                            result.scoreComplete = true
                        elseif boonGroup == "Non-Core Boons" then
                            delta, reasonCode = 100, "BUILD_NON_CORE"
                            addReason(result, reasonCode, delta)
                            result.scoreComplete = sourceRarityBonus(result, offer, false, true)
                        elseif group == "Poms of Power" then
                            addReason(result, "SOURCE_REQUIREMENTS_UNRESOLVED", 0)
                        else
                            addReason(result, "SOURCE_REQUIREMENTS_UNRESOLVED", 0)
                        end
                    end
                end
            end
            results[#results + 1] = result
        end
    end
    return results
end

local function scoreHammerOffers(snapshot, profile, profileSupported)
    if type(profile.sourceScoring) == "table" and type(profile.sourceScoring.hammers) == "table" then
        return scoreSourceRecommendations(snapshot, profile, profileSupported, "hammers")
    end
    local plan = {}
    for _, entry in ipairs(type(profile.hammerPlan) == "table" and profile.hammerPlan or {}) do
        if type(entry) == "table" and type(entry.traitId) == "string" then plan[entry.traitId] = entry end
    end
    local results = {}
    for _, offer in ipairs(type(snapshot.offers) == "table" and snapshot.offers or {}) do
        if type(offer) == "table" then
            local result = {
                originalIndex = offer.originalIndex, itemName = offer.ItemName,
                supported = profileSupported, eligible = profileSupported and offer.Blocked ~= true,
                score = 0, reasons = {}, covered = false, scoreComplete = false,
            }
            if offer.Blocked == true then
                result.supported = false
                result.eligible = false
                addReason(result, "BLOCKED", 0)
            elseif profileSupported then
                local entry = plan[offer.ItemName]
                if entry ~= nil then
                    addReason(result, "HAMMER_BUILD_PRIORITY", -entry.priority)
                    result.covered = true
                    result.hammerPriority = entry.priority
                    result.hammerClassification = entry.classification
                    local focus = type(snapshot.playerFocus) == "table"
                        and snapshot.playerFocus.focus or "none"
                    local focusResolved = nil
                    if profile.id == "black_coat_melinoe_intermediate"
                        and type(snapshot.playerFocus) == "table" then
                        if offer.ItemName == "SuitAttackSpeedTrait"
                            or offer.ItemName == "SuitAttackSizeTrait" then
                            focusResolved = focus == "attack"
                        elseif offer.ItemName == "SuitSpecialAutoTrait" then
                            focusResolved = focus == "special"
                        end
                    end
                    if entry.condition ~= nil and focusResolved ~= true
                        or focusResolved == false then
                        result.hammerCondition = entry.condition
                        addReason(result, "HAMMER_CONDITION_UNRESOLVED", 0)
                    else
                        result.scoreComplete = true
                    end
                end
            end
            results[#results + 1] = result
        end
    end
    return results
end

function ScoringEngine.effectiveProfile(snapshot, profile)
    snapshot = type(snapshot) == "table" and snapshot or {}
    profile = type(profile) == "table" and profile or {}
    local coatRoute = nil
    if profile.id == "black_coat_melinoe_intermediate"
        and type(snapshot.playerFocus) == "table" then
        local declared = type(snapshot.playerFocus) == "table" and snapshot.playerFocus or {}
        if declared.focus == "special" then coatRoute = declared.route end
        if coatRoute == "zeus" then
            local projected = {}
            for key, value in pairs(profile) do projected[key] = value end
            projected.slots = {}
            for key, value in pairs(profile.slots or {}) do projected.slots[key] = value end
            projected.slots.Special = {
                core = {}, alternatives = {}, preferred = { "ZeusSpecialBoon" },
                slotPolicy = "reserved",
            }
            return projected, coatRoute
        end
    end
    return profile, coatRoute
end

function ScoringEngine.scoreOffers(snapshot, profile)
    snapshot = type(snapshot) == "table" and snapshot or {}
    profile = type(profile) == "table" and profile or {}
    local profileSupported = ScoringEngine.isProfileSupported(snapshot, profile)
    if type(profile.sourceScoring) == "table" then
        if snapshot.offerKind == "boon" and type(profile.sourceScoring.boons) == "table" then
            return scoreSourceRecommendations(snapshot, profile, profileSupported, "boons")
        elseif snapshot.offerKind == "pom" and type(profile.sourceScoring.poms) == "table" then
            return scoreSourceRecommendations(snapshot, profile, profileSupported, "poms")
        end
    end
    if snapshot.offerKind == "hammer" then
        return scoreHammerOffers(snapshot, profile, profileSupported)
    end
    local coatRoute
    profile, coatRoute = ScoringEngine.effectiveProfile(snapshot, profile)
    local owned = ownedGodTraits(snapshot)
    local hammers = ownedHammers(snapshot)
    local results = {}

    for _, offer in ipairs(type(snapshot.offers) == "table" and snapshot.offers or {}) do
        if type(offer) == "table" then
            local result = {
                originalIndex = offer.originalIndex,
                itemName = offer.ItemName,
                supported = profileSupported,
                eligible = profileSupported and offer.Blocked ~= true,
                score = 0,
                reasons = {},
                covered = false,
                scoreComplete = false,
                rarity = offer.Rarity,
                traitToReplace = offer.TraitToReplace,
                oldRarity = offer.OldRarity,
                stackNum = offer.StackNum,
            }
            if offer.ItemName == "LowHealthLifestealBoon" then
                local health = type(snapshot.combatContext) == "table"
                    and snapshot.combatContext.health or nil
                local current = type(health) == "table" and health.current or nil
                local currentlyActive = nil
                if type(current) == "number" then currentlyActive = current < 40 end
                result.condition = {
                    kind = "health_below_absolute",
                    threshold = 40,
                    currentlyActive = currentlyActive,
                }
            end
            if offer.Blocked == true then
                result.supported = false
                result.eligible = false
                addReason(result, "BLOCKED", 0)
            elseif profileSupported then
                local core = ScoringEngine.getCoreSlotContext(snapshot, profile, offer)
                local interactions = ScoringEngine.getAspectInteractions(profile, offer.ItemName)
                local origination = ScoringEngine.getOriginationContext(snapshot, profile, offer.ItemName)
                local originationUnresolved = false

                local replacement = core.replacesCoreSlot
                    and ScoringEngine.evaluateCoreReplacement(snapshot, profile, offer) or nil
                if core.replacesCoreSlot then
                    if replacement ~= nil then
                        addReason(result, "CORE_REPLACEMENT_DELTA", replacement.delta, offer.TraitToReplace)
                        result.covered = true
                    else
                        addReason(result, "REPLACEMENT_UNRESOLVED", 0)
                    end
                elseif core.fillsEmptyCoreSlot then
                    local alignment = ScoringEngine.getBuildAlignment(profile, core.coreRole, offer.ItemName)
                    if alignment ~= "NON_TARGET" or core.slotPolicy == "open" then
                        local code = (core.coreRole == "Attack" or core.coreRole == "Special"
                            or core.coreRole == "Cast") and "FILL_EMPTY_PRIMARY_CORE"
                            or "FILL_EMPTY_UTILITY_CORE"
                        local delta = weight(profile, code)
                        if delta ~= nil then
                            addReason(result, code, delta)
                            result.covered = true
                        end
                    end
                end

                local policyDelta = core.conditionUnresolved and 0 or slotPolicyDelta(profile, core)
                if policyDelta ~= 0 then
                    addReason(result, "BUILD_SLOT_POLICY_DELTA", policyDelta)
                end

                if not core.replacesCoreSlot then
                    for _, interaction in ipairs(interactions) do
                        local delta = weight(profile, interaction)
                        if delta ~= nil then
                            addReason(result, interaction, delta)
                            result.covered = true
                        end
                    end
                end

                if not core.replacesCoreSlot then
                    local alignment = ScoringEngine.getBuildAlignment(profile, core.coreRole, offer.ItemName)
                    local priorityCode = alignment == "CORE" and "BUILD_CORE_PRIORITY"
                        or alignment == "PREFERRED" and "BUILD_PREFERRED" or nil
                    local delta = priorityCode and weight(profile, priorityCode) or nil
                    if delta ~= nil then
                        addReason(result, priorityCode, delta)
                        result.covered = true
                    end
                    -- An explicit build plan resolves NON_TARGET as known
                    -- profile information. It is coverage, not a penalty or
                    -- a score contribution.
                    if alignment ~= "NO_PLAN" then
                        result.covered = true
                    end
                    if isDiscouraged(profile, core.coreRole, offer.ItemName) then
                        addReason(result, "BUILD_DISCOURAGED", weight(profile, "BUILD_DISCOURAGED") or 0)
                        result.covered = true
                    end
                end

                local attackBranchUnresolved = unresolvedAttackBranch(profile, offer.ItemName)
                if attackBranchUnresolved then addReason(result, "ATTACK_BRANCH_UNRESOLVED", 0) end

                if not core.replacesCoreSlot and origination.offerEnablesOrigination == true then
                    local delta = weight(profile, "ORIGINATION_ENABLE")
                    if delta ~= nil then
                        addReason(result, "ORIGINATION_ENABLE", delta)
                        result.covered = true
                    end
                elseif not core.replacesCoreSlot and origination.offerEnablesOrigination == nil
                    and origination.originationActive
                    and weight(profile, "ORIGINATION_ENABLE") ~= nil then
                    addReason(result, "ORIGINATION_UNRESOLVED", 0)
                    originationUnresolved = true
                end

                local hammerNames = type(profile.hammerRoles) == "table"
                    and profile.hammerRoles[core.coreRole] or nil
                local hammer = firstOwned(hammers, hammerNames)
                if not core.replacesCoreSlot and hammer ~= nil then
                    local delta = weight(profile, "EXISTING_HAMMER_SYNERGY")
                    if delta ~= nil then
                        addReason(result, "EXISTING_HAMMER_SYNERGY", delta, hammer)
                        result.covered = true
                    end
                end

                local rules = type(profile.rules) == "table" and profile.rules[offer.ItemName] or nil
                for _, rule in ipairs(type(rules) == "table" and rules or {}) do
                    local with = firstOwned(owned, rule.requiresAnyOwned)
                    local allOwned = rule.requiresAllOwned
                    local requirementsMet = rule.requiresAnyOwned == nil or with ~= nil
                    if requirementsMet and type(allOwned) == "table" then
                        for _, required in ipairs(allOwned) do
                            if not owned[required] then
                                requirementsMet = false
                                break
                            end
                        end
                    end
                    local delta = type(profile.weights) == "table" and profile.weights[rule.weight] or nil
                    if requirementsMet and type(delta) == "number" then
                        addReason(result, rule.code, delta, with)
                        result.covered = true
                    end
                end

                local semantic = traitSemantic(profile, offer.ItemName)
                if semantic ~= nil and semantic.kind == "conditional_outgoing_damage" then
                    result.condition = {
                        kind = semantic.kind,
                        threshold = semantic.healthThreshold,
                        currentlyActive = semanticCondition(snapshot, semantic),
                    }
                end
                if semantic ~= nil and (semantic.kind == "max_resource_support"
                    or semantic.kind == "conditional_outgoing_damage") then
                    local delta = weight(profile, semantic.reason)
                    if delta ~= nil then
                        addReason(result, semantic.reason, delta)
                        result.covered = true
                    end
                end

                if offer.ItemName == "AresStatusDoubleDamageBoon"
                    and buildCanProduceStatus(snapshot, profile, "Curse") then
                    local delta = weight(profile, "BUILD_STATUS_SYNERGY")
                    if delta ~= nil then
                        addReason(result, "BUILD_STATUS_SYNERGY", delta)
                        result.covered = true
                    end
                end
                if (offer.ItemName == "RendBloodDropBoon"
                    or offer.ItemName == "DoubleBloodDropBoon")
                    and hasBloodDropProducer(snapshot, profile) then
                    local delta = weight(profile, "BLOOD_DROP_ENGINE_SYNERGY")
                    if delta ~= nil then
                        addReason(result, "BLOOD_DROP_ENGINE_SYNERGY", delta)
                        result.covered = true
                    end
                end
                if offer.ItemName == "LowHealthLifestealBoon" then
                    local delta = weight(profile, "SURVIVAL_SUPPORT")
                    if delta ~= nil then
                        addReason(result, "SURVIVAL_SUPPORT", delta)
                        result.covered = true
                    end
                end

                result.scoreComplete = result.covered
                    and not originationUnresolved
                    and not attackBranchUnresolved
                    and (not core.replacesCoreSlot or replacement ~= nil)
                if coatRoute ~= nil and (offer.ItemName == "AresSpecialBoon"
                    or offer.ItemName == "ZeusSpecialBoon") then
                    local selected = coatRoute == "ares" and "AresSpecialBoon"
                        or coatRoute == "zeus" and "ZeusSpecialBoon" or nil
                    if offer.ItemName ~= selected then
                        addReason(result, "SPECIAL_ROUTE_UNRESOLVED", 0)
                        result.scoreComplete = false
                    end
                elseif profile.id == "black_coat_melinoe_intermediate"
                    and type(snapshot.playerFocus) == "table"
                    and (offer.ItemName == "AresSpecialBoon"
                        or offer.ItemName == "ZeusSpecialBoon") then
                    addReason(result, "SPECIAL_ROUTE_UNRESOLVED", 0)
                    result.scoreComplete = false
                end
                if result.scoreComplete then
                    local rarityResolved = rarityDelta(result, offer.Rarity, offer.OldRarity,
                        core.replacesCoreSlot)
                    result.scoreComplete = rarityResolved
                end
            end
            results[#results + 1] = result
        end
    end
    return results
end

function ScoringEngine.rank(results)
    local ranked = {}
    for _, result in ipairs(type(results) == "table" and results or {}) do
        if type(result) == "table" and result.supported == true and result.eligible == true then
            local copy = {}
            for key, value in pairs(result) do copy[key] = value end
            ranked[#ranked + 1] = copy
        end
    end
    table.sort(ranked, function(left, right)
        if left.score ~= right.score then return left.score > right.score end
        return left.originalIndex < right.originalIndex
    end)
    local previousScore = nil
    local previousRank = 0
    local scoreCounts = {}
    for _, result in ipairs(ranked) do
        scoreCounts[result.score] = (scoreCounts[result.score] or 0) + 1
    end
    for index, result in ipairs(ranked) do
        if result.score == previousScore then
            result.rank = previousRank
        else
            result.rank = index
            previousScore = result.score
            previousRank = index
        end
        result.rankGroup = result.rank
        result.tied = scoreCounts[result.score] > 1
    end
    return ranked
end

return ScoringEngine
