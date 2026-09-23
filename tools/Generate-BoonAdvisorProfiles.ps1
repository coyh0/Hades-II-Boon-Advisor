[CmdletBinding()]
param(
    [string]$CanonicalDirectory,
    [string]$MechanicsDirectory,
    [string]$OutputDirectory,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($CanonicalDirectory)) {
    $CanonicalDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'data\canonical\profiles'
}
if ([string]::IsNullOrWhiteSpace($MechanicsDirectory)) {
    $MechanicsDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'data\canonical\mechanics'
}
if (-not $PSBoundParameters.ContainsKey('OutputDirectory')) {
    $OutputDirectory = Join-Path ([IO.Path]::GetTempPath()) ('boon-advisor-generated-' + [Guid]::NewGuid())
}
function Fail([string]$message) { throw "Canonical profile validation failed: $message" }
function ConvertTo-HashtableRecursive([object]$value) {
    if ($null -eq $value) { return $null }
    if ($value -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in $value.Keys) { $table[$key] = ConvertTo-HashtableRecursive $value[$key] }
        return $table
    }
    if ($value -is [PSCustomObject]) {
        $table = @{}
        foreach ($property in $value.PSObject.Properties) {
            $table[$property.Name] = ConvertTo-HashtableRecursive $property.Value
        }
        return $table
    }
    if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
        $items = @()
        foreach ($item in $value) { $items += ,(ConvertTo-HashtableRecursive $item) }
        return ,$items
    }
    return $value
}
function Read-Json([string]$path) {
    $parsed = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    return ConvertTo-HashtableRecursive $parsed
}
function Assert-String([object]$value, [string]$name) {
    if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) { Fail "$name must be a non-empty string" }
}
function Assert-StringArray([object]$value, [string]$name) {
    if ($value -isnot [object[]]) { Fail "$name must be an array" }
    $seen = @{}
    foreach ($item in $value) {
        Assert-String $item "$name entry"
        if ($seen[$item]) { Fail "$name contains duplicate ID $item" }
        $seen[$item] = $true
    }
}
function Validate-Profile([hashtable]$profile, [hashtable]$seenIds) {
    if ($profile.schemaVersion -ne 1) { Fail 'unsupported schemaVersion' }
    foreach ($field in @('id', 'weapon', 'aspect', 'profileMode', 'selectionKey', 'mechanicsTemplate')) { Assert-String $profile[$field] $field }
    if ($profile.selectionKey -notmatch '^[a-z][a-z0-9_]*$') { Fail "invalid selectionKey $($profile.selectionKey)" }
    if ($seenIds[$profile.id]) { Fail "duplicate profile id $($profile.id)" }; $seenIds[$profile.id] = $true
    if ($profile.weapon -ne 'WeaponDagger' -or $profile.aspect -notin @('DaggerBackstabAspect', 'DaggerTripleAspect')) { Fail 'unknown weapon/aspect' }
    if ($profile.source -isnot [hashtable]) { Fail 'source must be an object' }
    Assert-String $profile.source.type 'source.type'; Assert-String $profile.source.profile 'source.profile'
    if ($profile.slots -isnot [hashtable]) { Fail 'slots must be an object' }
    if ($profile.ContainsKey('autoSignals')) { Assert-StringArray $profile.autoSignals 'autoSignals' }
    foreach ($slotName in $profile.slots.Keys) {
        if ($slotName -notin @('Attack', 'Special', 'Cast', 'Sprint', 'Mana')) { Fail "unknown slot name $slotName" }
        $slot = $profile.slots[$slotName]
        if ($slot -isnot [hashtable] -or $slot.slotPolicy -notin @('reserved', 'preferred', 'open')) { Fail "unknown slotPolicy in $slotName" }
        $all = @{}
        foreach ($role in @('core', 'alternatives', 'preferred', 'discouraged')) {
            if ($role -eq 'discouraged' -and $null -eq $slot[$role]) { continue }
            Assert-StringArray $slot[$role] "$slotName.$role"
            foreach ($id in $slot[$role]) { if ($all[$id]) { Fail "contradictory role assignment for $id in $slotName" }; $all[$id] = $true }
        }
    }
    if ($profile.ContainsKey('rules')) {
        if ($profile.rules -isnot [hashtable]) { Fail 'rules must be an object' }
        foreach ($offerId in $profile.rules.Keys) {
            Assert-String $offerId 'rules offer trait ID'
            $seenConditions = @{}
            if ($profile.rules[$offerId] -isnot [object[]]) { Fail "rules.$offerId must be an array" }
            foreach ($rule in $profile.rules[$offerId]) {
                if ($rule -isnot [hashtable]) { Fail "rules.$offerId entry must be an object" }
                Assert-String $rule.code "rules.$offerId.code"
                Assert-String $rule.weight "rules.$offerId.weight"
                $hasAll = $rule.ContainsKey('requiresAllOwned')
                $hasAny = $rule.ContainsKey('requiresAnyOwned')
                if (($hasAll -and $hasAny) -or (-not $hasAll -and -not $hasAny)) { Fail "rules.$offerId must contain exactly one ownership condition" }
                $conditionName = if ($hasAny) { 'requiresAnyOwned' } else { 'requiresAllOwned' }
                $condition = $rule[$conditionName]
                if ($condition -isnot [object[]] -or $condition.Count -eq 0) { Fail "rules.$offerId.$conditionName must be a non-empty array" }
                Assert-StringArray $condition "rules.$offerId.$conditionName"
                $conditionKey = $conditionName + ':' + (($condition | Sort-Object) -join '|')
                if ($seenConditions[$conditionKey]) { Fail "rules.$offerId contains duplicate condition $conditionKey" }
                $seenConditions[$conditionKey] = $true
            }
        }
    }
    Assert-StringArray $profile.constraints 'constraints'
}
function Validate-Mechanics([hashtable]$mechanics, [hashtable]$seenIds) {
    if ($mechanics.schemaVersion -ne 1) { Fail 'unsupported mechanics schemaVersion' }
    foreach ($field in @('id', 'weapon', 'aspect')) { Assert-String $mechanics[$field] "mechanics.$field" }
    if ($seenIds[$mechanics.id]) { Fail "duplicate mechanics template id $($mechanics.id)" }
    $seenIds[$mechanics.id] = $true
    if ($mechanics.weapon -ne 'WeaponDagger' -or $mechanics.aspect -notin @('DaggerBackstabAspect', 'DaggerTripleAspect')) { Fail 'invalid mechanics weapon/aspect' }
    foreach ($section in @('weights', 'statusMappings', 'knownNonStatusTraits', 'potentialStatusTraits',
        'statusCapabilityTraits', 'bloodDropEngine', 'aspectInteractions', 'hammerRoles', 'rules', 'verifiedIds', 'traitSemantics')) {
        if ($null -eq $mechanics[$section]) { Fail "missing mechanics section $section" }
    }
    if (($mechanics.weights -isnot [hashtable]) -or ($mechanics.statusMappings -isnot [hashtable]) -or
        ($mechanics.hammerRoles -isnot [hashtable]) -or ($mechanics.aspectInteractions -isnot [hashtable]) -or
        ($mechanics.bloodDropEngine -isnot [hashtable]) -or ($mechanics.verifiedIds -isnot [hashtable])) {
        Fail 'malformed mechanics object section'
    }
    if ($mechanics.genericCoreAspectCompatibility -isnot [bool]) {
        Fail 'genericCoreAspectCompatibility must be a boolean'
    }
    foreach ($value in $mechanics.weights.Values) {
        if ($value -isnot [int] -and $value -isnot [long] -and $value -isnot [double] -and $value -isnot [decimal]) { Fail 'invalid numeric weight' }
    }
    foreach ($entry in $mechanics.aspectInteractions.GetEnumerator()) {
        Assert-String $entry.Key 'aspectInteractions trait ID'
        if ($entry.Value -is [string]) {
            Assert-String $entry.Value "aspectInteractions.$($entry.Key)"
        } elseif ($entry.Value -is [object[]]) {
            Assert-StringArray $entry.Value "aspectInteractions.$($entry.Key)"
        } else {
            Fail "aspectInteractions.$($entry.Key) must be a string or string array"
        }
    }
    foreach ($entry in $mechanics.traitSemantics.GetEnumerator()) {
        Assert-String $entry.Key 'traitSemantics trait ID'
        if ($entry.Value -isnot [hashtable]) { Fail "traitSemantics.$($entry.Key) must be an object" }
        Assert-String $entry.Value.kind "traitSemantics.$($entry.Key).kind"
        Assert-String $entry.Value.reason "traitSemantics.$($entry.Key).reason"
        if ($entry.Value.kind -eq 'max_resource_support') {
            if ($entry.Value.reason -ne 'MAX_RESOURCE_SUPPORT') { Fail "unsupported trait semantic reason $($entry.Value.reason)" }
        } elseif ($entry.Value.kind -eq 'conditional_outgoing_damage') {
            if ($entry.Value.reason -ne 'HIGH_HEALTH_OFFENSE') { Fail "unsupported trait semantic reason $($entry.Value.reason)" }
            if ($entry.Value.healthThreshold -isnot [double] -and $entry.Value.healthThreshold -isnot [decimal] -and $entry.Value.healthThreshold -isnot [int]) { Fail 'healthThreshold must be numeric' }
            if ($entry.Value.healthThreshold -le 0 -or $entry.Value.healthThreshold -gt 1) { Fail 'healthThreshold must be in (0,1]' }
            if ($entry.Value.thresholdMultiplier -isnot [double] -and $entry.Value.thresholdMultiplier -isnot [decimal] -and $entry.Value.thresholdMultiplier -isnot [int]) { Fail 'thresholdMultiplier must be numeric' }
            if ($entry.Value.thresholdMultiplier -lt 1) { Fail 'thresholdMultiplier must be >= 1' }
            if ($entry.Value.excludesIgnoreAllModifiers -isnot [bool]) { Fail 'excludesIgnoreAllModifiers must be boolean' }
        } else { Fail "unsupported trait semantic kind $($entry.Value.kind)" }
    }
    foreach ($field in @('slots', 'profileMode', 'source', 'constraints')) {
        if ($mechanics.ContainsKey($field)) { Fail "profile-only field inside mechanics template: $field" }
    }
}
function Escape-Lua([string]$value) { $value.Replace('\\', '\\\\').Replace('"', '\\"') }
function To-IdSet([object[]]$values) {
    $set = @{}
    foreach ($value in $values) { $set[$value] = $true }
    return $set
}
function Compose-Profile([hashtable]$profile, [hashtable]$mechanics) {
    $composed = @{}
    foreach ($field in @('schemaVersion', 'id', 'weapon', 'aspect', 'profileMode', 'selectionKey', 'source', 'slots', 'constraints')) {
        $composed[$field] = $profile[$field]
    }
    if ($profile.ContainsKey('autoSignals')) { $composed.autoSignals = To-IdSet $profile.autoSignals }
    foreach ($field in @('weights', 'statusMappings', 'aspectInteractions', 'hammerRoles', 'verifiedIds', 'genericCoreAspectCompatibility', 'traitSemantics')) {
        $composed[$field] = $mechanics[$field]
    }
    $composed.rules = if ($profile.ContainsKey('rules')) { $profile.rules } else { $mechanics.rules }
    if ($profile.ContainsKey('weights')) {
        foreach ($key in $profile.weights.Keys) { $composed.weights[$key] = $profile.weights[$key] }
    }
    $composed.knownNonStatusTraits = To-IdSet $mechanics.knownNonStatusTraits
    $composed.potentialStatusTraits = To-IdSet $mechanics.potentialStatusTraits
    $composed.statusCapabilityTraits = @{}
    foreach ($family in $mechanics.statusCapabilityTraits.Keys) {
        $composed.statusCapabilityTraits[$family] = To-IdSet $mechanics.statusCapabilityTraits[$family]
    }
    $composed.bloodDropEngine = @{
        producers = To-IdSet $mechanics.bloodDropEngine.producers
        payoffs = To-IdSet $mechanics.bloodDropEngine.payoffs
    }
    return $composed
}
function ConvertTo-Lua([object]$value, [int]$indent = 0) {
    $pad = ' ' * $indent; $next = ' ' * ($indent + 4); $nl = [Environment]::NewLine
    if ($null -eq $value) { return 'nil' }
    if ($value -is [string]) { return '"' + (Escape-Lua $value) + '"' }
    if ($value -is [bool]) { return $value.ToString().ToLowerInvariant() }
    if ($value -is [int] -or $value -is [long] -or $value -is [double] -or $value -is [decimal]) { return [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $value) }
    if ($value -is [System.Collections.IDictionary]) {
        $parts = @()
        foreach ($key in @($value.Keys | Sort-Object)) {
            $renderedKey = if ($key -match '^[A-Za-z_][A-Za-z0-9_]*$') { $key } else { '["' + (Escape-Lua $key) + '"]' }
            $parts += $next + $renderedKey + ' = ' + (ConvertTo-Lua $value[$key] ($indent + 4)) + ','
        }
        if ($parts.Count -eq 0) { return '{}' }
        return '{' + $nl + ($parts -join $nl) + $nl + $pad + '}'
    }
    if ($value -is [System.Collections.IEnumerable]) {
        $parts = @(); foreach ($item in $value) { $parts += $next + (ConvertTo-Lua $item ($indent + 4)) + ',' }
        if ($parts.Count -eq 0) { return '{}' }
        return '{' + $nl + ($parts -join $nl) + $nl + $pad + '}'
    }
    Fail "unsupported JSON value type $($value.GetType().FullName)"
}
$mechanicsFiles = @(Get-ChildItem -LiteralPath $MechanicsDirectory -Filter '*.json' -File | Sort-Object Name)
if ($mechanicsFiles.Count -eq 0) { Fail "no mechanics templates in $MechanicsDirectory" }
$mechanicsIds = @{}; $mechanicsById = @{}
foreach ($file in $mechanicsFiles) {
    $mechanics = Read-Json $file.FullName; Validate-Mechanics $mechanics $mechanicsIds
    $mechanicsById[$mechanics.id] = $mechanics
}
$files = @(Get-ChildItem -LiteralPath $CanonicalDirectory -Filter '*.json' -File | Sort-Object Name)
if ($files.Count -eq 0) { Fail "no canonical profiles in $CanonicalDirectory" }
$seenIds = @{}; $seenOutputs = @{}; $seenSelectable = @{}; $profileByKey = @{}; $profiles = @()
foreach ($file in $files) {
    $profile = Read-Json $file.FullName; Validate-Profile $profile $seenIds
    $mechanics = $mechanicsById[$profile.mechanicsTemplate]
    if ($null -eq $mechanics) { Fail "unknown mechanicsTemplate $($profile.mechanicsTemplate)" }
    if ($profile.weapon -ne $mechanics.weapon -or $profile.aspect -ne $mechanics.aspect) { Fail "profile/template weapon or aspect mismatch for $($profile.id)" }
    $outputName = $profile.id + '.lua'
    if ($seenOutputs[$outputName]) { Fail "duplicate generated output name $outputName" }; $seenOutputs[$outputName] = $true
    if ($seenSelectable[$profile.selectionKey]) { Fail "duplicate selectable profile key $($profile.selectionKey)" }
    $seenSelectable[$profile.selectionKey] = $true; $profileByKey[$profile.selectionKey] = $profile
    $profiles += $profile
}
if ($ValidateOnly) { Write-Output "PASS: validated $($profiles.Count) canonical profiles"; exit 0 }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$nl = [Environment]::NewLine
foreach ($profile in $profiles) {
    $mechanics = $mechanicsById[$profile.mechanicsTemplate]
    $lua = '-- Generated runtime profile from canonical JSON only. Do not edit manually.' + $nl
    $lua += 'return ' + (ConvertTo-Lua (Compose-Profile $profile $mechanics)) + $nl
    [IO.File]::WriteAllText((Join-Path $OutputDirectory ($profile.id + '.lua')), $lua)
}
 $registry = '-- Generated static runtime registry from canonical JSON only.' + $nl + 'return {' + $nl
foreach ($key in @($profileByKey.Keys | Sort-Object)) {
    $profile = $profileByKey[$key]
    $registry += '    ' + $profile.selectionKey + ' = { selectionKey = "' + $profile.selectionKey + '", id = "' + $profile.id + '", profileMode = "' + $profile.profileMode + '", weapon = "' + $profile.weapon + '", aspect = "' + $profile.aspect + '", module = "data/builds/' + $profile.id + '.lua" },' + $nl
}
$registry += '}' + $nl
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'registry.lua'), $registry)
Write-Output "Generated $($profiles.Count) deterministic canonical runtime files in $OutputDirectory"
