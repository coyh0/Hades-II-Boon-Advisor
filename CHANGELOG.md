# Changelog

All notable changes to Hades II Boon Advisor are documented here.

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
