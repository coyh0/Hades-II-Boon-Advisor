# Build Registry import contract (Phase 11A.2)

`tools/Test-BuildRegistryImport.ps1` validates a local JSON export and writes a deterministic **plan**, not a canonical profile or a runtime module. Spreadsheet transport is outside this tool. It runs on Windows PowerShell 5.1.

Input JSON has `schemaVersion: 1` and a `rows` array. Files are read as UTF-8 text, including UTF-8 without a BOM, before JSON parsing. Rows use the conceptual Build Registry columns plus `runtimeItemId`, `importStatus`, and `verificationStatus`. The latter two fields are independent:

- `importStatus`: `ready`, `blocked`, `excluded`, or `documentation_only`.
- `verificationStatus`: `verified`, `unverified`, or `not_applicable`.

`verified` means that an internal runtime ID has been confirmed against reliable local game data. Runtime identifiers are opaque and compared exactly using ordinal, case-sensitive matching. A row's claim of `verified` is insufficient on its own: a runtime candidate's `runtimeItemId` must also occur in the separate, locally maintained policy's `verifiedRuntimeItemIds` list. Weapon/aspect IDs must occur as an exact pair in the canonical weapon/aspect catalog. Do not derive IDs from `name`, `god`, `weaponLabel`, or `aspectLabel`.

The trusted policy JSON also has `schemaVersion: 1`, `boonClassifications` (an explicit classification-to-role object), and `keepsakeStartAsAutoSignal` (boolean). Supported boon roles are `core`, `alternatives`, `preferred`, and `discouraged`. External boon slot keys are exact lowercase values: `attack → Attack`, `special → Special`, `cast → Cast`, and `sprint → Sprint`. Values such as `Attack` or `SPECIAL` are rejected. `gain → Mana` is not established and remains blocked. A verified keepsake with `slot: start` can become an `autoSignal` only when the trusted policy explicitly enables that mapping. Other item types do not automatically become slots, signals, mechanics, or scoring rules.

`profileKeyProposal` groups active rows and is a selection-key candidate. The exact key `auto` is reserved for automatic profile selection and cannot identify an imported explicit profile. An importable group's `canonicalId` must be present, safe as a filename, and unique across groups. The exact ID `registry` is reserved because `data/builds/registry.lua` is the generated registry module. All rows in a group must agree on `canonicalId`, `profileMode`, `runtimeWeaponId`, and `runtimeAspectId`. The tool derives the module as `data/builds/<canonicalId>.lua`; a supplied `module` can only be empty or equal to this value. `condition`, `priority`, names, and labels are source metadata and never create runtime behavior. Classification has no effect unless it is mapped by the trusted policy.

Malformed enum values and conflicting identities fail validation. `excluded` and `documentation_only` rows are skipped. `blocked` rows, missing/unverified IDs, missing mappings, unsupported item types, and unverified slots block their entire active group. A blocked group has sorted reason codes and no module or items in the output plan. No partial runtime profile is emitted. This tool does not write to `data/canonical/profiles`, `data/builds`, staging, or a game directory.

For a local fixture, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-BuildRegistryImport.ps1 -InputPath <rows.json> -PolicyPath <trusted-policy.json> -OutputPath <plan.json>
```

The `-CatalogPath` parameter can point at a fixture catalog in tests; its default is `data/canonical/catalog/weapons_aspects.json`. Keep the policy under local review, separate from any external spreadsheet export. The tool does not contain or require a spreadsheet URL or credential.
