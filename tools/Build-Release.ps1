[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [switch]$IncludeWindowsTools,
    [Parameter(DontShow = $true)][string]$InternalStageScript
)
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).ProviderPath
$stageScript = if ([string]::IsNullOrWhiteSpace($InternalStageScript)) { Join-Path $PSScriptRoot 'Stage-Probe.ps1' } else { $InternalStageScript }
$releaseOutput = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { Join-Path $repo 'dist\release' } else { $OutputDirectory }
. (Join-Path $PSScriptRoot 'BoonAdvisor.Install.Common.ps1')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-ReleaseNormalizedPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Release output path was empty.' }
    $providerPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    [IO.Path]::GetFullPath($providerPath)
}

function Get-ReleaseZipFiles([string]$ZipPath, [string]$PluginDirectory) {
    $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entries = @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) })
        $topLevels = @($entries | ForEach-Object { $_.FullName.Split('/')[0] } | Sort-Object -Unique)
        if ($topLevels.Count -ne 1 -or $topLevels[0] -ne $PluginDirectory) { throw 'ZIP must contain exactly the Local-HadesIIBoonAdvisor top-level directory.' }
        $files = @{}
        foreach ($entry in $entries) {
            if (-not $entry.FullName.StartsWith($PluginDirectory + '/', [StringComparison]::Ordinal)) { throw "ZIP entry escaped plugin directory: $($entry.FullName)" }
            $relative = $entry.FullName.Substring($PluginDirectory.Length + 1)
            if ([string]::IsNullOrWhiteSpace($relative) -or $relative.Contains('..') -or $relative.StartsWith('/')) { throw "ZIP entry path is invalid: $($entry.FullName)" }
            if ($files.ContainsKey($relative)) { throw "ZIP contains a duplicate file: $relative" }
            $stream = $entry.Open()
            try {
                $hasher = [Security.Cryptography.SHA256]::Create()
                try { $hash = ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
                finally { $hasher.Dispose() }
            } finally { $stream.Dispose() }
            $files[$relative] = $hash
        }
        [pscustomobject]@{ TopLevels = $topLevels; Files = $files }
    } finally { $archive.Dispose() }
}

function Test-ReleaseZip([string]$ZipPath, $Package) {
    if (-not (Test-RealFile $ZipPath)) { throw "Release ZIP was not created: $ZipPath" }
    $zip = Get-ReleaseZipFiles $ZipPath $script:BoonAdvisorPluginDirectory
    $expected = @($Package.Files | ForEach-Object { $_ -replace '\\', '/' } | Sort-Object)
    $actual = @($zip.Files.Keys | Sort-Object)
    if (Compare-Object $expected $actual) { throw 'ZIP runtime file inventory is not exact.' }
    foreach ($relative in $expected) {
        $sourceHash = (Get-FileHash -LiteralPath (Join-Path $Package.Root ($relative -replace '/', '\\')) -Algorithm SHA256).Hash
        if ($zip.Files[$relative] -ne $sourceHash) { throw "ZIP entry hash differs from staged source: $relative" }
    }
    $manifestBytes = [IO.File]::ReadAllBytes((Join-Path $Package.Root 'manifest.json'))
    $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entry = $archive.GetEntry($script:BoonAdvisorPluginDirectory + '/manifest.json')
        if ($null -eq $entry) { throw 'ZIP manifest.json is missing.' }
        $stream = $entry.Open()
        try {
            $memory = New-Object IO.MemoryStream
            try { $stream.CopyTo($memory); if (-not (Test-BoonAdvisorBytesEqual $manifestBytes $memory.ToArray())) { throw 'ZIP manifest differs from staged manifest.' } }
            finally { $memory.Dispose() }
        } finally { $stream.Dispose() }
    } finally { $archive.Dispose() }
}

function New-ReleaseZip([string]$ZipPath, $Entries) {
    $stream = [IO.File]::Open($ZipPath, [IO.FileMode]::CreateNew)
    try {
        $archive = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            foreach ($item in @($Entries | Sort-Object Name)) {
                $entry = $archive.CreateEntry($item.Name, [IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
                $destination = $entry.Open()
                try {
                    $source = [IO.File]::OpenRead($item.Source)
                    try { $source.CopyTo($destination) } finally { $source.Dispose() }
                } finally { $destination.Dispose() }
            }
        } finally { $archive.Dispose() }
    } finally { $stream.Dispose() }
}

function Get-AnyReleaseZipFiles([string]$ZipPath) {
    $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entries = @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) })
        $files = @{}
        foreach ($entry in $entries) {
            if ($files.ContainsKey($entry.FullName)) { throw "ZIP contains a duplicate file: $($entry.FullName)" }
            $stream = $entry.Open()
            try {
                $sha = [Security.Cryptography.SHA256]::Create()
                try { $files[$entry.FullName] = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
                finally { $sha.Dispose() }
            } finally { $stream.Dispose() }
        }
        [pscustomobject]@{ TopLevels = @($entries | ForEach-Object { $_.FullName.Split('/')[0] } | Sort-Object -Unique); Files = $files }
    } finally { $archive.Dispose() }
}

function Test-WindowsBundleZip([string]$ZipPath, $Entries) {
    $actual = Get-AnyReleaseZipFiles $ZipPath
    $expectedNames = @($Entries | ForEach-Object { $_.Name } | Sort-Object)
    $actualNames = @($actual.Files.Keys | Sort-Object)
    if (Compare-Object $expectedNames $actualNames) { throw 'Windows bundle ZIP inventory is not exact.' }
    $expectedTop = @('Local-HadesIIBoonAdvisor', 'docs', 'tools') | Sort-Object
    if (Compare-Object $expectedTop $actual.TopLevels) { throw 'Windows bundle ZIP top-level inventory is not exact.' }
    foreach ($item in $Entries) {
        $sourceHash = (Get-FileHash -LiteralPath $item.Source -Algorithm SHA256).Hash
        if ($actual.Files[$item.Name] -ne $sourceHash) { throw "Windows bundle entry hash differs from source: $($item.Name)" }
    }
}

if (-not (Test-RealFile $stageScript)) { throw "Stage script does not exist: $stageScript" }
& $stageScript

$stagedRoot = Join-Path $repo 'dist\Local-HadesIIBoonAdvisor'
$package = Test-BoonAdvisorPackage $stagedRoot
$version = [string]$package.Manifest.version_number
if ([string]::IsNullOrWhiteSpace($version)) { throw 'Staged manifest version_number is required.' }
$output = Get-ReleaseNormalizedPath $releaseOutput
if (-not (Test-Path -LiteralPath $output)) { New-Item -ItemType Directory -Path $output -Force | Out-Null }
if (-not (Test-RealDirectory $output)) { throw "Release output path is not a directory: $output" }
Assert-NoReparsePoint $output

$baseName = 'Hades-II-Boon-Advisor-v' + $version
$zipPath = Join-Path $output ($baseName + '.zip')
$checksumPath = Join-Path $output ($baseName + '.sha256')
$temporaryZip = Join-Path $output ('.' + $baseName + '.' + [Guid]::NewGuid() + '.tmp')
$temporaryWindowsZip = $null
try {
    $pluginEntries = @($package.Files | Sort-Object | ForEach-Object { [pscustomobject]@{ Name = $script:BoonAdvisorPluginDirectory + '/' + ($_ -replace '\\', '/'); Source = Join-Path $package.Root $_ } })
    New-ReleaseZip $temporaryZip $pluginEntries
    Test-ReleaseZip $temporaryZip $package
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Move-Item -LiteralPath $temporaryZip -Destination $zipPath
    $zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    [IO.File]::WriteAllText($checksumPath, $zipHash + "`r`n", [Text.Encoding]::ASCII)

    Write-Output "Release ZIP: $zipPath"
    Write-Output "SHA-256: $zipHash"
    Write-Output "Checksum: $checksumPath"
    if ($IncludeWindowsTools) {
        $windowsBaseName = 'Hades-II-Boon-Advisor-Windows-v' + $version
        $windowsZipPath = Join-Path $output ($windowsBaseName + '.zip')
        $windowsChecksumPath = Join-Path $output ($windowsBaseName + '.sha256')
        $temporaryWindowsZip = Join-Path $output ('.' + $windowsBaseName + '.' + [Guid]::NewGuid() + '.tmp')
        $bundleEntries = @($pluginEntries)
        foreach ($relative in @('BoonAdvisor.Install.Common.ps1', 'Install-BoonAdvisor.ps1', 'Update-BoonAdvisor.ps1', 'Uninstall-BoonAdvisor.ps1', 'Test-PatchCompatibility.ps1')) {
            $bundleEntries += [pscustomobject]@{ Name = 'tools/' + $relative; Source = Join-Path $repo ('tools\' + $relative) }
        }
        foreach ($relative in @('INSTALL.md', 'UPDATE.md', 'UNINSTALL.md', 'PATCH_COMPATIBILITY.md')) {
            $bundleEntries += [pscustomobject]@{ Name = 'docs/' + $relative; Source = Join-Path $repo ('docs\' + $relative) }
        }
        New-ReleaseZip $temporaryWindowsZip $bundleEntries
        Test-WindowsBundleZip $temporaryWindowsZip $bundleEntries
        if (Test-Path -LiteralPath $windowsZipPath) { Remove-Item -LiteralPath $windowsZipPath -Force }
        Move-Item -LiteralPath $temporaryWindowsZip -Destination $windowsZipPath
        $windowsZipHash = (Get-FileHash -LiteralPath $windowsZipPath -Algorithm SHA256).Hash
        [IO.File]::WriteAllText($windowsChecksumPath, $windowsZipHash + "`r`n", [Text.Encoding]::ASCII)
        Write-Output "Windows bundle ZIP: $windowsZipPath"
        Write-Output "SHA-256: $windowsZipHash"
        Write-Output "Checksum: $windowsChecksumPath"
    }
} catch {
    if (Test-Path -LiteralPath $temporaryZip) { Remove-Item -LiteralPath $temporaryZip -Force }
    if ($null -ne $temporaryWindowsZip -and (Test-Path -LiteralPath $temporaryWindowsZip)) { Remove-Item -LiteralPath $temporaryWindowsZip -Force }
    throw
}
