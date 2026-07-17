<#
    Public package catalog-signature and trust management surface.
#>

function Add-PackageTrustCommandMessages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject]$InputObject,

        [string[]]$Messages = @(),

        [string[]]$NextSteps = @()
    )

    process {
        foreach ($message in @($Messages)) {
            if (-not [string]::IsNullOrWhiteSpace($message)) {
                Write-PackageExecutionMessage -Message ("[ACTION] {0}" -f $message)
            }
        }
        foreach ($nextStep in @($NextSteps)) {
            if (-not [string]::IsNullOrWhiteSpace($nextStep)) {
                Write-PackageExecutionMessage -Message ("[NEXT] {0}" -f $nextStep)
            }
        }

        $InputObject | Add-Member -MemberType NoteProperty -Name 'Messages' -Value @($Messages) -Force
        $InputObject | Add-Member -MemberType NoteProperty -Name 'NextSteps' -Value @($NextSteps) -Force
        return $InputObject
    }
}

function Get-PackageDefinitionPublisherIdForSigning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DefinitionInfo
    )

    $document = $DefinitionInfo.Document
    if (-not $document.PSObject.Properties['definitionPublication'] -or
        -not $document.definitionPublication -or
        -not $document.definitionPublication.PSObject.Properties['publisherId'] -or
        [string]::IsNullOrWhiteSpace([string]$document.definitionPublication.publisherId)) {
        throw "Package definition '$($DefinitionInfo.Path)' is missing definitionPublication.publisherId. Set it to the publisher id used by New-PackageSigningCertificate."
    }

    return [string]$document.definitionPublication.publisherId
}

function New-PackageSigningCertificate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$Name = $null,

        [AllowNull()]
        [string]$PublisherId = $null,

        [AllowNull()]
        [string]$PublisherName = $null,

        [AllowNull()]
        [string]$CommonName = $null,

        [AllowNull()]
        [string]$Organization = $null,

        [AllowNull()]
        [string]$OrganizationalUnit = $null,

        [AllowNull()]
        [string]$Country = $null,

        [AllowNull()]
        [string]$SignerDisplayName = $null,

        [AllowNull()]
        [string]$TrustReason = $null,

        [AllowNull()]
        [string]$OutputDirectory = $null,

        [AllowNull()]
        [string]$PfxPath = $null,

        [AllowNull()]
        [string]$CertificatePath = $null,

        [AllowNull()]
        [string]$SigningDescriptorPath = $null,

        [Parameter(Mandatory = $true)]
        [securestring]$Password,

        [AllowNull()]
        [string]$Subject = $null,

        [ValidateRange(2048, 16384)]
        [int]$KeyLength = 3072,

        [ValidateRange(1, 50)]
        [int]$ValidYears = 10
    )

    if (-not ([type]'System.Security.Cryptography.X509Certificates.CertificateRequest')) {
        throw 'This PowerShell/.NET runtime does not expose CertificateRequest. Create a PFX externally or run this command on PowerShell 7+.'
    }

    $usesFriendlyProfile = -not [string]::IsNullOrWhiteSpace($Name)
    if (-not $usesFriendlyProfile -and [string]::IsNullOrWhiteSpace($PfxPath)) {
        throw "Use either -Name for the friendly signing-profile workflow or -PfxPath for an explicit PFX path."
    }

    if ([string]::IsNullOrWhiteSpace($PublisherId)) {
        $PublisherId = if ($usesFriendlyProfile) { $Name } else { $null }
    }
    if (-not [string]::IsNullOrWhiteSpace($PublisherId)) {
        Assert-PackagePublisherId -PublisherId $PublisherId
    }
    if ([string]::IsNullOrWhiteSpace($PublisherName) -and -not [string]::IsNullOrWhiteSpace($PublisherId)) {
        $PublisherName = $PublisherId
    }
    if ([string]::IsNullOrWhiteSpace($Subject)) {
        if ([string]::IsNullOrWhiteSpace($CommonName)) {
            if (-not [string]::IsNullOrWhiteSpace($PublisherId)) {
                $CommonName = "$PublisherId Package Catalog Signing"
            }
            elseif ($usesFriendlyProfile) {
                $CommonName = "$Name Package Catalog Signing"
            }
            else {
                $CommonName = 'Eigenverft Package Catalog Signing'
            }
        }
        $Subject = New-PackageCertificateSubject -CommonName $CommonName -Organization $Organization -OrganizationalUnit $OrganizationalUnit -Country $Country
    }
    if ([string]::IsNullOrWhiteSpace($SignerDisplayName)) {
        $SignerDisplayName = if (-not [string]::IsNullOrWhiteSpace($CommonName)) { $CommonName } else { $Subject }
    }

    $safeName = if ($usesFriendlyProfile) { ConvertTo-PackageSafeFileName -Value $Name } else { $null }
    if ($usesFriendlyProfile) {
        $baseDirectory = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { Get-PackageDefaultSigningDirectory } else { [System.IO.Path]::GetFullPath($OutputDirectory) }
        $profileDirectory = Join-Path $baseDirectory $safeName
        if ([string]::IsNullOrWhiteSpace($PfxPath)) {
            $PfxPath = Join-Path $profileDirectory ("{0}.catalog-signing.pfx" -f $safeName)
        }
        if ([string]::IsNullOrWhiteSpace($CertificatePath)) {
            $CertificatePath = Join-Path $profileDirectory ("{0}.catalog-signing.cer" -f $safeName)
        }
        if ([string]::IsNullOrWhiteSpace($SigningDescriptorPath)) {
            $SigningDescriptorPath = Join-Path $profileDirectory ("{0}.catalog-signing.json" -f $safeName)
        }
    }

    $resolvedPfxPath = [System.IO.Path]::GetFullPath($PfxPath)
    $resolvedCertificatePath = if ([string]::IsNullOrWhiteSpace($CertificatePath)) { $null } else { [System.IO.Path]::GetFullPath($CertificatePath) }
    $resolvedSigningDescriptorPath = if ([string]::IsNullOrWhiteSpace($SigningDescriptorPath)) { $null } else { [System.IO.Path]::GetFullPath($SigningDescriptorPath) }
    $rsa = [System.Security.Cryptography.RSA]::Create($KeyLength)
    $certificate = $null
    try {
        $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
            $Subject,
            $rsa,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
        )
        $request.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($false, $false, 0, $true)) | Out-Null
        $request.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new([System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature, $true)) | Out-Null
        $request.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509SubjectKeyIdentifierExtension]::new($request.PublicKey, $false)) | Out-Null

        $notBefore = [DateTimeOffset]::UtcNow.AddDays(-1)
        $notAfter = [DateTimeOffset]::UtcNow.AddYears($ValidYears)
        $certificate = $request.CreateSelfSigned($notBefore, $notAfter)
        try {
            $certificate.FriendlyName = $SignerDisplayName
        }
        catch {
            # FriendlyName is not writable on every platform/runtime.
        }

        $thumbprint = (($certificate.Thumbprint -replace '\s', '').ToUpperInvariant())
        $messages = New-Object System.Collections.Generic.List[string]
        $nextSteps = New-Object System.Collections.Generic.List[string]
        if ($PSCmdlet.ShouldProcess($resolvedPfxPath, 'Create package signing certificate PFX')) {
            $pfxDirectory = Split-Path -Parent $resolvedPfxPath
            if (-not [string]::IsNullOrWhiteSpace($pfxDirectory)) {
                $null = New-Item -ItemType Directory -Path $pfxDirectory -Force
            }

            $plainTextPassword = ConvertFrom-PackageSecureString -SecureString $Password
            try {
                [System.IO.File]::WriteAllBytes($resolvedPfxPath, $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $plainTextPassword))
            }
            finally {
                $plainTextPassword = $null
            }
            $messages.Add("Created private signing certificate PFX '$resolvedPfxPath'.") | Out-Null

            if (-not [string]::IsNullOrWhiteSpace($resolvedCertificatePath)) {
                $certDirectory = Split-Path -Parent $resolvedCertificatePath
                if (-not [string]::IsNullOrWhiteSpace($certDirectory)) {
                    $null = New-Item -ItemType Directory -Path $certDirectory -Force
                }
                if ([string]::Equals([System.IO.Path]::GetExtension($resolvedCertificatePath), '.pem', [System.StringComparison]::OrdinalIgnoreCase)) {
                    ConvertTo-PackageCertificatePem -Certificate $certificate | Set-Content -LiteralPath $resolvedCertificatePath -Encoding ascii
                }
                else {
                    [System.IO.File]::WriteAllBytes($resolvedCertificatePath, $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
                }
                $messages.Add("Exported public signing certificate '$resolvedCertificatePath'.") | Out-Null
            }

            if (-not [string]::IsNullOrWhiteSpace($resolvedSigningDescriptorPath)) {
                Save-PackageSigningPasswordDescriptor -Path $resolvedSigningDescriptorPath -Password $Password
                $messages.Add("Saved local signing password descriptor '$resolvedSigningDescriptorPath'.") | Out-Null
            }

            if ($usesFriendlyProfile) {
                $nextSteps.Add("Sign a package definition with: Sign-PackageDefinition -Path '<definition-json>' -Cert '$safeName'.") | Out-Null
                if (-not [string]::IsNullOrWhiteSpace($resolvedCertificatePath)) {
                    $nextSteps.Add("Share the public .cer file with clients: $resolvedCertificatePath.") | Out-Null
                    $nextSteps.Add("Clients can trust it with: Import-PackageTrust -Path '$resolvedCertificatePath'.") | Out-Null
                }
            }
        }

        $result = [pscustomobject]@{
            Name                = if ($usesFriendlyProfile) { $Name } else { $null }
            PublisherId         = $PublisherId
            PublisherName       = $PublisherName
            PfxPath             = $resolvedPfxPath
            CertificatePath     = $resolvedCertificatePath
            SigningDescriptorPath = $resolvedSigningDescriptorPath
            Subject             = [string]$certificate.Subject
            CommonName          = $CommonName
            Organization        = $Organization
            OrganizationalUnit  = $OrganizationalUnit
            Country             = if ([string]::IsNullOrWhiteSpace($Country)) { $null } else { $Country.Trim().ToUpperInvariant() }
            SignerDisplayName   = $SignerDisplayName
            TrustReason         = $TrustReason
            Thumbprint          = $thumbprint
            NotBeforeUtc        = $certificate.NotBefore.ToUniversalTime().ToString('o')
            NotAfterUtc         = $certificate.NotAfter.ToUniversalTime().ToString('o')
            SignatureAlgorithm  = [string]$certificate.SignatureAlgorithm.FriendlyName
        }
        return Add-PackageTrustCommandMessages -InputObject $result -Messages @($messages.ToArray()) -NextSteps @($nextSteps.ToArray())
    }
    finally {
        if ($certificate) { $certificate.Dispose() }
        if ($rsa) { $rsa.Dispose() }
    }
}

function Sign-PackageDefinition {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string]$Path,

        [AllowNull()]
        [string]$Cert = $null,

        [AllowNull()]
        [securestring]$Password = $null,

        [switch]$KeepSchemaVersion
    )

    process {
        $definitionInfo = Read-PackageJsonDocument -Path $Path
        $publisherId = Get-PackageDefinitionPublisherIdForSigning -DefinitionInfo $definitionInfo
        $signingReference = Resolve-PackageSigningCertificateReference -Cert $Cert -Password $Password

        $certificate = Import-PackageCertificate -Path $signingReference.PfxPath -Password $signingReference.Password -WithPrivateKey
        try {
            if (-not $KeepSchemaVersion.IsPresent) {
                Set-PackageObjectProperty -InputObject $definitionInfo.Document -Name 'schemaVersion' -Value '2.0'
                if ($definitionInfo.Document.PSObject.Properties['$schema'] -and -not [string]::IsNullOrWhiteSpace([string]$definitionInfo.Document.'$schema')) {
                    Set-PackageObjectProperty -InputObject $definitionInfo.Document -Name '$schema' -Value (([string]$definitionInfo.Document.'$schema') -replace 'package-definition-[0-9]+\.[0-9]+\.schema\.json', 'package-definition-2.0.schema.json')
                }
            }

            if ($PSCmdlet.ShouldProcess($definitionInfo.Path, 'Sign package definition')) {
                $signature = Invoke-PackageDefinitionDocumentSigning -Definition $definitionInfo.Document -Certificate $certificate
                Save-PackageJsonDocument -Path $definitionInfo.Path -Document $definitionInfo.Document
                $verification = Test-PackageDefinitionSignatureDocument -Definition $definitionInfo.Document -Certificate $certificate
            }
            else {
                $signature = $null
                $verification = $null
            }

            $messages = @(
                if ($signature) {
                    "Signed package definition '$($definitionInfo.Path)' with key '$($signature.KeyThumbprint)'."
                    "Verified embedded signature status '$($verification.Status)'."
                    if ([string]::Equals([string]$signingReference.PasswordSource, 'descriptor', [System.StringComparison]::OrdinalIgnoreCase)) {
                        "Used local signing password descriptor '$($signingReference.DescriptorPath)'."
                    }
                    elseif ([string]::Equals([string]$signingReference.PasswordSource, 'environment', [System.StringComparison]::OrdinalIgnoreCase)) {
                        "Used signing password from environment variable '$(Get-PackageSigningPasswordEnvironmentVariableName)'."
                    }
                }
                else {
                    "Prepared package definition signing for '$($definitionInfo.Path)' without writing changes."
                }
            )
            $nextSteps = @(
                "Publish or keep the signed definition in the endpoint scanned by PackageEndpointInventory.json."
                "Clients can trust the embedded certificate during Invoke-Package, or preseed trust with a public .cer using Import-PackageTrust -Path '<public-cert.cer>'."
            )
            $result = [pscustomobject]@{
                Path                 = $definitionInfo.Path
                PublisherId          = $publisherId
                Cert                 = $Cert
                PfxPath              = [System.IO.Path]::GetFullPath($signingReference.PfxPath)
                SigningDescriptorPath = $signingReference.DescriptorPath
                PasswordSource       = [string]$signingReference.PasswordSource
                KeyThumbprint        = if ($signature) { $signature.KeyThumbprint } else { (($certificate.Thumbprint -replace '\s', '').ToUpperInvariant()) }
                CanonicalContentHash = if ($signature) { $signature.CanonicalContentHash } else { $null }
                VerificationStatus   = if ($verification) { $verification.Status } else { 'WhatIf' }
                Valid                = if ($verification) { [bool]$verification.Valid } else { $false }
            }
            return Add-PackageTrustCommandMessages -InputObject $result -Messages $messages -NextSteps $nextSteps
        }
        finally {
            $certificate.Dispose()
        }
    }
}

function Resign-PackageDefinition {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string]$Path,

        [AllowNull()]
        [string]$Cert = $null,

        [AllowNull()]
        [securestring]$Password = $null,

        [switch]$KeepSchemaVersion
    )

    process {
        return Sign-PackageDefinition -Path $Path -Cert $Cert -Password $Password -KeepSchemaVersion:$KeepSchemaVersion
    }
}

function Verify-PackageDefinitionSignature {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string]$Path,

        [AllowNull()]
        [string]$CertificatePath = $null,

        [AllowNull()]
        [string]$CertificatePem = $null,

        [switch]$RequireTrusted,

        [switch]$ErrorOnFailure
    )

    process {
        $definitionInfo = Read-PackageJsonDocument -Path $Path
        $certificate = $null
        $trustInventory = $null
        try {
            if (-not [string]::IsNullOrWhiteSpace($CertificatePath)) {
                $certificate = Import-PackageCertificate -Path $CertificatePath
            }
            elseif (-not [string]::IsNullOrWhiteSpace($CertificatePem)) {
                $certificate = ConvertFrom-PackageCertificatePem -CertificatePem $CertificatePem
            }
            else {
                $trustInventory = (Get-PackageTrustInventoryInfo).Document
            }

            $result = Test-PackageDefinitionSignatureDocument -Definition $definitionInfo.Document -Certificate $certificate -TrustInventoryDocument $trustInventory
            $result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $definitionInfo.Path -Force

            if ($RequireTrusted.IsPresent -and -not [bool]$result.Trusted) {
                $message = if ([string]::IsNullOrWhiteSpace([string]$result.ErrorMessage)) { "Package definition '$($definitionInfo.Path)' is not trusted." } else { [string]$result.ErrorMessage }
                if ($ErrorOnFailure.IsPresent) {
                    throw $message
                }
            }
            elseif ($ErrorOnFailure.IsPresent -and -not [bool]$result.Valid) {
                $message = if ([string]::IsNullOrWhiteSpace([string]$result.ErrorMessage)) { "Package definition '$($definitionInfo.Path)' signature is not valid." } else { [string]$result.ErrorMessage }
                throw $message
            }

            return $result
        }
        finally {
            if ($certificate) { $certificate.Dispose() }
        }
    }
}

function Verify-PackageDefinitionCatalog {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [AllowNull()]
        [string]$CertificatePath = $null,

        [switch]$RequireTrusted,

        [switch]$ErrorOnFailure
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $jsonFiles = if (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
        @((Get-Item -LiteralPath $resolvedPath))
    }
    else {
        @(Get-ChildItem -LiteralPath $resolvedPath -Filter '*.json' -File -Recurse)
    }

    $results = @(
        foreach ($jsonFile in @($jsonFiles)) {
            Verify-PackageDefinitionSignature -Path $jsonFile.FullName -CertificatePath $CertificatePath -RequireTrusted:$RequireTrusted -ErrorOnFailure:$ErrorOnFailure
        }
    )

    return [pscustomobject]@{
        Path          = $resolvedPath
        CheckedCount  = $results.Count
        ValidCount    = @($results | Where-Object { [bool]$_.Valid }).Count
        TrustedCount  = @($results | Where-Object { [bool]$_.Trusted }).Count
        FailedCount   = @($results | Where-Object { -not [bool]$_.Valid }).Count
        Results       = @($results)
    }
}

function Remove-PackageDefinitionSignature {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string]$Path,

        [switch]$KeepSchemaVersion
    )

    process {
        $definitionInfo = Read-PackageJsonDocument -Path $Path
        if (-not $KeepSchemaVersion.IsPresent) {
            Set-PackageObjectProperty -InputObject $definitionInfo.Document -Name 'schemaVersion' -Value '2.0'
            if ($definitionInfo.Document.PSObject.Properties['$schema'] -and -not [string]::IsNullOrWhiteSpace([string]$definitionInfo.Document.'$schema')) {
                Set-PackageObjectProperty -InputObject $definitionInfo.Document -Name '$schema' -Value (([string]$definitionInfo.Document.'$schema') -replace 'package-definition-[0-9]+\.[0-9]+\.schema\.json', 'package-definition-2.0.schema.json')
            }
        }
        Set-PackageDefinitionUnsignedSignature -Definition $definitionInfo.Document

        if ($PSCmdlet.ShouldProcess($definitionInfo.Path, 'Remove package definition signature')) {
            Save-PackageJsonDocument -Path $definitionInfo.Path -Document $definitionInfo.Document
        }

        $result = [pscustomobject]@{
            Path          = $definitionInfo.Path
            SchemaVersion = [string]$definitionInfo.Document.schemaVersion
            Status        = 'Unsigned'
        }
        return Add-PackageTrustCommandMessages -InputObject $result -Messages @("Removed embedded package definition signature from '$($definitionInfo.Path)'.") -NextSteps @("Re-sign this definition with Resign-PackageDefinition -Path '$($definitionInfo.Path)' -Cert '<signing-name-or-pfx>' before using strict catalog trust.")
    }
}

function Get-PackageTrust {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$PublisherId = $null,

        [AllowNull()]
        [string]$KeyThumbprint = $null
    )

    $rows = @(Get-PackageTrustSummaries)
    if (-not [string]::IsNullOrWhiteSpace($PublisherId)) {
        $rows = @($rows | Where-Object { [string]::Equals([string]$_.PublisherId, $PublisherId, [System.StringComparison]::OrdinalIgnoreCase) })
    }
    if (-not [string]::IsNullOrWhiteSpace($KeyThumbprint)) {
        $normalizedThumbprint = (($KeyThumbprint -replace '\s', '').ToUpperInvariant())
        $rows = @($rows | Where-Object { [string]::Equals(([string]$_.KeyThumbprint).ToUpperInvariant(), $normalizedThumbprint, [System.StringComparison]::OrdinalIgnoreCase) })
    }

    return $rows
}

function Get-PackageSigningProfile {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Name = $null,

        [AllowNull()]
        [string]$PublisherId = $null,

        [AllowNull()]
        [string]$KeyThumbprint = $null
    )

    $rows = @(Get-PackageSigningProfileSummaries)
    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        $rows = @($rows | Where-Object { [string]::Equals([string]$_.Name, $Name, [System.StringComparison]::OrdinalIgnoreCase) })
    }
    if (-not [string]::IsNullOrWhiteSpace($PublisherId)) {
        $rows = @($rows | Where-Object { [string]::Equals([string]$_.PublisherId, $PublisherId, [System.StringComparison]::OrdinalIgnoreCase) })
    }
    if (-not [string]::IsNullOrWhiteSpace($KeyThumbprint)) {
        $normalizedThumbprint = (($KeyThumbprint -replace '\s', '').ToUpperInvariant())
        $rows = @($rows | Where-Object { [string]::Equals(([string]$_.KeyThumbprint).ToUpperInvariant(), $normalizedThumbprint, [System.StringComparison]::OrdinalIgnoreCase) })
    }

    return $rows
}

function Trust-PackageSigningCertificate {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CertificatePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PublisherId,

        [AllowNull()]
        [string]$PublisherName = $null,

        [AllowNull()]
        [string]$SignerDisplayName = $null,

        [string]$TrustSource = 'userApproved',

        [AllowNull()]
        [string]$TrustReason = $null,

        [switch]$Force
    )

    $certificate = Import-PackageCertificate -Path $CertificatePath
    try {
        $entry = New-PackageTrustEntry -Certificate $certificate -PublisherId $PublisherId -PublisherName $PublisherName -SignerDisplayName $SignerDisplayName -TrustSource $TrustSource -TrustReason $TrustReason
        $documentInfo = Get-PackageTrustInventoryEditInfo
        $existing = Get-PackageTrustEntryByThumbprint -Document $documentInfo.Document -KeyThumbprint ([string]$entry.keyThumbprint)
        if ($existing -and -not $Force.IsPresent) {
            throw "Package signing certificate '$($entry.keyThumbprint)' already exists in '$($documentInfo.Path)'. Use -Force to replace it."
        }

        if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Trust package signing certificate '$($entry.keyThumbprint)'")) {
            $documentInfo.Document.keys = @(@($documentInfo.Document.keys) | Where-Object {
                    -not [string]::Equals(([string]$_.keyThumbprint).ToUpperInvariant(), ([string]$entry.keyThumbprint).ToUpperInvariant(), [System.StringComparison]::OrdinalIgnoreCase)
                }) + $entry
            Save-PackageTrustInventoryDocument -DocumentInfo $documentInfo
        }

        $summary = Select-PackageTrustSummary -Entry $entry -InventoryPath $documentInfo.Path
        return Add-PackageTrustCommandMessages -InputObject $summary -Messages @("Trusted package signing certificate '$($entry.keyThumbprint)' for publisher '$PublisherId'.") -NextSteps @("Signed definitions for publisher '$PublisherId' can now resolve when catalogTrust.policy is strict.")
    }
    finally {
        $certificate.Dispose()
    }
}

function Untrust-PackageSigningCertificate {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$KeyThumbprint,

        [AllowNull()]
        [string]$Reason = 'Disabled by Untrust-PackageSigningCertificate.'
    )

    $documentInfo = Get-PackageTrustInventoryEditInfo
    $entry = Get-PackageTrustEntryByThumbprint -Document $documentInfo.Document -KeyThumbprint $KeyThumbprint
    if (-not $entry) {
        throw "Package signing certificate '$KeyThumbprint' was not found in '$($documentInfo.Path)'."
    }

    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Untrust package signing certificate '$KeyThumbprint'")) {
        Set-PackageObjectProperty -InputObject $entry -Name 'enabled' -Value $false
        Set-PackageObjectProperty -InputObject $entry -Name 'trustReason' -Value $Reason
        Save-PackageTrustInventoryDocument -DocumentInfo $documentInfo
    }

    $summary = Select-PackageTrustSummary -Entry $entry -InventoryPath $documentInfo.Path
    return Add-PackageTrustCommandMessages -InputObject $summary -Messages @("Disabled package signing trust '$KeyThumbprint'.") -NextSteps @("Use Get-PackageTrust to review current trust status, or Import-PackageTrust to add a replacement key.")
}

function Revoke-PackageSigningCertificate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$KeyThumbprint,

        [AllowNull()]
        [string]$Reason = 'Revoked by Revoke-PackageSigningCertificate.'
    )

    $documentInfo = Get-PackageTrustInventoryEditInfo
    $entry = Get-PackageTrustEntryByThumbprint -Document $documentInfo.Document -KeyThumbprint $KeyThumbprint
    if (-not $entry) {
        throw "Package signing certificate '$KeyThumbprint' was not found in '$($documentInfo.Path)'. Use Block-PackageSigningCertificate to block an unknown thumbprint."
    }

    $normalizedThumbprint = (([string]$entry.keyThumbprint -replace '\s', '').ToUpperInvariant())
    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Revoke package signing certificate '$normalizedThumbprint'")) {
        Set-PackageObjectProperty -InputObject $entry -Name 'enabled' -Value $false
        Set-PackageObjectProperty -InputObject $entry -Name 'revokedAtUtc' -Value ([DateTime]::UtcNow.ToString('o'))
        Set-PackageObjectProperty -InputObject $entry -Name 'revocationReason' -Value $Reason
        Set-PackageObjectProperty -InputObject $entry -Name 'revokedBy' -Value ([Environment]::UserName)

        if (-not (Test-PackageKeyThumbprintRevoked -TrustInventoryDocument $documentInfo.Document -KeyThumbprint $normalizedThumbprint -PublisherId ([string]$entry.publisherId))) {
            $documentInfo.Document.revokedKeys = @($documentInfo.Document.revokedKeys) + [pscustomobject][ordered]@{
                keyThumbprint = $normalizedThumbprint
                publisherId   = [string]$entry.publisherId
                source        = 'user'
                reason        = $Reason
                addedAtUtc    = [DateTime]::UtcNow.ToString('o')
            }
        }
        Save-PackageTrustInventoryDocument -DocumentInfo $documentInfo
    }

    $summary = Select-PackageTrustSummary -Entry $entry -InventoryPath $documentInfo.Path
    return Add-PackageTrustCommandMessages -InputObject $summary -Messages @("Revoked package signing certificate '$normalizedThumbprint'.") -NextSteps @("Replace affected signed definitions with a new trusted signing key.")
}

function Block-PackageSigningCertificate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$KeyThumbprint,

        [AllowNull()]
        [string]$PublisherId = $null,

        [AllowNull()]
        [string]$Reason = 'Blocked by Block-PackageSigningCertificate.'
    )

    $documentInfo = Get-PackageTrustInventoryEditInfo
    $normalizedThumbprint = (($KeyThumbprint -replace '\s', '').ToUpperInvariant())
    if (-not [string]::IsNullOrWhiteSpace($PublisherId)) {
        Assert-PackagePublisherId -PublisherId $PublisherId
    }
    if (Test-PackageKeyThumbprintRevoked -TrustInventoryDocument $documentInfo.Document -KeyThumbprint $normalizedThumbprint -PublisherId $PublisherId) {
        throw "Package signing certificate '$normalizedThumbprint' is already blocked in '$($documentInfo.Path)'."
    }

    $block = [ordered]@{
        keyThumbprint = $normalizedThumbprint
        source        = 'user'
        reason        = $Reason
        addedAtUtc    = [DateTime]::UtcNow.ToString('o')
    }
    if (-not [string]::IsNullOrWhiteSpace($PublisherId)) {
        $block['publisherId'] = $PublisherId
    }

    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Block package signing certificate '$normalizedThumbprint'")) {
        $documentInfo.Document.revokedKeys = @($documentInfo.Document.revokedKeys) + ([pscustomobject]$block)
        Save-PackageTrustInventoryDocument -DocumentInfo $documentInfo
    }

    $result = [pscustomobject]$block
    return Add-PackageTrustCommandMessages -InputObject $result -Messages @("Blocked package signing certificate '$normalizedThumbprint'.") -NextSteps @("Use Import-PackageTrust or Trust-PackageSigningCertificate to trust a replacement key when needed.")
}

function Remove-PackageTrust {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$KeyThumbprint
    )

    $documentInfo = Get-PackageTrustInventoryEditInfo
    $entry = Get-PackageTrustEntryByThumbprint -Document $documentInfo.Document -KeyThumbprint $KeyThumbprint
    if (-not $entry) {
        throw "Package signing certificate '$KeyThumbprint' was not found in '$($documentInfo.Path)'."
    }
    $normalizedThumbprint = (([string]$entry.keyThumbprint -replace '\s', '').ToUpperInvariant())

    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Remove package trust '$normalizedThumbprint'")) {
        $documentInfo.Document.keys = @($documentInfo.Document.keys | Where-Object {
                -not [string]::Equals((([string]$_.keyThumbprint -replace '\s', '').ToUpperInvariant()), $normalizedThumbprint, [System.StringComparison]::OrdinalIgnoreCase)
            })
        Save-PackageTrustInventoryDocument -DocumentInfo $documentInfo
    }

    $result = [pscustomobject]@{
        Action        = 'Remove'
        KeyThumbprint = $normalizedThumbprint
        InventoryPath = $documentInfo.Path
        Status        = 'Removed'
    }
    return Add-PackageTrustCommandMessages -InputObject $result -Messages @("Removed package trust '$normalizedThumbprint' from '$($documentInfo.Path)'.") -NextSteps @("Use Import-PackageTrust to add this public key again if definitions still need it.")
}

function Export-PackageTrust {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$KeyThumbprint = $null,

        [AllowNull()]
        [string]$CertificatePath = $null,

        [AllowNull()]
        [string]$PublisherId = $null,

        [AllowNull()]
        [string]$PublisherName = $null,

        [AllowNull()]
        [string]$SignerDisplayName = $null,

        [string]$TrustSource = 'exported',

        [AllowNull()]
        [string]$TrustReason = $null,

        [AllowNull()]
        [string]$OutputPath = $null
    )

    if ([string]::IsNullOrWhiteSpace($KeyThumbprint) -and [string]::IsNullOrWhiteSpace($CertificatePath)) {
        throw 'Use either -KeyThumbprint or -CertificatePath.'
    }

    if (-not [string]::IsNullOrWhiteSpace($CertificatePath)) {
        if ([string]::IsNullOrWhiteSpace($PublisherId)) {
            throw 'PublisherId is required when exporting trust directly from a certificate file.'
        }
        $certificate = Import-PackageCertificate -Path $CertificatePath
        try {
            $entry = New-PackageTrustEntry -Certificate $certificate -PublisherId $PublisherId -PublisherName $PublisherName -SignerDisplayName $SignerDisplayName -TrustSource $TrustSource -TrustReason $TrustReason
        }
        finally {
            $certificate.Dispose()
        }
    }
    else {
        $documentInfo = Get-PackageTrustInventoryInfo
        $entry = Get-PackageTrustEntryByThumbprint -Document $documentInfo.Document -KeyThumbprint $KeyThumbprint
        if (-not $entry) {
            throw "Package trust '$KeyThumbprint' was not found in '$($documentInfo.Path)'."
        }
    }

    $export = New-PackageTrustExportDocument -Entry $entry

    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        Save-PackageJsonDocument -Path $OutputPath -Document $export
        $messages = @("Wrote package trust export '$([System.IO.Path]::GetFullPath($OutputPath))'.")
        $nextSteps = @("Clients can import this public trust export with Import-PackageTrust -Path '$([System.IO.Path]::GetFullPath($OutputPath))'.")
        $export | Add-Member -MemberType NoteProperty -Name 'OutputPath' -Value ([System.IO.Path]::GetFullPath($OutputPath)) -Force
        return Add-PackageTrustCommandMessages -InputObject $export -Messages $messages -NextSteps $nextSteps
    }

    return $export
}

function Import-PackageTrust {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [AllowNull()]
        [string]$PublisherId = $null,

        [AllowNull()]
        [string]$PublisherName = $null,

        [AllowNull()]
        [string]$SignerDisplayName = $null,

        [string]$TrustSource = 'imported',

        [AllowNull()]
        [string]$TrustReason = $null,

        [switch]$Force
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $extension = [System.IO.Path]::GetExtension($resolvedPath)
    $importLabel = $resolvedPath
    $certificate = $null
    $importInfo = $null
    if ($extension -in @('.cer', '.crt', '.pem')) {
        $certificate = Import-PackageCertificate -Path $resolvedPath
        try {
            if ([string]::IsNullOrWhiteSpace($PublisherId)) {
                $PublisherId = Resolve-PackagePublisherIdFromCertificate -Certificate $certificate
            }
            if ([string]::IsNullOrWhiteSpace($PublisherId)) {
                throw "Package trust certificate '$resolvedPath' does not contain an inferable publisher id. Use Import-PackageTrust -Path '$resolvedPath' -PublisherId '<publisherId>'."
            }
            if ([string]::IsNullOrWhiteSpace($PublisherName)) {
                $PublisherName = $PublisherId
            }
            $entries = @(New-PackageTrustEntry -Certificate $certificate -PublisherId $PublisherId -PublisherName $PublisherName -SignerDisplayName $SignerDisplayName -TrustSource $TrustSource -TrustReason $TrustReason)
        }
        finally {
            $certificate.Dispose()
        }
    }
    else {
        $importInfo = Read-PackageJsonDocument -Path $resolvedPath
        if ($importInfo.Document.PSObject.Properties['definitionPublication']) {
            throw "Import-PackageTrust imports public certificate files or package trust export JSON only. Package-definition JSON uses embedded certificate trust during Invoke-Package; run Invoke-Package -DefinitionId '<definitionId>' to review the trust prompt, or use Invoke-Package -DefinitionId '<definitionId>' -AcceptUnknownSigningKey for controlled auto-trust."
        }
        $entries = if ($importInfo.Document.PSObject.Properties['keys']) { @($importInfo.Document.keys) } else { @($importInfo.Document) }
    }

    if ($entries.Count -eq 0) {
        throw "Package trust import '$importLabel' does not contain any keys."
    }

    $documentInfo = Get-PackageTrustInventoryEditInfo
    $imported = New-Object System.Collections.Generic.List[object]
    foreach ($entry in @($entries)) {
        foreach ($requiredProperty in @('publisherId', 'publisherName', 'keyThumbprint', 'certificatePem')) {
            if (-not $entry.PSObject.Properties[$requiredProperty] -or [string]::IsNullOrWhiteSpace([string]$entry.$requiredProperty)) {
                throw "Package trust import '$importLabel' has an entry missing '$requiredProperty'."
            }
        }
        $normalizedThumbprint = (([string]$entry.keyThumbprint -replace '\s', '').ToUpperInvariant())
        $existing = Get-PackageTrustEntryByThumbprint -Document $documentInfo.Document -KeyThumbprint $normalizedThumbprint
        if ($existing -and -not $Force.IsPresent) {
            throw "Package signing certificate '$normalizedThumbprint' already exists in '$($documentInfo.Path)'. Use -Force to replace it."
        }

        Set-PackageObjectProperty -InputObject $entry -Name 'keyThumbprint' -Value $normalizedThumbprint
        if (-not $entry.PSObject.Properties['trustSource']) {
            Set-PackageObjectProperty -InputObject $entry -Name 'trustSource' -Value 'imported'
        }
        if (-not $entry.PSObject.Properties['trustedAtUtc']) {
            Set-PackageObjectProperty -InputObject $entry -Name 'trustedAtUtc' -Value ([DateTime]::UtcNow.ToString('o'))
        }
        if (-not $entry.PSObject.Properties['enabled']) {
            Set-PackageObjectProperty -InputObject $entry -Name 'enabled' -Value $true
        }
        if (-not $entry.PSObject.Properties['trustedBy']) {
            Set-PackageObjectProperty -InputObject $entry -Name 'trustedBy' -Value ([Environment]::UserName)
        }

        $documentInfo.Document.keys = @(@($documentInfo.Document.keys) | Where-Object {
                -not [string]::Equals((([string]$_.keyThumbprint -replace '\s', '').ToUpperInvariant()), $normalizedThumbprint, [System.StringComparison]::OrdinalIgnoreCase)
            }) + $entry
        $imported.Add($entry) | Out-Null
    }

    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Import package trust from '$importLabel'")) {
        Save-PackageTrustInventoryDocument -DocumentInfo $documentInfo
    }

    $messages = @(
        "Imported $($imported.Count) package signing trust entr$(if ($imported.Count -eq 1) { 'y' } else { 'ies' }) from '$importLabel'."
        "Updated package trust inventory '$($documentInfo.Path)'."
    )
    $nextSteps = @(
        "Run Invoke-Package after the matching endpoint is registered."
        "Use Get-PackageTrust to review trusted package signing keys."
    )
    $result = [pscustomobject]@{
        Action        = 'Import'
        InventoryPath = $documentInfo.Path
        SourcePath    = $importLabel
        ImportedCount = $imported.Count
        Keys          = @($imported.ToArray() | ForEach-Object { Select-PackageTrustSummary -Entry $_ -InventoryPath $documentInfo.Path })
    }
    return Add-PackageTrustCommandMessages -InputObject $result -Messages $messages -NextSteps $nextSteps
}
