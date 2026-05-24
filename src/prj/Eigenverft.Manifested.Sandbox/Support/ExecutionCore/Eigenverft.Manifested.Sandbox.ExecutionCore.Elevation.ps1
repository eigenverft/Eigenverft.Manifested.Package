<#
    Eigenverft.Manifested.Sandbox.ExecutionEngine.Elevation
#>

function Test-ProcessElevation {
<#
.SYNOPSIS
Returns whether the current process is elevated.

.DESCRIPTION
Checks Windows administrator token state. Non-Windows hosts return false so
callers can make platform-specific elevation decisions explicitly.

.EXAMPLE
Test-ProcessElevation
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
        return $false
    }

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

