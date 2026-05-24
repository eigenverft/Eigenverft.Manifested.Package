<#
    Eigenverft.Manifested.Package.ExecutionCore.Archive

    Zip/archive expansion and temporary archive staging helpers.

    - Expand-ArchiveToDirectory - what Package and callers use: path checks, destination
      creation, .nupkg->.zip alias, then extract.
    - Expand-ZipArchiveFileToDirectory - internal seam: .zip file + existing directory ->
      bytes on disk. Replace its body (Expand-Archive today) with PS 5.1-friendly .NET
      ZipFile / long-path logic when needed; keep Expand-ArchiveToDirectory unchanged.
    - Get-ExpandedArchiveRoot - layout heuristic for callers that expand into their own
      scoped staging directory.

    TAR and GZip helpers intentionally live in separate ExecutionCore files.
#>

function Expand-ZipArchiveFileToDirectory {
<#
.SYNOPSIS
Extracts a .zip file into an existing destination directory.

.DESCRIPTION
Not the main entry point - use Expand-ArchiveToDirectory from outside this module.
Callers pass a resolved .zip path (.nupkg must already be aliased to .zip by Expand-ArchiveToDirectory).
This function is the single place to swap Expand-Archive for a .NET-based extractor.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDirectory,

        [switch]$Overwrite
    )

    if ([string]::IsNullOrWhiteSpace($ZipArchivePath)) {
        throw 'A zip archive path is required.'
    }

    if ([string]::IsNullOrWhiteSpace($DestinationDirectory)) {
        throw 'A destination directory is required.'
    }

    $resolvedZip = [System.IO.Path]::GetFullPath($ZipArchivePath)
    $resolvedDest = [System.IO.Path]::GetFullPath($DestinationDirectory)

    if (-not (Test-Path -LiteralPath $resolvedZip -PathType Leaf)) {
        throw "Zip archive '$resolvedZip' was not found."
    }

    $ext = [System.IO.Path]::GetExtension($resolvedZip)
    if (-not [string]::Equals($ext, '.zip', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Expand-ZipArchiveFileToDirectory expects a .zip file; got extension '$ext'."
    }

    if (-not (Test-Path -LiteralPath $resolvedDest -PathType Container)) {
        throw "Destination directory '$resolvedDest' must exist before extraction."
    }

    if ($Overwrite) {
        $null = Expand-Archive -LiteralPath $resolvedZip -DestinationPath $resolvedDest -Force
    }
    else {
        $null = Expand-Archive -LiteralPath $resolvedZip -DestinationPath $resolvedDest
    }

    return $resolvedDest
}

function Expand-ArchiveToDirectory {
<#
.SYNOPSIS
Expands an archive into a destination directory.

.DESCRIPTION
Ensures the destination directory exists, normalizes .nupkg to a temporary .zip
when needed, then calls Expand-ZipArchiveFileToDirectory for the actual extract.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDirectory,

        [switch]$Overwrite
    )

    if ([string]::IsNullOrWhiteSpace($ArchivePath)) {
        throw 'An archive path is required.'
    }

    if ([string]::IsNullOrWhiteSpace($DestinationDirectory)) {
        throw 'A destination directory is required.'
    }

    $resolvedArchivePath = [System.IO.Path]::GetFullPath($ArchivePath)
    if (-not (Test-Path -LiteralPath $resolvedArchivePath -PathType Leaf)) {
        throw "Archive '$resolvedArchivePath' was not found."
    }

    $resolvedDestinationDirectory = [System.IO.Path]::GetFullPath($DestinationDirectory)
    $null = New-Item -ItemType Directory -Path $resolvedDestinationDirectory -Force

    $archivePathForExpansion = $resolvedArchivePath
    $archiveAliasPath = $null
    if ([string]::Equals([System.IO.Path]::GetExtension($resolvedArchivePath), '.nupkg', [System.StringComparison]::OrdinalIgnoreCase)) {
        $archiveAliasPath = Join-Path $resolvedDestinationDirectory ('{0}.zip' -f [System.IO.Path]::GetFileNameWithoutExtension($resolvedArchivePath))
        Copy-Item -LiteralPath $resolvedArchivePath -Destination $archiveAliasPath -Force
        $archivePathForExpansion = $archiveAliasPath
    }

    try {
        $null = Expand-ZipArchiveFileToDirectory -ZipArchivePath $archivePathForExpansion -DestinationDirectory $resolvedDestinationDirectory -Overwrite:$Overwrite
    }
    finally {
        if ($archiveAliasPath -and (Test-Path -LiteralPath $archiveAliasPath)) {
            Remove-Item -LiteralPath $archiveAliasPath -Force -ErrorAction SilentlyContinue
        }
    }

    return $resolvedDestinationDirectory
}

function Get-ExpandedArchiveRoot {
<#
.SYNOPSIS
Resolves the effective expanded root inside a stage directory.

.DESCRIPTION
If the archive expands under one top-level directory and no files are written
directly to the stage root, the child directory is returned. Otherwise the
stage root itself is returned.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StagePath
    )

    if ([string]::IsNullOrWhiteSpace($StagePath)) {
        throw 'A stage path is required.'
    }

    $resolvedStagePath = [System.IO.Path]::GetFullPath($StagePath)
    if (-not (Test-Path -LiteralPath $resolvedStagePath -PathType Container)) {
        throw "Stage path '$resolvedStagePath' was not found."
    }

    $directories = @(Get-ChildItem -LiteralPath $resolvedStagePath -Directory -Force -ErrorAction SilentlyContinue)
    $files = @(Get-ChildItem -LiteralPath $resolvedStagePath -File -Force -ErrorAction SilentlyContinue)

    if ($directories.Count -eq 1 -and $files.Count -eq 0) {
        return $directories[0].FullName
    }

    return $resolvedStagePath
}
