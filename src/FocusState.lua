local FocusState = {}

-- Kept in plugin memory only. A new CurrentRun object starts with no focus.
function FocusState.new()
    return { run = nil, focus = "none", route = "none", locked = false }
end

function FocusState.sync(state, run)
    if type(state) ~= "table" then return nil end
    if type(run) ~= "table" then
        state.run, state.focus, state.route, state.locked = nil, "none", "none", false
    elseif state.run ~= run then
        state.run, state.focus, state.route, state.locked = run, "none", "none", false
    end
    return state
end

function FocusState.selectFocus(state, focus)
    if type(state) ~= "table" or state.locked then return false end
    if focus ~= "none" and focus ~= "attack" and focus ~= "special" then return false end
    state.focus = focus
    state.route = "none"
    return true
end

function FocusState.selectRoute(state, route)
    if type(state) ~= "table" or state.locked or state.focus ~= "special" then return false end
    if route ~= "none" and route ~= "ares" and route ~= "zeus" then return false end
    state.route = route
    return true
end

function FocusState.lock(state)
    if type(state) ~= "table" or state.locked then return false end
    if state.focus ~= "none" and state.focus ~= "attack" and state.focus ~= "special" then return false end
    if state.focus ~= "special" and state.route ~= "none" then return false end
    if state.route ~= "none" and state.route ~= "ares" and state.route ~= "zeus" then return false end
    state.locked = true
    return true
end

function FocusState.forProfile(state, profile)
    if type(profile) ~= "table" or profile.id ~= "black_coat_melinoe_intermediate" then
        return nil
    end
    return { focus = state.focus, route = state.route, locked = state.locked == true }
end

return FocusState
