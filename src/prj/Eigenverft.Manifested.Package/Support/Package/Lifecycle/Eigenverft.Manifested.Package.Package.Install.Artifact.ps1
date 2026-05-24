<#
    Eigenverft.Manifested.Package.Package.Install - archive expansion and single-file package placement.
    Dot-sourced from Eigenverft.Manifested.Package.psm1 (mirrored in TestImports.ps1) before Package.Install.ps1.
#>

function Install-PackageArchive {
<#
.SYNOPSIS
Installs a package by expanding an archive into the install directory.

.DESCRIPTION
Expands the saved package file into a stage directory, promotes the expanded
root into the final install directory, and creates any extra directories that
the install block requests.

.PARAMETER PackageResult
The Package result object to install.

.EXAMPLE
Install-PackageArchive -PackageResult $result
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if ([string]::IsNullOrWhiteSpace($PackageResult.PackageFilePath) -or -not (Test-Path -LiteralPath $PackageResult.PackageFilePath)) {
        throw "Package archive install for '$($PackageResult.PackageId)' requires a saved package file."
    }

    $install = Get-PackageAssignedInstallOperation -Release $PackageResult.Package
    if (-not $install) {
        throw "Package archive install for '$($PackageResult.PackageId)' requires an assigned block on the selected release."
    }
    if ([string]::IsNullOrWhiteSpace([string]$PackageResult.PackageInstallStageDirectory)) {
        throw "Package archive install for '$($PackageResult.PackageId)' requires a package install stage directory."
    }

    $stagePath = [System.IO.Path]::GetFullPath([string]$PackageResult.PackageInstallStageDirectory)
    Remove-PathIfExists -Path $stagePath | Out-Null
    Expand-ArchiveToDirectory -ArchivePath $PackageResult.PackageFilePath -DestinationDirectory $stagePath -Overwrite | Out-Null
    $expandedRoot = Get-ExpandedArchiveRoot -StagePath $stagePath
    if ($install.PSObject.Properties['expandedRoot'] -and
        -not [string]::IsNullOrWhiteSpace([string]$install.expandedRoot) -and
        [string]$install.expandedRoot -ne 'auto') {
        $expandedRoot = Join-Path $stagePath (([string]$install.expandedRoot) -replace '/', '\')
    }

    if (-not (Test-Path -LiteralPath $expandedRoot -PathType Container)) {
        throw "Expanded package root '$expandedRoot' was not found for '$($PackageResult.PackageId)'."
    }

    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $PackageResult.InstallDirectory) -Force
    if (Test-Path -LiteralPath $PackageResult.InstallDirectory) {
        Remove-Item -LiteralPath $PackageResult.InstallDirectory -Recurse -Force
    }

    New-Item -ItemType Directory -Path $PackageResult.InstallDirectory -Force | Out-Null
    Get-ChildItem -LiteralPath $expandedRoot -Force | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination $PackageResult.InstallDirectory -Force
    }

    foreach ($relativePath in @($install.createDirectories)) {
        $targetDirectory = Join-Path $PackageResult.InstallDirectory (([string]$relativePath) -replace '/', '\')
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    }

    return [pscustomobject]@{
        Status           = Get-PackageOwnedInstallStatus -PackageResult $PackageResult
        InstallKind      = 'expandArchive'
        InstallDirectory = $PackageResult.InstallDirectory
        ReusedExisting   = $false
    }
}

function Get-PackageInstalledFilePath {
<#
.SYNOPSIS
Resolves the final installed file path for a single-file package install.

.DESCRIPTION
Uses install.targetRelativePath when present and otherwise falls back to the
canonical packageFile.fileName so single-file resource packages can share one
simple install model.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $install = Get-PackageAssignedInstallOperation -Release $PackageResult.Package
    if (-not $install) {
        throw "Package single-file install for '$($PackageResult.PackageId)' requires an assigned block on the selected release."
    }
    $targetRelativePath = $null
    if ($install.PSObject.Properties['targetRelativePath'] -and
        -not [string]::IsNullOrWhiteSpace([string]$install.targetRelativePath)) {
        $targetRelativePath = ([string]$install.targetRelativePath) -replace '/', '\'
    }
    elseif ($PackageResult.Package -and
        $PackageResult.Package.PSObject.Properties['packageFile'] -and
        $PackageResult.Package.packageFile -and
        $PackageResult.Package.packageFile.PSObject.Properties['fileName'] -and
        -not [string]::IsNullOrWhiteSpace([string]$PackageResult.Package.packageFile.fileName)) {
        $targetRelativePath = [string]$PackageResult.Package.packageFile.fileName
    }
    else {
        throw "Package single-file install for '$($PackageResult.PackageId)' requires assigned.targetRelativePath or packageFile.fileName."
    }

    return (Join-Path $PackageResult.InstallDirectory $targetRelativePath)
}

function Install-PackagePackageFile {
<#
.SYNOPSIS
Installs a package by placing one saved package file into the install directory.

.DESCRIPTION
Creates or replaces the target install directory, then copies the verified
saved package file into the configured target-relative path.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if ([string]::IsNullOrWhiteSpace($PackageResult.PackageFilePath) -or -not (Test-Path -LiteralPath $PackageResult.PackageFilePath -PathType Leaf)) {
        throw "Package single-file install for '$($PackageResult.PackageId)' requires a saved package file."
    }

    $installedFilePath = Get-PackageInstalledFilePath -PackageResult $PackageResult
    $targetDirectory = Split-Path -Parent $installedFilePath

    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $PackageResult.InstallDirectory) -Force
    if (Test-Path -LiteralPath $PackageResult.InstallDirectory) {
        Remove-PathIfExists -Path $PackageResult.InstallDirectory | Out-Null
    }

    $null = New-Item -ItemType Directory -Path $PackageResult.InstallDirectory -Force
    if (-not [string]::IsNullOrWhiteSpace($targetDirectory)) {
        $null = New-Item -ItemType Directory -Path $targetDirectory -Force
    }

    $null = Copy-FileToPath -SourcePath $PackageResult.PackageFilePath -TargetPath $installedFilePath -Overwrite

    return [pscustomobject]@{
        Status           = Get-PackageOwnedInstallStatus -PackageResult $PackageResult
        InstallKind      = 'placePackageFile'
        InstallDirectory = $PackageResult.InstallDirectory
        InstalledFilePath = $installedFilePath
        PackageFilePath  = $PackageResult.PackageFilePath
        ReusedExisting   = $false
    }
}
