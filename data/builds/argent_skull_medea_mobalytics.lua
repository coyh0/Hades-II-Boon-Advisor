-- Generated runtime profile from canonical JSON only. Do not edit manually.
return {
    aspect = "LobCloseAttackAspect",
    aspectInteractions = {},
    bloodDropEngine = {
        payoffs = {},
        producers = {},
    },
    constraints = {},
    corePlan = {
        AresManaBoon = {
            displayName = {
                en = "Grisly Gain",
                fr = "Conscience Barbare",
            },
            role = "Mana",
        },
        DemeterCastBoon = {
            displayName = {
                en = "Arctic Ring",
                fr = "Glyphe Polaire",
            },
            role = "Cast",
        },
        HeraWeaponBoon = {
            displayName = {
                en = "Sworn Strike",
                fr = "Frappe Unificatrice",
            },
            role = "Attack",
        },
        ZeusSpecialBoon = {
            displayName = {
                en = "Heaven Flourish",
                fr = "Technique Céleste",
            },
            role = "Special",
        },
    },
    genericCoreAspectCompatibility = false,
    godPool = {
        {
            offerSource = "ZeusUpgrade",
            recommendationId = "mobalytics_skull_medea_fullbuild_god_pool_zeus_01",
            sourceGod = "Zeus",
        },
        {
            offerSource = "HeraUpgrade",
            recommendationId = "mobalytics_skull_medea_fullbuild_god_pool_hera_01",
            sourceGod = "Hera",
        },
        {
            offerSource = "AresUpgrade",
            recommendationId = "mobalytics_skull_medea_fullbuild_god_pool_ares_01",
            sourceGod = "Ares",
        },
        {
            offerSource = "DemeterUpgrade",
            recommendationId = "mobalytics_skull_medea_fullbuild_god_pool_demeter_01",
            sourceGod = "Demeter",
        },
    },
    hammerRoles = {},
    id = "argent_skull_medea_mobalytics",
    knownNonStatusTraits = {},
    nonCoreContext = {
        ReserveManaHitShieldBoon = {
            recommendedCore = {
                "DemeterCastBoon",
            },
        },
    },
    potentialStatusTraits = {},
    profileMode = "meta",
    rules = {},
    schemaVersion = 1,
    selectionKey = "argent_skull_medea_mobalytics",
    slots = {
        Special = {
            alternatives = {},
            core = {},
            preferred = {
                "ZeusSpecialBoon",
            },
            slotPolicy = "open",
        },
    },
    source = {
        profile = "skull_medea",
        type = "mobalytics",
    },
    sourceScoring = {
        boons = {
            AresManaBoon = "Core Boons",
            CastNovaBoon = "Non-Core Boons",
            DeathDefianceRefillBoon = "NPC Offerings",
            DemeterCastBoon = "Core Boons",
            DoubleBoltBoon = "Non-Core Boons",
            FocusLightningBoon = "Non-Core Boons",
            HadesDeathDefianceDamageBoon = "NPC Offerings",
            HeraWeaponBoon = "Core Boons",
            LinkedDeathDamageBoon = "Non-Core Boons",
            MissingHealthCritBoon = "Non-Core Boons",
            ReserveManaHitShieldBoon = "Non-Core Boons",
            ZeusSpecialBoon = "Core Boons",
        },
        deferred = {
            BloodRetentionBoon = "Legendary / Duo Boons",
            KeepsakeLevelBoon = "Legendary / Duo Boons",
        },
        hammers = {
            LobPulseAmmoTrait = "Daedalus Hammer Upgrades",
            LobSturdySpecialTrait = "Daedalus Hammer Upgrades",
        },
        npcOfferings = {
            DeathDefianceRefillBoon = "NPC_Athena_01",
            HadesDeathDefianceDamageBoon = "NPC_Hades_Field_01",
        },
        poms = {
            ZeusSpecialBoon = "Poms of Power",
        },
    },
    statusCapabilityTraits = {},
    statusMappings = {},
    traitSemantics = {},
    verifiedIds = {
        coreAttack = {},
        coreCast = {},
        coreMana = {},
        coreSpecial = {
            "ZeusSpecialBoon",
            "PoseidonSpecialBoon",
        },
        coreSprint = {},
    },
    weapon = "WeaponLob",
    weights = {
        BUILD_PREFERRED = 2,
    },
}
