<#
    Eigenverft.Manifested.Package Package - catalog trust
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - catalog trust' -Body {
    It 'creates the local PackageTrustInventory.json copy from shipped configuration when missing' {
        $localTrustInventoryPath = Get-PackageLocalTrustInventoryPath
        if (Test-Path -LiteralPath $localTrustInventoryPath -PathType Leaf) {
            Remove-Item -LiteralPath $localTrustInventoryPath -Force
        }

        $trustRows = @(Get-PackageTrust)
        $localInfo = Read-PackageJsonDocument -Path $localTrustInventoryPath

        Test-Path -LiteralPath $localTrustInventoryPath -PathType Leaf | Should -BeTrue
        $localInfo.Document.inventoryVersion | Should -Be 1
        @($localInfo.Document.keys).Count | Should -Be 1
        @($localInfo.Document.revokedKeys).Count | Should -Be 0
        $trustRows.Count | Should -Be 1
        $trustRows[0].PublisherId | Should -Be 'Eigenverft'
        $trustRows[0].TrustSource | Should -Be 'moduleShipped'
    }

    It 'canonicalizes ISO timestamp strings like parsed DateTime values across PowerShell runtimes' {
        $stringDocument = [pscustomobject]@{ publishedAtUtc = '2026-05-23T12:00:00Z' }
        $dateDocument = [pscustomobject]@{ publishedAtUtc = [datetime]'2026-05-23T12:00:00Z' }

        $stringCanonical = ConvertTo-PackageCanonicalJson -Value $stringDocument
        $dateCanonical = ConvertTo-PackageCanonicalJson -Value $dateDocument

        $stringCanonical | Should -Be $dateCanonical
        $stringCanonical | Should -Match '2026-05-23T12:00:00.0000000Z'
    }

    It 'creates a PFX signing certificate, signs a definition, verifies it, and strips it back to unsigned' {
        $rootPath = Join-Path $TestDrive 'sign-verify-strip'
        $pfxPath = Join-Path $rootPath 'eigenverft-package-catalog-signing.pfx'
        $certificatePath = Join-Path $rootPath 'eigenverft-package-catalog-signing.pem'
        $definitionPath = Join-Path $rootPath 'VSCodeRuntime.json'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $definition = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        Write-TestJsonDocument -Path $definitionPath -Document $definition

        $certificate = New-PackageSigningCertificate -PfxPath $pfxPath -CertificatePath $certificatePath -Password $password
        $signature = Sign-PackageDefinition -Path $definitionPath -CertificatePath $pfxPath -Password $password
        $verification = Verify-PackageDefinitionSignature -Path $definitionPath -CertificatePath $certificatePath
        $stripped = Remove-PackageDefinitionSignature -Path $definitionPath
        $strippedInfo = Read-PackageJsonDocument -Path $definitionPath

        Test-Path -LiteralPath $pfxPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $certificatePath -PathType Leaf | Should -BeTrue
        $certificate.Thumbprint | Should -Not -BeNullOrEmpty
        $signature.VerificationStatus | Should -Be 'validUntrusted'
        $verification.Valid | Should -BeTrue
        $verification.Status | Should -Be 'validUntrusted'
        $stripped.Status | Should -Be 'Unsigned'
        $strippedInfo.Document.schemaVersion | Should -Be '1.7'
        $strippedInfo.Document.definitionPublication.definitionSignature.kind | Should -Be 'unsigned'
        $strippedInfo.Document.definitionPublication.definitionSignature.PSObject.Properties['signatureValue'] | Should -BeNullOrEmpty
    }

    It 'creates a friendly signing profile and signs a definition without explicit certificate parameters' {
        $rootPath = Join-Path $TestDrive 'friendly-signing-profile'
        $definitionPath = Join-Path $rootPath 'MyPackage.json'
        $passwordText = 'CatalogTrust-Test-Password-123!'
        $password = ConvertTo-SecureString $passwordText -AsPlainText -Force
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        Write-TestJsonDocument -Path $definitionPath -Document $definition

        $created = New-PackageSigningCertificate -Name 'My Team' -Password $password -OutputDirectory (Join-Path $rootPath 'Signing')
        $profile = Get-PackageSigningProfile -PublisherId 'My Team'
        $profileRaw = Get-Content -LiteralPath (Get-PackageSigningProfileInventoryPath) -Raw
        $signature = Sign-PackageDefinition -Path $definitionPath
        $verification = Verify-PackageDefinitionSignature -Path $definitionPath -CertificatePath $created.CertificatePath

        Test-Path -LiteralPath $created.PfxPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $created.CertificatePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $created.TrustExportPath -PathType Leaf | Should -BeTrue
        $created.Messages | Should -Contain "Saved local signing profile 'My Team' for publisher 'My Team'."
        $created.NextSteps -join "`n" | Should -Match 'Sign-PackageDefinition -Path'
        @($profile).Count | Should -Be 1
        @($profile)[0].PublisherId | Should -Be 'My Team'
        @($profile)[0].PasswordStored | Should -BeTrue
        $profileRaw | Should -Not -Match [regex]::Escape($passwordText)
        $signature.UsedSigningProfile | Should -BeTrue
        $signature.VerificationStatus | Should -Be 'validUntrusted'
        $signature.Messages -join "`n" | Should -Match 'Signed package definition'
        $signature.NextSteps -join "`n" | Should -Match 'public .cer'
        $verification.Valid | Should -BeTrue
    }

    It 'fails one-command signing with a clear next step when no matching profile exists' {
        $rootPath = Join-Path $TestDrive 'missing-signing-profile'
        $definitionPath = Join-Path $rootPath 'MyPackage.json'
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        Write-TestJsonDocument -Path $definitionPath -Document $definition

        { Sign-PackageDefinition -Path $definitionPath } | Should -Throw "*No local package signing profile exists for publisher 'My Team'*New-PackageSigningCertificate -Name 'My Team'*"
    }

    It 'imports public CER trust directly and requires PublisherId when the certificate CN is not usable' {
        $rootPath = Join-Path $TestDrive 'import-cer-trust'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $friendly = New-PackageSigningCertificate -Name 'My Team' -Password $password -OutputDirectory (Join-Path $rootPath 'Friendly')
        $imported = Import-PackageTrust -Path $friendly.CertificatePath

        $explicitPfxPath = Join-Path $rootPath 'Explicit\bad-cn.pfx'
        $explicitCerPath = Join-Path $rootPath 'Explicit\bad-cn.cer'
        $null = New-PackageSigningCertificate -PfxPath $explicitPfxPath -CertificatePath $explicitCerPath -Password $password -Subject 'CN=123'

        { Import-PackageTrust -Path $explicitCerPath } | Should -Throw '*does not contain an inferable publisher id*'
        $fallback = Import-PackageTrust -Path $explicitCerPath -PublisherId 'FallbackPublisher' -PublisherName 'Fallback Publisher'

        $imported.ImportedCount | Should -Be 1
        $imported.Keys[0].PublisherId | Should -Be 'My Team'
        $imported.Messages -join "`n" | Should -Match 'Imported 1 package signing trust entry'
        $fallback.ImportedCount | Should -Be 1
        $fallback.Keys[0].PublisherId | Should -Be 'FallbackPublisher'
    }

    It 'trusts a signing certificate and verifies a signed definition as trusted' {
        $rootPath = Join-Path $TestDrive 'trusted-signature'
        $pfxPath = Join-Path $rootPath 'eigenverft-package-catalog-signing.pfx'
        $certificatePath = Join-Path $rootPath 'eigenverft-package-catalog-signing.pem'
        $definitionPath = Join-Path $rootPath 'VSCodeRuntime.json'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $definition = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        Write-TestJsonDocument -Path $definitionPath -Document $definition

        $certificate = New-PackageSigningCertificate -PfxPath $pfxPath -CertificatePath $certificatePath -Password $password
        $trust = Trust-PackageSigningCertificate -CertificatePath $certificatePath -PublisherId 'Eigenverft' -PublisherName 'Eigenverft' -SignerDisplayName 'Eigenverft Package Catalog Signing'
        $null = Sign-PackageDefinition -Path $definitionPath -CertificatePath $pfxPath -Password $password
        $verification = Verify-PackageDefinitionSignature -Path $definitionPath -RequireTrusted

        $trust.KeyThumbprint | Should -Be $certificate.Thumbprint
        $verification.Valid | Should -BeTrue
        $verification.Trusted | Should -BeTrue
        $verification.Status | Should -Be 'validTrusted'
    }

    It 'resolves strict catalog trust from trusted signing key without publisher inventory' {
        $rootPath = Join-Path $TestDrive 'strict-runtime-selection'
        $pfxPath = Join-Path $rootPath 'eigenverft-package-catalog-signing.pfx'
        $certificatePath = Join-Path $rootPath 'eigenverft-package-catalog-signing.pem'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definition = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definition

        $certificate = New-PackageSigningCertificate -PfxPath $pfxPath -CertificatePath $certificatePath -Password $password
        $null = Trust-PackageSigningCertificate -CertificatePath $certificatePath -PublisherId 'Eigenverft' -PublisherName 'Eigenverft' -SignerDisplayName 'Eigenverft Package Catalog Signing'
        $null = Sign-PackageDefinition -Path $documents.DefinitionPath -CertificatePath $pfxPath -Password $password

        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }

        $reference = Resolve-PackageDefinitionReference -DefinitionId 'VSCodeRuntime' -LocalEndpointRoot (Join-Path $rootPath 'PkgEndpoint') -CatalogTrustPolicy strict

        $reference.SignatureStatus | Should -Be 'validTrusted'
        $reference.SignatureTrusted | Should -BeTrue
        $reference.CatalogTrustStatus | Should -Be 'signedTrusted'
        $reference.SignatureKeyThumbprint | Should -Be $certificate.Thumbprint
    }

    It 'rejects unsigned definitions in strict mode but accepts matching allowUnsignedPublisherIds as the explicit migration path' {
        $rootPath = Join-Path $TestDrive 'strict-rejects-unsigned'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definition = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definition

        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }

        { Resolve-PackageDefinitionReference -DefinitionId 'VSCodeRuntime' -LocalEndpointRoot (Join-Path $rootPath 'StrictEndpoint') -CatalogTrustPolicy strict } | Should -Throw "*catalog trust policy 'strict'*definitionPublication.definitionSignature.kind='signed'*"

        $reference = Resolve-PackageDefinitionReference -DefinitionId 'VSCodeRuntime' -LocalEndpointRoot (Join-Path $rootPath 'UnsignedEndpoint') -CatalogTrustPolicy allowUnsigned -CatalogTrustAllowUnsignedPublisherIds @('Eigenverft')
        $reference.CatalogTrustStatus | Should -Be 'unsignedConfigTrust'
        $reference.SignatureStatus | Should -Be 'missingSignature'
    }

    It 'rejects trusted keys scoped to a different publisherId' {
        $rootPath = Join-Path $TestDrive 'wrong-publisher-trust'
        $pfxPath = Join-Path $rootPath 'team-package-catalog-signing.pfx'
        $certificatePath = Join-Path $rootPath 'team-package-catalog-signing.pem'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definition = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definition

        $null = New-PackageSigningCertificate -PfxPath $pfxPath -CertificatePath $certificatePath -Password $password
        $null = Trust-PackageSigningCertificate -CertificatePath $certificatePath -PublisherId 'OtherPublisher' -PublisherName 'OtherPublisher' -SignerDisplayName 'Other Publisher Signing'
        $null = Sign-PackageDefinition -Path $documents.DefinitionPath -CertificatePath $pfxPath -Password $password

        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }

        { Resolve-PackageDefinitionReference -DefinitionId 'VSCodeRuntime' -LocalEndpointRoot (Join-Path $rootPath 'PkgEndpoint') -CatalogTrustPolicy strict } | Should -Throw '*signing key is not trusted for this publisher*'
    }

    It 'blocks an otherwise valid trusted signature by publisherId' {
        $rootPath = Join-Path $TestDrive 'blocked-publisher'
        $pfxPath = Join-Path $rootPath 'eigenverft-package-catalog-signing.pfx'
        $certificatePath = Join-Path $rootPath 'eigenverft-package-catalog-signing.pem'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definition = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definition

        $null = New-PackageSigningCertificate -PfxPath $pfxPath -CertificatePath $certificatePath -Password $password
        $null = Trust-PackageSigningCertificate -CertificatePath $certificatePath -PublisherId 'Eigenverft' -PublisherName 'Eigenverft' -SignerDisplayName 'Eigenverft Package Catalog Signing'
        $null = Sign-PackageDefinition -Path $documents.DefinitionPath -CertificatePath $pfxPath -Password $password

        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }

        { Resolve-PackageDefinitionReference -DefinitionId 'VSCodeRuntime' -LocalEndpointRoot (Join-Path $rootPath 'PkgEndpoint') -CatalogTrustPolicy strict -CatalogTrustBlockedPublisherIds @('Eigenverft') } | Should -Throw '*blocked by catalogTrust.blockedPublisherIds*'
    }

    It 'rejects allowUnsigned when the publisherId is not explicitly listed' {
        $rootPath = Join-Path $TestDrive 'allow-unsigned-no-match'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definition = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definition

        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }

        { Resolve-PackageDefinitionReference -DefinitionId 'VSCodeRuntime' -LocalEndpointRoot (Join-Path $rootPath 'PkgEndpoint') -CatalogTrustPolicy allowUnsigned -CatalogTrustAllowUnsignedPublisherIds @('OtherPublisher') } | Should -Throw '*not listed in catalogTrust.allowUnsignedPublisherIds*'
    }

    It 'enforces package-file payload hash metadata when strict payload verification is enabled' {
        $candidate = [pscustomobject]@{
            kind         = 'download'
            verification = [pscustomobject]@{ mode = 'none' }
        }
        $unsignedPackage = New-TestPackageRelease -Id 'payload-without-hash' -Version '1.0.0' -Architecture 'x64' -FileName 'payload.zip'

        { Resolve-PackageAcquisitionCandidateVerification -Package $unsignedPackage -AcquisitionCandidate $candidate -PayloadVerificationPolicy enforceWhenPackageFileExists -PackageFileRequired $true } | Should -Throw "*requires packageFile.contentHash or packageFile.publisherSignature*"

        $hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        $hashedPackage = New-TestPackageRelease -Id 'payload-with-hash' -Version '1.0.0' -Architecture 'x64' -FileName 'payload.zip' -PackageFileSha256 $hash
        $verification = Resolve-PackageAcquisitionCandidateVerification -Package $hashedPackage -AcquisitionCandidate $candidate -PayloadVerificationPolicy enforceWhenPackageFileExists -PackageFileRequired $true

        $verification.mode | Should -Be 'required'
        $verification.sha256 | Should -Be $hash
    }
}
