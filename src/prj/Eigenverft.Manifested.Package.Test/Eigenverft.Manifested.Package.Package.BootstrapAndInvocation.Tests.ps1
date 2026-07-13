<#
    Eigenverft.Manifested.Package Package - bootstrap and invocation
#>

. "$PSScriptRoot\\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - bootstrap and invocation' -Body {

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

    It 'evaluates dependency versionRange comparator terms' {
        Test-PackageVersionRange -VersionText '1.5.0' -VersionRange '>=1.0.0 <2.0.0' | Should -BeTrue
        Test-PackageVersionRange -VersionText '2.0.0' -VersionRange '>=1.0.0 <2.0.0' | Should -BeFalse
        Test-PackageVersionRange -VersionText '1.14.46' -VersionRange '1.14.46' | Should -BeTrue
        Test-PackageVersionRange -VersionText '1.14.47' -VersionRange '1.14.46' | Should -BeFalse
        { Resolve-PackageVersionRangeTerms -VersionRange '^1.0.0' } | Should -Throw '*Unsupported Package versionRange term*'
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

    It 'passes Offline and MaterializeOnly command mode through Invoke-Package' {
        Mock Invoke-PackageDefinitionCommandCore {
            [pscustomobject]@{
                DefinitionId     = $DefinitionId
                DesiredState     = $DesiredState
                CommandMode      = if ($MaterializeOnly) { 'MaterializeOnly' } else { $DesiredState }
                Offline          = [bool]$Offline
                MaterializeOnly  = [bool]$MaterializeOnly
                Status           = if ($MaterializeOnly) { 'Materialized' } else { 'Ready' }
            }
        }

        $result = Invoke-Package -DefinitionId 'OpenCodeCli' -Offline -MaterializeOnly

        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter {
            $DefinitionId -eq 'OpenCodeCli' -and
            $DesiredState -eq 'Assigned' -and
            [bool]$Offline -and
            [bool]$MaterializeOnly
        }
        $result.Status | Should -Be 'Materialized'
        $result.Offline | Should -BeTrue
    }

    It 'rejects MaterializeOnly when DesiredState is explicitly set' {
        { Invoke-Package -DefinitionId 'OpenCodeCli' -MaterializeOnly -DesiredState Assigned } | Should -Throw '*MaterializeOnly*DesiredState*'
        { Invoke-Package -DefinitionId 'OpenCodeCli' -MaterializeOnly -DesiredState Removed } | Should -Throw '*MaterializeOnly*DesiredState*'
    }

    It 'runs materialize-only flow without assignment, readiness, PATH, or inventory effects' {
        $packageResult = [pscustomobject]@{
            DefinitionPublisherId  = 'Eigenverft'
            DefinitionEndpointName  = 'test'
            DefinitionId            = 'OpenCodeCli'
            DesiredState            = 'Assigned'
            CommandMode             = 'MaterializeOnly'
            Offline                 = $false
            MaterializeOnly         = $true
            PackageConfig           = [pscustomobject]@{}
            LocalEnvironment        = [pscustomobject]@{ Status = 'Initialized' }
            Dependencies            = @()
            Status                  = 'Pending'
            ErrorMessage            = $null
            FailureReason           = $null
            CurrentStep             = 'Pending'
        }

        Mock Resolve-PackagePackage {
            $PackageResult | Add-Member -MemberType NoteProperty -Name PackageId -Value 'opencode-runtime' -Force
            $PackageResult | Add-Member -MemberType NoteProperty -Name Package -Value ([pscustomobject]@{ id = 'opencode-runtime' }) -Force
            $PackageResult
        }
        Mock Resolve-PackageDependencies { $PackageResult }
        Mock Resolve-PackagePaths { $PackageResult }
        Mock Build-PackageAcquisitionPlan { $PackageResult }
        Mock Resolve-PackageInstallFile {
            $PackageResult | Add-Member -MemberType NoteProperty -Name PackageFilePreparation -Value ([pscustomobject]@{ Success = $true; Status = 'Skipped'; ErrorMessage = $null }) -Force
            $PackageResult
        }
        Mock Invoke-PackageDepotDistribution { $PackageResult }
        Mock Invoke-PackageNpmMaterialization { $PackageResult }
        Mock Assert-PackageMaterializationDurable {
            $PackageResult | Add-Member -MemberType NoteProperty -Name Materialization -Value ([pscustomobject]@{ Success = $true; Status = 'Durable' }) -Force
            $PackageResult
        }
        Mock Clear-PackageWorkDirectories { $PackageResult }
        Mock Set-PackageAssignedState { throw 'assign should not run in materialize-only mode' }
        Mock Test-PackageAssignedReadiness { throw 'readiness should not run in materialize-only mode' }
        Mock Register-PackagePath { throw 'path registration should not run in materialize-only mode' }
        Mock Update-PackageInventoryRecord { throw 'inventory should not run in materialize-only mode' }

        $result = Invoke-PackageMaterializeOnlyFlow -PackageResult $packageResult
        $completed = Complete-PackageResult -PackageResult $result

        $completed.Status | Should -Be 'Materialized'
        Assert-MockCalled Set-PackageAssignedState -Times 0
        Assert-MockCalled Test-PackageAssignedReadiness -Times 0
        Assert-MockCalled Register-PackagePath -Times 0
        Assert-MockCalled Update-PackageInventoryRecord -Times 0
    }

    It 'continues assigned flow after dependency resolution returns the parent result' {
        $packageResult = [pscustomobject]@{
            DefinitionPublisherId = 'Eigenverft'
            DefinitionEndpointName = 'test'
            DefinitionId           = 'RootA'
            DesiredState           = 'Assigned'
            CommandMode            = 'Assigned'
            Offline                = $false
            MaterializeOnly        = $false
            PackageConfig          = [pscustomobject]@{
                Definition = [pscustomobject]@{
                    definitionId = 'RootA'
                }
            }
            LocalEnvironment       = [pscustomobject]@{ Status = 'Initialized' }
            Dependencies           = @()
            Status                 = 'Pending'
            ErrorMessage           = $null
            FailureReason          = $null
            CurrentStep            = 'Pending'
        }
        $stepOrder = New-Object System.Collections.Generic.List[string]

        Mock Resolve-PackagePackage {
            $stepOrder.Add('ResolvePackage') | Out-Null
            $PackageResult | Add-Member -MemberType NoteProperty -Name PackageId -Value 'root-a-runtime' -Force
            $PackageResult | Add-Member -MemberType NoteProperty -Name Package -Value ([pscustomobject]@{ id = 'root-a-runtime' }) -Force
            $PackageResult
        }
        Mock Resolve-PackageDependencies {
            $stepOrder.Add('ResolveDependencies') | Out-Null
            $PackageResult.Dependencies = @(
                [pscustomobject]@{ DefinitionId = 'VisualRuntime'; Status = 'Ready' }
                [pscustomobject]@{ DefinitionId = 'NodeRuntime'; Status = 'Ready' }
            )
            $PackageResult
        }
        Mock Resolve-PackagePaths { $stepOrder.Add('ResolvePaths') | Out-Null; $PackageResult }
        Mock Resolve-PackagePreAssignmentSatisfaction { $stepOrder.Add('ResolvePreAssignmentSatisfaction') | Out-Null; $PackageResult }
        Mock Build-PackageAcquisitionPlan { $stepOrder.Add('BuildAcquisitionPlan') | Out-Null; $PackageResult }
        Mock Find-PackageExistingPackage { $stepOrder.Add('FindExistingPackage') | Out-Null; $PackageResult }
        Mock Set-PackageExistingPackage { $stepOrder.Add('ClassifyExistingPackage') | Out-Null; $PackageResult }
        Mock Resolve-PackageExistingPackageDecision { $stepOrder.Add('ResolveExistingPackageDecision') | Out-Null; $PackageResult }
        Mock Resolve-PackageInstallFile { $stepOrder.Add('PreparePackageAssignedFile') | Out-Null; $PackageResult }
        Mock Invoke-PackageDepotDistribution { $stepOrder.Add('DistributePackageFileToDepots') | Out-Null; $PackageResult }
        Mock Invoke-PackageNpmMaterialization { $stepOrder.Add('MaterializeNpmPackage') | Out-Null; $PackageResult }
        Mock Set-PackageAssignedState {
            $stepOrder.Add('AssignPackage') | Out-Null
            $PackageResult | Add-Member -MemberType NoteProperty -Name Assigned -Value ([pscustomobject]@{ Status = 'ReusedPackageOwned' }) -Force
            $PackageResult | Add-Member -MemberType NoteProperty -Name InstallOrigin -Value 'PackageReused' -Force
            $PackageResult
        }
        Mock Test-PackageAssignedReadiness {
            $stepOrder.Add('CheckAssignedReadiness') | Out-Null
            $PackageResult | Add-Member -MemberType NoteProperty -Name Readiness -Value ([pscustomobject]@{ Accepted = $true }) -Force
            $PackageResult
        }
        Mock Register-PackagePath { $stepOrder.Add('RegisterPath') | Out-Null; $PackageResult }
        Mock Remove-PackageReplacedPackageOwnedInstallDirectory { $PackageResult }
        Mock Resolve-PackageEntryPoints { $stepOrder.Add('ResolveEntryPoints') | Out-Null; $PackageResult }
        Mock Update-PackageInventoryRecord { $stepOrder.Add('UpdateInventory') | Out-Null; $PackageResult }
        Mock Clear-PackageWorkDirectories { $stepOrder.Add('ClearPackageWorkDirectories') | Out-Null; $PackageResult }
        Mock Get-PackageOutcomeSummary { '[OK] test package completed.' }

        $result = Invoke-PackageAssignedFlow -PackageResult $packageResult

        $result.DefinitionId | Should -Be 'RootA'
        @($result.Dependencies.DefinitionId) | Should -Be @('VisualRuntime', 'NodeRuntime')
        $stepOrder.IndexOf('ResolveDependencies') | Should -BeLessThan $stepOrder.IndexOf('AssignPackage')
        $stepOrder.IndexOf('AssignPackage') | Should -BeGreaterThan -1
        Assert-MockCalled Set-PackageAssignedState -Times 1
        Assert-MockCalled Update-PackageInventoryRecord -Times 1
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

    It 'returns failed root results without execution when multi-root dependency planning fails' {
        $failedPlan = [pscustomobject]@{
            Accepted   = $false
            Status     = 'Failed'
            Roots      = @(
                [pscustomobject]@{ RequestedPublisherId = $null; RequestedDefinitionId = 'RootA'; PublisherId = $null; DefinitionId = 'RootA'; NodeKey = $null; PackageConfig = $null }
                [pscustomobject]@{ RequestedPublisherId = $null; RequestedDefinitionId = 'RootB'; PublisherId = $null; DefinitionId = 'RootB'; NodeKey = $null; PackageConfig = $null }
            )
            Nodes      = @()
            Edges      = @()
            Violations = @(
                New-PackageDependencyPlanViolation -Reason 'DependencyConflict' -Message 'planned conflict' -RootDefinitionId 'RootA' -DefinitionId 'RootB'
            )
        }
        Mock New-PackageDependencyPlan { $failedPlan }
        Mock Invoke-PackageDefinitionCommandCore { throw 'execution should not run' }

        $results = @(Invoke-Package -DefinitionId RootA, RootB)

        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 0
        @($results.DefinitionId) | Should -Be @('RootA', 'RootB')
        @($results.Status) | Should -Be @('Failed', 'Failed')
        @($results.FailureReason) | Should -Be @('PackageDependencyPlanFailed', 'PackageDependencyPlanFailed')
        @($results.CurrentStep) | Should -Be @('PlanDependencies', 'PlanDependencies')
    }

    It 'passes approved dependency plan root context while preserving Invoke-Package array order' {
        $approvedPlan = [pscustomobject]@{
            Accepted   = $true
            Status     = 'Approved'
            Roots      = @(
                [pscustomobject]@{ RequestedPublisherId = $null; RequestedDefinitionId = 'RootA'; PublisherId = 'Eigenverft'; DefinitionId = 'RootA'; NodeKey = 'Eigenverft:RootA'; PackageConfig = $null }
                [pscustomobject]@{ RequestedPublisherId = $null; RequestedDefinitionId = 'RootB'; PublisherId = 'Eigenverft'; DefinitionId = 'RootB'; NodeKey = 'Eigenverft:RootB'; PackageConfig = $null }
            )
            Nodes      = @([pscustomobject]@{ NodeKey = 'Eigenverft:RootA' }, [pscustomobject]@{ NodeKey = 'Eigenverft:RootB' })
            Edges      = @()
            Violations = @()
        }
        Mock New-PackageDependencyPlan { $approvedPlan }
        Mock Invoke-PackageDefinitionCommandCore {
            [pscustomobject]@{
                PublisherId            = $PublisherId
                DefinitionId           = $DefinitionId
                DependencyPlanNodeKey  = $DependencyPlanNodeKey
                DesiredState           = $DesiredState
                Status                 = 'Ready'
            }
        }

        $results = @(Invoke-Package -DefinitionId RootA, RootB)

        @($results.DefinitionId) | Should -Be @('RootA', 'RootB')
        @($results.DependencyPlanNodeKey) | Should -Be @('Eigenverft:RootA', 'Eigenverft:RootB')
        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter { $DefinitionId -eq 'RootA' -and $DependencyPlan -eq $approvedPlan -and $DependencyPlanNodeKey -eq 'Eigenverft:RootA' }
        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter { $DefinitionId -eq 'RootB' -and $DependencyPlan -eq $approvedPlan -and $DependencyPlanNodeKey -eq 'Eigenverft:RootB' }
    }

    It 'uses the approved dependency plan for MaterializeOnly invokes' {
        $approvedPlan = [pscustomobject]@{
            Accepted   = $true
            Status     = 'Approved'
            Roots      = @([pscustomobject]@{ RequestedPublisherId = $null; RequestedDefinitionId = 'RootA'; PublisherId = 'Eigenverft'; DefinitionId = 'RootA'; NodeKey = 'Eigenverft:RootA'; PackageConfig = $null })
            Nodes      = @([pscustomobject]@{ NodeKey = 'Eigenverft:RootA' })
            Edges      = @()
            Violations = @()
        }
        Mock New-PackageDependencyPlan { $approvedPlan }
        Mock Invoke-PackageDefinitionCommandCore {
            [pscustomobject]@{
                DefinitionId          = $DefinitionId
                CommandMode           = if ($MaterializeOnly) { 'MaterializeOnly' } else { $DesiredState }
                DependencyPlanNodeKey = $DependencyPlanNodeKey
                Status                = 'Materialized'
            }
        }

        $result = Invoke-Package -DefinitionId RootA -MaterializeOnly

        $result.Status | Should -Be 'Materialized'
        $result.DependencyPlanNodeKey | Should -Be 'Eigenverft:RootA'
        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter { [bool]$MaterializeOnly -and $DependencyPlan -eq $approvedPlan }
    }

}
