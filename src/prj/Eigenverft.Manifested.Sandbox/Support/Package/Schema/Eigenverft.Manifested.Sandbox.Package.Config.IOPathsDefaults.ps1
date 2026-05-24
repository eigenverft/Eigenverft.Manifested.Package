<#
    Eigenverft.Manifested.Sandbox.Package.Config - paths, defaults, runtime context, inventory path helpers.
    Loaded by Eigenverft.Manifested.Sandbox.Package.Config.ps1 (do not dot-source directly from the module root).
#>

function Read-PackageJsonDocument {
<#
.SYNOPSIS
Reads a Package JSON document from disk.

.DESCRIPTION
Resolves a JSON file path, validates that it contains content, parses it, and
returns the resolved path together with the parsed document object.

.PARAMETER Path
Path to the JSON file that should be loaded.

.EXAMPLE
Read-PackageJsonDocument -Path .\Configuration\Internal\PackageConfig.json
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $rawContent = Get-Content -LiteralPath $resolvedPath -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($rawContent)) {
        throw "Package JSON file '$resolvedPath' is empty."
    }

    try {
        $document = $rawContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Package JSON file '$resolvedPath' could not be parsed. $($_.Exception.Message)"
    }

    return [pscustomobject]@{
        Path     = $resolvedPath
        Document = $document
    }
}

function Resolve-PackagePathValue {
<#
.SYNOPSIS
Expands and normalizes a filesystem path value.

.DESCRIPTION
Expands environment variables, normalizes path separators, and returns a full
filesystem path for relative, local, or UNC paths.

.PARAMETER PathValue
The raw path value that should be normalized.

.EXAMPLE
Resolve-PackagePathValue -PathValue '%USERPROFILE%/Downloads/Test'
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    return Resolve-ConfiguredPath -PathValue $PathValue -BaseDirectory (Get-Location).Path -Tokens @{}
}

function Get-PackageDefaultApplicationRootDirectory {
<#
.SYNOPSIS
Returns the default Package application root.

.DESCRIPTION
Builds the fallback local application root used when PackageConfig.json does not
define package.applicationRootDirectory.
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Get-PackageLocalRoot))
}

function Resolve-PackageApplicationRootDirectory {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$PackageConfiguration
    )

    if ($PackageConfiguration -and
        $PackageConfiguration.PSObject.Properties['applicationRootDirectory'] -and
        -not [string]::IsNullOrWhiteSpace([string]$PackageConfiguration.applicationRootDirectory)) {
        return Resolve-ConfiguredPath -PathValue ([string]$PackageConfiguration.applicationRootDirectory) -BaseDirectory (Get-PackageLocalRoot) -Tokens @{}
    }

    return Get-PackageDefaultApplicationRootDirectory
}

function Get-PackageApplicationPathTokens {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationRootDirectory
    )

    return [ordered]@{
        applicationRootDirectory = [System.IO.Path]::GetFullPath($ApplicationRootDirectory)
    }
}

function Resolve-PackageConfiguredPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,

        [Parameter(Mandatory = $true)]
        [string]$ApplicationRootDirectory,

        [System.Collections.IDictionary]$Tokens = $null
    )

    $pathTokens = [ordered]@{}
    foreach ($property in @((Get-PackageApplicationPathTokens -ApplicationRootDirectory $ApplicationRootDirectory).GetEnumerator())) {
        $pathTokens[$property.Key] = $property.Value
    }
    if ($Tokens) {
        foreach ($key in @($Tokens.Keys)) {
            $pathTokens[$key] = $Tokens[$key]
        }
    }

    return Resolve-ConfiguredPath -PathValue $PathValue -BaseDirectory $ApplicationRootDirectory -Tokens $pathTokens
}

function Get-PackageRuntimeContext {
<#
.SYNOPSIS
Resolves the current Package runtime context.

.DESCRIPTION
Detects the effective platform and architecture used for package matching.

.EXAMPLE
Get-PackageRuntimeContext
#>
    [CmdletBinding()]
    param()

    $platform = switch ([Environment]::OSVersion.Platform) {
        ([System.PlatformID]::Win32NT) { 'windows'; break }
        ([System.PlatformID]::Unix) { 'linux'; break }
        ([System.PlatformID]::MacOSX) { 'macos'; break }
        default { [Environment]::OSVersion.Platform.ToString().ToLowerInvariant() }
    }

    $architecture = 'x86'
    foreach ($candidate in @($env:PROCESSOR_ARCHITECTURE, $env:PROCESSOR_ARCHITEW6432)) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        $normalizedCandidate = $candidate.ToUpperInvariant()
        if ($normalizedCandidate -like '*ARM64*') {
            $architecture = 'arm64'
            break
        }
        if ($normalizedCandidate -like '*64*') {
            $architecture = 'x64'
            break
        }
    }

    return [pscustomobject]@{
        Platform     = $platform
        Architecture = $architecture
        OSVersion    = [Environment]::OSVersion.Version.ToString()
    }
}

function Get-PackageDefaultPackageFileStagingDirectory {
<#
.SYNOPSIS
Returns the default Package package-file staging root.

.DESCRIPTION
Builds the fallback local staging root for raw package files
when the shipped or external config does not define one explicitly.

.EXAMPLE
Get-PackageDefaultPackageFileStagingDirectory
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Get-PackageDefaultApplicationRootDirectory) 'FileStage'))
}

function Get-PackageDefaultPackageInstallStageDirectory {
<#
.SYNOPSIS
Returns the default Package install-stage root.

.DESCRIPTION
Builds the fallback local stage root for package extraction and installer
execution when the shipped or external config does not define one explicitly.

.EXAMPLE
Get-PackageDefaultPackageInstallStageDirectory
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Get-PackageDefaultApplicationRootDirectory) 'InstStage'))
}

function Get-PackageDefaultShimDirectory {
<#
.SYNOPSIS
Returns the default Package shim root.

.DESCRIPTION
Builds the fallback local shim root when PackageConfig.json does not define one
explicitly.
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Get-PackageDefaultApplicationRootDirectory) 'Shims'))
}

function Get-PackageDefaultPreferredTargetInstallDirectory {
<#
.SYNOPSIS
Returns the default Package preferred target-install root.

.DESCRIPTION
Builds the fallback local application-data root for Package preferred
target installs when the Package config document does not define one explicitly.

.EXAMPLE
Get-PackageDefaultPreferredTargetInstallDirectory
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Get-PackageDefaultApplicationRootDirectory) 'Inst'))
}

function Get-PackageDefaultPackageAssignmentInventoryFilePath {
<#
.SYNOPSIS
Returns the default Package inventory path.

.DESCRIPTION
Builds the fallback local package inventory file path when the Package
Package config document does not define one explicitly.

.EXAMPLE
Get-PackageDefaultPackageAssignmentInventoryFilePath
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Join-Path (Get-PackageDefaultApplicationRootDirectory) 'State') 'PackageAssignmentInventory.json'))
}

function Get-PackageDefaultOperationHistoryFilePath {
<#
.SYNOPSIS
Returns the default Package operation-history path.

.DESCRIPTION
Builds the fallback local package operation-history file path when the Package
Package config document does not define one explicitly.

.EXAMPLE
Get-PackageDefaultOperationHistoryFilePath
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Join-Path (Get-PackageDefaultApplicationRootDirectory) 'State') 'PackageOperationHistory.json'))
}

function Get-PackageDefaultLocalEndpointRoot {
<#
.SYNOPSIS
Returns the default Package local endpoint definition root.

.DESCRIPTION
Builds the fallback local root for materialized package-definition copies
(Candidate and Assigned) sourced from configured endpoints.

.EXAMPLE
Get-PackageDefaultLocalEndpointRoot
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Get-PackageDefaultApplicationRootDirectory) 'PkgEndpoint'))
}

function Get-PackageDefaultSourceInventoryPath {
<#
.SYNOPSIS
Returns the default external Package source-inventory path.

.DESCRIPTION
Builds the fallback local source-inventory path that can hold environment and
site acquisition sources outside the shipped module JSON.

.EXAMPLE
Get-PackageDefaultSourceInventoryPath
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Join-Path (Get-PackageDefaultApplicationRootDirectory) 'Configuration\External') 'PackageSourceInventory.json'))
}

function Get-PackageDefaultLogRootDirectory {
<#
.SYNOPSIS
Returns the default Package log root.

.DESCRIPTION
Builds the fallback local application-data root for package installer logs.

.EXAMPLE
Get-PackageDefaultLogRootDirectory
#>
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Get-PackageDefaultApplicationRootDirectory) 'Logs'))
}

function Get-PackageRootFromInventoryPath {
<#
.SYNOPSIS
Returns the Package local root from a package inventory path.

.DESCRIPTION
The current layout stores inventory under State. Older or custom test layouts may
place the inventory directly under the package root, so this helper accepts
both shapes.

.EXAMPLE
Get-PackageRootFromInventoryPath -PackageAssignmentInventoryFilePath $path
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageAssignmentInventoryFilePath
    )

    $indexDirectory = Split-Path -Parent ([System.IO.Path]::GetFullPath($PackageAssignmentInventoryFilePath))
    if ([string]::Equals((Split-Path -Leaf $indexDirectory), 'State', [System.StringComparison]::OrdinalIgnoreCase)) {
        return [System.IO.Path]::GetFullPath((Split-Path -Parent $indexDirectory))
    }

    return [System.IO.Path]::GetFullPath($indexDirectory)
}
