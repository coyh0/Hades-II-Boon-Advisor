[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)][string]$GameRoot,
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(DontShow = $true)][string]$CompatibilityScript,
    [Parameter(DontShow = $true)][string]$ProcessProbe
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($CompatibilityScript)) { $CompatibilityScript = Join-Path $PSScriptRoot 'Test-PatchCompatibility.ps1' }
. (Join-Path $PSScriptRoot 'BoonAdvisor.Install.Common.ps1')
$paths = Get-BoonAdvisorPaths $GameRoot
$package = Test-BoonAdvisorPackage $PackagePath
Test-Hades2NotRunning $ProcessProbe
Test-BoonAdvisorDependencies $paths $package.Manifest
Invoke-BoonAdvisorCompatibilityGate $CompatibilityScript $paths
if (Test-Path -LiteralPath $paths.Target) { throw "Boon Advisor is already installed: $($paths.Target). Use Update-BoonAdvisor.ps1 once it is implemented." }
$candidate = Join-Path $paths.Plugins ('.Local-HadesIIBoonAdvisor.candidate-' + [Guid]::NewGuid())
if (-not (Test-ChildPath $candidate $paths.Plugins)) { throw 'Candidate escaped plugins directory.' }
if ($WhatIfPreference) { Write-Output "What if: would install $($package.Manifest.name) $($package.Manifest.version_number) to $($paths.Target)"; return }
try {
    if ($PSCmdlet.ShouldProcess($candidate, 'Create validated candidate')) {
        Copy-BoonAdvisorPackage $package.Root $candidate
        $candidatePackage = Test-BoonAdvisorPackage $candidate -AllowCandidateName
        if ($candidatePackage.Manifest.version_number -ne $package.Manifest.version_number) { throw 'Candidate manifest changed during copy.' }
    }
    if ($PSCmdlet.ShouldProcess($paths.Target, 'Install Boon Advisor')) { Move-Item -LiteralPath $candidate -Destination $paths.Target }
    Test-BoonAdvisorPackage $paths.Target | Out-Null
    Write-Output "Installed Boon Advisor $($package.Manifest.version_number): $($paths.Target)"
} catch {
    if (Test-Path -LiteralPath $candidate) { Remove-Item -LiteralPath $candidate -Recurse -Force }
    throw
}
