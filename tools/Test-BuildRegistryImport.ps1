[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$PolicyPath,
    [string]$CatalogPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'data\canonical\catalog\weapons_aspects.json'),
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'

function Fail([string]$message) { throw "Build Registry import validation failed: $message" }
function Read-Json([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "missing input file: $path" }
    $jsonText = [IO.File]::ReadAllText($path, (New-Object System.Text.UTF8Encoding($false, $true)))
    return $jsonText | ConvertFrom-Json
}
function Required-String([object]$value, [string]$field) {
    if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) { Fail "$field must be a non-empty string" }
}
function Optional-String([object]$value, [string]$field) {
    if ($null -ne $value -and $value -isnot [string]) { Fail "$field must be a string when present" }
}
function Properties([object]$value) {
    if ($null -eq $value -or $value -isnot [pscustomobject]) { return @() }
    return @($value.PSObject.Properties)
}
function Has-Property([object]$value, [string]$name) {
    return $null -ne $value.PSObject.Properties[$name]
}
function Add-Reason([System.Collections.Generic.List[string]]$reasons, [string]$reason) {
    if (-not $reasons.Contains($reason)) { $reasons.Add($reason) }
}

$document = Read-Json $InputPath
$policy = Read-Json $PolicyPath
$catalog = Read-Json $CatalogPath
if ($document.schemaVersion -ne 1 -or $document.rows -isnot [array]) { Fail 'input requires schemaVersion 1 and a rows array' }
if ($policy.schemaVersion -ne 1 -or $policy.boonClassifications -isnot [pscustomobject] -or
    $policy.verifiedRuntimeItemIds -isnot [array] -or $policy.keepsakeStartAsAutoSignal -isnot [bool]) {
    Fail 'policy requires schemaVersion 1, boonClassifications, verifiedRuntimeItemIds, and keepsakeStartAsAutoSignal'
}
if ($catalog.schemaVersion -ne 1 -or $catalog.weapons -isnot [array]) { Fail 'catalog requires schemaVersion 1 and a weapons array' }

$verifiedItems = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($itemId in $policy.verifiedRuntimeItemIds) {
    Required-String $itemId 'policy.verifiedRuntimeItemIds entry'
    if (-not $verifiedItems.Add($itemId)) { Fail "duplicate verified runtime item ID $itemId" }
}
$roleNames = @('core', 'alternatives', 'preferred', 'discouraged')
foreach ($entry in (Properties $policy.boonClassifications)) {
    if ($entry.Value -cnotin $roleNames) { Fail "unsupported policy role for classification $($entry.Name)" }
}
$catalogPairs = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$catalogWeapons = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($weapon in $catalog.weapons) {
    Required-String $weapon.runtimeWeaponId 'catalog.runtimeWeaponId'
    if (-not $catalogWeapons.Add($weapon.runtimeWeaponId)) { Fail "duplicate catalog weapon $($weapon.runtimeWeaponId)" }
    if ($weapon.aspects -isnot [array]) { Fail "catalog aspects must be an array for $($weapon.runtimeWeaponId)" }
    foreach ($aspect in $weapon.aspects) {
        Required-String $aspect.runtimeAspectId 'catalog.runtimeAspectId'
        $pair = $weapon.runtimeWeaponId + '/' + $aspect.runtimeAspectId
        if (-not $catalogPairs.Add($pair)) { Fail "duplicate catalog weapon/aspect $pair" }
    }
}

$allowedImport = @('ready', 'blocked', 'excluded', 'documentation_only')
$allowedVerification = @('verified', 'unverified', 'not_applicable')
$allowedTypes = @('boon', 'keepsake', 'hammer', 'support', 'arcana', 'familiar', 'hex')
$slotMap = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
$slotMap.Add('attack', 'Attack')
$slotMap.Add('special', 'Special')
$slotMap.Add('cast', 'Cast')
$slotMap.Add('sprint', 'Sprint')
$groups = @{}
$canonicalOwners = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
foreach ($row in $document.rows) {
    if ($row -isnot [pscustomobject]) { Fail 'every row must be an object' }
    foreach ($field in @('importStatus', 'verificationStatus', 'itemType')) { Required-String $row.$field $field }
    if ($row.importStatus -cnotin $allowedImport) { Fail "invalid importStatus $($row.importStatus)" }
    if ($row.verificationStatus -cnotin $allowedVerification) { Fail "invalid verificationStatus $($row.verificationStatus)" }
    if ($row.itemType -cnotin $allowedTypes) { Fail "invalid itemType $($row.itemType)" }
    if ((Has-Property $row 'profileMode') -and $null -ne $row.profileMode -and $row.profileMode -isnot [string]) { Fail 'profileMode must be a string when present' }
    foreach ($field in @('canonicalId', 'runtimeWeaponId', 'runtimeAspectId', 'runtimeItemId', 'module',
        'name', 'god', 'weaponLabel', 'aspectLabel', 'condition', 'classification', 'slot')) {
        Optional-String $row.$field $field
    }
    if ($row.importStatus -in @('excluded', 'documentation_only')) { continue }
    Required-String $row.profileKeyProposal 'profileKeyProposal for active row'
    if ($row.profileKeyProposal -cnotmatch '^[a-z][a-z0-9_]*$') { Fail "invalid profileKeyProposal $($row.profileKeyProposal)" }
    if (-not $groups.ContainsKey($row.profileKeyProposal)) { $groups[$row.profileKeyProposal] = @() }
    $groups[$row.profileKeyProposal] += ,$row
    if ($row.importStatus -eq 'ready') {
        Required-String $row.canonicalId 'canonicalId for ready row'
        if ($row.canonicalId -cnotmatch '^[a-z][a-z0-9_]*$') { Fail "invalid canonicalId $($row.canonicalId)" }
    }
}

$plans = @()
foreach ($groupKey in @($groups.Keys | Sort-Object -CaseSensitive)) {
    $rows = @($groups[$groupKey])
    $identities = New-Object 'System.Collections.Generic.List[string]'
    foreach ($identityRow in $rows) {
        $identityValue = [string]$identityRow.canonicalId
        $found = $false
        foreach ($knownIdentity in $identities) { if ([string]::Equals($knownIdentity, $identityValue, [StringComparison]::Ordinal)) { $found = $true; break } }
        if (-not $found) { $identities.Add($identityValue) }
    }
    if ($identities.Count -ne 1) { Fail "conflicting canonicalId in group $groupKey" }
    $id = $identities[0]
    if ($id -and $id -cnotmatch '^[a-z][a-z0-9_]*$') { Fail "invalid canonicalId $id" }
    if ($id) {
        if ($canonicalOwners.ContainsKey($id)) { Fail "duplicate canonicalId $id across groups" }
        $canonicalOwners.Add($id, $groupKey)
    }
    foreach ($field in @('profileMode', 'runtimeWeaponId', 'runtimeAspectId')) {
        $values = New-Object 'System.Collections.Generic.List[string]'
        foreach ($identityRow in $rows) {
            $identityValue = [string]$identityRow.$field
            $found = $false
            foreach ($knownValue in $values) { if ([string]::Equals($knownValue, $identityValue, [StringComparison]::Ordinal)) { $found = $true; break } }
            if (-not $found) { $values.Add($identityValue) }
        }
        if ($values.Count -ne 1) { Fail "conflicting $field in group $groupKey" }
    }
    $first = $rows[0]
    $reasons = New-Object 'System.Collections.Generic.List[string]'
    if (-not $id) { Add-Reason $reasons 'missing_canonical_id' }
    if (-not $first.profileMode) { Add-Reason $reasons 'missing_profile_mode' }
    if (-not $first.runtimeWeaponId) { Add-Reason $reasons 'missing_runtime_weapon_id' }
    if (-not $first.runtimeAspectId) { Add-Reason $reasons 'missing_runtime_aspect_id' }
    $pair = [string]$first.runtimeWeaponId + '/' + [string]$first.runtimeAspectId
    if ($first.runtimeWeaponId -and $first.runtimeAspectId -and -not $catalogPairs.Contains($pair)) {
        Add-Reason $reasons 'unverified_weapon_aspect'
    }
    $derivedModule = if ($id) { "data/builds/$id.lua" } else { $null }
    $items = @()
    foreach ($row in $rows) {
        if ($row.importStatus -eq 'blocked') { Add-Reason $reasons 'source_row_blocked'; continue }
        if ($row.module -and $row.module -cne $derivedModule) { Add-Reason $reasons 'module_mismatch' }
        if ($row.verificationStatus -ne 'verified') { Add-Reason $reasons 'unverified_runtime_item_id' }
        if (-not $row.runtimeItemId) { Add-Reason $reasons 'missing_runtime_item_id' }
        elseif (-not $verifiedItems.Contains($row.runtimeItemId)) { Add-Reason $reasons 'runtime_item_id_not_in_verified_policy' }
        $role = $null; $slot = $null
        if ($row.itemType -eq 'boon') {
            if ($row.slot -ceq 'gain') { Add-Reason $reasons 'gain_to_mana_unverified' }
            elseif ($slotMap.ContainsKey([string]$row.slot)) {
                $slot = $slotMap[[string]$row.slot]
                $classification = (Properties $policy.boonClassifications | Where-Object { $_.Name -ceq $row.classification } | Select-Object -First 1)
                if ($null -eq $classification) { Add-Reason $reasons 'unsupported_boon_classification' }
                else { $role = [string]$classification.Value }
            } else { Add-Reason $reasons 'unsupported_boon_slot' }
        } elseif ($row.itemType -eq 'keepsake') {
            if ($row.slot -cne 'start' -or -not $policy.keepsakeStartAsAutoSignal) { Add-Reason $reasons 'unsupported_keepsake_mapping' }
            else { $role = 'autoSignal' }
        } else { Add-Reason $reasons 'unsupported_runtime_item_type' }
        if ($role -and $row.runtimeItemId) {
            $items += [ordered]@{ runtimeItemId = $row.runtimeItemId; slot = $slot; role = $role; name = $row.name }
        }
    }
    $orderedItems = @($items | Sort-Object { [string]$_.slot }, { [string]$_.role }, { [string]$_.runtimeItemId })
    $orderedReasons = @($reasons | Sort-Object -CaseSensitive)
    $status = if ($orderedReasons.Count -eq 0 -and $orderedItems.Count -gt 0) { 'ready' } else { 'blocked' }
    $visibleItems = @()
    if ($status -eq 'ready') { $visibleItems = @($orderedItems) }
    $plans += [ordered]@{
        profileKeyProposal = $groupKey
        canonicalId = $id
        status = $status
        reasons = $orderedReasons
        module = if ($status -eq 'ready') { $derivedModule } else { $null }
        weapon = if ($status -eq 'ready') { $first.runtimeWeaponId } else { $null }
        aspect = if ($status -eq 'ready') { $first.runtimeAspectId } else { $null }
        profileMode = if ($status -eq 'ready') { $first.profileMode } else { $null }
        items = $visibleItems
    }
}
$result = [ordered]@{ schemaVersion = 1; groups = @($plans) }
$json = ConvertTo-Json -InputObject $result -Depth 20 -Compress
if ($OutputPath) { [IO.File]::WriteAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath), $json + "`n", (New-Object System.Text.UTF8Encoding($false))) }
else { Write-Output $json }
