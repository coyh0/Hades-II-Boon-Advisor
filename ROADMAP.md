# Hades II Boon Advisor — Roadmap

_Last updated: 2026-09-24_

This file is the project roadmap and the source of truth for planned work and validation status.

**Maintenance rule:** ChatGPT updates this roadmap automatically when a milestone has been objectively completed and validated in our workflow, or when the maintainer explicitly requests a roadmap change. Coding agents such as Codex must not self-mark milestones complete or change priorities on their own; their work must first be reviewed and, where relevant, tested.

## Current focus

**11C.11 — Prepare controlled Registry v2→V1 projection and informational keepsakePlan for the three v0.2 profiles**

Published release: `v0.1.2` — Sister Blades only. Future-`v0.2` `main` has three active runtime profiles: Sister Blades Melinoë Intermediate, Sister Blades Morrigan Meta, and Black Coat Melinoë Intermediate. Starter was removed in commit `3201282380574f8adbb1920b1a3bf40c4cc045e2`; installed `BUILD_PROFILE="starter"` now warns once and uses session-only auto fallback. Runtime inventory is **14 files**. Offline suites, transactional DEV-only deployment, 13 staged-file hash matches (DEV `config/settings.lua` intentionally preserved with `DEBUG=true`), and the final Melinoë Ares live screenshot/log validation all passed. Epic/live installation was not touched.

The initial live Melinoë Ares offer displayed Vicious Strike as unevaluated. Native DEV evidence (game executable version `139606`) established that the base Attack independently applies Rend; the five-file correction was independently patch-reviewed and committed as `10af3645165cf286db6c28609dbcb4d4bae61e49`. The maintainer's fresh-run DEV screenshot shows Ares ranked first with an empty Attack slot. The 2026-09-24 22:59:55 session log, analyzed by Codex, confirms `sister_blades_melinoe_intermediate`, `AresWeaponBoon`, `SlotStateBefore=EMPTY`, `Covered=true`, `Complete=true`, `Score=13` (`8` fill + `4` aspect + `1` rarity), full ranking, and no `ATTACK_BRANCH_UNRESOLVED` or Boon Advisor error. **11C.8 is complete.** Origination-category combination behavior remains unresolved; this live run had Origination active but no owned status families, so it does not prove uncertain combinations.

Community Curator completed the private Sheet migration and the maintainer approved the V2 visuals: six Intermediate guides and six Meta guides, 378 atomic DATA rows in total (260 new). **11C.10 is complete:** a separate 49-column `Build Registry v2` now holds all 378 documentary recommendations (118 v0.2-scope rows; 260 deferred), while the legacy V1 Registry and its archive remain intact. **11C.9 is complete:** the maintainer accepted all 378 DATA records as a documentary reference on 2026-09-24, expressly retaining uncertain/unnamed recommendations as unresolved and non-executable. Optional publication-date research for 34 `unknown` dates remains a non-blocking follow-up outside the completed acceptance gate; all 20 missing public URLs are explicitly not applicable to owner preferences or Curator inferences. The three-profile v0.2 scope is maintainer-approved. All Registry v2 recommendations remain `documentation_only`. **11C.11's read-only per-profile inventory is complete (38 + 45 + 35 = 118);** consolidate the proposed runtime delta, independently verify consequential new mechanics/IDs, use the now reconciled documentary-approval metadata, and then review the controlled V2→V1 projection and informational `keepsakePlan` before implementation. DATA coverage is not runtime readiness. Historical 15-file, Starter and pre-audit statements below describe past milestones, not the current runtime. The 2-of-3-evaluable Hammer case remains an optional live observation; Hammer rerolls are not a game mechanic.

## Completed Phase 10 work

### 10B — Runtime validation and automatic profile resolution

- [x] Confirm in-game Sister Blades weapon detection: `WeaponDagger`
- [x] Confirm in-game Aspect of Melinoë detection: `DaggerBackstabAspect`
- [x] Confirm in-game Aspect of Morrigan detection: `DaggerTripleAspect`
- [x] Confirm Aspect of Artemis remains an unsupported/fail-safe case
- [x] **10B.1 — Automatic profile resolver** — COMPLETE (offline tests + code review)
  - Resolve profiles from exact internal `weapon + aspect` IDs.
  - Keep `registry.lua` as the runtime source of truth.
  - Treat `BUILD_PROFILE` as a preference only among compatible profiles.
  - Auto-select `morrigan_meta` for `WeaponDagger + DaggerTripleAspect`.
  - Preserve Melinoë Starter / Intermediate selection.
  - Never guess when profile selection is ambiguous.
  - Keep unsupported weapon/aspect combinations fail-safe with no ranking.
  - Add resolver and runtime integration regression tests.
- [x] **10B.2 — Morrigan runtime validation** — COMPLETE (in-game log + visual ranking)
  - Confirmed `WeaponDagger + DaggerTripleAspect` resolves to `sister_blades_morrigan_meta` with `Supported=true` and `RankingReady=true` in game.
  - Confirmed ranking appears after removing the duplicate backup plugin from the active plugins directory.
- [x] **10B.3 — Melinoë regression** — COMPLETE (Intermediate and Starter validated in game)
  - Confirmed both profiles for `WeaponDagger + DaggerBackstabAspect` with visual rankings.
  - Live logs confirmed correct BuildId and Supported=true for both; Starter RankingReady=true.
- [x] **10B.4 — Unsupported regression** — COMPLETE (in-game Artemis + Witch's Staff)
  - Artemis: `WeaponDagger + DaggerBlockAspect`, `Supported=false`, unsupported UI with no ranks.
  - Witch's Staff: `WeaponStaffSwing + BaseStaffAspect`, `Supported=false`, unsupported UI with no ranks.
- [x] **10B.5 — Morrigan real-offer validation** — COMPLETE (in-game screenshots)
  - Confirmed ranked Hera offers with displayed reason labels and refreshed rankings after three rerolls.
  - Confirmed an incomplete offer shows `ANALYSE INCOMPLÈTE` and hides rankings when one choice is not evaluated.
  - Confirmed Sublime changes `Frappe unificatrice` from +50% to Rare +60% while ranks remain consistent.
  - Final runtime-log/error audit remains part of 10B.6.
- [x] **10B.6 — Runtime cleanliness** — COMPLETE
  - Pre-`auto` runtime audit was clean: no Boon Advisor ERROR/traceback/exception entries were found.
  - The broad Lua error search only matched `Scimiterror` script names (false positives), not actual Lua errors.
  - Final post-`auto` smoke/log audit is clean: targeted ERROR/WARN/traceback/nil/exception search returned no matches after live first-offer, reroll and Sublime validation.
  - Runtime remains informational-only; no gameplay/RNG/save mutation path was introduced by the resolver/auto-signal changes.

## 10C — v0.1.1 hotfix release

- [x] **Remove the legacy implicit Melinoë default profile.**
  - Offline implementation and regression migration are complete: full Lua 5.2 suite, resolver, probe, Phase 2, scoring, UI and diff checks pass.
  - Change the shipped default from `BUILD_PROFILE = "intermediate"` to `BUILD_PROFILE = "auto"`.
  - In `auto`, first filter profiles by the live internal weapon + aspect IDs, then use the current run state to identify the best-matching compatible build profile when several profiles share that weapon/aspect.
  - Reuse existing profile build data (for example owned core/alternative/preferred slot Boons) as runtime evidence where practical; prefer stronger build-defining evidence over weaker alternatives.
  - If exactly one compatible profile exists, select it automatically.
  - If several compatible profiles exist and runtime evidence identifies one profile unambiguously, select it automatically.
  - If runtime evidence is absent or tied between several compatible profiles, fail safely as ambiguous instead of guessing.
  - Keep explicit `starter` / `intermediate` preferences for Melinoë.
  - Morrigan must still auto-resolve because it has a single compatible profile.
  - Distinguish ambiguous profile selection from unsupported weapon/aspect in the player-facing status. Runtime-confirmed: `ambiguous` maps to `PROFIL À CHOISIR`, while `unsupported` keeps `PROFIL NON PRIS EN CHARGE`; neither renders rankings.
  - Update runtime/offline tests, staging/package defaults, profile-switcher behavior and public configuration docs accordingly.
  - Runtime/offline behavior, staging/package defaults, profile-switcher support and public configuration documentation are complete. The README now documents the `auto` default, ambiguity behavior and explicit profile overrides.
  - Auto affinity implementation has passed code review and offline regression tests for the current Melinoë/Morrigan profile set.
  - Runtime validation found an important first-offer case: Melinoë had `GodTraitCount=0`, so owned-Boon affinity alone could not resolve Starter vs Intermediate, even though the live run exposed `ForceAresBoonKeepsake`.
  - v0.1.1 auto detection must therefore support pre-Boon build-intent signals already present in the current run (for example an equipped god keepsake) when they are explicitly mapped/validated for a profile.
  - Pre-Boon signals are fallback intent evidence, not stronger than decisive owned-Boon evidence: once currently owned Boons identify a profile unambiguously, the owned build state must win over the starting keepsake signal.
  - Current offered Boons must still never participate in profile selection.
  - If owned-Boon evidence is absent/tied, use validated pre-Boon signals; if neither source distinguishes candidates, remain safely ambiguous rather than guess.
  - Auto-evidence precedence is now implemented and covered by offline tests: decisive owned-Boon affinity is evaluated before pre-Boon `autoSignals`; validated pre-Boon signals are used only as fallback evidence.
  - Verified offline cases include Ares keepsake-only → Intermediate, Ares keepsake + Ares Attack → Intermediate, Ares keepsake + Aphrodite Attack → Starter, shared Zeus Special + Ares keepsake → Intermediate via fallback, no decisive evidence → ambiguous, Morrigan singleton → Morrigan, and explicit compatible preferences remaining authoritative.
  - Live runtime revalidation confirms the first-offer case now resolves with `BUILD_PROFILE="auto"` from the Ares keepsake signal and renders normal rankings instead of unsupported/ambiguous fallback.
  - Live reroll/Sublime interaction also refreshes rankings correctly under the auto-resolved profile.
  - Live ambiguous Melinoë validation confirms the player-facing `PROFIL À CHOISIR` fallback appears with no rankings when no compatible profile can be selected decisively.
  - Live transition validation confirms auto resolution can recover later in the same run: after an initially ambiguous Melinoë start, acquiring a distinguishing Ares Boon causes owned-Boon affinity to resolve the Intermediate profile on subsequent offers. Incomplete-offer masking still works independently when one offered choice is not evaluable.
  - Final runtime/log audit passed clean after live first-offer, reroll and Sublime validation; no targeted Boon Advisor ERROR/WARN/traceback/nil/exception entries were found.
  - Additive affinity weights (`core +3 / alternative +2 / preferred +1 / discouraged -1`) are accepted for owned-Boon matching in the then-current v0.1.1 profile set; revisit weighting/signature metadata in Phase 11 if future community profiles create ambiguous or counter-intuitive matches.
  - Do not introduce a hidden/recommended default until a build is explicitly documented as recommended.
- [x] Audit the profile-resolver diff.
  - Final review covered resolver/main integration, canonical `autoSignals`, deterministic generation, staging/package inventory, profile switcher support, probe regressions and fail-safe ambiguity behavior; no blocking defect found.
- [x] Run the complete relevant regression suite.
  - Full Lua 5.2, resolver, probe, Phase 2, scoring, UI, canonical validation/generation, staging and `git diff --check` all passed after the final evidence-precedence correction.
- [x] Bump `0.1.0` to `0.1.1`.
  - Release metadata now targets `0.1.1` in `manifest.json` and `thunderstore.toml`; the changelog preserves the historical `0.1.0` entry and adds a dedicated `0.1.1` section.
- [x] Build and verify the manual GitHub ZIP.
  - Deterministic release build produced `Hades-II-Boon-Advisor-v0.1.1.zip` and passed the built-in inventory/hash verification.
  - SHA-256: `403CCE25845439ECA1883CAA5D3DE5CC190A9813C2FE696D24247A34AEFE930E`.
- [x] Build and verify the Thunderstore package.
  - Final rebased build produced `Coyh0Mods-Hades_II_Boon_Advisor-0.1.1.zip`.
  - Verified `plugins/ProfileResolver.lua` is present; packaged README includes the build-profile selection, `BUILD_PROFILE = "auto"`, and project-roadmap sections; no developer-only `tests`, `tools`, `docs`, `data/canonical`, or `dist` content is present.
  - SHA-256: `D0ECFE9F773A13C9C50329030B14108E4FE419A710A71E4E0109CE7E8D3A14F9`.
- [x] Create a new immutable `v0.1.1` Git tag.
  - Annotated tag `v0.1.1` is published and resolves to release commit `f86b3a48b929bceb0b948de86df81e1c8f777a73`.
- [x] Do not publish the GitHub `v0.1.1` release.
  - Intentionally superseded by the `v0.1.2` compliance release because the `v0.1.1` tagged source/artifacts predate the required AI disclosure. Keep the existing `v0.1.1` tag immutable and leave the GitHub release unpublished.
- [x] Do not publish Thunderstore `0.1.1`.
  - Intentionally superseded by Thunderstore `0.1.2` for the same AI-disclosure compliance reason. The verified `0.1.1` package remains historical and must not be published.
- [x] Never move or rewrite the existing `v0.1.0` tag/release.
  - `v0.1.0` remains the immutable initial public release baseline.

## 10C.1 — v0.1.2 compliance release

- [x] Keep the existing annotated `v0.1.1` tag immutable and unpublished.
  - `v0.1.1` remains attached to commit `f86b3a48b929bceb0b948de86df81e1c8f777a73`; do not move or rewrite it.
  - Do not publish the existing GitHub/Thunderstore `0.1.1` artifacts because their packaged README predates the required AI disclosure.
- [x] Add the required AI disclosure/provenance text to the public README.
  - README now states that OpenAI ChatGPT and Codex substantially assisted with architecture, code generation, code review, documentation and testing support, while requirements, design/release decisions, review and in-game validation remain maintainer-controlled.
- [x] Bump release metadata from `0.1.1` to `0.1.2` and add a `0.1.2` changelog entry.
  - `manifest.json` and `thunderstore.toml` now target `0.1.2`; `CHANGELOG.md` adds a dedicated `0.1.2` compliance entry while preserving `0.1.1` and `0.1.0` history.
- [x] Re-run relevant release/package validation after the documentation-only compliance change.
  - `tests/staging_spec.ps1` passed with exactly 13 expected staged files and matching hashes; `tests/thunderstore_package_spec.ps1` passed package/dependency/inventory validation; `git diff --check` was clean.
- [x] Build and verify the manual GitHub ZIP for `v0.1.2`.
  - Deterministic release build produced `Hades-II-Boon-Advisor-v0.1.2.zip` and passed the built-in inventory/hash verification.
  - SHA-256: `ECD11118549EC16D94771EF9290CF10BE613448C0EDA05812193BF18AC823382`.
- [x] Build and verify the Thunderstore package for `0.1.2`.
  - Final package `Coyh0Mods-Hades_II_Boon_Advisor-0.1.2.zip` contains `plugins/ProfileResolver.lua`, the AI disclosure with OpenAI ChatGPT and Codex attribution, and the `BUILD_PROFILE = "auto"` documentation; no developer-only content is included.
  - SHA-256: `9380A802ACDD543C1FB24B0B68AF89AC876BD637E69E183EF11A7AAE3BC49208`.
- [x] Create a new immutable `v0.1.2` Git tag.
  - Annotated tag `v0.1.2` is published and resolves to release commit `df707244c43e77a3a5792920caed27df74500054`.
- [x] Publish the GitHub `v0.1.2` release.
  - GitHub Release `v0.1.2` is published with the verified manual ZIP and `.sha256` assets; the ZIP asset digest matches `ECD11118549EC16D94771EF9290CF10BE613448C0EDA05812193BF18AC823382`.
- [x] Publish Thunderstore `0.1.2`.
  - `Coyh0Mods-Hades_II_Boon_Advisor-0.1.2.zip` was successfully uploaded and finalized; Thunderstore reported the package published at `https://thunderstore.io/package/download/Coyh0Mods/Hades_II_Boon_Advisor/0.1.2/`.

## 10D.0 — AI disclosure and project provenance

- [x] Re-check Thunderstore's current AI disclosure requirements before the next release.
  - Current Thunderstore guidance requires README disclosure when an LLM or other AI technology was used to create a mod/package; generated code should identify the AI/agent used.
- [x] Check whether the Hades II community exposes an applicable AI-generated category at publish time.
  - Current Hades II public categories show Audio, Libraries, Misc, Modpacks, Mods and Tools; no AI-generated category is exposed at this check, so README disclosure remains the applicable release gate.
- [x] Add a clear AI disclosure to the Thunderstore-facing README/package information.
  - Source README disclosure is complete; the v0.1.2 Thunderstore package must be rebuilt so the packaged README contains it.
- [x] Add a matching transparency section to GitHub documentation.
- [x] State that ChatGPT/Codex substantially assisted with architecture, code generation, review, documentation and testing support.
- [x] State that requirements, decisions, review and in-game validation are performed/approved by the maintainer.
- [x] Do not imply that substantially AI-assisted code was written entirely by hand.

## 10D — Public release polish, English-first

- [x] Make English the default public documentation language.
  - Public-facing README, changelog, installation, update, uninstall, and patch-compatibility documentation are now English-first; runtime labels remain unchanged for the separate 10E localization phase.
- [x] Review and polish the GitHub README.
  - README installation guidance, profile-selection behavior, fail-safe statuses, safety guarantees, AI disclosure, and Epic-manager workaround wording were reviewed and validated.
- [x] Review the repository description and release text.
  - GitHub release `v0.1.2` text is English and reviewed.
  - GitHub repository description is now: `Build-aware Hades II Boon advisor for supported Sister Blades profiles. Explains and ranks choices without changing gameplay, RNG, offers, or saves.`
  - Revisit this description in Phase 11 when support expands beyond the current Sister Blades scope.
- [x] Review `CHANGELOG.md`.
  - Historical 0.1.0/0.1.1/0.1.2 entries were translated to English without changing their technical meaning.
- [x] Review installation, update and uninstall documentation.
  - `docs/INSTALL.md`, `docs/UPDATE.md`, `docs/UNINSTALL.md`, and patch-compatibility guidance were converted to English and validated with generic public path placeholders.
- [x] Review Thunderstore description and README content.
  - `thunderstore.toml` already used an English safety-focused description; the source README used for future Thunderstore packages is now English-first and preserves the AI disclosure and informational-only guarantees.
- [x] Document Epic/Thunderstore deployment behavior if the current manager deployment limitation persists.
  - Documented as an observed workaround only: on one tested Epic Games installation, the manager kept `ReturnOfModding` inside its profile instead of copying it to `<Hades-II-root>\Ship\ReturnOfModding\`; users are told to compare/copy manually only if the mod does not appear in game.
- [x] Keep French documentation optional/secondary.
  - Remaining French technical/internal documents are secondary developer material rather than the default public user documentation.
  - The maintainer is comfortable reviewing public documentation in English directly, so English-first wording does not need to be simplified for maintainer review.

## 10E — Runtime localization

- [x] Centralize all player-facing strings.
  - Player-facing rank, status, reason and fallback text is centralized in `Localization.lua`.
  - UI reason ordering and deduplication use stable keys; translation occurs only at render time.
- [x] Detect the game language.
  - Runtime validation on the development game copy confirmed `rom.game.GetLanguage` is exposed as a function and returns the active game language.
  - Direct plugin-global `GetLanguage` access was unavailable (`nil`), so runtime localization uses `rom.game.GetLanguage` with a safe English fallback if the function is missing, errors, or returns an unsupported code.
  - Live validation confirmed switching the game from French to English from the main menu in the same Hades II process is picked up on the next run/diagnosis without restarting the game or reloading the mod.
- [x] Support English and French first.
  - Live French and English Boon-offer validation confirmed localized normal rankings, reason labels, evaluated/non-evaluated states and incomplete-analysis messaging.
- [x] Use English as the fallback language.
  - Offline localization tests cover missing, invalid and unsupported language results and verify deterministic English fallback.
  - Missing translation keys render the player-safe `TEXT UNAVAILABLE` sentinel rather than exposing internal localization keys.
- [x] Localize rank/status/reason labels and fallback messages.
  - Live FR/EN validation covered `RANG`/`RANK`, `ÉVALUÉ`/`EVALUATED`, `NON ÉVALUÉ`/`NOT EVALUATED`, conflict/utility reason labels, and incomplete-analysis title/subtitle behavior.
- [x] Never localize internal IDs or make scoring/profile selection depend on display text.
  - Stable reason codes and weapon/aspect/profile IDs remain unchanged; offline invariance tests confirm identical scores, ranks, `RankingReady` state and selected profile between English and French.
  - Final targeted development-runtime log audit after FR/EN validation returned no Boon Advisor localization-related ERROR/WARN/traceback/exception/nil-value entries.

## 10F — Logging and runtime diagnostics hardening

- [x] Define clear runtime log levels and responsibilities: `ERROR`, `WARN`, `INFO`, `DEBUG`.
  - `ERROR` and `WARN` remain available with `DEBUG=false`; `INFO` exists but is silent by default; routine diagnostics remain `DEBUG` only.
- [x] Keep real errors and actionable warnings available in normal releases.
  - Runtime validation with `DEBUG=false` confirmed a deliberately injected `ERROR` is still written to `LogOutput.log` while the plugin continues loading normally.
  - Expected unsupported/ambiguous profile states remain DEBUG rather than noisy normal-release warnings.
- [x] Keep verbose diagnostic logging disabled by default with `DEBUG = false`.
  - Live validation exercised normal ranking, standard Boon reroll, incomplete analysis and Sublimation refresh with zero `[BoonAdvisor]` lines emitted on the successful path.
- [x] Add deduplication / rate limiting for repeated identical errors or warnings so a bad callback cannot flood the log.
  - Deterministic once-per-session deduplication uses stable `LEVEL:CODE` keys with in-memory suppression counters.
  - Failed log-sink writes do not consume a dedupe key, so a later occurrence can retry.
- [x] Verify that repeated failures cannot produce per-frame log spam or unnecessary disk I/O.
  - No per-frame logging hook exists; repeated user-driven refresh paths are protected by stable-code deduplication.
  - Live DEV validation injected the same `RUNTIME_TEST_DEDUPE` error twice and produced exactly one log line.
- [x] Keep useful support context such as active weapon/aspect/profile and resolution state without exposing unnecessary data.
  - Existing DEBUG diagnostics retain internal weapon/aspect/profile/resolution identifiers; normal ERROR messages use short stable codes and avoid raw stack paths, full `CurrentRun`/save structures, or other unnecessary data.
- [x] Add regression coverage for logging behavior where practical.
  - Lua tests cover ERROR/WARN visibility with DEBUG disabled, DEBUG gating, silent INFO, missing/failing sinks, non-string messages, persistent dedupe state, suppression counts, different stable codes, and retry after a failed sink.
  - Full Lua 5.2 suite, staging validation, Thunderstore structural package validation and `git diff --check` passed.
- [x] Complete real runtime validation and restore the DEV copy after the temporary fault injection.
  - Temporary dedupe test code was removed after validation; DEV `main.lua` matches the repository `main.lua` by SHA-256 and contains zero `RUNTIME_TEST_DEDUPE` markers.

## Phase 11 — v0.2 expansion and automation

### 11A.1 — Generator safety and generic weapon/aspect catalog

- [x] **Fix shared mechanics mutation during profile composition.**
  - Profile-level weight overrides now apply to a deep-copied weights table instead of mutating the shared mechanics template.
  - Regression coverage proves an override profile generated first cannot contaminate a later profile sharing the same mechanics template.
- [x] **Introduce a canonical weapon/aspect catalog and replace the Sister Blades whitelist.**
  - Added `data/canonical/catalog/weapons_aspects.json` with only runtime IDs already verified for supported Sister Blades profiles.
  - Generator profile and mechanics validation now resolve weapon/aspect support through the catalog instead of hardcoded `WeaponDagger` / aspect checks.
  - Human-readable labels remain metadata only; runtime matching uses internal IDs exclusively.
  - `DaggerBlockAspect` remains outside the catalog and therefore unsupported.
- [x] **Preserve deterministic generation and current runtime behavior.**
  - Generated Lua output now uses explicit LF line endings for byte-stable generation on Windows.
  - All current generated Sister Blades outputs remain byte-for-byte identical to the checked-in runtime files.
  - `ProfileResolver.lua`, runtime Lua, canonical profiles, and generated runtime files were not changed.
- [x] **Clarify current `aspectMechanics` status.**
  - Repository review confirms `aspectMechanics` is currently validated canonical/audit metadata only; it is not copied by the generator or consumed by runtime scoring.
- [x] **Validate 11A.1 offline.**
  - Canonical profile validation, full Lua 5.2 regression suite, standalone mechanics validation, strict mechanics equivalence, deterministic generation, staging, and `git diff --check` all passed.
  - Staging still produces exactly 14 runtime files with matching hashes.

### 11A.2 — Build Registry import contract

- [x] **Add a deterministic Build Registry validation/import-plan layer without coupling spreadsheet transport to runtime generation.**
  - Added a Windows PowerShell 5.1 validator that consumes local JSON rows plus a separate trusted policy and emits a deterministic validation plan only.
  - The validator does not access Google Sheets, write canonical/runtime profiles, stage files, deploy to Hades II, or depend on localized display names.
- [x] **Define explicit import/readiness and verification states.**
  - `importStatus` supports `ready`, `blocked`, `excluded`, and `documentation_only`.
  - `verificationStatus` supports `verified`, `unverified`, and `not_applicable`.
  - These states remain independent; a row's own `verified` claim is insufficient unless the runtime item ID is also present in the separately reviewed trusted policy.
- [x] **Enforce exact runtime identity and safe mapping rules.**
  - Runtime item, weapon and aspect IDs use ordinal case-sensitive matching.
  - Weapon/aspect pairs must exist exactly in the canonical catalog.
  - External boon slot keys are exact lowercase `attack`, `special`, `cast`, and `sprint`; `gain -> Mana` remains intentionally blocked.
  - `module` is derived from `canonicalId`; arbitrary external module paths cannot control output.
  - Human names, labels, `priority`, and free-text `condition` remain metadata only and cannot create runtime logic.
- [x] **Define strict item-type and group blocking behavior.**
  - Verified boon rows require an explicit supported classification mapping before they can become import-plan items.
  - A verified keepsake with `slot=start` can become an `autoSignal` only through explicit trusted policy.
  - Hammer/support/arcana/familiar/hex rows cannot silently create runtime behavior.
  - `excluded` and `documentation_only` rows are skipped deterministically; any blocked/unresolved active row blocks the whole group and produces no partial runtime profile/module/items.
- [x] **Validate UTF-8 and malformed input handling.**
  - JSON is read as strict UTF-8, including UTF-8 without BOM.
  - Non-ASCII metadata is preserved in the deterministic plan while remaining non-authoritative.
  - Malformed enum values, conflicting group identity and non-string `profileMode` fail validation explicitly.
- [x] **Validate 11A.2 offline.**
  - Import-contract regression tests cover ready, rejected, skipped, blocked, exact-case IDs, exact lowercase slots, UTF-8 metadata, keepsake policy, unsupported item types, path safety and deterministic repeated output.
  - Existing canonical profile generation remains byte-identical for Sister Blades; canonical mechanics/equivalence, full Lua 5.2 regression coverage, staging with exactly 14 runtime files, and `git diff --check` all passed.
  - No runtime Lua/profile, ROADMAP-by-Codex, game deployment, release, tag, or real Build Registry access occurred during implementation.

### 11A.3 — First multi-weapon pilot: Black Coat / Melinoë Intermediate

- [x] **Verify the Black Coat runtime identity from local Hades II game data.**
  - `WeaponSuit` is the verified Black Coat weapon ID.
  - `BaseSuitAspect` is the verified Aspect of Melinoë ID for Black Coat.
  - `ForcePoseidonBoonKeepsake`, `PoseidonWeaponBoon`, `AresSpecialBoon`, and `PoseidonSprintBoon` are the verified runtime trait IDs used by this pilot.
  - Verification used exact English localization mappings plus matching game-data definitions; no IDs were inferred from names.
- [x] **Add the first non-Sister-Blades canonical profile.**
  - Added `black_coat_melinoe_intermediate` for `WeaponSuit + BaseSuitAspect`.
  - The profile uses `ForcePoseidonBoonKeepsake` as its pre-Boon auto signal.
  - Attack / Special / Sprint target `PoseidonWeaponBoon`, `AresSpecialBoon`, and `PoseidonSprintBoon`; Cast and Mana remain explicitly open.
- [x] **Keep Black Coat mechanics conservative until weapon-specific behavior is verified.**
  - Added `black_coat_melinoe` with generic build-plan weights and generic core-slot inventories only.
  - No Black Coat-specific aspect, Hammer, Omega, status, Origination, projectile, or free-text-condition scoring was introduced.
  - `genericCoreAspectCompatibility` remains `false`.
- [x] **Prove the existing generator, registry and resolver are genuinely multi-weapon.**
  - The canonical generator emits `data/builds/black_coat_melinoe_intermediate.lua` and a `coat_melinoe_intermediate` registry entry.
  - Existing Sister Blades generated profiles remain byte-for-byte unchanged.
  - `ProfileResolver.lua` remains unchanged; `WeaponSuit + BaseSuitAspect` resolves through the existing singleton-candidate path.
  - Unknown Black Coat aspects and unknown weapons remain unsupported.
- [x] **Validate the first multi-weapon pilot offline.**
  - Canonical generation, Lua 5.2 regression coverage, conservative mechanics validation, strict Sister Blades mechanics equivalence, resolver/scoring regressions, Build Registry import-contract tests, staging and whitespace checks all passed.
  - Staging now contains exactly 15 runtime files; the only newly staged runtime profile is `data/builds/black_coat_melinoe_intermediate.lua`.
  - No Hades II installation was modified or launched; no deployment, release or tag was created.
- [x] **Validate the Black Coat pilot in the live DEV game.**
  - Live diagnostics confirm `WeaponSuit + BaseSuitAspect`, `BuildId=black_coat_melinoe_intermediate`, `Supported=true`, and `BUILD_PROFILE="auto"` on a first three-choice Poseidon offer.
  - The run had `ForcePoseidonBoonKeepsake` equipped and `GodTraitCount=0`. Because this weapon/aspect currently has only one compatible profile, the observed auto-selection validates the singleton path but does **not** independently prove that the keepsake signal caused selection; isolate that signal when another Black Coat profile is introduced.
  - The initial three evaluated offers produced `RankingReady=true` with observed scores -4 (conflicting Poseidon Special), 10 (open Cast), and 5 (open Mana); UI displayed the corresponding ranks.
  - Live reroll refreshed the offers under the same Black Coat profile. `PoseidonWeaponBoon` scored 12 at Common and 13 at Rare following Sublime/`TryUpgradeBoon`; the post-upgrade log confirms `UI refresh after TryUpgradeBoon`.
  - At the 11A.3 validation point, an unknown `RoomRewardBonusBoon` / `DoubleRewardBoon` remained `Covered=false`, `Complete=false`; the then-current all-or-nothing gate masked all ranks rather than guessing. Phase 11B later replaced that behavior with validated safe partial ranking.
  - Targeted live log audit found no Boon Advisor ERROR/WARN/traceback/exception; false-positive `Scimiterror` filenames are unrelated.
  - Restored DEV `DEBUG=false` with `BUILD_PROFILE="auto"`. This is validation of the pilot only; no release, tag, or Epic installation deployment was performed.

### Phase 11 invariants

> Historical 15-file statements in completed 11A/11B milestones record the state at those validation points. Current future-v0.2 `main` uses the validated **14-file** runtime after Starter removal.


- **Keep external build-source identifiers private during import automation.**
  - Never hardcode or commit the maintainer's Google Sheet ID or full private Sheet URL.
  - Read the Sheet ID from an explicit local parameter, environment variable, connector context or secret store.
  - Keep local secret/config files untracked and covered by `.gitignore`.
  - Do not print the real Sheet ID in normal logs, test snapshots, generated JSON/Lua, package contents, release artifacts or public documentation.
  - Use fake/example IDs in tests and docs.
  - If CI import is added later, store the identifier/credentials in repository secrets rather than source-controlled files.
- **Keep the pipeline deterministic and automated:** canonical source → JSON → generated Lua profile → registry → tests.
- **Keep runtime logic informational-only:** never alter gameplay, RNG, offers, damage, saves or player choice.
- **Use verified internal Hades II IDs for runtime logic:** localized/display names and free-text build notes remain non-authoritative.

### 11B — Safe partial ranking

- [x] **Improve incomplete-offer handling with safe partial ranking.**
  - 3/3 rank-eligible choices preserve the normal full ranking.
  - 2/3 rank-eligible choices rank only the two evaluated choices against each other; the unknown choice remains `NOT EVALUATED` / hors classement.
  - 1/3 and 0/3 evaluable states display no numeric ranking.
  - `RankingReady` remains the compatibility gate for full ranking; the new decision layer exposes `full / partial / none`.
  - Partial ranking uses only `supported + eligible + covered + scoreComplete` offers and recomputes differentiating evidence on that subset only.
  - Equal evaluated choices do not receive artificial `1/2` and `2/2` ranks.
  - Unknown or incomplete offers never contribute differentiating evidence and are never silently assigned the worst rank.
  - `RARITY_UNRESOLVED`, `REPLACEMENT_UNRESOLVED`, and `ORIGINATION_UNRESOLVED` remain outside `rankEligible`; when two other choices are complete and distinguishable they may still be compared safely.
  - English/French partial-ranking labels and scope text are covered by regression tests.
- [x] **Validate 11B offline.**
  - Full Lua 5.2 regression suite, staging with exactly 15 runtime files, canonical profile generation, standalone mechanics validation, strict mechanics equivalence, Build Registry import-contract tests and whitespace checks all passed.
  - Regression coverage includes 3/3, 2/3, 1/3, 0/3, evaluated ties, unknown-only differentiating evidence, unsupported/ambiguous profiles, standard Boon reroll and Sublime refresh. Hammer rerolls are impossible in the game and are not a runtime criterion.
- [x] **Validate 11B in the live DEV game.**
  - Black Coat / Aspect of Melinoë confirmed normal 3/3 ranking with `RankingReady=true` and `RankingMode=full`.
  - Multiple real 2/3 offers confirmed `RankingReady=false` with `RankingMode=partial`, `RANG 1/2`, `RANG 2/2`, and the third choice `NON ÉVALUÉ`.
  - Live standard Boon reroll cleared and rebuilt the partial annotations correctly.
  - Live Sublime/`TryUpgradeBoon` refreshed the UI and rescored the upgraded boon while preserving partial mode and excluding the unknown choice.
  - DEV config was restored to `DEBUG=false`, `UI_TEST_MODE=false`, `BUILD_PROFILE="auto"` after validation.
  - No Epic/live installation deployment, release or tag was performed.

### 11C — Expansion and automation hardening

- [x] **Repair the historical 15-file install/update/release inventory (superseded by the 14-file v0.2 runtime).**
  - `tools/BoonAdvisor.Install.Common.ps1` now includes `black_coat_melinoe_intermediate.lua` in the exact runtime package inventory.
  - `tests/thunderstore_package_spec.ps1` now validates the exact 15-file runtime inventory.
  - Thunderstore package, install and update/rollback regression tests all passed; no Thunderstore publish or game deployment occurred.
  - No active `14-file` / `14 runtime` inventory references remain in `tools/` or `tests/`.
  - Historical completion record: the later approved Starter removal reduced the current runtime and staging inventory to 14 files; do not restore 15-file assertions.
- [x] **Extend profile-switcher coverage and documentation to Black Coat.**
  - `tools/Set-BoonAdvisorProfile.ps1` now uses registry-driven selection keys without a stale fixed profile list.
  - `tests/profile_switcher_spec.ps1` now covers `coat_melinoe_intermediate`, `-Show`, settings preservation, and regression against the obsolete fixed list.
  - Targeted profile-switcher regression passed, and no active obsolete `auto|intermediate|starter|morrigan_meta` list remains in `tools/` or `tests/`.
- [x] **Strengthen remaining end-to-end registry collision/invariant validation.**
  - Existing duplicate profile, selection-key, output, mechanics/catalog and imported canonical-ID collision checks were audited and retained without redundant variants.
  - Canonical generation and Build Registry import now reserve synthetic/control identifiers (`auto` selection key and `registry` module ID), and canonical profile IDs use the same safe lowercase format as imported canonical IDs.
  - Generated-registry tests now verify descriptor keys, canonical IDs, derived module paths and descriptor/profile identity generically for every generated profile.
  - Build Registry import, profile-switcher and canonical generation/Lua regression suites passed; no runtime gameplay behavior or deployment changed.
- [x] **Continue controlled Build Registry import expansion.**
  - Treat each repeated `profileKeyProposal` group as one candidate profile assembled from structured item rows.
  - Reuse structured `itemType=keepsake` + `slot=start` rows as possible pre-Boon signals under explicit policy.
  - Require verified machine-readable internal IDs before rows can affect runtime behavior.
  - Keep human-readable `condition` text documentation-only unless a separate machine-readable rule is defined.
  - Skip incomplete/unresolved profile groups safely; Sister Blades may remain on their current canonical JSON source of truth.
  - Black Coat — Melinoë Intermediate is the first real import pilot: a sanitized 14-row fixture preserves 4 verified runtime rows plus 10 documentation-only build rows without exposing the private spreadsheet source.
  - Its imported projection is regression-tested against the existing canonical profile for profile identity, weapon/aspect, mode, starting keepsake auto-signal, and Attack/Special/Sprint core Boons.
  - Documentation-only Arcana, Hammers, support, Familiar and Hex rows remain non-runtime and do not block the group.
- [x] **11C.5 — Add build-critical Hammer support to the canonical/import/scoring pipeline.**
  - `hammerPlan` is distinct from `hammerRoles`: the former describes offered Hammer priorities and conditions; the latter describes Hammers already owned.
  - Black Coat offers are identified by the exact `WeaponUpgrade` source. `Exhaust Riser` / `SuitDashAttackTrait` has priority 1; `Rapid Frame` / `SuitAttackSpeedTrait` priority 2; `Launcher Frame` / `SuitSpecialAutoTrait` priority 3 as a Special-branch alternative with a free-text condition.
  - Scoring is ordinal through `HAMMER_BUILD_PRIORITY`; rarity provides no bonus. Conditions are not executed: unresolved conditions produce `HAMMER_CONDITION_UNRESOLVED` and `Complete=false`, never a guessed branch.
  - Unknown Hammers remain unevaluated. Full/partial/none ranking applies only to fully evaluated choices, preserving safe partial ranking behavior.
  - Registry import requires exact verified `runtimeItemId`, `ready` / `verified` states and a conforming classification/priority. Condition text is retained as documentation and is not executable.
  - Offline implementation/review passed, including simulated 2/3 evaluation and condition cases. Live DEV validation on 2026-09-24 covered two Hammer screens: one fully evaluable choice each, unknown alternatives left unevaluated, expected `RankingMode=none`; the subsequent owned-Hammer state confirmed the selected Rapid Frame and Exhaust Riser. The log had no `[BoonAdvisor] ERROR/WARN` entries.
  - The 2/3 evaluable case was not encountered live and remains optional, non-blocking observation. The game does not allow Hammer rerolls; no such test or criterion is required. UI cleanup/refresh after selection is not claimed as log-proven.
  - No release, tag, push or Epic/live deployment is implied by this validation.
- [x] **Complete Sister Blades community build audit in the private Build Registry (documentation only).**
  - Audit contains 104 rows: Melinoë Starter 33 (rows 221–253), Melinoë Intermediate 35 (254–288), Morrigan Meta 36 (289–324).
  - 103 rows have `not_applicable` IDs; only Morrigan Vicious Flourish → `AresSpecialBoon` has a verified ID, and it remains `documentation_only` until canonical/module readiness. No row is runtime-ready by virtue of the audit alone.
  - Audit conclusions to verify against game/runtime data before canonical promotion: Starter/Intermediate default Heaven Flourish / Zeus Special; Attack branches Nova Strike (range), Flutter Strike (high %), Flame Strike (on-hit), Vicious Strike (Wounds/Grievous Blow); Trick Knives priority Hammer, with Wicked Onslaught, Rapid Onslaught and Reaper Knives alternatives; Final Slice situational; Dancing Knives conditional/uncertain, not a universal top pick; Cloud Bangle starting Zeus keepsake. Intermediate Ares Attack + Sword Hilt is conditional/build-specific.
  - Morrigan is a distinct `DaggerTripleAspect` profile: Sworn Strike/Hera or Nova Strike/Apollo Attack branches; Heaven Flourish/Zeus Special primary with Vicious Flourish and Volcanic Flourish alternatives; Born Gain for Ω-heavy, Lucid Gain alternative; Final Slice and Sweeping Ambush priority Hammers, Wicked Onslaught/Rapid Onslaught alternatives; Banshee Brand/Phantom Brand are build-specific Blood Triad amplifiers; The Sorceress is important. Dancing Knives has a strong profile-specific caution, not a universal ban. Origination boosts normal/Ω damage but not the fixed Blood Triad proc directly. Premium Service remains unverified and must not be encoded from memory.
  - No repository, canonical JSON, runtime code or ROADMAP was changed during that separate audit.
- [x] **Community Audit V2 — documentary review completed (2026-09-24).**
  - The audit covers Sister Blades — Melinoë Starter (33 rows), Sister Blades — Melinoë Intermediate (35 rows), and Sister Blades — Morrigan Meta / Blood Triad (36 rows): 104 rows total.
  - All 104 rows remain documentation_only. Community recommendations do not promote a profile or row to runtime.
  - Internal IDs and mechanics must still be independently verified against the game files and target runtime before canonicalization.
  - The audit records both source recommendations and competing recommendations; ordinal source priorities are documentation and never create numeric scoring bonuses by themselves.
- **Permanent Community Audit Gate — applies to every future build/profile.**
  - Intermediate/reference tier: use Mobalytics as the principal source; independently verify any mechanically consequential claim. Do not call single-source guidance a community consensus.
  - Meta/Best Builds tier: use Lee Reamsnyder + Mobalytics + NeonHades2, with Reddit only for substantive conflicts, bugs or unclear interactions. Mark unresolved recommendations rather than inventing a ranking.
  - Separate documented guide advice, maintainer-specific route choices, and actual game mechanics. Independently verify native IDs, prerequisites and consequential mechanics against the target game version before promoting rows to runtime.
  - Auditing one profile never validates another, including the separate Black Coat Melinoë community review. Run offline tests and realistic DEV runtime validation for every released profile.
- **Maintainer-approved v0.2 profile scope (currently present on main; release still gated).**
  - Sister Blades — Melinoë Intermediate: active runtime profile; native Ares correction and renewed live offer validation pending.
  - Sister Blades — Morrigan Meta / Blood Triad: active runtime profile; final cross-check against normalized Best Builds and live regression pending.
  - Black Coat — Melinoë Intermediate: active runtime/technically DEV-validated; separate community pilot exists, final audit approval and release-level validation pending.
  - Sister Blades — Melinoë Starter: removed from future-v0.2 runtime and generated registry; retain the historical documentary records. Published v0.1.2 behavior is unchanged.
  - The maintainer froze the intended v0.2 profile set at these three existing profiles. Do not add an additional Melinoë Meta profile or rename Intermediate without separate approval.
- **Historical Community Audit V2 Melinoë Intermediate Registry snapshot (documentary only, not runtime scoring).**
  - Cloud Bangle: priority 1; Beautiful Mirror: alternative 2; Sword Hilt: conditional 3. Heaven Flourish / Zeus Special: priority 1.
  - Nova Strike / Apollo, Flutter Strike / Aphrodite, Flame Strike / Hestia: Attack alternatives 1. Vicious Strike / Ares: conditional Attack 2 in this historical Registry snapshot.
  - Trick Knives: Hammer priority 1; Wicked Onslaught, Rapid Onslaught, Reaper Knives: alternatives 2; Final Slice: alternative 3; Dancing Knives: conditional 3.
  - Curator pilot DATA separately preserves the maintainer's Sword Hilt → Ares route as a labeled owner preference and the Zeus-first Mobalytics route as an alternative. This distinction is now present documentarily in `Build Registry v2` but has not been projected into the legacy V1 runtime profile. Neither source priorities nor classification automatically create numeric scoring bonuses.
- [x] **11C.6 — Reconcile Sister Blades v0.2 runtime offline and deploy to DEV (commit `3201282`).**
  - Removed Starter from generated registry/runtime while retaining history. Existing `BUILD_PROFILE="starter"` emits a deduplicated warning, preserves on-disk settings and falls back to session-only auto; singleton regression covers Melinoë, Morrigan and Black Coat.
  - Preserved Attack Branches architecture and the five existing Sister Blades Hammer choices. Ares conditional uncertainty is fail-safe: no premature slot-policy delta, `conflictResolved=false`, `scoreComplete=false`; all regression, canonical generation, import, package inventory and staging tests passed with **14 runtime files**.
  - Pushed implementation commit `3201282380574f8adbb1920b1a3bf40c4cc045e2`; DEV-only transactional update passed compatibility and 14-file source/staging/DEV hash comparison. Epic/live installation was not touched. The initial child-process `ShouldProcess` error wrote nothing; direct retry succeeded.
  - The first live Melinoë screenshot showed an Ares offer marked unevaluated; this historical failure was corrected and successfully regression-tested in 11C.8, including the live DEV screenshot and timestamped log.
- [x] **11C.7 — Read-only native mechanics audit completed; targeted Ares/Origination evidence paths now available, other evidence excerpts outstanding.**
  - DEV executable file/product version `139606`; static inspection only. `AresWeaponBoon` and `AresSpecialBoon` apply `AresStatus` (Rend; shared vulnerability category `Curse`); `AresStatusDoubleDamageBoon` (Grievous Blow) is a payoff requiring an existing Ares status, not a prerequisite for Attack validity.
  - `EffectVulnerabilityMetaUpgrade` checks `MinRequiredVulnerabilityEffects=2` against `victim.VulnerabilityEffects`. The inspected logic does not directly require two different Olympians; confirm exact category combination/deduplication before coding new Origination inference.
  - Morrigan `CheckFinisher` requires Attack, Special and Ex/Ω markers on the same target; `WomboStrike` base damage 111 has `IgnoreAllModifiers=true`. `DaggerTripleBuffTrait` buffs the finisher; `DaggerTripleRepeatWomboTrait` specifies 0.33 repetition chance.
  - `DaggerSpecialJumpTrait` preserves `FinalJumpToOwner=true`; no blanket Zeus exclusion proven. No static mutual exclusion was found for `DaggerRapidAttackTrait` / `DaggerAttackFinisherTrait`, but dynamic behavior is not proven.
  - Hephaestus `WeaponUpgradeBoon` (Premium Service) requires one trait from each of three native groups **and** `WorldUpgradeWeaponUpgradeSystem`. Name-to-ID mappings of all human guide entries still need confirmation. Obtain precise native file paths/function excerpts for the remaining claims and keep unresolved mechanics separate.
  - [x] Codex provided native DEV paths for the targeted Ares fix: `Content/Scripts/TraitData_Ares.lua` (AresWeaponBoon applies AresStatus), `Content/Scripts/TraitData.lua` (AresRendTraits and Grievous Blow prerequisite direction), `Content/Scripts/EffectData.lua` (Rend / Curse category), and `Content/Scripts/TraitData_MetaUpgrade.lua` (Origination threshold). DEV executable version/hash matched the prior audit. This annex does not establish exact category deduplication or independently prove the other native claims.
- [x] **11C.8 — Fix Ares base-branch scoring and rerun realistic live DEV validation (commit `10af364`).**
  - Evaluate `AresWeaponBoon` as a valid Attack independently of Grievous Blow. Keep downstream Rend/Origination synergy conservative until category-combination behavior is proven.
  - Preserve safe replacement/partial-ranking behavior and assert no unjustified `BUILD_SLOT_POLICY_DELTA`; add direct regression coverage for normal↔Ares replacement cases.
  - [x] **Native evidence supplied for this fix:** `TraitData_Ares.lua:4`, `TraitData.lua:91,254`, `EffectData.lua:1848`, `TraitData_MetaUpgrade.lua:1076` (Codex report; game executable `139606`, prior hash confirmed).
  - [x] **Corrective patch merged to `main` and deployed DEV-only:** `AresWeaponBoon` moved from conditional `WOUNDS_ACCESS` to `alternative` with ordinal priority 2 in canonical Intermediate JSON and regenerated Lua; `ScoringEngine.lua`, Origination rules, other profiles and five Hammer choices unchanged. Exactly five committed files (canonical JSON, generated Lua and three tests), commit `10af3645165cf286db6c28609dbcb4d4bae61e49`. The review-only `.patch` remained untracked and undeployed.
  - [x] **Offline validation reported by Codex:** Lua 5.2 suites, targeted replacement/Origination/regression cases, canonical deterministic generation and equivalence, import, resolver/profile switcher, staging/package inventory, install/update/uninstall, patch compatibility and `git diff --check` passed. Re-run after fast-forward to the latest pre-patch `main` passed. Staging contains 14 files; generated/staged Intermediate Lua SHA-256 matched. Raw test logs were not independently rerun here.
  - [x] **Independent static patch review:** the attached `ares-11C8-review.patch` contains exactly the expected five file diffs; Ares is now an unconditional alternative Attack with ordinal priority 2 in canonical JSON and generated Lua. Tests cover Attack replacements, genuine unresolved-branch safety, unknown Origination and valid slot-policy transitions. The five patch preimage blob SHA prefixes match the corresponding files on current GitHub `main`. No ScoringEngine changes or unrelated patch hunks were found. Offline test PASS results are Codex-reported, not independently rerun here.
  - [x] **Integration completed:** local `3201282` was fast-forwarded after stashing/restoring exactly five modified files and the review patch; Codex reran relevant suites, then committed and pushed the reviewed five-file fix to `main` as `10af364` (no ROADMAP or patch artefact in commit).
  - [x] **DEV deployment verified (maintainer-authorized):** transactional staging/compatibility PASS; exactly 14 installed files, 13 staging→DEV hash matches; the preserved DEV `config/settings.lua` retained `DEBUG=true` and matched its own predeployment hash. `UI.lua` full SHA-256 in staging and DEV: `886289BF673282D44A8FCD429DA6076961BEE75337CDE26BA5BF99A2F37C9D01`. No Epic/live access.
  - [x] **Final live regression, 2026-09-24 22:59:55:** maintainer started a new run with Ares-forcing Keepsake, empty Attack slot, Sister Blades / Melinoë. Screenshot displays Ares Vicious Strike as RANG 1 (all three offers ranked); Codex's timestamped log review confirms profile `sister_blades_melinoe_intermediate`, `AresWeaponBoon` with `FillsEmpty=true`, score 13 = `FILL_EMPTY_PRIMARY_CORE +8` + `ASPECT_COMPATIBLE +4` + `RARITY +1`, `Eligible=true`, `Covered=true`, `Complete=true`, `RankingMode=full`, and no `ATTACK_BRANCH_UNRESOLVED` or Boon Advisor error. Origination was active but `OwnedStatusFamilies=none`; unproven category combinations remain unresolved.
- [x] **11C.9 — Accept completed Community Curator migration, classify provenance gaps, and freeze the intended v0.2 profile set.**
  - [x] Curator migrated the remaining nine builds (four Intermediate, five Meta) and added 260 atomic recommendations; the final DATA now has **191 Intermediate + 187 Meta = 378 rows**, spanning six distinct profiles per tier. Ten new V2 cards plus the two existing prototypes give six human guides per final guide tab.
  - [x] Promoted the approved compact V2 guides into `Builds intermédiaires` and `Best Builds`; finalized `Build Data — Intermediate` / `Build Data — Best`; removed superseded prototype tabs; retained the unchanged `Build Registry` and both archives. Curator reported zero formula errors/new duplicates/low-contrast content cells; connector read-back confirmed six keys per tier and no displayed formula errors in scanned human guide ranges.
  - [x] **Human-guide V2 visual approval by maintainer (2026-09-24).** Community Curator inspected all 12 cards, rebuilt the 10 non-pilot cards as individual four-column recommendation rows, preserved the two pilot references, verified navigation/formulas in native Sheets, and removed temporary repair tabs. The maintainer explicitly approved the final visual presentation. No DATA, Build Registry or mod code changed.
  - [x] **Classify historical provenance gaps in Registry v2:** all 34 missing source dates (19 Intermediate, 15 Meta) are explicitly `unknown`; all 20 missing public URLs (12 Intermediate, 8 Meta) are `public_url_not_applicable` for owner preferences/Curator inferences. Preserve DATA blanks and do not invent publication dates or URLs.
  - [x] **Freeze v0.2 runtime scope (maintainer-approved 2026-09-24):** Sister Blades Melinoë Intermediate, Sister Blades Morrigan Meta, and Black Coat Melinoë Intermediate. Prepare Registry v2 documentary coverage for all 12 guides; keep the remaining nine out of v0.2 runtime. Promote accessible non-hidden-aspect profiles first in later patches, and hidden-aspect profiles only when unlocked and independently validated in DEV.
  - [x] **Final DATA content approval by maintainer (2026-09-24):** all 378 recommendations accepted as the documentary reference, including explicitly unresolved items. The two unnamed Main choices (Persephone Special, Nyx Sprint), unresolved Morrigan Special comparisons and unproven mechanics remain non-executable until independently specified and verified. Approval is not a declaration of 12 validated runtime profiles; all Registry v2 records remain `documentation_only`.
  - [x] **Resolve DATA→canonical identity mapping in Registry v2:** all 12 DATA BuildKeys have explicit canonical IDs; the three active v0.2 mappings are verified against existing canonical profiles, while the nine deferred IDs are explicitly proposed/pending verification. No runtime IDs were inferred or silently renamed.
  - [x] Added a compact clickable index/jump links for the six vertically stacked guide cards per human tab, preserving the approved V2 card design. Native Google Sheets links navigate without filtering or hiding adjacent cards.
- [x] **11C.10 — Design and approve Build Registry v2 from finalized DATA.**
  - Approved a separate 49-column Registry v2 schema with stable recommendation IDs, profile identity/scope, phase-aware Keepsake metadata, provenance, independent recommendation/native-mechanics/native-ID verification states, and explicit runtime block reasons.
  - Migrated all **378** DATA recommendations documentarily into `Build Registry v2`: 118 rows for the three v0.2-scope profiles and 260 deferred rows. All rows remain `documentation_only`; no new runtime execution was enabled.
  - Connector QA confirmed exact 1:1 source coverage against both DATA tabs, zero missing DATA rows, zero duplicate recommendation IDs/fingerprints, and no field mismatches in mapped source content. The legacy 21-column `Build Registry` remains untouched and was duplicated to `Archive — Build Registry v1 2026-09-24` before further Registry work.
  - Documentary `Priority` remains separate from runtime scoring; free-text/unknown conditions remain non-executable. The v2 schema must project explicitly into the legacy V1 import contract until a separately approved importer upgrade exists.
- [ ] **Optional, non-blocking provenance follow-up:** verify up to 34 currently `unknown` historical source publication dates only if authoritative page/archive evidence exists; otherwise leave `unknown`. This research is outside the completed 11C.9 documentary approval and is not a runtime import prerequisite.
- [ ] **11C.11 — Generate vetted canonical profiles and introduce informational `keepsakePlan`.**
  - [x] **Read-only first-pass screening received (2026-09-24):** Codex examined the 378-row CSV (118 in v0.2 scope, 260 deferred) against the three existing canonical profiles and V1 importer contract. All 118 v2 records currently remain `documentation_only` with `content_review_pending`, `not_reassessed` native IDs/mechanics and `free_text_unresolved`; no v2 row is currently eligible for automatic V1 import. This is a record-state result, not proof that no individual existing runtime mechanic is valid. No files, Sheet or runtime were modified.
  - [x] **Melinoë Intermediate deep read-only audit, 38/38 records (Codex report, 2026-09-24):** cross-referenced documentary records against current canonical JSON, generated Lua and DEV-native name/ID files. Four Attack branches, Zeus Special core and five evaluable Hammers are already represented; `Dancing Knives` stays outside the executable Hammer plan. Eight Keepsake records have candidate native ID mappings for a phase-only informational plan. Unknown Arcana mappings, unresolved conditions, support, Familiar and Hex effects remain outside scoring; the live-validated base Ares Attack must never regain `WOUNDS_ACCESS`.
  - [x] **Morrigan Meta deep read-only audit, 45/45 records (Codex report, 2026-09-24):** mapped documented Boons, Keepsakes and seven Hammers against current canonical and DEV-native text; `Harmonic Photon` maps to `ForceApolloBoonKeepsake` according to `TraitText.en.sjson`, whereas documentary `Embryo` is displayed natively as `Transcendent Embryo`. Base Attack/Cast/Mana/Sprint selections broadly match existing canonical. Special classification discrepancies (Ares, Hephaestus, Apollo, Aphrodite), all seven unprojected Hammers, Blood Triad context and free-text conditions require distinct decisions and native mechanic verification before projection. Name→ID mappings alone do not validate a scoring mechanic; no runtime/Sheet changes occurred.
  - [x] **Black Coat Melinoë deep read-only audit, 35/35 records (Codex report, 2026-09-24):** mapped documentary entries to available DEV-native names/IDs and current canonical. Existing Poseidon Attack, Ares Special, Poseidon Sprint, and Exhaust Riser/Rapid Frame/Launcher Frame Hammers match the canonical baseline. Hestia/Zeus Attack, Zeus Special/Cast, Reaper Frame and conditional supports are documentary candidates only. Launcher Frame's `Special branch` remains non-executable and its evaluation incomplete. Phase-aware Vivid Sea→later Keepsake candidates can inform a future advisory; preserve the existing Poseidon `autoSignal`, without promoting the other Keepsakes to profile-selection evidence. No files or runtime were modified.
  - [x] **Registry v2 documentary approval metadata reconciled and independently verified (2026-09-24):** Community Curator backed up `Build Registry v2` as `Backup — Build Registry v2 pré-11C.11 2026-09-24`, changed all 378 `recommendationVerificationStatus` values from `content_review_pending` to `documentary_content_approved` and removed only `content_approval_pending` from all 378 `runtimeBlockReasonsJson`. Independent Google Sheets connector comparison of the complete active and backup 49-column/378-row tabs found 378 unique stable recommendationIds, 118 active + 260 deferred, exactly the two authorized fields changed per record and zero other field changes; JSON valid and both `explicitly_unresolved_recommendation` markers intact. All 378 records remain `documentation_only`, with native ID/mechanics checks `not_reassessed`; this is not runtime eligibility. Curator corrected an initial partial 377-row write from the backup before final QA.
  - [ ] **Resolve selected v0.2 source→runtime differences before projection:** the documentary Melinoë Ares route describes a conditional Wounds preference while the live-validated base `AresWeaponBoon` Attack is unconditionally valid; distinguish build preference from native boon prerequisite and do not reverse the 11C.8 fix. Separately verify Morrigan Special/Hammer choices and Black Coat alternatives/Hammer conditions against native evidence. Treat existing trusted canonical choices as a baseline, not 118 fresh changes.
  - [x] **Read-only per-profile inventory completed for all 118 v0.2 documentary records (38 Melinoë + 45 Morrigan + 35 Black Coat):** all three Codex reports identify available name→ID evidence, overlap with canonical and unresolved choices/conditions. This closes the inventory stage only; no v2 record was promoted, and naming evidence does not complete native-mechanics verification.
  - [ ] **Consolidate the 118-row decision matrix and verify only consequential proposed runtime changes:** distinguish preexisting DEV-validated behavior from new additions; resolve owner decisions on Morrigan Specials/Hammers and Black Coat alternatives/Reaper Frame only if proposed for v0.2. Do not promote the other 260 records. Every newly projected row needs independent native-ID/mechanics evidence and realistic per-profile DEV testing; defer review of the nine future builds until their inclusion is proposed.
  - [x] **Consolidated implementation proposal received (Codex report, 2026-09-24; planning only):** inventoried A/B/C against the three active canonical profiles, proposed optional informational `keepsakePlan` for `Start`/`R2`/`R3`/`Final`, and documented conservative V2→V1 gating with unverified recommendations excluded. No code, Sheet, tests or runtime changed. Proposal still requires schema/UX decisions and exact projection review before implementation. The existing V1 import contract cannot ingest arbitrary `keepsakePlan` records; keep advisory metadata separate from the V1 runtime-item projection unless a separately reviewed importer upgrade is authorized.
  - [ ] Define and review an explicit Registry v2→V1 projection and phase-aware `keepsakePlan` mapping; leave unknowns documentary-only and preserve existing gameplay/scoring semantics until separately approved.
  - [x] **Maintainer decision (2026-09-24):** include and test optional `keepsakePlan` metadata in all three v0.2 canonical profiles, but **no new in-game UI in v0.2**. Keep metadata informational and non-executable: Start/R2/R3/Final, exact verified Keepsake IDs, documentary classification/priority, raw condition text, stable recommendationId. No scoring, resolver/autoSignals changes (preserve Black Coat's existing Poseidon signal), RNG, offers, saves, or automatic profile selection. Treat this metadata separately from the V1 importer, which does not currently support it. Implement and regression-test locally first; DEV deployment, any scoring changes and release remain separate approvals.
  - [ ] **Implement and test metadata-only `keepsakePlan` for the three existing profiles:** extend canonical schema/generator conservatively, deterministic generated Lua parity, reject unknown/duplicate IDs and malformed phases as appropriate, preserve unresolved route conditions as display-only text, and assert zero effects on existing runtime behavior. Verify the new Sheet status export before any unrelated Registry v2→V1 item promotion.
  - Import only approved Registry records with verified IDs/mechanics. Generate phase-aware Keepsake guidance without changing RNG, offers, saves or player choice.
  - Add/expand resolver regression generation where practical as part of this work rather than as a separate open-ended task.
  - Re-run deterministic canonical/Lua generation, importer, scoring/resolver, staging, install/update/uninstall and packaging regressions; then complete realistic DEV validation for each planned v0.2 profile.
- [x] **Multiple-profile policy for the same weapon/aspect pair is defined.**
  - `auto` filters by exact weapon + aspect, then uses decisive owned build evidence before validated pre-Boon intent signals. If evidence is absent/tied, fail safely as ambiguous.
  - Manual explicit profile selection remains an override/fallback for true same-aspect ambiguity. Profile identity remains separate from weapon/aspect identity.
  - New profiles must not reintroduce offer-based profile selection or hidden defaults.

### 11D — v0.2 release readiness

`v0.1.2` remains the published Sister Blades-only release. 11D is a **release gate only**: implementation/audit work belongs to 11C and is not duplicated here. No release action is authorized until the relevant 11C milestones are complete.

- [ ] **Modernize public/project documentation for the finalized v0.2 scope.**
  - Update `README.md` and repository description for multi-weapon support while clearly separating published `v0.1.2` from future `v0.2`.
  - Modernize `docs/RUNTIME_TEST.md` for the current resolver/full/partial/localization/profile validation flow.
  - Refresh or mark historical sections in `docs/TECHNICAL_ANALYSIS.md` that describe obsolete defaults, profile inventories or staging counts.
- [ ] **Harden the release/developer gate.**
  - Ensure Build Registry import, deterministic generation, staging/package inventory, install/update/uninstall, localization, scoring/resolver and package regressions cannot be skipped accidentally.
  - Prevent building a `0.1.2` artifact from future-v0.2 `main`; bump version metadata before release artifact creation.
- [ ] **Run final dependency and profile validation.**
  - Re-check pinned dependency/runtime versions.
  - Require every v0.2 profile to have its approved Community Audit/Data provenance, verified native IDs/mechanics where consequential, and realistic DEV runtime validation.
  - Run final live regression for every profile in the maintainer-approved v0.2 profile set.
- [ ] **Prepare public release content.**
  - Ensure the source English `CHANGELOG.md` is the one bundled/published so Thunderstore no longer shows the historical French 0.1.2 changelog.
  - Review AI disclosure, installation/update notes and supported-profile scope.
- [ ] **Publish v0.2 only after all release gates pass.**
  - Bump version, rebuild deterministic staging/packages, verify inventories and SHA-256, create an immutable tag, publish GitHub release, then publish Thunderstore.

## Later — Expand runtime with additional builds (after v0.2)

The nine deferred profiles and their 260 documentary Registry v2 rows remain `documentation_only` until a later, separately scoped release. Do not require a full personal recommendation-by-recommendation review of those future profiles during 11C.11 or block v0.2 on their unresolved entries.

- [ ] **Select the next build-expansion scope with the maintainer.** Prefer accessible non-hidden aspects; only consider hidden aspects once unlocked and independently verified in DEV.
- [ ] **Review each proposed new build when it is actually scheduled for runtime inclusion:** confirm the maintainer still agrees with its guide recommendations, resolve or explicitly exclude incomplete/contested entries (including Persephone Special and Nyx Sprint where applicable), and check current native IDs and consequential mechanics. Reassess deferred Morrigan Special comparisons only if they are to become executable; do not presume approval from documentary sign-off.
- [ ] **Promote only individually approved, verified records:** perform explicit Registry v2→V1 projection (or separately approve a new importer), add focused tests, run offline suites and realistic per-profile DEV validation. Keep unrelated and unresolved DATA documentary-only; require a separate release gate before publishing.

## Later — Profile selection and UI polish

- [ ] Add an in-game profile selector as a future override/fallback for `auto`:
  - Suggested flow: Weapon → Aspect → validated Build/Profile.
  - Keep `Auto` as the default/recommended operating mode.
  - Manual selection must only offer profiles compatible with the selected weapon/aspect.
  - A manual choice must override auto-detection without changing scoring data.
  - Decide later whether the override persists across runs/sessions or is run-scoped.
  - Design the selector so future community-contributed profiles appear automatically from the registry rather than from hardcoded menu entries.
### UI polish

Stability and correctness come first. UI redesign happens after runtime/profile selection is proven stable.

- [ ] **Run one consolidated UI polish pass.**
  - Improve placement, Hades II visual integration, icons/emphasis and hierarchy while preserving the native choice screen.
  - Validate multiple resolutions and localized text lengths without overlap.
- [ ] **Show the active/detected build profile discreetly.**
  - Prefer the unused upper-right status area near analysis/status text; keep it small, low-attention and non-animated.
  - Show auto-detected profile clearly enough for player/support diagnostics and distinguish any future manual override.
  - Re-evaluate placement during the polish pass if localization/resolution makes the upper-right area crowded.

### Later — Build guidance and optimization

Legendary/Duo eligibility and information-only RNG-steering guidance are deferred until after Pom priority and Build Setup Health. Model goals, alternative prerequisites and owned/missing state without changing RNG or offers. Premium Service's native three-group gate plus `WorldUpgradeWeaponUpgradeSystem` requirement are verified at the mechanics level, but human-name→internal-ID mappings still require exact confirmation before runtime guidance.

These features extend the advisor beyond immediate Boon ranking while remaining informational-only and visually secondary.

- [ ] **Pom priority advisor.**
  - When a Pom offers upgrades for Boons already owned, use the active build profile to indicate which offered Boon is the better upgrade priority.
  - Start with existing profile roles/priorities rather than introducing a separate opaque scoring model.
  - Keep this independent from Boon-offer ranking and never alter the offered choices or gameplay state.
- [ ] **Discreet Build Setup Health indicator.**
  - Surface lightweight build-state checks without competing visually with the main ranking UI.
  - Validate important Arcana setup expectations where they are explicitly defined by the profile.
  - Model Keepsakes as a run sequence rather than simultaneous requirements: starting Keepsake first, then later expected/recommended Keepsake changes by run phase when such a plan is defined.
  - Example intent: `Arcana ✓ · Starting Keepsake ✓ · Next Keepsake !`, using low-attention status text rather than warnings or blocking UI.
  - Missing or intentionally different setup choices remain informational; they must not make a supported profile fail or override player choice.
- [ ] **Evaluate Hex and Familiar guidance before adding runtime weight.**
  - Keep Hex and Familiar metadata available in build sources, but only promote them into runtime advice if testing shows they produce useful, actionable build decisions.
  - Avoid adding scoring/runtime complexity merely because the data exists.
## Confirmed runtime facts

| Item | Internal ID | Status |
| --- | --- | --- |
| Sister Blades | `WeaponDagger` | Confirmed in game |
| Aspect of Melinoë | `DaggerBackstabAspect` | Confirmed |
| Aspect of Morrigan | `DaggerTripleAspect` | Confirmed in game |
| Aspect of Artemis | `DaggerBlockAspect` | Intentionally unsupported in current release scope |
| Black Coat | `WeaponSuit` | Verified from local game data and live DEV runtime |
| Black Coat — Aspect of Melinoë | `BaseSuitAspect` | Verified from local game data and live DEV runtime |

Current profile state (published versus development):

- Published `v0.1.2` remains Sister Blades-only and preserves historical Starter/Intermediate support.
- Future-`v0.2` `main`: Sister Blades — Melinoë Intermediate, Sister Blades — Morrigan Meta / Blood Triad, Black Coat — Melinoë Intermediate; exact **14-file** DEV inventory. Melinoë Starter is removed on `main`, not retroactively from the published release.
- Sister Blades Ares scoring correction and final live DEV verification are pending; all prospective release profiles must pass their independent Community Audit Gate and realistic DEV test.
- Other weapon/aspect combinations remain unsupported unless explicitly added to the generated registry and validated.

## Deferred design decisions

These are intentionally deferred beyond the current Phase 11 / future `v0.2` work unless promoted into an explicit milestone:

- A future explicit `recommended` metadata/policy may be added for discovery/documentation, but it must not silently override the user's choice when multiple profiles exist.
- Lazy-loading/profile caching for a future large profile catalog.
- Post-v0.2 runtime promotion of additional builds/aspects documented by Community Curator; DATA coverage alone never implies runtime support.
- Large UI redesign.
- Additional runtime languages beyond English/French.
- Full automation from external build data sources.

## Release principles

- The advisor is informational only.
- Do not change gameplay, RNG, offered Boons, damage, saves or player choices.
- Prefer internal IDs over localized names.
- Unsupported or ambiguous states must fail safely rather than guess.
- Scoring calibration is not changed as part of profile-resolution work.
- Public releases require tests and real in-game validation.
