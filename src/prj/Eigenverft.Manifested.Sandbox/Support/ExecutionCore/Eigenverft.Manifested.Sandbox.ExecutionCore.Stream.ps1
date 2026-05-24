<#
    Eigenverft.Manifested.Sandbox.ExecutionCore.Stream

    Small binary stream helpers shared by archive readers.
#>

function Read-ExactBytesFromStream {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.Stream]$Stream,

        [Parameter(Mandatory = $true)]
        [long]$Length,

        [Parameter(Mandatory = $true)]
        [string]$Context
    )

    if ($Length -lt 0) {
        throw "Cannot read a negative byte count for $Context."
    }
    if ($Length -gt [int]::MaxValue) {
        throw "Cannot read $Length bytes for $Context into memory."
    }

    $buffer = New-Object byte[] ([int]$Length)
    $offset = 0
    while ($offset -lt $Length) {
        $read = $Stream.Read($buffer, $offset, ([int]$Length - $offset))
        if ($read -le 0) {
            throw "Unexpected end of archive while reading $Context."
        }
        $offset += $read
    }

    return $buffer
}

function Skip-BytesFromStream {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.Stream]$Stream,

        [Parameter(Mandatory = $true)]
        [long]$Length,

        [Parameter(Mandatory = $true)]
        [string]$Context
    )

    if ($Length -lt 0) {
        throw "Cannot skip a negative byte count for $Context."
    }

    $buffer = New-Object byte[] 8192
    $remaining = $Length
    while ($remaining -gt 0) {
        $readLength = [Math]::Min([int64]$buffer.Length, $remaining)
        $read = $Stream.Read($buffer, 0, [int]$readLength)
        if ($read -le 0) {
            throw "Unexpected end of archive while skipping $Context."
        }
        $remaining -= $read
    }
}
