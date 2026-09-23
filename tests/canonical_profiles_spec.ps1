[CmdletBinding()]
param(
    [string]$PythonPath,
    [string]$LuaDllPath
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$generator = Join-Path $repo 'tools\Generate-BoonAdvisorProfiles.ps1'

function Resolve-RequiredFile([string]$ExplicitPath, [string]$EnvironmentName, [string]$Description) {
    $candidate = $ExplicitPath
    if ([string]::IsNullOrWhiteSpace($candidate)) { $candidate = [Environment]::GetEnvironmentVariable($EnvironmentName) }
    if ([string]::IsNullOrWhiteSpace($candidate) -and $Description -eq 'PythonPath') {
        $pythonCommand = Get-Command python.exe -ErrorAction SilentlyContinue
        if ($null -ne $pythonCommand) { $candidate = $pythonCommand.Source }
    }
    if ([string]::IsNullOrWhiteSpace($candidate) -and $Description -eq 'LuaDllPath') {
        $gameRoot = [Environment]::GetEnvironmentVariable('HADES2_GAME_ROOT')
        if (-not [string]::IsNullOrWhiteSpace($gameRoot)) { $candidate = Join-Path $gameRoot 'Ship\lua52.dll' }
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) { throw "$Description is required. Pass -$Description or set $EnvironmentName." }
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($candidate)
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "$Description was not found: $resolved" }
    return $resolved
}

$python = Resolve-RequiredFile $PythonPath 'BOON_ADVISOR_PYTHON' 'PythonPath'
$dll = Resolve-RequiredFile $LuaDllPath 'BOON_ADVISOR_LUA_DLL' 'LuaDllPath'
$windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
$root = Join-Path ([IO.Path]::GetTempPath()) ('boon-canonical-test-' + [Guid]::NewGuid())
$first = Join-Path $root 'first'; $second = Join-Path $root 'second'
& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -ValidateOnly | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Windows PowerShell 5.1 canonical validation failed.' }
& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -OutputDirectory $first | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Windows PowerShell 5.1 first generation failed.' }
& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -OutputDirectory $second | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Windows PowerShell 5.1 second generation failed.' }
$isolatedProfiles = Join-Path $root 'isolated-profiles'
$isolatedMechanics = Join-Path $root 'isolated-mechanics'
Copy-Item -LiteralPath (Join-Path $repo 'data\canonical\profiles') -Destination $isolatedProfiles -Recurse
Copy-Item -LiteralPath (Join-Path $repo 'data\canonical\mechanics') -Destination $isolatedMechanics -Recurse
$isolatedOutput = Join-Path $root 'isolated-output'
& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -CanonicalDirectory $isolatedProfiles -MechanicsDirectory $isolatedMechanics -OutputDirectory $isolatedOutput | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'JSON-only isolated generation failed.' }
foreach ($generated in @(Get-ChildItem -LiteralPath $isolatedOutput -Filter '*.lua' -File)) {
    if ((Get-Content -LiteralPath $generated.FullName -Raw) -match 'loadfile\s*\(') {
        throw 'Generated profile retained a runtime Lua dependency.'
    }
}
$multiMechanics = Join-Path $root 'multi-mechanics'
Copy-Item -LiteralPath (Join-Path $repo 'data\canonical\mechanics') -Destination $multiMechanics -Recurse
$multiMechanicsPath = Join-Path $multiMechanics 'sister_blades_melinoe.json'
$multiMechanicsText = [IO.File]::ReadAllText($multiMechanicsPath)
$multiMechanicsText = $multiMechanicsText.Replace('"DaggerRapidAttackTrait":"ASPECT_COMPATIBLE"', '"DaggerRapidAttackTrait":["ASPECT_COMPATIBLE","ASPECT_SETUP_SYNERGY"]')
[IO.File]::WriteAllText($multiMechanicsPath, $multiMechanicsText)
$multiOutput = Join-Path $root 'multi-output'
& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -CanonicalDirectory $isolatedProfiles -MechanicsDirectory $multiMechanics -OutputDirectory $multiOutput | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Aspect interaction string-array generation failed.' }
function Assert-Mechanics-Fails([string]$name, [string]$find, [string]$replace) {
    $case = Join-Path $root $name
    Copy-Item -LiteralPath (Join-Path $repo 'data\canonical\mechanics') -Destination $case -Recurse
    $path = Join-Path $case 'sister_blades_melinoe.json'
    [IO.File]::WriteAllText($path, ([IO.File]::ReadAllText($path)).Replace($find, $replace))
    try {
        & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -MechanicsDirectory $case -ValidateOnly 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { throw "Expected mechanics failure: $name" }
    }
    catch { if ($_.Exception.Message -like 'Expected mechanics failure:*') { throw } }
}
Assert-Mechanics-Fails 'missing-generic-core-aspect-compatibility' '  "genericCoreAspectCompatibility": true,' ''
Assert-Mechanics-Fails 'invalid-generic-core-aspect-compatibility' '"genericCoreAspectCompatibility": true' '"genericCoreAspectCompatibility": "true"'
Assert-Mechanics-Fails 'unknown-catalog-mechanics-weapon' '"weapon": "WeaponDagger"' '"weapon": "UnknownWeapon"'
Assert-Mechanics-Fails 'unknown-catalog-mechanics-aspect' '"aspect": "DaggerBackstabAspect"' '"aspect": "UnknownAspect"'
Assert-Mechanics-Fails 'malformed-aspect-interaction' '"DaggerRapidAttackTrait":"ASPECT_COMPATIBLE"' '"DaggerRapidAttackTrait":true'
Assert-Mechanics-Fails 'duplicate-aspect-interaction' '"DaggerRapidAttackTrait":"ASPECT_COMPATIBLE"' '"DaggerRapidAttackTrait":["ASPECT_SETUP_SYNERGY","ASPECT_SETUP_SYNERGY"]'
$firstFiles = @(Get-ChildItem -LiteralPath $first -File | Sort-Object Name)
foreach ($file in $firstFiles) {
    $other = Join-Path $second $file.Name
    if (-not (Test-Path -LiteralPath $other) -or (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $other -Algorithm SHA256).Hash) {
        throw 'generation was not deterministic.'
    }
    $checkedIn = Join-Path $repo ('data\builds\' + $file.Name)
    if (-not (Test-Path -LiteralPath $checkedIn -PathType Leaf) -or
        (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $checkedIn -Algorithm SHA256).Hash) {
        throw "Generated Sister Blades output changed: $($file.Name)"
    }
}
$env:BOON_CANONICAL_OUTPUT = $first
& $python (Join-Path $repo 'tests\run_lua52.py') $dll 'tests/canonical_generated_spec.lua'
if ($LASTEXITCODE -ne 0) { throw 'generated Lua equivalence test failed.' }
Remove-Item Env:BOON_CANONICAL_OUTPUT
function Assert-Fails([string]$name, [string]$find, [string]$replace) {
    $case = Join-Path $root $name
    Copy-Item -LiteralPath (Join-Path $repo 'data\canonical\profiles') -Destination $case -Recurse
    $path = Join-Path $case 'sister_blades_melinoe_starter.json'
    [IO.File]::WriteAllText($path, ([IO.File]::ReadAllText($path)).Replace($find, $replace))
    try {
        & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -CanonicalDirectory $case -ValidateOnly 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { throw "Expected failure: $name" }
    }
    catch { if ($_.Exception.Message -like 'Expected failure:*') { throw } }
}
Assert-Fails 'invalid-schema' '"schemaVersion": 1' '"schemaVersion": 2'
Assert-Fails 'missing-selection-key' '"selectionKey": "starter",' ''
Assert-Fails 'duplicate-selection-key' '"selectionKey": "starter"' '"selectionKey": "intermediate"'
Assert-Fails 'invalid-policy' '"slotPolicy": "open"' '"slotPolicy": "invalid"'
Assert-Fails 'duplicate-id' '"id": "sister_blades_melinoe_starter"' '"id": "sister_blades_melinoe_intermediate"'
Assert-Fails 'contradiction' '"alternatives": []' '"alternatives": ["AphroditeWeaponBoon"]'
Assert-Fails 'duplicate-slot-id' '["AphroditeWeaponBoon"]' '["AphroditeWeaponBoon", "AphroditeWeaponBoon"]'
Assert-Fails 'malformed-role-array' '"core": ["AphroditeWeaponBoon"]' '"core": "AphroditeWeaponBoon"'
Assert-Fails 'unknown-slot' '"Sprint": {' '"Omega": {'
Assert-Fails 'unknown-catalog-weapon' '"weapon": "WeaponDagger"' '"weapon": "UnknownWeapon"'
Assert-Fails 'unknown-catalog-aspect' '"aspect": "DaggerBackstabAspect"' '"aspect": "UnknownAspect"'
Assert-Fails 'profile-template-mismatch' '"aspect": "DaggerBackstabAspect"' '"aspect": "DaggerTripleAspect"'

function Assert-Catalog-Fails([string]$name, [string]$contents) {
    $path = Join-Path $root ($name + '.json')
    [IO.File]::WriteAllText($path, $contents)
    try {
        & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -CatalogPath $path -ValidateOnly 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { throw "Expected catalog failure: $name" }
    }
    catch { if ($_.Exception.Message -like 'Expected catalog failure:*') { throw } }
}
Assert-Catalog-Fails 'duplicate-catalog-weapon' @'
{"schemaVersion":1,"weapons":[{"runtimeWeaponId":"WeaponDagger","aspects":[{"runtimeAspectId":"DaggerBackstabAspect"}]},{"runtimeWeaponId":"WeaponDagger","aspects":[{"runtimeAspectId":"DaggerTripleAspect"}]}]}
'@
Assert-Catalog-Fails 'duplicate-catalog-aspect' @'
{"schemaVersion":1,"weapons":[{"runtimeWeaponId":"WeaponDagger","aspects":[{"runtimeAspectId":"DaggerBackstabAspect"},{"runtimeAspectId":"DaggerBackstabAspect"}]}]}
'@

$overrideProfiles = Join-Path $root 'override-profiles'
Copy-Item -LiteralPath (Join-Path $repo 'data\canonical\profiles') -Destination $overrideProfiles -Recurse
$overridePath = Join-Path $overrideProfiles 'aaa_shared_mechanics_override.json'
$override = [IO.File]::ReadAllText((Join-Path $overrideProfiles 'sister_blades_melinoe_starter.json'))
$override = $override.Replace('"id": "sister_blades_melinoe_starter"', '"id": "aaa_shared_mechanics_override"')
$override = $override.Replace('"selectionKey": "starter"', '"selectionKey": "aaa_shared_mechanics_override"')
$override = $override.Replace('"mechanicsTemplate": "sister_blades_melinoe",', '"mechanicsTemplate": "sister_blades_melinoe",' + [Environment]::NewLine + '  "weights": { "FILL_EMPTY_PRIMARY_CORE": 999 },')
[IO.File]::WriteAllText($overridePath, $override)
$overrideOutput = Join-Path $root 'override-output'
& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -CanonicalDirectory $overrideProfiles -OutputDirectory $overrideOutput | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Shared mechanics override isolation generation failed.' }
if ((Get-Content -LiteralPath (Join-Path $overrideOutput 'aaa_shared_mechanics_override.lua') -Raw) -notmatch 'FILL_EMPTY_PRIMARY_CORE = 999') {
    throw 'Profile-specific weight override was not generated.'
}
if ((Get-FileHash -LiteralPath (Join-Path $overrideOutput 'sister_blades_melinoe_starter.lua') -Algorithm SHA256).Hash -ne
    (Get-FileHash -LiteralPath (Join-Path $repo 'data\builds\sister_blades_melinoe_starter.lua') -Algorithm SHA256).Hash) {
    throw 'Shared mechanics weight override contaminated a later profile.'
}
Write-Output 'PASS: canonical validation, deterministic generation, generated Lua validation, and scoring equivalence'
