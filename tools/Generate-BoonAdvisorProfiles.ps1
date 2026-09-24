[CmdletBinding()]
param(
    [string]$CanonicalDirectory,
    [string]$MechanicsDirectory,
    [string]$CatalogPath,
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
if ([string]::IsNullOrWhiteSpace($CatalogPath)) {
    $CatalogPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'data\canonical\catalog\weapons_aspects.json'
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
function Test-CatalogWeaponAspect([hashtable]$catalog, [string]$weapon, [string]$aspect) {
    $aspects = $catalog[$weapon]
    if ($null -eq $aspects) { Fail "unknown catalog weapon $weapon" }
    if (-not $aspects[$aspect]) { Fail "unknown catalog aspect $aspect for weapon $weapon" }
}
function Read-WeaponAspectCatalog([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "weapon/aspect catalog was not found: $path" }
    $catalog = Read-Json $path
    if ($catalog.schemaVersion -ne 1) { Fail 'unsupported weapon/aspect catalog schemaVersion' }
    if ($catalog.weapons -isnot [object[]] -or $catalog.weapons.Count -eq 0) { Fail 'weapon/aspect catalog weapons must be a non-empty array' }
    $byWeapon = @{}
    foreach ($weaponEntry in $catalog.weapons) {
        if ($weaponEntry -isnot [hashtable]) { Fail 'weapon/aspect catalog weapon entry must be an object' }
        Assert-String $weaponEntry.runtimeWeaponId 'weapon/aspect catalog runtimeWeaponId'
        if ($byWeapon[$weaponEntry.runtimeWeaponId]) { Fail "duplicate catalog weapon ID $($weaponEntry.runtimeWeaponId)" }
        if ($weaponEntry.ContainsKey('label')) { Assert-String $weaponEntry.label 'weapon/aspect catalog weapon label' }
        if ($weaponEntry.aspects -isnot [object[]] -or $weaponEntry.aspects.Count -eq 0) { Fail "catalog aspects must be a non-empty array for weapon $($weaponEntry.runtimeWeaponId)" }
        $aspects = @{}
        foreach ($aspectEntry in $weaponEntry.aspects) {
            if ($aspectEntry -isnot [hashtable]) { Fail 'weapon/aspect catalog aspect entry must be an object' }
            Assert-String $aspectEntry.runtimeAspectId 'weapon/aspect catalog runtimeAspectId'
            if ($aspects[$aspectEntry.runtimeAspectId]) { Fail "duplicate catalog aspect ID $($aspectEntry.runtimeAspectId) for weapon $($weaponEntry.runtimeWeaponId)" }
            if ($aspectEntry.ContainsKey('label')) { Assert-String $aspectEntry.label 'weapon/aspect catalog aspect label' }
            $aspects[$aspectEntry.runtimeAspectId] = $true
        }
        $byWeapon[$weaponEntry.runtimeWeaponId] = $aspects
    }
    return $byWeapon
}
function Validate-Profile([hashtable]$profile, [hashtable]$seenIds, [hashtable]$catalog) {
    if ($profile.schemaVersion -ne 1) { Fail 'unsupported schemaVersion' }
    foreach ($field in @('id', 'weapon', 'aspect', 'profileMode', 'selectionKey', 'mechanicsTemplate')) { Assert-String $profile[$field] $field }
    if ($profile.id -cnotmatch '^[a-z][a-z0-9_]*$') { Fail "invalid profile id $($profile.id)" }
    if ($profile.id -ceq 'registry') { Fail 'profile id registry is reserved for the generated registry module' }
    if ($profile.selectionKey -cnotmatch '^[a-z][a-z0-9_]*$') { Fail "invalid selectionKey $($profile.selectionKey)" }
    if ($profile.selectionKey -ceq 'auto') { Fail 'selectionKey auto is reserved for automatic profile selection' }
    if ($seenIds[$profile.id]) { Fail "duplicate profile id $($profile.id)" }; $seenIds[$profile.id] = $true
    Test-CatalogWeaponAspect $catalog $profile.weapon $profile.aspect
    if ($profile.source -isnot [hashtable]) { Fail 'source must be an object' }
    Assert-String $profile.source.type 'source.type'; Assert-String $profile.source.profile 'source.profile'
    if ($profile.slots -isnot [hashtable]) { Fail 'slots must be an object' }
    if ($profile.ContainsKey('autoSignals')) { Assert-StringArray $profile.autoSignals 'autoSignals' }
    if ($profile.ContainsKey('hammerPlan')) {
        if ($profile.hammerPlan -isnot [object[]]) { Fail 'hammerPlan must be an array' }
        $seenHammerIds = @{}
        foreach ($entry in $profile.hammerPlan) {
            if ($entry -isnot [hashtable]) { Fail 'hammerPlan entry must be an object' }
            Assert-String $entry.traitId 'hammerPlan.traitId'
            if ($seenHammerIds[$entry.traitId]) { Fail "hammerPlan contains duplicate trait ID $($entry.traitId)" }
            $seenHammerIds[$entry.traitId] = $true
            $priorityIsNumber = $entry.priority -is [int] -or $entry.priority -is [long] -or
                $entry.priority -is [double] -or $entry.priority -is [decimal]
            if (-not $priorityIsNumber -or $entry.priority -le 0 -or $entry.priority % 1 -ne 0) {
                Fail 'hammerPlan.priority must be a positive integer'
            }
            if ($entry.classification -cnotin @('priority', 'alternative')) { Fail "unsupported hammerPlan classification $($entry.classification)" }
            if ($entry.ContainsKey('condition')) { Assert-String $entry.condition 'hammerPlan.condition' }
        }
    }
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
        if ($slot.ContainsKey('branches')) {
            if ($slotName -cne 'Attack' -or $slot.branches -isnot [object[]] -or $slot.branches.Count -eq 0) {
                Fail 'branches must be a non-empty Attack array'
            }
            foreach ($branch in $slot.branches) {
                if ($branch -isnot [hashtable]) { Fail 'Attack.branches entry must be an object' }
                foreach ($key in $branch.Keys) {
                    if ($key -cnotin @('traitId', 'classification', 'priority', 'condition')) {
                        Fail "unknown Attack branch field $key"
                    }
                }
                Assert-String $branch.traitId 'Attack.branches.traitId'
                if ($all[$branch.traitId]) { Fail "contradictory or duplicate Attack branch $($branch.traitId)" }
                $all[$branch.traitId] = $true
                if ($branch.classification -cnotin @('alternative', 'conditional')) { Fail 'unknown Attack branch classification' }
                $number = $branch.priority -is [int] -or $branch.priority -is [long] -or $branch.priority -is [double] -or $branch.priority -is [decimal]
                if (-not $number -or $branch.priority -le 0 -or $branch.priority % 1 -ne 0) { Fail 'Attack branch priority must be a positive integer' }
                if ($branch.ContainsKey('condition')) {
                    $condition = $branch.condition
                    if ($branch.classification -cne 'conditional' -or $condition -isnot [hashtable] -or
                        $condition.Count -ne 2 -or $condition.state -cne 'unresolved' -or $condition.code -cne 'WOUNDS_ACCESS') {
                        Fail 'unknown Attack branch condition'
                    }
                } elseif ($branch.classification -ceq 'conditional') { Fail 'conditional Attack branch requires a condition' }
            }
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
function Validate-Mechanics([hashtable]$mechanics, [hashtable]$seenIds, [hashtable]$catalog) {
    if ($mechanics.schemaVersion -ne 1) { Fail 'unsupported mechanics schemaVersion' }
    foreach ($field in @('id', 'weapon', 'aspect')) { Assert-String $mechanics[$field] "mechanics.$field" }
    if ($seenIds[$mechanics.id]) { Fail "duplicate mechanics template id $($mechanics.id)" }
    $seenIds[$mechanics.id] = $true
    Test-CatalogWeaponAspect $catalog $mechanics.weapon $mechanics.aspect
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
            if ($entry.Value.healthThreshold -isnot [double] -and $entry.Value.healthThreshold -isnot [decimal] -and $entry.Value.healthThreshold -isnot [int] -and $entry.Value.healthThreshold -isnot [long]) { Fail 'healthThreshold must be numeric' }
            if ($entry.Value.healthThreshold -le 0 -or $entry.Value.healthThreshold -gt 1) { Fail 'healthThreshold must be in (0,1]' }
            if ($entry.Value.thresholdMultiplier -isnot [double] -and $entry.Value.thresholdMultiplier -isnot [decimal] -and $entry.Value.thresholdMultiplier -isnot [int] -and $entry.Value.thresholdMultiplier -isnot [long]) { Fail 'thresholdMultiplier must be numeric' }
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
    if ($profile.ContainsKey('hammerPlan')) { $composed.hammerPlan = ConvertTo-HashtableRecursive $profile.hammerPlan }
    foreach ($field in @('statusMappings', 'aspectInteractions', 'hammerRoles', 'verifiedIds', 'genericCoreAspectCompatibility', 'traitSemantics')) {
        $composed[$field] = $mechanics[$field]
    }
    # Profile overrides must never mutate the mechanics template reused by another profile.
    $composed.weights = ConvertTo-HashtableRecursive $mechanics.weights
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
    $pad = ' ' * $indent; $next = ' ' * ($indent + 4); $nl = "`n"
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
$catalog = Read-WeaponAspectCatalog $CatalogPath
$mechanicsFiles = @(Get-ChildItem -LiteralPath $MechanicsDirectory -Filter '*.json' -File | Sort-Object Name)
if ($mechanicsFiles.Count -eq 0) { Fail "no mechanics templates in $MechanicsDirectory" }
$mechanicsIds = @{}; $mechanicsById = @{}
foreach ($file in $mechanicsFiles) {
    $mechanics = Read-Json $file.FullName; Validate-Mechanics $mechanics $mechanicsIds $catalog
    $mechanicsById[$mechanics.id] = $mechanics
}
$files = @(Get-ChildItem -LiteralPath $CanonicalDirectory -Filter '*.json' -File | Sort-Object Name)
if ($files.Count -eq 0) { Fail "no canonical profiles in $CanonicalDirectory" }
$seenIds = @{}; $seenOutputs = @{}; $seenSelectable = @{}; $profileByKey = @{}; $profiles = @()
foreach ($file in $files) {
    $profile = Read-Json $file.FullName; Validate-Profile $profile $seenIds $catalog
    $mechanics = $mechanicsById[$profile.mechanicsTemplate]
    if ($null -eq $mechanics) { Fail "unknown mechanicsTemplate $($profile.mechanicsTemplate)" }
    if ($profile.weapon -ne $mechanics.weapon -or $profile.aspect -ne $mechanics.aspect) { Fail "profile/template weapon or aspect mismatch for $($profile.id)" }
    $attack = $profile.slots.Attack
    if ($attack -is [hashtable] -and $attack.ContainsKey('branches')) {
        foreach ($branch in $attack.branches) {
            if ($branch.traitId -cnotin $mechanics.verifiedIds.coreAttack) {
                Fail "unverified Attack branch trait ID $($branch.traitId)"
            }
        }
    }
    $outputName = $profile.id + '.lua'
    if ($seenOutputs[$outputName]) { Fail "duplicate generated output name $outputName" }; $seenOutputs[$outputName] = $true
    if ($seenSelectable[$profile.selectionKey]) { Fail "duplicate selectable profile key $($profile.selectionKey)" }
    $seenSelectable[$profile.selectionKey] = $true; $profileByKey[$profile.selectionKey] = $profile
    $profiles += $profile
}
if ($ValidateOnly) { Write-Output "PASS: validated $($profiles.Count) canonical profiles"; exit 0 }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$nl = "`n"
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
