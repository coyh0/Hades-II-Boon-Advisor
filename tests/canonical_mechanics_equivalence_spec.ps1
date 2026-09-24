[CmdletBinding()]
param(
    [string]$PythonPath,
    [string]$LuaDllPath
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$json = Get-Content -LiteralPath (Join-Path $repo 'data\canonical\mechanics\sister_blades_melinoe.json') -Raw | ConvertFrom-Json
$runtimeSections = @('weights','statusMappings','knownNonStatusTraits','potentialStatusTraits',
    'statusCapabilityTraits','bloodDropEngine','aspectInteractions','hammerRoles','rules','verifiedIds',
    'genericCoreAspectCompatibility')
$setPaths = @('knownNonStatusTraits','potentialStatusTraits',
    'statusCapabilityTraits.Curse','bloodDropEngine.producers','bloodDropEngine.payoffs')
function Convert-Value([object]$value, [string]$path = '') {
    if ($null -eq $value) { return $null }
    if ($value -is [PSCustomObject]) {
        $table = @{}
        foreach ($property in $value.PSObject.Properties) {
            $child = if ($path) { $path + '.' + $property.Name } else { $property.Name }
            $table[$property.Name] = Convert-Value $property.Value $child
        }
        return $table
    }
    if ($value -is [System.Array]) {
        if ($setPaths -contains $path) {
            $table = @{}; foreach ($item in $value) { $table[[string]$item] = $true }; return $table
        }
        $items = @(); foreach ($item in $value) { $items += ,(Convert-Value $item $path) }; return ,$items
    }
    return $value
}
function Escape-Lua([string]$value) { $value.Replace('\','\\').Replace('"','\"') }
function To-Lua([object]$value, [int]$indent = 0) {
    $nl = [Environment]::NewLine
    if ($null -eq $value) { return 'nil' }
    if ($value -is [string]) { return '"' + (Escape-Lua $value) + '"' }
    if ($value -is [bool]) { return $value.ToString().ToLowerInvariant() }
    if ($value -is [int] -or $value -is [long] -or $value -is [double]) { return [string]$value }
    if ($value -is [System.Collections.IDictionary]) {
        $rows = @(); foreach ($key in @($value.Keys | Sort-Object)) {
            $rows += ('    ' * ($indent + 1)) + $key + ' = ' + (To-Lua $value[$key] ($indent + 1)) + ','
        }
        if ($rows.Count -eq 0) { return '{}' }; return '{' + $nl + ($rows -join $nl) + $nl + ('    ' * $indent) + '}'
    }
    if ($value -is [System.Collections.IEnumerable]) {
        $rows = @(); foreach ($item in $value) { $rows += ('    ' * ($indent + 1)) + (To-Lua $item ($indent + 1)) + ',' }
        if ($rows.Count -eq 0) { return '{}' }; return '{' + $nl + ($rows -join $nl) + $nl + ('    ' * $indent) + '}'
    }
    throw "Unsupported value type: $($value.GetType().FullName)"
}
$mechanics = @{}
foreach ($section in $runtimeSections) { $mechanics[$section] = Convert-Value $json.$section $section }
$literal = To-Lua $mechanics
$lua = @"
local canonical = $literal
local sections = { "weights", "statusMappings", "knownNonStatusTraits", "potentialStatusTraits", "statusCapabilityTraits", "bloodDropEngine", "aspectInteractions", "hammerRoles", "rules", "verifiedIds" }
local function fail(path, kind, expected, actual) error("MECHANICS_MISMATCH path=" .. path .. " type=" .. kind .. " canonical=" .. tostring(expected) .. " runtime=" .. tostring(actual), 0) end
local function compare(expected, actual, path)
    if type(expected) ~= type(actual) then fail(path, "TYPE", expected, actual) end
    if type(expected) ~= "table" then if expected ~= actual then fail(path, "VALUE", expected, actual) end return end
    for key, value in pairs(expected) do if actual[key] == nil then fail(path .. "." .. tostring(key), "MISSING", value, nil) end compare(value, actual[key], path .. "." .. tostring(key)) end
    for key, value in pairs(actual) do if expected[key] == nil then fail(path .. "." .. tostring(key), "EXTRA", nil, value) end end
end
local intermediate = assert(loadfile("data/builds/sister_blades_melinoe_intermediate.lua"))()
for _, section in ipairs(sections) do compare(canonical[section], intermediate[section], section) end
print("PASS: strict recursive canonical/runtime Intermediate mechanics equivalence")
"@
$temp = Join-Path ([IO.Path]::GetTempPath()) ('mechanics-equivalence-' + [Guid]::NewGuid() + '.lua')
[IO.File]::WriteAllText($temp, $lua)
function Resolve-RequiredFile([string]$ExplicitPath, [string]$EnvironmentName, [string]$Description) {
    $candidate = $ExplicitPath
    if ([string]::IsNullOrWhiteSpace($candidate)) { $candidate = [Environment]::GetEnvironmentVariable($EnvironmentName) }
    if ([string]::IsNullOrWhiteSpace($candidate) -and $Description -eq 'PythonPath') {
        $pythonCommand = Get-Command python.exe -ErrorAction SilentlyContinue
        if ($null -ne $pythonCommand) { $candidate = $pythonCommand.Source }
    }
    if ([string]::IsNullOrWhiteSpace($candidate) -and $Description -eq 'LuaDllPath') {
        $gameRoot = [Environment]::GetEnvironmentVariable('HADES2_GAME_ROOT')
        if (-not [string]::IsNullOrWhiteSpace($gameRoot)) { $candidate = Join-Path $gameRoot 'Ship\lua52.dll' }
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) { throw "$Description is required. Pass -$Description or set $EnvironmentName." }
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($candidate)
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "$Description was not found: $resolved" }
    return $resolved
}

$python = Resolve-RequiredFile $PythonPath 'BOON_ADVISOR_PYTHON' 'PythonPath'
$dll = Resolve-RequiredFile $LuaDllPath 'BOON_ADVISOR_LUA_DLL' 'LuaDllPath'
& $python (Join-Path $repo 'tests\run_lua52.py') $dll $temp
if ($LASTEXITCODE -ne 0) { throw 'Strict mechanics equivalence failed.' }
Write-Output 'PASS: strict field-by-field mechanics equivalence'
