local GameStateSnapshot = {}

local traitFields = { "Name", "Rarity", "StackNum", "Slot" }
local trackedArcanaTraits = { EffectVulnerabilityMetaUpgrade = true }

local function copyTrait(trait)
    local copy = {}
    for _, field in ipairs(traitFields) do
        local value = trait[field]
        local valueType = type(value)
        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            copy[field] = value
        end
    end
    return copy
end

function GameStateSnapshot.capture(runtime)
    runtime = runtime or {}
    local snapshot = { traits = {}, hammers = {}, godTraits = {}, activeArcana = {}, slottedTraits = {},
        combatContext = { statusFamilies = {} } }
    local run = runtime.CurrentRun
    local hero = type(run) == "table" and run.Hero or nil
    if type(hero) ~= "table" then return snapshot end

    local health, mana = {}, {}
    if type(hero.Health) == "number" then health.current = hero.Health end
    if type(hero.MaxHealth) == "number" then health.max = hero.MaxHealth end
    if type(hero.Mana) == "number" then mana.current = hero.Mana end
    if type(hero.MaxMana) == "number" then mana.max = hero.MaxMana end
    if next(health) ~= nil then snapshot.combatContext.health = health end
    if next(mana) ~= nil then snapshot.combatContext.mana = mana end

    if type(runtime.GetEquippedWeapon) == "function" then
        local ok, weapon = pcall(runtime.GetEquippedWeapon)
        if ok and type(weapon) == "string" then snapshot.weapon = weapon end
    end

    local traits = type(hero.Traits) == "table" and hero.Traits or {}
    if type(hero.SlottedTraits) == "table" then
        for slot, traitName in pairs(hero.SlottedTraits) do
            if type(slot) == "string" and type(traitName) == "string" then
                snapshot.slottedTraits[slot] = traitName
            end
        end
    end
    local aspectName = type(hero.SlottedTraits) == "table" and hero.SlottedTraits.Aspect or nil
    if type(aspectName) ~= "string" then aspectName = nil end
    local hammerIndex = type(runtime.LootData) == "table"
        and type(runtime.LootData.WeaponUpgrade) == "table"
        and runtime.LootData.WeaponUpgrade.TraitIndex or nil

    for _, trait in ipairs(traits) do
        if type(trait) == "table" then
            local traitCopy = copyTrait(trait)
            snapshot.traits[#snapshot.traits + 1] = traitCopy
            if trackedArcanaTraits[trait.Name] then
                snapshot.activeArcana[trait.Name] = {}
                if type(trait.Rarity) == "string" then
                    snapshot.activeArcana[trait.Name].Rarity = trait.Rarity
                end
            end
            if trait.Name == aspectName and trait.IsWeaponEnchantment == true then
                snapshot.aspect = trait.Name
            end
            if type(hammerIndex) == "table" and type(trait.Name) == "string"
                and hammerIndex[trait.Name] then
                snapshot.hammers[#snapshot.hammers + 1] = traitCopy
            end
            if type(runtime.IsGodTrait) == "function" and type(trait.Name) == "string" then
                local ok, isGodTrait = pcall(runtime.IsGodTrait, trait.Name)
                if ok and isGodTrait == true then
                    snapshot.godTraits[#snapshot.godTraits + 1] = traitCopy
                end
            end
        end
    end
    for _, trait in ipairs(snapshot.godTraits) do
        local status = type(runtime.StatusMappings) == "table" and runtime.StatusMappings[trait.Name] or nil
        if type(status) == "table" and type(status.family) == "string" then
            snapshot.combatContext.statusFamilies[status.family] = true
        end
    end
    return snapshot
end

return GameStateSnapshot
