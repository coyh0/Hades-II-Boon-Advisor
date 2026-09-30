# Runtime attestation catalog — migration inventory and first migration

Baseline: checkpoint `b5ee996` (`chore: checkpoint validated Moonstone Axe build`).

This inventory records what the current repository contains before migration. It does not add, reinterpret, or promote any claim. Existing local review patches remain outside this work.

## 1. Moonstone Axe source projection

`data/projections/moonstone-axe-starter/rows.json` contains 14 selected runtime candidates: five Core recommendations, six Non-Core recommendations, and three offering recommendations. `policy.json` separately contains 14 verified runtime IDs, 11 verified source-group mappings, and three exact offering pairs. `plan.json` is the deterministic import result.

The 11 Core/Non-Core group assignments and five Core roles are build/recommendation claims. They are not native item facts and must stay in the Moonstone projection. The 14 external names may be candidates for reusable name-to-ID mappings, but they must be migrated only with evidence that specifically supports each association. The current projection rows have stable `recommendationId` values; `source-recommendations.json` preserves 52 reviewed source rows. These establish source traceability, not native item identity by themselves.

The 14 selected runtime item IDs are: `ApolloWeaponBoon`, `HephaestusSpecialBoon`, `DemeterCastBoon`, `PoseidonSprintBoon`, `HephaestusManaBoon`, `DoubleStrikeChanceBoon`, `CastNovaBoon`, `EncounterStartDefenseBuffBoon`, `FocusDamageShaveBoon`, `EncounterStartOffenseBuffBoon`, `RootDurationBoon`, `InsideCastCritBoon`, `ChaosWeaponBlessing`, and `ChaosHealthBlessing`.

Candidate reusable external name mappings from the active rows are:

| External name | Runtime item ID |
| --- | --- |
| Nova Strike | `ApolloWeaponBoon` |
| Volcanic Flourish | `HephaestusSpecialBoon` |
| Arctic Ring | `DemeterCastBoon` |
| Breaker Rush | `PoseidonSprintBoon` |
| Tough Gain | `HephaestusManaBoon` |
| Extra Dose | `DoubleStrikeChanceBoon` |
| Arctic Gale | `CastNovaBoon` |
| Security System | `EncounterStartDefenseBuffBoon` |
| High Surf | `FocusDamageShaveBoon` |
| Hydraulic Might | `EncounterStartOffenseBuffBoon` |
| Cold Storage | `RootDurationBoon` |
| Lethal Snare | `InsideCastCritBoon` |
| Strike | `ChaosWeaponBlessing` |
| Soul | `ChaosHealthBlessing` |

This table is an inventory of candidate name/ID associations, not a claim that the current repo stores adequate per-mapping evidence. Recommendation IDs, Core/Non-Core group, role, and choice of which entries are active stay with the build.

Exact offering pairs currently selected by Moonstone:

| Source ID | Runtime item ID | Current source recommendation |
| --- | --- | --- |
| `NPC_Artemis_Field_01` | `InsideCastCritBoon` | Lethal Snare |
| `TrialUpgrade` | `ChaosWeaponBlessing` | Strike |
| `TrialUpgrade` | `ChaosHealthBlessing` | Soul |

Keep the `TrialUpgrade` allowlist limited to those exact two pairs unless separate evidence and review approve another pair.

## 2. Medea source mechanics

`data/canonical/mechanics/argent_skull_medea_mobalytics.json` contains 12 boon IDs in `sourceScoring.boons`: four marked Core, six Non-Core, and two NPC offerings. Its four Core roles (Special, Attack, Cast, Mana), six Non-Core assignments, Pom choices, God Pool, deferred items, Hammer entries, and support context are build data; they are not catalog-wide attributes.

Exact NPC offering pairs currently selected by Medea:

| Source ID | Runtime item ID |
| --- | --- |
| `NPC_Athena_01` | `DeathDefianceRefillBoon` |
| `NPC_Hades_Field_01` | `HadesDeathDefianceDamageBoon` |

The mechanics template records the IDs and mappings, but it does not carry per-claim evidence references or file hashes. Treat these as previously accepted project facts whose original evidence must be located or documented during migration; do not invent a native file path, build number, or hash.

The 12 currently referenced boon IDs are: `ZeusSpecialBoon`, `HeraWeaponBoon`, `DemeterCastBoon`, `AresManaBoon`, `DoubleBoltBoon`, `FocusLightningBoon`, `ReserveManaHitShieldBoon`, `LinkedDeathDamageBoon`, `CastNovaBoon`, `MissingHealthCritBoon`, `DeathDefianceRefillBoon`, and `HadesDeathDefianceDamageBoon`. The template also references Hammer IDs `LobPulseAmmoTrait` and `LobSturdySpecialTrait`, and deferred IDs `KeepsakeLevelBoon` and `BloodRetentionBoon`; those four are inventoried separately because they are not part of the 12 boon classifications above.

## 3. Shared and separate identities

The two Mobalytics mechanics templates overlap on `DemeterCastBoon` and `CastNovaBoon`. There are therefore 24 distinct IDs across the 12 Medea boon IDs and 14 Moonstone selected runtime item IDs. Preserve each build's own classification and recommendation usage even when the native item identity is shared. The Moonstone policy is explicit about its verified IDs and group mappings; Medea's legacy mechanics format does not use that same policy structure and must remain compatible during migration.

Moonstone and Medea also have build-level God Pool entries that name native offer-source IDs. Those selected pools must remain in their respective mechanics data. A shared source identity, if independently attested, may be represented once in the catalog; the catalog must not store either build's God Pool selection.

Medea has two Hammer IDs and two deferred boon IDs in its mechanics template. They are recorded here as additional IDs currently consumed by build mechanics, not as newly verified catalog claims. Their inclusion in the first catalog migration depends on recovering the same level of native identity evidence as for active boon candidates. Their build priority/selection status remains outside the catalog.

## 4. Provenance coverage and migration gate

The current Moonstone policy records verification decisions but not per-claim provenance metadata. The projection preserves Mobalytics names, sections, and stable recommendation IDs; the source recommendation export has no `tooltipEvidence` for the sampled entries. It does not by itself preserve the CDN asset filename/reference and review date for each name-to-ID association. The mechanics templates likewise do not record per-ID native file paths, game builds, or hashes.

Therefore, the first migration must separate:

1. facts whose evidence can be recovered from existing native-game evidence or approved source records;
2. previously approved facts for which the repository has no per-claim provenance yet;
3. build-specific claims that must not be copied into the shared catalog.

Only the first group can enter the initial populated catalog with `validated` status and complete evidence. Do not mark an entry validated by borrowing provenance from a different kind of source. If evidence cannot be recovered, leave the claim out of the usable catalog pending review; do not silently invalidate the existing Medea or Moonstone runtime behavior during a preparatory inventory.

## 5. Draft schema field intent

`runtime_attestations.json` is intentionally empty at this gate and points to `runtime_attestations.schema.json`. The JSON Schema defines the record shapes; semantic checks for duplicate IDs, dangling references, evidence coverage, and incompatible source/item pairs belong in the catalog validator and tests at later gates. Its collections have these meanings:

- `nativeItems`: exact Hades II runtime item identity and independently evidenced native claims (`nativeType`, optional `nativeSlot`). The schema has no `recommendationRole`, Core/Non-Core, scoring, or priority field.
- `offerSources`: exact native source ID and verified source type (NPC reward, trial reward, or another specifically attested type).
- `sourceBoonPairs`: explicit, separately attested `(sourceId, runtimeItemId)` pairs. No wildcard or family inference.
- `externalNameMappings`: reusable external label-to-native-ID associations only where that association itself is attested. No Core/Non-Core classification, build role, priority, scoring, pool, condition, or build selection.
- `evidence`: typed proof records that state what claim they support, their method, stable reference, and relevant version/hash metadata.

For review before populating records, the intended record shapes are:

```json
{
  "nativeItems": [{
    "runtimeItemId": "ExactNativeId",
    "claims": [{
      "claimId": "native-item-exact-id-type",
      "predicate": "nativeType",
      "value": "Trait",
      "status": "validated",
      "evidenceIds": ["evidence-native-001"]
    }, {
      "claimId": "native-item-exact-id-slot",
      "predicate": "nativeSlot",
      "value": "Attack",
      "status": "validated",
      "evidenceIds": ["evidence-native-002"]
    }]
  }],
  "offerSources": [{
    "offerSource": "ExactSourceId",
    "claims": [{
      "claimId": "source-exact-id-type",
      "predicate": "sourceType",
      "value": "NPCReward",
      "status": "validated",
      "evidenceIds": ["evidence-source-001"]
    }]
  }],
  "sourceBoonPairs": [{
    "pairId": "source_trial_chaos_weapon",
    "offerSource": "TrialUpgrade",
    "runtimeItemId": "ChaosWeaponBlessing",
    "claimId": "pair-trial-chaos-weapon",
    "status": "validated",
    "evidenceIds": ["evidence-pair-001"]
  }],
  "externalNameMappings": [{
    "mappingId": "mobalytics-lethal-snare",
    "provider": "Mobalytics",
    "externalName": "Lethal Snare",
    "runtimeItemId": "InsideCastCritBoon",
    "status": "validated",
    "evidenceIds": ["evidence-name-001"]
  }],
  "evidence": [{
    "evidenceId": "evidence-native-001",
    "evidenceKind": "Hades2NativeFile",
    "attests": ["native-item-exact-id-type"],
    "gameBuild": "139606",
    "filePath": "Content/Scripts/example.lua",
    "stableReference": "exact symbol or record reference",
    "method": "local native definition inspection",
    "reviewedAt": "YYYY-MM-DD",
    "sha256": "file digest when available"
  }]
}
```

Allowed stored statuses proposed for claims and pairs: `validated`, `needs_revalidation`, `invalid`, `deprecated`. `needs_revalidation` is set only by an explicitly reviewed catalog update; the future freshness tool may report it but must never write it. Evidence kinds are typed so CDN evidence can support an external name mapping without satisfying a native ID or source-pair claim. Semantic validation must also enforce evidence-kind compatibility: native-file evidence cannot be replaced by CDN proof, and vice versa.

## 6. First migration result

After approval of Gate 1, the catalog was populated only from exact local native-file evidence recoverable in the installed Hades II build `139606`. Each migrated claim is `validated` against a recorded source file, exact stable reference, inspection method, review date, and full-file SHA-256. Evidence records identify the specific claim IDs they support; no build recommendation data was copied into the catalog.

### Migrated native identities

There are **24** native item identity claims, all `nativeType: Trait`. The exact source references and hashes are in the catalog evidence records. Grouping below is only for readability; each listed ID has its own claim and line reference.

| Native evidence file | Runtime IDs migrated | Proof reference(s) |
| --- | --- | --- |
| `TraitData_Apollo.lua` | `ApolloWeaponBoon`, `DoubleStrikeChanceBoon` | Exact `TraitData` table keys, lines 3 and 2288 |
| `TraitData_Hephaestus.lua` | `HephaestusSpecialBoon`, `HephaestusManaBoon`, `EncounterStartDefenseBuffBoon` | Exact keys, lines 824, 1571, 1823 |
| `TraitData_Demeter.lua` | `DemeterCastBoon`, `CastNovaBoon`, `RootDurationBoon`, `ReserveManaHitShieldBoon` | Exact keys, lines 1377, 1696, 2211, 1952 |
| `TraitData_Poseidon.lua` | `PoseidonSprintBoon`, `FocusDamageShaveBoon`, `EncounterStartOffenseBuffBoon` | Exact keys, lines 1788, 2188, 1992 |
| `TraitData_Artemis.lua` | `InsideCastCritBoon` | Exact key, line 3 |
| `TraitData_Chaos.lua` | `ChaosWeaponBlessing`, `ChaosHealthBlessing` | Exact keys, lines 61 and 125 |
| `TraitData_Zeus.lua` | `ZeusSpecialBoon`, `DoubleBoltBoon`, `FocusLightningBoon` | Exact keys, lines 791, 1926, 1828 |
| `TraitData_Hera.lua` | `HeraWeaponBoon`, `LinkedDeathDamageBoon` | Exact keys, lines 3 and 1922 |
| `TraitData_Ares.lua` | `AresManaBoon`, `MissingHealthCritBoon` | Exact keys, lines 1393 and 1923 |
| `TraitData_Athena.lua` | `DeathDefianceRefillBoon` | Exact key, line 282 |
| `TraitData_Hades.lua` | `HadesDeathDefianceDamageBoon` | Exact key, line 468 |

These records attest only that the exact runtime table key is defined as a Trait. **No `nativeSlot` claims** were migrated. Core/Non-Core classification and recommendation roles remain in their existing build data.

### Migrated sources and exact pairs

There are **4** native source identities and **5** individually attested source/boon pairs. Their source type and pair claims use the native source definitions below; the catalog records their full hashes and links each evidence record to the relevant claim IDs.

| Source identity | Source type claim | Exact source/boon pair(s) | Native evidence and references |
| --- | --- | --- | --- |
| `NPC_Artemis_Field_01` | `NPCReward` | `InsideCastCritBoon` | `NPCData_Artemis.lua`: source definition line 1829, `UseLoot` callback line 1833, trait-list membership line 1917 |
| `NPC_Athena_01` | `NPCReward` | `DeathDefianceRefillBoon` | `NPCData_Athena.lua`: source definition line 3, trait-list membership line 129 |
| `NPC_Hades_Field_01` | `NPCReward` | `HadesDeathDefianceDamageBoon` | `NPCData_Hades.lua`: source definition line 4, trait-list membership line 50 |
| `TrialUpgrade` | `TrialReward` | `ChaosWeaponBlessing`; `ChaosHealthBlessing` | `LootData_Chaos.lua`: source definition line 4; explicit `PermanentTraits` membership line 61 |

The `TrialUpgrade` allowlist contains exactly those two reviewed pairs. Although the native file lists additional Chaos traits, none were added as pairs. The Artemis, Athena, Hades, and TrialUpgrade source/pair entries correspond to the previously reviewed build facts; the migration adds recoverable native provenance, not new relationships.

### Facts deliberately left out

- **14 Mobalytics external-name mappings** were not migrated because the checked-in rows do not preserve a per-mapping CDN filename/reference or other independent evidence. The pairs left out are: Nova Strike → `ApolloWeaponBoon`; Volcanic Flourish → `HephaestusSpecialBoon`; Arctic Ring → `DemeterCastBoon`; Breaker Rush → `PoseidonSprintBoon`; Tough Gain → `HephaestusManaBoon`; Extra Dose → `DoubleStrikeChanceBoon`; Arctic Gale → `CastNovaBoon`; Security System → `EncounterStartDefenseBuffBoon`; High Surf → `FocusDamageShaveBoon`; Hydraulic Might → `EncounterStartOffenseBuffBoon`; Cold Storage → `RootDurationBoon`; Lethal Snare → `InsideCastCritBoon`; Strike → `ChaosWeaponBlessing`; Soul → `ChaosHealthBlessing`. The names remain in their build projections. Native TraitData evidence cannot attest Mobalytics naming.
- No `nativeSlot` claims were added because the recovered evidence selected for this migration supports native identity/type, not an independent slot claim.
- Medea's Hammer IDs `LobPulseAmmoTrait`, `LobSturdySpecialTrait` and deferred IDs `KeepsakeLevelBoon`, `BloodRetentionBoon` remain out of the catalog. They are outside the 24 boon-ID inventory and their catalog-specific evidence was not established in this bounded migration.
- Build God Pool choices remain in each build. The seven distinct source IDs referenced by those pools (`ZeusUpgrade`, `HeraUpgrade`, `AresUpgrade`, `DemeterUpgrade`, `ApolloUpgrade`, `HephaestusUpgrade`, `PoseidonUpgrade`) were not promoted as shared source attestations in this migration.
- Build-specific Core/Non-Core, recommendation roles, priorities, scoring, conditions, and active selection were not copied into the catalog.

No fact was newly inferred or added from name similarity, god/family grouping, file proximity, or absence of a ranking. `externalNameMappings` remains empty.

## Gate status

The approved migration is present in `data/canonical/catalog/runtime_attestations.json`: **24 native item claims, 4 source type claims, 5 exact source/boon pairs, 0 external-name mappings, and 15 evidence records**. Formal JSON Schema validation and semantic safeguards are now implemented and tested as a separate gate; setup and invocation are documented in `docs/ATTESTATION_CATALOG_VALIDATION.md`. The catalog is still not operational because it is not connected to any consumer.

No importer, generator, runtime, projection, policy, roadmap, deployment, or Git state was changed during migration or catalog-validation work. The three local review patches remain untouched. This inventory records the migration; the validation gate report is provided separately.
