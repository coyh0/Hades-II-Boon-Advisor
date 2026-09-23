# Mettre à jour Hades II Boon Advisor

## Recommandé : Thunderstore et r2modman

Mettez le mod à jour depuis r2modman/Thunderstore. Le gestionnaire applique la
nouvelle version et ses dépendances déclarées.

## Mise à jour manuelle : ZIP minimal

Fermez Hades II, extrayez le nouveau
`Hades-II-Boon-Advisor-v<VERSION>.zip`, puis remplacez uniquement :

```text
<Hades-II-root>\Ship\ReturnOfModding\plugins\Local-HadesIIBoonAdvisor
```

Une copie manuelle peut réinitialiser votre configuration. Préservez
`config\settings.lua` vous-même si vous souhaitez conserver vos réglages.

## Avancé : mise à jour transactionnelle PowerShell

Pour une préservation byte à byte de `config\settings.lua` et un rollback en
cas d'échec, les utilisateurs avancés peuvent employer l'outil du dépôt :

```powershell
.\tools\Update-BoonAdvisor.ps1 `
    -GameRoot "<Hades-II-root>" `
    -PackagePath ".\Local-HadesIIBoonAdvisor"
```

Ajoutez `-WhatIf` pour prévisualiser. L'outil valide le package et exige une
compatibilité Runtime `PASS` avant toute écriture.
