# Étape A — QA runtime ciblée du cleanup Focus/Route + Black Coat

Nom du fichier : `QA_Runtime_Etape-A_Cleanup-Focus-Route-Black-Coat.md`

**Jeu QA :** `<HADES_II_DEV_ROOT>`<br>
**Mod déployé :** `Ship\ReturnOfModding\plugins\Local-HadesIIBoonAdvisor`
`DEBUG = true` est conservé pour faciliter la lecture des logs.

**État de préparation :** le plugin QA installé a été comparé en lecture seule au dépôt source et ses 16 fichiers payload correspondent par SHA-256. Ce contrôle confirme l'intégrité du déploiement, pas un résultat de QA runtime. Aucun redéploiement n'est requis tant que ces fichiers source ne changent pas.

**Périmètre de build et sauvegarde :** les builds importés fixent explicitement les Core et Non-Core Boons; aucun changement dynamique de route n'est attendu. Le build source actuel est Mobalytics; le futur Curator / import unifié Excel n'est pas encore une dépendance active. Toutes les armes et tous les Aspects réguliers sont disponibles dans la sauvegarde QA; parmi les Aspects cachés, seul Morrigan est débloqué. Ne modifie pas directement la sauvegarde et ne manipule pas ses déblocages; les scénarios nécessitant un autre Aspect caché sont `NOT TESTABLE`.

Pour chaque vérification, coche exactement une case : **PASS**, **FAIL** ou **NOT TESTABLE**. Laisse les deux autres décochées. Si tu n’as pas pu effectuer la vérification, coche **NOT TESTABLE**. Ajoute une note ou une preuve si utile.

## A.1 — Chargement du jeu et du mod

- Hades II démarre depuis la copie QA
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE
- Boon Advisor se charge
  - [x] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE
- Aucune erreur Lua ne mentionne `FocusState`, une fonction Focus/Route manquante ou un module introuvable
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE

**Notes / preuves :**

## A.2 — HUD du build et absence de l’ancienne interface

- Le HUD affiche les informations du build actif
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE
- Aucune ancienne interface Focus/Route ne s’affiche : bouton, label ou rappel
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE
- Un build pris en charge, Médée ou Moonstone, est reconnu
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE
- Les recommandations et le scoring apparaissent correctement sur une offre
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE

**Build testé / notes / preuves :**

## A.3 — Changement de room et hook `StartRoom`

- Après un changement de room, le jeu continue normalement
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE
- Le HUD du build reste correct ou se rafraîchit normalement
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE
- Aucune erreur `StartRoom` ou UI n’apparaît dans les logs
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE

**Notes / preuves :**

## A.4 — `LobbyProbe`

- Les entrées `LobbyProbe` apparaissent normalement dans les logs
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE
- Elles ne s’accompagnent pas d’erreurs ou d’un comportement inattendu
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE

**Notes / preuves :**

## A.5 — Contrôle Black Coat facultatif

À vérifier uniquement si Black Coat est accessible naturellement. Ne recrée pas les anciens profils retirés.

- Aucune ancienne branche Black Coat supprimée ne provoque d’erreur
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE
- Le moteur générique continue de fonctionner normalement
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE

**Notes / preuves :**

## A.6 — Vérification finale des logs

- Aucun message d’erreur Lua
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE
- Aucune référence runtime à Focus/Route
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE
  - Note d'interprétation : vérifier uniquement l'ancienne fonctionnalité retirée (`FocusState`, `BoonAdvisorFocus`, ancien sélecteur/bouton/rappel Focus, ou branche de sélection de route). Ne pas échouer pour des identifiants de boons légitimes contenant `Focus` (par exemple `FocusLightningBoon` ou `FocusDamageShaveBoon`) ni pour le nettoyage `UI.clearFocus` des anciens composants UI.
- Aucune erreur de scoring, de profil, de `StartRoom` ou d’UI
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE

**Log consulté / notes / preuves :**
