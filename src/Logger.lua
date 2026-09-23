local Logger = {}

function Logger.new(enabled, sink)
    return function(message)
        if enabled ~= true or type(sink) ~= "function" then return end
        -- A logging failure must not escape into the game's input coroutine.
        pcall(sink, "[BoonAdvisor] " .. message)
    end
end

return Logger
