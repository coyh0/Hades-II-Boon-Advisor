local CoreAdvisory = {}

local noticeRoles = { Attack = true, Special = true, Cast = true }

local verifiedGodOfferSources = {
    AphroditeUpgrade = true, ApolloUpgrade = true, AresUpgrade = true,
    DemeterUpgrade = true, HephaestusUpgrade = true, HeraUpgrade = true,
    HestiaUpgrade = true, PoseidonUpgrade = true, ZeusUpgrade = true,
}

local function ownedTraitSet(snapshot)
    local owned = {}
    local function add(traits)
        for _, trait in ipairs(type(traits) == "table" and traits or {}) do
            if type(trait) == "table" and type(trait.Name) == "string" then
                owned[trait.Name] = true
            end
        end
    end
    add(snapshot.traits)
    add(snapshot.godTraits)
    for _, traitId in pairs(type(snapshot.slottedTraits) == "table" and snapshot.slottedTraits or {}) do
        if type(traitId) == "string" then owned[traitId] = true end
    end
    return owned
end

function CoreAdvisory.getChecklist(profile, snapshot)
    if type(profile) ~= "table" then return {} end
    local owned = ownedTraitSet(type(snapshot) == "table" and snapshot or {})
    local checklist = {}
    local scoring = profile.sourceScoring
    if type(profile.source) == "table" and profile.source.type == "mobalytics"
        and type(scoring) == "table" and type(scoring.boons) == "table"
        and type(profile.corePlan) == "table" then
        -- The verified Core Boons source map is authoritative for Mobalytics.
        for traitId, group in pairs(scoring.boons) do
            local metadata = profile.corePlan[traitId]
            if group == "Core Boons" and type(metadata) == "table" then
                checklist[#checklist + 1] = {
                    traitId = traitId,
                    role = metadata.role,
                    displayName = metadata.displayName,
                    acquired = owned[traitId] == true,
                }
            end
        end
    else
        -- Other canonical profiles declare Core boons directly in slots.
        for role, slot in pairs(type(profile.slots) == "table" and profile.slots or {}) do
            for _, traitId in ipairs(type(slot) == "table" and type(slot.core) == "table"
                and slot.core or {}) do
                if type(traitId) == "string" then
                    checklist[#checklist + 1] = {
                        traitId = traitId, role = role, acquired = owned[traitId] == true,
                    }
                end
            end
        end
    end
    table.sort(checklist, function(left, right)
        if left.traitId == right.traitId then return tostring(left.role) < tostring(right.role) end
        return left.traitId < right.traitId
    end)
    return checklist
end

function CoreAdvisory.hasMissingCore(profile, snapshot)
    local checklist = CoreAdvisory.getChecklist(profile, snapshot)
    local countByRole = {}
    for _, core in ipairs(checklist) do
        if noticeRoles[core.role] then
            countByRole[core.role] = (countByRole[core.role] or 0) + 1
        end
    end
    for _, core in ipairs(checklist) do
        -- More than one Core candidate for a single slot does not say which
        -- one is required. Do not infer an all-owned or any-owned rule.
        if noticeRoles[core.role] and countByRole[core.role] == 1
            and not core.acquired then return true end
    end
    return false
end

function CoreAdvisory.godPoolMembership(profile, snapshot)
    if type(profile) ~= "table" or type(profile.godPool) ~= "table"
        or type(snapshot) ~= "table" or type(snapshot.offerSource) ~= "string"
        or not verifiedGodOfferSources[snapshot.offerSource] then
        return nil
    end
    for _, entry in ipairs(profile.godPool) do
        if type(entry) == "table" and entry.offerSource == snapshot.offerSource then return true end
    end
    return false
end

function CoreAdvisory.shouldShow(profile, snapshot, profileSupported)
    if type(snapshot) ~= "table" or snapshot.offerKind ~= "boon" then return false end
    -- Preserve the existing conservative fallback for an unresolved profile.
    if type(profile) ~= "table" then return true end
    local checklist = CoreAdvisory.getChecklist(profile, snapshot)
    if #checklist == 0 then return profileSupported ~= true end
    -- The notice depends on owned Attack, Special, and Cast Cores alone.
    -- Offer source, God Pool membership, and ranking are unrelated to it.
    return CoreAdvisory.hasMissingCore(profile, snapshot)
end

return CoreAdvisory
