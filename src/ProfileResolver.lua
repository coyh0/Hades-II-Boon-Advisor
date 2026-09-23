local ProfileResolver = {}

local function matches(descriptor, weapon, aspect)
    return type(descriptor) == "table"
        and descriptor.weapon == weapon
        and descriptor.aspect == aspect
end

local function ownedNames(ownedTraits)
    local result = {}
    if type(ownedTraits) == "table" then
        for _, trait in ipairs(ownedTraits) do
            if type(trait) == "table" and type(trait.Name) == "string" then result[trait.Name] = true end
            if type(trait) == "string" then result[trait] = true end
        end
    end
    return result
end

local function affinity(profile, owned)
    if type(profile) ~= "table" or type(profile.slots) ~= "table" then return 0 end
    local score = 0
    for _, slot in pairs(profile.slots) do
        if type(slot) == "table" then
            for _, name in ipairs(slot.core or {}) do if owned[name] then score = score + 3 end end
            for _, name in ipairs(slot.alternatives or {}) do if owned[name] then score = score + 2 end end
            for _, name in ipairs(slot.preferred or {}) do if owned[name] then score = score + 1 end end
            for _, name in ipairs(slot.discouraged or {}) do if owned[name] then score = score - 1 end end
        end
    end
    return score
end

local function signalMatch(profile, owned)
    if type(profile) ~= "table" or type(profile.autoSignals) ~= "table" then return false end
    for traitName in pairs(profile.autoSignals) do if owned[traitName] then return true end end
    return false
end

function ProfileResolver.resolve(registry, weapon, aspect, preferredProfileKey, ownedTraits, loadedProfiles)
    if type(registry) ~= "table" then return nil, "invalid_registry" end
    local candidates, keys = {}, {}
    for key, descriptor in pairs(registry) do
        if matches(descriptor, weapon, aspect) then
            keys[#keys + 1] = key
            candidates[key] = descriptor
        end
    end
    table.sort(keys)
    if #keys == 0 then return nil, "unsupported" end
    if type(preferredProfileKey) == "string" and candidates[preferredProfileKey] ~= nil then
        return candidates[preferredProfileKey], "preferred"
    end
    if #keys == 1 then return candidates[keys[1]], "only_candidate" end
    local owned = ownedNames(ownedTraits)
    local bestKey, bestScore, tied = nil, nil, false
    for _, key in ipairs(keys) do
        local descriptor = candidates[key]
        local profile = type(loadedProfiles) == "table" and loadedProfiles[descriptor.module] or nil
        local score = affinity(profile, owned)
        if bestScore == nil or score > bestScore then bestKey, bestScore, tied = key, score, false
        elseif score == bestScore then tied = true end
    end
    if bestKey ~= nil and bestScore > 0 and not tied then return candidates[bestKey], "affinity" end
    local signalKey, signalCount = nil, 0
    for _, key in ipairs(keys) do
        local profile = type(loadedProfiles) == "table" and loadedProfiles[candidates[key].module] or nil
        if signalMatch(profile, owned) then signalKey, signalCount = key, signalCount + 1 end
    end
    if signalCount == 1 then return candidates[signalKey], "auto_signal" end
    return nil, "ambiguous"
end

return ProfileResolver
