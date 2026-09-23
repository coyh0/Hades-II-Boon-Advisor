# Hades II Boon Advisor — Roadmap

_Last updated: 2026-09-23_

This file is the project roadmap and the source of truth for planned work and validation status.

**Maintenance rule:** ChatGPT updates this roadmap automatically when a milestone has been objectively completed and validated in our workflow, or when the maintainer explicitly requests a roadmap change. Coding agents such as Codex must not self-mark milestones complete or change priorities on their own; their work must first be reviewed and, where relevant, tested.

## Current focus

**11C — Expansion and automation hardening**

Published release: `v0.1.2` — Sister Blades only.

Current `main` / future `v0.2`: Black Coat pilot validated offline and live DEV; safe partial ranking validated offline and live DEV.

Next priority: repair release/install tooling for the 15-file runtime inventory, then continue controlled profile expansion.

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
- [ ] Publish the English changelog on Thunderstore in the next package version.
  - The live Thunderstore `0.1.2` changelog still renders the French `CHANGELOG.md` that was bundled when `0.1.2` was published.
  - Thunderstore package versions are immutable, so `0.1.2` cannot be edited in place; the already-translated English `CHANGELOG.md` on `main` will appear only after a new package version is built and published.
  - This is non-blocking for `0.1.2`; carry it as a required release checklist item for the next published version so the Thunderstore changelog switches to English.
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
  - Live validation exercised normal ranking, reroll, incomplete analysis and Sublimation refresh with zero `[BoonAdvisor]` lines emitted on the successful path.
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
  - Regression coverage includes 3/3, 2/3, 1/3, 0/3, evaluated ties, unknown-only differentiating evidence, unsupported/ambiguous profiles, reroll and Sublime refresh.
- [x] **Validate 11B in the live DEV game.**
  - Black Coat / Aspect of Melinoë confirmed normal 3/3 ranking with `RankingReady=true` and `RankingMode=full`.
  - Multiple real 2/3 offers confirmed `RankingReady=false` with `RankingMode=partial`, `RANG 1/2`, `RANG 2/2`, and the third choice `NON ÉVALUÉ`.
  - Live reroll cleared and rebuilt the partial annotations correctly.
  - Live Sublime/`TryUpgradeBoon` refreshed the UI and rescored the upgraded boon while preserving partial mode and excluding the unknown choice.
  - DEV config was restored to `DEBUG=false`, `UI_TEST_MODE=false`, `BUILD_PROFILE="auto"` after validation.
  - No Epic/live installation deployment, release or tag was performed.

### 11C — Expansion and automation hardening

- [x] **Repair the 15-file install/update/release inventory.**
  - `tools/BoonAdvisor.Install.Common.ps1` now includes `black_coat_melinoe_intermediate.lua` in the exact runtime package inventory.
  - `tests/thunderstore_package_spec.ps1` now validates the exact 15-file runtime inventory.
  - Thunderstore package, install and update/rollback regression tests all passed; no Thunderstore publish or game deployment occurred.
  - No active `14-file` / `14 runtime` inventory references remain in `tools/` or `tests/`.
- [x] **Extend profile-switcher coverage and documentation to Black Coat.**
  - `tools/Set-BoonAdvisorProfile.ps1` now uses registry-driven selection keys without a stale fixed profile list.
  - `tests/profile_switcher_spec.ps1` now covers `coat_melinoe_intermediate`, `-Show`, settings preservation, and regression against the obsolete fixed list.
  - Targeted profile-switcher regression passed, and no active obsolete `auto|intermediate|starter|morrigan_meta` list remains in `tools/` or `tests/`.
- [ ] **Strengthen remaining end-to-end registry collision/invariant validation.**
  - Existing generator/import validation already covers many duplicate IDs, selection keys, output names and module constraints; add only the remaining cross-layer cases rather than duplicating existing checks.
- [ ] **Continue controlled Build Registry import expansion.**
  - Treat each repeated `profileKeyProposal` group as one candidate profile assembled from structured item rows.
  - Reuse structured `itemType=keepsake` + `slot=start` rows as possible pre-Boon signals under explicit policy.
  - Require verified machine-readable internal IDs before rows can affect runtime behavior.
  - Keep human-readable `condition` text documentation-only unless a separate machine-readable rule is defined.
  - Skip incomplete/unresolved profile groups safely; Sister Blades may remain on their current canonical JSON source of truth.
- [ ] **Add a second validated profile for an existing weapon/aspect pair.**
  - Use it to validate real competition between owned-Boon affinity, pre-Boon auto signals and safe ambiguity.
  - Explicitly prove the Black Coat Poseidon-keepsake signal once singleton selection no longer makes the signal observationally redundant.
- [ ] Generate/expand profile-resolution regression tests automatically where practical.
- [x] Define the multiple-profile policy for the same weapon/aspect pair:
  - The runtime may contain several community/maintainer-approved profiles for the same weapon + aspect.
  - `auto` first filters by weapon + aspect, then uses the current run state/build evidence to select the matching profile when that evidence is decisive.
  - Existing build structure (owned core/alternative/preferred Boons and occupied core slots) is the primary profile-affinity evidence; decisive owned-Boon state must outrank pre-Boon intent signals such as starting keepsakes.
  - Validated pre-Boon signals are fallback evidence for early-run detection when owned-Boon evidence is absent or tied; future profiles may add explicit activation/signature metadata if needed.
  - If all available evidence is absent or tied, `auto` must fail safely as ambiguous rather than guess.
  - Keep an explicit profile selection mechanism as an override/fallback for truly ambiguous same-aspect variants.
  - Profile identity must remain distinct from weapon/aspect identity so future creative/community builds can coexist.
- [ ] Add more supported builds and Aspects.

### 11D — v0.2 release readiness

- [ ] Modernize `README.md` and repository description for multi-weapon support while clearly distinguishing published `v0.1.2` from future `v0.2`.
- [ ] Modernize `docs/RUNTIME_TEST.md` from the Phase 1 probe procedure to the current resolver/full/partial/reroll/Sublime/localization validation flow.
- [ ] Refresh or clearly mark historical sections in `docs/TECHNICAL_ANALYSIS.md` that describe obsolete profile defaults, unsupported generated profiles or old staging inventories.
- [ ] Expand the release/developer validation gate so Build Registry import and packaging regressions cannot be skipped accidentally.
- [ ] Prevent building a `0.1.2` artifact from future-v0.2 `main`; bump the version before release artifact creation.
- [ ] Re-check pinned dependency/runtime versions before release.
- [ ] Run live regression validation for every profile intended for `v0.2`.
- [ ] Prepare the Thunderstore changelog in English.
- [ ] Bump version, rebuild staging/package, verify ZIP and SHA-256, create an immutable tag, publish GitHub release, then publish Thunderstore.



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

- [ ] Improve placement and hierarchy while preserving the native Hades II choice screen.
- [ ] Improve visual integration with the Hades II style.
- [ ] Review icons, emphasis and color usage where useful.
- [ ] Prevent overlap at different resolutions and localized text lengths.
- [ ] **Show the active/detected build profile discreetly in the in-game UI**, for example:
  - `Profile: Melinoë — Intermediate`
  - `Profile: Morrigan — Meta`
  - When `auto` resolves a profile from live run state, show the detected profile so the player can immediately verify what the advisor is using.
  - If a future manual override is active, distinguish it clearly but discreetly from an auto-detected profile.
- [ ] Prefer a low-attention placement in the unused upper-right status area (near the current analysis/status message) so the player can confirm the active build without pulling focus away from the boon choices.
- [ ] Keep the active-profile indicator visually secondary to ranking/status text: small type, low visual weight, no animation, and no extra input required.
- [ ] Re-evaluate the exact placement during UI polish if localization or resolution constraints make the upper-right area too crowded.
- [ ] Keep the active-profile indicator useful for both players and support/debugging without dominating the UI.

## Confirmed runtime facts

| Item | Internal ID | Status |
| --- | --- | --- |
| Sister Blades | `WeaponDagger` | Confirmed in game |
| Aspect of Melinoë | `DaggerBackstabAspect` | Confirmed |
| Aspect of Morrigan | `DaggerTripleAspect` | Confirmed in game |
| Aspect of Artemis | `DaggerBlockAspect` | Intentionally unsupported in current release scope |
| Black Coat | `WeaponSuit` | Verified from local game data and live DEV runtime |
| Black Coat — Aspect of Melinoë | `BaseSuitAspect` | Verified from local game data and live DEV runtime |

Current supported profile intent:

- Sister Blades — Melinoë Starter
- Sister Blades — Melinoë Intermediate
- Sister Blades — Morrigan Meta / Blood Triad
- Black Coat — Melinoë Intermediate (offline and live DEV validated; not yet released)
- Other weapon/aspect combinations: unsupported unless explicitly added to the registry and validated.

## Deferred design decisions

These are intentionally deferred beyond the current Phase 11 / future `v0.2` work unless promoted into an explicit milestone:

- A future explicit `recommended` metadata/policy may be added for discovery/documentation, but it must not silently override the user's choice when multiple profiles exist.
- Lazy-loading/profile caching for a future large profile catalog.
- Further multi-weapon profile expansion beyond the first Black Coat pilot.
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
