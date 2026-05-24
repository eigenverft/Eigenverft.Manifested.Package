<#
    Eigenverft.Manifested.Sandbox.Package.Config - template resolution and depot/work-slot layout helpers.
    Loaded by Eigenverft.Manifested.Sandbox.Package.Config.ps1.
#>

function Resolve-PackageTemplateText {
<#
.SYNOPSIS
Resolves simple Package template tokens in text.

.DESCRIPTION
Replaces package-aware tokens such as `{releaseTrack}`, `{version}`, and
`{artifactDistributionVariant}` with the current values from the resolved
Package config and selected package.

.PARAMETER Text
The text that contains optional Package tokens.

.PARAMETER PackageConfig
The resolved Package config object.

.PARAMETER Package
The selected release object.

.PARAMETER ExtraTokens
Optional extra tokens to merge into the standard replacement map.

.EXAMPLE
Resolve-PackageTemplateText -Text '{releaseTrack}\{version}\{artifactDistributionVariant}' -PackageConfig $config -Package $package
#>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Text,

        [AllowNull()]
        [psobject]$PackageConfig,

        [AllowNull()]
        [psobject]$Package,

        [hashtable]$ExtraTokens = @{}
    )

    if ($null -eq $Text) {
        return $null
    }

    $tokens = Get-PackageTemplateTokenMap -PackageConfig $PackageConfig -Package $Package -ExtraTokens $ExtraTokens
    return Resolve-TemplateText -Text $Text -Tokens $tokens
}

function ConvertTo-PackageSafePathSegment {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value
    )

    $segmentText = ([string]$Value).Trim() -replace '[\\/:\*\?"<>\|]', '-'
    if ([string]::IsNullOrWhiteSpace($segmentText)) {
        throw 'Package path layout produced an empty path segment.'
    }

    return $segmentText
}

function Get-PackageTemplateTokenMap {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$PackageConfig,

        [AllowNull()]
        [psobject]$Package,

        [hashtable]$ExtraTokens = @{},

        [switch]$SanitizePathSegments
    )

    $tokens = [ordered]@{}
    if ($PackageConfig) {
        $tokens['definitionId'] = $PackageConfig.DefinitionId
        $tokens['platform'] = $PackageConfig.Platform
        $tokens['architecture'] = $PackageConfig.Architecture
        $tokens['releaseTrack'] = $PackageConfig.ReleaseTrack
        if ($PackageConfig.PSObject.Properties['ApplicationRootDirectory']) {
            $tokens['applicationRootDirectory'] = $PackageConfig.ApplicationRootDirectory
        }
        if ($PackageConfig.PSObject.Properties['PreferredTargetInstallRootDirectory']) {
            $tokens['preferredTargetInstallDirectory'] = $PackageConfig.PreferredTargetInstallRootDirectory
        }
        if ($PackageConfig.PSObject.Properties['PackageFileStagingRootDirectory']) {
            $tokens['packageFileStagingDirectory'] = $PackageConfig.PackageFileStagingRootDirectory
        }
        if ($PackageConfig.PSObject.Properties['PackageInstallStageRootDirectory']) {
            $tokens['packageInstallStageDirectory'] = $PackageConfig.PackageInstallStageRootDirectory
        }
        if ($PackageConfig.PSObject.Properties['DefaultPackageDepotDirectory']) {
            $tokens['defaultPackageDepotDirectory'] = $PackageConfig.DefaultPackageDepotDirectory
        }
    }
    if ($Package) {
        $tokens['packageId'] = if ($Package.PSObject.Properties['id']) { [string]$Package.id } else { $null }
        $tokens['releaseId'] = if ($Package.PSObject.Properties['id']) { [string]$Package.id } else { $null }
        $tokens['releaseTrack'] = if ($Package.PSObject.Properties['releaseTrack']) { [string]$Package.releaseTrack } else { $tokens['releaseTrack'] }
        $tokens['version'] = if ($Package.PSObject.Properties['version']) { [string]$Package.version } else { $null }
        $tokens['artifactDistributionVariant'] = if ($Package.PSObject.Properties['artifactDistributionVariant']) { [string]$Package.artifactDistributionVariant } else { $null }
        $tokens['artifactTargetId'] = if ($Package.PSObject.Properties['artifactTargetId']) { [string]$Package.artifactTargetId } else { $null }
    }
    foreach ($key in @($ExtraTokens.Keys)) {
        $tokens[$key] = $ExtraTokens[$key]
    }

    if ($SanitizePathSegments) {
        foreach ($key in @($tokens.Keys)) {
            if ($null -eq $tokens[$key]) {
                continue
            }
            $tokens[$key] = ConvertTo-PackageSafePathSegment -Value ([string]$tokens[$key])
        }
    }

    return $tokens
}

function Resolve-PackageLayoutRelativeDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Template,

        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig,

        [Parameter(Mandatory = $true)]
        [psobject]$Package,

        [hashtable]$ExtraTokens = @{}
    )

    $tokens = Get-PackageTemplateTokenMap -PackageConfig $PackageConfig -Package $Package -ExtraTokens $ExtraTokens -SanitizePathSegments
    $resolvedPath = (Resolve-TemplateText -Text $Template -Tokens $tokens).Trim() -replace '/', '\'
    if ([string]::IsNullOrWhiteSpace($resolvedPath)) {
        throw 'Package layout template produced an empty relative path.'
    }
    if ([System.IO.Path]::IsPathRooted($resolvedPath)) {
        throw "Package layout template '$Template' produced rooted path '$resolvedPath'. Layout values must be relative."
    }

    $safeSegments = foreach ($segment in @($resolvedPath -split '\\')) {
        ConvertTo-PackageSafePathSegment -Value $segment
    }

    return (($safeSegments -join '\') -replace '/', '\')
}

function Get-PackagePackageDepotRelativeDirectory {
<#
.SYNOPSIS
Builds the relative package-file directory for depot storage.

.DESCRIPTION
Derives the durable relative directory used below package depots from the
configured depot layout template.

.PARAMETER PackageConfig
The resolved Package config object.

.PARAMETER Package
The selected release object.

.EXAMPLE
Get-PackagePackageDepotRelativeDirectory -PackageConfig $config -Package $package
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig,

        [Parameter(Mandatory = $true)]
        [psobject]$Package
    )

    $template = if ($PackageConfig.PSObject.Properties['PackageDepotRelativePathTemplate'] -and
        -not [string]::IsNullOrWhiteSpace([string]$PackageConfig.PackageDepotRelativePathTemplate)) {
        [string]$PackageConfig.PackageDepotRelativePathTemplate
    }
    else {
        '{definitionId}/{releaseTrack}/{version}/{artifactDistributionVariant}'
    }

    return Resolve-PackageLayoutRelativeDirectory -Template $template -PackageConfig $PackageConfig -Package $Package
}

function Get-PackagePackageWorkSlotDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig,

        [Parameter(Mandatory = $true)]
        [psobject]$Package
    )

    $definitionId = [string]$PackageConfig.DefinitionId
    $releaseTrack = if ($Package.PSObject.Properties['releaseTrack']) { [string]$Package.releaseTrack } else { [string]$PackageConfig.ReleaseTrack }
    $version = if ($Package.PSObject.Properties['version']) { [string]$Package.version } else { $null }
    $artifactDistributionVariant = if ($Package.PSObject.Properties['artifactDistributionVariant']) { [string]$Package.artifactDistributionVariant } else { $null }
    foreach ($requiredValue in @($definitionId, $releaseTrack, $version, $artifactDistributionVariant)) {
        if ([string]::IsNullOrWhiteSpace($requiredValue)) {
            throw 'Package work slot derivation requires definition id, releaseTrack, version, and artifactDistributionVariant.'
        }
    }

    $slotIdentity = '{0}|{1}|{2}|{3}' -f $definitionId, $releaseTrack, $version, $artifactDistributionVariant
    $slotHash = Get-StableShortHash -InputText $slotIdentity -Length 8
    $template = if ($PackageConfig.PSObject.Properties['PackageWorkSlotDirectoryTemplate'] -and
        -not [string]::IsNullOrWhiteSpace([string]$PackageConfig.PackageWorkSlotDirectoryTemplate)) {
        [string]$PackageConfig.PackageWorkSlotDirectoryTemplate
    }
    else {
        '{definitionId}-{slotHash}'
    }

    return Resolve-PackageLayoutRelativeDirectory -Template $template -PackageConfig $PackageConfig -Package $Package -ExtraTokens @{ slotHash = $slotHash }
}
