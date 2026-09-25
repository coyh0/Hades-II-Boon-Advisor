# v0.2 showcase repair — review report

Date: 2026-09-25. Clean baseline: `dc57eabc45b967bd40bc124f8df13332744cb687`. Repaired branch: `codex/v02-mechanics-showcase`, based on existing commit `4a647f607023602a34b1d705a15a39cfbb3bc19d`. Changes are local and prepared for review; no deployment or publication.

## Result

Restored the three corrupted files from the clean baseline. `ROADMAP.md` and the complete `tests/scoring_spec.lua` are unchanged from main; `tests/canonical_profiles_spec.ps1` retains its full baseline and adds the five-row projection gate. All three are valid UTF-8 without NUL bytes. No milestones were self-marked complete.

The five approved additions remain intact:

- Morrigan: `DaggerTripleBuffTrait` priority 1 and `DaggerAttackFinisherTrait` alternative 2.
- Black Coat: `HestiaWeaponBoon` and `ZeusWeaponBoon` Attack alternatives; `SuitAttackSizeTrait` alternative 3.

`data/projections/v02-showcase` now provides the explicit five-row delta, independent ID policy, documentary provenance and native evidence hashes. It is not a full-profile import. The source Sheet and the other 373 documentary records are untouched.

New runtime regression tests are included in the standard Lua harness. The canonical suite runs the projection test, including a negative case where removing an attested ID blocks the entire affected group. The historical Black Coat pilot test now checks its three original Hammers as a subset by exact ID; the existing generated-profile test separately enforces the complete four-Hammer plan.

Static comparison against main confirmed that profile changes are limited to the five approved entries. All 23 Keepsake metadata entries, autoSignals, Melinoe profile, mechanics templates, scorer, resolver and UI are unchanged. No new condition interpreter or Blood Triad frequency detector exists; selected documentary conditions were adapted to profile intent as approved. Launcher Frame remains incomplete.

## Validation

Windows PowerShell 5.1, bundled Python, and DEV `Ship/lua52.dll`. Target game version 139606. All final results PASS:

| Suite | Result |
| --- | --- |
| Canonical profiles, deterministic generation and generated Lua parity | PASS |
| Full Lua 5.2: scoring, probe, lifecycle, partial ranking, localization, UI, Attack branches, resolver, new showcase scenarios | PASS |
| Canonical mechanics and strict equivalence | PASS |
| Build Registry importer | PASS |
| Historical Black Coat pilot | PASS |
| Five-row v0.2 projection and missing-attestation negative | PASS |
| Profile switcher | PASS |
| Staging: exactly 14 files | PASS |
| Patch compatibility fixtures | PASS |
| Read-only DEV 139606 compatibility check | PASS |
| Install documentation | PASS |
| Installation fixture | PASS |
| Update/rollback fixture | PASS |
| Uninstallation fixture | PASS |
| Thunderstore structure/inventory | PASS |
| Release packaging fixture with explicit ValidatedGameRoot | PASS |
| Diff whitespace and preserved baseline integrity | PASS |

New scenarios cover Morrigan full/partial/none Hammer offers, Black Coat full and conditional partial Hammer offers, Poseidon +12 versus Hestia/Zeus +8 at Common rarity in an empty slot, incomplete replacement of owned Poseidon without an empty-slot bonus, and Rare base Ares Melinoe +13 without Wounds.

Initial orchestration failures are retained in `dist/repair-validation/first-pass-results.json`: eight suites could not resolve Get-FileHash when Python forwarded a mixed PowerShell module path. They passed after setting the child process PSModulePath to the Windows PowerShell 5.1 module directories. No global environment or product script was changed. A direct importer invocation also failed to initialize its default catalog path under that invocation; the projection gate passes CatalogPath explicitly and succeeds. These invocation failures are not represented as product test successes.

Final machine-readable results and logs are in `dist/repair-validation/`. Packaging was exercised only as a test fixture, not a public release. Native files were read for evidence/compatibility. The v0.2 candidate was subsequently installed on DEV through the transactional updater after verifying a fresh persistent backup; its 14-file inventory and preserved settings passed post-update checks. Epic was not accessed. Fresh gameplay validation remains pending because Windows Computer Use denied access to the Hades app.

## Remaining gate

The repair is pushed on `codex/v02-mechanics-showcase`; draft PR [#1](https://github.com/coyh0/Hades-II-Boon-Advisor/pull/1) is open against `main` for shared review. It is not merged. Transactional deployment to DEV is complete with verified backup and exact inventory. The maintainer prefers human control of Hades, so gameplay automation will not be used. Fresh evidence is pending: screenshots and the complete DEBUG log for natural Morrigan Hammer and Black Coat Attack/Hammer offers. If RNG does not provide an offer, record it as unobserved. Keep the compact UI after v0.2. Public updater documentation and other release-readiness work remain separate.

The three historical review patches remain untracked and their SHA-256 values are preserved. Branch `codex/v02-mechanics-showcase` is synchronized with its remote tracking ref and has not been merged to `main`. The pre-update backup is `D:\Dev\Games\HadesII-Dev\Ship\ReturnOfModding\backup\Local-HadesIIBoonAdvisor-pre-v02-showcase-20260925-204854`; post-update checks confirm 14 installed files, 13 staging hash matches and byte-preserved `config/settings.lua`. Awaiting human-operated gameplay evidence at `D:\Dev\Games\HadesII-Dev\Ship\ReturnOfModding\LogOutput.log` with matching screenshots; no automated game input will be sent.
