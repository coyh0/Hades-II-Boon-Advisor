# Build Registry import contract (Phase 11A.2)

`tools/Test-BuildRegistryImport.ps1` validates a local JSON export and writes a deterministic **plan**, not a canonical profile or a runtime module. Spreadsheet transport is outside this tool. It runs on Windows PowerShell 5.1.

Input JSON has `schemaVersion: 1` and a `rows` array. Files are read as UTF-8 text, including UTF-8 without a BOM, before JSON parsing. Rows use the conceptual Build Registry columns plus `runtimeItemId`, `importStatus`, and `verificationStatus`. The latter two fields are independent:

- `importStatus`: `ready`, `blocked`, `excluded`, or `documentation_only`.
- `verificationStatus`: `verified`, `unverified`, or `not_applicable`.

`verified` means that an internal runtime ID has been confirmed against reliable local game data. Runtime identifiers are opaque and compared exactly using ordinal, case-sensitive matching. A row's claim of `verified` is insufficient on its own: a runtime candidate's `runtimeItemId` must also occur in the separate, locally maintained policy's `verifiedRuntimeItemIds` list. Weapon/aspect IDs must occur as an exact pair in the canonical weapon/aspect catalog. Do not derive IDs from `name`, `god`, `weaponLabel`, or `aspectLabel`.

The trusted policy JSON uses `schemaVersion: 1`, requires `boonClassifications` (an explicit classification-to-role object), `verifiedRuntimeItemIds`, and `keepsakeStartAsAutoSignal` (boolean). `hammerClassifications` is optional for compatibility with existing schema-1 policies; when present it must map classifications explicitly to `priority` or `alternative`. `verifiedOfferingPairs` is an optional trusted array of exact `{ runtimeItemId, offerSource }` pairs. Its source allowlist is deliberately limited to locally attested offering sources: `NPC_Athena_01`, `NPC_Hades_Field_01`, `NPC_Artemis_Field_01`, and `TrialUpgrade`. The legacy `verifiedNpcOfferingPairs` policy field remains supported for existing imports and accepts only the three verified NPC IDs. Artemis and Chaos support are generic exact-source mappings, not weapon/build/item-specific rules. Legacy boon rows retain roles `core`, `alternatives`, `preferred`, and `discouraged`. Their external slot keys remain exact lowercase values: `attack → Attack`, `special → Special`, `cast → Cast`, and `sprint → Sprint`; legacy `gain` remains blocked. A verified keepsake with `slot: start` can become an `autoSignal` only when the trusted policy explicitly enables that mapping.

For reviewed Mobalytics boon rows, the optional `sourceGroup` field opts into an exact mapping in the trusted policy's `verifiedBoonMappings` array. Each mapping names a `runtimeItemId` already in `verifiedRuntimeItemIds` and its exact `sourceGroup`: `Core Boons` or `Non-Core Boons`. A Core mapping additionally declares `coreRole` as `Attack`, `Special`, `Cast`, `Sprint`, or `Mana`; the row must repeat that attested role. Its projected item has role `core` and that slot. A Non-Core mapping has no Core role; its row needs no slot and projects as role `nonCore` with a null slot. The importer rejects missing, duplicate, or incompatible ID, group, role, and slot claims, as well as mixing the new source-group path with legacy `classification`. The optional path does not reinterpret legacy boon rows, and it does not create Core UI alerts for Sprint or Mana.

An active row with `itemType: offering` must have an exact source/item pair in `verifiedOfferingPairs`; the importer projects it as role `offering` with the verified `offerSource`. The old `npcOffering` row type and policy remain accepted for compatibility, but new data should use the generic form.

A ready Hammer row requires a separately attested runtime Trait ID, a positive integer priority, and a classification explicitly mapped by `hammerClassifications`. Ordinary source priority and free text remain non-authoritative unless a trusted projection explicitly defines their meaning. For a verified Hammer row, the trusted projection carries positive integer priority into `hammerPlan` as ordinal ordering; classification has meaning only through `hammerClassifications`. Free-text `condition` is never parsed or guessed as a branch rule. If a Hammer plan entry carries condition metadata, runtime evaluation remains incomplete until an explicit machine-readable condition model exists. Thus `Special branch` is preserved but not interpreted, and safely prevents a complete Hammer ranking for Launcher Frame. Arcana, support, familiar, and Hex rows remain documentation-only until their own conservative projections exist.

## Mobalytics group-score projection

The Mobalytics projection is an explicit, source-specific scoring policy. Do not transfer it to other guide sources. Its tier values are fixed policy constants, not editorial weights from the source workbook and not the profile's generic `weights`:

| Offer category | Guide classification | Base score | Rarity adjustment |
|---|---|---:|---|
| Ordinary boon | `Core Boons` | 200 | Common 0, Rare +1, Epic +2, Heroic +3 |
| Ordinary boon | `Non-Core Boons` | 100 | Common 0, Rare +1, Epic +2, Heroic +3 |
| Ordinary boon | Not mapped in the guide | 0 | Common 0, Rare +1, Epic +2, Heroic +3 |
| Hammer | Listed in `Daedalus Hammer Upgrades` | 200 | Add only from a verified offer rarity |
| Hammer | Not listed | 0 | Add only from a verified offer rarity |
| Legendary boon | Listed | 203 (maximum) | No separate rarity adjustment |
| Legendary boon | Not listed | 0 | No separate rarity adjustment |
| Duo boon | Listed | 200 | None; keep the result incomplete while eligibility/prerequisites are unresolved |
| Duo boon | Not listed | 0 | None; keep the result incomplete while eligibility/prerequisites are unresolved |
| Pom | Owned Core boon | 200 | None |
| Pom | Owned non-Core boon | 100 | Add verified Common/Rare/Epic/Heroic adjustment |
| Pom | Known Core/non-Core boon group | Use that boon tier | Core: none; Non-Core: verified Common/Rare/Epic/Heroic adjustment |
| Pom | Listed only in `Poms of Power`, with no known boon tier | Unresolved | No inferred tier; keep incomplete |
| Offering boon | Listed exact source/item pair | 200 | Add only from a verified offer rarity |
| Offering boon | Not listed at an attested offering source | 0 | Add only from a verified offer rarity |

These bounds ensure Core scores remain above Non-Core scores, and Non-Core scores remain above unlisted scores, regardless of ordinary boon rarity. The same bounded comparison applies to listed versus unlisted Hammers and offering boons. Rarity is read from `OfferSnapshot` only when `raritySource` is `button` or `upgrade_option`. Ordinary boon and known Non-Core Pom scoring require a recognized rarity; if it is absent, unknown, or unverified, retain the base/tier information but mark the result incomplete. Hammers and offering boons may be scored at their base when rarity is absent, as their approved rules make rarity conditional; a present but unknown/unverified rarity still leaves the result incomplete. A Core Pom uses exactly 200 and does not need a rarity value. For explicit boon replacement, use the new base-score minus the replaced boon base-score, then add the verified rarity difference (`new - old`) once. Do not add an absolute rarity bonus on top of a replacement delta.

The mechanics template maps verified trait IDs to the exact source group. New generic profiles use the `Offerings` group and `sourceScoring.offerSources` to map each listed trait to its exact native source; the scorer grants the listed base only when both source and Trait ID match. The source allowlist contains the three verified NPC IDs above and `TrialUpgrade`; it must not grow without source attestation. Existing profiles using `NPC Offerings` and `sourceScoring.npcOfferings` remain valid and retain their NPC-only validation. A mismatched, unlisted, or unknown source/item pair cannot receive a listed score; mismatches remain incomplete. Keep source-group classification separate from the exact source/item mapping.

For Pom offers, a boon mapped to `Core Boons` is scored once at 200 even if it is also listed under `Poms of Power`; no rarity or duplicate group bonus is added. A mapped Non-Core boon uses its source tier and verified rarity. Ownership must be visible in the captured run state. If only `Poms of Power` identifies the offer and no Core/Non-Core boon tier is known, do not infer a base or rarity preference; retain it as incomplete. This source projection does not add ordinary boon, Hammer, offering, or Pom scores together with unrelated synergy or slot bonuses.

Legendary rows use the fixed maximum ordinary-boon score (203) only when listed and the offer's Legendary rarity is verified. Unlisted Legendary offers receive 0. Duo offers use 200/0 according to the source map but remain incomplete until runtime can resolve their eligibility; a spreadsheet row does not prove availability. A missing/unverified rarity for a row whose Duo/Legendary category cannot otherwise be established also remains incomplete. Free-text conditions remain documentary and are never executed implicitly.

This tier policy does not impose an ownership gate requiring every Core boon to be acquired. Snow Queen is the native `ReserveManaHitShieldBoon`: the local Hades II native data identifies that trait under Demeter, includes it in Demeter's boon pool, and names it “Snow Queen” in `Content/Game/Text/en/TraitText.en.sjson` (French: “Manteau Neigeux”). The Medea mechanics template and generated runtime profile already map `ReserveManaHitShieldBoon` to `Non-Core Boons`. The preserved QA log at `D:\Dev\Games\HadesII-Dev\Ship\ReturnOfModding\LogOutput.log` records a Common `ReserveManaHitShieldBoon` offer at 19:42:58.893, marked covered and complete, ranked first among the three offers, and logged score 1 under the then-installed scoring policy. This confirms the observed offer/ranking case and disproves the prior statement that the executable mapping was absent, but its logged score is not the score under the subsequently approved tier policy. Under the approved tier model, the mapped offer's Common base is 100 before any applicable replacement adjustment; its being first in an offer is valid when no currently offered choice has a higher score. Do not require all Core recommendations (including Arctic Ring) to be owned before ranking Non-Core options. Keep this scenario in runtime QA and do not add an ownership gate without an explicit maintainer rule.

## Mobalytics God Pool metadata

Spreadsheet transport remains outside `Test-BuildRegistryImport.ps1`; it validates a local JSON export and does not read a workbook or infer mappings from labels. A reviewed `Dieu` / `God Pool` source row may be represented on its canonical mechanics template by an optional top-level `godPool` array. Each entry has exactly:

```json
{
  "recommendationId": "mobalytics_skull_medea_fullbuild_god_pool_zeus_01",
  "sourceGod": "Zeus",
  "offerSource": "ZeusUpgrade"
}
```

`recommendationId` preserves the source row identity; `sourceGod` preserves the source's god label; `offerSource` is an explicit, locally verified native offer-source ID. The canonical profile generator validates each exact god/source pair against its closed verified mapping, checks that the source-god slug in the stable recommendation ID agrees with `sourceGod`, rejects duplicate recommendation IDs, gods, or offer sources, and copies the array into the generated runtime profile. The runtime profile validator repeats those checks. Profiles without a reviewed God Pool omit the field. God Pool membership does not suppress the missing-Core notice.

For the reviewed Medea rows, the explicit mapping is Zeus → `ZeusUpgrade`, Hera → `HeraUpgrade`, Ares → `AresUpgrade`, and Demeter → `DemeterUpgrade`. This metadata does not add source recommendations, Core requirements, score reasons, weights, priorities, or offer eligibility. It preserves the source's God Pool for later contextual display; it does not control the offer-level `Boon Core Build Missing` notice. The notice follows possession of unambiguous Attack, Special, and Cast Cores declared by the active profile, whether the offered god is inside or outside the pool. Owned boons are never used to infer pool membership.

The build identity resolver can identify the selected profile in the lobby and retain that build name for the run HUD. Offer scoring independently resolves and validates the profile against the captured weapon/aspect for each supported offer; `snapshot.offerSource` comes from the native loot-data `Name`. The God Pool is therefore already present in the profile loaded for that aspect before any boon from a pool god is acquired. The reminder stays informational and independent of scores, ranks, ties, eligibility, coverage, and choice order.

## Core checklist and non-Core context advisory

`sourceScoring.boons[traitId] = "Core Boons"` is the single source of truth for the profile's recommended Core checklist. Build the checklist from that map after profile resolution; do not derive recommendations from `verifiedIds`, slot names, the Olympian, or UI labels. Each mapped Core ID must have a matching `corePlan` entry that supplies its native slot role and verified localized display name. These fields annotate the recommendation only.

For a profile using `sourceScoring`, the optional contextual metadata is:

```json
{
  "corePlan": {
    "DemeterCastBoon": {
      "role": "Cast",
      "displayName": { "en": "Arctic Ring", "fr": "Glyphe Polaire" }
    }
  },
  "nonCoreContext": {
    "ReserveManaHitShieldBoon": {
      "recommendedCore": ["DemeterCastBoon"]
    }
  }
}
```

`corePlan` must cover exactly the IDs classed as `Core Boons`, and each role must be one of `Attack`, `Special`, `Cast`, `Sprint`, or `Mana`. Localized names are stored with the canonical template because no safe, verified runtime API for resolving native TraitText strings by trait ID is used by this mod. The names must be transcribed from the matching native English/French TraitText records and remain metadata, not identifiers. `nonCoreContext` may mention only IDs classed as `Non-Core Boons`; every target must be a distinct ID in `corePlan`. These explicit edges are authored review data. Never infer them from name, slot, god, `verifiedIds`, or prose in a guide.

Ownership is read from the current captured Traits and slotted Traits on each offer diagnostic. A core is present only while its ID appears in that snapshot; replacing it therefore makes it missing on the next refresh. This naturally reevaluates rerolls, reopened/refreshed offers, room transitions, and a newly resolved weapon/aspect profile. Do not cache checklist acquisition across offers or add an all-Core-owned gate.

`CoreAdvisory` derives a checklist from the active profile: the verified `Core Boons` map plus `corePlan` for Mobalytics profiles, or explicit `slots.<role>.core` entries for other canonical profiles. It reads the current run inventory on each boon-offer diagnostic. The offer-level `Boon Core Build Missing` notice considers only unambiguous declared Cores whose role is Attack, Special, or Cast; Mana and Sprint remain in the checklist when declared, but do not keep this notice visible. Multiple Core candidates for one role do not establish whether one or all are required; that role is excluded from the notice until the contract records its requirement semantics. This is independent of the offered god, God Pool membership, source group, score, rank, coverage, and ranking completeness; it also appears beside `NO RELIABLE PREFERENCE`. A supported profile with no declared Attack, Special, or Cast Core shows no notice. The existing conservative fallback for an unresolved profile remains separate from this ownership rule. The notice is not a score reason and must not change score, rank, tie, eligibility, coverage, completeness, or choice order. UI cleanup destroys the single notice on refresh so acquisition, replacement, reroll, and a new profile cannot leave stale text.

Sprint follows the source map exactly: an unlisted Sprint boon is score 0 and is absent from the checklist; a mapped Non-Core Sprint is a normal 100-tier recommendation but is not Core; a mapped Core Sprint is a 200-tier recommendation and enters the checklist without affecting the three-role missing-Core notice. In non-Mobalytics profiles, only an explicit `slots.Sprint.core` entry has the same checklist effect. `Rush` slot occupancy and `verifiedIds.coreSprint` alone confer no source priority or missing-Core notice. A Sprint context edge is permitted only when explicitly declared in `nonCoreContext`.

The generator and runtime profile validator must reject a Core metadata ID outside the Core source map, any omitted Core metadata, a context source outside Non-Core, an unknown or duplicate context target, an invalid role, or a missing English/French name. Regression tests separately verify unchanged score/rank outputs and offer-level advisory selection/cleanup. This metadata is not executable scoring policy and does not change the approved Core > Non-Core > unlisted levels.

When adding a Mobalytics profile, validate group IDs, duplicate assignments, deferred-vs-active conflicts, the exact NPC source/item pairs, and the required verified source identity. Regression coverage must include all four rarity values, tier dominance, replacements, listed/unlisted Hammer and NPC offers, Legendary/Duo handling, Pom ownership and deduplication, and incomplete ranking. The generic `BUILD_PREFERRED` default remains +2 for profiles using the existing non-Mobalytics scoring path; these source-tier constants do not alter it or any other profile's behavior.

Every runtime profile must also have a localized `Localization.buildName` entry and an English/French regression assertion. Profile generation and staging checks must include the generated profile and registry row; a profile is not considered complete while the active-build identity label silently disappears.

`profileKeyProposal` groups active rows and is a selection-key candidate. The exact key `auto` is reserved for automatic profile selection and cannot identify an imported explicit profile. An importable group's `canonicalId` must be present, safe as a filename, and unique across groups. The exact ID `registry` is reserved because `data/builds/registry.lua` is the generated registry module. All rows in a group must agree on `canonicalId`, `profileMode`, `runtimeWeaponId`, and `runtimeAspectId`. The tool derives the module as `data/builds/<canonicalId>.lua`; a supplied `module` can only be empty or equal to this value. For non-Hammer rows, source `condition`, `priority`, names, and labels remain metadata; classification has no effect unless mapped by trusted policy. Hammer priority and classification follow the explicit projection described above.

Malformed enum values and conflicting identities fail validation. `excluded` and `documentation_only` rows are skipped. `blocked` rows, missing/unverified IDs, missing mappings, unsupported item types, and unverified slots block their entire active group. A blocked group has sorted reason codes and no module or items in the output plan. No partial runtime profile is emitted. This tool does not write to `data/canonical/profiles`, `data/builds`, staging, or a game directory.

For a local fixture, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-BuildRegistryImport.ps1 -InputPath <rows.json> -PolicyPath <trusted-policy.json> -OutputPath <plan.json>
```

The `-CatalogPath` parameter can point at a fixture catalog in tests; its default is `data/canonical/catalog/weapons_aspects.json`. Keep the policy under local review, separate from any external spreadsheet export. The tool does not contain or require a spreadsheet URL or credential.
