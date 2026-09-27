local UI = {}
local debugLog = function() end
local errorLog = function() end
local localization = nil
local language = "en"
local reasonOrder = { "conflict", "core", "utility", "build", "discouraged", "resources", "damage", "aspect", "setup", "positioning", "origination", "hammerPriority", "hammer", "status", "synergy", "survival", "rarity" }

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
    if type(logger) == "function" then
        debugLog, errorLog = logger, logger
    elseif type(logger) == "table" then
        debugLog = type(logger.debug) == "function" and logger.debug or function() end
        errorLog = type(logger.error) == "function" and logger.error or function() end
    else
        debugLog, errorLog = function() end, function() end
    end
end

function UI.setLocalization(value)
    localization = value
end

function UI.setLanguage(value)
    language = type(value) == "string" and value or "en"
end

local function focusLabel(state, menu)
    if state.focus == "attack" then return localization.get(language, "focusAttack") end
    if state.focus == "special" then
        if menu == "route" then
            return localization.get(language, "focusSpecial") .. " · "
                .. localization.get(language, "focusChooseBetween")
        end
        local route = state.route == "ares" and "focusAres"
            or state.route == "zeus" and "focusZeus" or "focusRouteUnknown"
        return localization.get(language, "focusSpecial") .. " · " .. localization.get(language, route)
    end
    return localization.get(language, "focusNone")
end

function UI.clearFocus(screen, api)
    if type(screen) ~= "table" or type(screen.BoonAdvisorFocus) ~= "table" then return end
    local ids = {}
    for _, entry in ipairs(screen.BoonAdvisorFocus) do
        if entry.id ~= nil then ids[#ids + 1] = entry.id end
        if type(screen.Components) == "table" then screen.Components[entry.key] = nil end
    end
    screen.BoonAdvisorFocus = nil
    if #ids > 0 and type(api) == "table" and type(api.Destroy) == "function" then
        api.Destroy({ Ids = ids })
    end
end

local function focusButton(screen, api, key, y, label, choice)
    local x = (type(ScreenCenterX) == "number" and ScreenCenterX or 960) + 690
    local component = api.CreateScreenComponent({
        Name = choice ~= nil and "BlankInteractableObstacle" or "BlankObstacle", Group = "Combat_Menu_Overlay",
        X = x, Y = y, Width = 310, Height = 30,
    })
    if type(component) ~= "table" or component.Id == nil then return end
    if choice ~= nil then
        component.Screen = screen
        component.BoonAdvisorChoice = choice
        component.OnPressedFunctionName = "BoonAdvisorSelectFocus"
        api.AttachLua({ Id = component.Id, Table = component })
    end
    screen.Components[key] = component
    screen.BoonAdvisorFocus[#screen.BoonAdvisorFocus + 1] = { id = component.Id, key = key }
    api.CreateTextBox({ Id = component.Id, RawText = label, Width = 310,
        Font = "LatoBold", FontSize = 14, Justification = "Center",
        ShadowBlur = 0, ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 1 } })
end

function UI.renderFocus(screen, focus, api, menu)
    UI.clearFocus(screen, api)
    if type(screen) ~= "table" or type(screen.Components) ~= "table"
        or type(focus) ~= "table" or type(api) ~= "table"
        or type(api.CreateScreenComponent) ~= "function"
        or type(api.CreateTextBox) ~= "function" then return end
    screen.BoonAdvisorFocus = {}
    if focus.locked then menu = nil end
    local canInteract = not focus.locked and type(api.AttachLua) == "function"
    focusButton(screen, api, "BoonAdvisorFocusTile", 122,
        localization.get(language, "focus") .. ": " .. focusLabel(focus, menu), canInteract and "open" or nil)
    if canInteract and menu == "focus" then
        focusButton(screen, api, "BoonAdvisorFocusNone", 152,
            localization.get(language, "focusNone"), "focus:none")
        focusButton(screen, api, "BoonAdvisorFocusAttack", 182,
            localization.get(language, "focusAttack"), "focus:attack")
        focusButton(screen, api, "BoonAdvisorFocusSpecial", 212,
            localization.get(language, "focusSpecial"), "focus:special")
    elseif canInteract and menu == "route" then
        focusButton(screen, api, "BoonAdvisorRouteNone", 152,
            localization.get(language, "focusRouteUnknown"), "route:none")
        focusButton(screen, api, "BoonAdvisorRouteAres", 182,
            localization.get(language, "focusAres"), "route:ares")
        focusButton(screen, api, "BoonAdvisorRouteZeus", 212,
            localization.get(language, "focusZeus"), "route:zeus")
    end
end

function UI.syncFocusReminder(hudState, focus, api, forceNew)
    if type(hudState) ~= "table" then return end
    if forceNew then hudState.id, hudState.label = nil, nil end
    local label = type(focus) == "table" and focus.locked
        and (localization.get(language, "focus") .. ": " .. focusLabel(focus)) or nil
    if label == nil then
        if hudState.id ~= nil and type(api) == "table" and type(api.Destroy) == "function" then
            api.Destroy({ Ids = { hudState.id } })
        end
        hudState.id, hudState.label = nil, nil
        return
    end
    if hudState.id ~= nil and hudState.label == label then return end
    if hudState.id ~= nil and type(api.Destroy) == "function" then
        api.Destroy({ Ids = { hudState.id } })
    end
    hudState.id, hudState.label = nil, nil
    if type(api) ~= "table" or type(api.CreateScreenComponent) ~= "function"
        or type(api.CreateTextBox) ~= "function" then return end
    local centerX = type(ScreenCenterX) == "number" and ScreenCenterX or 960
    local width = 440
    local offsetX = math.min(600, centerX * 0.60)
    local component = api.CreateScreenComponent({
        Name = "BlankObstacle", Group = "Combat_UI", X = centerX + offsetX, Y = 100,
        Width = width, Height = 30,
    })
    if type(component) ~= "table" or component.Id == nil then return end
    api.CreateTextBox({ Id = component.Id, RawText = label, Width = width,
        Font = "LatoBold", FontSize = 16, Justification = "Center",
        ShadowBlur = 0, ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 1 } })
    hudState.id, hudState.label = component.Id, label
end

local function clearBuildOverview(state, api)
    if type(state) ~= "table" then return end
    local ids = {}
    for _, item in ipairs(state.items or {}) do
        if item.id ~= nil then ids[#ids + 1] = item.id end
    end
    state.items, state.key = {}, nil
    if #ids > 0 and type(api) == "table" and type(api.Destroy) == "function" then
        -- Room transitions can make these screen IDs stale before the next
        -- refresh. A failed best-effort cleanup must not block re-creation.
        local ok = pcall(api.Destroy, { Ids = ids })
        if not ok then
            errorLog("UI_BUILD_OVERVIEW_DESTROY_FAILED", "Build overview cleanup failed")
        end
    end
end

function UI.syncBuildOverview(overviewState, data, api, forceNew)
    if type(overviewState) ~= "table" then return end
    data = type(data) == "table" and data or {}
    local buildName = type(data.buildName) == "string" and data.buildName or nil
    local key = buildName
    if forceNew or overviewState.key ~= key then clearBuildOverview(overviewState, api) end
    if key == nil then return end
    if overviewState.key == key and #(overviewState.items or {}) > 0 then return end
    local create = type(api) == "table" and api.CreateScreenComponent or nil
    local textBox = type(api) == "table" and api.CreateTextBox or nil
    if type(create) ~= "function" or type(textBox) ~= "function" then return end
    local centerX = type(ScreenCenterX) == "number" and ScreenCenterX or 960
    local items = {}
    local function addText(rawText, y, width, height, fontSize, justification)
        local component = create({ Name = "BlankObstacle", Group = "Combat_UI",
            X = centerX + math.min(580, centerX * 0.60), Y = y,
            Width = width, Height = height })
        if type(component) ~= "table" or component.Id == nil then return false end
        textBox({ Id = component.Id, RawText = rawText, Width = width, Height = height,
            Font = "LatoBold", FontSize = fontSize, Justification = justification,
            ShadowBlur = 0, ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 1 } })
        items[#items + 1] = { id = component.Id }
        return true
    end
    local separator = language == "fr" and " : " or ": "
    addText(localization.get(language, "buildIdentity") .. separator .. buildName,
        140, 760, 32, 16, "Center")
    overviewState.items = items
    -- Leave the cache invalid if the screen component could not be created;
    -- the next HUD refresh can then retry instead of assuming it is visible.
    overviewState.key = #items > 0 and key or nil
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
            errorLog("UI_MISSING_DESTROY", "UI cleanup API Destroy unavailable")
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
    elseif entry.id ~= nil then errorLog("UI_MISSING_DESTROY", "UI cleanup API Destroy unavailable") end
end

function UI.renderFallback(screen, data, api)
    UI.clearFallback(screen, api)
    if type(screen) ~= "table" or type(data) ~= "table" then return end
    local create = type(api) == "table" and api.CreateScreenComponent or nil
    local textBox = type(api) == "table" and api.CreateTextBox or nil
    local attach = type(api) == "table" and api.Attach or nil
    if type(create) ~= "function" or type(textBox) ~= "function" or type(attach) ~= "function" then
        errorLog("UI_MISSING_FALLBACK_API", "UI fallback API unavailable")
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
        PARTIAL_RANKING = "partialRanking",
        REPLACEMENT_UNRESOLVED = "replacementUnevaluated",
        INCOMPLETE_ANALYSIS = "incompleteAnalysis", NO_RELIABLE_PREFERENCE = "noReliablePreference",
    }
    local subtitleKeys = {
        REPLACEMENT_UNRESOLVED = "rankingUnreliable",
        NO_RELIABLE_PREFERENCE = "equivalentChoices", PARTIAL_RANKING = "partialRankingScope",
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
        errorLog("UI_MISSING_PARTIAL_API", "UI partial-analysis API unavailable")
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
                local label = evaluated and type(offer.rank) == "number" and offer.rankTotal == 2
                    and (formatRankLabel(offer.rank) .. "/2")
                    or localization.get(language, evaluated and "evaluated" or "unevaluated")
                textBox({ Id = component.Id, RawText = label,
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
        errorLog("UI_MISSING_CREATE_SCREEN_COMPONENT", "UI CreateScreenComponent unavailable")
        return
    end
    if type(attach) ~= "function" then
        errorLog("UI_MISSING_ATTACH", "UI Attach unavailable")
        return
    end
    if type(createTextBox) ~= "function" then
        errorLog("UI_MISSING_CREATE_TEXT_BOX", "UI CreateTextBox unavailable")
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
