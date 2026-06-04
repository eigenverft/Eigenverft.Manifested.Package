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
        $signature = Sign-PackageDefinition -Path $definitionPath -Cert $pfxPath -Password $password
        $verification = Verify-PackageDefinitionSignature -Path $definitionPath -CertificatePath $certificatePath
        $embeddedVerification = Verify-PackageDefinitionSignature -Path $definitionPath
        $signedInfo = Read-PackageJsonDocument -Path $definitionPath
        $signedText = Get-Content -LiteralPath $definitionPath -Raw
        $stripped = Remove-PackageDefinitionSignature -Path $definitionPath
        $strippedInfo = Read-PackageJsonDocument -Path $definitionPath

        Test-Path -LiteralPath $pfxPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $certificatePath -PathType Leaf | Should -BeTrue
        $certificate.Thumbprint | Should -Not -BeNullOrEmpty
        $signature.VerificationStatus | Should -Be 'validUntrusted'
        $signedInfo.Document.definitionPublication.definitionSignature.certificatePem | Should -Match 'BEGIN CERTIFICATE'
        $signedText | Should -Match '"schemaVersion": "1\.9"'
        $signedText | Should -Match '"dependency": \{'
        $signedText | Should -Match '"requires": \[\]'
        $signedText | Should -Not -Match '":  '
        $verification.Valid | Should -BeTrue
        $verification.Status | Should -Be 'validUntrusted'
        $embeddedVerification.Valid | Should -BeTrue
        $embeddedVerification.Status | Should -Be 'validUntrusted'
        $embeddedVerification.CertificateSource | Should -Be 'embedded'
        $stripped.Status | Should -Be 'Unsigned'
        $strippedInfo.Document.schemaVersion | Should -Be '1.9'
        $strippedInfo.Document.definitionPublication.definitionSignature.kind | Should -Be 'unsigned'
        $strippedInfo.Document.definitionPublication.definitionSignature.PSObject.Properties['signatureValue'] | Should -BeNullOrEmpty
    }

    It 'resigns a package definition with the same command shape as sign and remove' {
        $rootPath = Join-Path $TestDrive 'resign'
        $pfxPath = Join-Path $rootPath 'eigenverft-package-catalog-signing.pfx'
        $definitionPath = Join-Path $rootPath 'VSCodeRuntime.json'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $definition = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        Write-TestJsonDocument -Path $definitionPath -Document $definition
        $null = New-PackageSigningCertificate -PfxPath $pfxPath -Password $password
        $null = Sign-PackageDefinition -Path $definitionPath -Cert $pfxPath -Password $password

        $result = Resign-PackageDefinition -Path $definitionPath -Cert $pfxPath -Password $password -KeepSchemaVersion
        $verification = Verify-PackageDefinitionSignature -Path $definitionPath

        $result.VerificationStatus | Should -Be 'validUntrusted'
        $verification.Valid | Should -BeTrue
        $verification.Status | Should -Be 'validUntrusted'
    }

    It 'creates a friendly signing certificate descriptor and signs by certificate name' {
        $rootPath = Join-Path $TestDrive 'friendly-signing-profile'
        $definitionPath = Join-Path $rootPath 'MyPackage.json'
        $passwordText = 'CatalogTrust-Test-Password-123!'
        $password = ConvertTo-SecureString $passwordText -AsPlainText -Force
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        Write-TestJsonDocument -Path $definitionPath -Document $definition
        Mock Get-PackageDefaultSigningDirectory { Join-Path $rootPath 'Signing' }

        $created = New-PackageSigningCertificate -Name 'My Team' -Password $password
        $profile = Get-PackageSigningProfile -PublisherId 'My Team'
        $descriptor = Read-PackageJsonDocument -Path $created.SigningDescriptorPath
        $descriptorRaw = Get-Content -LiteralPath $created.SigningDescriptorPath -Raw
        $signature = Sign-PackageDefinition -Path $definitionPath -Cert 'MyTeam'
        $verification = Verify-PackageDefinitionSignature -Path $definitionPath -CertificatePath $created.CertificatePath

        Test-Path -LiteralPath $created.PfxPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $created.CertificatePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $created.SigningDescriptorPath -PathType Leaf | Should -BeTrue
        $created.Messages | Should -Contain "Saved local signing password descriptor '$($created.SigningDescriptorPath)'."
        $created.NextSteps -join "`n" | Should -Match 'Sign-PackageDefinition -Path.+-Cert'
        @($profile).Count | Should -Be 1
        @($profile)[0].PublisherId | Should -Be 'My Team'
        @($profile)[0].PasswordStored | Should -BeTrue
        $descriptor.Document.kind | Should -Be 'catalogSigningPassword'
        $descriptor.Document.PSObject.Properties['pfxPath'] | Should -BeNullOrEmpty
        $descriptor.Document.PSObject.Properties['certificatePath'] | Should -BeNullOrEmpty
        $descriptorRaw | Should -Not -Match [regex]::Escape($passwordText)
        $signature.PasswordSource | Should -Be 'descriptor'
        $signature.VerificationStatus | Should -Be 'validUntrusted'
        $signature.Messages -join "`n" | Should -Match 'Signed package definition'
        $signature.NextSteps -join "`n" | Should -Match 'public .cer'
        $verification.Valid | Should -BeTrue
    }

    It 'builds friendly certificate metadata and carries display data into signatures and trust rows' {
        $rootPath = Join-Path $TestDrive 'friendly-certificate-metadata'
        $definitionPath = Join-Path $rootPath 'MyPackage.json'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        Write-TestJsonDocument -Path $definitionPath -Document $definition
        Mock Get-PackageDefaultSigningDirectory { Join-Path $rootPath 'Signing' }

        $created = New-PackageSigningCertificate `
            -Name 'My Team' `
            -Password $password `
            -PublisherName 'My Team Packages' `
            -CommonName 'My Team Package Catalog Signing' `
            -Organization 'Example Org' `
            -OrganizationalUnit 'Package Maintainers' `
            -Country 'DE' `
            -SignerDisplayName 'Example Org Catalog Signing' `
            -TrustReason 'Test trust reason.'
        $signature = Sign-PackageDefinition -Path $definitionPath -Cert 'My Team'
        $signedInfo = Read-PackageJsonDocument -Path $definitionPath
        $imported = Import-PackageTrust -Path $created.CertificatePath -PublisherName 'My Team Packages' -SignerDisplayName 'Example Org Catalog Signing' -TrustReason 'Test trust reason.'

        $created.Subject | Should -Match 'CN=My Team Package Catalog Signing'
        $created.Subject | Should -Match 'O=Example Org'
        $created.Subject | Should -Match 'OU=Package Maintainers'
        $created.Subject | Should -Match 'C=DE'
        $created.SignerDisplayName | Should -Be 'Example Org Catalog Signing'
        $created.TrustReason | Should -Be 'Test trust reason.'
        $signature.VerificationStatus | Should -Be 'validUntrusted'
        $signedInfo.Document.definitionPublication.definitionSignature.signerDisplayName | Should -Be 'Example Org Catalog Signing'
        $imported.Keys[0].PublisherId | Should -Be 'My Team'
        $imported.Keys[0].PublisherName | Should -Be 'My Team Packages'
        $imported.Keys[0].SignerDisplayName | Should -Be 'Example Org Catalog Signing'
        $imported.Keys[0].TrustSource | Should -Be 'imported'
        $imported.Keys[0].TrustReason | Should -Be 'Test trust reason.'
    }

    It 'rejects invalid certificate country values and keeps raw Subject as the advanced override' {
        $rootPath = Join-Path $TestDrive 'friendly-certificate-subject-validation'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $invalidPfxPath = Join-Path $rootPath 'invalid-country.pfx'
        $advancedPfxPath = Join-Path $rootPath 'advanced-subject.pfx'

        { New-PackageSigningCertificate -PfxPath $invalidPfxPath -Password $password -PublisherId 'My Team' -Country 'Germany' } | Should -Throw '*two-letter ISO country code*'
        $advanced = New-PackageSigningCertificate -PfxPath $advancedPfxPath -Password $password -Subject 'CN=Raw Subject'

        $advanced.Subject | Should -Be 'CN=Raw Subject'
    }

    It 'fails signing without an explicit certificate selector' {
        $rootPath = Join-Path $TestDrive 'missing-signing-profile'
        $definitionPath = Join-Path $rootPath 'MyPackage.json'
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        Write-TestJsonDocument -Path $definitionPath -Document $definition

        { Sign-PackageDefinition -Path $definitionPath } | Should -Throw "*requires -Cert*"
    }

    It 'signs with a PFX path using the environment password fallback when no descriptor exists' {
        $rootPath = Join-Path $TestDrive 'sign-env-password'
        $pfxPath = Join-Path $rootPath 'team.catalog-signing.pfx'
        $certificatePath = Join-Path $rootPath 'team.catalog-signing.cer'
        $definitionPath = Join-Path $rootPath 'MyPackage.json'
        $passwordText = 'CatalogTrust-Test-Password-123!'
        $password = ConvertTo-SecureString $passwordText -AsPlainText -Force
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        Write-TestJsonDocument -Path $definitionPath -Document $definition
        $null = New-PackageSigningCertificate -PfxPath $pfxPath -CertificatePath $certificatePath -Password $password
        $descriptorPath = Get-PackageSigningPasswordDescriptorPath -PfxPath $pfxPath
        [Environment]::SetEnvironmentVariable((Get-PackageSigningPasswordEnvironmentVariableName), $passwordText, 'Process')

        try {
            $signature = Sign-PackageDefinition -Path $definitionPath -Cert $pfxPath
        }
        finally {
            [Environment]::SetEnvironmentVariable((Get-PackageSigningPasswordEnvironmentVariableName), $null, 'Process')
        }

        Test-Path -LiteralPath $descriptorPath -PathType Leaf | Should -BeFalse
        $signature.PasswordSource | Should -Be 'environment'
        $signature.VerificationStatus | Should -Be 'validUntrusted'
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

    It 'rejects package-definition JSON as an Import-PackageTrust input' {
        $rootPath = Join-Path $TestDrive 'import-definition-json-rejected'
        $definitionPath = Join-Path $rootPath 'MyPackage.json'
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        Write-TestJsonDocument -Path $definitionPath -Document $definition

        { Import-PackageTrust -Path $definitionPath } | Should -Throw '*public certificate files or package trust export JSON only*Invoke-Package*AcceptUnknownSigningKey*'
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
        $signingCertificate = Import-PackageCertificate -Path $pfxPath -Password $password -WithPrivateKey
        try {
            $signedInfo = Read-PackageJsonDocument -Path $definitionPath
            Set-PackageObjectProperty -InputObject $signedInfo.Document -Name 'schemaVersion' -Value '1.9'
            Set-PackageDefinitionSignature -Definition $signedInfo.Document -Certificate $signingCertificate -SignatureValue ''
            $signedInfo.Document.definitionPublication.definitionSignature.PSObject.Properties.Remove('certificatePem')
            $signable = Get-PackageDefinitionSignableContent -Definition $signedInfo.Document
            $rsa = Get-PackageCertificateRsaPrivateKey -Certificate $signingCertificate
            try {
                $signatureBytes = Invoke-PackageRsaSignData -Rsa $rsa -Bytes $signable.Bytes
            }
            finally {
                $rsa.Dispose()
            }
            Set-PackageObjectProperty -InputObject $signedInfo.Document.definitionPublication.definitionSignature -Name 'signatureValue' -Value ([Convert]::ToBase64String($signatureBytes))
            Save-PackageJsonDocument -Path $definitionPath -Document $signedInfo.Document
        }
        finally {
            $signingCertificate.Dispose()
        }
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
        $null = Sign-PackageDefinition -Path $documents.DefinitionPath -Cert $pfxPath -Password $password

        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }

        $reference = Resolve-PackageDefinitionReference -DefinitionId 'VSCodeRuntime' -LocalEndpointRoot (Join-Path $rootPath 'PkgEndpoint') -CatalogTrustPolicy strict

        $reference.SignatureStatus | Should -Be 'validTrusted'
        $reference.SignatureTrusted | Should -BeTrue
        $reference.CatalogTrustStatus | Should -Be 'signedTrusted'
        $reference.SignatureKeyThumbprint | Should -Be $certificate.Thumbprint
    }

    It 'rejects valid embedded unknown signing keys when unknownSignedKeyPolicy is fail' {
        $rootPath = Join-Path $TestDrive 'unknown-key-fail'
        $pfxPath = Join-Path $rootPath 'team-package-catalog-signing.pfx'
        $certificatePath = Join-Path $rootPath 'team-package-catalog-signing.cer'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definition

        $null = New-PackageSigningCertificate -PfxPath $pfxPath -CertificatePath $certificatePath -Password $password -Subject 'CN=My Team'
        $null = Sign-PackageDefinition -Path $documents.DefinitionPath -Cert $pfxPath -Password $password

        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }

        { Resolve-PackageDefinitionReference -DefinitionId 'MyPackage' -LocalEndpointRoot (Join-Path $rootPath 'PkgEndpoint') -CatalogTrustPolicy strict -UnknownSignedKeyPolicy fail } | Should -Throw '*signing key is not trusted for this publisher*'
    }

    It 'prompts for a valid embedded unknown signing key and imports trust only when accepted' {
        $rootPath = Join-Path $TestDrive 'unknown-key-prompt'
        $pfxPath = Join-Path $rootPath 'team-package-catalog-signing.pfx'
        $certificatePath = Join-Path $rootPath 'team-package-catalog-signing.cer'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definition

        $certificate = New-PackageSigningCertificate -PfxPath $pfxPath -CertificatePath $certificatePath -Password $password -Subject 'CN=My Team'
        $null = Sign-PackageDefinition -Path $documents.DefinitionPath -Cert $pfxPath -Password $password

        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }
        Mock Confirm-PackageUnknownSigningKeyTrust { $true }

        $reference = Resolve-PackageDefinitionReference -DefinitionId 'MyPackage' -LocalEndpointRoot (Join-Path $rootPath 'PkgEndpoint') -CatalogTrustPolicy strict -UnknownSignedKeyPolicy prompt
        $trust = @(Get-PackageTrust -PublisherId 'My Team')

        $reference.SignatureStatus | Should -Be 'validTrusted'
        $reference.SignatureTrusted | Should -BeTrue
        $reference.CatalogTrustStatus | Should -Be 'signedTrusted'
        $trust.Count | Should -Be 1
        $trust[0].KeyThumbprint | Should -Be $certificate.Thumbprint
        $trust[0].TrustSource | Should -Be 'invokePackagePrompt'
    }

    It 'rejects prompt-mode unknown signing keys when trust is declined' {
        $rootPath = Join-Path $TestDrive 'unknown-key-prompt-declined'
        $pfxPath = Join-Path $rootPath 'team-package-catalog-signing.pfx'
        $certificatePath = Join-Path $rootPath 'team-package-catalog-signing.cer'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definition

        $null = New-PackageSigningCertificate -PfxPath $pfxPath -CertificatePath $certificatePath -Password $password -Subject 'CN=My Team'
        $null = Sign-PackageDefinition -Path $documents.DefinitionPath -Cert $pfxPath -Password $password

        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }
        Mock Confirm-PackageUnknownSigningKeyTrust { $false }

        { Resolve-PackageDefinitionReference -DefinitionId 'MyPackage' -LocalEndpointRoot (Join-Path $rootPath 'PkgEndpoint') -CatalogTrustPolicy strict -UnknownSignedKeyPolicy prompt } | Should -Throw '*key was not trusted*AcceptUnknownSigningKey*'
        @(Get-PackageTrust -PublisherId 'My Team').Count | Should -Be 0
    }

    It 'auto-imports a valid embedded unknown signing key when unknownSignedKeyPolicy is trust' {
        $rootPath = Join-Path $TestDrive 'unknown-key-auto-trust'
        $pfxPath = Join-Path $rootPath 'team-package-catalog-signing.pfx'
        $certificatePath = Join-Path $rootPath 'team-package-catalog-signing.cer'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definition

        $certificate = New-PackageSigningCertificate -PfxPath $pfxPath -CertificatePath $certificatePath -Password $password -Subject 'CN=My Team'
        $null = Sign-PackageDefinition -Path $documents.DefinitionPath -Cert $pfxPath -Password $password

        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }

        $reference = Resolve-PackageDefinitionReference -DefinitionId 'MyPackage' -LocalEndpointRoot (Join-Path $rootPath 'PkgEndpoint') -CatalogTrustPolicy strict -UnknownSignedKeyPolicy trust
        $trust = @(Get-PackageTrust -PublisherId 'My Team')

        $reference.SignatureStatus | Should -Be 'validTrusted'
        $reference.SignatureTrusted | Should -BeTrue
        $trust.Count | Should -Be 1
        $trust[0].KeyThumbprint | Should -Be $certificate.Thumbprint
        $trust[0].TrustSource | Should -Be 'invokePackageAutoTrust'
    }

    It 'lets AcceptUnknownSigningKey override config fail policy during package config resolution' {
        $rootPath = Join-Path $TestDrive 'unknown-key-switch-override'
        $pfxPath = Join-Path $rootPath 'team-package-catalog-signing.pfx'
        $certificatePath = Join-Path $rootPath 'team-package-catalog-signing.cer'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot') -CatalogTrustPolicy strict -CatalogTrustUnknownSignedKeyPolicy fail
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definition

        $certificate = New-PackageSigningCertificate -PfxPath $pfxPath -CertificatePath $certificatePath -Password $password -Subject 'CN=My Team'
        $null = Sign-PackageDefinition -Path $documents.DefinitionPath -Cert $pfxPath -Password $password

        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }

        $config = Get-PackageConfig -DefinitionId 'MyPackage' -PublisherId 'My Team' -AcceptUnknownSigningKey
        $trust = @(Get-PackageTrust -PublisherId 'My Team')

        $config.CatalogTrustUnknownSignedKeyPolicy | Should -Be 'trust'
        $config.AcceptUnknownSigningKey | Should -BeTrue
        $config.DefinitionSignatureTrusted | Should -BeTrue
        $trust.Count | Should -Be 1
        $trust[0].KeyThumbprint | Should -Be $certificate.Thumbprint
    }

    It 'rejects embedded certificates whose thumbprint does not match the signed key thumbprint without prompting' {
        $rootPath = Join-Path $TestDrive 'embedded-cert-mismatch'
        $pfxPath = Join-Path $rootPath 'team-package-catalog-signing.pfx'
        $certificatePath = Join-Path $rootPath 'team-package-catalog-signing.cer'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definition

        $null = New-PackageSigningCertificate -PfxPath $pfxPath -CertificatePath $certificatePath -Password $password -Subject 'CN=My Team'
        $null = Sign-PackageDefinition -Path $documents.DefinitionPath -Cert $pfxPath -Password $password
        $signedInfo = Read-PackageJsonDocument -Path $documents.DefinitionPath
        $signedInfo.Document.definitionPublication.definitionSignature.keyThumbprint = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        Save-PackageJsonDocument -Path $documents.DefinitionPath -Document $signedInfo.Document

        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }
        Mock Confirm-PackageUnknownSigningKeyTrust { throw 'Prompt should not be called.' }

        { Resolve-PackageDefinitionReference -DefinitionId 'MyPackage' -LocalEndpointRoot (Join-Path $rootPath 'PkgEndpoint') -CatalogTrustPolicy strict -UnknownSignedKeyPolicy trust } | Should -Throw '*thumbprint does not match*'
        @(Get-PackageTrust -PublisherId 'My Team').Count | Should -Be 0
    }

    It 'rejects unsigned definitions in strict mode but accepts matching allowUnsignedPublisherIds as the explicit migration path' {
        $rootPath = Join-Path $TestDrive 'strict-rejects-unsigned'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definition = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definition

        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }

        { Resolve-PackageDefinitionReference -DefinitionId 'VSCodeRuntime' -LocalEndpointRoot (Join-Path $rootPath 'StrictEndpoint') -CatalogTrustPolicy strict } | Should -Throw "*catalogTrust.policy='strict' rejects unsigned definitions*"

        $reference = Resolve-PackageDefinitionReference -DefinitionId 'VSCodeRuntime' -LocalEndpointRoot (Join-Path $rootPath 'UnsignedEndpoint') -CatalogTrustPolicy allowUnsigned -CatalogTrustAllowUnsignedPublisherIds @('Eigenverft')
        $reference.CatalogTrustStatus | Should -Be 'unsignedConfigTrust'
        $reference.SignatureStatus | Should -Be 'unsigned'
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
        $null = Sign-PackageDefinition -Path $documents.DefinitionPath -Cert $pfxPath -Password $password

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
        $null = Sign-PackageDefinition -Path $documents.DefinitionPath -Cert $pfxPath -Password $password

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

    It 'validates an unsigned single package definition as a warning by default and an error when trusted definitions are required' {
        $rootPath = Join-Path $TestDrive 'catalog-validation-unsigned'
        $definitionPath = Join-Path $rootPath 'VSCodeRuntime.json'
        $definition = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        Write-TestJsonDocument -Path $definitionPath -Document $definition

        $draftReport = Test-PackageDefinitionCatalog -Path $definitionPath
        $trustedReport = Test-PackageDefinitionCatalog -Path $definitionPath -RequireTrusted
        $errorRecord = $null
        try {
            Test-PackageDefinitionCatalog -Path $definitionPath -RequireTrusted -ErrorOnFailure | Out-Null
        }
        catch {
            $errorRecord = $_
        }

        $draftReport.Valid | Should -BeTrue
        $draftReport.WarningCount | Should -Be 1
        @($draftReport.Issues.Code) | Should -Contain 'PackageDefinitionSignatureUnsigned'
        $trustedReport.Valid | Should -BeFalse
        $trustedReport.ErrorCount | Should -Be 1
        @($trustedReport.Issues.Code) | Should -Contain 'PackageDefinitionSignatureUnsigned'
        $errorRecord | Should -Not -BeNullOrEmpty
        $errorRecord.FullyQualifiedErrorId | Should -Match 'PackageDefinitionCatalogValidationFailed'
        $errorRecord.TargetObject.Valid | Should -BeFalse
    }

    It 'reports JSON parse and schema failures without running package assignment' {
        $rootPath = Join-Path $TestDrive 'catalog-validation-bad-json'
        $invalidJsonPath = Join-Path $rootPath 'Invalid.json'
        $invalidSchemaPath = Join-Path $rootPath 'InvalidSchema.json'
        Write-TestTextFile -Path $invalidJsonPath -Content '{ "schemaVersion": '
        $definition = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -Releases @(
                New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
            ))
        $definition.PSObject.Properties.Remove('dependency')
        Write-TestJsonDocument -Path $invalidSchemaPath -Document $definition

        $parseReport = Test-PackageDefinitionCatalog -Path $invalidJsonPath
        $schemaReport = Test-PackageDefinitionCatalog -Path $invalidSchemaPath

        $parseReport.Valid | Should -BeFalse
        @($parseReport.Issues.Code) | Should -Contain 'CatalogJsonParseFailed'
        $schemaReport.Valid | Should -BeFalse
        @($schemaReport.Issues.Code) | Should -Contain 'PackageDefinitionSchemaInvalid'
    }

    It 'reports an endpoint folder with no JSON definitions' {
        $emptyCatalogRoot = Join-Path $TestDrive 'empty-catalog'
        $null = New-Item -ItemType Directory -Path $emptyCatalogRoot -Force

        $report = Test-PackageDefinitionCatalog -Path $emptyCatalogRoot

        $report.Valid | Should -BeFalse
        $report.CheckedCount | Should -Be 0
        @($report.Issues.Code) | Should -Contain 'CatalogNoJsonFiles'
    }

    It 'reports valid untrusted signatures as warnings by default and invalid signatures as errors' {
        $rootPath = Join-Path $TestDrive 'catalog-validation-signatures'
        $pfxPath = Join-Path $rootPath 'team.catalog-signing.pfx'
        $certificatePath = Join-Path $rootPath 'team.catalog-signing.cer'
        $definitionPath = Join-Path $rootPath 'MyPackage.json'
        $password = ConvertTo-SecureString 'CatalogTrust-Test-Password-123!' -AsPlainText -Force
        $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'MyPackage' -PublisherId 'My Team' -PublisherName 'My Team' -Releases @(
            New-TestPackageRelease -Id 'my-package-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        Write-TestJsonDocument -Path $definitionPath -Document $definition
        $null = New-PackageSigningCertificate -PfxPath $pfxPath -CertificatePath $certificatePath -Password $password -Subject 'CN=My Team'
        $null = Sign-PackageDefinition -Path $definitionPath -Cert $pfxPath -Password $password

        $untrustedReport = Test-PackageDefinitionCatalog -Path $definitionPath
        $trustedReport = Test-PackageDefinitionCatalog -Path $definitionPath -RequireTrusted
        $signedInfo = Read-PackageJsonDocument -Path $definitionPath
        $signedInfo.Document.definitionPublication.definitionSignature.signatureValue = [Convert]::ToBase64String([byte[]](1, 2, 3))
        Save-PackageJsonDocument -Path $definitionPath -Document $signedInfo.Document
        $invalidReport = Test-PackageDefinitionCatalog -Path $definitionPath

        $untrustedReport.Valid | Should -BeTrue
        $untrustedReport.WarningCount | Should -Be 1
        @($untrustedReport.Issues.Code) | Should -Contain 'PackageDefinitionSignatureUntrusted'
        $trustedReport.Valid | Should -BeFalse
        @($trustedReport.Issues.Code) | Should -Contain 'PackageDefinitionSignatureUntrusted'
        $invalidReport.Valid | Should -BeFalse
        @($invalidReport.Issues.Code) | Should -Contain 'PackageDefinitionSignatureInvalid'
    }

    It 'reports folder-level duplicate identity and dependency reference issues' {
        $rootPath = Join-Path $TestDrive 'catalog-validation-folder-references'
        $catalogRoot = Join-Path $rootPath 'Catalog'
        $rootDefinition = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'RootA' -Releases @(
                New-TestPackageRelease -Id 'RootA-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
            ))
        $rootDefinition.dependency.requires = @(
            [pscustomobject]@{ definitionId = 'MissingRuntime' },
            [pscustomobject]@{ definitionId = 'RootA' }
        )
        $rootDefinition.dependency | Add-Member -MemberType NoteProperty -Name policy -Value ([pscustomobject]@{
                conflictsWith = @([pscustomobject]@{ definitionId = 'MissingPeer' })
                requiresAbsent = @([pscustomobject]@{ definitionId = 'RootA' })
            }) -Force
        $duplicateDefinition = ConvertTo-TestPsObject $rootDefinition
        $otherDefinition = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'OtherTool' -Releases @(
                New-TestPackageRelease -Id 'OtherTool-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
            ))
        Write-TestJsonDocument -Path (Join-Path $catalogRoot 'RootA.json') -Document $rootDefinition
        Write-TestJsonDocument -Path (Join-Path $catalogRoot 'RootA-copy.json') -Document $duplicateDefinition
        Write-TestJsonDocument -Path (Join-Path $catalogRoot 'OtherTool.json') -Document $otherDefinition

        $report = Test-PackageDefinitionCatalog -Path $catalogRoot
        $singleFileReport = Test-PackageDefinitionCatalog -Path (Join-Path $catalogRoot 'RootA.json')

        $report.Valid | Should -BeFalse
        @($report.Issues.Code) | Should -Contain 'CatalogDuplicateDefinitionIdentity'
        @($report.Issues.Code) | Should -Contain 'CatalogDependencyReferenceMissing'
        @($report.Issues.Code) | Should -Contain 'CatalogDependencySelfReference'
        @($report.Issues.Code) | Should -Contain 'CatalogPolicyReferenceMissing'
        @($report.Issues.Code) | Should -Contain 'CatalogPolicySelfReference'
        @($singleFileReport.Issues.Code) | Should -Not -Contain 'CatalogDependencyReferenceMissing'
        @($singleFileReport.Issues.Code) | Should -Not -Contain 'CatalogPolicyReferenceMissing'
    }

    It 'reports mixed schema versions as warnings by default and errors in strict schema mode' {
        $rootPath = Join-Path $TestDrive 'catalog-validation-mixed-schema'
        $catalogRoot = Join-Path $rootPath 'Catalog'
        $currentDefinition = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'CurrentTool' -Releases @(
                New-TestPackageRelease -Id 'CurrentTool-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
            ))
        $oldDefinition = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'OldTool' -Releases @(
                New-TestPackageRelease -Id 'OldTool-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
            ))
        $oldDefinition.schemaVersion = '1.8'
        Write-TestJsonDocument -Path (Join-Path $catalogRoot 'CurrentTool.json') -Document $currentDefinition
        Write-TestJsonDocument -Path (Join-Path $catalogRoot 'OldTool.json') -Document $oldDefinition

        $report = Test-PackageDefinitionCatalog -Path $catalogRoot
        $strictReport = Test-PackageDefinitionCatalog -Path $catalogRoot -StrictSchemaVersion

        @($report.Issues | Where-Object { [string]$_.Code -eq 'CatalogMixedSchemaVersion' -and [string]$_.Severity -eq 'Warning' }).Count | Should -BeGreaterThan 0
        @($strictReport.Issues | Where-Object { [string]$_.Code -eq 'CatalogMixedSchemaVersion' -and [string]$_.Severity -eq 'Error' }).Count | Should -BeGreaterThan 0
    }

    It 'reports semantic warnings for installer, readiness, removal, and architecture-risk shapes' {
        $rootPath = Join-Path $TestDrive 'catalog-validation-semantic-warnings'
        $catalogRoot = Join-Path $rootPath 'Catalog'

        $missingTargetDefinition = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'MissingInstallTarget' -Releases @(
                New-TestPackageRelease -Id 'missing-target-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
            ))
        $missingTargetDefinition.packageOperations.assigned.install = [pscustomobject]@{
            kind             = 'runInstaller'
            targetKind       = 'directory'
            installerKind    = 'customExe'
            uiMode           = 'silent'
            elevation        = 'required'
            timeoutSec       = 60
            commandArguments = @('/S')
            successExitCodes = @(0)
            restartExitCodes = @()
        }

        $machinePrerequisiteDefinition = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'MachinePrerequisiteRisk' -Releases @(
                New-TestPackageRelease -Id 'machine-prereq-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
            ))
        $machinePrerequisiteDefinition.packageOperations.assigned.install = [pscustomobject]@{
            kind             = 'runInstaller'
            targetKind       = 'machinePrerequisite'
            installerKind    = 'customExe'
            uiMode           = 'silent'
            elevation        = 'required'
            timeoutSec       = 60
            commandArguments = @('/S', '{installDirectory}')
            successExitCodes = @(0)
            restartExitCodes = @()
        }
        $machinePrerequisiteDefinition.packageOperations.removed.operation = [pscustomobject]@{
            kind = 'none'
        }
        $machinePrerequisiteDefinition.packageOperations.removed.absenceVerification.require.registry = $true

        $multiArchDefinition = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'SharedReadinessMultiArch' -Releases @(
                New-TestPackageRelease -Id 'multi-arch-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
                New-TestPackageRelease -Id 'multi-arch-win-x86-stable' -Version '1.0.0' -Architecture 'x86' -ArtifactDistributionVariant 'win32-x86'
            ))
        $multiArchDefinition.discovery.presence.files = @('TOTALCMD64.EXE', 'TOTALCMD.EXE')
        $multiArchDefinition.packageOperations.assigned.readyStateCheck.require.files = $true

        Write-TestJsonDocument -Path (Join-Path $catalogRoot 'MissingInstallTarget.json') -Document $missingTargetDefinition
        Write-TestJsonDocument -Path (Join-Path $catalogRoot 'MachinePrerequisiteRisk.json') -Document $machinePrerequisiteDefinition
        Write-TestJsonDocument -Path (Join-Path $catalogRoot 'SharedReadinessMultiArch.json') -Document $multiArchDefinition

        $report = Test-PackageDefinitionCatalog -Path $catalogRoot
        $codes = @($report.Issues | Where-Object { [string]$_.Severity -eq 'Warning' } | ForEach-Object { [string]$_.Code })

        $report.Valid | Should -BeTrue
        $codes | Should -Contain 'PackageDefinitionInstallTargetMissing'
        $codes | Should -Contain 'PackageDefinitionInstallDirectoryArgumentWithoutTarget'
        $codes | Should -Contain 'PackageDefinitionInstallRootReadinessWithoutInstallRoot'
        $codes | Should -Contain 'PackageDefinitionNoOpRemovalRequiresAbsence'
        $codes | Should -Contain 'PackageDefinitionMachinePrerequisiteRemovalInventoryRisk'
        $codes | Should -Contain 'PackageDefinitionSharedReadinessAcrossArchitectures'
    }

    It 'validates the shipped Eigenverft package-definition catalog as trusted' {
        $definitionRoot = Join-Path (Get-PackageShippedEndpointRoot) 'Defaults\Eigenverft'

        $report = Test-PackageDefinitionCatalog -Path $definitionRoot -RequireTrusted

        $report.Valid | Should -BeTrue
        $report.ErrorCount | Should -Be 0
        $report.CheckedCount | Should -Be @(Get-ChildItem -LiteralPath $definitionRoot -Filter '*.json' -File).Count
        $report.TrustedCount | Should -Be $report.CheckedCount
    }

    It 'enforces package-file payload hash metadata when strict payload verification is enabled' {
        $candidate = [pscustomobject]@{
            kind         = 'vendorDownload'
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
