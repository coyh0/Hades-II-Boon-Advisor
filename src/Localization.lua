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
        discouraged = "Discouraged",
        resources = "Resources", damage = "Damage", aspect = "Aspect", setup = "Setup",
        positioning = "Positioning", origination = "Origination", hammer = "Hammer",
        hammerPriority = "Hammer plan",
        requirements = "Requirements unresolved",
        focus = "Focus", focusNone = "None", focusAttack = "Attack",
        focusSpecial = "Special / rockets", focusRouteUnknown = "Route undecided",
        focusAres = "Ares route", focusZeus = "Zeus route",
        focusChooseBetween = "Choose between:",
        buildIdentity = "Build",
        missingCore = "Boon Core Build Missing",
        godPoolBuildYes = "Build God Pool: Recommended",
        godPoolBuildNo = "Build God Pool: Outside",
        godPoolBuildUnknown = "Build God Pool: Unknown",
        godPoolRunYes = "Run God Pool: Present",
        godPoolRunNo = "Run God Pool: Absent",
        godPoolRunUnknown = "Run God Pool: Unknown",
        buildMedea = "Argent Skull · Aspect of Medea",
        buildMoonstoneAxe = "Moonstone Axe · Aspect of Melinoë",
        pomCore = "Build core", pomAlternative = "Build alternative",
        pomPreferred = "Build preference", pomDiscouraged = "Discouraged",
        pomCoreBuildStatus = "Core Boon · Build", pomBuildStatus = "Build",
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
        discouraged = "Déconseillé",
        resources = "Ressources", damage = "Dégâts", aspect = "Aspect", setup = "Setup",
        positioning = "Positionnement", origination = "Origination", hammer = "Marteau",
        hammerPriority = "Plan Marteau",
        requirements = "Pré-requis non modélisés",
        focus = "Focus", focusNone = "Aucun", focusAttack = "Attaque",
        focusSpecial = "Technique / roquettes", focusRouteUnknown = "Route indéterminée",
        focusAres = "Route Arès", focusZeus = "Route Zeus",
        focusChooseBetween = "Choisir entre :",
        buildIdentity = "Build",
        missingCore = "Boon Core Build Missing",
        godPoolBuildYes = "God Pool du build : recommandé",
        godPoolBuildNo = "God Pool du build : hors sélection",
        godPoolBuildUnknown = "God Pool du build : inconnu",
        godPoolRunYes = "God Pool de la run : présent",
        godPoolRunNo = "God Pool de la run : absent",
        godPoolRunUnknown = "God Pool de la run : inconnu",
        buildMedea = "Argent Skull · Aspect de Médée",
        buildMoonstoneAxe = "Hache Sélénique · Aspect de Mélinoé",
        pomCore = "Core du build", pomAlternative = "Alternative du build",
        pomPreferred = "Préférence du build", pomDiscouraged = "Déconseillé",
        pomCoreBuildStatus = "Boon Core · Build", pomBuildStatus = "Build",
        status = "Statut", synergy = "Synergie", survival = "Survie", rarity = "Rareté",
    },
}

local reasonKeys = {
    FILL_EMPTY_PRIMARY_CORE = "core", FILL_EMPTY_UTILITY_CORE = "utility",
    BUILD_CORE_PRIORITY = "build", BUILD_PREFERRED = "build", BUILD_DISCOURAGED = "discouraged",
    RARITY = "rarity", RARITY_DELTA = "rarity", BUILD_STATUS_SYNERGY = "status",
    BLOOD_DROP_ENGINE_SYNERGY = "synergy", SURVIVAL_SUPPORT = "survival",
    MAX_RESOURCE_SUPPORT = "resources", HIGH_HEALTH_OFFENSE = "damage",
    BUILD_SLOT_POLICY_DELTA = "build", ASPECT_COMPATIBLE = "aspect",
    ASPECT_DIRECT_SYNERGY = "aspect", ASPECT_SETUP_SYNERGY = "setup",
    BACKSTAB_SETUP = "positioning", ORIGINATION_ENABLE = "origination",
    EXISTING_HAMMER_SYNERGY = "hammer",
    HAMMER_BUILD_PRIORITY = "hammerPriority",
    BUILD_NON_CORE = "build", SOURCE_REPLACEMENT_DELTA = "build",
    SOURCE_REQUIREMENTS_UNRESOLVED = "requirements",
    POM_CORE = "pomCore", POM_ALTERNATIVE = "pomAlternative",
    POM_PREFERRED = "pomPreferred", POM_DISCOURAGED = "pomDiscouraged",
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

function Localization.buildName(language, profileId)
    local names = {
        argent_skull_medea_mobalytics = "buildMedea",
        moonstone_axe_melinoe_mobalytics = "buildMoonstoneAxe",
    }
    local key = names[profileId]
    return key and Localization.get(language, key) or nil
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

function Localization.formatMissingCore(language)
    return Localization.get(language, "missingCore")
end

return Localization
