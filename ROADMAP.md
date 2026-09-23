# Hades II Boon Advisor — Roadmap

_Last updated: 2026-09-23_

This file is the project roadmap and the source of truth for planned work and validation status.

**Maintenance rule:** ChatGPT updates this roadmap automatically when a milestone has been objectively completed and validated in our workflow, or when the maintainer explicitly requests a roadmap change. Coding agents such as Codex must not self-mark milestones complete or change priorities on their own; their work must first be reviewed and, where relevant, tested.

## Current focus

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
- [ ] **10B.6 — Runtime cleanliness** — NEXT
  - Confirm clean logs, no Lua errors and no gameplay/RNG/save mutations.

## 10C — v0.1.1 hotfix release

- [ ] **Remove the legacy implicit Melinoë default profile.**
  - Change the shipped default from `BUILD_PROFILE = "intermediate"` to `BUILD_PROFILE = "auto"`.
  - In `auto`, select a profile automatically only when exactly one compatible profile exists.
  - If several compatible profiles exist and no explicit preference is set, fail safely as ambiguous instead of guessing.
  - Keep explicit `starter` / `intermediate` preferences for Melinoë.
  - Morrigan must still auto-resolve because it has a single compatible profile.
  - Update runtime/offline tests, staging/package defaults, profile-switcher behavior and public configuration docs accordingly.
  - Do not introduce a hidden/recommended default until a build is explicitly documented as recommended.
- [ ] Audit the profile-resolver diff.
- [ ] Run the complete relevant regression suite.
- [ ] Bump `0.1.0` to `0.1.1`.
- [ ] Build and verify the manual GitHub ZIP.
- [ ] Build and verify the Thunderstore package.
- [ ] Create a new immutable `v0.1.1` Git tag.
- [ ] Publish the GitHub `v0.1.1` release.
- [ ] Publish Thunderstore `0.1.1`.
- [ ] Never move or rewrite the existing `v0.1.0` tag/release.

## 10D.0 — AI disclosure and project provenance

- [ ] Re-check Thunderstore's current AI disclosure requirements before the next release.
- [ ] Check whether the Hades II community exposes an applicable AI-generated category at publish time.
- [ ] Add a clear AI disclosure to the Thunderstore-facing README/package information.
- [ ] Add a matching transparency section to GitHub documentation.
- [ ] State that ChatGPT/Codex substantially assisted with architecture, code generation, review, documentation and testing support.
- [ ] State that requirements, decisions, review and in-game validation are performed/approved by the maintainer.
- [ ] Do not imply that substantially AI-assisted code was written entirely by hand.

## 10D — Public release polish, English-first

- [ ] Make English the default public documentation language.
- [ ] Review and polish the GitHub README.
- [ ] Review the repository description and release text.
- [ ] Review `CHANGELOG.md`.
- [ ] Review installation, update and uninstall documentation.
- [ ] Review Thunderstore description and README content.
- [ ] Document Epic/Thunderstore deployment behavior if the current manager deployment limitation persists.
- [ ] Keep French documentation optional/secondary.

## 10E — Runtime localization

- [ ] Centralize all player-facing strings.
- [ ] Detect the game language.
- [ ] Support English and French first.
- [ ] Use English as the fallback language.
- [ ] Localize rank/status/reason labels and fallback messages.
- [ ] Never localize internal IDs or make scoring/profile selection depend on display text.

## Phase 11 — v0.2 expansion and automation

- [ ] Add more supported builds and Aspects.
- [ ] Define/import additional canonical build data, potentially from the maintainer's build spreadsheet.
- [ ] Keep the pipeline automated: canonical source → JSON → generated Lua profile → registry → tests.
- [ ] Generalize `Generate-BoonAdvisorProfiles.ps1` beyond the current Sister Blades whitelist.
- [ ] Introduce a generic weapon/aspect catalog rather than hardcoded generator validation.
- [ ] Keep runtime profile resolution generic for future weapons.
- [ ] Generate/expand profile-resolution regression tests automatically where practical.
- [ ] Design an explicit policy for multiple profiles that target the same weapon/aspect pair.
- [ ] Strengthen automated validation for duplicate IDs, selection keys, modules and ambiguous profile mappings.

## Later — UI polish

Stability and correctness come first. UI redesign happens after runtime/profile selection is proven stable.

- [ ] Improve placement and hierarchy while preserving the native Hades II choice screen.
- [ ] Improve visual integration with the Hades II style.
- [ ] Review icons, emphasis and color usage where useful.
- [ ] Prevent overlap at different resolutions and localized text lengths.
- [ ] **Show the active build profile discreetly in the in-game UI**, for example:
  - `Profile: Melinoë — Intermediate`
  - `Profile: Morrigan — Meta`
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

Current supported profile intent:

- Sister Blades — Melinoë Starter
- Sister Blades — Melinoë Intermediate
- Sister Blades — Morrigan Meta / Blood Triad
- Other weapon/aspect combinations: unsupported unless explicitly added to the registry and validated.

## Deferred design decisions

These are intentionally not part of the current v0.1.1 hotfix:

- A future explicit `recommended` / default-profile policy for weapon/aspect pairs with multiple builds, only if that recommendation is documented and intentional.
- Lazy-loading/profile caching for a future large profile catalog.
- Multi-weapon generator generalization.
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
