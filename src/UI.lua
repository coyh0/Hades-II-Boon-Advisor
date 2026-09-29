local UI = {}
local debugLog = function() end
local errorLog = function() end
local localization = nil
local language = "en"
local reasonOrder = { "conflict", "core", "utility", "build", "discouraged", "resources", "damage", "aspect", "setup", "positioning", "origination", "hammerPriority", "hammer", "status", "synergy", "survival", "rarity" }
local offerLabelLayout = {
    rank = { offsetX = -145, offsetY = -120, width = 210, height = 28, fontSize = 20 },
    reasons = { offsetX = -145, offsetY = -88, width = 300, height = 24, fontSize = 14 },
    pomStatus = { offsetX = -145, offsetY = -120, width = 230, height = 28, fontSize = 16 },
    advisory = { offsetX = -315, offsetY = -120, width = 250, height = 28, fontSize = 15 },
}

local function buildOverviewLayout(centerX, centerY)
    centerX = type(centerX) == "number" and centerX > 0 and centerX or 960
    centerY = type(centerY) == "number" and centerY > 0 and centerY or 540
    local screenWidth = centerX * 2
    local margin = math.max(12, screenWidth * 0.01)
    local width = math.min(420, screenWidth * 0.30)
    return {
        -- Right justification anchors the visible line at the component X;
        -- do not subtract half the text box width or the label sits too far left.
        x = screenWidth - margin,
        y = centerY * 0.09,
        width = width,
        height = 32,
    }
end

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
    local centerY = type(ScreenCenterY) == "number" and ScreenCenterY or 540
    local overviewLayout = buildOverviewLayout(centerX, centerY)
    local items = {}
    local function addText(rawText, y, width, height, fontSize, justification)
        local component = create({ Name = "BlankObstacle", Group = "Combat_Menu_Overlay",
            X = overviewLayout.x, Y = y,
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
        overviewLayout.y, overviewLayout.width, overviewLayout.height, 16, "Right")
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

function UI.clearCoreAdvisory(screen, api)
    if type(screen) ~= "table" or type(screen.BoonAdvisorCoreAdvisory) ~= "table" then return end
    local entry = screen.BoonAdvisorCoreAdvisory
    screen.BoonAdvisorCoreAdvisory = nil
    if type(screen.Components) == "table" then screen.Components.BoonAdvisorCoreAdvisory = nil end
    if entry.id ~= nil and type(api) == "table" and type(api.Destroy) == "function" then
        api.Destroy({ Ids = { entry.id } })
    end
end

function UI.pomBuildStatus(profile, result)
    if type(profile) ~= "table" or type(profile.source) ~= "table"
        or profile.source.type ~= "mobalytics" or type(result) ~= "table"
        or type(result.itemName) ~= "string" or result.itemName == ""
        or type(profile.sourceScoring) ~= "table"
        or type(profile.sourceScoring.boons) ~= "table" then
        return "unknown"
    end

    local group = profile.sourceScoring.boons[result.itemName]
    if group == "Core Boons" then
        local entry = type(profile.corePlan) == "table" and profile.corePlan[result.itemName] or nil
        local names = type(entry) == "table" and entry.displayName or nil
        local validRoles = { Attack = true, Special = true, Cast = true, Mana = true, Sprint = true }
        local fieldsValid = type(entry) == "table"
        if fieldsValid then
            for key in pairs(entry) do
                if key ~= "role" and key ~= "displayName" then fieldsValid = false end
            end
        end
        if type(names) == "table" then
            for key in pairs(names) do
                if key ~= "en" and key ~= "fr" then fieldsValid = false end
            end
        else
            fieldsValid = false
        end
        if fieldsValid and validRoles[entry.role]
            and type(names) == "table" and type(names.en) == "string" and names.en ~= ""
            and type(names.fr) == "string" and names.fr ~= "" then
            return "core_build"
        end
        return "unknown"
    end
    if group == "Non-Core Boons" or group == "NPC Offerings" then
        return "build"
    end
    if group == nil then
        if result.covered == true and result.scoreComplete == true then
            return "not_in_build"
        end
        return "unknown"
    end
    return "unknown"
end

function UI.clearPomStatuses(screen, api)
    if type(screen) ~= "table" or type(screen.BoonAdvisorPomStatuses) ~= "table" then return end
    local ids = {}
    for _, entry in ipairs(screen.BoonAdvisorPomStatuses) do
        if type(entry) == "table" and entry.id ~= nil then ids[#ids + 1] = entry.id end
        if type(entry) == "table" and type(screen.Components) == "table" and entry.key ~= nil then
            screen.Components[entry.key] = nil
        end
    end
    screen.BoonAdvisorPomStatuses = nil
    if #ids > 0 and type(api) == "table" and type(api.Destroy) == "function" then
        api.Destroy({ Ids = ids })
    end
end

function UI.renderPomTieStatuses(screen, results, profile, api)
    UI.clearPomStatuses(screen, api)
    if type(screen) ~= "table" or type(screen.Components) ~= "table"
        or type(results) ~= "table" or type(profile) ~= "table"
        or type(profile.source) ~= "table" or profile.source.type ~= "mobalytics" then
        return false
    end

    local eligible, commonScore = {}, nil
    for _, result in ipairs(results) do
        if type(result) == "table" and result.eligible == true then
            if result.supported ~= true or result.covered ~= true or result.scoreComplete ~= true
                or type(result.score) ~= "number" then
                return false
            end
            for _, reason in ipairs(type(result.reasons) == "table" and result.reasons or {}) do
                if type(reason) == "table" and reason.code == "REPLACEMENT_UNRESOLVED" then
                    return false
                end
            end
            if commonScore == nil then commonScore = result.score
            elseif result.score ~= commonScore then return false end
            eligible[#eligible + 1] = result
        end
    end
    if #eligible < 2 then return false end

    local create = type(api) == "table" and api.CreateScreenComponent or nil
    local attach = type(api) == "table" and api.Attach or nil
    local textBox = type(api) == "table" and api.CreateTextBox or nil
    if type(create) ~= "function" or type(attach) ~= "function" or type(textBox) ~= "function" then
        return false
    end

    screen.BoonAdvisorPomStatuses = {}
    local components = screen.Components
    for _, result in ipairs(eligible) do
        local index = result.originalIndex
        local button = type(index) == "number" and components["PurchaseButton" .. index] or nil
        local status = UI.pomBuildStatus(profile, result)
        local keyName = status == "core_build" and "pomCoreBuildStatus"
            or status == "build" and "pomBuildStatus"
            or status == "unknown" and "unevaluated" or nil
        if button ~= nil and button.Id ~= nil and keyName ~= nil then
            local component = create({ Name = "BlankObstacle", Group = "Combat_Menu_Overlay" })
            if type(component) == "table" and component.Id ~= nil then
                local layout = offerLabelLayout.pomStatus
                attach({ Id = component.Id, DestinationId = button.Id,
                    OffsetX = layout.offsetX, OffsetY = layout.offsetY })
                local key = "BoonAdvisorPomStatus" .. tostring(index)
                components[key] = component
                textBox({ Id = component.Id, RawText = localization.get(language, keyName),
                    Width = layout.width, Height = layout.height, Font = "LatoBold",
                    FontSize = layout.fontSize, Justification = "Center", ShadowBlur = 0,
                    ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 1 } })
                table.insert(screen.BoonAdvisorPomStatuses, { id = component.Id, key = key })
            end
        end
    end
    return true
end

function UI.renderCoreAdvisory(screen, show, api)
    UI.clearCoreAdvisory(screen, api)
    if show ~= true or type(screen) ~= "table" or type(screen.Components) ~= "table" then return end
    local button = screen.Components.PurchaseButton1
    if type(button) ~= "table" or button.Id == nil then
        local firstIndex = nil
        for key, candidate in pairs(screen.Components) do
            local index = type(key) == "string" and tonumber(key:match("^PurchaseButton(%d+)$")) or nil
            if index ~= nil and type(candidate) == "table" and candidate.Id ~= nil
                and (firstIndex == nil or index < firstIndex) then
                firstIndex, button = index, candidate
            end
        end
    end
    local create = type(api) == "table" and api.CreateScreenComponent or nil
    local attach = type(api) == "table" and api.Attach or nil
    local textBox = type(api) == "table" and api.CreateTextBox or nil
    if type(button) ~= "table" or button.Id == nil
        or type(create) ~= "function" or type(attach) ~= "function"
        or type(textBox) ~= "function" then return end
    local component = create({ Name = "BlankObstacle", Group = "Combat_Menu_Overlay" })
    if type(component) ~= "table" or component.Id == nil then return end
    local layout = offerLabelLayout.advisory
    attach({ Id = component.Id, DestinationId = button.Id,
        OffsetX = layout.offsetX, OffsetY = layout.offsetY })
    screen.Components.BoonAdvisorCoreAdvisory = component
    screen.BoonAdvisorCoreAdvisory = { id = component.Id }
    textBox({ Id = component.Id, RawText = localization.formatMissingCore(language),
        Width = layout.width, Height = layout.height,
        Font = "LatoBold", FontSize = layout.fontSize, Justification = "Center", ShadowBlur = 0,
        ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 1 } })
end

function UI.clearGodPoolContext(screen, api)
    if type(screen) ~= "table" or type(screen.BoonAdvisorGodPoolContext) ~= "table" then return end
    local ids = screen.BoonAdvisorGodPoolContext
    screen.BoonAdvisorGodPoolContext = nil
    if type(screen.Components) == "table" then
        screen.Components.BoonAdvisorGodPoolBuild = nil
        screen.Components.BoonAdvisorGodPoolRun = nil
    end
    if #ids > 0 and type(api) == "table" and type(api.Destroy) == "function" then
        api.Destroy({ Ids = ids })
    end
end

function UI.renderGodPoolContext(screen, context, api)
    UI.clearGodPoolContext(screen, api)
    if type(screen) ~= "table" or type(screen.Components) ~= "table"
        or type(context) ~= "table" then return end
    local create = type(api) == "table" and api.CreateScreenComponent or nil
    local textBox = type(api) == "table" and api.CreateTextBox or nil
    if type(create) ~= "function" or type(textBox) ~= "function" then return end
    local layout = buildOverviewLayout(ScreenCenterX, ScreenCenterY)
    local ids = {}
    screen.BoonAdvisorGodPoolContext = ids
    local function add(key, status, y, componentKey)
        if status ~= "Yes" and status ~= "No" then status = "Unknown" end
        local component = create({ Name = "BlankObstacle", Group = "Combat_Menu_Overlay",
            X = layout.x, Y = y, Width = layout.width, Height = 22 })
        if type(component) ~= "table" or component.Id == nil then return end
        screen.Components[componentKey] = component
        ids[#ids + 1] = component.Id
        textBox({ Id = component.Id, RawText = localization.get(language, key .. status),
            Width = layout.width, Height = 22, Font = "LatoBold", FontSize = 14,
            Justification = "Right", ShadowBlur = 0,
            ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 1 } })
    end
    add("godPoolBuild", context.recommendedByBuild, layout.y + 29, "BoonAdvisorGodPoolBuild")
    add("godPoolRun", context.observedInRuntimePool, layout.y + 52, "BoonAdvisorGodPoolRun")
end

function UI.clearRanks(screen, api)
    UI.clearCoreAdvisory(screen, api)
    UI.clearGodPoolContext(screen, api)
    UI.clearPomStatuses(screen, api)
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
                local rankLayout = offerLabelLayout.rank
                attach({ Id = component.Id, DestinationId = button.Id,
                    OffsetX = rankLayout.offsetX, OffsetY = rankLayout.offsetY })
                components[key] = component
                local evaluated = offer.evaluated == true
                local label = evaluated and type(offer.rank) == "number" and offer.rankTotal == 2
                    and (formatRankLabel(offer.rank) .. "/2")
                    or localization.get(language, evaluated and "evaluated" or "unevaluated")
                textBox({ Id = component.Id, RawText = label, Width = rankLayout.width, Height = rankLayout.height,
                    Font = "LatoBold", FontSize = rankLayout.fontSize, Justification = "Center",
                    ShadowBlur = 0, ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 1 } })
                local entry = { id = component.Id, key = key, originalIndex = index }
                table.insert(rankState(screen), entry)
                local visibleReasons = evaluated and formatReasonLabels(offer.reasons) or {}
                if evaluated and #visibleReasons > 0 then
                    local reasonComponent = create({ Name = "BlankObstacle", Group = "Combat_Menu_Overlay" })
                    if type(reasonComponent) == "table" and reasonComponent.Id ~= nil then
                        local reasonKey = "BoonAdvisorReasons" .. tostring(index)
                        local reasonLayout = offerLabelLayout.reasons
                        attach({ Id = reasonComponent.Id, DestinationId = button.Id,
                            OffsetX = reasonLayout.offsetX, OffsetY = reasonLayout.offsetY })
                        components[reasonKey] = reasonComponent
                        textBox({ Id = reasonComponent.Id, RawText = table.concat(visibleReasons, " · "),
                            Width = reasonLayout.width, Height = reasonLayout.height,
                            Font = "LatoBold", FontSize = reasonLayout.fontSize, Justification = "Center",
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
                local rankLayout = offerLabelLayout.rank
                attach({ Id = component.Id, DestinationId = button.Id,
                    OffsetX = rankLayout.offsetX, OffsetY = rankLayout.offsetY })
                local key = "BoonAdvisorRank" .. tostring(originalIndex)
                components[key] = component
                local text = formatRankLabel(rank)
                createTextBox({
                    Id = component.Id,
                    RawText = text,
                    Font = "LatoBold",
                    Width = rankLayout.width, Height = rankLayout.height,
                    FontSize = rankLayout.fontSize,
                    Justification = "Center",
                    ShadowBlur = 0,
                    ShadowColor = { 0, 0, 0, 1 },
                    ShadowOffset = { 0, 2 },
                })
                local entry = { id = component.Id, key = key, originalIndex = originalIndex }
                table.insert(rankState(screen), entry)
                debugLog("UI Rank rendered originalIndex=" .. tostring(originalIndex) .. " Rank=" .. tostring(rank))
                local labels = formatReasonLabels(type(result) == "table" and result.reasons or nil)
                if #labels > 0 then
                    local reasonComponent = createScreenComponent({
                        Name = "BlankObstacle", Group = "Combat_Menu_Overlay",
                    })
                    if type(reasonComponent) == "table" and reasonComponent.Id ~= nil then
                        local reasonLayout = offerLabelLayout.reasons
                        attach({ Id = reasonComponent.Id, DestinationId = button.Id,
                            OffsetX = reasonLayout.offsetX, OffsetY = reasonLayout.offsetY })
                        local reasonKey = "BoonAdvisorReasons" .. tostring(originalIndex)
                        components[reasonKey] = reasonComponent
                        createTextBox({ Id = reasonComponent.Id,
                            RawText = table.concat(labels, " · "), Font = "LatoBold",
                            Width = reasonLayout.width, Height = reasonLayout.height,
                            FontSize = reasonLayout.fontSize, Justification = "Center", ShadowBlur = 0,
                            ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 1 }, })
                        entry.reasonId = reasonComponent.Id
                        entry.reasonKey = reasonKey
                        debugLog("UI Reasons rendered originalIndex=" .. tostring(originalIndex)
                            .. " Labels=" .. table.concat(labels, "|"))
                    end
                end
            end
        end
    end
end

return UI
