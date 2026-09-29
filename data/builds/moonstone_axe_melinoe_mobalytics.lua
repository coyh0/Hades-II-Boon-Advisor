-- Generated runtime profile from canonical JSON only. Do not edit manually.
return {
    aspect = "AxeRecoveryAspect",
    aspectInteractions = {},
    bloodDropEngine = {
        payoffs = {},
        producers = {},
    },
    constraints = {},
    corePlan = {
        ApolloWeaponBoon = {
            displayName = {
                en = "Nova Strike",
                fr = "Frappe Éclatante",
            },
            role = "Attack",
        },
        DemeterCastBoon = {
            displayName = {
                en = "Arctic Ring",
                fr = "Glyphe Polaire",
            },
            role = "Cast",
        },
        HephaestusManaBoon = {
            displayName = {
                en = "Tough Gain",
                fr = "Conscience Tenace",
            },
            role = "Mana",
        },
        HephaestusSpecialBoon = {
            displayName = {
                en = "Volcanic Flourish",
                fr = "Technique Volcanique",
            },
            role = "Special",
        },
        PoseidonSprintBoon = {
            displayName = {
                en = "Breaker Rush",
                fr = "Ruée Torrentielle",
            },
            role = "Sprint",
        },
    },
    genericCoreAspectCompatibility = false,
    godPool = {
        {
            offerSource = "ApolloUpgrade",
            recommendationId = "mobalytics_axe_melinoe_fullbuild_god_pool_apollo_01",
            sourceGod = "Apollo",
        },
        {
            offerSource = "DemeterUpgrade",
            recommendationId = "mobalytics_axe_melinoe_fullbuild_god_pool_demeter_01",
            sourceGod = "Demeter",
        },
        {
            offerSource = "HephaestusUpgrade",
            recommendationId = "mobalytics_axe_melinoe_fullbuild_god_pool_hephaestus_01",
            sourceGod = "Hephaestus",
        },
        {
            offerSource = "PoseidonUpgrade",
            recommendationId = "mobalytics_axe_melinoe_fullbuild_god_pool_poseidon_01",
            sourceGod = "Poseidon",
        },
    },
    hammerRoles = {},
    id = "moonstone_axe_melinoe_mobalytics",
    knownNonStatusTraits = {},
    nonCoreContext = {},
    potentialStatusTraits = {},
    profileMode = "starter",
    rules = {},
    schemaVersion = 1,
    selectionKey = "moonstone_axe_melinoe_mobalytics",
    slots = {},
    source = {
        profile = "axe_melinoe",
        type = "mobalytics",
    },
    sourceScoring = {
        boons = {
            ApolloWeaponBoon = "Core Boons",
            CastNovaBoon = "Non-Core Boons",
            ChaosHealthBlessing = "Offerings",
            ChaosWeaponBlessing = "Offerings",
            DemeterCastBoon = "Core Boons",
            DoubleStrikeChanceBoon = "Non-Core Boons",
            EncounterStartDefenseBuffBoon = "Non-Core Boons",
            EncounterStartOffenseBuffBoon = "Non-Core Boons",
            FocusDamageShaveBoon = "Non-Core Boons",
            HephaestusManaBoon = "Core Boons",
            HephaestusSpecialBoon = "Core Boons",
            InsideCastCritBoon = "Offerings",
            PoseidonSprintBoon = "Core Boons",
            RootDurationBoon = "Non-Core Boons",
        },
        deferred = {},
        hammers = {},
        offerSources = {
            ChaosHealthBlessing = "TrialUpgrade",
            ChaosWeaponBlessing = "TrialUpgrade",
            InsideCastCritBoon = "NPC_Artemis_Field_01",
        },
        poms = {
            ApolloWeaponBoon = "Poms of Power",
            HephaestusSpecialBoon = "Poms of Power",
            PoseidonSprintBoon = "Poms of Power",
        },
    },
    statusCapabilityTraits = {},
    statusMappings = {},
    traitSemantics = {},
    verifiedIds = {
        coreAttack = {
            "ApolloWeaponBoon",
        },
        coreCast = {
            "DemeterCastBoon",
        },
        coreMana = {
            "HephaestusManaBoon",
        },
        coreSpecial = {
            "HephaestusSpecialBoon",
        },
        coreSprint = {
            "PoseidonSprintBoon",
        },
    },
    weapon = "WeaponAxe",
    weights = {
        BUILD_PREFERRED = 2,
    },
}
