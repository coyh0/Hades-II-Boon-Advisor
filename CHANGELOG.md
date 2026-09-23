# Changelog

Tous les changements importants de Hades II Boon Advisor seront documentés ici.

## [0.1.2] - 2026-09-23

### Changed

- Ajout d'une disclosure publique sur l'utilisation substantielle d'OpenAI ChatGPT et Codex pendant le développement.
- Clarification du rôle du mainteneur dans les exigences, décisions, revues et validations en jeu.
- Passage des métadonnées de release de `0.1.1` à `0.1.2`.
- Aucun changement de logique runtime ou de gameplay par rapport au tag `v0.1.1`.

## [0.1.1] - 2026-09-23

### Changed

- `BUILD_PROFILE = "auto"` devient le mode par défaut.
- Résolution automatique du profil selon l'arme, l'Aspect et l'état actuel de la run.
- Les Boons déjà possédés servent de preuve principale lorsque plusieurs profils sont compatibles.
- Les `autoSignals` validés peuvent départager les profils en début de run lorsqu'aucun Boon distinctif n'est encore possédé.
- Les sélections explicites `starter`, `intermediate` et `morrigan_meta` restent disponibles comme overrides.

### Fixed

- Suppression du profil Melinoë Intermediate implicite qui pouvait être appliqué à un autre Aspect.
- Résolution automatique correcte du profil Morrigan.
- Un profil compatible mais indéterminé affiche désormais `PROFIL À CHOISIR` au lieu de `PROFIL NON PRIS EN CHARGE`.
- Les armes et Aspects réellement non supportés conservent `PROFIL NON PRIS EN CHARGE`.
- La résolution automatique peut sortir de l'état ambigu plus tard dans la même run dès que les Boons possédés permettent d'identifier un profil sans ambiguïté.

## [0.1.0] - 2026-09-23

### Added

- Détection des offres de Boons olympiens.
- Lecture de l'état actuel de la run.
- Moteur de scoring explicable.
- Interface intégrée à l'écran de sélection des Boons.
- Support des profils Sister Blades / Aspect of Melinoë.
- Support du profil Sister Blades / Aspect of Morrigan.
- Gestion des statuts et d'Origination.
- Règles conditionnelles `requiresAnyOwned` et `requiresAllOwned`.
- Données canoniques JSON et génération déterministe des profils Lua.
- Suite de tests Lua 5.2.
- Validation PowerShell 5.1.
- Tests d'équivalence canonical/runtime.
- Validation du staging et du changement de profil.
- UI polish : hiérarchie visuelle, états d'analyse, raisons compactes et cas limites.
- Compatibility Gate : validation du patch Hades II, des ancres critiques et de la cohérence interne du projet.
