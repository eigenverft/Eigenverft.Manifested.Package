<#
    Eigenverft.Manifested.Package Package - registry and installer
#>

. "$PSScriptRoot\\Eigenverft.Manifested.Package.Package.InstallAndNpm.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - registry and installer' -Body {

    It 'stages a complete split installer set and executes the selected file beside its parts' {
        $rootPath = Join-Path $TestDrive 'split-installer-stage'
        $sourceDirectory = Join-Path $rootPath 'source'
        $installStageDirectory = Join-Path $rootPath 'install-stage'
        $setupSource = Join-Path $sourceDirectory 'setup.exe'
        $partSource = Join-Path $sourceDirectory 'setup.001'
        Write-TestTextFile -Path $setupSource -Content 'setup'
        Write-TestTextFile -Path $partSource -Content 'part001'
        $setupArtifact = [pscustomobject]@{ Id = 'setup'; RelativePath = 'installer\setup.exe'; StagingPath = $setupSource }
        $partArtifact = [pscustomobject]@{ Id = 'part001'; RelativePath = 'installer\setup.001'; StagingPath = $partSource }
        $invokeCalls = New-Object System.Collections.Generic.List[object]
        Mock Invoke-PackageInstallerCommand {
            param($PackageResult, $CommandPath, $CommandArguments, $WorkingDirectory)
            $invokeCalls.Add([pscustomobject]@{ CommandPath = $CommandPath; WorkingDirectory = $WorkingDirectory }) | Out-Null
            [pscustomobject]@{ CommandPath = $CommandPath; WorkingDirectory = $WorkingDirectory }
        }
        $packageResult = [pscustomobject]@{
            PackageId = 'SplitSuite'
            PackageInstallStageDirectory = $installStageDirectory
            InstallDirectory = Join-Path $rootPath 'installed'
            ArtifactPreparation = [pscustomobject]@{ Success = $true }
            ArtifactFiles = @($setupArtifact, $partArtifact)
            OperationArtifactFile = $setupArtifact
            OperationArtifactFilePath = $setupSource
            PackageConfig = [pscustomobject]@{}
            Package = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind = 'runInstaller'; artifactFileId = 'setup'; targetKind = 'directory'
                        installerKind = 'customExe'; uiMode = 'silent'; elevation = 'none'
                        commandArguments = @('/S'); successExitCodes = @(0); restartExitCodes = @()
                    }
                }
            }
        }

        $packageResult = Stage-PackageArtifactFilesForInstallation -PackageResult $packageResult
        $null = Invoke-PackageInstallerProcess -PackageResult $packageResult

        $expectedDirectory = Join-Path $installStageDirectory 'Artifacts\installer'
        $packageResult.OperationArtifactFilePath | Should -Be (Join-Path $expectedDirectory 'setup.exe')
        Test-Path -LiteralPath (Join-Path $expectedDirectory 'setup.001') -PathType Leaf | Should -BeTrue
        $invokeCalls.Count | Should -Be 1
        $invokeCalls[0].CommandPath | Should -Be $packageResult.OperationArtifactFilePath
        $invokeCalls[0].WorkingDirectory | Should -Be $expectedDirectory
    }

    It 'resolves registry values through the generic execution-engine helper' {
        $registryPath = 'HKLM:\SOFTWARE\Vendor\Product'

        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq $registryPath }
        Mock Get-ItemProperty {
            [pscustomobject]@{
                Version = '1.2.3'
            }
        } -ParameterFilter { $LiteralPath -eq $registryPath -and $Name -eq 'Version' }

        $result = Resolve-RegistryValueFromPaths -Paths @($registryPath) -ValueName 'Version'

        $result.Path | Should -Be $registryPath
        $result.ActualValue | Should -Be '1.2.3'
        $result.Status | Should -Be 'Ready'
    }

    It 'returns missing when no registry candidate path exists' {
        $paths = @(
            'HKLM:\SOFTWARE\Vendor\MissingA',
            'HKLM:\SOFTWARE\Vendor\MissingB'
        )

        Mock Test-Path { $false }

        $result = Resolve-RegistryValueFromPaths -Paths $paths -ValueName 'Version'

        $result.Path | Should -Be $paths[0]
        $result.Paths | Should -Be $paths
        $result.ActualValue | Should -BeNullOrEmpty
        $result.Status | Should -Be 'Missing'
    }

    It 'reads a direct Windows uninstall registry key and resolves display-icon directory' {
        $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++'

        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq $registryPath }
        Mock Get-ItemProperty {
            [pscustomobject]@{
                DisplayName     = 'Notepad++ (64-bit x64)'
                DisplayVersion  = '8.9.4'
                Publisher       = 'Notepad++ Team'
                InstallLocation = ''
                DisplayIcon     = '"C:\Program Files\Notepad++\notepad++.exe",0'
                UninstallString = '"C:\Program Files\Notepad++\uninstall.exe" /S'
            }
        } -ParameterFilter { $LiteralPath -eq $registryPath }

        $entry = Get-WindowsUninstallRegistryEntry -Path $registryPath
        $displayIconDirectory = Resolve-WindowsUninstallRegistryEntryPath -Entry $entry -Source 'displayIconDirectory'
        $uninstallPath = Resolve-WindowsUninstallRegistryEntryPath -Entry $entry -Source 'uninstallString'

        $entry.Status | Should -Be 'Ready'
        $entry.DisplayVersion | Should -Be '8.9.4'
        $displayIconDirectory.Status | Should -Be 'Ready'
        $displayIconDirectory.ResolvedPath | Should -Be ([System.IO.Path]::GetFullPath('C:\Program Files\Notepad++'))
        $uninstallPath.ResolvedPath | Should -Be ([System.IO.Path]::GetFullPath('C:\Program Files\Notepad++\uninstall.exe'))
    }

    It 'resolves windows uninstall registry discovery to an install directory candidate' {
        $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++'
        $installDirectory = Join-Path $TestDrive 'Program Files\Notepad++'
        $displayIconPath = Join-Path $installDirectory 'notepad++.exe'
        $null = New-Item -ItemType Directory -Path $installDirectory -Force

        Mock Test-Path { $false }
        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq $registryPath }
        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq $installDirectory -and $PathType -eq 'Container' }
        Mock Get-ItemProperty {
            [pscustomobject]@{
                DisplayName    = 'Notepad++ (64-bit x64)'
                DisplayVersion = '8.9.4'
                DisplayIcon    = '"' + $displayIconPath + '",0'
            }
        } -ParameterFilter { $LiteralPath -eq $registryPath }

        $packageResult = [pscustomobject]@{
            InstallDirectory = $null
            PackageConfig = ConvertTo-TestPsObject @{
                Definition = @{
                    discovery = @{
                      existingInstall = @{
                        enabled = $true
                        searchLocations = @(
                            [pscustomobject]@{
                                kind = 'windowsUninstallRegistryKey'
                                paths = @($registryPath)
                                installDirectorySource = 'displayIconDirectory'
                            }
                        )
                        installRootRules = @(
                            [pscustomobject]@{
                                match = @{
                                    kind  = 'fileName'
                                    value = 'notepad++'
                                }
                                installRootRelativePath = '..'
                            }
                        )
                    }
                    }
                }
            }
            Package          = [pscustomobject]@{
                id = 'notepad-plus-plus-8.9.4-win-x64'
            }
            ExistingPackage  = $null
        }

        $packageResult = Find-PackageExistingPackage -PackageResult $packageResult

        $packageResult.ExistingPackage.SearchKind | Should -Be 'windowsUninstallRegistryKey'
        $packageResult.ExistingPackage.CandidatePath | Should -Be ([System.IO.Path]::GetFullPath($installDirectory))
        $packageResult.ExistingPackage.InstallDirectory | Should -Be ([System.IO.Path]::GetFullPath($installDirectory))
        $packageResult.ExistingPackage.DiscoveryDetails.RegistryEntry.DisplayName | Should -Be 'Notepad++ (64-bit x64)'
    }

    It 'resolves scanned windows uninstall registry discovery to an install directory candidate' {
        $installDirectory = Join-Path $TestDrive 'Program Files\7-Zip'
        $null = New-Item -ItemType Directory -Path $installDirectory -Force

        Mock Get-WindowsUninstallRegistryEntries {
            @(
                [pscustomobject]@{
                    Path = 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\{11111111-1111-1111-1111-111111111111}'
                    KeyName = '{11111111-1111-1111-1111-111111111111}'
                    Status = 'Ready'
                    DisplayName = 'Other App'
                    Publisher = 'Other'
                    InstallLocation = Join-Path $TestDrive 'Other'
                },
                [pscustomobject]@{
                    Path = 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\{22222222-2222-2222-2222-222222222222}'
                    KeyName = '{22222222-2222-2222-2222-222222222222}'
                    Status = 'Ready'
                    DisplayName = '7-Zip 26.01 (x64)'
                    Publisher = 'Igor Pavlov'
                    InstallLocation = $installDirectory
                }
            )
        }

        $packageResult = [pscustomobject]@{
            InstallDirectory = $null
            PackageConfig = ConvertTo-TestPsObject @{
                Definition = @{
                    discovery = @{
                      existingInstall = @{
                        enabled = $true
                        searchLocations = @(
                            @{
                                kind = 'windowsUninstallRegistrySearch'
                                rootPaths = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
                                displayNamePatterns = @('7-Zip* (x64)*')
                                publisherPatterns = @('Igor Pavlov')
                                installDirectorySource = 'installLocation'
                            }
                        )
                        installRootRules = @()
                    }
                    }
                }
            }
            Package = [pscustomobject]@{
                id = 'sevenzip-msi-win-x64-stable'
                version = '26.01'
            }
            ExistingPackage = $null
        }

        $packageResult = Find-PackageExistingPackage -PackageResult $packageResult

        $packageResult.ExistingPackage.SearchKind | Should -Be 'windowsUninstallRegistrySearch'
        $packageResult.ExistingPackage.InstallDirectory | Should -Be ([System.IO.Path]::GetFullPath($installDirectory))
        $packageResult.ExistingPackage.DiscoveryDetails.RegistryEntry.KeyName | Should -Be '{22222222-2222-2222-2222-222222222222}'
    }

    It 'marks a satisfied machine prerequisite so acquisition and installer execution can be skipped' {
        $packageResult = [pscustomobject]@{
            InstallOrigin = $null
            Assigned      = $null
            Readiness    = $null
            Package       = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind       = 'runInstaller'
                        targetKind = 'machinePrerequisite'
                    }
                }
            }
        }

        Mock Test-PackageAssignedReadiness {
            param([psobject]$PackageResult)
            $PackageResult.Readiness = [pscustomobject]@{
                Accepted      = $true
                Files         = @()
                Directories   = @()
                Commands      = @()
                MetadataFiles = @()
                Signatures    = @()
                FileDetails   = @()
                Registry      = @([pscustomobject]@{ Status = 'Ready' })
            }
            $PackageResult
        }

        $packageResult = Resolve-PackagePreAssignmentSatisfaction -PackageResult $packageResult

        $packageResult.InstallOrigin | Should -Be 'AlreadySatisfied'
        $packageResult.Assigned.Status | Should -Be 'AlreadySatisfied'
        $packageResult.Assigned.TargetKind | Should -Be 'machinePrerequisite'
    }

    It 'runs required-elevation installers with RunAs and quoted log-path arguments' {
        $rootPath = Join-Path $TestDrive 'installer path with space'
        $installerPath = Join-Path $rootPath 'vc_redist.x64.exe'
        $workspacePath = Join-Path $rootPath 'workspace'
        Write-TestTextFile -Path $installerPath -Content 'installer'

        $process = [pscustomobject]@{
            Id       = 42
            ExitCode = 0
        }
        $process | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param([int]$Timeout) $true }
        $process | Add-Member -MemberType ScriptMethod -Name Refresh -Value { }

        $startProcessCalls = New-Object System.Collections.Generic.List[object]
        Mock Test-ProcessElevation { $false }
        Mock Start-Process {
            param(
                [string]$FilePath,
                [object[]]$ArgumentList,
                [string]$WorkingDirectory,
                [switch]$PassThru,
                [string]$Verb
            )
            $startProcessCalls.Add([pscustomobject]@{
                FilePath         = $FilePath
                ArgumentList     = @($ArgumentList)
                WorkingDirectory = $WorkingDirectory
                Verb             = $Verb
            }) | Out-Null
            $process
        }

        $packageResult = [pscustomobject]@{
            OperationArtifactFilePath = $installerPath
            ArtifactStagingDirectory = $workspacePath
            PackageInstallStageDirectory = $workspacePath
            InstallDirectory          = $null
            PackageConfig        = [pscustomobject]@{
                PreferredTargetInstallRootDirectory = $rootPath
                PackageAssignmentInventoryFilePath           = Join-Path (Join-Path $rootPath 'State') 'PackageAssignmentInventory.json'
            }
            Package = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind           = 'runInstaller'
                        targetKind     = 'machinePrerequisite'
                        installerKind  = 'burn'
                        uiMode         = 'quiet'
                        elevation      = 'required'
                        logRelativePath = 'visual-cpp-redist/{timestamp}.log'
                        commandArguments = @('/install', '/quiet', '/norestart', '/log', '{logPath}')
                        successExitCodes = @(0)
                        restartExitCodes = @(3010)
                    }
                }
            }
        }

        $result = Invoke-PackageInstallerProcess -PackageResult $packageResult

        $startProcessCalls.Count | Should -Be 1
        $startProcessCalls[0].Verb | Should -Be 'RunAs'
        $startProcessCalls[0].WorkingDirectory | Should -Be (Split-Path -Parent $installerPath)
        $startProcessCalls[0].ArgumentList[-1].StartsWith('"') | Should -BeTrue
        $startProcessCalls[0].ArgumentList[-1].EndsWith('"') | Should -BeTrue
        $result.TargetKind | Should -Be 'machinePrerequisite'
        $result.Elevation.ShouldElevate | Should -BeTrue
        $result.LogPath | Should -Match '\\Logs\\visual-cpp-redist\\[0-9]{8}-[0-9]{6}\.log$'
    }

    It 'runs NSIS installers from PackageInstallStage and appends target directory argument last without quoting' {
        $rootPath = Join-Path $TestDrive 'nsis installer path with space'
        $packageFilePath = Join-Path $rootPath 'file-stage\npp.8.9.4.Installer.x64.exe'
        $installStageDirectory = Join-Path $rootPath 'install-stage'
        $installDirectory = Join-Path $rootPath 'Inst\Notepad++ Target'
        Write-TestTextFile -Path $packageFilePath -Content 'installer'

        $process = [pscustomobject]@{
            Id       = 43
            ExitCode = 0
        }
        $process | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param([int]$Timeout) $true }
        $process | Add-Member -MemberType ScriptMethod -Name Refresh -Value { }

        $startProcessCalls = New-Object System.Collections.Generic.List[object]
        Mock Test-ProcessElevation { $false }
        Mock Start-Process {
            param(
                [string]$FilePath,
                [object[]]$ArgumentList,
                [string]$WorkingDirectory,
                [switch]$PassThru,
                [string]$Verb
            )
            $startProcessCalls.Add([pscustomobject]@{
                FilePath         = $FilePath
                ArgumentList     = @($ArgumentList)
                WorkingDirectory = $WorkingDirectory
                Verb             = $Verb
            }) | Out-Null
            $process
        }

        $packageResult = [pscustomobject]@{
            PackageId                    = 'NotepadPlusPlus'
            OperationArtifactFilePath    = $packageFilePath
            ArtifactStagingDirectory  = Split-Path -Parent $packageFilePath
            PackageInstallStageDirectory = $installStageDirectory
            InstallDirectory             = $installDirectory
            PackageConfig                = [pscustomobject]@{}
            Package                      = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind = 'nsisInstaller'
                        elevation = 'none'
                        commandArguments = @('/S', '/noUpdater', '/closeRunningNpp')
                        targetDirectoryArgument = [pscustomobject]@{
                            enabled = $true
                            prefix  = '/D='
                        }
                        successExitCodes = @(0)
                        restartExitCodes = @()
                    }
                }
            }
        }

        $result = Invoke-PackageNsisInstallerProcess -PackageResult $packageResult

        $stagedInstallerPath = $packageFilePath
        $startProcessCalls.Count | Should -Be 1
        $startProcessCalls[0].FilePath | Should -Be $stagedInstallerPath
        $startProcessCalls[0].WorkingDirectory | Should -Be (Split-Path -Parent $stagedInstallerPath)
        $startProcessCalls[0].ArgumentList | Should -Be @('/S', '/noUpdater', '/closeRunningNpp', ('/D=' + $installDirectory))
        $startProcessCalls[0].ArgumentList[-1].StartsWith('"') | Should -BeFalse
        Test-Path -LiteralPath $stagedInstallerPath -PathType Leaf | Should -BeTrue
        $result.InstallKind | Should -BeNullOrEmpty
        $result.InstallerKind | Should -Be 'nsis'
    }

    It 'runs MSI installers through system msiexec with staged package and target directory property' {
        $rootPath = Join-Path $TestDrive 'msi installer path with space'
        $packageFilePath = Join-Path $rootPath 'file-stage\7z2601-x64.msi'
        $installStageDirectory = Join-Path $rootPath 'install-stage'
        $installDirectory = Join-Path $rootPath 'Inst\7-Zip Target'
        $msiexecPath = Join-Path $rootPath 'Windows\System32\msiexec.exe'
        Write-TestTextFile -Path $packageFilePath -Content 'msi'
        Write-TestTextFile -Path $msiexecPath -Content 'msiexec'

        $invokeCalls = New-Object System.Collections.Generic.List[object]
        Mock Get-PackageWindowsInstallerExecutablePath { $msiexecPath }
        Mock Invoke-PackageInstallerCommand {
            param($PackageResult, $CommandPath, $CommandArguments, $WorkingDirectory, $TimeoutSec, $SuccessExitCodes, $RestartExitCodes, $TargetKind, $InstallerKind, $UiMode, $LogPath, $ElevationMode, $WindowStyle)
            $invokeCalls.Add([pscustomobject]@{
                CommandPath = $CommandPath
                CommandArguments = @($CommandArguments)
                WorkingDirectory = $WorkingDirectory
                SuccessExitCodes = @($SuccessExitCodes)
                RestartExitCodes = @($RestartExitCodes)
                InstallerKind = $InstallerKind
                ElevationMode = $ElevationMode
            }) | Out-Null
            [pscustomobject]@{ InstallerKind = $InstallerKind }
        }

        $packageResult = [pscustomobject]@{
            PackageId = 'SevenZip'
            OperationArtifactFilePath = $packageFilePath
            ArtifactStagingDirectory = Split-Path -Parent $packageFilePath
            PackageInstallStageDirectory = $installStageDirectory
            InstallDirectory = $installDirectory
            PackageConfig = [pscustomobject]@{}
            Package = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind = 'msiInstaller'
                        elevation = 'required'
                        uiMode = 'silent'
                        timeoutSec = 600
                        commandArguments = @('/qn', '/norestart')
                        targetDirectoryProperty = [pscustomobject]@{
                            enabled = $true
                            name = 'INSTALLDIR'
                        }
                        successExitCodes = @(0, 3010)
                        restartExitCodes = @(3010)
                    }
                }
            }
        }

        $result = Invoke-PackageMsiInstallerProcess -PackageResult $packageResult

        $stagedInstallerPath = $packageFilePath
        $invokeCalls.Count | Should -Be 1
        $invokeCalls[0].CommandPath | Should -Be $msiexecPath
        $invokeCalls[0].WorkingDirectory | Should -Be (Split-Path -Parent $stagedInstallerPath)
        $invokeCalls[0].CommandArguments | Should -Be @('/i', (Format-PackageProcessArgument -Value $stagedInstallerPath), '/qn', '/norestart', (Format-PackageProcessArgument -Value ('INSTALLDIR=' + $installDirectory)))
        $invokeCalls[0].InstallerKind | Should -Be 'msi'
        $invokeCalls[0].ElevationMode | Should -Be 'required'
        $invokeCalls[0].SuccessExitCodes | Should -Contain 3010
        $invokeCalls[0].RestartExitCodes | Should -Contain 3010
        Test-Path -LiteralPath $stagedInstallerPath -PathType Leaf | Should -BeTrue
        $result.InstallerKind | Should -Be 'msi'
    }

    It 'invokes a registry uninstaller and does not append duplicate configured arguments' {
        $uninstallerPath = Join-Path $TestDrive 'uninstall.exe'
        Write-TestTextFile -Path $uninstallerPath -Content 'uninstaller'
        $operation = [pscustomobject]@{
            commandSource = [pscustomobject]@{
                searchLocationId   = 'testRegistry'
                registryValueOrder = @('QuietUninstallString', 'UninstallString')
            }
            commandArguments = @('/S')
            elevation = 'none'
            timeoutSec = 300
            successExitCodes = @(0)
            restartExitCodes = @()
            uiMode = 'silent'
        }
        $packageResult = [pscustomobject]@{
            DefinitionId = 'NotepadPlusPlus'
            InstallDirectory = Join-Path $TestDrive 'npp'
            OperationArtifactFilePath = $null
            ArtifactStagingDirectory = Join-Path $TestDrive 'FileStage'
            PackageInstallStageDirectory = Join-Path $TestDrive 'InstStage'
            PackageConfig = [pscustomobject]@{ Definition = [pscustomobject]@{} }
            Package = [pscustomobject]@{}
        }

        $invokeCalls = New-Object System.Collections.Generic.List[object]
        Mock Get-PackageExistingInstallSearchLocationById { [pscustomobject]@{ id = 'testRegistry' } }
        Mock Resolve-PackageExistingUninstallRegistryCandidate {
            [pscustomobject]@{
                RegistryEntry = [pscustomobject]@{
                    QuietUninstallString = ('"{0}" /S' -f $uninstallerPath)
                    UninstallString = $null
                }
            }
        }
        Mock Invoke-PackageInstallerCommand {
            param($PackageResult, $CommandPath, $CommandArguments, $WorkingDirectory, $TimeoutSec, $SuccessExitCodes, $RestartExitCodes, $TargetKind, $InstallerKind, $UiMode, $LogPath, $ElevationMode, $WindowStyle)
            $invokeCalls.Add([pscustomobject]@{
                CommandPath = $CommandPath
                CommandArguments = @($CommandArguments)
                InstallerKind = $InstallerKind
                ElevationMode = $ElevationMode
            }) | Out-Null
        }

        $result = Invoke-PackageRegistryUninstaller -PackageResult $packageResult -Operation $operation -InstallerKind 'nsis'

        $result.Status | Should -Be 'Invoked'
        $invokeCalls.Count | Should -Be 1
        $invokeCalls[0].CommandPath | Should -Be $uninstallerPath
        $invokeCalls[0].CommandArguments | Should -Be @('/S')
        $invokeCalls[0].InstallerKind | Should -Be 'nsis'
    }

    It 'normalizes MSI uninstall registry commands to msiexec x product code' {
        $rootPath = Join-Path $TestDrive 'msi-uninstall'
        $msiexecPath = Join-Path $rootPath 'Windows\System32\msiexec.exe'
        Write-TestTextFile -Path $msiexecPath -Content 'msiexec'
        $productCode = '{12345678-1234-1234-1234-1234567890AB}'
        $operation = [pscustomobject]@{
            commandSource = [pscustomobject]@{
                searchLocationId = 'sevenZipUninstallRegistry'
                registryValueOrder = @('QuietUninstallString', 'UninstallString')
            }
            commandArguments = @('/qn', '/norestart')
            elevation = 'required'
            timeoutSec = 600
            successExitCodes = @(0, 1605, 3010)
            restartExitCodes = @(3010)
            uiMode = 'silent'
        }
        $packageResult = [pscustomobject]@{
            DefinitionId = 'SevenZip'
            InstallDirectory = Join-Path $rootPath '7-Zip'
            OperationArtifactFilePath = $null
            ArtifactStagingDirectory = Join-Path $rootPath 'FileStage'
            PackageInstallStageDirectory = Join-Path $rootPath 'InstStage'
            PackageConfig = [pscustomobject]@{ Definition = [pscustomobject]@{} }
            Package = [pscustomobject]@{}
        }

        $invokeCalls = New-Object System.Collections.Generic.List[object]
        Mock Get-PackageExistingInstallSearchLocationById { [pscustomobject]@{ id = 'sevenZipUninstallRegistry' } }
        Mock Resolve-PackageExistingUninstallRegistryCandidate {
            [pscustomobject]@{
                RegistryEntry = [pscustomobject]@{
                    Path = 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\' + $productCode
                    KeyName = $productCode
                    QuietUninstallString = "MsiExec.exe /I$productCode"
                    UninstallString = "MsiExec.exe /I$productCode"
                }
            }
        }
        Mock Get-PackageWindowsInstallerExecutablePath { $msiexecPath }
        Mock Invoke-PackageInstallerCommand {
            param($PackageResult, $CommandPath, $CommandArguments, $WorkingDirectory, $TimeoutSec, $SuccessExitCodes, $RestartExitCodes, $TargetKind, $InstallerKind, $UiMode, $LogPath, $ElevationMode, $WindowStyle)
            $invokeCalls.Add([pscustomobject]@{
                CommandPath = $CommandPath
                CommandArguments = @($CommandArguments)
                InstallerKind = $InstallerKind
                ElevationMode = $ElevationMode
            }) | Out-Null
        }

        $result = Invoke-PackageMsiRegistryUninstaller -PackageResult $packageResult -Operation $operation

        $result.Status | Should -Be 'Invoked'
        $result.ProductCode | Should -Be $productCode
        $invokeCalls.Count | Should -Be 1
        $invokeCalls[0].CommandPath | Should -Be $msiexecPath
        $invokeCalls[0].CommandArguments | Should -Be @('/x', $productCode, '/qn', '/norestart')
        $invokeCalls[0].CommandArguments | Should -Not -Contain '/I'
        $invokeCalls[0].InstallerKind | Should -Be 'msi'
        $invokeCalls[0].ElevationMode | Should -Be 'required'
    }

    It 'refuses MSI removal folder deletion when product code cannot be found' {
        $installDirectory = Join-Path $TestDrive 'missing-msi-uninstaller\App'
        Write-TestTextFile -Path (Join-Path $installDirectory '7z.exe') -Content '7z'
        $packageResult = [pscustomobject]@{
            DefinitionId = 'SevenZip'
            InstallDirectory = $installDirectory
            PackageConfig = [pscustomobject]@{
                PreferredTargetInstallRootDirectory = (Join-Path $TestDrive 'missing-msi-uninstaller')
                Definition = [pscustomobject]@{
                    packageOperations = [pscustomobject]@{
                        removed = [pscustomobject]@{
                            operation = [pscustomobject]@{ kind = 'msiUninstaller' }
                        }
                    }
                }
            }
        }

        Mock Invoke-PackageMsiRegistryUninstaller { [pscustomobject]@{ Status = 'CommandNotFound' } }

        { Invoke-PackageRemovedOperation -PackageResult $packageResult } | Should -Throw '*refusing to delete*'
        Test-Path -LiteralPath $installDirectory | Should -BeTrue
    }

    It 'falls back to tracked install directory removal when an installer uninstall command is missing' {
        $installDirectory = Join-Path $TestDrive 'missing-uninstaller-fallback\App'
        Write-TestTextFile -Path (Join-Path $installDirectory 'app.exe') -Content 'app'
        $packageResult = [pscustomobject]@{
            DefinitionId = 'NotepadPlusPlus'
            InstallDirectory = $installDirectory
            PackageConfig = [pscustomobject]@{
                PreferredTargetInstallRootDirectory = (Join-Path $TestDrive 'missing-uninstaller-fallback')
                Definition = [pscustomobject]@{
                    packageOperations = [pscustomobject]@{
                        removed = [pscustomobject]@{
                            operation = [pscustomobject]@{ kind = 'nsisUninstaller' }
                        }
                    }
                }
            }
        }

        Mock Invoke-PackageRegistryUninstaller { [pscustomobject]@{ Status = 'CommandNotFound' } }

        $result = Invoke-PackageRemovedOperation -PackageResult $packageResult

        $result | Should -Be $packageResult
        Test-Path -LiteralPath $installDirectory | Should -BeFalse
    }

    It 'does not fallback to directory deletion when a found uninstaller fails' {
        $installDirectory = Join-Path $TestDrive 'failing-uninstaller\App'
        Write-TestTextFile -Path (Join-Path $installDirectory 'app.exe') -Content 'app'
        $packageResult = [pscustomobject]@{
            DefinitionId = 'NotepadPlusPlus'
            InstallDirectory = $installDirectory
            PackageConfig = [pscustomobject]@{
                PreferredTargetInstallRootDirectory = (Join-Path $TestDrive 'failing-uninstaller')
                Definition = [pscustomobject]@{
                    packageOperations = [pscustomobject]@{
                        removed = [pscustomobject]@{
                            operation = [pscustomobject]@{ kind = 'nsisUninstaller' }
                        }
                    }
                }
            }
        }

        Mock Invoke-PackageRegistryUninstaller { throw 'uninstaller exit failed' }

        { Invoke-PackageRemovedOperation -PackageResult $packageResult } | Should -Throw '*uninstaller exit failed*'
        Test-Path -LiteralPath $installDirectory | Should -BeTrue
    }

}
