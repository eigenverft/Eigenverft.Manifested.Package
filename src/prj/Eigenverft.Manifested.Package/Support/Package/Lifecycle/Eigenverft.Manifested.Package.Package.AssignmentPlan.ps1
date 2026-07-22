<#
    Eigenverft.Manifested.Package.Package.AssignmentPlan
    Shared dependency-plan entry point and mutation-free assignment preview enrichment.
#>

function New-PackageAssignmentPlanIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Warning', 'Blocker')]
        [string]$Severity,

        [Parameter(Mandatory = $true)]
        [string]$Code,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [AllowNull()]
        [string]$NodeKey = $null,

        [AllowNull()]
        [string]$DefinitionId = $null,

        [AllowNull()]
        [string]$ArtifactFileId = $null,

        [AllowNull()]
        [string]$ExpectedDepotPath = $null
    )

    return [pscustomobject]@{
        Severity          = $Severity
        Code              = $Code
        Message           = $Message
        NodeKey           = $NodeKey
        DefinitionId      = $DefinitionId
        ArtifactFileId    = $ArtifactFileId
        ExpectedDepotPath = $ExpectedDepotPath
    }
}

function Test-PackageAssignmentArchiveEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$EntryPath,

        [AllowNull()]
        [psobject]$Verification,

        [switch]$VerifyContent
    )

    $normalizedEntryPath = $EntryPath.Replace('\', '/').TrimStart('/')
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
        try {
            $entryMatches = @($archive.Entries | Where-Object {
                    [string]::Equals($_.FullName.Replace('\', '/').TrimStart('/'), $normalizedEntryPath, [System.StringComparison]::OrdinalIgnoreCase)
                })
            if ($entryMatches.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$entryMatches[0].Name)) {
                return [pscustomobject]@{ Accepted = $false; Status = 'ArchiveEntryMissing'; Verified = $false; ExpectedHash = $null; ActualHash = $null }
            }
            if (-not $VerifyContent.IsPresent) {
                return [pscustomobject]@{ Accepted = $true; Status = 'ArchiveEntryPresentNotVerified'; Verified = $false; ExpectedHash = $null; ActualHash = $null }
            }

            $algorithm = if ($Verification -and $Verification.PSObject.Properties['algorithm']) { ([string]$Verification.algorithm).ToLowerInvariant() } else { 'sha256' }
            $expectedHash = if ($Verification -and $Verification.PSObject.Properties[$algorithm]) {
                ([string]$Verification.$algorithm).Trim().ToLowerInvariant()
            }
            elseif ($Verification -and $Verification.PSObject.Properties['value']) {
                ([string]$Verification.value).Trim().ToLowerInvariant()
            }
            else { $null }
            if ([string]::IsNullOrWhiteSpace($expectedHash)) {
                return [pscustomobject]@{ Accepted = $true; Status = 'ArchiveEntryVerificationDeferred'; Verified = $false; ExpectedHash = $null; ActualHash = $null }
            }

            $hashAlgorithm = switch -Exact ($algorithm) {
                'sha256' { [System.Security.Cryptography.SHA256]::Create(); break }
                'sha512' { [System.Security.Cryptography.SHA512]::Create(); break }
                default { $null }
            }
            if (-not $hashAlgorithm) {
                return [pscustomobject]@{ Accepted = $false; Status = 'VerificationAlgorithmUnsupported'; Verified = $false; ExpectedHash = $expectedHash; ActualHash = $null }
            }
            try {
                $stream = $entryMatches[0].Open()
                try {
                    $actualHash = (($hashAlgorithm.ComputeHash($stream) | ForEach-Object { $_.ToString('x2') }) -join '')
                }
                finally { $stream.Dispose() }
            }
            finally { $hashAlgorithm.Dispose() }

            return [pscustomobject]@{
                Accepted     = [string]::Equals($expectedHash, $actualHash, [System.StringComparison]::OrdinalIgnoreCase)
                Status       = if ([string]::Equals($expectedHash, $actualHash, [System.StringComparison]::OrdinalIgnoreCase)) { 'VerificationPassed' } else { 'VerificationFailed' }
                Verified     = $true
                ExpectedHash = $expectedHash
                ActualHash   = $actualHash
            }
        }
        finally { $archive.Dispose() }
    }
    catch {
        return [pscustomobject]@{ Accepted = $false; Status = 'ArchiveInspectionFailed'; Verified = $false; ExpectedHash = $null; ActualHash = $null; ErrorMessage = $_.Exception.Message }
    }
}

function Resolve-PackageAssignmentArtifactPreview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [psobject]$ArtifactFile,

        [Parameter(Mandatory = $true)]
        [hashtable]$Resolved,

        [Parameter(Mandatory = $true)]
        [hashtable]$Visiting,

        [switch]$VerifyDepotContent
    )

    $artifactFileId = [string]$ArtifactFile.Id
    if ($Resolved.ContainsKey($artifactFileId)) {
        return $Resolved[$artifactFileId]
    }
    if ($Visiting.ContainsKey($artifactFileId)) {
        throw "Artifact acquisition cycle encountered while planning '$artifactFileId'."
    }
    $Visiting[$artifactFileId] = $true

    $candidatePreviews = New-Object System.Collections.Generic.List[object]
    $selectedCandidate = $null
    $availablePath = $null
    $fileStatus = 'Missing'
    foreach ($candidate in @($ArtifactFile.AcquisitionPlan.Candidates)) {
        $kind = [string]$candidate.kind
        $candidatePreview = $null
        switch -Exact ($kind) {
            'packageDepot' {
                $sourceId = if ($candidate.sourceRef) { [string]$candidate.sourceRef.id } else { $null }
                $resolvedPath = $null
                $exists = $false
                $verification = $null
                try {
                    $source = Get-PackageSourceDefinition -PackageConfig $PackageResult.PackageConfig -SourceRef $candidate.sourceRef
                    if (-not [string]::IsNullOrWhiteSpace([string]$source.BasePath)) {
                        $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path ([string]$source.BasePath) ([string]$candidate.sourcePath)))
                        $exists = Test-Path -LiteralPath $resolvedPath -PathType Leaf
                    }
                    if ($exists -and $VerifyDepotContent.IsPresent) {
                        $verification = Test-PackageSavedFile -Path $resolvedPath -Verification $candidate.verification
                    }
                }
                catch {
                    $candidatePreview = [pscustomobject]@{
                        Kind = $kind; SourceId = $sourceId; Source = $resolvedPath; Reachability = 'Local'; Status = 'InvalidSource'
                        Exists = $false; Verification = $null; ErrorMessage = $_.Exception.Message
                    }
                }
                if (-not $candidatePreview) {
                    $accepted = $exists -and ((-not $VerifyDepotContent.IsPresent) -or [bool]$verification.Accepted)
                    $candidatePreview = [pscustomobject]@{
                        Kind = $kind; SourceId = $sourceId; Source = $resolvedPath; Reachability = 'Local'
                        Status = if (-not $exists) { 'Missing' } elseif ($VerifyDepotContent.IsPresent -and -not $verification.Accepted) { 'Invalid' } elseif ($VerifyDepotContent.IsPresent) { 'Verified' } else { 'PresentNotVerified' }
                        Exists = $exists; Verification = $verification; ErrorMessage = $null
                    }
                    if ($accepted -and -not $selectedCandidate) {
                        $selectedCandidate = $candidatePreview
                        $availablePath = $resolvedPath
                        $fileStatus = 'Available'
                    }
                }
            }
            'vendorDownload' {
                $sourceId = if ($candidate.sourceRef) { [string]$candidate.sourceRef.id } else { 'directDownload' }
                $sourceText = if (-not [string]::IsNullOrWhiteSpace([string]$candidate.url)) { [string]$candidate.url } else { [string]$candidate.sourcePath }
                $candidatePreview = [pscustomobject]@{
                    Kind = $kind; SourceId = $sourceId; Source = $sourceText; Reachability = 'NotTested'; Status = 'ResolvableOnline'
                    Exists = $null; Verification = $candidate.verification; ErrorMessage = $null
                }
                if (-not $selectedCandidate) {
                    $selectedCandidate = $candidatePreview
                    $fileStatus = 'ResolvableOnline'
                }
            }
            'archiveEntry' {
                $sourceArtifact = Get-PackageArtifactFileResult -PackageResult $PackageResult -ArtifactFileId ([string]$candidate.sourceArtifactFileId)
                $sourcePreview = if ($sourceArtifact) {
                    Resolve-PackageAssignmentArtifactPreview -PackageResult $PackageResult -ArtifactFile $sourceArtifact -Resolved $Resolved -Visiting $Visiting -VerifyDepotContent:$VerifyDepotContent
                }
                else { $null }
                $entryCheck = $null
                if ($sourcePreview -and -not [string]::IsNullOrWhiteSpace([string]$sourcePreview.AvailablePath)) {
                    $entryCheck = Test-PackageAssignmentArchiveEntry -ArchivePath ([string]$sourcePreview.AvailablePath) -EntryPath ([string]$candidate.entryPath) -Verification $candidate.verification -VerifyContent:$VerifyDepotContent
                }
                $sourceFeasible = $sourcePreview -and [string]$sourcePreview.Status -in @('Available', 'ResolvableOnline', 'Derivable')
                $accepted = $sourceFeasible -and ((-not $entryCheck) -or [bool]$entryCheck.Accepted)
                $candidatePreview = [pscustomobject]@{
                    Kind = $kind; SourceId = [string]$candidate.sourceArtifactFileId; Source = [string]$candidate.entryPath
                    Reachability = if ($entryCheck) { 'LocalArchive' } else { 'DependsOnArtifact' }
                    Status = if (-not $sourceArtifact) { 'MissingSourceArtifact' } elseif (-not $sourceFeasible) { 'SourceArtifactUnavailable' } elseif ($entryCheck -and -not $entryCheck.Accepted) { [string]$entryCheck.Status } elseif ($entryCheck) { [string]$entryCheck.Status } else { 'Derivable' }
                    Exists = if ($entryCheck) { [bool]$entryCheck.Accepted } else { $null }; Verification = $entryCheck; ErrorMessage = if ($entryCheck -and $entryCheck.PSObject.Properties['ErrorMessage']) { [string]$entryCheck.ErrorMessage } else { $null }
                }
                if ($accepted -and -not $selectedCandidate) {
                    $selectedCandidate = $candidatePreview
                    $fileStatus = 'Derivable'
                }
            }
            default {
                $candidatePreview = [pscustomobject]@{
                    Kind = $kind; SourceId = $null; Source = $null; Reachability = 'Unknown'; Status = 'Unsupported'
                    Exists = $null; Verification = $null; ErrorMessage = "Unsupported artifact acquisition candidate kind '$kind'."
                }
            }
        }
        $candidatePreviews.Add($candidatePreview) | Out-Null
    }

    if ($PackageResult.Offline) {
        foreach ($rawCandidate in @($ArtifactFile.AcquisitionCandidates | Where-Object { [string]$_.kind -notin @('packageDepot', 'archiveEntry') })) {
            $candidatePreviews.Add([pscustomobject]@{
                    Kind = [string]$rawCandidate.kind
                    SourceId = if ($rawCandidate.PSObject.Properties['sourceId']) { [string]$rawCandidate.sourceId } else { 'directDownload' }
                    Source = if ($rawCandidate.PSObject.Properties['url']) { [string]$rawCandidate.url } elseif ($rawCandidate.PSObject.Properties['sourcePath']) { [string]$rawCandidate.sourcePath } else { $null }
                    Reachability = 'DisabledOffline'; Status = 'DisabledOffline'; Exists = $null; Verification = $rawCandidate.verification; ErrorMessage = $null
                }) | Out-Null
        }
    }

    $preview = [pscustomobject]@{
        Id                = $artifactFileId
        RelativePath      = [string]$ArtifactFile.RelativePath
        ExpectedDepotPath = [string]$ArtifactFile.DefaultDepotPath
        StagingPath       = [string]$ArtifactFile.StagingPath
        Status            = $fileStatus
        Ready             = [bool]$selectedCandidate
        AvailablePath     = $availablePath
        SelectedCandidate = $selectedCandidate
        Candidates        = @($candidatePreviews.ToArray())
    }
    $Resolved[$artifactFileId] = $preview
    $Visiting.Remove($artifactFileId)
    return $preview
}

function Get-PackageAssignmentPlannedAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$ArtifactFiles,

        [AllowNull()]
        [psobject]$NpmMaterialization,

        [switch]$MaterializeOnly
    )

    if ($MaterializeOnly.IsPresent) {
        $artifactWorkRequired = @($ArtifactFiles | Where-Object { [string]$_.Status -ne 'Available' }).Count -gt 0
        $npmWorkRequired = $NpmMaterialization -and [string]$NpmMaterialization.Status -ne 'Available'
        return $(if ($artifactWorkRequired -or $npmWorkRequired) { 'Materialize' } else { 'NoChange' })
    }
    if ($PackageResult.Assigned -and [string]::Equals([string]$PackageResult.Assigned.Status, 'AlreadySatisfied', [System.StringComparison]::OrdinalIgnoreCase)) {
        return 'NoChange'
    }
    if (-not $PackageResult.ExistingPackage) {
        return 'Install'
    }

    switch -Exact ([string]$PackageResult.ExistingPackage.Decision) {
        'ReusePackageOwned' { return 'Reuse' }
        'AdoptExternal' { return 'Adopt' }
        'ReplacePackageOwnedInstall' { return 'Replace' }
        'UpgradeAdoptedInstall' { return 'Replace' }
        'ExistingInstallReadinessFailed' {
            if ([string]::Equals([string]$PackageResult.ExistingPackage.SearchKind, 'packageTargetInstallPath', [System.StringComparison]::OrdinalIgnoreCase)) { return 'Repair' }
            return 'Install'
        }
        default { return 'Install' }
    }
}

function ConvertTo-PackageAssignmentNextCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$DefinitionId,

        [AllowNull()]
        [string]$PublisherId,

        [AllowNull()]
        [string]$PackageVersion,

        [switch]$Offline,

        [switch]$MaterializeOnly
    )

    $quotedIds = @($DefinitionId | ForEach-Object { "'{0}'" -f (([string]$_).Replace("'", "''")) }) -join ','
    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add('Invoke-Package') | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($PublisherId)) {
        $parts.Add(("-PublisherId '{0}'" -f $PublisherId.Replace("'", "''"))) | Out-Null
    }
    $parts.Add("-DefinitionId $quotedIds") | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($PackageVersion)) {
        $parts.Add(("-PackageVersion '{0}'" -f $PackageVersion.Replace("'", "''"))) | Out-Null
    }
    if ($Offline.IsPresent) { $parts.Add('-Offline') | Out-Null }
    if ($MaterializeOnly.IsPresent) { $parts.Add('-MaterializeOnly') | Out-Null }
    return ($parts -join ' ')
}

function New-PackageAssignmentPlanCore {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$PublisherId = $null,

        [Parameter(Mandatory = $true)]
        [string[]]$DefinitionId,

        [AllowNull()]
        [string]$PackageVersion = $null,

        [bool]$PackageVersionOverrideSpecified = $false,

        [ValidateSet('Execution', 'Inspection')]
        [string]$Purpose = 'Execution',

        [switch]$AcceptUnknownSigningKey,

        [switch]$RequireAlreadyTrusted,

        [switch]$Offline,

        [switch]$MaterializeOnly,

        [switch]$VerifyDepotContent
    )

    $dependencyPlan = New-PackageDependencyPlan -PublisherId $PublisherId -DefinitionId $DefinitionId -DesiredState 'Assigned' -PackageVersion $PackageVersion -PackageVersionOverrideSpecified $PackageVersionOverrideSpecified -AcceptUnknownSigningKey:$AcceptUnknownSigningKey -RequireAlreadyTrusted:$RequireAlreadyTrusted -InspectionOnly:([string]::Equals($Purpose, 'Inspection', [System.StringComparison]::OrdinalIgnoreCase))
    if ([string]::Equals($Purpose, 'Execution', [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ DependencyPlan = $dependencyPlan; Purpose = 'Execution'; MutationFree = $false }
    }

    $warnings = New-Object System.Collections.Generic.List[object]
    $blockers = New-Object System.Collections.Generic.List[object]
    $trustActions = New-Object System.Collections.Generic.List[object]
    foreach ($violation in @(ConvertTo-PackageDependencyPlanArray -Value $dependencyPlan.Violations)) {
        $violationCode = [string]$violation.Reason
        if ([string]::Equals($violationCode, 'DependencyDefinitionNotFound', [System.StringComparison]::OrdinalIgnoreCase) -and
            [string]$violation.Message -match 'catalog trust') {
            $violationCode = 'DefinitionTrustRejected'
        }
        $blockers.Add((New-PackageAssignmentPlanIssue -Severity Blocker -Code $violationCode -Message ([string]$violation.Message) -NodeKey ([string]$violation.NodeKey) -DefinitionId ([string]$violation.DefinitionId))) | Out-Null
    }

    $nodePreviews = New-Object System.Collections.Generic.List[object]
    foreach ($node in @(ConvertTo-PackageDependencyPlanArray -Value $dependencyPlan.Nodes)) {
        $nodeWarnings = New-Object System.Collections.Generic.List[object]
        $nodeBlockers = New-Object System.Collections.Generic.List[object]
        $config = $node.PackageConfig
        $trustStatus = [string]$config.DefinitionCatalogTrustStatus
        if ($trustStatus -in @('signedUnknownKeyPrompt', 'signedUnknownKeyAutoTrust')) {
            $trustAction = [pscustomobject]@{
                Action             = 'TrustSigningKey'
                PublisherId        = [string]$node.PublisherId
                DefinitionId       = [string]$node.DefinitionId
                KeyThumbprint      = [string]$config.DefinitionSignatureKeyThumbprint
                SignerDisplayName  = [string]$config.DefinitionSignatureSignerDisplayName
                RecommendedCommand = "Import-PackageTrust -Path '<public-signing-cert.cer>'"
            }
            $trustActions.Add($trustAction) | Out-Null
            if ($AcceptUnknownSigningKey.IsPresent) {
                $nodeWarnings.Add((New-PackageAssignmentPlanIssue -Severity Warning -Code 'DefinitionTrustWillBeAccepted' -Message "Definition '$($node.DefinitionId)' has a valid signature from an unknown signing key that this invocation explicitly accepts." -NodeKey ([string]$node.NodeKey) -DefinitionId ([string]$node.DefinitionId))) | Out-Null
            }
            else {
                $nodeBlockers.Add((New-PackageAssignmentPlanIssue -Severity Blocker -Code 'DefinitionTrustRequired' -Message "Definition '$($node.DefinitionId)' has a valid signature from an unknown signing key and requires an explicit trust action." -NodeKey ([string]$node.NodeKey) -DefinitionId ([string]$node.DefinitionId))) | Out-Null
            }
        }
        elseif ([string]::Equals($trustStatus, 'unsignedConfigTrust', [System.StringComparison]::OrdinalIgnoreCase)) {
            $nodeWarnings.Add((New-PackageAssignmentPlanIssue -Severity Warning -Code 'UnsignedDefinitionAllowed' -Message "Definition '$($node.DefinitionId)' is unsigned and allowed by configured catalog policy." -NodeKey ([string]$node.NodeKey) -DefinitionId ([string]$node.DefinitionId))) | Out-Null
        }
        elseif (-not [string]::Equals($trustStatus, 'signedTrusted', [System.StringComparison]::OrdinalIgnoreCase)) {
            $nodeBlockers.Add((New-PackageAssignmentPlanIssue -Severity Blocker -Code 'DefinitionTrustRejected' -Message "Definition '$($node.DefinitionId)' has catalog trust status '$trustStatus'." -NodeKey ([string]$node.NodeKey) -DefinitionId ([string]$node.DefinitionId))) | Out-Null
        }

        $artifactPreviews = @()
        $npmPreview = $null
        $packageResult = $null
        $plannedAction = 'Blocked'
        try {
            $isRoot = @($dependencyPlan.Roots | Where-Object { [string]::Equals([string]$_.NodeKey, [string]$node.NodeKey, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
            $resultParams = @{
                DesiredState    = 'Assigned'
                CommandMode     = if ($MaterializeOnly.IsPresent) { 'MaterializeOnly' } else { 'Assigned' }
                Offline         = $Offline
                MaterializeOnly = $MaterializeOnly
                PackageConfig   = $config
            }
            if ($isRoot -and $PackageVersionOverrideSpecified) { $resultParams.PackageVersionSelector = $PackageVersion }
            $packageResult = New-PackageResult @resultParams
            if (-not [string]::IsNullOrWhiteSpace([string]$node.VersionRange)) {
                $packageResult | Add-Member -MemberType NoteProperty -Name PackageVersionRange -Value ([string]$node.VersionRange) -Force
            }
            $packageResult = Resolve-PackagePackage -PackageResult $packageResult
            if (-not [string]::Equals([string]$packageResult.PackageVersion, [string]$node.PackageVersion, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Preview selected version '$($packageResult.PackageVersion)' but dependency planning selected '$($node.PackageVersion)'."
            }
            $packageResult = Resolve-PackagePaths -PackageResult $packageResult
            $packageResult = Build-PackageAcquisitionPlan -PackageResult $packageResult

            $resolvedArtifacts = @{}
            $visitingArtifacts = @{}
            $verifyContent = $Offline.IsPresent -or $VerifyDepotContent.IsPresent
            $artifactPreviews = @(
                foreach ($artifactFile in @($packageResult.ArtifactFiles)) {
                    Resolve-PackageAssignmentArtifactPreview -PackageResult $packageResult -ArtifactFile $artifactFile -Resolved $resolvedArtifacts -Visiting $visitingArtifacts -VerifyDepotContent:$verifyContent
                }
            )
            foreach ($artifactPreview in @($artifactPreviews | Where-Object { -not $_.Ready })) {
                $nodeBlockers.Add((New-PackageAssignmentPlanIssue -Severity Blocker -Code 'ArtifactFileUnavailable' -Message "Artifact file '$($artifactPreview.Id)' for definition '$($node.DefinitionId)' has no feasible source in the selected mode." -NodeKey ([string]$node.NodeKey) -DefinitionId ([string]$node.DefinitionId) -ArtifactFileId ([string]$artifactPreview.Id) -ExpectedDepotPath ([string]$artifactPreview.ExpectedDepotPath))) | Out-Null
            }

            if (Test-PackageNpmMaterializedInstallKind -Package $packageResult.Package) {
                $packageSpec = Get-PackageNpmResolvedPackageSpec -PackageResult $packageResult
                $npmMaterialization = Find-PackageNpmMaterializationInDepots -PackageResult $packageResult
                $expectedDirectories = @(
                    foreach ($depotSource in @(Get-PackagePackageDepotSources -PackageConfig $packageResult.PackageConfig)) {
                        if (-not [string]::IsNullOrWhiteSpace([string]$depotSource.basePath)) {
                            [System.IO.Path]::GetFullPath((Join-Path ([string]$depotSource.basePath) ([string]$packageResult.PackageDepotRelativeDirectory)))
                        }
                    }
                )
                $npmPreview = [pscustomobject]@{
                    PackageSpec = $packageSpec
                    Status = if ($npmMaterialization) { 'Available' } elseif ($Offline.IsPresent) { 'Missing' } else { 'ResolvableOnline' }
                    Reachability = if ($npmMaterialization) { 'Local' } elseif ($Offline.IsPresent) { 'DisabledOffline' } else { 'NotTested' }
                    SourceId = if ($npmMaterialization) { [string]$npmMaterialization.SourceId } else { 'npmRegistry' }
                    SourceDirectory = if ($npmMaterialization) { [string]$npmMaterialization.SourceDirectory } else { $null }
                    ExpectedDepotDirectories = @($expectedDirectories)
                }
                if ($Offline.IsPresent -and -not $npmMaterialization) {
                    $nodeBlockers.Add((New-PackageAssignmentPlanIssue -Severity Blocker -Code 'NpmMaterializationUnavailable' -Message "npm materialization '$packageSpec' for definition '$($node.DefinitionId)' is missing from every configured depot." -NodeKey ([string]$node.NodeKey) -DefinitionId ([string]$node.DefinitionId) -ExpectedDepotPath (@($expectedDirectories) -join '; '))) | Out-Null
                }
            }

            if (-not $MaterializeOnly.IsPresent) {
                $packageResult = Resolve-PackagePreAssignmentSatisfaction -PackageResult $packageResult
                $packageResult = Find-PackageExistingPackage -PackageResult $packageResult
                $packageResult = Set-PackageExistingPackage -PackageResult $packageResult
                $packageResult = Resolve-PackageExistingPackageDecision -PackageResult $packageResult
            }
            foreach ($compatibilityCheck in @($packageResult.Compatibility | Where-Object { -not $_.Accepted -and [string]$_.OnFail -eq 'warn' })) {
                $nodeWarnings.Add((New-PackageAssignmentPlanIssue -Severity Warning -Code 'CompatibilityWarning' -Message "Compatibility check '$($compatibilityCheck.Kind)' warned for definition '$($node.DefinitionId)'." -NodeKey ([string]$node.NodeKey) -DefinitionId ([string]$node.DefinitionId))) | Out-Null
            }
            $plannedAction = Get-PackageAssignmentPlannedAction -PackageResult $packageResult -ArtifactFiles $artifactPreviews -NpmMaterialization $npmPreview -MaterializeOnly:$MaterializeOnly
        }
        catch {
            $nodeBlockers.Add((New-PackageAssignmentPlanIssue -Severity Blocker -Code 'NodePreviewFailed' -Message $_.Exception.Message -NodeKey ([string]$node.NodeKey) -DefinitionId ([string]$node.DefinitionId))) | Out-Null
        }

        foreach ($issue in @($nodeWarnings.ToArray())) { $warnings.Add($issue) | Out-Null }
        foreach ($issue in @($nodeBlockers.ToArray())) { $blockers.Add($issue) | Out-Null }
        $nodeStatus = if ($nodeBlockers.Count -gt 0) { 'Blocked' } elseif ($nodeWarnings.Count -gt 0) { 'ReadyWithWarnings' } else { 'Ready' }
        $selectedPackage = if ($packageResult -and $packageResult.Package) { $packageResult.Package } else { $node.Package }
        $install = if ($selectedPackage) { Get-PackageAssignedInstallOperation -Release $selectedPackage } else { $null }
        $nodePreviews.Add([pscustomobject]@{
                NodeKey                     = [string]$node.NodeKey
                IsRoot                      = [bool]$node.IsRoot
                PublisherId                 = [string]$node.PublisherId
                DefinitionId                = [string]$node.DefinitionId
                DefinitionRevision          = [int]$node.DefinitionRevision
                DefinitionHash              = [string]$config.DefinitionSourceHash
                DefinitionPath              = [string]$config.DefinitionPath
                DefinitionEndpointName      = [string]$node.DefinitionEndpointName
                CatalogTrustStatus           = $trustStatus
                SignatureStatus              = [string]$config.DefinitionSignatureStatus
                PackageId                    = [string]$node.PackageId
                Version                      = [string]$node.PackageVersion
                ArtifactTargetId             = if ($selectedPackage) { [string]$selectedPackage.artifactTargetId } else { $null }
                ReleaseTrack                 = [string]$node.ReleaseTrack
                ArtifactDistributionVariant = [string]$node.ArtifactDistributionVariant
                InstallKind                  = if ($install) { [string]$install.kind } else { $null }
                PlannedAction                = $plannedAction
                Status                       = $nodeStatus
                ExistingInstall              = if ($packageResult) { $packageResult.ExistingPackage } else { $null }
                Ownership                    = if ($packageResult) { $packageResult.Ownership } else { $null }
                ArtifactStagingDirectory     = if ($packageResult) { [string]$packageResult.ArtifactStagingDirectory } else { $null }
                OperationArtifactFilePath    = if ($packageResult) { [string]$packageResult.OperationArtifactFilePath } else { $null }
                ArtifactFiles                = @($artifactPreviews)
                NpmMaterialization           = $npmPreview
                Warnings                     = @($nodeWarnings.ToArray())
                Blockers                     = @($nodeBlockers.ToArray())
            }) | Out-Null
    }

    $nodes = @($nodePreviews.ToArray())
    $rootPreviews = @(
        foreach ($root in @(ConvertTo-PackageDependencyPlanArray -Value $dependencyPlan.Roots)) {
            $nodePreview = @($nodes | Where-Object { [string]::Equals([string]$_.NodeKey, [string]$root.NodeKey, [System.StringComparison]::OrdinalIgnoreCase) }) | Select-Object -First 1
            [pscustomobject]@{
                RequestedPublisherId  = [string]$root.RequestedPublisherId
                RequestedDefinitionId = [string]$root.RequestedDefinitionId
                NodeKey               = [string]$root.NodeKey
                PublisherId           = if ($nodePreview) { [string]$nodePreview.PublisherId } else { [string]$root.PublisherId }
                DefinitionId          = if ($nodePreview) { [string]$nodePreview.DefinitionId } else { [string]$root.DefinitionId }
                Version               = if ($nodePreview) { [string]$nodePreview.Version } else { $null }
                PlannedAction         = if ($nodePreview) { [string]$nodePreview.PlannedAction } else { 'Blocked' }
                Status                = if ($nodePreview) { [string]$nodePreview.Status } else { 'Blocked' }
            }
        }
    )
    $status = if ($blockers.Count -gt 0) { 'Blocked' } elseif ($warnings.Count -gt 0) { 'ReadyWithWarnings' } else { 'Ready' }
    return [pscustomobject]@{
        PSTypeName      = 'Eigenverft.Manifested.Package.AssignmentPlan'
        CreatedAtUtc    = [DateTime]::UtcNow.ToString('o')
        Status          = $status
        Accepted        = $blockers.Count -eq 0
        Mode            = if ($MaterializeOnly.IsPresent) { 'MaterializeOnly' } else { 'Assigned' }
        Offline         = [bool]$Offline
        MutationFree    = $true
        VerifyDepotContent = [bool]($Offline.IsPresent -or $VerifyDepotContent.IsPresent)
        Roots           = @($rootPreviews)
        Nodes           = @($nodes)
        Edges           = @(ConvertTo-PackageDependencyPlanArray -Value $dependencyPlan.Edges)
        Warnings        = @($warnings.ToArray())
        Blockers        = @($blockers.ToArray())
        TrustActions    = @($trustActions.ToArray())
        NextCommand     = ConvertTo-PackageAssignmentNextCommand -DefinitionId $DefinitionId -PublisherId $PublisherId -PackageVersion $PackageVersion -Offline:$Offline -MaterializeOnly:$MaterializeOnly
        DependencyPlan  = $dependencyPlan
    }
}
