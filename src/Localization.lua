local Localization = {}

local strings = {
    en = {
        rank = "RANK", evaluated = "EVALUATED", unevaluated = "NOT EVALUATED",
        profileAmbiguous = "PROFILE SELECTION REQUIRED",
        profileUnsupported = "PROFILE NOT SUPPORTED",
        replacementUnevaluated = "REPLACEMENT NOT EVALUATED",
        rankingUnreliable = "Ranking not reliable",
        incompleteAnalysis = "INCOMPLETE ANALYSIS",
        noReliablePreference = "NO RELIABLE PREFERENCE",
        partialRanking = "PARTIAL RANKING",
        partialRankingScope = "Ranks compare 2 evaluated choices only",
        equivalentChoices = "Choices are equivalent under the current rules",
        conflict = "Conflict", core = "Core", utility = "Utility", build = "Build",
        resources = "Resources", damage = "Damage", aspect = "Aspect", setup = "Setup",
        positioning = "Positioning", origination = "Origination", hammer = "Hammer",
        hammerPriority = "Hammer plan",
        status = "Status", synergy = "Synergy", survival = "Survival", rarity = "Rarity",
    },
    fr = {
        rank = "RANG", evaluated = "ÉVALUÉ", unevaluated = "NON ÉVALUÉ",
        profileAmbiguous = "PROFIL À CHOISIR",
        profileUnsupported = "PROFIL NON PRIS EN CHARGE",
        replacementUnevaluated = "REMPLACEMENT NON ÉVALUÉ",
        rankingUnreliable = "Classement non fiable",
        incompleteAnalysis = "ANALYSE INCOMPLÈTE",
        noReliablePreference = "PAS DE PRÉFÉRENCE FIABLE",
        partialRanking = "CLASSEMENT PARTIEL",
        partialRankingScope = "Rangs limités aux 2 choix évalués",
        equivalentChoices = "Choix équivalents avec les règles actuelles",
        conflict = "Conflit", core = "Core", utility = "Utilitaire", build = "Build",
        resources = "Ressources", damage = "Dégâts", aspect = "Aspect", setup = "Setup",
        positioning = "Positionnement", origination = "Origination", hammer = "Marteau",
        hammerPriority = "Plan Marteau",
        status = "Statut", synergy = "Synergie", survival = "Survie", rarity = "Rareté",
    },
}

local reasonKeys = {
    FILL_EMPTY_PRIMARY_CORE = "core", FILL_EMPTY_UTILITY_CORE = "utility",
    BUILD_CORE_PRIORITY = "build", BUILD_PREFERRED = "build", BUILD_DISCOURAGED = "build",
    RARITY = "rarity", RARITY_DELTA = "rarity", BUILD_STATUS_SYNERGY = "status",
    BLOOD_DROP_ENGINE_SYNERGY = "synergy", SURVIVAL_SUPPORT = "survival",
    MAX_RESOURCE_SUPPORT = "resources", HIGH_HEALTH_OFFENSE = "damage",
    BUILD_SLOT_POLICY_DELTA = "build", ASPECT_COMPATIBLE = "aspect",
    ASPECT_DIRECT_SYNERGY = "aspect", ASPECT_SETUP_SYNERGY = "setup",
    BACKSTAB_SETUP = "positioning", ORIGINATION_ENABLE = "origination",
    EXISTING_HAMMER_SYNERGY = "hammer",
    HAMMER_BUILD_PRIORITY = "hammerPriority",
}

function Localization.normalizeLanguage(value)
    if value == "fr" then return "fr" end
    return "en"
end

function Localization.resolveLanguage(gameGlobals)
    local getter = type(gameGlobals) == "table" and gameGlobals.GetLanguage or nil
    if type(getter) ~= "function" then return "en" end
    local ok, value = pcall(getter, {})
    if not ok or type(value) ~= "string" then return "en" end
    return Localization.normalizeLanguage(value)
end

function Localization.get(language, key)
    local value = strings[Localization.normalizeLanguage(language)][key]
        or strings.en[key]
    if value ~= nil then return value end
    return "TEXT UNAVAILABLE"
end

function Localization.reasonKey(code, delta)
    if code == "BUILD_SLOT_POLICY_DELTA" and type(delta) == "number" and delta < 0 then
        return "conflict"
    end
    return reasonKeys[code]
end

function Localization.reasonLabel(language, code, delta)
    local key = Localization.reasonKey(code, delta)
    return key and Localization.get(language, key) or nil
end

function Localization.formatIncompleteCount(language, count)
    count = type(count) == "number" and count or 0
    if Localization.normalizeLanguage(language) == "fr" then
        return tostring(count) .. " choix non évalué" .. (count == 1 and "" or "s")
            .. " — classement masqué"
    end
    return tostring(count) .. " choice" .. (count == 1 and "" or "s")
        .. " not evaluated — ranking hidden"
end

return Localization
