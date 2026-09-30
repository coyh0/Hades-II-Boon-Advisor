[CmdletBinding()]
param(
    [string]$PythonPath,
    [string]$LuaDllPath
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$generator = Join-Path $repo 'tools\Generate-BoonAdvisorProfiles.ps1'
$windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
$python = if ($PythonPath) { $PythonPath } elseif ($env:BOON_ADVISOR_PYTHON) { $env:BOON_ADVISOR_PYTHON } else { (Get-Command python.exe -ErrorAction Stop).Source }
$dll = if ($LuaDllPath) { $LuaDllPath } elseif ($env:BOON_ADVISOR_LUA_DLL) { $env:BOON_ADVISOR_LUA_DLL } elseif ($env:HADES2_GAME_ROOT) { Join-Path $env:HADES2_GAME_ROOT 'Ship\lua52.dll' } else { throw 'LuaDllPath is required.' }
foreach ($path in @($python, $dll)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file missing: $path" }
}
$root = Join-Path ([IO.Path]::GetTempPath()) ('boon-canonical-test-' + [Guid]::NewGuid().ToString('N'))
$profilesSource = Join-Path $repo 'data\canonical\profiles'
$mechanicsSource = Join-Path $repo 'data\canonical\mechanics'
$expectedNames = @('argent_skull_medea_mobalytics.lua', 'moonstone_axe_melinoe_mobalytics.lua', 'registry.lua')
New-Item -ItemType Directory -Path $root | Out-Null
try {
    function Invoke-Generation([string[]]$Arguments) {
        & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator @Arguments | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Canonical generation failed: $($Arguments -join ' ')" }
    }
    Invoke-Generation @('-ValidateOnly')
    $first = Join-Path $root 'first'
    $second = Join-Path $root 'second'
    Invoke-Generation @('-OutputDirectory', $first)
    Invoke-Generation @('-OutputDirectory', $second)
    $firstFiles = @(Get-ChildItem -LiteralPath $first -Filter '*.lua' -File | Sort-Object Name)
    if (($firstFiles.Name -join '|') -cne ($expectedNames -join '|')) {
        throw "Generated inventory differs from two active profiles plus registry: $($firstFiles.Name -join ', ')"
    }
    $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
    foreach ($file in $firstFiles) {
        $text = [IO.File]::ReadAllText($file.FullName, $strictUtf8)
        if ($text -match 'loadfile\s*\(' -or $text -match '[\u00C3\u00C2\u00E2\uFFFD]') {
            throw "Generated profile has a runtime dependency or encoding damage: $($file.Name)"
        }
        $secondFile = Join-Path $second $file.Name
        $checkedIn = Join-Path $repo ('data\builds\' + $file.Name)
        if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $secondFile -Algorithm SHA256).Hash -or
            (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $checkedIn -Algorithm SHA256).Hash) {
            throw "Generation is not deterministic or differs from checked-in output: $($file.Name)"
        }
    }
    $medeaText = [IO.File]::ReadAllText((Join-Path $first 'argent_skull_medea_mobalytics.lua'), $strictUtf8)
    if (-not $medeaText.Contains(('Technique C' + [char]0x00E9 + 'leste'))) { throw 'Medea UTF-8 localization changed.' }
    $env:BOON_CANONICAL_OUTPUT = $first
    try {
        & $python (Join-Path $repo 'tests\run_lua52.py') $dll --only 'tests/canonical_generated_spec.lua'
        if ($LASTEXITCODE -ne 0) { throw 'Generated Lua semantic validation failed.' }
    }
    finally { Remove-Item Env:BOON_CANONICAL_OUTPUT -ErrorAction SilentlyContinue }

    function Assert-InvalidProfile([string]$Name, [scriptblock]$Mutate) {
        $case = Join-Path $root $Name
        Copy-Item -LiteralPath $profilesSource -Destination $case -Recurse
        $path = Join-Path $case 'argent_skull_medea_mobalytics.json'
        $profile = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        & $Mutate $profile
        [IO.File]::WriteAllText($path, ($profile | ConvertTo-Json -Depth 100), (New-Object System.Text.UTF8Encoding($false)))
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { $null = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -CanonicalDirectory $case -ValidateOnly 2>$null; $exit = $LASTEXITCODE }
        finally { $ErrorActionPreference = $previous }
        if ($exit -eq 0) { throw "Invalid profile was accepted: $Name" }
    }
    Assert-InvalidProfile 'invalid-schema' { param($p) $p.schemaVersion = 2 }
    Assert-InvalidProfile 'missing-selection-key' { param($p) $p.PSObject.Properties.Remove('selectionKey') }
    Assert-InvalidProfile 'reserved-selection-key' { param($p) $p.selectionKey = 'auto' }
    Assert-InvalidProfile 'invalid-slot-policy' { param($p) $p.slots.Special.slotPolicy = 'invalid' }
    Assert-InvalidProfile 'path-like-id' { param($p) $p.id = '../escape' }
    Assert-InvalidProfile 'invalid-id-syntax' { param($p) $p.id = 'profile-name' }
    Assert-InvalidProfile 'reserved-id' { param($p) $p.id = 'registry' }
    Assert-InvalidProfile 'unknown-weapon' { param($p) $p.weapon = 'UnknownWeapon' }
    Assert-InvalidProfile 'unknown-aspect' { param($p) $p.aspect = 'UnknownAspect' }
    Assert-InvalidProfile 'template-mismatch' { param($p) $p.aspect = 'AxeRecoveryAspect' }

    function Assert-InvalidCatalog([string]$Name, [string]$Json) {
        $path = Join-Path $root ($Name + '.json')
        [IO.File]::WriteAllText($path, $Json, (New-Object System.Text.UTF8Encoding($false)))
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { $null = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator -CatalogPath $path -ValidateOnly 2>$null; $exit = $LASTEXITCODE }
        finally { $ErrorActionPreference = $previous }
        if ($exit -eq 0) { throw "Invalid catalog was accepted: $Name" }
    }
    Assert-InvalidCatalog 'duplicate-catalog-weapon' '{"schemaVersion":1,"weapons":[{"runtimeWeaponId":"WeaponDagger","aspects":[{"runtimeAspectId":"DaggerBackstabAspect"}]},{"runtimeWeaponId":"WeaponDagger","aspects":[{"runtimeAspectId":"DaggerTripleAspect"}]}]}'
    Assert-InvalidCatalog 'duplicate-catalog-aspect' '{"schemaVersion":1,"weapons":[{"runtimeWeaponId":"WeaponDagger","aspects":[{"runtimeAspectId":"DaggerBackstabAspect"},{"runtimeAspectId":"DaggerBackstabAspect"}]}]}'

    $isolatedProfiles = Join-Path $root 'isolated-profiles'
    $isolatedMechanics = Join-Path $root 'isolated-mechanics'
    Copy-Item -LiteralPath $profilesSource -Destination $isolatedProfiles -Recurse
    Copy-Item -LiteralPath $mechanicsSource -Destination $isolatedMechanics -Recurse
    $isolatedOutput = Join-Path $root 'isolated-output'
    Invoke-Generation @('-CanonicalDirectory', $isolatedProfiles, '-MechanicsDirectory', $isolatedMechanics, '-OutputDirectory', $isolatedOutput)
    foreach ($name in $expectedNames) {
        if ((Get-FileHash -LiteralPath (Join-Path $isolatedOutput $name) -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath (Join-Path $first $name) -Algorithm SHA256).Hash) {
            throw "Isolated JSON generation differs: $name"
        }
    }

    $overrideProfiles = Join-Path $root 'override-profiles'
    Copy-Item -LiteralPath $profilesSource -Destination $overrideProfiles -Recurse
    $override = Get-Content -LiteralPath (Join-Path $overrideProfiles 'argent_skull_medea_mobalytics.json') -Raw | ConvertFrom-Json
    $override.id = 'synthetic_medea_override'
    $override.selectionKey = 'synthetic_medea_override'
    $override | Add-Member -NotePropertyName weights -NotePropertyValue @{ BUILD_PREFERRED = 999 }
    [IO.File]::WriteAllText((Join-Path $overrideProfiles 'synthetic_medea_override.json'),
        ($override | ConvertTo-Json -Depth 100), (New-Object System.Text.UTF8Encoding($false)))
    $overrideOutput = Join-Path $root 'override-output'
    Invoke-Generation @('-CanonicalDirectory', $overrideProfiles, '-OutputDirectory', $overrideOutput)
    if ((Get-Content -LiteralPath (Join-Path $overrideOutput 'synthetic_medea_override.lua') -Raw) -notmatch 'BUILD_PREFERRED = 999' -or
        (Get-FileHash -LiteralPath (Join-Path $overrideOutput 'argent_skull_medea_mobalytics.lua') -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath (Join-Path $first 'argent_skull_medea_mobalytics.lua') -Algorithm SHA256).Hash) {
        throw 'Synthetic profile override contaminated its source profile.'
    }
    & (Join-Path $PSScriptRoot 'moonstone_projection_spec.ps1')
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'Moonstone projection failed.' }
    Write-Output 'PASS: active canonical validation, deterministic generation, Lua semantics and isolated overrides'
}
finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
