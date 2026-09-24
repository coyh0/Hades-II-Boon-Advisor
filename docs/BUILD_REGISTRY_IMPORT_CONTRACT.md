# Build Registry import contract (Phase 11A.2)

`tools/Test-BuildRegistryImport.ps1` validates a local JSON export and writes a deterministic **plan**, not a canonical profile or a runtime module. Spreadsheet transport is outside this tool. It runs on Windows PowerShell 5.1.

Input JSON has `schemaVersion: 1` and a `rows` array. Files are read as UTF-8 text, including UTF-8 without a BOM, before JSON parsing. Rows use the conceptual Build Registry columns plus `runtimeItemId`, `importStatus`, and `verificationStatus`. The latter two fields are independent:

- `importStatus`: `ready`, `blocked`, `excluded`, or `documentation_only`.
- `verificationStatus`: `verified`, `unverified`, or `not_applicable`.

`verified` means that an internal runtime ID has been confirmed against reliable local game data. Runtime identifiers are opaque and compared exactly using ordinal, case-sensitive matching. A row's claim of `verified` is insufficient on its own: a runtime candidate's `runtimeItemId` must also occur in the separate, locally maintained policy's `verifiedRuntimeItemIds` list. Weapon/aspect IDs must occur as an exact pair in the canonical weapon/aspect catalog. Do not derive IDs from `name`, `god`, `weaponLabel`, or `aspectLabel`.

The trusted policy JSON uses `schemaVersion: 1`, requires `boonClassifications` (an explicit classification-to-role object), `verifiedRuntimeItemIds`, and `keepsakeStartAsAutoSignal` (boolean). `hammerClassifications` is optional for compatibility with existing schema-1 policies; when present it must map classifications explicitly to `priority` or `alternative`. Supported boon roles are `core`, `alternatives`, `preferred`, and `discouraged`. External boon slot keys are exact lowercase values: `attack → Attack`, `special → Special`, `cast → Cast`, and `sprint → Sprint`. Values such as `Attack` or `SPECIAL` are rejected. `gain → Mana` is not established and remains blocked. A verified keepsake with `slot: start` can become an `autoSignal` only when the trusted policy explicitly enables that mapping.

A ready Hammer row requires a separately attested runtime Trait ID, a positive integer priority, and a classification explicitly mapped by `hammerClassifications`. Ordinary source priority and free text remain non-authoritative unless a trusted projection explicitly defines their meaning. For a verified Hammer row, the trusted projection carries positive integer priority into `hammerPlan` as ordinal ordering; classification has meaning only through `hammerClassifications`. Free-text `condition` is never parsed or guessed as a branch rule. If a Hammer plan entry carries condition metadata, runtime evaluation remains incomplete until an explicit machine-readable condition model exists. Thus `Special branch` is preserved but not interpreted, and safely prevents a complete Hammer ranking for Launcher Frame. Arcana, support, familiar, and Hex rows remain documentation-only until their own conservative projections exist.

`profileKeyProposal` groups active rows and is a selection-key candidate. The exact key `auto` is reserved for automatic profile selection and cannot identify an imported explicit profile. An importable group's `canonicalId` must be present, safe as a filename, and unique across groups. The exact ID `registry` is reserved because `data/builds/registry.lua` is the generated registry module. All rows in a group must agree on `canonicalId`, `profileMode`, `runtimeWeaponId`, and `runtimeAspectId`. The tool derives the module as `data/builds/<canonicalId>.lua`; a supplied `module` can only be empty or equal to this value. For non-Hammer rows, source `condition`, `priority`, names, and labels remain metadata; classification has no effect unless mapped by trusted policy. Hammer priority and classification follow the explicit projection described above.

Malformed enum values and conflicting identities fail validation. `excluded` and `documentation_only` rows are skipped. `blocked` rows, missing/unverified IDs, missing mappings, unsupported item types, and unverified slots block their entire active group. A blocked group has sorted reason codes and no module or items in the output plan. No partial runtime profile is emitted. This tool does not write to `data/canonical/profiles`, `data/builds`, staging, or a game directory.

For a local fixture, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-BuildRegistryImport.ps1 -InputPath <rows.json> -PolicyPath <trusted-policy.json> -OutputPath <plan.json>
```

The `-CatalogPath` parameter can point at a fixture catalog in tests; its default is `data/canonical/catalog/weapons_aspects.json`. Keep the policy under local review, separate from any external spreadsheet export. The tool does not contain or require a spreadsheet URL or credential.
