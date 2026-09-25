# Registry v0.2: 118-row audit

Baseline: `dc57eabc45b967bd40bc124f8df13332744cb687`. Source snapshot: `v02-registry-source.json`.

Native text matching verifies names only. Conditions and documentary priorities are never executed automatically.
Existing generic slot evaluation is separate from an explicit build recommendation. All source rows remain documentation_only.

| Sheet row | Profile | Name / ID | Documentary role / priority | Main baseline | Decision |
| --- | --- | --- | --- | --- | --- |
| 2 | melinoe_intermediate | Sword Hilt / ForceAresBoonKeepsake | Main / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 3 | melinoe_intermediate | Cloud Bangle / ForceZeusBoonKeepsake | Alternative / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 4 | melinoe_intermediate | Cloud Bangle / ForceZeusBoonKeepsake | Conditional / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 5 | melinoe_intermediate | Beautiful Mirror / ForceAphroditeBoonKeepsake | Alternative / 2 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 6 | melinoe_intermediate | Experimental Hammer / TempHammerKeepsake | Conditional / 2 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 7 | melinoe_intermediate | Metallic Droplet / TimedBuffKeepsake | Situational / 2 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 8 | melinoe_intermediate | Luckier Tooth / ReincarnationKeepsake | Conditional / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 9 | melinoe_intermediate | Knuckle Bones / BossPreDamageKeepsake | Alternative / 2 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 10 | melinoe_intermediate | Vicious Strike / AresWeaponBoon | Main / 1 | Attack.branches alternative 2; existing aspectInteractions; contextual evaluation required | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 11 | melinoe_intermediate | Nova Strike / ApolloWeaponBoon | Alternative / 1 | Attack.branches alternative 1 | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 12 | melinoe_intermediate | Flutter Strike / AphroditeWeaponBoon | Alternative / 1 | Attack.branches alternative 1 | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 13 | melinoe_intermediate | Flame Strike / HestiaWeaponBoon | Alternative / 1 | Attack.branches alternative 1 | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 14 | melinoe_intermediate | Heaven Flourish / ZeusSpecialBoon | Main / 1 | Special.core; existing aspectInteractions; contextual evaluation required | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 15 | melinoe_intermediate | Arctic Ring / DemeterCastBoon | Conditional / 2 | existing aspectInteractions; contextual evaluation required | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 16 | melinoe_intermediate | Grievous Blow / AresStatusDoubleDamageBoon | Conditional / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 17 | melinoe_intermediate | Static Shock / FocusLightningBoon | Conditional / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 18 | melinoe_intermediate | Back Burner / ApolloBlindBoon | Situational / 3 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 19 | melinoe_intermediate | Trick Knives / DaggerDashAttackTripleTrait | Main / 1 | hammerPlan priority 1 | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 20 | melinoe_intermediate | Wicked Onslaught / DaggerFinalHitTrait | Alternative / 2 | hammerPlan alternative 2; existing aspectInteractions; contextual evaluation required | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 21 | melinoe_intermediate | Rapid Onslaught / DaggerRapidAttackTrait | Alternative / 2 | hammerPlan alternative 2; existing aspectInteractions; contextual evaluation required | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 22 | melinoe_intermediate | Reaper Knives / DaggerSpecialReturnTrait | Alternative / 2 | hammerPlan alternative 2 | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 23 | melinoe_intermediate | Final Slice / DaggerAttackFinisherTrait | Alternative / 2 | hammerPlan alternative 3 | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 24 | melinoe_intermediate | Dancing Knives / DaggerSpecialJumpTrait | Conditional / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 25 | melinoe_intermediate | The Huntress / unresolved | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 26 | melinoe_intermediate | The Furies / CastBuff | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 27 | melinoe_intermediate | The Messenger / BonusDodge | Alternative / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 28 | melinoe_intermediate | The Swift Runner / SprintShield | Alternative / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 29 | melinoe_intermediate | Death / LastStand | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 30 | melinoe_intermediate | Origination / StatusVulnerability | Conditional / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 31 | melinoe_intermediate | The Lovers / ChanneledBlock | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 32 | melinoe_intermediate | The Wayward Son / unresolved | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 33 | melinoe_intermediate | The Centaur / MaxHealthPerRoom | Situational / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 34 | melinoe_intermediate | The Fates / TradeOff | Situational / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 35 | melinoe_intermediate | Divinity / unresolved | Situational / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 36 | melinoe_intermediate | Frinos / HealthFamiliar | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 37 | melinoe_intermediate | Toula / LastStandFamiliar | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 38 | melinoe_intermediate | Lunar Ray / SpellLaserTrait | Situational / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 39 | melinoe_intermediate | Special → dash-strike → short Attack → reposition / unresolved | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 40 | coat_melinoe_intermediate | Vivid Sea / ForcePoseidonBoonKeepsake | Main / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 41 | coat_melinoe_intermediate | Sword Hilt / ForceAresBoonKeepsake | Conditional / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 42 | coat_melinoe_intermediate | Metallic Droplet / TimedBuffKeepsake | Main / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 43 | coat_melinoe_intermediate | Experimental Hammer / TempHammerKeepsake | Conditional / 2 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 44 | coat_melinoe_intermediate | Gorgon Amulet / AthenaEncounterKeepsake | Conditional / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 45 | coat_melinoe_intermediate | Luckier Tooth / ReincarnationKeepsake | Alternative / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 46 | coat_melinoe_intermediate | Wave Strike / PoseidonWeaponBoon | Main / 1 | Attack.core | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 47 | coat_melinoe_intermediate | Flame Strike / HestiaWeaponBoon | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | SELECTED_DELTA: Attack alternatives |
| 48 | coat_melinoe_intermediate | Heaven Strike / ZeusWeaponBoon | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | SELECTED_DELTA: Attack alternatives |
| 49 | coat_melinoe_intermediate | Vicious Flourish / AresSpecialBoon | Main / 1 | Special.core | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 50 | coat_melinoe_intermediate | Heaven Flourish / ZeusSpecialBoon | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 51 | coat_melinoe_intermediate | Storm Ring / ZeusCastBoon | Conditional / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 52 | coat_melinoe_intermediate | Breaker Rush / PoseidonSprintBoon | Main / 1 | Sprint.core | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 53 | coat_melinoe_intermediate | Slippery Slope / PoseidonStatusBoon | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 54 | coat_melinoe_intermediate | King Tide / AmplifyConeBoon | Conditional / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 55 | coat_melinoe_intermediate | Grievous Blow / AresStatusDoubleDamageBoon | Conditional / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 56 | coat_melinoe_intermediate | Blood Spree / LowHealthLifestealBoon | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 57 | coat_melinoe_intermediate | Arterial Spray / DoubleSplashBoon | Conditional / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 58 | coat_melinoe_intermediate | Static Shock / FocusLightningBoon | Conditional / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 59 | coat_melinoe_intermediate | Exhaust Riser / SuitDashAttackTrait | Main / 1 | hammerPlan priority 1 | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 60 | coat_melinoe_intermediate | Rapid Frame / SuitAttackSpeedTrait | Alternative / 2 | hammerPlan priority 2 | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 61 | coat_melinoe_intermediate | Launcher Frame / SuitSpecialAutoTrait | Conditional / 3 | hammerPlan alternative 3; INCOMPLETE: Special branch | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 62 | coat_melinoe_intermediate | Reaper Frame / SuitAttackSizeTrait | Alternative / 3 | No explicit recommendation entry; not proof of runtime non-coverage | SELECTED_DELTA: hammer alternative 3 |
| 63 | coat_melinoe_intermediate | The Sorceress / ChanneledCast | Conditional / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 64 | coat_melinoe_intermediate | The Huntress / unresolved | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 65 | coat_melinoe_intermediate | The Furies / CastBuff | Alternative / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 66 | coat_melinoe_intermediate | The Messenger / BonusDodge | Alternative / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 67 | coat_melinoe_intermediate | The Swift Runner / SprintShield | Alternative / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 68 | coat_melinoe_intermediate | Death / LastStand | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 69 | coat_melinoe_intermediate | Origination / StatusVulnerability | Conditional / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 70 | coat_melinoe_intermediate | The Wayward Son / unresolved | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 71 | coat_melinoe_intermediate | Toula / LastStandFamiliar | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 72 | coat_melinoe_intermediate | Gale / DodgeFamiliar | Situational / 3 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 73 | coat_melinoe_intermediate | Wolf Howl / SpellLeapTrait | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 74 | coat_melinoe_intermediate | Ω Special → dash-in → dash-strike → Special → exit / unresolved | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 193 | morrigan_meta | Iridescent Fan / ForceHeraBoonKeepsake | Main / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 194 | morrigan_meta | Harmonic Photon / ForceApolloBoonKeepsake | Alternative / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 195 | morrigan_meta | Iridescent Fan / ForceHeraBoonKeepsake | Conditional / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 196 | morrigan_meta | Harmonic Photon / ForceApolloBoonKeepsake | Alternative / 2 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 197 | morrigan_meta | Embryo / RandomBlessingKeepsake | Situational / 2 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 198 | morrigan_meta | Knuckle Bones / BossPreDamageKeepsake | Situational / 2 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 199 | morrigan_meta | Luckier Tooth / ReincarnationKeepsake | Conditional / 2 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 200 | morrigan_meta | Knuckle Bones / BossPreDamageKeepsake | Main / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 201 | morrigan_meta | Luckier Tooth / ReincarnationKeepsake | Alternative / 1 | metadata-only keepsakePlan; no condition execution | PRESERVE_METADATA_ONLY |
| 202 | morrigan_meta | Sworn Strike / HeraWeaponBoon | Main / 1 | Attack.core | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 203 | morrigan_meta | Nova Strike / ApolloWeaponBoon | Alternative / 1 | Attack.alternatives | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 204 | morrigan_meta | Flame Strike / HestiaWeaponBoon | Alternative / 2 | Attack.alternatives | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 205 | morrigan_meta | Ice Strike / DemeterWeaponBoon | Alternative / 2 | Attack.alternatives | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 206 | morrigan_meta | Heaven Flourish / ZeusSpecialBoon | Main / 1 | Special.preferred | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 207 | morrigan_meta | Vicious Flourish / AresSpecialBoon | Alternative / 1 | Special.preferred | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 208 | morrigan_meta | Volcanic Flourish / HephaestusSpecialBoon | Conditional / 2 | Special.preferred | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 209 | morrigan_meta | Nova Flourish / ApolloSpecialBoon | Unresolved / 3 | Special.discouraged | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 210 | morrigan_meta | Flutter Flourish / AphroditeSpecialBoon | Unresolved / 3 | Special.discouraged | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 211 | morrigan_meta | Tidal Ring / PoseidonCastBoon | Main / 1 | Cast.core | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 212 | morrigan_meta | Blinding Rush / ApolloSprintBoon | Main / 1 | Sprint.preferred | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 213 | morrigan_meta | Born Gain / HeraManaBoon | Main / 1 | Mana.core | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 214 | morrigan_meta | Lucid Gain / ApolloManaBoon | Alternative / 1 | Mana.alternatives | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 215 | morrigan_meta | Beach Ball / PoseidonSplashSprintBoon | Conditional / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 216 | morrigan_meta | Premium Service / WeaponUpgradeBoon | Conditional / 2 | existing aspectInteractions; contextual evaluation required | PRESERVE_BASELINE; documentary condition/classification is not a new rule |
| 217 | morrigan_meta | Grievous Blow / AresStatusDoubleDamageBoon | Conditional / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 218 | morrigan_meta | Final Slice / DaggerAttackFinisherTrait | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | SELECTED_DELTA: hammer alternative 2 |
| 219 | morrigan_meta | Sweeping Ambush / DaggerBlinkAoETrait | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 220 | morrigan_meta | Wicked Onslaught / DaggerFinalHitTrait | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 221 | morrigan_meta | Rapid Onslaught / DaggerRapidAttackTrait | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 222 | morrigan_meta | Banshee Brand / DaggerTripleRepeatWomboTrait | Conditional / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 223 | morrigan_meta | Phantom Brand / DaggerTripleBuffTrait | Conditional / 1 | No explicit recommendation entry; not proof of runtime non-coverage | SELECTED_DELTA: hammer priority 1 |
| 224 | morrigan_meta | Dancing Knives / DaggerSpecialJumpTrait | Avoid / 3 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist |
| 225 | morrigan_meta | The Sorceress / ChanneledCast | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 226 | morrigan_meta | The Huntress / unresolved | Alternative / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 227 | morrigan_meta | The Furies / CastBuff | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 228 | morrigan_meta | Origination / StatusVulnerability | Conditional / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 229 | morrigan_meta | Death / LastStand | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 230 | morrigan_meta | The Lovers / ChanneledBlock | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 231 | morrigan_meta | Night / MagicCrit | Conditional / 3 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 232 | morrigan_meta | Eternity / CastCount | Situational / 3 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 233 | morrigan_meta | Hecuba / DigFamiliar | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 234 | morrigan_meta | Toula / LastStandFamiliar | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 235 | morrigan_meta | Frinos / HealthFamiliar | Alternative / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 236 | morrigan_meta | Night Bloom / SpellSummonTrait | Situational / 2 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
| 237 | morrigan_meta | Special → dash-strike → Ω Attack on same foe / unresolved | Main / 1 | No explicit recommendation entry; not proof of runtime non-coverage | DEFER_DOCUMENTARY_GUIDANCE |
