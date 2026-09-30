# Procédure des checklists de QA runtime

Cette procédure s'applique à chaque nouvelle demande de QA runtime du projet.

## Workflow with maintainer approval

1. When the roadmap or an approved development report reaches a human runtime QA gate, prepare a dedicated checklist from the approved scope and acceptance criteria.
2. Present the complete checklist and proposed QA Manager analysis scope to the maintainer. Obtain explicit approval before runtime QA begins.
3. The maintainer performs the in-game QA, completes the checklist, and provides the evidence to MAIN.
4. After receiving the completed checklist and evidence, MAIN may request read-only QA Manager analysis within the scope already approved for QA, without seeking a second approval.
5. Obtain new approval before expanding the analysis scope. Provide the QA Manager with the checklist path, approved scope, evidence locations, and log path.

Creating a checklist or approving QA Manager analysis does not authorize runtime QA, tests, deployment, or code changes. The maintainer's explicit approval authorizes runtime QA only within the stated scope. After the evidence is supplied, MAIN may request read-only QA Manager analysis within that same scope without a second approval; expanding the scope requires new approval.

## Emplacement et nommage

- Créer une checklist Markdown dédiée sous `<PROJECT_ROOT>\docs\qa`.
- La nommer `QA_Runtime_Etape-<lettre>_<sujet-court>.md`.
- Mettre le nom de l'étape et le sujet testé dans le titre du document.
- Conserver les captures d'écran de QA sous `<PROJECT_ROOT>\docs\qa\images`, avec un nom qui identifie l'étape ou le scénario.

## Contenu de la checklist

- Indiquer le jeu QA (`<HADES_II_DEV_ROOT>`) et le chemin du mod déployé. Ne jamais créer un dépôt source sous la racine du jeu QA.
- Découper la QA en étapes lisibles, avec des vérifications concrètes et distinctes.
- Pour chaque vérification, fournir trois cases Markdown indépendantes, placées en sous-liste :

  ```markdown
  - [ ] PASS
  - [ ] FAIL
  - [ ] NOT TESTABLE
  ```

- Demander de cocher exactement une case par vérification. Si la vérification n'a pas pu être effectuée, choisir `NOT TESTABLE`.
- Laisser toutes les cases décochées dans une nouvelle checklist. Ne pas préjuger du résultat ; les résultats connus d'une checklist existante ne sont conservés que lors d'une régénération à la demande.
- Prévoir une zone de notes/preuves par étape et les détails utiles du build testé.

Les cases doivent être de vraies cases de tâche Markdown, afin d'être cochables dans MarkText. Le format ne rend pas les choix mutuellement exclusifs : l'utilisateur coche un seul statut manuellement.

## Rôles et limites

- L'assistant qui prépare la QA crée la checklist avec ce format et un nom de fichier explicite.
- L'utilisateur réalise la QA dans le jeu et renseigne les statuts et les preuves.
- Le QA Manager peut analyser les checklists, captures et logs en lecture seule et produire un rapport. Il ne modifie aucun fichier et ne lance ni jeu, ni test, ni déploiement.
- La création d'une checklist ne déclenche pas de test, de lancement du jeu ou de déploiement.

## Chemins de référence

- Dépôt source : `<PROJECT_ROOT>`
- Jeu QA : `<HADES_II_DEV_ROOT>`
- Checklists et preuves QA : `<PROJECT_ROOT>\docs\qa`
- Captures : `<PROJECT_ROOT>\docs\qa\images`
- Log runtime principal : `<HADES_II_DEV_ROOT>\Ship\ReturnOfModding\LogOutput.log`

Le dépôt source est distinct de la racine du jeu QA. Ne jamais créer le dépôt source sous `<HADES_II_DEV_ROOT>`.
