<#
    Eigenverft.Manifested.Sandbox.Package.DefinitionReference
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

            $candidates.Add([pscustomobject]@{
                EndpointName               = $EndpointName
                EndpointSourceKind         = [string]$EndpointSource.kind
                DefinitionScanRootPath     = $ScanRootPath
                DefinitionId               = $docDefinitionId
                DefinitionPath             = [System.IO.Path]::GetFullPath($definitionPath)
                PublisherId                = [string]$publication.PublisherId
                PublisherName              = [string]$publication.PublisherName
                DefinitionRevision         = [int]$publication.DefinitionRevision
                PublishedAtUtc             = [string]$publication.PublishedAtUtc
                SourceHash                 = Get-PackageFileSha256 -Path $definitionPath
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
        [string]$DefinitionId = $null
    )

    $candidateRows = New-Object System.Collections.Generic.List[object]
    foreach ($sourceRow in @($SourceRows)) {
        $endpointName = [string]$sourceRow.EndpointName
        $scanRootPath = Resolve-PackageEndpointRootPath -EndpointName $endpointName -Source $sourceRow.Source -ApplicationRootDirectory $ApplicationRootDirectory
        foreach ($candidate in @(Select-PackageDefinitionCandidatesFromEndpointScanRoot -EndpointName $endpointName -EndpointSource $sourceRow.Source -ScanRootPath $scanRootPath -DefinitionId $DefinitionId)) {
            $candidate | Add-Member -MemberType NoteProperty -Name EndpointSearchOrder -Value ([int]$sourceRow.SearchOrder) -Force
            $candidateRows.Add($candidate) | Out-Null
        }
    }

    return @($candidateRows.ToArray())
}

function Select-PackageDefinitionCandidateWinner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Candidates,

        [Parameter(Mandatory = $true)]
        [object[]]$PublisherRows,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [AllowNull()]
        [string]$PublisherId = $null,

        [ValidateSet('fail', 'warnFirst', 'first', 'warnLast', 'last')]
        [string]$DefinitionPublisherConflictMode = 'fail'
    )

    $publisherById = @{}
    foreach ($publisherRow in @($PublisherRows)) {
        $publisherById[[string]$publisherRow.PublisherId] = $publisherRow
    }

    if (-not [string]::IsNullOrWhiteSpace($PublisherId) -and -not $publisherById.ContainsKey($PublisherId)) {
        throw "Package definition publisher '$PublisherId' is not enabled and trusted in PackagePublisherInventory.json."
    }

    $trustedCandidates = @(
        foreach ($candidate in @($Candidates)) {
            if (-not $publisherById.ContainsKey([string]$candidate.PublisherId)) {
                continue
            }
            if (-not [string]::IsNullOrWhiteSpace($PublisherId) -and
                -not [string]::Equals([string]$candidate.PublisherId, [string]$PublisherId, [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            $publisherRow = $publisherById[[string]$candidate.PublisherId]
            $candidate | Add-Member -MemberType NoteProperty -Name PublisherTrustMode -Value ([string]$publisherRow.TrustMode) -Force
            $candidate
        }
    )

    if ($trustedCandidates.Count -eq 0) {
        $suffix = if ([string]::IsNullOrWhiteSpace($PublisherId)) { '' } else { " for publisher '$PublisherId'" }
        throw "Package definition '$DefinitionId' was found only from untrusted or disabled publishers$suffix."
    }

    if ([string]::IsNullOrWhiteSpace($PublisherId)) {
        $publisherIds = @($trustedCandidates | Select-Object -ExpandProperty PublisherId -Unique)
        if ($publisherIds.Count -gt 1) {
            if ([string]::Equals($DefinitionPublisherConflictMode, 'fail', [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Package definition '$DefinitionId' is provided by multiple trusted publishers: $($publisherIds -join ', '). Use -PublisherId or set package.endpointEnvironment.defaults.definitionPublisherConflictMode."
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
                Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Package definition '{0}' is provided by multiple trusted publishers ({1}); definitionPublisherConflictMode='{2}' selected publisher '{3}' from endpoint '{4}'." -f $DefinitionId, ($publisherIds -join ', '), $DefinitionPublisherConflictMode, $selectedPublisherId, [string]$selectedByEndpoint.EndpointName)
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

        [Parameter(Mandatory = $true)]
        [object[]]$PublisherRows,

        [AllowNull()]
        [string]$ApplicationRootDirectory = $null,

        [Parameter(Mandatory = $true)]
        [string]$LocalEndpointRoot,

        [ValidateSet('fail', 'warnFirst', 'first', 'warnLast', 'last')]
        [string]$DefinitionPublisherConflictMode = 'fail'
    )

    $allCandidates = @(Get-PackageDefinitionCandidateRows -SourceRows $SourceRows -ApplicationRootDirectory $ApplicationRootDirectory)
    $keys = @($allCandidates | ForEach-Object { [string]$_.DefinitionId } | Sort-Object -Unique)
    $materializedCount = 0
    foreach ($definitionId in @($keys)) {
        try {
            $winner = Select-PackageDefinitionCandidateWinner -Candidates @($allCandidates | Where-Object { [string]::Equals([string]$_.DefinitionId, [string]$definitionId, [System.StringComparison]::OrdinalIgnoreCase) }) -PublisherRows $PublisherRows -DefinitionId $definitionId -DefinitionPublisherConflictMode $DefinitionPublisherConflictMode
            Copy-PackageDefinitionToLocalDefinitionStore -Role 'Candidate' -SourcePath $winner.DefinitionPath -LocalEndpointRoot $LocalEndpointRoot -PublisherId ([string]$winner.PublisherId) -DefinitionId ([string]$winner.DefinitionId) -DefinitionRevision ([int]$winner.DefinitionRevision) | Out-Null
            $materializedCount++
        }
        catch {
            Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Skipped endpoint-wide Candidate materialization for definition '{0}': {1}" -f $definitionId, $_.Exception.Message)
        }
    }

    return $materializedCount
}

function Resolve-PackageDefinitionReference {
<#
.SYNOPSIS
Resolves a Package definition identity to a local materialized definition path.

.DESCRIPTION
PackageEndpointInventory.json lists scan endpoints. PackagePublisherInventory.json
lists trusted publisher namespaces. Matching uses definitionPublication.definitionId,
then publisher trust and conflict policy, then definitionRevision.
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

        [ValidateSet('fail', 'warnFirst', 'first', 'warnLast', 'last')]
        [string]$DefinitionPublisherConflictMode = 'fail'
    )

    $endpointInventoryInfo = Get-PackageEndpointInventoryInfo
    $publisherInventoryInfo = Get-PackagePublisherInventoryInfo
    $sourceRows = @(Get-PackageEnabledEndpointSources -EndpointInventoryDocument $endpointInventoryInfo.Document)
    $publisherRows = @(Get-PackageEnabledTrustedPublisherRows -PublisherInventoryDocument $publisherInventoryInfo.Document)

    $resolvedLocalEndpointRoot = if ([string]::IsNullOrWhiteSpace($LocalEndpointRoot)) {
        Get-PackageDefaultLocalEndpointRoot
    }
    else {
        [string]$LocalEndpointRoot
    }

    if ([string]::Equals($EndpointMaterializationMode, 'endpointFocused', [System.StringComparison]::OrdinalIgnoreCase)) {
        $count = Sync-PackageEndpointCandidateDefinitions -SourceRows $sourceRows -PublisherRows $publisherRows -ApplicationRootDirectory $ApplicationRootDirectory -LocalEndpointRoot $resolvedLocalEndpointRoot -DefinitionPublisherConflictMode $DefinitionPublisherConflictMode
        Write-PackageExecutionMessage -Message ("[STATE] Endpoint-wide definition materialization refreshed {0} Candidate definition file(s)." -f $count)
    }

    $candidates = @(Get-PackageDefinitionCandidateRows -SourceRows $sourceRows -ApplicationRootDirectory $ApplicationRootDirectory -DefinitionId $DefinitionId)
    if ($candidates.Count -eq 0) {
        $narrow = if ([string]::IsNullOrWhiteSpace($PublisherId)) { '' } else { " for publisher '$PublisherId'" }
        throw "Package definition '$DefinitionId' was not found in enabled endpoints$narrow."
    }

    $selected = Select-PackageDefinitionCandidateWinner -Candidates $candidates -PublisherRows $publisherRows -DefinitionId $DefinitionId -PublisherId $PublisherId -DefinitionPublisherConflictMode $DefinitionPublisherConflictMode
    $candidateCopy = Copy-PackageDefinitionToLocalDefinitionStore -Role 'Candidate' -SourcePath $selected.DefinitionPath -LocalEndpointRoot $resolvedLocalEndpointRoot -PublisherId $selected.PublisherId -DefinitionId $selected.DefinitionId -DefinitionRevision $selected.DefinitionRevision

    return [pscustomobject]@{
        EndpointName                  = [string]$selected.EndpointName
        DefinitionId                  = [string]$selected.DefinitionId
        DefinitionPath                = [System.IO.Path]::GetFullPath($candidateCopy.Path)
        SourceKind                    = [string]$selected.EndpointSourceKind
        SourcePath                    = [string]$selected.DefinitionPath
        SourceDefinitionScanRootPath  = [string]$selected.DefinitionScanRootPath
        SourceHash                    = [string]$selected.SourceHash
        CandidatePath                 = [System.IO.Path]::GetFullPath($candidateCopy.Path)
        CandidateHash                 = [string]$candidateCopy.Hash
        SnapshotPath                  = $null
        SnapshotHash                  = $null
        ResolvedAtUtc                 = [DateTime]::UtcNow.ToString('o')
        SnapshotFallback              = $false
        EndpointInventoryPath         = $endpointInventoryInfo.Path
        PublisherInventoryPath        = $publisherInventoryInfo.Path
        Trusted                       = $true
        PublisherTrustMode            = [string]$selected.PublisherTrustMode
        PublisherId                   = [string]$selected.PublisherId
        PublisherName                 = [string]$selected.PublisherName
        DefinitionRevision            = [int]$selected.DefinitionRevision
        PublishedAtUtc                = [string]$selected.PublishedAtUtc
        MaterializationStatus         = [string]$candidateCopy.Status
        EndpointMaterializationMode   = [string]$EndpointMaterializationMode
    }
}
