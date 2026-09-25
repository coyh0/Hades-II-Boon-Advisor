# Audit v0.2 — 25 septembre 2026

Audit des 118 lignes actives du Registry v2 contre `main=dc57eabc45b967bd40bc124f8df13332744cb687`, puis comparaison avec la branche existante `codex/v02-mechanics-showcase`, commit `4a647f607023602a34b1d705a15a39cfbb3bc19d`.

**Conclusion : les cinq deltas sélectionnés sont présents dans la branche et corroborés par le DEV 139606, mais cette branche ne doit pas être fusionnée en l'état : trois fichiers sont corrompus.** Les probes isolées des profils passent ; elles ne remplacent ni la suite complète de la branche ni une validation en jeu.

## Périmètre et décisions reprises

- Brief lu : `Hades-II-Boon-Advisor_Work_Migration_2026-09-25(1).md`, pièce jointe de la tâche « Dev project MOD Hades II ».
- La proposition des cinq ajouts et la réponse du mainteneur « Approuvé » sont présentes dans cette tâche. Les classements Morrigan sont des adaptations stratégiques approuvées, pas une mesure de fréquence des combos.
- v0.2 : recommandations et mécaniques des trois profils existants. Interface compacte après v0.2 ; `keepsakePlan` reste metadata-only.
- Aucun import massif des 118 lignes ; les 260 lignes futures restent hors périmètre.
- Lecture seule du Sheet. Ses statuts documentaires ne sont pas modifiés par cet audit.

## Git et intégrité

Départ : `main=origin/main` local à `1eb5671`, zéro modification suivie, trois patches non suivis. La consultation distante a révélé quatre nouveaux commits sur `main`, exclusivement dans `ROADMAP.md`. Après contrôle du diff, fast-forward à `dc57eab`. La branche showcase a été extraite dans `dist/audit/4a647f6` pour inspection, sans checkout ni fusion.

Les trois patches sont conservés :

| Fichier | SHA-256 |
| --- | --- |
| ares-11C8-review.patch | 397CD0FD06A62EB150D71A6CA59A0F43E39C4D37CDA25DA1682D737C628D8A36 |
| build-discouraged-11C11-review.patch | 6BCF3D9DC3E555CB671F54784F77F5BBBF43399AD5798718D9F6AC13DCC6688A |
| keepsakeplan-11C11-review.patch | EABD625780B358FA5F29FEF7B848805C03CAAB6A0767F66A91AD7B5CB96C013F |

## Matrice des 118 lignes

Source : [Build Registry v2](https://docs.google.com/spreadsheets/d/1hmkyHXxYSpLyLz1bsZ2FIFnb5Qt0Svlve-b1zaX59Tc/edit?gid=2092400260), lecture bornée A1:AW379, puis sélection exacte `releaseScope=v0.2_active_scope`.

La capture locale `v02-registry-source.json` conserve les 49 champs, les numéros de ligne et les fingerprints des 118 recommandations. `v02-registry-matrix.json` conserve la décision, l'ID et sa preuve de nommage, le rôle canonique et la condition documentaire de chaque ligne. La version Markdown est `v02-registry-matrix.md`.

| Disposition | Nombre | Signification |
| --- | ---: | --- |
| Métadonnées Keepsake conservées | 23 | 8 Melinoë, 9 Morrigan, 6 Black Coat ; IDs canoniques, recommendationIds, priorités, classifications et conditions comparés |
| Comportement existant conservé | 31 | Recoupement explicite avec slots, branches, hammerPlan ou règles/interactions existantes ; ne signifie pas validation en jeu de chaque ligne |
| Deltas sélectionnés | 5 | Deux Hammers Morrigan, deux Attack alternatives et un Hammer Black Coat |
| Nouvelles recommandations différées | 19 | Pas de promotion supplémentaire ; certaines offres ont déjà une évaluation générique de slot |
| Guidance documentaire différée | 40 | Arcana, Familiar, Hex et Gameplay ; aucune nouvelle règle exécutable |
| **Total** | **118** | **38 Melinoë + 45 Morrigan + 35 Black Coat**, IDs de recommandation uniques |

Tous les enregistrements source restent `documentation_only`, `documentary_content_approved`, avec vérifications natives `not_reassessed`. Une correspondance de nom dans le texte natif ne valide pas une mécanique. Les noms sans correspondance exacte, dont The Huntress, The Wayward Son et Divinity, restent explicitement non résolus dans cette passe ; aucun ID n'est deviné. Embryo conserve son mapping canonique par recommendationId vers `RandomBlessingKeepsake` (nom natif Transcendent Embryo).

Écarts conservés volontairement :

- Melinoë : Ares documentaire Main est une branche alternative canonique ; sa validité de base reste inconditionnelle. Final Slice documentaire priorité 2 reste ordinal 3 dans le plan existant. Arctic Ring/Grievous Blow recoupent des interactions/règles existantes, sans rendre leurs conditions documentaires exécutables.
- Morrigan : Zeus Special documentaire Main, Ares Alternative et Hephaestus Conditional restent tous `preferred`. Apollo/Aphrodite Special documentaires Unresolved restent `discouraged` dans la base déjà validée ; leur comparaison stratégique n'est pas résolue par cet audit. Blinding Rush Main reste `preferred`.
- Black Coat : Rapid Frame documentaire Alternative reste `priority` ordinal 2 dans la base. Launcher Frame conserve `condition="Special branch"` et une évaluation incomplète. Zeus Special/Cast et les supports non sélectionnés ne sont pas promus.

## Preuves natives des cinq deltas

Racine lue : `D:/Dev/Games/HadesII-Dev/Content`. Version du fichier `Ship/Hades2.exe` relue : **139606**. Aucun lancement du jeu.

| Recommandation | Identité dans Game/Text/en/TraitText.en.sjson | Mécanique dans Scripts/ | Projection sélectionnée |
| --- | --- | --- | --- |
| Phantom Brand | 6433, `DaggerTripleBuffTrait` | `TraitData_Dagger.lua:729` : WeaponDagger et DaggerTripleAspect requis ; `WomboDamageBonusMultiplier` base 2. `WeaponLogic.lua:800,806` ajoute ce bonus au multiplicateur du projectile | Morrigan Hammer priority, ordinal 1 ; intention Blood Triad du profil, aucune fréquence mesurée |
| Final Slice | 6378, `DaggerAttackFinisherTrait` | `TraitData_Dagger.lua:448` : WeaponDagger requis ; multiplicateur base 4 sur WeaponDaggerDouble, rayon ×1.6 ; texte natif : dernière frappe de la séquence | Morrigan Hammer alternative, ordinal 2 ; adaptation approuvée du Main/1 documentaire |
| Flame Strike | 2753, `HestiaWeaponBoon` | `TraitData_Hestia.lua:3,26` : slot Melee, ApplyBurn/BurnEffect sur HeroPrimaryWeapons | Black Coat Attack alternatives ; aucune synergie Scorch ajoutée |
| Heaven Strike | 1776, `ZeusWeaponBoon` | `TraitData_Zeus.lua:3,27` : slot Melee, DamageEchoEffect sur HeroPrimaryWeapons | Black Coat Attack alternatives ; aucun bonus Static Shock ajouté |
| Reaper Frame | 6739, `SuitAttackSizeTrait` | `TraitData_Suit.lua:88` : WeaponSuit requis ; +10 dégâts de base, ProjectileScaleMultiplier +0.4 sur WeaponSuit | Black Coat Hammer alternative, ordinal 3 |

`WeaponSets.lua:40–48` contient WeaponSuit dans HeroPrimaryWeapons. `LootData.lua:285,290,346` référence les trois Hammers dans le pool ; l'audit ne simule pas toutes les règles d'éligibilité de l'offre native. `DaggerFinalHitTrait` est **Wicked Onslaught**, pas Final Slice. Les valeurs natives décrivent les effets du jeu ; elles ne deviennent pas des poids du scorer.

Les conditions de style de jeu sont conservées dans la capture documentaire. Leur absence dans les nouveaux hammerPlan exprime l'adaptation stratégique sélectionnée ; elle ne prétend pas que le runtime sait observer l'usage régulier d'un finisher ou la fréquence des Triads. Launcher Frame n'a pas cette adaptation et reste incomplet.

## Comparaison runtime isolée

`check_v02_runtime.py` exécute le scorer Lua 5.2 sur **55 lignes Boon/Support/Hammer par révision**, offre Common seule, slots vides, aucun trait/Hammer/Arcana possédé. Les autres catégories ne sont pas artificiellement soumises au scorer de Boons. Résultat détaillé : `v02-runtime-comparison.json`.

Exactement cinq différences :

| ID | main | showcase |
| --- | --- | --- |
| HestiaWeaponBoon, Black Coat | −4, conflit de slot | +8, alternative complète |
| ZeusWeaponBoon, Black Coat | −4, conflit de slot | +8, alternative complète |
| SuitAttackSizeTrait | 0, non couvert/incomplet | −3, complet |
| DaggerAttackFinisherTrait, Morrigan | 0, non couvert/incomplet | −2, complet |
| DaggerTripleBuffTrait | 0, non couvert/incomplet | −1, complet |

Le score négatif Hammer est l'ordre de priorité, pas un avis défavorable. Les 50 autres probes sont identiques. Ces probes ne valident pas tous les contextes possibles.

`v02-showcase-scenarios.lua` vérifie en plus : paire Morrigan full, paire + inconnu partial, un seul Hammer connu none ; trois Hammers Coat full ; Launcher Frame incomplet/partial ; Poseidon +12 face aux alternatives +8/+8 ; remplacement de Poseidon par Hestia/Zeus incomplet sans bonus de slot vide ; Ares Melinoë Rare +13 couvert/complet sans Wounds. **PASS** dans l'extraction de la branche.

## Défauts bloquants de la branche existante

1. **[P1] `tests/scoring_spec.lua` ne charge plus.** 24 061 octets, UTF-8 invalide, cinq octets NUL ; `loadfile` Lua 5.2 échoue ligne 1 avec `syntax error near char(170)`. Le diff apparent de ~1 600 suppressions n'est pas un nettoyage de tests acceptable. Restaurer le fichier sain puis réappliquer les tests ciblés.
2. **[P1] `tests/canonical_profiles_spec.ps1` est corrompu.** UTF-8 invalide et neuf NUL ; aucune validation complète de cette branche ne peut être déduite des anciens PASS de main. Restaurer la base saine et adapter seulement les assertions nécessaires aux cinq deltas.
3. **[P1] `ROADMAP.md` est remplacé par un contenu binaire tronqué.** 24 060 octets contre 113 713 dans main, UTF-8 invalide et quatre NUL. Restaurer exactement la roadmap de main ; ne pas auto-clôturer les jalons.

Les SHA-256 de ces blobs sont dans `v02-runtime-comparison.json`. Les quatre fichiers de profils modifiés sont lisibles et portent les cinq deltas attendus. Cela ne rend pas le commit complet intégrable.

## Vérifications effectuées

- PASS : génération de la matrice, cardinalités 38/45/35, unicité, cinq recommendationIds sélectionnés, correspondance des 23 Keepsakes.
- PASS sur main : `tests/canonical_profiles_spec.ps1` sous Windows PowerShell 5.1, avec Python embarqué et DLL DEV explicites ; validation, génération déterministe, équivalence JSON/Lua et suites Lua lancées par le test.
- PASS sur main : `tests/canonical_mechanics_equivalence_spec.ps1`, mêmes dépendances explicites.
- PASS : resolver Lua lors du premier lancement direct ; ce lancement a ensuite refusé le test généré faute de `BOON_CANONICAL_OUTPUT`. Relance correcte via le harness PowerShell ci-dessus : PASS. Le premier refus est un prérequis de harness manquant, pas un succès.
- PASS : 55 probes par révision et scénarios showcase isolés décrits ci-dessus.
- FAIL : chargement du test de scoring de la branche showcase, corruption confirmée.
- Non relancés : installation/update/uninstall, packaging et captures live ; cet audit ne change pas le runtime et ne produit pas de release.

## Suite structurée

1. Réparer la branche existante à partir des trois fichiers sains de main, sans réécrire l'historique ni importer ses blobs corrompus. Conserver les cinq deltas approuvés et les quatre fichiers canoniques/générés correspondants.
2. Ajouter les régressions ciblées au harness normal, comparer les métadonnées Keepsake/autoSignals et les profils non ciblés, relancer canonical/Lua/importers/staging puis la matrice de release adaptée.
3. Formaliser la projection V2→V1 des cinq recommendationIds avec politique native attestée ; la branche actuelle modifie directement les canoniques, elle ne contient pas encore cet artefact de projection. Ne pas changer les statuts du Sheet en bloc.
4. Faire revoir le diff réparé. Tester les nouveaux comportements en DEV avec offres naturelles et logs frais selon l'autorisation applicable ; les cinq ajouts restent **non validés en live par cet audit**. Ne pas répéter le smoke BUILD_DISCOURAGED déjà clos.
5. Actualiser les documents publics et l'invocation updater avant la release ; conserver les gates de version/package/publication. Interface compacte après v0.2.

Livrables de cette passe : documents, snapshots et scripts d'audit seulement. Aucun runtime canonique, scorer, UI, configuration de jeu ou Sheet modifié ; aucun commit, push, déploiement, package de publication, tag ou release.
