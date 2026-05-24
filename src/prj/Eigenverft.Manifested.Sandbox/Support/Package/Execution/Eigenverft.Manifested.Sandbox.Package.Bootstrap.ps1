<#
    Eigenverft.Manifested.Sandbox.Package.Bootstrap
#>

$script:ManifestedPackageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$script:ManifestedPackageConfigurationRoot = Join-Path $script:ManifestedPackageRoot 'Configuration'
$script:ManifestedPackageShippedEndpointRoot = Join-Path $script:ManifestedPackageRoot 'Endpoint'
$script:ManifestedPackageDefaultEndpointName = 'moduleDefaults'
$script:ManifestedPackageDefaultPublisherId = 'Eigenverft'
$script:ManifestedPackageSourceInventoryPathEnvironmentVariableName = 'EIGENVERFT_MANIFESTED_PACKAGE_SOURCE_INVENTORY_PATH'
$script:ManifestedPackageSiteCodeEnvironmentVariableName = 'EIGENVERFT_MANIFESTED_PACKAGE_SITE_CODE'

function Get-PackageConfigurationRoot {
<#
.SYNOPSIS
Returns the shipped Package configuration directory.

.DESCRIPTION
Resolves the module-relative directory that contains shipped Package
configuration JSON documents.

.EXAMPLE
Get-PackageConfigurationRoot
#>
    [CmdletBinding()]
    param()

    return $script:ManifestedPackageConfigurationRoot
}

function Get-PackageShippedEndpointRoot {
<#
.SYNOPSIS
Returns the shipped Package endpoint directory.

.DESCRIPTION
Resolves the module-relative directory that contains shipped Package definition
scan endpoints.

.EXAMPLE
Get-PackageShippedEndpointRoot
#>
    [CmdletBinding()]
    param()

    return $script:ManifestedPackageShippedEndpointRoot
}

function Get-PackageDefaultPublisherId {
<#
.SYNOPSIS
Returns the default trusted publisher id used on shipped package definitions.

.DESCRIPTION
This is the publisher namespace carried in definitionPublication.publisherId
for shipped package definitions.

.EXAMPLE
Get-PackageDefaultPublisherId
#>
    [CmdletBinding()]
    param()

    return $script:ManifestedPackageDefaultPublisherId
}

function Get-PackageDefaultEndpointName {
<#
.SYNOPSIS
Returns the shipped module-local endpoint name from PackageEndpointInventory.json.

.DESCRIPTION
Identifies the default scan endpoint row (`endpointName`) that ships with the module. Used to protect removal of the last shipped endpoint configuration.

.EXAMPLE
Get-PackageDefaultEndpointName
#>
    [CmdletBinding()]
    param()

    return $script:ManifestedPackageDefaultEndpointName
}

function Get-PackageShippedConfigPath {
<#
.SYNOPSIS
Returns the shipped Package config path.

.DESCRIPTION
Builds the module-relative path to the JSON document that defines Package
defaults.

.EXAMPLE
Get-PackageShippedConfigPath
#>
    [CmdletBinding()]
    param()

    return (Join-Path (Join-Path (Get-PackageConfigurationRoot) 'Internal') 'PackageConfig.json')
}

function Get-PackageShippedDepotInventoryPath {
<#
.SYNOPSIS
Returns the shipped Package depot-inventory path.

.DESCRIPTION
Builds the module-relative path to the JSON document that defines Package
depot/source defaults.

.EXAMPLE
Get-PackageShippedDepotInventoryPath
#>
    [CmdletBinding()]
    param()

    return (Join-Path (Join-Path (Get-PackageConfigurationRoot) 'Internal') 'PackageDepotInventory.json')
}

function Get-PackageShippedEndpointInventoryPath {
<#
.SYNOPSIS
Returns the shipped PackageEndpointInventory.json path.

.DESCRIPTION
Builds the module-relative path to the JSON document that defines Package definition scan endpoints.

.EXAMPLE
Get-PackageShippedEndpointInventoryPath
#>
    [CmdletBinding()]
    param()

    return (Join-Path (Join-Path (Get-PackageConfigurationRoot) 'Internal') 'PackageEndpointInventory.json')
}

function Get-PackageShippedPublisherInventoryPath {
<#
.SYNOPSIS
Returns the shipped PackagePublisherInventory.json path.
#>
    [CmdletBinding()]
    param()

    return (Join-Path (Join-Path (Get-PackageConfigurationRoot) 'Internal') 'PackagePublisherInventory.json')
}

function Get-PackageLocalRoot {
<#
.SYNOPSIS
Returns the Package local application-data root.

.DESCRIPTION
Resolves the local Package root from the shipped PackageConfig.json. This bootstrap
step intentionally does not read the local PackageConfig.json because the local root
is needed before the local config path can be known.

.EXAMPLE
Get-PackageLocalRoot
#>
    [CmdletBinding()]
    param()

    $shippedConfigPath = Get-PackageShippedConfigPath
    if (-not (Test-Path -LiteralPath $shippedConfigPath -PathType Leaf)) {
        throw "Package shipped config '$shippedConfigPath' does not exist. Cannot resolve the local Package root."
    }

    $rawContent = Get-Content -LiteralPath $shippedConfigPath -Raw -ErrorAction Stop
    try {
        $document = $rawContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Package shipped config '$shippedConfigPath' could not be parsed. Cannot resolve the local Package root. $($_.Exception.Message)"
    }

    if (-not $document.PSObject.Properties['package'] -or
        -not $document.package.PSObject.Properties['applicationRootDirectory'] -or
        [string]::IsNullOrWhiteSpace([string]$document.package.applicationRootDirectory)) {
        throw "Package shipped config '$shippedConfigPath' must define package.applicationRootDirectory to resolve the local Package root."
    }

    $applicationRootDirectory = [string]$document.package.applicationRootDirectory
    try {
        return (Resolve-ConfiguredPath -PathValue $applicationRootDirectory -BaseDirectory $null -Tokens @{})
    }
    catch {
        throw "Package shipped config '$shippedConfigPath' defines package.applicationRootDirectory '$applicationRootDirectory', but it does not resolve to an absolute path. $($_.Exception.Message)"
    }
}

function Get-PackageLocalConfigPath {
<#
.SYNOPSIS
Returns the local Package config path.

.DESCRIPTION
Builds the local copy path for PackageConfig.json. The local file can later be edited
or refreshed independently of the module installation.

.EXAMPLE
Get-PackageLocalConfigPath
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Join-Path (Get-PackageLocalRoot) 'Configuration\Internal') 'PackageConfig.json'))
}

function Get-PackageLocalDepotInventoryPath {
<#
.SYNOPSIS
Returns the local Package depot-inventory path.

.DESCRIPTION
Builds the local copy path for PackageDepotInventory.json. The local file can later
be edited or refreshed independently of the module installation.

.EXAMPLE
Get-PackageLocalDepotInventoryPath
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Join-Path (Get-PackageLocalRoot) 'Configuration\Internal') 'PackageDepotInventory.json'))
}

function Get-PackageLocalEndpointInventoryPath {
<#
.SYNOPSIS
Returns the local PackageEndpointInventory.json path.

.DESCRIPTION
Builds the local copy path for PackageEndpointInventory.json. The local file can
later be edited or refreshed independently of the module installation.

.EXAMPLE
Get-PackageLocalEndpointInventoryPath
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Join-Path (Get-PackageLocalRoot) 'Configuration\Internal') 'PackageEndpointInventory.json'))
}

function Get-PackageLocalPublisherInventoryPath {
<#
.SYNOPSIS
Returns the local PackagePublisherInventory.json path.
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Join-Path (Get-PackageLocalRoot) 'Configuration\Internal') 'PackagePublisherInventory.json'))
}

function Get-PackageConfigPath {
<#
.SYNOPSIS
Returns the active Package config path.

.DESCRIPTION
Returns the local PackageConfig.json path, creating it from the shipped module
configuration when the local copy does not exist yet.

.EXAMPLE
Get-PackageConfigPath
#>
    [CmdletBinding()]
    param()

    $localConfigPath = Get-PackageLocalConfigPath
    if (-not (Test-Path -LiteralPath $localConfigPath -PathType Leaf)) {
        $localConfigDirectory = Split-Path -Parent $localConfigPath
        if (-not [string]::IsNullOrWhiteSpace($localConfigDirectory)) {
            $null = New-Item -ItemType Directory -Path $localConfigDirectory -Force
        }

        Copy-FileToPath -SourcePath (Get-PackageShippedConfigPath) -TargetPath $localConfigPath -Overwrite | Out-Null
    }

    return $localConfigPath
}

function Get-PackageDepotInventoryPath {
<#
.SYNOPSIS
Returns the active Package depot-inventory path.

.DESCRIPTION
Returns the local PackageDepotInventory.json path, creating it from the shipped
module configuration when the local copy does not exist yet.

.EXAMPLE
Get-PackageDepotInventoryPath
#>
    [CmdletBinding()]
    param()

    $localInventoryPath = Get-PackageLocalDepotInventoryPath
    if (-not (Test-Path -LiteralPath $localInventoryPath -PathType Leaf)) {
        $localInventoryDirectory = Split-Path -Parent $localInventoryPath
        if (-not [string]::IsNullOrWhiteSpace($localInventoryDirectory)) {
            $null = New-Item -ItemType Directory -Path $localInventoryDirectory -Force
        }

        Copy-FileToPath -SourcePath (Get-PackageShippedDepotInventoryPath) -TargetPath $localInventoryPath -Overwrite | Out-Null
    }

    return $localInventoryPath
}

function Get-PackageEndpointInventoryPath {
<#
.SYNOPSIS
Returns the active PackageEndpointInventory.json path.

.DESCRIPTION
Returns the local PackageEndpointInventory.json path, creating it from the shipped
module configuration when the local copy does not exist yet.

.EXAMPLE
Get-PackageEndpointInventoryPath
#>
    [CmdletBinding()]
    param()

    $localInventoryPath = Get-PackageLocalEndpointInventoryPath
    if (-not (Test-Path -LiteralPath $localInventoryPath -PathType Leaf)) {
        $localInventoryDirectory = Split-Path -Parent $localInventoryPath
        if (-not [string]::IsNullOrWhiteSpace($localInventoryDirectory)) {
            $null = New-Item -ItemType Directory -Path $localInventoryDirectory -Force
        }

        Copy-FileToPath -SourcePath (Get-PackageShippedEndpointInventoryPath) -TargetPath $localInventoryPath -Overwrite | Out-Null
    }

    return $localInventoryPath
}

function Get-PackagePublisherInventoryPath {
<#
.SYNOPSIS
Returns the active PackagePublisherInventory.json path.
#>
    [CmdletBinding()]
    param()

    $localInventoryPath = Get-PackageLocalPublisherInventoryPath
    if (-not (Test-Path -LiteralPath $localInventoryPath -PathType Leaf)) {
        $localInventoryDirectory = Split-Path -Parent $localInventoryPath
        if (-not [string]::IsNullOrWhiteSpace($localInventoryDirectory)) {
            $null = New-Item -ItemType Directory -Path $localInventoryDirectory -Force
        }

        Copy-FileToPath -SourcePath (Get-PackageShippedPublisherInventoryPath) -TargetPath $localInventoryPath -Overwrite | Out-Null
    }

    return $localInventoryPath
}

function Get-PackageSourceInventoryPathEnvironmentVariableName {
<#
.SYNOPSIS
Returns the Package source-inventory path environment-variable name.

.DESCRIPTION
Provides the environment-variable name that can point Package to an
external source-inventory document.

.EXAMPLE
Get-PackageSourceInventoryPathEnvironmentVariableName
#>
    [CmdletBinding()]
    param()

    return $script:ManifestedPackageSourceInventoryPathEnvironmentVariableName
}

function Get-PackageSiteCodeEnvironmentVariableName {
<#
.SYNOPSIS
Returns the Package site-code environment-variable name.

.DESCRIPTION
Provides the environment-variable name used to select a site-specific overlay
from the external Package source inventory.

.EXAMPLE
Get-PackageSiteCodeEnvironmentVariableName
#>
    [CmdletBinding()]
    param()

    return $script:ManifestedPackageSiteCodeEnvironmentVariableName
}

function Get-PackageDefinitionPath {
<#
.SYNOPSIS
Returns the shipped Package definition path for an id.

.DESCRIPTION
Finds a Package definition JSON file in the shipped `Endpoint\Defaults` tree by
reading the JSON definitionId. Filenames and subdirectories are storage details.

.PARAMETER DefinitionId
The Package definition id.

.EXAMPLE
Get-PackageDefinitionPath -DefinitionId VSCodeRuntime
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DefinitionId
    )

    $endpointRoot = Join-Path (Get-PackageShippedEndpointRoot) 'Defaults'
    if (-not (Test-Path -LiteralPath $endpointRoot -PathType Container)) {
        throw "Package shipped endpoint root '$endpointRoot' does not exist."
    }

    foreach ($jsonFile in @(Get-ChildItem -LiteralPath $endpointRoot -Filter '*.json' -File -Recurse)) {
        try {
            $document = Get-Content -LiteralPath $jsonFile.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            $docDefinitionId = if ($document.PSObject.Properties['definitionPublication'] -and
                $document.definitionPublication.PSObject.Properties['definitionId'] -and
                -not [string]::IsNullOrWhiteSpace([string]$document.definitionPublication.definitionId)) {
                [string]$document.definitionPublication.definitionId
            }
            else {
                $null
            }
            if (-not [string]::IsNullOrWhiteSpace($docDefinitionId) -and
                [string]::Equals($docDefinitionId, $DefinitionId, [System.StringComparison]::OrdinalIgnoreCase)) {
                return [System.IO.Path]::GetFullPath($jsonFile.FullName)
            }
        }
        catch {
            continue
        }
    }

    throw "Package definition '$DefinitionId' was not found by JSON definitionId under shipped endpoint '$endpointRoot'."
}

