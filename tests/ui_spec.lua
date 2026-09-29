local function check(value, message) assert(value, message) end
local function overlaps(a, b)
    return a.left < b.right and b.left < a.right
        and a.top < b.bottom and b.top < a.bottom
end
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
check(attaches[1].OffsetX == -145 and attaches[1].OffsetY == -120,
    "rank component offsets were not applied")
check(textBoxes[1].RawText == "RANG 1" and textBoxes[5].RawText == "RANG 3"
    and textBoxes[2].RawText == "Core",
    "rank labels were not formatted")
check(textBoxes[1].RawText == "RANG 1" and textBoxes[3].RawText == "RANG 1"
    and textBoxes[5].RawText == "RANG 3", "competition ranking 1/1/3 was not preserved")
check(textBoxes[1].FontSize == 20 and textBoxes[1].Width == 210 and textBoxes[1].Height == 28,
    "rank badge dimensions or font size changed unexpectedly")
check(screen.BoonAdvisorRanks[1].originalIndex == 3
    and screen.BoonAdvisorRanks[2].originalIndex == 1,
    "private rank ownership lost originalIndex mapping")
check(screen.Components.BoonAdvisorRank3 ~= nil and screen.Components.PurchaseButton3.Id == "native3",
    "private rank component overwrote or bypassed native component storage")
UI.renderCoreAdvisory(screen, true, api)
check(screen.BoonAdvisorCoreAdvisory ~= nil and created[#created].data.Group == "Combat_Menu_Overlay",
    "three-choice ranked offer did not receive one foreground advisory")
local firstCardRank, threeChoiceNotice
for _, attached in ipairs(attaches) do
    if attached.DestinationId == "native1" and attached.OffsetX == -145
        and attached.OffsetY == -120 then firstCardRank = attached end
    if attached.DestinationId == "native1" and attached.OffsetX == -315 then threeChoiceNotice = attached end
end
check(firstCardRank ~= nil and threeChoiceNotice ~= nil
    and threeChoiceNotice.OffsetY == -120 and firstCardRank.OffsetY == -120
    and threeChoiceNotice.OffsetX + 110 < firstCardRank.OffsetX - 50,
    "Core notice is not aligned with or visually separated from the first-card rank")
local missingCoreScreen = { Components = { PurchaseButton1 = { Id = "native-advisory" } } }
local function checkMissingCorePlacement(language)
    UI.setLanguage(language)
    UI.renderRanks(missingCoreScreen, { { originalIndex = 1, rank = 1,
        reasons = { { code = "BUILD_PREFERRED", delta = 2 } } } }, api)
    UI.renderCoreAdvisory(missingCoreScreen, true, api)
    check(textBoxes[#textBoxes].RawText == "Boon Core Build Missing",
        "offer advisory did not use the single approved label for " .. language)
    local advisoryAttach, advisoryBox = attaches[#attaches], textBoxes[#textBoxes]
    local reasonAttach, reasonBox = attaches[#attaches - 1], textBoxes[#textBoxes - 1]
    local rankAttach, rankBox = attaches[#attaches - 2], textBoxes[#textBoxes - 2]
    check(advisoryAttach.DestinationId == "native-advisory"
        and advisoryAttach.OffsetX == -315 and advisoryAttach.OffsetY == -120
        and advisoryBox.Width == 250 and advisoryBox.Height == 28
        and rankAttach.OffsetY == -120 and advisoryBox.FontSize == 15,
        "missing-Core advisory did not align vertically with the rank")
    check(advisoryAttach.OffsetX + 110 < rankAttach.OffsetX - 50,
        "Core notice text is not visually separated from the rank text")
    check(rankAttach.OffsetY + rankBox.Height / 2
        < reasonAttach.OffsetY - reasonBox.Height / 2,
        "rank and Build reason labels overlap vertically")
    check(reasonBox.RawText == "Build" and reasonAttach.OffsetY > rankAttach.OffsetY,
        "Build reason was removed or not placed lower than the rank row")
    -- DEV 139606 UpgradeChoiceData.lua places the native card icon center at
    -- (-504, -54) relative to PurchaseButton. Its sprite bounds need live QA.
    check(advisoryAttach.OffsetX - 110 > -504 + 70,
        "offer notice text overlaps the native card icon")
    check(created[#created].data.Group == "Combat_Menu_Overlay",
        "offer advisory is not rendered in the foreground overlay group")
    check(missingCoreScreen.Components.BoonAdvisorCoreAdvisory ~= nil,
        "offer-level notice was not tracked independently of rank components")
    UI.clearRanks(missingCoreScreen, api)
    check(missingCoreScreen.Components.BoonAdvisorCoreAdvisory == nil,
        "offer-level notice survived rank cleanup")
end
checkMissingCorePlacement("fr")
checkMissingCorePlacement("en")
local partialAdvisoryScreen = { Components = {
    PurchaseButton1 = { Id = "partial1" }, PurchaseButton2 = { Id = "partial2" },
    PurchaseButton3 = { Id = "partial3" },
} }
UI.renderPartial(partialAdvisoryScreen, {
    { originalIndex = 1, evaluated = true, rank = 1, reasons = {{ code = "BUILD_CORE_PRIORITY", delta = 1 }} },
    { originalIndex = 2, evaluated = true, rank = 2, reasons = {{ code = "BUILD_NON_CORE", delta = 1 }} },
    { originalIndex = 3, evaluated = false, reasons = {} },
}, api)
UI.renderFallback(partialAdvisoryScreen, { code = "PARTIAL_RANKING" }, api)
UI.renderCoreAdvisory(partialAdvisoryScreen, true, api)
check(partialAdvisoryScreen.BoonAdvisorCoreAdvisory ~= nil
    and partialAdvisoryScreen.BoonAdvisorFallback ~= nil
    and partialAdvisoryScreen.Components.BoonAdvisorRank1 ~= nil
    and partialAdvisoryScreen.Components.BoonAdvisorRank3 ~= nil,
    "partial three-choice UI lost the advisory or its per-card evaluation labels")
local partialNoticeAttach, partialFallbackAttach
for _, attached in ipairs(attaches) do
    if attached.DestinationId == "partial1" and attached.OffsetX == -315 then partialNoticeAttach = attached end
    if attached.DestinationId == "partial1" and attached.OffsetX == 405 then partialFallbackAttach = attached end
end
check(partialNoticeAttach ~= nil and partialFallbackAttach ~= nil
    and partialNoticeAttach.OffsetX + 250 / 2 < partialFallbackAttach.OffsetX - 600 / 2,
    "partial-ranking banner overlaps the missing-Core notice")
UI.clearRanks(partialAdvisoryScreen, api)
local noRankingNotice = { Components = { PurchaseButton1 = { Id = "no-ranking-1" } } }
UI.renderFallback(noRankingNotice, { code = "NO_RELIABLE_PREFERENCE" }, api)
UI.renderCoreAdvisory(noRankingNotice, true, api)
local noRankingNoticeAttach, noRankingFallbackAttach
for _, attached in ipairs(attaches) do
    if attached.DestinationId == "no-ranking-1" and attached.OffsetX == -315 then
        noRankingNoticeAttach = attached
    elseif attached.DestinationId == "no-ranking-1" and attached.OffsetX == 405 then
        noRankingFallbackAttach = attached
    end
end
check(noRankingNotice.BoonAdvisorCoreAdvisory ~= nil and noRankingNotice.BoonAdvisorFallback ~= nil
    and noRankingNoticeAttach ~= nil and noRankingFallbackAttach ~= nil
    and noRankingNoticeAttach.OffsetY == -120
    and noRankingNoticeAttach.OffsetX + 250 / 2 < noRankingFallbackAttach.OffsetX - 600 / 2,
    "unranked NO RELIABLE PREFERENCE state overlaps the raised missing-Core notice")
UI.clearRanks(noRankingNotice, api)
UI.clearFallback(noRankingNotice, api)
check(noRankingNotice.BoonAdvisorCoreAdvisory == nil and noRankingNotice.BoonAdvisorFallback == nil,
    "reroll cleanup left stale unranked notice or fallback")
UI.renderRanks(noRankingNotice, { { originalIndex = 1, rank = 1, reasons = {} } }, api)
UI.renderCoreAdvisory(noRankingNotice, true, api)
check(noRankingNotice.BoonAdvisorCoreAdvisory ~= nil and attaches[#attaches].OffsetY == -120,
    "post-reroll ranked offer did not recreate the raised advisory")
UI.clearRanks(noRankingNotice, api)
UI.clearFallback(noRankingNotice, api)
UI.setLanguage("fr")
do
    local pomProfile = {
        source = { type = "mobalytics" },
        sourceScoring = { boons = {
            CorePom = "Core Boons", NonCorePom = "Non-Core Boons",
            FuturePom = "Future Group",
        }, poms = { CorePom = "Poms of Power" } },
        corePlan = { CorePom = { role = "Cast", displayName = { en = "Core Pom", fr = "Boon Core" } } },
    }
    local function pomResult(index, itemName, score)
        return { originalIndex = index, itemName = itemName, score = score,
            eligible = true, supported = true, covered = true, scoreComplete = true }
    end
    check(UI.pomBuildStatus(pomProfile, pomResult(1, "CorePom", 200)) == "core_build",
        "explicit Core plus valid corePlan did not produce the Core build status")
    check(UI.pomBuildStatus(pomProfile, pomResult(2, "NonCorePom", 200)) == "build",
        "explicit Non-Core source classification did not produce the Build status")
    check(UI.pomBuildStatus(pomProfile, pomResult(3, "KnownAbsent", 200)) == "not_in_build",
        "evaluated unlisted boon was incorrectly treated as unknown")
    check(UI.pomBuildStatus(pomProfile, pomResult(4, "FuturePom", 200)) == "unknown",
        "unknown source classification was treated as a known build status")
    local invalidCore = {
        source = { type = "mobalytics" }, sourceScoring = { boons = { CorePom = "Core Boons" } },
        corePlan = { CorePom = { role = "Unknown", displayName = { en = "Core", fr = "Core" } } },
    }
    check(UI.pomBuildStatus(invalidCore, pomResult(1, "CorePom", 200)) == "unknown",
        "invalid Core metadata was promoted to Core Boon · Build")
    local otherSource = { source = { type = "other" }, sourceScoring = pomProfile.sourceScoring,
        corePlan = pomProfile.corePlan }
    check(UI.pomBuildStatus(otherSource, pomResult(1, "CorePom", 200)) == "unknown",
        "non-Mobalytics profile received Mobalytics presentation labels")

    local pomScreen = { Components = {
        PurchaseButton1 = { Id = "pom-card-1", X = 500, Y = 300 },
        PurchaseButton2 = { Id = "pom-card-2", X = 960, Y = 520 },
        PurchaseButton3 = { Id = "pom-card-3", X = 1420, Y = 740 },
        PurchaseButton4 = { Id = "pom-card-4", X = 1420, Y = 960 },
    } }
    UI.setLanguage("en")
    UI.renderFallback(pomScreen, { code = "NO_RELIABLE_PREFERENCE" }, api)
    local tied = {
        pomResult(1, "CorePom", 200), pomResult(2, "NonCorePom", 200),
        pomResult(3, "KnownAbsent", 200), pomResult(4, "FuturePom", 200),
    }
    local textStart, attachStart = #textBoxes, #attaches
    check(UI.renderPomTieStatuses(pomScreen, tied, pomProfile, api),
        "complete equal-score Mobalytics Pom offer did not render status labels")
    check(pomScreen.BoonAdvisorFallback ~= nil
        and (pomScreen.BoonAdvisorRanks == nil or #pomScreen.BoonAdvisorRanks == 0),
        "Pom tie replaced No Reliable Preference or created artificial ranks")
    local shown, expectedAnchors = {}, { ["pom-card-1"] = true, ["pom-card-2"] = true,
        ["pom-card-4"] = true }
    for index = textStart + 1, #textBoxes do shown[textBoxes[index].RawText] = true end
    check(shown["Core Boon · Build"] and shown.Build and shown["NOT EVALUATED"]
        and #textBoxes - textStart == 3,
        "Pom tie did not render per-choice source statuses or rendered a known off-build choice")
    for index = attachStart + 1, #attaches do
        local attached = attaches[index]
        check(expectedAnchors[attached.DestinationId]
            and attached.OffsetX == -145 and attached.OffsetY == -120,
            "Pom status was not centered in the corresponding choice Rank area")
    end
    for index = textStart + 1, #textBoxes do
        local box = textBoxes[index]
        check(box.Width == 230 and box.Height == 28 and box.FontSize == 16
            and box.Justification == "Center",
            "Pom status layout is not centered with the dedicated readable width")
    end
    local labelCount = #textBoxes
    UI.setLanguage("fr")
    UI.clearPomStatuses(pomScreen, api)
    check(pomScreen.BoonAdvisorPomStatuses == nil
        and pomScreen.Components.BoonAdvisorPomStatus1 == nil,
        "reroll/status refresh cleanup left an old Pom status attached")
    check(UI.renderPomTieStatuses(pomScreen, tied, pomProfile, api),
        "French Pom tie statuses were not rendered")
    check(textBoxes[labelCount + 1].RawText == "Boon Core · Build"
        and textBoxes[labelCount + 2].RawText == "Build"
        and textBoxes[labelCount + 3].RawText == "NON ÉVALUÉ",
        "French Pom status localization or ordering changed")
    UI.clearPomStatuses(pomScreen, api)
    check(not UI.renderPomTieStatuses(pomScreen, {
        pomResult(1, "CorePom", 200), pomResult(2, "NonCorePom", 101),
    }, pomProfile, api), "distinct-score Pom offer received tie-only status labels")
    check(not UI.renderPomTieStatuses(pomScreen, {
        pomResult(1, "CorePom", 200),
        { originalIndex = 2, itemName = "NonCorePom", score = 200,
            eligible = true, supported = true, covered = true, scoreComplete = false },
    }, pomProfile, api), "incomplete Pom offer received tie-only status labels")
    check(not UI.renderPomTieStatuses(pomScreen, {
        pomResult(1, "CorePom", 200),
        { originalIndex = 2, itemName = "NonCorePom", score = 200, eligible = true,
            supported = true, covered = true, scoreComplete = true,
            reasons = { { code = "REPLACEMENT_UNRESOLVED", delta = 0 } } },
    }, pomProfile, api), "uncertain replacement received tie-only statuses")
    check(not UI.renderPomTieStatuses(pomScreen, {
        pomResult(1, "CorePom", 200),
    }, pomProfile, api), "single-choice Pom offer received tie-only status labels")
    local rankedPomStart = #textBoxes
    UI.renderRanks(pomScreen, {
        { originalIndex = 1, rank = 1, reasons = {} },
        { originalIndex = 2, rank = 2, reasons = {} },
        { originalIndex = 3, rank = 3, reasons = {} },
    }, api)
    check(textBoxes[rankedPomStart + 1].RawText == "RANG 1"
        and textBoxes[rankedPomStart + 2].RawText == "RANG 2"
        and textBoxes[rankedPomStart + 3].RawText == "RANG 3"
        and attaches[#attaches - 2].OffsetX == -145 and attaches[#attaches - 2].OffsetY == -120,
        "ranked Pom labels or their established position changed")
    UI.clearRanks(pomScreen, api)
    UI.renderPomTieStatuses(pomScreen, tied, pomProfile, api)
    local beforeRankClear = #destroyed
    UI.clearRanks(pomScreen, api)
    check(pomScreen.BoonAdvisorPomStatuses == nil and pomScreen.Components.BoonAdvisorPomStatus1 == nil
        and #destroyed > beforeRankClear,
        "normal offer/rank cleanup did not remove Pom tie labels")
    UI.clearFallback(pomScreen, api)
    UI.setLanguage("fr")
end
local hammerPartialScreen = { Components = {
    PurchaseButton1 = { Id = "daggerHammer1" }, PurchaseButton2 = { Id = "daggerHammer2" },
    PurchaseButton3 = { Id = "daggerHammer3" },
} }
local hammerTextStart = #textBoxes
UI.renderPartial(hammerPartialScreen, {
    { originalIndex = 1, evaluated = true, rank = 1, rankTotal = 2,
        reasons = {{ code = "HAMMER_BUILD_PRIORITY", delta = -1 }} },
    { originalIndex = 2, evaluated = true, rank = 2, rankTotal = 2,
        reasons = {{ code = "HAMMER_BUILD_PRIORITY", delta = -2 }} },
    { originalIndex = 3, evaluated = false, reasons = {} },
}, api)
UI.renderFallback(hammerPartialScreen, { code = "PARTIAL_RANKING" }, api)
local partialSawBanner, partialSawPlanLabel, partialSawUnknown = false, false, false
for index = hammerTextStart + 1, #textBoxes do
    if textBoxes[index].RawText == "CLASSEMENT PARTIEL" then partialSawBanner = true end
    if textBoxes[index].RawText == "Plan Marteau" then partialSawPlanLabel = true end
    if textBoxes[index].RawText == "NON ÉVALUÉ" then partialSawUnknown = true end
end
check(partialSawBanner and partialSawPlanLabel and partialSawUnknown,
    "partial Hammer UI omitted its scope, Hammer explanation, or unknown-choice label")
check(hammerPartialScreen.Components.BoonAdvisorRank1 ~= nil
    and hammerPartialScreen.Components.BoonAdvisorRank2 ~= nil
    and hammerPartialScreen.Components.BoonAdvisorRank3 ~= nil,
    "partial Hammer UI did not annotate all offer cards with their evaluation status")
UI.clearRanks(hammerPartialScreen, api)
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
local discouragedScreen = { Components = {
    PurchaseButton1 = { Id = "discouraged1" }, PurchaseButton2 = { Id = "discouraged2" },
    PurchaseButton3 = { Id = "discouraged3" },
} }
UI.renderRanks(discouragedScreen, {
    { originalIndex = 1, rank = 1, reasons = {
        { code = "FILL_EMPTY_PRIMARY_CORE", delta = 4 },
        { code = "BUILD_DISCOURAGED", delta = -4 },
    } },
}, api)
check(textBoxes[#textBoxes].RawText == "Core · Déconseillé",
    "French discouraged Apollo Special label was not rendered")
UI.clearRanks(discouragedScreen, api)
UI.setLanguage("en")
local discouragedEnglishScreen = { Components = {
    PurchaseButton1 = { Id = "discouraged-en1" }, PurchaseButton2 = { Id = "discouraged-en2" },
    PurchaseButton3 = { Id = "discouraged-en3" },
} }
UI.renderPartial(discouragedEnglishScreen, {
    { originalIndex = 1, evaluated = true, rank = 1, rankTotal = 2, reasons = {
        { code = "FILL_EMPTY_PRIMARY_CORE", delta = 4 },
        { code = "BUILD_DISCOURAGED", delta = -4 },
    } },
    { originalIndex = 2, evaluated = true, rank = 2, rankTotal = 2, reasons = {
        { code = "BUILD_CORE_PRIORITY", delta = 4 },
    } },
    { originalIndex = 3, evaluated = false, reasons = {} },
}, api)
check(textBoxes[#textBoxes - 3].RawText == "Core · Discouraged",
    "English discouraged Apollo Special partial label was not rendered")
UI.setLanguage("fr")
UI.clearRanks(discouragedEnglishScreen, api)
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
check(#destroyed == destroysBeforePrimaryClear + 2
    and #destroyed[destroysBeforePrimaryClear + 1].Ids == 1
    and #destroyed[#destroyed].Ids == 6 and #screen.BoonAdvisorRanks == 0
    and screen.Components.BoonAdvisorRank3 == nil,
    "clearRanks did not destroy all private rank components")
UI.clearRanks(screen, api)
check(#destroyed == destroysBeforePrimaryClear + 2, "clearRanks was not idempotent")
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
local comparedScreen = { Components = {
    PurchaseButton1 = { Id = "compared1" }, PurchaseButton2 = { Id = "compared2" },
    PurchaseButton3 = { Id = "compared3" },
} }
local comparedBefore = #textBoxes
UI.renderPartial(comparedScreen, {
    { originalIndex = 1, evaluated = true, rank = 1, rankTotal = 2, reasons = {} },
    { originalIndex = 2, evaluated = true, rank = 2, rankTotal = 2, reasons = {} },
    { originalIndex = 3, evaluated = false, rank = 1, rankTotal = 2, reasons = {} },
}, api)
check(textBoxes[comparedBefore + 1].RawText == "RANG 1/2"
    and textBoxes[comparedBefore + 2].RawText == "RANG 2/2"
    and textBoxes[comparedBefore + 3].RawText == "NON ÉVALUÉ",
    "partial ranks implied a rank for the unknown choice")
UI.renderFallback(comparedScreen, { code = "PARTIAL_RANKING" }, api)
check(textBoxes[#textBoxes - 1].RawText == "CLASSEMENT PARTIEL"
    and textBoxes[#textBoxes].RawText == "Rangs limités aux 2 choix évalués",
    "French partial-ranking scope was not explicit")
local comparedDestroy = #destroyed
UI.clearRanks(comparedScreen, api)
UI.clearFallback(comparedScreen, api)
check(#destroyed == comparedDestroy + 2 and #comparedScreen.BoonAdvisorRanks == 0
    and comparedScreen.BoonAdvisorFallback == nil,
    "partial ranking cleanup left components")
UI.clearRanks(comparedScreen, api)
UI.clearFallback(comparedScreen, api)
check(#destroyed == comparedDestroy + 2, "partial ranking cleanup was not idempotent")
local unresolvedAttackScreen = { Components = { PurchaseButton1 = { Id = "wounds-unknown" } } }
UI.renderPartial(unresolvedAttackScreen, { { originalIndex = 1, evaluated = false,
    reasons = { { code = "ATTACK_BRANCH_UNRESOLVED", delta = 0 } } } }, api)
check(textBoxes[#textBoxes].RawText == "NON ÉVALUÉ",
    "unresolved Wounds branch displayed a ranked or evaluated label")
UI.clearRanks(unresolvedAttackScreen, api)
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
UI.renderFallback(englishFallback, { code = "PARTIAL_RANKING" }, api)
check(textBoxes[#textBoxes - 1].RawText == "PARTIAL RANKING"
    and textBoxes[#textBoxes].RawText == "Ranks compare 2 evaluated choices only",
    "English partial-ranking scope was not rendered")
local overview = { items = {}, key = nil }
local buildData = { buildName = "Lames Sœurs · Aspect de Morrigan" }
local overviewCreatedStart, overviewTextStart = #created, #textBoxes
local overviewApi = { CreateScreenComponent = CreateScreenComponent, CreateTextBox = CreateTextBox,
    Destroy = Destroy, AttachLua = function(data) attaches[#attaches + 1] = data end }
UI.setLanguage("fr")
UI.syncBuildOverview(overview, buildData, overviewApi)
check(#created == overviewCreatedStart + 1 and #textBoxes == overviewTextStart + 1
    and created[overviewCreatedStart + 1].data.Name == "BlankObstacle"
    and textBoxes[overviewTextStart + 1].RawText == "Build : Lames Sœurs · Aspect de Morrigan",
    "build identity was not rendered alone")
UI.syncBuildOverview(overview, buildData, overviewApi)
check(#created == overviewCreatedStart + 1, "unchanged overview was needlessly recreated")
UI.syncBuildOverview(overview, buildData, overviewApi, true)
check(#created == overviewCreatedStart + 2 and #destroyed > 0
    and textBoxes[#textBoxes].RawText == "Build : Lames Sœurs · Aspect de Morrigan",
    "build identity was not refreshed")
local beforeClear = #destroyed
UI.syncBuildOverview(overview, nil, overviewApi)
check(overview.key == nil and #destroyed == beforeClear + 1,
    "unknown build did not clear the persistent overview")
local staleOverview = { items = { { id = "stale-overview-id" } }, key = "stale-key" }
local staleApi = { Destroy = function() error("screen id already removed during room transition") end,
    CreateScreenComponent = function(data)
        nextId = nextId + 1
        local component = { Id = "recovered-overview" .. nextId }
        created[#created + 1] = { data = data, component = component }
        return component
    end,
    CreateTextBox = CreateTextBox }
UI.syncBuildOverview(staleOverview, { buildName = "Lames Sœurs · Morrigan" }, staleApi, true)
check(staleOverview.key == "Lames Sœurs · Morrigan" and #staleOverview.items == 1,
    "stale screen cleanup failure blocked recreation of the build reminder")
for _, resolution in ipairs({ { 640, 360 }, { 960, 540 }, { 1280, 720 } }) do
    local centerX, centerY = resolution[1], resolution[2]
    ScreenCenterX, ScreenCenterY = centerX, centerY
    local responsive = { items = {}, key = nil }
    UI.syncBuildOverview(responsive, { buildName = "Argent Skull · Aspect of Medea" }, overviewApi, true)
    local componentData, textData = created[#created].data, textBoxes[#textBoxes]
    local screenWidth, screenHeight = centerX * 2, centerY * 2
    check(componentData.Group == "Combat_Menu_Overlay"
        and componentData.X - textData.Width > centerX
        and componentData.X <= screenWidth,
        "build identity text does not clear the centered native title or its screen edge at width " .. screenWidth)
    check(componentData.X > centerX and textData.Justification == "Right"
        and textData.Width == componentData.Width and componentData.Width <= 420
        and componentData.Width <= screenWidth * 0.30
        and componentData.Y - componentData.Height / 2 >= 0
        and componentData.Y <= screenHeight * 0.05
        and math.abs(componentData.X - screenWidth * 0.99) < 0.001
        and textData.FontSize == 16,
        "build identity did not use the upper-right, right-aligned, bounded header placement")
    UI.syncBuildOverview(responsive, nil, overviewApi, true)
end
ScreenCenterX, ScreenCenterY = 960, 540
print("PASS: UI rank mapping, ties, private components, build overview, idempotent cleanup")
