local FocusState = assert(loadfile("src/FocusState.lua"))()
local ScoringEngine = assert(loadfile("src/ScoringEngine.lua"))()
local UI = assert(loadfile("src/UI.lua"))()
local Localization = assert(loadfile("src/Localization.lua"))()
local coat = assert(loadfile("data/builds/black_coat_melinoe_intermediate.lua"))()

local function check(value, message) assert(value, message) end
local state = FocusState.new()
local firstRun, secondRun = {}, {}
FocusState.sync(state, firstRun)
check(state.focus == "none" and state.route == "none" and not state.locked,
    "focus must start undecided and unlocked")
check(not FocusState.selectRoute(state, "ares"), "route cannot be chosen without Special focus")
check(FocusState.selectFocus(state, "special") and FocusState.selectRoute(state, "ares"),
    "explicit Special route was not accepted")
check(FocusState.selectFocus(state, "attack") and state.route == "none",
    "switching to Attack retained a Special route")
FocusState.selectFocus(state, "special")
FocusState.selectRoute(state, "zeus")
check(FocusState.lock(state), "explicit route could not be locked")
check(not FocusState.selectRoute(state, "ares") and state.route == "zeus",
    "locked route could be changed")
FocusState.sync(state, secondRun)
check(state.focus == "none" and state.route == "none" and not state.locked,
    "focus/lock leaked into another run")
check(FocusState.forProfile(state, { id = "sister_blades_morrigan_meta" }) == nil,
    "Black Coat focus leaked into another profile")

local function score(offerKind, names, focus, route)
    local offers = {}
    for index, name in ipairs(names) do
        offers[index] = { originalIndex = index, ItemName = name, Rarity = "Common" }
    end
    return ScoringEngine.scoreOffers({
        weapon = coat.weapon, aspect = coat.aspect, offerKind = offerKind,
        offers = offers, traits = {}, hammers = {}, godTraits = {}, activeArcana = {},
        playerFocus = { focus = focus, route = route or "none" },
    }, coat)
end

local hammerNames = { "SuitDashAttackTrait", "SuitAttackSpeedTrait", "SuitSpecialAutoTrait",
    "SuitAttackSizeTrait" }
local undecided = score("hammer", hammerNames, "none")
check(undecided[1].scoreComplete and not undecided[2].scoreComplete
    and not undecided[3].scoreComplete and not undecided[4].scoreComplete,
    "undecided focus evaluated conditional Hammer alternatives")
local attack = score("hammer", hammerNames, "attack")
check(attack[1].scoreComplete and attack[2].scoreComplete
    and not attack[3].scoreComplete and attack[4].scoreComplete,
    "Attack focus did not select the documented Hammer alternatives")
local special = score("hammer", hammerNames, "special", "zeus")
check(special[1].scoreComplete and not special[2].scoreComplete
    and special[3].scoreComplete and not special[4].scoreComplete,
    "Special focus did not select Launcher Frame alone")
check(special[1].score > special[3].score, "Exhaust Riser lost its general P1")

local specialNames = { "AresSpecialBoon", "ZeusSpecialBoon" }
local noRoute = score("boon", specialNames, "special", "none")
check(not noRoute[1].scoreComplete and not noRoute[2].scoreComplete,
    "undecided Special route was ranked")
local aresRoute = score("boon", specialNames, "special", "ares")
check(aresRoute[1].scoreComplete and not aresRoute[2].scoreComplete,
    "Ares route evaluated the wrong Special")
local zeusRoute = score("boon", specialNames, "special", "zeus")
check(not zeusRoute[1].scoreComplete and zeusRoute[2].scoreComplete,
    "Zeus route evaluated the wrong Special")

UI.setLocalization(Localization)
UI.setLanguage("fr")
local made, labels, destroyed = {}, {}, {}
local api = {
    CreateScreenComponent = function(data)
        local component = { Id = #made + 1, Name = data.Name, Data = data }
        made[#made + 1] = component
        return component
    end,
    CreateTextBox = function(data) labels[#labels + 1] = data.RawText end,
    AttachLua = function() end,
    Destroy = function(data) destroyed[#destroyed + 1] = data end,
}
local screen = { Components = {} }
UI.renderFocus(screen, { focus = "special", route = "none" }, api, "route")
check(#screen.BoonAdvisorFocus == 4
    and labels[1]:find("Choisir entre :", 1, true)
    and not labels[1]:find("Route indéterminée", 1, true)
    and labels[2] == "Route indéterminée",
    "French Special route picker repeated the undecided option")
check(screen.Components.BoonAdvisorRouteAres.OnPressedFunctionName == "BoonAdvisorSelectFocus",
    "route option is not clickable")
UI.clearFocus(screen, api)
check(screen.BoonAdvisorFocus == nil and screen.Components.BoonAdvisorRouteAres == nil
    and #destroyed == 1, "focus UI was not cleaned up")

local lockedScreen = { Components = {} }
local lockedFocus = { focus = "special", route = "ares", locked = true }
UI.renderFocus(lockedScreen, lockedFocus, api, "route")
check(#lockedScreen.BoonAdvisorFocus == 1
    and lockedScreen.Components.BoonAdvisorFocusTile.OnPressedFunctionName == nil,
    "locked focus tile remained interactive or showed picker options")
local hud = {}
UI.syncFocusReminder(hud, lockedFocus, api)
check(hud.id ~= nil and hud.label == "Focus: Technique / roquettes · Route Arès",
    "locked focus HUD reminder was not rendered")
local hudComponent = made[#made]
check(hudComponent.Data.Group == "Combat_UI"
    and hudComponent.Name == "BlankObstacle"
    and hudComponent.OnPressedFunctionName == nil,
    "combat reminder is interactive or outside the HUD group")
check(hudComponent.Data.X + hudComponent.Data.Width / 2 <= 1920,
    "combat reminder exceeds a 1920-pixel-wide HUD")
local createdCount = #made
UI.syncFocusReminder(hud, lockedFocus, api)
check(#made == createdCount, "unchanged focus reminder was recreated")
UI.syncFocusReminder(hud, nil, api)
check(hud.id == nil and #destroyed == 2, "run reset did not clear the passive HUD reminder")
print("PASS: run-scoped focus lock/reset, conditional Hammers, read-only offer label and passive HUD reminder")
