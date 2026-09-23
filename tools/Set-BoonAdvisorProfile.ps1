[CmdletBinding(DefaultParameterSetName = 'Set')]
param(
    [Parameter(ParameterSetName = 'Set')]
    [string]$Profile,
    [Parameter(ParameterSetName = 'Show', Mandatory = $true)]
    [switch]$Show,
    [Parameter(ParameterSetName = 'Set', Mandatory = $true)]
    [Parameter(ParameterSetName = 'Show', Mandatory = $true)]
    [string]$TargetPath
)
$ErrorActionPreference = 'Stop'
if (-not $Show -and [string]::IsNullOrWhiteSpace($Profile)) {
    throw 'Specify -Profile auto|intermediate|starter|morrigan_meta, or use -Show.'
}
$target = [IO.Path]::GetFullPath($TargetPath)
$settingsPath = Join-Path $target 'config\settings.lua'
$registryPath = Join-Path $target 'data\builds\registry.lua'
if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw "Target directory does not exist: $target" }
if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) { throw "Settings file does not exist: $settingsPath" }
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { throw "Generated profile registry does not exist: $registryPath" }
$registryText = [IO.File]::ReadAllText($registryPath)
$registryMatches = [regex]::Matches($registryText, 'selectionKey\s*=\s*"([a-z][a-z0-9_]*)"')
$validProfiles = @($registryMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$validProfiles += 'auto'
$validProfiles = @($validProfiles | Sort-Object -Unique)
if ($validProfiles.Count -eq 0 -or $validProfiles.Count - 1 -ne $registryMatches.Count) {
    throw "Generated profile registry is malformed: $registryPath"
}
$text = [IO.File]::ReadAllText($settingsPath)
$pattern = '(?m)^(\s*BUILD_PROFILE\s*=\s*)["'']([^"'']+)["''](\s*,?\s*)$'
$matches = [regex]::Matches($text, $pattern)
if ($matches.Count -ne 1) { throw "Expected exactly one BUILD_PROFILE assignment; found $($matches.Count)." }
$current = $matches[0].Groups[2].Value
$debugMatch = [regex]::Match($text, '(?m)^\s*DEBUG\s*=\s*(true|false)\s*,?\s*$')
$uiTestMatch = [regex]::Match($text, '(?m)^\s*UI_TEST_MODE\s*=\s*(true|false)\s*,?\s*$')
$debugValue = if ($debugMatch.Success) { $debugMatch.Groups[1].Value } else { 'unknown' }
$uiTestValue = if ($uiTestMatch.Success) { $uiTestMatch.Groups[1].Value } else { 'unknown' }
if ($Show) {
    Write-Output "Profile: $current"
    Write-Output "Settings: $settingsPath"
    Write-Output "DEBUG: $debugValue"
    Write-Output "UI_TEST_MODE: $uiTestValue"
    Write-Output ("Available profiles: " + ($validProfiles -join ', '))
    exit 0
}
if ($validProfiles -notcontains $Profile) {
    throw "Unknown profile '$Profile'. Available profiles: $($validProfiles -join ', ')."
}
if ($current -eq $Profile) {
    Write-Output "Boon Advisor profile already set to: $Profile"
} else {
    $replacement = '$1"' + $Profile + '"$3'
    $updated = [regex]::Replace($text, $pattern, $replacement, 1)
    [IO.File]::WriteAllText($settingsPath, $updated)
    Write-Output "Profile: $Profile"
    Write-Output "Settings: $settingsPath"
    Write-Output "DEBUG: $debugValue"
    Write-Output "UI_TEST_MODE: $uiTestValue"
}
$running = Get-Process -Name 'Hades2' -ErrorAction SilentlyContinue
if ($null -ne $running) {
    Write-Warning 'Hades II is running. Restart the game for the profile change to take effect.'
} else {
    Write-Output 'Restart Hades II for the selected profile to be loaded.'
}
