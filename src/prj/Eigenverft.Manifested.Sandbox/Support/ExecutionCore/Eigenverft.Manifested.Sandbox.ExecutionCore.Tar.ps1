<#
    Eigenverft.Manifested.Sandbox.ExecutionCore.Tar

    Minimal TAR reader helpers. This file knows TAR records only; compression
    wrappers live elsewhere.
#>

function Read-TarHeaderTextField {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Header,

        [Parameter(Mandatory = $true)]
        [int]$Offset,

        [Parameter(Mandatory = $true)]
        [int]$Length
    )

    $end = $Offset
    $limit = $Offset + $Length
    while ($end -lt $limit -and $Header[$end] -ne 0) {
        $end++
    }

    if ($end -le $Offset) {
        return ''
    }

    return ([System.Text.Encoding]::ASCII.GetString($Header, $Offset, ($end - $Offset))).Trim()
}

function ConvertFrom-TarHeaderOctalSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Header
    )

    $sizeText = Read-TarHeaderTextField -Header $Header -Offset 124 -Length 12
    $sizeText = ($sizeText -replace "`0", '').Trim()
    if ([string]::IsNullOrWhiteSpace($sizeText)) {
        return [int64]0
    }

    try {
        return [Convert]::ToInt64($sizeText, 8)
    }
    catch {
        throw "TAR header contains an invalid octal size '$sizeText'."
    }
}

function Test-TarHeaderIsZeroBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Header
    )

    foreach ($value in $Header) {
        if ($value -ne 0) {
            return $false
        }
    }

    return $true
}

function Get-NormalizedTarEntryPath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Path
    )

    $normalized = ([string]$Path) -replace '\\', '/'
    $normalized = $normalized.Trim()
    while ($normalized.StartsWith('./', [System.StringComparison]::Ordinal)) {
        $normalized = $normalized.Substring(2)
    }
    return $normalized.TrimStart('/')
}

function Read-TarArchiveEntryBytes {
<#
.SYNOPSIS
Reads one file entry from an uncompressed TAR stream without extracting it.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.Stream]$Stream,

        [Parameter(Mandatory = $true)]
        [string]$EntryPath
    )

    if ([string]::IsNullOrWhiteSpace($EntryPath)) {
        throw 'A tar entry path is required.'
    }

    $targetEntryPath = Get-NormalizedTarEntryPath -Path $EntryPath
    while ($true) {
        $header = Read-ExactBytesFromStream -Stream $Stream -Length 512 -Context 'TAR header'
        if (Test-TarHeaderIsZeroBlock -Header $header) {
            break
        }

        $name = Read-TarHeaderTextField -Header $header -Offset 0 -Length 100
        $prefix = Read-TarHeaderTextField -Header $header -Offset 345 -Length 155
        $entryPath = if ([string]::IsNullOrWhiteSpace($prefix)) { $name } else { "$prefix/$name" }
        $entryPath = Get-NormalizedTarEntryPath -Path $entryPath
        $entrySize = ConvertFrom-TarHeaderOctalSize -Header $header
        $typeFlag = [char]$header[156]
        $paddingSize = (512 - ($entrySize % 512)) % 512

        if ([string]::Equals($entryPath, $targetEntryPath, [System.StringComparison]::Ordinal) -and
            ($typeFlag -eq [char]0 -or $typeFlag -eq '0')) {
            $content = Read-ExactBytesFromStream -Stream $Stream -Length $entrySize -Context "TAR entry '$targetEntryPath'"
            if ($paddingSize -gt 0) {
                Skip-BytesFromStream -Stream $Stream -Length $paddingSize -Context "padding for TAR entry '$targetEntryPath'"
            }
            return $content
        }

        $skipLength = $entrySize + $paddingSize
        if ($skipLength -gt 0) {
            Skip-BytesFromStream -Stream $Stream -Length $skipLength -Context "TAR entry '$entryPath'"
        }
    }

    throw "TAR archive does not contain entry '$targetEntryPath'."
}

function Read-TarArchiveEntryText {
<#
.SYNOPSIS
Reads one text file entry from an uncompressed TAR stream without extracting it.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.Stream]$Stream,

        [Parameter(Mandatory = $true)]
        [string]$EntryPath,

        [System.Text.Encoding]$Encoding = [System.Text.Encoding]::UTF8
    )

    $bytes = Read-TarArchiveEntryBytes -Stream $Stream -EntryPath $EntryPath
    return $Encoding.GetString($bytes)
}
