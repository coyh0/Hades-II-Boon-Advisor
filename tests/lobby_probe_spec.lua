package.path = "./src/?.lua;" .. package.path

local LobbyProbe = require("LobbyProbe")

local function check(condition, message)
    if not condition then error(message or "check failed") end
end

local weapons = { WeaponDagger = true, WeaponStaff = false, WeaponDaggerProjectile = true }
local traits = { Aspect = "DaggerTripleAspect" }
local runtime = {
    CurrentHubRoom = { Name = "Hub_Main" },
    CurrentRun = {
        ActiveBounty = nil,
        CurrentRoom = { Name = "Hub_Main" },
        Hero = { Weapons = weapons, SlottedTraits = traits },
    },
    GameState = { LastWeaponUpgradeName = { WeaponDagger = "DaggerTripleAspect" } },
    WeaponSets = { HeroPrimaryWeapons = { "WeaponSuit", "WeaponDagger" } },
}

local line = LobbyProbe.describe("HubPostLoad", runtime)
check(line:find("stage=HubPostLoad", 1, true), "probe stage absent")
check(line:find("hub=Hub_Main", 1, true), "hub name absent")
check(line:find("primaryCount=1 weapon=WeaponDagger", 1, true), "primary weapon not resolved")
check(line:find("activeAspect=DaggerTripleAspect", 1, true), "active Aspect absent")
check(line:find("storedAspect=DaggerTripleAspect", 1, true), "stored Aspect absent")
check(weapons.WeaponDagger == true and traits.Aspect == "DaggerTripleAspect", "probe mutated game state")

local noHero = LobbyProbe.describe("plugin_loaded", { CurrentHubRoom = { Name = "Hub_Main" } })
check(noHero:find("hero=false", 1, true), "missing hero not represented")
check(noHero:find("weapon=none", 1, true), "missing weapon not represented")

local ambiguous = LobbyProbe.describe("StartRoom", {
    CurrentRun = { Hero = { Weapons = { WeaponDagger = true, WeaponSuit = true } } },
    WeaponSets = { HeroPrimaryWeapons = { "WeaponDagger", "WeaponSuit" } },
    GameState = { LastWeaponUpgradeName = { WeaponDagger = "DaggerTripleAspect" } },
})
check(ambiguous:find("primaryCount=2 weapon=ambiguous:WeaponDagger,WeaponSuit", 1, true),
    "multiple primary weapons did not remain ambiguous")
check(ambiguous:find("storedAspect=unknown", 1, true), "ambiguous selection borrowed a stale Aspect")

print("PASS: lobby probe reports hub/run, unique or ambiguous primary weapon, active/stored Aspect; no mutation")
