# Désinstaller Hades II Boon Advisor

## Recommandé : Thunderstore et r2modman

Supprimez **Hades II Boon Advisor** depuis r2modman/Thunderstore.

## Désinstallation manuelle

Fermez Hades II, puis supprimez uniquement :

```text
<Hades-II-root>\Ship\ReturnOfModding\plugins\Local-HadesIIBoonAdvisor
```

Ne retirez pas Hell2Modding ou les dépendances partagées avec d'autres mods.
Cette opération ne touche ni aux fichiers Hades II hors de ce dossier ni aux
sauvegardes.

## Avancé : PowerShell

Les utilisateurs avancés peuvent prévisualiser puis effectuer la même
suppression contrôlée avec :

```powershell
.\tools\Uninstall-BoonAdvisor.ps1 -GameRoot "<Hades-II-root>"
.\tools\Uninstall-BoonAdvisor.ps1 -GameRoot "<Hades-II-root>" -WhatIf
```
