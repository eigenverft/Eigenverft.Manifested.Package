<#
    Eigenverft.Manifested.Package Package - PowerShell module installer
#>

. "$PSScriptRoot\\Eigenverft.Manifested.Package.Package.InstallAndNpm.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - PowerShell module installer' -Body {

    It 'requires package-file acquisition for powershellModuleInstaller' {
        $package = [pscustomobject]@{
            assigned = [pscustomobject]@{
                install = [pscustomobject]@{
                    kind            = 'powershellModuleInstaller'
                    moduleName      = 'PowerShellGet'
                    requiredVersion = '2.2.5'
                }
            }
        }

        Test-PackagePackageFileAcquisitionRequired -Package $package | Should -BeTrue
    }

    It 'resolves paths for powershellModuleInstaller without an install directory' {
        $rootPath = Join-Path $TestDrive 'psmodule-paths'
        $packageResult = [pscustomobject]@{
            PackageFileStagingDirectory = $null
            PackageInstallStageDirectory = $null
            InstallDirectory = $null
            PackageDepotRelativeDirectory = $null
            PackageWorkSlotDirectory = $null
            PackageFilePath = $null
            DefaultPackageDepotFilePath = $null
            PackageConfig = [pscustomobject]@{
                DefinitionId = 'PowerShellGet'
                Definition   = [pscustomobject]@{ id = 'PowerShellGet' }
                PackageFileStagingRootDirectory = Join-Path $rootPath 'FileStage'
                PackageInstallStageRootDirectory = Join-Path $rootPath 'InstStage'
                DefaultPackageDepotDirectory = Join-Path $rootPath 'PkgDepot'
                PreferredTargetInstallRootDirectory = Join-Path $rootPath 'Installed'
                ReleaseTrack = 'stable'
            }
            Package = [pscustomobject]@{
                id           = 'powershellget-psmodule-stable'
                version      = '2.2.5'
                releaseTrack = 'stable'
                artifactDistributionVariant = 'psmodule-any'
                packageFile  = [pscustomobject]@{
                    fileName = 'PowerShellGet.2.2.5.nupkg'
                }
                assigned     = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind            = 'powershellModuleInstaller'
                        moduleName      = 'PowerShellGet'
                        requiredVersion = '2.2.5'
                    }
                }
            }
        }

        $result = Resolve-PackagePaths -PackageResult $packageResult

        $result.InstallDirectory | Should -BeNullOrEmpty
        $result.PackageFilePath | Should -Match 'PowerShellGet\.2\.2\.5\.nupkg$'
        $result.DefaultPackageDepotFilePath | Should -Match 'PkgDepot\\PowerShellGet\\stable\\2\.2\.5\\psmodule-any\\PowerShellGet\.2\.2\.5\.nupkg$'
    }

    It 'invokes powershellModuleInstaller through a full helper script path and staged local repository' {
        $rootPath = Join-Path $TestDrive 'psmodule-helper'
        $packageFilePath = Join-Path $rootPath 'FileStage\Eigenverft.Manifested.Agent.1.20261.39327.nupkg'
        $stageDirectory = Join-Path $rootPath 'InstStage'
        Write-TestTextFile -Path $packageFilePath -Content 'nupkg'

        $invokeCalls = New-Object System.Collections.Generic.List[object]
        Mock Get-PackageWindowsPowerShellPath { Join-Path $rootPath 'WindowsPowerShell\v1.0\powershell.exe' }
        Mock Invoke-PackageInstallerCommand {
            param($PackageResult, $CommandPath, $CommandArguments, $WorkingDirectory, $TimeoutSec, $SuccessExitCodes, $RestartExitCodes, $TargetKind, $InstallerKind, $UiMode, $LogPath, $ElevationMode, $WindowStyle)
            $resultPath = [string]$CommandArguments[([array]::IndexOf($CommandArguments, '-ResultPath') + 1)]
            [pscustomobject]@{
                success = $true
                status = 'Installed'
                installed = $true
                moduleName = 'Eigenverft.Manifested.Agent'
                requiredVersion = '1.20261.39327'
                installedVersion = '1.20261.39327'
                moduleBase = Join-Path $rootPath 'Modules\Eigenverft.Manifested.Agent\1.20261.39327'
                scope = 'CurrentUser'
            } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding UTF8
            $invokeCalls.Add([pscustomobject]@{
                CommandPath = $CommandPath
                CommandArguments = @($CommandArguments)
                WorkingDirectory = $WorkingDirectory
                TimeoutSec = $TimeoutSec
                TargetKind = $TargetKind
                InstallerKind = $InstallerKind
                UiMode = $UiMode
                ElevationMode = $ElevationMode
                WindowStyle = $WindowStyle
            }) | Out-Null
            [pscustomobject]@{
                ExitCode = 0
                RestartRequired = $false
                CommandPath = $CommandPath
                CommandArguments = @($CommandArguments)
                TargetKind = $TargetKind
                InstallerKind = $InstallerKind
                UiMode = $UiMode
            }
        }

        $packageResult = [pscustomobject]@{
            DefinitionId = 'EigenverftManifestedAgent'
            PackageId = 'eigenverft-manifested-agent-psmodule-stable'
            PackageFilePath = $packageFilePath
            PackageInstallStageDirectory = $stageDirectory
            Package = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind = 'powershellModuleInstaller'
                        moduleName = 'Eigenverft.Manifested.Agent'
                        requiredVersion = '1.20261.39327'
                        scope = 'CurrentUser'
                        allowClobber = $true
                        skipPublisherCheck = $false
                        timeoutSec = 600
                    }
                }
            }
        }

        $result = Install-PackagePowerShellModule -PackageResult $packageResult

        $invokeCalls.Count | Should -Be 1
        $invokeCalls[0].CommandArguments | Should -Contain '-File'
        $helperPath = [string]$invokeCalls[0].CommandArguments[([array]::IndexOf($invokeCalls[0].CommandArguments, '-File') + 1)]
        [System.IO.Path]::IsPathRooted($helperPath) | Should -BeTrue
        $invokeCalls[0].WorkingDirectory | Should -Be ([System.IO.Path]::GetFullPath($stageDirectory))
        $invokeCalls[0].TargetKind | Should -Be 'powershellModule'
        $invokeCalls[0].InstallerKind | Should -Be 'powershellModuleInstaller'
        $invokeCalls[0].ElevationMode | Should -Be 'none'
        $invokeCalls[0].WindowStyle | Should -Be 'Hidden'
        Test-Path -LiteralPath (Join-Path $stageDirectory 'Nuget\Eigenverft.Manifested.Agent.1.20261.39327.nupkg') -PathType Leaf | Should -BeTrue
        $result.InstallKind | Should -Be 'powershellModuleInstaller'
        $result.Status | Should -Be 'Applied'
        $result.InstalledVersion | Should -Be '1.20261.39327'
    }

    It 'does not short-circuit powershellModuleInstaller before acquisition' {
        $packageResult = [pscustomobject]@{
            InstallOrigin = $null
            Assigned      = $null
            PackageInstallStageDirectory = Join-Path $TestDrive 'psmodule-check'
            Package       = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind            = 'powershellModuleInstaller'
                        moduleName      = 'PowerShellGet'
                        requiredVersion = '2.2.5'
                    }
                }
            }
        }

        $packageResult = Resolve-PackagePreAssignmentSatisfaction -PackageResult $packageResult

        $packageResult.InstallOrigin | Should -BeNullOrEmpty
        $packageResult.Assigned | Should -BeNullOrEmpty
    }

    It 'discovers and adopts an exact existing PowerShell module when policy allows it' {
        $moduleBase = Join-Path $TestDrive 'Modules\PowerShellGet\2.2.5'
        $inventoryPath = Join-Path $TestDrive 'State\PackageAssignmentInventory.json'
        $packageResult = [pscustomobject]@{
            DefinitionId = 'PowerShellGet'
            PackageId    = 'powershellget-psmodule-stable'
            PackageVersion = '2.2.5'
            ReleaseTrack = 'stable'
            InstallOrigin = $null
            InstallDirectory = $null
            Assigned = $null
            Readiness = $null
            PackageInstallStageDirectory = Join-Path $TestDrive 'psmodule-adopt-stage'
            ExistingPackage = $null
            Ownership = $null
            PackageConfig = ConvertTo-TestPsObject @{
                PackageAssignmentInventoryFilePath = $inventoryPath
                Definition = @{
                    discovery = @{
                      existingInstall = @{
                        enabled = $true
                        searchLocations = @(
                            @{
                                id = 'currentUserPowerShellModule'
                                kind = 'powershellModule'
                                searchOrder = 100
                                name = 'PowerShellGet'
                                requiredVersion = '2.2.5'
                                scope = 'CurrentUser'
                            }
                        )
                        installRootRules = @()
                    }
                    }
                }
            }
            Package = ConvertTo-TestPsObject @{
                id = 'powershellget-psmodule-stable'
                version = '2.2.5'
                releaseTrack = 'stable'
                artifactDistributionVariant = 'psmodule-any'
                readiness = @{
                    files = @()
                    directories = @()
                    commandChecks = @()
                    metadataFiles = @()
                    signatures = @()
                    fileDetails = @()
                    registryChecks = @()
                    powerShellModules = @(
                        @{
                            name = 'PowerShellGet'
                            requiredVersion = '2.2.5'
                            scope = 'CurrentUser'
                        }
                    )
                }
                ownershipPolicy = @{
                    allowAdoptExternal = $true
                    upgradeAdoptedInstall = $false
                    requirePackageOwnership = $false
                }
                assigned = @{
                    install = @{
                        kind = 'powershellModuleInstaller'
                        moduleName = 'PowerShellGet'
                        requiredVersion = '2.2.5'
                        scope = 'CurrentUser'
                    }
                }
            }
        }

        Mock Test-PackagePowerShellModulePresence {
            [pscustomobject]@{
                installed = $true
                moduleInstalled = $true
                status = 'AlreadyInstalled'
                moduleName = 'PowerShellGet'
                requiredVersion = '2.2.5'
                installedVersion = '2.2.5'
                moduleBase = $moduleBase
                scope = 'CurrentUser'
                nugetProviderAvailable = $true
            }
        }

        $packageResult = Find-PackageExistingPackage -PackageResult $packageResult
        $packageResult = Set-PackageExistingPackage -PackageResult $packageResult
        $packageResult = Resolve-PackageExistingPackageDecision -PackageResult $packageResult
        $packageResult = Set-PackageAssignedState -PackageResult $packageResult

        $packageResult.ExistingPackage.SearchKind | Should -Be 'powershellModule'
        $packageResult.ExistingPackage.InstallDirectory | Should -BeNullOrEmpty
        $packageResult.InstallOrigin | Should -Be 'AdoptedExternal'
        $packageResult.Assigned.InstallKind | Should -Be 'powershellModuleInstaller'
        $packageResult.Assigned.Status | Should -Be 'AdoptedExternal'
        $packageResult.Assigned.ModuleBase | Should -Be $moduleBase
    }

    It 'does not adopt PackageManagement when the NuGet provider is missing' {
        $packageResult = [pscustomobject]@{
            DefinitionId = 'PackageManagement'
            PackageInstallStageDirectory = Join-Path $TestDrive 'psmodule-provider-stage'
            PackageConfig = ConvertTo-TestPsObject @{
                Definition = @{
                    discovery = @{
                      existingInstall = @{
                        enabled = $true
                        searchLocations = @(
                            @{
                                id = 'currentUserPowerShellModule'
                                kind = 'powershellModule'
                                searchOrder = 100
                                name = 'PackageManagement'
                                requiredVersion = '1.4.8.1'
                                scope = 'CurrentUser'
                                requireNuGetProvider = $true
                            }
                        )
                        installRootRules = @()
                    }
                    }
                }
            }
            Package = ConvertTo-TestPsObject @{ id = 'package-management-psmodule-stable'; version = '1.4.8.1' }
        }

        Mock Test-PackagePowerShellModulePresence {
            [pscustomobject]@{
                installed = $false
                moduleInstalled = $true
                status = 'NuGetProviderMissing'
                moduleName = 'PackageManagement'
                requiredVersion = '1.4.8.1'
                installedVersion = '1.4.8.1'
                moduleBase = Join-Path $TestDrive 'Modules\PackageManagement\1.4.8.1'
                scope = 'CurrentUser'
                requireNuGetProvider = $true
                nugetProviderAvailable = $false
            }
        }

        $packageResult = Find-PackageExistingPackage -PackageResult $packageResult

        $packageResult.ExistingPackage | Should -BeNullOrEmpty
    }

    It 'keeps package-file acquisition active for adopted PowerShell modules' {
        $packageFilePath = Join-Path $TestDrive 'PowerShellGet.2.2.5.nupkg'
        Set-Content -LiteralPath $packageFilePath -Value 'nupkg' -Encoding UTF8
        $packageResult = [pscustomobject]@{
            ExistingPackage = [pscustomobject]@{
                Decision = 'AdoptExternal'
            }
            Package = ConvertTo-TestPsObject @{
                id = 'powershellget-psmodule-stable'
                assigned = @{
                    install = @{
                        kind = 'powershellModuleInstaller'
                    }
                }
            }
            PackageConfig = ConvertTo-TestPsObject @{
                AllowAcquisitionFallback = $true
            }
            PackageFilePath = $packageFilePath
            AcquisitionPlan = [pscustomobject]@{
                PackageFileRequired = $true
                Candidates = @(
                    [pscustomobject]@{
                        verification = [pscustomobject]@{
                            mode = 'none'
                        }
                    }
                )
            }
            PackageFilePreparation = $null
        }

        $packageResult = Resolve-PackageInstallFile -PackageResult $packageResult

        $packageResult.PackageFilePreparation.Status | Should -Be 'ReusedPackageFile'
    }

    It 'writes adopted PowerShell modules to package inventory without an install directory' {
        $inventoryPath = Join-Path $TestDrive 'State\PackageAssignmentInventory.json'
        $packageResult = [pscustomobject]@{
            DefinitionId = 'PowerShellGet'
            PackageId = 'powershellget-psmodule-stable'
            PackageVersion = '2.2.5'
            InstallOrigin = 'AdoptedExternal'
            InstallDirectory = $null
            Readiness = [pscustomobject]@{ Accepted = $true }
            Ownership = $null
            Dependencies = @()
            PackageConfig = [pscustomobject]@{
                PackageAssignmentInventoryFilePath = $inventoryPath
            }
            Package = [pscustomobject]@{
                releaseTrack = 'stable'
                artifactDistributionVariant = 'psmodule-any'
            }
        }

        Mock Copy-PackageDefinitionToAssignedSnapshot {
            [pscustomobject]@{
                EndpointName = 'moduleDefaults'
                PublisherId = 'Eigenverft'
                PublisherName = 'Eigenverft'
                DefinitionRevision = 1
                PublishedAtUtc = '2026-05-17T12:00:00Z'
                SourceKind = 'moduleLocal'
                SourcePath = 'source.json'
                SourceHash = 'sourcehash'
                CandidatePath = 'candidate.json'
                CandidateHash = 'candidatehash'
                AssignedSnapshotPath = 'assigned.json'
                AssignedSnapshotHash = 'assignedhash'
                ResolvedAtUtc = '2026-05-17T12:00:00Z'
            }
        }

        $packageResult = Update-PackageInventoryRecord -PackageResult $packageResult
        $inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json

        $inventory.records[0].ownershipKind | Should -Be 'AdoptedExternal'
        $inventory.records[0].installDirectory | Should -BeNullOrEmpty
        $packageResult.Ownership.Classification | Should -Be 'AdoptedExternal'
    }

    It 'classifies powershellModuleInstaller assignments as PackageApplied' {
        $packageResult = [pscustomobject]@{
            InstallOrigin = $null
            Assigned = $null
            PackageFilePreparation = [pscustomobject]@{ Success = $true }
            ExistingPackage = $null
            Package = [pscustomobject]@{
                id = 'powershellget-psmodule-stable'
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind            = 'powershellModuleInstaller'
                        moduleName      = 'PowerShellGet'
                        requiredVersion = '2.2.5'
                    }
                }
            }
        }

        Mock Install-PackagePowerShellModule {
            [pscustomobject]@{
                Status = 'Applied'
                InstallKind = 'powershellModuleInstaller'
                TargetKind = 'powershellModule'
                InstallDirectory = $null
                ReusedExisting = $false
            }
        }

        $result = Set-PackageAssignedState -PackageResult $packageResult

        $result.InstallOrigin | Should -Be 'PackageApplied'
        $result.Assigned.InstallKind | Should -Be 'powershellModuleInstaller'
    }

    It 'accepts package-file Authenticode verification without a SHA256 hash' {
        $packageFilePath = Join-Path $TestDrive 'authenticode-package\vc_redist.x64.exe'
        Write-TestTextFile -Path $packageFilePath -Content 'signed installer placeholder'

        Mock Get-AuthenticodeSignature {
            [pscustomobject]@{
                Status            = [System.Management.Automation.SignatureStatus]::Valid
                SignerCertificate = [pscustomobject]@{
                    Subject = 'CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US'
                }
            }
        }

        $verification = [pscustomobject]@{
            mode = 'required'
            authenticode = [pscustomobject]@{
                requireValid    = $true
                subjectContains = 'Microsoft Corporation'
            }
        }

        $result = Test-PackageSavedFile -Path $packageFilePath -Verification $verification

        $result.Accepted | Should -BeTrue
        $result.Status | Should -Be 'AuthenticodePassed'
        $result.SignatureStatus | Should -Be 'Valid'
    }

    It 'validates registry-only machine prerequisites without an install directory' {
        $registryPath = 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'
        $packageResult = [pscustomobject]@{
            InstallDirectory = $null
            Readiness = $null
            PackageConfig = [pscustomobject]@{}
            Package = [pscustomobject]@{
                readiness = [pscustomobject]@{
                    files = @()
                    directories = @()
                    commandChecks = @()
                    metadataFiles = @()
                    signatures = @()
                    fileDetails = @()
                    registryChecks = @(
                        [pscustomobject]@{
                            paths = @($registryPath)
                            valueName = 'Installed'
                            expectedValue = '1'
                        },
                        [pscustomobject]@{
                            paths = @($registryPath)
                            valueName = 'Version'
                            operator = '>='
                            expectedValue = '14.0'
                        }
                    )
                }
            }
        }

        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq $registryPath }
        Mock Get-ItemProperty {
            [pscustomobject]@{
                Installed = 1
                Version   = '14.44.35211.0'
            }
        } -ParameterFilter { $LiteralPath -eq $registryPath }

        $packageResult = Test-PackageAssignedReadiness -PackageResult $packageResult

        $packageResult.Readiness.Accepted | Should -BeTrue
        @($packageResult.Readiness.Registry | ForEach-Object { $_.Status }) | Should -Be @('Ready', 'Ready')
    }

}
