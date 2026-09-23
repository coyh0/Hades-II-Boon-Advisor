$ErrorActionPreference = 'Stop'; $ConfirmPreference = 'None'
$repo = Split-Path $PSScriptRoot -Parent
$uninstall = Join-Path $repo 'tools\Uninstall-BoonAdvisor.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('boon-advisor-uninstall-' + [Guid]::NewGuid())
$game = Join-Path $fixture 'Game'; $plugins = Join-Path $game 'Ship\ReturnOfModding\plugins'; $target = Join-Path $plugins 'Local-HadesIIBoonAdvisor'
function New-Probe([string]$Name, [int]$ExitCode) { $path = Join-Path $fixture ($Name + '.ps1'); [IO.File]::WriteAllText($path, ('exit ' + $ExitCode)); $path }
function Assert-Throws([string]$Name, [scriptblock]$Action) { try { & $Action; throw "Expected failure: $Name" } catch { if ($_.Exception.Message -like 'Expected failure:*') { throw } } }
function Invoke-Uninstall([string]$Probe, [switch]$Simulate) { if($Simulate){ & $uninstall -GameRoot $game -ProcessProbe $Probe -WhatIf } else { & $uninstall -GameRoot $game -ProcessProbe $Probe } }
try {
    New-Item -ItemType Directory -Path $target -Force | Out-Null; New-Item -ItemType Directory -Path (Join-Path $plugins 'SharedDependency') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $game 'Ship\Hades2.exe'), 'fixture executable'); [IO.File]::WriteAllText((Join-Path $target 'own.txt'), 'remove only'); [IO.File]::WriteAllText((Join-Path $plugins 'SharedDependency\keep.txt'), 'keep')
    $safe=New-Probe 'safe' 0; $running=New-Probe 'running' 1; $shared=(Get-FileHash (Join-Path $plugins 'SharedDependency\keep.txt')).Hash; $exe=(Get-FileHash (Join-Path $game 'Ship\Hades2.exe')).Hash
    Invoke-Uninstall $safe -Simulate; if(-not(Test-Path -LiteralPath $target)){throw '-WhatIf removed target'}
    Assert-Throws 'running game' { Invoke-Uninstall $running }; if(-not(Test-Path -LiteralPath $target)){throw 'running-game refusal removed target'}
    Invoke-Uninstall $safe; if(Test-Path -LiteralPath $target){throw 'target was not removed'}
    if((Get-FileHash (Join-Path $plugins 'SharedDependency\keep.txt')).Hash -ne $shared){throw 'shared plugin changed'}; if((Get-FileHash (Join-Path $game 'Ship\Hades2.exe')).Hash -ne $exe){throw 'Hades2.exe changed'}
    Invoke-Uninstall $safe
    Write-Output 'PASS: uninstall removes only the exact plugin, supports safe no-op and WhatIf, and preserves dependencies and executable'
} finally { if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force} }
