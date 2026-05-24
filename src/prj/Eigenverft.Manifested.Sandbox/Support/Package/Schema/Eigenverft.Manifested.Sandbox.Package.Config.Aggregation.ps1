<#
    Eigenverft.Manifested.Sandbox.Package.Config - environment resolution, Get-PackageConfig, path resolution, New-PackageResult.
    Loaded by Eigenverft.Manifested.Sandbox.Package.Config.ps1.
#>

function Resolve-PackageEnvironmentSources {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$EnvironmentSources,

        [AllowNull()]
        [string[]]$ActiveSiteCodes = @(),

        [AllowNull()]
        [string]$ApplicationRootDirectory
    )

    $resolvedSources = [ordered]@{}

    if ($EnvironmentSources) {
        foreach ($property in @($EnvironmentSources.PSObject.Properties)) {
            $sourceValue = $property.Value
            $enabled = $true
            if ($sourceValue.PSObject.Properties['enabled']) {
                $enabled = [bool]$sourceValue.enabled
            }
            if (-not $enabled) {
                continue
            }
            if ($sourceValue.PSObject.Properties['priority']) {
                throw "Package environment source '$($property.Name)' still uses retired property 'priority'. Use 'searchOrder'."
            }
            if (-not $sourceValue.PSObject.Properties['searchOrder']) {
                throw "Package environment source '$($property.Name)' is missing searchOrder."
            }
            Assert-PackageEnvironmentSourceCapabilities -SourceId $property.Name -SourceValue $sourceValue -DocumentPath 'effective acquisition environment'

            $sourceSiteCodes = @()
            if ($sourceValue.PSObject.Properties['siteCodes'] -and $null -ne $sourceValue.siteCodes) {
                $sourceSiteCodes = @($sourceValue.siteCodes | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
            if ($sourceSiteCodes.Count -gt 0) {
                $matchesActiveSiteCode = $false
                foreach ($sourceSiteCode in $sourceSiteCodes) {
                    foreach ($activeSiteCode in @($ActiveSiteCodes)) {
                        if ([string]::Equals([string]$sourceSiteCode, [string]$activeSiteCode, [System.StringComparison]::OrdinalIgnoreCase)) {
                            $matchesActiveSiteCode = $true
                            break
                        }
                    }
                    if ($matchesActiveSiteCode) {
                        break
                    }
                }
                if (-not $matchesActiveSiteCode) {
                    continue
                }
            }

            $resolvedSource = [ordered]@{
                id       = $property.Name
                kind     = if ($sourceValue.PSObject.Properties['kind']) { [string]$sourceValue.kind } else { $null }
                enabled  = $true
                searchOrder = if ($sourceValue.PSObject.Properties['searchOrder']) { [int]$sourceValue.searchOrder } else { 1000 }
                readable = if ($sourceValue.PSObject.Properties['readable']) { [bool]$sourceValue.readable } else { $true }
                writable = if ($sourceValue.PSObject.Properties['writable']) { [bool]$sourceValue.writable } else { $false }
                mirrorTarget = if ($sourceValue.PSObject.Properties['mirrorTarget']) { [bool]$sourceValue.mirrorTarget } else { $false }
                ensureExists = if ($sourceValue.PSObject.Properties['ensureExists']) { [bool]$sourceValue.ensureExists } else { $false }
            }

            if ($sourceValue.PSObject.Properties['baseUri'] -and -not [string]::IsNullOrWhiteSpace([string]$sourceValue.baseUri)) {
                $resolvedSource.baseUri = [string]$sourceValue.baseUri
            }
            if ($sourceValue.PSObject.Properties['basePath'] -and -not [string]::IsNullOrWhiteSpace([string]$sourceValue.basePath)) {
                $resolvedSource.basePath = if (-not [string]::IsNullOrWhiteSpace($ApplicationRootDirectory)) {
                    Resolve-PackageConfiguredPath -PathValue ([string]$sourceValue.basePath) -ApplicationRootDirectory $ApplicationRootDirectory
                }
                else {
                    Resolve-PackagePathValue -PathValue ([string]$sourceValue.basePath)
                }
            }
            if ($sourceSiteCodes.Count -gt 0) {
                $resolvedSource.siteCodes = @($sourceSiteCodes)
            }

            $resolvedSources[$property.Name] = $resolvedSource
        }
    }

    return (ConvertTo-PackageObject -InputObject $resolvedSources)
}

function Resolve-PackageEffectiveAcquisitionEnvironment {
<#
.SYNOPSIS
Materializes the effective Package acquisition environment.

.DESCRIPTION
Starts from the shipped acquisition-environment config, applies optional
inventory global and site overlays, resolves concrete store paths, and returns
the internal effective environment model used by later source planning.

.PARAMETER PackageConfiguration
The shipped Package config object.

.PARAMETER SourceInventoryInfo
The optional external source-inventory document info.

.PARAMETER DepotInventoryInfo
The internal depot-inventory document info.

.EXAMPLE
Resolve-PackageEffectiveAcquisitionEnvironment -PackageConfiguration $global -SourceInventoryInfo $inventory -DepotInventoryInfo $depotInventory
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfiguration,

        [Parameter(Mandatory = $true)]
        [psobject]$SourceInventoryInfo,

        [Parameter(Mandatory = $true)]
        [psobject]$DepotInventoryInfo
    )

    $mergedAcquisitionEnvironment = ConvertTo-PackageMergeValue -InputObject $PackageConfiguration.acquisitionEnvironment
    $activeSiteCodes = @(Get-PackageActiveSiteCodes)

    if ($DepotInventoryInfo -and $DepotInventoryInfo.Document) {
        $depotOverlay = Get-PackageInventoryAcquisitionOverlay -InventoryNode $DepotInventoryInfo.Document
        if ($depotOverlay) {
            $mergedAcquisitionEnvironment = Merge-PackageValues -BaseValue $mergedAcquisitionEnvironment -OverlayValue (ConvertTo-PackageMergeValue -InputObject $depotOverlay)
        }
    }

    if ($SourceInventoryInfo -and $SourceInventoryInfo.Exists -and $SourceInventoryInfo.Document) {
        $inventoryGlobal = if ($SourceInventoryInfo.Document.PSObject.Properties['global']) { $SourceInventoryInfo.Document.global } else { $null }
        if ($inventoryGlobal) {
            $inventoryGlobalOverlay = Get-PackageInventoryAcquisitionOverlay -InventoryNode $inventoryGlobal
            if ($inventoryGlobalOverlay) {
                $mergedAcquisitionEnvironment = Merge-PackageValues -BaseValue $mergedAcquisitionEnvironment -OverlayValue (ConvertTo-PackageMergeValue -InputObject $inventoryGlobalOverlay)
            }
        }

        if ($activeSiteCodes.Count -gt 0 -and $SourceInventoryInfo.Document.PSObject.Properties['sites']) {
            foreach ($activeSiteCode in @($activeSiteCodes)) {
                foreach ($siteProperty in @($SourceInventoryInfo.Document.sites.PSObject.Properties)) {
                    if ([string]::Equals([string]$siteProperty.Name, [string]$activeSiteCode, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $siteOverlay = Get-PackageInventoryAcquisitionOverlay -InventoryNode $siteProperty.Value
                        if ($siteOverlay) {
                            $mergedAcquisitionEnvironment = Merge-PackageValues -BaseValue $mergedAcquisitionEnvironment -OverlayValue (ConvertTo-PackageMergeValue -InputObject $siteOverlay)
                        }
                        break
                    }
                }
            }
        }
    }

    $acquisitionEnvironment = ConvertTo-PackageObject -InputObject $mergedAcquisitionEnvironment
    $applicationRootDirectory = Resolve-PackageApplicationRootDirectory -PackageConfiguration $PackageConfiguration

    $packageFileStagingDirectory = if ($acquisitionEnvironment.stores.PSObject.Properties['packageFileStagingDirectory'] -and
        -not [string]::IsNullOrWhiteSpace([string]$acquisitionEnvironment.stores.packageFileStagingDirectory)) {
        Resolve-PackageConfiguredPath -PathValue ([string]$acquisitionEnvironment.stores.packageFileStagingDirectory) -ApplicationRootDirectory $applicationRootDirectory
    }
    else {
        Resolve-PackageConfiguredPath -PathValue 'FileStage' -ApplicationRootDirectory $applicationRootDirectory
    }

    $packageInstallStageDirectory = if ($acquisitionEnvironment.stores.PSObject.Properties['packageInstallStageDirectory'] -and
        -not [string]::IsNullOrWhiteSpace([string]$acquisitionEnvironment.stores.packageInstallStageDirectory)) {
        Resolve-PackageConfiguredPath -PathValue ([string]$acquisitionEnvironment.stores.packageInstallStageDirectory) -ApplicationRootDirectory $applicationRootDirectory
    }
    else {
        Resolve-PackageConfiguredPath -PathValue 'InstStage' -ApplicationRootDirectory $applicationRootDirectory
    }

    $allowFallback = $true
    if ($acquisitionEnvironment.defaults.PSObject.Properties['allowFallback']) {
        $allowFallback = [bool]$acquisitionEnvironment.defaults.allowFallback
    }
    $depotDistributionMode = 'packageFocused'
    if ($acquisitionEnvironment.defaults.PSObject.Properties['depotDistributionMode'] -and
        -not [string]::IsNullOrWhiteSpace([string]$acquisitionEnvironment.defaults.depotDistributionMode)) {
        $depotDistributionMode = [string]$acquisitionEnvironment.defaults.depotDistributionMode
    }
    if ($depotDistributionMode -notin @('packageFocused', 'depotFocused', 'disabled')) {
        throw "Effective package acquisition environment defines unsupported defaults.depotDistributionMode '$depotDistributionMode'. Use 'packageFocused', 'depotFocused', or 'disabled'."
    }

    $configuredEnvironmentSources = $null
    if ($acquisitionEnvironment.PSObject.Properties['environmentSources']) {
        $configuredEnvironmentSources = $acquisitionEnvironment.environmentSources
    }

    $environmentSources = Resolve-PackageEnvironmentSources -EnvironmentSources $configuredEnvironmentSources -ActiveSiteCodes $activeSiteCodes -ApplicationRootDirectory $applicationRootDirectory
    $defaultPackageDepotDirectory = $null
    if ($environmentSources -and $environmentSources.PSObject.Properties['defaultPackageDepot']) {
        $defaultPackageDepot = $environmentSources.defaultPackageDepot
        if ([string]::Equals([string]$defaultPackageDepot.kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase) -and
            $defaultPackageDepot.PSObject.Properties['basePath'] -and
            -not [string]::IsNullOrWhiteSpace([string]$defaultPackageDepot.basePath)) {
            $defaultPackageDepotDirectory = [string]$defaultPackageDepot.basePath
        }
    }

    return [pscustomobject]@{
        SourceInventoryPath = $SourceInventoryInfo.Path
        DepotInventoryPath  = $DepotInventoryInfo.Path
        SiteCode            = (@($activeSiteCodes) -join ';')
        SiteCodes           = @($activeSiteCodes)
        ApplicationRootDirectory = $applicationRootDirectory
        Stores              = [pscustomobject]@{
            PackageFileStagingDirectory  = $packageFileStagingDirectory
            PackageInstallStageDirectory = $packageInstallStageDirectory
            DefaultPackageDepotDirectory = $defaultPackageDepotDirectory
        }
        Defaults            = [pscustomobject]@{
            AllowFallback          = $allowFallback
            DepotDistributionMode  = $depotDistributionMode
        }
        EnvironmentSources  = $environmentSources
    }
}

function Get-PackageInventoryAcquisitionOverlay {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$InventoryNode
    )

    if (-not $InventoryNode) {
        return $null
    }

    if ($InventoryNode.PSObject.Properties['acquisitionEnvironment'] -and $null -ne $InventoryNode.acquisitionEnvironment) {
        return $InventoryNode.acquisitionEnvironment
    }

    return $InventoryNode
}

function Get-PackageConfig {
<#
.SYNOPSIS
Loads the effective Package config for a definition id.

.DESCRIPTION
Loads the shipped Package config document, applies the optional external
source inventory, resolves one live or assigned-snapshot Package definition,
validates the current schema, resolves runtime context and Package roots, and returns the
combined config object for command orchestration.

.PARAMETER DefinitionId
The Package definition id. Definition resolution matches the JSON definitionId, not the
file name.

.PARAMETER PublisherId
Optional. When set, only definitions from this trusted publisher are considered.

.EXAMPLE
Get-PackageConfig -DefinitionId VSCodeRuntime
#>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$PublisherId = $null,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [ValidateSet('Assigned', 'Removed')]
        [string]$DesiredState = 'Assigned'
    )

    $globalDocumentInfo = Read-PackageJsonDocument -Path (Get-PackageConfigPath)
    Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalDocumentInfo

    $packageGlobalConfig = $globalDocumentInfo.Document.package
    $applicationRootDirectory = Resolve-PackageApplicationRootDirectory -PackageConfiguration $packageGlobalConfig
    $localEndpointRoot = if ($packageGlobalConfig.PSObject.Properties['localEndpointRoot'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.localEndpointRoot)) {
        Resolve-PackageConfiguredPath -PathValue ([string]$packageGlobalConfig.localEndpointRoot) -ApplicationRootDirectory $applicationRootDirectory
    }
    else {
        Resolve-PackageConfiguredPath -PathValue 'PkgEndpoint' -ApplicationRootDirectory $applicationRootDirectory
    }

    $endpointDefaults = $packageGlobalConfig.endpointEnvironment.defaults
    $endpointMaterializationMode = 'packageFocused'
    if ($endpointDefaults.PSObject.Properties['endpointMaterializationMode'] -and
        -not [string]::IsNullOrWhiteSpace([string]$endpointDefaults.endpointMaterializationMode)) {
        $endpointMaterializationMode = [string]$endpointDefaults.endpointMaterializationMode
    }

    if ($endpointMaterializationMode -notin @('packageFocused', 'endpointFocused')) {
        throw "Package config '$($globalDocumentInfo.Path)' defines unsupported endpointEnvironment.defaults.endpointMaterializationMode '$endpointMaterializationMode'. Use 'packageFocused' or 'endpointFocused'."
    }

    $definitionPublisherConflictMode = 'fail'
    if ($endpointDefaults.PSObject.Properties['definitionPublisherConflictMode'] -and
        -not [string]::IsNullOrWhiteSpace([string]$endpointDefaults.definitionPublisherConflictMode)) {
        $definitionPublisherConflictMode = [string]$endpointDefaults.definitionPublisherConflictMode
    }
    if ($definitionPublisherConflictMode -notin @('fail', 'warnFirst', 'first', 'warnLast', 'last')) {
        throw "Package config '$($globalDocumentInfo.Path)' defines unsupported definitionPublisherConflictMode '$definitionPublisherConflictMode'. Use 'fail', 'warnFirst', 'first', 'warnLast', or 'last'."
    }

    $packageInventoryFilePath = if ($packageGlobalConfig.packageState.PSObject.Properties['inventoryFilePath'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.packageState.inventoryFilePath)) {
        Resolve-PackageConfiguredPath -PathValue ([string]$packageGlobalConfig.packageState.inventoryFilePath) -ApplicationRootDirectory $applicationRootDirectory
    }
    else {
        Resolve-PackageConfiguredPath -PathValue 'State\PackageAssignmentInventory.json' -ApplicationRootDirectory $applicationRootDirectory
    }

    $definitionReference = $null
    if ([string]::Equals($DesiredState, 'Removed', [System.StringComparison]::OrdinalIgnoreCase)) {
        try {
            $definitionReference = Resolve-PackageDefinitionSnapshotReference -PublisherId $PublisherId -DefinitionId $DefinitionId -PackageAssignmentInventoryFilePath $packageInventoryFilePath -LiveResolutionError $null
            Write-PackageExecutionMessage -Message ("[STATE] Using assigned definition snapshot '{0}' for removed desired state." -f $definitionReference.DefinitionPath)
        }
        catch {
            try {
                $definitionReference = Resolve-PackageDefinitionReference -PublisherId $PublisherId -DefinitionId $DefinitionId -ApplicationRootDirectory $applicationRootDirectory -LocalEndpointRoot $localEndpointRoot -EndpointMaterializationMode $endpointMaterializationMode -DefinitionPublisherConflictMode $definitionPublisherConflictMode
            }
            catch {
                $definitionReference = Resolve-PackageDefinitionSnapshotReference -PublisherId $PublisherId -DefinitionId $DefinitionId -PackageAssignmentInventoryFilePath $packageInventoryFilePath -LiveResolutionError $_.Exception.Message
                Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Live package definition from endpoints could not be resolved for definition '{0}'; using local assigned definition snapshot '{1}' for removal. Live error: {2}" -f $DefinitionId, $definitionReference.DefinitionPath, $_.Exception.Message)
            }
        }
    }
    else {
        $definitionReference = Resolve-PackageDefinitionReference -PublisherId $PublisherId -DefinitionId $DefinitionId -ApplicationRootDirectory $applicationRootDirectory -LocalEndpointRoot $localEndpointRoot -EndpointMaterializationMode $endpointMaterializationMode -DefinitionPublisherConflictMode $definitionPublisherConflictMode
    }

    $definitionDocumentInfo = Read-PackageJsonDocument -Path $definitionReference.DefinitionPath
    Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionDocumentInfo -DefinitionId $DefinitionId -PublisherId $PublisherId

    $endpointInventoryInfo = Get-PackageEndpointInventoryInfo
    $publisherInventoryInfo = Get-PackagePublisherInventoryInfo
    $depotInventoryInfo = Get-PackageDepotInventoryInfo
    $sourceInventoryInfo = Get-PackageSourceInventoryInfo -ApplicationRootDirectory $applicationRootDirectory

    $runtimeContext = Get-PackageRuntimeContext
    $definition = $definitionDocumentInfo.Document
    $effectiveAcquisitionEnvironment = Resolve-PackageEffectiveAcquisitionEnvironment -PackageConfiguration $packageGlobalConfig -SourceInventoryInfo $sourceInventoryInfo -DepotInventoryInfo $depotInventoryInfo

    $selectionReleaseTrack = 'none'
    if ($packageGlobalConfig.selectionDefaults.PSObject.Properties['releaseTrack'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.selectionDefaults.releaseTrack)) {
        $selectionReleaseTrack = [string]$packageGlobalConfig.selectionDefaults.releaseTrack
    }

    $selectionStrategy = 'latestByVersion'
    if ($packageGlobalConfig.selectionDefaults.PSObject.Properties['strategy'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.selectionDefaults.strategy)) {
        $selectionStrategy = [string]$packageGlobalConfig.selectionDefaults.strategy
    }

    $preferredTargetInstallDirectory = if ($packageGlobalConfig.PSObject.Properties['preferredTargetInstallDirectory'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.preferredTargetInstallDirectory)) {
        Resolve-PackageConfiguredPath -PathValue ([string]$packageGlobalConfig.preferredTargetInstallDirectory) -ApplicationRootDirectory $applicationRootDirectory
    }
    else {
        Resolve-PackageConfiguredPath -PathValue 'Inst' -ApplicationRootDirectory $applicationRootDirectory
    }

    $packageOperationHistoryFilePath = if ($packageGlobalConfig.packageState.PSObject.Properties['operationHistoryFilePath'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.packageState.operationHistoryFilePath)) {
        Resolve-PackageConfiguredPath -PathValue ([string]$packageGlobalConfig.packageState.operationHistoryFilePath) -ApplicationRootDirectory $applicationRootDirectory
    }
    else {
        Resolve-PackageConfiguredPath -PathValue 'State\PackageOperationHistory.json' -ApplicationRootDirectory $applicationRootDirectory
    }

    $shimDirectory = if ($packageGlobalConfig.PSObject.Properties['shimDirectory'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.shimDirectory)) {
        Resolve-PackageConfiguredPath -PathValue ([string]$packageGlobalConfig.shimDirectory) -ApplicationRootDirectory $applicationRootDirectory
    }
    else {
        Resolve-PackageConfiguredPath -PathValue 'Shims' -ApplicationRootDirectory $applicationRootDirectory
    }

    $packageDepotRelativePathTemplate = '{definitionId}/{releaseTrack}/{version}/{artifactDistributionVariant}'
    $packageWorkSlotDirectoryTemplate = '{definitionId}-{slotHash}'
    if ($packageGlobalConfig.PSObject.Properties['layout'] -and $packageGlobalConfig.layout) {
        if ($packageGlobalConfig.layout.PSObject.Properties['packageDepotRelativePath'] -and
            -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.layout.packageDepotRelativePath)) {
            $packageDepotRelativePathTemplate = [string]$packageGlobalConfig.layout.packageDepotRelativePath
        }
        if ($packageGlobalConfig.layout.PSObject.Properties['packageWorkSlotDirectory'] -and
            -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.layout.packageWorkSlotDirectory)) {
            $packageWorkSlotDirectoryTemplate = [string]$packageGlobalConfig.layout.packageWorkSlotDirectory
        }
    }

    $definitionWireDefinitionId = if ($definition.PSObject.Properties['definitionPublication'] -and
        $definition.definitionPublication.PSObject.Properties['definitionId'] -and
        -not [string]::IsNullOrWhiteSpace([string]$definition.definitionPublication.definitionId)) {
        [string]$definition.definitionPublication.definitionId
    }
    else {
        [string]$DefinitionId
    }

    $display = if ($definition.display -and $definition.display.PSObject.Properties['default'] -and $null -ne $definition.display.default) {
        $definition.display.default
    }
    else {
        [pscustomobject]@{}
    }

    return [pscustomobject]@{
        PackageConfigPath                  = $globalDocumentInfo.Path
        PackageConfigDocument              = $packageGlobalConfig
        ApplicationRootDirectory           = $applicationRootDirectory
        SourceInventoryPath                = $effectiveAcquisitionEnvironment.SourceInventoryPath
        SourceInventory                    = $sourceInventoryInfo.Document
        EndpointInventoryPath              = $endpointInventoryInfo.Path
        EndpointInventory                  = $endpointInventoryInfo.Document
        PublisherInventoryPath             = $publisherInventoryInfo.Path
        PublisherInventory                 = $publisherInventoryInfo.Document
        DepotInventoryPath                 = $effectiveAcquisitionEnvironment.DepotInventoryPath
        DepotInventory                     = $depotInventoryInfo.Document
        EffectiveAcquisitionEnvironment    = $effectiveAcquisitionEnvironment
        DefinitionReference                = $definitionReference
        DefinitionPath                     = $definitionDocumentInfo.Path
        Definition                         = $definition
        DefinitionId                       = $definitionWireDefinitionId
        DefinitionPublisherId              = [string]$definitionReference.PublisherId
        DefinitionPublisherName            = [string]$definitionReference.PublisherName
        DefinitionRevision                 = [int]$definitionReference.DefinitionRevision
        DefinitionPublishedAtUtc           = [string]$definitionReference.PublishedAtUtc
        DefinitionEndpointName             = if ($definitionReference.PSObject.Properties['EndpointName']) { [string]$definitionReference.EndpointName } else { $null }
        DefinitionSourceKind               = [string]$definitionReference.SourceKind
        DefinitionSourcePath               = [string]$definitionReference.SourcePath
        DefinitionSourceHash               = [string]$definitionReference.SourceHash
        DefinitionCandidatePath            = [string]$definitionReference.CandidatePath
        DefinitionCandidateHash            = [string]$definitionReference.CandidateHash
        DefinitionAssignedSnapshotPath     = [string]$definitionReference.SnapshotPath
        DefinitionAssignedSnapshotHash     = [string]$definitionReference.SnapshotHash
        DefinitionResolvedAtUtc            = [string]$definitionReference.ResolvedAtUtc
        DefinitionSnapshotFallback         = [bool]$definitionReference.SnapshotFallback
        DefinitionSources                  = $definition.artifacts.sources
        Display                            = $display
        SchemaVersion                      = [string]$definition.schemaVersion
        Platform                           = $runtimeContext.Platform
        Architecture                       = $runtimeContext.Architecture
        OSVersion                          = $runtimeContext.OSVersion
        ReleaseTrack                       = $selectionReleaseTrack
        SelectionStrategy                  = $selectionStrategy
        PackageFileStagingRootDirectory      = $effectiveAcquisitionEnvironment.Stores.PackageFileStagingDirectory
        PackageInstallStageRootDirectory     = $effectiveAcquisitionEnvironment.Stores.PackageInstallStageDirectory
        DefaultPackageDepotDirectory       = $effectiveAcquisitionEnvironment.Stores.DefaultPackageDepotDirectory
        PreferredTargetInstallRootDirectory = $preferredTargetInstallDirectory
        LocalEndpointRoot                  = $localEndpointRoot
        EndpointMaterializationMode        = $endpointMaterializationMode
        DefinitionPublisherConflictMode    = $definitionPublisherConflictMode
        ShimDirectory                      = $shimDirectory
        PackageDepotRelativePathTemplate   = $packageDepotRelativePathTemplate
        PackageWorkSlotDirectoryTemplate   = $packageWorkSlotDirectoryTemplate
        PackageAssignmentInventoryFilePath           = $packageInventoryFilePath
        PackageOperationHistoryFilePath    = $packageOperationHistoryFilePath
        AllowAcquisitionFallback           = $effectiveAcquisitionEnvironment.Defaults.AllowFallback
        DepotDistributionMode              = $effectiveAcquisitionEnvironment.Defaults.DepotDistributionMode
        EnvironmentSources                 = $effectiveAcquisitionEnvironment.EnvironmentSources
    }
}

function Resolve-PackagePaths {
<#
.SYNOPSIS
Resolves the concrete package-file workspace/depot and install paths for a selected release.

.DESCRIPTION
Builds the shared relative package-file directory for depot and workspace
storage from the selected release identity, resolves the effective install
directory template, and attaches the resolved directories to the Package
result object.

.PARAMETER PackageResult
The Package result object to enrich.

.EXAMPLE
Resolve-PackagePaths -PackageResult $result
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $packageConfig = $PackageResult.PackageConfig
    $definition = $packageConfig.Definition
    $package = $PackageResult.Package
    if (-not $package) {
        throw 'Resolve-PackagePaths requires a selected release.'
    }
    $assignedInstall = Get-PackageAssignedInstallOperation -Release $package
    $installKind = if ($assignedInstall -and $assignedInstall.PSObject.Properties['kind']) {
        [string]$assignedInstall.kind
    }
    else {
        $null
    }
    $installTargetKind = if ($assignedInstall -and $assignedInstall.PSObject.Properties['targetKind'] -and
        -not [string]::IsNullOrWhiteSpace([string]$assignedInstall.targetKind)) {
        [string]$assignedInstall.targetKind
    }
    else {
        'directory'
    }

    $packageDepotRelativeDirectory = Get-PackagePackageDepotRelativeDirectory -PackageConfig $packageConfig -Package $package
    $packageWorkSlotDirectory = Get-PackagePackageWorkSlotDirectory -PackageConfig $packageConfig -Package $package
    $installDirectoryTemplate = $null
    if ($assignedInstall -and
        $assignedInstall.PSObject.Properties['installDirectory'] -and
        -not [string]::IsNullOrWhiteSpace([string]$assignedInstall.installDirectory)) {
        $installDirectoryTemplate = Resolve-PackageTemplateText -Text ([string]$assignedInstall.installDirectory) -PackageConfig $packageConfig -Package $package
    }
    elseif (-not [string]::Equals($installKind, 'reuseExisting', [System.StringComparison]::OrdinalIgnoreCase) -and
        -not [string]::Equals($installKind, 'powershellModuleInstaller', [System.StringComparison]::OrdinalIgnoreCase) -and
        -not [string]::Equals($installTargetKind, 'machinePrerequisite', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Package definition '$($definition.id)' does not define an install target path. Use packageOperations.assigned.install.installDirectory."
    }

    $normalizedPackageDepotRelativeDirectory = $packageDepotRelativeDirectory.Trim() -replace '/', '\'
    if ([System.IO.Path]::IsPathRooted($normalizedPackageDepotRelativeDirectory)) {
        throw "Package definition '$($definition.id)' must use a relative package depot directory."
    }
    $normalizedPackageWorkSlotDirectory = $packageWorkSlotDirectory.Trim() -replace '/', '\'
    if ([System.IO.Path]::IsPathRooted($normalizedPackageWorkSlotDirectory)) {
        throw "Package definition '$($definition.id)' must use a relative package work slot directory."
    }

    $packageFileStagingDirectory = [System.IO.Path]::GetFullPath((Join-Path $packageConfig.PackageFileStagingRootDirectory $normalizedPackageWorkSlotDirectory))
    $packageInstallStageDirectory = [System.IO.Path]::GetFullPath((Join-Path $packageConfig.PackageInstallStageRootDirectory $normalizedPackageWorkSlotDirectory))

    $installDirectory = $null
    if (-not [string]::IsNullOrWhiteSpace($installDirectoryTemplate)) {
        $expandedInstallDirectoryTemplate = [Environment]::ExpandEnvironmentVariables(([string]$installDirectoryTemplate).Trim()) -replace '/', '\'
        $installDirectory = if ([System.IO.Path]::IsPathRooted($expandedInstallDirectoryTemplate)) {
            [System.IO.Path]::GetFullPath($expandedInstallDirectoryTemplate)
        }
        else {
            [System.IO.Path]::GetFullPath((Join-Path $packageConfig.PreferredTargetInstallRootDirectory $expandedInstallDirectoryTemplate))
        }
    }

    $packageFilePath = $null
    $defaultPackageDepotFilePath = $null
    if ($package.PSObject.Properties['packageFile'] -and
        $package.packageFile -and
        $package.packageFile.PSObject.Properties['fileName'] -and
        -not [string]::IsNullOrWhiteSpace([string]$package.packageFile.fileName)) {
        $packageFilePath = Join-Path $packageFileStagingDirectory ([string]$package.packageFile.fileName)
        if (-not [string]::IsNullOrWhiteSpace([string]$packageConfig.DefaultPackageDepotDirectory)) {
            $defaultPackageDepotDirectory = [System.IO.Path]::GetFullPath((Join-Path $packageConfig.DefaultPackageDepotDirectory $normalizedPackageDepotRelativeDirectory))
            $defaultPackageDepotFilePath = Join-Path $defaultPackageDepotDirectory ([string]$package.packageFile.fileName)
        }
    }

    $PackageResult.PackageFileStagingDirectory = $packageFileStagingDirectory
    $PackageResult.PackageInstallStageDirectory = $packageInstallStageDirectory
    $PackageResult.InstallDirectory = $installDirectory
    $PackageResult.PackageDepotRelativeDirectory = $normalizedPackageDepotRelativeDirectory
    $PackageResult.PackageWorkSlotDirectory = $normalizedPackageWorkSlotDirectory
    $PackageResult.PackageFilePath = $packageFilePath
    $PackageResult.DefaultPackageDepotFilePath = $defaultPackageDepotFilePath

    $resolvedInstallDirectoryText = if ([string]::IsNullOrWhiteSpace([string]$installDirectory)) { '<none>' } else { $installDirectory }
    $resolvedPackageFilePathText = if ([string]::IsNullOrWhiteSpace([string]$packageFilePath)) { '<none>' } else { $packageFilePath }
    $resolvedDefaultDepotFilePathText = if ([string]::IsNullOrWhiteSpace([string]$defaultPackageDepotFilePath)) { '<none>' } else { $defaultPackageDepotFilePath }
    Write-PackageExecutionMessage -Message '[STATE] Resolved paths:'
    Write-PackageExecutionMessage -Message ("[PATH] Package file staging: {0}" -f $packageFileStagingDirectory)
    Write-PackageExecutionMessage -Message ("[PATH] Package install stage: {0}" -f $packageInstallStageDirectory)
    Write-PackageExecutionMessage -Message ("[PATH] Target install directory: {0}" -f $resolvedInstallDirectoryText)
    Write-PackageExecutionMessage -Message ("[PATH] Package file: {0}" -f $resolvedPackageFilePathText)
    Write-PackageExecutionMessage -Message ("[PATH] Default package depot file: {0}" -f $resolvedDefaultDepotFilePathText)

    return $PackageResult
}

function New-PackageResult {
<#
.SYNOPSIS
Creates the initial Package result object.

.DESCRIPTION
Creates the result object that later Package stage helpers enrich with
artifact selection, package file, assigned-state, ownership, readiness, and entry-point data.

.PARAMETER PackageConfig
The resolved Package config object for the command.

.EXAMPLE
New-PackageResult -PackageConfig $config
#>
    [CmdletBinding()]
    param(
        [ValidateSet('Assigned', 'Removed')]
        [string]$DesiredState = 'Assigned',

        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig,

        [AllowNull()]
        [string]$PackageVersionSelector = $null
    )

    $packageVersionOverrideSpecified = $PSBoundParameters.ContainsKey('PackageVersionSelector') -and -not [string]::IsNullOrWhiteSpace([string]$PackageVersionSelector)
    $normalizedPackageVersionSelector = if ($packageVersionOverrideSpecified) { ([string]$PackageVersionSelector).Trim() } else { $null }

    return [pscustomobject]@{
        OperationId                      = [guid]::NewGuid().ToString('n')
        OperationStartedAtUtc            = [DateTime]::UtcNow.ToString('o')
        DesiredState                     = $DesiredState
        PackageVersionOverrideSpecified  = $packageVersionOverrideSpecified
        PackageVersionSelectionSource    = if ($packageVersionOverrideSpecified) { 'command' } else { 'definition' }
        PackageVersionSelector           = $normalizedPackageVersionSelector
        PackageVersionOrderingKind       = $null
        RequestedPackageVersion          = $null
        PublisherId                      = $PackageConfig.DefinitionPublisherId
        Status                           = 'Pending'
        FailureReason                    = $null
        ErrorMessage                     = $null
        CurrentStep                      = 'Pending'
        DefinitionId                     = $PackageConfig.DefinitionId
        DefinitionPublisherId            = $PackageConfig.DefinitionPublisherId
        DefinitionPublisherName          = $PackageConfig.DefinitionPublisherName
        DefinitionRevision               = $PackageConfig.DefinitionRevision
        DefinitionPublishedAtUtc         = $PackageConfig.DefinitionPublishedAtUtc
        DefinitionEndpointName           = $PackageConfig.DefinitionEndpointName
        Display                          = $PackageConfig.Display
        Platform                         = $PackageConfig.Platform
        Architecture                     = $PackageConfig.Architecture
        OSVersion                        = $PackageConfig.OSVersion
        ReleaseTrack                     = $PackageConfig.ReleaseTrack
        SourceInventoryPath              = $PackageConfig.SourceInventoryPath
        EndpointInventoryPath            = $PackageConfig.EndpointInventoryPath
        PublisherInventoryPath           = $PackageConfig.PublisherInventoryPath
        DepotInventoryPath               = $PackageConfig.DepotInventoryPath
        DefinitionSourceKind             = $PackageConfig.DefinitionSourceKind
        DefinitionSourcePath             = $PackageConfig.DefinitionSourcePath
        DefinitionSourceHash             = $PackageConfig.DefinitionSourceHash
        DefinitionCandidatePath          = $PackageConfig.DefinitionCandidatePath
        DefinitionCandidateHash          = $PackageConfig.DefinitionCandidateHash
        DefinitionAssignedSnapshotPath   = $PackageConfig.DefinitionAssignedSnapshotPath
        DefinitionAssignedSnapshotHash   = $PackageConfig.DefinitionAssignedSnapshotHash
        DefinitionResolvedAtUtc          = $PackageConfig.DefinitionResolvedAtUtc
        DefinitionSnapshotFallback       = $PackageConfig.DefinitionSnapshotFallback
        PackageFileStagingRootDirectory    = $PackageConfig.PackageFileStagingRootDirectory
        PackageInstallStageRootDirectory   = $PackageConfig.PackageInstallStageRootDirectory
        DefaultPackageDepotDirectory     = $PackageConfig.DefaultPackageDepotDirectory
        PreferredTargetInstallRootDirectory = $PackageConfig.PreferredTargetInstallRootDirectory
        LocalEndpointRoot              = $PackageConfig.LocalEndpointRoot
        ShimDirectory                    = $PackageConfig.ShimDirectory
        PackageAssignmentInventoryFilePath         = $PackageConfig.PackageAssignmentInventoryFilePath
        PackageOperationHistoryFilePath  = $PackageConfig.PackageOperationHistoryFilePath
        LocalEnvironment                 = $null
        Package                          = $null
        EffectiveRelease                 = $null
        PackageId                        = $null
        PackageVersion                   = $null
        Compatibility                    = @()
        PackageFileStagingDirectory        = $null
        PackageInstallStageDirectory       = $null
        InstallDirectory                 = $null
        PackageDepotRelativeDirectory    = $null
        PackageWorkSlotDirectory         = $null
        PackageFilePath                  = $null
        DefaultPackageDepotFilePath      = $null
        AcquisitionPlan                  = $null
        ExistingPackage                  = $null
        Ownership                        = $null
        InstallOrigin                    = $null
        PackageFilePreparation                  = $null
        DepotDistribution                = $null
        Dependencies                     = @()
        Assigned                         = $null
        Removed                          = $null
        Readiness                       = $null
        EntryPoints                      = $null
        PathRegistration                 = $null
        PackageConfig               = $PackageConfig
    }
}
