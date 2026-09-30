# Runtime attestation catalog validation

The catalog validation is a development-only check. It does not connect the
catalog to the importer, profile generator, active profiles, or runtime.

## Requirements

- CPython 3.10 or newer, installed for the developer (not supplied by Codex or
  another application runtime).
- Windows PowerShell 5.1 or newer.

`requirements-dev.txt` pins `jsonschema==4.26.0`. That release supports Python
3.10 and newer. The dependency is installed only in the repository-local
`.venv`; it is not installed globally. `.venv` is ignored by Git.

## Create or refresh the project environment

Run these commands from the repository root in PowerShell:

```powershell
python --version
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install --requirement requirements-dev.txt
```

If the `python` command is unavailable, install CPython 3.10+ from the official
Python distribution and enable its command-line launcher/PATH option, then
repeat the commands. Do not install `jsonschema` globally.

## Run catalog tests and validation

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\runtime_attestations_spec.ps1
```

The test entry point requires the project `.venv`. It fails with setup guidance
if the environment is missing, and the Python validator fails explicitly if
`jsonschema` is unavailable. It never substitutes JSON parsing or custom checks
for formal JSON Schema validation.

The Python test suite checks Draft 2020-12 schema validity, validates the
committed catalog with `FormatChecker`, and exercises semantic safeguards:
unique IDs, exact/case-sensitive references, bidirectional evidence links,
evidence-kind compatibility, allowed statuses, rejection of build-specific
fields, proof requirements for external-name mappings, and the exact
`TrialUpgrade` pair allowlist.

## Direct validator invocation

```powershell
.\.venv\Scripts\python.exe .\tools\validate_runtime_attestations.py
```

Optional `--catalog` and `--schema` paths allow validation of isolated fixtures.
The validator is deliberately not called by the importer or profile generator
in this phase.
