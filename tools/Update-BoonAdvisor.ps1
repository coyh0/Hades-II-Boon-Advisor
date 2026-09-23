[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)][string]$GameRoot,
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(DontShow = $true)][string]$CompatibilityScript,
    [Parameter(DontShow = $true)][string]$ProcessProbe,
    [Parameter(DontShow = $true)][string]$InternalTestFailurePoint
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($CompatibilityScript)) { $CompatibilityScript = Join-Path $PSScriptRoot 'Test-PatchCompatibility.ps1' }
. (Join-Path $PSScriptRoot 'BoonAdvisor.Install.Common.ps1')

$paths = Get-BoonAdvisorPaths $GameRoot
$package = Test-BoonAdvisorPackage $PackagePath
Test-Hades2NotRunning $ProcessProbe
Test-BoonAdvisorDependencies $paths $package.Manifest
Invoke-BoonAdvisorCompatibilityGate $CompatibilityScript $paths
if (-not (Test-RealDirectory $paths.Target)) { throw "Boon Advisor is not installed: $($paths.Target). Use Install-BoonAdvisor.ps1." }
Assert-NoReparsePointTree $paths.Target
$oldManifestPath = Join-Path $paths.Target 'manifest.json'
if (-not (Test-RealFile $oldManifestPath)) { throw 'Installed Boon Advisor manifest.json is missing or is not a file.' }
$oldManifest = Get-Manifest $oldManifestPath
if ($oldManifest.name -ne 'HadesIIBoonAdvisor') { throw 'Installed target is not HadesIIBoonAdvisor.' }
$oldTreeSnapshot = Get-BoonAdvisorTreeSnapshot $paths.Target
$settingsPath = Join-Path $paths.Target 'config\settings.lua'
$preserveSettings = Test-Path -LiteralPath $settingsPath
$settingsBytes = $null
if ($preserveSettings) {
    if (-not (Test-RealFile $settingsPath)) { throw 'Installed config/settings.lua must be a normal file.' }
    $settingsItem = Get-Item -LiteralPath $settingsPath -Force
    if ($settingsItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Installed config/settings.lua must not be a reparse point.' }
    $settingsBytes = [IO.File]::ReadAllBytes($settingsPath)
}
if ($WhatIfPreference) {
    $configPlan = if ($preserveSettings) { 'and preserve config/settings.lua' } else { 'and use the package default config/settings.lua' }
    Write-Output "What if: would update/replace HadesIIBoonAdvisor $($oldManifest.version_number) -> $($package.Manifest.version_number) $configPlan"
    return
}

$candidate = Join-Path $paths.Plugins ('.Local-HadesIIBoonAdvisor.candidate-' + [Guid]::NewGuid())
$backup = Join-Path $paths.Plugins ('.Local-HadesIIBoonAdvisor.backup-' + [Guid]::NewGuid())
foreach ($temporary in @($candidate, $backup)) { if (-not (Test-ChildPath $temporary $paths.Plugins)) { throw 'Temporary update path escaped plugins directory.' } }
$movedOld = $false
$createdNewTarget = $false
try {
    if ($PSCmdlet.ShouldProcess($candidate, 'Create validated update candidate')) {
        Copy-BoonAdvisorPackage $package.Root $candidate
        if ($preserveSettings) { [IO.File]::WriteAllBytes((Join-Path $candidate 'config\settings.lua'), $settingsBytes) }
        $candidatePackage = Test-BoonAdvisorPackage $candidate -AllowCandidateName
        if ($candidatePackage.Manifest.version_number -ne $package.Manifest.version_number) { throw 'Candidate manifest changed during copy.' }
        if ($preserveSettings -and -not (Test-BoonAdvisorBytesEqual $settingsBytes ([IO.File]::ReadAllBytes((Join-Path $candidate 'config\settings.lua'))))) { throw 'Candidate settings bytes were not preserved.' }
    }
    if ($PSCmdlet.ShouldProcess($paths.Target, 'Move installed Boon Advisor to transactional backup')) {
        Move-Item -LiteralPath $paths.Target -Destination $backup
        $movedOld = $true
    }
    Invoke-BoonAdvisorTestFailure $InternalTestFailurePoint 'AfterBackup'
    if ($PSCmdlet.ShouldProcess($paths.Target, 'Move validated candidate into place')) {
        Move-Item -LiteralPath $candidate -Destination $paths.Target
        $createdNewTarget = $true
    }
    Invoke-BoonAdvisorTestFailure $InternalTestFailurePoint 'AfterTarget'
    Test-BoonAdvisorPackage $paths.Target | Out-Null
    if ($preserveSettings -and -not (Test-BoonAdvisorBytesEqual $settingsBytes ([IO.File]::ReadAllBytes((Join-Path $paths.Target 'config\settings.lua'))))) { throw 'Installed settings bytes were not preserved.' }
    if ($PSCmdlet.ShouldProcess($backup, 'Remove completed transactional backup')) { Remove-Item -LiteralPath $backup -Recurse -Force }
    Write-Output "Updated/replaced HadesIIBoonAdvisor $($oldManifest.version_number) -> $($package.Manifest.version_number): $($paths.Target)"
} catch {
    $originalMessage = $_.Exception.Message
    if (-not $movedOld) {
        if (Test-Path -LiteralPath $candidate) { Remove-Item -LiteralPath $candidate -Recurse -Force }
        throw
    }
    try {
        Invoke-BoonAdvisorTestFailure $InternalTestFailurePoint 'Rollback'
        if ($createdNewTarget -and (Test-Path -LiteralPath $paths.Target)) { Remove-Item -LiteralPath $paths.Target -Recurse -Force }
        if (-not (Test-RealDirectory $backup)) { throw 'Transactional backup is missing.' }
        Move-Item -LiteralPath $backup -Destination $paths.Target
        if (@($InternalTestFailurePoint -split ',' | ForEach-Object { $_.Trim() }) -contains 'RollbackMismatch') {
            [IO.File]::WriteAllText((Join-Path $paths.Target 'rollback-mismatch.test'), 'test-only mismatch')
        }
        Assert-NoReparsePointTree $paths.Target
        if ((Get-Manifest (Join-Path $paths.Target 'manifest.json')).name -ne 'HadesIIBoonAdvisor') { throw 'Restored target manifest identity is invalid.' }
        if (-not (Test-BoonAdvisorTreeSnapshot $paths.Target $oldTreeSnapshot)) { throw 'Restored installation differs from its pre-update snapshot.' }
        if ($preserveSettings -and -not (Test-BoonAdvisorBytesEqual $settingsBytes ([IO.File]::ReadAllBytes((Join-Path $paths.Target 'config\settings.lua'))))) { throw 'Restored settings bytes differ.' }
        if (Test-Path -LiteralPath $candidate) { Remove-Item -LiteralPath $candidate -Recurse -Force }
        Write-Warning "Update failed; transactional rollback restored the previous installation. Original failure: $originalMessage"
        throw "Update failed and rollback completed: $originalMessage"
    } catch {
        $rollbackMessage = $_.Exception.Message
        if ($rollbackMessage -like 'Update failed and rollback completed:*') { throw }
        throw "Update failed: $originalMessage`nRollback failed: $rollbackMessage"
    }
}
