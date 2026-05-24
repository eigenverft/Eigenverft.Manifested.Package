<#
    Eigenverft.Manifested.Sandbox.ExecutionEngine.FileSystem
#>

function Remove-PathIfExists {
<#
.SYNOPSIS
Removes a file or directory when it exists.

.DESCRIPTION
Returns `$false` when the path is already missing. Otherwise removes the path
recursively and forcefully, then returns `$true`.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    if (Test-Path -LiteralPath $Path) {
        throw "Could not remove path '$Path'."
    }

    return $true
}

function Get-EmptyParentPruneCeilingDirectory {
<#
.SYNOPSIS
Resolves the directory ceiling for empty-parent pruning after deleting an inventory install path.

.DESCRIPTION
If InstallLeafPath lies under PreferredInstallRootDirectory (Inst), returns that Inst root so pruning
never leaves empty version folders above the package but stays inside the managed install tree.

If the leaf is outside Inst (for example an adopted path on another drive), returns the volume or
UNC share root of InstallLeafPath. Remove-EmptyParentDirectoryChain only removes empty directories
and never removes the ceiling directory itself, so pruning stays on that volume/share and stops at
the first non-empty parent.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallLeafPath,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$PreferredInstallRootDirectory
    )

    if ([string]::IsNullOrWhiteSpace($InstallLeafPath)) {
        return $null
    }

    $leafFull = [System.IO.Path]::GetFullPath($InstallLeafPath)

    if (-not [string]::IsNullOrWhiteSpace($PreferredInstallRootDirectory)) {
        $trimmed = $PreferredInstallRootDirectory.TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar)
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
            $instFull = [System.IO.Path]::GetFullPath($trimmed)
            if ([string]::Equals($leafFull, $instFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $instFull
            }
            $instPrefix = $instFull + [System.IO.Path]::DirectorySeparatorChar
            if ($leafFull.StartsWith($instPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $instFull
            }
        }
    }

    $root = [System.IO.Path]::GetPathRoot($leafFull)
    if ([string]::IsNullOrWhiteSpace($root)) {
        return $null
    }

    return [System.IO.Path]::GetFullPath($root)
}

function Remove-EmptyParentDirectoryChain {
<#
.SYNOPSIS
Removes empty parent directories from a deleted path up to a ceiling directory.

.DESCRIPTION
Walks from the immediate parent of DeletedLeafPath upward. Each directory is removed
only if it exists, is empty (no child files or directories), and is a strict
descendant of AncestorCeilingDirectory. The ceiling directory itself is never removed.
Stops at the first non-empty directory or when the path is no longer under the ceiling.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeletedLeafPath,

        [Parameter(Mandatory = $true)]
        [string]$AncestorCeilingDirectory
    )

    if ([string]::IsNullOrWhiteSpace($DeletedLeafPath) -or [string]::IsNullOrWhiteSpace($AncestorCeilingDirectory)) {
        return
    }

    $ceilingFull = [System.IO.Path]::GetFullPath($AncestorCeilingDirectory.TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar))
    $resolvedLeaf = [System.IO.Path]::GetFullPath($DeletedLeafPath)
    $current = Split-Path -Path $resolvedLeaf -Parent

    while (-not [string]::IsNullOrWhiteSpace($current)) {
        $currentFull = [System.IO.Path]::GetFullPath($current)

        if ([string]::Equals($currentFull, $ceilingFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            break
        }

        $ceilingPrefix = $ceilingFull + [System.IO.Path]::DirectorySeparatorChar
        if (-not $currentFull.StartsWith($ceilingPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            break
        }

        if (-not (Test-Path -LiteralPath $currentFull -PathType Container)) {
            break
        }

        $children = @(Get-ChildItem -LiteralPath $currentFull -Force -ErrorAction SilentlyContinue)
        if ($children.Count -gt 0) {
            break
        }

        Remove-PathIfExists -Path $currentFull | Out-Null
        $current = Split-Path -Path $currentFull -Parent
    }
}

function Copy-FileToPath {
<#
.SYNOPSIS
Copies one file to a target path.

.DESCRIPTION
Provides a thin execution seam over `Copy-Item` so callers do not depend on a
specific file-copy backend.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath,

        [switch]$Overwrite
    )

    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        throw 'A source file path is required.'
    }

    if ([string]::IsNullOrWhiteSpace($TargetPath)) {
        throw 'A target file path is required.'
    }

    if ($Overwrite) {
        Copy-Item -LiteralPath $SourcePath -Destination $TargetPath -Force
    }
    else {
        Copy-Item -LiteralPath $SourcePath -Destination $TargetPath
    }

    return (Resolve-Path -LiteralPath $TargetPath -ErrorAction Stop).Path
}

function New-CommandShim {
<#
.SYNOPSIS
Creates a small command shim script.

.DESCRIPTION
Writes a `.cmd` shim that forwards all arguments to a concrete target command.
The helper is intentionally generic so the Package layer can decide ownership,
name collision, and lifecycle policy.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ShimPath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath,

        [string[]]$HeaderLines = @(),

        [switch]$Overwrite
    )

    if ([string]::IsNullOrWhiteSpace($ShimPath)) {
        throw 'A shim path is required.'
    }

    if ([string]::IsNullOrWhiteSpace($TargetPath)) {
        throw 'A shim target path is required.'
    }

    $resolvedShimPath = [System.IO.Path]::GetFullPath($ShimPath)
    $resolvedTargetPath = [System.IO.Path]::GetFullPath($TargetPath)
    $shimDirectory = Split-Path -Parent $resolvedShimPath
    if (-not [string]::IsNullOrWhiteSpace($shimDirectory) -and -not (Test-Path -LiteralPath $shimDirectory -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $shimDirectory -Force
    }

    if ((Test-Path -LiteralPath $resolvedShimPath -PathType Leaf) -and -not $Overwrite.IsPresent) {
        throw "Command shim '$resolvedShimPath' already exists."
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('@echo off') | Out-Null
    foreach ($headerLine in @($HeaderLines)) {
        if (-not [string]::IsNullOrWhiteSpace($headerLine)) {
            $lines.Add(("rem {0}" -f [string]$headerLine)) | Out-Null
        }
    }
    $lines.Add(('call "{0}" %*' -f $resolvedTargetPath)) | Out-Null
    $lines.Add('exit /b %ERRORLEVEL%') | Out-Null

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($resolvedShimPath, (@($lines.ToArray()) -join "`r`n") + "`r`n", $encoding)

    return $resolvedShimPath
}

