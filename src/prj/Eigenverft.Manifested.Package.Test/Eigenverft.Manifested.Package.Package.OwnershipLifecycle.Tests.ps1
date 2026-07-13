<#
    Eigenverft.Manifested.Package Package - ownership lifecycle
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - ownership lifecycle' -Body {

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
