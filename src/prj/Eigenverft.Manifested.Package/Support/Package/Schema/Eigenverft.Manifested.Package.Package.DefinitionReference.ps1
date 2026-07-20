<#
    Eigenverft.Manifested.Package.Package.DefinitionReference
#>

function Get-PackageDefinitionPublication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DefinitionDocument,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionPath
    )

    if (-not $DefinitionDocument.PSObject.Properties['definitionPublication']) {
        throw "Package definition '$DefinitionPath' is missing required definitionPublication metadata."
    }

    $publication = $DefinitionDocument.definitionPublication
    foreach ($requiredProperty in @('publisherId', 'publisherName', 'definitionId', 'definitionRevision', 'publishedAtUtc')) {
        if (-not $publication.PSObject.Properties[$requiredProperty] -or [string]::IsNullOrWhiteSpace([string]$publication.$requiredProperty)) {
            throw "Package definition '$DefinitionPath' is missing definitionPublication.$requiredProperty."
        }
    }

    return [pscustomobject]@{
        PublisherId        = [string]$publication.publisherId
        PublisherName      = [string]$publication.publisherName
        DefinitionId       = [string]$publication.definitionId
        DefinitionRevision = [int]$publication.definitionRevision
        PublishedAtUtc     = [string]$publication.publishedAtUtc
        DepotNamespace     = Get-PackageDefinitionDepotNamespace -Publication $publication
    }
}

function Get-PackageDefinitionDepotNamespace {
    <#
    .SYNOPSIS
    Resolves the optional definitionPublication.depotNamespace used as the first depot subdirectory.

    .DESCRIPTION
    When omitted or blank, returns the neutral namespace 'default'. Explicit values must be a single
    safe path segment (letters, digits, '-' or '_', starting with a letter).
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$Publication = $null,

        [AllowNull()]
        [psobject]$DefinitionDocument = $null
    )

    $source = $Publication
    if ($null -eq $source -and $null -ne $DefinitionDocument -and
        $DefinitionDocument.PSObject.Properties['definitionPublication']) {
        $source = $DefinitionDocument.definitionPublication
    }

    $raw = ''
    if ($null -ne $source -and $source.PSObject.Properties['depotNamespace']) {
        $raw = [string]$source.depotNamespace
    }

    if ([string]::IsNullOrWhiteSpace($raw)) {
        return 'default'
    }

    return $raw.Trim()
}

function Assert-PackageDefinitionDepotNamespace {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$DepotNamespace,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId
    )

    if ([string]::IsNullOrWhiteSpace($DepotNamespace)) {
        return
    }

    if ($DepotNamespace -notmatch '^[A-Za-z][A-Za-z0-9_-]*$') {
        throw "Package definition '$DefinitionId' definitionPublication.depotNamespace '$DepotNamespace' is invalid. Use letters, numbers, '-' or '_' and start with a letter."
    }
}

function Get-PackageLocalDefinitionPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Candidate', 'Assigned')]
        [string]$Role,

        [Parameter(Mandatory = $true)]
        [string]$LocalEndpointRoot,

        [Parameter(Mandatory = $true)]
        [string]$PublisherId,

        [AllowNull()]
        [string]$DefinitionId = $null
    )

    $safePublisherId = ConvertTo-PackageSafePathSegment -Value $PublisherId
    $safeDefinitionId = ConvertTo-PackageSafePathSegment -Value $DefinitionId
    return [System.IO.Path]::GetFullPath((Join-Path (Join-Path (Join-Path $LocalEndpointRoot $Role) $safePublisherId) ($safeDefinitionId + '.json')))
}

function Copy-PackageDefinitionToLocalDefinitionStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Candidate', 'Assigned')]
        [string]$Role,

        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$LocalEndpointRoot,

        [Parameter(Mandatory = $true)]
        [string]$PublisherId,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [Parameter(Mandatory = $true)]
        [int]$DefinitionRevision
    )

    $targetPath = Get-PackageLocalDefinitionPath -Role $Role -LocalEndpointRoot $LocalEndpointRoot -PublisherId $PublisherId -DefinitionId $DefinitionId
    $targetDirectory = Split-Path -Parent $targetPath
    $null = New-Item -ItemType Directory -Path $targetDirectory -Force

    $sourceHash = Get-PackageFileSha256 -Path $SourcePath
    $targetExists = Test-Path -LiteralPath $targetPath -PathType Leaf
    if ($targetExists) {
        $targetHash = Get-PackageFileSha256 -Path $targetPath
        if ([string]::Equals($sourceHash, $targetHash, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{
                Path          = $targetPath
                Hash          = $targetHash
                Status        = 'Reused'
                RevisionReuse = $false
            }
        }

        try {
            $existingInfo = Read-PackageJsonDocument -Path $targetPath
            $existingPublication = Get-PackageDefinitionPublication -DefinitionDocument $existingInfo.Document -DefinitionPath $targetPath
            if ($existingPublication.DefinitionRevision -eq $DefinitionRevision) {
                Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Package definition publisher '{0}' reused definitionRevision '{1}' for definition '{2}' with different content; updating local {3} materialized copy." -f $PublisherId, $DefinitionRevision, $DefinitionId, $Role)
            }
        }
        catch {
            Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Existing local {0} definition copy '{1}' could not be inspected before replacement: {2}" -f $Role, $targetPath, $_.Exception.Message)
        }
    }

    Copy-FileToPath -SourcePath $SourcePath -TargetPath $targetPath -Overwrite | Out-Null
    return [pscustomobject]@{
        Path          = $targetPath
        Hash          = Get-PackageFileSha256 -Path $targetPath
        Status        = if ($targetExists) { 'Updated' } else { 'Copied' }
        RevisionReuse = $targetExists
    }
}

function Get-PackageDefinitionJsonPathsUnderDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath
    )

    if (-not (Test-Path -LiteralPath $DirectoryPath -PathType Container)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $DirectoryPath -Filter '*.json' -File -Recurse | Select-Object -ExpandProperty FullName)
}

function Select-PackageDefinitionCandidatesFromEndpointScanRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EndpointName,

        [Parameter(Mandatory = $true)]
        [psobject]$EndpointSource,

        [Parameter(Mandatory = $true)]
        [string]$ScanRootPath,

        [AllowNull()]
        [psobject]$TrustInventoryDocument = $null,

        [AllowNull()]
        [string]$DefinitionId = $null
    )

    $candidates = New-Object System.Collections.Generic.List[object]
    foreach ($definitionPath in @(Get-PackageDefinitionJsonPathsUnderDirectory -DirectoryPath $ScanRootPath)) {
        try {
            $definitionInfo = Read-PackageJsonDocument -Path $definitionPath
            $definition = $definitionInfo.Document
            $publication = Get-PackageDefinitionPublication -DefinitionDocument $definition -DefinitionPath $definitionPath
            $docDefinitionId = [string]$publication.DefinitionId
            if ([string]::IsNullOrWhiteSpace($docDefinitionId) -or
                (-not [string]::IsNullOrWhiteSpace($DefinitionId) -and
                -not [string]::Equals($docDefinitionId, $DefinitionId, [System.StringComparison]::OrdinalIgnoreCase))) {
                continue
            }

            $signatureInfo = Test-PackageDefinitionSignatureDocument -Definition $definition -TrustInventoryDocument $TrustInventoryDocument
            $candidates.Add([pscustomobject]@{
                EndpointName               = $EndpointName
                EndpointSourceKind         = [string]$EndpointSource.kind
                DepotNamespace             = [string]$publication.DepotNamespace
                DefinitionScanRootPath     = $ScanRootPath
                DefinitionId               = $docDefinitionId
                DefinitionPath             = [System.IO.Path]::GetFullPath($definitionPath)
                PublisherId                = [string]$publication.PublisherId
                PublisherName              = [string]$publication.PublisherName
                DefinitionRevision         = [int]$publication.DefinitionRevision
                PublishedAtUtc             = [string]$publication.PublishedAtUtc
                SourceHash                 = Get-PackageFileSha256 -Path $definitionPath
                SignatureStatus            = [string]$signatureInfo.Status
                SignatureValid             = [bool]$signatureInfo.Valid
                SignatureTrusted           = [bool]$signatureInfo.Trusted
                SignatureKeyThumbprint     = if ($signatureInfo.PSObject.Properties['KeyThumbprint']) { [string]$signatureInfo.KeyThumbprint } else { $null }
                SignatureSignerDisplayName = if ($signatureInfo.PSObject.Properties['SignerDisplayName']) { [string]$signatureInfo.SignerDisplayName } else { $null }
                SignatureCertificateSubject = if ($signatureInfo.PSObject.Properties['CertificateSubject']) { [string]$signatureInfo.CertificateSubject } else { $null }
                SignatureCertificatePem    = if ($signatureInfo.PSObject.Properties['CertificatePem']) { [string]$signatureInfo.CertificatePem } else { $null }
                SignatureCertificateSource = if ($signatureInfo.PSObject.Properties['CertificateSource']) { [string]$signatureInfo.CertificateSource } else { $null }
                SignatureCertificateNotBeforeUtc = if ($signatureInfo.PSObject.Properties['CertificateNotBeforeUtc']) { [string]$signatureInfo.CertificateNotBeforeUtc } else { $null }
                SignatureCertificateNotAfterUtc = if ($signatureInfo.PSObject.Properties['CertificateNotAfterUtc']) { [string]$signatureInfo.CertificateNotAfterUtc } else { $null }
                SignatureTrustEntryFound   = if ($signatureInfo.PSObject.Properties['TrustEntryFound']) { [bool]$signatureInfo.TrustEntryFound } else { $false }
                SignatureTrustEntryPublisherMatches = if ($signatureInfo.PSObject.Properties['TrustEntryPublisherMatches']) { [bool]$signatureInfo.TrustEntryPublisherMatches } else { $false }
                SignatureCanonicalContentHash = if ($signatureInfo.PSObject.Properties['CanonicalContentHash']) { [string]$signatureInfo.CanonicalContentHash } else { $null }
                SignatureErrorMessage      = if ($signatureInfo.PSObject.Properties['ErrorMessage']) { [string]$signatureInfo.ErrorMessage } else { $null }
            }) | Out-Null
        }
        catch {
            Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Skipped package definition candidate '{0}' from endpoint '{1}': {2}" -f $definitionPath, $EndpointName, $_.Exception.Message)
        }
    }

    return @($candidates.ToArray())
}

function Get-PackageEnabledEndpointSources {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$EndpointInventoryDocument
    )

    $sources = @(
        foreach ($source in @(Get-PackageEndpointSourceEntries -Document $EndpointInventoryDocument)) {
            if (-not [bool]$source.enabled) {
                continue
            }
            $endpointName = [string]$source.endpointName
            [pscustomobject]@{
                EndpointName = $endpointName
                Source       = $source
                SearchOrder  = if ($source.PSObject.Properties['searchOrder']) { [int]$source.searchOrder } else { 1000 }
            }
        }
    )

    return @($sources | Sort-Object -Property SearchOrder, EndpointName)
}

function Get-PackageDefinitionCandidateRows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$SourceRows,

        [AllowNull()]
        [string]$ApplicationRootDirectory = $null,

        [AllowNull()]
        [psobject]$TrustInventoryDocument = $null,

        [AllowNull()]
        [string]$DefinitionId = $null
    )

    $candidateRows = New-Object System.Collections.Generic.List[object]
    foreach ($sourceRow in @($SourceRows)) {
        $endpointName = [string]$sourceRow.EndpointName
        $scanRootPath = Resolve-PackageEndpointRootPath -EndpointName $endpointName -Source $sourceRow.Source -ApplicationRootDirectory $ApplicationRootDirectory
        foreach ($candidate in @(Select-PackageDefinitionCandidatesFromEndpointScanRoot -EndpointName $endpointName -EndpointSource $sourceRow.Source -ScanRootPath $scanRootPath -TrustInventoryDocument $TrustInventoryDocument -DefinitionId $DefinitionId)) {
            $candidate | Add-Member -MemberType NoteProperty -Name EndpointSearchOrder -Value ([int]$sourceRow.SearchOrder) -Force
            $candidateRows.Add($candidate) | Out-Null
        }
    }

    return @($candidateRows.ToArray())
}

function Test-PackageCatalogTrustPublisherIdListed {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string[]]$PublisherIds = @(),

        [AllowNull()]
        [string]$PublisherId = $null
    )

    if ([string]::IsNullOrWhiteSpace($PublisherId)) {
        return $false
    }

    foreach ($configuredPublisherId in @($PublisherIds)) {
        if ([string]::IsNullOrWhiteSpace([string]$configuredPublisherId)) {
            continue
        }
        if ([string]::Equals(([string]$configuredPublisherId).Trim(), $PublisherId, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Resolve-PackageDefinitionCandidateTrustEligibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Candidate,

        [ValidateSet('strict', 'allowUnsigned')]
        [string]$CatalogTrustPolicy = 'strict',

        [AllowNull()]
        [string[]]$CatalogTrustAllowUnsignedPublisherIds = @(),

        [AllowNull()]
        [string[]]$CatalogTrustBlockedPublisherIds = @(),

        [ValidateSet('fail', 'prompt', 'trust')]
        [string]$UnknownSignedKeyPolicy = 'prompt'
    )

    $publisherId = if ($Candidate.PSObject.Properties['PublisherId']) { [string]$Candidate.PublisherId } else { $null }
    $signatureStatus = if ($Candidate.PSObject.Properties['SignatureStatus'] -and
        -not [string]::IsNullOrWhiteSpace([string]$Candidate.SignatureStatus)) {
        [string]$Candidate.SignatureStatus
    }
    else {
        'missingSignature'
    }

    if (Test-PackageCatalogTrustPublisherIdListed -PublisherIds $CatalogTrustBlockedPublisherIds -PublisherId $publisherId) {
        return [pscustomobject]@{
            Eligible    = $false
            TrustStatus = 'blockedPublisher'
            TrustReason = "Publisher '$publisherId' is blocked by catalogTrust.blockedPublisherIds."
        }
    }

    if ($Candidate.PSObject.Properties['SignatureTrusted'] -and [bool]$Candidate.SignatureTrusted) {
        return [pscustomobject]@{
            Eligible    = $true
            TrustStatus = 'signedTrusted'
            TrustReason = 'Definition signature is valid and the signing key is trusted for this publisher.'
        }
    }

    $hasEmbeddedCertificate = $Candidate.PSObject.Properties['SignatureCertificatePem'] -and
        -not [string]::IsNullOrWhiteSpace([string]$Candidate.SignatureCertificatePem)
    $hasExistingTrustEntry = $Candidate.PSObject.Properties['SignatureTrustEntryFound'] -and [bool]$Candidate.SignatureTrustEntryFound
    if ($Candidate.PSObject.Properties['SignatureValid'] -and [bool]$Candidate.SignatureValid -and
        [string]::Equals($signatureStatus, 'validUntrusted', [System.StringComparison]::OrdinalIgnoreCase) -and
        $hasEmbeddedCertificate -and
        -not $hasExistingTrustEntry -and
        $UnknownSignedKeyPolicy -in @('prompt', 'trust')) {
        return [pscustomobject]@{
            Eligible    = $true
            TrustStatus = if ([string]::Equals($UnknownSignedKeyPolicy, 'trust', [System.StringComparison]::OrdinalIgnoreCase)) { 'signedUnknownKeyAutoTrust' } else { 'signedUnknownKeyPrompt' }
            TrustReason = "Definition signature is valid with an embedded certificate, but the signing key is not yet trusted for publisher '$publisherId'."
        }
    }

    $isUnsignedDefinition = $signatureStatus -in @('missingSignature', 'unsigned')
    $publisherAllowsUnsigned = Test-PackageCatalogTrustPublisherIdListed -PublisherIds $CatalogTrustAllowUnsignedPublisherIds -PublisherId $publisherId

    if ([string]::Equals($CatalogTrustPolicy, 'allowUnsigned', [System.StringComparison]::OrdinalIgnoreCase) -and
        $isUnsignedDefinition -and $publisherAllowsUnsigned) {
        return [pscustomobject]@{
            Eligible    = $true
            TrustStatus = 'unsignedConfigTrust'
            TrustReason = "Unsigned definition is allowed because catalogTrust.policy='allowUnsigned' and publisher '$publisherId' is listed in catalogTrust.allowUnsignedPublisherIds."
        }
    }

    $reason = switch -Exact ($signatureStatus) {
        'missingSignature' {
            if ([string]::Equals($CatalogTrustPolicy, 'strict', [System.StringComparison]::OrdinalIgnoreCase)) {
                "catalogTrust.policy='strict' requires definitionPublication.definitionSignature.kind='signed'."
            }
            elseif (-not $publisherAllowsUnsigned) {
                "Unsigned definition is not allowed because publisher '$publisherId' is not listed in catalogTrust.allowUnsignedPublisherIds."
            }
            else {
                'definitionPublication.definitionSignature is missing.'
            }
        }
        'unsigned' {
            if ([string]::Equals($CatalogTrustPolicy, 'strict', [System.StringComparison]::OrdinalIgnoreCase)) {
                "catalogTrust.policy='strict' rejects unsigned definitions."
            }
            elseif (-not $publisherAllowsUnsigned) {
                "Unsigned definition is not allowed because publisher '$publisherId' is not listed in catalogTrust.allowUnsignedPublisherIds."
            }
            else {
                'Unsigned definition was not allowed by catalog policy.'
            }
        }
        'unknownKey' { 'Definition signing key is not trusted or its certificate is unavailable.' }
        'validUntrusted' { 'Definition signature is valid, but the signing key is not trusted for this publisher.' }
        'revokedKey' { 'Definition signing key is revoked.' }
        'invalidEmbeddedCertificate' { 'Definition embedded signing certificate is not valid PEM.' }
        'certificateThumbprintMismatch' { 'Definition embedded signing certificate thumbprint does not match definitionSignature.keyThumbprint.' }
        'invalidSignature' { 'Definition signature verification failed.' }
        'invalidSignatureValue' { 'Definition signature value is not valid base64.' }
        'missingSignatureValue' { 'Signed definition is missing definitionSignature.signatureValue.' }
        'unsupportedSignatureKind' { 'Definition uses an unsupported definitionSignature.kind.' }
        'unsupportedSignatureFormat' { 'Definition uses an unsupported definitionSignature.format.' }
        default { "Definition signature status '$signatureStatus' is not eligible." }
    }

    return [pscustomobject]@{
        Eligible    = $false
        TrustStatus = $signatureStatus
        TrustReason = $reason
    }
}

function Select-PackageDefinitionCandidateWinner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Candidates,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [AllowNull()]
        [string]$PublisherId = $null,

        [ValidateSet('strict', 'allowUnsigned')]
        [string]$CatalogTrustPolicy = 'strict',

        [AllowNull()]
        [string[]]$CatalogTrustAllowUnsignedPublisherIds = @(),

        [AllowNull()]
        [string[]]$CatalogTrustBlockedPublisherIds = @(),

        [ValidateSet('fail', 'prompt', 'trust')]
        [string]$UnknownSignedKeyPolicy = 'prompt',

        [ValidateSet('fail', 'warnFirst', 'first', 'warnLast', 'last')]
        [string]$DefinitionPublisherConflictMode = 'fail'
    )

    $candidateSet = @($Candidates)
    if (-not [string]::IsNullOrWhiteSpace($PublisherId)) {
        $candidateSet = @($candidateSet | Where-Object {
                [string]::Equals([string]$_.PublisherId, [string]$PublisherId, [System.StringComparison]::OrdinalIgnoreCase)
            })
        if ($candidateSet.Count -eq 0) {
            throw "Package definition '$DefinitionId' was found in enabled endpoints, but not for publisher '$PublisherId'. -PublisherId filters definitionPublication.publisherId."
        }
    }

    $ineligibleReasons = New-Object System.Collections.Generic.List[string]
    $trustedCandidates = @(
        foreach ($candidate in @($candidateSet)) {
            $eligibility = Resolve-PackageDefinitionCandidateTrustEligibility -Candidate $candidate -CatalogTrustPolicy $CatalogTrustPolicy -CatalogTrustAllowUnsignedPublisherIds $CatalogTrustAllowUnsignedPublisherIds -CatalogTrustBlockedPublisherIds $CatalogTrustBlockedPublisherIds -UnknownSignedKeyPolicy $UnknownSignedKeyPolicy
            $candidate | Add-Member -MemberType NoteProperty -Name CatalogTrustPolicy -Value ([string]$CatalogTrustPolicy) -Force
            $candidate | Add-Member -MemberType NoteProperty -Name CatalogTrustStatus -Value ([string]$eligibility.TrustStatus) -Force
            $candidate | Add-Member -MemberType NoteProperty -Name CatalogTrustReason -Value ([string]$eligibility.TrustReason) -Force
            if (-not [bool]$eligibility.Eligible) {
                $ineligibleReasons.Add(("{0}: {1}" -f [string]$candidate.PublisherId, [string]$eligibility.TrustReason)) | Out-Null
                continue
            }
            $candidate
        }
    )

    if ($trustedCandidates.Count -eq 0) {
        $suffix = if ([string]::IsNullOrWhiteSpace($PublisherId)) { '' } else { " for publisher '$PublisherId'" }
        $reasonText = (@($ineligibleReasons.ToArray()) | Select-Object -Unique) -join '; '
        if ([string]::IsNullOrWhiteSpace($reasonText)) {
            $reasonText = 'No matching candidate satisfied catalog trust.'
        }
        throw "Package definition '$DefinitionId' was found but no candidate satisfied catalog trust policy '$CatalogTrustPolicy'$suffix. $reasonText"
    }

    if ([string]::IsNullOrWhiteSpace($PublisherId)) {
        $publisherIds = @($trustedCandidates | Select-Object -ExpandProperty PublisherId -Unique)
        if ($publisherIds.Count -gt 1) {
            if ([string]::Equals($DefinitionPublisherConflictMode, 'fail', [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Package definition '$DefinitionId' is provided by multiple eligible publisherIds: $($publisherIds -join ', '). Use -PublisherId or set package.endpointEnvironment.defaults.definitionPublisherConflictMode."
            }

            $descending = $DefinitionPublisherConflictMode -in @('warnLast', 'last')
            $selectedByEndpoint = if ($descending) {
                @($trustedCandidates | Sort-Object -Property EndpointSearchOrder, EndpointName, DefinitionPath -Descending | Select-Object -First 1)[0]
            }
            else {
                @($trustedCandidates | Sort-Object -Property EndpointSearchOrder, EndpointName, DefinitionPath | Select-Object -First 1)[0]
            }
            $selectedPublisherId = [string]$selectedByEndpoint.PublisherId
            if ($DefinitionPublisherConflictMode -in @('warnFirst', 'warnLast')) {
                Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Package definition '{0}' is provided by multiple eligible publisherIds ({1}); definitionPublisherConflictMode='{2}' selected publisher '{3}' from endpoint '{4}'." -f $DefinitionId, ($publisherIds -join ', '), $DefinitionPublisherConflictMode, $selectedPublisherId, [string]$selectedByEndpoint.EndpointName)
            }
            $trustedCandidates = @($trustedCandidates | Where-Object { [string]::Equals([string]$_.PublisherId, $selectedPublisherId, [System.StringComparison]::OrdinalIgnoreCase) })
        }
    }

    $bestRevision = (@($trustedCandidates) | Measure-Object -Property DefinitionRevision -Maximum).Maximum
    $bestRevisionCandidates = @($trustedCandidates | Where-Object { [int]$_.DefinitionRevision -eq [int]$bestRevision })
    $bestHashes = @($bestRevisionCandidates | Select-Object -ExpandProperty SourceHash -Unique)
    if ($bestHashes.Count -gt 1) {
        $locations = (@($bestRevisionCandidates) | ForEach-Object { "'$($_.EndpointName):$($_.DefinitionPath) hash=$($_.SourceHash)'" }) -join ', '
        throw "Package definition '$DefinitionId' publisher '$($bestRevisionCandidates[0].PublisherId)' reused definitionRevision '$bestRevision' with different content across endpoints. Matching candidates: $locations. Publish a higher revision or disable one endpoint."
    }

    return @($bestRevisionCandidates | Sort-Object -Property EndpointSearchOrder, EndpointName, DefinitionPath | Select-Object -First 1)[0]
}

function Sync-PackageEndpointCandidateDefinitions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$SourceRows,

        [AllowNull()]
        [psobject]$TrustInventoryDocument = $null,

        [AllowNull()]
        [string]$ApplicationRootDirectory = $null,

        [Parameter(Mandatory = $true)]
        [string]$LocalEndpointRoot,

        [ValidateSet('strict', 'allowUnsigned')]
        [string]$CatalogTrustPolicy = 'strict',

        [AllowNull()]
        [string[]]$CatalogTrustAllowUnsignedPublisherIds = @(),

        [AllowNull()]
        [string[]]$CatalogTrustBlockedPublisherIds = @(),

        [ValidateSet('fail', 'prompt', 'trust')]
        [string]$UnknownSignedKeyPolicy = 'prompt',

        [ValidateSet('fail', 'warnFirst', 'first', 'warnLast', 'last')]
        [string]$DefinitionPublisherConflictMode = 'fail'
    )

    $allCandidates = @(Get-PackageDefinitionCandidateRows -SourceRows $SourceRows -ApplicationRootDirectory $ApplicationRootDirectory -TrustInventoryDocument $TrustInventoryDocument)
    $keys = @($allCandidates | ForEach-Object { [string]$_.DefinitionId } | Sort-Object -Unique)
    $materializedCount = 0
    foreach ($definitionId in @($keys)) {
        try {
            $winner = Select-PackageDefinitionCandidateWinner -Candidates @($allCandidates | Where-Object { [string]::Equals([string]$_.DefinitionId, [string]$definitionId, [System.StringComparison]::OrdinalIgnoreCase) }) -DefinitionId $definitionId -CatalogTrustPolicy $CatalogTrustPolicy -CatalogTrustAllowUnsignedPublisherIds $CatalogTrustAllowUnsignedPublisherIds -CatalogTrustBlockedPublisherIds $CatalogTrustBlockedPublisherIds -UnknownSignedKeyPolicy $UnknownSignedKeyPolicy -DefinitionPublisherConflictMode $DefinitionPublisherConflictMode
            Copy-PackageDefinitionToLocalDefinitionStore -Role 'Candidate' -SourcePath $winner.DefinitionPath -LocalEndpointRoot $LocalEndpointRoot -PublisherId ([string]$winner.PublisherId) -DefinitionId ([string]$winner.DefinitionId) -DefinitionRevision ([int]$winner.DefinitionRevision) | Out-Null
            $materializedCount++
        }
        catch {
            Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Skipped endpoint-wide Candidate materialization for definition '{0}': {1}" -f $definitionId, $_.Exception.Message)
        }
    }

    return $materializedCount
}

function Confirm-PackageUnknownSigningKeyTrust {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Candidate
    )

    $keyText = if ([string]::IsNullOrWhiteSpace([string]$Candidate.SignatureKeyThumbprint)) { '<none>' } else { [string]$Candidate.SignatureKeyThumbprint }
    $signerText = if ([string]::IsNullOrWhiteSpace([string]$Candidate.SignatureSignerDisplayName)) { '<none>' } else { [string]$Candidate.SignatureSignerDisplayName }
    $subjectText = if ([string]::IsNullOrWhiteSpace([string]$Candidate.SignatureCertificateSubject)) { '<none>' } else { [string]$Candidate.SignatureCertificateSubject }
    $notBeforeText = if ([string]::IsNullOrWhiteSpace([string]$Candidate.SignatureCertificateNotBeforeUtc)) { '<unknown>' } else { [string]$Candidate.SignatureCertificateNotBeforeUtc }
    $notAfterText = if ([string]::IsNullOrWhiteSpace([string]$Candidate.SignatureCertificateNotAfterUtc)) { '<unknown>' } else { [string]$Candidate.SignatureCertificateNotAfterUtc }
    $hashText = if ([string]::IsNullOrWhiteSpace([string]$Candidate.SignatureCanonicalContentHash)) { '<none>' } else { [string]$Candidate.SignatureCanonicalContentHash }

    $message = @(
        "Package definition is signed by an unknown signing key. The signature is valid with the embedded public certificate."
        "Trust is for this signing key and publisher id, and will apply to other package definitions signed by this key for the same publisher."
        ''
        "Publisher: $($Candidate.PublisherId) ($($Candidate.PublisherName))"
        "Definition: $($Candidate.DefinitionId) revision $($Candidate.DefinitionRevision)"
        "Endpoint: $($Candidate.EndpointName)"
        "Path: $($Candidate.DefinitionPath)"
        "Signer: $signerText"
        "Certificate subject: $subjectText"
        "Thumbprint: $keyText"
        "Valid from: $notBeforeText"
        "Valid until: $notAfterText"
        "Canonical content hash: $hashText"
        ''
        "Trust this signing key for publisher '$($Candidate.PublisherId)'?"
    ) -join [Environment]::NewLine

    $choices = [System.Management.Automation.Host.ChoiceDescription[]]@(
        [System.Management.Automation.Host.ChoiceDescription]::new('&Yes', 'Trust this signing key for this publisher and continue.')
        [System.Management.Automation.Host.ChoiceDescription]::new('&No', 'Do not trust this signing key.')
    )

    try {
        return ((Get-Host).UI.PromptForChoice('Trust package signing key', $message, $choices, 1) -eq 0)
    }
    catch {
        Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Could not prompt for package signing-key trust: {0}" -f $_.Exception.Message)
        return $false
    }
}

function Add-PackageTrustForDefinitionCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Candidate,

        [Parameter(Mandatory = $true)]
        [psobject]$TrustInventoryDocumentInfo,

        [Parameter(Mandatory = $true)]
        [string]$TrustSource,

        [Parameter(Mandatory = $true)]
        [string]$TrustReason
    )

    if (-not $Candidate.PSObject.Properties['SignatureCertificatePem'] -or [string]::IsNullOrWhiteSpace([string]$Candidate.SignatureCertificatePem)) {
        throw "Package definition '$($Candidate.DefinitionId)' does not contain definitionSignature.certificatePem."
    }

    $certificate = ConvertFrom-PackageCertificatePem -CertificatePem ([string]$Candidate.SignatureCertificatePem)
    try {
        $entry = New-PackageTrustEntry -Certificate $certificate -PublisherId ([string]$Candidate.PublisherId) -PublisherName ([string]$Candidate.PublisherName) -SignerDisplayName ([string]$Candidate.SignatureSignerDisplayName) -TrustSource $TrustSource -TrustReason $TrustReason
        $existing = Get-PackageTrustEntryByThumbprint -Document $TrustInventoryDocumentInfo.Document -KeyThumbprint ([string]$entry.keyThumbprint)
        if ($existing) {
            $existingPublisherId = if ($existing.PSObject.Properties['publisherId']) { [string]$existing.publisherId } else { '<unknown>' }
            throw "Package signing certificate '$($entry.keyThumbprint)' already exists in '$($TrustInventoryDocumentInfo.Path)' for publisher '$existingPublisherId'. Use explicit trust management to change this key."
        }

        $TrustInventoryDocumentInfo.Document.keys = @($TrustInventoryDocumentInfo.Document.keys) + $entry
        Save-PackageTrustInventoryDocument -DocumentInfo $TrustInventoryDocumentInfo
        return Select-PackageTrustSummary -Entry $entry -InventoryPath $TrustInventoryDocumentInfo.Path
    }
    finally {
        $certificate.Dispose()
    }
}

function Resolve-PackageSelectedCandidateUnknownSigningKeyTrust {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Candidate,

        [Parameter(Mandatory = $true)]
        [psobject]$TrustInventoryDocumentInfo,

        [ValidateSet('fail', 'prompt', 'trust')]
        [string]$UnknownSignedKeyPolicy = 'prompt'
    )

    if ([string]$Candidate.CatalogTrustStatus -notin @('signedUnknownKeyPrompt', 'signedUnknownKeyAutoTrust')) {
        return $Candidate
    }

    if ([string]::Equals($UnknownSignedKeyPolicy, 'prompt', [System.StringComparison]::OrdinalIgnoreCase)) {
        if (-not (Confirm-PackageUnknownSigningKeyTrust -Candidate $Candidate)) {
            throw "Package definition '$($Candidate.DefinitionId)' is signed by unknown key '$($Candidate.SignatureKeyThumbprint)' for publisher '$($Candidate.PublisherId)', and the key was not trusted. Use Import-PackageTrust -Path '<public-cert.cer>' before Invoke-Package, or rerun Invoke-Package with -AcceptUnknownSigningKey."
        }
    }

    $trustSource = if ([string]::Equals($UnknownSignedKeyPolicy, 'trust', [System.StringComparison]::OrdinalIgnoreCase)) { 'invokePackageAutoTrust' } else { 'invokePackagePrompt' }
    $trustReason = "Trusted from embedded certificate while resolving package definition '$($Candidate.DefinitionId)' from endpoint '$($Candidate.EndpointName)'."
    $summary = Add-PackageTrustForDefinitionCandidate -Candidate $Candidate -TrustInventoryDocumentInfo $TrustInventoryDocumentInfo -TrustSource $trustSource -TrustReason $trustReason
    Write-PackageExecutionMessage -Message ("[TRUST] Trusted embedded signing key '{0}' for publisher '{1}'." -f [string]$summary.KeyThumbprint, [string]$summary.PublisherId)

    Set-PackageObjectProperty -InputObject $Candidate -Name 'SignatureTrusted' -Value $true
    Set-PackageObjectProperty -InputObject $Candidate -Name 'SignatureStatus' -Value 'validTrusted'
    Set-PackageObjectProperty -InputObject $Candidate -Name 'CatalogTrustStatus' -Value 'signedTrusted'
    Set-PackageObjectProperty -InputObject $Candidate -Name 'CatalogTrustReason' -Value 'Definition signature is valid and the signing key was trusted from the embedded certificate during this invocation.'
    return $Candidate
}

function Resolve-PackageDefinitionReference {
<#
.SYNOPSIS
Resolves a Package definition identity to a local materialized definition path.

.DESCRIPTION
PackageEndpointInventory.json lists scan endpoints. PackageTrustInventory.json and
PackageConfig.catalogTrust decide catalog authority. Matching uses
definitionPublication.definitionId, optional definitionPublication.publisherId,
catalog trust eligibility, conflict policy, and then definitionRevision.
#>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$PublisherId = $null,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DefinitionId,

        [AllowNull()]
        [string]$ApplicationRootDirectory = $null,

        [AllowNull()]
        [string]$LocalEndpointRoot = $null,

        [ValidateSet('packageFocused', 'endpointFocused')]
        [string]$EndpointMaterializationMode = 'packageFocused',

        [ValidateSet('strict', 'allowUnsigned')]
        [string]$CatalogTrustPolicy = 'strict',

        [AllowNull()]
        [string[]]$CatalogTrustAllowUnsignedPublisherIds = @(),

        [AllowNull()]
        [string[]]$CatalogTrustBlockedPublisherIds = @(),

        [ValidateSet('fail', 'prompt', 'trust')]
        [string]$UnknownSignedKeyPolicy = 'prompt',

        [ValidateSet('fail', 'warnFirst', 'first', 'warnLast', 'last')]
        [string]$DefinitionPublisherConflictMode = 'fail',

        [switch]$InspectionOnly
    )

    $endpointInventoryInfo = Get-PackageEndpointInventoryInfo -InspectionOnly:$InspectionOnly
    $trustInventoryInfo = Get-PackageTrustInventoryInfo -InspectionOnly:$InspectionOnly
    $sourceRows = @(Get-PackageEnabledEndpointSources -EndpointInventoryDocument $endpointInventoryInfo.Document)

    $resolvedLocalEndpointRoot = if ([string]::IsNullOrWhiteSpace($LocalEndpointRoot)) {
        Get-PackageDefaultLocalEndpointRoot
    }
    else {
        [string]$LocalEndpointRoot
    }

    if ((-not $InspectionOnly.IsPresent) -and
        [string]::Equals($EndpointMaterializationMode, 'endpointFocused', [System.StringComparison]::OrdinalIgnoreCase)) {
        $count = Sync-PackageEndpointCandidateDefinitions -SourceRows $sourceRows -TrustInventoryDocument $trustInventoryInfo.Document -ApplicationRootDirectory $ApplicationRootDirectory -LocalEndpointRoot $resolvedLocalEndpointRoot -CatalogTrustPolicy $CatalogTrustPolicy -CatalogTrustAllowUnsignedPublisherIds $CatalogTrustAllowUnsignedPublisherIds -CatalogTrustBlockedPublisherIds $CatalogTrustBlockedPublisherIds -UnknownSignedKeyPolicy $UnknownSignedKeyPolicy -DefinitionPublisherConflictMode $DefinitionPublisherConflictMode
        Write-PackageExecutionMessage -Message ("[STATE] Endpoint-wide definition materialization refreshed {0} Candidate definition file(s)." -f $count)
    }

    $candidates = @(Get-PackageDefinitionCandidateRows -SourceRows $sourceRows -ApplicationRootDirectory $ApplicationRootDirectory -TrustInventoryDocument $trustInventoryInfo.Document -DefinitionId $DefinitionId)
    if ($candidates.Count -eq 0) {
        $narrow = if ([string]::IsNullOrWhiteSpace($PublisherId)) { '' } else { " for publisher '$PublisherId'" }
        throw "Package definition '$DefinitionId' was not found in enabled endpoints$narrow."
    }

    $selected = Select-PackageDefinitionCandidateWinner -Candidates $candidates -DefinitionId $DefinitionId -PublisherId $PublisherId -CatalogTrustPolicy $CatalogTrustPolicy -CatalogTrustAllowUnsignedPublisherIds $CatalogTrustAllowUnsignedPublisherIds -CatalogTrustBlockedPublisherIds $CatalogTrustBlockedPublisherIds -UnknownSignedKeyPolicy $UnknownSignedKeyPolicy -DefinitionPublisherConflictMode $DefinitionPublisherConflictMode
    $candidateCopy = $null
    if (-not $InspectionOnly.IsPresent) {
        $selected = Resolve-PackageSelectedCandidateUnknownSigningKeyTrust -Candidate $selected -TrustInventoryDocumentInfo $trustInventoryInfo -UnknownSignedKeyPolicy $UnknownSignedKeyPolicy
        $candidateCopy = Copy-PackageDefinitionToLocalDefinitionStore -Role 'Candidate' -SourcePath $selected.DefinitionPath -LocalEndpointRoot $resolvedLocalEndpointRoot -PublisherId $selected.PublisherId -DefinitionId $selected.DefinitionId -DefinitionRevision $selected.DefinitionRevision
    }
    $keyText = if ([string]::IsNullOrWhiteSpace([string]$selected.SignatureKeyThumbprint)) { '<none>' } else { [string]$selected.SignatureKeyThumbprint }
    $signerText = if ([string]::IsNullOrWhiteSpace([string]$selected.SignatureSignerDisplayName)) { '<none>' } else { [string]$selected.SignatureSignerDisplayName }
    Write-PackageExecutionMessage -Message ("[TRUST] Definition signature status='{0}' catalogTrust='{1}' key='{2}' signer='{3}' policy='{4}'." -f [string]$selected.SignatureStatus, [string]$selected.CatalogTrustStatus, $keyText, $signerText, [string]$CatalogTrustPolicy)

    return [pscustomobject]@{
        EndpointName                  = [string]$selected.EndpointName
        DepotNamespace                = if ($selected.PSObject.Properties['DepotNamespace']) { [string]$selected.DepotNamespace } else { '' }
        DefinitionId                  = [string]$selected.DefinitionId
        DefinitionPath                = [System.IO.Path]::GetFullPath($(if ($candidateCopy) { $candidateCopy.Path } else { $selected.DefinitionPath }))
        SourceKind                    = [string]$selected.EndpointSourceKind
        SourcePath                    = [string]$selected.DefinitionPath
        SourceDefinitionScanRootPath  = [string]$selected.DefinitionScanRootPath
        SourceHash                    = [string]$selected.SourceHash
        CandidatePath                 = if ($candidateCopy) { [System.IO.Path]::GetFullPath($candidateCopy.Path) } else { $null }
        CandidateHash                 = if ($candidateCopy) { [string]$candidateCopy.Hash } else { $null }
        SnapshotPath                  = $null
        SnapshotHash                  = $null
        ResolvedAtUtc                 = [DateTime]::UtcNow.ToString('o')
        SnapshotFallback              = $false
        EndpointInventoryPath         = $endpointInventoryInfo.Path
        TrustInventoryPath            = $trustInventoryInfo.Path
        Trusted                       = [bool]$selected.SignatureTrusted
        CatalogTrustPolicy            = [string]$CatalogTrustPolicy
        CatalogTrustAllowUnsignedPublisherIds = @($CatalogTrustAllowUnsignedPublisherIds)
        CatalogTrustBlockedPublisherIds = @($CatalogTrustBlockedPublisherIds)
        CatalogTrustStatus            = [string]$selected.CatalogTrustStatus
        CatalogTrustReason            = [string]$selected.CatalogTrustReason
        SignatureStatus               = [string]$selected.SignatureStatus
        SignatureValid                = [bool]$selected.SignatureValid
        SignatureTrusted              = [bool]$selected.SignatureTrusted
        SignatureKeyThumbprint        = if ([string]::IsNullOrWhiteSpace([string]$selected.SignatureKeyThumbprint)) { $null } else { [string]$selected.SignatureKeyThumbprint }
        SignatureSignerDisplayName    = if ([string]::IsNullOrWhiteSpace([string]$selected.SignatureSignerDisplayName)) { $null } else { [string]$selected.SignatureSignerDisplayName }
        SignatureCertificateSubject   = if ([string]::IsNullOrWhiteSpace([string]$selected.SignatureCertificateSubject)) { $null } else { [string]$selected.SignatureCertificateSubject }
        SignatureCertificatePem       = if ([string]::IsNullOrWhiteSpace([string]$selected.SignatureCertificatePem)) { $null } else { [string]$selected.SignatureCertificatePem }
        SignatureCertificateSource    = if ([string]::IsNullOrWhiteSpace([string]$selected.SignatureCertificateSource)) { $null } else { [string]$selected.SignatureCertificateSource }
        SignatureCertificateNotBeforeUtc = if ([string]::IsNullOrWhiteSpace([string]$selected.SignatureCertificateNotBeforeUtc)) { $null } else { [string]$selected.SignatureCertificateNotBeforeUtc }
        SignatureCertificateNotAfterUtc = if ([string]::IsNullOrWhiteSpace([string]$selected.SignatureCertificateNotAfterUtc)) { $null } else { [string]$selected.SignatureCertificateNotAfterUtc }
        SignatureCanonicalContentHash = if ([string]::IsNullOrWhiteSpace([string]$selected.SignatureCanonicalContentHash)) { $null } else { [string]$selected.SignatureCanonicalContentHash }
        PublisherId                   = [string]$selected.PublisherId
        PublisherName                 = [string]$selected.PublisherName
        DefinitionRevision            = [int]$selected.DefinitionRevision
        PublishedAtUtc                = [string]$selected.PublishedAtUtc
        MaterializationStatus         = if ($candidateCopy) { [string]$candidateCopy.Status } else { 'InspectionOnly' }
        EndpointMaterializationMode   = [string]$EndpointMaterializationMode
        InspectionOnly                = [bool]$InspectionOnly
    }
}
