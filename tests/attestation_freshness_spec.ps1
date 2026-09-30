$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$python = Join-Path $repo '.venv\Scripts\python.exe'
$test = Join-Path $PSScriptRoot 'attestation_freshness_spec.py'
$tool = Join-Path $repo 'tools\report_attestation_freshness.py'
$catalog = Join-Path $repo 'data\canonical\catalog\runtime_attestations.json'

if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    throw "Project Python environment is missing. Follow docs/ATTESTATION_CATALOG_VALIDATION.md to create .venv and install requirements-dev.txt."
}

& $python $test
if ($LASTEXITCODE -ne 0) { throw "Attestation freshness tests failed (exit=$LASTEXITCODE)." }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('attestation-freshness-smoke-' + [Guid]::NewGuid())
$gameRoot = Join-Path $tempRoot 'game'
$reportPath = Join-Path $tempRoot 'freshness.json'
New-Item -ItemType Directory -Path (Join-Path $gameRoot 'Content\Scripts') -Force | Out-Null
$catalogBefore = (Get-FileHash -LiteralPath $catalog -Algorithm SHA256).Hash
& $python $tool --catalog $catalog --game-root $gameRoot --game-build 'smoke-test' --output $reportPath
if ($LASTEXITCODE -ne 0) { throw "Attestation freshness report failed (exit=$LASTEXITCODE)." }
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if ($report.observedGameBuild -cne 'smoke-test' -or $report.summary.evidenceMissing -ne 15) {
    throw 'Freshness CLI smoke report did not identify the missing native proof files and observed build.'
}
$catalogAfter = (Get-FileHash -LiteralPath $catalog -Algorithm SHA256).Hash
if ($catalogAfter -cne $catalogBefore) { throw 'Freshness report modified the catalog.' }
Remove-Item -LiteralPath $tempRoot -Recurse -Force
Write-Output 'PASS: freshness CLI emits deterministic JSON and leaves the catalog unchanged'
