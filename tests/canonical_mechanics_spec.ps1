$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$mechanicsDirectory = Join-Path $repo 'data\canonical\mechanics'
$mechanicsFiles = @(Get-ChildItem -LiteralPath $mechanicsDirectory -Filter '*.json' -File | Sort-Object Name)
$expected = @{
    'sister_blades_melinoe.json' = @{ id = 'sister_blades_melinoe'; weapon = 'WeaponDagger'; aspect = 'DaggerBackstabAspect'; generic = $true }
    'sister_blades_morrigan.json' = @{ id = 'sister_blades_morrigan'; weapon = 'WeaponDagger'; aspect = 'DaggerTripleAspect'; generic = $false }
    'black_coat_melinoe.json' = @{ id = 'black_coat_melinoe'; weapon = 'WeaponSuit'; aspect = 'BaseSuitAspect'; generic = $false }
}
if ($mechanicsFiles.Count -ne $expected.Count) { throw 'Unexpected canonical mechanics template inventory.' }
$sections = @('weights','statusMappings','knownNonStatusTraits','potentialStatusTraits',
    'statusCapabilityTraits','bloodDropEngine','aspectInteractions','hammerRoles','rules','verifiedIds')
foreach ($file in $mechanicsFiles) {
    $canonical = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    $expectation = $expected[$file.Name]
    if ($null -eq $expectation -or $canonical.schemaVersion -ne 1 -or $canonical.id -ne $expectation.id -or
        $canonical.weapon -ne $expectation.weapon -or $canonical.aspect -ne $expectation.aspect -or
        $canonical.genericCoreAspectCompatibility -isnot [bool] -or
        $canonical.genericCoreAspectCompatibility -ne $expectation.generic) { throw "Invalid mechanics identity: $($file.Name)" }
    foreach ($section in $sections) {
        if ($null -eq $canonical.$section) { throw "Missing canonical mechanics section: $($file.Name).$section" }
    }
    foreach ($property in $canonical.weights.PSObject.Properties) {
        if ($property.Value -isnot [ValueType] -or $property.Value -is [bool]) {
            throw "Invalid canonical weight at $($file.Name).weights.$($property.Name)"
        }
    }
    foreach ($property in $canonical.statusMappings.PSObject.Properties) {
        foreach ($field in @('effect','family','olympian')) {
            if ([string]::IsNullOrWhiteSpace([string]$property.Value.$field)) {
                throw "Invalid status mapping at $($file.Name).statusMappings.$($property.Name).$field"
            }
        }
    }
    foreach ($section in @('knownNonStatusTraits','potentialStatusTraits')) {
        foreach ($id in $canonical.$section) { if ([string]::IsNullOrWhiteSpace([string]$id)) { throw "Empty ID at $($file.Name).$section" } }
    }
    foreach ($group in $canonical.verifiedIds.PSObject.Properties) {
        $seen = @{}
        foreach ($id in @($group.Value)) {
            if ([string]::IsNullOrWhiteSpace([string]$id)) { throw "Empty verified ID at $($file.Name).verifiedIds.$($group.Name)" }
            if ($seen.ContainsKey([string]$id)) { throw "Duplicate verified ID at $($file.Name).verifiedIds.$($group.Name): $id" }
            $seen[[string]$id] = $true
        }
    }
    if ($expectation.weapon -eq 'WeaponDagger' -and $canonical.weights.ASPECT_SETUP_SYNERGY -ne 4) { throw "Missing setup weight: $($file.Name)" }
}
$coat = Get-Content -LiteralPath (Join-Path $mechanicsDirectory 'black_coat_melinoe.json') -Raw | ConvertFrom-Json
if (@($coat.aspectInteractions.PSObject.Properties).Count -ne 0 -or
    @($coat.hammerRoles.PSObject.Properties).Count -ne 0 -or
    @($coat.rules.PSObject.Properties).Count -ne 0 -or
    @($coat.verifiedIds.PSObject.Properties).Count -ne 5) {
    throw 'Black Coat mechanics must contain only generic core slot inventories.'
}
foreach ($group in @('coreAttack','coreSpecial','coreCast','coreSprint','coreMana')) {
    if (-not (@($coat.verifiedIds.$group).Count -gt 0)) { throw "Black Coat missing generic $group inventory." }
}
$melinoe = Get-Content -LiteralPath (Join-Path $mechanicsDirectory 'sister_blades_melinoe.json') -Raw | ConvertFrom-Json
if (($melinoe.statusCapabilityTraits.Curse.Count -ne 2) -or
    ($melinoe.bloodDropEngine.producers.Count -ne 2) -or ($melinoe.bloodDropEngine.payoffs.Count -ne 2) -or
    ($melinoe.aspectInteractions.DemeterCastBoon -ne 'BACKSTAB_SETUP') -or
    ($melinoe.aspectInteractions.DaggerBackstabTrait -ne 'ASPECT_DIRECT_SYNERGY') -or
    $melinoe.hammerRoles.Attack.Count -ne 4 -or $melinoe.hammerRoles.Special.Count -ne 5) {
    throw 'Melinoe audited mechanics differ from the validated runtime data.'
}
$morrigan = Get-Content -LiteralPath (Join-Path $mechanicsDirectory 'sister_blades_morrigan.json') -Raw | ConvertFrom-Json
if ($morrigan.aspectInteractions.WeaponUpgradeBoon -ne 'ASPECT_DIRECT_SYNERGY' -or
    $null -ne $morrigan.aspectInteractions.AresWeaponBoon -or $null -ne $morrigan.aspectInteractions.AresSpecialBoon -or
    $morrigan.aspectMechanics.proc.id -ne 'WomboStrike' -or $morrigan.aspectMechanics.proc.baseDamage -ne 111 -or
    $morrigan.aspectMechanics.proc.useVulnerability -ne $false -or $morrigan.aspectMechanics.proc.ignoreAllModifiers -ne $true -or
    $morrigan.aspectMechanics.proc.normalCrit -ne $false -or $morrigan.aspectMechanics.proc.normalGlobalModifiers -ne $false -or
    $morrigan.aspectMechanics.origination.contributingHits -ne $true -or $morrigan.aspectMechanics.origination.womboStrike -ne $false -or
    $morrigan.aspectMechanics.proc.rankMultipliers.Perfect -ne 9 -or
    $morrigan.aspectMechanics.hammers.DaggerTripleBuffTrait.womboDamageBonusMultiplier -ne 2 -or
    $morrigan.aspectMechanics.hammers.DaggerTripleRepeatWomboTrait.repeatTripleStrikeChance -ne 0.33 -or
    @($morrigan.hammerRoles.PSObject.Properties).Count -ne 0) { throw 'Morrigan mechanics template differs from audited data.' }
foreach ($id in @('WeaponDagger','DaggerTripleAspect','WomboStrike','ComboAttackIndicator','ComboSpecialIndicator','ComboExIndicator','WeaponUpgradeBoon','DaggerTripleBuffTrait','DaggerTripleRepeatWomboTrait','DaggerTripleHomingSpecialTrait','DaggerBlinkAoETrait')) {
    if (-not (@($morrigan.verifiedIds.bloodTriad + $morrigan.verifiedIds.morriganHammers) -contains $id)) { throw "Missing Morrigan verified ID: $id" }
}
foreach ($profilePath in @('data\builds\sister_blades_melinoe_intermediate.lua')) {
    if (-not (Test-Path (Join-Path $repo $profilePath))) { throw "Missing runtime reference: $profilePath" }
}
Write-Output 'PASS: Sister Blades and conservative Black Coat canonical mechanics templates validated'
