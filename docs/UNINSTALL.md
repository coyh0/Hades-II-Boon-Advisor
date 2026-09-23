# Uninstall Hades II Boon Advisor

## Thunderstore and r2modman

Remove **Hades II Boon Advisor** through r2modman/Thunderstore. If you used the observed Epic Games manual-copy workaround, also remove the copied game-folder plugin directory below.

## Manual uninstall

Close Hades II, then remove only:

```text
<Hades-II-root>\Ship\ReturnOfModding\plugins\Local-HadesIIBoonAdvisor
```

Do not remove Hell2Modding or dependencies shared with other mods. This does not change Hades II files outside that directory or any save data.

## Advanced: PowerShell

Advanced users can preview and perform the same controlled removal:

```powershell
.\tools\Uninstall-BoonAdvisor.ps1 -GameRoot "<Hades-II-root>"
.\tools\Uninstall-BoonAdvisor.ps1 -GameRoot "<Hades-II-root>" -WhatIf
```
