$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$projection = Join-Path $repo 'data\projections\v02-showcase'
$source = Get-Content (Join-Path $projection 'rows.json') -Raw | ConvertFrom-Json
$policy = Get-Content (Join-Path $projection 'policy.json') -Raw | ConvertFrom-Json
$tool = Join-Path $repo 'tools\Test-BuildRegistryImport.ps1'
$catalog = Join-Path $repo 'data\canonical\catalog\weapons_aspects.json'
$expected = @{
    br2_blades_morrigan_meta_dbc147e065e62721 = 'DaggerTripleBuffTrait'
    br2_blades_morrigan_meta_0e7999238013ae66 = 'DaggerAttackFinisherTrait'
    br2_coat_melinoe_intermediate_78929f2a975027d2 = 'HestiaWeaponBoon'
    br2_coat_melinoe_intermediate_ef44fbef3991267d = 'ZeusWeaponBoon'
    br2_coat_melinoe_intermediate_093a7c1192f7eb29 = 'SuitAttackSizeTrait'
}
if ($source.projectionMode -cne 'delta_only_not_complete_profiles' -or
    $source.rows.Count -ne 5 -or $source.excludedActiveRows -ne 113 -or $source.deferredRows -ne 260) {
    throw 'Projection scope differs from the five approved deltas.'
}
if ($policy.keepsakeStartAsAutoSignal -or $policy.verifiedRuntimeItemIds.Count -ne 5) {
    throw 'Projection policy expanded beyond the five attested IDs.'
}
$seen = @{}
foreach ($row in $source.rows) {
    if (-not $expected.ContainsKey($row.recommendationId) -or $seen.ContainsKey($row.recommendationId) -or
        $row.runtimeItemId -cne $expected[$row.recommendationId]) { throw 'Unexpected or duplicate source mapping.' }
    $seen[$row.recommendationId] = $true
    if ($row.sourceRuntimeImportStatus -cne 'documentation_only' -or
        [string]::IsNullOrWhiteSpace($row.documentaryCondition) -or
        [string]::IsNullOrWhiteSpace($row.sourceFingerprint) -or
        [string]::IsNullOrWhiteSpace($row.conditionDisposition) -or
        $row.PSObject.Properties.Name -contains 'condition') {
        throw 'Documentary provenance lost or free-text condition made executable.'
    }
}
$plan = & $tool -InputPath (Join-Path $projection 'rows.json') -PolicyPath (Join-Path $projection 'policy.json') -CatalogPath $catalog | ConvertFrom-Json
if ($plan.groups.Count -ne 2) { throw 'Expected exactly Morrigan and Black Coat delta groups.' }
$count = 0
foreach ($group in $plan.groups) {
    if ($group.status -cne 'ready' -or $group.reasons.Count -ne 0) { throw 'Approved delta projection is blocked.' }
    $canonical = Get-Content (Join-Path $repo "data\canonical\profiles\$($group.canonicalId).json") -Raw | ConvertFrom-Json
    if ($group.weapon -cne $canonical.weapon -or $group.aspect -cne $canonical.aspect -or
        $group.profileKeyProposal -cne $canonical.selectionKey -or $group.profileMode -cne $canonical.profileMode) {
        throw 'Projection identity differs from canonical.'
    }
    foreach ($item in $group.items) {
        $count++
        if ($item.role -ceq 'hammer') {
            $match = @($canonical.hammerPlan | Where-Object { $_.traitId -ceq $item.runtimeItemId })
            if ($match.Count -ne 1 -or $match[0].priority -ne $item.priority -or
                $match[0].classification -cne $item.classification -or $match[0].condition) {
                throw 'Projected Hammer differs from canonical.'
            }
        } elseif ($item.role -ceq 'alternatives' -and $item.slot -ceq 'Attack') {
            if ($canonical.slots.Attack.alternatives -cnotcontains $item.runtimeItemId) {
                throw 'Projected Attack alternative missing from canonical.'
            }
        } else { throw 'Unexpected executable projection role.' }
    }
}
if ($count -ne 5) { throw 'Projection item count changed.' }
# Removing independent ID attestation must block the whole affected group.
$negative = Join-Path ([IO.Path]::GetTempPath()) ('v02-policy-' + [Guid]::NewGuid() + '.json')
try {
    $policy.verifiedRuntimeItemIds = @($policy.verifiedRuntimeItemIds | Where-Object { $_ -cne 'DaggerTripleBuffTrait' })
    [IO.File]::WriteAllText($negative, ($policy | ConvertTo-Json -Depth 20))
    $blocked = & $tool -InputPath (Join-Path $projection 'rows.json') -PolicyPath $negative -CatalogPath $catalog | ConvertFrom-Json
    $morrigan = @($blocked.groups | Where-Object { $_.canonicalId -ceq 'sister_blades_morrigan_meta' })[0]
    if ($morrigan.status -cne 'blocked' -or $morrigan.items.Count -ne 0 -or
        $morrigan.reasons -cnotcontains 'runtime_item_id_not_in_verified_policy') {
        throw 'Missing native attestation did not block the full group.'
    }
} finally { Remove-Item -LiteralPath $negative -Force -ErrorAction SilentlyContinue }
Write-Output 'PASS: five-row v0.2 projection, canonical parity, retained provenance and independent ID gate'
