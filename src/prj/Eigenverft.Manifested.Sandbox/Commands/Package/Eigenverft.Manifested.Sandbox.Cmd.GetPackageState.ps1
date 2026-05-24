<#
    Public package state command surface.
#>

function Get-PackageState {
    [CmdletBinding()]
    param(
        [switch]$Raw
    )

    $config = Get-PackageStateConfig
    $packageInventory = Get-PackageInventory -PackageConfig $config
    $operationHistory = Get-PackageOperationHistory -PackageConfig $config
    $sourceInventoryInfo = $config.SourceInventoryInfo
    $endpointInventoryInfo = $config.EndpointInventoryInfo
    $depotInventoryInfo = $config.DepotInventoryInfo

    $directories = [pscustomobject]@{
        Installed           = Get-PackageStateDirectorySummary -Path $config.PreferredTargetInstallRootDirectory
        PackageFileStaging  = Get-PackageStateDirectorySummary -Path $config.PackageFileStagingRootDirectory
        PackageInstallStage = Get-PackageStateDirectorySummary -Path $config.PackageInstallStageRootDirectory
        DefaultPackageDepot = Get-PackageStateDirectorySummary -Path $config.DefaultPackageDepotDirectory
        LocalEndpointRoot = Get-PackageStateDirectorySummary -Path $config.LocalEndpointRoot
        Shims               = Get-PackageStateDirectorySummary -Path $config.ShimDirectory
    }

    if ($Raw.IsPresent) {
        return [pscustomobject]@{
            Config                     = $config
            PackageAssignmentInventory = $packageInventory
            PackageOperationHistory    = $operationHistory
            EndpointInventory = $endpointInventoryInfo
            DepotInventory   = $depotInventoryInfo
            SourceInventory  = $sourceInventoryInfo
            Directories      = $directories
        }
    }

    $localRoot = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$config.PackageAssignmentInventoryFilePath)) {
        $localRoot = Get-PackageRootFromInventoryPath -PackageAssignmentInventoryFilePath $config.PackageAssignmentInventoryFilePath
    }

    $packageRecords = @($packageInventory.Records)
    $operationRecords = @($operationHistory.Records)

    return [pscustomobject]@{
        LocalRoot                 = $localRoot
        ApplicationRootDirectory  = $config.ApplicationRootDirectory
        PackageConfigPath    = $config.PackageConfigPath
        PackageConfigExists  = Test-PackageStateLeafPath -Path $config.PackageConfigPath
        LocalEndpointInventoryPath = $config.LocalEndpointInventoryPath
        LocalEndpointInventoryExists = Test-PackageStateLeafPath -Path $config.LocalEndpointInventoryPath
        EndpointInventoryPath    = $endpointInventoryInfo.Path
        EndpointInventoryExists  = [bool]$endpointInventoryInfo.Exists
        LocalDepotInventoryPath   = $config.LocalDepotInventoryPath
        LocalDepotInventoryExists = Test-PackageStateLeafPath -Path $config.LocalDepotInventoryPath
        DepotInventoryPath        = $depotInventoryInfo.Path
        DepotInventoryExists      = [bool]$depotInventoryInfo.Exists
        LocalEndpointRoot       = $config.LocalEndpointRoot
        PackageAssignmentInventoryPath      = $packageInventory.Path
        PackageAssignmentInventoryExists    = Test-PackageStateLeafPath -Path $packageInventory.Path
        PackageOperationHistoryPath      = $operationHistory.Path
        PackageOperationHistoryExists    = Test-PackageStateLeafPath -Path $operationHistory.Path
        SourceInventoryPath       = $sourceInventoryInfo.Path
        SourceInventoryExists     = [bool]$sourceInventoryInfo.Exists
        PackageRecordCount        = $packageRecords.Count
        OperationRecordCount      = $operationRecords.Count
        PackageRecords            = @($packageRecords | ForEach-Object { Select-PackageStateOwnershipRecord -Record $_ })
        OperationRecords          = @($operationRecords)
        Directories               = $directories
    }
}
