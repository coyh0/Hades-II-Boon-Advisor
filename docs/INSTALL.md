# Installer Hades II Boon Advisor

## Recommandé : Thunderstore et r2modman

Installez **Hades II Boon Advisor** dans r2modman depuis Thunderstore. Le
gestionnaire installe le mod et ses dépendances déclarées dans le bon dossier
ReturnOfModding.

## Installation manuelle : ZIP minimal

1. Fermez Hades II et vérifiez que Hell2Modding et les dépendances déclarées
   dans `manifest.json` sont déjà installés.
2. Téléchargez et extrayez `Hades-II-Boon-Advisor-v<VERSION>.zip`.
3. Copiez le dossier unique `Local-HadesIIBoonAdvisor` dans :

```text
<Hades-II-root>\Ship\ReturnOfModding\plugins\
```

Aucun PowerShell ni connaissance du dépôt n'est nécessaire. La configuration
du mod est ensuite dans `config\settings.lua` sous ce dossier.

## Avancé : outils PowerShell

Les outils du dépôt sont destinés aux installations contrôlées, diagnostics et
mises à jour transactionnelles. Ils ne sont pas le workflow recommandé aux
joueurs. `GameRoot` est le dossier qui contient `Ship\Hades2.exe` et
`PackagePath` est un dossier extrait `Local-HadesIIBoonAdvisor`.

```powershell
.\tools\Install-BoonAdvisor.ps1 `
    -GameRoot "<Hades-II-root>" `
    -PackagePath ".\Local-HadesIIBoonAdvisor"
```

Ajoutez `-WhatIf` pour prévisualiser l'opération sans écrire. La vérification
de compatibilité Runtime doit produire `PASS`; `MANUAL RUNTIME TEST REQUIRED`
et `FAIL` refusent l'installation. Les outils ne téléchargent ni
Hell2Modding ni les dépendances.
