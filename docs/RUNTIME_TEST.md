# Validation runtime et procédure d'installation

Statut : **validation DEV représentative effectuée sous contrôle humain** pour
les trois profils v0.2. Les captures et le journal DEBUG ont confirmé les
profils, identifiants, scores et replis full/partial/none observés. La
validation a utilisé le profil Windows principal `Profile1` avec les
sauvegardes cloud activées, contexte accepté par le mainteneur ; elle ne doit
pas être décrite comme un test isolé.

La procédure d'isolation ci-dessous reste la méthode recommandée pour un
nouveau test reproductible. Elle décrit des contrôles de sécurité et ne
constitue pas une étape restante de la validation v0.2 déjà effectuée.

## 1. Préconditions de sauvegarde

Le journal existant `<primary-user-profile>\Saved Games\Hades II\Hades II.log:32` charge explicitement ce dossier et `Profile1`. Les fichiers `.sav`, `.bak`, `.sjson`, `activeProfile`, `cloud.cache` y sont présents. Le journal signale l'activation des sauvegardes cloud. Le déplacer ou choisir un autre slot n'est pas une isolation suffisante.

Méthode retenue pour un premier test : un **compte Windows local de test distinct**, sans connexion Epic/Steam/Nintendo ni synchronisation cloud, avec un nouveau profil Hades II. Aucun argument supposé de redirection de sauvegarde n'est utilisé.

1. Fermer Hades II et attendre la fin de la synchronisation du launcher principal, puis fermer ce launcher.
2. Sauvegarder **tout** `<primary-user-profile>\Saved Games\Hades II` vers un nouveau dossier daté hors des installations du jeu. Faire une copie, jamais un déplacement. Comparer noms, tailles et SHA-256 entre originaux et copies ; ne pas se limiter à `Profile1.sav`. Aucune sauvegarde n'a été copiée ou modifiée pendant le présent travail.
3. Ouvrir une session Windows locale de test distincte. Ne pas simplement changer `USERPROFILE` dans une console : cela ne change pas les Known Folders Windows ni l'identité réelle du processus.
4. Vérifier que ce compte ne peut pas écrire dans le dossier de sauvegardes principal et qu'aucune jonction ne renvoie son dossier Saved Games vers celui du compte principal. Les permissions doivent être contrôlées avant le lancement, pas déduites du nom du compte.
5. Effectuer d'abord un lancement **non moddé** de `<development-game-root>\Ship\Hades2.exe`, depuis `Ship`, sous ce compte de test. Vérifier dans le nouveau journal la ligne `Loading default profile` : elle doit pointer vers le Saved Games du compte de test. Si le lancement exige une connexion au compte principal, arrêter et réexaminer l'isolation.
6. Fermer le jeu. Vérifier que les empreintes et dates des sauvegardes principales n'ont pas changé. Le nouveau profil du compte test sera jetable ; ne pas importer la sauvegarde principale pour ce premier essai.

**UNVERIFIED ici :** compte de test, permissions effectives, lancement direct de la copie et chemin sous ce compte. Ces vérifications sont des gates avant le test moddé. Si elles échouent, ne pas continuer les étapes suivantes.

## 2. Installation manuelle, uniquement dans la copie de développement

Les packages exacts et leurs SHA-256 sont dans [STACK_LOCK.json](STACK_LOCK.json). Télécharger chaque archive depuis `https://thunderstore.io/package/download/<namespace>/<name>/<version>/`, selon les noms/version du lock. Le template 0.10.0 n'est pas une dépendance à installer.

1. Jeu fermé, vérifier une dernière fois la cible : `<development-game-root>\Ship`. Ne rien déposer dans `<production-game-root>`.
2. Extraire `d3d12.dll` du package **Hell2Modding-Hell2Modding-1.0.112** à côté de `Hades2.exe`, selon le README officiel. Ne pas prendre la release GitHub `nightly`, qui est mutable.
3. Lancer puis fermer la copie sous le compte test isolé pour que le chargeur initialise son environnement. Vérifier son journal et la version 1.0.112. Le chemin exact du fichier de log généré doit être relevé à ce moment, pas supposé.
4. Dans `Ship\ReturnOfModding\plugins`, déployer chaque dépendance Lua du lock dans son dossier `Namespace-Name`, avec son `main.lua` à la racine de ce dossier. Pour les archives téléchargées et inspectées ici, les fichiers Lua sont à la racine du ZIP. Garder leurs fichiers associés et leur manifeste ; ne pas mettre deux versions du même package côte à côte. `SGG_Modding-ENVY` et `LuaENVY-ENVY` sont deux identifiants réellement requis par les sources inspectées, pas deux versions à fusionner.
5. Depuis le repository, exécuter `powershell -NoProfile -File .\tools\Stage-Probe.ps1`. Cela prépare seulement `dist\Local-HadesIIBoonAdvisor` dans le repository.
6. Copier ce dossier préparé dans `Ship\ReturnOfModding\plugins\Local-HadesIIBoonAdvisor`. Vérifier la structure :

```text
Local-HadesIIBoonAdvisor/
  manifest.json
  main.lua
  Logger.lua
  config/settings.lua
```

Ce déploiement local suit le point d'entrée `main.lua` du template et l'import relatif ENVY. Ce n'est pas un ZIP de publication Thunderstore ; ni icône, ni workflow de release, ni compte éditeur n'est nécessaire pour cette sonde locale. Aucune publication n'est prévue. Le script ne réalise volontairement pas le déploiement dans le jeu.

## 3. Validation de la sonde

1. Lancer la copie modifiée sous le compte test. Confirmer dans les logs que toutes les dépendances du lock chargent sans erreur. Arrêter en cas de dépendance manquante ou de version inattendue.
2. Après chargement des scripts du jeu, chercher exactement une ligne `[BoonAdvisor] Hook installed: CreateBoonLootButtons` et le marqueur `Probe ready; hook count=1`. Ce compteur est l'état revendiqué par la sonde, **pas une preuve indépendante** d'absence de wrapper tiers.
3. Atteindre normalement une offre d'une des neuf sources supportées. Avant toute sélection, constater une seule paire :

```text
[BoonAdvisor] CreateBoonLootButtons detected
[BoonAdvisor] Source=<ID interne de la source>
```

4. Choisir manuellement : acquisition et fermeture doivent rester normales. Aucun nouvel élément graphique ni ID de boon n'est ajouté.
5. Si un reroll est disponible naturellement sur le profil test, l'utiliser : une seule nouvelle paire, sans seconde installation de hook. Sinon marquer ce cas **non testé**, sans modifier la sauvegarde ou forcer les ressources.
6. Tester un Pom, un Marteau et, quand accessibles, Hermès, Chaos et un événement : aucune paire de détection attendue. Ouvrir/fermer le Codex : aucune paire attendue. Ne pas prétendre valider les cas non rencontrés.
7. Rechargement : faire une modification de commentaire dans le `main.lua` **déployé**, puis attendre une confirmation de rechargement du chargeur. Attendre un nouveau `Probe ready` sans nouveau `Hook installed`. Si le chargeur ne confirme aucun reload, le cas reste **UNVERIFIED** ; ne pas interpréter son silence comme un succès. Au choix suivant, une seule paire. Ne pas recharger ModUtil/ReLoad/ENVY pendant cet essai : le redémarrage complet est requis si une dépendance change.
8. Mettre `DEBUG = false` dans le fichier de configuration déployé puis relancer la copie : aucune ligne BoonAdvisor. Pour un essai à chaud, le changement de configuration doit être suivi d'un rechargement confirmé du point d'entrée ; la configuration seule n'est pas surveillée par Chalk.
9. Fermer le jeu et relever les résultats : versions, chemin du profil test, source, heure de détection avant sélection, reroll/reload, menus exclus, erreurs éventuelles. Revérifier les empreintes des sauvegardes principales.

La première sonde n'observe pas les changements individuels de rareté et n'inspecte pas `UpgradeOptions`. Aucun passage à la Phase 2 avant validation réelle de cette procédure.

## 4. Tests hors jeu déjà effectués

Depuis le repository :

```powershell
& '<python-executable>' tests\run_lua52.py '<development-game-root>\Ship\lua52.dll'
```

Le lanceur ouvre un état Lua isolé avec la DLL existante ; il ne lance pas Hades II et ne charge aucun script du jeu. Les interfaces de ModUtil/ENVY/ReLoad sont remplacées dans le test par des doubles explicitement limités. Les assertions valident le code de la sonde, **pas** l'intégration des vrais frameworks. Résultat : PASS sur arguments inchangés, retours multiples/zéro/`nil`, propagation des erreurs natives, erreur de diagnostic/logger, exclusion des menus, garde de reload et attente coroutine.
