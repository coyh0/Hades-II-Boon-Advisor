local UI = {}
local debugLog = function() end
local localization = nil
local language = "en"
local reasonOrder = { "conflict", "core", "utility", "build", "resources", "damage", "aspect", "setup", "positioning", "origination", "hammer", "status", "synergy", "survival", "rarity" }

local function formatRankLabel(rank)
    return localization.get(language, "rank") .. " " .. tostring(rank)
end

local function formatReasonLabels(reasons)
    local present = {}
    for _, reason in ipairs(type(reasons) == "table" and reasons or {}) do
        if type(reason) == "table" and type(reason.delta) == "number" and reason.delta ~= 0 then
            if reason.code == "RARITY" or reason.code == "RARITY_DELTA" then
                goto continue
            end
            local key = localization.reasonKey(reason.code, reason.delta)
            if key then present[key] = true end
        end
        ::continue::
    end
    local labels = {}
    for _, key in ipairs(reasonOrder) do
        if present[key] then
            labels[#labels + 1] = localization.get(language, key)
            if #labels == 2 then break end
        end
    end
    return labels
end

function UI.setLogger(logger)
    debugLog = type(logger) == "function" and logger or function() end
end

function UI.setLocalization(value)
    localization = value
end

function UI.setLanguage(value)
    language = type(value) == "string" and value or "en"
end

local function rankState(screen)
    if type(screen) ~= "table" then return nil end
    screen.BoonAdvisorRanks = screen.BoonAdvisorRanks or {}
    return screen.BoonAdvisorRanks
end

function UI.clearRanks(screen, api)
    local ranks = rankState(screen)
    if ranks == nil then return end
    local ids = {}
    for _, entry in ipairs(ranks) do
        local id = type(entry) == "table" and entry.id or entry
        if id ~= nil then ids[#ids + 1] = id end
        if type(entry) == "table" and entry.reasonId ~= nil then ids[#ids + 1] = entry.reasonId end
        if type(entry) == "table" and type(screen.Components) == "table"
                and entry.key ~= nil and screen.Components[entry.key] ~= nil then
            screen.Components[entry.key] = nil
        end
        if type(entry) == "table" and type(screen.Components) == "table"
            and entry.reasonKey ~= nil and screen.Components[entry.reasonKey] ~= nil then
            screen.Components[entry.reasonKey] = nil
        end
    end
    screen.BoonAdvisorRanks = {}
    if #ids > 0 then
        local destroy = type(api) == "table" and api.Destroy or nil
        if type(destroy) == "function" then
            destroy({ Ids = ids })
        else
            debugLog("UI ERROR missing native API Destroy")
        end
    end
    if #ids > 0 then debugLog("UI cleared count=" .. tostring(#ids)) end
end

function UI.clearFallback(screen, api)
    if type(screen) ~= "table" or type(screen.BoonAdvisorFallback) ~= "table" then return end
    local entry = screen.BoonAdvisorFallback
    screen.BoonAdvisorFallback = nil
    if type(screen.Components) == "table" and entry.key then screen.Components[entry.key] = nil end
    local destroy = type(api) == "table" and api.Destroy or nil
    if type(destroy) == "function" and entry.id ~= nil then destroy({ Ids = { entry.id } })
    elseif entry.id ~= nil then debugLog("UI ERROR missing native API Destroy") end
end

function UI.renderFallback(screen, data, api)
    UI.clearFallback(screen, api)
    if type(screen) ~= "table" or type(data) ~= "table" then return end
    local create = type(api) == "table" and api.CreateScreenComponent or nil
    local textBox = type(api) == "table" and api.CreateTextBox or nil
    local attach = type(api) == "table" and api.Attach or nil
    if type(create) ~= "function" or type(textBox) ~= "function" or type(attach) ~= "function" then
        debugLog("UI ERROR missing native API for fallback")
        return
    end
    local anchor = type(screen.Components) == "table"
        and screen.Components.PurchaseButton1 or nil
    if anchor == nil then return end
    local component = create({ Name = "BlankObstacle", Group = "Combat_Menu_Overlay" })
    if type(component) ~= "table" or component.Id == nil then return end
    attach({ Id = component.Id, DestinationId = anchor.Id, OffsetX = 405, OffsetY = -170 })
    local key = "BoonAdvisorFallback"
    if type(screen.Components) == "table" then screen.Components[key] = component end
    local fallbackKeys = {
        AMBIGUOUS_PROFILE = "profileAmbiguous", UNSUPPORTED_PROFILE = "profileUnsupported",
        REPLACEMENT_UNRESOLVED = "replacementUnevaluated",
        INCOMPLETE_ANALYSIS = "incompleteAnalysis", NO_RELIABLE_PREFERENCE = "noReliablePreference",
    }
    local subtitleKeys = {
        REPLACEMENT_UNRESOLVED = "rankingUnreliable",
        NO_RELIABLE_PREFERENCE = "equivalentChoices",
    }
    textBox({ Id = component.Id, RawText = localization.get(language, fallbackKeys[data.code]), Width = 600,
        Font = "LatoBold", FontSize = 18,
        Justification = "Center", ShadowBlur = 0, ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 1 } })
    local subtitle = subtitleKeys[data.code] and localization.get(language, subtitleKeys[data.code]) or nil
    if data.code == "INCOMPLETE_ANALYSIS" and type(data.incompleteCount) == "number" then
        subtitle = localization.formatIncompleteCount(language, data.incompleteCount)
    end
    if subtitle then
        textBox({ Id = component.Id, RawText = subtitle, Width = 600,
            Font = "LatoBold", FontSize = 13,
            Justification = "Center", OffsetY = 22, ShadowBlur = 0,
            ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 1 } })
    end
    screen.BoonAdvisorFallback = { id = component.Id, key = key }
    debugLog("UI Fallback rendered Code=" .. tostring(data.code)
        .. (data.incompleteCount and " IncompleteCount=" .. tostring(data.incompleteCount) or ""))
end

function UI.renderPartial(screen, offers, api)
    UI.clearRanks(screen, api)
    if type(screen) ~= "table" or type(offers) ~= "table" then return end
    local components = type(screen.Components) == "table" and screen.Components or {}
    local create = type(api) == "table" and api.CreateScreenComponent or nil
    local textBox = type(api) == "table" and api.CreateTextBox or nil
    local attach = type(api) == "table" and api.Attach or nil
    if type(create) ~= "function" or type(textBox) ~= "function" or type(attach) ~= "function" then
        debugLog("UI ERROR missing native API for partial analysis")
        return
    end
    for _, offer in ipairs(offers) do
        local index = type(offer) == "table" and offer.originalIndex or nil
        local button = type(index) == "number" and components["PurchaseButton" .. index] or nil
        if button ~= nil then
            local key = "BoonAdvisorRank" .. tostring(index)
            local component = create({ Name = "BlankObstacle", Group = "Combat_Menu_Overlay" })
            if type(component) == "table" and component.Id ~= nil then
                attach({ Id = component.Id, DestinationId = button.Id, OffsetX = -145, OffsetY = -105 })
                components[key] = component
                local evaluated = offer.evaluated == true
                textBox({ Id = component.Id, RawText = localization.get(language,
                    evaluated and "evaluated" or "unevaluated"),
                    Font = "LatoBold", FontSize = 18, Justification = "Center",
                    ShadowBlur = 0, ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 1 } })
                local entry = { id = component.Id, key = key, originalIndex = index }
                table.insert(rankState(screen), entry)
                local visibleReasons = evaluated and formatReasonLabels(offer.reasons) or {}
                if evaluated and #visibleReasons > 0 then
                    local reasonComponent = create({ Name = "BlankObstacle", Group = "Combat_Menu_Overlay" })
                    if type(reasonComponent) == "table" and reasonComponent.Id ~= nil then
                        local reasonKey = "BoonAdvisorReasons" .. tostring(index)
                        attach({ Id = reasonComponent.Id, DestinationId = button.Id,
                            OffsetX = -145, OffsetY = -86 })
                        components[reasonKey] = reasonComponent
                        textBox({ Id = reasonComponent.Id, RawText = table.concat(visibleReasons, " · "),
                            Font = "LatoBold", FontSize = 16, Justification = "Center",
                            ShadowBlur = 0, ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 1 } })
                        entry.reasonId, entry.reasonKey = reasonComponent.Id, reasonKey
                    end
                end
            end
        end
    end
end

function UI.renderRanks(screen, rankedScores, api)
    debugLog("UI renderRanks entered")
    local createScreenComponent = type(api) == "table" and api.CreateScreenComponent or nil
    local attach = type(api) == "table" and api.Attach or nil
    local createTextBox = type(api) == "table" and api.CreateTextBox or nil
    debugLog("UI API CreateScreenComponent=" .. tostring(type(createScreenComponent) == "function"))
    debugLog("UI API Attach=" .. tostring(type(attach) == "function"))
    debugLog("UI API CreateTextBox=" .. tostring(type(createTextBox) == "function"))
    UI.clearRanks(screen, api)
    if type(screen) ~= "table" or type(rankedScores) ~= "table" then
        return
    end
    if type(createScreenComponent) ~= "function" then
        debugLog("UI ERROR missing native API CreateScreenComponent")
        return
    end
    if type(attach) ~= "function" then
        debugLog("UI ERROR missing native API Attach")
        return
    end
    if type(createTextBox) ~= "function" then
        debugLog("UI ERROR missing native API CreateTextBox")
        return
    end
    local components = type(screen.Components) == "table" and screen.Components or {}
    for _, result in ipairs(rankedScores) do
        local originalIndex = type(result) == "table" and result.originalIndex or nil
        local rank = type(result) == "table" and result.rank or nil
        local button = type(originalIndex) == "number"
            and components["PurchaseButton" .. originalIndex] or nil
        if button ~= nil and rank ~= nil then
            local component = createScreenComponent({
                Name = "BlankObstacle",
                Group = "Combat_Menu_Overlay",
            })
            if type(component) == "table" and component.Id ~= nil then
                attach({ Id = component.Id, DestinationId = button.Id, OffsetX = -145, OffsetY = -105 })
                local key = "BoonAdvisorRank" .. tostring(originalIndex)
                components[key] = component
                local text = formatRankLabel(rank)
                createTextBox({
                    Id = component.Id,
                    RawText = text,
                    Font = "LatoBold",
                    FontSize = 24,
                    Justification = "Center",
                    ShadowBlur = 0,
                    ShadowColor = { 0, 0, 0, 1 },
                    ShadowOffset = { 0, 2 },
                })
                table.insert(rankState(screen), { id = component.Id, key = key, originalIndex = originalIndex })
                debugLog("UI Rank rendered originalIndex=" .. tostring(originalIndex) .. " Rank=" .. tostring(rank))
                local labels = formatReasonLabels(type(result) == "table" and result.reasons or nil)
                if #labels > 0 then
                    local reasonComponent = createScreenComponent({
                        Name = "BlankObstacle", Group = "Combat_Menu_Overlay",
                    })
                    if type(reasonComponent) == "table" and reasonComponent.Id ~= nil then
                        attach({ Id = reasonComponent.Id, DestinationId = button.Id,
                            OffsetX = -145, OffsetY = -86 })
                        local reasonKey = "BoonAdvisorReasons" .. tostring(originalIndex)
                        components[reasonKey] = reasonComponent
                        createTextBox({ Id = reasonComponent.Id,
                            RawText = table.concat(labels, " · "), Font = "LatoBold",
                            FontSize = 16, Justification = "Center", ShadowBlur = 0,
                            ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 1 }, })
                        rankState(screen)[#rankState(screen)].reasonId = reasonComponent.Id
                        rankState(screen)[#rankState(screen)].reasonKey = reasonKey
                        debugLog("UI Reasons rendered originalIndex=" .. tostring(originalIndex)
                            .. " Labels=" .. table.concat(labels, "|"))
                    end
                end
            end
        end
    end
end

return UI
