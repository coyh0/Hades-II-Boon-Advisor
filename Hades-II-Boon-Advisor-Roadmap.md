# Hades II Boon Advisor — feuille de route

_Mise à jour : 28 septembre 2026 · [Historique détaillé et jalons terminés](docs/ROADMAP_ARCHIVE.md)_

Cette page sert à savoir ce qui est disponible, ce qui est en essai et ce qu’il faut faire ensuite. Les détails de conception, les anciens jalons et leurs preuves restent dans l’[archive](docs/ROADMAP_ARCHIVE.md).

**Règle de suivi :** actualiser une ligne quand son état franchit une étape vérifiée : code local, installation DEV, tests automatisés, QA humaine, puis publication. Une installation ou des tests automatisés ne valident pas à eux seuls l’affichage en jeu. Garder une seule ligne active par chantier et déplacer les jalons terminés dans l’archive.

## Versions et code

| État | Contenu |
| --- | --- |
| **Publié — v0.2.0** | Trois profils runtime : Sister Blades/Melinoë, Sister Blades/Morrigan et Black Coat/Melinoë. C’est la version publiée sur GitHub et Thunderstore. L’inventaire historique de l’archive compte 14 fichiers. |
| **Candidat local** | Checkout `codex/integration-origin-main`, commit `522d7df3`. Les modifications locales non commitées ajoutent notamment le profil Médée, son sélecteur de route et les libellés de rôle par carte ; le registre liste quatre profils. Glace reste sans score runtime. Ce candidat n’est pas la version publiée. Voir le [registre](data/builds/registry.lua) et les [profils canoniques](data/canonical/profiles/). |
| **Installé en DEV** | Hades II DEV `139606`, mod `0.2.0`. Le candidat local contrôlé est installé dans l’environnement DEV ; inventaire constaté : 18 fichiers. L’installation de Médée ne valide pas automatiquement toutes ses recommandations. |

Les références GitHub n’ont pas pu être actualisées pendant le dernier audit : les comparaisons de branche mentionnées dans l’archive utilisent les références locales en cache.

## Travaux ouverts et ordre de traitement

Les lignes sont classées dans l’ordre conseillé. « QA partielle » décrit seulement les éléments montrés par des preuves humaines ; elle ne signifie pas que tout le profil ou tous les écrans sont validés.

| Sujet | État | Prochaine action | Critère de validation |
| --- | --- | --- | --- |
| **Étape 2 — modèle commun des builds avec/sans routes** | À concevoir après l’audit ; aucune architecture n’est adoptée. Cette étude ne dépend pas des décisions ouvertes sur le seuil 2/3 ou `Support`. Elle doit intégrer la QA Black Coat encore ouverte. | Comparer les contrats existants et proposer les parties réellement communes et celles qui restent propres à chaque build. | Proposition examinée avec limites de migration, compatibilité, modes de repli, tests et validation DEV. Cette étape documentaire n’autorise aucune implémentation. |
| **Black Coat — identité, branches Spécial et QA visuelle** | Le candidat local/DEV fournit le sélecteur en deux étapes et un scoring des offres `AresSpecialBoon` / `ZeusSpecialBoon` conditionné par le focus et la route explicitement choisis. Sans route arrêtée, ces offres restent incomplètes. `SuitSpecialAutoTrait` est évalué avec le focus déclaré « Spécial / roquettes ». Les tests ciblés et la QA humaine fonctionnelle du sélecteur sont consignés dans l’archive. Les prédicats de route natifs ne sont pas établis ; le jeu ne fournit pas, d’après l’audit archivé, de drapeau natif attesté pour ces routes. Au-delà de ces règles implémentées, les autres recommandations du profil restent documentaires ; leur promotion et la fidélité de leurs conditions ne sont pas tranchées. | Refaire un run après sélection explicite de Black Coat et de l’Aspect de Mélinoë. Tester les offres Spécial après déclaration Arès et Zeus ; si possible, vérifier aussi l’offre de Marteau conditionnelle. | Identité du lobby, `BUILD_IDENTITY stage=run_start` et `BuildId` d’offre concordent (`WeaponSuit + BaseSuitAspect`) ; captures avant/après reroll lisibles et journal montrant le comportement pour les choix déclarés. Ne pas présenter ces choix comme des routes détectées nativement. Le journal précédent contient une transition vers Médée, mais les captures ne sont pas horodatées pour l’associer à un segment précis. [Code du sélecteur](src/FocusState.lua), [scoring](src/ScoringEngine.lua), [tests ciblés](tests/focus_spec.lua) et [diagnostic/source historique](docs/ROADMAP_ARCHIVE.md#black-coat-qa-mismatch--evidence-based-diagnosis). |
| **Médée — lisibilité des libellés Zeus / burst** | **QA partielle réussie pour les éléments visibles.** Le Community Curator a examiné les captures complètes avant et après reroll. Le placement route/badge, le bandeau de classement incomplet et le remplacement de la deuxième carte sont lisibles. | Vérifier les infobulles et les états qui ne figurent pas sur les captures. | Captures correspondantes montrant ces éléments sans collision. Ne pas généraliser à d’autres résolutions ou états non photographiés. |
| **Classement incomplet — seuil 2/3** | Décision produit ouverte ; règle actuelle conservée. | Décider si le seuil 2/3 reste la règle générale ou doit évoluer pour tous les profils, avec des exemples inter-profils. | Décision documentée et tests démontrant qu’aucun boon inconnu ne reçoit de rang inventé. Aucun changement propre à Médée. |
| **DATA 132 — Static Shock / Support** | Bloqué côté runtime : l’ID natif `FocusLightningBoon` est confirmé, mais aucune représentation ou règle de score conditionnelle fidèle n’est établie. Il reste documentaire. | Définir d’abord un modèle `Support` fidèle et une condition vérifiable, ou conserver la ligne hors runtime. | Preuve mécanique et représentation testée qui ne l’active ni comme Attaque ni comme Spécial et ne rend pas évaluables les autres lignes Support. [Détails](docs/ROADMAP_ARCHIVE.md#2026-09-27--medea-route-selector-qa-and-data-118-candidate). |
| **Prochain profil runtime** | Périmètre à choisir avec le mainteneur. Les lignes documentaires ne sont pas automatiquement des recommandations runtime. | Choisir un build précis ; vérifier ses sources, IDs natifs et conditions avant toute promotion. | Approbation du contenu, tests d’import/scoring et QA DEV réaliste propres à ce profil. |

Les pistes non prioritaires — sélecteur manuel de profil, conseils de Keepsake/Hex/Familiar, option Chaos Trial et refonte générale de l’UI — restent dans l’[archive](docs/ROADMAP_ARCHIVE.md). Elles ne sont pas des prérequis au tableau ci-dessus.

## Validation : ne pas confondre les preuves

- **Tests automatisés :** le candidat contient des tests de résolution, scoring, focus, UI et import Médée. Le dernier audit documentaire n’a pas relancé la suite complète ; les anciens résultats sont datés dans l’archive.
- **QA humaine :** le comportement du sélecteur Médée et la QA fonctionnelle du sélecteur Black Coat ont été confirmés séparément. La QA visuelle Médée est partielle pour les éléments visibles ; Black Coat attend un run à identité confirmée.
- **Publié / candidat / DEV :** seul `v0.2.0` est une publication. Le code Médée est dans les modifications locales et installé dans DEV, mais son profil complet et la route Glace ne sont pas validés en jeu.

## Où consulter les preuves

- [Audit courant, flux technique et diagnostic Black Coat/Médée](docs/ROADMAP_ARCHIVE.md#current-state-audit--2026-09-27)
- [Historique détaillé de la roadmap](docs/ROADMAP_ARCHIVE.md)
- [Tests d’installation et de QA DEV](docs/RUNTIME_TEST.md)
- [Résolution du profil](src/ProfileResolver.lua), [état focus/route](src/FocusState.lua), [scoring](src/ScoringEngine.lua) et [rendu UI](src/UI.lua)

## Petit glossaire

- **Runtime :** profils et règles réellement chargés par le mod en jeu.
- **DEV :** installation de développement utilisée pour tester sans publier une nouvelle version.
- **QA :** contrôle de qualité ; ici, tests automatisés ou vérification humaine en jeu/captures.
- **Profil documentaire :** recommandations conservées comme référence, sans effet sur le scoring runtime.
- **Support :** catégorie de boon distincte d’Attaque et de Spécial dans les données du mod.
- **Reroll :** relance d’une offre de boons en jeu.
