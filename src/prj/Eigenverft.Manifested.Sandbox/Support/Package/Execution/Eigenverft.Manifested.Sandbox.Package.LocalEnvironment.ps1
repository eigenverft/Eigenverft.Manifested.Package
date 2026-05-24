<#
    Eigenverft.Manifested.Sandbox.Package.LocalEnvironment
#>

function Get-PackageLocalEnvironmentMarkerPath {
<#
.SYNOPSIS
Returns the one-time local Package environment marker path.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig
    )

    $applicationRootDirectory = [string]$PackageConfig.ApplicationRootDirectory
    if ([string]::IsNullOrWhiteSpace($applicationRootDirectory)) {
        $applicationRootDirectory = Get-PackageDefaultApplicationRootDirectory
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Join-Path $applicationRootDirectory 'State') 'PackageLocalEnvironment.json'))
}

function Add-PackageLocalEnvironmentDirectoryCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IList]$Candidates,

        [AllowNull()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $Candidates.Add([System.IO.Path]::GetFullPath($Path)) | Out-Null
}

function Initialize-PackageLocalEnvironment {
<#
.SYNOPSIS
Creates the local Package base directory layout once per user profile.

.DESCRIPTION
If the local environment marker exists, this helper skips all directory checks
and returns immediately. Missing feature-specific paths are still handled by
the existing lazy creation paths elsewhere in the Package flow.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig
    )

    $markerPath = Get-PackageLocalEnvironmentMarkerPath -PackageConfig $PackageConfig
    if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        return [pscustomobject]@{
            Status              = 'AlreadyInitialized'
            InitializedNow      = $false
            MarkerPath          = $markerPath
            CreatedDirectories  = @()
            ExistingDirectories = @()
            SkippedSources      = @()
        }
    }

    $applicationRootDirectory = [string]$PackageConfig.ApplicationRootDirectory
    if ([string]::IsNullOrWhiteSpace($applicationRootDirectory)) {
        $applicationRootDirectory = Get-PackageDefaultApplicationRootDirectory
    }

    $directoryCandidates = [System.Collections.Generic.List[string]]::new()
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path $applicationRootDirectory
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path (Split-Path -Parent $markerPath)
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path (Split-Path -Parent (Get-PackageLocalConfigPath))
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path (Split-Path -Parent (Get-PackageLocalDepotInventoryPath))
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path (Split-Path -Parent (Get-PackageLocalEndpointInventoryPath))
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path (Split-Path -Parent (Get-PackageLocalPublisherInventoryPath))
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path (Join-Path (Join-Path $applicationRootDirectory 'Configuration') 'External')
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path (Split-Path -Parent ([string]$PackageConfig.PackageAssignmentInventoryFilePath))
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path (Split-Path -Parent ([string]$PackageConfig.PackageOperationHistoryFilePath))
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path ([string]$PackageConfig.PreferredTargetInstallRootDirectory)
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path ([string]$PackageConfig.PackageFileStagingRootDirectory)
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path ([string]$PackageConfig.PackageInstallStageRootDirectory)
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path ([string]$PackageConfig.LocalEndpointRoot)
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path ([string]$PackageConfig.ShimDirectory)
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path (Join-Path $applicationRootDirectory 'Caches')
    Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path (Join-Path (Join-Path $applicationRootDirectory 'Caches') 'npm')

    $skippedSources = @()
    $environmentSources = $PackageConfig.EnvironmentSources
    if ($environmentSources) {
        foreach ($sourceProperty in @($environmentSources.PSObject.Properties)) {
            $source = $sourceProperty.Value
            if (-not [string]::Equals([string]$source.kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            if ($source.writable -and $source.ensureExists -and -not [string]::IsNullOrWhiteSpace([string]$source.basePath)) {
                Add-PackageLocalEnvironmentDirectoryCandidate -Candidates $directoryCandidates -Path ([string]$source.basePath)
            }
            else {
                $skippedSources += [pscustomobject]@{
                    SourceId = [string]$source.id
                    Kind     = [string]$source.kind
                    Reason   = 'NotWritableOrEnsureExistsFalse'
                }
            }
        }
    }

    $createdDirectories = @()
    $existingDirectories = @()
    $seenDirectories = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($directoryPath in @($directoryCandidates)) {
        if ([string]::IsNullOrWhiteSpace($directoryPath)) {
            continue
        }

        $normalizedDirectoryPath = [System.IO.Path]::GetFullPath($directoryPath)
        if (-not $seenDirectories.Add($normalizedDirectoryPath)) {
            continue
        }

        if (Test-Path -LiteralPath $normalizedDirectoryPath -PathType Container) {
            $existingDirectories += $normalizedDirectoryPath
            continue
        }

        $null = New-Item -ItemType Directory -Path $normalizedDirectoryPath -Force
        $createdDirectories += $normalizedDirectoryPath
    }

    [ordered]@{
        schemaVersion = 1
        initializedAtUtc = [DateTime]::UtcNow.ToString('o')
        applicationRootDirectory = [System.IO.Path]::GetFullPath($applicationRootDirectory)
        directoryVersion = 1
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $markerPath -Encoding UTF8

    return [pscustomobject]@{
        Status              = 'Initialized'
        InitializedNow      = $true
        MarkerPath          = $markerPath
        CreatedDirectories  = @($createdDirectories)
        ExistingDirectories = @($existingDirectories)
        SkippedSources      = @($skippedSources)
    }
}
