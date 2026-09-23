$ErrorActionPreference = 'Stop'
$ConfirmPreference = 'None'
$repo = Split-Path $PSScriptRoot -Parent
$install = Join-Path $repo 'tools\Install-BoonAdvisor.ps1'
$helper = Join-Path $repo 'tools\BoonAdvisor.Install.Common.ps1'
$stage = Join-Path $repo 'tools\Stage-Probe.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('boon-advisor-install-' + [Guid]::NewGuid())
$package = Join-Path $fixture 'Local-HadesIIBoonAdvisor'
$game = Join-Path $fixture 'Game'
$plugins = Join-Path $game 'Ship\ReturnOfModding\plugins'
$tokens = @(
    @('LuaENVY-ENVY', 'ENVY', '1.2.0', 'LuaENVY-ENVY-1.2.0'), @('SGG_Modding-ModUtil', 'ModUtil', '4.0.1', 'SGG_Modding-ModUtil-4.0.1'),
    @('SGG_Modding-ReLoad', 'ReLoad', '1.0.2', 'SGG_Modding-ReLoad-1.0.2'), @('SGG_Modding-ENVY', 'ENVY', '1.1.0', 'SGG_Modding-ENVY-1.1.0'),
    @('SGG_Modding-DemonDaemon', 'DemonDaemon', '1.1.0', 'SGG_Modding-DemonDaemon-1.1.0'), @('SGG_Modding-Chalk', 'Chalk', '2.1.1', 'SGG_Modding-Chalk-2.1.1'),
    @('SGG_Modding-SJSON', 'SJSON', '1.0.0', 'SGG_Modding-SJSON-1.0.0')
)
function Assert-Throws([string]$Name, [scriptblock]$Action) { try { & $Action; throw "Expected failure: $Name" } catch { if ($_.Exception.Message -like 'Expected failure:*') { throw } } }
function New-GameFixture {
    New-Item -ItemType Directory -Path $plugins -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $game 'Ship\Hades2.exe'), 'fixture executable')
    [IO.File]::WriteAllText((Join-Path $game 'Ship\d3d12.dll'), 'unverified fixture loader')
    foreach ($token in $tokens) {
        $dir = Join-Path $plugins $token[0]; New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $dir 'manifest.json'), ('{"name":"' + $token[1] + '","version_number":"' + $token[2] + '"}'))
    }
    $other = Join-Path $plugins 'OtherPlugin'; New-Item -ItemType Directory -Path $other -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $other 'keep.txt'), 'unchanged')
}
function New-Mock([string]$Name, [int]$ExitCode, [switch]$RequireRuntime) {
    $path = Join-Path $fixture ($Name + '.ps1')
    $guard = if ($RequireRuntime) { 'param([string]$Mode)' + [Environment]::NewLine + 'if($Mode -ne ''Runtime''){exit 9}' + [Environment]::NewLine } else { '' }
    [IO.File]::WriteAllText($path, ($guard + 'exit ' + $ExitCode))
    $path
}
function Invoke-Install([string]$Compatibility, [string]$Probe, [switch]$Simulate, [string]$PackageArgument) {
    if ([string]::IsNullOrWhiteSpace($PackageArgument)) { $PackageArgument = $package }
    if ($Simulate) { & $install -GameRoot $game -PackagePath $PackageArgument -CompatibilityScript $Compatibility -ProcessProbe $Probe -WhatIf }
    else { & $install -GameRoot $game -PackagePath $PackageArgument -CompatibilityScript $Compatibility -ProcessProbe $Probe }
}
try {
    & $stage | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo 'dist\Local-HadesIIBoonAdvisor') -Destination $package -Recurse
    New-GameFixture
    $pass = New-Mock 'compat-pass' 0 -RequireRuntime; $manual = New-Mock 'compat-manual' 2 -RequireRuntime; $fail = New-Mock 'compat-fail' 1 -RequireRuntime; $notRunning = New-Mock 'not-running' 0; $running = New-Mock 'running' 1
    . $helper
    $originalLocation = (Get-Location).Path
    $originalCurrentDirectory = [Environment]::CurrentDirectory
    Set-Location -LiteralPath $fixture
    [Environment]::CurrentDirectory = ([IO.Path]::GetTempPath())
    $relativeExpected = [IO.Path]::Combine($fixture, 'Local-HadesIIBoonAdvisor')
    if ((Get-NormalizedPath '.\Local-HadesIIBoonAdvisor') -ne [IO.Path]::GetFullPath($relativeExpected)) { throw 'PowerShell-relative path resolved against the wrong directory.' }
    if ((Get-NormalizedPath $package) -ne [IO.Path]::GetFullPath($package)) { throw 'Absolute path normalization changed unexpectedly.' }
    if ((Get-NormalizedPath '.\does-not-exist\future') -ne [IO.Path]::GetFullPath((Join-Path $fixture 'does-not-exist\future'))) { throw 'Missing relative path was not normalized.' }
    $childRoot = Join-Path $fixture 'root\plugins'; $childPath = Join-Path $childRoot 'Mod'; New-Item -ItemType Directory -Path $childPath -Force | Out-Null
    if (-not (Test-ChildPath $childPath $childRoot)) { throw 'Real child path was rejected.' }
    if (Test-ChildPath (Join-Path $fixture 'root\plugins-evil\x') $childRoot) { throw 'Sibling prefix-confusion path was accepted.' }
    Invoke-Install $pass $notRunning -PackageArgument '.\Local-HadesIIBoonAdvisor'
    Set-Location -LiteralPath $originalLocation
    [Environment]::CurrentDirectory = $originalCurrentDirectory
    Remove-Item -LiteralPath (Join-Path $plugins 'Local-HadesIIBoonAdvisor') -Recurse -Force
    $otherHash = (Get-FileHash -LiteralPath (Join-Path $plugins 'OtherPlugin\keep.txt')).Hash
    Invoke-Install $pass $notRunning
    $installed = Join-Path $plugins 'Local-HadesIIBoonAdvisor'
    $parsed = Parse-BoonAdvisorDependencyToken 'SGG_Modding-ModUtil-4.0.1'
    if ($parsed.PackageIdentity -ne 'SGG_Modding-ModUtil' -or $parsed.Package -ne 'ModUtil' -or $parsed.Version -ne '4.0.1') { throw 'ModUtil dependency token parsing regression.' }
    $parsed = Parse-BoonAdvisorDependencyToken 'LuaENVY-ENVY-1.2.0'
    if ($parsed.PackageIdentity -ne 'LuaENVY-ENVY') { throw 'LuaENVY dependency token parsing regression.' }
    $parsed = Parse-BoonAdvisorDependencyToken 'SGG_Modding-ENVY-1.1.0'
    if ($parsed.PackageIdentity -ne 'SGG_Modding-ENVY') { throw 'SGG ENVY dependency token parsing regression.' }
    Test-BoonAdvisorPackage $installed | Out-Null
    if ((Get-FileHash -LiteralPath (Join-Path $plugins 'OtherPlugin\keep.txt')).Hash -ne $otherHash) { throw 'Install changed an unrelated plugin.' }
    Assert-Throws 'existing destination' { Invoke-Install $pass $notRunning }
    Remove-Item -LiteralPath $installed -Recurse -Force
    Invoke-Install $pass $notRunning -Simulate
    if (Test-Path -LiteralPath $installed) { throw '-WhatIf installed the plugin.' }
    Assert-Throws 'manual compatibility' { Invoke-Install $manual $notRunning }
    Assert-Throws 'failed compatibility' { Invoke-Install $fail $notRunning }
    Assert-Throws 'running game' { Invoke-Install $pass $running }
    Remove-Item -LiteralPath (Join-Path $plugins 'SGG_Modding-ModUtil') -Recurse -Force
    Assert-Throws 'missing dependency' { Invoke-Install $pass $notRunning }
    $fake = Join-Path $plugins 'SGG_Modding-ModUtil-4.0.1'; New-Item -ItemType Directory -Path $fake | Out-Null
    [IO.File]::WriteAllText((Join-Path $fake 'manifest.json'), '{"name":"ModUtil","version_number":"4.0.1"}')
    Assert-Throws 'version-suffixed fake directory' { Invoke-Install $pass $notRunning }
    Remove-Item -LiteralPath $fake -Recurse -Force
    $dir = Join-Path $plugins 'SGG_Modding-ModUtil'; New-Item -ItemType Directory -Path $dir | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir 'manifest.json'), '{"name":"ModUtil","version_number":"0.0.0"}')
    Assert-Throws 'wrong dependency version' { Invoke-Install $pass $notRunning }
    [IO.File]::WriteAllText((Join-Path $dir 'manifest.json'), '{"name":"WrongModUtil","version_number":"4.0.1"}')
    Assert-Throws 'wrong dependency name' { Invoke-Install $pass $notRunning }
    [IO.File]::WriteAllText((Join-Path $dir 'manifest.json'), '{"name":"ModUtil","version_number":"4.0.1"}')
    Remove-Item -LiteralPath (Join-Path $plugins 'SGG_Modding-ENVY') -Recurse -Force
    Assert-Throws 'ENVY packages cannot satisfy each other' { Invoke-Install $pass $notRunning }
    $envy = Join-Path $plugins 'SGG_Modding-ENVY'; New-Item -ItemType Directory -Path $envy | Out-Null
    [IO.File]::WriteAllText((Join-Path $envy 'manifest.json'), '{"name":"ENVY","version_number":"1.1.0"}')
    Remove-Item -LiteralPath (Join-Path $game 'Ship\d3d12.dll')
    Assert-Throws 'missing loader' { Invoke-Install $pass $notRunning }
    [IO.File]::WriteAllText((Join-Path $game 'Ship\d3d12.dll'), 'different valid fixture loader')
    Test-BoonAdvisorDependencies (Get-BoonAdvisorPaths $game) (Test-BoonAdvisorPackage $package).Manifest
    $extra = Join-Path $package 'extra.lua'; [IO.File]::WriteAllText($extra, 'extra')
    Assert-Throws 'extra package file' { Test-BoonAdvisorPackage $package }
    Remove-Item -LiteralPath $extra
    $manifestPath = Join-Path $package 'manifest.json'; $manifestText = [IO.File]::ReadAllText($manifestPath); [IO.File]::WriteAllText($manifestPath, '{"name":"Wrong","version_number":"1"}')
    Assert-Throws 'invalid manifest identity' { Test-BoonAdvisorPackage $package }
    [IO.File]::WriteAllText($manifestPath, $manifestText)
    $missing = Join-Path $package 'UI.lua'; Move-Item -LiteralPath $missing -Destination ($missing + '.moved')
    Assert-Throws 'missing package file' { Test-BoonAdvisorPackage $package }
    Move-Item -LiteralPath ($missing + '.moved') -Destination $missing
    Write-Output 'PASS: install validation, exact transaction, dependencies, loader reporting, compatibility policy, running-game refusal, WhatIf, and sibling preservation'
} finally {
    if ($null -ne $originalLocation -and (Test-Path -LiteralPath $originalLocation)) { Set-Location -LiteralPath $originalLocation }
    if ($null -ne $originalCurrentDirectory) { [Environment]::CurrentDirectory = $originalCurrentDirectory }
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
