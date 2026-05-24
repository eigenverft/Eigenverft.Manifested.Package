<#
    Eigenverft.Manifested.Package.ExecutionCore.GZip

    GZip decompression helpers and TAR+GZip composition wrappers.
#>

function Read-TarGzipArchiveEntryBytes {
<#
.SYNOPSIS
Reads one file entry from a .tar.gz/.tgz archive without extracting it.

.DESCRIPTION
This helper owns the GZip file stream and delegates TAR record parsing to the
TAR execution core helpers.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$EntryPath
    )

    if ([string]::IsNullOrWhiteSpace($ArchivePath)) {
        throw 'A tar gzip archive path is required.'
    }
    if ([string]::IsNullOrWhiteSpace($EntryPath)) {
        throw 'A tar entry path is required.'
    }

    $resolvedArchivePath = [System.IO.Path]::GetFullPath($ArchivePath)
    if (-not (Test-Path -LiteralPath $resolvedArchivePath -PathType Leaf)) {
        throw "Tar gzip archive '$resolvedArchivePath' was not found."
    }

    Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
    $fileStream = [System.IO.File]::OpenRead($resolvedArchivePath)
    $gzipStream = $null
    try {
        $gzipStream = New-Object System.IO.Compression.GZipStream($fileStream, [System.IO.Compression.CompressionMode]::Decompress)
        return (Read-TarArchiveEntryBytes -Stream $gzipStream -EntryPath $EntryPath)
    }
    finally {
        if ($gzipStream) {
            $gzipStream.Dispose()
        }
        $fileStream.Dispose()
    }
}

function Read-TarGzipArchiveEntryText {
<#
.SYNOPSIS
Reads one text file entry from a .tar.gz/.tgz archive without extracting it.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$EntryPath,

        [System.Text.Encoding]$Encoding = [System.Text.Encoding]::UTF8
    )

    $bytes = Read-TarGzipArchiveEntryBytes -ArchivePath $ArchivePath -EntryPath $EntryPath
    return $Encoding.GetString($bytes)
}
