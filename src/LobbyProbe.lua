-- Read-only diagnostics for build identity and hub/run lifecycle discovery.
local LobbyProbe = {}

local function display(value)
    if type(value) == "string" and value ~= "" then return value end
    return "unknown"
end

local function getPrimaryWeapons(hero, weaponSets)
    local names = {}
    local weaponNames = type(weaponSets) == "table" and weaponSets.HeroPrimaryWeapons or nil
    local weapons = type(hero) == "table" and hero.Weapons or nil
    if type(weaponNames) ~= "table" or type(weapons) ~= "table" then
        return names
    end
    for _, weaponName in ipairs(weaponNames) do
        if type(weaponName) == "string" and weapons[weaponName] then
            names[#names + 1] = weaponName
        end
    end
    table.sort(names)
    return names
end

function LobbyProbe.describe(stage, runtime)
    runtime = type(runtime) == "table" and runtime or {}
    local run = runtime.CurrentRun
    local hero = type(run) == "table" and run.Hero or nil
    local hub = runtime.CurrentHubRoom
    local room = type(run) == "table" and run.CurrentRoom or nil
    local primaryWeapons = getPrimaryWeapons(hero, runtime.WeaponSets)
    local weapon = #primaryWeapons == 1 and primaryWeapons[1]
        or (#primaryWeapons == 0 and "none" or "ambiguous:" .. table.concat(primaryWeapons, ","))
    local slottedTraits = type(hero) == "table" and hero.SlottedTraits or nil
    local activeAspect = type(slottedTraits) == "table" and slottedTraits.Aspect or nil
    local storedAspect = nil
    local gameState = runtime.GameState
    local lastUpgrades = type(gameState) == "table" and gameState.LastWeaponUpgradeName or nil
    if weapon ~= "none" and weapon:sub(1, 10) ~= "ambiguous:" and type(lastUpgrades) == "table" then
        storedAspect = lastUpgrades[weapon]
    end

    local hubName = type(hub) == "table" and hub.Name or nil
    local roomName = type(room) == "table" and room.Name or nil
    return "LOBBY_PROBE"
        .. " stage=" .. display(stage)
        .. " hub=" .. display(hubName)
        .. " room=" .. display(roomName)
        .. " run=" .. tostring(type(run) == "table")
        .. " hero=" .. tostring(type(hero) == "table")
        .. " primaryCount=" .. tostring(#primaryWeapons)
        .. " weapon=" .. weapon
        .. " activeAspect=" .. display(activeAspect)
        .. " storedAspect=" .. display(storedAspect)
end

return LobbyProbe
