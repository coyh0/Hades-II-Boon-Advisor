[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$manifestPath = Join-Path $repo 'manifest.json'
$tomlPath = Join-Path $repo 'thunderstore.toml'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-TomlValue([string]$Text, [string]$Section, [string]$Name) {
    $sectionPattern = '(?ms)^\[' + [regex]::Escape($Section) + '\]\s*$(.*?)(?=^\[|\z)'
    $sectionMatch = [regex]::Match($Text, $sectionPattern)
    if (-not $sectionMatch.Success) { throw "Missing TOML section [$Section]." }
    $valueMatch = [regex]::Match($sectionMatch.Groups[1].Value, '(?m)^' + [regex]::Escape($Name) + '\s*=\s*"([^"]*)"\s*$')
    if (-not $valueMatch.Success) { throw "Missing TOML value [$Section].$Name." }
    return $valueMatch.Groups[1].Value
}

function Get-ExpectedThunderstoreDependency([string]$Token) {
    if ($Token -notmatch '^(?<owner>.+)-(?<package>[^-]+)-(?<version>\d+(?:\.\d+)+)$') {
        throw "Unsupported dependency token: $Token"
    }
    return [pscustomobject]@{
        Identity = "$($Matches.owner)-$($Matches.package)"
        Version = $Matches.version
    }
}

Assert-True (Test-Path -LiteralPath $tomlPath -PathType Leaf) 'thunderstore.toml is missing.'
$toml = [IO.File]::ReadAllText($tomlPath)
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

Assert-True ((Get-TomlValue $toml 'config' 'schemaVersion') -eq '0.0.1') 'Thunderstore schema version is incorrect.'
$namespace = Get-TomlValue $toml 'package' 'namespace'
$packageName = Get-TomlValue $toml 'package' 'name'
$version = Get-TomlValue $toml 'package' 'versionNumber'
$description = Get-TomlValue $toml 'package' 'description'
Assert-True ($namespace -match '^[A-Za-z0-9_]+$') 'Thunderstore namespace syntax is invalid.'
Assert-True ($packageName -match '^[A-Za-z0-9_]+$') 'Thunderstore package name syntax is invalid.'
Assert-True ($version -eq $manifest.version_number) 'Thunderstore package version does not match manifest.json.'
Assert-True ($description.Length -le 250) 'Thunderstore package description exceeds 250 characters.'
Assert-True ((Get-TomlValue $toml 'package' 'websiteUrl') -eq 'https://github.com/coyh0/Hades-II-Boon-Advisor') 'Thunderstore website URL is incorrect.'

$declared = @{}
$dependencySection = [regex]::Match($toml, '(?ms)^\[package\.dependencies\]\s*$(.*?)(?=^\[|\z)').Groups[1].Value
foreach ($match in [regex]::Matches($dependencySection, '(?m)^(?<identity>[A-Za-z0-9_\-]+)\s*=\s*"(?<version>\d+(?:\.\d+)+)"\s*$')) {
    $declared[$match.Groups['identity'].Value] = $match.Groups['version'].Value
}
$expected = @{}
foreach ($token in $manifest.dependencies) {
    $dependency = Get-ExpectedThunderstoreDependency $token
    $expected[$dependency.Identity] = $dependency.Version
}
Assert-True ($declared.Count -eq $expected.Count) 'Thunderstore dependency count does not match manifest.json.'
foreach ($identity in $expected.Keys) {
    Assert-True ($declared.ContainsKey($identity)) "Thunderstore dependency is missing: $identity"
    Assert-True ($declared[$identity] -eq $expected[$identity]) "Thunderstore dependency version is incorrect: $identity"
}

$requiredCopies = @(
    './CHANGELOG.md|./CHANGELOG.md',
    './LICENSE|./LICENSE',
    './src|./plugins',
    './config|./plugins/config',
    './data/builds|./plugins/data/builds',
    './manifest.json|./plugins/manifest.json'
)
$copyMatches = [regex]::Matches($toml, '(?ms)^\[\[build\.copy\]\]\s*$(.*?)(?=^\[|\z)')
$actualCopies = @()
foreach ($copy in $copyMatches) {
    $source = [regex]::Match($copy.Groups[1].Value, '(?m)^source\s*=\s*"([^"]+)"\s*$').Groups[1].Value
    $target = [regex]::Match($copy.Groups[1].Value, '(?m)^target\s*=\s*"([^"]+)"\s*$').Groups[1].Value
    $actualCopies += "$source|$target"
}
Assert-True ($actualCopies.Count -eq $requiredCopies.Count) 'Thunderstore build.copy inventory is incorrect.'
foreach ($copy in $requiredCopies) { Assert-True ($actualCopies -contains $copy) "Thunderstore build.copy entry is missing: $copy" }
foreach ($forbidden in './tests', './tools', './data/canonical', './dist', './docs') {
    Assert-True (-not ($actualCopies | Where-Object { $_.StartsWith($forbidden + '|', [StringComparison]::Ordinal) })) "Developer-only content leaks into Thunderstore build: $forbidden"
}

$runtimeExpected = @(
    'GameState.lua', 'Logger.lua', 'Localization.lua', 'OfferSnapshot.lua', 'ProfileResolver.lua', 'ScoringEngine.lua', 'UI.lua', 'main.lua',
    'config/settings.lua',
    'data/builds/black_coat_melinoe_intermediate.lua',
    'data/builds/registry.lua',
    'data/builds/sister_blades_melinoe_intermediate.lua',
    'data/builds/sister_blades_morrigan_meta.lua',
    'manifest.json'
) | Sort-Object
$runtimeActual = @()
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repo 'src') -File) { $runtimeActual += $file.Name }
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repo 'config') -Recurse -File) { $runtimeActual += ('config/' + $file.FullName.Substring((Join-Path $repo 'config').Length + 1).Replace('\', '/')) }
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repo 'data\builds') -Recurse -File) { $runtimeActual += ('data/builds/' + $file.FullName.Substring((Join-Path $repo 'data\builds').Length + 1).Replace('\', '/')) }
$runtimeActual += 'manifest.json'
Assert-True (-not (Compare-Object $runtimeExpected ($runtimeActual | Sort-Object))) 'Thunderstore plugin runtime inventory is not the exact 14-file inventory.'

foreach ($required in 'README.md', 'LICENSE', 'CHANGELOG.md') {
    Assert-True (Test-Path -LiteralPath (Join-Path $repo $required) -PathType Leaf) "Thunderstore-required file is missing: $required"
}
Assert-True ((Get-TomlValue $toml 'build' 'readme') -eq './README.md') 'Thunderstore README path is incorrect.'
Assert-True ((Get-TomlValue $toml 'build' 'icon') -eq './icon.png') 'Thunderstore icon path is incorrect.'

$iconPath = Join-Path $repo 'icon.png'
if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
    Write-Output 'BLOCKER: icon.png is missing; Thunderstore publication requires a 256x256 PNG icon.'
} else {
    Add-Type -AssemblyName System.Drawing
    $image = [Drawing.Image]::FromFile($iconPath)
    try {
        Assert-True ($image.Width -eq 256 -and $image.Height -eq 256) 'icon.png must be 256x256.'
    } finally { $image.Dispose() }
}

$tcli = Get-Command tcli -ErrorAction SilentlyContinue
if ($null -eq $tcli) {
    Write-Output 'INFO: tcli is unavailable; thunderstore.toml received structural validation only.'
} else {
    Write-Output "INFO: tcli is available at $($tcli.Source); no publish command was run."
}
Write-Output 'PASS: Thunderstore package definition, dependency mapping, and build inventory are valid.'
