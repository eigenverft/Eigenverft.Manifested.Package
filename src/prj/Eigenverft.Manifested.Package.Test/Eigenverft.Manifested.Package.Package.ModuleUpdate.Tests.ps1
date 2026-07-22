<#
    Eigenverft.Manifested.Package Package - module update
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - module update' -Body {
    BeforeEach {
        $null = Import-Module -Name $script:ModuleManifestPath -Force -PassThru -WarningAction SilentlyContinue
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

    It 'does not install when PSGallery is not newer than the highest relevant local version' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            Mock Initialize-ProxyAccessProfile { }
            Mock Get-PackageModuleVersionState {
                [pscustomobject]@{
                    ExecutingVersion       = [version]'2.0.0'
                    LoadedModules          = @([pscustomobject]@{ Version = [version]'2.0.0' })
                    InstalledModules       = @([pscustomobject]@{ Version = [version]'1.9.0' })
                    HighestRelevantVersion = [version]'2.0.0'
                }
            }
            Mock Find-Module {
                [pscustomobject]@{ Name = 'Eigenverft.Manifested.Package'; Version = [version]'2.0.0' }
            }
            Mock Install-Module { throw 'Install-Module must not run.' }
            Mock Enable-PackageUpdatedModuleVersion { throw 'Activation must not run.' }

            $result = Update-PackageVersion

            $result | Should -Be 'No newer version was found. Installed version: 2.0.0.'
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

    It 'installs the exact newer version and reports it active only after activation verification' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $script:versionStateCallCount = 0
            Mock Initialize-ProxyAccessProfile { }
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
                [pscustomobject]@{ Active = $true; Reason = $null }
            }

            $result = Update-PackageVersion -Scope CurrentUser -Confirm:$false

            $result | Should -Be 'Eigenverft.Manifested.Package was updated from 1.0.0 to 2.0.0. The new version is active for subsequent commands in this session.'
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

    It 'keeps the installed update and reports a restart when activation cannot be proven' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $script:versionStateCallCount = 0
            Mock Initialize-ProxyAccessProfile { }
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

            $result | Should -Be 'Eigenverft.Manifested.Package was updated from 1.5.0 to 2.0.0. This session is still using 1.0.0. Open a new PowerShell session to activate the update.'
        }
    }

    It 'performs discovery but no installation or activation under WhatIf' {
        InModuleScope 'Eigenverft.Manifested.Package' {
            $script:proxySawWhatIf = $null
            Mock Initialize-ProxyAccessProfile { $script:proxySawWhatIf = [bool]$WhatIfPreference }
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

            $result | Should -Be 'A newer version was found. Installed version: 1.0.0. Available version: 2.0.0. No installation was performed.'
            $script:proxySawWhatIf | Should -BeFalse
            Assert-MockCalled Find-Module -Times 1 -Exactly
            Assert-MockCalled Install-Module -Times 0 -Exactly
            Assert-MockCalled Enable-PackageUpdatedModuleVersion -Times 0 -Exactly
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
            Mock Get-Module { @($loadedModule) }
            Mock Get-Command {
                [pscustomobject]@{ Module = $loadedModule }
            }

            $result = Enable-PackageUpdatedModuleVersion `
                -ModuleName 'Eigenverft.Manifested.Package' `
                -Version ([version]'2.0.0') `
                -InstalledModule $installedModule

            $result.Active | Should -BeTrue
            $result.CommandVersion | Should -Be ([version]'2.0.0')
            Assert-MockCalled Import-Module -Times 1 -Exactly -ParameterFilter {
                $Name -eq $manifestPath -and $Force -and $Global -and $DisableNameChecking
            }
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
