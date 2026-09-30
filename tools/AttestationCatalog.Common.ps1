# Shared, fail-closed lookup for the attestation catalog consumers.
# Formal Draft 2020-12 validation remains in validate_runtime_attestations.py;
# consumers additionally enforce the exact records they rely on at use time.
function Read-AttestationCatalog([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Attestation catalog was not found: $Path"
    }
    $jsonText = [IO.File]::ReadAllText($Path, (New-Object System.Text.UTF8Encoding($false, $true)))
    try { $catalog = $jsonText | ConvertFrom-Json }
    catch { throw "Attestation catalog is not valid JSON: $Path" }
    if ($catalog.schemaVersion -ne 1 -or $catalog.nativeItems -isnot [array] -or
        $catalog.offerSources -isnot [array] -or $catalog.sourceBoonPairs -isnot [array] -or
        $catalog.externalNameMappings -isnot [array] -or $catalog.evidence -isnot [array]) {
        throw 'Attestation catalog has an unsupported or incomplete schemaVersion 1 structure.'
    }

    $items = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $sources = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $pairs = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $evidenceById = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $claimKinds = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    $claimEvidence = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $evidenceClaims = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)

    foreach ($record in $catalog.evidence) {
        if ($record.evidenceId -isnot [string] -or [string]::IsNullOrWhiteSpace($record.evidenceId) -or
            $evidenceById.ContainsKey($record.evidenceId) -or $record.attests -isnot [array]) {
            throw 'Attestation catalog contains a missing/duplicate evidence ID or malformed attests list.'
        }
        $evidenceById.Add($record.evidenceId, $record)
        $seenClaims = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($claimId in $record.attests) {
            if ($claimId -isnot [string] -or -not $seenClaims.Add($claimId)) {
                throw "Evidence $($record.evidenceId) contains a malformed or duplicate claim reference."
            }
        }
        $evidenceClaims.Add($record.evidenceId, $seenClaims)
    }

    function Add-CatalogClaim([object]$Claim, [string]$Kind) {
        if ($Claim.claimId -isnot [string] -or [string]::IsNullOrWhiteSpace($Claim.claimId) -or
            $claimKinds.ContainsKey($Claim.claimId) -or $Claim.evidenceIds -isnot [array]) {
            throw 'Attestation catalog contains a missing/duplicate claim ID or malformed evidenceIds list.'
        }
        if ($Claim.status -cnotin @('validated', 'needs_revalidation', 'invalid', 'deprecated')) {
            throw "Attestation claim $($Claim.claimId) has an unsupported status."
        }
        $claimKinds.Add($Claim.claimId, $Kind)
        $claimEvidence.Add($Claim.claimId, $Claim.evidenceIds)
    }

    foreach ($item in $catalog.nativeItems) {
        if ($item.runtimeItemId -isnot [string] -or [string]::IsNullOrWhiteSpace($item.runtimeItemId) -or
            $items.ContainsKey($item.runtimeItemId) -or $item.claims -isnot [array]) {
            throw 'Attestation catalog contains a missing/duplicate native runtimeItemId or malformed claims list.'
        }
        $items.Add($item.runtimeItemId, $item)
        foreach ($claim in $item.claims) {
            $suffix = switch ($claim.predicate) { 'nativeType' { 'type' } 'nativeSlot' { 'slot' } default { throw "Unsupported native predicate on $($item.runtimeItemId)." } }
            if ($claim.claimId -cne "native-item-$($item.runtimeItemId)-$suffix") { throw "Native claim ID does not match runtime ID and predicate: $($claim.claimId)" }
            Add-CatalogClaim $claim 'native'
        }
    }
    foreach ($source in $catalog.offerSources) {
        if ($source.offerSource -isnot [string] -or [string]::IsNullOrWhiteSpace($source.offerSource) -or
            $sources.ContainsKey($source.offerSource) -or $source.claims -isnot [array]) {
            throw 'Attestation catalog contains a missing/duplicate offerSource or malformed claims list.'
        }
        $sources.Add($source.offerSource, $source)
        foreach ($claim in $source.claims) {
            if ($claim.claimId -cne "source-$($source.offerSource)-type" -or $claim.predicate -cne 'sourceType') {
                throw "Source claim does not match offerSource: $($source.offerSource)"
            }
            Add-CatalogClaim $claim 'source'
        }
    }
    foreach ($pair in $catalog.sourceBoonPairs) {
        if ($pair.offerSource -isnot [string] -or $pair.runtimeItemId -isnot [string] -or
            $pair.pairId -isnot [string] -or $pair.claimId -isnot [string] -or
            [string]::IsNullOrWhiteSpace($pair.pairId) -or $pairs.ContainsKey($pair.pairId)) {
            throw 'Attestation catalog contains a malformed or duplicate source/boon pair.'
        }
        if ($pair.pairId -cne "pair-$($pair.offerSource)-$($pair.runtimeItemId)" -or $pair.claimId -cne $pair.pairId) {
            throw "Source/boon pair identity does not match its exact IDs: $($pair.pairId)"
        }
        if (-not $sources.ContainsKey($pair.offerSource) -or -not $items.ContainsKey($pair.runtimeItemId)) {
            throw "Source/boon pair references an unknown source or runtime item: $($pair.offerSource) / $($pair.runtimeItemId)"
        }
        $key = $pair.offerSource + "`0" + $pair.runtimeItemId
        if ($pairs.ContainsKey($key)) { throw "Attestation catalog contains a duplicate source/boon pair: $($pair.offerSource) / $($pair.runtimeItemId)" }
        $pairs.Add($key, $pair)
        Add-CatalogClaim $pair 'pair'
    }
    foreach ($mapping in $catalog.externalNameMappings) { Add-CatalogClaim $mapping 'mapping' }

    foreach ($claimId in $claimKinds.Keys) {
        $attesting = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($evidence in $catalog.evidence) {
            if ($evidenceClaims[$evidence.evidenceId].Contains($claimId)) { [void]$attesting.Add($evidence.evidenceId) }
        }
        $listed = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($evidenceId in $claimEvidence[$claimId]) {
            if ($evidenceId -isnot [string] -or -not $evidenceById.ContainsKey($evidenceId)) {
                throw "Attestation claim $claimId references an unknown evidence record."
            }
            [void]$listed.Add($evidenceId)
        }
        if ($listed.Count -ne $attesting.Count) { throw "Attestation evidence references are not bidirectional for claim $claimId." }
        foreach ($evidenceId in $listed) {
            if (-not $attesting.Contains($evidenceId)) { throw "Attestation evidence references are not bidirectional for claim $claimId." }
            $kind = $evidenceById[$evidenceId].evidenceKind
            $allowed = switch ($claimKinds[$claimId]) {
                'native' { @('Hades2NativeFile') }
                'source' { @('Hades2NativeFile', 'Documentary') }
                'pair' { @('Hades2NativeFile', 'Documentary') }
                'mapping' { @('MobalyticsPage', 'MobalyticsCDN', 'Documentary') }
            }
            if ($kind -cnotin $allowed) { throw "Incompatible evidence kind $kind for attestation claim $claimId." }
        }
    }
    foreach ($evidence in $catalog.evidence) {
        foreach ($claimId in $evidenceClaims[$evidence.evidenceId]) {
            if (-not $claimKinds.ContainsKey($claimId)) { throw "Evidence $($evidence.evidenceId) references unknown claim $claimId." }
        }
    }

    return @{ nativeItems = $items; offerSources = $sources; pairs = $pairs }
}

function Test-AttestedRuntimeItem([hashtable]$Catalog, [string]$RuntimeItemId) {
    if (-not $Catalog.nativeItems.ContainsKey($RuntimeItemId)) { return $false }
    $usableType = $false
    foreach ($claim in $Catalog.nativeItems[$RuntimeItemId].claims) {
        if ($claim.predicate -ceq 'nativeType' -and $claim.value -ceq 'Trait' -and
            $claim.status -ceq 'validated' -and @($claim.evidenceIds).Count -gt 0) {
            $usableType = $true
        }
    }
    return $usableType
}

function Test-AttestedSourceBoonPair([hashtable]$Catalog, [string]$OfferSource, [string]$RuntimeItemId) {
    if (-not $Catalog.offerSources.ContainsKey($OfferSource) -or -not (Test-AttestedRuntimeItem $Catalog $RuntimeItemId)) { return $false }
    $sourceUsable = $false
    foreach ($claim in $Catalog.offerSources[$OfferSource].claims) {
        if ($claim.predicate -ceq 'sourceType' -and $claim.status -ceq 'validated' -and
            @($claim.evidenceIds).Count -gt 0) { $sourceUsable = $true }
    }
    if (-not $sourceUsable) { return $false }
    $key = $OfferSource + "`0" + $RuntimeItemId
    if (-not $Catalog.pairs.ContainsKey($key)) { return $false }
    $pair = $Catalog.pairs[$key]
    return ($pair.status -ceq 'validated' -and @($pair.evidenceIds).Count -gt 0)
}
