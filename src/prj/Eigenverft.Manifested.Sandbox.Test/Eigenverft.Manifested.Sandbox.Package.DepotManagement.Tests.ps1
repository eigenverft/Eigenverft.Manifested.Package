<#
    Eigenverft.Manifested.Sandbox Package - depot management
#>

. "$PSScriptRoot\Eigenverft.Manifested.Sandbox.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Sandbox Package - depot management' -Body {
    function global:New-TestDepotManagementStateConfig {
        param(
            [Parameter(Mandatory = $true)]
            [string]$RootPath,

            [AllowNull()]
            [psobject]$EnvironmentSources = $null,

            [string[]]$SiteCodes = @()
        )

        return [pscustomobject]@{
            ApplicationRootDirectory        = $RootPath
            EnvironmentSources              = $EnvironmentSources
            EffectiveAcquisitionEnvironment = [pscustomobject]@{
                SiteCodes = @($SiteCodes)
            }
        }
    }

    It 'exports depot management commands' {
        $module = Import-Module -Name $script:ModuleManifestPath -Force -PassThru

        foreach ($commandName in @('Get-PackageDepot', 'Add-PackageDepot', 'Add-TeamPackageDepot', 'Set-PackageDepot', 'Remove-PackageDepot')) {
            $module.ExportedCommands.Keys | Should -Contain $commandName
        }
    }

    It 'adds a filesystem depot with safe read-only defaults' {
        $root = Join-Path $TestDrive 'depot-add'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageDepotInventory.json'
        Write-TestJsonDocument -Path $inventoryPath -Document (New-TestDepotInventoryDocument -DefaultPackageDepotDirectory '{applicationRootDirectory}/PkgDepot')

        Mock Get-PackageDepotInventoryPath { $inventoryPath }
        Mock Get-PackageStateConfig {
            New-TestDepotManagementStateConfig -RootPath $root -EnvironmentSources ([pscustomobject]@{
                    defaultPackageDepot = [pscustomobject]@{
                        id       = 'defaultPackageDepot'
                        kind     = 'filesystem'
                        enabled  = $true
                        basePath = (Join-Path $root 'PkgDepot')
                    }
                })
        }

        $result = Add-PackageDepot -DepotId 'teamPackageDepot' -BasePath '\\team-share\PackageDepot' -WarningAction SilentlyContinue
        $info = Read-PackageJsonDocument -Path $inventoryPath
        $source = $info.Document.acquisitionEnvironment.environmentSources.teamPackageDepot

        $result.Action | Should -Be 'Add'
        $source.kind | Should -Be 'filesystem'
        $source.enabled | Should -BeTrue
        $source.searchOrder | Should -Be 400
        $source.basePath | Should -Be '\\team-share\PackageDepot'
        $source.readable | Should -BeTrue
        $source.writable | Should -BeFalse
        $source.mirrorTarget | Should -BeFalse
        $source.ensureExists | Should -BeFalse
        $result.Notes -join "`n" | Should -Match 'read-only'
    }

    It 'adds a team package depot as a writable mirror at searchOrder 150 by default' {
        $root = Join-Path $TestDrive 'depot-add-team'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageDepotInventory.json'
        Write-TestJsonDocument -Path $inventoryPath -Document (New-TestDepotInventoryDocument -DefaultPackageDepotDirectory '{applicationRootDirectory}/PkgDepot')

        Mock Get-PackageDepotInventoryPath { $inventoryPath }
        Mock Get-PackageStateConfig {
            New-TestDepotManagementStateConfig -RootPath $root -EnvironmentSources ([pscustomobject]@{})
        }

        $result = Add-TeamPackageDepot -BasePath '\\team-share\PackageDepot'
        $source = (Read-PackageJsonDocument -Path $inventoryPath).Document.acquisitionEnvironment.environmentSources.teamPackageDepot

        $result.Action | Should -Be 'Add'
        $source.enabled | Should -BeTrue
        $source.searchOrder | Should -Be 150
        $source.basePath | Should -Be '\\team-share\PackageDepot'
        $source.readable | Should -BeTrue
        $source.writable | Should -BeTrue
        $source.mirrorTarget | Should -BeTrue
        $source.ensureExists | Should -BeTrue
    }

    It 'places a package depot after an existing depot when requested' {
        $root = Join-Path $TestDrive 'depot-add-after'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageDepotInventory.json'
        $inventory = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory '{applicationRootDirectory}/PkgDepot' -EnvironmentSources @{
            sitePackageDepot = @{
                kind         = 'filesystem'
                enabled      = $true
                searchOrder  = 200
                basePath     = '\\site-share\PackageDepot'
                readable     = $true
                writable     = $false
                mirrorTarget = $false
                ensureExists = $false
            }
        }
        $inventory.acquisitionEnvironment.environmentSources.defaultPackageDepot.searchOrder = 100
        Write-TestJsonDocument -Path $inventoryPath -Document $inventory

        Mock Get-PackageDepotInventoryPath { $inventoryPath }
        Mock Get-PackageStateConfig {
            New-TestDepotManagementStateConfig -RootPath $root -EnvironmentSources ([pscustomobject]@{})
        }

        Add-PackageDepot -DepotId 'betweenDepot' -BasePath '\\between-share\PackageDepot' -After 'defaultPackageDepot' -WarningAction SilentlyContinue | Out-Null
        $source = (Read-PackageJsonDocument -Path $inventoryPath).Document.acquisitionEnvironment.environmentSources.betweenDepot

        $source.searchOrder | Should -Be 150
    }

    It 'sets a disabled depot path and reports that it remains inactive' {
        $root = Join-Path $TestDrive 'depot-set'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageDepotInventory.json'
        $inventory = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory '{applicationRootDirectory}/PkgDepot' -EnvironmentSources @{
            corpPackageDepot = @{
                kind         = 'filesystem'
                enabled      = $false
                searchOrder  = 300
                basePath     = '\\old-corp\PackageDepot'
                readable     = $true
                writable     = $false
                mirrorTarget = $false
                ensureExists = $false
            }
        }
        Write-TestJsonDocument -Path $inventoryPath -Document $inventory

        Mock Get-PackageDepotInventoryPath { $inventoryPath }
        Mock Get-PackageStateConfig {
            New-TestDepotManagementStateConfig -RootPath $root -EnvironmentSources ([pscustomobject]@{})
        }

        $result = Set-PackageDepot -DepotId 'corpPackageDepot' -BasePath '\\new-corp\PackageDepot' -WarningAction SilentlyContinue
        $source = (Read-PackageJsonDocument -Path $inventoryPath).Document.acquisitionEnvironment.environmentSources.corpPackageDepot

        $source.basePath | Should -Be '\\new-corp\PackageDepot'
        $source.enabled | Should -BeFalse
        $result.After.Enabled | Should -BeFalse
        $result.Notes -join "`n" | Should -Match 'remains disabled'
        $result.Notes -join "`n" | Should -Match '\\\\new-corp\\PackageDepot'
    }

    It 'removes a depot entry without deleting depot files' {
        $root = Join-Path $TestDrive 'depot-remove'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageDepotInventory.json'
        $depotRoot = Join-Path $root 'team-depot'
        $markerPath = Join-Path $depotRoot 'keep.txt'
        Write-TestTextFile -Path $markerPath -Content 'keep'
        $inventory = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory '{applicationRootDirectory}/PkgDepot' -EnvironmentSources @{
            teamPackageDepot = @{
                kind         = 'filesystem'
                enabled      = $true
                searchOrder  = 400
                basePath     = $depotRoot
                readable     = $true
                writable     = $false
                mirrorTarget = $false
                ensureExists = $false
            }
        }
        Write-TestJsonDocument -Path $inventoryPath -Document $inventory

        Mock Get-PackageDepotInventoryPath { $inventoryPath }
        Mock Get-PackageStateConfig {
            New-TestDepotManagementStateConfig -RootPath $root -EnvironmentSources ([pscustomobject]@{
                    teamPackageDepot = [pscustomobject]@{
                        id       = 'teamPackageDepot'
                        kind     = 'filesystem'
                        enabled  = $true
                        basePath = $depotRoot
                    }
                })
        }

        $result = Remove-PackageDepot -DepotId 'teamPackageDepot' -Confirm:$false -WarningAction SilentlyContinue
        $sources = (Read-PackageJsonDocument -Path $inventoryPath).Document.acquisitionEnvironment.environmentSources

        $result.Action | Should -Be 'Remove'
        $sources.PSObject.Properties['teamPackageDepot'] | Should -BeNullOrEmpty
        Test-Path -LiteralPath $markerPath -PathType Leaf | Should -BeTrue
        $result.Notes -join "`n" | Should -Match 'files were not deleted'
    }

    It 'requires force before removing defaultPackageDepot' {
        $root = Join-Path $TestDrive 'depot-remove-default'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageDepotInventory.json'
        Write-TestJsonDocument -Path $inventoryPath -Document (New-TestDepotInventoryDocument -DefaultPackageDepotDirectory '{applicationRootDirectory}/PkgDepot')

        Mock Get-PackageDepotInventoryPath { $inventoryPath }

        { Remove-PackageDepot -DepotId 'defaultPackageDepot' -Confirm:$false } | Should -Throw "*-Force*"
    }
}

