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
        [psobject]$Package
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
            if (-not $Package.PSObject.Properties['packageFile'] -or
                $null -eq $Package.packageFile -or
                -not $Package.packageFile.PSObject.Properties['fileName'] -or
                [string]::IsNullOrWhiteSpace([string]$Package.packageFile.fileName)) {
                throw "Package release '$($Package.id)' requires packageFile.fileName when acquisition uses GitHub release source '$($SourceDefinition.Id)'."
            }

            $release = Get-GitHubRelease -RepositoryOwner $SourceDefinition.GitHubOwner -RepositoryName $SourceDefinition.GitHubRepository -ReleaseTag ([string]$Package.releaseTag)
            $assetName = [string]$Package.packageFile.fileName
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

function Test-PackagePackageFileAcquisitionRequired {
<#
.SYNOPSIS
Determines whether the selected release needs an acquired package file.

.DESCRIPTION
Interprets the current install kind so acquisition is skipped for install flows
that do not consume a saved package file.

.PARAMETER Package
The selected release object.

.EXAMPLE
Test-PackagePackageFileAcquisitionRequired -Package $package
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Package
    )

    $assignedInstall = Get-PackageAssignedInstallOperation -Release $Package
    $installKind = if ($assignedInstall -and $assignedInstall.PSObject.Properties['kind']) {
        [string]$assignedInstall.kind
    }
    else {
        $null
    }

    switch -Exact ($installKind) {
        'expandArchive' { return $true }
        'placePackageFile' { return $true }
        'nsisInstaller' { return $true }
        'innoSetupInstaller' { return $true }
        'msiInstaller' { return $true }
        'powershellModuleInstaller' { return $true }
        'runInstaller' {
            return (-not $assignedInstall.PSObject.Properties['commandPath'] -or [string]::IsNullOrWhiteSpace([string]$assignedInstall.commandPath))
        }
        default { return $false }
    }
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

        [AllowNull()]
        [psobject]$AcquisitionCandidate,

        [ValidateSet('off', 'warnWhenPackageFileExists', 'enforceWhenPackageFileExists', 'enforceAllAcquisition')]
        [string]$PayloadVerificationPolicy = 'off',

        [bool]$PackageFileRequired = $false
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

    $packageContentHash = if ($Package -and
        $Package.PSObject.Properties['packageFile'] -and
        $Package.packageFile -and
        $Package.packageFile.PSObject.Properties['contentHash']) {
        $Package.packageFile.contentHash
    }
    else {
        $null
    }
    if ($packageContentHash -is [System.Collections.IDictionary]) {
        $packageContentHash = [pscustomobject]$packageContentHash
    }

    $packagePublisherSignature = if ($Package -and
        $Package.PSObject.Properties['packageFile'] -and
        $Package.packageFile -and
        $Package.packageFile.PSObject.Properties['publisherSignature']) {
        $Package.packageFile.publisherSignature
    }
    else {
        $null
    }
    if ($packagePublisherSignature -is [System.Collections.IDictionary]) {
        $packagePublisherSignature = [pscustomobject]$packagePublisherSignature
    }

    $packageFilePresent = $Package -and
        $Package.PSObject.Properties['packageFile'] -and
        $Package.packageFile -and
        $Package.packageFile.PSObject.Properties['fileName'] -and
        -not [string]::IsNullOrWhiteSpace([string]$Package.packageFile.fileName)
    $packageContentHashPresent = $packageContentHash -and
        $packageContentHash.PSObject.Properties['value'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageContentHash.value)
    $packagePublisherSignaturePresent = $null -ne $packagePublisherSignature
    $packageBoundaryPresent = $packageContentHashPresent -or $packagePublisherSignaturePresent
    $payloadVerificationRequired = switch -Exact ($PayloadVerificationPolicy) {
        'enforceWhenPackageFileExists' { [bool]($PackageFileRequired -and $packageFilePresent) }
        'enforceAllAcquisition' { [bool]$PackageFileRequired }
        default { $false }
    }
    $payloadVerificationWarnOnly = [string]::Equals($PayloadVerificationPolicy, 'warnWhenPackageFileExists', [System.StringComparison]::OrdinalIgnoreCase) -and
        $PackageFileRequired -and
        $packageFilePresent -and
        -not $packageBoundaryPresent

    if ($payloadVerificationRequired -and -not $packageBoundaryPresent) {
        throw "Catalog payload policy '$PayloadVerificationPolicy' requires packageFile.contentHash or packageFile.publisherSignature for package '$([string]$Package.id)' because package-file acquisition is required."
    }
    if ($payloadVerificationWarnOnly) {
        Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Catalog payload policy '{0}' found no packageFile.contentHash or packageFile.publisherSignature for package '{1}'." -f $PayloadVerificationPolicy, [string]$Package.id)
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

function Resolve-PackageDepotDistributionSourceArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if (-not $PackageResult.Package -or
        -not $PackageResult.Package.PSObject.Properties['packageFile'] -or
        -not $PackageResult.Package.packageFile -or
        -not $PackageResult.Package.packageFile.PSObject.Properties['fileName'] -or
        [string]::IsNullOrWhiteSpace([string]$PackageResult.Package.packageFile.fileName)) {
        return $null
    }

    $orderedCandidates = if ($PackageResult.AcquisitionPlan) { @($PackageResult.AcquisitionPlan.Candidates) } else { @() }
    $preferredVerification = Get-PackagePreferredVerification -AcquisitionCandidates $orderedCandidates
    $offline = $PackageResult.PSObject.Properties['Offline'] -and [bool]$PackageResult.Offline

    if ((-not $offline) -and
        -not [string]::IsNullOrWhiteSpace([string]$PackageResult.PackageFilePath) -and
        (Test-Path -LiteralPath $PackageResult.PackageFilePath -PathType Leaf)) {
        $verification = Test-PackageSavedFile -Path $PackageResult.PackageFilePath -Verification $preferredVerification
        if ($verification.Accepted) {
            return [pscustomobject]@{
                SourcePath   = [string]$PackageResult.PackageFilePath
                SourceScope  = 'packageFileStaging'
                SourceId     = 'packageFileStaging'
                SourceKind   = 'filesystem'
                Verification = $verification
            }
        }
    }

    $packageFileName = [string]$PackageResult.Package.packageFile.fileName
    foreach ($depotSource in @(Get-PackagePackageDepotSources -PackageConfig $PackageResult.PackageConfig)) {
        if ([string]::IsNullOrWhiteSpace([string]$depotSource.basePath)) {
            continue
        }
        $candidateDirectory = [System.IO.Path]::GetFullPath((Join-Path ([string]$depotSource.basePath) $PackageResult.PackageDepotRelativeDirectory))
        $candidatePath = Join-Path $candidateDirectory $packageFileName
        if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
            continue
        }

        $verification = Test-PackageSavedFile -Path $candidatePath -Verification $preferredVerification
        if ($verification.Accepted) {
            return [pscustomobject]@{
                SourcePath   = $candidatePath
                SourceScope  = 'environment'
                SourceId     = [string]$depotSource.id
                SourceKind   = 'filesystem'
                Verification = $verification
            }
        }
    }

    return $null
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
    else {
        'packageFocused'
    }

    $actions = New-Object System.Collections.Generic.List[object]
    $result = [pscustomobject]@{
        Mode       = $mode
        Status     = 'Skipped'
        Reason     = $null
        SourcePath = $null
        SourceScope = $null
        SourceId   = $null
        Actions    = @()
    }

    if ([string]::Equals($mode, 'disabled', [System.StringComparison]::OrdinalIgnoreCase)) {
        $result.Reason = 'DisabledByPolicy'
        return $result
    }

    if (-not $PackageResult.Package -or
        -not $PackageResult.Package.PSObject.Properties['packageFile'] -or
        -not $PackageResult.Package.packageFile -or
        -not $PackageResult.Package.packageFile.PSObject.Properties['fileName'] -or
        [string]::IsNullOrWhiteSpace([string]$PackageResult.Package.packageFile.fileName)) {
        $result.Reason = 'PackageFileNotRequired'
        return $result
    }

    $sourceArtifact = Resolve-PackageDepotDistributionSourceArtifact -PackageResult $PackageResult
    if (-not $sourceArtifact) {
        $result.Reason = 'NoVerifiedArtifact'
        return $result
    }

    $result.Status = 'Planned'
    $result.SourcePath = [string]$sourceArtifact.SourcePath
    $result.SourceScope = [string]$sourceArtifact.SourceScope
    $result.SourceId = [string]$sourceArtifact.SourceId

    $sourceFullPath = [System.IO.Path]::GetFullPath([string]$sourceArtifact.SourcePath)
    $packageFileName = [string]$PackageResult.Package.packageFile.fileName
    foreach ($mirrorSource in @(Get-PackageDepotDistributionTargets -PackageConfig $PackageResult.PackageConfig)) {
        if (-not [string]::Equals([string]$mirrorSource.kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
            $actions.Add([pscustomobject]@{
                DepotId      = [string]$mirrorSource.id
                Action       = 'Skip'
                Status       = 'Skipped'
                Reason       = 'UnsupportedDepotKind'
                SourcePath   = $sourceFullPath
                TargetPath   = $null
                EnsureExists = [bool]$mirrorSource.ensureExists
                ErrorMessage = $null
            }) | Out-Null
            continue
        }
        if ([string]::IsNullOrWhiteSpace([string]$mirrorSource.basePath)) {
            $actions.Add([pscustomobject]@{
                DepotId      = [string]$mirrorSource.id
                Action       = 'Skip'
                Status       = 'Skipped'
                Reason       = 'MissingBasePath'
                SourcePath   = $sourceFullPath
                TargetPath   = $null
                EnsureExists = [bool]$mirrorSource.ensureExists
                ErrorMessage = $null
            }) | Out-Null
            continue
        }

        $targetDirectory = [System.IO.Path]::GetFullPath((Join-Path ([string]$mirrorSource.basePath) $PackageResult.PackageDepotRelativeDirectory))
        $targetPath = Join-Path $targetDirectory $packageFileName
        $targetFullPath = [System.IO.Path]::GetFullPath($targetPath)
        if ([string]::Equals($sourceFullPath, $targetFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $actions.Add([pscustomobject]@{
                DepotId      = [string]$mirrorSource.id
                Action       = 'Skip'
                Status       = 'Skipped'
                Reason       = 'SourceIsTarget'
                SourcePath   = $sourceFullPath
                TargetPath   = $targetFullPath
                EnsureExists = [bool]$mirrorSource.ensureExists
                ErrorMessage = $null
            }) | Out-Null
            continue
        }

        $match = Test-PackageDepotDistributionFileMatches -SourcePath $sourceFullPath -TargetPath $targetFullPath
        if ($match.Matches) {
            $actions.Add([pscustomobject]@{
                DepotId      = [string]$mirrorSource.id
                Action       = 'Skip'
                Status       = 'Skipped'
                Reason       = [string]$match.Reason
                SourcePath   = $sourceFullPath
                TargetPath   = $targetFullPath
                EnsureExists = [bool]$mirrorSource.ensureExists
                ErrorMessage = $null
            }) | Out-Null
            continue
        }

        if ([string]::Equals($mode, 'packageFocused', [System.StringComparison]::OrdinalIgnoreCase) -and
            -not [string]::Equals([string]$match.Reason, 'Missing', [System.StringComparison]::OrdinalIgnoreCase)) {
            $actions.Add([pscustomobject]@{
                DepotId      = [string]$mirrorSource.id
                Action       = 'Skip'
                Status       = 'Skipped'
                Reason       = 'DifferentTargetPreservedByPackageFocusedPolicy'
                SourcePath   = $sourceFullPath
                TargetPath   = $targetFullPath
                EnsureExists = [bool]$mirrorSource.ensureExists
                ErrorMessage = [string]$match.Reason
            }) | Out-Null
            continue
        }

        $actions.Add([pscustomobject]@{
            DepotId      = [string]$mirrorSource.id
            Action       = 'Copy'
            Status       = 'Pending'
            Reason       = [string]$match.Reason
            SourcePath   = $sourceFullPath
            TargetPath   = $targetFullPath
            EnsureExists = [bool]$mirrorSource.ensureExists
            ErrorMessage = $null
        }) | Out-Null
    }

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
        if (-not [string]::Equals([string]$action.Action, 'Copy', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        try {
            $targetDirectory = Split-Path -Parent ([string]$action.TargetPath)
            if ($action.EnsureExists -and -not [string]::IsNullOrWhiteSpace($targetDirectory)) {
                $null = New-Item -ItemType Directory -Path $targetDirectory -Force
            }
            $null = Copy-FileToPath -SourcePath ([string]$action.SourcePath) -TargetPath ([string]$action.TargetPath) -Overwrite
            $action.Status = 'Copied'
            $action.ErrorMessage = $null
            Write-PackageExecutionMessage -Message ("[ACTION] Mirrored package file to depot '{0}' at '{1}'." -f [string]$action.DepotId, [string]$action.TargetPath)
        }
        catch {
            $action.Status = 'Failed'
            $action.ErrorMessage = $_.Exception.Message
            Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Failed to mirror package file to depot '{0}' at '{1}': {2}" -f [string]$action.DepotId, [string]$action.TargetPath, $_.Exception.Message)
        }
    }

    $copiedCount = @($plan.Actions | Where-Object { [string]::Equals([string]$_.Status, 'Copied', [System.StringComparison]::OrdinalIgnoreCase) }).Count
    $failedCount = @($plan.Actions | Where-Object { [string]::Equals([string]$_.Status, 'Failed', [System.StringComparison]::OrdinalIgnoreCase) }).Count
    $skippedCount = @($plan.Actions | Where-Object { [string]::Equals([string]$_.Status, 'Skipped', [System.StringComparison]::OrdinalIgnoreCase) }).Count
    $plan | Add-Member -MemberType NoteProperty -Name CopiedCount -Value $copiedCount -Force
    $plan | Add-Member -MemberType NoteProperty -Name FailedCount -Value $failedCount -Force
    $plan | Add-Member -MemberType NoteProperty -Name SkippedCount -Value $skippedCount -Force
    $PackageResult.DepotDistribution = $plan

    if ([string]::Equals([string]$plan.Status, 'Skipped', [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-PackageExecutionMessage -Message ("[STATE] Depot distribution skipped: mode='{0}', reason='{1}'." -f [string]$plan.Mode, [string]$plan.Reason)
    }
    else {
        Write-PackageExecutionMessage -Message ("[STATE] Depot distribution completed: mode='{0}', copied={1}, skipped={2}, failed={3}." -f [string]$plan.Mode, $copiedCount, $skippedCount, $failedCount)
    }

    return $PackageResult
}

function Build-PackageAcquisitionPlan {
<#
.SYNOPSIS
Builds the internal Package acquisition plan for the selected release.

.DESCRIPTION
    Normalizes the ordered acquisition candidates and captures the package-file staging
and depot targets so later package-file save steps can execute linearly.

.PARAMETER PackageResult
The Package result object to enrich.

.EXAMPLE
Build-PackageAcquisitionPlan -PackageResult $result
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $package = $PackageResult.Package
    if (-not $package) {
        throw 'Build-PackageAcquisitionPlan requires a selected release.'
    }

    if ([string]::Equals([string]$PackageResult.InstallOrigin, 'AlreadySatisfied', [System.StringComparison]::OrdinalIgnoreCase)) {
        $PackageResult.AcquisitionPlan = [pscustomobject]@{
            PackageFileRequired      = $false
            PackageFileStagingFilePath = $PackageResult.PackageFilePath
            Offline                  = if ($PackageResult.PSObject.Properties['Offline']) { [bool]$PackageResult.Offline } else { $false }
            SkippedOfflineCandidateCount = 0
            SkippedOfflineVendorCandidateCount = 0
            Candidates               = @()
        }
        Write-PackageExecutionMessage -Message '[STATE] Acquisition skipped because package target is already satisfied.'
        return $PackageResult
    }

    $requiresPackageFile = Test-PackagePackageFileAcquisitionRequired -Package $package
    $payloadVerificationPolicy = if ($PackageResult.PackageConfig -and
        $PackageResult.PackageConfig.PSObject.Properties['CatalogTrustPayloadVerification'] -and
        -not [string]::IsNullOrWhiteSpace([string]$PackageResult.PackageConfig.CatalogTrustPayloadVerification)) {
        [string]$PackageResult.PackageConfig.CatalogTrustPayloadVerification
    }
    else {
        'off'
    }
    $offline = $PackageResult.PSObject.Properties['Offline'] -and [bool]$PackageResult.Offline
    $skippedOfflineCandidateCount = 0
    $skippedOfflineVendorCandidateCount = 0
    $orderedCandidates = New-Object System.Collections.Generic.List[object]
    if ($requiresPackageFile -and $package.PSObject.Properties['acquisitionCandidates']) {
        foreach ($candidate in @($package.acquisitionCandidates | Sort-Object -Property @{
                    Expression = { if ($_.PSObject.Properties['searchOrder']) { [int]$_.searchOrder } else { [int]::MaxValue } }
                })) {
            $candidateKind = [string]$candidate.kind
            if ($offline -and -not [string]::Equals($candidateKind, 'packageDepot', [System.StringComparison]::OrdinalIgnoreCase)) {
                $skippedOfflineCandidateCount++
                if ([string]::Equals($candidateKind, 'vendorDownload', [System.StringComparison]::OrdinalIgnoreCase)) {
                    $skippedOfflineVendorCandidateCount++
                }
                continue
            }
            $resolvedVerification = Resolve-PackageAcquisitionCandidateVerification -Package $package -AcquisitionCandidate $candidate -PayloadVerificationPolicy $payloadVerificationPolicy -PackageFileRequired $requiresPackageFile
            switch -Exact ($candidateKind) {
                'packageDepot' {
                    $resolvedDepotSourcePath = Join-Path $PackageResult.PackageDepotRelativeDirectory ([string]$package.packageFile.fileName)
                    foreach ($depotSource in @(Get-PackagePackageDepotSources -PackageConfig $PackageResult.PackageConfig)) {
                        $orderedCandidates.Add([pscustomobject]@{
                            kind         = 'packageDepot'
                            searchOrder     = if ($candidate.PSObject.Properties['searchOrder']) { [int]$candidate.searchOrder } else { [int]::MaxValue }
                            sourceSearchOrder = [int]$depotSource.searchOrder
                            sourceRef    = [pscustomobject]@{
                                scope = 'environment'
                                id    = $depotSource.id
                            }
                            sourcePath   = $resolvedDepotSourcePath
                            verification = $resolvedVerification
                        }) | Out-Null
                    }
                }
                'vendorDownload' {
                    $directUrl = if ($candidate.PSObject.Properties['url']) { [string]$candidate.url } else { $null }
                    $orderedCandidates.Add([pscustomobject]@{
                        kind         = $candidateKind
                        searchOrder     = if ($candidate.PSObject.Properties['searchOrder']) { [int]$candidate.searchOrder } else { [int]::MaxValue }
                        sourceSearchOrder = 1000
                        sourceRef    = if ($candidate.PSObject.Properties['sourceId'] -and -not [string]::IsNullOrWhiteSpace([string]$candidate.sourceId)) {
                            [pscustomobject]@{
                                scope = 'definition'
                                id    = [string]$candidate.sourceId
                            }
                        }
                        else {
                            $null
                        }
                        sourcePath   = [string]$candidate.sourcePath
                        url          = $directUrl
                        verification = $resolvedVerification
                    }) | Out-Null
                }
                'filesystem' {
                    $orderedCandidates.Add([pscustomobject]@{
                        kind         = 'filesystem'
                        searchOrder     = if ($candidate.PSObject.Properties['searchOrder']) { [int]$candidate.searchOrder } else { [int]::MaxValue }
                        sourceSearchOrder = 1000
                        sourceRef    = if ($candidate.PSObject.Properties['sourceId'] -and -not [string]::IsNullOrWhiteSpace([string]$candidate.sourceId)) {
    [pscustomobject]@{
                                scope = 'environment'
                                id    = [string]$candidate.sourceId
                            }
                        }
                        else {
                            $null
                        }
                        sourcePath   = [string]$candidate.sourcePath
                        verification = $resolvedVerification
                    }) | Out-Null
                }
            }
        }
    }

    $PackageResult.AcquisitionPlan = [pscustomobject]@{
        PackageFileRequired    = $requiresPackageFile
        PackageFileStagingFilePath = $PackageResult.PackageFilePath
        DefaultPackageDepotFilePath = $PackageResult.DefaultPackageDepotFilePath
        Offline                = $offline
        SkippedOfflineCandidateCount = $skippedOfflineCandidateCount
        SkippedOfflineVendorCandidateCount = $skippedOfflineVendorCandidateCount
        Candidates             = @(
            $orderedCandidates.ToArray() |
                Sort-Object -Property searchOrder, sourceSearchOrder, @{
                    Expression = {
                        if ($_.sourceRef) { [string]$_.sourceRef.id } else { [string]::Empty }
                    }
                }
        )
    }

    $candidateSummary = @(
        foreach ($candidate in @($PackageResult.AcquisitionPlan.Candidates)) {
            $sourceSummary = if ($candidate.sourceRef) {
                '{0}:{1}' -f [string]$candidate.sourceRef.scope, [string]$candidate.sourceRef.id
            }
            else {
                'direct'
            }
            '{0}@{1}->{2}' -f [string]$candidate.kind, [string]$candidate.searchOrder, $sourceSummary
        }
    ) -join ', '
    if ([string]::IsNullOrWhiteSpace($candidateSummary)) {
        $candidateSummary = '<none>'
    }
    $offlineSuffix = if ($offline) { " offline='true', skippedByPolicy=$skippedOfflineCandidateCount" } else { " offline='false'" }
    Write-PackageExecutionMessage -Message ("[STATE] Acquisition plan packageFileRequired='{0}'{1} with {2} candidate(s): {3}." -f $requiresPackageFile, $offlineSuffix, @($PackageResult.AcquisitionPlan.Candidates).Count, $candidateSummary)

    return $PackageResult
}

function Resolve-PackageInstallFile {
<#
.SYNOPSIS
Ensures the selected package file is present in the package file staging.

.DESCRIPTION
Reuses an already-present verified package file when possible, then checks the
default package depot, and otherwise attempts each configured acquisition
candidate in searchOrder order until one succeeds or all candidates fail.

.PARAMETER PackageResult
The Package result object to enrich.

.EXAMPLE
Resolve-PackageInstallFile -PackageResult $result
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $package = $PackageResult.Package
    $packageConfig = $PackageResult.PackageConfig

    if (-not $package -or -not (Get-PackageAssignedOperation -Release $package)) {
        throw 'Resolve-PackageInstallFile requires a selected release with assigned settings.'
    }

    $assignedInstall = Get-PackageAssignedInstallOperation -Release $package
    $installKind = if ($assignedInstall -and $assignedInstall.PSObject.Properties['kind']) { [string]$assignedInstall.kind } else { $null }
    $existingDecision = if ($PackageResult.ExistingPackage -and $PackageResult.ExistingPackage.PSObject.Properties['Decision']) { [string]$PackageResult.ExistingPackage.Decision } else { $null }
    $keepPackageFileAcquisitionForAdoptedPowerShellModule = [string]::Equals($existingDecision, 'AdoptExternal', [System.StringComparison]::OrdinalIgnoreCase) -and
        [string]::Equals($installKind, 'powershellModuleInstaller', [System.StringComparison]::OrdinalIgnoreCase)
    if ($PackageResult.ExistingPackage -and
        $PackageResult.ExistingPackage.PSObject.Properties['Decision'] -and
        $PackageResult.ExistingPackage.Decision -in @('ReusePackageOwned', 'AdoptExternal') -and
        (-not $keepPackageFileAcquisitionForAdoptedPowerShellModule)) {
        $PackageResult.PackageFilePreparation = [pscustomobject]@{
            Success         = $true
            Status          = 'Skipped'
            PackageFilePath = $PackageResult.PackageFilePath
            SelectedSource  = $null
            Verification    = $null
            Attempts        = @()
            FailureReason   = $null
            ErrorMessage    = $null
        }
        Write-PackageExecutionMessage -Message ("[STATE] Package file step skipped because existing install decision is '{0}'." -f [string]$PackageResult.ExistingPackage.Decision)
        return $PackageResult
    }

    if (-not $PackageResult.AcquisitionPlan) {
        $PackageResult = Build-PackageAcquisitionPlan -PackageResult $PackageResult
    }

    if (-not $PackageResult.AcquisitionPlan.PackageFileRequired) {
        $PackageResult.PackageFilePreparation = [pscustomobject]@{
            Success         = $true
            Status          = 'Skipped'
            PackageFilePath = $PackageResult.PackageFilePath
            SelectedSource  = $null
            Verification    = $null
            Attempts        = @()
            FailureReason   = $null
            ErrorMessage    = $null
        }
        Write-PackageExecutionMessage -Message "[STATE] Package file step skipped because the selected install kind does not require a saved package file."
        return $PackageResult
    }

    if ([string]::IsNullOrWhiteSpace($PackageResult.PackageFilePath)) {
        throw "Package release '$($package.id)' does not define packageFile.fileName."
    }

    $offline = $PackageResult.PSObject.Properties['Offline'] -and [bool]$PackageResult.Offline
    $orderedCandidates = @($PackageResult.AcquisitionPlan.Candidates)
    if (-not $orderedCandidates) {
        if ($offline) {
            $skippedByPolicy = if ($PackageResult.AcquisitionPlan.PSObject.Properties['SkippedOfflineCandidateCount']) { [int]$PackageResult.AcquisitionPlan.SkippedOfflineCandidateCount } else { 0 }
            throw "Package release '$($package.id)' has no usable packageDepot acquisition candidates for Offline mode. Skipped $skippedByPolicy vendor or package-definition non-depot candidate(s)."
        }
        throw "Package release '$($package.id)' does not define any acquisition candidates."
    }

    $attempts = New-Object System.Collections.Generic.List[object]
    $preferredVerification = Get-PackagePreferredVerification -AcquisitionCandidates $orderedCandidates

    if ((-not $offline) -and (Test-Path -LiteralPath $PackageResult.PackageFilePath)) {
        $verification = Test-PackageSavedFile -Path $PackageResult.PackageFilePath -Verification $preferredVerification
        $attempts.Add([pscustomobject]@{
            AttemptType        = 'ReuseCheck'
            Status             = if ($verification.Accepted) { 'ReusedPackageFile' } else { 'ReuseRejected' }
            SourceScope        = 'packageFileStaging'
            SourceId           = 'packageFileStaging'
            SourceKind         = 'filesystem'
            ResolvedSource     = $PackageResult.PackageFilePath
            VerificationStatus = $verification.Status
            ErrorMessage       = if ($verification.Accepted) { $null } else { 'Existing package-file staging file did not satisfy verification.' }
        }) | Out-Null

        if ($verification.Accepted) {
            $PackageResult.PackageFilePreparation = [pscustomobject]@{
                Success         = $true
                Status          = 'ReusedPackageFile'
                PackageFilePath = $PackageResult.PackageFilePath
                SelectedSource  = [pscustomobject]@{
                    SourceScope = 'packageFileStaging'
                    SourceId    = 'packageFileStaging'
                    SourceKind  = 'filesystem'
                    ResolvedSource = $PackageResult.PackageFilePath
                }
                Verification    = $verification
                Attempts        = @($attempts.ToArray())
                FailureReason   = $null
                ErrorMessage    = $null
            }
            Write-PackageExecutionMessage -Message ("[ACTION] Reused package-file staging file '{0}'." -f $PackageResult.PackageFilePath)
            return $PackageResult
        }
    }

    $null = New-Item -ItemType Directory -Path $PackageResult.PackageFileStagingDirectory -Force

    foreach ($candidate in $orderedCandidates) {
        $sourceDefinition = $null
        $resolvedSource = $null
        $verification = $null
        $stagingPath = '{0}.{1}.partial' -f $PackageResult.PackageFilePath, ([guid]::NewGuid().ToString('N'))

        try {
            if ($candidate.sourceRef) {
                $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $packageConfig -SourceRef $candidate.sourceRef
            }
            elseif ([string]::Equals([string]$candidate.kind, 'vendorDownload', [System.StringComparison]::OrdinalIgnoreCase) -and
                $candidate.PSObject.Properties['url'] -and
                -not [string]::IsNullOrWhiteSpace([string]$candidate.url)) {
                $sourceDefinition = [pscustomobject]@{
                    Scope            = 'direct'
                    Id               = 'directDownload'
                    Kind             = 'download'
                    BaseUri          = $null
                    BasePath         = $null
                    GitHubOwner      = $null
                    GitHubRepository = $null
                }
            }
            elseif ([string]::Equals([string]$candidate.kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
                $sourceDefinition = [pscustomobject]@{
                    Scope   = 'direct'
                    Id      = 'directFilesystem'
                    Kind    = 'filesystem'
                    BaseUri = $null
                    BasePath = $null
                }
            }
            else {
                throw "Package acquisition candidate kind '$($candidate.kind)' could not be resolved to a source definition."
            }
            $resolvedSource = Resolve-PackageSource -SourceDefinition $sourceDefinition -AcquisitionCandidate $candidate -Package $package

            switch -Exact ([string]$resolvedSource.Kind) {
                'download' {
                    $null = Save-PackageDownloadFile -Uri $resolvedSource.ResolvedSource -TargetPath $stagingPath
                }
                'filesystem' {
                    $null = Save-PackageFilesystemFile -SourcePath $resolvedSource.ResolvedSource -TargetPath $stagingPath
                }
                default {
                    throw "Unsupported package-file source kind '$($resolvedSource.Kind)'."
                }
            }

            $verification = Test-PackageSavedFile -Path $stagingPath -Verification $candidate.verification
            if (-not $verification.Accepted) {
                if (Test-Path -LiteralPath $stagingPath) {
                    Remove-Item -LiteralPath $stagingPath -Force -ErrorAction SilentlyContinue
                }

                $attempts.Add([pscustomobject]@{
                    AttemptType        = 'Save'
                    Status             = 'Failed'
                    SourceScope        = $sourceDefinition.Scope
                    SourceId           = $sourceDefinition.Id
                    SourceKind         = $resolvedSource.Kind
                    ResolvedSource     = $resolvedSource.ResolvedSource
                    VerificationStatus = $verification.Status
                    ErrorMessage       = 'Saved package file did not satisfy verification.'
                }) | Out-Null

                if (-not $packageConfig.AllowAcquisitionFallback) {
                    break
                }

                continue
            }

            if (Test-Path -LiteralPath $PackageResult.PackageFilePath) {
                Remove-Item -LiteralPath $PackageResult.PackageFilePath -Force
            }
            Move-Item -LiteralPath $stagingPath -Destination $PackageResult.PackageFilePath -Force

            $saveStatus = if ([string]::Equals([string]$sourceDefinition.Scope, 'environment', [System.StringComparison]::OrdinalIgnoreCase) -and
                [string]::Equals([string]$sourceDefinition.Id, 'defaultPackageDepot', [System.StringComparison]::OrdinalIgnoreCase)) {
                'HydratedFromDefaultPackageDepot'
            }
            else {
                'SavedPackageFile'
            }

            $attempts.Add([pscustomobject]@{
                AttemptType        = 'Save'
                Status             = $saveStatus
                SourceScope        = $sourceDefinition.Scope
                SourceId           = $sourceDefinition.Id
                SourceKind         = $resolvedSource.Kind
                ResolvedSource     = $resolvedSource.ResolvedSource
                VerificationStatus = $verification.Status
                ErrorMessage       = $null
            }) | Out-Null

            $PackageResult.PackageFilePreparation = [pscustomobject]@{
                Success         = $true
                Status          = $saveStatus
                PackageFilePath = $PackageResult.PackageFilePath
                SelectedSource  = [pscustomobject]@{
                    SourceScope    = $sourceDefinition.Scope
                    SourceId       = $sourceDefinition.Id
                    SourceKind     = $resolvedSource.Kind
                    ResolvedSource = $resolvedSource.ResolvedSource
                }
                Verification    = $verification
                Attempts        = @($attempts.ToArray())
                FailureReason   = $null
                ErrorMessage    = $null
            }
            Write-PackageExecutionMessage -Message ("[ACTION] Saved package file from '{0}:{1}'." -f $sourceDefinition.Scope, $sourceDefinition.Id)
            return $PackageResult
        }
        catch {
            if (Test-Path -LiteralPath $stagingPath) {
                Remove-Item -LiteralPath $stagingPath -Force -ErrorAction SilentlyContinue
            }

            $attempts.Add([pscustomobject]@{
                AttemptType        = 'Save'
                Status             = 'Failed'
                SourceScope        = if ($sourceDefinition) { $sourceDefinition.Scope } elseif ($candidate.sourceRef) { [string]$candidate.sourceRef.scope } else { $null }
                SourceId           = if ($sourceDefinition) { $sourceDefinition.Id } elseif ($candidate.sourceRef) { [string]$candidate.sourceRef.id } else { $null }
                SourceKind         = if ($resolvedSource) { $resolvedSource.Kind } else { $null }
                ResolvedSource     = if ($resolvedSource) { $resolvedSource.ResolvedSource } else { $null }
                VerificationStatus = if ($verification) { $verification.Status } else { $null }
                ErrorMessage       = $_.Exception.Message
            }) | Out-Null

            if (-not $packageConfig.AllowAcquisitionFallback) {
                break
            }
        }
    }

    $failureReason = if ($offline) { 'DepotMiss' } else { 'AllSourcesFailed' }
    $errorMessage = if ($offline) {
        "Offline acquisition failed for Package release '$($package.id)': no packageDepot candidate provided a verified depot artifact. vendorDownload and package-definition filesystem candidates were skipped by policy."
    }
    else {
        "All acquisition candidates failed for Package release '$($package.id)'."
    }

    $PackageResult.PackageFilePreparation = [pscustomobject]@{
        Success         = $false
        Status          = 'Failed'
        PackageFilePath = $PackageResult.PackageFilePath
        SelectedSource  = $null
        Verification    = $null
        Attempts        = @($attempts.ToArray())
        FailureReason   = $failureReason
        ErrorMessage    = $errorMessage
    }

    if ($offline) {
        Write-PackageExecutionMessage -Level 'ERR' -Message ("[ACTION] Offline depot acquisition failed for release '{0}'." -f $package.id)
    }
    else {
        Write-PackageExecutionMessage -Level 'ERR' -Message ("[ACTION] All acquisition candidates failed for release '{0}'." -f $package.id)
    }

    return $PackageResult
}
