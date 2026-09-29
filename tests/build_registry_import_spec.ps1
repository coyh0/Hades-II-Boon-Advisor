$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$tool = Join-Path $repo 'tools\Test-BuildRegistryImport.ps1'
$catalog = Join-Path $repo 'data\canonical\catalog\weapons_aspects.json'
$windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('boon-import-contract-' + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$inputPath = Join-Path $testRoot 'rows.json'
$policyPath = Join-Path $testRoot 'policy.json'
$outputPath = Join-Path $testRoot 'result.json'

function Write-Json([string]$path, [object]$value) {
    [IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $value -Depth 20 -Compress), (New-Object System.Text.UTF8Encoding($false)))
}
function New-Row {
    return [pscustomobject]@{
        profileKeyProposal = 'test_profile'; canonicalId = 'test_profile'; profileMode = 'test'
        runtimeWeaponId = 'WeaponDagger'; runtimeAspectId = 'DaggerBackstabAspect'
        itemType = 'boon'; slot = 'attack'; classification = 'core'
        runtimeItemId = 'AresWeaponBoon'; importStatus = 'ready'; verificationStatus = 'verified'
        module = ''; name = 'Display name'; god = 'Ares'; condition = 'Free text only'
    }
}
function Clone-Row([object]$row) { return ($row | ConvertTo-Json -Depth 20 | ConvertFrom-Json) }
function Run-Case([object[]]$rows, [bool]$expectSuccess, [string]$name) {
    Write-Json $inputPath ([ordered]@{ schemaVersion = 1; rows = @($rows) })
    if (Test-Path -LiteralPath $outputPath) { Remove-Item -LiteralPath $outputPath }
    $ErrorActionPreference = 'Continue'
    $null = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $tool -InputPath $inputPath -PolicyPath $policyPath -CatalogPath $catalog -OutputPath $outputPath 2>$null
    $ErrorActionPreference = 'Stop'
    if (($LASTEXITCODE -eq 0) -ne $expectSuccess) { throw "Unexpected import validation result: $name (exit=$LASTEXITCODE)" }
    if (-not $expectSuccess) {
        if (Test-Path -LiteralPath $outputPath) { throw "Failed case emitted output: $name" }
        return $null
    }
    $planJson = [IO.File]::ReadAllText($outputPath, (New-Object System.Text.UTF8Encoding($false, $true)))
    return $planJson | ConvertFrom-Json
}
function Assert-Blocked([object[]]$rows, [string]$reason, [string]$name) {
    $result = Run-Case $rows $true $name
    if ($result.groups.Count -ne 1 -or $result.groups[0].status -ne 'blocked' -or
        $result.groups[0].reasons -notcontains $reason -or $result.groups[0].items.Count -ne 0 -or
        $null -ne $result.groups[0].module) { throw "Expected blocked group without runtime output: $name" }
}

$policy = [ordered]@{ schemaVersion = 1; boonClassifications = [ordered]@{ core = 'core' };
    hammerClassifications = [ordered]@{ priority = 'priority'; alternative = 'alternative' };
    verifiedRuntimeItemIds = @('AresWeaponBoon', 'ForceAresBoonKeepsake', 'SuitDashAttackTrait', 'InsideCastCritBoon', 'ChaosWeaponBlessing', 'ChaosHealthBlessing', 'HephaestusManaBoon', 'DoubleStrikeChanceBoon', 'CastNovaBoon');
    verifiedBoonMappings = @(
        [ordered]@{ runtimeItemId = 'HephaestusManaBoon'; sourceGroup = 'Core Boons'; coreRole = 'Mana' },
        [ordered]@{ runtimeItemId = 'DoubleStrikeChanceBoon'; sourceGroup = 'Non-Core Boons' },
        [ordered]@{ runtimeItemId = 'CastNovaBoon'; sourceGroup = 'Non-Core Boons' }
    );
    verifiedNpcOfferingPairs = @([ordered]@{ runtimeItemId = 'InsideCastCritBoon'; offerSource = 'NPC_Artemis_Field_01' });
    verifiedOfferingPairs = @(
        [ordered]@{ runtimeItemId = 'InsideCastCritBoon'; offerSource = 'NPC_Artemis_Field_01' },
        [ordered]@{ runtimeItemId = 'ChaosWeaponBlessing'; offerSource = 'TrialUpgrade' },
        [ordered]@{ runtimeItemId = 'ChaosHealthBlessing'; offerSource = 'TrialUpgrade' }
    );
    keepsakeStartAsAutoSignal = $true }
Write-Json $policyPath $policy
$base = New-Row
$valid = Run-Case @($base) $true 'valid ready boon'
if ($valid.groups.Count -ne 1 -or $valid.groups[0].status -ne 'ready' -or
    $valid.groups[0].module -ne 'data/builds/test_profile.lua' -or
    $valid.groups[0].items[0].runtimeItemId -ne 'AresWeaponBoon' -or
    $valid.groups[0].items[0].slot -ne 'Attack' -or $valid.groups[0].items[0].role -ne 'core') { throw 'Valid ready group projection failed.' }
$firstBytes = [IO.File]::ReadAllBytes($outputPath)
$null = Run-Case @($base) $true 'deterministic repeat'
if (-not [Linq.Enumerable]::SequenceEqual([byte[]]$firstBytes, [byte[]][IO.File]::ReadAllBytes($outputPath))) { throw 'Import result was not deterministic.' }

# Legacy schema-1 policies predate Hammer projections and remain valid for Boons.
$legacyPolicy = [ordered]@{}
foreach ($entry in $policy.GetEnumerator()) { $legacyPolicy[$entry.Key] = $entry.Value }
$legacyPolicy.Remove('hammerClassifications')
Write-Json $policyPath $legacyPolicy
$legacyBoon = Run-Case @($base) $true 'legacy schema-1 policy imports Boon'
if ($legacyBoon.groups[0].status -ne 'ready' -or $legacyBoon.groups[0].items[0].role -ne 'core') {
    throw 'Legacy schema-1 policy no longer imports a valid Boon.'
}
$legacyHammer = Clone-Row $base; $legacyHammer.itemType = 'hammer'; $legacyHammer.slot = 'priority'
$legacyHammer.classification = 'priority'; $legacyHammer.runtimeItemId = 'SuitDashAttackTrait'
$legacyHammer | Add-Member -NotePropertyName priority -NotePropertyValue 1
$legacyHammerResult = Run-Case @($legacyHammer) $true 'legacy schema-1 Hammer remains blocked'
if ($legacyHammerResult.groups[0].status -ne 'blocked' -or
    $legacyHammerResult.groups[0].reasons -notcontains 'unsupported_hammer_classification') {
    throw 'Legacy schema-1 policy gained implicit Hammer classification trust.'
}
Write-Json $policyPath $policy

$row = Clone-Row $base; $row.importStatus = 'invalid'
$null = Run-Case @($row) $false 'invalid importStatus'
$row = Clone-Row $base; $row.verificationStatus = 'invalid'
$null = Run-Case @($row) $false 'invalid verificationStatus'
$row = Clone-Row $base; $row.canonicalId = ''
$null = Run-Case @($row) $false 'missing canonicalId for ready group'
$row = Clone-Row $base; $row.profileMode = 17
$null = Run-Case @($row) $false 'numeric profileMode rejected'
$row = Clone-Row $base; $row.profileKeyProposal = 'other_profile'
$null = Run-Case @($base, $row) $false 'duplicate canonicalId across groups'
$row = Clone-Row $base; $row.profileKeyProposal = 'auto'
$null = Run-Case @($row) $false 'reserved auto profile key'
$row = Clone-Row $base; $row.canonicalId = 'registry'
$null = Run-Case @($row) $false 'reserved generated registry module'
$row = Clone-Row $base; $row.canonicalId = 'other_id'
$null = Run-Case @($base, $row) $false 'conflicting group identity'
$row = Clone-Row $base; $row.runtimeWeaponId = ''
Assert-Blocked @($row) 'missing_runtime_weapon_id' 'missing weapon ID'
$row = Clone-Row $base; $row.runtimeWeaponId = 'UnknownWeapon'
Assert-Blocked @($row) 'unverified_weapon_aspect' 'unknown weapon ID'
$row = Clone-Row $base; $row.runtimeWeaponId = 'weapondagger'
Assert-Blocked @($row) 'unverified_weapon_aspect' 'weapon ID case mismatch'
$row = Clone-Row $base; $row.runtimeAspectId = ''
Assert-Blocked @($row) 'missing_runtime_aspect_id' 'missing aspect ID'
$row = Clone-Row $base; $row.runtimeAspectId = 'UnknownAspect'
Assert-Blocked @($row) 'unverified_weapon_aspect' 'unknown aspect ID'
$row = Clone-Row $base; $row.runtimeAspectId = 'daggerbackstabaspect'
Assert-Blocked @($row) 'unverified_weapon_aspect' 'aspect ID case mismatch'
$row = Clone-Row $base; $row.runtimeItemId = ''
Assert-Blocked @($row) 'missing_runtime_item_id' 'name cannot substitute for runtime ID'
$row = Clone-Row $base; $row.verificationStatus = 'unverified'
Assert-Blocked @($row) 'unverified_runtime_item_id' 'unverified item ID'
$row = Clone-Row $base; $row.runtimeItemId = 'UnknownItem'
Assert-Blocked @($row) 'runtime_item_id_not_in_verified_policy' 'unattested item ID'
$row = Clone-Row $base; $row.runtimeItemId = 'aresweaponboon'
Assert-Blocked @($row) 'runtime_item_id_not_in_verified_policy' 'runtime item ID case mismatch'
$row = Clone-Row $base; $row.importStatus = 'documentation_only'
$result = Run-Case @($row) $true 'documentation only'
if ($result.groups.Count -ne 0) { throw 'Documentation-only row was imported.' }
$row.importStatus = 'excluded'
$result = Run-Case @($row) $true 'excluded'
if ($result.groups.Count -ne 0) { throw 'Excluded row was imported.' }
$row = Clone-Row $base; $row.importStatus = 'blocked'
Assert-Blocked @($base, $row) 'source_row_blocked' 'blocked group has no partial import'
$row = Clone-Row $base; $row.condition = 'requiresAnyOwned:UnknownItem; weight=999'
$row | Add-Member -NotePropertyName priority -NotePropertyValue 999
$result = Run-Case @($row) $true 'condition cannot create rules'
if ($result.groups[0].items[0].role -ne 'core' -or $result.groups[0].PSObject.Properties.Name -contains 'rules') { throw 'Free-text condition affected output.' }
$row = Clone-Row $base; $row.module = '../../malicious.lua'
Assert-Blocked @($row) 'module_mismatch' 'arbitrary module path'
$row = Clone-Row $base; $row.slot = 'gain'
Assert-Blocked @($row) 'gain_to_mana_unverified' 'gain does not map to Mana'
$row = Clone-Row $base; $row.runtimeItemId = 'HephaestusManaBoon'; $row.slot = ''
$row.classification = ''; $row | Add-Member -NotePropertyName sourceGroup -NotePropertyValue 'Core Boons'
$row | Add-Member -NotePropertyName coreRole -NotePropertyValue 'Mana'
$result = Run-Case @($row) $true 'attested Core Mana boon'
if ($result.groups[0].status -cne 'ready' -or $result.groups[0].items[0].slot -cne 'Mana' -or
    $result.groups[0].items[0].role -cne 'core') { throw 'Attested Core Mana projection failed.' }
$row.coreRole = 'Cast'
Assert-Blocked @($row) 'core_role_mismatch' 'Core role mismatch'
$row.coreRole = 'Mana'; $row.sourceGroup = 'Non-Core Boons'
Assert-Blocked @($row) 'boon_source_group_mismatch' 'Core category mismatch'
$row.sourceGroup = 'Core Boons'; $row.slot = 'cast'
Assert-Blocked @($row) 'core_slot_mismatch' 'Core slot mismatch'
$row.slot = ''; $row.classification = 'core'
Assert-Blocked @($row) 'mixed_boon_classification' 'legacy classification cannot override source group'
foreach ($supportId in @('DoubleStrikeChanceBoon', 'CastNovaBoon')) {
    $row = Clone-Row $base; $row.runtimeItemId = $supportId; $row.slot = ''; $row.classification = ''
    $row | Add-Member -NotePropertyName sourceGroup -NotePropertyValue 'Non-Core Boons'
    $result = Run-Case @($row) $true "attested Non-Core support $supportId"
    if ($result.groups[0].status -cne 'ready' -or $result.groups[0].items[0].role -cne 'nonCore' -or
        $null -ne $result.groups[0].items[0].slot) { throw "Non-Core support projection failed: $supportId" }
    $row.sourceGroup = 'Core Boons'
    Assert-Blocked @($row) 'boon_source_group_mismatch' "Non-Core category mismatch $supportId"
}
$row = Clone-Row $base; $row.runtimeItemId = 'DoubleStrikeChanceBoon'; $row.slot = ''; $row.classification = ''
$row | Add-Member -NotePropertyName sourceGroup -NotePropertyValue 'Non-Core Boons'
$row | Add-Member -NotePropertyName coreRole -NotePropertyValue 'Mana'
Assert-Blocked @($row) 'non_core_role_mismatch' 'Non-Core cannot claim Core role'
$row.coreRole = ''; $row.slot = 'attack'
Assert-Blocked @($row) 'non_core_slot_mismatch' 'Non-Core cannot claim artificial slot'
$row = Clone-Row $base; $row.runtimeItemId = 'UnknownSupportBoon'; $row.slot = ''; $row.classification = ''
$row | Add-Member -NotePropertyName sourceGroup -NotePropertyValue 'Non-Core Boons'
Assert-Blocked @($row) 'unverified_boon_source_mapping' 'unattested boon source mapping'
$row = Clone-Row $base; $row.slot = 'Attack'
Assert-Blocked @($row) 'unsupported_boon_slot' 'slot key case mismatch'
$row = Clone-Row $base; $row.itemType = 'keepsake'; $row.slot = 'start'; $row.classification = ''; $row.runtimeItemId = 'ForceAresBoonKeepsake'
$result = Run-Case @($row) $true 'explicit keepsake autoSignal'
if ($result.groups[0].status -ne 'ready' -or $result.groups[0].items[0].role -ne 'autoSignal') { throw 'Explicit keepsake mapping failed.' }
$policy.keepsakeStartAsAutoSignal = $false; Write-Json $policyPath $policy
Assert-Blocked @($row) 'unsupported_keepsake_mapping' 'keepsake needs explicit policy'
$policy.keepsakeStartAsAutoSignal = $true; Write-Json $policyPath $policy
$artemisOffering = Clone-Row $base; $artemisOffering.itemType = 'npcOffering'; $artemisOffering.slot = ''
$artemisOffering.classification = ''; $artemisOffering.runtimeItemId = 'InsideCastCritBoon'
$artemisOffering | Add-Member -NotePropertyName offerSource -NotePropertyValue 'NPC_Artemis_Field_01'
$artemisPlan = Run-Case @($artemisOffering) $true 'verified Artemis source/item pair'
if ($artemisPlan.groups[0].status -ne 'ready' -or $artemisPlan.groups[0].items[0].role -cne 'npcOffering' -or
    $artemisPlan.groups[0].items[0].offerSource -cne 'NPC_Artemis_Field_01') {
    throw 'Verified Artemis source/item pair was not projected by the importer.'
}
$artemisOffering.offerSource = 'NPC_Athena_01'
Assert-Blocked @($artemisOffering) 'unverified_npc_source_item_pair' 'mismatched Artemis source/item pair'
$artemisOffering = Clone-Row $artemisOffering; $artemisOffering.runtimeItemId = 'UnknownArtemisBoon'
Assert-Blocked @($artemisOffering) 'runtime_item_id_not_in_verified_policy' 'unverified Artemis boon ID'
$trialOffering = Clone-Row $base; $trialOffering.itemType = 'offering'; $trialOffering.slot = ''
$trialOffering.classification = ''; $trialOffering.runtimeItemId = 'ChaosWeaponBlessing'
$trialOffering | Add-Member -NotePropertyName offerSource -NotePropertyValue 'TrialUpgrade'
$trialPlan = Run-Case @($trialOffering) $true 'verified TrialUpgrade offering pair'
if ($trialPlan.groups[0].status -ne 'ready' -or $trialPlan.groups[0].items[0].role -cne 'offering' -or
    $trialPlan.groups[0].items[0].offerSource -cne 'TrialUpgrade') {
    throw 'Verified TrialUpgrade source/item pair was not projected by the importer.'
}
$trialOffering.offerSource = 'NPC_Artemis_Field_01'
Assert-Blocked @($trialOffering) 'unverified_offering_source_item_pair' 'mismatched TrialUpgrade source/item pair'
$trialOffering = Clone-Row $trialOffering; $trialOffering.runtimeItemId = 'ChaosHealthBlessing'; $trialOffering.offerSource = 'TrialUpgrade'
$soulPlan = Run-Case @($trialOffering) $true 'verified TrialUpgrade Soul pair'
if ($soulPlan.groups[0].status -ne 'ready' -or $soulPlan.groups[0].items[0].offerSource -cne 'TrialUpgrade') {
    throw 'Verified TrialUpgrade Soul source/item pair was not projected by the importer.'
}
$trialOffering.offerSource = 'ChaosUpgrade'
Assert-Blocked @($trialOffering) 'unverified_offering_source_item_pair' 'unattested offering source'
$row = Clone-Row $base; $row.itemType = 'hammer'; $row.slot = 'priority'; $row.classification = 'priority'
$row.runtimeItemId = 'SuitDashAttackTrait'; $row | Add-Member -NotePropertyName priority -NotePropertyValue 1
$result = Run-Case @($row) $true 'verified Hammer projection'
$hammer = $result.groups[0].items[0]
if ($result.groups[0].status -ne 'ready' -or $hammer.role -ne 'hammer' -or
    $hammer.priority -ne 1 -or $hammer.classification -cne 'priority') {
    throw 'Verified Hammer projection failed.'
}
$row.condition = 'Free text metadata only'
$result = Run-Case @($row) $true 'Hammer condition metadata preserved'
$hammer = $result.groups[0].items[0]
if ($hammer.condition -cne 'Free text metadata only' -or
    $hammer.PSObject.Properties.Name -contains 'runtimeCondition') {
    throw 'Hammer condition text gained runtime semantics.'
}
$row = Clone-Row $row; $row.runtimeItemId = ''
Assert-Blocked @($row) 'missing_runtime_item_id' 'Hammer missing runtime ID'
$row = Clone-Row $base; $row.itemType = 'hammer'; $row.slot = 'priority'; $row.classification = 'priority'
$row.runtimeItemId = 'UnknownHammerTrait'; $row | Add-Member -NotePropertyName priority -NotePropertyValue 1
Assert-Blocked @($row) 'runtime_item_id_not_in_verified_policy' 'unverified Hammer ID'
$row = Clone-Row $row; $row.runtimeItemId = 'SuitDashAttackTrait'; $row.priority = 0
$null = Run-Case @($row) $false 'invalid Hammer priority'
$row = Clone-Row $row; $row.priority = 1; $row.classification = 'untrusted'
Assert-Blocked @($row) 'unsupported_hammer_classification' 'untrusted Hammer classification'
$row = Clone-Row $base; $row.itemType = 'support'
Assert-Blocked @($row) 'unsupported_runtime_item_type' 'support requires rules'
foreach ($type in @('arcana', 'familiar', 'hex')) {
    $row = Clone-Row $base; $row.itemType = $type
    Assert-Blocked @($row) 'unsupported_runtime_item_type' "$type cannot affect runtime"
}
$nonAsciiName = 'Boon ' + [char]0x2014 + ' ' + [char]0x00C9 + 'cho'
$row = Clone-Row $base; $row.name = $nonAsciiName
$result = Run-Case @($row) $true 'UTF-8 name metadata'
$rawPlan = [IO.File]::ReadAllText($outputPath, (New-Object System.Text.UTF8Encoding($false, $true)))
if (-not $rawPlan.Contains($nonAsciiName) -or $result.groups[0].items[0].name -cne $nonAsciiName) { throw 'UTF-8 metadata was not preserved in the validation plan.' }
$second = Clone-Row $base; $second.runtimeWeaponId = 'weapondagger'
$null = Run-Case @($base, $second) $false 'case-sensitive runtimeWeaponId group identity'
$second = Clone-Row $base; $second.runtimeAspectId = 'daggerbackstabaspect'
$null = Run-Case @($base, $second) $false 'case-sensitive runtimeAspectId group identity'
Write-Output 'PASS: Windows PowerShell 5.1 Build Registry import contract, strict blocking, explicit mappings, and deterministic output'
