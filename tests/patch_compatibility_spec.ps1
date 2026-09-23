$ErrorActionPreference='Stop'; $repo=Split-Path $PSScriptRoot -Parent; $fixture=Join-Path ([IO.Path]::GetTempPath()) ('patch-fixture-'+[guid]::NewGuid()); New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'Ship'),(Join-Path $fixture 'Content\Scripts') | Out-Null
$exeFixture=Join-Path (Join-Path $fixture 'Ship') 'Hades2.exe'
[IO.File]::WriteAllText($exeFixture, 'fixture')
Set-Content (Join-Path $fixture 'Content\Scripts\LootData.lua') 'OnUsedFunctionName = "UseLoot"'
Set-Content (Join-Path $fixture 'Content\Scripts\InteractLogic.lua') 'function UseLoot(...) HandleLootPickup(CurrentRun, usee, args) end function HandleLootPickup(...) OpenUpgradeChoiceMenu(loot, args) end'
Set-Content (Join-Path $fixture 'Content\Scripts\UpgradeChoiceLogic.lua') 'function OpenUpgradeChoiceMenu(...) screen.Source = source CreateBoonLootButtons(screen, source, nil, args) end function CreateBoonLootButtons(...) lootData.UpgradeOptions SetTraitsOnLoot(lootData) end function RerollBoonLoot(...) CreateBoonLootButtons(screen, lootData, true) end'
$tool=Join-Path $repo 'tools\Test-PatchCompatibility.ps1'; & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -GameRoot $fixture -SkipProjectValidation; if($LASTEXITCODE -ne 2){throw 'intact fixture did not require manual runtime test'}
$exeInfo=Get-Item $exeFixture
$customExpected=[ordered]@{FileVersion=$exeInfo.VersionInfo.FileVersion;ProductVersion=$exeInfo.VersionInfo.ProductVersion;SizeBytes=7;ExeHash=(Get-FileHash $exeFixture -Algorithm SHA256).Hash;Scripts=[ordered]@{}}
foreach($p in 'Content\Scripts\LootData.lua','Content\Scripts\InteractLogic.lua','Content\Scripts\UpgradeChoiceLogic.lua'){$customExpected.Scripts[$p]=(Get-FileHash (Join-Path $fixture $p) -Algorithm SHA256).Hash}
. $tool -GameRoot $fixture -NoRun
$exactResult=Test-Compatibility $fixture $customExpected; if($exactResult.Status -ne 'PASS'){throw 'exact custom baseline did not pass'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -GameRoot $fixture -Mode Runtime; if($LASTEXITCODE -ne 2){throw 'runtime mode did not preserve manual fixture status'}
$runtimePass=Test-Compatibility $fixture $customExpected; if($runtimePass.Status -ne 'PASS'){throw 'runtime patch-only compatibility fixture did not pass'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -GameRoot $fixture -Mode Full -PythonPath (Join-Path $fixture 'missing-python.exe') -LuaDllPath (Join-Path $fixture 'missing-lua52.dll'); if($LASTEXITCODE -ne 1){throw 'full mode did not require developer validation paths'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -GameRoot $fixture -PythonPath (Join-Path $fixture 'missing-python.exe') -LuaDllPath (Join-Path $fixture 'missing-lua52.dll'); if($LASTEXITCODE -ne 1){throw 'default compatibility mode was not Full'}
if((Get-FinalCompatibilityStatus 'PASS' 'PASS') -ne 'PASS'){throw 'PASS aggregation failed'}
if((Get-FinalCompatibilityStatus 'MANUAL RUNTIME TEST REQUIRED' 'PASS') -ne 'MANUAL RUNTIME TEST REQUIRED'){throw 'manual aggregation failed'}
if((Get-FinalCompatibilityStatus 'PASS' 'FAIL') -ne 'FAIL'){throw 'project FAIL aggregation failed'}
if((Get-FinalCompatibilityStatus 'MANUAL RUNTIME TEST REQUIRED' 'FAIL') -ne 'FAIL'){throw 'FAIL priority aggregation failed'}
Set-Content (Join-Path $fixture 'Content\Scripts\LootData.lua') "`r`n`r`n  OnUsedFunctionName   =   'UseLoot'  `r`n"; Set-Content (Join-Path $fixture 'Content\Scripts\InteractLogic.lua') "`r`nfunction UseLoot ( ... )`r`n  HandleLootPickup ( CurrentRun , usee , args )`r`nend`r`nfunction HandleLootPickup ( ... )`r`n  OpenUpgradeChoiceMenu ( loot , args )`r`nend`r`n"; & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -GameRoot $fixture -SkipProjectValidation; if($LASTEXITCODE -ne 2){throw 'whitespace fixture changed status'}
Set-Content (Join-Path $fixture 'Content\Scripts\UpgradeChoiceLogic.lua') 'function CreateBoonLootButtons(...) end'; & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -GameRoot $fixture -SkipProjectValidation; if($LASTEXITCODE -ne 1){throw 'missing anchor did not fail'}
Remove-Item (Join-Path $fixture 'Content\Scripts\LootData.lua'); & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -GameRoot $fixture -SkipProjectValidation; if($LASTEXITCODE -ne 1){throw 'missing file did not fail'}
Remove-Item -Recurse -Force $fixture; Write-Output 'PASS: patch compatibility fixture statuses and structural checks'
