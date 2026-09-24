# Hades II Boon Advisor — Audit technique

Date : 20 septembre 2026. Les sections 1–9 conservent l'audit initial. **Mise à jour Phase 0.5 / sonde Phase 1 : voir section 10**, qui remplace les inconnues désormais résolues. Aucun jeu lancé, aucun mod installé dans le jeu, aucun scoring implémenté.

**Conclusion : les scripts locaux permettent d'identifier précisément les offres et l'état de la run. Le candidat recommandé est un wrapper après `CreateBoonLootButtons`, qui observe les options après leur tri et la construction des boutons. La disponibilité de Hell2Modding/ModUtil en exécution reste UNVERIFIED.**

Niveaux de preuve utilisés :

- **LOCAL CONFIRMED** : définition ou utilisation directement lue dans la copie de développement. Ne signifie pas testé en jeu.
- **UPSTREAM CONFIRMED** : source publique consultée à la révision indiquée. Ne signifie pas installé ni compatible avec cette copie.
- **PROPOSED** : choix de conception du futur mod, pas une API du jeu.
- **UNVERIFIED** : information non établie ; méthode de vérification indiquée.

Les chemins `Scripts/...` ci-dessous sont relatifs à `<development-game-root>\Content\`. Les numéros de ligne correspondent aux fichiers audités, pas nécessairement à une prochaine mise à jour.

## 1. Environment discovered

| Élément | Observation réelle |
| --- | --- |
| Repository | `<repository-root>` ; uniquement `.git` au début de l'audit ; branche `master`, sans commit |
| Copie de développement | `<development-game-root>` ; dossiers `Content`, `Ship`, `Release`, `.egstore` |
| Scripts | `<development-game-root>\Content\Scripts` ; sources Lua lisibles |
| Exécutable inspecté | `<development-game-root>\Ship\Hades2.exe` ; métadonnées FileVersion/ProductVersion : `139606` |
| Installation Epic protégée | `<production-game-root>`, identifiée par le manifeste Epic ; `AppVersionString = 139652-Win`. Aucune écriture ni installation effectuée dans ce dossier |
| Autres dossiers trouvés | `D:\Games\Hades II` et `E:\Games\Hades 2` ; contenu/version/rôle non audités. Ne pas les assimiler à la copie de développement |
| Outils disponibles | PowerShell, Git, `rg` ; `lua`/`luajit` non trouvés dans PATH. `Ship\lua52.dll` existe mais ne constitue pas un interpréteur CLI testé |
| Hell2Modding local | Aucun `d3d12.dll`, dossier `ReturnOfModding` ou fichier de plugin trouvé dans l'arborescence de développement inspectée |
| ModUtil et mods locaux | Aucun trouvé dans cette copie. Aucun dossier dont le nom correspond à r2modman/Thunderstore/modman au premier niveau des AppData Local/Roaming inspectés ; cela n'exclut pas une installation personnalisée ailleurs |
| Localisation | `Content\Game\Text\en\TraitText.en.sjson` et `Content\Game\Text\fr\TraitText.fr.sjson` présents |
| Instructions locales | Aucun `AGENTS.md` trouvé dans le repository, les parents inspectés ou la copie de développement |

Les dossiers racine de la copie, `Content`, `Content\Scripts` et `Ship` n'indiquent pas de jonction/lien dans les métadonnées inspectées. L'absence de hardlinks fichier par fichier n'a pas été vérifiée ; aucune modification de fichiers du jeu n'est nécessaire pour cet audit.

Les versions déclarées par le manifeste Epic et par l'exécutable de développement sont deux observations distinctes : **ne pas conclure que les scripts des deux installations sont identiques**. Les conclusions locales concernent exclusivement la copie de développement.

### Références publiques effectivement consultées

Sources téléchargées comme texte dans `<temporary-audit-directory>`, sans exécution ni copie dans le jeu. Les liens figés ci-dessous permettent de retrouver les preuves si ce dossier temporaire disparaît.

| Référence | Révision consultée | Fichiers utiles |
| --- | --- | --- |
| [Improved Boon Info UI](https://github.com/SMarechalBE/Hades-2-Improved-Boon-Info-UI/tree/13eb043a736707c54366b19ce20eec0825677f0b) | `13eb043a736707c54366b19ce20eec0825677f0b` | `src/main.lua`, `src/ready.lua`, `src/reload.lua`, `thunderstore.toml` |
| [Run Boon Overview](https://github.com/SMarechalBE/Hades-2-Run-Boon-Overview/tree/5c9a67ebb0c25fe10b189c678793e40356efc0c5) | `5c9a67ebb0c25fe10b189c678793e40356efc0c5` | mêmes fichiers, plus `src/ordering.lua` |
| [ModUtil](https://github.com/SGG-Modding/ModUtil/tree/3ee4392d6580fe3cbc45b7d8eeba67d978511552) | `3ee4392d6580fe3cbc45b7d8eeba67d978511552` | `src/main.lua`, `src/def_mod.lua`, manifeste |
| [Hell2Modding](https://github.com/SGG-Modding/Hell2Modding/tree/d0fd25ceec6ab614f33f9506568908b76e39d944) | `d0fd25ceec6ab614f33f9506568908b76e39d944` | documentation `docs/lua/tables/rom.on_import.md`, `rom.log.md`, `rom.game.md` |
| [Hades2ModWiki](https://github.com/SGG-Modding/Hades2ModWiki/tree/2345a1b32f073acf89fb6952ffe8383a94566172) | `2345a1b32f073acf89fb6952ffe8383a94566172` | `docs/creating-mods/development-environment.md`, `first-mod-guide/1-mod-template.md` |

Les manifestes des deux mods déclarent Hell2Modding `1.0.87` et ModUtil `4.0.1` comme dépendances, avec ENVY, Chalk et d'autres dépendances. Ce ne sont ni des versions installées ici ni une validation de compatibilité. Le manifeste du dépôt ModUtil déclare lui-même des dépendances plus anciennes et un autre identifiant ENVY : ne pas assembler une stack en recopiant ces fichiers sans contrôler les packages réellement retenus.

## 2. Boon choice flow

### Flux normal confirmé localement

```text
BaseLoot.OnUsedFunctionName = "UseLoot"
  → UseLoot(usee, args, user)
  → HandleLootPickup(CurrentRun, usee, args)
  → OpenUpgradeChoiceMenu(loot, args)
  → CreateBoonLootButtons(screen, source, nil, args)
      → SetTraitsOnLoot(lootData) si les options doivent être générées
      → calcul des indices bloqués et tri des options
      → CreateUpgradeChoiceButton(screen, lootData, itemIndex, itemData, args)
  → HandleScreenInput(screen)
```

| Fonction / déclaration | Source locale et lignes | Rôle et certitude |
| --- | --- | --- |
| `BaseLoot.OnUsedFunctionName` | `Scripts/LootData.lua:10–23` | Déclare `UseLoot` comme gestionnaire ; LOCAL CONFIRMED |
| `UseLoot(usee, args, user)` | `Scripts/InteractLogic.lua:621–690`, appel à 676 | Vérifie l'interaction, gère l'achat éventuel, appelle le pickup ; LOCAL CONFIRMED |
| `HandleLootPickup(currentRun, loot, args)` | `Scripts/InteractLogic.lua:693–739`, appel à 733 | Présentations et historique, puis ouverture ; LOCAL CONFIRMED |
| `OpenUpgradeChoiceMenu(source, args)` | `Scripts/UpgradeChoiceLogic.lua:2–111` | Copie `ScreenData.UpgradeChoice`, affecte `screen.Source` et `ScreenAnchors.ChoiceScreen` (27–28), construit l'écran, appelle les boutons (104), puis l'entrée utilisateur (109) ; LOCAL CONFIRMED |
| `CreateBoonLootButtons(screen, lootData, reroll, args)` | `Scripts/UpgradeChoiceLogic.lua:113–278` | Prépare les offres si absentes, fallback, blocages, tri, boutons ; LOCAL CONFIRMED |
| `SetTraitsOnLoot(lootData, args)` | `Scripts/TraitLogic.lua:1760–2002` | Génère les offres et leurs raretés, écrit `lootData.UpgradeOptions` ; LOCAL CONFIRMED, fonction avec effets de bord et RNG |
| `CreateUpgradeChoiceButton(screen, lootData, itemIndex, itemData, args)` | `Scripts/UpgradeChoiceLogic.lua:280–673` | Transforme une option en bouton, textes et tooltip ; retourne le bouton (672) ; LOCAL CONFIRMED |
| `HandleScreenInput(screen)` | `Scripts/UILogic.lua:883–885` et suite | Boucle tant que `screen.KeepOpen` ; LOCAL CONFIRMED |
| `RerollBoonLoot(screen, button)` | `Scripts/UpgradeChoiceLogic.lua:707–718` | Détruit les boutons, régénère les offres, rappelle `CreateBoonLootButtons(..., true)` ; LOCAL CONFIRMED |
| `TryUpgradeBoon(lootData, screen, button)` | `Scripts/UpgradeChoiceLogic.lua:1271–1327` | Peut changer la rareté et recréer un seul bouton ; LOCAL CONFIRMED |
| `CloseUpgradeChoiceScreen(screen, button)` | `Scripts/UpgradeChoiceLogic.lua:1073–1099` et suite | Ferme les composants de l'écran ; LOCAL CONFIRMED |

`OpenUpgradeChoiceMenu` est aussi appelé par des événements dans `Scripts/EventLogic.lua` (954, 1004, 1055, 1107, 1190, 1243, 1624). Il ne désigne donc pas exclusivement une bénédiction olympienne. Le MVP devra filtrer la source et les types d'options.

**Pièges importants :**

- Un wrapper qui attend le retour de `OpenUpgradeChoiceMenu` risque d'observer l'écran après sa fermeture : cette fonction entre dans la boucle d'entrée. Préférer le retour de `CreateBoonLootButtons`.
- Avant `CreateBoonLootButtons`, les offres peuvent encore être absentes ou révisées. À l'intérieur, `table.sort(upgradeOptions, ...)` fixe l'ordre visuel (165–185).
- Le jeu emploie de la RNG jusque dans la construction des boutons, notamment `UpgradeChoiceLogic.lua:299–305`. Ne jamais réappeler ces fonctions pour obtenir un aperçu ou un score.
- `OpenUpgradeChoiceMenu` invalide normalement un checkpoint (ligne 9). Le mod doit laisser l'appel original suivre son cours une seule fois ; il ne doit ni reproduire ni neutraliser ce comportement.

## 3. Offered boon structure

### Structure prouvée, sans fausse capture de run

Extrait minimal réel du constructeur, `Scripts/TraitLogic.lua:1841` :

```lua
table.insert( upgradeOptions, { ItemName = traitName, Type = "Trait", Rarity = rarity })
```

La même fonction affecte cette liste à `lootData.UpgradeOptions` à la ligne 2001. `traitName` et `rarity` sont ici les variables du jeu, pas des identifiants inventés. Aucun triplet d'offres de run n'a été capturé pendant cet audit.

| Champ / accès | Sens confirmé et preuve |
| --- | --- |
| `lootData.UpgradeOptions[i].ItemName` | ID interne du trait proposé ; consommé par `GetProcessedTraitData` à `UpgradeChoiceLogic.lua:294` |
| `.Type` | Type de proposition ; `"Trait"` confirmé ci-dessus. `"TransformingTrait"` est traité séparément à 350–354 |
| `.Rarity` | Rareté proposée ; passée au traitement à 294, utilisée pour le texte à 531–535 |
| `.TraitToReplace`, `.OldRarity` | Remplacement explicitement représenté ; construction à `UpgradeChoiceLogic.lua:817`, utilisation à 320–331 |
| `.SecondaryItemName` | Deuxième trait des offres transformantes (Chaos), utilisé à 352 ; hors MVP initial |
| `.StackNum` | Nombre de niveaux utilisé dans certaines offres ; 296–298, 1313 |
| `.Blocked` | Mis à `true` pour un indice bloqué à 441–447 ; ne pas l'interpréter isolément comme un booléen toujours frais |
| `screen.BlockedIndexes` | Liste des indices bloqués pour la construction courante ; 153–162 |
| `screen.Components["PurchaseButton" .. i]` | Bouton actuellement enregistré pour cette position ; 407–421 |
| `button.Data.Name`, `button.Data.Rarity` | Trait traité affecté à `button.Data` à 504 ; différent de l'option brute, particulièrement pour Chaos |
| `button.Index`, `button.LootData`, `button.UpgradeName` | Position et source associées ; 505–514 |
| `screen.UpgradeButtons` | Liste des boutons, initialisée à 190 et remplie à 203 ; mise à jour d'un bouton rarifié à 1322–1323 |

### Lire les options effectivement présentées

PROPOSED : après l'appel original à `CreateBoonLootButtons`, parcourir `lootData.UpgradeOptions` dans son ordre courant avec les indices réels. Pour chaque indice, vérifier l'existence de `screen.Components["PurchaseButton" .. i]`, copier l'ID et la rareté en valeurs scalaires, et noter séparément si l'indice figure dans `screen.BlockedIndexes`. Comparer aux données du bouton pour diagnostiquer une divergence ; en cas d'incohérence, ne pas recommander.

`ScreenData.UpgradeChoice.MaxChoices = 3` est confirmé dans `Scripts/UpgradeChoiceData.lua:24`. Mais **ne pas imposer trois choix valides** : `CalcNumLootChoices` (`TraitLogic.lua:1746–1753`) peut réduire le nombre sélectionnable ; la génération peut fournir moins d'options ; `FallbackGold` est inséré si la liste est vide (`UpgradeChoiceLogic.lua:149–150`). Les options bloquées peuvent rester représentées par un bouton, sans être sélectionnables. Ne pas les classer comme choix disponibles ni révéler un contenu masqué dans l'UI future.

L'ordre et les indices du jeu doivent rester inchangés. Un classement futur triera exclusivement une copie détenue par le mod et conservera la position d'origine.

### Dieu offrant et rareté

- **Source offrant réellement le choix :** `lootData.Name`, ou `screen.Source.Name` (affectation à 27). Exemple confirmé : `AphroditeUpgrade`, défini dans `Scripts/LootData_Aphrodite.lua:4–21`, avec `GodLoot = true`. Le nom affiché n'est pas nécessaire à l'identification.
- **Origine d'un trait :** `GetLootSourceName(traitName, args)` (`TraitLogic.lua:1576–1598`) parcourt les index des loots et peut consulter `TraitData[traitName].LootSource`. Cela n'est pas interchangeable avec la source de l'écran, notamment pour un Duo ou un événement. `GetAllLootSourceNames` existe à 1599 et suite pour les sources multiples.
- **Rareté :** conserver la valeur de l'option après construction, ainsi que celle du bouton si utile au diagnostic. Le rendu utilise `Common` lorsque l'option n'a pas de rareté (531–535) ; distinguer dans le diagnostic une valeur absente d'une valeur explicitement `Common`.
- `TryUpgradeBoon` modifie `.Rarity` à 1283 et recrée le bouton à 1314. Un hook uniquement sur `CreateBoonLootButtons` ne couvrira pas cette actualisation ; l'ajouter avant toute recommandation persistante en UI.

## 4. Player run state

Toutes les méthodes ci-dessous sont confirmées **dans les sources**, pas observées dans une session vivante. Vérifier l'existence de chaque table avant lecture ; une donnée absente signifie « inconnue », pas « aucun boon » ou « aspect par défaut ».

| Information | Méthode de lecture recommandée | Preuve locale |
| --- | --- | --- |
| Arme principale | `GetEquippedWeapon()` ; parcourt `WeaponSets.HeroPrimaryWeapons` et teste `CurrentRun.Hero.Weapons[weaponName]` | `WeaponUpgradeLogic.lua:363–369` ; fonction de lecture sans écriture dans ce corps |
| Traits possédés | Lire `CurrentRun.Hero.Traits`, copier `trait.Name`, `trait.Rarity`, `trait.StackNum`, `trait.Slot` si présents | `TraitLogic.lua:662–682` ; accès aux niveaux/raretés aussi dans `UpgradeChoiceLogic.lua:341–349` |
| Recherche par ID | `CurrentRun.Hero.TraitDictionary[id]` est une liste de traits, pas un unique trait ni un booléen | `TraitLogic.lua:663–682` ; `GetHeroTrait` à 495–502 renvoie son premier élément ; `HeroHasTrait` à 505 et suite |
| Slots occupés | `CurrentRun.Hero.SlottedTraits[slot]` contient un nom interne | Construction `TraitLogic.lua:666–667`, publication à 741 |
| Aspect courant | Lire `CurrentRun.Hero.SlottedTraits.Aspect`, recouper avec les traits possédés `IsWeaponEnchantment` et l'arme | `TraitData.lua:1079–1085` définit `Slot = "Aspect"`, `IsWeaponEnchantment = true` ; `WeaponUpgradeLogic.lua:406–408` utilise ce marqueur |
| Hammers possédés | Parcourir les traits courants et tester `LootData.WeaponUpgrade.TraitIndex[trait.Name]` | Exactement le filtre de `TraitLogic.lua:2579–2585` ; lire ce filtre, ne pas appeler `ChaosHammerUpgrade` |
| Bénédictions divines | Parmi les traits, classification via `IsGodTrait(trait.Name)` si les tables sont prêtes | `TraitLogic.lua:1547–1560` ; ne pas assimiler tous les traits à des boons |

`GameState.LastWeaponUpgradeName[currentWeaponName]` est lu à `WeaponUpgradeLogic.lua:433` pour équiper l'aspect. C'est une sélection persistante utilisée à l'équipement, donc une vérification secondaire, pas un substitut automatique au trait réellement porté. Ne jamais appeler `EquipWeaponUpgrade`, `AddTraitToHero` ou `UpdateHeroTraitDictionary` pour « lire » l'état : ces fonctions le modifient.

### Identifiants du seul profil MVP

| Concept | ID vérifié | Preuve |
| --- | --- | --- |
| Sister Blades | `WeaponDagger` | `Content/Game/Text/en/TraitText.en.sjson:6860–6862` associe explicitement ID et DisplayName |
| Aspect of Melinoë des Sister Blades | `DaggerBackstabAspect` | Même fichier : 7156–7159 ; `Scripts/TraitData_Aspect.lua:874–878` associe ce trait à `WeaponDagger` |

`Scripts/WeaponUpgradeData.lua:42–66` confirme cet aspect dans `FreeUnlocks` et `DisplayOrder` de `ScreenData.WeaponUpgradeScreen`. Ces listes ne prouvent pas qu'il est actuellement équipé.

Cas important : si aucun aspect n'est sélectionné, `EquipWeaponUpgrade` peut ajouter un trait factice (433–441). `Scripts/WeaponData_Dagger.lua:21` identifie `DummyWeaponDagger`, défini dans `TraitData.lua:1351–1358`. **UNVERIFIED :** équivalence pratique de cet état initial avec le profil Melinoë souhaité. Ne pas activer le profil par défaut sur la seule présence de l'arme ; vérifier ce cas en jeu.

Les Hammers sont des traits ; leur liste de référence est dans `LootData.WeaponUpgrade`, pas un champ de run supposé `HammerUpgrades`. Garder leurs éventuels `RemainingUses` pour distinguer les traits temporaires. Le filtre des Hammers ci-dessus est indépendant du nom traduit.

## 5. Hook candidates

### Mécanismes réellement documentés / implémentés en amont

- [ModUtil `src/def_mod.lua:2407–2409`](https://github.com/SGG-Modding/ModUtil/blob/3ee4392d6580fe3cbc45b7d8eeba67d978511552/src/def_mod.lua#L2407) définit `mod.Path.Wrap`. Les deux mods emploient **`modutil.mod.Path.Wrap("NomDeFonction", function(base, ...) ... end)`**, après obtention de `modutil` via `rom.mods["SGG_Modding-ModUtil"]`. API UPSTREAM CONFIRMED ; disponibilité locale UNVERIFIED.
- [`modutil.once_loaded.game(callback)`](https://github.com/SGG-Modding/ModUtil/blob/3ee4392d6580fe3cbc45b7d8eeba67d978511552/src/main.lua#L30) est défini à 30–59 et utilisé dans les deux bootstraps. Vérifier aussi que la fonction ciblée existe au moment de poser le wrapper.
- [Hell2Modding `rom.on_import.post`](https://github.com/SGG-Modding/Hell2Modding/blob/d0fd25ceec6ab614f33f9506568908b76e39d944/docs/lua/tables/rom.on_import.md) appelle un callback après import d'un script ; `pre` permet même de substituer son environnement. Ce sont des événements de chargement de fichier, **pas des événements d'ouverture de menu**. Préférer ModUtil pour le wrapper de fonction ; ne pas changer l'environnement des scripts.
- [`rom.log.info` / `rom.log.warning`](https://github.com/SGG-Modding/Hell2Modding/blob/d0fd25ceec6ab614f33f9506568908b76e39d944/docs/lua/tables/rom.log.md) sont documentés. Éviter `rom.log.error` pour le repli silencieux : la documentation le décrit comme un miroir de `error` Lua.
- `Path.Override` existe (`def_mod.lua:2435–2436`), mais remplace une implémentation : pas nécessaire pour cet advisor.

### Points d'observation comparés

| Cible | Intérêt | Risque / décision | Preuve |
| --- | --- | --- | --- |
| Après `CreateBoonLootButtons` | Ensemble des choix, ordre visuel, blocages et boutons disponibles ; couvre ouverture et reroll | **Recommandé pour le premier diagnostic**. Fonction contenant des attentes ; comportement du wrapper à valider en jeu. Ne couvre pas seule la rarification individuelle | `UpgradeChoiceLogic.lua:113–278`, 717 |
| Après `CreateUpgradeChoiceButton` | Option et bouton exacts ; utilisé aussi lors d'une rarification | Bon complément ultérieur. Pendant la construction initiale, la liste complète des boutons n'est pas encore prête. Retour du bouton à préserver | Même fichier : 280, 672, 1314 |
| Avant `OpenUpgradeChoiceMenu` | Détecte une demande d'ouverture et sa source | Options possiblement absentes et ouverture pas encore terminée ; couvre davantage que les boons divins. Après son retour : trop tard | Même fichier : 2–111 |
| Après `SetTraitsOnLoot` | Offre générée disponible | Trop proche du générateur ; ordre et blocages visuels pas encore fixés ; certaines offres sont préconstruites. À écarter du MVP | `TraitLogic.lua:1760–2002` et `EventLogic.lua:912` et suite |
| Après `RerollBoonLoot` | Lot renouvelé | Redondant avec le wrapper recommandé ; risque de logs doublés | `UpgradeChoiceLogic.lua:707–718` |
| `DestroyBoonLootButton`, `CloseUpgradeChoiceScreen` | Nettoyer les éléments UI détenus par le mod, plus tard | La rarification a sa propre destruction inline : ne pas supposer que le premier hook couvre tout | Même fichier : 681–705, 1099, 1289–1311 |
| `HandleUpgradeChoiceSelection` | Accès à la sélection | Trop tard et touche le parcours d'acquisition ; ne pas wrapper pour ce MVP | Même fichier : 940 et suite |

Un futur wrapper doit transmettre les arguments inchangés, appeler `base` exactement une fois et préserver tous ses retours. Protéger uniquement le diagnostic du mod contre ses propres erreurs ; ne pas avaler une erreur du jeu, ni rappeler `base` après une erreur. Installation unique du wrapper ; vérifier le rechargement pour éviter les doubles hooks.

### Ce que prouvent les deux mods de référence

**Improved Boon Info UI** : [`src/ready.lua`](https://github.com/SMarechalBE/Hades-2-Improved-Boon-Info-UI/blob/13eb043a736707c54366b19ce20eec0825677f0b/src/ready.lua) remplace notamment `CreateBoonInfoButton` (191), `CreateTraitRequirementList` (476 et suite) et `ShowBoonInfoScreen` (683). Il illustre le rendu de texte, les composants, `GetLootSourceName` et les slots. [`src/reload.lua:336–350`](https://github.com/SMarechalBE/Hades-2-Improved-Boon-Info-UI/blob/13eb043a736707c54366b19ce20eec0825677f0b/src/reload.lua#L336) lit les traits possédés. Son écran principal est le **Boon Info du Codex**, différent d'`UpgradeChoice`. Ne pas reprendre ses remplacements complets.

**Run Boon Overview** : [`src/ready.lua`](https://github.com/SMarechalBE/Hades-2-Run-Boon-Overview/blob/5c9a67ebb0c25fe10b189c678793e40356efc0c5/src/ready.lua) wrappe `BoonInfoPopulateTraits` (8), des fonctions du Codex, `StartRoom` (44), et `AttemptOpenUpgradeChoiceBoonInfo` (51). Ce dernier adapte temporairement `screen.Source.Name` pour ouvrir une page du Codex : mutation inutile et à ne pas reproduire ici. [`src/reload.lua:14–33`](https://github.com/SMarechalBE/Hades-2-Run-Boon-Overview/blob/5c9a67ebb0c25fe10b189c678793e40356efc0c5/src/reload.lua#L14) agrège les traits du pool des dieux rencontrés, pas les trois options d'un loot. Il ne fournit pas une capture des offres actuelles.

## 6. UI injection candidates

**PROPOSED, phase 6 seulement :** ajouter un petit composant textuel par position, détenu par le mod, après la construction native. Primitives attestées dans `UpgradeChoiceLogic.lua` : `CreateScreenComponent` (421, 460), `CreateTextBox` (638, 642), `ModifyTextBox` (89), `Destroy` (704), `CloseScreen` (1099). Le composant `BlankObstacle` et le groupe `Combat_Menu_Overlay` sont employés à 460. Cela prouve leur usage, pas un emplacement libre ni un rendu français validé.

Comparaison :

1. **Texte indépendant près de chaque offre — recommandé.** Garde titres, descriptions et handlers natifs ; mémorise les IDs UI dans une table privée du mod. Gestion explicite de la disparition/recréation des boutons, fermeture et erreurs. Ne pas muter `lootData`, `TraitData` ou `CurrentRun`.
2. **Texte ajouté directement au bouton natif.** Moins de composants mais risque de chevauchement, conflit de TextBox, tooltip et nettoyage. À tester avant adoption.
3. **Panneau récapitulatif séparé.** Peu de dépendance à la structure interne d'un bouton, mais espace disponible et association avec les trois positions à valider.
4. **Remplacement de `CreateUpgradeChoiceButton` / modification globale de `ScreenData.UpgradeChoice`.** Trop invasif pour le besoin ; maintenance et conflits accrus. Non recommandé.

Le nettoyage natif de `DestroyBoonLootButton` utilise une liste de clés explicites (684–697) : il ne détruira pas magiquement une nouvelle clé du mod. La rarification possède en plus son propre bloc de destruction (1289–1311). Prévoir un nettoyage des seuls composants détenus par l'advisor lors du reroll, de la reconstruction d'une position et de la fermeture. `CloseScreen(GetAllIds(screen.Components), ...)` couvre les composants enregistrés dans l'écran, mais ne suffit pas à garantir tous les cycles intermédiaires.

Ne pas modifier `OnPressedFunctionName`, l'ordre, le curseur, les blocs d'interaction ni les tooltips natifs. Aucun rang ne doit être affiché sur une option non sélectionnable. Une erreur doit supprimer ou omettre uniquement l'information de l'advisor.

UNVERIFIED : positions, taille de police, résolutions, masquage lors de l'ouverture du Codex/trait tray et compatibilité visuelle avec d'autres mods. Valider ultérieurement en jeu. Employer d'abord des labels textuels ; la prise en charge des médailles Unicode n'est pas prouvée. Les futurs codes de raisons seront internes au mod, avec textes EN/FR séparés des IDs des traits.

## 7. Unknowns

| Statut | Inconnue | Comment la lever |
| --- | --- | --- |
| UNVERIFIED | Chargeur et dépendances réellement exécutables avec cette build Epic copiée | Installer une stack figée uniquement dans la copie de développement lors d'une étape distincte ; consulter son log de démarrage |
| UNVERIFIED | Package ModUtil installé et résolution exacte de ses dépendances | Inspecter le contenu et les manifestes du package retenu, comparer aux sources citées ; tester `once_loaded.game` et le wrapper |
| UNVERIFIED | Ordre de chargement, wrapper avec attentes/coroutines, reload | Observer une ouverture réelle ; vérifier une seule installation du hook et un seul log par reconstruction |
| UNVERIFIED | État réel des tables pendant une run | Capturer un instantané scalaire au point recommandé, comparer aux options visibles et à l'inventaire |
| UNVERIFIED | Trait factice des Sister Blades avant déblocage des Aspects | Tester une progression correspondante ; ne pas présumer `DaggerBackstabAspect` |
| UNVERIFIED | Cas particuliers, compatibilité intermods | Tester reroll, choix bloqué, remplacement, rarification et ouverture/fermeture du Codex ; exclure Chaos/Pom/Hammer/événements non supportés proprement |
| UNVERIFIED | Isolation des sauvegardes entre copie et installation originale | Avant un lancement de développement, vérifier le profil/chemin de sauvegarde réellement utilisé. Une copie des fichiers du jeu ne prouve pas cette isolation ; aucun jeu lancé ici |
| UNVERIFIED | Relation entre version de l'exécutable et état exact de tous les scripts | Conserver les empreintes ci-dessous ; refaire les lectures après mise à jour |
| UNVERIFIED | Coûts, rangs, valeurs et activation d'Origination/Arcana ; curses ; règles Duo et synergies | Audits ciblés futurs des données et logique de la build locale avant toute règle de score ; aucune valeur proposée ici |
| UNVERIFIED | Provenance/meta des recommandations | À documenter par règle ultérieurement : consensus, préférence de build, expérimental, confirmé en jeu ; aucune base meta créée |

### Empreintes du périmètre principal (SHA-256)

```text
Scripts/UpgradeChoiceLogic.lua  07E7A81D5674ECD1D774CEC81B4450B6E16F2A9DD315996D786EF71518F95292
Scripts/TraitLogic.lua          268C08251C8B05C6A26CA4F6F9642EA6C6A0314C62FC194DD853D96372B53C5E
Scripts/WeaponUpgradeLogic.lua  023271AAB24F3F12DD76F5CCBECE3175BE7AE9E22FD72C07C4E38D4AAAF1F8D9
Scripts/WeaponUpgradeData.lua   A9B87221EF8F56CC4166E62837A431DC050ED368D79C23C8EBB3F35E40C2BDD9
Scripts/InteractLogic.lua       DA50CB72BCF80855DE627930A0745F21ABCA22C4744A5FFB53C21553F9E7B584
Scripts/LootData.lua            64D50A847E193C2F6602493ACB956820C7B3EE44DE8D074043E03C25320000A2
Scripts/TraitData_Aspect.lua    254C6BA4C2B00D71852B19FBECE490993097237E8C5A7DBF4CD386A93B5919BF
```

## 8. Proposed MVP architecture

Conserver les responsabilités proposées. Une adaptation de nom est recommandée : **`src/main.lua` en minuscules**, conforme aux points d'entrée des deux plugins examinés et au template de l'écosystème ; ne pas créer simultanément `Main.lua` et `main.lua` sous Windows. Le mécanisme de chargement exact sera figé après choix du package/boilerplate vérifié.

```text
src/main.lua                         bootstrap et pose unique des hooks confirmés
src/Logger.lua                       logger désactivable, échec sans interruption du jeu
config/settings.lua                  configuration propre au mod
docs/TECHNICAL_ANALYSIS.md            présent audit

À ajouter seulement aux phases concernées :
src/GameState.lua                    instantané de lecture, aucun appel mutateur
src/BoonAdvisor.lua                  orchestration, filtre de profil, copie des offres
src/ScoringEngine.lua                calcul pur : score et codes de raisons
src/UI.lua                           composants d'information et leur cycle de vie
data/builds/*.lua                    profils runtime générés et registre statique
```

Les chemins, modules et noms d'API internes de l'advisor ci-dessus sont des propositions d'architecture, pas des structures du jeu. Aucun de ces fichiers Lua n'est créé à cette étape.

`GameState.lua` devra exposer des copies scalaires et collections propres au mod ; ne pas conserver des références modifiables aux tables du jeu dans le moteur. Garder l'indice d'offre comme donnée stable du classement. Une arme/aspect inconnu produit « profil non supporté », jamais une recommandation par défaut.

Prévoir seulement un emplacement de configuration pour Starter / Intermediate / Meta, sans inventer leurs pondérations. Le logger permettra progressivement weapon, aspect, profil, IDs proposés/possédés, Hammers, scores et raisons. Pour la première sonde, seuls les champs disponibles à son étape seront journalisés ; pas de faux scores ou faux profil détecté.

## 9. First implementation step

**Proposition uniquement, pas implémentée dans cet audit : une sonde de diagnostic après `CreateBoonLootButtons`.**

Prérequis avant son exécution : stack et version installées vérifiées dans la copie de développement, sauvegardes de test isolées, aucune cible pointant vers `<production-game-root>`. Le repository reste indépendant du jeu. Aucun besoin de patcher les scripts originaux.

Séquence strictement incrémentale :

1. **Phase 1 :** bootstrap minimal, `DEBUG` désactivable, wrapper posé une seule fois quand le jeu est prêt. Après l'appel original, logger uniquement la détection et la source de l'écran. Filtrer les loots divins supportés ; vérifier la fonction et les tables sans les créer dans le jeu. Arrêter la validation ici tant que l'ouverture n'est pas stable.
2. **Phase 2, après validation de phase 1 :** ajouter au même point la lecture de `UpgradeOptions` et des boutons : indice affiché, `ItemName`, rareté, statut bloqué. Aucun appel de génération, aucun tri en place, aucun score ni composant UI. Ne pas inventer un lot de trois IDs pour masquer une lecture incomplète.

Critères de validation de la sonde :

- Log présent au moment où les offres sont affichées, pas après le choix ; identifiants et ordre corrélés aux boutons.
- Une nouvelle construction lors d'un reroll donne un nouvel instantané ; aucun doublon de wrapper après reload.
- Les offres bloquées sont distinguées ; les écrans hors périmètre sont ignorés sans erreur.
- `DEBUG = false` supprime les diagnostics ; une panne du logger n'empêche ni la sélection manuelle ni la fermeture.
- Revue du code : aucun RNG, aucune écriture dans `CurrentRun`/`GameState`/les options, aucune sélection automatique, aucun appel supplémentaire aux fonctions natives de construction. L'appel original demeure unique, arguments et retours préservés.
- Limite annoncée : la rarification individuelle ne sera couverte qu'avec l'observation complémentaire décrite en section 5 ; ne pas considérer le pipeline d'affichage final validé par cette seule sonde.

Ensuite seulement : lecture de run (phase 3), arme/aspect (4), scoring minimal (5), UI (6), règles dynamiques (7), profils (8), autres Aspects (9). Aucun test runtime n'a été effectué pendant cet audit et aucune garantie d'absence de régression en jeu n'est prétendue.

## 10. Phase 0.5 — preflight et préparation de la sonde Phase 1

### 10.1 Comparaison des builds : aucune synchronisation nécessaire dans le périmètre vérifié

Comparaison en lecture seule de `<development-game-root>` avec `<production-game-root>` : **481 fichiers comparés, 481 identiques, zéro différence**. Cela comprend tous les 479 fichiers `Content\Scripts\*.lua` du premier niveau, `Ship\Hades2.exe` et `Ship\lua52.dll`. Aucun script Lua supplémentaire au premier niveau côté Epic.

Le manifeste Epic indique `139652-Win`, mais **les deux exécutables indiquent `139606`** et ont le même SHA-256 : `DB88529B0961C41763413FC676762B9AC05CD22F9547A9305E0B629B30F2EE74`. Ce sont donc des identifiants de couches différentes, pas une preuve de copie périmée. La signification exacte du numéro de manifeste reste UNVERIFIED. Aucune conclusion d'identité de tous les assets/packages non comparés n'est tirée.

| Script minimal demandé | SHA-256 identique dans les deux installations |
| --- | --- |
| `UpgradeChoiceLogic.lua` | `07E7A81D5674ECD1D774CEC81B4450B6E16F2A9DD315996D786EF71518F95292` |
| `TraitLogic.lua` | `268C08251C8B05C6A26CA4F6F9642EA6C6A0314C62FC194DD853D96372B53C5E` |
| `WeaponUpgradeLogic.lua` | `023271AAB24F3F12DD76F5CCBECE3175BE7AE9E22FD72C07C4E38D4AAAF1F8D9` |
| `InteractLogic.lua` | `DA50CB72BCF80855DE627930A0745F21ABCA22C4744A5FFB53C21553F9E7B584` |
| `LootData.lua` | `64D50A847E193C2F6602493ACB956820C7B3EE44DE8D074043E03C25320000A2` |
| `TraitData_Aspect.lua` | `254C6BA4C2B00D71852B19FBECE490993097237E8C5A7DBF4CD386A93B5919BF` |

Preuve détaillée : [BUILD_COMPARISON.csv](BUILD_COMPARISON.csv), avec chemins relatifs et deux hashes par fichier. Aucun fichier synchronisé, copié ou patché entre installations.

### 10.2 Stack actuelle retenue pour le premier essai

Les packages ont été téléchargés et extraits **uniquement en temporaire** dans `<temporary-preflight-directory>`. Leurs manifestes et leurs sources Lua ont été lus. Ils ne sont pas installés dans la copie du jeu. Les APIs sont confirmées dans les packages/sources, leur exécution locale reste UNVERIFIED.

| Package | Version figée | Motif |
| --- | --- | --- |
| Hell2Modding-Hell2Modding | **1.0.112** | Version disponible confirmée sur Thunderstore et par le manifeste de l'archive téléchargée ; pas 1.0.87 ni la nightly mutable |
| SGG_Modding-ModUtil | **4.0.1** | Dernière release GitHub retournée ; archive exacte inspectée pour `once_loaded.game` et `mod.Path.Wrap` |
| LuaENVY-ENVY | 1.2.0 | Dépendance du template actuel ; environnement privé et imports |
| SGG_Modding-ReLoad | 1.0.2 | Dépendance du template ; garde par signature lors des rechargements |
| SGG_Modding-ENVY | 1.1.0 | Dépendance transitive explicitement demandée par ModUtil ; identifiant distinct de LuaENVY |
| SGG_Modding-DemonDaemon | 1.0.1 | Dépendance ModUtil |
| SGG_Modding-Chalk | 2.1.1 | Présent dans le template et satisfait la dépendance de DemonDaemon ; pas utilisé directement pour DEBUG |
| SGG_Modding-SJSON | 1.0.0 | Dépendance transitive de DemonDaemon ; aucune opération SJSON de l'advisor |

Les dépendances historiques des packages demandent des versions inférieures de certains de ces mêmes identifiants ; une seule version par identifiant est retenue ci-dessus. Ce choix explicite ne prouve pas leur compatibilité runtime. Les versions déclarées d'origine et hashes des archives sont conservés dans [STACK_LOCK.json](STACK_LOCK.json). Aucune fusion arbitraire de manifestes de mods de référence.

Sources actuelles : [Hell2Modding 1.0.112](https://thunderstore.io/c/hades-ii/p/Hell2Modding/Hell2Modding/), [ModUtil 4.0.1](https://github.com/SGG-Modding/ModUtil/releases/tag/4.0.1), [template 0.10.0](https://github.com/SGG-Modding/Hades2ModTemplate/releases/tag/0.10.0), [guide du template](https://sgg-modding.github.io/Hades2ModWiki/docs/creating-mods/first-mod-guide/mod-template).

Le template courant est **0.10.0**, HEAD `a40d04d72746913e5ed7edacf3bce1fa2c385a66`. Son archive contient `src/main.lua`, `ready.lua`, `reload.lua`, variantes late et `thunderstore.toml`. Son manifeste mentionne encore Hell2Modding 1.0.70 : ce minimum historique n'est pas notre version retenue. Wiki : HEAD `2345a1b32f073acf89fb6952ffe8383a94566172`, sans release versionnée retournée par l'API GitHub.

**Clarification de provenance, revérifiée le 20 septembre 2026 après signalement de 0.9.1 :** la valeur 0.10.0 provenait de `https://api.github.com/repos/SGG-Modding/Hades2ModTemplate/releases/latest`, champs `tag_name` et `name`, puis du téléchargement de l'asset de cette release. La nouvelle lecture de cet endpoint et de `/releases/tags/0.10.0` confirme une release publique, non draft et non prerelease, publiée le `2026-08-09T17:42:25Z`. Le dépôt exact est `https://github.com/SGG-Modding/Hades2ModTemplate`. Le tag annoté `0.10.0` est l'objet `49b3ecf53d643717e0a004e36bb7248e35257f16`, résolu via `/git/tags/49b3ecf53d643717e0a004e36bb7248e35257f16` vers le commit `a40d04d72746913e5ed7edacf3bce1fa2c385a66`. La release 0.9.1 existe également, publiée le `2026-04-05T02:39:06Z` ; elle n'est pas celle retournée par l'API latest lors des deux vérifications.

Le numéro 0.10.0 figure dans le **`CHANGELOG.md` à la racine du dépôt**, entrée du 2026-08-09 et liens de comparaison. Ce numéro est celui de la release et du tag du template, pas celui d'un package de mod : `src/thunderstore.toml` contient `versionNumber = "0.0.1"`. Le workflow racine `.github/workflows/release.yaml` reçoit le tag en entrée et archive le dossier `src/`. Ainsi `src/src/main.lua` dans Git devient `src/main.lua` dans le ZIP, et `src/CHANGELOG.md` devient le changelog du mod exemple, distinct du changelog racine portant 0.10.0.

L'archive initialement téléchargée depuis `https://github.com/SGG-Modding/Hades2ModTemplate/releases/download/0.10.0/hades2-mod-template.zip` a le SHA-256 `5BED5A713398DDA7FF15C1744CFD4FC9CCF9E3386A1114FC502451F32E6B4143`, identique au digest de l'asset annoncé par GitHub. Son `src/main.lua` correspond textuellement au `src/src/main.lua` du commit ci-dessus (fins de ligne normalisées pour cette comparaison).

**Rectification de la présentation initiale :** le numéro 0.10.0 n'est pas démenti par les preuves relues ; aucune substitution par 0.9.1 n'est faite. L'insuffisance initiale était de juxtaposer release et HEAD sans établir explicitement la résolution du tag ni distinguer chemins Git/ZIP. Cette chaîne est maintenant documentée. Le code Phase 1 de Boon Advisor est une adaptation minimale écrite pour la sonde, **pas une copie exacte de cette révision** : il utilise `auto_single`, son logger/configuration et son filtre, et omet les exemples et callbacks late du template. Aucun code source changé par cette vérification ; aucune Phase 2 commencée.

Adaptation minimale : garder `main.lua`, ENVY, `once_loaded.game` et ReLoad ; omettre les exemples, mutations SJSON, images, callbacks late, publication et Chalk de configuration. Utiliser un manifeste de plugin local et un script de staging, sans installer un ancien mod entier. `config/settings.lua` est copié sous `config/` à la racine du plugin ; `Logger.lua` est placé à côté de `main.lua`. ENVY 1.2.0 `main.lua:79–109` confirme que `import` résout les chemins depuis `_PLUGIN.plugins_mod_folder_path` et conserve les retours du module.

### 10.3 Lua, retours et rechargement

[Hell2Modding `cmake_scripts/rom.cmake`](https://github.com/SGG-Modding/Hell2Modding/blob/d0fd25ceec6ab614f33f9506568908b76e39d944/cmake_scripts/rom.cmake) fixe `LUA_USE_LUAJIT false`, le fork Lua `e2f0a33c52c18516c61b6fedfd6b518c5f0fbdb5` et ReturnOfModdingBase `693360501a0b5309e302956fca1c5aaf528da441`. Le [`lua.h` de ce fork](https://github.com/xiaoxiao921/lua-fork-hades2/blob/e2f0a33c52c18516c61b6fedfd6b518c5f0fbdb5/lua.h) indique **Lua 5.2.2**. Le package ReLoad utilise lui-même `table.pack` et `table.unpack`. La correspondance binaire exacte de l'archive Hell2Modding avec ce HEAD n'a pas été reconstruite ; la sonde vérifie la présence de ces primitives avant de poser le hook.

La sonde effectue `table.pack(base(...))` puis `table.unpack(results, 1, results.n)` : zéro retour, `nil` intermédiaires et finaux sont conservés. `base` est appelé exactement une fois, hors de tout `pcall`. Seul le diagnostic postérieur est protégé. Aucun tri, aucune génération, aucune lecture de `CurrentRun`, aucune écriture dans les tables du jeu, aucun composant UI.

Protection de reload : `ReLoad.auto_single()` utilise une signature formée du plugin et du fichier source (`ReLoad/main.lua`, fonctions `get_sig`, `handle_load`, `auto_single`). Le callback d'installation ne s'exécute qu'une fois pour cette signature. Une seconde garde `private.probeState.installed` est détenue par l'environnement privé ENVY ; `state.log` peut être actualisé lors du reload sans changer le wrapper existant. Si une dépendance est rechargée ou l'environnement entièrement recréé, redémarrer le jeu : ce cas n'est pas promis comme reload supporté.

Logger : `rom.log.info` est confirmé dans la documentation officielle Hell2Modding citée en section 5 ; aucun usage de `rom.log.error`. Il est injecté au logger et appelé sous `pcall`. S'il est absent/non fonctionnel, le logger reste silencieux. Aucune API ne peut encore être qualifiée de « validée dans la stack installée », puisqu'aucune stack n'a été installée. Cette condition doit être levée au premier essai isolé.

### 10.4 Sauvegardes : chemin établi, isolation encore à réaliser

**LOCAL CONFIRMED :** `<primary-user-profile>\Saved Games\Hades II` contient les profils, variantes temporaires, backups, options et cache cloud. Le journal existant `Hades II.log:32` écrit `Loading default profile` avec ce chemin et `Profile1` ; la ligne 121 identifie `Ship 139606`. L'activation cloud est également indiquée dans le journal. Aucun contenu binaire de sauvegarde n'a été analysé ou changé.

**Conclusion opérationnelle :** lancer la copie sous le compte principal avec les paramètres par défaut doit être considéré comme partageant les sauvegardes principales. Le simple chemin différent de l'exécutable ne prouve aucune redirection. Aucune option de redirection n'a été établie dans les sources inspectées ; ne pas inventer `/SavePath` ou une variable d'environnement.

Méthode sûre proposée : backup intégral vérifié du dossier principal, puis compte Windows local de test distinct, sans cloud ni accès en écriture aux sauvegardes principales ; nouveau profil jetable. Vérifier d'abord, sans mod, le chemin effectivement utilisé sous ce compte. Les instructions détaillées et gates sont dans [RUNTIME_TEST.md](RUNTIME_TEST.md). Aucun lancement, changement de permissions, copie/suppression de sauvegarde ou changement de compte effectué ici.

### 10.5 Audit du predicate GodLoot

L'héritage est effectif : `RunData.lua:919–921` affecte les noms et appelle `ProcessDataInheritance`. Cette fonction (`1363` et suite) hérite des parents puis restaure certains champs exclus. **`DebugOnly` fait partie des exclusions** (`RunData.lua:1325`) : le `DebugOnly = true` du gabarit `BaseLoot` n'est pas transmis aux vrais dieux.

| Famille / ID interne vérifié | GodLoot effectif dans les données natives | Décision Phase 1 et preuve |
| --- | --- | --- |
| `BaseLoot` | true explicite, DebugOnly | Gabarit exclu ; `LootData.lua:10–23` |
| `AphroditeUpgrade`, `ApolloUpgrade`, `AresUpgrade`, `DemeterUpgrade`, `HephaestusUpgrade`, `HeraUpgrade`, `HestiaUpgrade` | true explicite | Inclus ; chacun défini à la ligne 4 de son `LootData_<Dieu>.lua`, drapeau respectivement 18, 16, 18, 15, 27, 19, 18 |
| `ZeusUpgrade`, `PoseidonUpgrade` | true hérité de BaseLoot | Inclus ; `LootData_Zeus.lua:4–6`, `LootData_Poseidon.lua:4–6` ; une recherche du seul texte `GodLoot = true` les manquerait |
| Duo | Offre dans un loot de dieu, pas une source supplémentaire à inventer | Sonde déclenchée selon la source de l'écran ; `InteractLogic.lua:700–705` reconnaît `IsDuoBoon` dans ses options. Aucun ID d'offre inspecté par la sonde |
| `HermesUpgrade` | false ; TreatAsGodLootByShops=true | Exclu volontairement ; `LootData_Hermes.lua:4–11` |
| `TrialUpgrade` (Chaos) | false ; TransformingTraits=true | Exclu ; `LootData_Chaos.lua:4–17`, 58 |
| `WeaponUpgrade` (Hammer) | false | Exclu ; `LootData.lua:212–217` |
| `StackUpgrade`, `StackUpgradeBig`, `StackUpgradeTriple` (Pom) | false explicite/hérité ; StackOnly=true | Exclus ; `LootData.lua:89–110`, 196–205 |
| `SpellDrop` | Pas d'héritage BaseLoot, pas de GodLoot=true | Exclu ; `LootData_Selene.lua:4–6` |
| Artemis, Athena, Dionysus, Hades via données NPC | TreatAsGodLootByShops ne vaut pas GodLoot | Hors périmètre ; marqueurs dans `NPCData_Artemis.lua:1850`, `NPCData_Athena.lua:26`, `NPCData_Dionysus.lua:28`, `NPCData_Hades.lua:17` ; transfert vers FieldLootData à `RunData.lua:561–564` |
| Choix d'événement | Plusieurs sources utilisent aussi OpenUpgradeChoiceMenu | Hors liste autorisée ; appels `EventLogic.lua` référencés en section 2 |

La recherche des déclarations et de leurs parents dans les `LootData*.lua` locaux identifie neuf sources concrètes GodLoot=true, plus le gabarit BaseLoot. Aucun universalisme n'est revendiqué pour les mods tiers ou futures mises à jour.

**Predicate implémenté :** appel de `CreateBoonLootButtons`, tables `screen` et `lootData` présentes, `screen.Source == lootData`, `screen.KeepOpen == true`, `lootData.Name` dans la liste des neuf IDs ci-dessus, `lootData.GodLoot == true`, et ni `DebugOnly`, ni `StackOnly`, ni `TransformingTraits`. Certitude : statiquement cohérent avec les fichiers identiques audités ; **UNVERIFIED runtime**. Le contrôle croisé réduit les faux positifs ; un nouveau dieu ou un écran non conforme est ignoré. Il ne peut pas distinguer un événement tiers qui reproduirait exactement une source olympienne native.

### 10.6 Livraison et statut des gates

| Gate | Résultat |
| --- | --- |
| Build cible / copie | PASS sur 481 fichiers comparés ; aucune synchronisation requise pour ce périmètre |
| Format de plugin, APIs, Lua | Sources/packages vérifiés ; squelette préparé localement |
| Tests unitaires de la sonde | PASS dans un état Lua isolé chargé via `Ship/lua52.dll` ; frameworks remplacés par des doubles |
| Installation effective de la stack | NON EFFECTUÉE ; à vérifier selon le lock avant essai |
| Backup et isolation des sauvegardes | Méthode documentée, NON EFFECTUÉS ; lancement moddé bloqué jusqu'à validation |
| Hook en jeu, filtres réels, reroll, reload | UNVERIFIED ; aucune réussite runtime prétendue |
| Phase 2 | NON COMMENCÉE |

Fichiers ajoutés : `src/main.lua`, `src/Logger.lua`, `config/settings.lua`, `manifest.json`, `tools/Stage-Probe.ps1`, `tests/probe_spec.lua`, `tests/run_lua52.py`, `.gitignore`, `README.md`, `docs/BUILD_COMPARISON.csv`, `docs/STACK_LOCK.json`, `docs/RUNTIME_TEST.md`, `docs/PHASE1_CODE.diff`. Présent document mis à jour. `dist/Local-HadesIIBoonAdvisor` est uniquement un staging local ignoré par Git.

Le [diff complet du code](PHASE1_CODE.diff) inclut la sonde, la configuration, le manifeste, le staging et les tests. [RUNTIME_TEST.md](RUNTIME_TEST.md) décrit le premier essai, les preuves attendues et les limites. Le développement s'arrête à cette sonde tant que l'essai réel n'est pas validé.

## Ares Audit (Phase 5A)

Source primaire : `<development-game-root>\Content\Scripts\TraitData_Ares.lua`.
Les fonctions référencées ont été suivies dans `PowersLogic.lua`.

| ID | Rôle / mécanique native | StatusKnowledge | Source |
|---|---|---|---|
| `AresWeaponBoon` | Melee, Ares curse damage/status | mapped: `AresStatus` / `Curse` | TraitData_Ares.lua:4-80 |
| `AresSpecialBoon` | Secondary, Ares curse damage/status | mapped: `AresStatus` / `Curse` | TraitData_Ares.lua:~800-880 |
| `AresCastBoon` | Ranged; `CheckAresCurseApply` creates delayed sword projectiles after `ImpactSlow`; no vulnerability application in the called function | known_non_status | TraitData_Ares.lua:1462-1540; PowersLogic.lua:2359-2400 |
| `AresManaBoon` | Mana; `CheckAresManaBloodDrop` creates BloodDrop chance; no status application | known_non_status | TraitData_Ares.lua:1393-1460; PowersLogic.lua:941-945 |
| `AresSprintBoon` | Rush; `StartAresSprintProjectile` creates sword-wake projectiles | known_non_status | TraitData_Ares.lua:1542-1610; PowersLogic.lua:2489-2498 |
| `AresExCastBoon` | Cast-ex projectile damage and mana cost; no vulnerability application | known_non_status | TraitData_Ares.lua:1612-1685 |
| `RendBloodDropBoon` | Blood-drop/rend projectile damage | known_non_status | TraitData_Ares.lua:1694-1762 |
| `AresStatusDoubleDamageBoon` | Chance-based double damage while `AresStatus` is already active | known_non_status (does not produce the status) | TraitData_Ares.lua:1766-1838 |
| `BloodDropRevengeBoon` | Blood drops on self damage/enemy death | known_non_status | TraitData_Ares.lua:1841-1922 |
| `MissingHealthCritBoon` | Missing-health critical/double-damage modifier | known_non_status | TraitData_Ares.lua:1923-1988 |
| `LowHealthLifestealBoon` | Low-health lifesteal modifier | known_non_status | TraitData_Ares.lua:1989-2051 |
| `OmegaDelayedDamageBoon` | Omega mana cost plus delayed Ares sword damage | known_non_status | TraitData_Ares.lua:2053-2138 |
| `DoubleBloodDropBoon` | Legendary blood-drop damage/magnetize behavior | known_non_status | TraitData_Ares.lua:2140-2177 |

Only `AresWeaponBoon` and `AresSpecialBoon` are mapped status producers. The
other audited IDs are explicitly known not to produce a vulnerability status;
this classification does not make them gameplay-covered. No Ares-specific
scoring rule or new weight was activated in Phase 5A. Replacement remains
unresolved and blocking as before.

## Core Replacement Model (Phase 5B)

For a core offer with `TraitToReplace`, the engine resolves replacement only when both IDs are verified core traits and their native slots match. `oldKnownCoreValue` and `newKnownCoreValue` are the sums of already-active Aspect interaction and existing Hammer synergy weights, plus a deterministically recomputed Origination contribution. Empty-slot fill rules are excluded from both values. The new-state calculation removes the old trait from a copied `godTraits` list before adding the new trait; the native snapshot is never mutated.

The emitted reason is `CORE_REPLACEMENT_DELTA = newKnownCoreValue - oldKnownCoreValue`. Zero, positive, and negative deltas are covered and complete when all status knowledge is explicit. If slots, IDs, status transition, or potential status traits are unresolved, the result remains `REPLACEMENT_UNRESOLVED`, uncovered and incomplete. Rarity is intentionally excluded. Hammer synergy is included in both old and new values, so a role or Hammer interaction change contributes to the relative delta.
## Build Priority Layer (Phase 5F)

The intermediate Sister Blades profile contains a declarative `buildPlan`
for the audited Attack, Special, Cast, and Sprint slots. This is a build
profile synthesis, not native game data. Native mechanics remain sourced
from local Hades II scripts; profile priority and its numeric weights are
mod decisions. `CORE` and `PREFERRED` alignments add their configured
priority reason, while `NON_TARGET` suppresses only the generic empty-slot
fill for a planned slot and is never a penalty. A slot with no plan retains
the generic Phase 3 behavior. Absence from the community sheet does not
mean that a Boon is bad.

For an empty slot with `slotPolicy = open`, every recognized core-slot trait
receives the generic empty-slot value. Alignment then adds the profile layer:
`PREFERRED` adds `BUILD_PREFERRED`, ordinary `NON_TARGET` adds no build
delta, and `DISCOURAGED` adds `BUILD_DISCOURAGED`. A `preferred` policy does
not receive this ordinary-fill exception. Reserved-slot `NON_TARGET` keeps
its existing conflict semantics. The Morrigan Special hierarchy is therefore
10 / 8 / 6 for preferred / ordinary / discouraged offers.

Phase 5F adds only `BUILD_CORE_PRIORITY = 4` and `BUILD_PREFERRED = 2` to
the profile. The constraint `DO_NOT_SACRIFICE_CORE_PLAN` is documentary and
does not create an observable condition. Replacement values include the
priority contribution; `FILL_EMPTY_*` remains excluded. Coverage,
completeness, ranking gates, UI, and lifecycle are unchanged.
## Rarity Scoring Policy (Phase 5G)

Native Hades II rarity scaling is trait-specific: each trait has its own
`RarityLevels` and multipliers. The mod therefore uses a separate bounded
policy for normal Boon rarities only: Common/Rare/Epic/Heroic map to
0/1/2/3. Duo and Legendary are known non-comparable categories and do not
receive a numeric contribution. Rarity is applied only after semantic
coverage and completeness; it cannot make an unknown offer covered.

Non-replacement offers use the `RARITY` reason. Replacements use only the
difference as `RARITY_DELTA`; an absent comparable `OldRarity` yields
`RARITY_UNRESOLVED` and incomplete scoring. Sublimation recreates one native
button, after which the Advisor rescans and reranks the complete screen.
## Structural Ares Support Synergies (Phase 5H1)

The profile now records two generic capability layers backed by local native
data. `AresStatusDoubleDamageBoon` receives `BUILD_STATUS_SYNERGY` only when
an owned audited Ares Weapon or Special producer can apply `AresStatus`; this
does not assert that an enemy is currently cursed. BloodDrop payoffs receive
`BLOOD_DROP_ENGINE_SYNERGY` only when an owned producer (`AresManaBoon` or
`BloodDropRevengeBoon`) is present. No instant BloodDrop existence is inferred.

The new weights are both 4. LowHealthLifesteal, MissingHealthCrit,
OmegaDelayedDamage, and AresExCast remain deferred; transient health and
unobservable Omega/Ex usage are not used for ranking. Rarity remains applied
only after semantic coverage and completeness.
## Conditional Low-Health Support (Phase 5H2)

`LowHealthLifestealBoon` is structurally supported with the existing
`SURVIVAL_SUPPORT = 2` weight. Its condition metadata is private diagnostic
context only: `health_below_absolute`, threshold `40`, and
`currentlyActive` derived from copied current health when available. Current
health never changes the score, reasons, completeness, or ranking gates.
MissingHealthCrit and the other deferred conditional supports remain
uncovered. Normal rarity is still applied after this structural rule.
## Generic Build Schema and Slot Reservation (Phase 5I-A)

The Sister Blades Intermediate profile uses `schemaVersion = 1`, a stable
build ID, `profileMode`, optional declarative source metadata, and a
top-level `slots` table. Every slot definition supplies `core`,
`alternatives`, `preferred`, and one `slotPolicy`: `reserved`, `preferred`,
or `open`. The validator rejects an absent or unsupported schema version,
malformed identity fields, unknown slot roles or policies, non-table role
lists, empty trait IDs, duplicate IDs, and conflicting role membership.
An invalid profile is unsupported; it cannot score an offer.

Current slot occupancy is captured as scalar copies of
`CurrentRun.Hero.SlottedTraits[slot]`, with the copied God-trait `Slot` data
as a read-only fallback. For a recognized core offer, the engine exposes
alignment, policy, prior and projected slot states, and non-scoring conflict
metadata. A conflict means a `NON_TARGET` offer would occupy a `reserved`
slot. It has no reason, score, coverage, completeness, or ranking effect in
5I-A. Replacement metadata distinguishes resolving a non-target occupancy
from sacrificing a Core, while preserving the existing replacement score.

`DO_NOT_SACRIFICE_CORE_PLAN` remains documentary: no runtime code reads it.
Future 5I-B may replace that policy statement with scoring based on the
captured metadata, but this phase intentionally adds no conflict penalty.
## Replacement Transition Audit (Phase 5I-A.1)

`CORE -> ALTERNATIVE` is build-valid metadata, not proof of mechanical
equivalence. The current Ares-to-Aphrodite replacement is resolvable when
Origination is inactive: both core IDs and their slot are verified, and the
existing relative delta is preserved. When Origination is active,
`AphroditeWeaponBoon` remains status-unknown because its status mapping has
not been audited; the existing conservative path therefore emits
`REPLACEMENT_UNRESOLVED`, leaving coverage and completeness false. No build
alignment is used to invent a status contribution or replacement bonus.

Transition debug fields (`SlotStateBefore`, `SlotStateAfter`,
`ConflictIntroduced`, `ConflictResolved`, and `CoreSacrificed`) are
diagnostic only. `CoreSacrificed` is true only for an actual replacement from
a target Core to a `NON_TARGET`; replacing a Core with an allowed Alternative
does not count as a sacrificed Core.
## Build Slot Policy Scoring (Phase 5I-B)

Reserved-slot conformity uses one configured magnitude, `BUILD_SLOT_POLICY =
4`. The emitted reason is the signed `BUILD_SLOT_POLICY_DELTA`: `-4` when a
reserved slot becomes `NON_TARGET`, `+4` when a known conflict is resolved,
and no reason for zero deltas or `preferred`/`open` slots. Empty-slot offers
use the empty-to-after delta; replacements use after minus before.
`CORE_REPLACEMENT_DELTA` and this policy delta are intentionally distinct:
the former represents the value change of the traits, while the latter
represents the state of the reserved slot. No separate Core-sacrifice or
recovery bonus exists.

Negative scores are preserved without clamping and remain equal to the sum
of their reasons. In the UI, a negative policy delta is shown as `Conflit`, a
positive one as `Build`, and zero is hidden. `Conflit` is prioritized so an
active negative policy remains visible within the two-label limit. A known
policy transition does not make an unresolved mechanical replacement
complete; `REPLACEMENT_UNRESOLVED` still blocks global ranking.

## Second Real Build Profile (historical Phase 5J-A)

This section records the v0.1.x Starter experiment. Starter is retired from
active v0.2 canonical generation, runtime staging, and profile selection; its
historical data remains in Git and the private documentary Build Registry.

The historical `data/builds/sister_blades_melinoe_starter.lua` was a separate, validated
Sheet-sourced profile, with identity `sister_blades_melinoe_starter`,
`profileMode = "starter"`, `WeaponDagger`, and `DaggerBackstabAspect`. Its
recorded Starter plan is intentionally narrow: `AphroditeWeaponBoon` is the
reserved Attack Core, `ZeusSpecialBoon` is the reserved Special Core, Sprint
is open and flexible, and Cast is omitted entirely (`NO_PLAN`). No missing
slot is inferred from the Intermediate plan.

At that stage the selector was `BUILD_PROFILE` in `config/settings.lua`, and
`"starter"` selected this experimental profile. The current default is
`"auto"`; a retired or unknown explicit selection emits one WARN and uses
auto for the session without rewriting settings.lua. Profile DEBUG logs
include `BuildId`, `ProfileMode`, and `SchemaVersion`.

The scoring engine remains profile-generic: it receives a selected profile
as data and has no branch on profile identity. At that stage both profiles carried the
same audited mechanical mappings, weights, and rules. The active v0.2 staging
artifact contains Intermediate only for DaggerBackstabAspect.

## Profile Selection (Phase 5J-B)

The development helper `tools\Set-BoonAdvisorProfile.ps1` updates only
`config\settings.lua` in the selected plugin directory. Available values now come from the generated registry, plus `auto`.
Starter is rejected for a new selection:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Set-BoonAdvisorProfile.ps1 -Profile intermediate -TargetPath <plugin-root>
powershell -ExecutionPolicy Bypass -File .\tools\Set-BoonAdvisorProfile.ps1 -Show -TargetPath <plugin-root>
```

The required `-TargetPath` names the plugin directory to inspect or update.
The helper validates the target, settings file, generated registry, and exactly
one `BUILD_PROFILE` assignment before writing only that value. `-Show` is
read-only, and repeated selection is idempotent. If Hades II is running, the
helper warns that a restart is needed.
After a successful change, restart Hades II for the selected profile to be
loaded. The helper is development tooling and is not included in runtime
staging.

## Canonical Build Data Prototype (Phase 5K-A)

The two real profiles separate naturally into identity (id, weapon, aspect,
mode, Sheet provenance), build plan (slots, roles, policies, constraints),
and shared mechanics (weights, verified IDs, status mappings, Hammer roles,
and scoring rules). The first two categories differ; the mechanical tables
are presently duplicated byte-for-byte in the runtime Lua files.

data/canonical/profiles/*.json is the development-only canonical plan
format. It uses internal IDs only and preserves schema version, identity,
source metadata, slot roles (core, alternatives, preferred), policies
(reserved, preferred, open), constraints, and intentional missing slots. An
omitted Cast is therefore NO_PLAN; it is not an empty reserved Cast slot.
mechanicsTemplate records which audited mechanical dataset the development
generator composes with the plan.

The prototype commands are:

    powershell -ExecutionPolicy Bypass -File .\tools\Generate-BoonAdvisorProfiles.ps1 -ValidateOnly
    powershell -ExecutionPolicy Bypass -File .\tools\Generate-BoonAdvisorProfiles.ps1 -OutputDirectory C:\Temp\BoonAdvisorGenerated

Its validator rejects unsupported schema versions, missing identities,
duplicate IDs/output names, unsupported weapon/aspect pairs and slots,
invalid policies, malformed role arrays, duplicate slot IDs, and cross-role
contradictions. Input files and output names are sorted lexicographically;
object keys are sorted; arrays retain their listed order. Identical canonical
input therefore generates byte-identical Lua.

Generated Lua is deliberately a development composition prototype: it loads
the audited Sister Blades mechanical template and overwrites only canonical
profile fields. It validates and scores identically to the current runtime
profiles, but is not staged or deployed. This proves the schema and
generation path without changing runtime loading or duplicating mechanics a
third time.

The recommended next step, outside this phase, is a single runtime-safe Lua
mechanical dataset generated from canonical data, plus a static generated Lua
registry. That would remove duplicated tables and manual registration without
filesystem scanning. It requires a dedicated compatibility review because
the current mod environment has no safe runtime directory enumeration.

### Windows PowerShell 5.1 Compatibility

The generator intentionally uses ConvertFrom-Json without the PowerShell 7
AsHashtable parameter. Its development-only recursive helper converts parsed
PSCustomObject values, nested objects, arrays, scalars, and null into the
hashtable/array representation required by the validator. Object keys are
still sorted during Lua rendering and arrays retain their declared order.
The canonical test invokes powershell.exe for both validation and generation,
so Windows PowerShell 5.1 compatibility is a required regression check.

## Canonical Mechanics Template and Registry Prototype (Phase 5K-B)

The canonical mechanics template data/canonical/mechanics/sister_blades_melinoe.json
owns the shared template identity, weapon/aspect compatibility boundary, the
runtime mechanical template location, and the explicit list of shared
mechanical sections: weights, status mappings and knowledge, BloodDrop,
aspect, Hammer, rules, and verified IDs. Profile JSON owns only profile
identity, Sheet provenance, plan slots, policies, and constraints.

Generation validates mechanics before profiles, checks the profile template
reference and identity match, and emits a temporary static registry.lua. At Phase 5K-C, the
registry mapped intermediate and starter to static build ID, mode, weapon,
aspect, and generated module file. The active v0.2 registry instead contains
intermediate, morrigan_meta, and coat_melinoe_intermediate. Duplicate
selectable keys, IDs, and output names are rejected. ProfileMode is retained
as the temporary key because the two present values are unique; a later
multi-build design should introduce a dedicated selectionKey before two
profiles can share a mode.

5K-C can replace main.lua's hand-written table with an import of the static
generated registry and a static module lookup. The profile switcher should
then accept a plain string and validate it against generated canonical
registry metadata, rather than extending a fixed ValidateSet. No runtime
migration is performed in this phase.

### JSON-only Generation (Phase 5K-B.1b)

The generator now composes each temporary Lua profile directly from its
canonical profile JSON and mechanics JSON. runtimeTemplate was removed from
the mechanics schema and no generated Lua calls loadfile. JSON arrays that
represent runtime sets are rendered as independent boolean-key maps:
knownNonStatusTraits, potentialStatusTraits, status capability memberships,
and BloodDrop producers/payoffs. All other arrays retain their declared
order; map keys are sorted during rendering.

Runtime Lua profiles remain test-only equivalence references. The generated
registry is still temporary and main.lua continues to use its existing
hand-written registration. 5K-C is the future runtime migration phase.

## Generated Runtime Profiles and Static Registry (Phase 5K-C)

The next paragraphs record the historical Phase 5K-C implementation. The
active v0.2 profile set and staging inventory are specified at the end of
this analysis.

Canonical profile JSON now owns a dedicated `selectionKey`, distinct from
`profileMode`. The generator validates that every selection key is non-empty,
matches the conservative lowercase identifier format, and is globally unique.
It produces the two runtime profiles and `data/builds/registry.lua` directly
from canonical JSON. The static registry maps each key to immutable metadata
and to its explicit module path; it performs no runtime filesystem scan.

`main.lua` imports that registry, resolves `settings.BUILD_PROFILE`, and then
imports only the selected generated module. Its established fallback remains
`intermediate`, including the existing DEBUG-gated warning for an unknown
setting. ScoringEngine remains profile agnostic and no scoring, ranking,
gameplay, UI, RNG, save, or hook behavior changes in this migration.

`Stage-Probe.ps1` first runs the Windows PowerShell 5.1-compatible generator
into a fresh temporary directory. Only after successful generation does it
replace `dist/Local-HadesIIBoonAdvisor`; it stages the generated Intermediate,
Starter, and registry artifacts. The final staging tree has exactly 11 files.
The profile switcher now accepts a string and validates it against the
deployed generated registry's `selectionKey` metadata instead of a hard-coded
ValidateSet. To roll back, set `BUILD_PROFILE = "intermediate"`; adding a
future profile requires only canonical data, generation, and staging.

## Generic Aspect Setup Synergy (Phase 6B)

`ASPECT_SETUP_SYNERGY` is a generic, data-driven scoring primitive for an
explicitly verified effect that improves execution, frequency, reliability,
positioning, or completion of an aspect mechanic without directly amplifying
that aspect's proc. It has weight `4`, the same conservative magnitude as the
existing compatible/setup rules. It is not inferred from use of Attack,
Special, Cast, or Omega alone.

Canonical `aspectInteractions` accepts either one interaction code or an
ordered array of codes. The engine deduplicates that array before scoring; a
direct and setup reason coexist only when both codes are explicitly declared.
Existing profiles declare no setup interaction in this phase, so their
runtime scoring behavior is unchanged. The UI renders the generic French
label `Setup` within the existing two-label limit. No Morrigan profile,
template, registry entry, or runtime behavior is introduced by this schema
preparation.

## Sister Blades / Aspect of Morrigan Mechanics Template (Phase 6C-A)

The standalone canonical template `sister_blades_morrigan` records the
mechanics of `WeaponDagger` with `DaggerTripleAspect`; it is not a build
profile and is not selectable at runtime. The template explicitly sets
`genericCoreAspectCompatibility = false`: an Attack or Special boon does not
gain generic aspect compatibility merely because its hit helps complete Blood
Triad.

Blood Triad requires `ComboAttackIndicator`, `ComboSpecialIndicator`, and
`ComboExIndicator` on one target, then launches `WomboStrike`. Its verified
base formula is `111 * (AspectRankMultiplier + WomboDamageBonusMultiplier)`;
rank multipliers are Common 3, Rare 4, Epic 5, Heroic 6, Legendary 7, and
Perfect 9. The proc uses neither Vulnerability nor normal global modifiers,
while the contributing hits remain normal hits. `WeaponUpgradeBoon` is the
explicit direct aspect interaction because `UpgradeAspect` advances that rank.

The template distinguishes direct proc amplification (Phantom Brand and
Banshee Brand), combo setup support (Sinister Pinion), and contributing-hit
damage (Sweeping Ambush). Those Hammer facts are recorded in canonical aspect
mechanics only: no `hammerRoles` or scoring reason is inferred without a
separate supported scoring relationship. Generic status knowledge is copied
because it describes game traits rather than the Melinoë aspect; Origination
can affect contributing hits, never `WomboStrike` itself. At that historical phase the runtime registry contained only `intermediate`
and `starter`; the active registry now includes Morrigan.

## Origination Status Knowledge Completion (Phase 6E.2)

The Origination completeness gap was a data-knowledge issue, not a scoring
issue. `HeraManaBoon` remains `FILL_EMPTY_UTILITY_CORE +4` plus
`BUILD_CORE_PRIORITY +4`, for a base score of `8`; `ApolloManaBoon` remains
`4 + 2 = 6`. Local trait and effect scripts prove that the audited support
traits without a direct vulnerability application are known non-status traits.
They now resolve to `StatusKnowledge=known_non_status` and
`OriginationEnable=false` when Origination is active, so they no longer emit
`ORIGINATION_UNRESOLVED`. No new status mapping was inferred: `CanIgnite` is
not `BurnEffect`, and `ManaRestoreDamageBoon` consumes an existing
`DamageShareEffect` rather than applying one.

The same aspect-independent known-non-status inventory is present in both
canonical mechanics templates. `ScoringEngine.lua` and `UI.lua` are unchanged;
the existing completeness gate remains authoritative for genuinely unknown
traits.

## Morrigan Meta Build Profile (Phase 6C-B)

`morrigan_meta` is the first selectable Morrigan profile. It references the
Morrigan mechanics template and contains build preference only: Hera Attack,
Poseidon Cast, Hera Gain, Apollo Sprint, Attack alternatives Apollo/Hestia/
Demeter, and flexible Zeus/Ares/Hephaestus Special choices. Premium Service
keeps its mechanical direct-proc reason; the current slot-only plan schema has
no separate support-trait priority field, so no duplicate build reason is
invented. Beach Ball and the sheet's unspecified on-hit Special support are
omitted because their internal IDs were not established. Runtime validation of
Morrigan gameplay remains pending the aspect unlock.

### Generic max-resource semantic

`HealthRewardBonusBoon` is the first generic semantic trait implemented from
canonical mechanics. Its native effect is permanent and unconditional: it
raises maximum Health and maximum Mana by the same rarity-scaled percentage
(15%, 20%, 25%, 30%). Runtime scoring deliberately represents this with the
fixed `MAX_RESOURCE_SUPPORT = 2` reason; the existing `RARITY` rule remains
separate. The trait is already `known_non_status`, so Origination remains
resolved without an unresolved-status reason. No snapshot extension is
required. `HighHealthOffenseBoon` remains intentionally unresolved for the
next phase.

`HighHealthOffenseBoon` is now represented by the generic
`HIGH_HEALTH_OFFENSE = 2` semantic. Its native threshold is inclusive at
80%; current health is diagnostic only and never changes the structural
score. WomboStrike remains excluded because its native projectile uses
`IgnoreAllModifiers=true`; normal contributing hits may still benefit. No
Morrigan penalty is inferred.

### Poseidon Special and Morrigan

Native data verifies that `PoseidonSpecialBoon` creates a separate
`PoseidonSplashSplinter`. Under `DaggerTripleAspect`, the charged Dagger
Special receives the native 0.12-second splash cooldown condition, allowing
additional splash opportunities across its multihit projectiles. The splash
does not create `ComboSpecialIndicator`, modify `WomboStrike`, or receive
Wombo damage credit; the original Special hit remains the Blood Triad
contributor. No dedicated Hammer interaction was established.

This mechanic is documented but deliberately receives no Aspect or Setup
score: its relative value against the Morrigan profile's preferred Specials
has not been quantitatively calibrated. `PoseidonSpecialBoon` is therefore
shared `known_non_status` data only, with no status mapping or profile
preference change.

### Lightning Vulnerability Duo and Morrigan

Native `TraitData_Duo.lua` defines `LightningVulnerabilityBoon` as an
outgoing-damage modifier for the Zeus projectile set
(`ZeusEchoStrike`, `ZeusCastStrike`, `ZeusRootStrike`, `ZeusSprintStrike`,
`ProjectileZeusSpark`, `ZeusZeroManaStrike`, and `ZeusRetaliateStrike`). The
modifier is `1.30` and applies `AmplifyKnockbackEffect`, whose native effect
data marks it as a vulnerability effect. `WomboStrike` is excluded because
its projectile has `IgnoreAllModifiers=true`. The native data contains no
clear/removal operation for this effect in the duo, so Froth is not consumed;
Froth's separate consumption rules must not be attributed to this boon.

The Morrigan profile exposes this mechanic only as a declarative owned-build
synergy: `LightningVulnerabilityBoon` receives `BUILD_STATUS_SYNERGY +4` when
both `PoseidonCastBoon` and `ZeusSpecialBoon` are already owned. The rule is
profile-specific, does not alter `statusMappings`, does not infer a status
from the god, and adds no Origination, Hammer, Wombo, or Melinoe scoring.

### Focus Lightning status knowledge

Native `FocusLightningBoon` reserves exactly 50 Mana through
`TraitReserveMana`. `ReserveMana` reduces the currently available Mana by
the reservation; it does not reduce `MaxMana` itself. The effective available
Mana is therefore `MaxMana` minus native reservations. The current advisor
snapshot copies `Mana` and `MaxMana`, but does not capture
`ReserveManaSources`, so the complete post-reservation state is not yet
represented.

The boon triggers `ProjectileZeusSpark` from the native
`WeaponDagger`/`WeaponDaggerThrow` primary and secondary weapon set. Morrigan
Omega Special remains `WeaponDaggerThrow` and can generate multiple sparks,
subject to the native first-hit and three-per-0.75-second cap. The spark does
not apply a vulnerability or status itself; `LightningVulnerabilityBoon` may
amplify that projectile when its separate Froth condition is met.

`FocusLightningBoon` is consequently recorded as shared
`known_non_status` knowledge in both mechanics templates. It receives no score,
Blood Triad/Wombo credit, Hammer or Aspect reason, and remains intentionally
NON ÉVALUÉ until generic Mana-reservation and spark-support mechanics can be
calibrated without guessing.

### Damage Share Potency and Morrigan

Native `DamageShareEffect` starts at 8 seconds, 30 percent shared damage and
1200 range. `DamageSharePotencyBoon` adds 5 seconds and a percentage-point
increase to future applications: +10 points Common, +15 Rare, +20 Epic and
+25 Heroic. Common therefore changes a future application to 13 seconds and
40 percent. The verified producers are `HeraWeaponBoon`, `HeraSpecialBoon`,
`HeraCastBoon` and `HeraSprintBoon`; `HeraManaBoon` is not a producer.

The Potency boon itself is `known_non_status`: it does not apply or refresh
`DamageShareEffect`, and receives no Origination credit. Its Morrigan advisor
payoff requires at least one of the four producer traits to be actually owned;
the profile plan alone is insufficient. The calibrated advisor rule is the
existing `BUILD_STATUS_SYNERGY +4`, with no Wombo, Blood Triad or Aspect credit.

`HeraWeaponBoon` is verified for normal `WeaponDagger` through
`HeroPrimaryWeapons`. Morrigan's Omega Attack uses `WeaponDagger5`, whose
inclusion through that Hera path was not demonstrated; the +4 rule must not be
read as proof that every attack form applies Damage Share.

### Echo Expiration payoff and Morrigan

Despite its name, native `EchoExpirationBoon` is Omega-triggered rather than
an expiration-only effect. `CheckOmegaBlitzTrigger` requires a valid Omega hit
and `DamageEchoEffect` in `ActiveEffectsAtDamageStart`; it forces the Echo
threshold, schedules the existing `ZeusEchoStrike` after 0.45 seconds, then
clears `DamageEchoEffect` and applies the normal 0.6-second reapplication
block. The boon supplies the additional Echo multiplier: 1.30 Common, 1.40
Rare, 1.50 Epic, 1.60 Heroic, with Pom increments +0.10, +0.05, +0.03, then
+0.02.

The verified `DamageEchoEffect` producers are exactly `ZeusWeaponBoon` and
`ZeusSpecialBoon`. `DamageEchoEffect` is Zeus `Amplify`; Poseidon's
`AmplifyKnockbackEffect` is `Froth` and is unrelated. The Morrigan advisor
records `EchoExpirationBoon` as shared `known_non_status` knowledge and awards
the profile-only calibrated `BUILD_STATUS_SYNERGY +4` only when at least one
producer is actually owned. A preference for `ZeusSpecialBoon` alone is not
ownership, and both producers still yield one reason.

The forced proc can shorten an individual enemy's Amplify uptime because the
effect is cleared immediately. No penalty is modeled because the snapshot has
no per-enemy transient state. The boon receives no Origination, Wombo, Blood
Triad, Hammer, or Aspect credit; `WomboStrike` remains
`IgnoreAllModifiers=true` and is not an Echo contributor.

### Phase 8B patch compatibility gate

`tools/Test-PatchCompatibility.ps1` checks the development build at
`<development-game-root>` in read-only mode. The validated baseline is build
139606 (`FileVersion` and `ProductVersion` 139606), executable size 6197864,
SHA-256 `DB88529B0961C41763413FC676762B9AC05CD22F9547A9305E0B629B30F2EE74`.
It also records the SHA-256 values of `LootData.lua`, `InteractLogic.lua`, and
`UpgradeChoiceLogic.lua` and verifies the semantic loot, menu, boon-button and
reroll anchors with whitespace-tolerant expressions. A complete match is
`PASS`; changed hashes or metadata with intact anchors require manual runtime
validation; missing files or broken anchors are `FAIL`. A hash mismatch alone
never constitutes incompatibility.

Phase 8C adds a project-validation layer to the same command. It runs the
canonical profile and mechanics suites, strict canonical/runtime equivalence,
deterministic generated-profile validation, Lua 5.2 regression suite, staging
fixture test, and profile-switcher test. Any such failure is `FAIL`; it can
never be downgraded to manual testing. The final status is `FAIL` if either
layer fails, otherwise `MANUAL RUNTIME TEST REQUIRED` when patch hashes differ
with intact anchors, otherwise `PASS`.

`verifiedIds` remains an internal canonical-data integrity check: non-empty,
non-duplicate IDs must survive generation into runtime profiles. It is not
proof that a name still exists in a future Hades II build. A manual runtime
test after a structurally compatible patch must confirm mod load, supported
weapon/aspect detection, initial Olympian screen and reroll rebuild detection,
ranking or fallback UI, normal boon choice/RNG behavior, and absence of Lua
runtime errors. The gate never launches the game.

### PoseidonExCastBoon status knowledge (Phase 6E.4C7.1)

Native `PoseidonExCastBoon` (`TraitData_Poseidon.lua:1586`) adds
`ArmedExpirationDamage` to the generic `WeaponCast` and installs callbacks for
an armed and detonated `ProjectileCast`. Its damage is +150/+200/+250/+300 by
rarity, with stack increments +50, +30, +20 and then +20. The native
requirement is any entry in `LinkedTraitData.CastTraits`; `PoseidonCastBoon` is
not required. The trait neither applies nor consumes `AmplifyKnockbackEffect`
(`Froth`), nor does it modify `DaggerTripleAspect` or `WomboStrike`.

An armed Cast may participate in Morrigan's generic `CheckFinisher` path as
the `ComboExIndicator` source, but that is a property of the armed Cast and
does not make `PoseidonExCastBoon` an Aspect or Blood Triad payoff. The trait
therefore remains shared `known_non_status`, receives no Origination credit,
no profile/build score, and intentionally remains NON ÉVALUÉ.

### Phase 9B installation safety architecture

Phase 9B adds PowerShell 5.1-compatible `Install-BoonAdvisor.ps1` and
`Uninstall-BoonAdvisor.ps1`, backed by a small private validation helper.
Both commands require an explicit `-GameRoot`, use `SupportsShouldProcess`, and
therefore support non-mutating `-WhatIf` validation. They only target the exact
plugin directory `Ship\ReturnOfModding\plugins\Local-HadesIIBoonAdvisor`.

Installation accepts only a staged `Local-HadesIIBoonAdvisor` directory with the
exact twelve-file Stage-Probe runtime inventory, no reparse points, and a valid
Boon Advisor manifest identity/version. It validates `Ship\Hades2.exe`, the
plugins root, required dependency manifests by token plus name/version (so the
two distinct ENVY packages cannot be confused), and `Ship\d3d12.dll`. The
known loader hash is reported as validated; another hash is reported only as
loader-present-but-unverified and is never assigned an invented version.

The patch compatibility gate runs before installation mutation. PASS may
continue; MANUAL RUNTIME TEST REQUIRED and FAIL both refuse installation. A
candidate directory is created as a uniquely named sibling, copied from the
validated package using only the expected files, revalidated, and moved to the
exact target. An existing target is refused pending the future Update command.
Uninstall validates the requested root and running-game state, then removes
only the exact target; a missing target is a successful no-op. No command
modifies game content, executables, shared dependencies, other plugins, or
saves.

### Phase 9C transactional update architecture

`Update-BoonAdvisor.ps1` performs the same Phase 9B preflight before any
mutation: explicit game-root validation, running-game refusal, exact package
contract, dependency and loader checks, and a PASS-only compatibility gate. It
requires an existing, safely resolved Boon Advisor installation with a valid
Advisor manifest, but deliberately does not require the old installation to
match the current twelve-file inventory; older stale Advisor files are removed
by replacement.

When present as a normal non-linked file, the installed `config\settings.lua`
is copied as bytes without parsing or normalization. The update first builds
and validates a unique sibling candidate, then renames the active target to a
unique sibling backup, moves the candidate to the exact target, verifies the
new package and preserved settings bytes, and only then removes the backup.
Any failure after the backup move removes a failed new target and restores the
backup directory itself, including stale legacy files and the original config.
If restoration fails, both the update and rollback errors are surfaced and the
backup is retained. V1 keeps no persistent rollback history. `-WhatIf` runs
preflight only and creates neither candidate nor backup.

### Phase 9D compatibility modes

`tools\Test-PatchCompatibility.ps1` exposes `-Mode Runtime|Full` and defaults
to `Full` for developer and project validation. `Runtime` checks only the
installed Hades II executable and the three native script anchors, returning
the existing PASS, MANUAL RUNTIME TEST REQUIRED, or FAIL status without
running Python, Lua, canonical-data, generated-profile, or other project
tests. `Full` retains the complete developer validation path, including the
explicit Python and Lua 5.2 inputs when required.

Install and Update invoke the gate explicitly with `-Mode Runtime`; their
public interfaces no longer expose Python or Lua paths. This keeps release
packages independent of repository-only assets while preserving the existing
PASS-only mutation policy and the separate Full validation command for
developers.

### Sister Blades Melinoë Intermediate (Community Audit V2 reconciliation)

The active Intermediate profile has four exclusive, audited Attack branches:
`AphroditeWeaponBoon`, `ApolloWeaponBoon`, and `HestiaWeaponBoon` are
alternative priority 1; `AresWeaponBoon` is conditional priority 2 with
`WOUNDS_ACCESS` unresolved. Priority is ordinal/documentary and adds no
numeric score. Ares can be recognized but is score-incomplete and cannot be
ranked until the condition has a verified native predicate. Replacements to,
from, or within that unresolved branch remain incomplete. No Wounds predicate
is inferred from Curse, AresStatus, or SharedVulnerabilityCategory.

`ZeusSpecialBoon` remains the Special core. Cast, Sprint, and Mana have no
profile slot plan (`NO_PLAN`); this absence does not create a `NON_TARGET`
policy penalty. The five verified nonconditional Sister Blades Hammers remain
in `hammerPlan`; `DaggerSpecialJumpTrait` (Dancing Knives) stays outside the
evaluable plan. No Hammer exclusion or reroll behavior is inferred.

Only Intermediate remains compatible with `WeaponDagger` and
`DaggerBackstabAspect` in the active registry, so auto resolves it as
`only_candidate` without using current offers or treating Cloud Bangle or
Sword Hilt as exclusive evidence. An installed `BUILD_PROFILE = "starter"` is
not rewritten: the mod emits one WARN and uses auto for that session. The
profile switcher does not offer Starter. Morrigan and Black Coat mechanics
are unchanged; Black Coat still requires its separate Community Audit.
