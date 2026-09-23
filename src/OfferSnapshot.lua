local OfferSnapshot = {}

local offerFields = {
    "ItemName", "Type", "Rarity", "TraitToReplace", "OldRarity",
    "SecondaryItemName", "StackNum",
}

local function isBlocked(screen, option, index)
    if type(screen) == "table" and type(screen.BlockedIndexes) == "table" then
        for _, blockedIndex in ipairs(screen.BlockedIndexes) do
            if blockedIndex == index then return true end
        end
        return false
    end
    return option.Blocked == true
end

function OfferSnapshot.capture(screen, lootData)
    local offers = {}
    local options = type(lootData) == "table" and lootData.UpgradeOptions or nil
    if type(options) ~= "table" then return offers end

    local indexes = {}
    for index, option in pairs(options) do
        if type(index) == "number" and index >= 1 and index % 1 == 0 and type(option) == "table" then
            indexes[#indexes + 1] = index
        end
    end
    table.sort(indexes)

    for _, index in ipairs(indexes) do
        local option = options[index]
        if type(option) == "table" then
            local copy = { originalIndex = index, Blocked = isBlocked(screen, option, index) }
            for _, field in ipairs(offerFields) do
                local value = option[field]
                local valueType = type(value)
                if valueType == "string" or valueType == "number" or valueType == "boolean" then
                    copy[field] = value
                end
            end
            local rawRarity = option.Rarity
            local effectiveRarity = rawRarity
            local source = "upgrade_option"
            local buttons = type(screen) == "table" and screen.UpgradeButtons or nil
            local button = type(buttons) == "table" and buttons[index] or nil
            local data = type(button) == "table" and button.Data or nil
            if type(option.ItemName) == "string" and type(data) == "table"
                and data.Name == option.ItemName and type(data.Rarity) == "string" then
                effectiveRarity = data.Rarity
                source = "button"
            end
            if type(rawRarity) == "string" then copy.rawRarity = rawRarity end
            if type(effectiveRarity) == "string" then copy.Rarity = effectiveRarity end
            copy.raritySource = source
            offers[#offers + 1] = copy
        end
    end
    return offers
end

return OfferSnapshot
