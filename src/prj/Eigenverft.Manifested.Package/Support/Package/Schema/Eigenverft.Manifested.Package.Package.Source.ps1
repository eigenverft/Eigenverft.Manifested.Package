<#
    Eigenverft.Manifested.Package.Package.Source
#>

function Get-PackageSourceDefinition {
<#
.SYNOPSIS
Returns a resolved Package source definition by sourceRef.

.DESCRIPTION
Looks up an acquisition source from the effective acquisition environment or
from definition-local artifact sources and returns the normalized source
definition with scope and id metadata.

.PARAMETER PackageConfig
The resolved Package config object.

.PARAMETER SourceRef
The acquisition-candidate sourceRef object.

.EXAMPLE
Get-PackageSourceDefinition -PackageConfig $config -SourceRef $candidate.sourceRef
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig,

        [Parameter(Mandatory = $true)]
        [psobject]$SourceRef
    )

    $scope = [string]$SourceRef.scope
    $id = [string]$SourceRef.id
    $sourceObject = $null

    switch -Exact ($scope) {
        'environment' {
            foreach ($property in @($PackageConfig.EnvironmentSources.PSObject.Properties)) {
                if ([string]::Equals([string]$property.Name, $id, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $sourceObject = $property.Value
                    $id = $property.Name
                    break
                }
            }
            if (-not $sourceObject) {
                throw "Package environment source '$($SourceRef.id)' was not found in the effective acquisition environment."
            }
        }
        'definition' {
            foreach ($property in @($PackageConfig.DefinitionSources.PSObject.Properties)) {
                if ([string]::Equals([string]$property.Name, $id, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $sourceObject = $property.Value
                    $id = $property.Name
                    break
                }
            }
            if (-not $sourceObject) {
                throw "Package definition source '$($SourceRef.id)' was not found in definition '$($PackageConfig.DefinitionId)'."
            }
        }
        default {
            throw "Unsupported Package sourceRef.scope '$scope'."
        }
    }

    return [pscustomobject]@{
        Scope           = $scope
        Id              = $id
        Kind            = if ($sourceObject.PSObject.Properties['kind']) { [string]$sourceObject.kind } else { $null }
        BaseUri         = if ($sourceObject.PSObject.Properties['baseUri']) { [string]$sourceObject.baseUri } else { $null }
        BasePath        = if ($sourceObject.PSObject.Properties['basePath']) { [string]$sourceObject.basePath } else { $null }
        GitHubOwner      = if ($sourceObject.PSObject.Properties['githubOwner']) { [string]$sourceObject.githubOwner } else { $null }
        GitHubRepository = if ($sourceObject.PSObject.Properties['githubRepository']) { [string]$sourceObject.githubRepository } else { $null }
    }
}

function Resolve-PackageSource {
<#
.SYNOPSIS
Resolves a concrete source location from a source definition and acquisition candidate.

.DESCRIPTION
Combines a resolved source definition with one release acquisition candidate
and returns the concrete URI or filesystem path that should be used for the
package-file save.

.PARAMETER SourceDefinition
The resolved source definition for the acquisition candidate.

.PARAMETER AcquisitionCandidate
The release acquisition candidate.

.PARAMETER Package
The selected effective release object. Required for source kinds that resolve
through release metadata, such as GitHub release lookup by tag.

.EXAMPLE
Resolve-PackageSource -SourceDefinition $source -AcquisitionCandidate $candidate
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$SourceDefinition,

        [Parameter(Mandatory = $true)]
        [psobject]$AcquisitionCandidate,

        [AllowNull()]
        [psobject]$Package,

        [AllowNull()]
        [psobject]$ArtifactFile
    )

    switch -Exact ([string]$SourceDefinition.Kind) {
        'download' {
            if ($AcquisitionCandidate.PSObject.Properties['url'] -and -not [string]::IsNullOrWhiteSpace([string]$AcquisitionCandidate.url)) {
                return [pscustomobject]@{
                    Kind           = 'download'
                    ResolvedSource = [string]$AcquisitionCandidate.url
                }
            }

            if ([string]::IsNullOrWhiteSpace([string]$SourceDefinition.BaseUri)) {
                throw "Package download source '$($SourceDefinition.Id)' does not define baseUri. Use sourcePath with sourceId, or use acquisitionCandidate.url/urlTemplate for direct downloads."
            }
            if (-not $AcquisitionCandidate.PSObject.Properties['sourcePath'] -or [string]::IsNullOrWhiteSpace([string]$AcquisitionCandidate.sourcePath)) {
                throw "Package acquisition candidate for '$($SourceDefinition.Id)' does not define sourcePath. Use sourcePath, artifact sourcePath, url, or urlTemplate."
            }
            $baseUriText = ([string]$SourceDefinition.BaseUri).TrimEnd('/') + '/'
            $resolvedUri = [System.Uri]::new([System.Uri]$baseUriText, [string]$AcquisitionCandidate.sourcePath)
            return [pscustomobject]@{
                Kind           = 'download'
                ResolvedSource = $resolvedUri.AbsoluteUri
            }
        }
        'githubRelease' {
            if (-not $Package) {
                throw "Package GitHub release source '$($SourceDefinition.Id)' requires the selected package release context."
            }
            if ([string]::IsNullOrWhiteSpace([string]$SourceDefinition.GitHubOwner)) {
                throw "Package GitHub release source '$($SourceDefinition.Id)' does not define githubOwner."
            }
            if ([string]::IsNullOrWhiteSpace([string]$SourceDefinition.GitHubRepository)) {
                throw "Package GitHub release source '$($SourceDefinition.Id)' does not define githubRepository."
            }
            if (-not $Package.PSObject.Properties['releaseTag'] -or [string]::IsNullOrWhiteSpace([string]$Package.releaseTag)) {
                throw "Package release '$($Package.id)' requires releaseTag when acquisition uses GitHub release source '$($SourceDefinition.Id)'."
            }
            if (-not $ArtifactFile -or [string]::IsNullOrWhiteSpace([string]$ArtifactFile.RelativePath)) {
                throw "Package release '$($Package.id)' requires artifact file context when acquisition uses GitHub release source '$($SourceDefinition.Id)'."
            }

            $release = Get-GitHubRelease -RepositoryOwner $SourceDefinition.GitHubOwner -RepositoryName $SourceDefinition.GitHubRepository -ReleaseTag ([string]$Package.releaseTag)
            $assetName = Split-Path -Leaf ([string]$ArtifactFile.RelativePath)
            $matchedAsset = @(
                $release.Assets | Where-Object {
                    [string]::Equals([string]$_.Name, $assetName, [System.StringComparison]::OrdinalIgnoreCase)
                }
            ) | Select-Object -First 1

            if (-not $matchedAsset) {
                throw "GitHub release '$($Package.releaseTag)' for '$($SourceDefinition.GitHubOwner)/$($SourceDefinition.GitHubRepository)' does not contain asset '$assetName'."
            }
            if ([string]::IsNullOrWhiteSpace([string]$matchedAsset.DownloadUrl)) {
                throw "GitHub release '$($Package.releaseTag)' asset '$assetName' for '$($SourceDefinition.GitHubOwner)/$($SourceDefinition.GitHubRepository)' does not expose a download URL."
            }

            return [pscustomobject]@{
                Kind           = 'download'
                ResolvedSource = [string]$matchedAsset.DownloadUrl
            }
        }
        'filesystem' {
            if (-not $AcquisitionCandidate.PSObject.Properties['sourcePath'] -or [string]::IsNullOrWhiteSpace([string]$AcquisitionCandidate.sourcePath)) {
                throw "Package acquisition candidate for '$($SourceDefinition.Id)' does not define sourcePath."
            }

            $sourcePath = ([string]$AcquisitionCandidate.sourcePath).Trim() -replace '/', '\'
            if ([System.IO.Path]::IsPathRooted($sourcePath)) {
                $resolvedPath = Resolve-PackagePathValue -PathValue $sourcePath
            }
            else {
                if ([string]::IsNullOrWhiteSpace([string]$SourceDefinition.BasePath)) {
                    throw "Package filesystem source '$($SourceDefinition.Id)' does not define basePath."
                }

                $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $SourceDefinition.BasePath $sourcePath))
            }

            return [pscustomobject]@{
                Kind           = 'filesystem'
                ResolvedSource = $resolvedPath
            }
        }
        default {
            throw "Unsupported Package source kind '$($SourceDefinition.Kind)'."
        }
    }
}

function Test-PackageSavedFile {
<#
.SYNOPSIS
Evaluates a package file against a save-time verification policy.

.DESCRIPTION
Applies the acquisition candidate verification policy to a local file and
returns the verification status, whether the file is accepted, and the expected
and actual hash values when hashing is performed.

.PARAMETER Path
The local file path to verify.

.PARAMETER Verification
The verification policy object from the acquisition candidate.

.EXAMPLE
Test-PackageSavedFile -Path .\package.zip -Verification $verification
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [AllowNull()]
        [psobject]$Verification
    )

    if ($Verification -is [System.Collections.IDictionary]) {
        $Verification = [pscustomobject]$Verification
    }

    $authenticode = if ($Verification -and $Verification.PSObject.Properties['authenticode'] -and $null -ne $Verification.authenticode) {
        if ($Verification.authenticode -is [System.Collections.IDictionary]) {
            [pscustomobject]$Verification.authenticode
        }
        else {
            $Verification.authenticode
        }
    }
    else {
        $null
    }

    $mode = if ($Verification -and $Verification.PSObject.Properties['mode'] -and -not [string]::IsNullOrWhiteSpace([string]$Verification.mode)) {
        ([string]$Verification.mode).ToLowerInvariant()
    }
    else {
        'none'
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            Status       = 'FileMissing'
            Accepted     = $false
            Verified     = $false
            Mode         = $mode
            Algorithm    = $null
            ExpectedHash = $null
            ActualHash   = $null
        }
    }

    if ($mode -eq 'none' -and -not $authenticode) {
        return [pscustomobject]@{
            Status       = 'VerificationSkipped'
            Accepted     = $true
            Verified     = $false
            Mode         = $mode
            Algorithm    = $null
            ExpectedHash = $null
            ActualHash   = $null
            SignatureStatus = $null
            SignerSubject = $null
        }
    }

    $algorithm = if ($Verification -and $Verification.PSObject.Properties['algorithm'] -and -not [string]::IsNullOrWhiteSpace([string]$Verification.algorithm)) {
        ([string]$Verification.algorithm).ToLowerInvariant()
    }
    else {
        'sha256'
    }
    $hashAlgorithmName = switch -Exact ($algorithm) {
        'sha256' { 'SHA256' }
        'sha512' { 'SHA512' }
        default { $null }
    }
    if ([string]::IsNullOrWhiteSpace($hashAlgorithmName)) {
        return [pscustomobject]@{
            Status       = 'VerificationAlgorithmUnsupported'
            Accepted     = $false
            Verified     = $false
            Mode         = $mode
            Algorithm    = $algorithm
            ExpectedHash = $null
            ActualHash   = $null
            SignatureStatus = $null
            SignerSubject = $null
        }
    }

    $hashProperty = $algorithm
    $expectedHash = if ($Verification -and $Verification.PSObject.Properties[$hashProperty] -and -not [string]::IsNullOrWhiteSpace([string]$Verification.$hashProperty)) {
        ([string]$Verification.$hashProperty).Trim().ToLowerInvariant()
    }
    elseif ($Verification -and $Verification.PSObject.Properties['value'] -and -not [string]::IsNullOrWhiteSpace([string]$Verification.value)) {
        ([string]$Verification.value).Trim().ToLowerInvariant()
    }
    else {
        $null
    }

    if ([string]::IsNullOrWhiteSpace($expectedHash) -and -not $authenticode) {
        return [pscustomobject]@{
            Status       = if ($mode -eq 'required') { 'VerificationHashMissing' } else { 'VerificationHashMissingOptional' }
            Accepted     = ($mode -ne 'required')
            Verified     = $false
            Mode         = $mode
            Algorithm    = $algorithm
            ExpectedHash = $null
            ActualHash   = $null
            SignatureStatus = $null
            SignerSubject = $null
        }
    }

    $actualHash = $null
    $hashAccepted = $true
    if (-not [string]::IsNullOrWhiteSpace($expectedHash)) {
        $actualHash = (Get-FileHash -LiteralPath $Path -Algorithm $hashAlgorithmName).Hash.ToLowerInvariant()
        $hashAccepted = ($actualHash -eq $expectedHash)
    }

    $signatureStatus = $null
    $signerSubject = $null
    $authenticodeAccepted = $true
    if ($authenticode) {
        $authenticodeAccepted = $false
        try {
            $signature = Get-AuthenticodeSignature -FilePath $Path
            $signatureStatus = $signature.Status.ToString()
            $signerSubject = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
            $requiresValid = $true
            if ($authenticode.PSObject.Properties['requireValid']) {
                $requiresValid = [bool]$authenticode.requireValid
            }

            $authenticodeAccepted = (-not $requiresValid) -or ($signature.Status -eq [System.Management.Automation.SignatureStatus]::Valid)
            if ($authenticodeAccepted -and $authenticode.PSObject.Properties['subjectContains'] -and
                -not [string]::IsNullOrWhiteSpace([string]$authenticode.subjectContains)) {
                $authenticodeAccepted = ($null -ne $signerSubject -and $signerSubject -match [regex]::Escape([string]$authenticode.subjectContains))
            }
        }
        catch {
            $signatureStatus = 'Failed'
            $authenticodeAccepted = $false
        }
    }

    $accepted = $hashAccepted -and $authenticodeAccepted
    $status = if (-not $hashAccepted) {
        'VerificationFailed'
    }
    elseif ($authenticode -and -not $authenticodeAccepted) {
        'AuthenticodeFailed'
    }
    elseif ($authenticode -and [string]::IsNullOrWhiteSpace($expectedHash)) {
        'AuthenticodePassed'
    }
    else {
        'VerificationPassed'
    }

    return [pscustomobject]@{
        Status       = $status
        Accepted     = $accepted
        Verified     = $true
        Mode         = $mode
        Algorithm    = $algorithm
        ExpectedHash = $expectedHash
        ActualHash   = $actualHash
        SignatureStatus = $signatureStatus
        SignerSubject = $signerSubject
    }
}

function Save-PackageDownloadFile {
<#
.SYNOPSIS
Downloads a package file to a local path.

.DESCRIPTION
Uses the module's download helper to fetch a package file from an HTTP or HTTPS
source into a staging path for later verification and promotion.

.PARAMETER Uri
The package download URI.

.PARAMETER TargetPath
The local staging path that should receive the file.

.EXAMPLE
Save-PackageDownloadFile -Uri https://example.org/package.zip -TargetPath C:\Temp\package.zip
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    Invoke-WebRequestEx -Uri $Uri -OutFile $TargetPath -UseBasicParsing
    return (Resolve-Path -LiteralPath $TargetPath -ErrorAction Stop).Path
}

function Save-PackageFilesystemFile {
<#
.SYNOPSIS
Copies a package file from a filesystem source.

.DESCRIPTION
Copies a package file from a local or network filesystem path into a staging
path for later verification and promotion.

.PARAMETER SourcePath
The local or network path that contains the package file.

.PARAMETER TargetPath
The local staging path that should receive the copy.

.EXAMPLE
Save-PackageFilesystemFile -SourcePath \\server\share\package.zip -TargetPath C:\Temp\package.zip
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw "Package filesystem source '$SourcePath' does not exist."
    }

    return (Copy-FileToPath -SourcePath $SourcePath -TargetPath $TargetPath -Overwrite)
}

function Test-PackageArtifactFileAcquisitionRequired {
<#
.SYNOPSIS
    Determines whether the selected release has required static artifact files.

.DESCRIPTION
Interprets the current install kind so acquisition is skipped for install flows
that do not consume a saved package file.

.PARAMETER Package
The selected release object.

.EXAMPLE
Test-PackageArtifactFileAcquisitionRequired -Package $package
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Package
    )

    return [bool]($Package.PSObject.Properties['artifactFiles'] -and @($Package.artifactFiles).Count -gt 0)
}

function Get-PackagePreferredVerification {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object[]]$AcquisitionCandidates
    )

    foreach ($candidate in @($AcquisitionCandidates)) {
        if ($candidate.PSObject.Properties['verification'] -and $null -ne $candidate.verification) {
            return $candidate.verification
        }
    }

    return [pscustomobject]@{ mode = 'none' }
}

function Resolve-PackageAcquisitionCandidateVerification {
<#
.SYNOPSIS
Builds the effective verification policy for one acquisition candidate.

.DESCRIPTION
Combines acquisition-candidate verification mode with canonical package-file
content hash and publisher-signature metadata when present, while remaining
compatible with candidate-local hash definitions.

.PARAMETER Package
The selected effective release.

.PARAMETER AcquisitionCandidate
The raw acquisition candidate.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Package,

        [Parameter(Mandatory = $true)]
        [psobject]$ArtifactFile,

        [AllowNull()]
        [psobject]$AcquisitionCandidate,

        [ValidateSet('off', 'warnWhenPackageFileExists', 'enforceWhenPackageFileExists', 'enforceAllAcquisition')]
        [string]$PayloadVerificationPolicy = 'off',

        [bool]$ArtifactFileRequired = $false
    )

    $candidateVerification = if ($AcquisitionCandidate -and $AcquisitionCandidate.PSObject.Properties['verification']) {
        $AcquisitionCandidate.verification
    }
    else {
        $null
    }
    if ($candidateVerification -is [System.Collections.IDictionary]) {
        $candidateVerification = [pscustomobject]$candidateVerification
    }

    $packageContentHash = if ($ArtifactFile.PSObject.Properties['ContentHash']) {
        $ArtifactFile.ContentHash
    }
    else {
        $null
    }
    if ($packageContentHash -is [System.Collections.IDictionary]) {
        $packageContentHash = [pscustomobject]$packageContentHash
    }

    $packagePublisherSignature = if ($ArtifactFile.PSObject.Properties['PublisherSignature']) {
        $ArtifactFile.PublisherSignature
    }
    else {
        $null
    }
    if ($packagePublisherSignature -is [System.Collections.IDictionary]) {
        $packagePublisherSignature = [pscustomobject]$packagePublisherSignature
    }

    $packageFilePresent = -not [string]::IsNullOrWhiteSpace([string]$ArtifactFile.RelativePath)
    $packageContentHashPresent = $packageContentHash -and
        $packageContentHash.PSObject.Properties['value'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageContentHash.value)
    $packagePublisherSignaturePresent = $null -ne $packagePublisherSignature
    $packageBoundaryPresent = $packageContentHashPresent -or $packagePublisherSignaturePresent
    $payloadVerificationRequired = switch -Exact ($PayloadVerificationPolicy) {
        'enforceWhenPackageFileExists' { [bool]($ArtifactFileRequired -and $packageFilePresent) }
        'enforceAllAcquisition' { [bool]$ArtifactFileRequired }
        default { $false }
    }
    $payloadVerificationWarnOnly = [string]::Equals($PayloadVerificationPolicy, 'warnWhenPackageFileExists', [System.StringComparison]::OrdinalIgnoreCase) -and
        $ArtifactFileRequired -and
        $packageFilePresent -and
        -not $packageBoundaryPresent

    if ($payloadVerificationRequired -and -not $packageBoundaryPresent) {
        throw "Catalog payload policy '$PayloadVerificationPolicy' requires contentHash or publisherSignature for artifact file '$([string]$ArtifactFile.Id)' in package '$([string]$Package.id)'."
    }
    if ($payloadVerificationWarnOnly) {
        Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Catalog payload policy '{0}' found no trust boundary for artifact file '{1}' in package '{2}'." -f $PayloadVerificationPolicy, [string]$ArtifactFile.Id, [string]$Package.id)
    }

    $mode = if ($candidateVerification -and $candidateVerification.PSObject.Properties['mode'] -and -not [string]::IsNullOrWhiteSpace([string]$candidateVerification.mode)) {
        [string]$candidateVerification.mode
    }
    else {
        'none'
    }
    if ($payloadVerificationRequired) {
        $mode = 'required'
    }

    $algorithm = if ($packageContentHash -and $packageContentHash.PSObject.Properties['algorithm'] -and -not [string]::IsNullOrWhiteSpace([string]$packageContentHash.algorithm)) {
        ([string]$packageContentHash.algorithm).ToLowerInvariant()
    }
    elseif ($candidateVerification -and $candidateVerification.PSObject.Properties['algorithm'] -and -not [string]::IsNullOrWhiteSpace([string]$candidateVerification.algorithm)) {
        ([string]$candidateVerification.algorithm).ToLowerInvariant()
    }
    else {
        'sha256'
    }

    $hashValue = if ($packageContentHash -and $packageContentHash.PSObject.Properties['value'] -and -not [string]::IsNullOrWhiteSpace([string]$packageContentHash.value)) {
        [string]$packageContentHash.value
    }
    elseif ($candidateVerification -and $candidateVerification.PSObject.Properties[$algorithm] -and -not [string]::IsNullOrWhiteSpace([string]$candidateVerification.$algorithm)) {
        [string]$candidateVerification.$algorithm
    }
    elseif ($candidateVerification -and $candidateVerification.PSObject.Properties['sha256'] -and -not [string]::IsNullOrWhiteSpace([string]$candidateVerification.sha256)) {
        [string]$candidateVerification.sha256
    }
    else {
        $null
    }

    $verification = [ordered]@{
        mode = $mode
    }
    if (-not [string]::IsNullOrWhiteSpace($algorithm)) {
        $verification.algorithm = $algorithm
    }
    if (-not [string]::IsNullOrWhiteSpace($hashValue)) {
        $verification[$algorithm] = $hashValue
    }
    if ($packagePublisherSignature) {
        $verification.authenticode = $packagePublisherSignature
    }

    return [pscustomobject]$verification
}

function Get-PackagePackageDepotSources {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig
    )

    $orderedSources = New-Object System.Collections.Generic.List[object]

    foreach ($property in @($PackageConfig.EnvironmentSources.PSObject.Properties)) {
        $source = $property.Value
        if (-not [string]::Equals([string]$source.kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        if ($source.PSObject.Properties['readable'] -and -not [bool]$source.readable) {
            continue
        }

        $orderedSources.Add([pscustomobject]@{
            id           = $property.Name
            basePath     = if ($source.PSObject.Properties['basePath']) { [string]$source.basePath } else { $null }
            searchOrder  = if ($source.PSObject.Properties['searchOrder']) { [int]$source.searchOrder } else { 1000 }
            readable     = if ($source.PSObject.Properties['readable']) { [bool]$source.readable } else { $true }
            writable     = if ($source.PSObject.Properties['writable']) { [bool]$source.writable } else { $false }
            mirrorTarget = if ($source.PSObject.Properties['mirrorTarget']) { [bool]$source.mirrorTarget } else { $false }
            ensureExists = if ($source.PSObject.Properties['ensureExists']) { [bool]$source.ensureExists } else { $false }
        }) | Out-Null
    }

    return @(
        $orderedSources.ToArray() |
            Sort-Object -Property searchOrder, id
    )
}

function Get-PackageDepotDistributionTargets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig
    )

    $targets = New-Object System.Collections.Generic.List[object]
    foreach ($property in @($PackageConfig.EnvironmentSources.PSObject.Properties)) {
        $source = $property.Value
        if (-not ($source.PSObject.Properties['writable'] -and [bool]$source.writable)) {
            continue
        }
        if (-not ($source.PSObject.Properties['mirrorTarget'] -and [bool]$source.mirrorTarget)) {
            continue
        }

        $targets.Add([pscustomobject]@{
            id           = $property.Name
            kind         = if ($source.PSObject.Properties['kind']) { [string]$source.kind } else { $null }
            basePath     = if ($source.PSObject.Properties['basePath']) { [string]$source.basePath } else { $null }
            searchOrder  = if ($source.PSObject.Properties['searchOrder']) { [int]$source.searchOrder } else { 1000 }
            ensureExists = if ($source.PSObject.Properties['ensureExists']) { [bool]$source.ensureExists } else { $false }
        }) | Out-Null
    }

    return @(
        $targets.ToArray() |
            Sort-Object -Property searchOrder, id
    )
}

function Get-PackageDepotDistributionFileHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-PackageDepotDistributionFileMatches {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        return [pscustomobject]@{
            Matches = $false
            Reason  = 'Missing'
        }
    }

    $sourceItem = Get-Item -LiteralPath $SourcePath -ErrorAction Stop
    $targetItem = Get-Item -LiteralPath $TargetPath -ErrorAction Stop
    if ($sourceItem.Length -ne $targetItem.Length) {
        return [pscustomobject]@{
            Matches = $false
            Reason  = 'SizeMismatch'
        }
    }

    $sourceHash = Get-PackageDepotDistributionFileHash -Path $SourcePath
    $targetHash = Get-PackageDepotDistributionFileHash -Path $TargetPath
    return [pscustomobject]@{
        Matches = [string]::Equals($sourceHash, $targetHash, [System.StringComparison]::OrdinalIgnoreCase)
        Reason  = if ([string]::Equals($sourceHash, $targetHash, [System.StringComparison]::OrdinalIgnoreCase)) { 'AlreadyCurrent' } else { 'HashMismatch' }
    }
}

function Get-PackageArtifactFileResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [string]$ArtifactFileId
    )

    return @($PackageResult.ArtifactFiles | Where-Object {
            [string]::Equals([string]$_.Id, $ArtifactFileId, [System.StringComparison]::OrdinalIgnoreCase)
        }) | Select-Object -First 1
}

function Build-PackageAcquisitionPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $package = $PackageResult.Package
    if (-not $package) {
        throw 'Build-PackageAcquisitionPlan requires a selected release.'
    }

    $offline = $PackageResult.PSObject.Properties['Offline'] -and [bool]$PackageResult.Offline
    $payloadVerificationPolicy = if ($PackageResult.PackageConfig -and
        $PackageResult.PackageConfig.PSObject.Properties['CatalogTrustPayloadVerification'] -and
        -not [string]::IsNullOrWhiteSpace([string]$PackageResult.PackageConfig.CatalogTrustPayloadVerification)) {
        [string]$PackageResult.PackageConfig.CatalogTrustPayloadVerification
    }
    else {
        'off'
    }

    $filePlans = New-Object System.Collections.Generic.List[object]
    $skippedOfflineCandidateCount = 0
    foreach ($artifactFile in @($PackageResult.ArtifactFiles)) {
        $orderedCandidates = New-Object System.Collections.Generic.List[object]
        foreach ($candidate in @($artifactFile.AcquisitionCandidates | Sort-Object -Property @{
                    Expression = { if ($_.PSObject.Properties['searchOrder']) { [int]$_.searchOrder } else { [int]::MaxValue } }
                })) {
            $candidateKind = [string]$candidate.kind
            if ($offline -and $candidateKind -notin @('packageDepot', 'archiveEntry')) {
                $skippedOfflineCandidateCount++
                continue
            }

            $resolvedVerification = Resolve-PackageAcquisitionCandidateVerification `
                -Package $package `
                -ArtifactFile $artifactFile `
                -AcquisitionCandidate $candidate `
                -PayloadVerificationPolicy $payloadVerificationPolicy `
                -ArtifactFileRequired $true
            $searchOrder = if ($candidate.PSObject.Properties['searchOrder']) { [int]$candidate.searchOrder } else { [int]::MaxValue }

            switch -Exact ($candidateKind) {
                'packageDepot' {
                    $sourcePath = Join-Path $PackageResult.PackageDepotRelativeDirectory ([string]$artifactFile.RelativePath)
                    foreach ($depotSource in @(Get-PackagePackageDepotSources -PackageConfig $PackageResult.PackageConfig)) {
                        $orderedCandidates.Add([pscustomobject]@{
                                kind              = 'packageDepot'
                                searchOrder       = $searchOrder
                                sourceSearchOrder = [int]$depotSource.searchOrder
                                sourceRef         = [pscustomobject]@{ scope = 'environment'; id = [string]$depotSource.id }
                                sourcePath        = $sourcePath
                                verification      = $resolvedVerification
                            }) | Out-Null
                    }
                }
                'vendorDownload' {
                    $orderedCandidates.Add([pscustomobject]@{
                            kind              = 'vendorDownload'
                            searchOrder       = $searchOrder
                            sourceSearchOrder = 1000
                            sourceRef         = if ($candidate.PSObject.Properties['sourceId'] -and -not [string]::IsNullOrWhiteSpace([string]$candidate.sourceId)) {
                                [pscustomobject]@{ scope = 'definition'; id = [string]$candidate.sourceId }
                            }
                            else { $null }
                            sourcePath        = if ($candidate.PSObject.Properties['sourcePath']) { [string]$candidate.sourcePath } else { $null }
                            url               = if ($candidate.PSObject.Properties['url']) { [string]$candidate.url } else { $null }
                            verification      = $resolvedVerification
                        }) | Out-Null
                }
                'archiveEntry' {
                    $orderedCandidates.Add([pscustomobject]@{
                            kind                 = 'archiveEntry'
                            searchOrder          = $searchOrder
                            sourceSearchOrder    = 1000
                            sourceArtifactFileId = [string]$candidate.sourceArtifactFileId
                            entryPath            = [string]$candidate.entryPath
                            verification         = $resolvedVerification
                        }) | Out-Null
                }
                default {
                    throw "Unsupported artifact acquisition candidate kind '$candidateKind'."
                }
            }
        }

        $plan = [pscustomobject]@{
            ArtifactFileId      = [string]$artifactFile.Id
            StagingPath         = [string]$artifactFile.StagingPath
            DefaultDepotPath    = [string]$artifactFile.DefaultDepotPath
            Offline             = $offline
            Candidates          = @($orderedCandidates.ToArray() | Sort-Object -Property searchOrder, sourceSearchOrder, @{
                    Expression = { if ($_.sourceRef) { [string]$_.sourceRef.id } else { [string]::Empty } }
                })
        }
        $artifactFile.AcquisitionPlan = $plan
        $filePlans.Add($plan) | Out-Null
    }

    $PackageResult.ArtifactAcquisitionPlan = [pscustomobject]@{
        ArtifactFilesRequired        = @($PackageResult.ArtifactFiles).Count -gt 0
        ArtifactStagingDirectory     = [string]$PackageResult.ArtifactStagingDirectory
        Offline                      = $offline
        SkippedOfflineCandidateCount = $skippedOfflineCandidateCount
        Files                        = @($filePlans.ToArray())
    }
    Write-PackageExecutionMessage -Message ("[STATE] Acquisition plans built for {0} required artifact file(s); offline='{1}'." -f $filePlans.Count, $offline)
    return $PackageResult
}

function Expand-PackageDeclaredArchiveEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$EntryPath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    $normalizedEntryPath = $EntryPath.Replace('\', '/').TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($normalizedEntryPath) -or
        [System.IO.Path]::IsPathRooted($EntryPath) -or
        @($normalizedEntryPath.Split('/') | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) {
        throw "Archive entry path '$EntryPath' is unsafe."
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $matches = @($archive.Entries | Where-Object {
                [string]::Equals($_.FullName.Replace('\', '/').TrimStart('/'), $normalizedEntryPath, [System.StringComparison]::OrdinalIgnoreCase)
            })
        if ($matches.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$matches[0].Name)) {
            throw "Archive '$ArchivePath' must contain exactly one file entry named '$EntryPath'; found $($matches.Count)."
        }

        $targetDirectory = Split-Path -Parent $TargetPath
        $null = New-Item -ItemType Directory -Path $targetDirectory -Force
        $inputStream = $matches[0].Open()
        try {
            $outputStream = [System.IO.File]::Open($TargetPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            try { $inputStream.CopyTo($outputStream) }
            finally { $outputStream.Dispose() }
        }
        finally { $inputStream.Dispose() }
    }
    finally { $archive.Dispose() }

    return (Resolve-Path -LiteralPath $TargetPath -ErrorAction Stop).Path
}

function Resolve-PackageArtifactFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [psobject]$ArtifactFile,

        [Parameter(Mandatory = $true)]
        [hashtable]$ResolutionState,

        [Parameter(Mandatory = $true)]
        [hashtable]$Visiting
    )

    $artifactFileId = [string]$ArtifactFile.Id
    if ($ResolutionState.ContainsKey($artifactFileId)) {
        return [bool]$ResolutionState[$artifactFileId]
    }
    if ($Visiting.ContainsKey($artifactFileId)) {
        throw "Artifact acquisition cycle encountered while resolving '$artifactFileId'."
    }
    $Visiting[$artifactFileId] = $true

    $attempts = New-Object System.Collections.Generic.List[object]
    $orderedCandidates = @($ArtifactFile.AcquisitionPlan.Candidates)
    $preferredVerification = Get-PackagePreferredVerification -AcquisitionCandidates $orderedCandidates
    $offline = $PackageResult.PSObject.Properties['Offline'] -and [bool]$PackageResult.Offline

    if ((-not $offline) -and (Test-Path -LiteralPath $ArtifactFile.StagingPath -PathType Leaf)) {
        $verification = Test-PackageSavedFile -Path $ArtifactFile.StagingPath -Verification $preferredVerification
        $attempts.Add([pscustomobject]@{
                AttemptType = 'ReuseCheck'; Status = if ($verification.Accepted) { 'ReusedArtifactFile' } else { 'ReuseRejected' }
                SourceScope = 'artifactStaging'; SourceId = $artifactFileId; SourceKind = 'filesystem'
                ResolvedSource = [string]$ArtifactFile.StagingPath; VerificationStatus = $verification.Status
                ErrorMessage = if ($verification.Accepted) { $null } else { 'Existing staged artifact did not satisfy verification.' }
            }) | Out-Null
        if ($verification.Accepted) {
            $ArtifactFile.Verification = $verification
            $ArtifactFile.Preparation = [pscustomobject]@{
                Success = $true; Status = 'ReusedArtifactFile'; ArtifactFileId = $artifactFileId
                StagingPath = [string]$ArtifactFile.StagingPath; SelectedSource = [pscustomobject]@{
                    SourceScope = 'artifactStaging'; SourceId = $artifactFileId; SourceKind = 'filesystem'; ResolvedSource = [string]$ArtifactFile.StagingPath
                }
                Verification = $verification; Attempts = @($attempts.ToArray()); FailureReason = $null; ErrorMessage = $null
            }
            $ResolutionState[$artifactFileId] = $true
            $Visiting.Remove($artifactFileId)
            return $true
        }
    }

    $targetDirectory = Split-Path -Parent ([string]$ArtifactFile.StagingPath)
    $null = New-Item -ItemType Directory -Path $targetDirectory -Force
    foreach ($candidate in $orderedCandidates) {
        $sourceDefinition = $null
        $resolvedSource = $null
        $verification = $null
        $partialPath = '{0}.{1}.partial' -f $ArtifactFile.StagingPath, ([guid]::NewGuid().ToString('N'))
        try {
            if ([string]::Equals([string]$candidate.kind, 'archiveEntry', [System.StringComparison]::OrdinalIgnoreCase)) {
                $sourceArtifactFile = Get-PackageArtifactFileResult -PackageResult $PackageResult -ArtifactFileId ([string]$candidate.sourceArtifactFileId)
                if (-not $sourceArtifactFile) {
                    throw "Artifact file '$artifactFileId' references missing source artifact file '$($candidate.sourceArtifactFileId)'."
                }
                if (-not (Resolve-PackageArtifactFile -PackageResult $PackageResult -ArtifactFile $sourceArtifactFile -ResolutionState $ResolutionState -Visiting $Visiting)) {
                    throw "Source artifact file '$($candidate.sourceArtifactFileId)' could not be prepared."
                }
                $sourceDefinition = [pscustomobject]@{ Scope = 'artifact'; Id = [string]$sourceArtifactFile.Id; Kind = 'archiveEntry' }
                $resolvedSource = [pscustomobject]@{ Kind = 'archiveEntry'; ResolvedSource = [string]$sourceArtifactFile.StagingPath }
                $null = Expand-PackageDeclaredArchiveEntry -ArchivePath $sourceArtifactFile.StagingPath -EntryPath ([string]$candidate.entryPath) -TargetPath $partialPath
            }
            else {
                if ($candidate.sourceRef) {
                    $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $PackageResult.PackageConfig -SourceRef $candidate.sourceRef
                }
                elseif ([string]::Equals([string]$candidate.kind, 'vendorDownload', [System.StringComparison]::OrdinalIgnoreCase) -and
                    -not [string]::IsNullOrWhiteSpace([string]$candidate.url)) {
                    $sourceDefinition = [pscustomobject]@{
                        Scope = 'direct'; Id = 'directDownload'; Kind = 'download'; BaseUri = $null; BasePath = $null
                        GitHubOwner = $null; GitHubRepository = $null
                    }
                }
                else {
                    throw "Artifact acquisition candidate kind '$($candidate.kind)' could not be resolved to a source definition."
                }
                $resolvedSource = Resolve-PackageSource -SourceDefinition $sourceDefinition -AcquisitionCandidate $candidate -Package $PackageResult.Package -ArtifactFile $ArtifactFile
                switch -Exact ([string]$resolvedSource.Kind) {
                    'download' { $null = Save-PackageDownloadFile -Uri $resolvedSource.ResolvedSource -TargetPath $partialPath }
                    'filesystem' { $null = Save-PackageFilesystemFile -SourcePath $resolvedSource.ResolvedSource -TargetPath $partialPath }
                    default { throw "Unsupported artifact source kind '$($resolvedSource.Kind)'." }
                }
            }

            $verification = Test-PackageSavedFile -Path $partialPath -Verification $candidate.verification
            if (-not $verification.Accepted) {
                throw "Prepared artifact file '$artifactFileId' did not satisfy verification ($($verification.Status))."
            }

            if (Test-Path -LiteralPath $ArtifactFile.StagingPath) {
                Remove-Item -LiteralPath $ArtifactFile.StagingPath -Force
            }
            Move-Item -LiteralPath $partialPath -Destination $ArtifactFile.StagingPath -Force
            $selectedSource = [pscustomobject]@{
                SourceScope = [string]$sourceDefinition.Scope; SourceId = [string]$sourceDefinition.Id
                SourceKind = [string]$resolvedSource.Kind; ResolvedSource = [string]$resolvedSource.ResolvedSource
            }
            $preparedStatus = if ($candidate.kind -eq 'archiveEntry') {
                'ExtractedArchiveEntry'
            }
            elseif ($candidate.kind -eq 'packageDepot' -and $sourceDefinition.Id -eq 'defaultPackageDepot') {
                'HydratedFromDefaultPackageDepot'
            }
            elseif ($candidate.kind -eq 'packageDepot') {
                'HydratedFromPackageDepot'
            }
            else { 'SavedArtifactFile' }
            $attempts.Add([pscustomobject]@{
                    AttemptType = 'Save'; Status = $preparedStatus
                    SourceScope = $selectedSource.SourceScope; SourceId = $selectedSource.SourceId; SourceKind = $selectedSource.SourceKind
                    ResolvedSource = $selectedSource.ResolvedSource; VerificationStatus = $verification.Status; ErrorMessage = $null
                }) | Out-Null
            $ArtifactFile.Verification = $verification
            $ArtifactFile.Preparation = [pscustomobject]@{
                Success = $true; Status = $attempts[$attempts.Count - 1].Status; ArtifactFileId = $artifactFileId
                StagingPath = [string]$ArtifactFile.StagingPath; SelectedSource = $selectedSource; Verification = $verification
                Attempts = @($attempts.ToArray()); FailureReason = $null; ErrorMessage = $null
            }
            $ResolutionState[$artifactFileId] = $true
            $Visiting.Remove($artifactFileId)
            Write-PackageExecutionMessage -Message ("[ACTION] Prepared artifact file '{0}' from '{1}:{2}'." -f $artifactFileId, $selectedSource.SourceScope, $selectedSource.SourceId)
            return $true
        }
        catch {
            if (Test-Path -LiteralPath $partialPath) {
                Remove-Item -LiteralPath $partialPath -Force -ErrorAction SilentlyContinue
            }
            $attempts.Add([pscustomobject]@{
                    AttemptType = 'Save'; Status = 'Failed'
                    SourceScope = if ($sourceDefinition) { [string]$sourceDefinition.Scope } elseif ($candidate.sourceRef) { [string]$candidate.sourceRef.scope } else { $null }
                    SourceId = if ($sourceDefinition) { [string]$sourceDefinition.Id } elseif ($candidate.sourceRef) { [string]$candidate.sourceRef.id } else { $null }
                    SourceKind = if ($resolvedSource) { [string]$resolvedSource.Kind } else { [string]$candidate.kind }
                    ResolvedSource = if ($resolvedSource) { [string]$resolvedSource.ResolvedSource } else { $null }
                    VerificationStatus = if ($verification) { [string]$verification.Status } else { $null }
                    ErrorMessage = $_.Exception.Message
                }) | Out-Null
            if (-not $PackageResult.PackageConfig.AllowAcquisitionFallback) { break }
        }
    }

    $failureReason = if ($offline) { 'DepotMiss' } else { 'AllSourcesFailed' }
    $ArtifactFile.Preparation = [pscustomobject]@{
        Success = $false; Status = 'Failed'; ArtifactFileId = $artifactFileId; StagingPath = [string]$ArtifactFile.StagingPath
        SelectedSource = $null; Verification = $null; Attempts = @($attempts.ToArray()); FailureReason = $failureReason
        ErrorMessage = "No verified acquisition candidate produced required artifact file '$artifactFileId'."
    }
    $ResolutionState[$artifactFileId] = $false
    $Visiting.Remove($artifactFileId)
    return $false
}

function Resolve-PackageArtifactFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if (-not $PackageResult.ArtifactAcquisitionPlan) {
        $PackageResult = Build-PackageAcquisitionPlan -PackageResult $PackageResult
    }

    if (@($PackageResult.ArtifactFiles).Count -eq 0) {
        $PackageResult.ArtifactPreparation = [pscustomobject]@{ Success = $true; Status = 'Skipped'; Files = @(); MissingArtifactFiles = @() }
        return $PackageResult
    }

    $state = @{}
    foreach ($artifactFile in @($PackageResult.ArtifactFiles)) {
        $null = Resolve-PackageArtifactFile -PackageResult $PackageResult -ArtifactFile $artifactFile -ResolutionState $state -Visiting @{}
    }
    $missing = @($PackageResult.ArtifactFiles | Where-Object { -not $_.Preparation -or -not [bool]$_.Preparation.Success })
    $PackageResult.ArtifactPreparation = [pscustomobject]@{
        Success = $missing.Count -eq 0
        Status = if ($missing.Count -eq 0) { 'Prepared' } else { 'Failed' }
        Files = @($PackageResult.ArtifactFiles | ForEach-Object { $_.Preparation })
        MissingArtifactFiles = @($missing | ForEach-Object {
                [pscustomobject]@{ Id = [string]$_.Id; RelativePath = [string]$_.RelativePath; ExpectedDepotPath = [string]$_.DefaultDepotPath }
            })
    }
    if ($missing.Count -gt 0) {
        $details = @($missing | ForEach-Object { "'$($_.Id)' at '$($_.DefaultDepotPath)'" }) -join ', '
        throw "Required artifact file acquisition failed for package '$($PackageResult.Package.id)': $details."
    }

    return $PackageResult
}

function Resolve-PackageDepotDistributionPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $mode = if ($PackageResult.PackageConfig.PSObject.Properties['DepotDistributionMode'] -and
        -not [string]::IsNullOrWhiteSpace([string]$PackageResult.PackageConfig.DepotDistributionMode)) {
        [string]$PackageResult.PackageConfig.DepotDistributionMode
    }
    else { 'packageFocused' }

    $actions = New-Object System.Collections.Generic.List[object]
    $result = [pscustomobject]@{ Mode = $mode; Status = 'Skipped'; Reason = $null; Actions = @() }
    if ([string]::Equals($mode, 'disabled', [System.StringComparison]::OrdinalIgnoreCase)) {
        $result.Reason = 'DisabledByPolicy'
        return $result
    }
    if (@($PackageResult.ArtifactFiles).Count -eq 0) {
        $result.Reason = 'NoArtifactFiles'
        return $result
    }
    if (-not $PackageResult.ArtifactPreparation -or -not [bool]$PackageResult.ArtifactPreparation.Success) {
        throw 'Depot distribution requires the complete verified artifact file set.'
    }

    $targets = @(Get-PackageDepotDistributionTargets -PackageConfig $PackageResult.PackageConfig)
    if ($targets.Count -eq 0) {
        $result.Reason = 'NoWritableMirrorTargets'
        return $result
    }

    foreach ($artifactFile in @($PackageResult.ArtifactFiles)) {
        if (-not (Test-Path -LiteralPath $artifactFile.StagingPath -PathType Leaf)) {
            throw "Verified staging file for artifact '$($artifactFile.Id)' is missing."
        }
        foreach ($target in $targets) {
            if (-not [string]::Equals([string]$target.kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase) -or
                [string]::IsNullOrWhiteSpace([string]$target.basePath)) {
                continue
            }
            $targetPackageDirectory = Resolve-PackageArtifactChildPath -RootPath ([string]$target.basePath) -RelativePath ([string]$PackageResult.PackageDepotRelativeDirectory) -ArtifactFileId ([string]$artifactFile.Id)
            $targetPath = Resolve-PackageArtifactChildPath -RootPath $targetPackageDirectory -RelativePath ([string]$artifactFile.RelativePath) -ArtifactFileId ([string]$artifactFile.Id)
            $comparison = Test-PackageDepotDistributionFileMatches -SourcePath ([string]$artifactFile.StagingPath) -TargetPath $targetPath
            $actions.Add([pscustomobject]@{
                    ArtifactFileId = [string]$artifactFile.Id; DepotId = [string]$target.id
                    SourcePath = [string]$artifactFile.StagingPath; TargetPath = $targetPath
                    Action = if ($comparison.Matches) { 'Skip' } else { 'Copy' }
                    Status = if ($comparison.Matches) { 'Skipped' } else { 'Pending' }
                    Reason = [string]$comparison.Reason; EnsureExists = [bool]$target.ensureExists; ErrorMessage = $null
                }) | Out-Null
        }
    }

    $result.Status = 'Planned'
    $result.Actions = @($actions.ToArray())
    return $result
}

function Invoke-PackageDepotDistribution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $plan = Resolve-PackageDepotDistributionPlan -PackageResult $PackageResult
    foreach ($action in @($plan.Actions)) {
        if ($action.Action -ne 'Copy') { continue }
        try {
            $targetDirectory = Split-Path -Parent ([string]$action.TargetPath)
            $null = New-Item -ItemType Directory -Path $targetDirectory -Force
            $null = Copy-FileToPath -SourcePath ([string]$action.SourcePath) -TargetPath ([string]$action.TargetPath) -Overwrite
            $action.Status = 'Copied'
            Write-PackageExecutionMessage -Message ("[ACTION] Mirrored artifact file '{0}' to depot '{1}'." -f $action.ArtifactFileId, $action.DepotId)
        }
        catch {
            $action.Status = 'Failed'
            $action.ErrorMessage = $_.Exception.Message
            Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Failed to mirror artifact file '{0}' to depot '{1}': {2}" -f $action.ArtifactFileId, $action.DepotId, $_.Exception.Message)
        }
    }

    $plan | Add-Member -MemberType NoteProperty -Name CopiedCount -Value @($plan.Actions | Where-Object Status -eq 'Copied').Count -Force
    $plan | Add-Member -MemberType NoteProperty -Name FailedCount -Value @($plan.Actions | Where-Object Status -eq 'Failed').Count -Force
    $plan | Add-Member -MemberType NoteProperty -Name SkippedCount -Value @($plan.Actions | Where-Object Status -eq 'Skipped').Count -Force
    $PackageResult.DepotDistribution = $plan
    return $PackageResult
}
