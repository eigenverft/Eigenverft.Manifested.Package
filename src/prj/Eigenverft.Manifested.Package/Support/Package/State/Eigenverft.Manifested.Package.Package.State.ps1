<#
    Eigenverft.Manifested.Package.Package.State
#>

function Get-PackageStateDirectorySummary {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Path
    )

    $exists = $false
    $childCount = 0

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $exists = Test-Path -LiteralPath $Path -PathType Container
        if ($exists) {
            $childCount = @(
                Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue
            ).Count
        }
    }

    return [pscustomobject]@{
        Path       = $Path
        Exists     = $exists
        ChildCount = $childCount
    }
}

function Test-PackageStateLeafPath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    return (Test-Path -LiteralPath $Path -PathType Leaf)
}

function Write-PackageStateFormattedView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$State
    )

    $localRootText = if ([string]::IsNullOrWhiteSpace([string]$State.LocalRoot)) { '<none>' } else { [string]$State.LocalRoot }
    Write-Host ''
    Write-Host ("Package state (local root: {0})" -f $localRootText)
    Write-Host ("  Assigned packages: {0}  |  Recent operations: {1}" -f $State.PackageRecordCount, $State.OperationRecordCount)

    if (@($State.PackageRecords).Count -gt 0) {
        Write-Host ''
        Write-Host 'Assigned packages'
        @($State.PackageRecords) |
            Select-Object -Property @(
                @{ Name = 'DefinitionId'; Expression = { $_.DefinitionId } }
                @{ Name = 'Version'; Expression = { $_.CurrentVersion } }
                @{ Name = 'Ownership'; Expression = { $_.OwnershipKind } }
                @{ Name = 'InstallSlot'; Expression = { $_.InstallSlotId } }
                @{ Name = 'PathReg'; Expression = {
                        if ($_.PathRegistration -and $_.PathRegistration.Status) { [string]$_.PathRegistration.Status }
                        else { '' }
                    }
                }
                @{ Name = 'InstallDir'; Expression = {
                        if ($_.InstallDirectoryExists) { 'present' }
                        elseif (-not [string]::IsNullOrWhiteSpace([string]$_.InstallDirectory)) { 'missing' }
                        else { '' }
                    }
                }
            ) |
            Format-Table -AutoSize |
            Out-String -Width 4096 |
            ForEach-Object { $_.TrimEnd() } |
            Write-Host
    }

    if (@($State.OperationRecords).Count -gt 0) {
        Write-Host ''
        Write-Host 'Recent operations'
        @($State.OperationRecords) |
            Select-Object -Property @(
                @{ Name = 'DefinitionId'; Expression = { if ($_.PSObject.Properties['definitionId']) { $_.definitionId } else { $null } } }
                @{ Name = 'DesiredState'; Expression = { if ($_.PSObject.Properties['desiredState']) { $_.desiredState } else { $null } } }
                @{ Name = 'Status'; Expression = { if ($_.PSObject.Properties['status']) { $_.status } else { $null } } }
                @{ Name = 'Version'; Expression = { if ($_.PSObject.Properties['packageVersion']) { $_.packageVersion } else { $null } } }
                @{ Name = 'CompletedUtc'; Expression = { if ($_.PSObject.Properties['completedAtUtc']) { $_.completedAtUtc } else { $null } } }
            ) |
            Format-Table -AutoSize |
            Out-String -Width 4096 |
            ForEach-Object { $_.TrimEnd() } |
            Write-Host
    }

    Write-Host ''
    Write-Host 'Key paths'
    @(
        [pscustomobject]@{ Name = 'PackageConfig'; Path = $State.PackageConfigPath; Exists = $State.PackageConfigExists }
        [pscustomobject]@{ Name = 'AssignmentInventory'; Path = $State.PackageAssignmentInventoryPath; Exists = $State.PackageAssignmentInventoryExists }
        [pscustomobject]@{ Name = 'OperationHistory'; Path = $State.PackageOperationHistoryPath; Exists = $State.PackageOperationHistoryExists }
        [pscustomobject]@{ Name = 'InstalledRoot'; Path = $State.Directories.Installed.Path; Exists = $State.Directories.Installed.Exists }
        [pscustomobject]@{ Name = 'Shims'; Path = $State.Directories.Shims.Path; Exists = $State.Directories.Shims.Exists }
    ) |
        Select-Object Name, Exists, Path |
        Format-Table -AutoSize |
        Out-String -Width 4096 |
        ForEach-Object { $_.TrimEnd() } |
        Write-Host

    Write-Host 'Use Get-PackageState -Raw for full inventories and configuration.'
    Write-Host ''
}

function Select-PackageStateOwnershipRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Record
    )

    $installDirectory = [string]$Record.installDirectory
    $installDirectoryExists = $false
    if (-not [string]::IsNullOrWhiteSpace($installDirectory)) {
        $installDirectoryExists = Test-Path -LiteralPath $installDirectory -PathType Container
    }

    $pathRegistration = $null
    if ($Record.PSObject.Properties['pathRegistration'] -and $null -ne $Record.pathRegistration) {
        $sourcePath = [string]$Record.pathRegistration.sourcePath
        $registeredPath = [string]$Record.pathRegistration.registeredPath
        $registeredPathExists = $false
        if (-not [string]::IsNullOrWhiteSpace($registeredPath)) {
            $registeredPathExists = Test-Path -LiteralPath $registeredPath -PathType Container
        }

        $pathRegistration = [pscustomobject]@{
            Mode                 = $Record.pathRegistration.mode
            SourceKind           = $Record.pathRegistration.sourceKind
            SourceValue          = $Record.pathRegistration.sourceValue
            SourceValues         = @($Record.pathRegistration.sourceValues)
            SourcePath           = $sourcePath
            SourcePathExists     = Test-PackageStateLeafPath -Path $sourcePath
            RegisteredPath       = $registeredPath
            RegisteredPathExists = $registeredPathExists
            Status               = $Record.pathRegistration.status
        }
    }

    $dependencyInstallSlotIds = if ($Record.PSObject.Properties['dependencyInstallSlotIds'] -and $null -ne $Record.dependencyInstallSlotIds) {
        @($Record.dependencyInstallSlotIds | ForEach-Object { [string]$_ })
    }
    else {
        @()
    }

    $candidatePath = if ($Record.PSObject.Properties['definitionCandidatePath']) { [string]$Record.definitionCandidatePath } else { $null }
    $assignedSnapshotPath = if ($Record.PSObject.Properties['definitionAssignedSnapshotPath']) { [string]$Record.definitionAssignedSnapshotPath } else { $null }

    return [pscustomobject]@{
        InstallSlotId          = $Record.installSlotId
        DefinitionId           = $Record.definitionId
        DefinitionPublisherId  = if ($Record.PSObject.Properties['definitionPublisherId']) { $Record.definitionPublisherId } else { $null }
        DefinitionPublisherName = if ($Record.PSObject.Properties['definitionPublisherName']) { $Record.definitionPublisherName } else { $null }
        DefinitionRevision     = if ($Record.PSObject.Properties['definitionRevision']) { $Record.definitionRevision } else { $null }
        DefinitionPublishedAtUtc = if ($Record.PSObject.Properties['definitionPublishedAtUtc']) { $Record.definitionPublishedAtUtc } else { $null }
        DefinitionEndpointName = if ($Record.PSObject.Properties['definitionEndpointName']) { $Record.definitionEndpointName } else { $null }
        DefinitionSourceKind   = if ($Record.PSObject.Properties['definitionSourceKind']) { $Record.definitionSourceKind } else { $null }
        DefinitionSourcePath   = $Record.definitionSourcePath
        DefinitionSourceHash   = if ($Record.PSObject.Properties['definitionSourceHash']) { $Record.definitionSourceHash } else { $null }
        DefinitionCandidatePath = $candidatePath
        DefinitionCandidateHash = if ($Record.PSObject.Properties['definitionCandidateHash']) { $Record.definitionCandidateHash } else { $null }
        DefinitionCandidateExists = Test-PackageStateLeafPath -Path $candidatePath
        DefinitionAssignedSnapshotPath = $assignedSnapshotPath
        DefinitionAssignedSnapshotHash = if ($Record.PSObject.Properties['definitionAssignedSnapshotHash']) { $Record.definitionAssignedSnapshotHash } else { $null }
        DefinitionAssignedSnapshotExists = Test-PackageStateLeafPath -Path $assignedSnapshotPath
        DefinitionResolvedAtUtc = if ($Record.PSObject.Properties['definitionResolvedAtUtc']) { $Record.definitionResolvedAtUtc } else { $null }
        ReleaseTrack           = $Record.releaseTrack
        ArtifactDistributionVariant = $Record.artifactDistributionVariant
        CurrentReleaseId       = $Record.currentReleaseId
        CurrentVersion         = $Record.currentVersion
        InstallDirectory       = $installDirectory
        InstallDirectoryExists = $installDirectoryExists
        OwnershipKind          = $Record.ownershipKind
        PathRegistration       = $pathRegistration
        DependencyInstallSlotIds = @($dependencyInstallSlotIds)
        UpdatedAtUtc           = $Record.updatedAtUtc
    }
}

function Get-PackageStateConfig {
    [CmdletBinding()]
    param()

    $globalDocumentInfo = Read-PackageJsonDocument -Path (Get-PackageConfigPath)
    Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalDocumentInfo

    $packageGlobalConfig = $globalDocumentInfo.Document.package
    $applicationRootDirectory = Resolve-PackageApplicationRootDirectory -PackageConfiguration $packageGlobalConfig
    $endpointInventoryInfo = Get-PackageEndpointInventoryInfo
    $trustInventoryInfo = Get-PackageTrustInventoryInfo
    $depotInventoryInfo = Get-PackageDepotInventoryInfo
    $effectiveAcquisitionEnvironment = Resolve-PackageEffectiveAcquisitionEnvironment -PackageConfiguration $packageGlobalConfig -DepotInventoryInfo $depotInventoryInfo

    $preferredTargetInstallDirectory = if ($packageGlobalConfig.PSObject.Properties['preferredTargetInstallDirectory'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.preferredTargetInstallDirectory)) {
        Resolve-PackageConfiguredPath -PathValue ([string]$packageGlobalConfig.preferredTargetInstallDirectory) -ApplicationRootDirectory $applicationRootDirectory
    }
    else {
        Resolve-PackageConfiguredPath -PathValue 'Inst' -ApplicationRootDirectory $applicationRootDirectory
    }

    $packageInventoryFilePath = if ($packageGlobalConfig.packageState.PSObject.Properties['inventoryFilePath'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.packageState.inventoryFilePath)) {
        Resolve-PackageConfiguredPath -PathValue ([string]$packageGlobalConfig.packageState.inventoryFilePath) -ApplicationRootDirectory $applicationRootDirectory
    }
    else {
        Resolve-PackageConfiguredPath -PathValue 'State\PackageAssignmentInventory.json' -ApplicationRootDirectory $applicationRootDirectory
    }

    $packageOperationHistoryFilePath = if ($packageGlobalConfig.packageState.PSObject.Properties['operationHistoryFilePath'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.packageState.operationHistoryFilePath)) {
        Resolve-PackageConfiguredPath -PathValue ([string]$packageGlobalConfig.packageState.operationHistoryFilePath) -ApplicationRootDirectory $applicationRootDirectory
    }
    else {
        Resolve-PackageConfiguredPath -PathValue 'State\PackageOperationHistory.json' -ApplicationRootDirectory $applicationRootDirectory
    }

    $localEndpointRoot = if ($packageGlobalConfig.PSObject.Properties['localEndpointRoot'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.localEndpointRoot)) {
        Resolve-PackageConfiguredPath -PathValue ([string]$packageGlobalConfig.localEndpointRoot) -ApplicationRootDirectory $applicationRootDirectory
    }
    else {
        Resolve-PackageConfiguredPath -PathValue 'PkgEndpoint' -ApplicationRootDirectory $applicationRootDirectory
    }

    $shimDirectory = if ($packageGlobalConfig.PSObject.Properties['shimDirectory'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.shimDirectory)) {
        Resolve-PackageConfiguredPath -PathValue ([string]$packageGlobalConfig.shimDirectory) -ApplicationRootDirectory $applicationRootDirectory
    }
    else {
        Resolve-PackageConfiguredPath -PathValue 'Shims' -ApplicationRootDirectory $applicationRootDirectory
    }

    return [pscustomobject]@{
        PackageConfigPath                   = $globalDocumentInfo.Path
        PackageConfigDocument               = $packageGlobalConfig
        ApplicationRootDirectory            = $applicationRootDirectory
        LocalEndpointInventoryPath         = Get-PackageLocalEndpointInventoryPath
        EndpointInventoryPath              = $endpointInventoryInfo.Path
        EndpointInventory                  = $endpointInventoryInfo.Document
        EndpointInventoryInfo              = $endpointInventoryInfo
        LocalTrustInventoryPath            = Get-PackageLocalTrustInventoryPath
        TrustInventoryPath                 = $trustInventoryInfo.Path
        TrustInventory                     = $trustInventoryInfo.Document
        TrustInventoryInfo                 = $trustInventoryInfo
        LocalDepotInventoryPath             = Get-PackageLocalDepotInventoryPath
        DepotInventoryPath                  = $effectiveAcquisitionEnvironment.DepotInventoryPath
        DepotInventory                      = $depotInventoryInfo.Document
        DepotInventoryInfo                  = $depotInventoryInfo
        EffectiveAcquisitionEnvironment     = $effectiveAcquisitionEnvironment
        PackageFileStagingRootDirectory       = $effectiveAcquisitionEnvironment.Stores.PackageFileStagingDirectory
        PackageInstallStageRootDirectory      = $effectiveAcquisitionEnvironment.Stores.PackageInstallStageDirectory
        DefaultPackageDepotDirectory        = $effectiveAcquisitionEnvironment.Stores.DefaultPackageDepotDirectory
        PreferredTargetInstallRootDirectory = $preferredTargetInstallDirectory
        LocalEndpointRoot                 = $localEndpointRoot
        ShimDirectory                       = $shimDirectory
        PackageAssignmentInventoryFilePath            = $packageInventoryFilePath
        PackageOperationHistoryFilePath     = $packageOperationHistoryFilePath
        EnvironmentSources                  = $effectiveAcquisitionEnvironment.EnvironmentSources
    }
}
