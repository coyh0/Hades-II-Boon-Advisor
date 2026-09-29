local GodPoolContext = {}

-- The recommendation is profile metadata. The observed status is reconstructed
-- independently from the current run's native loot history.
function GodPoolContext.evaluate(recommendedMembership, snapshot)
    local result = {
        recommendedByBuild = recommendedMembership == true and "Yes"
            or recommendedMembership == false and "No" or "Unknown",
        observedInRuntimePool = "Unknown",
    }
    if type(snapshot) ~= "table" or type(snapshot.offerSource) ~= "string" then return result end
    local runtime = snapshot.nativeGodPool
    if type(runtime) ~= "table" or runtime.offerIsGodLoot ~= true
        or type(runtime.registered) ~= "table" then
        return result
    end
    if runtime.registered[snapshot.offerSource] == true then
        result.observedInRuntimePool = "Yes"
        return result
    end
    if runtime.historyComplete ~= true then return result end
    local maxGods = runtime.maxGods
    if type(maxGods) ~= "number" or maxGods < 1 or maxGods ~= math.floor(maxGods) then
        return result
    end
    local count = 0
    for _, present in pairs(runtime.registered) do
        if present == true then count = count + 1 end
    end
    if count >= maxGods then result.observedInRuntimePool = "No" end
    return result
end

return GodPoolContext
