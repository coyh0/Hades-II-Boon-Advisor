$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$python = Join-Path $repo '.venv\Scripts\python.exe'
$test = Join-Path $PSScriptRoot 'runtime_attestations_spec.py'
$validator = Join-Path $repo 'tools\validate_runtime_attestations.py'

if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    throw "Project Python environment is missing. Follow docs/ATTESTATION_CATALOG_VALIDATION.md to create .venv and install requirements-dev.txt."
}

& $python $test
if ($LASTEXITCODE -ne 0) { throw "Runtime attestation catalog tests failed (exit=$LASTEXITCODE)." }
& $python $validator
if ($LASTEXITCODE -ne 0) { throw "Runtime attestation catalog validation failed (exit=$LASTEXITCODE)." }
