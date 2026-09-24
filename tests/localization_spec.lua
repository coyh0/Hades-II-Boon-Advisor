local function check(value, message) assert(value, message) end
local Localization = assert(loadfile("src/Localization.lua"))()

check(Localization.resolveLanguage({ GetLanguage = function() return "en" end }) == "en",
    "English game language was not selected")
check(Localization.resolveLanguage({ GetLanguage = function() return "fr" end }) == "fr",
    "French game language was not selected")
check(Localization.resolveLanguage({ GetLanguage = function() return "de" end }) == "en",
    "Unsupported game language did not fall back to English")
check(Localization.resolveLanguage({}) == "en", "Missing GetLanguage did not fall back to English")
check(Localization.resolveLanguage({ GetLanguage = function() error("broken") end }) == "en",
    "GetLanguage error did not fall back to English")
check(Localization.resolveLanguage({ GetLanguage = function() return nil end }) == "en",
    "Nil language did not fall back to English")
check(Localization.resolveLanguage({ GetLanguage = function() return 1 end }) == "en",
    "Non-string language did not fall back to English")

check(Localization.get("en", "evaluated") == "EVALUATED", "English string lookup failed")
check(Localization.get("fr", "evaluated") == "ÉVALUÉ", "French string lookup failed")
check(Localization.get("fr", "missing") == "TEXT UNAVAILABLE", "Missing key was not player-safe")
check(Localization.reasonKey("ASPECT_COMPATIBLE", 4) == "aspect",
    "Reason key was not stable")
check(Localization.reasonKey("BUILD_SLOT_POLICY_DELTA", -4) == "conflict",
    "Negative slot policy did not produce stable Conflict key")
check(Localization.reasonKey("UNKNOWN_REASON", 4) == nil,
    "Unknown reason unexpectedly produced a category")
check(Localization.reasonLabel("en", "ASPECT_COMPATIBLE", 4) == "Aspect",
    "English reason label failed")
check(Localization.reasonLabel("fr", "ASPECT_COMPATIBLE", 4) == "Aspect",
    "French reason label failed")
check(Localization.reasonLabel("en", "BUILD_SLOT_POLICY_DELTA", -4) == "Conflict",
    "Negative slot policy was not English Conflict")
check(Localization.reasonLabel("fr", "BUILD_SLOT_POLICY_DELTA", -4) == "Conflit",
    "Negative slot policy was not French Conflit")
check(Localization.reasonKey("BUILD_PREFERRED", 2) == Localization.reasonKey("BUILD_CORE_PRIORITY", 4),
    "Equivalent reason codes did not share a stable category")
check(Localization.reasonKey("HAMMER_BUILD_PRIORITY", -1) == "hammerPriority"
    and Localization.reasonLabel("en", "HAMMER_BUILD_PRIORITY", -1) == "Hammer plan"
    and Localization.reasonLabel("fr", "HAMMER_BUILD_PRIORITY", -1) == "Plan Marteau",
    "Hammer plan reason localization failed")
local stableCategory = Localization.reasonKey("FILL_EMPTY_UTILITY_CORE", 4)
check(stableCategory == "utility"
    and Localization.reasonLabel("en", "FILL_EMPTY_UTILITY_CORE", 4) == "Utility"
    and Localization.reasonLabel("fr", "FILL_EMPTY_UTILITY_CORE", 4) == "Utilitaire",
    "Reason category changed with display language")
check(Localization.formatIncompleteCount("en", 1) == "1 choice not evaluated — ranking hidden",
    "English singular incomplete count failed")
check(Localization.formatIncompleteCount("en", 2) == "2 choices not evaluated — ranking hidden",
    "English plural incomplete count failed")
check(Localization.formatIncompleteCount("fr", 1) == "1 choix non évalué — classement masqué",
    "French singular incomplete count failed")
check(Localization.formatIncompleteCount("fr", 2) == "2 choix non évalués — classement masqué",
    "French plural incomplete count failed")
print("PASS: localization language detection, labels, and incomplete counts")
