<#
    Eigenverft.Manifested.Sandbox.ExecutionEngine.SystemResources
#>

function Get-PhysicalMemoryGiB {
<#
.SYNOPSIS
Returns total physical memory in GiB for the current machine.

.DESCRIPTION
Reads Win32_ComputerSystem through CIM and returns total installed physical
memory as a GiB double value. Returns $null when the value cannot be resolved.
#>
    [CmdletBinding()]
    [OutputType([double])]
    param()

    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop | Select-Object -First 1
        if ($null -eq $computerSystem -or $null -eq $computerSystem.TotalPhysicalMemory) {
            return $null
        }

        $totalBytes = [uint64]$computerSystem.TotalPhysicalMemory
        if ($totalBytes -le 0) {
            return $null
        }

        return [double]($totalBytes / 1GB)
    }
    catch {
        return $null
    }
}

function Get-VideoMemoryGiB {
<#
.SYNOPSIS
Returns the highest reported video memory value in GiB for the current machine.

.DESCRIPTION
Reads Win32_VideoController through CIM and returns the maximum valid
AdapterRAM value as a GiB double value. Returns $null when no valid adapter
memory can be resolved.
#>
    [CmdletBinding()]
    [OutputType([double])]
    param()

    try {
        $videoControllers = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop)
    }
    catch {
        return $null
    }

    $highestBytes = [uint64]0
    foreach ($videoController in @($videoControllers)) {
        if ($null -eq $videoController -or $null -eq $videoController.AdapterRAM) {
            continue
        }

        try {
            $adapterBytes = [uint64]$videoController.AdapterRAM
        }
        catch {
            continue
        }

        if ($adapterBytes -gt $highestBytes) {
            $highestBytes = $adapterBytes
        }
    }

    if ($highestBytes -le 0) {
        return $null
    }

    return [double]($highestBytes / 1GB)
}

function Test-PhysicalOrVideoMemoryRequirement {
<#
.SYNOPSIS
Checks whether physical RAM or VRAM satisfies one GiB threshold.

.DESCRIPTION
Evaluates the current machine against a numeric threshold using OR semantics:
the check passes when either physical memory or video memory satisfies the
configured operator and value.

.PARAMETER Operator
The numeric comparison operator. Supported values are =, ==, !=, >, >=, <, <=.

.PARAMETER ValueGiB
The required GiB threshold.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operator,

        [Parameter(Mandatory = $true)]
        [double]$ValueGiB
    )

    $testNumericValue = {
        param(
            [AllowNull()]
            [object]$ActualGiB
        )

        if ($null -eq $ActualGiB) {
            return $false
        }

        $actualNumericValue = [double]$ActualGiB

        switch -Exact ($Operator) {
            '=' { return $actualNumericValue -eq $ValueGiB }
            '==' { return $actualNumericValue -eq $ValueGiB }
            '!=' { return $actualNumericValue -ne $ValueGiB }
            '>' { return $actualNumericValue -gt $ValueGiB }
            '>=' { return $actualNumericValue -ge $ValueGiB }
            '<' { return $actualNumericValue -lt $ValueGiB }
            '<=' { return $actualNumericValue -le $ValueGiB }
            default { throw "Unsupported numeric operator '$Operator'." }
        }
    }

    $physicalMemoryGiB = Get-PhysicalMemoryGiB
    $videoMemoryGiB = Get-VideoMemoryGiB
    $physicalAccepted = & $testNumericValue $physicalMemoryGiB
    $videoAccepted = & $testNumericValue $videoMemoryGiB

    return [pscustomobject]@{
        Accepted          = ($physicalAccepted -or $videoAccepted)
        PhysicalMemoryGiB = $physicalMemoryGiB
        VideoMemoryGiB    = $videoMemoryGiB
    }
}

