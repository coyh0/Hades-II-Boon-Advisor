$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$profilePath = Join-Path $repo 'data\documentary\profiles\argent_skull_medea_meta.json'
$profile = [IO.File]::ReadAllText($profilePath, (New-Object System.Text.UTF8Encoding($false, $true))) | ConvertFrom-Json
$profileText = [IO.File]::ReadAllText($profilePath, (New-Object System.Text.UTF8Encoding($false, $true)))

function Assert([bool]$condition, [string]$message) {
    if (-not $condition) { throw $message }
}

Assert ($profile.schemaVersion -eq 1) 'Unexpected documentary schema version.'
Assert ($profile.canonicalId -ceq 'argent_skull_medea_meta') 'Wrong canonical ID.'
Assert ($profile.buildKey -ceq 'skull_medea_meta') 'Wrong BuildKey.'
Assert ($profile.profileMode -ceq 'documentation_only') 'Profile became runtime-active.'
Assert ($profile.releaseScope -ceq 'future_deferred') 'Profile release scope changed.'
Assert ($profile.recommendations.Count -eq 27) 'Expected 27 independent DATA rows.'

$expectedRows = @(110..135) + @(173)
$actualRows = @($profile.recommendations | ForEach-Object { $_.dataRow })
Assert ((Compare-Object $expectedRows $actualRows -SyncWindow 0).Count -eq 0) 'DATA rows were omitted, merged, or reordered.'
$ids = @($profile.recommendations | ForEach-Object { $_.recommendationId })
Assert ((@($ids | Select-Object -Unique)).Count -eq 27) 'Recommendation IDs are not unique.'

foreach ($row in $profile.recommendations) {
    $data = $row.data
    $registry = $row.registry
    Assert ($data.BuildKey -ceq $profile.buildKey) "BuildKey mismatch at DATA row $($row.dataRow)."
    Assert ($data.Weapon -ceq 'Argent Skull' -and $data.Aspect -ceq 'Medea') "Weapon/aspect mismatch at DATA row $($row.dataRow)."
    Assert ($data.BuildName -ceq 'Medea · Blitz Burst') "Build name mismatch at DATA row $($row.dataRow)."
    Assert ($data.Source -ceq 'Lee Reamsnyder · Mobalytics · NeonHades2') "Source label changed at DATA row $($row.dataRow)."
    Assert ($data.SourceType -ceq 'Community guide' -and $data.SourceDate -ceq '2026-05-04') "Source metadata changed at DATA row $($row.dataRow)."
    Assert ($data.SourceURL -like 'https://www.leereamsnyder.com/*') "Source URL missing at DATA row $($row.dataRow)."
    Assert ($registry.releaseScope -ceq 'future_deferred') "Runtime scope at DATA row $($row.dataRow)."
    Assert ($registry.recommendationVerificationStatus -ceq 'documentary_content_approved') "Documentary approval lost at DATA row $($row.dataRow)."
    Assert ($registry.nativeMechanicsVerificationStatus -ceq 'not_reassessed' -and $registry.nativeIdVerificationStatus -ceq 'not_reassessed') "Verification status promoted at DATA row $($row.dataRow)."
    Assert ($registry.runtimeImportStatus -ceq 'documentation_only' -and $null -eq $registry.verifiedNativeItemId) "Native ID or runtime import promoted at DATA row $($row.dataRow)."
    Assert ($registry.runtimeBlockReasons -contains 'native_id_not_reassessed') "Native ID block reason missing at DATA row $($row.dataRow)."
    Assert ($registry.conditionResolutionStatus -in @('free_text_unresolved','not_applicable')) "Condition status changed at DATA row $($row.dataRow)."
}

$byRow = @{}
foreach ($row in $profile.recommendations) { $byRow[[int]$row.dataRow] = $row }
Assert ((Compare-Object @(116,117,132) @($profile.branches.zeus_burst.dataRows) -SyncWindow 0).Count -eq 0) 'Zeus/burst branch changed.'
Assert ((Compare-Object @(118,120,133) @($profile.branches.ice_control.dataRows) -SyncWindow 0).Count -eq 0) 'Ice/control branch changed.'
Assert ($byRow[116].data.Choice -ceq 'Heaven Flourish' -and $byRow[117].data.Choice -ceq 'Sworn Strike' -and $byRow[132].data.Choice -ceq 'Static Shock') 'Zeus/burst choices changed.'
Assert ($byRow[118].data.Choice -ceq 'Ice Strike' -and $byRow[120].data.Choice -ceq 'Arctic Ring' -and $byRow[133].data.Choice -ceq 'Snow Queen') 'Ice/control choices changed.'
Assert ($null -eq $byRow[121].data.Choice -and $null -eq $byRow[121].data.God) 'Unnamed Gain was filled.'
Assert ($null -eq $byRow[173].data.Choice -and $null -eq $byRow[173].data.God) 'Unnamed Sprint was filled.'
Assert ($byRow[173].data.SourceURL -notlike '*neonspace*') 'DATA row 173 URL was silently expanded.'
Assert ($byRow[173].registry.runtimeBlockReasons -contains 'generic_unnamed_choice') 'Sprint block reason missing.'
Assert ($profileText -notmatch 'Premium Service|WeaponUpgradeBoon') 'Premium Service was associated with this documentary profile.'
Assert ((@($profile.recommendations | Where-Object { $_.data.Category -eq 'Hex' })).Count -eq 0) 'An unsourced Hex was added.'
Assert ($profilePath -notlike '*data\canonical\profiles*') 'Documentary profile entered runtime canonical directory.'
Assert (-not (Test-Path (Join-Path $repo 'data\builds\argent_skull_medea_meta.lua'))) 'Runtime module was created.'

# Project the documentary item rows into the existing importer contract. The
# gameplay note is not an importable item type and remains in the document above.
$types = @{ Boon='boon'; Keepsake='keepsake'; Hammer='hammer'; Support='support'; Arcana='arcana'; Familiar='familiar' }
$importRows = @($profile.recommendations | Where-Object { $_.data.Category -ne 'Gameplay' } | ForEach-Object {
    [ordered]@{
        profileKeyProposal = $profile.buildKey
        canonicalId = $profile.canonicalId
        profileMode = $profile.profileMode
        itemType = $types[$_.data.Category]
        slot = $_.data.Slot
        classification = $_.data.Classification
        name = $_.data.Choice
        god = $_.data.God
        condition = $_.data.Condition
        runtimeItemId = $null
        importStatus = $_.registry.runtimeImportStatus
        verificationStatus = 'unverified'
    }
})
Assert ($importRows.Count -eq 26) 'Unexpected number of importer item rows.'
$tempDir = Join-Path ([IO.Path]::GetTempPath()) ('medea-documentary-import-' + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    $inputPath = Join-Path $tempDir 'rows.json'
    $outputPath = Join-Path $tempDir 'plan.json'
    [IO.File]::WriteAllText($inputPath, (ConvertTo-Json -InputObject ([ordered]@{schemaVersion=1; rows=$importRows}) -Depth 15), (New-Object System.Text.UTF8Encoding($false)))
    $tool = Join-Path $repo 'tools\Test-BuildRegistryImport.ps1'
    $policy = Join-Path $tempDir 'policy.json'
    [IO.File]::WriteAllText($policy, '{"schemaVersion":1,"boonClassifications":{},"hammerClassifications":{},"verifiedRuntimeItemIds":[],"keepsakeStartAsAutoSignal":false}', (New-Object System.Text.UTF8Encoding($false)))
    & $tool -InputPath $inputPath -PolicyPath $policy -OutputPath $outputPath | Out-Null
    $plan = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
    Assert ($plan.groups.Count -eq 0) 'Documentary Medea rows entered the runtime import plan.'
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force
}

Write-Output 'Medea documentary profile: 27 DATA rows preserved; 26 importable item rows excluded.'
