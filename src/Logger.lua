local Logger = {}

local function safeString(value)
    local ok, result = pcall(tostring, value)
    return ok and result or "<unprintable>"
end

function Logger.new(enabled, sink, persistentState)
    persistentState = type(persistentState) == "table" and persistentState or {}
    persistentState.seen = type(persistentState.seen) == "table" and persistentState.seen or {}
    persistentState.suppressed = type(persistentState.suppressed) == "table"
        and persistentState.suppressed or {}

    local function emit(level, code, message)
        if type(sink) ~= "function" then return end
        local stableCode = safeString(code)
        local key = level .. ":" .. stableCode
        if persistentState.seen[key] then
            persistentState.suppressed[key] = (persistentState.suppressed[key] or 0) + 1
            return
        end
        local ok = pcall(function()
            sink("[BoonAdvisor] " .. level .. " " .. stableCode .. ": " .. safeString(message))
        end)
        if ok then persistentState.seen[key] = true end
    end

    return {
        error = function(code, message) emit("ERROR", code, message) end,
        warn = function(code, message) emit("WARN", code, message) end,
        info = function() end,
        debug = function(message)
            if enabled == true and type(sink) == "function" then
                pcall(function() sink("[BoonAdvisor] " .. safeString(message)) end)
            end
        end,
        state = persistentState,
    }
end

return Logger
