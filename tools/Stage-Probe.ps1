$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).ProviderPath
$target = [IO.Path]::GetFullPath((Join-Path $repo 'dist\Local-HadesIIBoonAdvisor'))
$generated = Join-Path ([IO.Path]::GetTempPath()) ('boon-advisor-stage-generated-' + [Guid]::NewGuid())
# Generate before touching the previous staging directory. A failed canonical
# validation must never leave a partially rebuilt runtime staging tree.
& (Join-Path $repo 'tools\Generate-BoonAdvisorProfiles.ps1') -OutputDirectory $generated
# Refuse linked directories before recursive removal, including nested links.
$dist = Join-Path $repo 'dist'
if (-not $target.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Staging target is outside the repository.'
}
foreach ($path in @($dist, $target)) {
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path -Force
        if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Staging path must be a real directory: $path"
        }
    }
}
if (Test-Path -LiteralPath $target) {
    $resolvedTarget = (Resolve-Path -LiteralPath $target).ProviderPath
    if ($resolvedTarget -ne $target) { throw 'Unexpected resolved staging target.' }
    $links = Get-ChildItem -LiteralPath $target -Force -Recurse |
        Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }
    if ($links) { throw 'Staging contains links; refusing recursive removal.' }
    Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
}
New-Item -ItemType Directory -Path (Join-Path $target 'config') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $target 'data\builds') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'src\main.lua') -Destination $target
Copy-Item -LiteralPath (Join-Path $repo 'src\Logger.lua') -Destination $target
Copy-Item -LiteralPath (Join-Path $repo 'src\GameState.lua') -Destination $target
Copy-Item -LiteralPath (Join-Path $repo 'src\OfferSnapshot.lua') -Destination $target
Copy-Item -LiteralPath (Join-Path $repo 'src\ScoringEngine.lua') -Destination $target
Copy-Item -LiteralPath (Join-Path $repo 'src\UI.lua') -Destination $target
Copy-Item -LiteralPath (Join-Path $repo 'src\ProfileResolver.lua') -Destination $target
Copy-Item -LiteralPath (Join-Path $generated 'sister_blades_melinoe_intermediate.lua') -Destination (Join-Path $target 'data\builds')
Copy-Item -LiteralPath (Join-Path $generated 'sister_blades_melinoe_starter.lua') -Destination (Join-Path $target 'data\builds')
Copy-Item -LiteralPath (Join-Path $generated 'sister_blades_morrigan_meta.lua') -Destination (Join-Path $target 'data\builds')
Copy-Item -LiteralPath (Join-Path $generated 'registry.lua') -Destination (Join-Path $target 'data\builds')
Copy-Item -LiteralPath (Join-Path $repo 'config\settings.lua') -Destination (Join-Path $target 'config')
Copy-Item -LiteralPath (Join-Path $repo 'manifest.json') -Destination $target
Write-Output "Staged locally: $target"
Write-Output 'No game files or saves touched. See docs/RUNTIME_TEST.md before deployment.'
Remove-Item -LiteralPath $generated -Recurse -Force
