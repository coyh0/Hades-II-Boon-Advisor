# Curated v0.2 Registry delta

This is an explicit **five-item delta**, not a complete profile replacement. It preserves the existing canonical baseline, the other 113 active documentary rows, and the 260 deferred rows. The source Sheet remains `documentation_only`; `ready` here describes only the locally attested projection.

Source: Build Registry v2, retrieved 2026-09-25. Each row retains its stable recommendationId, source fingerprint, documentary classification/priority/condition, and original import status. The maintainer approved the five-item proposal in the migration continuation. `conditionDisposition` records the adaptation to profile intent; free text is never parsed. Morrigan Final Slice is deliberately alternative/2 instead of documentary Main/1. Phantom Brand expresses the Blood Triad profile intent, not a measured frequency of successful Triads. No new damage formula, status synergy, resolver signal, Keepsake behavior or UI is introduced.

## Independent local evidence

Target executable: HadesII-Dev 139606. Paths below are relative to its Content directory; evidence was read directly on 2026-09-25. File SHA-256 values are in `native-evidence.json` for reproducibility, not distributed native source content.

| ID | Name evidence in Game/Text/en/TraitText.en.sjson | Mechanics evidence in Scripts/ |
| --- | --- | --- |
| DaggerTripleBuffTrait | 6433, Phantom Brand | TraitData_Dagger.lua:729; WomboDamageBonusMultiplier base 2, requires WeaponDagger/DaggerTripleAspect; WeaponLogic.lua:800,806 consumes the bonus |
| DaggerAttackFinisherTrait | 6378, Final Slice | TraitData_Dagger.lua:448; WeaponDaggerDouble multiplier base 4 and radius x1.6, requires WeaponDagger |
| HestiaWeaponBoon | 2753, Flame Strike | TraitData_Hestia.lua:3,26; ApplyBurn/BurnEffect on HeroPrimaryWeapons |
| ZeusWeaponBoon | 1776, Heaven Strike | TraitData_Zeus.lua:3,27; DamageEchoEffect on HeroPrimaryWeapons |
| SuitAttackSizeTrait | 6739, Reaper Frame | TraitData_Suit.lua:88; WeaponSuit requirement, primary base damage +10, WeaponSuit projectile scale +0.4 |

WeaponSets.lua:40-48 includes WeaponSuit in HeroPrimaryWeapons. LootData.lua:285,290,346 references the three selected Hammers. Native naming/mechanics are verified; this does not assert every native offer eligibility case or live gameplay validation. DaggerFinalHitTrait is Wicked Onslaught, not Final Slice. Launcher Frame remains conditional and incomplete.

## Validation and use

The historical `tests/historical/v02_projection_spec.ps1` passed rows/policy and the explicit canonical catalog to `tools/Test-BuildRegistryImport.ps1`, required exactly two ready groups/five items, checked canonical parity and retained documentary provenance, and verified fail-closed behavior when native ID attestation was removed. It is no longer invoked by the active canonical profile suite because its profiles were retired. The importer's plan is informational and must never replace full canonical profiles with these partial groups.

The historical `tests/historical/v02_showcase_spec.lua` checked Hammer full/partial/none modes, the incomplete Launcher Frame, Black Coat core versus alternatives, conservative replacement handling, and unconditional base Ares scoring. It is no longer in the active Lua harness. Current generic ranking and Attack branch behavior are checked with active or synthetic inputs under `tests/`.

New live DEV validation is pending. No deployment or release is performed by these files.
