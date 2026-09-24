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
    $original = [IO.File]::ReadAllText($path)
    if (-not $original.Contains($find)) { throw "Missing fixture pattern for $name" }
    [IO.File]::WriteAllText($path, $original.Replace($find, $replace))
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
if ($firstFiles.Count -ne 4) { throw 'Generated output must contain three profiles and one registry.' }
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
    $path = Join-Path $case 'sister_blades_melinoe_intermediate.json'
    $original = [IO.File]::ReadAllText($path)
    if (-not $original.Contains($find)) { throw "Missing fixture pattern for $name" }
    [IO.File]::WriteAllText($path, $original.Replace($find, $replace))
    try {
        & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -CanonicalDirectory $case -ValidateOnly 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { throw "Expected failure: $name" }
    }
    catch { if ($_.Exception.Message -like 'Expected failure:*') { throw } }
}
Assert-Fails 'invalid-schema' '"schemaVersion": 1' '"schemaVersion": 2'
Assert-Fails 'missing-selection-key' '"selectionKey": "intermediate",' ''
Assert-Fails 'reserved-auto-selection-key' '"selectionKey": "intermediate"' '"selectionKey": "auto"'
Assert-Fails 'invalid-policy' '"slotPolicy": "reserved"' '"slotPolicy": "invalid"'
Assert-Fails 'path-like-profile-id' '"id": "sister_blades_melinoe_intermediate"' '"id": "../escape"'
Assert-Fails 'invalid-profile-id-syntax' '"id": "sister_blades_melinoe_intermediate"' '"id": "profile-name"'
Assert-Fails 'reserved-registry-profile-id' '"id": "sister_blades_melinoe_intermediate"' '"id": "registry"'
function Assert-Coat-Fails([string]$name, [string]$find, [string]$replace) {
    $case = Join-Path $root $name
    Copy-Item -LiteralPath (Join-Path $repo 'data\canonical\profiles') -Destination $case -Recurse
    $path = Join-Path $case 'black_coat_melinoe_intermediate.json'
    $original = [IO.File]::ReadAllText($path)
    if (-not $original.Contains($find)) { throw "Missing fixture pattern for $name" }
    [IO.File]::WriteAllText($path, $original.Replace($find, $replace))
    try {
        & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -CanonicalDirectory $case -ValidateOnly 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { throw "Expected failure: $name" }
    }
    catch { if ($_.Exception.Message -like 'Expected failure:*') { throw } }
}
Assert-Coat-Fails 'duplicate-selection-key' '"selectionKey": "coat_melinoe_intermediate"' '"selectionKey": "intermediate"'
Assert-Coat-Fails 'duplicate-id' '"id": "black_coat_melinoe_intermediate"' '"id": "sister_blades_melinoe_intermediate"'
Assert-Coat-Fails 'duplicate-hammer-plan-id' '"SuitAttackSpeedTrait"' '"SuitDashAttackTrait"'
Assert-Coat-Fails 'invalid-hammer-plan-priority' '"priority": 2' '"priority": 0'
Assert-Coat-Fails 'invalid-hammer-plan-classification' '"classification": "alternative"' '"classification": "unknown"'
function Assert-KeepsakePlan([string]$profileName, [hashtable]$expected) {
    $profile = Get-Content -LiteralPath (Join-Path $repo "data\canonical\profiles\$profileName.json") -Raw | ConvertFrom-Json
    foreach ($phase in @('Start', 'R2', 'R3', 'Final')) {
        $actual = @($profile.keepsakePlan.$phase)
        if ($actual.Count -ne $expected[$phase].Count) { throw "$profileName keepsakePlan.$phase count mismatch." }
        for ($index = 0; $index -lt $actual.Count; $index++) {
            $entry = $actual[$index]; $want = $expected[$phase][$index]
            foreach ($field in @('traitId', 'classification', 'documentaryPriority', 'conditionText', 'recommendationId')) {
                if ($entry.$field -cne $want[$field]) { throw "$profileName keepsakePlan.$phase entry $index $field mismatch." }
            }
        }
    }
}
Assert-KeepsakePlan 'sister_blades_melinoe_intermediate' @{
    Start = @(
        @{ traitId = 'ForceAresBoonKeepsake'; classification = 'main'; documentaryPriority = 1; conditionText = 'If owner Ares route selected'; recommendationId = 'br2_blades_melinoe_intermediate_6879d93624658ee8' },
        @{ traitId = 'ForceZeusBoonKeepsake'; classification = 'alternative'; documentaryPriority = 1; conditionText = 'If Zeus-first Mobalytics route selected'; recommendationId = 'br2_blades_melinoe_intermediate_ee98ea3a2027845e' }
    ); R2 = @(
        @{ traitId = 'ForceZeusBoonKeepsake'; classification = 'conditional'; documentaryPriority = 1; conditionText = 'If Heaven Flourish missing after Ares start'; recommendationId = 'br2_blades_melinoe_intermediate_79c367872fa86f25' },
        @{ traitId = 'ForceAphroditeBoonKeepsake'; classification = 'alternative'; documentaryPriority = 2; conditionText = 'If Aphrodite Attack pivot selected'; recommendationId = 'br2_blades_melinoe_intermediate_784e30cff6770b94' }
    ); R3 = @(
        @{ traitId = 'TempHammerKeepsake'; classification = 'conditional'; documentaryPriority = 2; conditionText = 'If key Hammer missing and random upgrade acceptable'; recommendationId = 'br2_blades_melinoe_intermediate_536ab88a6673beba' },
        @{ traitId = 'TimedBuffKeepsake'; classification = 'situational'; documentaryPriority = 2; conditionText = 'If core boons secured and speed desired'; recommendationId = 'br2_blades_melinoe_intermediate_996475bb0bcc7090' }
    ); Final = @(
        @{ traitId = 'ReincarnationKeepsake'; classification = 'conditional'; documentaryPriority = 1; conditionText = 'If extra Death Defiance needed'; recommendationId = 'br2_blades_melinoe_intermediate_66cba86eda75c5fb' },
        @{ traitId = 'BossPreDamageKeepsake'; classification = 'alternative'; documentaryPriority = 2; conditionText = 'If survival already secure'; recommendationId = 'br2_blades_melinoe_intermediate_192669216c0c2294' }
    )
}
Assert-KeepsakePlan 'sister_blades_morrigan_meta' @{
    Start = @(
        @{ traitId = 'ForceHeraBoonKeepsake'; classification = 'main'; documentaryPriority = 1; conditionText = 'If Hera Attack / Born Gain route selected'; recommendationId = 'br2_blades_morrigan_meta_eb0cc1beec69ff2a' },
        @{ traitId = 'ForceApolloBoonKeepsake'; classification = 'alternative'; documentaryPriority = 1; conditionText = 'If Nova Strike / Lucid Gain route selected'; recommendationId = 'br2_blades_morrigan_meta_0c1ab9d2d5838e52' }
    ); R2 = @(
        @{ traitId = 'ForceHeraBoonKeepsake'; classification = 'conditional'; documentaryPriority = 1; conditionText = 'If Born Gain or Hera Attack missing after Apollo start'; recommendationId = 'br2_blades_morrigan_meta_9dc8940e35c783f4' },
        @{ traitId = 'ForceApolloBoonKeepsake'; classification = 'alternative'; documentaryPriority = 2; conditionText = 'If safe Attack or Lucid Gain still missing'; recommendationId = 'br2_blades_morrigan_meta_045b71a5ec6ae51f' },
        @{ traitId = 'RandomBlessingKeepsake'; classification = 'situational'; documentaryPriority = 2; conditionText = 'If Attack and Gain already secured'; recommendationId = 'br2_blades_morrigan_meta_ae16c2ee636cfc84' }
    ); R3 = @(
        @{ traitId = 'BossPreDamageKeepsake'; classification = 'situational'; documentaryPriority = 2; conditionText = 'If next Guardian needs damage/safety'; recommendationId = 'br2_blades_morrigan_meta_e991eff83952900f' },
        @{ traitId = 'ReincarnationKeepsake'; classification = 'conditional'; documentaryPriority = 2; conditionText = 'If run survival is threatened'; recommendationId = 'br2_blades_morrigan_meta_468adabe05b33f40' }
    ); Final = @(
        @{ traitId = 'BossPreDamageKeepsake'; classification = 'main'; documentaryPriority = 1; conditionText = 'If room survival secure before final Guardian'; recommendationId = 'br2_blades_morrigan_meta_900dcecd675c94ad' },
        @{ traitId = 'ReincarnationKeepsake'; classification = 'alternative'; documentaryPriority = 1; conditionText = 'If extra Death Defiance needed'; recommendationId = 'br2_blades_morrigan_meta_b9968febb27e3b57' }
    )
}
Assert-KeepsakePlan 'black_coat_melinoe_intermediate' @{
    Start = @(
        @{ traitId = 'ForcePoseidonBoonKeepsake'; classification = 'main'; documentaryPriority = 1; conditionText = 'Always'; recommendationId = 'br2_coat_melinoe_intermediate_05cf1f64ff35b208' }
    ); R2 = @(
        @{ traitId = 'ForceAresBoonKeepsake'; classification = 'conditional'; documentaryPriority = 1; conditionText = 'If Ares Special or Grievous Blow missing'; recommendationId = 'br2_coat_melinoe_intermediate_26a4d7fa4e741847' }
    ); R3 = @(
        @{ traitId = 'TimedBuffKeepsake'; classification = 'main'; documentaryPriority = 1; conditionText = 'If main boons secured'; recommendationId = 'br2_coat_melinoe_intermediate_a90140fb0ff5c9e0' },
        @{ traitId = 'TempHammerKeepsake'; classification = 'conditional'; documentaryPriority = 2; conditionText = 'If key Hammer missing and random upgrade acceptable'; recommendationId = 'br2_coat_melinoe_intermediate_760fb32ab047f5fe' }
    ); Final = @(
        @{ traitId = 'AthenaEncounterKeepsake'; classification = 'conditional'; documentaryPriority = 1; conditionText = 'If Death Defiances depleted or defensive boon needed'; recommendationId = 'br2_coat_melinoe_intermediate_ba28f813ff6d8a27' },
        @{ traitId = 'ReincarnationKeepsake'; classification = 'alternative'; documentaryPriority = 1; conditionText = 'If Death Defiances remain and extra safety needed'; recommendationId = 'br2_coat_melinoe_intermediate_98387ade9e9341df' }
    )
}
function Assert-KeepsakePlan-Fails([string]$name, [string]$profileName, [string]$missingPhase) {
    $case = Join-Path $root $name
    Copy-Item -LiteralPath (Join-Path $repo 'data\canonical\profiles') -Destination $case -Recurse
    $path = Join-Path $case "$profileName.json"
    $profile = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $profile.keepsakePlan.PSObject.Properties.Remove($missingPhase)
    [IO.File]::WriteAllText($path, ($profile | ConvertTo-Json -Depth 20))
    try {
        & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -CanonicalDirectory $case -ValidateOnly 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { throw "Expected failure: $name" }
    }
    catch { if ($_.Exception.Message -like 'Expected failure:*') { throw } }
}
Assert-KeepsakePlan-Fails 'keepsake-plan-missing-phase' 'black_coat_melinoe_intermediate' 'Final'
function Assert-KeepsakeEntry-Fails([string]$name, [string]$profileName, [string]$phase, [string]$find, [string]$replace) {
    $case = Join-Path $root $name
    Copy-Item -LiteralPath (Join-Path $repo 'data\canonical\profiles') -Destination $case -Recurse
    $path = Join-Path $case "$profileName.json"
    $profile = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $entry = $profile.keepsakePlan.$phase[0]
    $entry.$find = $replace
    [IO.File]::WriteAllText($path, ($profile | ConvertTo-Json -Depth 20))
    try {
        & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -CanonicalDirectory $case -ValidateOnly 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { throw "Expected failure: $name" }
    }
    catch { if ($_.Exception.Message -like 'Expected failure:*') { throw } }
}
Assert-KeepsakeEntry-Fails 'keepsake-plan-duplicate-trait' 'black_coat_melinoe_intermediate' 'Final' 'traitId' 'ReincarnationKeepsake'
Assert-KeepsakeEntry-Fails 'keepsake-plan-invalid-classification' 'black_coat_melinoe_intermediate' 'Final' 'classification' 'unknown'
Assert-KeepsakeEntry-Fails 'keepsake-plan-invalid-priority' 'black_coat_melinoe_intermediate' 'Final' 'documentaryPriority' 0
Assert-KeepsakeEntry-Fails 'keepsake-plan-empty-recommendation' 'black_coat_melinoe_intermediate' 'Final' 'recommendationId' ''
foreach ($profileName in @('sister_blades_morrigan_meta', 'black_coat_melinoe_intermediate')) {
    $profile = Get-Content -LiteralPath (Join-Path $repo "data\canonical\profiles\$profileName.json") -Raw | ConvertFrom-Json
    foreach ($phase in @('Start', 'R2', 'R3', 'Final')) {
        if ($null -eq $profile.keepsakePlan.$phase) { throw "$profileName missing keepsakePlan.$phase" }
        foreach ($entry in @($profile.keepsakePlan.$phase)) {
            foreach ($field in @('traitId', 'classification', 'documentaryPriority', 'conditionText', 'recommendationId')) {
                if ($null -eq $entry.PSObject.Properties[$field]) { throw "$profileName keepsakePlan.$phase missing $field" }
            }
        }
    }
}
$coatProfile = Get-Content -LiteralPath (Join-Path $repo 'data\canonical\profiles\black_coat_melinoe_intermediate.json') -Raw | ConvertFrom-Json
if (@($coatProfile.autoSignals) -join '|' -cne 'ForcePoseidonBoonKeepsake') { throw 'Black Coat Poseidon autoSignal changed.' }
$unsafeProfiles = Join-Path $root 'unsafe-id-generation-profiles'
Copy-Item -LiteralPath (Join-Path $repo 'data\canonical\profiles') -Destination $unsafeProfiles -Recurse
$unsafeProfilePath = Join-Path $unsafeProfiles 'sister_blades_melinoe_intermediate.json'
[IO.File]::WriteAllText($unsafeProfilePath, ([IO.File]::ReadAllText($unsafeProfilePath)).Replace(
    '"id": "sister_blades_melinoe_intermediate"', '"id": "../escape"'))
$unsafeOutput = Join-Path $root 'unsafe-id-generation-output'
$unsafeGeneratorExitCode = 0
$previousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    $null = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator `
        -CanonicalDirectory $unsafeProfiles -OutputDirectory $unsafeOutput 2>$null
    $unsafeGeneratorExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
if ($unsafeGeneratorExitCode -eq 0 -or (Test-Path -LiteralPath (Join-Path $root 'escape.lua')) -or
    (Test-Path -LiteralPath (Join-Path $unsafeOutput 'escape.lua'))) {
    throw 'Unsafe profile id generated or escaped to a Lua filename.'
}
Assert-Fails 'contradiction' '"alternatives": []' '"alternatives": ["AphroditeWeaponBoon"]'
Assert-Fails 'duplicate-slot-id' '"traitId": "ApolloWeaponBoon"' '"traitId": "AphroditeWeaponBoon"'
Assert-Fails 'malformed-role-array' '"core": []' '"core": "AphroditeWeaponBoon"'
Assert-Fails 'invalid-branch-priority' '"traitId": "ApolloWeaponBoon", "classification": "alternative", "priority": 1' '"traitId": "ApolloWeaponBoon", "classification": "alternative", "priority": 0'
Assert-Fails 'invalid-branch-classification' '"traitId": "ApolloWeaponBoon", "classification": "alternative"' '"traitId": "ApolloWeaponBoon", "classification": "unknown"'
Assert-Fails 'unknown-branch-condition' '"traitId": "AresWeaponBoon", "classification": "alternative", "priority": 2' '"traitId": "AresWeaponBoon", "classification": "conditional", "priority": 2, "condition": { "state": "unresolved", "code": "UNKNOWN" }'
Assert-Fails 'unverified-branch-id' '"traitId": "ApolloWeaponBoon"' '"traitId": "UnverifiedAttackBoon"'
Assert-Fails 'unknown-slot' '"Special": {' '"Omega": {'
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
$override = [IO.File]::ReadAllText((Join-Path $overrideProfiles 'sister_blades_melinoe_intermediate.json'))
$override = $override.Replace('"id": "sister_blades_melinoe_intermediate"', '"id": "aaa_shared_mechanics_override"')
$override = $override.Replace('"selectionKey": "intermediate"', '"selectionKey": "aaa_shared_mechanics_override"')
$override = $override.Replace('"mechanicsTemplate": "sister_blades_melinoe",', '"mechanicsTemplate": "sister_blades_melinoe",' + [Environment]::NewLine + '  "weights": { "FILL_EMPTY_PRIMARY_CORE": 999 },')
[IO.File]::WriteAllText($overridePath, $override)
$overrideOutput = Join-Path $root 'override-output'
& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -CanonicalDirectory $overrideProfiles -OutputDirectory $overrideOutput | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Shared mechanics override isolation generation failed.' }
if ((Get-Content -LiteralPath (Join-Path $overrideOutput 'aaa_shared_mechanics_override.lua') -Raw) -notmatch 'FILL_EMPTY_PRIMARY_CORE = 999') {
    throw 'Profile-specific weight override was not generated.'
}
if ((Get-FileHash -LiteralPath (Join-Path $overrideOutput 'sister_blades_melinoe_intermediate.lua') -Algorithm SHA256).Hash -ne
    (Get-FileHash -LiteralPath (Join-Path $repo 'data\builds\sister_blades_melinoe_intermediate.lua') -Algorithm SHA256).Hash) {
    throw 'Shared mechanics weight override contaminated a later profile.'
}
$expectedMelinoeHammerPlan = @(
    @{ traitId = 'DaggerDashAttackTripleTrait'; priority = 1; classification = 'priority' },
    @{ traitId = 'DaggerFinalHitTrait'; priority = 2; classification = 'alternative' },
    @{ traitId = 'DaggerRapidAttackTrait'; priority = 2; classification = 'alternative' },
    @{ traitId = 'DaggerSpecialReturnTrait'; priority = 2; classification = 'alternative' },
    @{ traitId = 'DaggerAttackFinisherTrait'; priority = 3; classification = 'alternative' }
)
foreach ($profileName in @('sister_blades_melinoe_intermediate')) {
    $profile = Get-Content -LiteralPath (Join-Path $repo "data\canonical\profiles\$profileName.json") -Raw | ConvertFrom-Json
    if (@($profile.hammerPlan).Count -ne $expectedMelinoeHammerPlan.Count) { throw "$profileName Hammer plan count mismatch." }
    for ($index = 0; $index -lt $expectedMelinoeHammerPlan.Count; $index++) {
        $actual = $profile.hammerPlan[$index]
        $expected = $expectedMelinoeHammerPlan[$index]
        if ($actual.traitId -cne $expected.traitId -or $actual.priority -ne $expected.priority -or
            $actual.classification -cne $expected.classification -or
            $null -ne $actual.PSObject.Properties['condition']) {
            throw "$profileName Hammer plan entry $index mismatch or gained a condition."
        }
    }
    if (@($profile.hammerPlan | Where-Object { $_.traitId -ceq 'DaggerSpecialJumpTrait' }).Count -ne 0) {
        throw "$profileName unresolved Dancing Knives entered hammerPlan."
    }
}
Write-Output 'PASS: canonical validation, deterministic generation, generated Lua validation, and scoring equivalence'
