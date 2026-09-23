[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)][string]$GameRoot,
    [Parameter(DontShow = $true)][string]$ProcessProbe
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'BoonAdvisor.Install.Common.ps1')
$paths = Get-BoonAdvisorPaths $GameRoot
Test-Hades2NotRunning $ProcessProbe
if (-not (Test-Path -LiteralPath $paths.Target)) { Write-Output "Boon Advisor is not installed: $($paths.Target)"; return }
Assert-NoReparsePoint $paths.Target
if ($WhatIfPreference) { Write-Output "What if: would uninstall Boon Advisor: $($paths.Target)"; return }
if ($PSCmdlet.ShouldProcess($paths.Target, 'Uninstall Boon Advisor')) {
    Remove-Item -LiteralPath $paths.Target -Recurse -Force
    Write-Output "Uninstalled Boon Advisor: $($paths.Target)"
}
