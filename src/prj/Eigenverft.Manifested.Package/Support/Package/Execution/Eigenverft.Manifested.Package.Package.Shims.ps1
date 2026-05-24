<#
    Eigenverft.Manifested.Package.Package.Shims
#>

$script:PackageCommandShimMarker = 'Eigenverft.Manifested.Package Package Shim'

function Get-PackageCommandShimFileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    $safeName = $CommandName.Trim()
    foreach ($invalidChar in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safeName = $safeName.Replace([string]$invalidChar, '-')
    }

    if ([string]::IsNullOrWhiteSpace($safeName)) {
        throw "Package shim command name '$CommandName' does not produce a valid shim file name."
    }

    if ($safeName.EndsWith('.cmd', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $safeName
    }

    return "$safeName.cmd"
}

function Get-PackageCommandShimPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    if (-not $PackageResult.PackageConfig.PSObject.Properties['ShimDirectory'] -or
        [string]::IsNullOrWhiteSpace([string]$PackageResult.PackageConfig.ShimDirectory)) {
        throw 'Package shim registration requires PackageConfig.ShimDirectory.'
    }

    return [System.IO.Path]::GetFullPath((Join-Path ([string]$PackageResult.PackageConfig.ShimDirectory) (Get-PackageCommandShimFileName -CommandName $CommandName)))
}

function Get-PackageCommandShimMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ShimPath
    )

    $fullShimPath = [System.IO.Path]::GetFullPath($ShimPath)
    if (-not (Test-Path -LiteralPath $fullShimPath -PathType Leaf)) {
        return [pscustomobject]@{
            ShimPath      = $fullShimPath
            Exists        = $false
            IsPackageShim = $false
            DefinitionId  = $null
            CommandName   = $null
            TargetPath    = $null
        }
    }

    $content = Get-Content -LiteralPath $fullShimPath -Raw -ErrorAction Stop
    $parsedMetadata = @{
        definitionId = $null
        commandName  = $null
        targetPath   = $null
    }

    foreach ($line in ($content -split '\r?\n')) {
        $trimmedLine = $line.Trim()
        if ($trimmedLine -notmatch '^rem\s+(.+)$') {
            continue
        }

        $commentText = $Matches[1].Trim()
        foreach ($key in @('definitionId', 'commandName', 'targetPath')) {
            if ($commentText.StartsWith("$key=", [System.StringComparison]::OrdinalIgnoreCase)) {
                $parsedMetadata[$key] = $commentText.Substring($key.Length + 1)
            }
        }
    }

    return [pscustomobject]@{
        ShimPath      = $fullShimPath
        Exists        = $true
        IsPackageShim = $content.Contains($script:PackageCommandShimMarker)
        DefinitionId  = $parsedMetadata.definitionId
        CommandName   = $parsedMetadata.commandName
        TargetPath    = $parsedMetadata.targetPath
    }
}

function Test-PackageCommandShimOwnedByDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ShimPath,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId
    )

    $shimMetadata = Get-PackageCommandShimMetadata -ShimPath $ShimPath
    return ($shimMetadata.IsPackageShim -and
        [string]::Equals([string]$shimMetadata.DefinitionId, $DefinitionId, [System.StringComparison]::OrdinalIgnoreCase))
}

function New-PackageCommandShim {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [string]$CommandName,

        [string]$InstallDirectoryOverride
    )

    $baseInstallDirectory = if (-not [string]::IsNullOrWhiteSpace($InstallDirectoryOverride)) {
        $InstallDirectoryOverride
    }
    else {
        [string]$PackageResult.InstallDirectory
    }

    $targetPath = Resolve-PackagePresenceToolPath -Definition $PackageResult.PackageConfig.Definition -ToolKind 'commands' -Name $CommandName -InstallDirectory $baseInstallDirectory
    if ([string]::IsNullOrWhiteSpace($targetPath)) {
        throw "Package pathRegistration source shim '$CommandName' was not found in discovery.presence.commands."
    }
    if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
        throw "Package shim target path '$targetPath' was not found."
    }

    $shimPath = Get-PackageCommandShimPath -PackageResult $PackageResult -CommandName $CommandName
    $definitionId = [string]$PackageResult.DefinitionId
    if ([string]::IsNullOrWhiteSpace($definitionId)) {
        $definitionId = [string]$PackageResult.PackageConfig.DefinitionId
    }

    if (Test-Path -LiteralPath $shimPath -PathType Leaf) {
        $shimMetadata = Get-PackageCommandShimMetadata -ShimPath $shimPath
        if (-not (Test-PackageCommandShimOwnedByDefinition -ShimPath $shimPath -DefinitionId $definitionId)) {
            if ($shimMetadata.IsPackageShim -and -not [string]::IsNullOrWhiteSpace([string]$shimMetadata.DefinitionId)) {
                throw "Package shim '$shimPath' is already owned by definition '$($shimMetadata.DefinitionId)' and cannot be overwritten by definition '$definitionId'."
            }

            throw "Package shim '$shimPath' already exists and is not owned by Package."
        }
    }

    $writtenShimPath = New-CommandShim -ShimPath $shimPath -TargetPath $targetPath -Overwrite -HeaderLines @(
        $script:PackageCommandShimMarker
        "definitionId=$definitionId"
        "commandName=$CommandName"
        "targetPath=$([System.IO.Path]::GetFullPath($targetPath))"
    )

    Write-PackageExecutionMessage -Message ("[ACTION] Wrote command shim '{0}' -> '{1}'." -f $writtenShimPath, [System.IO.Path]::GetFullPath($targetPath))

    return [pscustomobject]@{
        CommandName = $CommandName
        ShimPath    = $writtenShimPath
        TargetPath  = [System.IO.Path]::GetFullPath($targetPath)
    }
}

function Remove-PackageCommandShimsForDefinition {
<#
.SYNOPSIS
Removes Package-owned command shims for the current definition.

.DESCRIPTION
Deletes shim files under ShimDirectory that carry Package shim metadata for
the definition identified on PackageResult.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $definitionId = [string]$PackageResult.DefinitionId
    if ([string]::IsNullOrWhiteSpace($definitionId)) {
        $definitionId = [string]$PackageResult.PackageConfig.DefinitionId
    }

    foreach ($command in @(Get-PackageDiscoveryPresenceEntryPoints -Definition $PackageResult.PackageConfig.Definition -ToolKind 'commands' -ExposedOnly)) {
        $commandName = [string]$command.name
        if ([string]::IsNullOrWhiteSpace($commandName)) {
            continue
        }
        $shimPath = Get-PackageCommandShimPath -PackageResult $PackageResult -CommandName $commandName
        if (-not (Test-Path -LiteralPath $shimPath -PathType Leaf)) {
            continue
        }
        if (-not (Test-PackageCommandShimOwnedByDefinition -ShimPath $shimPath -DefinitionId $definitionId)) {
            Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Skipping shim removal for '{0}' because it is not owned by definition '{1}'." -f $shimPath, $definitionId)
            continue
        }
        Remove-Item -LiteralPath $shimPath -Force -ErrorAction Stop
        Write-PackageExecutionMessage -Message ("[ACTION] Removed command shim '{0}'." -f $shimPath)
    }
}

