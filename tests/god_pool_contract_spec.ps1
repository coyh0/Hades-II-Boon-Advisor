[CmdletBinding()]
param(
    [string]$NativeScriptsPath = 'D:\Dev\Games\HadesII-Dev\Content\Scripts'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$documentaryPath = Join-Path $repo 'data\documentary\profiles\argent_skull_medea_mobalytics_pilot.json'
$mechanicsPath = Join-Path $repo 'data\canonical\mechanics\argent_skull_medea_mobalytics.json'
$profilePath = Join-Path $repo 'data\canonical\profiles\argent_skull_medea_mobalytics.json'
$generatorPath = Join-Path $repo 'tools\Generate-BoonAdvisorProfiles.ps1'
$expected = @(
    @{ id = 'mobalytics_skull_medea_fullbuild_god_pool_zeus_01'; god = 'Zeus'; source = 'ZeusUpgrade'; file = 'LootData_Zeus.lua' },
    @{ id = 'mobalytics_skull_medea_fullbuild_god_pool_hera_01'; god = 'Hera'; source = 'HeraUpgrade'; file = 'LootData_Hera.lua' },
    @{ id = 'mobalytics_skull_medea_fullbuild_god_pool_ares_01'; god = 'Ares'; source = 'AresUpgrade'; file = 'LootData_Ares.lua' },
    @{ id = 'mobalytics_skull_medea_fullbuild_god_pool_demeter_01'; god = 'Demeter'; source = 'DemeterUpgrade'; file = 'LootData_Demeter.lua' }
)
function Invoke-GeneratorCaptured([string[]]$Arguments) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $captured = & powershell.exe @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        return [pscustomobject]@{ ExitCode = $exitCode; Output = ($captured | Out-String) }
    }
    finally { $ErrorActionPreference = $previousPreference }
}

$documentary = Get-Content -LiteralPath $documentaryPath -Raw | ConvertFrom-Json
$godPoolGroup = @($documentary.sourceGroups | Where-Object { $_.sourceLabel -ceq 'God Pool' })
if ($godPoolGroup.Count -ne 1) { throw 'Documentary extraction must contain one God Pool group.' }
$sourceRows = @($godPoolGroup[0].recommendations)
if ($sourceRows.Count -ne $expected.Count) { throw 'God Pool source row count differs from the reviewed source.' }
$mechanics = Get-Content -LiteralPath $mechanicsPath -Raw | ConvertFrom-Json
if (@($mechanics.godPool).Count -ne $expected.Count) { throw 'Canonical mechanics God Pool row count differs from the source.' }
$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
if ($profile.source.type -cne 'mobalytics' -or $profile.mechanicsTemplate -cne $mechanics.id) {
    throw 'God Pool profile must use the Mobalytics mechanics template.'
}

for ($i = 0; $i -lt $expected.Count; $i++) {
    $item = $expected[$i]
    $row = $sourceRows | Where-Object { $_.sourceRecommendationId -ceq $item.id }
    $mapping = $mechanics.godPool | Where-Object { $_.recommendationId -ceq $item.id }
    if (@($row).Count -ne 1 -or $row.sourceName -cne $item.god -or $row.category -cne 'Dieu' -or $row.informationState -cne 'sourced' -or $null -ne $row.individualPriority -or $null -ne $row.runtimeMapping) {
        throw "Source row is missing, duplicated, or was given an unsupported priority/mapping: $($item.id)"
    }
    if (@($mapping).Count -ne 1 -or $mapping.sourceGod -cne $item.god -or $mapping.offerSource -cne $item.source) {
        throw "Canonical God Pool mapping does not preserve the reviewed source row: $($item.id)"
    }
    $nativePath = Join-Path $NativeScriptsPath $item.file
    if (-not (Test-Path -LiteralPath $nativePath -PathType Leaf)) { throw "Native source file missing: $nativePath" }
    $nativeText = [IO.File]::ReadAllText($nativePath)
    if ($nativeText -cnotmatch ('(?m)^\s*' + [regex]::Escape($item.source) + '\s*=')) {
        throw "Runtime offer source ID was not found in native data: $($item.source)"
    }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('god-pool-contract-' + [Guid]::NewGuid().ToString('N'))
$tempMechanics = Join-Path $tempRoot 'mechanics'
$tempOutput = Join-Path $tempRoot 'generated'
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    New-Item -ItemType Directory -Path $tempMechanics | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $repo 'data\canonical\mechanics') -Filter '*.json' -File |
        Copy-Item -Destination $tempMechanics
    $validatorArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $generatorPath,
        '-MechanicsDirectory', $tempMechanics, '-ValidateOnly')
    & powershell.exe @validatorArgs | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Canonical generator rejected the God Pool template.' }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $generatorPath -OutputDirectory $tempOutput | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Canonical generator failed to produce runtime profiles.' }
    $generatedMedea = Join-Path $tempOutput 'argent_skull_medea_mobalytics.lua'
    if (-not (Test-Path -LiteralPath $generatedMedea -PathType Leaf)) { throw 'Generated Medea profile is missing.' }
    $generatedText = [IO.File]::ReadAllText($generatedMedea)
    foreach ($item in $expected) {
        if ($generatedText -notmatch [regex]::Escape($item.id) -or $generatedText -notmatch [regex]::Escape('sourceGod = "' + $item.god + '"') -or $generatedText -notmatch [regex]::Escape('offerSource = "' + $item.source + '"')) {
            throw "Generated profile lost God Pool source mapping: $($item.id)"
        }
    }
    $generatedMoonstonePath = Join-Path $tempOutput 'moonstone_axe_melinoe_mobalytics.lua'
    if ((Get-FileHash -LiteralPath $generatedMoonstonePath -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath (Join-Path $repo 'data\builds\moonstone_axe_melinoe_mobalytics.lua') -Algorithm SHA256).Hash) {
        throw 'Medea God Pool validation changed the independent Moonstone profile.'
    }

    $mechanicsJsonPath = Join-Path $tempMechanics 'argent_skull_medea_mobalytics.json'
    $mechanicsJson = Get-Content -LiteralPath $mechanicsJsonPath -Raw
    $mechanicsObject = $mechanicsJson | ConvertFrom-Json
    $mechanicsObject.godPool[0].sourceGod = 'UnknownGod'
    [IO.File]::WriteAllText($mechanicsJsonPath, ($mechanicsObject | ConvertTo-Json -Depth 100),
        (New-Object System.Text.UTF8Encoding($false)))
    $unknownResult = Invoke-GeneratorCaptured @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $generatorPath,
        '-MechanicsDirectory', $tempMechanics, '-ValidateOnly')
    if ($unknownResult.ExitCode -eq 0 -or $unknownResult.Output -notmatch 'unknown or mismatched verified God Pool source mapping') {
        throw 'Unknown God Pool source did not fail with a clear validation error.'
    }

    $mechanicsObject = $mechanicsJson | ConvertFrom-Json
    $mechanicsObject.godPool += $mechanicsObject.godPool[0]
    [IO.File]::WriteAllText($mechanicsJsonPath, ($mechanicsObject | ConvertTo-Json -Depth 100),
        (New-Object System.Text.UTF8Encoding($false)))
    $duplicateResult = Invoke-GeneratorCaptured @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $generatorPath,
        '-MechanicsDirectory', $tempMechanics, '-ValidateOnly')
    if ($duplicateResult.ExitCode -eq 0 -or $duplicateResult.Output -notmatch 'duplicate recommendation IDs') {
        throw 'Duplicate God Pool source did not fail with a clear validation error.'
    }
}
finally {
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolvedTemp.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing cleanup outside the temporary directory: $resolvedTemp"
    }
    Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
}

Write-Output 'PASS: God Pool source rows, native IDs, generator projection, strict validation, and absent-profile behavior'
