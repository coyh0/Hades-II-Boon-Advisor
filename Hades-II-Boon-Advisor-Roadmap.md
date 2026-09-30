# Hades II Boon Advisor — Roadmap

_Last updated: 2026-10-01_

This file governs current status, active work, dependencies, deferred work,
and Human Gates. The [archive](docs/history/ROADMAP_ARCHIVE.md) preserves
completed phases, QA evidence, and earlier decisions. The
[roadmap change log](docs/ROADMAP_CHANGELOG.md) records planning changes.
Neither historical file authorizes new work.

## Current status

- **Published baseline:** v0.2.0 (2026-09-26).
- **Active development builds:** reviewed Mobalytics Medea and Moonstone Axe.
  The development registry contains only these two builds; published v0.2.0
  profiles are historical release content.
- **Build policy:** each imported build explicitly defines its Core and
  Non-Core Boons. The active imported build determines the applicable profile.
  No in-run Focus or Route selection is planned. `BUILD_PROFILE` remains
  a separate technical configuration setting.
- **QA access:** all weapons and regular Aspects are available. Morrigan is
  the only hidden Aspect currently reported unlocked. Await maintainer
  confirmation before planning QA with another hidden Aspect.
- **Current gate:** R-01 maintainer runtime QA for the Focus/Route and Black
  Coat cleanup, using the already hash-verified QA installation. The
  [R-01 checklist](docs/qa/QA_Runtime_Etape-A_R-01_Cleanup.md) is ready;
  runtime QA has not started. Deployment verification is not a gameplay QA
  result.
- **GitHub branches:** `main` remains the canonical public branch and
  `codex/v02-mechanics-showcase` remains the active work branch. Their
  divergence is a separate, unresolved matter outside R-00.

## Active roadmap

| ID | Work item | Status | Next action | Dependency / blocker | Human gate |
|---|---|---|---|---|---|
| R-00 | Public repository organization audit and proposal | Complete | None for R-00; the approved GitHub branch cleanup is complete | None; `codex/integration-origin-main`, `codex/roadmap-docs-2026-09-28`, and `codex/medea-runtime-pilot-qa` were deleted from GitHub. The divergence between `main` and `codex/v02-mechanics-showcase` remains unresolved outside R-00 | R-00 closure approved by the maintainer; subsequent work follows `AGENTS.md` |
| R-01 | Cleanup runtime QA | Awaiting maintainer QA | Complete the existing [QA_Runtime_Etape-A_R-01_Cleanup.md](docs/qa/QA_Runtime_Etape-A_R-01_Cleanup.md) | R-00 complete; use the already verified QA installation; redeploy only if source payload changes | Maintainer performs gameplay QA; MAIN may request read-only QA Manager analysis within approved scope |
| R-02 | Legacy Focus UI cleanup | Deferred until R-01 review | Review `UI.clearFocus` and its two call sites; propose their removal if R-01 confirms the old UI is absent | R-01 results; preserve generic build handling and the profile-retirement restore point | Approve the exact code change, offline validation scope, and any later DEV gate separately |
| R-03 | Shared native boon catalog and game-update workflow | Deferred / Contract pending | Define the full native boon inventory, version and file-hash checks, rescan/diff process, and reviewed catalog-update contract | R-02 review; existing attestation catalog covers only selected native facts; Curator data exchange remains a separate interface | Approve the contract, implementation scope, and any catalog promotion at separate Human Gates |
| R-04 | Select the first 10 Mobalytics builds and define the Excel import contract | Deferred / Contract pending | Select the first 10 builds with the maintainer; define the workbook schema, validation, and mapping to reviewed build profiles | R-03 native catalog workflow; formatted Mobalytics workbook and reviewed source evidence | Approve the 10-build selection and import contract; contract approval does not authorize implementation or advancement to the next step |
| R-05 | Implement Excel import and import the first 10 builds | Deferred until R-04 contract review | After separate implementation approval, import the approved first batch; manually review each build | Approved R-04 contract and implementation scope; exact native IDs, provenance, and per-build conditions | Approve implementation separately; approve each build before runtime promotion |
| R-06 | Prepare public release 0.3 | Deferred | Complete release preparation under the active [release rules](docs/RELEASE.md) | R-05 complete; package and supported-build set reviewed | Complete quick QA and maintainer human validation for the 0.3 candidate; approve release actions separately |
| R-07 | Import remaining Mobalytics builds | Deferred until 0.3 gate | After separate scope approval, use the approved Excel import to import the remaining selected builds; manually review each build | 0.3 release gate complete; approved R-04 contract and R-05 implementation; reviewed source evidence, exact native IDs, and per-build conditions | Approve the remaining batch and each build separately before implementation or runtime promotion |
| R-08 | Prepare public release 0.4 | Deferred | Complete release preparation under the active [release rules](docs/RELEASE.md) | R-07 complete; package and supported-build set reviewed | Complete quick QA and maintainer human validation for the 0.4 candidate; approve release actions separately |
| R-09 | Configure JSON import and export for Curator | Deferred / Contract pending | Define separate export and import contracts; after their approval, propose implementation scope for each | R-03 native catalog contract; Curator interface, data ownership, payload schemas, validation, provenance, and profile-promotion boundaries | Approve each contract, then separately approve its implementation; contract approval does not authorize implementation or advancement to the next step |
| R-10 | Prepare public release 0.5 | Deferred | Complete release preparation under the active [release rules](docs/RELEASE.md) | R-09 implementations and offline validation complete; package and supported-build set reviewed | Complete quick QA and maintainer human validation for the 0.5 candidate; approve release actions separately |
| R-11 | UI polish | Deferred until 0.5 gate | After the 0.5 release gate, propose a concrete UX/UI scope and, after its review, a separate implementation plan | 0.5 release gate complete; implementation remains subject to its own approval | Approve the UX/UI scope and implementation separately; neither approval is automatic |
| R-12 | Prepare public release 0.6 | Deferred | Complete release preparation under the active [release rules](docs/RELEASE.md) | R-11 implementation and offline validation complete; package and supported-build set reviewed | Complete quick QA and maintainer human validation for the 0.6 candidate; approve release actions separately |

The formatted Mobalytics workbook is the planned import interface for both
build batches: the first 10 builds precede release 0.3, and the remaining
selected builds precede release 0.4. Each build still requires manual review
and separate approval. The Excel import contract must be approved before its
implementation scope is considered; approving the contract does not authorize
implementation, build promotion, release, or advancement past a later Human
Gate. Curator JSON export and import are separate interfaces with separate
contracts and implementation approvals. The existing Build Registry JSON
validator does not read the Excel workbook or automatically promote Curator
data into a runtime profile.

## Deferred work

These topics have no implementation approval. Review scope and dependencies
with the maintainer before promoting any of them into the active roadmap.

| Topic | Current disposition | Revisit condition |
|---|---|---|
| Additional builds beyond the planned Mobalytics batches | Deferred; documentary data is not runtime support | Review each proposed build manually after the planned batches, including source recommendations, exact native IDs, unresolved conditions, and profile-specific QA; require separate approval before any build is approved or promoted |
| Build guidance beyond immediate Boon ranking | Deferred | Define a useful informational scope; resolve Legendary/Duo prerequisites before executable guidance |
| Keepsake setup guidance, Hex, and Familiar | Deferred | Demonstrate a useful, non-Arcana use case and obtain a separate scope approval |
| Chaos Trial opt-out | Deferred / To be classified | Decide whether reliable native mode detection and a user benefit justify a separate feature |
| Large UI redesign | Deferred / To be classified | Decide whether it is needed beyond the separately deferred UI polish |
| Optimize profile catalog cache if a massive import (40 or more additional profiles) is planned | Deferred | Define a concrete need and separate implementation scope |

## Standing constraints and references

- `AGENTS.md` is canonical for project boundaries, roles, delegation,
  language, and Human Gates. Do not advance automatically after a gate.
- Follow [Build Registry import rules](docs/Contracts/BUILD_REGISTRY_IMPORT_CONTRACT.md),
  related canonical-data contracts, and deterministic generation. Imported
  recommendations require reviewed provenance and exact native IDs before
  runtime promotion. Keep Mobalytics scoring specific to Mobalytics rows.
- Follow [release rules](docs/RELEASE.md) for future GitHub and Thunderstore
  releases. A public release requires a separate approval gate.
- The [archive](docs/history/ROADMAP_ARCHIVE.md) retains completed phases,
  QA evidence, retired Focus/Route and Black Coat decisions, old proposals,
  runtime facts, and former Git Health Check details. It is historical only.
- The [roadmap change log](docs/ROADMAP_CHANGELOG.md) records planning and
  governance changes. `CHANGELOG.md` remains the mod release changelog.
