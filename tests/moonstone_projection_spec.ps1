$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$base = Join-Path $repo 'data\projections\moonstone-axe-starter'
$rows = Get-Content -LiteralPath (Join-Path $base 'rows.json') -Raw | ConvertFrom-Json
$policy = Get-Content -LiteralPath (Join-Path $base 'policy.json') -Raw | ConvertFrom-Json
$source = Get-Content -LiteralPath (Join-Path $base 'source-recommendations.json') -Raw | ConvertFrom-Json
$mechanics = Get-Content -LiteralPath (Join-Path $repo 'data\canonical\mechanics\moonstone_axe_melinoe_mobalytics.json') -Raw | ConvertFrom-Json
if ($source.recommendations.Count -ne 52 -or $rows.rows.Count -ne 14 -or
    @($rows.rows | Where-Object sourceGroup -EQ 'Core Boons').Count -ne 5 -or
    @($rows.rows | Where-Object sourceGroup -EQ 'Non-Core Boons').Count -ne 6 -or
    @($rows.rows | Where-Object itemType -EQ 'offering').Count -ne 3) {
    throw 'Moonstone source/import projection counts changed.'
}
$sourceIds = @($source.recommendations | ForEach-Object recommendationId)
foreach ($row in $rows.rows) {
    if ($sourceIds -cnotcontains $row.recommendationId) { throw "Import row lost source evidence: $($row.name)" }
    $mapped = $mechanics.sourceScoring.boons.PSObject.Properties[$row.runtimeItemId]
    if ($null -eq $mapped) { throw "Canonical source group missing: $($row.runtimeItemId)" }
    if ($row.itemType -eq 'boon') {
        if ($mapped.Value -cne $row.sourceGroup) { throw "Canonical source group differs: $($row.runtimeItemId)" }
        if ($row.sourceGroup -ceq 'Core Boons' -and $mechanics.corePlan.PSObject.Properties[$row.runtimeItemId].Value.role -cne $row.coreRole) {
            throw "Canonical Core role differs: $($row.runtimeItemId)"
        }
    } elseif ($mapped.Value -cne 'Offerings' -or
        $mechanics.sourceScoring.offerSources.PSObject.Properties[$row.runtimeItemId].Value -cne $row.offerSource) {
        throw "Canonical offering pair differs: $($row.runtimeItemId)"
    }
}
if (@($mechanics.sourceScoring.hammers.PSObject.Properties).Count -ne 0 -or
    @($mechanics.sourceScoring.deferred.PSObject.Properties).Count -ne 0) {
    throw 'Documentary Hammers or deferred boons became active.'
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ('moonstone-import-' + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $temp -Force | Out-Null
$resultPath = Join-Path $temp 'plan.json'
$tool = Join-Path $repo 'tools\Test-BuildRegistryImport.ps1'
$catalog = Join-Path $repo 'data\canonical\catalog\weapons_aspects.json'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -InputPath (Join-Path $base 'rows.json') -PolicyPath (Join-Path $base 'policy.json') -CatalogPath $catalog -AttestationCatalogPath (Join-Path $repo 'data\canonical\catalog\runtime_attestations.json') -OutputPath $resultPath | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Moonstone importer validation failed.' }
$plan = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
if ($plan.groups.Count -ne 1 -or $plan.groups[0].status -cne 'ready' -or $plan.groups[0].items.Count -ne 14) {
    throw 'Moonstone import did not produce one complete ready group.'
}
foreach ($row in $rows.rows) {
    $matches = @($plan.groups[0].items | Where-Object runtimeItemId -CEQ $row.runtimeItemId)
    $item = if ($matches.Count -eq 1) { $matches[0] } else { $null }
    $expectedRole = if ($row.itemType -eq 'offering') { 'offering' } elseif ($row.sourceGroup -ceq 'Core Boons') { 'core' } else { 'nonCore' }
    $expectedSlot = if ($row.sourceGroup -ceq 'Core Boons') { $row.coreRole } else { $null }
    if ($null -eq $item -or $matches.Count -ne 1 -or $item.role -cne $expectedRole -or
        $item.slot -cne $expectedSlot -or $item.name -cne $row.name -or
        ($expectedRole -eq 'offering' -and $item.offerSource -cne $row.offerSource)) {
        throw "Imported Build Registry candidate differs from the approved projection: $($row.runtimeItemId)"
    }
}
Remove-Item -LiteralPath $temp -Recurse -Force
Write-Output 'PASS: Moonstone source/plan/canonical parity and 14 verified runtime candidates'
