$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('hades2-staging-test-' + [Guid]::NewGuid())
foreach ($dir in @('tools', 'src', 'config', 'data\builds', 'data\canonical\profiles', 'data\canonical\mechanics', 'data\canonical\catalog', 'dist\Local-HadesIIBoonAdvisor\old', 'dist\OtherPlugin')) {
    New-Item -ItemType Directory -Path (Join-Path $fixture $dir) -Force | Out-Null
}
foreach ($file in @('tools\Stage-Probe.ps1', 'tools\Generate-BoonAdvisorProfiles.ps1', 'src\main.lua', 'src\Logger.lua', 'src\Localization.lua', 'src\GameState.lua', 'src\OfferSnapshot.lua', 'src\ScoringEngine.lua', 'src\UI.lua', 'src\ProfileResolver.lua', 'data\builds\registry.lua', 'data\builds\sister_blades_melinoe_intermediate.lua', 'data\builds\sister_blades_melinoe_starter.lua', 'data\builds\sister_blades_morrigan_meta.lua', 'data\canonical\profiles\sister_blades_melinoe_intermediate.json', 'data\canonical\profiles\sister_blades_melinoe_starter.json', 'data\canonical\profiles\sister_blades_morrigan_meta.json', 'data\canonical\mechanics\sister_blades_melinoe.json', 'data\canonical\mechanics\sister_blades_morrigan.json', 'config\settings.lua', 'manifest.json')) {
    Copy-Item -LiteralPath (Join-Path $repo $file) -Destination (Join-Path $fixture $file)
}
Copy-Item -LiteralPath (Join-Path $repo 'data\canonical\catalog\weapons_aspects.json') -Destination (Join-Path $fixture 'data\canonical\catalog\weapons_aspects.json')
$staged = Join-Path $fixture 'dist\Local-HadesIIBoonAdvisor'
$generatedReference = Join-Path $fixture 'generated-reference'
& (Join-Path $fixture 'tools\Generate-BoonAdvisorProfiles.ps1') -OutputDirectory $generatedReference | Out-Null
Set-Content -LiteralPath (Join-Path $staged 'old\removed.lua') -Value 'stale'
$sibling = Join-Path $fixture 'dist\OtherPlugin\keep.txt'
Set-Content -LiteralPath $sibling -Value 'preserve'
$siblingHash = (Get-FileHash -LiteralPath $sibling).Hash
$expected = @('GameState.lua', 'Logger.lua', 'Localization.lua', 'OfferSnapshot.lua', 'ProfileResolver.lua', 'ScoringEngine.lua', 'UI.lua', 'config\settings.lua', 'data\builds\registry.lua', 'data\builds\sister_blades_melinoe_intermediate.lua', 'data\builds\sister_blades_melinoe_starter.lua', 'data\builds\sister_blades_morrigan_meta.lua', 'main.lua', 'manifest.json') | Sort-Object
for ($run = 1; $run -le 2; $run++) {
    & (Join-Path $fixture 'tools\Stage-Probe.ps1') | Out-Null
    $actual = @(Get-ChildItem -LiteralPath $staged -Recurse -File |
        ForEach-Object { $_.FullName.Substring($staged.Length + 1) } | Sort-Object)
    if (Compare-Object $expected $actual) { throw 'Staging contains missing or stale files.' }
    foreach ($pair in @(@('src\main.lua', 'main.lua'), @('src\Logger.lua', 'Logger.lua'), @('src\Localization.lua', 'Localization.lua'), @('src\GameState.lua', 'GameState.lua'),
        @('src\OfferSnapshot.lua', 'OfferSnapshot.lua'), @('src\ScoringEngine.lua', 'ScoringEngine.lua'),
        @('src\UI.lua', 'UI.lua'), @('src\ProfileResolver.lua', 'ProfileResolver.lua'),
        @('data\builds\registry.lua', 'data\builds\registry.lua'),
        @('data\builds\sister_blades_melinoe_intermediate.lua', 'data\builds\sister_blades_melinoe_intermediate.lua'),
        @('data\builds\sister_blades_melinoe_starter.lua', 'data\builds\sister_blades_melinoe_starter.lua'),
        @('data\builds\sister_blades_morrigan_meta.lua', 'data\builds\sister_blades_morrigan_meta.lua'),
        @('config\settings.lua', 'config\settings.lua'), @('manifest.json', 'manifest.json'))) {
        $sourcePath = Join-Path $fixture $pair[0]
        if ($pair[1].StartsWith('data\builds\', [StringComparison]::Ordinal)) {
            $sourcePath = Join-Path $generatedReference ($pair[1].Substring('data\builds\'.Length))
        }
        if ((Get-FileHash -LiteralPath $sourcePath).Hash -ne
            (Get-FileHash -LiteralPath (Join-Path $staged $pair[1])).Hash) {
            throw 'Staged file differs from its source.'
        }
    }
    if ((Get-FileHash -LiteralPath $sibling).Hash -ne $siblingHash) { throw 'Sibling changed.' }
    if ($run -eq 1) {
        Set-Content -LiteralPath (Join-Path $staged 'renamed-old.lua') -Value 'stale again'
    }
}
Write-Output 'PASS: staging rebuilt twice; stale files removed; exactly 14 expected files; hashes match; sibling dist directory preserved'
