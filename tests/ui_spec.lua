local function check(value, message) assert(value, message) end
local UI = assert(loadfile("src/UI.lua"))()
local Localization = assert(loadfile("src/Localization.lua"))()
UI.setLocalization(Localization)
UI.setLanguage("fr")

local created, textBoxes, attaches, destroyed = {}, {}, {}, {}
local nextId = 0
CreateScreenComponent = function(data)
    nextId = nextId + 1
    local component = { Id = "BoonAdvisorRank" .. nextId, X = data.X, Y = data.Y }
    created[#created + 1] = { data = data, component = component }
    return component
end
CreateTextBox = function(data) textBoxes[#textBoxes + 1] = data end
Attach = function(data) attaches[#attaches + 1] = data end
Destroy = function(data) destroyed[#destroyed + 1] = data end
local api = { CreateScreenComponent = CreateScreenComponent, CreateTextBox = CreateTextBox,
    Attach = Attach, Destroy = Destroy }
ScreenCenterX, ScreenCenterY = 960, 540

local screen = {
    Components = {
        PurchaseButton1 = { Id = "native1", X = 100, Y = 200 },
        PurchaseButton2 = { Id = "native2", X = 300, Y = 200 },
        PurchaseButton3 = { Id = "native3", X = 500, Y = 200 },
    },
}
UI.renderRanks(screen, {
    { originalIndex = 3, rank = 1, reasons = {{ code = "FILL_EMPTY_PRIMARY_CORE", delta = 1 }} },
    { originalIndex = 1, rank = 1, reasons = {{ code = "ASPECT_COMPATIBLE", delta = 1 }} },
    { originalIndex = 2, rank = 3, reasons = {{ code = "FILL_EMPTY_UTILITY_CORE", delta = 1 }} },
}, api)
check(#created == 6 and #textBoxes == 6, "rank and reason components/text were not created")
check(attaches[1].DestinationId == "native3" and attaches[3].DestinationId == "native1",
    "rank components were not attached to originalIndex buttons")
check(attaches[1].OffsetX == -145 and attaches[1].OffsetY == -105,
    "rank component offsets were not applied")
check(textBoxes[1].RawText == "RANG 1" and textBoxes[5].RawText == "RANG 3"
    and textBoxes[2].RawText == "Core",
    "rank labels were not formatted")
check(textBoxes[1].RawText == "RANG 1" and textBoxes[3].RawText == "RANG 1"
    and textBoxes[5].RawText == "RANG 3", "competition ranking 1/1/3 was not preserved")
check(textBoxes[1].FontSize == 24, "rank badge font size was not reduced")
check(screen.BoonAdvisorRanks[1].originalIndex == 3
    and screen.BoonAdvisorRanks[2].originalIndex == 1,
    "private rank ownership lost originalIndex mapping")
check(screen.Components.BoonAdvisorRank3 ~= nil and screen.Components.PurchaseButton3.Id == "native3",
    "private rank component overwrote or bypassed native component storage")
local buildLabelScreen = { Components = {
    PurchaseButton1 = { Id = "build1" }, PurchaseButton2 = { Id = "build2" },
    PurchaseButton3 = { Id = "build3" },
} }
UI.renderRanks(buildLabelScreen, {
    { originalIndex = 1, rank = 1, reasons = {
        { code = "BUILD_CORE_PRIORITY", delta = 4 },
        { code = "BUILD_PREFERRED", delta = 2 },
    } },
    { originalIndex = 2, rank = 2, reasons = {
        { code = "FILL_EMPTY_UTILITY_CORE", delta = 4 },
        { code = "BUILD_PREFERRED", delta = 2 },
        { code = "BUILD_CORE_PRIORITY", delta = 4 },
    } },
    { originalIndex = 3, rank = 3, reasons = {
        { code = "BUILD_STATUS_SYNERGY", delta = 4 },
        { code = "BLOOD_DROP_ENGINE_SYNERGY", delta = 4 },
    } },
}, api)
local sawBuild, sawUtilityBuild = false, false
local sawStatus, sawSynergy = false, false
for index = #textBoxes - 5, #textBoxes do
    if textBoxes[index].RawText == "Build" then sawBuild = true end
    if textBoxes[index].RawText == "Utilitaire · Build" then sawUtilityBuild = true end
    if textBoxes[index].RawText == "Statut · Synergie" then sawStatus = true end
end
check(sawBuild and sawUtilityBuild and sawStatus,
    "Build priority labels were not rendered or deduplicated")
local setupLabelScreen = { Components = { PurchaseButton1 = { Id = "setup1" } } }
UI.renderRanks(setupLabelScreen, {
    { originalIndex = 1, rank = 1, reasons = {
        { code = "ASPECT_DIRECT_SYNERGY", delta = 8 },
        { code = "ASPECT_SETUP_SYNERGY", delta = 4 },
        { code = "ASPECT_SETUP_SYNERGY", delta = 4 },
    } },
}, api)
check(textBoxes[#textBoxes].RawText == "Aspect · Setup",
    "ASPECT_SETUP_SYNERGY was not rendered once with the generic Setup label")
UI.clearRanks(setupLabelScreen, api)
local conflictScreen = { Components = {
    PurchaseButton1 = { Id = "conflict1" }, PurchaseButton2 = { Id = "conflict2" },
    PurchaseButton3 = { Id = "conflict3" },
} }
UI.renderRanks(conflictScreen, {
    { originalIndex = 1, rank = 1, reasons = {
        { code = "ASPECT_COMPATIBLE", delta = 4 },
        { code = "BUILD_SLOT_POLICY_DELTA", delta = -4 },
        { code = "RARITY", delta = 1 },
    } },
}, api)
check(textBoxes[#textBoxes - 1].RawText == "RANG 1"
    and textBoxes[#textBoxes].RawText == "Conflit · Aspect",
    "negative slot policy was not prioritized in the two-label UI: " .. tostring(textBoxes[#textBoxes].RawText))
local rarityFirstScreen = { Components = { PurchaseButton1 = { Id = "rarity-first" } } }
UI.renderRanks(rarityFirstScreen, {
    { originalIndex = 1, rank = 1, reasons = {
        { code = "RARITY", delta = 3 },
        { code = "BUILD_STATUS_SYNERGY", delta = 4 },
        { code = "ASPECT_COMPATIBLE", delta = 4 },
    } },
}, api)
check(textBoxes[#textBoxes].RawText == "Aspect · Statut"
    and not textBoxes[#textBoxes].RawText:match("Rareté")
    and not textBoxes[#textBoxes].RawText:match(" · $"),
    "rarity was not filtered while preserving two displayable reasons")
UI.clearRanks(rarityFirstScreen, api)
local rankedNoReasonsScreen = { Components = { PurchaseButton1 = { Id = "ranked-no-reasons" } } }
local rankedNoReasonsBefore = #textBoxes
UI.renderRanks(rankedNoReasonsScreen, {
    { originalIndex = 1, rank = 2, reasons = {{ code = "RARITY_DELTA", delta = 1 }} },
}, api)
check(#textBoxes == rankedNoReasonsBefore + 1 and textBoxes[#textBoxes].RawText == "RANG 2",
    "ranked item with no visible reasons rendered an empty reason line")
UI.clearRanks(rankedNoReasonsScreen, api)
local longReasonsScreen = { Components = { PurchaseButton1 = { Id = "long-reasons" } } }
UI.renderRanks(longReasonsScreen, {
    { originalIndex = 1, rank = 1, reasons = {
        { code = "BUILD_SLOT_POLICY_DELTA", delta = -4 },
        { code = "ORIGINATION_ENABLE", delta = 8 },
        { code = "EXISTING_HAMMER_SYNERGY", delta = 4 },
    } },
}, api)
check(textBoxes[#textBoxes].RawText == "Conflit · Origination"
    and not textBoxes[#textBoxes].RawText:match("^ ·")
    and not textBoxes[#textBoxes].RawText:match(" · $")
    and not textBoxes[#textBoxes].RawText:match(" · .* · "),
    "long reason combination exceeded two unique visible labels")
UI.clearRanks(longReasonsScreen, api)
UI.clearRanks(conflictScreen, api)
local policyPositive = { Components = { PurchaseButton1 = { Id = "policy-positive" } } }
UI.renderRanks(policyPositive, {
    { originalIndex = 1, rank = 1, reasons = {{ code = "BUILD_SLOT_POLICY_DELTA", delta = 4 }} },
}, api)
check(textBoxes[#textBoxes].RawText == "Build", "positive slot policy was not labelled Build")
UI.clearRanks(policyPositive, api)
local policyZero = { Components = { PurchaseButton1 = { Id = "policy-zero" } } }
local beforeZero = #textBoxes
UI.renderRanks(policyZero, {
    { originalIndex = 1, rank = 1, reasons = {{ code = "BUILD_SLOT_POLICY_DELTA", delta = 0 }} },
}, api)
check(#textBoxes == beforeZero + 1, "zero slot policy rendered an unnecessary label")
UI.clearRanks(policyZero, api)
local survivalScreen = { Components = { PurchaseButton1 = { Id = "survival1" } } }
UI.renderRanks(survivalScreen, {
    { originalIndex = 1, rank = 1, reasons = {{ code = "SURVIVAL_SUPPORT", delta = 2 }} },
}, api)
check(textBoxes[#textBoxes].RawText == "Survie",
    "SURVIVAL_SUPPORT was not rendered as Survie")
UI.clearRanks(survivalScreen, api)
local resourceScreen = { Components = { PurchaseButton1 = { Id = "resource1" } } }
UI.renderRanks(resourceScreen, {
    { originalIndex = 1, rank = 1, reasons = {
        { code = "MAX_RESOURCE_SUPPORT", delta = 2 },
        { code = "BUILD_PREFERRED", delta = 2 },
    } },
}, api)
check(textBoxes[#textBoxes].RawText == "Build · Ressources",
    "MAX_RESOURCE_SUPPORT was not rendered as Ressources: " .. tostring(textBoxes[#textBoxes].RawText))
UI.clearRanks(resourceScreen, api)
local damageScreen = { Components = { PurchaseButton1 = { Id = "damage1" } } }
UI.renderRanks(damageScreen, {
    { originalIndex = 1, rank = 1, reasons = {{ code = "HIGH_HEALTH_OFFENSE", delta = 2 }} },
}, api)
check(textBoxes[#textBoxes].RawText:sub(1, 1) == "D" and #textBoxes[#textBoxes].RawText > 5,
    "HIGH_HEALTH_OFFENSE was not rendered as Dégâts")
UI.clearRanks(damageScreen, api)
UI.clearRanks(buildLabelScreen, api)
local destroysBeforePrimaryClear = #destroyed
UI.clearRanks(screen, api)
check(#destroyed == destroysBeforePrimaryClear + 1 and #destroyed[#destroyed].Ids == 6 and #screen.BoonAdvisorRanks == 0
    and screen.Components.BoonAdvisorRank3 == nil,
    "clearRanks did not destroy all private rank components")
UI.clearRanks(screen, api)
check(#destroyed == destroysBeforePrimaryClear + 1, "clearRanks was not idempotent")
UI.clearRanks({ Components = nil }, api)
local fallbackScreen = { Components = { PurchaseButton1 = { Id = "purchase1" } } }
UI.renderFallback(fallbackScreen, { code = "INCOMPLETE_ANALYSIS", title = "ANALYSE INCOMPLÈTE",
    subtitle = "1 choix non évalué", incompleteCount = 1 }, api)
check(fallbackScreen.BoonAdvisorFallback ~= nil and textBoxes[#textBoxes - 1].RawText == "ANALYSE INCOMPLÈTE"
    and textBoxes[#textBoxes].RawText == "1 choix non évalué — classement masqué", "fallback was not rendered")
check(attaches[#attaches].OffsetX == 405 and attaches[#attaches].OffsetY == -170
    and attaches[#attaches].DestinationId == "purchase1",
    "fallback was not positioned above the purchase stack")
check(textBoxes[#textBoxes - 1].Width == 600 and textBoxes[#textBoxes].Width == 600,
    "fallback text did not use the global native width")
UI.clearFallback(fallbackScreen, api)
check(fallbackScreen.BoonAdvisorFallback == nil and screen.Components.BoonAdvisorFallback == nil,
    "fallback cleanup failed")
local ambiguousScreen = { Components = { PurchaseButton1 = { Id = "purchase1" } } }
UI.renderFallback(ambiguousScreen, { code = "AMBIGUOUS_PROFILE" }, api)
check(textBoxes[#textBoxes].RawText == "PROFIL À CHOISIR",
    "ambiguous profile fallback label was not rendered")
UI.clearFallback(ambiguousScreen, api)
local pluralFallbackScreen = { Components = { PurchaseButton1 = { Id = "purchase-plural" } } }
UI.renderFallback(pluralFallbackScreen, { code = "INCOMPLETE_ANALYSIS", title = "ANALYSE INCOMPLÈTE",
    subtitle = "Classement global indisponible", incompleteCount = 2 }, api)
check(textBoxes[#textBoxes].RawText == "2 choix non évalués — classement masqué",
    "plural incomplete-analysis subtitle was not rendered")
UI.clearFallback(pluralFallbackScreen, api)
local function partialReasonText(reasons)
    local partialReasonScreen = { Components = { PurchaseButton1 = { Id = "partial-reason" } } }
    local before = #textBoxes
    UI.renderPartial(partialReasonScreen, { { originalIndex = 1, evaluated = true, reasons = reasons } }, api)
    local added = {}
    for index = before + 1, #textBoxes do added[#added + 1] = textBoxes[index].RawText end
    UI.clearRanks(partialReasonScreen, api)
    return added
end
local onlyRarity = partialReasonText({ { code = "RARITY", delta = 1 } })
check(#onlyRarity == 1 and onlyRarity[1] == "ÉVALUÉ", "only RARITY leaked into partial UI")
local onlyRarityDelta = partialReasonText({ { code = "RARITY_DELTA", delta = 1 } })
check(#onlyRarityDelta == 1 and onlyRarityDelta[1] == "ÉVALUÉ", "only RARITY_DELTA leaked into partial UI")
local rarityAndOne = partialReasonText({ { code = "RARITY", delta = 1 },
    { code = "FILL_EMPTY_PRIMARY_CORE", delta = 1 } })
check(#rarityAndOne == 2 and rarityAndOne[2] == "Core", "RARITY hid the normal partial reason")
local rarityAndTwo = partialReasonText({ { code = "RARITY", delta = 1 },
    { code = "FILL_EMPTY_PRIMARY_CORE", delta = 1 }, { code = "BUILD_PREFERRED", delta = 1 } })
check(#rarityAndTwo == 2 and rarityAndTwo[2] == "Core · Build", "RARITY changed two normal partial reasons")
local partialNoReasons = partialReasonText({})
check(#partialNoReasons == 1 and partialNoReasons[1] == "ÉVALUÉ",
    "evaluated partial item with no visible reasons changed")
local partialScreen = { Components = {
    PurchaseButton1 = { Id = "p1" }, PurchaseButton2 = { Id = "p2" }, PurchaseButton3 = { Id = "p3" },
} }
UI.renderPartial(partialScreen, {
    { originalIndex = 1, evaluated = true, reasons = {
        { code = "FILL_EMPTY_PRIMARY_CORE", delta = 1 }, { code = "ASPECT_COMPATIBLE", delta = 1 },
    } },
    { originalIndex = 2, evaluated = true, reasons = {} },
    { originalIndex = 3, evaluated = false, reasons = {
        { code = "FILL_EMPTY_PRIMARY_CORE", delta = 1 },
    } },
}, api)
check(textBoxes[#textBoxes - 3].RawText == "ÉVALUÉ"
    and textBoxes[#textBoxes - 2].RawText == "Core · Aspect"
    and textBoxes[#textBoxes].RawText == "NON ÉVALUÉ", "partial analysis labels were wrong")
UI.clearRanks(partialScreen, api)
check(partialScreen.Components.BoonAdvisorRank1 == nil
    and partialScreen.Components.BoonAdvisorRank3 == nil, "partial cleanup left stale components")
local uiErrors = {}
UI.setLogger({ debug = function() end, error = function(code) uiErrors[#uiErrors + 1] = code end })
local errorScreen = { Components = { PurchaseButton1 = { Id = "native-error" } } }
local errorApi = { CreateScreenComponent = function() error("create failed") end,
    Attach = Attach, CreateTextBox = CreateTextBox, Destroy = Destroy }
check(not pcall(UI.renderRanks, errorScreen, { { originalIndex = 1, rank = 1 } }, errorApi),
    "CreateScreenComponent error was swallowed")
Attach = function() error("attach failed") end
errorApi.CreateScreenComponent = function() return { Id = "attach-error" } end
errorApi.Attach = function() error("attach failed") end
check(not pcall(UI.renderRanks, errorScreen, { { originalIndex = 1, rank = 1 } }, errorApi),
    "Attach error was swallowed")
errorApi.Attach = Attach
errorApi.CreateTextBox = function() error("textbox failed") end
check(not pcall(UI.renderRanks, errorScreen, { { originalIndex = 1, rank = 1 } }, errorApi),
    "CreateTextBox error was swallowed")
UI.renderRanks(errorScreen, { { originalIndex = 1, rank = 1 } }, { Destroy = Destroy })
UI.renderRanks(errorScreen, { { originalIndex = 1, rank = 1 } },
    { CreateScreenComponent = CreateScreenComponent, CreateTextBox = CreateTextBox, Destroy = Destroy })
UI.renderRanks(errorScreen, { { originalIndex = 1, rank = 1 } },
    { CreateScreenComponent = CreateScreenComponent, Attach = Attach, Destroy = Destroy })
local sawMissingCreate, sawMissingAttach, sawMissingText = false, false, false
for _, message in ipairs(uiErrors) do
    if message == "UI_MISSING_CREATE_SCREEN_COMPONENT" then sawMissingCreate = true end
    if message == "UI_MISSING_ATTACH" then sawMissingAttach = true end
    if message == "UI_MISSING_CREATE_TEXT_BOX" then sawMissingText = true end
end
check(sawMissingCreate and sawMissingAttach and sawMissingText,
    "missing native UI APIs were not diagnosed")
UI.setLanguage("en")
local englishScreen = { Components = { PurchaseButton1 = { Id = "english" } } }
UI.renderRanks(englishScreen, { { originalIndex = 1, rank = 1, reasons = {
    { code = "RARITY", delta = 1 }, { code = "BUILD_PREFERRED", delta = 1 },
} } }, api)
check(textBoxes[#textBoxes - 1].RawText == "RANK 1" and textBoxes[#textBoxes].RawText == "Build",
    "English rank or reason label was not rendered")
UI.clearRanks(englishScreen, api)
local englishFallback = { Components = { PurchaseButton1 = { Id = "english-fallback" } } }
UI.renderFallback(englishFallback, { code = "INCOMPLETE_ANALYSIS", incompleteCount = 2 }, api)
check(textBoxes[#textBoxes - 1].RawText == "INCOMPLETE ANALYSIS"
    and textBoxes[#textBoxes].RawText == "2 choices not evaluated — ranking hidden",
    "English fallback strings were not rendered")
print("PASS: UI rank mapping, ties, private components, idempotent cleanup")
