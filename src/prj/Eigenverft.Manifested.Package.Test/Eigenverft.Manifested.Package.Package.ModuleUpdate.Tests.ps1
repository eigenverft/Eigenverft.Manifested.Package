<#
    Eigenverft.Manifested.Package Package - module update
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - module update' -Body {
    BeforeEach {
        $null = Import-Module -Name $script:ModuleManifestPath -Force -PassThru -DisableNameChecking
        $Global:ProxyParamsPrepareSession = $null
        $Global:ProxyParamsInstallModule = @{}
    }

    AfterEach {
        Remove-Variable -Scope Global -Name ProxyParamsPrepareSession -Force -ErrorAction SilentlyContinue
        Remove-Variable -Scope Global -Name ProxyParamsInstallModule -Force -ErrorAction SilentlyContinue
    }

    It 'decodes the embedded 64-second package version without loading Drydock' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $result = Convert-64SecPowershellVersionToDateTime `
                -VersionBuild 1 `
                -VersionMajor 20264 `
                -VersionMinor 10435

            $result.VersionFull | Should -Be '1.20264.10435'
            $result.ComputedDateTime.ToString('o') | Should -Be '2026-07-21T21:50:56.0000000Z'
            $result.ComputedDateTime.Kind | Should -Be ([datetimekind]::Utc)
            Get-Module -Name 'Eigenverft.Manifested.Drydock' | Should -BeNullOrEmpty
        }
    }

    It 'formats an encoded package version with its stable UTC build time' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            Format-PackageVersionWithBuildDate -Version ([version]'1.20264.10744') |
                Should -Be '1.20264.10744 (built 2026-07-22 03:20:32 UTC)'
        }
    }

    It 'full-resets exactly the four internal configuration files and preserves package state and depot contents' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $previousLocalAppData = $env:LOCALAPPDATA
            try {
                $env:LOCALAPPDATA = Join-Path $TestDrive 'LocalAppData'
                $moduleBase = Join-Path $TestDrive 'Modules\Eigenverft.Manifested.Package\2.0.0'
                $sourceDirectory = Join-Path $moduleBase 'Configuration\Internal'
                $applicationRoot = Join-Path $env:LOCALAPPDATA 'Programs\Evf.Package'
                $targetDirectory = Join-Path $applicationRoot 'Configuration\Internal'
                $stateDirectory = Join-Path $applicationRoot 'State'
                $depotDirectory = Join-Path $applicationRoot 'Depot\evf\PowerShell7'
                $null = New-Item -ItemType Directory -Path $sourceDirectory -Force
                $null = New-Item -ItemType Directory -Path $targetDirectory -Force
                $null = New-Item -ItemType Directory -Path $stateDirectory -Force
                $null = New-Item -ItemType Directory -Path $depotDirectory -Force

                $configurationFileNames = @(
                    'PackageConfig.json'
                    'PackageDepotInventory.json'
                    'PackageEndpointInventory.json'
                    'PackageTrustInventory.json'
                )
                foreach ($fileName in $configurationFileNames) {
                    $sourceDocument = if ($fileName -eq 'PackageConfig.json') {
                        '{"package":{"applicationRootDirectory":"%LOCALAPPDATA%/Programs/Evf.Package"},"generation":"new"}'
                    }
                    else {
                        '{"generation":"new"}'
                    }
                    Set-Content -LiteralPath (Join-Path $sourceDirectory $fileName) -Value $sourceDocument -Encoding UTF8
                    Set-Content -LiteralPath (Join-Path $targetDirectory $fileName) -Value '{"generation":"old"}' -Encoding UTF8
                }

                $markerPath = Join-Path $stateDirectory 'PackageLocalEnvironment.json'
                $assignmentPath = Join-Path $stateDirectory 'PackageAssignmentInventory.json'
                $historyPath = Join-Path $stateDirectory 'PackageOperationHistory.json'
                $depotPayloadPath = Join-Path $depotDirectory 'PowerShell-7.6.4-win-x64.zip'
                Set-Content -LiteralPath $markerPath -Value '{"marker":"old"}' -Encoding UTF8
                Set-Content -LiteralPath $assignmentPath -Value 'assignment-preserved' -Encoding UTF8
                Set-Content -LiteralPath $historyPath -Value 'history-preserved' -Encoding UTF8
                Set-Content -LiteralPath $depotPayloadPath -Value 'depot-preserved' -Encoding UTF8

                $result = Reset-PackageInternalConfiguration -SourceModule ([pscustomobject]@{
                    ModuleBase = $moduleBase
                    Path = Join-Path $moduleBase 'Eigenverft.Manifested.Package.psd1'
                })

                $result.ConfigurationFiles | Should -Be $configurationFileNames
                $result.MarkerRemoved | Should -BeTrue
                $result.SourceModuleBase | Should -Be ([System.IO.Path]::GetFullPath($moduleBase))
                Test-Path -LiteralPath $markerPath | Should -BeFalse
                foreach ($fileName in $configurationFileNames) {
                    ((Get-Content -LiteralPath (Join-Path $targetDirectory $fileName) -Raw | ConvertFrom-Json).generation) |
                        Should -Be 'new'
                    ((Get-Content -LiteralPath (Join-Path $result.BackupDirectory $fileName) -Raw | ConvertFrom-Json).generation) |
                        Should -Be 'old'
                }
                ((Get-Content -LiteralPath (Join-Path $result.BackupDirectory 'PackageLocalEnvironment.json') -Raw | ConvertFrom-Json).marker) |
                    Should -Be 'old'
                Get-Content -LiteralPath $assignmentPath -Raw | Should -Match '^assignment-preserved'
                Get-Content -LiteralPath $historyPath -Raw | Should -Match '^history-preserved'
                Get-Content -LiteralPath $depotPayloadPath -Raw | Should -Match '^depot-preserved'
            }
            finally {
                $env:LOCALAPPDATA = $previousLocalAppData
            }
        }
    }

    It 'restores every changed configuration file when a full-reset replacement fails' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $previousLocalAppData = $env:LOCALAPPDATA
            try {
                $env:LOCALAPPDATA = Join-Path $TestDrive 'RollbackLocalAppData'
                $moduleBase = Join-Path $TestDrive 'RollbackModule'
                $sourceDirectory = Join-Path $moduleBase 'Configuration\Internal'
                $applicationRoot = Join-Path $env:LOCALAPPDATA 'Programs\Evf.Package'
                $targetDirectory = Join-Path $applicationRoot 'Configuration\Internal'
                $null = New-Item -ItemType Directory -Path $sourceDirectory -Force
                $null = New-Item -ItemType Directory -Path $targetDirectory -Force

                $configurationFileNames = @(
                    'PackageConfig.json'
                    'PackageDepotInventory.json'
                    'PackageEndpointInventory.json'
                    'PackageTrustInventory.json'
                )
                foreach ($fileName in $configurationFileNames) {
                    $sourceDocument = if ($fileName -eq 'PackageConfig.json') {
                        '{"package":{"applicationRootDirectory":"%LOCALAPPDATA%/Programs/Evf.Package"},"generation":"new"}'
                    }
                    else {
                        '{"generation":"new"}'
                    }
                    Set-Content -LiteralPath (Join-Path $sourceDirectory $fileName) -Value $sourceDocument -Encoding UTF8
                    Set-Content -LiteralPath (Join-Path $targetDirectory $fileName) -Value '{"generation":"old"}' -Encoding UTF8
                }

                $script:fullResetMoveCount = 0
                Mock Move-Item {
                    $script:fullResetMoveCount++
                    if ($script:fullResetMoveCount -eq 2) {
                        throw 'synthetic replacement failure'
                    }

                    Microsoft.PowerShell.Management\Move-Item `
                        -LiteralPath $LiteralPath `
                        -Destination $Destination `
                        -Force `
                        -ErrorAction Stop
                }

                {
                    Reset-PackageInternalConfiguration -SourceModule ([pscustomobject]@{
                        ModuleBase = $moduleBase
                        Path = Join-Path $moduleBase 'Eigenverft.Manifested.Package.psd1'
                    })
                } | Should -Throw '*previous local configuration was restored*'

                foreach ($fileName in $configurationFileNames) {
                    ((Get-Content -LiteralPath (Join-Path $targetDirectory $fileName) -Raw | ConvertFrom-Json).generation) |
                        Should -Be 'old'
                }
            }
            finally {
                $env:LOCALAPPDATA = $previousLocalAppData
            }
        }
    }

    It 'does not install when PSGallery is not newer than the highest relevant local version' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            Mock Initialize-ProxyAccessProfile { }
            Mock Write-StandardMessage { }
            Mock Get-PackageModuleVersionState {
                [pscustomobject]@{
                    ExecutingVersion       = [version]'1.20264.10744'
                    LoadedModules          = @([pscustomobject]@{ Version = [version]'1.20264.10744' })
                    InstalledModules       = @([pscustomobject]@{ Version = [version]'1.20264.10435' })
                    HighestRelevantVersion = [version]'1.20264.10744'
                }
            }
            Mock Find-Module {
                [pscustomobject]@{ Name = 'Eigenverft.Manifested.Package'; Version = [version]'1.20264.10744' }
            }
            Mock Install-Module { throw 'Install-Module must not run.' }
            Mock Enable-PackageUpdatedModuleVersion { throw 'Activation must not run.' }

            $result = Update-PackageVersion

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-StandardMessage -Times 1 -Exactly -ParameterFilter {
                $Message -eq 'No newer version was found. Installed version: 1.20264.10744 (built 2026-07-22 03:20:32 UTC).' -and
                $Level -eq 'INF'
            }
            Assert-MockCalled Initialize-ProxyAccessProfile -Times 1 -Exactly -ParameterFilter {
                $TestUri.AbsoluteUri -eq 'https://www.powershellgallery.com/api/v2/' -and $SuppressStatus
            }
            Assert-MockCalled Find-Module -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'Eigenverft.Manifested.Package' -and $Repository -eq 'PSGallery'
            }
            Assert-MockCalled Install-Module -Times 0 -Exactly
            Assert-MockCalled Enable-PackageUpdatedModuleVersion -Times 0 -Exactly
        }
    }

    It 'full-resets from the executing module when no newer version is available' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            Mock Initialize-ProxyAccessProfile { }
            Mock Write-StandardMessage { }
            Mock Get-PackageModuleVersionState {
                [pscustomobject]@{
                    ExecutingVersion       = [version]'2.0.0'
                    LoadedModules          = @([pscustomobject]@{ Version = [version]'2.0.0' })
                    InstalledModules       = @([pscustomobject]@{ Version = [version]'2.0.0' })
                    HighestRelevantVersion = [version]'2.0.0'
                }
            }
            Mock Find-Module {
                [pscustomobject]@{ Name = 'Eigenverft.Manifested.Package'; Version = [version]'2.0.0' }
            }
            Mock Install-Module { throw 'Install-Module must not run.' }
            Mock Enable-PackageUpdatedModuleVersion { throw 'Activation must not run.' }
            Mock Reset-PackageInternalConfiguration {
                [pscustomobject]@{
                    BackupDirectory = 'C:\local\Configuration\Backup\FullReset-current'
                    ConfigurationFiles = @('PackageConfig.json', 'PackageDepotInventory.json', 'PackageEndpointInventory.json', 'PackageTrustInventory.json')
                    MarkerRemoved = $false
                }
            }

            $result = Update-PackageVersion -FullReset

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-StandardMessage -Times 1 -Exactly -ParameterFilter {
                $Message -eq 'No newer version was found. Installed version: 2.0.0. FullReset will continue with defaults from the currently executing module.' -and
                $Level -eq 'INF'
            }
            Assert-MockCalled Install-Module -Times 0 -Exactly
            Assert-MockCalled Enable-PackageUpdatedModuleVersion -Times 0 -Exactly
            Assert-MockCalled Reset-PackageInternalConfiguration -Times 1 -Exactly -ParameterFilter {
                $null -ne $SourceModule -and
                $SourceModule.Name -eq 'Eigenverft.Manifested.Package'
            }
            Assert-MockCalled Write-StandardMessage -Times 1 -Exactly -ParameterFilter {
                $Message -like 'FullReset is replacing PackageConfig.json, PackageDepotInventory.json, PackageEndpointInventory.json, PackageTrustInventory.json with defaults from Eigenverft.Manifested.Package *' -and
                $Level -eq 'INF'
            }
            Assert-MockCalled Write-StandardMessage -Times 1 -Exactly -ParameterFilter {
                $Message -eq "FullReset completed for 4 configuration files. Backup: 'C:\local\Configuration\Backup\FullReset-current'. No local environment marker existed; it will be created on the next package operation." -and
                $Level -eq 'INF'
            }
        }
    }

    It 'previews a current-version full reset without changing configuration under WhatIf' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            Mock Initialize-ProxyAccessProfile { }
            Mock Write-StandardMessage { }
            Mock Get-PackageModuleVersionState {
                [pscustomobject]@{
                    ExecutingVersion       = [version]'2.0.0'
                    LoadedModules          = @([pscustomobject]@{ Version = [version]'2.0.0' })
                    InstalledModules       = @([pscustomobject]@{ Version = [version]'2.0.0' })
                    HighestRelevantVersion = [version]'2.0.0'
                }
            }
            Mock Find-Module {
                [pscustomobject]@{ Name = 'Eigenverft.Manifested.Package'; Version = [version]'2.0.0' }
            }
            Mock Install-Module { throw 'Install-Module must not run.' }
            Mock Enable-PackageUpdatedModuleVersion { throw 'Activation must not run.' }
            Mock Reset-PackageInternalConfiguration { throw 'FullReset must not run.' }

            $result = Update-PackageVersion -FullReset -WhatIf

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-StandardMessage -Times 1 -Exactly -ParameterFilter {
                $Message -eq 'No newer version was found. Installed version: 2.0.0. FullReset was requested, but no configuration reset was performed.' -and
                $Level -eq 'INF'
            }
            Assert-MockCalled Install-Module -Times 0 -Exactly
            Assert-MockCalled Enable-PackageUpdatedModuleVersion -Times 0 -Exactly
            Assert-MockCalled Reset-PackageInternalConfiguration -Times 0 -Exactly
        }
    }

    It 'installs the exact newer version and reports the expected same-session transition' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $script:versionStateCallCount = 0
            Mock Initialize-ProxyAccessProfile { }
            Mock Write-StandardMessage { }
            Mock Get-PackageModuleVersionState {
                $script:versionStateCallCount++
                if ($script:versionStateCallCount -eq 1) {
                    return [pscustomobject]@{
                        ExecutingVersion       = [version]'1.0.0'
                        LoadedModules          = @([pscustomobject]@{ Version = [version]'1.0.0' })
                        InstalledModules       = @([pscustomobject]@{ Version = [version]'1.0.0' })
                        HighestRelevantVersion = [version]'1.0.0'
                    }
                }

                return [pscustomobject]@{
                    ExecutingVersion       = [version]'1.0.0'
                    LoadedModules          = @([pscustomobject]@{ Version = [version]'1.0.0' })
                    InstalledModules       = @([pscustomobject]@{
                        Name = 'Eigenverft.Manifested.Package'
                        Version = [version]'2.0.0'
                        Path = 'C:\modules\Eigenverft.Manifested.Package\2.0.0\Eigenverft.Manifested.Package.psd1'
                    })
                    HighestRelevantVersion = [version]'2.0.0'
                }
            }
            Mock Find-Module {
                [pscustomobject]@{ Name = 'Eigenverft.Manifested.Package'; Version = [version]'2.0.0' }
            }
            Mock Install-Module { }
            Mock Test-PackageModuleInstallationScope {
                [pscustomobject]@{ Known = $true; Matches = $true; ScopeRoot = 'C:\modules' }
            }
            Mock Enable-PackageUpdatedModuleVersion {
                [pscustomobject]@{
                    Active = $true
                    Reason = $null
                    CommandVersion = [version]'2.0.0'
                    PreviousModuleStateLoaded = $true
                }
            }

            $result = Update-PackageVersion -Scope CurrentUser -Confirm:$false

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-StandardMessage -Times 1 -Exactly -ParameterFilter {
                $Message -eq 'Eigenverft.Manifested.Package was updated from 1.0.0 to 2.0.0. Subsequent commands use the new version. The previous module version remains loaded; open a new PowerShell session to clear it.' -and
                $Level -eq 'INF'
            }
            Assert-MockCalled Install-Module -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'Eigenverft.Manifested.Package' -and
                $Repository -eq 'PSGallery' -and
                $Scope -eq 'CurrentUser' -and
                $RequiredVersion -eq [version]'2.0.0' -and
                $Force -and
                $AllowClobber -and
                $PassThru
            }
            Assert-MockCalled Test-PackageModuleInstallationScope -Times 1 -Exactly -ParameterFilter { $Scope -eq 'CurrentUser' }
            Assert-MockCalled Enable-PackageUpdatedModuleVersion -Times 1 -Exactly -ParameterFilter {
                $ModuleName -eq 'Eigenverft.Manifested.Package' -and $Version -eq [version]'2.0.0'
            }
        }
    }

    It 'reports the full reset source, preservation boundary, backup, and marker behavior after an update' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $script:versionStateCallCount = 0
            Mock Initialize-ProxyAccessProfile { }
            Mock Write-StandardMessage { }
            Mock Get-PackageModuleVersionState {
                $script:versionStateCallCount++
                if ($script:versionStateCallCount -eq 1) {
                    return [pscustomobject]@{
                        ExecutingVersion       = [version]'1.0.0'
                        LoadedModules          = @([pscustomobject]@{ Version = [version]'1.0.0' })
                        InstalledModules       = @([pscustomobject]@{ Version = [version]'1.0.0' })
                        HighestRelevantVersion = [version]'1.0.0'
                    }
                }

                return [pscustomobject]@{
                    ExecutingVersion       = [version]'1.0.0'
                    LoadedModules          = @([pscustomobject]@{ Version = [version]'1.0.0' })
                    InstalledModules       = @([pscustomobject]@{
                        Name = 'Eigenverft.Manifested.Package'
                        Version = [version]'2.0.0'
                        Path = 'C:\modules\Eigenverft.Manifested.Package\2.0.0\Eigenverft.Manifested.Package.psd1'
                        ModuleBase = 'C:\modules\Eigenverft.Manifested.Package\2.0.0'
                    })
                    HighestRelevantVersion = [version]'2.0.0'
                }
            }
            Mock Find-Module {
                [pscustomobject]@{ Name = 'Eigenverft.Manifested.Package'; Version = [version]'2.0.0' }
            }
            Mock Install-Module { }
            Mock Test-PackageModuleInstallationScope {
                [pscustomobject]@{ Known = $true; Matches = $true; ScopeRoot = 'C:\modules' }
            }
            Mock Enable-PackageUpdatedModuleVersion {
                [pscustomobject]@{
                    Active = $true
                    Reason = $null
                    CommandVersion = [version]'2.0.0'
                    PreviousModuleStateLoaded = $false
                }
            }
            Mock Reset-PackageInternalConfiguration {
                [pscustomobject]@{
                    BackupDirectory = 'C:\local\Configuration\Backup\FullReset-test'
                    ConfigurationFiles = @('PackageConfig.json', 'PackageDepotInventory.json', 'PackageEndpointInventory.json', 'PackageTrustInventory.json')
                    MarkerRemoved = $true
                }
            }

            $result = Update-PackageVersion -Scope CurrentUser -FullReset -Confirm:$false

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Reset-PackageInternalConfiguration -Times 1 -Exactly -ParameterFilter {
                $SourceModule.Version -eq [version]'2.0.0' -and
                $SourceModule.ModuleBase -eq 'C:\modules\Eigenverft.Manifested.Package\2.0.0'
            }
            Assert-MockCalled Write-StandardMessage -Times 1 -Exactly -ParameterFilter {
                $Message -eq 'FullReset is replacing PackageConfig.json, PackageDepotInventory.json, PackageEndpointInventory.json, PackageTrustInventory.json with defaults from Eigenverft.Manifested.Package 2.0.0. Local customizations in these files will be replaced; depot contents, installed packages, assignment inventory, and operation history are preserved.' -and
                $Level -eq 'INF'
            }
            Assert-MockCalled Write-StandardMessage -Times 1 -Exactly -ParameterFilter {
                $Message -eq "FullReset completed for 4 configuration files. Backup: 'C:\local\Configuration\Backup\FullReset-test'. The local environment marker was removed and will be recreated on the next package operation." -and
                $Level -eq 'INF'
            }
            Assert-MockCalled Write-StandardMessage -Times 1 -Exactly -ParameterFilter {
                $Message -eq 'Eigenverft.Manifested.Package was updated from 1.0.0 to 2.0.0. The new version is active for subsequent commands in this session.' -and
                $Level -eq 'INF'
            }
        }
    }

    It 'keeps the installed update and reports a restart when activation cannot be proven' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $script:versionStateCallCount = 0
            Mock Initialize-ProxyAccessProfile { }
            Mock Write-StandardMessage { }
            Mock Get-PackageModuleVersionState {
                $script:versionStateCallCount++
                if ($script:versionStateCallCount -eq 1) {
                    return [pscustomobject]@{
                        ExecutingVersion       = [version]'1.0.0'
                        LoadedModules          = @([pscustomobject]@{ Version = [version]'1.0.0' })
                        InstalledModules       = @([pscustomobject]@{ Version = [version]'1.5.0' })
                        HighestRelevantVersion = [version]'1.5.0'
                    }
                }

                return [pscustomobject]@{
                    ExecutingVersion       = [version]'1.0.0'
                    LoadedModules          = @([pscustomobject]@{ Version = [version]'1.0.0' })
                    InstalledModules       = @([pscustomobject]@{ Version = [version]'2.0.0'; Path = 'C:\module.psd1' })
                    HighestRelevantVersion = [version]'2.0.0'
                }
            }
            Mock Find-Module {
                [pscustomobject]@{ Name = 'Eigenverft.Manifested.Package'; Version = [version]'2.0.0' }
            }
            Mock Install-Module { }
            Mock Test-PackageModuleInstallationScope {
                [pscustomobject]@{ Known = $true; Matches = $true; ScopeRoot = 'C:\modules' }
            }
            Mock Enable-PackageUpdatedModuleVersion {
                [pscustomobject]@{ Active = $false; Reason = 'unsafe reload' }
            }

            $result = Update-PackageVersion -Confirm:$false

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-StandardMessage -Times 1 -Exactly -ParameterFilter {
                $Message -eq 'Eigenverft.Manifested.Package was updated from 1.5.0 to 2.0.0. This session is still using 1.0.0. Open a new PowerShell session to activate the update.' -and
                $Level -eq 'INF'
            }
        }
    }

    It 'performs discovery but no installation or activation under WhatIf' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $script:proxySawWhatIf = $null
            Mock Initialize-ProxyAccessProfile { $script:proxySawWhatIf = [bool]$WhatIfPreference }
            Mock Write-StandardMessage { }
            Mock Get-PackageModuleVersionState {
                [pscustomobject]@{
                    ExecutingVersion       = [version]'1.0.0'
                    LoadedModules          = @([pscustomobject]@{ Version = [version]'1.0.0' })
                    InstalledModules       = @([pscustomobject]@{ Version = [version]'1.0.0' })
                    HighestRelevantVersion = [version]'1.0.0'
                }
            }
            Mock Find-Module {
                [pscustomobject]@{ Name = 'Eigenverft.Manifested.Package'; Version = [version]'2.0.0' }
            }
            Mock Install-Module { throw 'Install-Module must not run.' }
            Mock Enable-PackageUpdatedModuleVersion { throw 'Activation must not run.' }

            $result = Update-PackageVersion -WhatIf

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-StandardMessage -Times 1 -Exactly -ParameterFilter {
                $Message -eq 'A newer version was found. Installed version: 1.0.0. Available version: 2.0.0. No installation was performed.' -and
                $Level -eq 'INF'
            }
            $script:proxySawWhatIf | Should -BeFalse
            Assert-MockCalled Find-Module -Times 1 -Exactly
            Assert-MockCalled Install-Module -Times 0 -Exactly
            Assert-MockCalled Enable-PackageUpdatedModuleVersion -Times 0 -Exactly
        }
    }

    It 'previews both installation and full reset without changing either under WhatIf' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            Mock Initialize-ProxyAccessProfile { }
            Mock Write-StandardMessage { }
            Mock Get-PackageModuleVersionState {
                [pscustomobject]@{
                    ExecutingVersion       = [version]'1.0.0'
                    LoadedModules          = @([pscustomobject]@{ Version = [version]'1.0.0' })
                    InstalledModules       = @([pscustomobject]@{ Version = [version]'1.0.0' })
                    HighestRelevantVersion = [version]'1.0.0'
                }
            }
            Mock Find-Module {
                [pscustomobject]@{ Name = 'Eigenverft.Manifested.Package'; Version = [version]'2.0.0' }
            }
            Mock Install-Module { throw 'Install-Module must not run.' }
            Mock Enable-PackageUpdatedModuleVersion { throw 'Activation must not run.' }
            Mock Reset-PackageInternalConfiguration { throw 'FullReset must not run.' }

            $result = Update-PackageVersion -FullReset -WhatIf

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-StandardMessage -Times 1 -Exactly -ParameterFilter {
                $Message -eq 'A newer version was found. Installed version: 1.0.0. Available version: 2.0.0. No installation was performed. No configuration reset was performed.' -and
                $Level -eq 'INF'
            }
            Assert-MockCalled Install-Module -Times 0 -Exactly
            Assert-MockCalled Enable-PackageUpdatedModuleVersion -Times 0 -Exactly
            Assert-MockCalled Reset-PackageInternalConfiguration -Times 0 -Exactly
        }
    }

    It 'filters Find-Module and Install-Module parameters independently for legacy command surfaces' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            function Test-LegacyFindModule {
                [CmdletBinding()]
                param([string]$Name, [string]$Repository, [uri]$Proxy)
            }
            function Test-LegacyInstallModule {
                [CmdletBinding()]
                param([string]$Name, [string]$Repository, [string]$Scope, [switch]$Force, [uri]$Proxy)
            }

            try {
                $candidate = @{
                    Name = 'Eigenverft.Manifested.Package'
                    Repository = 'PSGallery'
                    Scope = 'CurrentUser'
                    Force = $true
                    AllowClobber = $true
                    RequiredVersion = [version]'2.0.0'
                    PassThru = $true
                    Proxy = [uri]'http://proxy.example:8080'
                    ProxyCredential = [pscredential]::Empty
                    ErrorAction = 'Stop'
                }

                $findParameters = Select-PackageCommandParameters `
                    -Command (Get-Command Test-LegacyFindModule) `
                    -CandidateParameters $candidate `
                    -RequiredParameters @('Name', 'Repository')
                $installParameters = Select-PackageCommandParameters `
                    -Command (Get-Command Test-LegacyInstallModule) `
                    -CandidateParameters $candidate `
                    -RequiredParameters @('Name', 'Repository', 'Scope')

                @($findParameters.Keys | Sort-Object) | Should -Be @('ErrorAction', 'Name', 'Proxy', 'Repository')
                @($installParameters.Keys | Sort-Object) | Should -Be @('ErrorAction', 'Force', 'Name', 'Proxy', 'Repository', 'Scope')
                $installParameters.ContainsKey('AllowClobber') | Should -BeFalse
                $installParameters.ContainsKey('RequiredVersion') | Should -BeFalse
                $installParameters.ContainsKey('PassThru') | Should -BeFalse
                $findParameters.ContainsKey('Scope') | Should -BeFalse
                $findParameters.ContainsKey('ProxyCredential') | Should -BeFalse
            }
            finally {
                Remove-Item -LiteralPath Function:\Test-LegacyFindModule -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath Function:\Test-LegacyInstallModule -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'distinguishes the requested CurrentUser module scope from another visible module path' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $shellModuleDirectory = if ($PSVersionTable.PSEdition -eq 'Desktop') {
                'WindowsPowerShell\Modules'
            }
            else {
                'PowerShell\Modules'
            }
            $currentUserRoot = Join-Path `
                -Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)) `
                -ChildPath $shellModuleDirectory
            $insideModule = [pscustomobject]@{
                Path = Join-Path $currentUserRoot 'Eigenverft.Manifested.Package\2.0.0\Eigenverft.Manifested.Package.psd1'
            }
            $outsideModule = [pscustomobject]@{
                Path = Join-Path $TestDrive 'OtherScope\Eigenverft.Manifested.Package\2.0.0\Eigenverft.Manifested.Package.psd1'
            }

            $insideResult = Test-PackageModuleInstallationScope -Module $insideModule -Scope CurrentUser
            $outsideResult = Test-PackageModuleInstallationScope -Module $outsideModule -Scope CurrentUser

            $insideResult.Known | Should -BeTrue
            $insideResult.Matches | Should -BeTrue
            $outsideResult.Known | Should -BeTrue
            $outsideResult.Matches | Should -BeFalse
        }
    }

    It 'verifies activation by manifest import and ModuleBase when the loaded Path is the root psm1' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $moduleBase = 'C:\modules\Eigenverft.Manifested.Package\2.0.0'
            $manifestPath = Join-Path $moduleBase 'Eigenverft.Manifested.Package.psd1'
            $rootModulePath = Join-Path $moduleBase 'Eigenverft.Manifested.Package.psm1'
            $loadedModule = [pscustomobject]@{
                Name = 'Eigenverft.Manifested.Package'
                Version = [version]'2.0.0'
                Path = $rootModulePath
                ModuleBase = $moduleBase
            }
            $installedModule = [pscustomobject]@{
                Name = 'Eigenverft.Manifested.Package'
                Version = [version]'2.0.0'
                Path = $manifestPath
                ModuleBase = $moduleBase
            }

            Mock Test-Path { $true }
            Mock Import-Module { }
            $previousModule = [pscustomobject]@{
                Name = 'Eigenverft.Manifested.Package'
                Version = [version]'1.0.0'
                Path = 'C:\modules\Eigenverft.Manifested.Package\1.0.0\Eigenverft.Manifested.Package.psm1'
                ModuleBase = 'C:\modules\Eigenverft.Manifested.Package\1.0.0'
            }
            $script:getLoadedModuleCallCount = 0
            Mock Get-Module {
                $script:getLoadedModuleCallCount++
                if ($script:getLoadedModuleCallCount -eq 1) {
                    return @($previousModule)
                }

                return @($loadedModule)
            }
            Mock Get-Command {
                [pscustomobject]@{ Module = $loadedModule }
            }

            $result = Enable-PackageUpdatedModuleVersion `
                -ModuleName 'Eigenverft.Manifested.Package' `
                -Version ([version]'2.0.0') `
                -InstalledModule $installedModule

            $result.Active | Should -BeTrue
            $result.CommandVersion | Should -Be ([version]'2.0.0')
            $result.PreviousModuleStateLoaded | Should -BeFalse
            Assert-MockCalled Import-Module -Times 1 -Exactly -ParameterFilter {
                $Name -eq $manifestPath -and $Force -and $Global -and $DisableNameChecking
            }
        }
    }

    It 'recognizes global activation while the executing module still resolves its private old command' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $oldModuleBase = 'C:\modules\Eigenverft.Manifested.Package\1.0.0'
            $newModuleBase = 'C:\modules\Eigenverft.Manifested.Package\2.0.0'
            $oldModule = [pscustomobject]@{
                Name = 'Eigenverft.Manifested.Package'
                Version = [version]'1.0.0'
                Path = Join-Path $oldModuleBase 'Eigenverft.Manifested.Package.psm1'
                ModuleBase = $oldModuleBase
            }
            $newModule = [pscustomobject]@{
                Name = 'Eigenverft.Manifested.Package'
                Version = [version]'2.0.0'
                Path = Join-Path $newModuleBase 'Eigenverft.Manifested.Package.psm1'
                ModuleBase = $newModuleBase
            }
            $installedModule = [pscustomobject]@{
                Name = 'Eigenverft.Manifested.Package'
                Version = [version]'2.0.0'
                Path = Join-Path $newModuleBase 'Eigenverft.Manifested.Package.psd1'
                ModuleBase = $newModuleBase
            }

            $script:getLoadedModuleCallCount = 0
            Mock Test-Path { $true }
            Mock Import-Module { }
            Mock Get-Module {
                $script:getLoadedModuleCallCount++
                if ($script:getLoadedModuleCallCount -eq 1) {
                    return @($oldModule)
                }

                return @($oldModule, $newModule)
            }
            Mock Get-Command {
                [pscustomobject]@{ Module = $oldModule }
            }

            $result = Enable-PackageUpdatedModuleVersion `
                -ModuleName 'Eigenverft.Manifested.Package' `
                -Version ([version]'2.0.0') `
                -InstalledModule $installedModule

            $result.Active | Should -BeTrue
            $result.CommandVersion | Should -Be ([version]'2.0.0')
            $result.PreviousModuleStateLoaded | Should -BeTrue
        }
    }

    It 'fails closed when Install-Module does not make the requested version visible' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $script:versionStateCallCount = 0
            Mock Initialize-ProxyAccessProfile { }
            Mock Get-PackageModuleVersionState {
                $script:versionStateCallCount++
                [pscustomobject]@{
                    ExecutingVersion       = [version]'1.0.0'
                    LoadedModules          = @([pscustomobject]@{ Version = [version]'1.0.0' })
                    InstalledModules       = @([pscustomobject]@{ Version = [version]'1.0.0' })
                    HighestRelevantVersion = [version]'1.0.0'
                }
            }
            Mock Find-Module {
                [pscustomobject]@{ Name = 'Eigenverft.Manifested.Package'; Version = [version]'2.0.0' }
            }
            Mock Install-Module { }
            Mock Enable-PackageUpdatedModuleVersion { throw 'Activation must not run.' }

            { Update-PackageVersion -Confirm:$false } |
                Should -Throw "*version '2.0.0' was not visible through Get-Module -ListAvailable*"
            Assert-MockCalled Enable-PackageUpdatedModuleVersion -Times 0 -Exactly
        }
    }
}
