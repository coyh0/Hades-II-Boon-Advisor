$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$root = Join-Path ([IO.Path]::GetTempPath()) ('attestation-consumers-' + [Guid]::NewGuid())
$profiles = Join-Path $root 'profiles'
$mechanics = Join-Path $root 'mechanics'
$catalogPath = Join-Path $root 'attestations.json'
$out = Join-Path $root 'generated'
$generator = Join-Path $repo 'tools\Generate-BoonAdvisorProfiles.ps1'
$weaponCatalog = Join-Path $repo 'data\canonical\catalog\weapons_aspects.json'
$sourceAttestationCatalog = Join-Path $repo 'data\canonical\catalog\runtime_attestations.json'
$windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
New-Item -ItemType Directory -Path $profiles,$mechanics -Force | Out-Null
Copy-Item (Join-Path $repo 'data\canonical\profiles\*.json') $profiles
Copy-Item (Join-Path $repo 'data\canonical\mechanics\*.json') $mechanics
Copy-Item $sourceAttestationCatalog $catalogPath

function Write-Json([string]$Path, [object]$Value) {
    [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 40), (New-Object System.Text.UTF8Encoding($false)))
}
function Run-Generator([string]$Catalog = $catalogPath, [string]$ProfileDirectory = $profiles, [string]$MechanicsDirectory = $mechanics, [bool]$ExpectedSuccess = $true) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $null = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator `
        -CanonicalDirectory $ProfileDirectory -MechanicsDirectory $MechanicsDirectory `
        -CatalogPath $weaponCatalog -AttestationCatalogPath $Catalog -ValidateOnly 2>$null
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    if (($exitCode -eq 0) -ne $ExpectedSuccess) { throw "Unexpected generator validation result (exit=$exitCode; expected success=$ExpectedSuccess)." }
}

try {
    Run-Generator
    & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $generator `
        -CanonicalDirectory $profiles -MechanicsDirectory $mechanics -CatalogPath $weaponCatalog `
        -AttestationCatalogPath $catalogPath -OutputDirectory $out | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Generator failed to emit catalog-backed profiles.' }
    foreach ($name in @('argent_skull_medea_mobalytics.lua','moonstone_axe_melinoe_mobalytics.lua','registry.lua')) {
        $generatedHash = (Get-FileHash (Join-Path $out $name) -Algorithm SHA256).Hash
        $baselineHash = (Get-FileHash (Join-Path (Join-Path $repo 'data\builds') $name) -Algorithm SHA256).Hash
        if ($generatedHash -cne $baselineHash) { throw "Functional generated output changed for $name ($generatedHash versus $baselineHash)." }
    }

    # A build may not add an ID to its own projection to bypass missing native evidence.
    $moonstonePath = Join-Path $mechanics 'moonstone_axe_melinoe_mobalytics.json'
    $moonstone = Get-Content $moonstonePath -Raw | ConvertFrom-Json
    $moonstone.sourceScoring.boons | Add-Member -NotePropertyName AresWeaponBoon -NotePropertyValue 'Non-Core Boons'
    Write-Json $moonstonePath $moonstone
    Run-Generator -ExpectedSuccess $false
    $moonstone.sourceScoring.boons.PSObject.Properties.Remove('AresWeaponBoon')
    Write-Json $moonstonePath $moonstone

    # A projection pair must match the exact source/boon evidence, not just a source allowlist.
    $moonstone.sourceScoring.offerSources.ChaosHealthBlessing = 'NPC_Artemis_Field_01'
    Write-Json $moonstonePath $moonstone
    Run-Generator -ExpectedSuccess $false
    $moonstone.sourceScoring.offerSources.ChaosHealthBlessing = 'TrialUpgrade'
    Write-Json $moonstonePath $moonstone

    # Evidence with a non-usable status cannot authorize the same native identity.
    $catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json
    $mana = $catalog.nativeItems | Where-Object runtimeItemId -CEQ 'HephaestusManaBoon'
    $mana.claims[0].status = 'needs_revalidation'
    Write-Json $catalogPath $catalog
    Run-Generator -ExpectedSuccess $false
    Copy-Item $sourceAttestationCatalog $catalogPath -Force

    # Historical Medea mechanics remain valid without consulting the shared catalog.
    $legacyProfiles = Join-Path $root 'legacy-profiles'; $legacyMechanics = Join-Path $root 'legacy-mechanics'
    New-Item -ItemType Directory -Path $legacyProfiles,$legacyMechanics -Force | Out-Null
    Copy-Item (Join-Path $repo 'data\canonical\profiles\argent_skull_medea_mobalytics.json') $legacyProfiles
    Copy-Item (Join-Path $repo 'data\canonical\mechanics\argent_skull_medea_mobalytics.json') $legacyMechanics
    Run-Generator -Catalog 'missing-catalog-is-allowed-for-legacy-mode' -ProfileDirectory $legacyProfiles -MechanicsDirectory $legacyMechanics

    Write-Output 'PASS: catalog-backed importer/generator refusals, exact source pairs, legacy Medea compatibility, and unchanged generated Lua parity'
} finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
