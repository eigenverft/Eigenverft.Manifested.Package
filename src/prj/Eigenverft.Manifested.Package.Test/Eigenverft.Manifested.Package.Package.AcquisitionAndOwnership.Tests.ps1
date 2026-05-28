<#
    Eigenverft.Manifested.Package Package - acquisition and ownership
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - acquisition and ownership' -Body {
    It 'resolves installRootRules for code.cmd and Code.exe' {
        $installRoot = Join-Path $TestDrive 'existing-root'
        $binDirectory = Join-Path $installRoot 'bin'
        $null = New-Item -ItemType Directory -Path $binDirectory -Force
        $codeCmdPath = Join-Path $binDirectory 'code.cmd'
        $codeExePath = Join-Path $installRoot 'Code.exe'
        Write-TestTextFile -Path $codeCmdPath -Content '@echo off'
        Write-TestTextFile -Path $codeExePath -Content 'fake'

        $existingInstallDiscovery = ConvertTo-TestPsObject @{
            enabled = $true
            searchLocations = @()
            installRootRules = @(
                @{
                    match = @{
                        kind  = 'fileName'
                        value = 'code.cmd'
                    }
                    installRootRelativePath = '..'
                },
                @{
                    match = @{
                        kind  = 'fileName'
                        value = 'Code.exe'
                    }
                    installRootRelativePath = '.'
                }
            )
        }

        (Resolve-PackageExistingInstallRoot -DiscoveryExistingInstall $existingInstallDiscovery -CandidatePath $codeCmdPath) | Should -Be $installRoot
        (Resolve-PackageExistingInstallRoot -DiscoveryExistingInstall $existingInstallDiscovery -CandidatePath $codeExePath) | Should -Be $installRoot
    }

    It 'keeps packageFileStaging and defaultPackageDepot distinct in the resolved paths' {
        $rootPath = Join-Path $TestDrive 'distinct-roots'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind        = 'packageDepot'
                searchOrder    = 10
                verification = @{ mode = 'optional'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            }
        )
        $globalDocument = New-TestPackageGlobalDocument -PackageFileStagingDirectory (Join-Path $rootPath 'workspace')
        $depotInventoryDocument = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory (Join-Path $rootPath 'default-depot')
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DepotInventoryDocument $depotInventoryDocument -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result

        $result.PackageFileStagingDirectory | Should -Not -Be $config.DefaultPackageDepotDirectory
        $result.PackageFilePath | Should -Not -Be $result.DefaultPackageDepotFilePath
        Split-Path -Parent $result.DefaultPackageDepotFilePath | Should -Match 'default-depot'
    }

    It 'verifies package files with sha512 content hashes' {
        $packagePath = Join-Path $TestDrive 'sha512-verification\package.zip'
        Write-TestTextFile -Path $packagePath -Content 'sha512 package content'
        $sha512 = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA512).Hash.ToLowerInvariant()

        $verification = Test-PackageSavedFile -Path $packagePath -Verification ([pscustomobject]@{
                mode      = 'required'
                algorithm = 'sha512'
                sha512    = $sha512
            })

        $verification.Status | Should -Be 'VerificationPassed'
        $verification.Accepted | Should -BeTrue
        $verification.Algorithm | Should -Be 'sha512'
        $verification.ExpectedHash | Should -Be $sha512
        $verification.ActualHash | Should -Be $sha512
    }

    It 'hydrates the package file staging from the default package depot before upstream download' {
        $rootPath = Join-Path $TestDrive 'default-depot-hydration'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0' -ArchiveFileName 'VSCode-win32-x64-2.0.0.zip'
        $globalDocument = New-TestPackageGlobalDocument -PackageFileStagingDirectory (Join-Path $rootPath 'workspace') -DefaultPackageDepotDirectory (Join-Path $rootPath 'default-depot')
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind        = 'packageDepot'
                searchOrder    = 10
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            },
            @{
                kind        = 'download'
                sourceId    = 'vsCodeUpdateService'
                searchOrder    = 100
                sourcePath  = '2.0.0/win32-x64-archive/stable'
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }
        Mock Save-PackageDownloadFile { throw 'download should not run when the default package depot already has a verified artifact' }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result

        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $result.DefaultPackageDepotFilePath) -Force
        Copy-Item -LiteralPath $packageArchive.ZipPath -Destination $result.DefaultPackageDepotFilePath -Force

        $result = Resolve-PackageInstallFile -PackageResult $result

        $result.PackageFilePreparation.Success | Should -BeTrue
        $result.PackageFilePreparation.Status | Should -Be 'HydratedFromDefaultPackageDepot'
        Test-Path -LiteralPath $result.PackageFilePath | Should -BeTrue
        (Get-FileHash -LiteralPath $result.PackageFilePath -Algorithm SHA256).Hash.ToLowerInvariant() | Should -Be $packageArchive.Sha256
        Assert-MockCalled Save-PackageDownloadFile -Times 0
    }

    It 'hydrates from a read-only default package depot without trying to create or mirror into it' {
        $rootPath = Join-Path $TestDrive 'readonly-default-depot-hydration'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0' -ArchiveFileName 'VSCode-win32-x64-2.0.0.zip'
        $defaultDepotPath = Join-Path $rootPath 'readonly-default-depot'
        $globalDocument = New-TestPackageGlobalDocument -PackageFileStagingDirectory (Join-Path $rootPath 'workspace')
        $depotInventoryDocument = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory $defaultDepotPath
        $depotInventoryDocument.acquisitionEnvironment.environmentSources.defaultPackageDepot.writable = $false
        $depotInventoryDocument.acquisitionEnvironment.environmentSources.defaultPackageDepot.mirrorTarget = $false
        $depotInventoryDocument.acquisitionEnvironment.environmentSources.defaultPackageDepot.ensureExists = $false
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder  = 10
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            },
            @{
                kind         = 'download'
                sourceId     = 'vsCodeUpdateService'
                searchOrder  = 100
                sourcePath   = '2.0.0/win32-x64-archive/stable'
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DepotInventoryDocument $depotInventoryDocument -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }
        Mock Save-PackageDownloadFile { throw 'download should not run when a readable package depot already has a verified artifact' }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result

        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $result.DefaultPackageDepotFilePath) -Force
        Copy-Item -LiteralPath $packageArchive.ZipPath -Destination $result.DefaultPackageDepotFilePath -Force

        $result = Resolve-PackageInstallFile -PackageResult $result

        $result.PackageFilePreparation.Success | Should -BeTrue
        $result.PackageFilePreparation.Status | Should -Be 'HydratedFromDefaultPackageDepot'
        Test-Path -LiteralPath $result.PackageFilePath | Should -BeTrue
        Assert-MockCalled Save-PackageDownloadFile -Times 0
    }

    It 'uses only depot candidates in Offline mode and skips vendorDownload' {
        $rootPath = Join-Path $TestDrive 'offline-depot-hit'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0' -ArchiveFileName 'VSCode-win32-x64-2.0.0.zip'
        $globalDocument = New-TestPackageGlobalDocument -PackageFileStagingDirectory (Join-Path $rootPath 'workspace') -DefaultPackageDepotDirectory (Join-Path $rootPath 'default-depot')
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder  = 10
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            },
            @{
                kind         = 'vendorDownload'
                sourceId     = 'vsCodeUpdateService'
                sourcePath   = '2.0.0/win32-x64-archive/stable'
                searchOrder  = 100
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            }
        )
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument.schemaVersion = '1.8'
        $definitionDocument.definitionPublication.definitionSignature = @{
            kind          = 'unsigned'
            format        = 'embedded-json-rsa-sha256-v1'
            signedContent = 'canonicalDefinitionExcludingSignatureValue'
        }
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }
        Mock Save-PackageDownloadFile { throw 'vendor download should not run in Offline mode' }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config -Offline
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result

        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $result.DefaultPackageDepotFilePath) -Force
        Copy-Item -LiteralPath $packageArchive.ZipPath -Destination $result.DefaultPackageDepotFilePath -Force

        $result = Resolve-PackageInstallFile -PackageResult $result

        @($result.AcquisitionPlan.Candidates | ForEach-Object { $_.kind }) | Should -Be @('packageDepot')
        $result.AcquisitionPlan.SkippedOfflineVendorCandidateCount | Should -Be 1
        $result.PackageFilePreparation.Status | Should -Be 'HydratedFromDefaultPackageDepot'
        Assert-MockCalled Save-PackageDownloadFile -Times 0
    }

    It 'fails closed on Offline depot misses and does not accept package-file staging as a source' {
        $rootPath = Join-Path $TestDrive 'offline-depot-miss'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0' -ArchiveFileName 'VSCode-win32-x64-2.0.0.zip'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder  = 10
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            },
            @{
                kind         = 'download'
                sourceId     = 'vsCodeUpdateService'
                sourcePath   = '2.0.0/win32-x64-archive/stable'
                searchOrder  = 100
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            },
            @{
                kind         = 'filesystem'
                sourceId     = 'localShare'
                sourcePath   = 'VSCode-win32-x64-2.0.0.zip'
                searchOrder  = 110
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PackageFileStagingDirectory (Join-Path $rootPath 'workspace')) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }
        Mock Save-PackageDownloadFile { throw 'download should not run in Offline mode' }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config -Offline
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result

        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $result.PackageFilePath) -Force
        Copy-Item -LiteralPath $packageArchive.ZipPath -Destination $result.PackageFilePath -Force

        $result = Resolve-PackageInstallFile -PackageResult $result

        @($result.AcquisitionPlan.Candidates | ForEach-Object { $_.kind }) | Should -Be @('packageDepot')
        $result.AcquisitionPlan.SkippedOfflineCandidateCount | Should -Be 2
        $result.PackageFilePreparation.Success | Should -BeFalse
        $result.PackageFilePreparation.FailureReason | Should -Be 'DepotMiss'
        @($result.PackageFilePreparation.Attempts | Where-Object { $_.AttemptType -eq 'ReuseCheck' }).Count | Should -Be 0
        Assert-MockCalled Save-PackageDownloadFile -Times 0
    }

    It 'reconciles a newly added writable mirror depot from an existing depot artifact' {
        $rootPath = Join-Path $TestDrive 'mirror-from-depot'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0' -ArchiveFileName 'VSCode-win32-x64-2.0.0.zip'
        $defaultDepotPath = Join-Path $rootPath 'default-depot'
        $teamDepotPath = Join-Path $rootPath 'team-depot'
        $depotInventoryDocument = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory $defaultDepotPath -EnvironmentSources @{
            teamPackageDepot = @{
                kind         = 'filesystem'
                enabled      = $true
                searchOrder  = 150
                basePath     = $teamDepotPath
                readable     = $true
                writable     = $true
                mirrorTarget = $true
                ensureExists = $true
            }
        }
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder  = 10
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            },
            @{
                kind         = 'download'
                sourceId     = 'vsCodeUpdateService'
                searchOrder  = 100
                sourcePath   = '2.0.0/win32-x64-archive/stable'
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PackageFileStagingDirectory (Join-Path $rootPath 'workspace') -DepotDistributionMode 'packageFocused') -DepotInventoryDocument $depotInventoryDocument -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }
        Mock Save-PackageDownloadFile { throw 'download should not run when a readable depot already has the package file' }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result

        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $result.DefaultPackageDepotFilePath) -Force
        Copy-FileToPath -SourcePath $packageArchive.ZipPath -TargetPath $result.DefaultPackageDepotFilePath -Overwrite | Out-Null
        $teamDepotFilePath = Join-Path (Join-Path $teamDepotPath $result.PackageDepotRelativeDirectory) 'VSCode-win32-x64-2.0.0.zip'

        $result = Resolve-PackageInstallFile -PackageResult $result
        $result = Invoke-PackageDepotDistribution -PackageResult $result

        $result.PackageFilePreparation.Status | Should -Be 'HydratedFromDefaultPackageDepot'
        $result.DepotDistribution.CopiedCount | Should -Be 1
        Test-Path -LiteralPath $teamDepotFilePath -PathType Leaf | Should -BeTrue
        (Get-FileHash -LiteralPath $teamDepotFilePath -Algorithm SHA256).Hash.ToLowerInvariant() | Should -Be $packageArchive.Sha256
        Assert-MockCalled Save-PackageDownloadFile -Times 0
    }

    It 'skips depot distribution when effective package has null packageFile (npm-style artifact)' {
        $result = @{
            Package       = [pscustomobject]@{ packageFile = $null }
            PackageConfig = [pscustomobject]@{
                DepotDistributionMode = 'packageFocused'
                EnvironmentSources    = [pscustomobject]@{}
            }
        }

        { Invoke-PackageDepotDistribution -PackageResult $result } | Should -Not -Throw
        $result.DepotDistribution.Status | Should -Be 'Skipped'
        $result.DepotDistribution.Reason | Should -Be 'PackageFileNotRequired'
    }

    It 'reconciles mirror depots from a verified staging file reuse' {
        $rootPath = Join-Path $TestDrive 'mirror-from-staging'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0' -ArchiveFileName 'VSCode-win32-x64-2.0.0.zip'
        $teamDepotPath = Join-Path $rootPath 'team-depot'
        $depotInventoryDocument = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory (Join-Path $rootPath 'default-depot') -EnvironmentSources @{
            teamPackageDepot = @{
                kind         = 'filesystem'
                enabled      = $true
                searchOrder  = 150
                basePath     = $teamDepotPath
                readable     = $true
                writable     = $true
                mirrorTarget = $true
                ensureExists = $true
            }
        }
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder  = 10
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PackageFileStagingDirectory (Join-Path $rootPath 'workspace') -DepotDistributionMode 'packageFocused') -DepotInventoryDocument $depotInventoryDocument -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result
        $null = New-Item -ItemType Directory -Path $result.PackageFileStagingDirectory -Force
        Copy-FileToPath -SourcePath $packageArchive.ZipPath -TargetPath $result.PackageFilePath -Overwrite | Out-Null
        $teamDepotFilePath = Join-Path (Join-Path $teamDepotPath $result.PackageDepotRelativeDirectory) 'VSCode-win32-x64-2.0.0.zip'
        $defaultDepotFilePath = $result.DefaultPackageDepotFilePath

        $result = Resolve-PackageInstallFile -PackageResult $result
        $result = Invoke-PackageDepotDistribution -PackageResult $result

        $result.PackageFilePreparation.Status | Should -Be 'ReusedPackageFile'
        $result.DepotDistribution.CopiedCount | Should -Be 2
        Test-Path -LiteralPath $teamDepotFilePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $defaultDepotFilePath -PathType Leaf | Should -BeTrue
    }

    It 'reconciles mirror depots during package-owned reuse from readable depots without downloading' {
        $rootPath = Join-Path $TestDrive 'mirror-from-reuse'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0' -ArchiveFileName 'VSCode-win32-x64-2.0.0.zip'
        $defaultDepotPath = Join-Path $rootPath 'default-depot'
        $teamDepotPath = Join-Path $rootPath 'team-depot'
        $depotInventoryDocument = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory $defaultDepotPath -EnvironmentSources @{
            teamPackageDepot = @{
                kind         = 'filesystem'
                enabled      = $true
                searchOrder  = 150
                basePath     = $teamDepotPath
                readable     = $true
                writable     = $true
                mirrorTarget = $true
                ensureExists = $true
            }
        }
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder  = 10
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            },
            @{
                kind         = 'download'
                sourceId     = 'vsCodeUpdateService'
                searchOrder  = 100
                sourcePath   = '2.0.0/win32-x64-archive/stable'
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PackageFileStagingDirectory (Join-Path $rootPath 'workspace') -DepotDistributionMode 'packageFocused') -DepotInventoryDocument $depotInventoryDocument -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }
        Mock Save-PackageDownloadFile { throw 'download should not run to reconcile mirror depots during package-owned reuse' }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $result.DefaultPackageDepotFilePath) -Force
        Copy-FileToPath -SourcePath $packageArchive.ZipPath -TargetPath $result.DefaultPackageDepotFilePath -Overwrite | Out-Null
        $result.ExistingPackage = [pscustomobject]@{ Decision = 'ReusePackageOwned' }
        $teamDepotFilePath = Join-Path (Join-Path $teamDepotPath $result.PackageDepotRelativeDirectory) 'VSCode-win32-x64-2.0.0.zip'

        $result = Resolve-PackageInstallFile -PackageResult $result
        $result = Invoke-PackageDepotDistribution -PackageResult $result

        $result.PackageFilePreparation.Status | Should -Be 'Skipped'
        $result.DepotDistribution.CopiedCount | Should -Be 1
        Test-Path -LiteralPath $teamDepotFilePath -PathType Leaf | Should -BeTrue
        Assert-MockCalled Save-PackageDownloadFile -Times 0
    }

    It 'respects packageFocused and disabled depot distribution modes' {
        $rootPath = Join-Path $TestDrive 'mirror-policy'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0' -ArchiveFileName 'VSCode-win32-x64-2.0.0.zip'
        $teamDepotPath = Join-Path $rootPath 'team-depot'
        $depotInventoryDocument = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory (Join-Path $rootPath 'default-depot') -EnvironmentSources @{
            teamPackageDepot = @{
                kind         = 'filesystem'
                enabled      = $true
                searchOrder  = 150
                basePath     = $teamDepotPath
                readable     = $true
                writable     = $true
                mirrorTarget = $true
                ensureExists = $true
            }
        }
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder  = 10
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PackageFileStagingDirectory (Join-Path $rootPath 'workspace') -DepotDistributionMode 'packageFocused') -DepotInventoryDocument $depotInventoryDocument -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result
        $null = New-Item -ItemType Directory -Path $result.PackageFileStagingDirectory -Force
        Copy-FileToPath -SourcePath $packageArchive.ZipPath -TargetPath $result.PackageFilePath -Overwrite | Out-Null
        $teamDepotFilePath = Join-Path (Join-Path $teamDepotPath $result.PackageDepotRelativeDirectory) 'VSCode-win32-x64-2.0.0.zip'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $teamDepotFilePath) -Force
        Write-TestTextFile -Path $teamDepotFilePath -Content 'stale'

        $result = Resolve-PackageInstallFile -PackageResult $result
        $result = Invoke-PackageDepotDistribution -PackageResult $result

        $result.DepotDistribution.Status | Should -Be 'Planned'
        $teamAction = $result.DepotDistribution.Actions | Where-Object DepotId -EQ 'teamPackageDepot'
        $teamAction.Status | Should -Be 'Skipped'
        $teamAction.Reason | Should -Be 'DifferentTargetPreservedByPackageFocusedPolicy'
        Get-Content -LiteralPath $teamDepotFilePath -Raw | Should -Be 'stale'

        $config.DepotDistributionMode = 'disabled'
        $result.PackageConfig = $config
        $result = Invoke-PackageDepotDistribution -PackageResult $result
        $result.DepotDistribution.Status | Should -Be 'Skipped'
        $result.DepotDistribution.Reason | Should -Be 'DisabledByPolicy'
    }

    It 'skips matching mirror targets and overwrites stale mirror targets' {
        $rootPath = Join-Path $TestDrive 'mirror-current-stale'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0' -ArchiveFileName 'VSCode-win32-x64-2.0.0.zip'
        $currentDepotPath = Join-Path $rootPath 'current-depot'
        $staleDepotPath = Join-Path $rootPath 'stale-depot'
        $depotInventoryDocument = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory (Join-Path $rootPath 'default-depot') -EnvironmentSources @{
            currentPackageDepot = @{
                kind         = 'filesystem'
                enabled      = $true
                searchOrder  = 150
                basePath     = $currentDepotPath
                readable     = $true
                writable     = $true
                mirrorTarget = $true
                ensureExists = $true
            }
            stalePackageDepot = @{
                kind         = 'filesystem'
                enabled      = $true
                searchOrder  = 160
                basePath     = $staleDepotPath
                readable     = $true
                writable     = $true
                mirrorTarget = $true
                ensureExists = $true
            }
        }
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder  = 10
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PackageFileStagingDirectory (Join-Path $rootPath 'workspace') -DepotDistributionMode 'depotFocused') -DepotInventoryDocument $depotInventoryDocument -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result
        $null = New-Item -ItemType Directory -Path $result.PackageFileStagingDirectory -Force
        Copy-FileToPath -SourcePath $packageArchive.ZipPath -TargetPath $result.PackageFilePath -Overwrite | Out-Null
        $currentTarget = Join-Path (Join-Path $currentDepotPath $result.PackageDepotRelativeDirectory) 'VSCode-win32-x64-2.0.0.zip'
        $staleTarget = Join-Path (Join-Path $staleDepotPath $result.PackageDepotRelativeDirectory) 'VSCode-win32-x64-2.0.0.zip'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $currentTarget) -Force
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $staleTarget) -Force
        Copy-FileToPath -SourcePath $packageArchive.ZipPath -TargetPath $currentTarget -Overwrite | Out-Null
        Write-TestTextFile -Path $staleTarget -Content 'stale'

        $result = Resolve-PackageInstallFile -PackageResult $result
        $result = Invoke-PackageDepotDistribution -PackageResult $result

        ($result.DepotDistribution.Actions | Where-Object DepotId -EQ 'currentPackageDepot').Reason | Should -Be 'AlreadyCurrent'
        ($result.DepotDistribution.Actions | Where-Object DepotId -EQ 'stalePackageDepot').Status | Should -Be 'Copied'
        (Get-FileHash -LiteralPath $staleTarget -Algorithm SHA256).Hash.ToLowerInvariant() | Should -Be $packageArchive.Sha256
    }

    It 'uses packageFile.contentHash when acquisition candidates only declare verification mode' {
        $rootPath = Join-Path $TestDrive 'packagefile-contenthash'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0' -ArchiveFileName 'VSCode-win32-x64-2.0.0.zip'
        $globalDocument = New-TestPackageGlobalDocument -PackageFileStagingDirectory (Join-Path $rootPath 'workspace') -DefaultPackageDepotDirectory (Join-Path $rootPath 'default-depot')
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -PackageFileSha256 $packageArchive.Sha256 -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder     = 10
                verification = @{ mode = 'required' }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result

        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $result.DefaultPackageDepotFilePath) -Force
        Copy-Item -LiteralPath $packageArchive.ZipPath -Destination $result.DefaultPackageDepotFilePath -Force

        $result = Resolve-PackageInstallFile -PackageResult $result

        $result.PackageFilePreparation.Success | Should -BeTrue
        $result.PackageFilePreparation.Verification.Status | Should -Be 'VerificationPassed'
        $result.PackageFilePreparation.Verification.ExpectedHash | Should -Be $packageArchive.Sha256
    }

    It 'adopts a valid external install when policy allows it' {
        $rootPath = Join-Path $TestDrive 'adopt-external'
        $installRoot = Join-Path $rootPath 'external-install'
        $binDirectory = Join-Path $installRoot 'bin'
        $null = New-Item -ItemType Directory -Path $binDirectory -Force
        Write-TestTextFile -Path (Join-Path $installRoot 'Code.exe') -Content 'fake'
        Write-TestTextFile -Path (Join-Path $binDirectory 'code.cmd') -Content "@echo off`r`necho 2.0.0`r`n"

        $existingInstallDiscovery = New-TestExistingInstallDiscovery -Enabled $true -SearchLocations @(
            @{ id = 'testAdoptExternalDir'; kind = 'directory'; searchOrder = 100; path = $installRoot }
        ) -InstallRootRules @()
        $policy = New-TestOwnershipPolicy -AllowAdoptExternal $true
        $readiness = New-TestReadiness -Version '2.0.0' -Directories @()
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -ExistingInstallDiscovery $existingInstallDiscovery -OwnershipPolicy $policy -Readiness $readiness
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PackageAssignmentInventoryFilePath (Join-Path $rootPath 'PackageAssignmentInventory.json')) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness $readiness)
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Find-PackageExistingPackage -PackageResult $result
        $result = Set-PackageExistingPackage -PackageResult $result
        $result = Resolve-PackageExistingPackageDecision -PackageResult $result

        $result.ExistingPackage.Decision | Should -Be 'AdoptExternal'
        $result.InstallOrigin | Should -Be 'AdoptedExternal'
    }

    It 'ignores a valid external install when managed ownership is required' {
        $rootPath = Join-Path $TestDrive 'ignore-external'
        $installRoot = Join-Path $rootPath 'external-install'
        $binDirectory = Join-Path $installRoot 'bin'
        $null = New-Item -ItemType Directory -Path $binDirectory -Force
        Write-TestTextFile -Path (Join-Path $installRoot 'Code.exe') -Content 'fake'
        Write-TestTextFile -Path (Join-Path $binDirectory 'code.cmd') -Content "@echo off`r`necho 2.0.0`r`n"

        $existingInstallDiscovery = New-TestExistingInstallDiscovery -Enabled $true -SearchLocations @(
            @{ id = 'testIgnoreExternalDir'; kind = 'directory'; searchOrder = 100; path = $installRoot }
        ) -InstallRootRules @()
        $policy = New-TestOwnershipPolicy -AllowAdoptExternal $true -RequirePackageOwnership $true
        $readiness = New-TestReadiness -Version '2.0.0' -Directories @()
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -ExistingInstallDiscovery $existingInstallDiscovery -OwnershipPolicy $policy -Readiness $readiness
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PackageAssignmentInventoryFilePath (Join-Path $rootPath 'PackageAssignmentInventory.json')) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness $readiness)
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Find-PackageExistingPackage -PackageResult $result
        $result = Set-PackageExistingPackage -PackageResult $result
        $result = Resolve-PackageExistingPackageDecision -PackageResult $result

        $result.ExistingPackage.Decision | Should -Be 'ExternalIgnored'
        $result.Readiness | Should -BeNullOrEmpty
    }

    It 'reuses a managed install when the ownership record matches the install slot and current release' {
        $rootPath = Join-Path $TestDrive 'reuse-managed'
        $installRoot = Join-Path $rootPath 'managed-install'
        $binDirectory = Join-Path $installRoot 'bin'
        $packageStateIndexPath = Join-Path $rootPath 'PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path $binDirectory -Force
        Write-TestTextFile -Path (Join-Path $installRoot 'Code.exe') -Content 'fake'
        Write-TestTextFile -Path (Join-Path $binDirectory 'code.cmd') -Content "@echo off`r`necho 2.0.0`r`n"
        Write-TestJsonDocument -Path $packageStateIndexPath -Document @{
            records = @(
                @{
                    installSlotId    = 'VSCodeRuntime:stable:win32-x64'
                    definitionId     = 'VSCodeRuntime'
                    releaseTrack     = 'stable'
                    artifactDistributionVariant           = 'win32-x64'
                    currentReleaseId = 'vsCode-win-x64-stable'
                    currentVersion   = '2.0.0'
                    installDirectory = $installRoot
                    ownershipKind    = 'PackageInstalled'
                    updatedAtUtc     = [DateTime]::UtcNow.ToString('o')
                }
            )
        }

        $existingInstallDiscovery = New-TestExistingInstallDiscovery -Enabled $true -SearchLocations @(
            @{ id = 'testReuseManagedDir'; kind = 'directory'; searchOrder = 100; path = $installRoot }
        ) -InstallRootRules @()
        $policy = New-TestOwnershipPolicy -AllowAdoptExternal $true
        $readiness = New-TestReadiness -Version '2.0.0' -Directories @()
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -ExistingInstallDiscovery $existingInstallDiscovery -OwnershipPolicy $policy -Readiness $readiness
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PackageAssignmentInventoryFilePath $packageStateIndexPath) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness $readiness)
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Find-PackageExistingPackage -PackageResult $result
        $result = Set-PackageExistingPackage -PackageResult $result
        $result = Resolve-PackageExistingPackageDecision -PackageResult $result

        $result.ExistingPackage.Decision | Should -Be 'ReusePackageOwned'
        $result.InstallOrigin | Should -Be 'PackageReused'
    }

    It 'discovers an older OpenCode package-owned install from inventory and replaces it for a new selected version' {
        $rootPath = Join-Path $TestDrive 'opencode-inventory-update'
        $preferredInstallRoot = Join-Path $rootPath 'installs'
        $oldInstallRoot = Join-Path $preferredInstallRoot 'opencode-runtime\stable\1.14.46\win32-x64'
        $packageStateIndexPath = Join-Path $rootPath 'PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Join-Path $oldInstallRoot 'bin') -Force
        Write-TestTextFile -Path (Join-Path $oldInstallRoot 'Code.exe') -Content 'fake'
        Write-TestTextFile -Path (Join-Path $oldInstallRoot 'bin\code.cmd') -Content "@echo off`r`necho 1.14.46`r`n"
        Write-TestJsonDocument -Path $packageStateIndexPath -Document @{
            records = @(
                @{
                    installSlotId    = 'OpenCodeCli:stable:win32-x64'
                    definitionId     = 'OpenCodeCli'
                    releaseTrack     = 'stable'
                    artifactDistributionVariant = 'win32-x64'
                    currentReleaseId = 'opencode-runtime-win32-x64-stable'
                    currentVersion   = '1.14.46'
                    installDirectory = $oldInstallRoot
                    ownershipKind    = 'PackageInstalled'
                    updatedAtUtc     = [DateTime]::UtcNow.ToString('o')
                }
            )
        }

        $sharedInstall = @{
            install = @{
                kind             = 'expandArchive'
                installDirectory = 'opencode-runtime/{releaseTrack}/{version}/{artifactDistributionVariant}'
                expandedRoot     = 'auto'
            }
            versionUpdatePolicy = @{
                whenAssigned = 'trackSelectedVersion'
                onSameSelectedVersion = 'reuseOrRepair'
                onNewSelectedVersion = 'replacePackageOwnedInstall'
            }
        }
        $readiness = New-TestReadiness -Version '1.15.7' -Directories @()
        $release = New-TestPackageRelease -Id 'opencode-runtime-win32-x64-stable' -Version '1.15.7' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'opencode-1.15.7.zip' -Readiness $readiness
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PreferredTargetInstallDirectory $preferredInstallRoot -PackageAssignmentInventoryFilePath $packageStateIndexPath) -DefinitionDocument (New-TestVSCodeDefinitionDocument -DefinitionId 'OpenCodeCli' -Releases @($release) -SharedInstall $sharedInstall -SharedReadiness $readiness -SharedExistingInstallDiscovery (New-TestExistingInstallDiscovery -Enabled $false))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'OpenCodeCli'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $newInstallRoot = $result.InstallDirectory
        Test-Path -LiteralPath $newInstallRoot -PathType Container | Should -BeFalse
        $result = Find-PackageExistingPackage -PackageResult $result
        $result = Set-PackageExistingPackage -PackageResult $result
        $result = Resolve-PackageExistingPackageDecision -PackageResult $result

        $result.ExistingPackage.SearchKind | Should -Be 'packageInventoryInstallSlot'
        $result.ExistingPackage.InstallDirectory | Should -Be ([System.IO.Path]::GetFullPath($oldInstallRoot))
        $result.ExistingPackage.Decision | Should -Be 'ReplacePackageOwnedInstall'
        $result.InstallDirectory | Should -Be $newInstallRoot
        $result.Readiness | Should -BeNullOrEmpty
    }

    It 'uses an exact PackageVersion selector to downgrade a package-owned install when replacement is allowed' {
        $rootPath = Join-Path $TestDrive 'opencode-inventory-downgrade'
        $preferredInstallRoot = Join-Path $rootPath 'installs'
        $newerInstallRoot = Join-Path $preferredInstallRoot 'opencode-runtime\stable\1.15.7\win32-x64'
        $packageStateIndexPath = Join-Path $rootPath 'PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Join-Path $newerInstallRoot 'bin') -Force
        Write-TestTextFile -Path (Join-Path $newerInstallRoot 'Code.exe') -Content 'fake'
        Write-TestTextFile -Path (Join-Path $newerInstallRoot 'bin\code.cmd') -Content "@echo off`r`necho 1.15.7`r`n"
        Write-TestJsonDocument -Path $packageStateIndexPath -Document @{
            records = @(
                @{
                    installSlotId    = 'OpenCodeCli:stable:win32-x64'
                    definitionId     = 'OpenCodeCli'
                    releaseTrack     = 'stable'
                    artifactDistributionVariant = 'win32-x64'
                    currentReleaseId = 'opencode-runtime-win32-x64-stable'
                    currentVersion   = '1.15.7'
                    installDirectory = $newerInstallRoot
                    ownershipKind    = 'PackageInstalled'
                    updatedAtUtc     = [DateTime]::UtcNow.ToString('o')
                }
            )
        }

        $sharedInstall = @{
            install = @{
                kind             = 'expandArchive'
                installDirectory = 'opencode-runtime/{releaseTrack}/{version}/{artifactDistributionVariant}'
                expandedRoot     = 'auto'
            }
            versionUpdatePolicy = @{
                whenAssigned = 'trackSelectedVersion'
                onSameSelectedVersion = 'reuseOrRepair'
                onNewSelectedVersion = 'replacePackageOwnedInstall'
            }
        }
        $readiness = New-TestReadiness -Version '1.14.46' -Directories @()
        $releaseLatest = New-TestPackageRelease -Id 'opencode-runtime-win32-x64-stable' -Version '1.15.7' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'opencode-1.15.7.zip' -Readiness (New-TestReadiness -Version '1.15.7' -Directories @())
        $definitionDocument = New-TestVSCodeDefinitionDocument -DefinitionId 'OpenCodeCli' -Releases @($releaseLatest) -SharedInstall $sharedInstall -SharedReadiness $readiness -SharedExistingInstallDiscovery (New-TestExistingInstallDiscovery -Enabled $false)
        $definitionDocument.artifacts.releases += [ordered]@{
            version = '1.14.46'
            releaseTracks = @('stable')
            targetArtifacts = @{
                'opencode-runtime-win32-x64-stable' = @{
                    artifactId = 'opencode-runtime-win32-x64-stable'
                    fileName   = 'opencode-1.14.46.zip'
                }
            }
        }
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PreferredTargetInstallDirectory $preferredInstallRoot -PackageAssignmentInventoryFilePath $packageStateIndexPath) -DefinitionDocument $definitionDocument
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'OpenCodeCli'
        $result = New-PackageResult -PackageConfig $config -PackageVersionSelector '1.14.46'
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $downgradeInstallRoot = $result.InstallDirectory
        $result = Find-PackageExistingPackage -PackageResult $result
        $result = Set-PackageExistingPackage -PackageResult $result
        $result = Resolve-PackageExistingPackageDecision -PackageResult $result

        $result.Package.version | Should -Be '1.14.46'
        $result.ExistingPackage.SearchKind | Should -Be 'packageInventoryInstallSlot'
        $result.ExistingPackage.InstallDirectory | Should -Be ([System.IO.Path]::GetFullPath($newerInstallRoot))
        $result.ExistingPackage.Decision | Should -Be 'ReplacePackageOwnedInstall'
        $result.InstallDirectory | Should -Be $downgradeInstallRoot
    }

    It 'fails an assigned version change when versionUpdatePolicy.onNewSelectedVersion is fail' {
        $rootPath = Join-Path $TestDrive 'opencode-inventory-update-fail'
        $preferredInstallRoot = Join-Path $rootPath 'installs'
        $oldInstallRoot = Join-Path $preferredInstallRoot 'opencode-runtime\stable\1.14.46\win32-x64'
        $packageStateIndexPath = Join-Path $rootPath 'PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Join-Path $oldInstallRoot 'bin') -Force
        Write-TestTextFile -Path (Join-Path $oldInstallRoot 'Code.exe') -Content 'fake'
        Write-TestTextFile -Path (Join-Path $oldInstallRoot 'bin\code.cmd') -Content "@echo off`r`necho 1.14.46`r`n"
        Write-TestJsonDocument -Path $packageStateIndexPath -Document @{
            records = @(
                @{
                    installSlotId    = 'OpenCodeCli:stable:win32-x64'
                    definitionId     = 'OpenCodeCli'
                    releaseTrack     = 'stable'
                    artifactDistributionVariant = 'win32-x64'
                    currentReleaseId = 'opencode-runtime-win32-x64-stable'
                    currentVersion   = '1.14.46'
                    installDirectory = $oldInstallRoot
                    ownershipKind    = 'PackageInstalled'
                    updatedAtUtc     = [DateTime]::UtcNow.ToString('o')
                }
            )
        }

        $sharedInstall = @{
            install = @{
                kind             = 'expandArchive'
                installDirectory = 'opencode-runtime/{releaseTrack}/{version}/{artifactDistributionVariant}'
                expandedRoot     = 'auto'
            }
            versionUpdatePolicy = @{
                whenAssigned = 'trackSelectedVersion'
                onSameSelectedVersion = 'reuseOrRepair'
                onNewSelectedVersion = 'fail'
            }
        }
        $readiness = New-TestReadiness -Version '1.15.7' -Directories @()
        $release = New-TestPackageRelease -Id 'opencode-runtime-win32-x64-stable' -Version '1.15.7' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'opencode-1.15.7.zip' -Readiness $readiness
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PreferredTargetInstallDirectory $preferredInstallRoot -PackageAssignmentInventoryFilePath $packageStateIndexPath) -DefinitionDocument (New-TestVSCodeDefinitionDocument -DefinitionId 'OpenCodeCli' -Releases @($release) -SharedInstall $sharedInstall -SharedReadiness $readiness -SharedExistingInstallDiscovery (New-TestExistingInstallDiscovery -Enabled $false))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'OpenCodeCli'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Find-PackageExistingPackage -PackageResult $result
        $result = Set-PackageExistingPackage -PackageResult $result

        { Resolve-PackageExistingPackageDecision -PackageResult $result } | Should -Throw -ExpectedMessage "*versionUpdatePolicy.onNewSelectedVersion='fail'*"
    }

    It 'removes the replaced package-owned install directory after the new install is ready' {
        $rootPath = Join-Path $TestDrive 'opencode-replacement-cleanup'
        $preferredInstallRoot = Join-Path $rootPath 'installs'
        $oldInstallRoot = Join-Path $preferredInstallRoot 'opencode-runtime\stable\1.14.46\win32-x64'
        $newInstallRoot = Join-Path $preferredInstallRoot 'opencode-runtime\stable\1.15.7\win32-x64'
        $null = New-Item -ItemType Directory -Path $oldInstallRoot -Force
        $null = New-Item -ItemType Directory -Path $newInstallRoot -Force
        Write-TestTextFile -Path (Join-Path $oldInstallRoot 'old.txt') -Content 'old'
        Write-TestTextFile -Path (Join-Path $newInstallRoot 'new.txt') -Content 'new'

        $result = [pscustomobject]@{
            ExistingPackage = [pscustomobject]@{
                Decision         = 'ReplacePackageOwnedInstall'
                InstallDirectory = $oldInstallRoot
            }
            InstallDirectory = $newInstallRoot
            Readiness = [pscustomobject]@{
                Accepted = $true
            }
            Ownership = [pscustomobject]@{
                OwnershipRecord = [pscustomobject]@{
                    ownershipKind = 'PackageInstalled'
                }
            }
            PackageConfig = [pscustomobject]@{
                PreferredTargetInstallRootDirectory = $preferredInstallRoot
            }
        }

        $result = Remove-PackageReplacedPackageOwnedInstallDirectory -PackageResult $result

        $result.ReplacementCleanup.Status | Should -Be 'Removed'
        Test-Path -LiteralPath $oldInstallRoot -PathType Container | Should -BeFalse
        Test-Path -LiteralPath $newInstallRoot -PathType Container | Should -BeTrue
    }

    It 'discovers and reuses the current package target install path even when inventory is missing' {
        $rootPath = Join-Path $TestDrive 'reuse-managed-untracked'
        $installRoot = Join-Path $rootPath 'managed-install'
        $binDirectory = Join-Path $installRoot 'bin'
        $null = New-Item -ItemType Directory -Path $binDirectory -Force
        Write-TestTextFile -Path (Join-Path $installRoot 'Code.exe') -Content 'fake'
        Write-TestTextFile -Path (Join-Path $binDirectory 'code.cmd') -Content "@echo off`r`necho 2.0.0`r`n"

        $readiness = New-TestReadiness -Version '2.0.0' -Directories @()
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{
            kind             = 'reuseExisting'
            installDirectory = $installRoot
        } -ExistingInstallDiscovery (New-TestExistingInstallDiscovery -Enabled $true -SearchLocations @()) -OwnershipPolicy (New-TestOwnershipPolicy -AllowAdoptExternal $true) -Readiness $readiness
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PreferredTargetInstallDirectory (Join-Path $rootPath 'managed-root') -PackageAssignmentInventoryFilePath (Join-Path $rootPath 'PackageAssignmentInventory.json')) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness $readiness)
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Find-PackageExistingPackage -PackageResult $result
        $result = Set-PackageExistingPackage -PackageResult $result
        $result = Resolve-PackageExistingPackageDecision -PackageResult $result
        $result = Set-PackageAssignedState -PackageResult $result

        $result.ExistingPackage.SearchKind | Should -Be 'packageTargetInstallPath'
        $result.ExistingPackage.Decision | Should -Be 'ReusePackageOwned'
        $result.InstallOrigin | Should -Be 'PackageReused'
        $result.Assigned.Status | Should -Be 'ReusedPackageOwned'
    }

    It 'marks a failed readiness on the managed install path as a repaired managed install after reinstall' {
        $rootPath = Join-Path $TestDrive 'repair-managed'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0' -ArchiveFileName 'VSCode-win32-x64-2.0.0.zip'
        $globalDocument = New-TestPackageGlobalDocument -PackageFileStagingDirectory (Join-Path $rootPath 'workspace') -DefaultPackageDepotDirectory (Join-Path $rootPath 'default-depot') -PreferredTargetInstallDirectory (Join-Path $rootPath 'installs')
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -Install @{
            kind             = 'expandArchive'
            installDirectory = 'vsc-rt/stable/2.0.0/win32-x64'
            expandedRoot     = 'auto'
            createDirectories = @('data')
        } -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder     = 10
                verification = @{ mode = 'required'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            }
        ) -Readiness (New-TestReadiness -Version '2.0.0')
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result

        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $result.DefaultPackageDepotFilePath) -Force
        Copy-Item -LiteralPath $packageArchive.ZipPath -Destination $result.DefaultPackageDepotFilePath -Force
        $result = Resolve-PackageInstallFile -PackageResult $result
        $result = Set-PackageAssignedState -PackageResult $result

        Remove-Item -LiteralPath (Join-Path $result.InstallDirectory 'data') -Recurse -Force

        $rerun = New-PackageResult -PackageConfig $config
        $rerun = Resolve-PackagePackage -PackageResult $rerun
        $rerun = Resolve-PackagePaths -PackageResult $rerun
        $rerun = Build-PackageAcquisitionPlan -PackageResult $rerun
        $rerun = Find-PackageExistingPackage -PackageResult $rerun
        $rerun = Set-PackageExistingPackage -PackageResult $rerun
        $rerun = Resolve-PackageExistingPackageDecision -PackageResult $rerun
        $rerun = Resolve-PackageInstallFile -PackageResult $rerun
        $rerun = Set-PackageAssignedState -PackageResult $rerun

        $rerun.ExistingPackage.SearchKind | Should -Be 'packageTargetInstallPath'
        $rerun.ExistingPackage.Decision | Should -Be 'ExistingInstallReadinessFailed'
        $rerun.Assigned.Status | Should -Be 'RepairedPackageOwnedInstall'
    }

}

