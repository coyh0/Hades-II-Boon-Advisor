[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$GameRoot, [ValidateSet('Runtime','Full')][string]$Mode = 'Full', [string]$PythonPath, [string]$LuaDllPath, [switch]$SkipProjectValidation, [switch]$NoRun)
$ErrorActionPreference = 'Stop'

$baseline = [ordered]@{
    FileVersion='139606'; ProductVersion='139606'; SizeBytes=6197864
    ExeHash='DB88529B0961C41763413FC676762B9AC05CD22F9547A9305E0B629B30F2EE74'
    Scripts = [ordered]@{
        'Content\Scripts\LootData.lua'='64D50A847E193C2F6602493ACB956820C7B3EE44DE8D074043E03C25320000A2'
        'Content\Scripts\InteractLogic.lua'='DA50CB72BCF80855DE627930A0745F21ABCA22C4744A5FFB53C21553F9E7B584'
        'Content\Scripts\UpgradeChoiceLogic.lua'='07E7A81D5674ECD1D774CEC81B4450B6E16F2A9DD315996D786EF71518F95292'
    }
}

function Get-Text([string]$Path) { Get-Content -LiteralPath $Path -Raw }
function Has-Pattern([string]$Text, [string]$Pattern) { [regex]::IsMatch($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Singleline) }
function Test-Compatibility([string]$Root, $Expected) {
    $exe=Join-Path $Root 'Ship\Hades2.exe'
    $rel=@('Content\Scripts\LootData.lua','Content\Scripts\InteractLogic.lua','Content\Scripts\UpgradeChoiceLogic.lua')
    $missing=@()
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { $missing += $exe }
    foreach($p in $rel){$full=Join-Path $Root $p; if(-not (Test-Path -LiteralPath $full -PathType Leaf)){$missing += $full}}
    if ($missing.Count -gt 0) { return [pscustomobject]@{Status='FAIL'; Missing=$missing; Anchors=@{}; Exact=$false; Records=@()} }
    $records=@(); $anchors=[ordered]@{}; $anchorFail=$false
    $loot=Get-Text (Join-Path $Root $rel[0]); $interact=Get-Text (Join-Path $Root $rel[1]); $upgrade=Get-Text (Join-Path $Root $rel[2])
    $anchors['LootData.OnUsedFunctionName'] = Has-Pattern $loot 'OnUsedFunctionName\s*=\s*["'']UseLoot["'']'
    $anchors['InteractLogic.UseLoot'] = Has-Pattern $interact 'function\s+UseLoot\s*\(' -and Has-Pattern $interact 'HandleLootPickup\s*\(\s*CurrentRun\s*,\s*usee\s*,\s*args\s*\)'
    $anchors['InteractLogic.HandleLootPickup'] = Has-Pattern $interact 'function\s+HandleLootPickup\s*\(' -and Has-Pattern $interact 'OpenUpgradeChoiceMenu\s*\(\s*loot\s*,\s*args\s*\)'
    $anchors['Upgrade.OpenMenu'] = Has-Pattern $upgrade 'function\s+OpenUpgradeChoiceMenu\s*\(' -and Has-Pattern $upgrade 'screen\.Source\s*=\s*source' -and Has-Pattern $upgrade 'CreateBoonLootButtons\s*\(\s*screen\s*,\s*source\s*,\s*nil\s*,\s*args\s*\)'
    $anchors['Upgrade.CreateButtons'] = Has-Pattern $upgrade 'function\s+CreateBoonLootButtons\s*\(' -and Has-Pattern $upgrade 'lootData\.UpgradeOptions' -and Has-Pattern $upgrade 'SetTraitsOnLoot\s*\(\s*lootData\s*\)'
    $anchors['Upgrade.Reroll'] = Has-Pattern $upgrade 'function\s+RerollBoonLoot\s*\(' -and Has-Pattern $upgrade 'CreateBoonLootButtons\s*\(\s*screen\s*,\s*lootData\s*,\s*true\s*\)'
    foreach($k in $anchors.Keys){if(-not $anchors[$k]){$anchorFail=$true}}
    $fi=Get-Item $exe; $fv=$fi.VersionInfo.FileVersion; $pv=$fi.VersionInfo.ProductVersion; $eh=(Get-FileHash $exe -Algorithm SHA256).Hash
    $exact=($fv -eq $Expected.FileVersion -and $pv -eq $Expected.ProductVersion -and $fi.Length -eq $Expected.SizeBytes -and $eh -eq $Expected.ExeHash)
    foreach($p in $rel){$full=Join-Path $Root $p; $hash=(Get-FileHash $full -Algorithm SHA256).Hash; $records += [pscustomobject]@{Path=$p;Hash=$hash;BaselineMatch=($hash -eq $Expected.Scripts[$p])}}
    $status='MANUAL RUNTIME TEST REQUIRED'
    if($anchorFail){$status='FAIL'} elseif($exact -and (@($records|Where-Object {-not $_.BaselineMatch}).Count -eq 0)){$status='PASS'}
    [pscustomobject]@{Status=$status;Missing=@();Anchors=$anchors;Exact=$exact;Records=$records;FileVersion=$fv;ProductVersion=$pv;SizeBytes=$fi.Length;ExeHash=$eh}
}
function Get-FinalCompatibilityStatus([string]$PatchStatus, [string]$ProjectStatus) {
    if($PatchStatus -eq 'FAIL' -or $ProjectStatus -eq 'FAIL'){return 'FAIL'}
    if($PatchStatus -eq 'MANUAL RUNTIME TEST REQUIRED'){return 'MANUAL RUNTIME TEST REQUIRED'}
    'PASS'
}
function Test-ProjectCompatibility([string]$Repo, [string]$Python, [string]$LuaDll) {
    $checks=@('tests\canonical_profiles_spec.ps1','tests\canonical_mechanics_spec.ps1','tests\canonical_mechanics_equivalence_spec.ps1','tests\staging_spec.ps1','tests\profile_switcher_spec.ps1')
    foreach($check in $checks){
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Repo $check)
        if($LASTEXITCODE -ne 0){return [pscustomobject]@{Status='FAIL';FailedCheck=$check}}
    }
    if([string]::IsNullOrWhiteSpace($Python)){$Python=$env:BOON_ADVISOR_PYTHON}
    if([string]::IsNullOrWhiteSpace($LuaDll)){$LuaDll=Join-Path $GameRoot 'Ship\lua52.dll'}
    if([string]::IsNullOrWhiteSpace($Python) -or -not (Test-Path -LiteralPath $Python -PathType Leaf) -or -not (Test-Path -LiteralPath $LuaDll -PathType Leaf)){return [pscustomobject]@{Status='FAIL';FailedCheck='Lua 5.2 runtime path'}}
    & $Python (Join-Path $Repo 'tests\run_lua52.py') $LuaDll
    if($LASTEXITCODE -ne 0){return [pscustomobject]@{Status='FAIL';FailedCheck='tests\run_lua52.py'}}
    [pscustomobject]@{Status='PASS';FailedCheck=$null}
}

if($NoRun){return}
$result=Test-Compatibility $GameRoot $baseline
Write-Output '[PATCH]'
Write-Output "GameRoot: $GameRoot"
if($result.Missing.Count){Write-Output ('Missing critical file: '+($result.Missing -join ', '))}
Write-Output "Detected version: FileVersion=$($result.FileVersion) ProductVersion=$($result.ProductVersion) SizeBytes=$($result.SizeBytes)"
Write-Output "Executable exact-baseline match: $($result.Exact)"
if($result.Anchors.Values -contains $false){$anchorStatus='FAIL'}else{$anchorStatus='PASS'}
foreach($r in $result.Records){Write-Output "$($r.Path): hash baseline match=$($r.BaselineMatch); structural anchors=$anchorStatus"}
foreach($a in $result.Anchors.Keys){Write-Output "Anchor ${a}: $($result.Anchors[$a])"}
if($Mode -eq 'Runtime') {
    Write-Output '[FINAL]'
    Write-Output "PATCH COMPATIBILITY: $($result.Status)"
    if($result.Status -eq 'PASS'){exit 0}; if($result.Status -eq 'MANUAL RUNTIME TEST REQUIRED'){exit 2}; exit 1
}
$repo=Split-Path $PSScriptRoot -Parent
if($SkipProjectValidation){$project=[pscustomobject]@{Status='PASS';FailedCheck=$null}}else{$project=Test-ProjectCompatibility $repo $PythonPath $LuaDllPath}
Write-Output '[PROJECT]'
Write-Output "Project validation: $($project.Status)"
if($project.FailedCheck){Write-Output "Failed check: $($project.FailedCheck)"}
$final=Get-FinalCompatibilityStatus $result.Status $project.Status
Write-Output '[FINAL]'
Write-Output "PATCH COMPATIBILITY: $final"
if($final -eq 'PASS'){exit 0}; if($final -eq 'MANUAL RUNTIME TEST REQUIRED'){exit 2}; exit 1
