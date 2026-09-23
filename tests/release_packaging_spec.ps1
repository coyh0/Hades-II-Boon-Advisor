[CmdletBinding()]
param(
    [string]$ValidatedGameRoot
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$builder = Join-Path $repo 'tools\Build-Release.ps1'
$stage = Join-Path $repo 'tools\Stage-Probe.ps1'
$output = Join-Path $repo ('dist\release-test-' + [Guid]::NewGuid())
$sibling = Join-Path $repo ('dist\release-sibling-' + [Guid]::NewGuid() + '.txt')
$plugin = 'Local-HadesIIBoonAdvisor'

if ([string]::IsNullOrWhiteSpace($ValidatedGameRoot)) { $ValidatedGameRoot = [Environment]::GetEnvironmentVariable('BOON_ADVISOR_VALIDATED_GAME_ROOT') }
if ([string]::IsNullOrWhiteSpace($ValidatedGameRoot)) { throw 'ValidatedGameRoot is required for the self-contained Windows bundle test. Pass -ValidatedGameRoot or set BOON_ADVISOR_VALIDATED_GAME_ROOT.' }
$ValidatedGameRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ValidatedGameRoot)
if (-not (Test-Path -LiteralPath (Join-Path $ValidatedGameRoot 'Ship\Hades2.exe') -PathType Leaf)) { throw "Validated game root is missing Ship\Hades2.exe: $ValidatedGameRoot" }

function Get-ZipFiles([string]$Path) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $files = @{}
        foreach ($entry in @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) })) {
            $relative = $entry.FullName.Substring($plugin.Length + 1)
            $stream = $entry.Open()
            try {
                $sha = [Security.Cryptography.SHA256]::Create()
                try { $files[$relative] = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
                finally { $sha.Dispose() }
            } finally { $stream.Dispose() }
        }
        $files
    } finally { $archive.Dispose() }
}

try {
    Set-Content -LiteralPath $sibling -Value 'preserve'
    $siblingHash = (Get-FileHash -LiteralPath $sibling -Algorithm SHA256).Hash
    $sourceHashesBefore = @{}
    foreach ($file in @('src\main.lua', 'src\ScoringEngine.lua', 'src\UI.lua', 'manifest.json')) {
        $sourceHashesBefore[$file] = (Get-FileHash -LiteralPath (Join-Path $repo $file) -Algorithm SHA256).Hash
    }

    & $builder -OutputDirectory $output | Out-Null
    $manifest = Get-Content -LiteralPath (Join-Path $repo 'dist\Local-HadesIIBoonAdvisor\manifest.json') -Raw | ConvertFrom-Json
    $baseName = 'Hades-II-Boon-Advisor-v' + $manifest.version_number
    $zipPath = Join-Path $output ($baseName + '.zip')
    $checksumPath = Join-Path $output ($baseName + '.sha256')
    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) { throw 'Release ZIP is missing.' }
    if ((Get-Content -LiteralPath $checksumPath -Raw).Trim() -ne (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash) { throw 'Release checksum does not match ZIP.' }

    $expected = @(Get-ChildItem -LiteralPath (Join-Path $repo 'dist\Local-HadesIIBoonAdvisor') -Recurse -File | ForEach-Object { $_.FullName.Substring((Join-Path $repo 'dist\Local-HadesIIBoonAdvisor').Length + 1) -replace '\\', '/' } | Sort-Object)
    $first = Get-ZipFiles $zipPath
    if (Compare-Object $expected @($first.Keys | Sort-Object)) { throw 'ZIP inventory is not the exact staged inventory.' }
    foreach ($relative in $expected) {
        $source = Join-Path (Join-Path $repo 'dist\Local-HadesIIBoonAdvisor') ($relative -replace '/', '\\')
        if ($first[$relative] -ne (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash) { throw "ZIP file hash differs from staging: $relative" }
    }
    if (@($first.Keys | Where-Object { $_ -match '(^|/)(src|tests|tools|docs|canonical)(/|$)' }).Count -ne 0) { throw 'ZIP contains a non-runtime project path.' }
    $stale = Join-Path $output 'stale-release-file.txt'; Set-Content -LiteralPath $stale -Value 'not part of zip'
    & $builder -OutputDirectory $output | Out-Null
    $second = Get-ZipFiles $zipPath
    if (Compare-Object @($first.Keys | Sort-Object) @($second.Keys | Sort-Object)) { throw 'Repeated ZIP inventory changed.' }
    foreach ($relative in $expected) { if ($first[$relative] -ne $second[$relative]) { throw "Repeated ZIP entry hash changed: $relative" } }
    if (-not (Test-Path -LiteralPath $stale)) { throw 'Release build unexpectedly removed unrelated output files.' }
    if ((Get-FileHash -LiteralPath $sibling -Algorithm SHA256).Hash -ne $siblingHash) { throw 'Release build changed a sibling dist file.' }

    $windowsZip = Join-Path $output (($baseName -replace '^Hades-II-Boon-Advisor', 'Hades-II-Boon-Advisor-Windows') + '.zip')
    if (Test-Path -LiteralPath $windowsZip) { throw 'Default release build unexpectedly created the optional Windows tools bundle.' }
    & $builder -OutputDirectory $output -IncludeWindowsTools | Out-Null
    if (-not (Test-Path -LiteralPath $windowsZip -PathType Leaf)) { throw 'Explicit Windows tools bundle build did not create its ZIP.' }
    $windowsExtract = Join-Path $output 'windows-extracted'
    [IO.Compression.ZipFile]::ExtractToDirectory($windowsZip, $windowsExtract)
    $bundleRoot = Join-Path $windowsExtract $plugin
    $bundleFiles = @(Get-ChildItem -LiteralPath $windowsExtract -Recurse -File | ForEach-Object { $_.FullName.Substring($windowsExtract.Length + 1) -replace '\\', '/' } | Sort-Object)
    $expectedTools = @('tools/BoonAdvisor.Install.Common.ps1', 'tools/Install-BoonAdvisor.ps1', 'tools/Update-BoonAdvisor.ps1', 'tools/Uninstall-BoonAdvisor.ps1', 'tools/Test-PatchCompatibility.ps1')
    $expectedDocs = @('docs/INSTALL.md', 'docs/UPDATE.md', 'docs/UNINSTALL.md', 'docs/PATCH_COMPATIBILITY.md')
    $expectedBundle = @($expected | ForEach-Object { $plugin + '/' + $_ }) + $expectedTools + $expectedDocs | Sort-Object
    if (Compare-Object $expectedBundle $bundleFiles) { throw 'Windows bundle file inventory is not exact.' }
    if (@($bundleFiles | Where-Object { $_ -match '(^|/)(src|tests|canonical|dist|\.git|Generate-|Stage-|Build-Release)' }).Count -ne 0) { throw 'Windows bundle contains development files.' }
    $fixtureGame = Join-Path $output 'bundle-game'
    New-Item -ItemType Directory -Path (Join-Path $fixtureGame 'Ship'), (Join-Path $fixtureGame 'Content\Scripts'), (Join-Path $fixtureGame 'Ship\ReturnOfModding\plugins') -Force | Out-Null
    foreach ($relative in @('Ship\Hades2.exe', 'Content\Scripts\LootData.lua', 'Content\Scripts\InteractLogic.lua', 'Content\Scripts\UpgradeChoiceLogic.lua')) {
        $source = Join-Path $ValidatedGameRoot $relative
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Validated game fixture is missing: $source" }
        Copy-Item -LiteralPath $source -Destination (Join-Path $fixtureGame $relative)
    }
    [IO.File]::WriteAllText((Join-Path $fixtureGame 'Ship\d3d12.dll'), 'fixture loader')
    $bundleManifest = Get-Content -LiteralPath (Join-Path $bundleRoot 'manifest.json') -Raw | ConvertFrom-Json
    foreach ($token in @($bundleManifest.dependencies)) {
        if ($token -eq 'Hell2Modding-Hell2Modding-1.0.112') { continue }
        $parts = $token -match '^(?<owner>[^-]+)-(?<package>.+)-(?<version>[0-9]+(?:\.[0-9]+)+)$'; $identity = $Matches.owner + '-' + $Matches.package
        $dependencyRoot = Join-Path $fixtureGame ('Ship\ReturnOfModding\plugins\' + $identity)
        New-Item -ItemType Directory -Path $dependencyRoot -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $dependencyRoot 'manifest.json'), ('{"name":"' + $Matches.package + '","version_number":"' + $Matches.version + '"}'))
    }
    $oldLocation = (Get-Location).Path
    Push-Location $windowsExtract
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\tools\Install-BoonAdvisor.ps1' -GameRoot $fixtureGame -PackagePath '.\Local-HadesIIBoonAdvisor' -WhatIf
        if ($LASTEXITCODE -ne 0) { throw 'Extracted bundle Install -WhatIf failed.' }
        Copy-Item -LiteralPath $bundleRoot -Destination (Join-Path $fixtureGame 'Ship\ReturnOfModding\plugins\Local-HadesIIBoonAdvisor') -Recurse
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\tools\Update-BoonAdvisor.ps1' -GameRoot $fixtureGame -PackagePath '.\Local-HadesIIBoonAdvisor' -WhatIf
        if ($LASTEXITCODE -ne 0) { throw 'Extracted bundle Update -WhatIf failed.' }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\tools\Uninstall-BoonAdvisor.ps1' -GameRoot $fixtureGame -WhatIf
        if ($LASTEXITCODE -ne 0) { throw 'Extracted bundle Uninstall -WhatIf failed.' }
    } finally { Pop-Location }

    foreach ($file in $sourceHashesBefore.Keys) {
        if ((Get-FileHash -LiteralPath (Join-Path $repo $file) -Algorithm SHA256).Hash -ne $sourceHashesBefore[$file]) { throw "Release build changed repository source: $file" }
    }

    $invalidStage = Join-Path $output 'invalid-stage.ps1'
    [IO.File]::WriteAllText($invalidStage, ('& "' + $stage + '"' + [Environment]::NewLine + 'Set-Content -LiteralPath (Join-Path "' + (Join-Path $repo 'dist\Local-HadesIIBoonAdvisor') + '" "unexpected.txt") -Value "invalid"'))
    $invalidOutput = Join-Path $output 'invalid-output'
    try { & $builder -OutputDirectory $invalidOutput -InternalStageScript $invalidStage; throw 'Invalid staging unexpectedly produced a release.' } catch { if ($_.Exception.Message -like 'Invalid staging unexpectedly*') { throw } }
    if (Test-Path -LiteralPath (Join-Path $invalidOutput ($baseName + '.zip'))) { throw 'Invalid staging left a misleading release ZIP.' }
    & $stage | Out-Null
    Write-Output 'PASS: release ZIP layout, exact staged hashes, checksum, repeated logical reproducibility, stale-output isolation, invalid-staging refusal, and source preservation'
} finally {
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Recurse -Force }
    if (Test-Path -LiteralPath $sibling) { Remove-Item -LiteralPath $sibling -Force }
}
