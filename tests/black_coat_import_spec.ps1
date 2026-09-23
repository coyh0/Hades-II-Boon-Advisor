$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $PSScriptRoot 'fixtures\build_registry\black_coat_melinoe_intermediate_rows.json'
$policy = Join-Path $PSScriptRoot 'fixtures\build_registry\black_coat_melinoe_intermediate_policy.json'
$canonicalPath = Join-Path $repo 'data\canonical\profiles\black_coat_melinoe_intermediate.json'
$tool = Join-Path $repo 'tools\Test-BuildRegistryImport.ps1'

function Read-Json([string]$path) {
    return ([IO.File]::ReadAllText($path, (New-Object System.Text.UTF8Encoding($false, $true))) | ConvertFrom-Json)
}
function Assert-Equal([object]$actual, [object]$expected, [string]$label) {
    if (-not [string]::Equals([string]$actual, [string]$expected, [StringComparison]::Ordinal)) {
        throw "$label mismatch: expected '$expected', got '$actual'"
    }
}

$source = Read-Json $fixture
$canonical = Read-Json $canonicalPath
$runtimeRows = @($source.rows | Where-Object { $_.importStatus -eq 'ready' })
$documentationRows = @($source.rows | Where-Object { $_.importStatus -eq 'documentation_only' })
if ($source.rows.Count -ne 14 -or $runtimeRows.Count -ne 4 -or $documentationRows.Count -ne 10) {
    throw 'Pilot fixture must contain exactly 4 ready and 10 documentation-only rows.'
}
$expectedDocumentationCounts = [ordered]@{ arcana = 3; hammer = 3; support = 2; familiar = 1; hex = 1 }
foreach ($type in $expectedDocumentationCounts.Keys) {
    if (@($documentationRows | Where-Object { $_.itemType -ceq $type }).Count -ne $expectedDocumentationCounts[$type]) {
        throw "Unexpected documentation-only $type row count."
    }
}
foreach ($row in $documentationRows) {
    if ($row.verificationStatus -cne 'not_applicable' -or $row.PSObject.Properties.Name -contains 'runtimeItemId') {
        throw "Documentation-only row '$($row.name)' must be not_applicable and have no runtimeItemId."
    }
}
$expectedHammers = @('Exhaust Riser', 'Rapid Frame', 'Launcher Frame')
$actualHammers = @($documentationRows | Where-Object { $_.itemType -ceq 'hammer' } | ForEach-Object { $_.name } | Sort-Object)
if (-not [Linq.Enumerable]::SequenceEqual([string[]]$actualHammers, [string[]]@($expectedHammers | Sort-Object))) {
    throw 'Documentation-only Hammer inventory changed.'
}

$plan = & $tool -InputPath $fixture -PolicyPath $policy | ConvertFrom-Json
if ($plan.schemaVersion -ne 1 -or @($plan.groups).Count -ne 1) { throw 'Expected exactly one import group.' }
$group = $plan.groups[0]
Assert-Equal $group.status 'ready' 'import status'
if (@($group.reasons).Count -ne 0) { throw 'Ready pilot unexpectedly has blocked reasons.' }
Assert-Equal $group.profileKeyProposal $canonical.selectionKey 'selection key'
Assert-Equal $group.canonicalId $canonical.id 'canonical ID'
Assert-Equal $group.module "data/builds/$($canonical.id).lua" 'module'
Assert-Equal $group.weapon $canonical.weapon 'weapon'
Assert-Equal $group.aspect $canonical.aspect 'aspect'
Assert-Equal $group.profileMode $canonical.profileMode 'profile mode'
if (@($group.items).Count -ne 4) { throw 'Documentation-only rows entered the runtime projection.' }

$signal = @($group.items | Where-Object { $_.role -ceq 'autoSignal' })
if ($signal.Count -ne 1 -or @($canonical.autoSignals).Count -ne 1) { throw 'Expected one keepsake autoSignal.' }
Assert-Equal $signal[0].runtimeItemId $canonical.autoSignals[0] 'autoSignal'
if ($null -ne $signal[0].slot) { throw 'Keepsake autoSignal acquired a core slot.' }
foreach ($slot in @('Attack', 'Special', 'Sprint')) {
    $items = @($group.items | Where-Object { $_.slot -ceq $slot -and $_.role -ceq 'core' })
    $expected = @($canonical.slots.$slot.core)
    if ($items.Count -ne 1 -or $expected.Count -ne 1) { throw "Expected one $slot core." }
    Assert-Equal $items[0].runtimeItemId $expected[0] "$slot core"
}
foreach ($item in $group.items) {
    if (@($runtimeRows | Where-Object { $_.runtimeItemId -ceq $item.runtimeItemId }).Count -ne 1) {
        throw "Unexpected runtime item $($item.runtimeItemId)."
    }
}
Write-Output 'PASS: Black Coat Build Registry pilot is READY; importable projection matches canonical profile; documentation-only rows ignored'
