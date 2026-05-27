<#
    Eigenverft.Manifested.Package Package - config and definitions
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - config and definitions' -Body {
    It 'loads the shipped global config without baked-in environment sources' {
        $globalInfo = Read-PackageJsonDocument -Path (Get-PackageShippedConfigPath)

        $globalInfo.Document.package.PSObject.Properties.Name | Should -Contain 'preferredTargetInstallDirectory'
        $globalInfo.Document.package.PSObject.Properties.Name | Should -Contain 'applicationRootDirectory'
        $globalInfo.Document.package.PSObject.Properties.Name | Should -Not -Contain 'repositorySources'
        $globalInfo.Document.package.PSObject.Properties.Name | Should -Contain 'localEndpointRoot'
        $globalInfo.Document.package.PSObject.Properties.Name | Should -Contain 'endpointEnvironment'
        $globalInfo.Document.package.PSObject.Properties.Name | Should -Not -Contain 'localRepositoryRoot'
        $globalInfo.Document.package.PSObject.Properties.Name | Should -Not -Contain 'repositoryEnvironment'
        $globalInfo.Document.package.PSObject.Properties.Name | Should -Contain 'shimDirectory'
        $globalInfo.Document.package.shimDirectory | Should -Be '{applicationRootDirectory}/Shims'
        $globalInfo.Document.package.PSObject.Properties.Name | Should -Contain 'layout'
        $globalInfo.Document.package.layout.packageDepotRelativePath | Should -Be '{definitionId}/{releaseTrack}/{version}/{artifactDistributionVariant}'
        $globalInfo.Document.package.layout.packageWorkSlotDirectory | Should -Be '{definitionId}-{slotHash}'
        $globalInfo.Document.package.PSObject.Properties.Name | Should -Contain 'packageState'
        $globalInfo.Document.package.acquisitionEnvironment.stores.PSObject.Properties.Name | Should -Contain 'packageFileStagingDirectory'
        $globalInfo.Document.package.acquisitionEnvironment.stores.PSObject.Properties.Name | Should -Contain 'packageInstallStageDirectory'
        $globalInfo.Document.package.acquisitionEnvironment.stores.packageFileStagingDirectory | Should -Be '{applicationRootDirectory}/FileStage'
        $globalInfo.Document.package.acquisitionEnvironment.stores.packageInstallStageDirectory | Should -Be '{applicationRootDirectory}/InstStage'
        $globalInfo.Document.package.acquisitionEnvironment.stores.PSObject.Properties.Name | Should -Not -Contain 'defaultPackageDepotDirectory'
        $globalInfo.Document.package.acquisitionEnvironment.defaults.PSObject.Properties.Name | Should -Contain 'allowFallback'
        $globalInfo.Document.package.acquisitionEnvironment.defaults.depotDistributionMode | Should -Be 'packageFocused'
        $globalInfo.Document.package.endpointEnvironment.defaults.endpointMaterializationMode | Should -Be 'packageFocused'
        $globalInfo.Document.package.endpointEnvironment.defaults.definitionPublisherConflictMode | Should -Be 'fail'
        $globalInfo.Document.package.acquisitionEnvironment.defaults.PSObject.Properties.Name | Should -Not -Contain 'mirrorDownloadedArtifactsToDefaultPackageDepot'
        $globalInfo.Document.package.packageState.PSObject.Properties.Name | Should -Contain 'inventoryFilePath'
        $globalInfo.Document.package.packageState.PSObject.Properties.Name | Should -Contain 'operationHistoryFilePath'
        $endpointInventoryInfo = Read-PackageJsonDocument -Path (Get-PackageShippedEndpointInventoryPath)
        $moduleSource = Get-TestEndpointSource -Document $endpointInventoryInfo.Document -SourceId 'moduleDefaults'
        $moduleSource.kind | Should -Be 'moduleLocal'
        $moduleSource.definitionRoot | Should -Be 'Endpoint/Defaults'
        $moduleSource.PSObject.Properties['trusted'] | Should -BeNullOrEmpty
        $moduleSource.PSObject.Properties['trustMode'] | Should -BeNullOrEmpty
        $depotInfo = Read-PackageJsonDocument -Path (Get-PackageShippedDepotInventoryPath)
        $depotInfo.Document.acquisitionEnvironment.environmentSources.PSObject.Properties.Name | Should -Contain 'defaultPackageDepot'
        $depotInfo.Document.acquisitionEnvironment.environmentSources.defaultPackageDepot.readable | Should -BeTrue
        $depotInfo.Document.acquisitionEnvironment.environmentSources.defaultPackageDepot.writable | Should -BeTrue
        $depotInfo.Document.acquisitionEnvironment.environmentSources.defaultPackageDepot.mirrorTarget | Should -BeTrue
        $depotInfo.Document.acquisitionEnvironment.environmentSources.defaultPackageDepot.ensureExists | Should -BeTrue
        $depotInfo.Document.acquisitionEnvironment.environmentSources.defaultPackageDepot.basePath | Should -Be '{applicationRootDirectory}/PkgDepot'
        $globalInfo.Document.package.acquisitionEnvironment.PSObject.Properties.Name | Should -Not -Contain 'tracking'
        $globalInfo.Document.package.acquisitionEnvironment.PSObject.Properties['environmentSources'] | Should -BeNullOrEmpty
    }

    It 'resolves the bootstrap local root from shipped PackageConfig.json' {
        $rootPath = Join-Path $TestDrive 'bootstrap-root-config'
        $applicationRootPath = Join-Path $rootPath 'AppRoot'
        $shippedConfigPath = Join-Path $rootPath 'Configuration\Internal\PackageConfig.json'
        Write-TestJsonDocument -Path $shippedConfigPath -Document (New-TestPackageGlobalDocument -ApplicationRootDirectory $applicationRootPath)
        Mock Get-PackageShippedConfigPath { $shippedConfigPath }

        Get-PackageLocalRoot | Should -Be ([System.IO.Path]::GetFullPath($applicationRootPath))
    }

    It 'fails clearly when shipped PackageConfig.json cannot provide an absolute bootstrap root' {
        $missingRootConfigPath = Join-Path $TestDrive 'missing-root\PackageConfig.json'
        Write-TestJsonDocument -Path $missingRootConfigPath -Document @{ package = @{} }
        $mockShippedConfigPath = $missingRootConfigPath
        Mock Get-PackageShippedConfigPath { $mockShippedConfigPath }

        { Get-PackageLocalRoot } | Should -Throw '*must define package.applicationRootDirectory*'

        $relativeRootConfigPath = Join-Path $TestDrive 'relative-root\PackageConfig.json'
        Write-TestJsonDocument -Path $relativeRootConfigPath -Document (New-TestPackageGlobalDocument -ApplicationRootDirectory 'relative-root')
        $mockShippedConfigPath = $relativeRootConfigPath

        { Get-PackageLocalRoot } | Should -Throw '*does not resolve to an absolute path*'
    }

    It 'creates the local PackageConfig.json copy from shipped configuration when missing' {
        $localGlobalPath = Get-PackageLocalConfigPath
        if (Test-Path -LiteralPath $localGlobalPath -PathType Leaf) {
            Remove-Item -LiteralPath $localGlobalPath -Force
        }

        $activeGlobalPath = Get-PackageConfigPath
        $localInfo = Read-PackageJsonDocument -Path $localGlobalPath

        $activeGlobalPath | Should -Be $localGlobalPath
        Test-Path -LiteralPath $localGlobalPath -PathType Leaf | Should -BeTrue
        $localInfo.Document.package.PSObject.Properties.Name | Should -Not -Contain 'repositorySources'
    }

    It 'creates the local PackageEndpointInventory.json copy from shipped configuration when missing' {
        $localEndpointInventoryPath = Get-PackageLocalEndpointInventoryPath
        if (Test-Path -LiteralPath $localEndpointInventoryPath -PathType Leaf) {
            Remove-Item -LiteralPath $localEndpointInventoryPath -Force
        }

        $activeEndpointInventoryPath = Get-PackageEndpointInventoryPath
        $localInfo = Read-PackageJsonDocument -Path $localEndpointInventoryPath

        $activeEndpointInventoryPath | Should -Be $localEndpointInventoryPath
        Test-Path -LiteralPath $localEndpointInventoryPath -PathType Leaf | Should -BeTrue
        (Get-TestEndpointSource -Document $localInfo.Document -SourceId 'moduleDefaults').kind | Should -Be 'moduleLocal'
    }

    It 'orders package versions by the package version selection policy' {
        $normalCandidates = @(
            [pscustomobject]@{ Label = '1.14.46'; VersionOrdering = Get-PackageVersionOrderingInfo -VersionText '1.14.46' -AuthorIndex 0 -CandidateIndex 0 }
            [pscustomobject]@{ Label = '1.15.7'; VersionOrdering = Get-PackageVersionOrderingInfo -VersionText '1.15.7' -AuthorIndex 1 -CandidateIndex 1 }
            [pscustomobject]@{ Label = '1.9.99'; VersionOrdering = Get-PackageVersionOrderingInfo -VersionText '1.9.99' -AuthorIndex 2 -CandidateIndex 2 }
        )
        @((Sort-PackageVersionCandidates -Candidates $normalCandidates).Label) | Should -Be @('1.15.7', '1.14.46', '1.9.99')
        $normalCandidates[0].VersionOrdering.OrderingKind | Should -Be 'normalVersion'

        $integerCandidates = @(
            [pscustomobject]@{ Label = '9094'; VersionOrdering = Get-PackageVersionOrderingInfo -VersionText '9094' -AuthorIndex 0 -CandidateIndex 0 }
            [pscustomobject]@{ Label = '100'; VersionOrdering = Get-PackageVersionOrderingInfo -VersionText '100' -AuthorIndex 1 -CandidateIndex 1 }
        )
        @((Sort-PackageVersionCandidates -Candidates $integerCandidates).Label) | Should -Be @('9094', '100')
        $integerCandidates[0].VersionOrdering.OrderingKind | Should -Be 'plainInteger'

        $dateHashCandidates = @(
            [pscustomobject]@{ Label = '2026.05.09-0afadcc'; VersionOrdering = Get-PackageVersionOrderingInfo -VersionText '2026.05.09-0afadcc' -AuthorIndex 0 -CandidateIndex 0 }
            [pscustomobject]@{ Label = '2026.04.30-abcdef0'; VersionOrdering = Get-PackageVersionOrderingInfo -VersionText '2026.04.30-abcdef0' -AuthorIndex 1 -CandidateIndex 1 }
        )
        @((Sort-PackageVersionCandidates -Candidates $dateHashCandidates).Label) | Should -Be @('2026.05.09-0afadcc', '2026.04.30-abcdef0')
        $dateHashCandidates[0].VersionOrdering.OrderingKind | Should -Be 'dateHash'

        $tieCandidates = @(
            [pscustomobject]@{ Label = 'first'; VersionOrdering = Get-PackageVersionOrderingInfo -VersionText '2026.05.09-aaa' -AuthorIndex 0 -CandidateIndex 0 }
            [pscustomobject]@{ Label = 'second'; VersionOrdering = Get-PackageVersionOrderingInfo -VersionText '2026.05.09-bbb' -AuthorIndex 1 -CandidateIndex 1 }
        )
        @((Sort-PackageVersionCandidates -Candidates $tieCandidates).Label) | Should -Be @('first', 'second')
    }

    It 'resolves package config paths from applicationRootDirectory and supports missing applicationRootDirectory fallback' {
        $rootPath = Join-Path $TestDrive 'application-root-config'
        $applicationRootPath = Join-Path $rootPath 'AppRoot'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory $applicationRootPath
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'

        $config.ApplicationRootDirectory | Should -Be ([System.IO.Path]::GetFullPath($applicationRootPath))
        $config.PreferredTargetInstallRootDirectory | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $applicationRootPath 'Inst')))
        $config.PackageFileStagingRootDirectory | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $applicationRootPath 'FileStage')))
        $config.PackageInstallStageRootDirectory | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $applicationRootPath 'InstStage')))
        $config.DefaultPackageDepotDirectory | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $applicationRootPath 'PkgDepot')))
        $config.LocalEndpointRoot | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $applicationRootPath 'PkgEndpoint')))
        $config.ShimDirectory | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $applicationRootPath 'Shims')))

        $fallbackRootPath = Join-Path $TestDrive 'application-root-fallback'
        $fallbackGlobalDocument = New-TestPackageGlobalDocument
        $fallbackGlobalDocument.package.Remove('applicationRootDirectory')
        $fallbackDocuments = Write-TestPackageDocuments -RootPath $fallbackRootPath -GlobalDocument $fallbackGlobalDocument -DefinitionDocument $definitionDocument
        Mock Get-PackageConfigPath { $fallbackDocuments.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $fallbackDocuments.DefinitionPath }

        $fallbackConfig = Get-PackageConfig -DefinitionId 'VSCodeRuntime'

        $fallbackConfig.ApplicationRootDirectory | Should -Be (Get-PackageDefaultApplicationRootDirectory)
        $fallbackConfig.PackageFileStagingRootDirectory | Should -Be ([System.IO.Path]::GetFullPath((Join-Path (Get-PackageDefaultApplicationRootDirectory) 'FileStage')))
        $fallbackConfig.ShimDirectory | Should -Be ([System.IO.Path]::GetFullPath((Join-Path (Get-PackageDefaultApplicationRootDirectory) 'Shims')))
    }

    It 'resolves absolute configured paths without joining them under applicationRootDirectory' {
        $rootPath = Join-Path $TestDrive 'absolute-config-paths'
        $applicationRootPath = Join-Path $rootPath 'AppRoot'
        $absoluteInstallPath = Join-Path $rootPath 'AbsoluteInstalled'
        $absoluteFileStagingPath = Join-Path $rootPath 'AbsoluteFileStaging'
        $absoluteInstallStagingPath = Join-Path $rootPath 'AbsoluteInstallStaging'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory $applicationRootPath -PreferredTargetInstallDirectory $absoluteInstallPath -PackageFileStagingDirectory $absoluteFileStagingPath -PackageInstallStageDirectory $absoluteInstallStagingPath
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'

        $config.PreferredTargetInstallRootDirectory | Should -Be ([System.IO.Path]::GetFullPath($absoluteInstallPath))
        $config.PackageFileStagingRootDirectory | Should -Be ([System.IO.Path]::GetFullPath($absoluteFileStagingPath))
        $config.PackageInstallStageRootDirectory | Should -Be ([System.IO.Path]::GetFullPath($absoluteInstallStagingPath))
        $config.ShimDirectory | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $applicationRootPath 'Shims')))
    }

    It 'creates the local PackageDepotInventory.json copy from shipped configuration when missing' {
        $localDepotInventoryPath = Get-PackageLocalDepotInventoryPath
        if (Test-Path -LiteralPath $localDepotInventoryPath -PathType Leaf) {
            Remove-Item -LiteralPath $localDepotInventoryPath -Force
        }

        $activeDepotInventoryPath = Get-PackageDepotInventoryPath
        $localInfo = Read-PackageJsonDocument -Path $localDepotInventoryPath

        $activeDepotInventoryPath | Should -Be $localDepotInventoryPath
        Test-Path -LiteralPath $localDepotInventoryPath -PathType Leaf | Should -BeTrue
        $localInfo.Document.acquisitionEnvironment.environmentSources.defaultPackageDepot.enabled | Should -BeTrue
    }

    It 'initializes the local package environment once and creates only eligible depot roots' {
        $rootPath = Join-Path $TestDrive 'local-environment-init'
        $applicationRootPath = Join-Path $rootPath 'AppRoot'
        $defaultDepotPath = Join-Path $rootPath 'PkgDepot'
        $readOnlyDepotPath = Join-Path $rootPath 'ReadOnlyPackageDepot'
        $disabledDepotPath = Join-Path $rootPath 'DisabledPackageDepot'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory $applicationRootPath
        $depotInventory = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory $defaultDepotPath -EnvironmentSources @{
            readOnlyPackageDepot = @{
                kind         = 'filesystem'
                enabled      = $true
                searchOrder  = 400
                basePath     = $readOnlyDepotPath
                readable     = $true
                writable     = $false
                mirrorTarget = $false
                ensureExists = $false
            }
            disabledPackageDepot = @{
                kind         = 'filesystem'
                enabled      = $false
                searchOrder  = 500
                basePath     = $disabledDepotPath
                readable     = $true
                writable     = $true
                mirrorTarget = $true
                ensureExists = $true
            }
        }
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DepotInventoryDocument $depotInventory -DefinitionDocument $definitionDocument
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $environment = Initialize-PackageLocalEnvironment -PackageConfig $config
        $markerPath = Join-Path (Join-Path $applicationRootPath 'State') 'PackageLocalEnvironment.json'
        $localConfigDirectory = Split-Path -Parent (Get-PackageLocalConfigPath)
        $localDepotInventoryDirectory = Split-Path -Parent (Get-PackageLocalDepotInventoryPath)

        $environment.Status | Should -Be 'Initialized'
        $environment.InitializedNow | Should -BeTrue
        $environment.MarkerPath | Should -Be ([System.IO.Path]::GetFullPath($markerPath))
        Test-Path -LiteralPath $markerPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $applicationRootPath -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $localConfigDirectory -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $localDepotInventoryDirectory -PathType Container | Should -BeTrue
        Test-Path -LiteralPath (Join-Path (Join-Path $applicationRootPath 'Configuration') 'External') -PathType Container | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $applicationRootPath 'Inst') -PathType Container | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $applicationRootPath 'FileStage') -PathType Container | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $applicationRootPath 'InstStage') -PathType Container | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $applicationRootPath 'PkgEndpoint') -PathType Container | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $applicationRootPath 'Shims') -PathType Container | Should -BeTrue
        Test-Path -LiteralPath (Join-Path (Join-Path $applicationRootPath 'Caches') 'npm') -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $defaultDepotPath -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $readOnlyDepotPath -PathType Container | Should -BeFalse
        Test-Path -LiteralPath $disabledDepotPath -PathType Container | Should -BeFalse
        @($environment.SkippedSources | Where-Object { $_.SourceId -eq 'readOnlyPackageDepot' }).Count | Should -Be 1
    }

    It 'skips all directory verification when the local environment marker already exists' {
        $rootPath = Join-Path $TestDrive 'local-environment-marker-skip'
        $applicationRootPath = Join-Path $rootPath 'AppRoot'
        $markerPath = Join-Path (Join-Path $applicationRootPath 'State') 'PackageLocalEnvironment.json'
        Write-TestJsonDocument -Path $markerPath -Document @{
            schemaVersion = 1
            initializedAtUtc = [DateTime]::UtcNow.ToString('o')
            applicationRootDirectory = $applicationRootPath
            directoryVersion = 1
        }
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory $applicationRootPath
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $environment = Initialize-PackageLocalEnvironment -PackageConfig $config

        $environment.Status | Should -Be 'AlreadyInitialized'
        $environment.InitializedNow | Should -BeFalse
        @($environment.CreatedDirectories).Count | Should -Be 0
        @($environment.ExistingDirectories).Count | Should -Be 0
        @($environment.SkippedSources).Count | Should -Be 0
        Test-Path -LiteralPath $config.LocalEndpointRoot -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $config.DefinitionCandidatePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $config.DefaultPackageDepotDirectory -PathType Container | Should -BeFalse
    }

    It 'reports local environment initialization failures through the package command result' {
        $rootPath = Join-Path $TestDrive 'local-environment-command-failure'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }
        Mock Initialize-PackageLocalEnvironment { throw 'local environment boom' }

        $result = Invoke-PackageDefinitionCommandCore -DefinitionId 'VSCodeRuntime'

        $result.Status | Should -Be 'Failed'
        $result.FailureReason | Should -Be 'LocalEnvironmentInitializationFailed'
        $result.ErrorMessage | Should -Be 'local environment boom'
    }

    It 'initializes the local package environment before catalog trust resolution' {
        $rootPath = Join-Path $TestDrive 'local-environment-before-trust'
        $applicationRootPath = Join-Path $rootPath 'AppRoot'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory $applicationRootPath -CatalogTrustPolicy strict -CatalogTrustAllowUnsignedPublisherIds @()
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument
        $markerPath = Join-Path (Join-Path $applicationRootPath 'State') 'PackageLocalEnvironment.json'
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }

        { Invoke-PackageDefinitionCommandCore -DefinitionId 'VSCodeRuntime' } | Should -Throw "*catalog trust policy 'strict'*"

        Test-Path -LiteralPath $markerPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $applicationRootPath 'PkgEndpoint') -PathType Container | Should -BeTrue
    }

    It 'runs Invoke-Package with active repository search and assigned state' {
        Mock Invoke-PackageDefinitionCommandCore {
            [pscustomobject]@{
                PublisherId     = $PublisherId
                DefinitionId    = $DefinitionId
                DesiredState    = $DesiredState
                PackageVersion  = $PackageVersion
                Status          = 'Ready'
            }
        }

        $result = Invoke-Package -DefinitionId 'GitRuntime'

        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter {
            [string]::IsNullOrWhiteSpace($PublisherId) -and
            $DefinitionId -eq 'GitRuntime' -and
            $DesiredState -eq 'Assigned' -and
            $null -eq $PackageVersion
        }
        $result.Status | Should -Be 'Ready'
        $result.PackageVersion | Should -BeNullOrEmpty
    }

    It 'passes an exact PackageVersion selector through Invoke-Package for assigned state' {
        Mock Invoke-PackageDefinitionCommandCore {
            [pscustomobject]@{
                PublisherId     = $PublisherId
                DefinitionId    = $DefinitionId
                DesiredState    = $DesiredState
                PackageVersion  = $PackageVersion
                Status          = 'Ready'
            }
        }

        $result = Invoke-Package -DefinitionId 'OpenCodeCli' -PackageVersion '1.14.46'

        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter {
            $DefinitionId -eq 'OpenCodeCli' -and
            $DesiredState -eq 'Assigned' -and
            $PackageVersion -eq '1.14.46'
        }
        $result.PackageVersion | Should -Be '1.14.46'
    }

    It 'rejects exact PackageVersion selectors for removed state' {
        { Invoke-Package -DefinitionId 'OpenCodeCli' -DesiredState Removed -PackageVersion '1.14.46' } | Should -Throw '*PackageVersion*DesiredState Removed*'
        { Invoke-Package -DefinitionId 'OpenCodeCli' -DesiredState Removed -PackageVersion 'previousByVersion' } | Should -Throw '*PackageVersion*DesiredState Removed*'
    }

    It 'allows explicit latestByVersion with removed state as default-equivalent' {
        Mock Invoke-PackageDefinitionCommandCore {
            [pscustomobject]@{
                DefinitionId   = $DefinitionId
                DesiredState   = $DesiredState
                PackageVersion = $PackageVersion
                Status         = 'Ready'
            }
        }

        $result = Invoke-Package -DefinitionId 'OpenCodeCli' -DesiredState Removed -PackageVersion 'latestByVersion'

        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter {
            $DefinitionId -eq 'OpenCodeCli' -and
            $DesiredState -eq 'Removed' -and
            $PackageVersion -eq 'latestByVersion'
        }
        $result.Status | Should -Be 'Ready'
    }

    It 'runs Invoke-Package definition id arrays in listed order' {
        Mock Invoke-PackageDefinitionCommandCore {
            [pscustomobject]@{
                PublisherId = $PublisherId
                DefinitionId = $DefinitionId
                DesiredState = $DesiredState
                Status       = 'Ready'
            }
        }

        $results = @(Invoke-Package -DefinitionId GitRuntime, CodexCli)

        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter { $DefinitionId -eq 'GitRuntime' }
        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter { $DefinitionId -eq 'CodexCli' }
        @($results.DefinitionId) | Should -Be @('GitRuntime', 'CodexCli')
    }

    It 'continues Invoke-Package definition id arrays after a failed result by default' {
        Mock Invoke-PackageDefinitionCommandCore {
            [pscustomobject]@{
                PublisherId = $PublisherId
                DefinitionId = $DefinitionId
                DesiredState = $DesiredState
                Status       = if ($DefinitionId -eq 'GitRuntime') { 'Failed' } else { 'Ready' }
            }
        }

        $results = @(Invoke-Package -DefinitionId GitRuntime, CodexCli)

        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter { $DefinitionId -eq 'GitRuntime' }
        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter { $DefinitionId -eq 'CodexCli' }
        @($results.DefinitionId) | Should -Be @('GitRuntime', 'CodexCli')
        $results[0].Status | Should -Be 'Failed'
        $results[1].Status | Should -Be 'Ready'
    }

    It 'stops Invoke-Package arrays after the first failed result when FailFast is set' {
        Mock Invoke-PackageDefinitionCommandCore {
            [pscustomobject]@{
                PublisherId = $PublisherId
                DefinitionId = $DefinitionId
                DesiredState = $DesiredState
                Status       = if ($DefinitionId -eq 'GitRuntime') { 'Failed' } else { 'Ready' }
            }
        }

        $results = @(Invoke-Package -DefinitionId GitRuntime, CodexCli -FailFast)

        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter { $DefinitionId -eq 'GitRuntime' }
        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 0 -ParameterFilter { $DefinitionId -eq 'CodexCli' }
        @($results.DefinitionId) | Should -Be @('GitRuntime')
        $results[0].Status | Should -Be 'Failed'
    }

    It 'resolves shipped package definitions through signed trust and endpoint seams' {
        $reference = Resolve-PackageDefinitionReference -DefinitionId 'VSCodeRuntime'

        $reference.EndpointName | Should -Be 'moduleDefaults'
        $reference.PublisherId | Should -Be 'Eigenverft'
        $reference.DefinitionId | Should -Be 'VSCodeRuntime'
        $reference.SourceKind | Should -Be 'moduleLocal'
        Split-Path -Leaf $reference.DefinitionPath | Should -Be 'VSCodeRuntime.json'
    }

    It 'ships Eigenverft defaults as trusted signed definitions with embedded public certificates' {
        $definitionRoot = Join-Path (Get-PackageShippedEndpointRoot) 'Defaults\Eigenverft'
        $catalog = Verify-PackageDefinitionCatalog -Path $definitionRoot -RequireTrusted
        $trustRows = @(Get-PackageTrust -PublisherId 'Eigenverft')
        $definitionFiles = @(Get-ChildItem -LiteralPath $definitionRoot -Filter '*.json' -File)
        $signedDocuments = @(
            foreach ($definitionFile in $definitionFiles) {
                (Read-PackageJsonDocument -Path $definitionFile.FullName).Document
            }
        )

        $catalog.CheckedCount | Should -Be $definitionFiles.Count
        $catalog.FailedCount | Should -Be 0
        $catalog.ValidCount | Should -Be $definitionFiles.Count
        $catalog.TrustedCount | Should -Be $definitionFiles.Count
        $trustRows.Count | Should -Be 1
        $trustRows[0].TrustSource | Should -Be 'moduleShipped'
        $trustRows[0].KeyThumbprint | Should -Not -Be 'DD1E9435FB3AE68ABF2DB99E5638502E00D2FD90'
        @($catalog.Results | Where-Object { $_.KeyThumbprint -ne $trustRows[0].KeyThumbprint }).Count | Should -Be 0
        @($signedDocuments | Where-Object { -not $_.definitionPublication.definitionSignature.PSObject.Properties['certificatePem'] }).Count | Should -Be 0
        @($signedDocuments | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.definitionPublication.definitionSignature.certificatePem) }).Count | Should -Be 0
    }

    It 'fails clearly when a publisher id selector does not match a discovered definition' {
        { Resolve-PackageDefinitionReference -PublisherId 'OtherPublisher' -DefinitionId 'VSCodeRuntime' } | Should -Throw "*publisher 'OtherPublisher'*"
    }

    It 'applies definition publisher conflict policy across eligible publishers' {
        $rootPath = Join-Path $TestDrive 'publisher-conflict-policy'
        $endpointA = Join-Path $rootPath 'EndpointA'
        $endpointB = Join-Path $rootPath 'EndpointB'
        $localEndpointRoot = Join-Path $rootPath 'PkgEndpoint'

        Write-TestJsonDocument -Path (Join-Path (Join-Path $endpointA 'Alpha') 'SharedTool.json') -Document (New-TestVSCodeDefinitionDocument -DefinitionId 'SharedTool' -PublisherId 'Alpha' -PublisherName 'Alpha' -Releases @(
                New-TestPackageRelease -Id 'shared-alpha' -Version '1.0.0' -Architecture 'x64'
            ))
        Write-TestJsonDocument -Path (Join-Path (Join-Path $endpointB 'Beta') 'SharedTool.json') -Document (New-TestVSCodeDefinitionDocument -DefinitionId 'SharedTool' -PublisherId 'Beta' -PublisherName 'Beta' -Releases @(
                New-TestPackageRelease -Id 'shared-beta' -Version '1.0.0' -Architecture 'x64'
            ))

        $endpointInventoryPath = Join-Path $rootPath 'PackageEndpointInventory.json'
        Write-TestJsonDocument -Path $endpointInventoryPath -Document @{
            inventoryVersion = 2
            endpoints = @(
                @{ endpointName = 'alphaEndpoint'; kind = 'filesystem'; enabled = $true; searchOrder = 100; basePath = $endpointA },
                @{ endpointName = 'betaEndpoint'; kind = 'filesystem'; enabled = $true; searchOrder = 200; basePath = $endpointB }
            )
        }

        Mock Get-PackageEndpointInventoryPath { $endpointInventoryPath }

        { Resolve-PackageDefinitionReference -DefinitionId 'SharedTool' -LocalEndpointRoot $localEndpointRoot -CatalogTrustPolicy allowUnsigned -CatalogTrustAllowUnsignedPublisherIds @('Alpha', 'Beta') -DefinitionPublisherConflictMode 'fail' } | Should -Throw '*multiple eligible publisherIds*Use -PublisherId*'

        $first = Resolve-PackageDefinitionReference -DefinitionId 'SharedTool' -LocalEndpointRoot $localEndpointRoot -CatalogTrustPolicy allowUnsigned -CatalogTrustAllowUnsignedPublisherIds @('Alpha', 'Beta') -DefinitionPublisherConflictMode 'warnFirst'
        $last = Resolve-PackageDefinitionReference -DefinitionId 'SharedTool' -LocalEndpointRoot $localEndpointRoot -CatalogTrustPolicy allowUnsigned -CatalogTrustAllowUnsignedPublisherIds @('Alpha', 'Beta') -DefinitionPublisherConflictMode 'last'

        $first.PublisherId | Should -Be 'Alpha'
        $last.PublisherId | Should -Be 'Beta'
    }

    It 'fails when one publisher reuses a definition revision with different bytes across endpoints' {
        $rootPath = Join-Path $TestDrive 'publisher-reused-revision'
        $endpointA = Join-Path $rootPath 'EndpointA'
        $endpointB = Join-Path $rootPath 'EndpointB'
        $localEndpointRoot = Join-Path $rootPath 'PkgEndpoint'

        Write-TestJsonDocument -Path (Join-Path (Join-Path $endpointA 'Alpha') 'SharedTool.json') -Document (New-TestVSCodeDefinitionDocument -DefinitionId 'SharedTool' -PublisherId 'Alpha' -PublisherName 'Alpha' -DefinitionRevision 7 -Releases @(
                New-TestPackageRelease -Id 'shared-alpha' -Version '1.0.0' -Architecture 'x64'
            ))
        Write-TestJsonDocument -Path (Join-Path (Join-Path $endpointB 'Alpha') 'SharedTool.json') -Document (New-TestVSCodeDefinitionDocument -DefinitionId 'SharedTool' -PublisherId 'Alpha' -PublisherName 'Alpha' -DefinitionRevision 7 -Releases @(
                New-TestPackageRelease -Id 'shared-alpha' -Version '1.0.1' -Architecture 'x64'
            ))

        $endpointInventoryPath = Join-Path $rootPath 'PackageEndpointInventory.json'
        Write-TestJsonDocument -Path $endpointInventoryPath -Document @{
            inventoryVersion = 2
            endpoints = @(
                @{ endpointName = 'alphaPrimary'; kind = 'filesystem'; enabled = $true; searchOrder = 100; basePath = $endpointA },
                @{ endpointName = 'alphaMirror'; kind = 'filesystem'; enabled = $true; searchOrder = 200; basePath = $endpointB }
            )
        }

        Mock Get-PackageEndpointInventoryPath { $endpointInventoryPath }

        { Resolve-PackageDefinitionReference -DefinitionId 'SharedTool' -LocalEndpointRoot $localEndpointRoot -CatalogTrustPolicy allowUnsigned -CatalogTrustAllowUnsignedPublisherIds @('Alpha') } | Should -Throw '*reused definitionRevision*different content across endpoints*'
    }

    It 'completes removed desired state when inventory is missing and whenNotInInventory is succeed' {
        $rootPath = Join-Path $TestDrive 'removed-no-inventory-succeed'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument

        $inventoryPath = Join-Path (Join-Path $rootPath 'AppRoot') 'State\PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force
        Write-TestJsonDocument -Path $inventoryPath -Document @{ schemaVersion = 1; records = @() }
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $result = Invoke-Package -DefinitionId 'VSCodeRuntime' -DesiredState Removed

        $result.Status | Should -Be 'Ready'
        $result.Removed.Accepted | Should -Be $true
    }

    It 'fails removed desired state when inventory is missing and whenNotInInventory is fail' {
        $rootPath = Join-Path $TestDrive 'removed-no-inventory-fail'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $definitionDocument.packageOperations.removed.policy.whenNotInInventory = 'fail'
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument

        $inventoryPath = Join-Path (Join-Path $rootPath 'AppRoot') 'State\PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force
        Write-TestJsonDocument -Path $inventoryPath -Document @{ schemaVersion = 1; records = @() }
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $result = Invoke-Package -DefinitionId 'VSCodeRuntime' -DesiredState Removed

        $result.Status | Should -Be 'Failed'
        $result.FailureReason | Should -Be 'RemovalInventoryResolutionFailed'
    }

    It 'fails removed flow when removeDependencies policy is true' {
        $rootPath = Join-Path $TestDrive 'removed-deps-not-implemented'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $definitionDocument.packageOperations.removed.policy.removeDependencies = $true
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument

        $inventoryPath = Join-Path (Join-Path $rootPath 'AppRoot') 'State\PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force
        Write-TestJsonDocument -Path $inventoryPath -Document @{ schemaVersion = 1; records = @() }
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $result = Invoke-Package -DefinitionId 'VSCodeRuntime' -DesiredState Removed

        $result.Status | Should -Be 'Failed'
        $result.FailureReason | Should -Be 'RemovalPolicyRejected'
        $result.ErrorMessage | Should -Match 'removeDependencies'
    }

    It 'removes install directory and inventory when removed flow runs with matching inventory record' {
        $rootPath = Join-Path $TestDrive 'removed-delete-success'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument

        $appRoot = Join-Path $rootPath 'AppRoot'
        $preferredRoot = Join-Path $appRoot 'Inst'
        $installDir = Join-Path $preferredRoot 'vsc-rt\stable\2.0.0\win32-x64'
        $null = New-Item -ItemType Directory -Path (Join-Path $installDir 'bin') -Force
        Write-TestTextFile -Path (Join-Path $installDir 'Code.exe') -Content 'x'
        Write-TestTextFile -Path (Join-Path $installDir 'bin\code.cmd') -Content '@echo off'

        $inventoryPath = Join-Path $appRoot 'State\PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force
        $assignedSnapshotPath = Join-Path $appRoot 'PkgEndpoint\Assigned\Eigenverft\VSCodeRuntime.json'
        Write-TestJsonDocument -Path $assignedSnapshotPath -Document $definitionDocument
        $record = @{
            installSlotId       = 'VSCodeRuntime:stable:win32-x64'
            definitionId        = 'VSCodeRuntime'
            definitionPublisherId = 'Eigenverft'
            definitionPublisherName = 'Eigenverft'
            definitionRevision = 1
            definitionPublishedAtUtc = '2026-05-13T00:00:00Z'
            definitionEndpointName = 'moduleDefaults'
            definitionSourceKind = 'filesystem'
            definitionSourcePath = $documents.DefinitionPath
            definitionSourceHash = (Get-PackageFileSha256 -Path $documents.DefinitionPath)
            definitionAssignedSnapshotPath = $assignedSnapshotPath
            definitionAssignedSnapshotHash = (Get-PackageFileSha256 -Path $assignedSnapshotPath)
            releaseTrack        = 'stable'
            artifactDistributionVariant = 'win32-x64'
            currentReleaseId    = 'vsCode-win-x64-stable'
            currentVersion      = '2.0.0'
            installDirectory    = $installDir
            ownershipKind       = 'PackageInstalled'
            pathRegistration    = $null
            updatedAtUtc        = [DateTime]::UtcNow.ToString('o')
        }
        Write-TestJsonDocument -Path $inventoryPath -Document @{ schemaVersion = 1; records = @($record) }
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $result = Invoke-Package -DefinitionId 'VSCodeRuntime' -DesiredState Removed

        $result.Status | Should -Be 'Ready'
        $result.Removed.Accepted | Should -Be $true
        Test-Path -LiteralPath $installDir | Should -Be $false
        Test-Path -LiteralPath (Join-Path $preferredRoot 'vsc-rt') | Should -Be $false

        $invAfter = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
        @($invAfter.records).Count | Should -Be 0
    }

    It 'keeps inventory when removed absence verification fails before cleanup' {
        $rootPath = Join-Path $TestDrive 'removed-absence-failure-keeps-inventory'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $definitionDocument.packageOperations.removed.operation = @{
            kind = 'none'
        }
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument

        $appRoot = Join-Path $rootPath 'AppRoot'
        $installDir = Join-Path $appRoot 'Inst\vsc-rt\stable\2.0.0\win32-x64'
        Write-TestTextFile -Path (Join-Path $installDir 'Code.exe') -Content 'x'
        Write-TestTextFile -Path (Join-Path $installDir 'bin\code.cmd') -Content "@echo off`r`necho 2.0.0`r`n"
        $null = New-Item -ItemType Directory -Path (Join-Path $installDir 'data') -Force

        $inventoryPath = Join-Path $appRoot 'State\PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force
        $assignedSnapshotPath = Join-Path $appRoot 'PkgEndpoint\Assigned\Eigenverft\VSCodeRuntime.json'
        Write-TestJsonDocument -Path $assignedSnapshotPath -Document $definitionDocument
        $record = @{
            installSlotId       = 'VSCodeRuntime:stable:win32-x64'
            definitionId        = 'VSCodeRuntime'
            definitionPublisherId = 'Eigenverft'
            definitionPublisherName = 'Eigenverft'
            definitionRevision = 1
            definitionPublishedAtUtc = '2026-05-13T00:00:00Z'
            definitionEndpointName = 'moduleDefaults'
            definitionSourceKind = 'filesystem'
            definitionSourcePath = $documents.DefinitionPath
            definitionSourceHash = (Get-PackageFileSha256 -Path $documents.DefinitionPath)
            definitionAssignedSnapshotPath = $assignedSnapshotPath
            definitionAssignedSnapshotHash = (Get-PackageFileSha256 -Path $assignedSnapshotPath)
            releaseTrack        = 'stable'
            artifactDistributionVariant = 'win32-x64'
            currentReleaseId    = 'vsCode-win-x64-stable'
            currentVersion      = '2.0.0'
            installDirectory    = $installDir
            ownershipKind       = 'PackageInstalled'
            pathRegistration    = $null
            updatedAtUtc        = [DateTime]::UtcNow.ToString('o')
        }
        Write-TestJsonDocument -Path $inventoryPath -Document @{ schemaVersion = 1; records = @($record) }
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $result = Invoke-Package -DefinitionId 'VSCodeRuntime' -DesiredState Removed

        $result.Status | Should -Be 'Failed'
        $result.ErrorMessage | Should -Match 'absence verification failed'
        $invAfter = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
        @($invAfter.records).Count | Should -Be 1
    }

    It 'blocks removed when another inventory record definition still depends on the target' {
        $rootPath = Join-Path $TestDrive 'removed-blocked-by-dependents'
        $defDir = Join-Path $rootPath 'RepoDefs'
        $null = New-Item -ItemType Directory -Path $defDir -Force
        $moduleProjectRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package'
        $shippedDefs = Join-Path $moduleProjectRoot 'Endpoint\Defaults\Eigenverft'
        Copy-Item -LiteralPath (Join-Path $shippedDefs 'CodexCli.json') -Destination (Join-Path $defDir 'CodexCli.json') -Force
        Copy-Item -LiteralPath (Join-Path $shippedDefs 'NodeRuntime.json') -Destination (Join-Path $defDir 'NodeRuntime.json') -Force

        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument

        Mock Get-PackageDefinitionPath { param($DefinitionId) Join-Path $defDir ("$DefinitionId.json") }

        $appRoot = Join-Path $rootPath 'AppRoot'
        $codexDir = Join-Path $appRoot 'Inst\codex-cli'
        $nodeDir = Join-Path $appRoot 'Inst\node'
        $null = New-Item -ItemType Directory -Path $codexDir -Force
        $null = New-Item -ItemType Directory -Path $nodeDir -Force

        $now = [DateTime]::UtcNow.ToString('o')
        $records = @(
            @{
                installSlotId                = 'CodexCli:stable:win32-x64'
                definitionId                 = 'CodexCli'
                definitionPublisherId        = 'Eigenverft'
                definitionPublisherName      = 'Eigenverft'
                definitionRevision           = 1
                definitionPublishedAtUtc     = '2026-05-13T12:00:00Z'
                definitionEndpointName        = 'moduleDefaults'
                definitionSourcePath         = (Join-Path $defDir 'CodexCli.json')
                definitionAssignedSnapshotPath = (Join-Path $defDir 'CodexCli.json')
                definitionAssignedSnapshotHash = (Get-PackageFileSha256 -Path (Join-Path $defDir 'CodexCli.json'))
                releaseTrack                 = 'stable'
                artifactDistributionVariant  = 'win32-x64'
                currentReleaseId             = 'CodexCli-win32-x64-stable'
                currentVersion               = '0.130.0'
                installDirectory             = $codexDir
                ownershipKind                = 'PackageInstalled'
                pathRegistration             = $null
                updatedAtUtc                 = $now
            }
            @{
                installSlotId                = 'NodeRuntime:stable:win-x64'
                definitionId                 = 'NodeRuntime'
                definitionPublisherId        = 'Eigenverft'
                definitionPublisherName      = 'Eigenverft'
                definitionRevision           = 1
                definitionPublishedAtUtc     = '2026-05-13T12:00:00Z'
                definitionEndpointName        = 'moduleDefaults'
                definitionSourcePath         = (Join-Path $defDir 'NodeRuntime.json')
                definitionAssignedSnapshotPath = (Join-Path $defDir 'NodeRuntime.json')
                definitionAssignedSnapshotHash = (Get-PackageFileSha256 -Path (Join-Path $defDir 'NodeRuntime.json'))
                releaseTrack                 = 'stable'
                artifactDistributionVariant  = 'win-x64'
                currentReleaseId             = 'NodeRuntime-win-x64-stable'
                currentVersion               = '22.0.0'
                installDirectory             = $nodeDir
                ownershipKind                = 'PackageInstalled'
                pathRegistration             = $null
                updatedAtUtc                 = $now
            }
        )
        $inventoryPath = Join-Path $appRoot 'State\PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force
        Write-TestJsonDocument -Path $inventoryPath -Document @{ schemaVersion = 1; records = $records }
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }

        $result = Invoke-Package -DefinitionId 'NodeRuntime' -DesiredState Removed

        $result.Status | Should -Be 'Failed'
        $result.FailureReason | Should -Be 'RemovalDependencyDependentsBlocked'
        $result.ErrorMessage | Should -Match 'CodexCli'
    }

    It 'fails clearly when global config still uses retired ownershipTracking' {
        $globalConfigPath = Join-Path $TestDrive 'Global-old-ownership.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.ownershipTracking = @{
            indexFilePath = Join-Path $TestDrive 'ownership-index.json'
        }
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*ownershipTracking*'
    }

    It 'fails clearly when global config still uses retired artifactIndexFilePath' {
        $globalConfigPath = Join-Path $TestDrive 'Global-old-artifact.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.acquisitionEnvironment.tracking = @{}
        $badGlobal.package.acquisitionEnvironment.tracking.artifactIndexFilePath = Join-Path $TestDrive 'artifact-index.json'
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*artifactIndexFilePath*'
    }

    It 'fails clearly when global config still uses retired packageFileIndexFilePath' {
        $globalConfigPath = Join-Path $TestDrive 'Global-old-package-file-index.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.acquisitionEnvironment.tracking = @{
            packageFileIndexFilePath = Join-Path $TestDrive 'package-file-index.json'
        }
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*packageFileIndexFilePath*'
    }

    It 'fails clearly when global config still uses retired installWorkspaceDirectory' {
        $globalConfigPath = Join-Path $TestDrive 'Global-old-install-workspace.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.acquisitionEnvironment.stores.Remove('packageFileStagingDirectory')
        $badGlobal.package.acquisitionEnvironment.stores.installWorkspaceDirectory = Join-Path $TestDrive 'InstallWorkspace'
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*installWorkspaceDirectory*'
    }

    It 'fails clearly when global config still uses retired installPreparationDirectory' {
        $globalConfigPath = Join-Path $TestDrive 'Global-old-install-preparation.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.acquisitionEnvironment.stores.Remove('packageFileStagingDirectory')
        $badGlobal.package.acquisitionEnvironment.stores.Remove('packageInstallStageDirectory')
        $badGlobal.package.acquisitionEnvironment.stores.installPreparationDirectory = Join-Path $TestDrive 'InstallPreparation'
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*installPreparationDirectory*'
    }

    It 'fails clearly when global config still uses retired mirrorDownloadedArtifactsToDefaultPackageDepot' {
        $globalConfigPath = Join-Path $TestDrive 'Global-old-mirror-default.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.acquisitionEnvironment.defaults.mirrorDownloadedArtifactsToDefaultPackageDepot = $true
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*mirrorDownloadedArtifactsToDefaultPackageDepot*'
    }

    It 'rejects unsupported depot distribution modes' {
        $globalConfigPath = Join-Path $TestDrive 'Global-invalid-depot-distribution-mode.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.acquisitionEnvironment.defaults.depotDistributionMode = 'surpriseMe'
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*depotDistributionMode*'
    }

    It 'rejects filesystem depot inventory entries without explicit capability fields' {
        $depotInventoryPath = Join-Path $TestDrive 'DepotInventory-missing-capability.json'
        $badDepotInventory = New-TestDepotInventoryDocument
        $badDepotInventory.acquisitionEnvironment.environmentSources.defaultPackageDepot.Remove('readable')
        Write-TestJsonDocument -Path $depotInventoryPath -Document $badDepotInventory

        $depotInfo = Read-PackageJsonDocument -Path $depotInventoryPath
        { Assert-PackageDepotInventorySchema -DepotInventoryDocumentInfo $depotInfo } | Should -Throw '*readable*'
    }

    It 'rejects depot inventory mirror and ensure flags when a filesystem depot is not writable' {
        $depotInventoryPath = Join-Path $TestDrive 'DepotInventory-invalid-capabilities.json'
        $badDepotInventory = New-TestDepotInventoryDocument
        $badDepotInventory.acquisitionEnvironment.environmentSources.defaultPackageDepot.writable = $false
        $badDepotInventory.acquisitionEnvironment.environmentSources.defaultPackageDepot.mirrorTarget = $true
        $badDepotInventory.acquisitionEnvironment.environmentSources.defaultPackageDepot.ensureExists = $true
        Write-TestJsonDocument -Path $depotInventoryPath -Document $badDepotInventory

        $depotInfo = Read-PackageJsonDocument -Path $depotInventoryPath
        { Assert-PackageDepotInventorySchema -DepotInventoryDocumentInfo $depotInfo } | Should -Throw '*mirrorTarget=true*'

        $badDepotInventory.acquisitionEnvironment.environmentSources.defaultPackageDepot.mirrorTarget = $false
        Write-TestJsonDocument -Path $depotInventoryPath -Document $badDepotInventory
        $depotInfo = Read-PackageJsonDocument -Path $depotInventoryPath
        { Assert-PackageDepotInventorySchema -DepotInventoryDocumentInfo $depotInfo } | Should -Throw '*ensureExists=true*'
    }

    It 'loads the shipped LlamaCppRuntime definition and selects the fixed GitHub-backed release' {

        $config = Get-PackageConfig -DefinitionId 'LlamaCppRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'llamaCppGitHub' })

        $config.DefinitionId | Should -Be 'LlamaCppRuntime'
        @($config.Definition.dependencies.definitionId) | Should -Be @('VisualCppRedistributable')
        @($config.Definition.dependencies.publisherId) | Should -Be @($null)
        $sourceDefinition.Kind | Should -Be 'githubRelease'
        $sourceDefinition.GitHubOwner | Should -Be 'ggml-org'
        $sourceDefinition.GitHubRepository | Should -Be 'llama.cpp'
        $result.PackageId | Should -Be 'llama-cpp-win-cpu-x64-stable'
        $result.Package.version | Should -Be '9279'
        $result.Package.releaseTag | Should -Be 'b9279'
        $result.Package.packageFile.fileName | Should -Be 'llama-b9279-bin-win-cpu-x64.zip'
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        @($config.Definition.discovery.presence.commands.name) | Should -Be @('llama-cli', 'llama-server', 'llama-quantize', 'llama-bench', 'llama-tokenize')
    }

    It 'loads the shipped GitRuntime definition and selects the fixed GitHub-backed release' {

        $config = Get-PackageConfig -DefinitionId 'GitRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'gitForWindowsGitHub' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'MinGit-2.54.0-arm64.zip'
        }
        else {
            'MinGit-2.54.0-64-bit.zip'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '68f6bdda5b58f4e40f431c0da48b05ba5596445314d5e491e7b4aebb1ec2e985'
        }
        else {
            '04f937e1f0918b17b9be6f2294cb2bb66e96e1d9832d1c298e2de088a1d0e668'
        }

        $config.DefinitionId | Should -Be 'GitRuntime'
        $sourceDefinition.Kind | Should -Be 'githubRelease'
        $sourceDefinition.GitHubOwner | Should -Be 'git-for-windows'
        $sourceDefinition.GitHubRepository | Should -Be 'git'
        $result.Package.version | Should -Be '2.54.0'
        $result.Package.releaseTag | Should -Be 'v2.54.0.windows.1'
        $result.Package.packageFile.fileName | Should -Be $expectedFileName
        $result.Package.packageFile.contentHash.value | Should -Be $expectedSha256
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        $config.Definition.discovery.presence.commands[0].name | Should -Be 'git'
    }

    It 'loads the shipped NotepadPlusPlus definition and selects the fixed NSIS installer release' {

        $config = Get-PackageConfig -DefinitionId 'NotepadPlusPlus'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'notepadPlusPlusGitHubRelease' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'npp.8.9.6.Installer.arm64.exe'
        }
        else {
            'npp.8.9.6.Installer.x64.exe'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '75ac9c66ee33d673ac3f7185386d2559547bb8ee9acb62adac9815445042ea3c'
        }
        else {
            '2ff794611c96ebbeb116ecd1ca4b97183435287bf7c24eef96c4fe2b11e5b8a0'
        }

        $config.DefinitionId | Should -Be 'NotepadPlusPlus'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/'
        $result.Package.version | Should -Be '8.9.6'
        $result.Package.assigned.install.kind | Should -Be 'nsisInstaller'
        $result.Package.assigned.install.targetDirectoryArgument.prefix | Should -Be '/D='
        $result.Package.discovery.existingInstall.searchLocations[0].kind | Should -Be 'windowsUninstallRegistryKey'
        $result.Package.discovery.existingInstall.searchLocations[0].installDirectorySource | Should -Be 'displayIconDirectory'
        $result.Package.packageFile.fileName | Should -Be $expectedFileName
        $result.Package.packageFile.contentHash.value | Should -Be $expectedSha256
    }

    It 'loads the shipped VSCodeUser definition with Inno Setup uninstall registry removal' {

        $config = Get-PackageConfig -DefinitionId 'VSCodeUser'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result

        $config.DefinitionId | Should -Be 'VSCodeUser'
        $result.Package.assigned.install.kind | Should -Be 'innoSetupInstaller'
        $result.Package.removed.operation.kind | Should -Be 'innoSetupUninstaller'
        $result.Package.discovery.existingInstall.enabled | Should -Be $true
        $result.Package.discovery.existingInstall.searchLocations[0].kind | Should -Be 'windowsUninstallRegistryKey'
        @($result.Package.discovery.existingInstall.searchLocations[0].paths)[0] | Should -Match '^HKCU:'
        $result.Package.discovery.existingInstall.searchLocations[0].installDirectorySource | Should -Be 'installLocation'
        $result.Package.removed.policy.allowedInventoryOwnershipKinds | Should -Contain 'AdoptedExternal'
    }

    It 'loads the shipped SevenZip definition with MSI install and uninstall registry search' {

        $config = Get-PackageConfig -DefinitionId 'SevenZip'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'sevenZipGitHubRelease' })

        $config.DefinitionId | Should -Be 'SevenZip'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://github.com/ip7z/7zip/releases/download/'
        $result.Package.version | Should -Be '26.01'
        $result.Package.releaseTag | Should -Be '2601'
        $result.Package.packageFile.fileName | Should -Be '7z2601-x64.msi'
        $result.Package.packageFile.contentHash.algorithm | Should -Be 'sha256'
        $result.Package.packageFile.contentHash.value | Should -Be 'a47ea8dcf8bc08e6de474cae77c828e031fa22cb528f6095defffebf11cd02f2'
        $result.Package.assigned.install.kind | Should -Be 'msiInstaller'
        $result.Package.assigned.install.targetDirectoryProperty.name | Should -Be 'INSTALLDIR'
        $result.Package.removed.operation.kind | Should -Be 'msiUninstaller'
        $result.Package.discovery.existingInstall.searchLocations[0].kind | Should -Be 'windowsUninstallRegistrySearch'
        $result.Package.discovery.existingInstall.searchLocations[0].displayNamePatterns | Should -Contain '7-Zip* (x64)*'
        $result.Package.removed.policy.allowedInventoryOwnershipKinds | Should -Contain 'AdoptedExternal'
        $result.AcquisitionPlan.PackageFileRequired | Should -BeTrue
        @($result.AcquisitionPlan.Candidates | ForEach-Object { $_.kind }) | Should -Be @('packageDepot', 'download')
    }

    It 'loads the shipped NodeRuntime definition and selects the fixed Node.js archive release' {

        $config = Get-PackageConfig -DefinitionId 'NodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'nodeJsRelease' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'node-v26.2.0-win-arm64.zip'
        }
        else {
            'node-v26.2.0-win-x64.zip'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '131efa8bd858f8ad000a1a0436d8bb1320c638291c779a921fb20e5702a1cc0a'
        }
        else {
            '371071a4f7e2c8a5dd280730049c685911feecc59f50ebc488d675dc1087c69c'
        }

        $config.DefinitionId | Should -Be 'NodeRuntime'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://nodejs.org/dist/'
        $result.Package.version | Should -Be '26.2.0'
        $result.Package.releaseTag | Should -Be 'v26.2.0'
        $result.Package.packageFile.fileName | Should -Be $expectedFileName
        $result.Package.packageFile.contentHash.value | Should -Be $expectedSha256
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        @($config.Definition.discovery.presence.commands.name) | Should -Be @('node', 'npm', 'npx')
    }

    It 'loads the shipped DotNetSdk10 definition and selects the fixed Microsoft archive release' {

        $config = Get-PackageConfig -DefinitionId 'DotNetSdk10'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'dotNetBuilds' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'dotnet-sdk-10.0.300-win-arm64.zip'
        }
        else {
            'dotnet-sdk-10.0.300-win-x64.zip'
        }
        $expectedSha512 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '86a6ab513ba16b6dfbe8497c5eb8ee9791819c6a0d8dfffc8eee6c7d6387718f9e486010da24c354e1f4be5f99286e78a799848ee806a67b8b9fec6e4bf773cd'
        }
        else {
            '32446eddffc5a485f58f9d79cdab3a1a9adab4adc2ef0e4c787cfbb2465020d50beaadc54d40f0850e2e0089edd09864d12d6c19c526319819d57a4c00d38518'
        }

        $config.DefinitionId | Should -Be 'DotNetSdk10'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://builds.dotnet.microsoft.com/dotnet/'
        $result.Package.version | Should -Be '10.0.300'
        $result.Package.releaseTag | Should -Be '10.0.8'
        $result.Package.packageFile.fileName | Should -Be $expectedFileName
        $result.Package.packageFile.contentHash.algorithm | Should -Be 'sha512'
        $result.Package.packageFile.contentHash.value | Should -Be $expectedSha512
        $result.Package.assigned.install.kind | Should -Be 'expandArchive'
        $result.Package.assigned.install.installDirectory | Should -Be 'dotnet-sdk10/{releaseTrack}/{version}/{artifactDistributionVariant}'
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        @($config.Definition.discovery.presence.commands.name) | Should -Be @('dotnet')
    }

    It 'loads the shipped CursorCli definition and selects the fixed Cursor lab archive release' {

        $config = Get-PackageConfig -DefinitionId 'CursorCli'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'cursorAgentCliLab' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'agent-cli-package-2026.05.09-0afadcc-win32-arm64.zip'
        }
        else {
            'agent-cli-package-2026.05.09-0afadcc-win32-x64.zip'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '9b622fb0d7f51f8e1bfa5dcb840a5c5eaaf4829fda588e653fc04e3c83dbd1ac'
        }
        else {
            '9acfc6043f021508bb91badc8b8d6c34ef00bd3389907d8930514f1c8b52f03c'
        }

        $config.DefinitionId | Should -Be 'CursorCli'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://downloads.cursor.com/lab/'
        $result.Package.version | Should -Be '2026.05.09-0afadcc'
        $result.Package.assigned.install.kind | Should -Be 'expandArchive'
        $result.Package.assigned.install.expandedRoot | Should -Be 'dist-package'
        $result.Package.packageFile.fileName | Should -Be $expectedFileName
        $result.Package.packageFile.contentHash.value | Should -Be $expectedSha256
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        $config.Definition.discovery.presence.commands[0].name | Should -Be 'agent'
        $config.Definition.discovery.presence.commands[0].relativePath | Should -Be 'cursor-agent.cmd'
    }

    It 'loads the shipped materialized npm definitions without authored package-file acquisition' {

        $cases = @(
            [pscustomobject]@{ DefinitionId = 'CodexCli'; PackageSpec = '@openai/codex@{version}'; Version = '0.133.0'; Command = 'codex'; RelativePath = 'codex.cmd'; Dependencies = @('VisualCppRedistributable', 'NodeRuntime') }
            [pscustomobject]@{ DefinitionId = 'OpenCodeCli'; PackageSpec = 'opencode-ai@{version}'; Version = '1.15.7'; Command = 'opencode'; RelativePath = 'opencode.cmd'; Dependencies = @('NodeRuntime') }
        )

        foreach ($case in $cases) {
            $config = Get-PackageConfig -DefinitionId $case.DefinitionId
            $result = New-PackageResult -PackageConfig $config
            $result = Resolve-PackagePackage -PackageResult $result
            $result = Resolve-PackagePaths -PackageResult $result
            $result = Build-PackageAcquisitionPlan -PackageResult $result

            $config.DefinitionId | Should -Be $case.DefinitionId
            @($config.Definition.dependencies.definitionId) | Should -Be $case.Dependencies
            $result.Package.version | Should -Be $case.Version
            $result.Package.assigned.install.kind | Should -Be 'npmMaterializedInstallGlobalPackage'
            $result.Package.assigned.install.packageSpec | Should -Be $case.PackageSpec
            $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
            $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
            $config.Definition.discovery.presence.commands[0].name | Should -Be $case.Command
            $config.Definition.discovery.presence.commands[0].relativePath | Should -Be $case.RelativePath
            foreach ($dep in @($config.Definition.dependencies)) {
                $dep.PSObject.Properties.Name | Should -Not -Contain 'repositoryId'
            }
            $result.Package.packageFile | Should -BeNullOrEmpty
            $result.Package.assigned.install.PSObject.Properties.Name | Should -Not -Contain 'additionalTarballs'
            $result.AcquisitionPlan.PackageFileRequired | Should -BeFalse
            @($result.AcquisitionPlan.Candidates).Count | Should -Be 0
        }

        { Get-PackageConfig -DefinitionId 'OpenCodeCliDepot' } | Should -Throw
        { Get-PackageConfig -DefinitionId 'OpenCodePlatformNpmPackage' } | Should -Throw
    }

    It 'selects OpenCode package versions from definition policy and command overrides' {

        $config = Get-PackageConfig -DefinitionId 'OpenCodeCli'

        $latest = New-PackageResult -PackageConfig $config
        $latest = Resolve-PackagePackage -PackageResult $latest
        $latest.PackageVersionSelectionSource | Should -Be 'definition'
        $latest.PackageVersionSelector | Should -Be 'latestByVersion'
        $latest.PackageVersionOrderingKind | Should -Be 'normalVersion'
        $latest.Package.version | Should -Be '1.15.7'

        $explicitLatest = New-PackageResult -PackageConfig $config -PackageVersionSelector 'latestByVersion'
        $explicitLatest = Resolve-PackagePackage -PackageResult $explicitLatest
        $explicitLatest.PackageVersionSelectionSource | Should -Be 'command'
        $explicitLatest.PackageVersionSelector | Should -Be 'latestByVersion'
        $explicitLatest.Package.version | Should -Be '1.15.7'

        $previous = New-PackageResult -PackageConfig $config -PackageVersionSelector 'previousByVersion'
        $previous = Resolve-PackagePackage -PackageResult $previous
        $previous.PackageVersionSelectionSource | Should -Be 'command'
        $previous.PackageVersionSelector | Should -Be 'previousByVersion'
        $previous.Package.version | Should -Be '1.14.46'

        $pinned = New-PackageResult -PackageConfig $config -PackageVersionSelector '1.14.46'
        $pinned = Resolve-PackagePackage -PackageResult $pinned
        $pinned.PackageVersionSelectionSource | Should -Be 'command'
        $pinned.PackageVersionSelector | Should -Be '1.14.46'
        $pinned.RequestedPackageVersion | Should -Be '1.14.46'
        $pinned.Package.version | Should -Be '1.14.46'
        $pinned.Package.assigned.install.packageSpec | Should -Be 'opencode-ai@{version}'

        $missing = New-PackageResult -PackageConfig $config -PackageVersionSelector '0.0.1'
        { Resolve-PackagePackage -PackageResult $missing } | Should -Throw "*Package version '0.0.1' is not authored*"
    }

    It 'selects the only compatible version for previousByVersion when no previous version exists' {

        $config = Get-PackageConfig -DefinitionId 'GitRuntime'
        $result = New-PackageResult -PackageConfig $config -PackageVersionSelector 'previousByVersion'
        $result = Resolve-PackagePackage -PackageResult $result

        $result.PackageVersionSelectionSource | Should -Be 'command'
        $result.PackageVersionSelector | Should -Be 'previousByVersion'
        $result.Package.version | Should -Be '2.54.0'
    }

    It 'loads shipped depot-backed PowerShell module definitions with package-file acquisition' {

        $cases = @(
            [pscustomobject]@{ DefinitionId = 'PackageManagement'; ModuleName = 'PackageManagement'; Version = '1.4.8.1'; Hash = '7e1f8a75b6bc8a83d8abff79f6690fc1dfbd534fd3e5733d97e19bcb5954c13e'; Dependencies = @() }
            [pscustomobject]@{ DefinitionId = 'PowerShellGet'; ModuleName = 'PowerShellGet'; Version = '2.2.5'; Hash = '6b8cebf2a464eaeb31b0a6d627355c30d9d1899dba0ce3bdd0d4e7afca148673'; Dependencies = @('PackageManagement') }
            [pscustomobject]@{ DefinitionId = 'EigenverftManifestedAgent'; ModuleName = 'Eigenverft.Manifested.Agent'; Version = '1.20261.39327'; Hash = 'dd4eacf33d5eb8e6fc0a706fb2e18941b07d9466ae9532e7f94f2c5bcfe1727f'; Dependencies = @('PowerShellGet') }
        )

        foreach ($case in $cases) {
            $config = Get-PackageConfig -DefinitionId $case.DefinitionId
            $result = New-PackageResult -PackageConfig $config
            $result = Resolve-PackagePackage -PackageResult $result
            $result = Resolve-PackagePaths -PackageResult $result
            $result = Build-PackageAcquisitionPlan -PackageResult $result

            $config.DefinitionId | Should -Be $case.DefinitionId
            @($config.Definition.dependencies.definitionId) | Should -Be $case.Dependencies
            $result.Package.version | Should -Be $case.Version
            $result.Package.assigned.install.kind | Should -Be 'powershellModuleInstaller'
            $result.Package.assigned.install.moduleName | Should -Be $case.ModuleName
            $result.Package.assigned.install.requiredVersion | Should -Be $case.Version
            $config.Definition.discovery.presence.powerShellModules[0].name | Should -Be $case.ModuleName
            $result.Package.readiness.powerShellModules[0].RequiredVersion | Should -Be $case.Version
            $result.Package.ownershipPolicy.allowAdoptExternal | Should -BeTrue
            $result.Package.ownershipPolicy.requirePackageOwnership | Should -BeFalse
            $result.Package.packageFile.fileName | Should -Be ('{0}.{1}.nupkg' -f $case.ModuleName, $case.Version)
            $result.Package.packageFile.contentHash.value | Should -Be $case.Hash
            $result.InstallDirectory | Should -BeNullOrEmpty
            $result.AcquisitionPlan.PackageFileRequired | Should -BeTrue
            @($result.AcquisitionPlan.Candidates | ForEach-Object { $_.kind }) | Should -Be @('packageDepot', 'download')
        }
    }

    It 'ensures direct package dependencies before package-specific install flow continues' {
        $definition = [pscustomobject]@{
            definitionId = 'CodexCli'
            dependencies = @(
                [pscustomobject]@{ definitionId = 'VisualCppRedistributable' }
                [pscustomobject]@{ definitionId = 'NodeRuntime' }
            )
        }
        $result = [pscustomobject]@{
            DefinitionId                = 'CodexCli'
            DefinitionPublisherId       = 'Eigenverft'
            PackageConfig = [pscustomobject]@{
                Definition = $definition
            }
            Dependencies  = @()
        }

        Mock Invoke-PackageDefinitionCommandCore {
            [pscustomobject]@{
                DefinitionPublisherId = 'Eigenverft'
                Status               = 'Ready'
                InstallOrigin        = 'PackageReused'
                Install                = [pscustomobject]@{ Status = 'ReusedPackageOwned' }
                EntryPoints            = [pscustomobject]@{
                    Commands = @(
                        [pscustomobject]@{
                            Name = if ($DefinitionId -eq 'NodeRuntime') { 'npm' } else { 'vc-runtime' }
                            Path = Join-Path $TestDrive "$DefinitionId.cmd"
                        }
                    )
                }
            }
        }

        $resolved = Resolve-PackageDependencies -PackageResult $result

        @($resolved.Dependencies.DefinitionId) | Should -Be @('VisualCppRedistributable', 'NodeRuntime')
        @($resolved.Dependencies.PublisherId) | Should -Be @('Eigenverft', 'Eigenverft')
        @($resolved.Dependencies.Status) | Should -Be @('Ready', 'Ready')
        @($resolved.Dependencies[1].Commands.Name) | Should -Be @('npm')
    }

    It 'fails clearly when direct package dependencies contain a cycle' {
        $definition = [pscustomobject]@{
            definitionId = 'CodexCli'
            dependencies = @(
                [pscustomobject]@{ definitionId = 'NodeRuntime' }
            )
        }
        $result = [pscustomobject]@{
            DefinitionId       = 'CodexCli'
            DefinitionPublisherId = 'Eigenverft'
            PackageConfig = [pscustomobject]@{
                Definition = $definition
            }
            Dependencies       = @()
        }

        { Resolve-PackageDependencies -PackageResult $result -DependencyStack @('Eigenverft:CodexCli', 'Eigenverft:NodeRuntime') } | Should -Throw '*dependency cycle*'
    }

    It 'loads the shipped PythonRuntime definition and selects the fixed NuGet package release' {

        $config = Get-PackageConfig -DefinitionId 'PythonRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'pythonNuGetPackage' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'pythonarm64.3.14.5.nupkg'
        }
        else {
            'python.3.14.5.nupkg'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'ff4558830622fb904923dd8b68132a1971b6cd688b04d28623c9f3953079409a'
        }
        else {
            '03ad5810986afd8273a34a28c15cb594300ba7f4749f24362d69206fa1b6ac15'
        }

        $config.DefinitionId | Should -Be 'PythonRuntime'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://api.nuget.org/v3-flatcontainer/'
        $result.Package.version | Should -Be '3.14.5'
        $result.Package.releaseTag | Should -Be '3.14.5'
        $result.Package.packageFile.fileName | Should -Be $expectedFileName
        $result.Package.packageFile.contentHash.value | Should -Be $expectedSha256
        $result.Package.assigned.install.expandedRoot | Should -Be 'tools'
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        $config.Definition.discovery.presence.commands[0].name | Should -Be 'python'
        $result.Package.readiness.commandChecks[1].arguments | Should -Be @('-m', 'pip', '--version')
    }

    It 'loads the shipped PowerShell7 definition and selects the fixed GitHub-backed release' {

        $config = Get-PackageConfig -DefinitionId 'PowerShell7'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'powerShellGitHub' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'PowerShell-7.6.2-win-arm64.zip'
        }
        else {
            'PowerShell-7.6.2-win-x64.zip'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '4dfc686a7aa872fe427d0508b89cef6069c01861c59d8844ae1ffb4d2d7ae017'
        }
        else {
            '32e0dd26752483ba3f0e40e9ae44150643cbff469c13210c93295d158bfd7b26'
        }

        $config.DefinitionId | Should -Be 'PowerShell7'
        $sourceDefinition.Kind | Should -Be 'githubRelease'
        $sourceDefinition.GitHubOwner | Should -Be 'PowerShell'
        $sourceDefinition.GitHubRepository | Should -Be 'PowerShell'
        $result.Package.version | Should -Be '7.6.2'
        $result.Package.releaseTag | Should -Be 'v7.6.2'
        $result.Package.packageFile.fileName | Should -Be $expectedFileName
        $result.Package.packageFile.contentHash.value | Should -Be $expectedSha256
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        $config.Definition.discovery.presence.commands[0].name | Should -Be 'pwsh'
    }

    It 'loads the shipped VisualCppRedistributable definition as an elevated machine prerequisite' {

        $config = Get-PackageConfig -DefinitionId 'VisualCppRedistributable'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'visualCppRedistributableDownload' })

        $config.DefinitionId | Should -Be 'VisualCppRedistributable'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://aka.ms/'
        $result.PackageId | Should -Be 'vc-runtime-x64-stable'
        $result.Package.assigned.install.kind | Should -Be 'runInstaller'
        $result.Package.assigned.install.targetKind | Should -Be 'machinePrerequisite'
        $result.Package.assigned.install.elevation | Should -Be 'required'
        $result.Package.assigned.install.commandArguments | Should -Be @('/install', '/quiet', '/norestart', '/log', '{logPath}')
        $result.Package.packageFile.fileName | Should -Be 'vc_redist.x64.exe'
        $result.Package.packageFile.publisherSignature.subjectContains | Should -Be 'Microsoft Corporation'
    }

    It 'loads the shipped Qwen35_9B_Q6_K_Model definition and selects the fixed Hugging Face-backed resource release' {
        Mock Get-PhysicalMemoryGiB { 8.0 }
        Mock Get-VideoMemoryGiB { 2.0 }

        $config = Get-PackageConfig -DefinitionId 'Qwen35_9B_Q6_K_Model'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'huggingFaceDownload' })

        $config.DefinitionId | Should -Be 'Qwen35_9B_Q6_K_Model'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/'
        $result.PackageId | Should -Be 'qwen35-9b-q6-k-stable'
        $result.Package.version | Should -Be '3.5.0'
        $result.Package.packageFile.fileName | Should -Be 'Qwen3.5-9B-Q6_K.gguf'
        $result.Package.packageFile.contentHash.algorithm | Should -Be 'sha256'
        $result.Package.packageFile.contentHash.value | Should -Be '91898433cf5ce0a8f45516a4cc3e9343b6e01d052d01f684309098c66a326c59'
        $result.Package.assigned.install.kind | Should -Be 'placePackageFile'
        $result.Compatibility.Count | Should -Be 1
        $result.Compatibility[0].Kind | Should -Be 'physicalOrVideoMemoryGiB'
        $result.Compatibility[0].OnFail | Should -Be 'warn'
        $result.Compatibility[0].Accepted | Should -BeFalse
    }

    It 'fails clearly when the shipped global config still defines vsCodeUpdateService as an environment source' {
        $globalConfigPath = Join-Path $TestDrive 'PackageConfig.json'
        $badGlobal = New-TestPackageGlobalDocument -EnvironmentSources @{
            vsCodeUpdateService = @{ kind = 'download'; baseUri = 'https://example.invalid/' }
        }
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*vsCodeUpdateService*'
    }

    It 'fails clearly when a definition still uses requireManagedOwnership' {
        $rootPath = Join-Path $TestDrive 'retired-require-managed-ownership'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0') -SharedOwnershipPolicy @{
            allowAdoptExternal    = $false
            upgradeAdoptedInstall = $false
            requireManagedOwnership = $false
        }
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument $definitionDocument

        $definitionInfo = Read-PackageJsonDocument -Path $documents.DefinitionPath
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*requireManagedOwnership*'
    }

    It 'fails clearly when npm install definitions use retired managerDependency fields' {
        $release = New-TestPackageRelease -Id 'cli-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{
            kind              = 'npmMaterializedInstallGlobalPackage'
            installerCommand  = 'npm'
            packageSpec       = 'example@{version}'
            managerDependency = @{
                definitionId = 'NodeRuntime'
                command      = 'npm'
            }
        } -Readiness (New-TestReadiness -Version '1.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '1.0.0')
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*packageOperations.assigned.install.managerDependency*'
    }

    It 'rejects retired npmGlobalPackage install definitions' {
        $release = New-TestPackageRelease -Id 'cli-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{
            kind             = 'npmGlobalPackage'
            installerCommand = 'npm'
            packageSpec      = 'example@{version}'
            installDirectory = 'example/{releaseTrack}/{version}/{artifactDistributionVariant}'
        } -Readiness (New-TestReadiness -Version '1.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '1.0.0')
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*npmGlobalPackage*'
    }

    It 'fails clearly when a definition is missing schemaVersion' {
        $rootPath = Join-Path $TestDrive 'missing-schema-version'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $null = $definitionDocument.Remove('schemaVersion')
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument $definitionDocument

        $definitionInfo = Read-PackageJsonDocument -Path $documents.DefinitionPath
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*schemaVersion*'
    }

    It 'fails clearly when a definition still uses retired root discovery properties' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)

        $definitionDocument['presenceDiscovery'] = @{ commands = @() }
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*presenceDiscovery*discovery.presence*'

        $null = $definitionDocument.Remove('presenceDiscovery')
        $definitionDocument['existingInstallDiscovery'] = @{ enabled = $false; searchLocations = @(); installRootRules = @() }
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*existingInstallDiscovery*discovery.existingInstall*'
    }

    It 'fails clearly when operations still reference retired discovery paths' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = $null
        }

        $definitionDocument.packageOperations.assigned.readyStateCheck.use = 'presenceDiscovery'
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*readyStateCheck.use*discovery.presence*'

        $definitionDocument.packageOperations.assigned.readyStateCheck.use = 'discovery.presence'
        $definitionDocument.packageOperations.assigned.pathRegistration = @{
            mode   = 'user'
            source = @{
                kind = 'shim'
                use  = 'discovery.presence.commands'
            }
        }
        $definitionDocument.packageOperations.assigned.pathRegistration.source.use = 'presenceDiscovery.commands'
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*pathRegistration.source*discovery.presence.commands*'

        $definitionDocument.packageOperations.assigned.pathRegistration.source.use = 'discovery.presence.commands'
        $definitionDocument.packageOperations.removed.absenceVerification.use = 'presenceDiscovery'
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*absenceVerification.use*discovery.presence*'

        $definitionDocument.packageOperations.removed.absenceVerification.use = 'discovery.presence'
        $definitionDocument.packageOperations.removed.operation = @{
            kind             = 'msiUninstaller'
            commandSource    = @{
                use                = 'existingInstallDiscovery'
                searchLocationId   = 'sevenZipUninstallRegistry'
                registryValueOrder = @('QuietUninstallString', 'UninstallString')
            }
            commandArguments = @('/qn', '/norestart')
            elevation        = 'required'
            timeoutSec       = 600
            successExitCodes = @(0, 1605, 3010)
            restartExitCodes = @(3010)
            uiMode           = 'silent'
        }
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*commandSource.use*discovery.existingInstall*'
    }

    It 'fails clearly when a definition still uses shared.requirements' {
        $rootPath = Join-Path $TestDrive 'retired-requirements-packages'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionDocument.shared = @{
            requirements = @{
                checks = [object[]]@()
            }
        }
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument $definitionDocument

        $definitionInfo = Read-PackageJsonDocument -Path $documents.DefinitionPath
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*shared*'
    }

    It 'fails clearly when a definition still uses retired root packageTargets' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionDocument.packageTargets = @()

        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*packageTargets*'
    }

    It 'fails clearly when a definition still uses retired root versionCatalog' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionDocument.versionCatalog = @()

        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*versionCatalog*'
    }

    It 'fails clearly when a release still uses retired artifactsByTarget' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionDocument.artifacts.releases[0].artifactsByTarget = @{}

        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*artifactsByTarget*'
    }

    It 'fails clearly when an acquisition candidate still uses retired priority' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                priority     = 100
                verification = @{ mode = 'none' }
            }
        )
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*priority*'
    }

    It 'fails clearly when packageFile still uses retired raw-file trust properties' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder  = 100
                verification = @{ mode = 'required' }
            }
        )
        $release.packageFile | Add-Member -NotePropertyName integrity -NotePropertyValue @{
            algorithm = 'sha256'
            sha256    = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
        }
        $release.packageFile | Add-Member -NotePropertyName authenticode -NotePropertyValue @{
            requireValid = $true
        }
        $release.packageFile | Add-Member -NotePropertyName autoUpdateSupported -NotePropertyValue $false
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $artifact = $definitionDocument.artifacts.releases[0].targetArtifacts['vsCode-win-x64-stable']
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*packageFile.autoUpdateSupported*'
        $null = $artifact.Remove('autoUpdateSupported')
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*packageFile.integrity*'
        $null = $artifact.Remove('integrity')
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*packageFile.authenticode*'
    }

    It 'rejects incomplete packageFile.contentHash and publisherSignature metadata' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder  = 100
                verification = @{ mode = 'required' }
            }
        )
        $release.packageFile | Add-Member -NotePropertyName contentHash -NotePropertyValue @{
            algorithm = 'sha256'
        }
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $artifact = $definitionDocument.artifacts.releases[0].targetArtifacts['vsCode-win-x64-stable']
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*packageFile.contentHash without value*'
        $null = $artifact.Remove('contentHash')
        $artifact.contentHash = @{
            algorithm = 'sha256'
            value     = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
        }
        $artifact.publisherSignature = @{
            requireValid = $true
        }
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*packageFile.publisherSignature without kind*'
    }

    It 'filters depot inventory sources by enabled flag and semicolon site-code list' {
        $rootPath = Join-Path $TestDrive 'depot-inventory-sites'
        $depotInventory = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory (Join-Path $rootPath 'default-depot') -EnvironmentSources @{
            disabledDepot = @{
                kind     = 'filesystem'
                enabled  = $false
                searchOrder = 50
                basePath = (Join-Path $rootPath 'disabled')
            }
            departmentDepot = @{
                kind      = 'filesystem'
                enabled   = $true
                searchOrder  = 150
                siteCodes = @('BER-ENG')
                basePath  = (Join-Path $rootPath 'department')
            }
            otherSiteDepot = @{
                kind      = 'filesystem'
                enabled   = $true
                searchOrder  = 100
                siteCodes = @('PD')
                basePath  = (Join-Path $rootPath 'other-site')
            }
            globalDepot = @{
                kind     = 'filesystem'
                enabled  = $true
                searchOrder = 400
                basePath = (Join-Path $rootPath 'global')
            }
        }
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DepotInventoryDocument $depotInventory -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @(
                New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                    @{
                        kind        = 'packageDepot'
                        searchOrder    = 100
                        verification = @{ mode = 'none' }
                    }
                )
            ))
        [Environment]::SetEnvironmentVariable($script:SiteCodeEnvVarName, 'BER;BER-ENG', 'Process')

        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $sourceNames = @($config.EnvironmentSources.PSObject.Properties.Name)
        $depotSources = @(Get-PackagePackageDepotSources -PackageConfig $config)

        $sourceNames | Should -Contain 'defaultPackageDepot'
        $sourceNames | Should -Contain 'departmentDepot'
        $sourceNames | Should -Contain 'globalDepot'
        $sourceNames | Should -Not -Contain 'disabledDepot'
        $sourceNames | Should -Not -Contain 'otherSiteDepot'
        @($depotSources.id) | Should -Be @('departmentDepot', 'defaultPackageDepot', 'globalDepot')
    }

    It 'rejects a selected release when compatibility.checks are not satisfied with onFail fail' {
        $rootPath = Join-Path $TestDrive 'requirements-checks-fail'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Compatibility @{
            checks = @(
                @{
                    kind    = 'osFamily'
                    allowed = @('linux')
                }
            )
        } -Readiness (New-TestReadiness -Version '2.0.0')
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config

        { Resolve-PackagePackage -PackageResult $result } | Should -Throw '*compatibility.checks*'
    }

    It 'resolves environment and definition source refs from the effective acquisition environment and upstream sources' {
        $rootPath = Join-Path $TestDrive 'source-resolution'
        $depotInventory = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory (Join-Path $rootPath 'default-depot') -EnvironmentSources @{
            remotePackageDepot = @{
                kind        = 'filesystem'
                searchOrder = 150
                basePath    = (Join-Path $TestDrive 'remote-depot')
            }
        }
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DepotInventoryDocument $depotInventory -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @(
                New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
            ) -UpstreamBaseUri 'https://example.invalid/vscode/')
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $environmentSource = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'environment'; id = 'remotePackageDepot' })
        $definitionSource = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'vsCodeUpdateService' })

        $environmentSource.Kind | Should -Be 'filesystem'
        $environmentSource.BasePath | Should -Be (Join-Path $TestDrive 'remote-depot')
        $definitionSource.Kind | Should -Be 'download'
        $definitionSource.BaseUri | Should -Be 'https://example.invalid/vscode/'
    }

    It 'loads GitHub release upstream sources and keeps releaseTag separate from version' {
        $rootPath = Join-Path $TestDrive 'github-release-source'
        $release = New-TestPackageRelease -Id 'llama-cpu-x64-stable' -Version '0.0.1' -ReleaseTag 'b8863' -Architecture 'x64' -ArtifactDistributionVariant 'win-cpu-x64' -FileName 'llama-b8863-bin-win-cpu-x64.zip' -AcquisitionCandidates @(
            @{
                kind         = 'download'
                sourceId     = 'llamaCppGitHub'
                searchOrder     = 100
                verification = @{ mode = 'required' }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '0.0.1') -UpstreamSources @{
            llamaCppGitHub = @{
                kind            = 'githubRelease'
                githubOwner      = 'ggml-org'
                githubRepository = 'llama.cpp'
            }
        })
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $definitionSource = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'llamaCppGitHub' })

        $definitionSource.Kind | Should -Be 'githubRelease'
        $definitionSource.GitHubOwner | Should -Be 'ggml-org'
        $definitionSource.GitHubRepository | Should -Be 'llama.cpp'
        $result.Package.version | Should -Be '0.0.1'
        $result.Package.releaseTag | Should -Be 'b8863'
    }

    It 'requires releaseTag for GitHub-backed releases' {
        $rootPath = Join-Path $TestDrive 'github-release-tag-required'
        $release = New-TestPackageRelease -Id 'llama-cpu-x64-stable' -Version '0.0.1' -Architecture 'x64' -ArtifactDistributionVariant 'win-cpu-x64' -FileName 'llama-b8863-bin-win-cpu-x64.zip' -AcquisitionCandidates @(
            @{
                kind         = 'download'
                sourceId     = 'llamaCppGitHub'
                searchOrder     = 100
                verification = @{ mode = 'required' }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '0.0.1') -UpstreamSources @{
            llamaCppGitHub = @{
                kind            = 'githubRelease'
                githubOwner      = 'ggml-org'
                githubRepository = 'llama.cpp'
            }
        })
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        { Get-PackageConfig -DefinitionId 'VSCodeRuntime' } | Should -Throw '*requires releaseTag*'
    }

    It 'resolves a GitHub release asset URL from releaseTag and packageFile.fileName' {
        $rootPath = Join-Path $TestDrive 'github-release-resolve'
        $release = New-TestPackageRelease -Id 'llama-cpu-x64-stable' -Version '0.0.1' -ReleaseTag 'b8863' -Architecture 'x64' -ArtifactDistributionVariant 'win-cpu-x64' -FileName 'llama-b8863-bin-win-cpu-x64.zip' -AcquisitionCandidates @(
            @{
                kind         = 'download'
                sourceId     = 'llamaCppGitHub'
                searchOrder     = 100
                verification = @{ mode = 'required' }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '0.0.1') -UpstreamSources @{
            llamaCppGitHub = @{
                kind            = 'githubRelease'
                githubOwner      = 'ggml-org'
                githubRepository = 'llama.cpp'
            }
        })
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }
        Mock Get-GitHubRelease {
            [pscustomobject]@{
                RepositoryOwner = 'ggml-org'
                RepositoryName  = 'llama.cpp'
                ReleaseTag      = 'b8863'
                Assets          = @(
                    [pscustomobject]@{
                        Name        = 'llama-b8863-bin-win-cpu-x64.zip'
                        DownloadUrl = 'https://example.invalid/ggml-org/llama.cpp/releases/download/b8863/llama-b8863-bin-win-cpu-x64.zip'
                    }
                )
            }
        }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'llamaCppGitHub' })
        $resolvedSource = Resolve-PackageSource -SourceDefinition $sourceDefinition -AcquisitionCandidate $result.Package.acquisitionCandidates[0] -Package $result.Package

        $resolvedSource.Kind | Should -Be 'download'
        $resolvedSource.ResolvedSource | Should -Be 'https://example.invalid/ggml-org/llama.cpp/releases/download/b8863/llama-b8863-bin-win-cpu-x64.zip'
        Assert-MockCalled Get-GitHubRelease -Times 1 -Exactly
    }

    It 'fails clearly when a GitHub release tag cannot be resolved' {
        Mock Invoke-WebRequestEx { throw '404 Not Found' }

        { Get-GitHubRelease -RepositoryOwner 'ggml-org' -RepositoryName 'llama.cpp' -ReleaseTag 'b9999' } | Should -Throw "*repository 'ggml-org/llama.cpp'*release tag 'b9999'*"
    }

    It 'normalizes GitHub release API metadata and assets' {
        $responseBody = @{
            id           = 42
            tag_name     = 'b8863'
            name         = 'b8863'
            html_url     = 'https://github.com/ggml-org/llama.cpp/releases/tag/b8863'
            published_at = '2026-04-20T23:54:06Z'
            draft        = $false
            prerelease   = $false
            immutable    = $false
            assets       = @(
                @{
                    id                   = 99
                    name                 = 'llama-b8863-bin-win-cpu-x64.zip'
                    browser_download_url = 'https://example.invalid/llama-b8863-bin-win-cpu-x64.zip'
                    content_type         = 'application/zip'
                    size                 = 12345
                    digest               = 'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
                    created_at           = '2026-04-20T23:54:06Z'
                    updated_at           = '2026-04-20T23:54:06Z'
                }
            )
        } | ConvertTo-Json -Depth 10

        Mock Invoke-WebRequestEx {
            [pscustomobject]@{
                Content = $responseBody
            }
        }

        $release = Get-GitHubRelease -RepositoryOwner 'ggml-org' -RepositoryName 'llama.cpp' -ReleaseTag 'b8863'

        $release.ReleaseId | Should -Be '42'
        $release.ReleaseTag | Should -Be 'b8863'
        $release.RepositoryOwner | Should -Be 'ggml-org'
        $release.RepositoryName | Should -Be 'llama.cpp'
        $release.Assets.Count | Should -Be 1
        $release.Assets[0].Name | Should -Be 'llama-b8863-bin-win-cpu-x64.zip'
        $release.Assets[0].DownloadUrl | Should -Be 'https://example.invalid/llama-b8863-bin-win-cpu-x64.zip'
        $release.Assets[0].Sha256 | Should -Be '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
    }

    It 'fails clearly when the GitHub release asset is missing' {
        $sourceDefinition = [pscustomobject]@{
            Scope           = 'definition'
            Id              = 'llamaCppGitHub'
            Kind            = 'githubRelease'
            GitHubOwner      = 'ggml-org'
            GitHubRepository = 'llama.cpp'
        }
        $package = ConvertTo-TestPsObject @{
            id         = 'llama-cpu-x64-stable'
            releaseTag = 'b8863'
            packageFile = @{
                fileName = 'llama-b8863-bin-win-cpu-x64.zip'
            }
        }
        $candidate = ConvertTo-TestPsObject @{
            kind     = 'download'
            sourceId = 'llamaCppGitHub'
        }

        Mock Get-GitHubRelease {
            [pscustomobject]@{
                RepositoryOwner = 'ggml-org'
                RepositoryName  = 'llama.cpp'
                ReleaseTag      = 'b8863'
                Assets          = @(
                    [pscustomobject]@{
                        Name        = 'llama-b8863-bin-win-cuda-12.4-x64.zip'
                        DownloadUrl = 'https://example.invalid/other.zip'
                    }
                )
            }
        }

        { Resolve-PackageSource -SourceDefinition $sourceDefinition -AcquisitionCandidate $candidate -Package $package } | Should -Throw '*does not contain asset*llama-b8863-bin-win-cpu-x64.zip*'
    }

    It 'builds an effective release from shared defaults and uses ReleaseTrack in path resolution' {
        $rootPath = Join-Path $TestDrive 'effective-release'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind        = 'packageDepot'
                searchOrder    = 10
                verification = @{ mode = 'optional'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -ReleaseTrack 'stable') -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result

        $result.EffectiveRelease | Should -Not -BeNullOrEmpty
        $result.Package.assigned.install.kind | Should -Be 'expandArchive'
        $result.Package.readiness.commandChecks[0].expectedValue | Should -Be '{version}'
        $result.PackageWorkSlotDirectory | Should -Match '^VSCodeRuntime-[0-9a-f]{8}$'
        $result.PackageFilePath | Should -Match '\\FileStage\\VSCodeRuntime-[0-9a-f]{8}\\'
        $result.PackageInstallStageDirectory | Should -Match '\\InstStage\\VSCodeRuntime-[0-9a-f]{8}$'
        (Split-Path -Leaf $result.PackageFileStagingDirectory) | Should -Be (Split-Path -Leaf $result.PackageInstallStageDirectory)
        $result.PackageDepotRelativeDirectory | Should -Be 'VSCodeRuntime\stable\2.0.0\win32-x64'
        $result.DefaultPackageDepotFilePath | Should -Match '\\stable\\2\.0\.0\\win32-x64\\'
    }

    It 'writes resolved paths as separate console lines' {
        $rootPath = Join-Path $TestDrive 'resolved-path-lines'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder     = 10
                verification = @{ mode = 'none' }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $messages = New-Object System.Collections.Generic.List[string]
        Mock Write-StandardMessage {
            param([string]$Message, [string]$Level)
            $messages.Add($Message) | Out-Null
        }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $null = Resolve-PackagePaths -PackageResult $result

        @($messages) | Should -Contain '[STATE] Resolved paths:'
        @($messages | Where-Object { $_.StartsWith('[PATH] Package file staging:') }).Count | Should -Be 1
        @($messages | Where-Object { $_.StartsWith('[PATH] Package install stage:') }).Count | Should -Be 1
        @($messages | Where-Object { $_.StartsWith('[PATH] Target install directory:') }).Count | Should -Be 1
        @($messages | Where-Object { $_.StartsWith('[PATH] Package file:') }).Count | Should -Be 1
        @($messages | Where-Object { $_.StartsWith('[PATH] Default package depot file:') }).Count | Should -Be 1
    }

}
