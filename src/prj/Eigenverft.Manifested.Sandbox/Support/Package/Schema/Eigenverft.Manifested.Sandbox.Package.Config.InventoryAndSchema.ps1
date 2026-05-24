<#
    Eigenverft.Manifested.Sandbox.Package.Config - depot/source inventory and global config schema assertions.
    Loaded by Eigenverft.Manifested.Sandbox.Package.Config.ps1.
#>

function Get-PackageSourceInventoryPath {
<#
.SYNOPSIS
Returns the effective external Package source-inventory path.

.DESCRIPTION
Resolves the environment-variable override first, then falls back to the
well-known local inventory path.

.EXAMPLE
Get-PackageSourceInventoryPath
#>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$ApplicationRootDirectory
    )

    $environmentVariableName = Get-PackageSourceInventoryPathEnvironmentVariableName
    $configuredPath = [Environment]::GetEnvironmentVariable($environmentVariableName)
    if (-not [string]::IsNullOrWhiteSpace($configuredPath)) {
        return (Resolve-PackagePathValue -PathValue $configuredPath)
    }

    if (-not [string]::IsNullOrWhiteSpace($ApplicationRootDirectory)) {
        return (Resolve-PackageConfiguredPath -PathValue 'Configuration\External\PackageSourceInventory.json' -ApplicationRootDirectory $ApplicationRootDirectory)
    }

    return (Get-PackageDefaultSourceInventoryPath)
}

function Get-PackageSiteCode {
<#
.SYNOPSIS
Returns the effective Package site code.

.DESCRIPTION
Reads the optional site-code environment variable and normalizes its value.

.EXAMPLE
Get-PackageSiteCode
#>
    [CmdletBinding()]
    param()

    $environmentVariableName = Get-PackageSiteCodeEnvironmentVariableName
    $siteCode = [Environment]::GetEnvironmentVariable($environmentVariableName)
    if ([string]::IsNullOrWhiteSpace($siteCode)) {
        return $null
    }

    return $siteCode.Trim()
}

function Get-PackageActiveSiteCodes {
<#
.SYNOPSIS
Returns the effective Package site-code list.

.DESCRIPTION
Reads the optional site-code environment variable as a semicolon-separated
list, trims empty entries, and de-duplicates while preserving order.

.EXAMPLE
Get-PackageActiveSiteCodes
#>
    [CmdletBinding()]
    param()

    $environmentVariableName = Get-PackageSiteCodeEnvironmentVariableName
    $siteCodeText = [Environment]::GetEnvironmentVariable($environmentVariableName)
    if ([string]::IsNullOrWhiteSpace($siteCodeText)) {
        return @()
    }

    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $siteCodes = New-Object System.Collections.Generic.List[string]
    foreach ($siteCode in @($siteCodeText -split ';')) {
        $normalizedSiteCode = ([string]$siteCode).Trim()
        if ([string]::IsNullOrWhiteSpace($normalizedSiteCode)) {
            continue
        }
        if ($seen.Add($normalizedSiteCode)) {
            $siteCodes.Add($normalizedSiteCode) | Out-Null
        }
    }

    return @($siteCodes.ToArray())
}

function Assert-PackageDepotInventorySchema {
<#
.SYNOPSIS
Validates the Package depot-inventory schema.

.DESCRIPTION
Checks that the internal depot inventory document uses the current shape with
inventoryVersion and acquisitionEnvironment.

.PARAMETER DepotInventoryDocumentInfo
The loaded depot-inventory document info.

.EXAMPLE
Assert-PackageDepotInventorySchema -DepotInventoryDocumentInfo $inventoryInfo
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DepotInventoryDocumentInfo
    )

    $document = $DepotInventoryDocumentInfo.Document
    if (-not $document.PSObject.Properties['inventoryVersion']) {
        throw "Package depot inventory '$($DepotInventoryDocumentInfo.Path)' is missing inventoryVersion."
    }
    if (-not $document.PSObject.Properties['acquisitionEnvironment'] -or $null -eq $document.acquisitionEnvironment) {
        throw "Package depot inventory '$($DepotInventoryDocumentInfo.Path)' is missing acquisitionEnvironment."
    }
    if ($document.acquisitionEnvironment.PSObject.Properties['environmentSources']) {
        foreach ($sourceProperty in @($document.acquisitionEnvironment.environmentSources.PSObject.Properties)) {
            if ($sourceProperty.Value -and $sourceProperty.Value.PSObject.Properties['priority']) {
                throw "Package depot inventory '$($DepotInventoryDocumentInfo.Path)' source '$($sourceProperty.Name)' still uses retired property 'priority'. Use 'searchOrder'."
            }
            if ($sourceProperty.Value -and -not $sourceProperty.Value.PSObject.Properties['searchOrder']) {
                throw "Package depot inventory '$($DepotInventoryDocumentInfo.Path)' source '$($sourceProperty.Name)' is missing searchOrder."
            }
            Assert-PackageEnvironmentSourceCapabilities -SourceId $sourceProperty.Name -SourceValue $sourceProperty.Value -DocumentPath $DepotInventoryDocumentInfo.Path
        }
    }
}

function Assert-PackageEnvironmentSourceCapabilities {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceId,

        [Parameter(Mandatory = $true)]
        [psobject]$SourceValue,

        [Parameter(Mandatory = $true)]
        [string]$DocumentPath
    )

    if (-not [string]::Equals([string]$SourceValue.kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
        return
    }

    foreach ($capabilityName in @('readable', 'writable', 'mirrorTarget', 'ensureExists')) {
        if (-not $SourceValue.PSObject.Properties[$capabilityName]) {
            throw "Package environment source '$SourceId' in '$DocumentPath' is missing capability '$capabilityName'."
        }
    }

    $writable = [bool]$SourceValue.writable
    if ([bool]$SourceValue.mirrorTarget -and -not $writable) {
        throw "Package environment source '$SourceId' in '$DocumentPath' cannot use mirrorTarget=true with writable=false."
    }
    if ([bool]$SourceValue.ensureExists -and -not $writable) {
        throw "Package environment source '$SourceId' in '$DocumentPath' cannot use ensureExists=true with writable=false."
    }
}

function Get-PackageDepotInventoryInfo {
<#
.SYNOPSIS
Loads the internal Package depot inventory.

.DESCRIPTION
Loads the effective local depot-inventory document, creating it from the
shipped module defaults when missing.

.EXAMPLE
Get-PackageDepotInventoryInfo
#>
    [CmdletBinding()]
    param()

    $inventoryPath = Get-PackageDepotInventoryPath
    $documentInfo = Read-PackageJsonDocument -Path $inventoryPath
    Assert-PackageDepotInventorySchema -DepotInventoryDocumentInfo $documentInfo
    return [pscustomobject]@{
        Path     = $documentInfo.Path
        Document = $documentInfo.Document
        Exists   = $true
    }
}

function Assert-PackageSourceInventorySchema {
<#
.SYNOPSIS
Validates the Package source-inventory schema.

.DESCRIPTION
Checks that the external inventory document uses the current shape with
inventoryVersion, global, and optional site overlays.

.PARAMETER SourceInventoryDocumentInfo
The loaded source-inventory document info.

.EXAMPLE
Assert-PackageSourceInventorySchema -SourceInventoryDocumentInfo $inventoryInfo
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$SourceInventoryDocumentInfo
    )

    $document = $SourceInventoryDocumentInfo.Document
    if (-not $document.PSObject.Properties['inventoryVersion']) {
        throw "Package source inventory '$($SourceInventoryDocumentInfo.Path)' is missing inventoryVersion."
    }
    if (-not $document.PSObject.Properties['global']) {
        $document | Add-Member -MemberType NoteProperty -Name global -Value ([pscustomobject]@{})
    }
    if (-not $document.PSObject.Properties['sites']) {
        $document | Add-Member -MemberType NoteProperty -Name sites -Value ([pscustomobject]@{})
    }
}

function Get-PackageSourceInventoryInfo {
<#
.SYNOPSIS
Loads the optional external Package source inventory.

.DESCRIPTION
Resolves the effective inventory path, loads it when present, validates the
schema, and otherwise returns a null document marker.

.EXAMPLE
Get-PackageSourceInventoryInfo
#>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$ApplicationRootDirectory
    )

    $inventoryPath = Get-PackageSourceInventoryPath -ApplicationRootDirectory $ApplicationRootDirectory
    if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) {
        return [pscustomobject]@{
            Path     = $inventoryPath
            Document = $null
            Exists   = $false
        }
    }

    $documentInfo = Read-PackageJsonDocument -Path $inventoryPath
    Assert-PackageSourceInventorySchema -SourceInventoryDocumentInfo $documentInfo
    return [pscustomobject]@{
        Path     = $documentInfo.Path
        Document = $documentInfo.Document
        Exists   = $true
    }
}

function Assert-PackageConfigSchema {
<#
.SYNOPSIS
Validates the Package config schema.

.DESCRIPTION
Rejects retired global field names and requires the current Package
preferred-install and acquisition-environment fields.

.PARAMETER PackageConfigDocumentInfo
The loaded Package config document info.

.EXAMPLE
Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfigDocumentInfo
    )

    if (-not $PackageConfigDocumentInfo.Document.PSObject.Properties['package'] -or $null -eq $PackageConfigDocumentInfo.Document.package) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' does not contain a 'package' object."
    }

    $package = $PackageConfigDocumentInfo.Document.package
    foreach ($retiredProperty in @('managedStorageRoots', 'acquisitionDefaults', 'sourceBindings', 'downloadRootDirectory', 'installRootDirectory', 'allowSourceFallback', 'packageSelection', 'ownershipTracking', 'localRepositoryRoot', 'repositoryEnvironment')) {
        if ($package.PSObject.Properties[$retiredProperty]) {
            throw "Package config '$($PackageConfigDocumentInfo.Path)' still uses retired property '$retiredProperty'."
        }
    }

    foreach ($requiredProperty in @('preferredTargetInstallDirectory', 'localEndpointRoot', 'endpointEnvironment', 'acquisitionEnvironment', 'packageState', 'selectionDefaults')) {
        if (-not $package.PSObject.Properties[$requiredProperty]) {
            throw "Package config '$($PackageConfigDocumentInfo.Path)' is missing required property '$requiredProperty'."
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$package.localEndpointRoot)) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' is missing localEndpointRoot."
    }
    if ($package.PSObject.Properties['repositorySources']) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' still uses retired property 'repositorySources'. Use Configuration/Internal/PackageEndpointInventory.json endpoints."
    }
    if (-not $package.endpointEnvironment.PSObject.Properties['defaults'] -or -not $package.endpointEnvironment.defaults) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' is missing endpointEnvironment.defaults."
    }
    $endpointDefaults = $package.endpointEnvironment.defaults
    if ($endpointDefaults.PSObject.Properties['endpointMaterializationMode']) {
        $endpointMaterializationMode = [string]$endpointDefaults.endpointMaterializationMode
        if ($endpointMaterializationMode -notin @('packageFocused', 'endpointFocused')) {
            throw "Package config '$($PackageConfigDocumentInfo.Path)' defines unsupported endpointEnvironment.defaults.endpointMaterializationMode '$endpointMaterializationMode'. Use 'packageFocused' or 'endpointFocused'."
        }
    }
    if ($endpointDefaults.PSObject.Properties['definitionPublisherConflictMode']) {
        $definitionPublisherConflictMode = [string]$endpointDefaults.definitionPublisherConflictMode
        if ($definitionPublisherConflictMode -notin @('fail', 'warnFirst', 'first', 'warnLast', 'last')) {
            throw "Package config '$($PackageConfigDocumentInfo.Path)' defines unsupported endpointEnvironment.defaults.definitionPublisherConflictMode '$definitionPublisherConflictMode'. Use 'fail', 'warnFirst', 'first', 'warnLast', or 'last'."
        }
    }

    if ($package.selectionDefaults.PSObject.Properties['channel']) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' still uses retired property 'selectionDefaults.channel'."
    }

    if ([string]::IsNullOrWhiteSpace([string]$package.preferredTargetInstallDirectory)) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' is missing preferredTargetInstallDirectory."
    }
    if ($package.PSObject.Properties['applicationRootDirectory'] -and
        [string]::IsNullOrWhiteSpace([string]$package.applicationRootDirectory)) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' defines an empty applicationRootDirectory."
    }
    if ($package.PSObject.Properties['shimDirectory'] -and
        [string]::IsNullOrWhiteSpace([string]$package.shimDirectory)) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' defines an empty shimDirectory."
    }
    if ($package.PSObject.Properties['layout'] -and $package.layout) {
        foreach ($layoutProperty in @('packageDepotRelativePath', 'packageWorkSlotDirectory')) {
            if ($package.layout.PSObject.Properties[$layoutProperty] -and
                [string]::IsNullOrWhiteSpace([string]$package.layout.$layoutProperty)) {
                throw "Package config '$($PackageConfigDocumentInfo.Path)' defines an empty layout.$layoutProperty."
            }
        }
    }

    foreach ($requiredAcquisitionProperty in @('stores', 'defaults')) {
        if (-not $package.acquisitionEnvironment.PSObject.Properties[$requiredAcquisitionProperty]) {
            throw "Package config '$($PackageConfigDocumentInfo.Path)' is missing acquisitionEnvironment.$requiredAcquisitionProperty."
        }
    }

    if ($package.acquisitionEnvironment.stores.PSObject.Properties['defaultPackageDepotDirectory']) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' still uses retired property 'acquisitionEnvironment.stores.defaultPackageDepotDirectory'. Use Configuration/Internal/PackageDepotInventory.json environmentSources.defaultPackageDepot.basePath."
    }
    if ($package.acquisitionEnvironment.stores.PSObject.Properties['installWorkspaceDirectory']) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' still uses retired property 'acquisitionEnvironment.stores.installWorkspaceDirectory'. Use 'acquisitionEnvironment.stores.packageFileStagingDirectory'."
    }
    if ($package.acquisitionEnvironment.stores.PSObject.Properties['installPreparationDirectory']) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' still uses retired property 'acquisitionEnvironment.stores.installPreparationDirectory'. Use 'acquisitionEnvironment.stores.packageFileStagingDirectory' and 'acquisitionEnvironment.stores.packageInstallStageDirectory'."
    }
    if ($package.acquisitionEnvironment.defaults.PSObject.Properties['mirrorDownloadedArtifactsToDefaultPackageDepot']) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' still uses retired property 'acquisitionEnvironment.defaults.mirrorDownloadedArtifactsToDefaultPackageDepot'. Use Configuration/Internal/PackageDepotInventory.json environmentSources.<depotId>.mirrorTarget with writable=true."
    }
    if ($package.acquisitionEnvironment.defaults.PSObject.Properties['depotDistributionMode']) {
        $depotDistributionMode = [string]$package.acquisitionEnvironment.defaults.depotDistributionMode
        if ($depotDistributionMode -notin @('packageFocused', 'depotFocused', 'disabled')) {
            throw "Package config '$($PackageConfigDocumentInfo.Path)' defines unsupported acquisitionEnvironment.defaults.depotDistributionMode '$depotDistributionMode'. Use 'packageFocused', 'depotFocused', or 'disabled'."
        }
    }

    foreach ($requiredStoreProperty in @('packageFileStagingDirectory', 'packageInstallStageDirectory')) {
        if (-not $package.acquisitionEnvironment.stores.PSObject.Properties[$requiredStoreProperty]) {
            throw "Package config '$($PackageConfigDocumentInfo.Path)' is missing acquisitionEnvironment.stores.$requiredStoreProperty."
        }
    }

    foreach ($requiredDefaultProperty in @('allowFallback')) {
        if (-not $package.acquisitionEnvironment.defaults.PSObject.Properties[$requiredDefaultProperty]) {
            throw "Package config '$($PackageConfigDocumentInfo.Path)' is missing acquisitionEnvironment.defaults.$requiredDefaultProperty."
        }
    }

    if ($package.acquisitionEnvironment.PSObject.Properties['tracking'] -and $package.acquisitionEnvironment.tracking) {
        if ($package.acquisitionEnvironment.tracking.PSObject.Properties['artifactIndexFilePath']) {
            throw "Package config '$($PackageConfigDocumentInfo.Path)' still uses retired property 'acquisitionEnvironment.tracking.artifactIndexFilePath'. Package-file inventory is no longer durable state."
        }
        if ($package.acquisitionEnvironment.tracking.PSObject.Properties['packageFileIndexFilePath']) {
            throw "Package config '$($PackageConfigDocumentInfo.Path)' still uses retired property 'acquisitionEnvironment.tracking.packageFileIndexFilePath'. Package-file inventory is resolved live from package definitions, config, and depot inventory."
        }
    }
    if ($package.packageState.PSObject.Properties['indexFilePath']) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' still uses retired property 'packageState.indexFilePath'. Use 'packageState.inventoryFilePath'."
    }
    if (-not $package.packageState.PSObject.Properties['inventoryFilePath']) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' is missing packageState.inventoryFilePath."
    }
    if (-not $package.packageState.PSObject.Properties['operationHistoryFilePath']) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' is missing packageState.operationHistoryFilePath."
    }
    if (-not $package.selectionDefaults.PSObject.Properties['releaseTrack']) {
        throw "Package config '$($PackageConfigDocumentInfo.Path)' is missing selectionDefaults.releaseTrack."
    }

    if ($package.acquisitionEnvironment.PSObject.Properties['environmentSources'] -and $null -ne $package.acquisitionEnvironment.environmentSources) {
        foreach ($retiredEnvironmentSourceId in @('localPackageDepot', 'remotePackageDepot', 'corpPackageDepot', 'sitePackageDepot', 'vsCodeUpdateService')) {
            if ($package.acquisitionEnvironment.environmentSources.PSObject.Properties[$retiredEnvironmentSourceId]) {
                throw "Package config '$($PackageConfigDocumentInfo.Path)' must not define acquisitionEnvironment.environmentSources.$retiredEnvironmentSourceId in the shipped global config."
            }
        }
    }
}
