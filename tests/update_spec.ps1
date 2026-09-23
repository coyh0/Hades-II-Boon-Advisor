$ErrorActionPreference = 'Stop'
$ConfirmPreference = 'None'
$repo = Split-Path $PSScriptRoot -Parent
$update = Join-Path $repo 'tools\Update-BoonAdvisor.ps1'
$stage = Join-Path $repo 'tools\Stage-Probe.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('boon-advisor-update-' + [Guid]::NewGuid())
$package = Join-Path $fixture 'Local-HadesIIBoonAdvisor'; $game = Join-Path $fixture 'Game'; $plugins = Join-Path $game 'Ship\ReturnOfModding\plugins'; $target = Join-Path $plugins 'Local-HadesIIBoonAdvisor'
$dependencies = @(@('LuaENVY-ENVY','ENVY','1.2.0'),@('SGG_Modding-ModUtil','ModUtil','4.0.1'),@('SGG_Modding-ReLoad','ReLoad','1.0.2'),@('SGG_Modding-ENVY','ENVY','1.1.0'),@('SGG_Modding-DemonDaemon','DemonDaemon','1.1.0'),@('SGG_Modding-Chalk','Chalk','2.1.1'),@('SGG_Modding-SJSON','SJSON','1.0.0'))
function Assert-Throws([string]$Name, [scriptblock]$Action) { try { & $Action; throw "Expected failure: $Name" } catch { if ($_.Exception.Message -like 'Expected failure:*') { throw } } }
function Get-Tree([string]$Root) { @(Get-ChildItem -LiteralPath $Root -Recurse -File | ForEach-Object { ($_.FullName.Substring($Root.Length + 1)) + '=' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } | Sort-Object) }
function Test-BytesEqual([byte[]]$Left,[byte[]]$Right){if($null -eq $Left -or $null -eq $Right -or $Left.Length -ne $Right.Length){return $false};for($index=0;$index -lt $Left.Length;$index++){if($Left[$index] -ne $Right[$index]){return $false}};$true}
function New-Mock([string]$Name,[int]$Code,[switch]$RequireRuntime) { $path=Join-Path $fixture ($Name+'.ps1'); $guard=if($RequireRuntime){'param([string]$Mode)'+[Environment]::NewLine+'if($Mode -ne ''Runtime''){exit 9}'+[Environment]::NewLine}else{''}; [IO.File]::WriteAllText($path,($guard+'exit '+$Code)); $path }
function New-Fixture {
    New-Item -ItemType Directory -Path $plugins -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $game 'Ship\Hades2.exe'),'fixture executable'); [IO.File]::WriteAllText((Join-Path $game 'Ship\d3d12.dll'),'fixture loader')
    foreach($dependency in $dependencies){$dir=Join-Path $plugins $dependency[0]; New-Item -ItemType Directory -Path $dir -Force|Out-Null; [IO.File]::WriteAllText((Join-Path $dir 'manifest.json'),('{"name":"'+$dependency[1]+'","version_number":"'+$dependency[2]+'"}'))}
    $other=Join-Path $plugins 'OtherPlugin'; New-Item -ItemType Directory -Path $other -Force|Out-Null; [IO.File]::WriteAllText((Join-Path $other 'keep.txt'),'keep')
}
function New-OldInstall([switch]$WithoutSettings) {
    Copy-Item -LiteralPath $package -Destination $target -Recurse
    [IO.File]::WriteAllText((Join-Path $target 'manifest.json'),'{"name":"HadesIIBoonAdvisor","version_number":"0.0.9"}')
    [IO.File]::WriteAllText((Join-Path $target 'stale-old.lua'),'stale old file')
    if($WithoutSettings){Remove-Item -LiteralPath (Join-Path $target 'config\settings.lua')}else{[IO.File]::WriteAllBytes((Join-Path $target 'config\settings.lua'),[byte[]](0x72,0x65,0x74,0x75,0x72,0x6E,0x20,0x7B,0x0D,0x0A,0x20,0x20,0x20,0x20,0x44,0x45,0x42,0x55,0x47,0x20,0x3D,0x20,0x74,0x72,0x75,0x65,0x2C,0x0D,0x0A,0x7D,0x0D,0x0A))}
}
function Invoke-Update([string]$Compatibility,[string]$Probe,[switch]$WhatIf,[string]$FailurePoint){$parameters=@{GameRoot=$game;PackagePath=$package;CompatibilityScript=$Compatibility;ProcessProbe=$Probe};if($WhatIf){$parameters.WhatIf=$true};if(-not [string]::IsNullOrWhiteSpace($FailurePoint)){$parameters.InternalTestFailurePoint=$FailurePoint};& $update @parameters}
try {
    & $stage | Out-Null; Copy-Item -LiteralPath (Join-Path $repo 'dist\Local-HadesIIBoonAdvisor') -Destination $package -Recurse; New-Fixture
    $pass=New-Mock 'pass' 0 -RequireRuntime; $manual=New-Mock 'manual' 2 -RequireRuntime; $fail=New-Mock 'fail' 1 -RequireRuntime; $safe=New-Mock 'safe' 0; $running=New-Mock 'running' 1
    New-OldInstall; $oldSettings=[IO.File]::ReadAllBytes((Join-Path $target 'config\settings.lua')); $otherHash=(Get-FileHash (Join-Path $plugins 'OtherPlugin\keep.txt')).Hash; $exeHash=(Get-FileHash (Join-Path $game 'Ship\Hades2.exe')).Hash
    $beforePreflight=Get-Tree $target; Assert-Throws 'manual compatibility' { Invoke-Update $manual $safe }; Assert-Throws 'failed compatibility' { Invoke-Update $fail $safe }; Assert-Throws 'running game' { Invoke-Update $pass $running }
    $extra=Join-Path $package 'extra.lua'; [IO.File]::WriteAllText($extra,'extra'); Assert-Throws 'invalid package' { Invoke-Update $pass $safe }; Remove-Item -LiteralPath $extra
    $modUtil=Join-Path $plugins 'SGG_Modding-ModUtil'; Remove-Item -LiteralPath $modUtil -Recurse -Force; Assert-Throws 'dependency failure' { Invoke-Update $pass $safe }; New-Item -ItemType Directory -Path $modUtil | Out-Null; [IO.File]::WriteAllText((Join-Path $modUtil 'manifest.json'),'{"name":"ModUtil","version_number":"4.0.1"}')
    if(Compare-Object $beforePreflight (Get-Tree $target)){throw 'Preflight failure mutated active target'}
    Assert-Throws 'explicit AfterBackup injection' { Invoke-Update $pass $safe -FailurePoint 'AfterBackup' }
    Invoke-Update $pass $safe
    . (Join-Path $repo 'tools\BoonAdvisor.Install.Common.ps1'); Test-BoonAdvisorPackage $target | Out-Null
    if(Test-Path -LiteralPath (Join-Path $target 'stale-old.lua')){throw 'Successful update retained stale file'}; if(-not (Test-BytesEqual $oldSettings ([IO.File]::ReadAllBytes((Join-Path $target 'config\settings.lua'))))){throw 'Settings were not byte-preserved'}
    if(@(Get-ChildItem -LiteralPath $plugins -Force -Directory -Filter '.Local-HadesIIBoonAdvisor.*').Count -ne 0){throw 'Successful update left transaction directories'}
    if((Get-FileHash (Join-Path $plugins 'OtherPlugin\keep.txt')).Hash -ne $otherHash -or (Get-FileHash (Join-Path $game 'Ship\Hades2.exe')).Hash -ne $exeHash){throw 'Update changed external files'}
    Remove-Item -LiteralPath $target -Recurse -Force; New-OldInstall -WithoutSettings; $packageSettings=[IO.File]::ReadAllBytes((Join-Path $package 'config\settings.lua')); Invoke-Update $pass $safe
    if(-not (Test-BytesEqual $packageSettings ([IO.File]::ReadAllBytes((Join-Path $target 'config\settings.lua'))))){throw 'Missing old settings did not use package default'}
    Remove-Item -LiteralPath $target -Recurse -Force; Assert-Throws 'absent old target' { Invoke-Update $pass $safe }
    New-OldInstall; $before=Get-Tree $target; Invoke-Update $pass $safe -WhatIf; if((Compare-Object $before (Get-Tree $target))){throw 'WhatIf changed target'}
    $oldManifest=Join-Path $target 'manifest.json'; Remove-Item -LiteralPath $oldManifest; Assert-Throws 'old manifest missing' { Invoke-Update $pass $safe }; [IO.File]::WriteAllText($oldManifest,'{"name":"Wrong","version_number":"0.0.9"}'); Assert-Throws 'old manifest wrong identity' { Invoke-Update $pass $safe }; [IO.File]::WriteAllText($oldManifest,'{"name":"HadesIIBoonAdvisor","version_number":"0.0.9"}')
    $before=Get-Tree $target; Assert-Throws 'rollback after backup' { Invoke-Update $pass $safe -FailurePoint 'AfterBackup' }; if(Compare-Object $before (Get-Tree $target)){throw 'Rollback after backup did not restore old tree'}
    $before=Get-Tree $target; Assert-Throws 'rollback after target' { Invoke-Update $pass $safe -FailurePoint 'AfterTarget' }; if(Compare-Object $before (Get-Tree $target)){throw 'Rollback after target did not restore old tree'}
    Assert-Throws 'rollback failure' { Invoke-Update $pass $safe -FailurePoint 'AfterBackup,Rollback' }; if(-not(Test-Path -LiteralPath $target) -and @(Get-ChildItem -LiteralPath $plugins -Directory -Filter '.Local-HadesIIBoonAdvisor.backup-*').Count -eq 0){throw 'Rollback failure lost both target and backup'}
    New-OldInstall -WithoutSettings; $before=Get-Tree $target; Assert-Throws 'rollback verification mismatch' { Invoke-Update $pass $safe -FailurePoint 'AfterBackup,RollbackMismatch' }; if(-not(Test-Path -LiteralPath $target)){throw 'Rollback mismatch removed restored target'}
    Write-Output 'PASS: update preflight, byte-preserved settings, clean replacement, WhatIf, rollback, rollback-failure reporting, and external-file preservation'
} finally { Remove-Item Env:BOON_ADVISOR_TEST_FAILURE_POINT -ErrorAction SilentlyContinue; if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force} }
