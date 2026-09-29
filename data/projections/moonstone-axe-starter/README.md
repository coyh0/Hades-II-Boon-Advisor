# Moonstone Axe Starter Build import pilot

Source: [Mobalytics Moonstone Axe Starter Build](https://mobalytics.gg/hades-2/builds/moonstone-axe-starter-build), approved by the maintainer. The local catalog workbook records this as `axe_melinoe` and provides stable recommendation IDs. `source-recommendations.json` preserves all 52 reviewed source rows for traceability. Names identified from the Mobalytics CDN asset filenames do not require a further tooltip check under the maintainer's review decision.

`rows.json` selects the 14 approved runtime candidates: five Core Boons, six Non-Core Boons, and three offerings. `policy.json` is the separate locally verified ID/category/role and source/boon attestation. `plan.json` is the importer's deterministic result. The canonical profile and mechanics template project those candidates, the four God Pool gods, and the three listed Core Poms. The five Core roles include Attack, Special, Cast, Sprint, and Mana. The existing missing-Core notice remains limited to Attack/Special/Cast; this import does not change the alert policy.

The two listed Hammers have no attested individual priority, so they have no active `hammerPlan` or source score. Hermes, Duo/Legendary, Arcana, Keepsakes, Familiar, and Hex recommendations stay documentary. Source conditions remain descriptive text and create no runtime branch. This pilot does not infer an order among recommendations beyond their explicit Core/Non-Core categories.

The God Pool lists Apollo, Demeter, Hephaestus, and Poseidon as build recommendations. It is informational and independent from scoring. Artemis `InsideCastCritBoon` requires `NPC_Artemis_Field_01`; Chaos Strike and Soul require `TrialUpgrade`. Mismatched pairs must be refused by both import validation and runtime scoring.

The repository profile is for offline validation. DEV deployment and runtime QA remain behind the maintainer's explicit approval gate. The legacy builds and existing local patches remain untouched pending the later backup and cleanup gates.
