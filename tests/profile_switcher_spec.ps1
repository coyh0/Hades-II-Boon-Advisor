$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$script = Join-Path $repo 'tools\Set-BoonAdvisorProfile.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('boon-advisor-profile-test-' + [Guid]::NewGuid())
$target = Join-Path $root 'plugin'
New-Item -ItemType Directory -Path (Join-Path $target 'config') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $target 'data\builds') -Force | Out-Null
$settings = Join-Path $target 'config\settings.lua'
$nl = [Environment]::NewLine
$original = 'return {' + $nl + '    DEBUG = true,' + $nl + '    UI_TEST_MODE = true,' + $nl + '    BUILD_PROFILE = "argent_skull_medea_mobalytics",' + $nl + '    OTHER = "preserve",' + $nl + '}' + $nl
[IO.File]::WriteAllText($settings, $original)
$registry = 'return {' + $nl + '    argent_skull_medea_mobalytics = { selectionKey = "argent_skull_medea_mobalytics" },' + $nl + '    moonstone_axe_melinoe_mobalytics = { selectionKey = "moonstone_axe_melinoe_mobalytics" },' + $nl + '}' + $nl
[IO.File]::WriteAllText((Join-Path $target 'data\builds\registry.lua'), $registry)
& $script -Profile argent_skull_medea_mobalytics -TargetPath $target | Out-Null
$changed = [IO.File]::ReadAllText($settings)
if ($changed -ne $original) { throw 'Idempotent Medea set rewrote settings.' }
& $script -Profile moonstone_axe_melinoe_mobalytics -TargetPath $target | Out-Null
$changed = [IO.File]::ReadAllText($settings)
if (($changed -notmatch 'BUILD_PROFILE\s*=\s*"moonstone_axe_melinoe_mobalytics"') -or
    ($changed -notmatch 'DEBUG\s*=\s*true') -or ($changed -notmatch 'UI_TEST_MODE\s*=\s*true') -or
    ($changed -notmatch 'OTHER\s*=\s*"preserve"')) {
    throw 'Medea -> Moonstone changed unrelated settings.'
}
& $script -Profile argent_skull_medea_mobalytics -TargetPath $target | Out-Null
if ([IO.File]::ReadAllText($settings) -notmatch 'BUILD_PROFILE\s*=\s*"argent_skull_medea_mobalytics"') {
    throw 'Moonstone -> Medea failed.'
}
$beforeMedeaSettings = [IO.File]::ReadAllText($settings)
& $script -Profile moonstone_axe_melinoe_mobalytics -TargetPath $target | Out-Null
$moonstoneSettings = [IO.File]::ReadAllText($settings)
if (($moonstoneSettings -notmatch 'BUILD_PROFILE\s*=\s*"moonstone_axe_melinoe_mobalytics"') -or
    ($moonstoneSettings -notmatch 'DEBUG\s*=\s*true') -or ($moonstoneSettings -notmatch 'UI_TEST_MODE\s*=\s*true') -or
    ($moonstoneSettings -notmatch 'OTHER\s*=\s*"preserve"') -or
    ($moonstoneSettings -replace 'BUILD_PROFILE\s*=\s*"[^"]+"', 'BUILD_PROFILE = "<profile>"') -ne
    ($beforeMedeaSettings -replace 'BUILD_PROFILE\s*=\s*"[^"]+"', 'BUILD_PROFILE = "<profile>"')) {
    throw 'Switching to Moonstone changed unrelated settings.'
}
$auto = Join-Path ([IO.Path]::GetTempPath()) ('profile-switcher-auto-' + [Guid]::NewGuid()); Copy-Item -LiteralPath $target -Destination $auto -Recurse
& $script -Profile auto -TargetPath $auto | Out-Null
if ([IO.File]::ReadAllText((Join-Path $auto 'config\settings.lua')) -notmatch 'BUILD_PROFILE\s*=\s*"auto"') { throw 'auto profile selection failed.' }
$showHash = (Get-FileHash -LiteralPath $settings -Algorithm SHA256).Hash
$shown = & $script -Show -TargetPath $target | Out-String
if (($shown -notmatch 'argent_skull_medea_mobalytics') -or
    ($shown -notmatch 'moonstone_axe_melinoe_mobalytics') -or
    ($shown -match '(?m)^Available profiles:.*\b(intermediate|morrigan_meta|starter)\b')) { throw '-Show inventory is stale.' }
if ((Get-FileHash -LiteralPath $settings -Algorithm SHA256).Hash -ne $showHash) { throw '-Show mutated settings.' }
if ((Get-Content -LiteralPath $script -Raw) -match ('auto\|' + 'intermediate\|' + 'starter\|' + 'morrigan_meta')) {
    throw 'Profile switcher reintroduced the obsolete fixed profile list.'
}
function Assert-Fails([string]$name, [scriptblock]$action) {
    try { & $action; throw "Expected failure: $name" } catch { if ($_.Exception.Message -like 'Expected failure:*') { throw } }
}
Assert-Fails 'missing settings' { & $script -Profile argent_skull_medea_mobalytics -TargetPath (Join-Path $root 'missing') }
Assert-Fails 'retired profile' { & $script -Profile intermediate -TargetPath $target }
Assert-Fails 'unknown generated profile' { & $script -Profile unknown -TargetPath $target }
$missingAssignment = Join-Path $root 'missing-assignment'
New-Item -ItemType Directory -Path (Join-Path $missingAssignment 'config') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $missingAssignment 'data\builds') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $missingAssignment 'config\settings.lua'), 'return { DEBUG = false }')
[IO.File]::WriteAllText((Join-Path $missingAssignment 'data\builds\registry.lua'), [IO.File]::ReadAllText((Join-Path $target 'data\builds\registry.lua')))
Assert-Fails 'missing BUILD_PROFILE' { & $script -Show -TargetPath $missingAssignment }
$duplicate = Join-Path $root 'duplicate'
New-Item -ItemType Directory -Path (Join-Path $duplicate 'config') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $duplicate 'data\builds') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $duplicate 'config\settings.lua'), 'BUILD_PROFILE = "auto"' + $nl + 'BUILD_PROFILE = "argent_skull_medea_mobalytics"' + $nl)
[IO.File]::WriteAllText((Join-Path $duplicate 'data\builds\registry.lua'), [IO.File]::ReadAllText((Join-Path $target 'data\builds\registry.lua')))
Assert-Fails 'duplicate BUILD_PROFILE' { & $script -Show -TargetPath $duplicate }
Write-Output 'PASS: profile switcher set/show/idempotency/validation/preservation tests'
