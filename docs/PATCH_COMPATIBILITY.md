# Hades II Patch Compatibility

`Test-PatchCompatibility.ps1` has two modes.

## Runtime

Install and Update automatically use `-Mode Runtime`. It checks the Hades II executable, critical scripts, and structural anchors required by the mod. It does not require Python, the Lua test runtime, canonical data, or developer-repository tests.

Results:

- `PASS`: installation or update may continue.
- `MANUAL RUNTIME TEST REQUIRED`: the operation is refused conservatively; this does not prove incompatibility.
- `FAIL`: a known structural check failed; the operation is refused.

V1 has no `Force` bypass.

## Full

`Full` is the developer/release mode and the default when the script runs directly without `-Mode`. It adds project validation, canonical validation, deterministic generation, and the implemented Lua 5.2/equivalence tests to the Runtime checks.

```powershell
.\tools\Test-PatchCompatibility.ps1 `
    -Mode Full `
    -GameRoot "<Hades-II-root>" `
    -PythonPath "C:\Path\To\python.exe" `
    -LuaDllPath "<Hades-II-root>\Ship\lua52.dll"
```

End users do not need to run Full mode.
