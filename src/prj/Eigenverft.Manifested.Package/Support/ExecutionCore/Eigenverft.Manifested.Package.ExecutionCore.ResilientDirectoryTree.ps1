<#
    Eigenverft.Manifested.Package.ExecutionCore.ResilientDirectoryTree

    Evolved from the wrk Copy-ResilientDirectoryTree draft into a cooperative multi-writer filesystem transport.
    Not wired into Invoke-PackageDepotDistribution yet; the transport helper is proven independently first.
    Source: src/wrk/Eigenverft.Manifested.Package/Copy-ResilientDirectoryTree .ps1
#>

function Get-ResilientCopyRemainingBytes {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [long] $TotalBytes,
        [Parameter(Mandatory)] [long] $ProcessedBytes
    )

    $remainingBytes = $TotalBytes - $ProcessedBytes
    if ($remainingBytes -lt 0L) {
        return 0L
    }

    return [long]$remainingBytes
}

function Format-ResilientCopyByteSize {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [double] $Bytes
    )

    if ($Bytes -lt 0) {
        $Bytes = 0
    }

    $kib = 1024.0
    $mib = 1024.0 * 1024.0
    $gib = 1024.0 * 1024.0 * 1024.0
    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    if ($Bytes -lt $kib) {
        return ($Bytes.ToString('0', $culture) + ' B')
    }
    if ($Bytes -lt $mib) {
        return (($Bytes / $kib).ToString('0.00', $culture) + ' KiB')
    }
    if ($Bytes -lt $gib) {
        return (($Bytes / $mib).ToString('0.00', $culture) + ' MiB')
    }

    return (($Bytes / $gib).ToString('0.00', $culture) + ' GiB')
}

function Format-ResilientCopyByteRate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [double] $BytesPerSecond
    )

    return ('{0}/s' -f (Format-ResilientCopyByteSize -Bytes $BytesPerSecond))
}

function Format-ResilientCopyOperationProgressStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Phase,
        [Parameter(Mandatory)] [long] $FilesDiscovered,
        [Parameter(Mandatory)] [long] $FilesSelected,
        [Parameter(Mandatory)] [long] $FilesCopied,
        [Parameter(Mandatory)] [long] $FilesFailed,
        [Parameter(Mandatory)] [long] $DirectoriesPreflighted,
        [Parameter(Mandatory)] [long] $RemovedCount,
        [Parameter(Mandatory)] [long] $PendingCount,
        [Parameter(Mandatory)] [long] $PendingBytes
    )

    return ('Phase: {0} | files discovered {1}; selected {2}; copied {3}; failed {4}; preflighted {5}; removed {6}; pending {7} ({8})' -f `
        $Phase, $FilesDiscovered, $FilesSelected, $FilesCopied, $FilesFailed,
        $DirectoriesPreflighted, $RemovedCount, $PendingCount,
        (Format-ResilientCopyByteSize -Bytes $PendingBytes))
}

function Copy-ResilientDirectoryTree {
    <#
    .SYNOPSIS
        Compares a source tree with a destination tree and copies selected files reliably.
 
    .DESCRIPTION
        Lazily traverses the source tree and compares each file as it is discovered, copying selected files without
        building a whole-tree selected-file list. The operation can optionally mirror destination-only files and
        create empty source directories. Each required destination directory is created if necessary and tested with
        one temporary write probe. The result is cached per directory so files sharing a directory do not repeat the
        ACL check. A failed preflight prevents copies that are expected to fail, while the copy retry loop remains in
        place for races and failures that occur after preflight. Failed files are skipped by default; use FailFast to stop.
        Selected files are copied through CopyFileRaw using writer-owned resumable partial files, prefix and completed
        partial verification, no-overwrite promotion, peer-win reconciliation, progress reporting, optional throttling,
        and source timestamp preservation. A verified final file is success regardless of which writer promoted it.
        Once that final is proven valid, exclusively claimable redundant partials for the same content identity are
        removed; active partials and different content identities are preserved.
 
        Mirror cleanup is deferred until source traversal completes. It checks destination paths directly against the
        source instead of retaining a source membership list. Cleanup is skipped when traversal is incomplete.
        Reparse points such as junctions and symbolic links are unsupported: nested source and destination reparse
        points are skipped with warnings and left untouched. Source roots and destination paths or their existing
        parent directories may not be reparse points.
        MaxOperationTime provides a total operation window: once it expires, no new work starts, but an active raw copy
        is allowed to finish.
 
        The operation also reports throttled phase progress for preflight, source traversal, copying, retries, and mirror
        cleanup. ProgressIntervalMilliseconds controls the minimum interval between operation-level updates and raw-copy
        chunk updates.
 
        By default, only the final object with OperationSummary set to $true is written to the success output stream.
        OutputMode can opt into per-file status and result objects. The summary contains file, directory, retry, byte,
        throughput, cleanup, and elapsed-time statistics.
 
    .PARAMETER SourceDirectory
        The root directory to compare and copy files from.
 
    .PARAMETER DestinationDirectory
        The root directory where files are compared and copied to.
 
    .PARAMETER SourceIgnorePatterns
        Path-style glob patterns matched against source-relative paths for both files and directories. Matching
        directories are not traversed, and matching files are skipped. Ignored content is preserved in MirrorMode.
        Use patterns such as '*.log', '**\temp', or 'build'. A pattern without a path separator matches at any depth;
        '*' matches within one path segment, and '**' matches zero or more directory segments.
 
    .PARAMETER SourceMinimumFileSizeBytes
        Minimum source file size to select, inclusive. Files smaller than this value are skipped and preserved in
        MirrorMode. The default is 0.
 
    .PARAMETER SourceMaximumFileSizeBytes
        Maximum source file size to select, inclusive. Files larger than this value are skipped and preserved in
        MirrorMode. The default is [long]::MaxValue.
 
    .PARAMETER MirrorMode
        Removes destination files and empty directories that are not present in the source. Off by default.
 
    .PARAMETER CopyEmptyDirectories
        Creates source directories even when no selected file requires them. Off by default.
 
    .PARAMETER ComparisonMode
        Selects how existing files are compared: Length, LastWriteTime, LengthAndLastWriteTime, or Hash.
 
    .PARAMETER LastWriteTimeTolerance
        Tolerance used by timestamp comparisons. The default is exact comparison.
 
    .PARAMETER ChunkSizeBytes
        Number of bytes read and written per stream-copy chunk. The default is 1 MiB.
 
    .PARAMETER FlushPolicy
        Controls when partial-file writes are flushed. EveryChunk preserves the current durability behavior and flushes
        after each chunk. EndOfCopy reduces SMB round trips by flushing at the end of the raw copy. The default is
        EveryChunk.
 
    .PARAMETER TargetBytesPerSecond
        Per-copy bandwidth limit. Zero disables throttling.
 
    .PARAMETER PartialIdentityMode
        Controls partial-file identity. FullHash uses the source SHA-256 hash and is the default for strong recovery
        identity. Metadata uses source path, length, and UTC timestamp; it is faster but cannot guarantee detection
        when a source is replaced with identical metadata.
 
    .PARAMETER FailFast
        Stops the operation when preflight fails or a file exhausts its retries. Off by default, so other files continue.
 
    .PARAMETER RetryCount
        Maximum attempts for each file and each source or destination enumeration operation, including the initial
        attempt. The default is 3.
 
    .PARAMETER WaitSeconds
        Base number of seconds to wait between retry attempts. The default is 5. RetryBackoffPolicy can increase later
        waits without introducing another time parameter.
 
    .PARAMETER RetryBackoffPolicy
        Retry wait policy for file-copy and source-enumeration retries. Fixed uses WaitSeconds for every wait;
        Exponential doubles the base wait after each retry. The default is Fixed.
 
    .PARAMETER MaxOperationTime
        Total [TimeSpan] operation window. No new work starts after this duration, but an active raw copy can finish.
        The default is no limit.
 
    .PARAMETER ProgressIntervalMilliseconds
        Minimum interval between progress updates. The default is 250 milliseconds. Lower values provide more frequent
        updates but add more PowerShell host overhead.
 
    .PARAMETER ProgressCallback
        Optional scriptblock invoked with each operation-progress object. Callback objects have OperationProgress set to
        $true and include the phase, current operation, counters, and elapsed time. Callback output is not added to the
        command's success output. If the callback throws, it is warned once, disabled, and the copy continues; the summary
        reports the event through ProgressCallbackFailures.
 
    .PARAMETER WorkQueueOrderPolicy
        Controls bounded lookahead scheduling. DiscoveryOrder is the default and disables queue optimization, preserving
        immediate discovery-order processing. SmallestFirst and LargestFirst enable a bounded queue and choose the next
        file by size within the currently buffered window. Ties preserve discovery order.
 
    .PARAMETER WorkQueueMaxItems
        Maximum number of file records held by the opt-in work queue. This limits queued metadata, not the active copy.
 
    .PARAMETER WorkQueueMaxBytes
        Maximum sum of queued file sizes for the opt-in work queue. A single file larger than this limit is allowed as
        the only queued file so it can still be processed.
 
    .PARAMETER OutputMode
        Selects success output: Summary (default), PerFile, or Both. Summary always writes the final summary object;
        PerFile writes per-file objects without the final summary; Both writes both kinds of output.
 
    .PARAMETER SkipIfUnchanged
        When $true (the default), skips existing files that match the selected comparison mode.
 
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Per-file copy and failure objects are written during the operation. The final object has OperationSummary set to $true.
        Summary objects include FailureReasons, FilesCopyFailed, and ProgressCallbackFailures for automation.
 
    .EXAMPLE
        Copy-ResilientDirectoryTree `
          -SourceDirectory 'C:\src' `
          -DestinationDirectory 'D:\backup' `
                -SourceIgnorePatterns '**\temp','**\logs','*.tmp','*.bak' `
          -MirrorMode -CopyEmptyDirectories `
          -ComparisonMode LengthAndLastWriteTime `
          -ChunkSizeBytes 1048576 -TargetBytesPerSecond 0 `
          -PartialIdentityMode FullHash `
          -RetryCount 5 -WaitSeconds 10 `
                -MaxOperationTime ([TimeSpan]::FromMinutes(30))
 
    .EXAMPLE
        $results = @(Copy-ResilientDirectoryTree -SourceDirectory 'C:\src' -DestinationDirectory 'D:\backup')
        $summary = $results | Where-Object { $_.OperationSummary }
        $summary | Format-List FilesCopied, FilesSkipped, FilesFailed, BytesTransferred, AverageBytesPerSecond
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [string]  $SourceDirectory,
        [Parameter(Mandatory)] [string]  $DestinationDirectory,
        [string[]]                       $SourceIgnorePatterns    = @(),
        [ValidateRange(0, 9223372036854775807)]
        [long]                            $SourceMinimumFileSizeBytes = 0,
        [ValidateRange(0, 9223372036854775807)]
        [long]                            $SourceMaximumFileSizeBytes = [long]::MaxValue,
        [switch]                         $MirrorMode,
        [switch]                         $CopyEmptyDirectories,
        [ValidateSet('Length', 'LastWriteTime', 'LengthAndLastWriteTime', 'Hash')]
        [string]                         $ComparisonMode           = 'LengthAndLastWriteTime',
        [TimeSpan]                       $LastWriteTimeTolerance    = [TimeSpan]::Zero,
        [ValidateRange(4096, 104857600)]
        [int]                            $ChunkSizeBytes             = 1048576,
        [ValidateRange(0, 2147483647)]
        [long]                           $TargetBytesPerSecond       = 0,
        [ValidateSet('Metadata', 'FullHash')]
        [string]                         $PartialIdentityMode        = 'FullHash',
        [ValidateSet('EveryChunk', 'EndOfCopy')]
        [string]                         $FlushPolicy                = 'EveryChunk',
        [switch]                         $FailFast,
        [ValidateRange(1, 2147483647)]
        [int]                            $RetryCount                = 3,
        [ValidateRange(0, 2147483647)]
        [int]                            $WaitSeconds               = 5,
        [ValidateSet('Fixed', 'Exponential')]
        [string]                         $RetryBackoffPolicy        = 'Fixed',
        [TimeSpan]                      $MaxOperationTime          = [TimeSpan]::MaxValue,
        [ValidateSet('Summary', 'PerFile', 'Both')]
        [string]                        $OutputMode                = 'Summary',
        [bool]                          $SkipIfUnchanged          = $true,
        [ValidateRange(50, 60000)]
        [int]                           $ProgressIntervalMilliseconds = 250,
        [scriptblock]                   $ProgressCallback,
        [ValidateSet('DiscoveryOrder', 'SmallestFirst', 'LargestFirst')]
        [string]                        $WorkQueueOrderPolicy      = 'DiscoveryOrder',
        [ValidateRange(1, 100000)]
        [int]                           $WorkQueueMaxItems         = 1000,
        [ValidateRange(1, 1099511627776)]
        [long]                          $WorkQueueMaxBytes         = 10737418240
    )
 
    function local:GetCopySourceHash {
        <#
        .SYNOPSIS
            Computes a streaming SHA-256 hash for a source file.
 
        .DESCRIPTION
            Opens the file for sequential shared reading and hashes it without loading the complete file into memory.
            The returned hexadecimal digest is lowercase and is used for full-hash partial-file identities and
            source-content validation.
 
        .PARAMETER SourcePath
            Path of the file to hash.
 
        .PARAMETER ChunkSizeBytes
            Stream buffer size in bytes. The default is 1 MiB.
 
        .OUTPUTS
            System.String
            Lowercase SHA-256 hexadecimal digest.
        #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)] [string] $SourcePath,
            [ValidateRange(4096, 104857600)]
            [int]                            $ChunkSizeBytes = 1048576
        )
   
        $stream = $null
        $sha256 = $null
        try {
            $stream = [System.IO.FileStream]::new(
                $SourcePath,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::ReadWrite,
                $ChunkSizeBytes,
                [System.IO.FileOptions]::SequentialScan
            )
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            $hashBytes = $sha256.ComputeHash($stream)
            return [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLowerInvariant()
        }
        finally {
            if ($sha256) {
                $sha256.Dispose()
                $stream.Dispose()
            }
        }
    }
   
    function local:GetCopyPrefixHash {
        <#
        .SYNOPSIS
            Computes a SHA-256 hash for a specified prefix of a file.
 
        .DESCRIPTION
            Reads exactly ByteCount bytes from the beginning of the file and hashes that prefix without buffering the
            entire file. Throws if the file ends before the requested prefix is read. This validates existing partial
            bytes before a resumable copy continues.
 
        .PARAMETER Path
            Path of the file whose prefix should be hashed.
 
        .PARAMETER ByteCount
            Number of bytes to read from the beginning of the file.
 
        .PARAMETER ChunkSizeBytes
            Stream buffer size in bytes. The default is 1 MiB.
 
        .OUTPUTS
            System.String
            Lowercase SHA-256 hexadecimal digest for the requested prefix.
        #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)] [string] $Path,
            [Parameter(Mandatory)] [long]   $ByteCount,
            [ValidateRange(4096, 104857600)]
            [int]                            $ChunkSizeBytes = 1048576
        )
   
        $stream = $null
        $sha256 = $null
        try {
            $stream = [System.IO.FileStream]::new(
                $Path,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::ReadWrite,
                $ChunkSizeBytes,
                [System.IO.FileOptions]::SequentialScan
            )
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            $buffer = New-Object byte[] $ChunkSizeBytes
            $remainingBytes = $ByteCount
   
            while ($remainingBytes -gt 0) {
                $requestedBytes = [int][Math]::Min($remainingBytes, $buffer.Length)
                $readBytes = $stream.Read($buffer, 0, $requestedBytes)
                if ($readBytes -eq 0) {
                    throw "Unable to read $ByteCount bytes from $Path."
                }
   
                $sha256.TransformBlock($buffer, 0, $readBytes, $buffer, 0) | Out-Null
                $remainingBytes -= $readBytes
            }
   
            $sha256.TransformFinalBlock([byte[]]@(), 0, 0) | Out-Null
            return [System.BitConverter]::ToString($sha256.Hash).Replace('-', '').ToLowerInvariant()
        }
        finally {
            if ($sha256) {
                $sha256.Dispose()
            }
            if ($stream) {
                $stream.Dispose()
            }
        }
    }
   
    function local:GetCopyPartialPath {
        <#
        .SYNOPSIS
            Builds the resumable partial-file path for a source and destination pair.
 
        .DESCRIPTION
            Creates a deterministic SHA-256 identity from the source metadata or full source hash and appends it to
            the destination path. This function only calculates the path; it does not create or modify a partial file.
            Metadata identity is faster, while FullHash identity distinguishes files replaced with identical metadata.
 
        .PARAMETER SourcePath
            Path of the source file used to build the identity.
 
        .PARAMETER DestinationPath
            Final destination path to which the partial-file suffix is appended.
 
        .PARAMETER PartialIdentityMode
            FullHash uses the source SHA-256 hash and is the default. Metadata uses source path, length, and UTC timestamp
            for a faster but weaker identity.
 
        .PARAMETER ChunkSizeBytes
            Stream buffer size used when FullHash must calculate the source hash. The default is 1 MiB.
 
        .PARAMETER SourceHash
            Optional precomputed source hash used by FullHash mode to avoid hashing the source twice.
 
        .PARAMETER WriterToken
            Per-writer token appended after the content identity so concurrent clients do not share one partial path.
            Defaults to a new GUID (N format) when omitted or blank.
 
        .OUTPUTS
            System.String
            Full path of the identity- and writer-specific resumable partial file.
        #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)] [string] $SourcePath,
            [Parameter(Mandatory)] [string] $DestinationPath,
            [ValidateSet('Metadata', 'FullHash')]
            [string]                         $PartialIdentityMode = 'FullHash',
            [ValidateRange(4096, 104857600)]
            [int]                            $ChunkSizeBytes = 1048576,
            [string]                         $SourceHash,
            [string]                         $WriterToken
        )
   
        $sourceInfo = Get-Item -LiteralPath $SourcePath -ErrorAction Stop
        if ($sourceInfo.PSIsContainer) {
            throw "Source path is a directory: $SourcePath"
        }
   
        if ($PartialIdentityMode -eq 'FullHash') {
            if (-not $SourceHash) {
                $SourceHash = GetCopySourceHash -SourcePath $sourceInfo.FullName -ChunkSizeBytes $ChunkSizeBytes
            }
            $identity = 'fullhash|{0}' -f $SourceHash
        }
        else {
            $identity = 'metadata|{0}|{1}|{2}' -f $sourceInfo.FullName, $sourceInfo.Length, $sourceInfo.LastWriteTimeUtc.Ticks
        }
   
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            $identityBytes = [System.Text.Encoding]::UTF8.GetBytes($identity)
            $identityHash = [System.BitConverter]::ToString($sha256.ComputeHash($identityBytes)).Replace('-', '').ToLowerInvariant()
        }
        finally {
            $sha256.Dispose()
        }
   
        if ([string]::IsNullOrWhiteSpace($WriterToken)) {
            $WriterToken = [guid]::NewGuid().ToString('N')
        }
 
        return "$DestinationPath.partial.$identityHash.$WriterToken"
    }
   
    function local:CopyFileRaw {
        <#
        .SYNOPSIS
            Copies one file through a resumable, streamed partial file.
 
        .DESCRIPTION
            Streams the source into a content- and writer-specific partial file using bounded memory. Only that writer's
            partial can be resumed or directly removed. Its existing prefix and completed SHA-256 are verified before
            no-overwrite promotion. A failed copy leaves the owned partial for the same writer's retry. If a peer wins
            promotion with identical bytes, the operation succeeds without replacing the peer's final file.
 
        .PARAMETER SourcePath
            Path of the source file to copy.
 
        .PARAMETER DestinationPath
            Final destination path for the completed file.
 
        .PARAMETER ChunkSizeBytes
            Number of bytes read and written per stream-copy chunk. The default is 1 MiB.
 
        .PARAMETER TargetBytesPerSecond
            Per-copy bandwidth limit. Zero disables throttling.
 
        .PARAMETER PartialIdentityMode
            Selects FullHash or Metadata identity for the resumable partial file. FullHash is the default and provides
            the strongest protection against resuming from a partial file belonging to different source content.
 
        .PARAMETER FlushPolicy
            EveryChunk flushes after each chunk. EndOfCopy flushes at completion to reduce flush round trips on
            high-latency storage. The default is EveryChunk.

        .PARAMETER WriterToken
            Stable per-file writer identity used across retries. It scopes resumable partial ownership so one writer
            never resumes or removes another writer's partial. A GUID is generated when omitted.
 
        .PARAMETER ProgressId
            Write-Progress identifier. A negative value derives an identifier from the destination path.
 
        .PARAMETER ProgressIntervalMilliseconds
            Minimum interval between raw-copy progress updates. The default is 250 milliseconds.
 
        .OUTPUTS
            System.Management.Automation.PSCustomObject
            Reports paths, byte counts, resume validation, throughput, flush policy, and completion state.
        #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)] [string] $SourcePath,
            [Parameter(Mandatory)] [string] $DestinationPath,
            [ValidateRange(4096, 104857600)]
            [int]                            $ChunkSizeBytes = 1048576,
            [ValidateRange(0, 2147483647)]
            [long]                           $TargetBytesPerSecond = 0,
            [ValidateSet('Metadata', 'FullHash')]
            [string]                         $PartialIdentityMode = 'FullHash',
            [ValidateSet('EveryChunk', 'EndOfCopy')]
            [string]                         $FlushPolicy = 'EveryChunk',
            [string]                         $WriterToken,
            [int]                            $ProgressId = -1,
            [ValidateRange(50, 60000)]
            [int]                            $ProgressIntervalMilliseconds = 250
        )
   
        $sourceInfo = Get-Item -LiteralPath $SourcePath -ErrorAction Stop
        if ($sourceInfo.PSIsContainer) {
            throw "Source path is a directory: $SourcePath"
        }
   
        $destinationFullPath = [System.IO.Path]::GetFullPath($DestinationPath)
        $destinationDirectory = Split-Path -Path $destinationFullPath -Parent
        if (-not (Test-Path -LiteralPath $destinationDirectory)) {
            New-Item -Path $destinationDirectory -ItemType Directory -Force | Out-Null
        }
        if (Test-Path -LiteralPath $destinationFullPath -PathType Container) {
            throw "Destination path is a directory: $destinationFullPath"
        }
   
        # Promotion and peer reconciliation always use exact content identity. PartialIdentityMode only controls
        # how the resumable partial name is derived; it must not weaken the final publish decision.
        $sourceHash = GetCopySourceHash -SourcePath $sourceInfo.FullName -ChunkSizeBytes $ChunkSizeBytes
 
        $writerToken = if ([string]::IsNullOrWhiteSpace($WriterToken)) {
            [guid]::NewGuid().ToString('N')
        }
        else {
            $WriterToken
        }
        $peerAlreadyPresent = $false
        $partialVerified = $false
        $redundantPartialsRemoved = 0

        $partialPath = GetCopyPartialPath `
            -SourcePath $sourceInfo.FullName `
            -DestinationPath $destinationFullPath `
            -PartialIdentityMode $PartialIdentityMode `
            -ChunkSizeBytes $ChunkSizeBytes `
            -SourceHash $sourceHash `
            -WriterToken $writerToken

        $partialLeafName = [System.IO.Path]::GetFileName($partialPath)
        $partialLeafPrefix = $partialLeafName.Substring(0, $partialLeafName.Length - $writerToken.Length)

        $removeOwnedPartial = {
            if (-not [System.IO.File]::Exists($partialPath)) {
                return
            }

            [System.IO.File]::Delete($partialPath)
            if ([System.IO.File]::Exists($partialPath)) {
                throw "Unable to remove writer-owned partial file '$partialPath'."
            }
        }

        $removeRedundantPeerPartials = {
            $removedCount = 0
            $peerPartials = @(Get-ChildItem -LiteralPath $destinationDirectory -File -Filter ($partialLeafPrefix + '*') -ErrorAction SilentlyContinue)
            foreach ($peerPartial in $peerPartials) {
                if ([string]::Equals($peerPartial.FullName, $partialPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                    continue
                }

                # DeleteOnClose while holding an exclusive handle makes cleanup conditional on the partial not
                # being used by another cooperative writer. Sharing/access failures mean "active or unavailable"
                # and are deliberately ignored. Only this destination leaf and content identity are considered.
                $cleanupStream = $null
                try {
                    $cleanupStream = [System.IO.FileStream]::new(
                        $peerPartial.FullName,
                        [System.IO.FileMode]::Open,
                        [System.IO.FileAccess]::ReadWrite,
                        [System.IO.FileShare]::None,
                        1,
                        [System.IO.FileOptions]::DeleteOnClose
                    )
                    $cleanupStream.Dispose()
                    $cleanupStream = $null
                    if (-not [System.IO.File]::Exists($peerPartial.FullName)) {
                        $removedCount++
                    }
                }
                catch [System.IO.IOException] {
                    # A live peer normally holds the partial without delete sharing. It owns that partial.
                }
                catch [System.UnauthorizedAccessException] {
                    # Read-only or share policy prevented a safe exclusive claim; leave the partial untouched.
                }
                finally {
                    if ($cleanupStream) {
                        $cleanupStream.Dispose()
                    }
                }
            }
            return $removedCount
        }

        $testFinalDestination = {
            if (-not [System.IO.File]::Exists($destinationFullPath)) {
                return [pscustomobject]@{ Exists = $false; Matches = $false; Hash = $null }
            }

            $existingDestination = Get-Item -LiteralPath $destinationFullPath -ErrorAction Stop
            $existingHash = $null
            $destinationMatches = $false
            if ($existingDestination.Length -eq $sourceInfo.Length) {
                $existingHash = GetCopySourceHash -SourcePath $destinationFullPath -ChunkSizeBytes $ChunkSizeBytes
                $destinationMatches = ($existingHash -eq $sourceHash)
            }

            return [pscustomobject]@{
                Exists  = $true
                Matches = $destinationMatches
                Hash    = $existingHash
            }
        }

        $initialDestination = & $testFinalDestination
        if ($initialDestination.Matches) {
            $verifiedSourceInfo = Get-Item -LiteralPath $sourceInfo.FullName -ErrorAction Stop
            $verifiedSourceHash = GetCopySourceHash -SourcePath $sourceInfo.FullName -ChunkSizeBytes $ChunkSizeBytes
            if ($verifiedSourceInfo.Length -ne $sourceInfo.Length -or
                $verifiedSourceInfo.LastWriteTimeUtc -ne $sourceInfo.LastWriteTimeUtc -or
                $verifiedSourceHash -ne $sourceHash) {
                throw "Source changed while verifying the existing final destination: $($sourceInfo.FullName)"
            }
            & $removeOwnedPartial
            $redundantPartialsRemoved = & $removeRedundantPeerPartials
            return [pscustomobject]@{
                SourcePath               = $sourceInfo.FullName
                DestinationPath          = $destinationFullPath
                PartialPath              = $null
                TotalBytes               = $sourceInfo.Length
                ResumedBytes             = 0L
                BytesTransferred         = 0L
                Elapsed                  = [TimeSpan]::Zero
                ElapsedSeconds           = 0
                AverageBytesPerSecond    = 0
                TargetBytesPerSecond     = $TargetBytesPerSecond
                PartialIdentityMode      = $PartialIdentityMode
                FlushPolicy              = $FlushPolicy
                ResumeValidation         = 'NotNeeded'
                WasResumed               = $false
                Completed                = $true
                PeerAlreadyPresent       = $true
                Outcome                  = 'AlreadyPresent'
                PartialVerified          = $false
                RedundantPartialsRemoved = $redundantPartialsRemoved
                WriterToken              = $writerToken
            }
        }

        $partialInfo = Get-Item -LiteralPath $partialPath -ErrorAction SilentlyContinue
        $resumedBytes = 0L
        $resumeValidation = 'NotNeeded'
        if ($partialInfo) {
            if ($partialInfo.Length -lt $sourceInfo.Length) {
                $partialPrefixHash = GetCopyPrefixHash `
                    -Path $partialPath `
                    -ByteCount $partialInfo.Length `
                    -ChunkSizeBytes $ChunkSizeBytes
                $sourcePrefixHash = GetCopyPrefixHash `
                    -Path $sourceInfo.FullName `
                    -ByteCount $partialInfo.Length `
                    -ChunkSizeBytes $ChunkSizeBytes
   
                if ($partialPrefixHash -eq $sourcePrefixHash) {
                    $resumedBytes = $partialInfo.Length
                    $resumeValidation = 'Valid'
                }
                else {
                    & $removeOwnedPartial
                    $resumeValidation = 'InvalidRestarted'
                }
            }
            elseif ($partialInfo.Length -eq $sourceInfo.Length) {
                $partialHash = GetCopySourceHash -SourcePath $partialPath -ChunkSizeBytes $ChunkSizeBytes
                if ($partialHash -eq $sourceHash) {
                    $resumedBytes = $partialInfo.Length
                    $resumeValidation = 'CompleteValid'
                }
                else {
                    & $removeOwnedPartial
                    $resumeValidation = 'InvalidRestarted'
                }
            }
            else {
                & $removeOwnedPartial
                $resumeValidation = 'InvalidRestarted'
            }
        }
   
        if ($ProgressId -lt 0) {
            $ProgressId = [int](([Math]::Abs([int64]$destinationFullPath.GetHashCode()) % 1000000) + 1)
        }
   
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $transferredBytes = 0L
        $lastProgressReportTicks = -1L
        $sourceStream = $null
        $partialStream = $null
        $copyCompleted = $false
   
        try {
            $sourceStream = [System.IO.FileStream]::new(
                $sourceInfo.FullName,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::ReadWrite,
                $ChunkSizeBytes,
                [System.IO.FileOptions]::SequentialScan
            )
            $partialStream = [System.IO.FileStream]::new(
                $partialPath,
                [System.IO.FileMode]::OpenOrCreate,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::Read,
                $ChunkSizeBytes,
                [System.IO.FileOptions]::SequentialScan
            )
            $sourceStream.Seek($resumedBytes, [System.IO.SeekOrigin]::Begin) | Out-Null
            $partialStream.Seek($resumedBytes, [System.IO.SeekOrigin]::Begin) | Out-Null
            $partialStream.SetLength($resumedBytes)
   
            $buffer = New-Object byte[] $ChunkSizeBytes
            while ($true) {
                $readBytes = $sourceStream.Read($buffer, 0, $buffer.Length)
                if ($readBytes -eq 0) {
                    break
                }
   
                $partialStream.Write($buffer, 0, $readBytes)
                if ($FlushPolicy -eq 'EveryChunk') {
                    $partialStream.Flush()
                }
                $transferredBytes += $readBytes
   
                if ($TargetBytesPerSecond -gt 0) {
                    $expectedSeconds = $transferredBytes / [double]$TargetBytesPerSecond
                    $actualSeconds = $stopwatch.Elapsed.TotalSeconds
                    if ($expectedSeconds -gt $actualSeconds) {
                        $sleepMilliseconds = [int][Math]::Ceiling(($expectedSeconds - $actualSeconds) * 1000)
                        if ($sleepMilliseconds -gt 0) {
                            Start-Sleep -Milliseconds $sleepMilliseconds
                        }
                    }
                }
   
                $processedBytes = $resumedBytes + $transferredBytes
                $percentComplete = if ($sourceInfo.Length -eq 0) { 100 } else {
                    [int][Math]::Min(100, [Math]::Floor(($processedBytes * 100.0) / $sourceInfo.Length))
                }
                $elapsedSeconds = $stopwatch.Elapsed.TotalSeconds
                $averageBytesPerSecond = if ($elapsedSeconds -gt 0) {
                    $transferredBytes / $elapsedSeconds
                }
                else {
                    0
                }
                $remainingBytes = Get-ResilientCopyRemainingBytes -TotalBytes $sourceInfo.Length -ProcessedBytes $processedBytes
                $eta = if ($averageBytesPerSecond -gt 0) {
                    [TimeSpan]::FromSeconds($remainingBytes / $averageBytesPerSecond)
                }
                else {
                    [TimeSpan]::Zero
                }
   
                if ($lastProgressReportTicks -lt 0 -or
                    $stopwatch.Elapsed.Ticks - $lastProgressReportTicks -ge ([TimeSpan]::FromMilliseconds($ProgressIntervalMilliseconds).Ticks)) {
                    Write-Progress `
                        -Id $ProgressId `
                        -Activity "Copying $($sourceInfo.Name)" `
                        -Status ("{0}/{1} | {2} | elapsed {3} | ETA {4}" -f `
                            (Format-ResilientCopyByteSize -Bytes $processedBytes),
                            (Format-ResilientCopyByteSize -Bytes $sourceInfo.Length),
                            (Format-ResilientCopyByteRate -BytesPerSecond $averageBytesPerSecond),
                            $stopwatch.Elapsed.ToString(), $eta.ToString()) `
                        -PercentComplete $percentComplete
                    $lastProgressReportTicks = $stopwatch.Elapsed.Ticks
                }
            }
   
            $partialStream.Flush()
            $copyCompleted = $true
        }
        catch {
            throw
        }
        finally {
            if ($partialStream) {
                $partialStream.Dispose()
            }
            if ($sourceStream) {
                $sourceStream.Dispose()
            }
            $stopwatch.Stop()
        }
   
        if ($copyCompleted) {
            $finalSourceInfo = Get-Item -LiteralPath $sourceInfo.FullName -ErrorAction Stop
            if ($finalSourceInfo.Length -ne $sourceInfo.Length -or
                $finalSourceInfo.LastWriteTimeUtc -ne $sourceInfo.LastWriteTimeUtc) {
                throw "Source changed during copy; partial file was retained: $partialPath"
            }
            $finalSourceHash = GetCopySourceHash -SourcePath $sourceInfo.FullName -ChunkSizeBytes $ChunkSizeBytes
            if ($finalSourceHash -ne $sourceHash) {
                throw "Source content changed during copy; partial file was retained: $partialPath"
            }

            $partialHash = GetCopySourceHash -SourcePath $partialPath -ChunkSizeBytes $ChunkSizeBytes
            if ($partialHash -ne $sourceHash) {
                & $removeOwnedPartial
                throw "Completed writer-owned partial failed SHA-256 verification and was removed: $partialPath"
            }
            $partialVerified = $true

            # Apply metadata before the atomic promotion so a process loss immediately after File.Move cannot leave
            # a content-valid final with a transient partial timestamp.
            [System.IO.File]::SetLastWriteTimeUtc($partialPath, $finalSourceInfo.LastWriteTimeUtc)
            $verifiedPartialInfo = Get-Item -LiteralPath $partialPath -ErrorAction Stop
            if ($verifiedPartialInfo.LastWriteTimeUtc -ne $finalSourceInfo.LastWriteTimeUtc) {
                throw "Unable to preserve the source timestamp on writer-owned partial: $partialPath"
            }

            $promoteSucceeded = $false
            $promoteError = $null
            try {
                # The two-argument File.Move is atomic within the destination directory and does not overwrite.
                # A peer that already promoted therefore wins without its verified file being replaced.
                [System.IO.File]::Move($partialPath, $destinationFullPath)
                $promoteSucceeded = $true
            }
            catch {
                $promoteError = $_.Exception
                $destinationAfterPromote = & $testFinalDestination
                if (-not $destinationAfterPromote.Matches) {
                    $observedState = if ($destinationAfterPromote.Exists) {
                        "existing final SHA-256 '$($destinationAfterPromote.Hash)' does not match source '$sourceHash'"
                    }
                    else {
                        'no final destination exists'
                    }
                    throw [System.IO.IOException]::new(
                        "Writer-owned partial promotion failed and $observedState. Partial retained: '$partialPath'.",
                        $promoteError
                    )
                }

                $peerAlreadyPresent = $true
                & $removeOwnedPartial
            }

            if (-not $promoteSucceeded -and -not $peerAlreadyPresent) {
                throw "Partial promote failed without a matching final destination: $partialPath"
            }

            $verifiedDestination = & $testFinalDestination
            if (-not $verifiedDestination.Matches) {
                throw "Final destination failed SHA-256 verification after promotion: $destinationFullPath"
            }
            $redundantPartialsRemoved = & $removeRedundantPeerPartials
            Write-Progress -Id $ProgressId -Activity "Copying $($sourceInfo.Name)" -Completed
        }
   
        $elapsedSeconds = $stopwatch.Elapsed.TotalSeconds
        [pscustomobject]@{
            SourcePath              = $sourceInfo.FullName
            DestinationPath         = $destinationFullPath
            PartialPath             = $partialPath
            TotalBytes               = $sourceInfo.Length
            ResumedBytes             = $resumedBytes
            BytesTransferred         = $transferredBytes
            Elapsed                  = $stopwatch.Elapsed
            ElapsedSeconds           = $elapsedSeconds
            AverageBytesPerSecond    = if ($elapsedSeconds -gt 0) { $transferredBytes / $elapsedSeconds } else { 0 }
            TargetBytesPerSecond     = $TargetBytesPerSecond
            PartialIdentityMode      = $PartialIdentityMode
            FlushPolicy              = $FlushPolicy
            ResumeValidation         = $resumeValidation
            WasResumed                = $resumedBytes -gt 0
            Completed                 = $copyCompleted
            PeerAlreadyPresent        = $peerAlreadyPresent
            Outcome                   = if ($peerAlreadyPresent) { 'PeerWon' } else { 'Copied' }
            PartialVerified           = $partialVerified
            RedundantPartialsRemoved  = $redundantPartialsRemoved
            WriterToken               = $writerToken
        }
    }
   
    function local:TestCopyDestinationDirectory {
        <#
        .SYNOPSIS
            Creates and write-tests a destination directory for copy preflight.
 
        .DESCRIPTION
            Resolves the destination path, creates the directory when needed, and writes a temporary probe file to
            verify that copying can proceed. The probe is removed during cleanup. The result is intended to be cached
            by the outer operation for files sharing the same destination directory.
 
        .PARAMETER Path
            Destination directory to create or test.
 
        .OUTPUTS
            System.Management.Automation.PSCustomObject
            Contains Path, Created, Succeeded, and ErrorMessage properties.
        #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)] [string] $Path
        )
   
        $fullPath = [System.IO.Path]::GetFullPath($Path)
        $probePath = $null
        $probeStream = $null
        $created = $false
   
        try {
            if (Test-Path -LiteralPath $fullPath -PathType Leaf -ErrorAction Stop) {
                Remove-Item -LiteralPath $fullPath -Force -ErrorAction Stop
            }
            if (-not (Test-Path -LiteralPath $fullPath -PathType Container -ErrorAction Stop)) {
                New-Item -Path $fullPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                $created = $true
            }
   
            $probePath = Join-Path $fullPath ('.copy-preflight.' + [guid]::NewGuid().ToString('N') + '.tmp')
            $probeStream = [System.IO.FileStream]::new(
                $probePath,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None,
                1,
                [System.IO.FileOptions]::SequentialScan
            )
            $probeStream.WriteByte(0)
            $probeStream.Flush()
   
            [pscustomobject]@{
                Path         = $fullPath
                Created      = $created
                Succeeded    = $true
                ErrorMessage = $null
            }
        }
        finally {
            if ($probeStream) {
                $probeStream.Dispose()
            }
            if ($probePath -and (Test-Path -LiteralPath $probePath)) {
                Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue
            }
        }
    }
   
    function local:CompareCopyFile {
        <#
        .SYNOPSIS
            Compares one source file with its destination using the selected policy.
 
        .DESCRIPTION
            Returns true when the destination is missing or differs from the source under the selected comparison
            mode. Length, timestamp, combined metadata, and SHA-256 hash comparisons are supported. A missing
            destination is always considered different.
 
        .PARAMETER SourceFile
            FileInfo object representing the source file.
 
        .PARAMETER DestinationPath
            Path of the destination file to compare.
 
        .PARAMETER ComparisonMode
            Length, LastWriteTime, LengthAndLastWriteTime, or Hash. The default is LengthAndLastWriteTime.
 
        .PARAMETER LastWriteTimeTolerance
            Maximum allowed timestamp difference for timestamp comparisons. The default is exact comparison.
 
        .OUTPUTS
            System.Boolean
            True when the file needs to be copied; otherwise false.
        #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)] [System.IO.FileInfo] $SourceFile,
            [Parameter(Mandatory)] [string]              $DestinationPath,
            [ValidateSet('Length', 'LastWriteTime', 'LengthAndLastWriteTime', 'Hash')]
            [string]                                            $ComparisonMode = 'LengthAndLastWriteTime',
            [TimeSpan]                                           $LastWriteTimeTolerance = [TimeSpan]::Zero
        )
   
        if (-not (Test-Path -LiteralPath $DestinationPath -ErrorAction Stop) -or
            -not (Test-Path -LiteralPath $DestinationPath -PathType Leaf -ErrorAction Stop)) {
            return $true
        }
   
        $destinationInfo = Get-Item -LiteralPath $DestinationPath -ErrorAction Stop
        switch ($ComparisonMode) {
            'Length' {
                return $SourceFile.Length -ne $destinationInfo.Length
            }
            'LastWriteTime' {
                return ($SourceFile.LastWriteTimeUtc - $destinationInfo.LastWriteTimeUtc).Duration() -gt $LastWriteTimeTolerance
            }
            'LengthAndLastWriteTime' {
                return $SourceFile.Length -ne $destinationInfo.Length -or
                    ($SourceFile.LastWriteTimeUtc - $destinationInfo.LastWriteTimeUtc).Duration() -gt $LastWriteTimeTolerance
            }
            'Hash' {
                if ($SourceFile.Length -ne $destinationInfo.Length) {
                    return $true
                }
                return (Get-FileHash -LiteralPath $SourceFile.FullName -Algorithm SHA256).Hash -ne
                    (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash
            }
        }
    }
 
    if ($LastWriteTimeTolerance -lt [TimeSpan]::Zero) {
        throw 'LastWriteTimeTolerance cannot be negative.'
    }
    if ($MaxOperationTime -lt [TimeSpan]::Zero) {
        throw 'MaxOperationTime cannot be negative.'
    }
    if ($SourceMaximumFileSizeBytes -lt $SourceMinimumFileSizeBytes) {
        throw 'SourceMaximumFileSizeBytes cannot be less than SourceMinimumFileSizeBytes.'
    }
 
    $operationStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $state = [pscustomobject]@{
        FilesDiscovered            = 0
        FilesSkipped               = 0
        FilesCompleted             = 0
        FilesAlreadyPresent        = 0
        FilesPeerWon               = 0
        FilesSelected              = 0
        FilesCopied                = 0
        FilesFailed                = 0
        FilesCopyFailed             = 0
        FilesPreflightFailed       = 0
        FilesCompareFailed         = 0
        FilesComparisonDeferred    = 0
        SelectedBytes              = 0L
        BytesTransferred           = 0L
        BytesResumed               = 0L
        FilesResumed               = 0
        InvalidPartialRestarts     = 0
        PartialFilesPreserved      = 0
        RedundantPartialsRemoved   = 0
        TotalAttempts              = 0
        TotalRetries               = 0
        DirectoriesCreated         = 0
        DirectoriesPreflighted     = 0
        DirectoriesPreflightPassed = 0
        DirectoriesPreflightFailed = 0
        FilesRemoved               = 0
        DirectoriesRemoved         = 0
        CleanupFailures             = 0
        ComparisonFailures         = 0
        EnumerationRetries          = 0
        DirectoriesPreflightInvalidated = 0
        ComparisonCompleted        = $true
        StoppedByTimeLimit         = $false
        CleanupCompleted           = $true
        RootPreflightSucceeded     = $false
        QueuedFilesNotAttempted    = 0
        WorkQueuePeakItems         = 0
        WorkQueuePeakBytes         = 0L
        LastProgressUpdateTicks     = -1L
        LastProgressPhase           = ''
        ProgressCallbackFailures   = 0
        ProgressCallbackEnabled    = $true
    }
 
    $copyStopwatch = New-Object System.Diagnostics.Stopwatch
    $directoryPreflight = @{}
    $operationProgressId = 1000001
    $copyProgressId = 1000002
    $workQueueEnabled = $WorkQueueOrderPolicy -ne 'DiscoveryOrder'
    $workQueueState = [pscustomobject]@{
        Items              = New-Object System.Collections.ArrayList
        Bytes              = 0L
        NextDiscoveryOrder = 0L
    }
 
    $writeOperationProgress = {
        param (
            [string] $Phase,
            [string] $CurrentOperation,
            [bool]   $Force,
            [string] $CurrentFilePath
        )
 
        $elapsedTicks = $operationStopwatch.Elapsed.Ticks
        $intervalTicks = ([TimeSpan]::FromMilliseconds($ProgressIntervalMilliseconds)).Ticks
        $phaseChanged = $state.LastProgressPhase -ne $Phase
        if (-not $Force -and -not $phaseChanged -and $state.LastProgressUpdateTicks -ge 0 -and
            $elapsedTicks - $state.LastProgressUpdateTicks -lt $intervalTicks) {
            return
        }
 
        $state.LastProgressUpdateTicks = $elapsedTicks
        $state.LastProgressPhase = $Phase
        $status = Format-ResilientCopyOperationProgressStatus `
            -Phase $Phase `
            -FilesDiscovered $state.FilesDiscovered `
            -FilesSelected $state.FilesSelected `
            -FilesCopied $state.FilesCopied `
            -FilesFailed $state.FilesFailed `
            -DirectoriesPreflighted $state.DirectoriesPreflighted `
            -RemovedCount ($state.FilesRemoved + $state.DirectoriesRemoved) `
            -PendingCount $workQueueState.Items.Count `
            -PendingBytes $workQueueState.Bytes
        if ($ProgressCallback -and $state.ProgressCallbackEnabled) {
            try {
                & $ProgressCallback ([pscustomobject]@{
                    OperationProgress        = $true
                    Phase                    = $Phase
                    CurrentOperation         = $CurrentOperation
                    CurrentFilePath          = $CurrentFilePath
                    FilesDiscovered          = $state.FilesDiscovered
                    FilesSelected            = $state.FilesSelected
                    FilesCopied              = $state.FilesCopied
                    FilesFailed              = $state.FilesFailed
                    FilesCopyFailed         = $state.FilesCopyFailed
                    FilesPreflightFailed    = $state.FilesPreflightFailed
                    FilesCompareFailed      = $state.FilesCompareFailed
                    DirectoriesPreflighted  = $state.DirectoriesPreflighted
                    FilesRemoved             = $state.FilesRemoved
                    DirectoriesRemoved      = $state.DirectoriesRemoved
                    WorkQueueOrderPolicy    = $WorkQueueOrderPolicy
                    QueueSize               = $workQueueState.Items.Count
                    QueueBytes              = $workQueueState.Bytes
                    QueueMaxItems           = $WorkQueueMaxItems
                    QueueMaxBytes           = $WorkQueueMaxBytes
                    ProgressCallbackFailures = $state.ProgressCallbackFailures
                    Elapsed                  = $operationStopwatch.Elapsed
                    ElapsedSeconds           = $operationStopwatch.Elapsed.TotalSeconds
                }) | Out-Null
            }
            catch {
                $state.ProgressCallbackFailures++
                $state.ProgressCallbackEnabled = $false
                Write-Warning "Progress callback failed and was disabled. $_"
            }
        }
        Write-Progress `
            -Id $operationProgressId `
            -Activity 'Copy-ResilientDirectoryTree' `
            -Status $status `
            -CurrentOperation $CurrentOperation
    }
 
    $isReparsePoint = {
        param ($Item)
 
        if ($Item -is [System.IO.FileSystemInfo]) {
            return (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
        }
        return $false
    }
 
    $normalizePath = {
        param ([string] $Path)
 
        $fullPath = [System.IO.Path]::GetFullPath($Path)
        $fullPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    }
 
    $srcRootInfo = Get-Item -LiteralPath $SourceDirectory -ErrorAction Stop
    if ($srcRootInfo.PSIsContainer -eq $false) {
        throw "Source path is not a directory: $SourceDirectory"
    }
    if (& $isReparsePoint $srcRootInfo) {
        Write-Warning "Source root is a reparse point and is unsupported: $($srcRootInfo.FullName)"
        throw "Source root reparse points are unsupported."
    }
    $srcRoot = $srcRootInfo.FullName
    $dstRoot = [System.IO.Path]::GetFullPath($DestinationDirectory)
    $destinationProbePath = $dstRoot
    while ($true) {
        if ([System.IO.Directory]::Exists($destinationProbePath)) {
            $destinationProbeAttributes = [System.IO.File]::GetAttributes($destinationProbePath)
            if (($destinationProbeAttributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                Write-Warning "Destination path or parent is a reparse point and is unsupported: $destinationProbePath"
                throw "Destination path or parent reparse points are unsupported."
            }
        }
 
        $destinationParentPath = Split-Path -Path $destinationProbePath -Parent
        if ([string]::IsNullOrEmpty($destinationParentPath) -or
            $destinationParentPath -eq $destinationProbePath) {
            break
        }
        $destinationProbePath = $destinationParentPath
    }
    $srcRootKey = & $normalizePath $srcRoot
    $dstRootKey = & $normalizePath $dstRoot
    $srcRootPrefix = $srcRootKey + [System.IO.Path]::DirectorySeparatorChar
    $dstRootPrefix = $dstRootKey + [System.IO.Path]::DirectorySeparatorChar
    if ($srcRootKey.Equals($dstRootKey, [System.StringComparison]::OrdinalIgnoreCase) -or
        $srcRootKey.StartsWith($dstRootPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        $dstRootKey.StartsWith($srcRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Source and destination directories must not be equal or nested inside one another."
    }
 
    $normalizedSrc = $srcRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $baseUri = [System.Uri]::new($normalizedSrc)
    $normalizedDst = $dstRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $destinationBaseUri = [System.Uri]::new($normalizedDst)
 
    $getRelativePath = {
        param (
            [System.Uri] $BaseUri,
            [string]     $FullName
        )
 
        $itemUri = [System.Uri]::new($FullName)
        [System.Uri]::UnescapeDataString(
            $BaseUri.MakeRelativeUri($itemUri).ToString()
        ).Replace('/', [IO.Path]::DirectorySeparatorChar)
    }
 
    $normalizeGlobPath = {
        param ([string] $Path)
 
        $Path.Replace('/', '\').Trim('\')
    }
 
    $compiledIgnorePatterns = @(
        foreach ($sourceIgnorePattern in $SourceIgnorePatterns) {
            $normalizedPattern = & $normalizeGlobPath $sourceIgnorePattern
            if ([string]::IsNullOrEmpty($normalizedPattern)) {
                continue
            }
 
            $patternSegments = @($normalizedPattern -split '\\')
            if ($patternSegments.Count -eq 1) {
                $patternSegments = @('**') + $patternSegments
            }
 
            $segmentMatchers = [object[]]::new($patternSegments.Count)
            for ($segmentIndex = 0; $segmentIndex -lt $patternSegments.Count; $segmentIndex++) {
                if ($patternSegments[$segmentIndex] -ne '**') {
                    $segmentMatchers[$segmentIndex] = [System.Management.Automation.WildcardPattern]::new(
                        $patternSegments[$segmentIndex],
                        [System.Management.Automation.WildcardOptions]::IgnoreCase
                    )
                }
            }
 
            [pscustomobject]@{
                Segments = $patternSegments
                Matchers = $segmentMatchers
            }
        }
    )
 
    $shouldIgnoreSourcePath = {
        param ([string] $RelativePath)
 
        if (-not $compiledIgnorePatterns) {
            return $false
        }
 
        $normalizedRelativePath = & $normalizeGlobPath $RelativePath
        $pathSegments = $normalizedRelativePath -split '\\'
        foreach ($compiledPattern in $compiledIgnorePatterns) {
            $patternSegments = $compiledPattern.Segments
            $segmentMatchers = $compiledPattern.Matchers
            $matchCache = @{}
            $matchSegments = {
                param (
                    [int] $PathIndex,
                    [int] $PatternIndex
                )
 
                $cacheKey = "$PathIndex/$PatternIndex"
                if ($matchCache.ContainsKey($cacheKey)) {
                    return $matchCache[$cacheKey]
                }
 
                if ($PatternIndex -eq $patternSegments.Count) {
                    $matched = $PathIndex -eq $pathSegments.Count
                }
                elseif ($patternSegments[$PatternIndex] -eq '**') {
                    $matched = & $matchSegments $PathIndex ($PatternIndex + 1)
                    if (-not $matched -and $PathIndex -lt $pathSegments.Count) {
                        $matched = & $matchSegments ($PathIndex + 1) $PatternIndex
                    }
                }
                elseif ($PathIndex -eq $pathSegments.Count) {
                    $matched = $false
                }
                else {
                    $matched = $segmentMatchers[$PatternIndex].IsMatch($pathSegments[$PathIndex]) -and
                        (& $matchSegments ($PathIndex + 1) ($PatternIndex + 1))
                }
 
                $matchCache[$cacheKey] = $matched
                return $matched
            }
 
            if (& $matchSegments 0 0) {
                return $true
            }
        }
 
        return $false
    }
 
    $isSourceFileSizeSelected = {
        param ([long] $FileSize)
 
        return $FileSize -ge $SourceMinimumFileSizeBytes -and
            $FileSize -le $SourceMaximumFileSizeBytes
    }
 
    $inspectSourcePathForCleanup = {
        param ([string] $SourcePath)
 
        try {
            $sourceInfo = Get-Item -LiteralPath $SourcePath -ErrorAction Stop
            return [pscustomobject]@{
                Status       = 'Present'
                SourceInfo   = $sourceInfo
                ErrorMessage = $null
            }
        }
        catch {
            $inspectionError = $_.Exception.Message
            $sourceProbePath = Split-Path -Path $SourcePath -Parent
            while (-not [string]::IsNullOrEmpty($sourceProbePath)) {
                try {
                    $sourceProbeInfo = Get-Item -LiteralPath $sourceProbePath -ErrorAction Stop
                    if ($sourceProbeInfo -and $sourceProbeInfo.PSIsContainer) {
                        return [pscustomobject]@{
                            Status       = 'Missing'
                            SourceInfo   = $null
                            ErrorMessage = $null
                        }
                    }
                    break
                }
                catch {
                    if ($sourceProbePath.Equals($srcRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                        break
                    }
                    $nextSourceProbePath = Split-Path -Path $sourceProbePath -Parent
                    if ($nextSourceProbePath -eq $sourceProbePath) {
                        break
                    }
                    $sourceProbePath = $nextSourceProbePath
                }
            }
 
            return [pscustomobject]@{
                Status       = 'Unavailable'
                SourceInfo   = $null
                ErrorMessage = $inspectionError
            }
        }
    }
 
    $isCopyPartialFile = {
        param ([string] $Name)
 
        return $Name -match '\.partial\.[0-9a-fA-F]{64}(\.[0-9a-fA-F]{32})?$'
    }
 
    $disposeFrame = {
        param ($Frame)
 
        if ($Frame.FilesEnumerator) {
            try {
                $Frame.FilesEnumerator.Dispose()
            }
            catch {
            }
            $Frame.FilesEnumerator = $null
        }
        if ($Frame.DirectoriesEnumerator) {
            try {
                $Frame.DirectoriesEnumerator.Dispose()
            }
            catch {
            }
            $Frame.DirectoriesEnumerator = $null
        }
    }
 
    $canStartOperationWork = {
        if ($MaxOperationTime -ne [TimeSpan]::MaxValue -and
            $operationStopwatch.Elapsed -ge $MaxOperationTime) {
            return $false
        }
        return $true
    }
 
    $getRetryDelaySeconds = {
        param ([int] $RetryNumber)
 
        if ($RetryBackoffPolicy -eq 'Fixed' -or $WaitSeconds -eq 0) {
            return $WaitSeconds
        }
 
        $delaySeconds = [double]$WaitSeconds
        for ($delayIndex = 1; $delayIndex -lt $RetryNumber; $delayIndex++) {
            if ($delaySeconds -ge [int]::MaxValue / 2.0) {
                return [int]::MaxValue
            }
            $delaySeconds *= 2
        }
        return [int][Math]::Ceiling([Math]::Min($delaySeconds, [double][int]::MaxValue))
    }
 
    $invokeEnumerationOperation = {
        param (
            [scriptblock] $Operation,
            [string]      $Description
        )
 
        $attempt = 0
        while ($true) {
            try {
                $operationResult = & $Operation
                return [pscustomobject]@{
                    Succeeded     = $true
                    Stopped       = $false
                    Result        = $operationResult
                    ErrorMessage  = $null
                }
            }
            catch {
                $attempt++
                if ($attempt -ge $RetryCount) {
                    return [pscustomobject]@{
                        Succeeded     = $false
                        Stopped       = $false
                        Result        = $null
                        ErrorMessage  = $_.Exception.Message
                    }
                }
 
                $retryDelaySeconds = & $getRetryDelaySeconds $attempt
                if ($MaxOperationTime -ne [TimeSpan]::MaxValue -and
                    $operationStopwatch.Elapsed.Add([TimeSpan]::FromSeconds($retryDelaySeconds)) -ge $MaxOperationTime) {
                    $state.StoppedByTimeLimit = $true
                    return [pscustomobject]@{
                        Succeeded     = $false
                        Stopped       = $true
                        Result        = $null
                        ErrorMessage  = 'Operation window expired before enumeration retry.'
                    }
                }
 
                $state.EnumerationRetries++
                & $writeOperationProgress 'Retry wait' ("Waiting {0} second(s) before retrying {1}" -f $retryDelaySeconds, $Description) $true
                Start-Sleep -Seconds $retryDelaySeconds
            }
        }
    }
 
    $invalidateDirectoryPreflight = {
        param ([string] $DestinationPath)
 
        $preflightKey = & $normalizePath $DestinationPath
        if ($directoryPreflight.ContainsKey($preflightKey)) {
            [void]$directoryPreflight.Remove($preflightKey)
            $state.DirectoriesPreflightInvalidated++
        }
    }
 
    $getDirectoryPreflight = {
        param ([string] $DestinationPath)
 
        $preflightKey = & $normalizePath $DestinationPath
        if ($directoryPreflight.ContainsKey($preflightKey)) {
            return $directoryPreflight[$preflightKey]
        }
 
        & $writeOperationProgress 'Preflight' ("Checking destination directory {0}" -f $DestinationPath) $false
 
        if (-not (& $canStartOperationWork)) {
            $state.StoppedByTimeLimit = $true
            $stoppedResult = [pscustomobject]@{
                Path          = $DestinationPath
                Created       = $false
                Succeeded     = $false
                Stopped       = $true
                ErrorMessage  = 'Operation window expired before destination preflight.'
            }
            $directoryPreflight[$preflightKey] = $stoppedResult
            return $stoppedResult
        }
 
        $state.DirectoriesPreflighted++
        try {
            $result = TestCopyDestinationDirectory -Path $DestinationPath -ErrorAction Stop
            $result | Add-Member -NotePropertyName Stopped -NotePropertyValue $false
            $directoryPreflight[$preflightKey] = $result
            $state.DirectoriesPreflightPassed++
            if ($result.Created) {
                $state.DirectoriesCreated++
            }
        }
        catch {
            $result = [pscustomobject]@{
                Path         = $DestinationPath
                Created      = $false
                Succeeded    = $false
                Stopped      = $false
                ErrorMessage = $_.Exception.Message
            }
            $directoryPreflight[$preflightKey] = $result
            $state.DirectoriesPreflightFailed++
            Write-Warning "Destination directory preflight failed for $DestinationPath. $_"
            if ($FailFast) {
                throw
            }
        }
        return $result
    }
 
    $processSelectedFile = {
        param (
            [System.IO.FileInfo] $SourceFile,
            [string]              $DestinationPath,
            [string]              $DestinationDirectoryPath
        )
 
        if (-not (& $canStartOperationWork)) {
            $state.StoppedByTimeLimit = $true
            if ($OutputMode -ne 'Summary') {
                Write-Output ([pscustomobject]@{
                    SourcePath       = $SourceFile.FullName
                    DestinationPath  = $DestinationPath
                    Attempts         = 0
                    Completed        = $false
                    NotAttempted     = $true
                    StoppedByTimeLimit = $true
                    ErrorMessage     = 'Operation window expired before copy started.'
                })
            }
            return
        }
 
        $preflightResult = & $getDirectoryPreflight $DestinationDirectoryPath
        if ($preflightResult.Stopped) {
            if ($OutputMode -ne 'Summary') {
                Write-Output ([pscustomobject]@{
                    SourcePath       = $SourceFile.FullName
                    DestinationPath  = $DestinationPath
                    Attempts         = 0
                    Completed        = $false
                    NotAttempted     = $true
                    StoppedByTimeLimit = $true
                    ErrorMessage     = $preflightResult.ErrorMessage
                })
            }
            return
        }
        if (-not $preflightResult.Succeeded) {
            $state.FilesPreflightFailed++
            $state.FilesFailed++
            Write-Warning "Skipping $($SourceFile.FullName) because destination preflight failed for $DestinationDirectoryPath. $($preflightResult.ErrorMessage)"
            if ($OutputMode -ne 'Summary') {
                Write-Output ([pscustomobject]@{
                    SourcePath      = $SourceFile.FullName
                    DestinationPath = $DestinationPath
                    Attempts        = 0
                    Completed       = $false
                    PreflightFailed = $true
                    ErrorMessage    = $preflightResult.ErrorMessage
                })
            }
            return
        }
 
        & $writeOperationProgress 'Copy' ("Copying {0}" -f $SourceFile.FullName) $false $SourceFile.FullName
        $attempt = 0
        $lastError = $null
        $fileFinished = $false
        $writerToken = [guid]::NewGuid().ToString('N')
        while ($attempt -lt $RetryCount -and -not $fileFinished) {
            if (-not (& $canStartOperationWork)) {
                $state.StoppedByTimeLimit = $true
                if ($attempt -eq 0) {
                    if ($OutputMode -ne 'Summary') {
                        Write-Output ([pscustomobject]@{
                            SourcePath       = $SourceFile.FullName
                            DestinationPath  = $DestinationPath
                            Attempts         = 0
                            Completed        = $false
                            NotAttempted     = $true
                            StoppedByTimeLimit = $true
                            ErrorMessage     = 'Operation window expired before copy started.'
                        })
                    }
                }
                else {
                    $state.FilesCopyFailed++
                    $state.FilesFailed++
                    if ($OutputMode -ne 'Summary') {
                        Write-Output ([pscustomobject]@{
                            SourcePath       = $SourceFile.FullName
                            DestinationPath  = $DestinationPath
                            Attempts         = $attempt
                            Completed        = $false
                            StoppedByTimeLimit = $true
                            ErrorMessage     = $lastError
                        })
                    }
                }
                break
            }
 
            if ($attempt -gt 0) {
                $preflightResult = & $getDirectoryPreflight $DestinationDirectoryPath
                if ($preflightResult.Stopped) {
                    $state.StoppedByTimeLimit = $true
                    $state.FilesCopyFailed++
                    $state.FilesFailed++
                    break
                }
                if (-not $preflightResult.Succeeded) {
                    $state.FilesPreflightFailed++
                    $state.FilesFailed++
                    Write-Warning "Skipping retry for $($SourceFile.FullName) because destination preflight failed for $DestinationDirectoryPath. $($preflightResult.ErrorMessage)"
                    break
                }
            }
 
            try {
                $attempt++
                $state.TotalAttempts++
                if ($attempt -gt 1) {
                    $state.TotalRetries++
                }
                if (Test-Path -LiteralPath $DestinationPath -PathType Container) {
                    Remove-Item -LiteralPath $DestinationPath -Recurse -Force -ErrorAction Stop
                }
                $copyStopwatch.Start()
                try {
                    $copyResult = CopyFileRaw `
                        -SourcePath $SourceFile.FullName `
                        -DestinationPath $DestinationPath `
                        -ChunkSizeBytes $ChunkSizeBytes `
                        -TargetBytesPerSecond $TargetBytesPerSecond `
                        -PartialIdentityMode $PartialIdentityMode `
                        -FlushPolicy $FlushPolicy `
                        -WriterToken $writerToken `
                        -ProgressIntervalMilliseconds $ProgressIntervalMilliseconds `
                        -ProgressId $copyProgressId
                }
                finally {
                    $copyStopwatch.Stop()
                }
                $sourceInfo = Get-Item -LiteralPath $SourceFile.FullName -ErrorAction Stop
                if ($copyResult.Outcome -eq 'Copied') {
                    $sourceTimestamp = $sourceInfo.LastWriteTimeUtc
                    $destinationInfo = Get-Item -LiteralPath $DestinationPath -ErrorAction Stop
                    if ($destinationInfo.LastWriteTimeUtc -ne $sourceTimestamp) {
                        [System.IO.File]::SetLastWriteTimeUtc($DestinationPath, $sourceTimestamp)
                    }
                    $verifiedDestinationInfo = Get-Item -LiteralPath $DestinationPath -ErrorAction Stop
                    if ($verifiedDestinationInfo.LastWriteTimeUtc -ne $sourceTimestamp) {
                        throw "Unable to preserve source timestamp on $DestinationPath."
                    }
                }
                else {
                    $null = Get-Item -LiteralPath $DestinationPath -ErrorAction Stop
                }
                $state.FilesCompleted++
                switch ($copyResult.Outcome) {
                    'Copied' {
                        $state.FilesCopied++
                    }
                    'AlreadyPresent' {
                        $state.FilesSkipped++
                        $state.FilesAlreadyPresent++
                    }
                    'PeerWon' {
                        $state.FilesSkipped++
                        $state.FilesPeerWon++
                    }
                    default {
                        throw "CopyFileRaw returned unsupported outcome '$($copyResult.Outcome)'."
                    }
                }
                $state.BytesTransferred += $copyResult.BytesTransferred
                $state.BytesResumed += $copyResult.ResumedBytes
                $state.RedundantPartialsRemoved += $copyResult.RedundantPartialsRemoved
                if ($copyResult.WasResumed) {
                    $state.FilesResumed++
                }
                if ($copyResult.ResumeValidation -eq 'InvalidRestarted') {
                    $state.InvalidPartialRestarts++
                }
                if ($OutputMode -ne 'Summary') {
                    Write-Output ("{0}: {1} -> {2} (attempt {3}; {4}; elapsed {5})" -f `
                        $copyResult.Outcome, $SourceFile.FullName, $DestinationPath, $attempt,
                        (Format-ResilientCopyByteRate -BytesPerSecond $copyResult.AverageBytesPerSecond),
                        $copyResult.Elapsed)
                    Write-Output $copyResult
                }
                & $writeOperationProgress 'Copy' ("Completed {0}" -f $SourceFile.FullName) $false $SourceFile.FullName
                $fileFinished = $true
            }
            catch {
                $lastError = $_.Exception.Message
                if ($attempt -ge $RetryCount) {
                    if ($FailFast) {
                        throw
                    }
                    $state.FilesCopyFailed++
                    $state.FilesFailed++
                    Write-Warning "Giving up on $($SourceFile.FullName) after $attempt attempt(s); continuing with the next file. $_"
                    if ($OutputMode -ne 'Summary') {
                        Write-Output ([pscustomobject]@{
                            SourcePath      = $SourceFile.FullName
                            DestinationPath = $DestinationPath
                            Attempts        = $attempt
                            Completed       = $false
                            ErrorMessage    = $lastError
                        })
                    }
                    break
                }
 
                $retryDelaySeconds = & $getRetryDelaySeconds $attempt
                $waitWouldExceedWindow = $false
                if ($MaxOperationTime -ne [TimeSpan]::MaxValue -and
                    $operationStopwatch.Elapsed.Add([TimeSpan]::FromSeconds($retryDelaySeconds)) -ge $MaxOperationTime) {
                    $waitWouldExceedWindow = $true
                }
                if ($waitWouldExceedWindow) {
                    $state.StoppedByTimeLimit = $true
                    $state.FilesCopyFailed++
                    $state.FilesFailed++
                    if ($OutputMode -ne 'Summary') {
                        Write-Output ([pscustomobject]@{
                            SourcePath       = $SourceFile.FullName
                            DestinationPath  = $DestinationPath
                            Attempts         = $attempt
                            Completed        = $false
                            StoppedByTimeLimit = $true
                            ErrorMessage     = $lastError
                        })
                    }
                    break
                }
                & $invalidateDirectoryPreflight $DestinationDirectoryPath
                Write-Warning "Attempt $attempt failed for $($SourceFile.FullName): $_"
                & $writeOperationProgress 'Retry wait' ("Waiting {0} second(s) before retrying {1}" -f $retryDelaySeconds, $SourceFile.FullName) $true $SourceFile.FullName
                Start-Sleep -Seconds $retryDelaySeconds
            }
        }
    }
 
    $processDiscoveredFile = {
        param (
            [System.IO.FileInfo] $File,
            [string]              $RelativePath
        )
 
        $destinationPath = $null
        $selectedForCopy = $false
        try {
            $destinationPath = Join-Path $dstRoot $RelativePath
            $needsCopy = -not $SkipIfUnchanged -or (CompareCopyFile `
                -SourceFile $File `
                -DestinationPath $destinationPath `
                -ComparisonMode $ComparisonMode `
                -LastWriteTimeTolerance $LastWriteTimeTolerance)

            $partialCandidatesRemain = $false
            if (-not $needsCopy) {
                $destinationDirectory = Split-Path -Path $destinationPath -Parent
                $destinationLeaf = [System.IO.Path]::GetFileName($destinationPath)
                $partialCandidatesRemain = @(
                    Get-ChildItem -LiteralPath $destinationDirectory -File -Filter ($destinationLeaf + '.partial.*') -ErrorAction SilentlyContinue
                ).Count -gt 0
            }
 
            if ($needsCopy -or $partialCandidatesRemain) {
                $state.FilesSelected++
                $state.SelectedBytes += $File.Length
                $selectedForCopy = $true
            }
            else {
                $state.FilesSkipped++
                $state.FilesAlreadyPresent++
            }
        }
        catch {
            # A transient lock on the final file must not fail a cooperative writer before CopyFileRaw can retry
            # and reconcile it. Defer the exact final decision to that retrying, hash-verifying path.
            $state.FilesComparisonDeferred++
            $state.FilesSelected++
            $state.SelectedBytes += $File.Length
            $selectedForCopy = $true
            Write-Warning "Unable to compare $($File.FullName); deferring verification to the retrying copy path. $_"
        }
 
        if ($selectedForCopy -and -not $state.StoppedByTimeLimit) {
            $destinationDirectoryPath = Split-Path $destinationPath -Parent
            $fileOutput = @(& $processSelectedFile `
                -SourceFile $File `
                -DestinationPath $destinationPath `
                -DestinationDirectoryPath $destinationDirectoryPath)
            foreach ($outputItem in $fileOutput) {
                Write-Output $outputItem
            }
        }
    }
 
    $processNextQueuedFile = {
        if ($workQueueState.Items.Count -eq 0) {
            return
        }
        if (-not (& $canStartOperationWork)) {
            $state.StoppedByTimeLimit = $true
            $state.ComparisonCompleted = $false
            return
        }
 
        $selectedIndex = 0
        if ($WorkQueueOrderPolicy -eq 'SmallestFirst' -or $WorkQueueOrderPolicy -eq 'LargestFirst') {
            for ($index = 1; $index -lt $workQueueState.Items.Count; $index++) {
                $candidate = $workQueueState.Items[$index]
                $selected = $workQueueState.Items[$selectedIndex]
                $candidateWins = if ($WorkQueueOrderPolicy -eq 'SmallestFirst') {
                    [long]$candidate.Size -lt [long]$selected.Size
                }
                else {
                    [long]$candidate.Size -gt [long]$selected.Size
                }
                if ($candidateWins) {
                    $selectedIndex = $index
                }
            }
        }
 
        $record = $workQueueState.Items[$selectedIndex]
        $workQueueState.Items.RemoveAt($selectedIndex)
        $workQueueState.Bytes -= [long]$record.Size
 
        try {
            $currentFile = Get-Item -LiteralPath $record.SourcePath -ErrorAction Stop
            if (-not ($currentFile -is [System.IO.FileInfo])) {
                throw "Queued source path is no longer a file: $($record.SourcePath)"
            }
            if (& $isReparsePoint $currentFile) {
                Write-Warning "Skipping unsupported source reparse point: $($currentFile.FullName)"
                return
            }
            if (-not (& $isSourceFileSizeSelected $currentFile.Length)) {
                return
            }
        }
        catch {
            $state.FilesCompareFailed++
            $state.FilesFailed++
            $state.ComparisonCompleted = $false
            Write-Warning "Unable to inspect queued source file $($record.SourcePath). $_"
            if ($OutputMode -ne 'Summary') {
                Write-Output ([pscustomobject]@{
                    SourcePath       = $record.SourcePath
                    DestinationPath  = Join-Path $dstRoot $record.RelativePath
                    Attempts         = 0
                    Completed        = $false
                    SourceUnavailable = $true
                    ComparisonFailed = $true
                    ErrorMessage     = $_.Exception.Message
                })
            }
            return
        }
 
        & $processDiscoveredFile $currentFile $record.RelativePath
    }
 
    $sourceTraversalCompleted = $true
    $rootPreflight = & $getDirectoryPreflight $dstRoot
    $state.RootPreflightSucceeded = $rootPreflight.Succeeded
    if ($rootPreflight.Stopped) {
        $state.ComparisonCompleted = $false
    }
 
    if (-not $rootPreflight.Stopped) {
        $sourceFrames = New-Object System.Collections.Stack
        $sourceFrames.Push([pscustomobject]@{
            Directory             = $srcRootInfo
            FilesEnumerator       = $null
            DirectoriesEnumerator = $null
            FilesStarted          = $false
            DirectoriesStarted    = $false
        })
 
        try {
            while ($sourceFrames.Count -gt 0) {
            & $writeOperationProgress 'Source traversal' ("Scanning {0}" -f $sourceFrames.Peek().Directory.FullName) $false
            if (-not (& $canStartOperationWork)) {
                $state.StoppedByTimeLimit = $true
                $state.ComparisonCompleted = $false
                $sourceTraversalCompleted = $false
                break
            }
 
            $frame = $sourceFrames.Peek()
            if (-not $frame.FilesStarted) {
                $frame.FilesStarted = $true
                if ($frame.Directory.FullName -ne $srcRoot -and
                    ($CopyEmptyDirectories -or $MirrorMode)) {
                    $relativeDirectory = & $getRelativePath $baseUri $frame.Directory.FullName
                    $destinationDirectory = Join-Path $dstRoot $relativeDirectory
                    $directoryResult = & $getDirectoryPreflight $destinationDirectory
                    if ($directoryResult.Stopped) {
                        $state.ComparisonCompleted = $false
                        $sourceTraversalCompleted = $false
                        break
                    }
                    if ($CopyEmptyDirectories -and $directoryResult.Succeeded -and $directoryResult.Created -and
                        $OutputMode -ne 'Summary') {
                        Write-Output "Created directory: $destinationDirectory"
                    }
                }
 
                $enumeratorResult = & $invokeEnumerationOperation `
                    { return ,($frame.Directory.EnumerateFiles().GetEnumerator()) } `
                    ("files in {0}" -f $frame.Directory.FullName)
                if (-not $enumeratorResult.Succeeded) {
                    $state.ComparisonCompleted = $false
                    $sourceTraversalCompleted = $false
                    if ($enumeratorResult.Stopped) {
                        break
                    }
                    $state.ComparisonFailures++
                    Write-Warning "Unable to enumerate files in $($frame.Directory.FullName). $($enumeratorResult.ErrorMessage)"
                    if ($FailFast) {
                        throw $enumeratorResult.ErrorMessage
                    }
                    & $disposeFrame $frame
                    $sourceFrames.Pop() | Out-Null
                    continue
                }
                $frame.FilesEnumerator = $enumeratorResult.Result
            }
 
            $moveNextResult = & $invokeEnumerationOperation `
                { $frame.FilesEnumerator.MoveNext() } `
                ("files in {0}" -f $frame.Directory.FullName)
            if (-not $moveNextResult.Succeeded) {
                $state.ComparisonCompleted = $false
                $sourceTraversalCompleted = $false
                if ($moveNextResult.Stopped) {
                    break
                }
                $state.ComparisonFailures++
                Write-Warning "Unable to continue enumerating files in $($frame.Directory.FullName). $($moveNextResult.ErrorMessage)"
                if ($FailFast) {
                    throw $moveNextResult.ErrorMessage
                }
            }
            $hasFile = if ($moveNextResult.Succeeded) { [bool]$moveNextResult.Result } else { $false }
 
            if ($hasFile) {
                $file = $frame.FilesEnumerator.Current
                if (& $isReparsePoint $file) {
                    Write-Warning "Skipping unsupported source reparse point: $($file.FullName)"
                    continue
                }
                $state.FilesDiscovered++
 
                $relativePath = & $getRelativePath $baseUri $file.FullName
                if (& $shouldIgnoreSourcePath $relativePath) {
                    continue
                }
                if (-not (& $isSourceFileSizeSelected $file.Length)) {
                    continue
                }
 
                if (-not $workQueueEnabled) {
                    & $processDiscoveredFile $file $relativePath
                    if ($state.StoppedByTimeLimit) {
                        $state.ComparisonCompleted = $false
                        $sourceTraversalCompleted = $false
                        break
                    }
                    continue
                }
 
                $fileSize = [long]$file.Length
                while ($workQueueState.Items.Count -gt 0 -and
                    ($workQueueState.Items.Count -ge $WorkQueueMaxItems -or
                    ($workQueueState.Bytes -gt 0 -and $workQueueState.Bytes + $fileSize -gt $WorkQueueMaxBytes))) {
                    & $processNextQueuedFile
                    if ($state.StoppedByTimeLimit) {
                        $state.ComparisonCompleted = $false
                        $sourceTraversalCompleted = $false
                        break
                    }
                }
                if ($state.StoppedByTimeLimit) {
                    break
                }
 
                [void]$workQueueState.Items.Add([pscustomobject]@{
                    SourcePath     = $file.FullName
                    RelativePath   = $relativePath
                    Size           = $fileSize
                    DiscoveryOrder = $workQueueState.NextDiscoveryOrder
                })
                $workQueueState.NextDiscoveryOrder++
                $workQueueState.Bytes += $fileSize
                if ($workQueueState.Items.Count -gt $state.WorkQueuePeakItems) {
                    $state.WorkQueuePeakItems = $workQueueState.Items.Count
                }
                if ($workQueueState.Bytes -gt $state.WorkQueuePeakBytes) {
                    $state.WorkQueuePeakBytes = $workQueueState.Bytes
                }
                continue
            }
 
            if (-not $frame.DirectoriesStarted) {
                $frame.DirectoriesStarted = $true
                $enumeratorResult = & $invokeEnumerationOperation `
                    { return ,($frame.Directory.EnumerateDirectories().GetEnumerator()) } `
                    ("directories in {0}" -f $frame.Directory.FullName)
                if (-not $enumeratorResult.Succeeded) {
                    $state.ComparisonCompleted = $false
                    $sourceTraversalCompleted = $false
                    if ($enumeratorResult.Stopped) {
                        break
                    }
                    $state.ComparisonFailures++
                    Write-Warning "Unable to enumerate directories in $($frame.Directory.FullName). $($enumeratorResult.ErrorMessage)"
                    if ($FailFast) {
                        throw $enumeratorResult.ErrorMessage
                    }
                    & $disposeFrame $frame
                    $sourceFrames.Pop() | Out-Null
                    continue
                }
                $frame.DirectoriesEnumerator = $enumeratorResult.Result
            }
 
            $moveNextResult = & $invokeEnumerationOperation `
                { $frame.DirectoriesEnumerator.MoveNext() } `
                ("directories in {0}" -f $frame.Directory.FullName)
            if (-not $moveNextResult.Succeeded) {
                $state.ComparisonCompleted = $false
                $sourceTraversalCompleted = $false
                if ($moveNextResult.Stopped) {
                    break
                }
                $state.ComparisonFailures++
                Write-Warning "Unable to continue enumerating directories in $($frame.Directory.FullName). $($moveNextResult.ErrorMessage)"
                if ($FailFast) {
                    throw $moveNextResult.ErrorMessage
                }
            }
            $hasDirectory = if ($moveNextResult.Succeeded) { [bool]$moveNextResult.Result } else { $false }
 
            if ($hasDirectory) {
                $sourceSubdirectory = $frame.DirectoriesEnumerator.Current
                if (-not ($sourceSubdirectory -is [System.IO.DirectoryInfo])) {
                    $sourceSubdirectory = Get-Item -LiteralPath (Join-Path $frame.Directory.FullName ([string]$sourceSubdirectory)) -ErrorAction Stop
                }
                if (& $isReparsePoint $sourceSubdirectory) {
                    Write-Warning "Skipping unsupported source reparse point: $($sourceSubdirectory.FullName)"
                    continue
                }
                $sourceSubdirectoryRelativePath = & $getRelativePath $baseUri $sourceSubdirectory.FullName
                if (& $shouldIgnoreSourcePath $sourceSubdirectoryRelativePath) {
                    continue
                }
                $sourceFrames.Push([pscustomobject]@{
                    Directory             = $sourceSubdirectory
                    FilesEnumerator       = $null
                    DirectoriesEnumerator = $null
                    FilesStarted          = $false
                    DirectoriesStarted    = $false
                })
                continue
            }
 
            & $disposeFrame $frame
                $sourceFrames.Pop() | Out-Null
            }
        }
        finally {
            while ($sourceFrames.Count -gt 0) {
                $sourceFrameToDispose = $sourceFrames.Pop()
                & $disposeFrame $sourceFrameToDispose
            }
        }
 
        if ($workQueueEnabled -and $sourceTraversalCompleted) {
            while ($workQueueState.Items.Count -gt 0) {
                & $processNextQueuedFile
                if ($state.StoppedByTimeLimit) {
                    $state.ComparisonCompleted = $false
                    $sourceTraversalCompleted = $false
                    break
                }
            }
        }
        if ($workQueueEnabled -and $workQueueState.Items.Count -gt 0) {
            $state.QueuedFilesNotAttempted += $workQueueState.Items.Count
            $workQueueState.Items.Clear()
            $workQueueState.Bytes = 0L
            $state.ComparisonCompleted = $false
            $sourceTraversalCompleted = $false
        }
    }
 
    $cleanupFiles = {
        if (-not $MirrorMode) {
            return
        }
        if (-not $state.ComparisonCompleted -or -not $state.RootPreflightSucceeded) {
            $state.CleanupCompleted = $false
            Write-Warning 'Mirror cleanup skipped because source traversal or destination root preflight did not complete.'
            return
        }
 
        $destinationFrames = New-Object System.Collections.Stack
        $destinationFrames.Push([pscustomobject]@{
            Directory             = Get-Item -LiteralPath $dstRoot -ErrorAction Stop
            FilesEnumerator       = $null
            DirectoriesEnumerator = $null
            FilesStarted          = $false
            DirectoriesStarted    = $false
        })
 
        try {
            while ($destinationFrames.Count -gt 0) {
            & $writeOperationProgress 'Mirror cleanup' ("Scanning {0}" -f $destinationFrames.Peek().Directory.FullName) $false
            if (-not (& $canStartOperationWork)) {
                $state.StoppedByTimeLimit = $true
                $state.CleanupCompleted = $false
                break
            }
            $frame = $destinationFrames.Peek()
            if (-not $frame.FilesStarted) {
                $frame.FilesStarted = $true
                $enumeratorResult = & $invokeEnumerationOperation `
                    { return ,($frame.Directory.EnumerateFiles().GetEnumerator()) } `
                    ("destination files in {0}" -f $frame.Directory.FullName)
                if (-not $enumeratorResult.Succeeded) {
                    $state.CleanupCompleted = $false
                    if ($enumeratorResult.Stopped) {
                        break
                    }
                    $state.CleanupFailures++
                    Write-Warning "Unable to enumerate destination files in $($frame.Directory.FullName). $($enumeratorResult.ErrorMessage)"
                    if ($FailFast) {
                        throw $enumeratorResult.ErrorMessage
                    }
                    & $disposeFrame $frame
                    $destinationFrames.Pop() | Out-Null
                    continue
                }
                $frame.FilesEnumerator = $enumeratorResult.Result
            }
 
            $moveNextResult = & $invokeEnumerationOperation `
                { $frame.FilesEnumerator.MoveNext() } `
                ("destination files in {0}" -f $frame.Directory.FullName)
            if (-not $moveNextResult.Succeeded) {
                $state.CleanupCompleted = $false
                if ($moveNextResult.Stopped) {
                    break
                }
                $state.CleanupFailures++
                Write-Warning "Unable to continue enumerating destination files in $($frame.Directory.FullName). $($moveNextResult.ErrorMessage)"
                if ($FailFast) {
                    throw $moveNextResult.ErrorMessage
                }
            }
            $hasFile = if ($moveNextResult.Succeeded) { [bool]$moveNextResult.Result } else { $false }
            if ($hasFile) {
                $destinationFile = $frame.FilesEnumerator.Current
                if (& $isReparsePoint $destinationFile) {
                    Write-Warning "Skipping unsupported destination reparse point: $($destinationFile.FullName)"
                    continue
                }
                $relativeFile = & $getRelativePath $destinationBaseUri $destinationFile.FullName
                if (& $shouldIgnoreSourcePath $relativeFile) {
                    continue
                }
                if (& $isCopyPartialFile $destinationFile.Name) {
                    $state.PartialFilesPreserved++
                    continue
                }
                $sourcePath = Join-Path $srcRoot $relativeFile
                $sourceStatus = & $inspectSourcePathForCleanup $sourcePath
                if ($sourceStatus.Status -eq 'Unavailable') {
                    $state.CleanupFailures++
                    $state.CleanupCompleted = $false
                    Write-Warning "Unable to inspect source path $sourcePath; preserving $($destinationFile.FullName). $($sourceStatus.ErrorMessage)"
                    if ($FailFast) {
                        throw $sourceStatus.ErrorMessage
                    }
                    continue
                }
                $sourceInfo = $sourceStatus.SourceInfo
                if ($sourceInfo -and (& $isReparsePoint $sourceInfo)) {
                    Write-Warning "Skipping destination cleanup for unsupported source reparse point: $sourcePath"
                    continue
                }
                if ($sourceInfo -and -not $sourceInfo.PSIsContainer -and
                    -not (& $isSourceFileSizeSelected $sourceInfo.Length)) {
                    continue
                }
                if ($sourceStatus.Status -eq 'Missing' -or ($sourceInfo -and $sourceInfo.PSIsContainer)) {
                    try {
                        $sourceRecheck = & $inspectSourcePathForCleanup $sourcePath
                        if ($sourceRecheck.Status -eq 'Present') {
                            continue
                        }
                        if ($sourceRecheck.Status -eq 'Unavailable') {
                            $state.CleanupFailures++
                            $state.CleanupCompleted = $false
                            Write-Warning "Unable to recheck source path $sourcePath; preserving $($destinationFile.FullName). $($sourceRecheck.ErrorMessage)"
                            if ($FailFast) {
                                throw $sourceRecheck.ErrorMessage
                            }
                            continue
                        }
                        Remove-Item -LiteralPath $destinationFile.FullName -Force -ErrorAction Stop
                        $state.FilesRemoved++
                        if ($OutputMode -ne 'Summary') {
                            Write-Output "Removed: $($destinationFile.FullName)"
                        }
                    }
                    catch {
                        $state.CleanupFailures++
                        Write-Warning "Unable to remove destination-only file $($destinationFile.FullName). $_"
                        if ($FailFast) {
                            throw
                        }
                    }
                }
                continue
            }
 
            if (-not $frame.DirectoriesStarted) {
                $frame.DirectoriesStarted = $true
                $enumeratorResult = & $invokeEnumerationOperation `
                    { return ,($frame.Directory.EnumerateDirectories().GetEnumerator()) } `
                    ("destination directories in {0}" -f $frame.Directory.FullName)
                if (-not $enumeratorResult.Succeeded) {
                    $state.CleanupCompleted = $false
                    if ($enumeratorResult.Stopped) {
                        break
                    }
                    $state.CleanupFailures++
                    Write-Warning "Unable to enumerate destination directories in $($frame.Directory.FullName). $($enumeratorResult.ErrorMessage)"
                    if ($FailFast) {
                        throw $enumeratorResult.ErrorMessage
                    }
                    & $disposeFrame $frame
                    $destinationFrames.Pop() | Out-Null
                    continue
                }
                $frame.DirectoriesEnumerator = $enumeratorResult.Result
            }
 
            $moveNextResult = & $invokeEnumerationOperation `
                { $frame.DirectoriesEnumerator.MoveNext() } `
                ("destination directories in {0}" -f $frame.Directory.FullName)
            if (-not $moveNextResult.Succeeded) {
                $state.CleanupCompleted = $false
                if ($moveNextResult.Stopped) {
                    break
                }
                $state.CleanupFailures++
                Write-Warning "Unable to continue enumerating destination directories in $($frame.Directory.FullName). $($moveNextResult.ErrorMessage)"
                if ($FailFast) {
                    throw $moveNextResult.ErrorMessage
                }
            }
            $hasDirectory = if ($moveNextResult.Succeeded) { [bool]$moveNextResult.Result } else { $false }
            if ($hasDirectory) {
                $destinationSubdirectory = $frame.DirectoriesEnumerator.Current
                if (-not ($destinationSubdirectory -is [System.IO.DirectoryInfo])) {
                    $destinationSubdirectory = Get-Item -LiteralPath (Join-Path $frame.Directory.FullName ([string]$destinationSubdirectory)) -ErrorAction Stop
                }
                if (& $isReparsePoint $destinationSubdirectory) {
                    Write-Warning "Skipping unsupported destination reparse point: $($destinationSubdirectory.FullName)"
                    continue
                }
                $relativeDirectory = & $getRelativePath $destinationBaseUri $destinationSubdirectory.FullName
                if (& $shouldIgnoreSourcePath $relativeDirectory) {
                    continue
                }
                $sourceDirectoryPath = Join-Path $srcRoot $relativeDirectory
                $sourceDirectoryStatus = & $inspectSourcePathForCleanup $sourceDirectoryPath
                if ($sourceDirectoryStatus.Status -eq 'Unavailable') {
                    $state.CleanupFailures++
                    $state.CleanupCompleted = $false
                    Write-Warning "Unable to inspect source path $sourceDirectoryPath; preserving $($destinationSubdirectory.FullName). $($sourceDirectoryStatus.ErrorMessage)"
                    if ($FailFast) {
                        throw $sourceDirectoryStatus.ErrorMessage
                    }
                    continue
                }
                if ($sourceDirectoryStatus.SourceInfo -and (& $isReparsePoint $sourceDirectoryStatus.SourceInfo)) {
                    Write-Warning "Skipping destination cleanup for unsupported source reparse point: $sourceDirectoryPath"
                    continue
                }
                $destinationFrames.Push([pscustomobject]@{
                    Directory             = $destinationSubdirectory
                    FilesEnumerator       = $null
                    DirectoriesEnumerator = $null
                    FilesStarted          = $false
                    DirectoriesStarted    = $false
                })
                continue
            }
 
            & $disposeFrame $frame
            $destinationFrames.Pop() | Out-Null
            if ($frame.Directory.FullName -eq $dstRoot) {
                continue
            }
            if (-not (& $canStartOperationWork)) {
                $state.StoppedByTimeLimit = $true
                $state.CleanupCompleted = $false
                break
            }
            $relativeDirectory = & $getRelativePath $destinationBaseUri $frame.Directory.FullName
            $sourceDirectoryPath = Join-Path $srcRoot $relativeDirectory
            try {
                $sourceDirectoryStatus = & $inspectSourcePathForCleanup $sourceDirectoryPath
                if ($sourceDirectoryStatus.Status -eq 'Unavailable') {
                    $state.CleanupFailures++
                    $state.CleanupCompleted = $false
                    Write-Warning "Unable to inspect source path $sourceDirectoryPath; preserving $($frame.Directory.FullName). $($sourceDirectoryStatus.ErrorMessage)"
                    if ($FailFast) {
                        throw $sourceDirectoryStatus.ErrorMessage
                    }
                    continue
                }
                $sourceDirectoryInfo = $sourceDirectoryStatus.SourceInfo
                if ($sourceDirectoryInfo -and (& $isReparsePoint $sourceDirectoryInfo)) {
                    Write-Warning "Skipping destination cleanup for unsupported source reparse point: $sourceDirectoryPath"
                    continue
                }
                $childEnumerator = $null
                try {
                    $childEnumerator = [System.IO.Directory]::EnumerateFileSystemEntries(
                        $frame.Directory.FullName
                    ).GetEnumerator()
                    $hasChild = $childEnumerator.MoveNext()
                }
                finally {
                    if ($childEnumerator) {
                        $childEnumerator.Dispose()
                    }
                }
                if (($sourceDirectoryStatus.Status -eq 'Missing' -or
                    ($sourceDirectoryInfo -and -not $sourceDirectoryInfo.PSIsContainer)) -and -not $hasChild) {
                    $sourceDirectoryRecheck = & $inspectSourcePathForCleanup $sourceDirectoryPath
                    if ($sourceDirectoryRecheck.Status -eq 'Present') {
                        continue
                    }
                    if ($sourceDirectoryRecheck.Status -eq 'Unavailable') {
                        $state.CleanupFailures++
                        $state.CleanupCompleted = $false
                        Write-Warning "Unable to recheck source path $sourceDirectoryPath; preserving $($frame.Directory.FullName). $($sourceDirectoryRecheck.ErrorMessage)"
                        if ($FailFast) {
                            throw $sourceDirectoryRecheck.ErrorMessage
                        }
                        continue
                    }
                    Remove-Item -LiteralPath $frame.Directory.FullName -Force -ErrorAction Stop
                    $state.DirectoriesRemoved++
                    if ($OutputMode -ne 'Summary') {
                        Write-Output "Removed directory: $($frame.Directory.FullName)"
                    }
                }
            }
            catch {
                $state.CleanupFailures++
                Write-Warning "Unable to remove destination-only directory $($frame.Directory.FullName). $_"
                if ($FailFast) {
                    throw
                }
            }
        }
        }
        finally {
            while ($destinationFrames.Count -gt 0) {
                $destinationFrameToDispose = $destinationFrames.Pop()
                & $disposeFrame $destinationFrameToDispose
            }
        }
    }
 
    & $cleanupFiles
    & $writeOperationProgress 'Complete' 'Operation finished' $true
    Write-Progress -Id $operationProgressId -Activity 'Copy-ResilientDirectoryTree' -Completed
    $copyStopwatch.Stop()
    $operationStopwatch.Stop()
    $copyElapsedSeconds = $copyStopwatch.Elapsed.TotalSeconds
    $operationCompleted = $state.ComparisonCompleted -and
        (-not $MirrorMode -or $state.CleanupCompleted) -and
        -not $state.StoppedByTimeLimit
    $failureReasons = @()
    if ($state.StoppedByTimeLimit) {
        $failureReasons += 'TimeLimit'
    }
    if (-not $state.RootPreflightSucceeded -and -not $state.StoppedByTimeLimit) {
        $failureReasons += 'RootPreflightFailure'
    }
    if ($state.FilesPreflightFailed -gt 0) {
        $failureReasons += 'FilePreflightFailures'
    }
    if ($state.FilesCompareFailed -gt 0) {
        $failureReasons += 'FileComparisonFailures'
    }
    if ($state.ComparisonFailures -gt 0) {
        $failureReasons += 'TraversalFailures'
    }
    if ($state.FilesCopyFailed -gt 0) {
        $failureReasons += 'CopyFailures'
    }
    if ($state.CleanupFailures -gt 0) {
        $failureReasons += 'CleanupFailures'
    }
    if ($MirrorMode -and -not $state.CleanupCompleted) {
        $failureReasons += 'MirrorCleanupIncomplete'
    }
    if (-not $state.ComparisonCompleted -and -not $state.StoppedByTimeLimit -and
        $state.ComparisonFailures -eq 0 -and $state.FilesCompareFailed -eq 0) {
        $failureReasons += 'SourceTraversalIncomplete'
    }
    if ($OutputMode -ne 'PerFile') {
        Write-Output ([pscustomobject]@{
            OperationSummary           = $true
            SourceDirectory            = $srcRoot
            DestinationDirectory       = $dstRoot
            ComparisonMode             = $ComparisonMode
            SourceMinimumFileSizeBytes = $SourceMinimumFileSizeBytes
            SourceMaximumFileSizeBytes = $SourceMaximumFileSizeBytes
            FlushPolicy                 = $FlushPolicy
            RetryBackoffPolicy          = $RetryBackoffPolicy
            WorkQueueOrderPolicy       = $WorkQueueOrderPolicy
            WorkQueueMaxItems          = $WorkQueueMaxItems
            WorkQueueMaxBytes          = $WorkQueueMaxBytes
            WorkQueuePeakItems         = $state.WorkQueuePeakItems
            WorkQueuePeakBytes         = $state.WorkQueuePeakBytes
            MirrorMode                 = [bool]$MirrorMode
            CopyEmptyDirectories       = [bool]$CopyEmptyDirectories
            OutputMode                 = $OutputMode
            ComparisonCompleted        = $state.ComparisonCompleted
            CleanupCompleted            = $state.CleanupCompleted
            Completed                   = $operationCompleted
            Succeeded                   = $operationCompleted -and
                $state.FilesFailed -eq 0 -and $state.CleanupFailures -eq 0
            StoppedByTimeLimit          = $state.StoppedByTimeLimit
            FilesDiscovered             = $state.FilesDiscovered
            FilesSelected               = $state.FilesSelected
            FilesSkipped                = $state.FilesSkipped
            FilesCompleted              = $state.FilesCompleted
            FilesAlreadyPresent         = $state.FilesAlreadyPresent
            FilesPeerWon                = $state.FilesPeerWon
            FilesCopied                 = $state.FilesCopied
            FilesFailed                 = $state.FilesFailed
            FilesCopyFailed             = $state.FilesCopyFailed
            FilesPreflightFailed        = $state.FilesPreflightFailed
            FilesCompareFailed          = $state.FilesCompareFailed
            FilesComparisonDeferred     = $state.FilesComparisonDeferred
            EnumerationRetries          = $state.EnumerationRetries
            FilesNotAttempted           = [Math]::Max(0, $state.FilesSelected - $state.FilesCompleted - $state.FilesFailed)
            QueuedFilesNotAttempted     = $state.QueuedFilesNotAttempted
            SelectedBytes               = $state.SelectedBytes
            BytesTransferred            = $state.BytesTransferred
            BytesResumed                = $state.BytesResumed
            BytesProcessed              = $state.BytesTransferred + $state.BytesResumed
            DirectoriesCreated          = $state.DirectoriesCreated
            DirectoriesPreflighted      = $state.DirectoriesPreflighted
            DirectoriesPreflightPassed  = $state.DirectoriesPreflightPassed
            DirectoriesPreflightFailed  = $state.DirectoriesPreflightFailed
            DirectoriesPreflightInvalidated = $state.DirectoriesPreflightInvalidated
            FilesRemoved                = $state.FilesRemoved
            DirectoriesRemoved          = $state.DirectoriesRemoved
            PartialFilesPreserved       = $state.PartialFilesPreserved
            RedundantPartialsRemoved    = $state.RedundantPartialsRemoved
            CleanupFailures             = $state.CleanupFailures
            ComparisonFailures          = $state.ComparisonFailures
            ProgressCallbackFailures    = $state.ProgressCallbackFailures
            FailureReasons               = $failureReasons
            Attempts                    = $state.TotalAttempts
            Retries                     = $state.TotalRetries
            Elapsed                     = $operationStopwatch.Elapsed
            ElapsedSeconds              = $operationStopwatch.Elapsed.TotalSeconds
            CopyElapsed                 = $copyStopwatch.Elapsed
            CopyElapsedSeconds          = $copyElapsedSeconds
            AverageBytesPerSecond       = if ($copyElapsedSeconds -gt 0) { $state.BytesTransferred / $copyElapsedSeconds } else { 0 }
        })
    }
}
