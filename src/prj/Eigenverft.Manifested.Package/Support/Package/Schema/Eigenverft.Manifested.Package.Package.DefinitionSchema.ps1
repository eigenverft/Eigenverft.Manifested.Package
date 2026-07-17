<#
    Eigenverft.Manifested.Package.Package.DefinitionSchema
    Package definition JSON validation for package definition wire models.

    Runtime validation is PowerShell-only (this module + DefinitionSchema.Wire2_0.ps1). The JSON schema file
    is the editor/agent contract (canonical examples under Endpoint/Defaults); keep schema and asserts aligned.
    Schema 2.0 root description and x-eigenverftAgentHint tell LLMs to author kind=unsigned drafts first and run
    Sign-PackageDefinition after content is final; runtime ignores those hints.
#>

$script:PackageDefinitionSupportedSchemaVersions = @(
    '2.0'
)

function Assert-PackageDefinitionSchemaVersionSupported {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SchemaVersionText,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionDocumentPath
    )

    foreach ($supported in $script:PackageDefinitionSupportedSchemaVersions) {
        if ([string]::Equals($SchemaVersionText, $supported, [System.StringComparison]::Ordinal)) {
            return
        }
    }

    if ([string]::Equals($SchemaVersionText, '1.9', [System.StringComparison]::Ordinal)) {
        throw "Package definition '$DefinitionDocumentPath' uses schemaVersion '1.9'. Schema 2.0 is a breaking artifact-file-set contract and requires manual migration; automatic conversion is not supported."
    }
    $supportedList = ($script:PackageDefinitionSupportedSchemaVersions | ForEach-Object { "'$_'" }) -join ', '
    throw "Package definition '$DefinitionDocumentPath' uses unsupported schemaVersion '$SchemaVersionText'. Supported schemaVersion values are $supportedList."
}

function Assert-PackageDefinitionSignatureSchema_2_0 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DefinitionDocumentInfo,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId
    )

    $definition = $DefinitionDocumentInfo.Document
    $publication = $definition.definitionPublication
    if (-not $publication.PSObject.Properties['definitionSignature'] -or -not $publication.definitionSignature) {
        throw "Package definition '$DefinitionId' schemaVersion 2.0 is missing definitionPublication.definitionSignature."
    }

    $signature = $publication.definitionSignature
    foreach ($requiredProperty in @('kind', 'format', 'signedContent')) {
        if (-not $signature.PSObject.Properties[$requiredProperty] -or [string]::IsNullOrWhiteSpace([string]$signature.$requiredProperty)) {
            throw "Package definition '$DefinitionId' definitionSignature is missing '$requiredProperty'."
        }
    }

    $kind = [string]$signature.kind
    if ($kind -notin @('signed', 'unsigned')) {
        throw "Package definition '$DefinitionId' definitionSignature.kind must be signed or unsigned."
    }
    if (-not [string]::Equals([string]$signature.format, $script:PackageDefinitionSignatureFormat, [System.StringComparison]::Ordinal)) {
        throw "Package definition '$DefinitionId' definitionSignature.format must be '$script:PackageDefinitionSignatureFormat'."
    }
    if (-not [string]::Equals([string]$signature.signedContent, $script:PackageDefinitionSignedContentKind, [System.StringComparison]::Ordinal)) {
        throw "Package definition '$DefinitionId' definitionSignature.signedContent must be '$script:PackageDefinitionSignedContentKind'."
    }

    if ([string]::Equals($kind, 'unsigned', [System.StringComparison]::OrdinalIgnoreCase)) {
        if ($signature.PSObject.Properties['signatureValue'] -and -not [string]::IsNullOrWhiteSpace([string]$signature.signatureValue)) {
            throw "Package definition '$DefinitionId' unsigned definitionSignature must not define signatureValue."
        }
        if ($signature.PSObject.Properties['certificatePem'] -and -not [string]::IsNullOrWhiteSpace([string]$signature.certificatePem)) {
            throw "Package definition '$DefinitionId' unsigned definitionSignature must not define certificatePem."
        }
        return
    }

    foreach ($requiredSignedProperty in @('keyThumbprint', 'signerDisplayName', 'signedAtUtc', 'signatureValue')) {
        if (-not $signature.PSObject.Properties[$requiredSignedProperty] -or [string]::IsNullOrWhiteSpace([string]$signature.$requiredSignedProperty)) {
            throw "Package definition '$DefinitionId' signed definitionSignature is missing '$requiredSignedProperty'."
        }
    }
    if (([string]$signature.keyThumbprint) -notmatch '^[A-Fa-f0-9]{40,128}$') {
        throw "Package definition '$DefinitionId' signed definitionSignature.keyThumbprint is not a hex thumbprint."
    }
    if ($signature.PSObject.Properties['certificatePem'] -and [string]::IsNullOrWhiteSpace([string]$signature.certificatePem)) {
        throw "Package definition '$DefinitionId' signed definitionSignature.certificatePem must not be empty."
    }
    try {
        [Convert]::FromBase64String([string]$signature.signatureValue) | Out-Null
    }
    catch {
        throw "Package definition '$DefinitionId' signed definitionSignature.signatureValue must be base64."
    }
}

function Assert-PackageDefinitionAcquisitionCandidateKind_2_0 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [Parameter(Mandatory = $true)]
        [psobject]$Candidate,

        [Parameter(Mandatory = $true)]
        [string]$CandidatePath
    )

    $kind = if ($Candidate.PSObject.Properties['kind']) { [string]$Candidate.kind } else { $null }
    if ([string]::IsNullOrWhiteSpace($kind)) {
        throw "Package definition '$DefinitionId' schemaVersion 2.0 acquisition candidate '$CandidatePath' is missing kind."
    }

    switch -Exact ($kind) {
        'packageDepot' { return }
        'vendorDownload' { return }
        'archiveEntry' { return }
        'download' {
            throw "Package definition '$DefinitionId' schemaVersion 2.0 acquisition candidate '$CandidatePath' uses retired kind 'download'. Use 'vendorDownload'."
        }
        'filesystem' {
            throw "Package definition '$DefinitionId' schemaVersion 2.0 acquisition candidate '$CandidatePath' uses retired package-definition kind 'filesystem'. Use packageDepot with PackageDepotInventory.json depot sources."
        }
        default {
            throw "Package definition '$DefinitionId' schemaVersion 2.0 acquisition candidate '$CandidatePath' uses unsupported kind '$kind'. Use packageDepot, vendorDownload, or archiveEntry."
        }
    }
}

function Assert-PackageDefinitionVendorDownloadCandidate_2_0 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [Parameter(Mandatory = $true)]
        [psobject]$VersionEntry,

        [Parameter(Mandatory = $true)]
        [string]$TargetId,

        [Parameter(Mandatory = $true)]
        [string]$ArtifactFileId,

        [Parameter(Mandatory = $true)]
        [psobject]$ArtifactFile,

        [Parameter(Mandatory = $true)]
        [psobject]$Candidate
    )

    if (-not [string]::Equals([string]$Candidate.kind, 'vendorDownload', [System.StringComparison]::OrdinalIgnoreCase)) {
        return
    }

    $releaseLabel = [string]$VersionEntry.version
    $hasSourceId = Test-PackageDefinitionTextPropertyPresent_2_0 -InputObject $Candidate -PropertyName 'sourceId'
    $hasCandidateSourcePath = Test-PackageDefinitionTextPropertyPresent_2_0 -InputObject $Candidate -PropertyName 'sourcePath'
    $hasArtifactSourcePath = Test-PackageDefinitionTextPropertyPresent_2_0 -InputObject $ArtifactFile -PropertyName 'sourcePath'
    $hasCandidateUrl = Test-PackageDefinitionTextPropertyPresent_2_0 -InputObject $Candidate -PropertyName 'url'
    $hasCandidateUrlTemplate = Test-PackageDefinitionTextPropertyPresent_2_0 -InputObject $Candidate -PropertyName 'urlTemplate'
    $hasArtifactUrl = Test-PackageDefinitionTextPropertyPresent_2_0 -InputObject $ArtifactFile -PropertyName 'url'
    $hasArtifactUrlTemplate = Test-PackageDefinitionTextPropertyPresent_2_0 -InputObject $ArtifactFile -PropertyName 'urlTemplate'
    $directDownloadCount = 0
    foreach ($hasDirectDownload in @($hasCandidateUrl, $hasCandidateUrlTemplate, $hasArtifactUrl, $hasArtifactUrlTemplate)) {
        if ($hasDirectDownload) {
            $directDownloadCount++
        }
    }

    if ($directDownloadCount -gt 1) {
        throw "Package definition '$DefinitionId' release '$releaseLabel' artifact '$TargetId' file '$ArtifactFileId' vendorDownload candidate must define only one direct url/urlTemplate location."
    }
    if ($directDownloadCount -gt 0 -and ($hasSourceId -or $hasCandidateSourcePath -or $hasArtifactSourcePath)) {
        throw "Package definition '$DefinitionId' release '$releaseLabel' artifact '$TargetId' file '$ArtifactFileId' vendorDownload candidate must use either direct url/urlTemplate or sourceId with sourcePath, not both."
    }
    if ($directDownloadCount -gt 0) {
        return
    }
    if (-not $hasSourceId) {
        throw "Package definition '$DefinitionId' release '$releaseLabel' artifact '$TargetId' file '$ArtifactFileId' vendorDownload candidate requires sourceId, direct url, or urlTemplate."
    }
    if (-not (Test-PackageObjectHasProperty -InputObject $Definition.artifacts.sources -Name ([string]$Candidate.sourceId))) {
        throw "Package definition '$DefinitionId' release '$releaseLabel' artifact '$TargetId' file '$ArtifactFileId' references unknown artifacts source '$($Candidate.sourceId)'."
    }

    $releaseUpstream = if ($VersionEntry.PSObject.Properties['upstreamRelease']) { $VersionEntry.upstreamRelease } else { $null }
    $candidateSource = Get-PackageObjectPropertyValue -InputObject $Definition.artifacts.sources -Name ([string]$Candidate.sourceId)
    if ($candidateSource -and [string]::Equals([string]$candidateSource.kind, 'githubRelease', [System.StringComparison]::OrdinalIgnoreCase)) {
        if (-not $releaseUpstream -or -not $releaseUpstream.PSObject.Properties['sourceId'] -or [string]::IsNullOrWhiteSpace([string]$releaseUpstream.sourceId) -or
            -not [string]::Equals([string]$releaseUpstream.sourceId, [string]$Candidate.sourceId, [System.StringComparison]::OrdinalIgnoreCase) -or
            -not $releaseUpstream.PSObject.Properties['releaseTag'] -or [string]::IsNullOrWhiteSpace([string]$releaseUpstream.releaseTag)) {
            throw "Package definition '$DefinitionId' release '$releaseLabel' artifact '$TargetId' file '$ArtifactFileId' requires releaseTag because candidate '$($Candidate.sourceId)' uses GitHub release."
        }
        return
    }

    if (-not ($hasCandidateSourcePath -or $hasArtifactSourcePath)) {
        throw "Package definition '$DefinitionId' release '$releaseLabel' artifact '$TargetId' file '$ArtifactFileId' vendorDownload candidate requires sourcePath, file sourcePath, url, or urlTemplate."
    }
}

function Assert-PackageDefinitionAcquisitionVocabulary_2_0 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DefinitionDocumentInfo,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId
    )

    $definition = $DefinitionDocumentInfo.Document
    $targetsById = @{}
    foreach ($target in @($definition.artifacts.targets)) {
        if ($target -and $target.PSObject.Properties['id']) {
            $targetsById[[string]$target.id] = $target
        }
        if (-not $target.PSObject.Properties['artifactFiles'] -or -not $target.artifactFiles) {
            continue
        }
        foreach ($fileProperty in @($target.artifactFiles.PSObject.Properties)) {
            $candidateIndex = 0
            foreach ($candidate in @($fileProperty.Value.acquisitionCandidates)) {
                Assert-PackageDefinitionAcquisitionCandidateKind_2_0 -DefinitionId $DefinitionId -Candidate $candidate -CandidatePath ("artifacts.targets['{0}'].artifactFiles['{1}'].acquisitionCandidates[{2}]" -f [string]$target.id, [string]$fileProperty.Name, $candidateIndex)
                $candidateIndex++
            }
        }
    }

    foreach ($versionEntry in @($definition.artifacts.releases)) {
        foreach ($artifactProperty in @($versionEntry.targetArtifacts.PSObject.Properties)) {
            $targetId = [string]$artifactProperty.Name
            $artifact = $artifactProperty.Value
            if (-not $artifact.PSObject.Properties['artifactFiles'] -or -not $artifact.artifactFiles) {
                continue
            }
            $target = $targetsById[$targetId]
            foreach ($releaseFileProperty in @($artifact.artifactFiles.PSObject.Properties)) {
                $fileId = [string]$releaseFileProperty.Name
                $releaseFile = $releaseFileProperty.Value
                $targetFileProperty = Get-PackageArtifactFileProperty_2_0 -ArtifactFiles $target.artifactFiles -ArtifactFileId $fileId
                $effectiveCandidates = if ($releaseFile.PSObject.Properties['acquisitionCandidates']) { @($releaseFile.acquisitionCandidates) } else { @($targetFileProperty.Value.acquisitionCandidates) }
                $candidateIndex = 0
                foreach ($candidate in @($effectiveCandidates)) {
                    Assert-PackageDefinitionAcquisitionCandidateKind_2_0 -DefinitionId $DefinitionId -Candidate $candidate -CandidatePath ("artifacts.releases['{0}'].targetArtifacts['{1}'].artifactFiles['{2}'].acquisitionCandidates[{3}]" -f [string]$versionEntry.version, $targetId, $fileId, $candidateIndex)
                    Assert-PackageDefinitionVendorDownloadCandidate_2_0 -Definition $definition -DefinitionId $DefinitionId -VersionEntry $versionEntry -TargetId $targetId -ArtifactFileId $fileId -ArtifactFile $releaseFile -Candidate $candidate
                    $candidateIndex++
                }
            }
        }
    }
}

function Assert-PackageDefinitionSchema {
<#
.SYNOPSIS
Validates the Package definition schema for this package pass.

    .DESCRIPTION
Rejects retired top-level names, requires schemaVersion 2.0 fields, then
validates dependency/artifacts/discovery/packageOperations references.

.PARAMETER DefinitionDocumentInfo
The loaded Package definition document info.

.PARAMETER DefinitionId
The expected definition id.

.EXAMPLE
Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId VSCodeRuntime
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DefinitionDocumentInfo,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [AllowNull()]
        [string]$PublisherId = $null
    )

    $definition = $DefinitionDocumentInfo.Document
    foreach ($retiredProperty in @(
            'target',
            'origins',
            'interfaces',
            'packageType',
            'paths',
            'sources',
            'packages',
            'entryPoints',
            'packageFamily',
            'managedPaths'
        )) {
        if ($definition.PSObject.Properties[$retiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' still uses retired property '$retiredProperty'."
        }
    }

    $schemaVersionText = [string]$definition.schemaVersion
    if ([string]::IsNullOrWhiteSpace($schemaVersionText)) {
        throw "Package definition '$($DefinitionDocumentInfo.Path)' defines schemaVersion, but it is empty."
    }
    Assert-PackageDefinitionSchemaVersionSupported -SchemaVersionText $schemaVersionText -DefinitionDocumentPath $DefinitionDocumentInfo.Path

    $retiredRootReplacements = @{
        presenceDiscovery        = 'discovery.presence'
        existingInstallDiscovery = 'discovery.existingInstall'
    }
    foreach ($retiredProperty in @($retiredRootReplacements.Keys)) {
        if ($definition.PSObject.Properties[$retiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' still uses retired root property '$retiredProperty'. Use '$($retiredRootReplacements[$retiredProperty])'."
        }
    }

    foreach ($requiredProperty in @('schemaVersion', 'definitionPublication', 'display', 'dependency', 'artifacts', 'discovery', 'packageOperations')) {
        if (-not $definition.PSObject.Properties[$requiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' is missing required property '$requiredProperty'."
        }
    }
    foreach ($retiredProperty in @('definitionId', 'repositoryId')) {
        if ($definition.PSObject.Properties[$retiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' still uses retired schema 1.4 root property '$retiredProperty'. Move definition identity to definitionPublication."
        }
    }
    foreach ($retiredProperty in @(
            'packageTargets',
            'versionCatalog',
            'upstreamSources',
            'stateDiscovery',
            'installedStateCheck',
            'providedTools',
            'releaseDefaults',
            'existingInstallPolicy'
        )) {
        if ($definition.PSObject.Properties[$retiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' still uses retired pre-1.3 property '$retiredProperty'."
        }
    }

    switch -Exact ($schemaVersionText) {
        '2.0' {
            Assert-PackageDefinitionSchema_2_0 -DefinitionDocumentInfo $DefinitionDocumentInfo -DefinitionId $DefinitionId -PublisherId $PublisherId
            Assert-PackageDefinitionSignatureSchema_2_0 -DefinitionDocumentInfo $DefinitionDocumentInfo -DefinitionId $DefinitionId
            Assert-PackageDefinitionAcquisitionVocabulary_2_0 -DefinitionDocumentInfo $DefinitionDocumentInfo -DefinitionId $DefinitionId
            return
        }
        default {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' encountered unsupported schemaVersion '$schemaVersionText' after validation gate."
        }
    }
}
