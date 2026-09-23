local function check(value, message) assert(value, message) end

local GameStateSnapshot = assert(loadfile("src/GameState.lua"))()
local OfferSnapshot = assert(loadfile("src/OfferSnapshot.lua"))()

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do copy[deepCopy(key, seen)] = deepCopy(child, seen) end
    return copy
end

local function deepEqual(left, right, seen)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right
    for key, value in pairs(left) do
        if not deepEqual(value, right[key], seen) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local empty = GameStateSnapshot.capture({})
check(empty.weapon == nil and empty.aspect == nil and #empty.traits == 0
    and #empty.hammers == 0 and #empty.godTraits == 0
    and next(empty.activeArcana) == nil, "nil CurrentRun not handled")
local noHero = GameStateSnapshot.capture({ CurrentRun = {} })
check(#noHero.traits == 0, "absent Hero not handled")
local equippedButNotApplied = GameStateSnapshot.capture({
    CurrentRun = { Hero = { Traits = {} } },
    GameState = { MetaUpgradeState = { StatusVulnerability = { Equipped = true } } },
})
check(next(equippedButNotApplied.activeArcana) == nil,
    "equipped card state was mistaken for an active Arcana trait")

local nativeRun = { Hero = {
    Weapons = { WeaponDagger = true },
    SlottedTraits = { Aspect = "DaggerBackstabAspect", Melee = "HestiaWeaponBoon" },
    Traits = {
        { Name = "DaggerBackstabAspect", Rarity = "Rare", StackNum = 2,
            Slot = "Aspect", IsWeaponEnchantment = true, Mutable = { 1 } },
        { Name = "DaggerRapidAttackTrait", Rarity = "Common", StackNum = 1 },
        { Name = "HestiaWeaponBoon", Rarity = "Epic", Slot = "Melee" },
        { Name = "EffectVulnerabilityMetaUpgrade", Rarity = "Rare" },
    },
    TraitDictionary = {
        DaggerRapidAttackTrait = { { Name = "DaggerRapidAttackTrait" }, { Name = "DaggerRapidAttackTrait" } },
    },
} }
local beforeRun = deepCopy(nativeRun)
local godCalls = 0
local snapshot = GameStateSnapshot.capture({
    CurrentRun = nativeRun,
    GetEquippedWeapon = function() return "WeaponDagger" end,
    LootData = { WeaponUpgrade = { TraitIndex = { DaggerRapidAttackTrait = true } } },
    IsGodTrait = function(name) godCalls = godCalls + 1; return name == "HestiaWeaponBoon" end,
})
check(snapshot.weapon == "WeaponDagger", "weapon missing")
check(snapshot.aspect == "DaggerBackstabAspect", "verified aspect missing")
check(snapshot.slottedTraits.Aspect == "DaggerBackstabAspect"
    and snapshot.slottedTraits.Melee == "HestiaWeaponBoon",
    "SlottedTraits scalar copy was not preserved")
check(#snapshot.traits == 4 and #snapshot.hammers == 1
    and snapshot.hammers[1].Name == "DaggerRapidAttackTrait", "trait or hammer snapshot wrong")
check(#snapshot.godTraits == 1 and snapshot.godTraits[1].Name == "HestiaWeaponBoon"
    and godCalls == 4, "IsGodTrait classification wrong")
check(type(snapshot.activeArcana.EffectVulnerabilityMetaUpgrade) == "table"
    and snapshot.activeArcana.EffectVulnerabilityMetaUpgrade.Rarity == "Rare",
    "active Origination trait not captured")
snapshot.activeArcana.EffectVulnerabilityMetaUpgrade.Rarity = "Changed"
check(nativeRun.Hero.Traits[4].Rarity == "Rare", "Arcana snapshot aliases native trait")

for _, rarity in ipairs({ "Common", "Rare", "Epic" }) do
    local arcanaSnapshot = GameStateSnapshot.capture({ CurrentRun = { Hero = { Traits = {
        { Name = "EffectVulnerabilityMetaUpgrade", Rarity = rarity },
    } } } })
    check(arcanaSnapshot.activeArcana.EffectVulnerabilityMetaUpgrade.Rarity == rarity,
        "Arcana rarity not preserved: " .. rarity)
end
check(snapshot.traits[1].Mutable == nil, "nested native field copied")
check(deepEqual(nativeRun, beforeRun), "GameState capture mutated native run")
snapshot.traits[1].Name = "Changed"
check(nativeRun.Hero.Traits[1].Name == "DaggerBackstabAspect", "trait snapshot aliases native trait")
snapshot.slottedTraits.Aspect = "Changed"
check(nativeRun.Hero.SlottedTraits.Aspect == "DaggerBackstabAspect",
    "SlottedTraits snapshot aliases native state")

local dummyRun = { Hero = {
    SlottedTraits = { Aspect = "DummyWeaponDagger" },
    Traits = { { Name = "DummyWeaponDagger", Slot = "Aspect" } },
} }
check(GameStateSnapshot.capture({ CurrentRun = dummyRun }).aspect == nil,
    "dummy weapon was invented as an aspect")
local wrongAspectType = { Hero = {
    SlottedTraits = { Aspect = { Name = "DaggerBackstabAspect" } },
    Traits = { { Name = "DaggerBackstabAspect", IsWeaponEnchantment = true } },
} }
check(GameStateSnapshot.capture({ CurrentRun = wrongAspectType }).aspect == nil,
    "non-string SlottedTraits.Aspect was accepted")
local missingAspect = { Hero = { SlottedTraits = {}, Traits = {} } }
check(GameStateSnapshot.capture({ CurrentRun = missingAspect }).aspect == nil, "absent aspect not nil")
local noHammer = GameStateSnapshot.capture({ CurrentRun = nativeRun, LootData = { WeaponUpgrade = {} } })
check(#noHammer.hammers == 0 and #noHammer.godTraits == 0,
    "missing TraitIndex or IsGodTrait not handled")
local combatRun = { Hero = {
    Health = 37, MaxHealth = 100, Mana = 12, MaxMana = 40,
    Traits = {
        { Name = "AresWeaponBoon", Slot = "Melee" },
        { Name = "AresSpecialBoon", Slot = "Secondary" },
    },
} }
local combatBefore = deepCopy(combatRun)
local combatSnapshot = GameStateSnapshot.capture({
    CurrentRun = combatRun,
    IsGodTrait = function(name) return name == "AresWeaponBoon" or name == "AresSpecialBoon" end,
    StatusMappings = {
        AresWeaponBoon = { family = "Curse" },
        AresSpecialBoon = { family = "Curse" },
    },
})
check(combatSnapshot.combatContext.health.current == 37
    and combatSnapshot.combatContext.health.max == 100
    and combatSnapshot.combatContext.mana.current == 12
    and combatSnapshot.combatContext.mana.max == 40,
    "health/mana context was not copied")
check(combatSnapshot.combatContext.statusFamilies.Curse == true,
    "Ares Curse family was not deduplicated/detected")
check(deepEqual(combatRun, combatBefore), "combat context capture mutated native run")
local invalidCombat = GameStateSnapshot.capture({ CurrentRun = { Hero = {
    Health = "37", MaxHealth = {}, Mana = false, MaxMana = nil, Traits = {},
} } })
check(invalidCombat.combatContext.health == nil
    and invalidCombat.combatContext.mana == nil,
    "invalid health/mana fields were not left unknown")
print("PASS: GameState nil run/Hero; weapon; verified/absent/dummy aspect; traits copied; list TraitDictionary ignored; hammers; optional IsGodTrait; no mutation")

check(#OfferSnapshot.capture({}, {}) == 0, "nil UpgradeOptions not handled")
check(#OfferSnapshot.capture({}, { UpgradeOptions = {} }) == 0, "zero offers not handled")
for count = 1, 3 do
    local options = {}
    for index = 1, count do options[index] = { ItemName = "Offer" .. index } end
    local offers = OfferSnapshot.capture({}, { UpgradeOptions = options })
    check(#offers == count and offers[count].originalIndex == count, count .. " offers not preserved")
end

local nativeScreen = { BlockedIndexes = { 2 }, Components = { PurchaseButton1 = { Id = 10 } } }
local nativeLoot = { UpgradeOptions = {
    { ItemName = "First", Type = "Trait", Rarity = "Rare", TraitToReplace = "OldTrait",
        OldRarity = "Common", SecondaryItemName = "Second", StackNum = 3, Nested = { unsafe = true } },
    { ItemName = "Blocked", Type = "Trait", Rarity = "Epic" },
    { ItemName = "Third", Blocked = true },
} }
local beforeScreen, beforeLoot = deepCopy(nativeScreen), deepCopy(nativeLoot)
local offers = OfferSnapshot.capture(nativeScreen, nativeLoot)
check(#offers == 3 and offers[1].originalIndex == 1 and offers[2].originalIndex == 2,
    "originalIndex missing")
check(offers[1].TraitToReplace == "OldTrait" and offers[1].OldRarity == "Common"
    and offers[1].SecondaryItemName == "Second" and offers[1].StackNum == 3,
    "optional offer fields missing")
check(offers[1].Blocked == false and offers[2].Blocked == true and offers[3].Blocked == false,
    "BlockedIndexes was not authoritative")
check(offers[1].Nested == nil, "nested option field copied")
check(deepEqual(nativeScreen, beforeScreen) and deepEqual(nativeLoot, beforeLoot),
    "offer capture mutated native tables")
offers[1].ItemName = "Changed"
check(nativeLoot.UpgradeOptions[1].ItemName == "First", "offer snapshot aliases native option")
local fallback = OfferSnapshot.capture({}, { UpgradeOptions = { { ItemName = "Fallback", Blocked = true } } })
check(fallback[1].Blocked == true, "option.Blocked fallback missing")
local sparseLoot = { UpgradeOptions = {
    [1] = { ItemName = "One", TraitToReplace = "OldOne" },
    [3] = { ItemName = "Three", TraitToReplace = { Name = "UnsafeNativeTrait" } },
    [7] = { ItemName = "Seven" },
} }
local sparseBefore = deepCopy(sparseLoot)
local sparse = OfferSnapshot.capture({ BlockedIndexes = { 3, 7 } }, sparseLoot)
check(#sparse == 3 and sparse[1].originalIndex == 1 and sparse[2].originalIndex == 3
    and sparse[3].originalIndex == 7, "sparse numeric offer indexes lost or reordered")
check(sparse[1].TraitToReplace == "OldOne" and sparse[2].TraitToReplace == nil,
    "TraitToReplace type handling changed")
check(sparse[1].Blocked == false and sparse[2].Blocked == true and sparse[3].Blocked == true,
    "BlockedIndexes list membership failed for sparse offer indexes")
check(deepEqual(sparseLoot, sparseBefore), "sparse offer capture mutated native table")
print("PASS: Offers nil/0/1/2/3/sparse; scalar TraitToReplace only; originalIndex; BlockedIndexes list authoritative; Blocked fallback; no mutation")
