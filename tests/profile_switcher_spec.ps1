$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$script = Join-Path $repo 'tools\Set-BoonAdvisorProfile.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('boon-advisor-profile-test-' + [Guid]::NewGuid())
$target = Join-Path $root 'plugin'
New-Item -ItemType Directory -Path (Join-Path $target 'config') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $target 'data\builds') -Force | Out-Null
$settings = Join-Path $target 'config\settings.lua'
$nl = [Environment]::NewLine
$original = 'return {' + $nl + '    DEBUG = true,' + $nl + '    UI_TEST_MODE = true,' + $nl + '    BUILD_PROFILE = "intermediate",' + $nl + '    OTHER = "preserve",' + $nl + '}' + $nl
[IO.File]::WriteAllText($settings, $original)
[IO.File]::WriteAllText((Join-Path $target 'data\builds\registry.lua'), 'return {' + $nl + '    coat_melinoe_intermediate = { selectionKey = "coat_melinoe_intermediate" },' + $nl + '    intermediate = { selectionKey = "intermediate" },' + $nl + '    starter = { selectionKey = "starter" },' + $nl + '    morrigan_meta = { selectionKey = "morrigan_meta" },' + $nl + '}' + $nl)
& $script -Profile starter -TargetPath $target | Out-Null
$changed = [IO.File]::ReadAllText($settings)
if (($changed -notmatch 'BUILD_PROFILE\s*=\s*"starter"') -or ($changed -notmatch 'DEBUG\s*=\s*true') -or
    ($changed -notmatch 'UI_TEST_MODE\s*=\s*true') -or ($changed -notmatch 'OTHER\s*=\s*"preserve"')) {
    throw 'intermediate -> starter changed more than BUILD_PROFILE.'
}
$starterHash = (Get-FileHash -LiteralPath $settings -Algorithm SHA256).Hash
& $script -Profile starter -TargetPath $target | Out-Null
if ((Get-FileHash -LiteralPath $settings -Algorithm SHA256).Hash -ne $starterHash) { throw 'Idempotent set rewrote settings.' }
& $script -Profile intermediate -TargetPath $target | Out-Null
if ([IO.File]::ReadAllText($settings) -notmatch 'BUILD_PROFILE\s*=\s*"intermediate"') { throw 'starter -> intermediate failed.' }
& $script -Profile morrigan_meta -TargetPath $target | Out-Null
if ([IO.File]::ReadAllText($settings) -notmatch 'BUILD_PROFILE\s*=\s*"morrigan_meta"') { throw 'dynamic Morrigan profile selection failed.' }
$beforeCoatSettings = [IO.File]::ReadAllText($settings)
& $script -Profile coat_melinoe_intermediate -TargetPath $target | Out-Null
$coatSettings = [IO.File]::ReadAllText($settings)
if (($coatSettings -notmatch 'BUILD_PROFILE\s*=\s*"coat_melinoe_intermediate"') -or
    ($coatSettings -notmatch 'DEBUG\s*=\s*true') -or ($coatSettings -notmatch 'UI_TEST_MODE\s*=\s*true') -or
    ($coatSettings -notmatch 'OTHER\s*=\s*"preserve"') -or
    ($coatSettings -replace 'BUILD_PROFILE\s*=\s*"[^"]+"', 'BUILD_PROFILE = "<profile>"') -ne
    ($beforeCoatSettings -replace 'BUILD_PROFILE\s*=\s*"[^"]+"', 'BUILD_PROFILE = "<profile>"')) {
    throw 'Switching to Black Coat changed unrelated settings.'
}
$auto = Join-Path ([IO.Path]::GetTempPath()) ('profile-switcher-auto-' + [Guid]::NewGuid()); Copy-Item -LiteralPath $target -Destination $auto -Recurse
& $script -Profile auto -TargetPath $auto | Out-Null
if ([IO.File]::ReadAllText((Join-Path $auto 'config\settings.lua')) -notmatch 'BUILD_PROFILE\s*=\s*"auto"') { throw 'auto profile selection failed.' }
$showHash = (Get-FileHash -LiteralPath $settings -Algorithm SHA256).Hash
$shown = & $script -Show -TargetPath $target | Out-String
if ($shown -notmatch 'coat_melinoe_intermediate') { throw '-Show omitted Black Coat from available profiles.' }
if ((Get-FileHash -LiteralPath $settings -Algorithm SHA256).Hash -ne $showHash) { throw '-Show mutated settings.' }
if ((Get-Content -LiteralPath $script -Raw) -match ('auto\|' + 'intermediate\|' + 'starter\|' + 'morrigan_meta')) {
    throw 'Profile switcher reintroduced the obsolete fixed profile list.'
}
function Assert-Fails([string]$name, [scriptblock]$action) {
    try { & $action; throw "Expected failure: $name" } catch { if ($_.Exception.Message -like 'Expected failure:*') { throw } }
}
Assert-Fails 'missing settings' { & $script -Profile starter -TargetPath (Join-Path $root 'missing') }
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
[IO.File]::WriteAllText((Join-Path $duplicate 'config\settings.lua'), 'BUILD_PROFILE = "starter"' + $nl + 'BUILD_PROFILE = "intermediate"' + $nl)
[IO.File]::WriteAllText((Join-Path $duplicate 'data\builds\registry.lua'), [IO.File]::ReadAllText((Join-Path $target 'data\builds\registry.lua')))
Assert-Fails 'duplicate BUILD_PROFILE' { & $script -Show -TargetPath $duplicate }
Write-Output 'PASS: profile switcher set/show/idempotency/validation/preservation tests'
