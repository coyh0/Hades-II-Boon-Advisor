# Update Hades II Boon Advisor

## Thunderstore and r2modman

Update the package from r2modman/Thunderstore. On one tested Epic Games installation, Thunderstore Mod Manager/r2modman installed the `ReturnOfModding` files inside its profile but did not copy them into the game's actual `ReturnOfModding` directory. If the mod does not appear in game, compare the active profile's `ReturnOfModding` directory with:

```text
<Hades-II-root>\Ship\ReturnOfModding\
```

and, if necessary, copy the profile's `ReturnOfModding` contents there manually while Hades II is closed. This is an observed workaround, not a universal manager rule.

## Manual update: minimal ZIP

Close Hades II, extract the new `Hades-II-Boon-Advisor-v<VERSION>.zip`, then replace only:

```text
<Hades-II-root>\Ship\ReturnOfModding\plugins\Local-HadesIIBoonAdvisor
```

A manual replacement can reset configuration. Preserve `config\settings.lua` if you want to keep settings such as `BUILD_PROFILE = "auto"` or an explicit profile preference.

## Advanced: transactional PowerShell update

Advanced users can preserve `config\settings.lua` byte-for-byte and receive a rollback on failure with:

Preview the operation first:

```powershell
& .\tools\Update-BoonAdvisor.ps1 `
    -GameRoot "<Hades-II-root>" `
    -PackagePath ".\Local-HadesIIBoonAdvisor" `
    -WhatIf
```

After reviewing the preview and confirming that Hades II is closed, use the
verified Windows PowerShell 5.1 invocation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& .\tools\Update-BoonAdvisor.ps1 -GameRoot '<Hades-II-root>' -PackagePath '.\Local-HadesIIBoonAdvisor' -Confirm:`$false"
```

`-Confirm:$false` suppresses the interactive confirmation prompt; it does not
bypass package validation, the compatibility gate, the stopped-game check, or
transactional rollback. Keep a backup before updating. The tool requires
Runtime compatibility `PASS` before writing.
