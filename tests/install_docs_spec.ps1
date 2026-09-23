$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$docs = @('docs\INSTALL.md', 'docs\UPDATE.md', 'docs\UNINSTALL.md', 'docs\PATCH_COMPATIBILITY.md')
foreach ($relative in $docs) {
    $path = Join-Path $repo $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Documentation file is missing: $relative" }
}

function Assert-Contains([string]$Path, [string]$Text) {
    if ((Get-Content -LiteralPath $Path -Raw).IndexOf($Text, [StringComparison]::Ordinal) -lt 0) {
        throw "Expected documentation text is missing from ${Path}: $Text"
    }
}
function Assert-NotContains([string]$Path, [string]$Text) {
    if ((Get-Content -LiteralPath $Path -Raw).IndexOf($Text, [StringComparison]::Ordinal) -ge 0) {
        throw "Unexpected documentation text is present in ${Path}: $Text"
    }
}

$installDoc = Join-Path $repo 'docs\INSTALL.md'
$updateDoc = Join-Path $repo 'docs\UPDATE.md'
$uninstallDoc = Join-Path $repo 'docs\UNINSTALL.md'
$compatDoc = Join-Path $repo 'docs\PATCH_COMPATIBILITY.md'
$readme = Join-Path $repo 'README.md'
Assert-Contains $installDoc 'Install-BoonAdvisor.ps1'
Assert-Contains $installDoc 'Runtime'
Assert-Contains $installDoc 'Local-HadesIIBoonAdvisor'
Assert-Contains $installDoc 'Thunderstore and r2modman'
Assert-Contains $installDoc '<Hades-II-root>\Ship\ReturnOfModding\'
Assert-Contains $installDoc 'Hades-II-Boon-Advisor-v<VERSION>.zip'
Assert-NotContains $installDoc '.\dist\Local-HadesIIBoonAdvisor'
Assert-NotContains $installDoc '-PythonPath'
Assert-NotContains $installDoc '-LuaDllPath'
Assert-Contains $updateDoc 'Update-BoonAdvisor.ps1'
Assert-Contains $updateDoc 'Runtime'
Assert-Contains $updateDoc 'Thunderstore and r2modman'
Assert-Contains $updateDoc '<Hades-II-root>\Ship\ReturnOfModding\'
Assert-Contains $updateDoc 'Hades-II-Boon-Advisor-v<VERSION>.zip'
Assert-NotContains $updateDoc '.\dist\Local-HadesIIBoonAdvisor'
Assert-NotContains $updateDoc '-PythonPath'
Assert-NotContains $updateDoc '-LuaDllPath'
Assert-Contains $uninstallDoc 'Uninstall-BoonAdvisor.ps1'
Assert-Contains $uninstallDoc 'Do not remove Hell2Modding'
Assert-Contains $compatDoc '-Mode Runtime'
Assert-Contains $compatDoc '-Mode Full'
Assert-Contains $compatDoc 'MANUAL RUNTIME TEST REQUIRED'
Assert-Contains $readme '<Hades-II-root>\Ship\ReturnOfModding\'
Assert-Contains $readme 'observed workaround'
Assert-Contains $readme 'universal manager behavior'

$publicDocs = @(
    $readme,
    (Join-Path $repo 'CHANGELOG.md'),
    (Join-Path $repo 'manifest.json'),
    (Join-Path $repo 'thunderstore.toml')
) + ($docs | ForEach-Object { Join-Path $repo $_ })
foreach ($path in $publicDocs) {
    foreach ($privatePath in @('jejsa', 'C:\Users\', 'D:\EpicGames', 'D:\Dev', 'AppData\Roaming\Thunderstore', 'Hades-II-Clean-Export')) {
        Assert-NotContains $path $privatePath
    }
}

foreach ($script in 'tools\Install-BoonAdvisor.ps1', 'tools\Update-BoonAdvisor.ps1', 'tools\Uninstall-BoonAdvisor.ps1') {
    if (-not (Test-Path -LiteralPath (Join-Path $repo $script) -PathType Leaf)) { throw "Documented script is missing: $script" }
}
Write-Output 'PASS: installation documentation paths, compatibility statements, and public examples are consistent'
