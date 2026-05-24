<#
    Eigenverft.Manifested.Sandbox.ExecutionEngine.CommandResolution
#>

function Get-ResolvedApplicationPath {
<#
.SYNOPSIS
Resolves the first application path for a command name.

.DESCRIPTION
Uses PowerShell command discovery to find the first application match for the
requested command name and returns a normalized full path when one is found.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    $command = @(Get-Command -Name $CommandName -CommandType Application -All -ErrorAction SilentlyContinue | Select-Object -First 1)
    if (-not $command) {
        return $null
    }

    $commandPath = $null
    if ($command[0].PSObject.Properties['Path'] -and $command[0].Path) {
        $commandPath = [string]$command[0].Path
    }
    elseif ($command[0].PSObject.Properties['Source'] -and $command[0].Source) {
        $commandPath = [string]$command[0].Source
    }

    if ([string]::IsNullOrWhiteSpace($commandPath)) {
        return $null
    }

    try {
        return [System.IO.Path]::GetFullPath($commandPath)
    }
    catch {
        return $commandPath
    }
}

