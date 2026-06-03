<#
    Eigenverft.Manifested.Package Package - exports and state
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - exports and state' -Body {
    It 'exports Invoke-Package with generic package parameters' {
        $module = Import-Module -Name $script:ModuleManifestPath -Force -PassThru
        $command = Get-Command -Name 'Invoke-Package'

        $command | Should -Not -BeNullOrEmpty
        $command.Parameters.Keys | Should -Contain 'DefinitionId'
        $command.Parameters.Keys | Should -Contain 'PublisherId'
        $command.Parameters.Keys | Should -Not -Contain 'RepositoryId'
        $command.Parameters.Keys | Should -Not -Contain 'RepositorySourceId'
        $command.Parameters.Keys | Should -Contain 'DesiredState'
        $command.Parameters.Keys | Should -Contain 'AcceptUnknownSigningKey'
        $command.Parameters.Keys | Should -Contain 'Offline'
        $command.Parameters.Keys | Should -Contain 'MaterializeOnly'
        $command.Parameters.Keys | Should -Contain 'FailFast'
        $command.Parameters.Keys | Should -Not -Contain 'CommandName'
        $command.Parameters.Keys | Should -Not -Contain 'DependencyStack'
    }

    It 'Get-PackageVersion lists Invoke-Package examples for shipped definitions' {
        $null = Import-Module -Name $script:ModuleManifestPath -Force -PassThru
        $text = Get-PackageVersion

        $text | Should -Match 'Invoke-Package -DefinitionId ''GitRuntime'''
        $text | Should -Match 'Invoke-Package -DefinitionId CodexCli,'
        $text | Should -Not -Match 'VSCodeUser,'
        $text | Should -Not -Match "Add-TeamPackagePublisher -PublisherId 'My Team'"
        $text | Should -Match "Import-PackageTrust -Path '<public-signing-cert.cer>'"
        $text | Should -Match 'New-PackageSigningCertificate -Name'
        $text | Should -Match 'Sign-PackageDefinition -Path'
        $text | Should -Match 'definitionPublication.publisherId'
        $text | Should -Match 'Other exported commands:'
    }

    It 'exports Search-Package with endpoint, trust, and platform filters' {
        $module = Import-Module -Name $script:ModuleManifestPath -Force -PassThru
        $command = $module.ExportedCommands['Search-Package']

        $command | Should -Not -BeNullOrEmpty
        $command.Parameters.Keys | Should -Contain 'Query'
        $command.Parameters.Keys | Should -Contain 'PublisherId'
        $command.Parameters.Keys | Should -Contain 'EndpointName'
        $command.Parameters.Keys | Should -Contain 'Platform'
        $command.Parameters.Keys | Should -Contain 'Architecture'
        $command.Parameters.Keys | Should -Contain 'ReleaseTrack'
        $command.Parameters.Keys | Should -Contain 'CurrentPlatformOnly'
        $command.Parameters.Keys | Should -Contain 'IncludeIneligible'
    }

    It 'exports Get-PackageState with only the Raw view switch' {
        $module = Import-Module -Name $script:ModuleManifestPath -Force -PassThru
        $command = Get-Command -Name 'Get-PackageState'

        $command | Should -Not -BeNullOrEmpty
        $publicParameterNames = @($command.Parameters.Keys | Where-Object {
                $_ -notin [System.Management.Automation.PSCmdlet]::CommonParameters -and
                $_ -notin [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
            })
        $publicParameterNames | Should -Be @('Raw')
    }

    It 'exports only the intended public command surface' {
        $module = Import-Module -Name $script:ModuleManifestPath -Force -PassThru

        @($module.ExportedCommands.Keys | Sort-Object) | Should -Be @(
            'Add-PackageDepot',
            'Add-PackageEndpoint',
            'Add-PackagePublisher',
            'Add-TeamPackageDepot',
            'Add-TeamPackageEndpoint',
            'Add-TeamPackagePublisher',
            'Block-PackageSigningCertificate',
            'Export-PackageTrust',
            'Get-PackageDepot',
            'Get-PackageEndpoint',
            'Get-PackagePublisher',
            'Get-PackageSigningProfile',
            'Get-PackageState',
            'Get-PackageTrust',
            'Get-PackageVersion',
            'Import-PackageTrust',
            'Invoke-Package',
            'Invoke-WebRequestEx',
            'New-PackageSigningCertificate',
            'Remove-PackageDefinitionSignature',
            'Remove-PackageDepot',
            'Remove-PackageEndpoint',
            'Remove-PackagePublisher',
            'Remove-PackageTrust',
            'Resign-PackageDefinition',
            'Revoke-PackageSigningCertificate',
            'Search-Package',
            'Set-PackageDepot',
            'Set-PackageEndpoint',
            'Set-PackagePublisher',
            'Sign-PackageDefinition',
            'Test-PackageDefinitionCatalog',
            'Trust-PackageSigningCertificate',
            'Untrust-PackageSigningCertificate',
            'Update-PackageVersion',
            'Verify-PackageDefinitionCatalog',
            'Verify-PackageDefinitionSignature'
        )
        Get-Command -Name 'Initialize-ProxyAccessProfile' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'keeps user-facing command files in command folders' {
        $moduleProjectRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package'

        Test-Path -LiteralPath (Join-Path $moduleProjectRoot 'Commands\Package\Eigenverft.Manifested.Package.Cmd.InvokePackage.ps1') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $moduleProjectRoot 'Commands\Package\Eigenverft.Manifested.Package.Cmd.GetPackageState.ps1') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $moduleProjectRoot 'Commands\Package\Eigenverft.Manifested.Package.Cmd.SearchPackage.ps1') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $moduleProjectRoot 'Commands\Depot\Eigenverft.Manifested.Package.Cmd.PackageDepot.ps1') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $moduleProjectRoot 'Commands\Endpoint\Eigenverft.Manifested.Package.Cmd.PackageEndpoint.ps1') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $moduleProjectRoot 'Commands\Publisher\Eigenverft.Manifested.Package.Cmd.PackagePublisher.ps1') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $moduleProjectRoot 'Commands\Trust\Eigenverft.Manifested.Package.Cmd.PackageTrust.ps1') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $moduleProjectRoot 'Commands\Trust\Eigenverft.Manifested.Package.Cmd.PackageCatalogValidation.ps1') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $moduleProjectRoot 'Commands\Module\Eigenverft.Manifested.Package.Cmd.Module.ps1') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $moduleProjectRoot 'Commands\Web\Eigenverft.Manifested.Package.Cmd.InvokeWebRequestEx.ps1') -PathType Leaf | Should -BeTrue
    }

    It 'ships the package definition authoring agent skill with safety workflow anchors' {
        $moduleProjectRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package'
        $skillPath = Join-Path $moduleProjectRoot 'AgentSkills\PackageDefinitionAuthoring.md'

        Test-Path -LiteralPath $skillPath -PathType Leaf | Should -BeTrue

        $text = Get-Content -Raw -LiteralPath $skillPath
        $anchors = @(
            'PackageDefinitionAuthoring',
            'PRODUCT-BOUNDARY.md',
            'eigenverft-module-package-definition-1.9.schema.json',
            'Endpoint/Defaults/Eigenverft',
            'Test-PackageDefinitionCatalog',
            'Get-PackageSigningProfile',
            'Sign-PackageDefinition',
            'Resign-PackageDefinition',
            '-KeepSchemaVersion',
            'Verify-PackageDefinitionSignature',
            'Verify-PackageDefinitionCatalog',
            'human review',
            'definitionSignature.kind = unsigned',
            'signatureValue',
            '.cer',
            '.pem'
        )

        foreach ($anchor in $anchors) {
            $text | Should -Match ([regex]::Escape($anchor))
        }
    }

    It 'returns an empty package state when durable inventory/history files and local directories are absent' {
        $root = Join-Path $TestDrive 'empty-package-state'
        $config = [pscustomobject]@{
            PackageConfigPath              = Join-Path $root 'Configuration\Internal\PackageConfig.json'
            PreferredTargetInstallRootDirectory = Join-Path $root 'Inst'
            PackageFileStagingRootDirectory       = Join-Path $root 'PackageFileStaging'
            PackageInstallStageRootDirectory    = Join-Path $root 'PackageInstallStage'
            DefaultPackageDepotDirectory        = Join-Path $root 'PkgDepot'
            LocalEndpointRoot                 = Join-Path $root 'PkgEndpoint'
            ShimDirectory                       = Join-Path $root 'Shims'
            PackageAssignmentInventoryFilePath            = Join-Path (Join-Path $root 'State') 'PackageAssignmentInventory.json'
            PackageOperationHistoryFilePath     = Join-Path (Join-Path $root 'State') 'PackageOperationHistory.json'
            LocalEndpointInventoryPath          = Join-Path (Join-Path $root 'Configuration\Internal') 'PackageEndpointInventory.json'
            LocalTrustInventoryPath             = Join-Path (Join-Path $root 'Configuration\Internal') 'PackageTrustInventory.json'
            LocalDepotInventoryPath             = Join-Path (Join-Path $root 'Configuration\Internal') 'PackageDepotInventory.json'
            ApplicationRootDirectory            = $root
            EndpointInventoryInfo               = [pscustomobject]@{ Path = (Join-Path (Join-Path $root 'Configuration\Internal') 'PackageEndpointInventory.json'); Exists = $false; Document = $null }
            TrustInventoryInfo                  = [pscustomobject]@{ Path = (Join-Path (Join-Path $root 'Configuration\Internal') 'PackageTrustInventory.json'); Exists = $false; Document = $null }
            DepotInventoryInfo                  = [pscustomobject]@{ Path = (Join-Path (Join-Path $root 'Configuration\Internal') 'PackageDepotInventory.json'); Exists = $false; Document = $null }
        }

        Mock Get-PackageConfig { throw 'Get-PackageState must not load a package definition.' }
        Mock Get-PackageStateConfig { return $config }
        Mock Get-PackageInventory { return [pscustomobject]@{ Path = $config.PackageAssignmentInventoryFilePath; Records = @() } }
        Mock Get-PackageOperationHistory { return [pscustomobject]@{ Path = $config.PackageOperationHistoryFilePath; Records = @() } }

        $state = Get-PackageState

        $state.LocalRoot | Should -Be $root
        $state.PackageConfigExists | Should -BeFalse
        $state.LocalTrustInventoryExists | Should -BeFalse
        $state.TrustInventoryExists | Should -BeFalse
        $state.PackageAssignmentInventoryExists | Should -BeFalse
        $state.PackageOperationHistoryExists | Should -BeFalse
        $state.PackageRecordCount | Should -Be 0
        $state.OperationRecordCount | Should -Be 0
        $state.PackageRecords.Count | Should -Be 0
        $state.OperationRecords.Count | Should -Be 0
        $state.Directories.Installed.Exists | Should -BeFalse
        $state.Directories.PackageFileStaging.Exists | Should -BeFalse
        $state.Directories.PackageInstallStage.Exists | Should -BeFalse
        $state.Directories.DefaultPackageDepot.Exists | Should -BeFalse
        $state.Directories.LocalEndpointRoot.Exists | Should -BeFalse
        $state.Directories.Shims.Exists | Should -BeFalse
    }

    It 'gets package state without loading a package definition config' {
        $root = Join-Path $TestDrive 'definition-free-package-state'
        $config = [pscustomobject]@{
            PackageConfigPath              = Join-Path $root 'Configuration\Internal\PackageConfig.json'
            PreferredTargetInstallRootDirectory = Join-Path $root 'Inst'
            PackageFileStagingRootDirectory       = Join-Path $root 'PackageFileStaging'
            PackageInstallStageRootDirectory    = Join-Path $root 'PackageInstallStage'
            DefaultPackageDepotDirectory        = Join-Path $root 'PkgDepot'
            LocalEndpointRoot                 = Join-Path $root 'PkgEndpoint'
            ShimDirectory                       = Join-Path $root 'Shims'
            PackageAssignmentInventoryFilePath            = Join-Path (Join-Path $root 'State') 'PackageAssignmentInventory.json'
            PackageOperationHistoryFilePath     = Join-Path (Join-Path $root 'State') 'PackageOperationHistory.json'
        }

        Mock Get-PackageConfig { throw 'VSCodeRuntime definition should not be required for state.' }
        Mock Get-PackageStateConfig { return $config }
        Mock Get-PackageInventory { return [pscustomobject]@{ Path = $config.PackageAssignmentInventoryFilePath; Records = @() } }
        Mock Get-PackageOperationHistory { return [pscustomobject]@{ Path = $config.PackageOperationHistoryFilePath; Records = @() } }

        { Get-PackageState } | Should -Not -Throw
        Should -Invoke Get-PackageStateConfig -Times 1 -Exactly
        Should -Invoke Get-PackageConfig -Times 0 -Exactly
    }

    It 'summarizes package inventory records, operation records, and local directory state' {
        $root = Join-Path $TestDrive 'populated-package-state'
        $installRoot = Join-Path $root 'Inst'
        $workspaceRoot = Join-Path $root 'PackageFileStaging'
        $installStageRoot = Join-Path $root 'PackageInstallStage'
        $depotRoot = Join-Path $root 'PkgDepot'
        $localEndpointRoot = Join-Path $root 'PkgEndpoint'
        $shimDirectory = Join-Path $root 'Shims'
        $installDirectory = Join-Path $installRoot 'vsc-rt\stable\1.0.0\win32-x64'
        $definitionCandidatePath = Join-Path $localEndpointRoot 'Candidate\Eigenverft\VSCodeRuntime.json'
        $definitionAssignedSnapshotPath = Join-Path $localEndpointRoot 'Assigned\Eigenverft\VSCodeRuntime.json'

        $null = New-Item -ItemType Directory -Path $installDirectory -Force
        $null = New-Item -ItemType Directory -Path $workspaceRoot -Force
        $null = New-Item -ItemType Directory -Path $installStageRoot -Force
        $null = New-Item -ItemType Directory -Path $depotRoot -Force
        $null = New-Item -ItemType Directory -Path $shimDirectory -Force
        Write-TestJsonDocument -Path $definitionCandidatePath -Document (New-TestVSCodeDefinitionDocument -Releases @(
                New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
            ))
        Write-TestJsonDocument -Path $definitionAssignedSnapshotPath -Document (New-TestVSCodeDefinitionDocument -Releases @(
                New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
            ))

        $config = [pscustomobject]@{
            PackageConfigPath              = Join-Path $root 'Configuration\Internal\PackageConfig.json'
            PreferredTargetInstallRootDirectory = $installRoot
            PackageFileStagingRootDirectory       = $workspaceRoot
            PackageInstallStageRootDirectory    = $installStageRoot
            DefaultPackageDepotDirectory        = $depotRoot
            LocalEndpointRoot                 = $localEndpointRoot
            ShimDirectory                       = $shimDirectory
            PackageAssignmentInventoryFilePath            = Join-Path (Join-Path $root 'State') 'PackageAssignmentInventory.json'
            PackageOperationHistoryFilePath     = Join-Path (Join-Path $root 'State') 'PackageOperationHistory.json'
            LocalEndpointInventoryPath          = Join-Path (Join-Path $root 'Configuration\Internal') 'PackageEndpointInventory.json'
            LocalTrustInventoryPath             = Join-Path (Join-Path $root 'Configuration\Internal') 'PackageTrustInventory.json'
            LocalDepotInventoryPath             = Join-Path (Join-Path $root 'Configuration\Internal') 'PackageDepotInventory.json'
            ApplicationRootDirectory            = $root
            EndpointInventoryInfo               = [pscustomobject]@{ Path = (Join-Path (Join-Path $root 'Configuration\Internal') 'PackageEndpointInventory.json'); Exists = $false; Document = $null }
            TrustInventoryInfo                  = [pscustomobject]@{ Path = (Join-Path (Join-Path $root 'Configuration\Internal') 'PackageTrustInventory.json'); Exists = $false; Document = $null }
            DepotInventoryInfo                  = [pscustomobject]@{ Path = (Join-Path (Join-Path $root 'Configuration\Internal') 'PackageDepotInventory.json'); Exists = $false; Document = $null }
        }
        Write-TestJsonDocument -Path $config.PackageAssignmentInventoryFilePath -Document @{ records = @() }
        Write-TestJsonDocument -Path $config.PackageOperationHistoryFilePath -Document @{ records = @() }

        $ownershipRecord = [pscustomobject]@{
            installSlotId    = 'VSCodeRuntime:stable:win32-x64'
            definitionId     = 'VSCodeRuntime'
            definitionPublisherId = 'Eigenverft'
            definitionPublisherName = 'Eigenverft'
            definitionRevision = 1
            definitionPublishedAtUtc = '2026-05-13T12:00:00Z'
            definitionEndpointName = 'moduleDefaults'
            definitionSourceKind = 'moduleLocal'
            definitionSourcePath = Join-Path $root 'VSCodeRuntime.json'
            definitionSourceHash = 'source-hash'
            definitionCandidatePath = $definitionCandidatePath
            definitionCandidateHash = 'candidate-hash'
            definitionAssignedSnapshotPath = $definitionAssignedSnapshotPath
            definitionAssignedSnapshotHash = 'snapshot-hash'
            definitionResolvedAtUtc = '2026-04-25T11:59:00Z'
            releaseTrack     = 'stable'
            artifactDistributionVariant = 'win32-x64'
            currentReleaseId = 'vscode-test'
            currentVersion   = '1.0.0'
            installDirectory = $installDirectory
            ownershipKind    = 'PackageInstalled'
            pathRegistration = [pscustomobject]@{
                mode           = 'user'
                sourceKind     = 'shim'
                sourceValue    = 'code'
                sourcePath     = Join-Path $shimDirectory 'code.cmd'
                registeredPath = $shimDirectory
                status         = 'Registered'
            }
            updatedAtUtc     = '2026-04-25T12:00:00Z'
        }
        $operationRecord = [pscustomobject]@{
            operationId    = 'test-operation'
            definitionEndpointName = 'moduleDefaults'
            definitionId   = 'VSCodeRuntime'
            desiredState   = 'Assigned'
            status         = 'Ready'
            packageId      = 'vscode-test'
            packageVersion = '1.0.0'
            completedAtUtc = '2026-04-25T12:01:00Z'
        }

        Mock Get-PackageConfig { throw 'Get-PackageState must not load a package definition.' }
        Mock Get-PackageStateConfig { return $config }
        Mock Get-PackageInventory { return [pscustomobject]@{ Path = $config.PackageAssignmentInventoryFilePath; Records = @($ownershipRecord) } }
        Mock Get-PackageOperationHistory { return [pscustomobject]@{ Path = $config.PackageOperationHistoryFilePath; Records = @($operationRecord) } }

        $state = Get-PackageState

        $state.PackageAssignmentInventoryExists | Should -BeTrue
        $state.PackageOperationHistoryExists | Should -BeTrue
        $state.PackageRecordCount | Should -Be 1
        $state.OperationRecordCount | Should -Be 1
        $state.PackageRecords[0].InstallSlotId | Should -Be 'VSCodeRuntime:stable:win32-x64'
        $state.PackageRecords[0].DefinitionEndpointName | Should -Be 'moduleDefaults'
        $state.PackageRecords[0].DefinitionCandidateExists | Should -BeTrue
        $state.PackageRecords[0].DefinitionAssignedSnapshotExists | Should -BeTrue
        $state.PackageRecords[0].InstallDirectoryExists | Should -BeTrue
        $state.PackageRecords[0].PathRegistration.SourceKind | Should -Be 'shim'
        $state.PackageRecords[0].PathRegistration.RegisteredPath | Should -Be $shimDirectory
        $state.OperationRecords[0].operationId | Should -Be 'test-operation'
        $state.Directories.Installed.Exists | Should -BeTrue
        $state.Directories.PackageFileStaging.Exists | Should -BeTrue
        $state.Directories.PackageInstallStage.Exists | Should -BeTrue
        $state.Directories.DefaultPackageDepot.Exists | Should -BeTrue
        $state.Directories.LocalEndpointRoot.Exists | Should -BeTrue
        $state.Directories.Shims.Exists | Should -BeTrue
    }

    It 'returns the resolved raw package state on request' {
        $root = Join-Path $TestDrive 'raw-package-state'
        $config = [pscustomobject]@{
            PackageConfigPath              = Join-Path $root 'Configuration\Internal\PackageConfig.json'
            PreferredTargetInstallRootDirectory = Join-Path $root 'Inst'
            PackageFileStagingRootDirectory       = Join-Path $root 'PackageFileStaging'
            PackageInstallStageRootDirectory    = Join-Path $root 'PackageInstallStage'
            DefaultPackageDepotDirectory        = Join-Path $root 'PkgDepot'
            LocalEndpointRoot                 = Join-Path $root 'PkgEndpoint'
            ShimDirectory                       = Join-Path $root 'Shims'
            PackageAssignmentInventoryFilePath            = Join-Path (Join-Path $root 'State') 'PackageAssignmentInventory.json'
            PackageOperationHistoryFilePath     = Join-Path (Join-Path $root 'State') 'PackageOperationHistory.json'
            LocalEndpointInventoryPath          = Join-Path (Join-Path $root 'Configuration\Internal') 'PackageEndpointInventory.json'
            LocalTrustInventoryPath             = Join-Path (Join-Path $root 'Configuration\Internal') 'PackageTrustInventory.json'
            LocalDepotInventoryPath             = Join-Path (Join-Path $root 'Configuration\Internal') 'PackageDepotInventory.json'
            ApplicationRootDirectory            = $root
            EndpointInventoryInfo               = [pscustomobject]@{ Path = (Join-Path (Join-Path $root 'Configuration\Internal') 'PackageEndpointInventory.json'); Exists = $false; Document = $null }
            TrustInventoryInfo                  = [pscustomobject]@{ Path = (Join-Path (Join-Path $root 'Configuration\Internal') 'PackageTrustInventory.json'); Exists = $false; Document = $null }
            DepotInventoryInfo                  = [pscustomobject]@{ Path = (Join-Path (Join-Path $root 'Configuration\Internal') 'PackageDepotInventory.json'); Exists = $false; Document = $null }
        }
        $packageInventory = [pscustomobject]@{ Path = $config.PackageAssignmentInventoryFilePath; Records = @([pscustomobject]@{ definitionId = 'VSCodeRuntime' }) }
        $operationHistory = [pscustomobject]@{ Path = $config.PackageOperationHistoryFilePath; Records = @([pscustomobject]@{ definitionId = 'VSCodeRuntime' }) }

        Mock Get-PackageConfig { throw 'Get-PackageState must not load a package definition.' }
        Mock Get-PackageStateConfig { return $config }
        Mock Get-PackageInventory { return $packageInventory }
        Mock Get-PackageOperationHistory { return $operationHistory }

        $state = Get-PackageState -Raw

        $state.Config | Should -Be $config
        $state.PackageAssignmentInventory | Should -Be $packageInventory
        $state.PackageOperationHistory | Should -Be $operationHistory
        $state.Directories.Installed.Path | Should -Be $config.PreferredTargetInstallRootDirectory
    }

    It 'does not export migrated legacy runtime commands' {
        $module = Import-Module -Name $script:ModuleManifestPath -Force -PassThru

        # Resolve commands against this import only: another copy of the module on PSModulePath
        # (e.g. Documents\WindowsPowerShell\Modules) can otherwise satisfy Get-Command by name alone.
        Get-Command -Name 'Initialize-VSCodeRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Initialize-GitRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Initialize-GHCliRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Initialize-NodeRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Initialize-PythonRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Initialize-Ps7Runtime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Initialize-VCRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Initialize-CodexRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Initialize-GeminiRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Initialize-OpenCodeRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Initialize-QwenRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-CodexRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-GeminiRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-OpenCodeRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-QwenCliRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-GHCliRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Qwen35-2B-Q6K' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Qwen35-2B-Q6K-Model' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-VCRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Ps7Runtime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Package-VSCodeRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Package-GitRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Package-GHCliRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Package-NodeRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Package-PythonRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Package-Ps7Runtime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Package-VCRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Package-CodexRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Package-GeminiRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Package-OpenCodeRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Package-QwenCliRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Package-Qwen35-2B-Q6K' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Package-LlamaCppRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-PackageDefinitionCommand' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-CodexCli' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-GitRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-VSCodeRuntime' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-GitHubCli' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-Qwen35-2B-Q8-0-Model' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-QwenCli' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-GeminiCli' -Module $module -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

}

