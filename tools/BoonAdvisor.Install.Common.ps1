$ErrorActionPreference = 'Stop'

$script:BoonAdvisorPluginDirectory = 'Local-HadesIIBoonAdvisor'
$script:BoonAdvisorExpectedFiles = @(
    'GameState.lua', 'Logger.lua', 'OfferSnapshot.lua', 'ScoringEngine.lua', 'UI.lua', 'main.lua', 'manifest.json',
    'config\settings.lua', 'data\builds\registry.lua', 'data\builds\sister_blades_melinoe_intermediate.lua',
    'data\builds\sister_blades_melinoe_starter.lua', 'data\builds\sister_blades_morrigan_meta.lua'
) | Sort-Object
$script:BoonAdvisorExpectedDirectories = @('config', 'data', 'data\builds') | Sort-Object
$script:BoonAdvisorLoaderHash = '0EC38238EEBB003740ED311FCFA4ECDFBA259F3675A9AAB446104367E4AEA94D'

function Get-NormalizedPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'A required path was empty.' }
    # Resolve through PowerShell's FileSystem provider. .NET's current
    # directory is not required to match PowerShell's current location.
    $providerPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    [IO.Path]::GetFullPath($providerPath)
}

function Test-ChildPath([string]$Child, [string]$Parent) {
    $childFull = Get-NormalizedPath $Child
    $parentFull = Get-NormalizedPath $Parent
    $prefix = $parentFull.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $childFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-NoReparsePoint([string]$Path) {
    $full = Get-NormalizedPath $Path
    $cursor = $full
    while ($true) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point is not permitted: $cursor" }
        }
        $parentInfo = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parentInfo -or $parentInfo.FullName -eq $cursor) { break }
        $cursor = $parentInfo.FullName
    }
}

function Assert-NoReparsePointTree([string]$Path) {
    Assert-NoReparsePoint $Path
    if (-not (Test-RealDirectory $Path)) { return }
    $links = @(Get-ChildItem -LiteralPath $Path -Force -Recurse | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint })
    if ($links.Count -ne 0) { throw "Reparse point is not permitted inside: $Path" }
}

function Test-RealDirectory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    (Get-Item -LiteralPath $Path -Force).PSIsContainer
}

function Test-RealFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    -not (Get-Item -LiteralPath $Path -Force).PSIsContainer
}

function Get-BoonAdvisorPaths([string]$GameRoot) {
    $root = Get-NormalizedPath $GameRoot
    if (-not (Test-RealDirectory $root)) { throw "GameRoot does not exist: $root" }
    Assert-NoReparsePoint $root
    $ship = Join-Path $root 'Ship'
    $exe = Join-Path $ship 'Hades2.exe'
    $plugins = Join-Path $ship 'ReturnOfModding\plugins'
    foreach ($path in @($ship, $exe, $plugins)) {
        if (-not (Test-ChildPath $path $root)) { throw "Game path escaped GameRoot: $path" }
    }
    if (-not (Test-RealFile $exe)) { throw "Hades2.exe does not exist: $exe" }
    if (-not (Test-RealDirectory $plugins)) { throw "ReturnOfModding plugins directory does not exist: $plugins" }
    Assert-NoReparsePoint $ship
    Assert-NoReparsePoint $plugins
    $target = Join-Path $plugins $script:BoonAdvisorPluginDirectory
    if (-not (Test-ChildPath $target $plugins)) { throw 'Boon Advisor destination escaped plugins directory.' }
    if (Test-Path -LiteralPath $target) { Assert-NoReparsePoint $target }
    [pscustomobject]@{ Root = $root; Ship = $ship; Exe = $exe; Plugins = $plugins; Target = $target }
}

function Get-Manifest([string]$Path) {
    try { $manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json } catch { throw "Invalid manifest JSON: $Path" }
    if ($null -eq $manifest) { throw "Invalid manifest JSON: $Path" }
    $manifest
}

function Parse-BoonAdvisorDependencyToken([string]$Token) {
    if ($Token -notmatch '^(?<owner>[^-]+)-(?<package>.+)-(?<version>[0-9]+(?:\.[0-9]+)+)$') {
        throw "Unsupported dependency token: $Token"
    }
    [pscustomobject]@{
        Token = $Token
        Owner = $Matches.owner
        Package = $Matches.package
        PackageIdentity = ($Matches.owner + '-' + $Matches.package)
        Version = $Matches.version
    }
}

function Test-BoonAdvisorPackage([string]$PackagePath, [switch]$AllowCandidateName) {
    $root = Get-NormalizedPath $PackagePath
    if (-not (Test-RealDirectory $root)) { throw "PackagePath is not a directory: $root" }
    if (-not $AllowCandidateName -and (Split-Path -Leaf $root) -ne $script:BoonAdvisorPluginDirectory) { throw "Package directory must be named $script:BoonAdvisorPluginDirectory" }
    Assert-NoReparsePoint $root
    $items = @(Get-ChildItem -LiteralPath $root -Force -Recurse)
    if (@($items | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count -ne 0) { throw 'Package contains a reparse point.' }
    $files = @(Get-ChildItem -LiteralPath $root -Force -Recurse -File | ForEach-Object { $_.FullName.Substring($root.Length + 1) } | Sort-Object)
    $dirs = @(Get-ChildItem -LiteralPath $root -Force -Recurse -Directory | ForEach-Object { $_.FullName.Substring($root.Length + 1) } | Sort-Object)
    if (Compare-Object $script:BoonAdvisorExpectedFiles $files) { throw 'Package runtime file inventory is not exact.' }
    if (Compare-Object $script:BoonAdvisorExpectedDirectories $dirs) { throw 'Package runtime directory inventory is not exact.' }
    $manifest = Get-Manifest (Join-Path $root 'manifest.json')
    if ($manifest.name -ne 'HadesIIBoonAdvisor') { throw 'Package manifest name must be HadesIIBoonAdvisor.' }
    if ([string]::IsNullOrWhiteSpace([string]$manifest.version_number)) { throw 'Package manifest version_number is required.' }
    [pscustomobject]@{ Root = $root; Manifest = $manifest; Files = $files }
}

function Test-BoonAdvisorDependencies($Paths, $Manifest) {
    $loader = Join-Path $Paths.Ship 'd3d12.dll'
    if (-not (Test-RealFile $loader)) { throw "Hell2Modding loader is missing: $loader" }
    Assert-NoReparsePoint $loader
    $loaderHash = (Get-FileHash -LiteralPath $loader -Algorithm SHA256).Hash
    if ($loaderHash -eq $script:BoonAdvisorLoaderHash) { Write-Output 'Hell2Modding loader: known validated binary hash.' }
    else { Write-Warning "Hell2Modding loader is present but its binary hash is unverified: $loaderHash" }
    foreach ($token in @($Manifest.dependencies)) {
        if ($token -eq 'Hell2Modding-Hell2Modding-1.0.112') { continue }
        $dependency = Parse-BoonAdvisorDependencyToken $token
        $expectedName = $dependency.Package; $expectedVersion = $dependency.Version
        $dependencyRoot = Join-Path $Paths.Plugins $dependency.PackageIdentity
        if (-not (Test-ChildPath $dependencyRoot $Paths.Plugins) -or -not (Test-RealDirectory $dependencyRoot)) { throw "Required dependency is missing: $token" }
        Assert-NoReparsePoint $dependencyRoot
        $dependencyManifestPath = Join-Path $dependencyRoot 'manifest.json'
        if (-not (Test-RealFile $dependencyManifestPath)) { throw "Dependency manifest is missing: $token" }
        $dependencyManifest = Get-Manifest $dependencyManifestPath
        if ($dependencyManifest.name -ne $expectedName -or [string]$dependencyManifest.version_number -ne $expectedVersion) {
            throw "Dependency identity/version mismatch for $token (found name=$($dependencyManifest.name), version=$($dependencyManifest.version_number))."
        }
    }
}

function Test-Hades2NotRunning([string]$ProcessProbe) {
    if (-not [string]::IsNullOrWhiteSpace($ProcessProbe)) {
        & $ProcessProbe
        if ($LASTEXITCODE -eq 0) { return }
        if ($LASTEXITCODE -eq 1) { throw 'Hades2.exe is running.' }
        throw "Process probe failed with exit code $LASTEXITCODE."
    }
    if ($null -ne (Get-Process -Name 'Hades2' -ErrorAction SilentlyContinue)) { throw 'Hades2.exe is running.' }
}

function Invoke-BoonAdvisorCompatibilityGate([string]$CompatibilityScript, $Paths) {
    if (-not (Test-RealFile $CompatibilityScript)) { throw "Compatibility gate does not exist: $CompatibilityScript" }
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $CompatibilityScript, '-GameRoot', $Paths.Root, '-Mode', 'Runtime')
    & powershell.exe @arguments
    if ($LASTEXITCODE -eq 0) { return }
    if ($LASTEXITCODE -eq 2) { throw 'Patch compatibility requires a manual runtime test; installation refused.' }
    throw "Patch compatibility failed (exit code $LASTEXITCODE); installation refused."
}

function Copy-BoonAdvisorPackage([string]$PackageRoot, [string]$Candidate) {
    New-Item -ItemType Directory -Path $Candidate -Force | Out-Null
    foreach ($relative in $script:BoonAdvisorExpectedFiles) {
        $destination = Join-Path $Candidate $relative
        $parent = [IO.Directory]::GetParent($destination).FullName
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -LiteralPath (Join-Path $PackageRoot $relative) -Destination $destination -Force
    }
}

function Invoke-BoonAdvisorTestFailure([string]$ConfiguredPoint, [string]$Point) {
    # Test-only failure seam. Production callers pass no configured point.
    if (@($ConfiguredPoint -split ',' | ForEach-Object { $_.Trim() }) -contains $Point) { throw "Test-only injected failure: $Point" }
}

function Test-BoonAdvisorBytesEqual([byte[]]$Left, [byte[]]$Right) {
    if ($null -eq $Left -or $null -eq $Right -or $Left.Length -ne $Right.Length) { return $false }
    for ($index = 0; $index -lt $Left.Length; $index++) { if ($Left[$index] -ne $Right[$index]) { return $false } }
    $true
}

function Get-BoonAdvisorTreeSnapshot([string]$Root) {
    $files = @(Get-ChildItem -LiteralPath $Root -Force -Recurse -File | ForEach-Object {
        [pscustomobject]@{ Path = $_.FullName.Substring($Root.Length + 1); Hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    } | Sort-Object Path)
    $directories = @(Get-ChildItem -LiteralPath $Root -Force -Recurse -Directory | ForEach-Object {
        $_.FullName.Substring($Root.Length + 1)
    } | Sort-Object)
    [pscustomobject]@{ Files = $files; Directories = $directories }
}

function Test-BoonAdvisorTreeSnapshot([string]$Root, $Snapshot) {
    $actual = Get-BoonAdvisorTreeSnapshot $Root
    if (@($actual.Files).Count -ne @($Snapshot.Files).Count -or @($actual.Directories).Count -ne @($Snapshot.Directories).Count) { return $false }
    for ($index = 0; $index -lt @($Snapshot.Files).Count; $index++) {
        if ($actual.Files[$index].Path -ne $Snapshot.Files[$index].Path -or $actual.Files[$index].Hash -ne $Snapshot.Files[$index].Hash) { return $false }
    }
    for ($index = 0; $index -lt @($Snapshot.Directories).Count; $index++) {
        if ($actual.Directories[$index] -ne $Snapshot.Directories[$index]) { return $false }
    }
    $true
}
