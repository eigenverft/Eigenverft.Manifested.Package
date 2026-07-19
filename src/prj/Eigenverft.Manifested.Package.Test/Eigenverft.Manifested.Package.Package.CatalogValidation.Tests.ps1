<#
    Eigenverft.Manifested.Package Package - catalog validation
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - catalog validation' -Body {

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
            artifactFileId   = 'package'
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
            artifactFileId   = 'package'
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
                New-TestPackageRelease -Id 'multi-arch-win-x86-stable' -Version '1.0.1' -Architecture 'x86' -ArtifactDistributionVariant 'win32-x86'
            ))
        $multiArchDefinition.discovery.presence.files = @('TOTALCMD64.EXE', 'TOTALCMD.EXE')
        $multiArchDefinition.packageOperations.assigned.readyStateCheck.require.files = $true

        $emptyRequiredPresenceDefinition = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'EmptyRequiredPresence' -Releases @(
                New-TestPackageRelease -Id 'empty-required-presence-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
            ))
        $emptyRequiredPresenceDefinition.discovery.presence.files = @()
        $emptyRequiredPresenceDefinition.discovery.presence.commands = @()
        $emptyRequiredPresenceDefinition.packageOperations.assigned.pathRegistration = [pscustomobject]@{
            mode = 'none'
        }
        $emptyRequiredPresenceDefinition.packageOperations.assigned.readyStateCheck.require.files = $true
        $emptyRequiredPresenceDefinition.packageOperations.removed.absenceVerification.require.commands = $true

        Write-TestJsonDocument -Path (Join-Path $catalogRoot 'MissingInstallTarget.json') -Document $missingTargetDefinition
        Write-TestJsonDocument -Path (Join-Path $catalogRoot 'MachinePrerequisiteRisk.json') -Document $machinePrerequisiteDefinition
        Write-TestJsonDocument -Path (Join-Path $catalogRoot 'SharedReadinessMultiArch.json') -Document $multiArchDefinition
        Write-TestJsonDocument -Path (Join-Path $catalogRoot 'EmptyRequiredPresence.json') -Document $emptyRequiredPresenceDefinition

        $report = Test-PackageDefinitionCatalog -Path $catalogRoot
        $codes = @($report.Issues | Where-Object { [string]$_.Severity -eq 'Warning' } | ForEach-Object { [string]$_.Code })

        $report.Valid | Should -BeTrue
        $codes | Should -Contain 'PackageDefinitionInstallTargetMissing'
        $codes | Should -Contain 'PackageDefinitionInstallDirectoryArgumentWithoutTarget'
        $codes | Should -Contain 'PackageDefinitionInstallRootReadinessWithoutInstallRoot'
        $codes | Should -Contain 'PackageDefinitionNoOpRemovalRequiresAbsence'
        $codes | Should -Contain 'PackageDefinitionMachinePrerequisiteRemovalInventoryRisk'
        $codes | Should -Contain 'PackageDefinitionSharedReadinessAcrossArchitectures'
        $codes | Should -Contain 'PackageDefinitionReadinessRequiresEmptyPresenceCategory'
        $codes | Should -Contain 'PackageDefinitionAbsenceRequiresEmptyPresenceCategory'
    }

    It 'validates the shipped Eigenverft package-definition catalog as trusted' {
        $definitionRoot = Join-Path (Get-PackageShippedEndpointRoot) 'Defaults\Eigenverft'

        $report = Test-PackageDefinitionCatalog -Path $definitionRoot -RequireTrusted

        $report.Valid | Should -BeTrue
        $report.ErrorCount | Should -Be 0
        $report.CheckedCount | Should -Be @(Get-ChildItem -LiteralPath $definitionRoot -Filter '*.json' -File).Count
        $report.TrustedCount | Should -Be $report.CheckedCount
    }

    It 'enforces per-artifact payload hash metadata when strict payload verification is enabled' {
        $candidate = [pscustomobject]@{
            kind         = 'vendorDownload'
            verification = [pscustomobject]@{ mode = 'none' }
        }
        $unsignedPackage = New-TestPackageRelease -Id 'payload-without-hash' -Version '1.0.0' -Architecture 'x64' -FileName 'payload.zip'
        $unsignedArtifactFile = ConvertTo-TestPsObject @{ id = 'package'; relativePath = 'payload.zip' }

        { Resolve-PackageAcquisitionCandidateVerification -Package $unsignedPackage -ArtifactFile $unsignedArtifactFile -AcquisitionCandidate $candidate -PayloadVerificationPolicy enforceWhenPackageFileExists -ArtifactFileRequired $true } | Should -Throw "*requires contentHash or publisherSignature for artifact file 'package'*"

        $hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        $hashedPackage = New-TestPackageRelease -Id 'payload-with-hash' -Version '1.0.0' -Architecture 'x64' -FileName 'payload.zip' -PackageFileSha256 $hash
        $hashedArtifactFile = ConvertTo-TestPsObject @{ id = 'package'; relativePath = 'payload.zip'; contentHash = @{ algorithm = 'sha256'; value = $hash } }
        $verification = Resolve-PackageAcquisitionCandidateVerification -Package $hashedPackage -ArtifactFile $hashedArtifactFile -AcquisitionCandidate $candidate -PayloadVerificationPolicy enforceWhenPackageFileExists -ArtifactFileRequired $true

        $verification.mode | Should -Be 'required'
        $verification.sha256 | Should -Be $hash
    }

}
