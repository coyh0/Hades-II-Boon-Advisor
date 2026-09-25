# Changelog

All notable changes to Hades II Boon Advisor are documented here.

## [0.2.0] - 2026-09-25

### Added

- Added validated Intermediate Sister Blades Melinoë, Morrigan Meta and Black Coat Melinoë profiles.
- Added explainable Hammer recommendations for the approved v0.2 showcase.
- Added safe full, partial and none ranking states when offered choices are not fully covered.
- Added metadata-only four-phase Keepsake plans for the three active profiles.
- Added canonical profile generation, Registry projection checks and strict mechanics equivalence tests.
- Added transactional install, update, rollback, uninstall and package validation tooling.
- Added human-controlled DEV validation evidence and release-grade offline regression coverage.

### Changed

- Expanded automatic profile resolution across weapon, Aspect and owned-run evidence, with safe ambiguity and unsupported fallbacks.
- Added explainable slot conflicts, replacement handling, aspect interactions, Hammer priorities and conservative status/Origination coverage.
- Added French and English labels for ranking states, incomplete analysis, conflicts, build reasons and discouraged recommendations.
- Reconciled the 118-row v0.2 Registry audit against canonical profiles and verified runtime identifiers; documentary conditions remain non-executable.
- Updated public documentation and runtime testing guidance to distinguish published v0.1.2 behavior from the unreleased v0.2 candidate.

### Fixed

- Corrected base Ares Attack evaluation so it does not depend on Grievous Blow or an unproven Wounds branch.
- Preserved unknown choices as unevaluated instead of assigning speculative ranks or scores.
- Fixed negative build recommendations being shown with the same positive label as core/build reasons.

### Notes

- The compact build-status interface, Duos, Hermes and Poms guidance remain future work.
- This candidate does not change gameplay, RNG, offers, damage, saves or player choice.

## [0.1.2] - 2026-09-23

### Changed

- Added a public disclosure of substantial OpenAI ChatGPT and Codex assistance during development.
- Clarified the maintainer's role in requirements, decisions, reviews, and in-game validation.
- Updated release metadata from `0.1.1` to `0.1.2`.
- No runtime logic or gameplay changes relative to tag `v0.1.1`.

## [0.1.1] - 2026-09-23

### Changed

- `BUILD_PROFILE = "auto"` became the default mode.
- Automatic profile resolution uses the weapon, Aspect, and current run state.
- Owned Boons are the primary evidence when multiple profiles are compatible.
- Validated `autoSignals` can distinguish profiles at the start of a run before a distinctive Boon is owned.
- Explicit `starter`, `intermediate`, and `morrigan_meta` selections remain available as overrides.

### Fixed

- Removed the implicit Melinoë Intermediate profile that could be applied to another Aspect.
- Fixed automatic resolution of the Morrigan profile.
- A compatible but unresolved profile now shows `PROFIL À CHOISIR` instead of `PROFIL NON PRIS EN CHARGE`.
- Truly unsupported weapons and Aspects continue to show `PROFIL NON PRIS EN CHARGE`.
- Automatic resolution can leave ambiguity later in a run once owned Boons identify a profile uniquely.

## [0.1.0] - 2026-09-23

### Added

- Detection of Olympian Boon choices.
- Read-only current-run state capture.
- Explainable scoring engine.
- User interface on the Boon choice screen.
- Sister Blades / Aspect of Melinoë profiles.
- Sister Blades / Aspect of Morrigan profile.
- Status and Origination handling.
- Conditional `requiresAnyOwned` and `requiresAllOwned` rules.
- Canonical JSON data and deterministic Lua profile generation.
- Lua 5.2 test suite.
- Windows PowerShell 5.1 validation.
- Canonical/runtime equivalence tests.
- Staging and profile-switch validation.
- UI polish: visual hierarchy, analysis states, compact reasons, and edge cases.
- Compatibility Gate: Hades II patch validation, critical anchors, and internal project consistency.
