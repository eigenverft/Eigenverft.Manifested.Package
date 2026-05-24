<#
.SYNOPSIS
Reports the longest path(s) inside a .zip and the combined length after a typical install prefix.

.DESCRIPTION
Use on a dev machine with long paths enabled to fully expand archives that exceed classic MAX_PATH
when placed under a long prefix (e.g. Evf.Sandbox install layout). On a machine without long-path
support, expansion may fail or omit entries - use this script to see predicted lengths first.

.PARAMETER ZipPath
Path to the archive (e.g. VSCode-win32-x64-*.zip).

.PARAMETER InstallDirectoryPrefix
Directory that simulates the final package install root (no trailing slash required).
Default matches a typical Windows Sandbox + Evf.Sandbox VSCodeRuntime layout.

.PARAMETER InstallLayout
Auto (default) predicts final paths the same way Get-ExpandedArchiveRoot does: if the archive
would expand with exactly one top-level directory and no top-level files, paths use that folder
stripped; otherwise the full entry path is placed under the install prefix (typical VS Code zips).

.PARAMETER StripFirstZipPathSegment
Forces strip-first-segment behavior. Wrong for archives with several top-level items (e.g. VS Code
ships Code.exe, bin/, and a hash folder). Prefer the default InstallLayout Auto.

.PARAMETER Materialize
Runs Expand-Archive into -MaterializeDestination (same backend the module uses for zips).

.PARAMETER MaterializeDestination
Directory to extract into when -Materialize is set. Created if missing. Default under %TEMP%.

.PARAMETER UseModuleExpandArchive
When used with -Materialize, dot-sources ExecutionCore.Archive.ps1 from this repository and calls
Expand-ArchiveToDirectory (same entry point as the package install path) instead of Expand-Archive directly.

.PARAMETER ShowTop
When greater than 0, prints that many longest combined paths after the summary.

.EXAMPLE
./Test-ZipLongPathProbe.ps1 -ZipPath 'D:\dl\VSCode-win32-x64-1.119.0.zip'

.EXAMPLE
./Test-ZipLongPathProbe.ps1 -ZipPath '...\VSCode-win32-x64-1.119.0.zip' -Materialize -MaterializeDestination 'D:\tmp\vscode-probe'

.EXAMPLE
./Test-ZipLongPathProbe.ps1 -ZipPath '...\VSCode-win32-x64-1.119.0.zip' -Materialize -UseModuleExpandArchive
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,

    [Parameter(Mandatory = $false)]
    [string]$InstallDirectoryPrefix = 'C:\Users\WDAGUtilityAccount\AppData\Local\Programs\Evf.Sandbox\Inst\vsc-rt\stable\1.119.0\win32-x64',

    [ValidateSet('Auto', 'StripSingleRoot', 'Full')]
    [string]$InstallLayout = 'Auto',

    [switch]$StripFirstZipPathSegment,

    [ValidateRange(0, 50)]
    [int]$ShowTop = 0,

    [switch]$Materialize,

    [Parameter(Mandatory = $false)]
    [string]$MaterializeDestination = $(Join-Path $env:TEMP ('evf-zip-longpath-probe-{0}' -f [Guid]::NewGuid().ToString('N').Substring(0, 8))),

    [switch]$UseModuleExpandArchive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedZip = [System.IO.Path]::GetFullPath($ZipPath)
if (-not (Test-Path -LiteralPath $resolvedZip -PathType Leaf)) {
    throw "Zip not found: $resolvedZip"
}

$prefix = [System.IO.Path]::GetFullPath($InstallDirectoryPrefix)

$resolvedLayout = if ($StripFirstZipPathSegment) { 'StripSingleRoot' } else { $InstallLayout }

function Get-ZipEntryNormalizedFilePath {
    param([string]$EntryFullName)
    return (($EntryFullName -replace '/', [System.IO.Path]::DirectorySeparatorChar).TrimEnd([System.IO.Path]::DirectorySeparatorChar))
}

function Get-InstallLayoutFromZipFilePaths {
    param([string[]]$NormalizedFilePaths)
    $rootFileCount = 0
    $firstSegs = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $NormalizedFilePaths) {
        $idx = $p.IndexOf([System.IO.Path]::DirectorySeparatorChar)
        if ($idx -lt 0) {
            $rootFileCount++
        }
        else {
            [void]$firstSegs.Add($p.Substring(0, $idx))
        }
    }
    if ($rootFileCount -eq 0 -and $firstSegs.Count -eq 1) {
        return 'StripSingleRoot'
    }
    return 'Full'
}

function Get-InstalledRelativePath {
    param(
        [string]$EntryFullName,
        [ValidateSet('StripSingleRoot', 'Full')]
        [string]$Layout
    )
    $rel = Get-ZipEntryNormalizedFilePath -EntryFullName $EntryFullName
    if ([string]::IsNullOrWhiteSpace($rel)) {
        return $null
    }
    if ($Layout -eq 'StripSingleRoot') {
        $idx = $rel.IndexOf([System.IO.Path]::DirectorySeparatorChar)
        if ($idx -ge 0 -and $idx -lt ($rel.Length - 1)) {
            return $rel.Substring($idx + 1)
        }
        return $null
    }
    return $rel
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($resolvedZip)
try {
    $normPaths = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $zip.Entries) {
        if ($null -eq $entry -or [string]::IsNullOrWhiteSpace($entry.FullName)) {
            continue
        }
        if ($entry.FullName.EndsWith('/')) {
            continue
        }
        $normPaths.Add((Get-ZipEntryNormalizedFilePath -EntryFullName $entry.FullName)) | Out-Null
    }

    if ($normPaths.Count -eq 0) {
        Write-Warning 'No file entries found in zip (after filters).'
        return
    }

    $effectiveLayout = if ([string]::Equals($resolvedLayout, 'Auto', [System.StringComparison]::OrdinalIgnoreCase)) {
        Get-InstallLayoutFromZipFilePaths -NormalizedFilePaths ($normPaths.ToArray())
    }
    else {
        $resolvedLayout
    }

    $rows = New-Object System.Collections.Generic.List[object]
    $maxZipEntryLen = 0
    $maxZipEntryName = [string]$null
    foreach ($entry in $zip.Entries) {
        if ($null -eq $entry -or [string]::IsNullOrWhiteSpace($entry.FullName)) {
            continue
        }
        if ($entry.FullName.EndsWith('/')) {
            continue
        }
        $zipPathNorm = Get-ZipEntryNormalizedFilePath -EntryFullName $entry.FullName
        if ($zipPathNorm.Length -gt $maxZipEntryLen) {
            $maxZipEntryLen = $zipPathNorm.Length
            $maxZipEntryName = $zipPathNorm
        }
        $rel = Get-InstalledRelativePath -EntryFullName $entry.FullName -Layout $effectiveLayout
        if ([string]::IsNullOrWhiteSpace($rel)) {
            continue
        }
        $combined = [System.IO.Path]::GetFullPath((Join-Path $prefix $rel))
        $rows.Add([pscustomobject]@{
                ZipEntry             = $entry.FullName
                AdjustedRelative     = $rel
                CombinedPath         = $combined
                CombinedLength       = $combined.Length
                EntryCompressedBytes = $entry.Length
            }) | Out-Null
    }

    if ($rows.Count -eq 0) {
        Write-Warning 'No file entries found in zip (after filters).'
        return
    }

    $sorted = $rows | Sort-Object -Property CombinedLength -Descending
    $maxLen = [int]($sorted[0].CombinedLength)
    $maxRelLen = [int](($rows | ForEach-Object { $_.AdjustedRelative.Length } | Measure-Object -Maximum).Maximum)

    Write-Host '--- Zip ---'
    Write-Host ("Longest path inside zip: {0} characters" -f $maxZipEntryLen)
    Write-Host ("  {0}" -f $maxZipEntryName)
    Write-Host ''
    Write-Host '--- Install location (prefix you add) ---'
    Write-Host ("Effective install layout: {0} (matches Get-ExpandedArchiveRoot when Auto)" -f $effectiveLayout)
    Write-Host ("Install prefix length: {0} characters" -f $prefix.Length)
    Write-Host ("  {0}" -f $prefix)
    $relDesc = if ($effectiveLayout -eq 'StripSingleRoot') {
        'Longest relative under prefix (single top-level folder stripped)'
    }
    else {
        'Longest relative under prefix (full archive paths; stage root = expanded root)'
    }
    Write-Host ("{0}: {1} characters" -f $relDesc, $maxRelLen)
    Write-Host ''
    Write-Host '--- On disk (prefix + relative) ---'
    Write-Host ("Max combined path length: {0} (classic MAX_PATH is 260)" -f $maxLen)
    if ($maxLen -gt 260) {
        Write-Host 'WARNING: Combined path exceeds 260 characters; machines without long-path support may fail expand or recursive delete.' -ForegroundColor Yellow
    }
    if ($ShowTop -gt 0) {
        Write-Host ''
        Write-Host ("Top {0} longest combined paths:" -f $ShowTop)
        $sorted | Select-Object -First $ShowTop CombinedLength, CombinedPath, ZipEntry | Format-Table -AutoSize -Wrap
    }

    if ($Materialize) {
        $dest = [System.IO.Path]::GetFullPath($MaterializeDestination)
        if (Test-Path -LiteralPath $dest) {
            Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction Stop
        }
        $null = New-Item -ItemType Directory -Path $dest -Force
        Write-Host ''
        if ($UseModuleExpandArchive) {
            $archivePs1 = Join-Path $PSScriptRoot '..\src\prj\Eigenverft.Manifested.Sandbox\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.Archive.ps1'
            $archivePs1 = [System.IO.Path]::GetFullPath($archivePs1)
            if (-not (Test-Path -LiteralPath $archivePs1 -PathType Leaf)) {
                throw "Could not find module archive helper at: $archivePs1"
            }
            . $archivePs1
            Write-Host ("Materializing with Expand-ArchiveToDirectory (repo) -> {0}" -f $dest)
            $null = Expand-ArchiveToDirectory -ArchivePath $resolvedZip -DestinationDirectory $dest -Overwrite
        }
        else {
            Write-Host ("Materializing with Expand-Archive -> {0}" -f $dest)
            Expand-Archive -LiteralPath $resolvedZip -DestinationPath $dest -Force
        }

        $longestOnDisk = Get-ChildItem -LiteralPath $dest -Recurse -File -Force -ErrorAction SilentlyContinue |
            ForEach-Object { $_.FullName } |
            Sort-Object { $_.Length } -Descending |
            Select-Object -First 15
        Write-Host ''
        Write-Host 'Top 15 longest paths on disk after expand (character length):'
        foreach ($p in $longestOnDisk) {
            Write-Host ("{0}  {1}" -f $p.Length, $p)
        }
        Write-Host ''
        Write-Host "Materialized root: $dest"
    }
}
finally {
    $zip.Dispose()
}
