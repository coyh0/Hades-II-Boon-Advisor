# Install Hades II Boon Advisor

## Recommended: Thunderstore and r2modman

Install **Hades II Boon Advisor** from Thunderstore through r2modman. The manager installs the package and declared dependencies into its own profile.

On one tested Epic Games installation, Thunderstore Mod Manager/r2modman installed the `ReturnOfModding` files inside its profile but did not copy them into the game's actual `ReturnOfModding` directory. If the mod does not appear in game, compare the active profile's `ReturnOfModding` directory with:

```text
<Hades-II-root>\Ship\ReturnOfModding\
```

and, if necessary, copy the profile's `ReturnOfModding` contents there manually while Hades II is closed. This is an observed workaround, not a universal manager rule.

## Manual install: minimal ZIP

1. Close Hades II. Confirm that Hell2Modding and the dependencies declared in `manifest.json` are already installed.
2. Download and extract `Hades-II-Boon-Advisor-v<VERSION>.zip`.
3. Copy the single `Local-HadesIIBoonAdvisor` directory to:

```text
<Hades-II-root>\Ship\ReturnOfModding\plugins\
```

This workflow needs neither PowerShell nor a repository checkout. The mod configuration is `config\settings.lua` inside that directory. Its default is `BUILD_PROFILE = "auto"`.

## Advanced: PowerShell tooling

Repository PowerShell tools support controlled installation, diagnostics, and transactional updates. They are intended for advanced users. `GameRoot` is the directory containing `Ship\Hades2.exe`; `PackagePath` is an extracted `Local-HadesIIBoonAdvisor` directory.

```powershell
.\tools\Install-BoonAdvisor.ps1 `
    -GameRoot "<Hades-II-root>" `
    -PackagePath ".\Local-HadesIIBoonAdvisor"
```

Use `-WhatIf` to preview without writing. Runtime compatibility must report `PASS`; `MANUAL RUNTIME TEST REQUIRED` and `FAIL` refuse installation. The tools do not download Hell2Modding or dependencies.
