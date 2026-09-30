local FocusState = assert(loadfile("src/FocusState.lua"))()
local medea = assert(loadfile("data/builds/argent_skull_medea_mobalytics.lua"))()
local moonstone = assert(loadfile("data/builds/moonstone_axe_melinoe_mobalytics.lua"))()
local function check(value, message) assert(value, message) end
local state = FocusState.new()
local firstRun, secondRun = {}, {}
FocusState.sync(state, firstRun)
check(state.focus == "none" and state.route == "none" and not state.locked,
    "focus did not start undecided")
check(not FocusState.selectRoute(state, "ares"), "route selected without Special focus")
check(FocusState.selectFocus(state, "special") and FocusState.selectRoute(state, "ares"),
    "explicit Special route was rejected")
check(FocusState.selectFocus(state, "attack") and state.route == "none",
    "switching to Attack retained a Special route")
FocusState.selectFocus(state, "special")
FocusState.selectRoute(state, "zeus")
check(FocusState.lock(state) and not FocusState.selectRoute(state, "ares")
    and state.route == "zeus", "locked route changed")
check(FocusState.forProfile(state, medea) == nil and FocusState.forProfile(state, moonstone) == nil,
    "retired focus policy leaked into an active profile")
FocusState.sync(state, secondRun)
check(state.focus == "none" and state.route == "none" and not state.locked,
    "focus leaked into another run")
print("PASS: focus state transitions and active-profile isolation")
