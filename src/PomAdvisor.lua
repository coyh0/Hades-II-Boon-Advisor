-- Pom priorities are intentionally independent from boon-offer scoring.
-- A Pom can only upgrade owned, stackable god traits. This module compares the
-- explicit role of those traits in the selected build; it does not estimate
-- damage, rarity value, or the value of an unmodelled boon.
local PomAdvisor = {}

local priorityByClassification = {
    core = 1,
    alternative = 2,
    preferred = 3,
    discouraged = 4,
}

local reasonByClassification = {
    core = "POM_CORE",
    alternative = "POM_ALTERNATIVE",
    preferred = "POM_PREFERRED",
    discouraged = "POM_DISCOURAGED",
}

local function addRole(roles, traitId, classification, priority)
    if type(traitId) ~= "string" or traitId == "" then return end
    local basePriority = priorityByClassification[classification]
    if basePriority == nil then return end
    -- Branch entries preserve their documentary order inside the same role.
    -- They remain below a direct core choice and above a merely preferred boon.
    if type(priority) == "number" and priority > 1 then
        basePriority = basePriority + priority - 1
    end
    local current = roles[traitId]
    if current == nil or basePriority < current.priority then
        roles[traitId] = {
            classification = classification,
            priority = basePriority,
            reason = reasonByClassification[classification],
        }
    end
end

function PomAdvisor.getRoles(profile)
    local roles = {}
    local slots = type(profile) == "table" and profile.slots or nil
    if type(slots) ~= "table" then return roles end
    for _, slot in pairs(slots) do
        if type(slot) == "table" then
            for _, traitId in ipairs(type(slot.core) == "table" and slot.core or {}) do
                addRole(roles, traitId, "core")
            end
            for _, traitId in ipairs(type(slot.alternatives) == "table" and slot.alternatives or {}) do
                addRole(roles, traitId, "alternative")
            end
            for _, traitId in ipairs(type(slot.preferred) == "table" and slot.preferred or {}) do
                addRole(roles, traitId, "preferred")
            end
            for _, traitId in ipairs(type(slot.discouraged) == "table" and slot.discouraged or {}) do
                addRole(roles, traitId, "discouraged")
            end
            for _, branch in ipairs(type(slot.branches) == "table" and slot.branches or {}) do
                if type(branch) == "table" then
                    addRole(roles, branch.traitId, branch.classification, branch.priority)
                end
            end
        end
    end
    return roles
end

function PomAdvisor.usesPomScoring(snapshot, profile)
    if type(snapshot) ~= "table" or snapshot.offerKind ~= "pom" then return false end
    if type(profile) == "table" and type(profile.sourceScoring) == "table"
        and type(profile.sourceScoring.poms) == "table" then return false end
    -- Stack upgrades use source-based numeric recommendations when the profile
    -- declares Pom groups; other profiles retain role-based Pom ranking.
    return true
end

function PomAdvisor.scoreOffers(snapshot, profile)
    local roles = PomAdvisor.getRoles(profile)
    local results = {}
    for _, offer in ipairs(type(snapshot) == "table" and snapshot.offers or {}) do
        local role = roles[offer.ItemName]
        -- Every visible Pom choice belongs to the comparison set. A choice
        -- without an explicit profile role is intentionally incomplete rather
        -- than silently removed from the comparison.
        local eligible = offer.Blocked ~= true
        local result = {
            originalIndex = offer.originalIndex,
            itemName = offer.ItemName,
            supported = eligible,
            eligible = eligible,
            covered = eligible and role ~= nil,
            scoreComplete = eligible and role ~= nil,
            score = role ~= nil and -role.priority or 0,
            reasons = {},
        }
        if eligible and role ~= nil then
            result.reasons[1] = { code = role.reason, delta = -role.priority }
        end
        results[#results + 1] = result
    end
    return results
end

return PomAdvisor
