<#
    Concurrent multi-process coverage for Copy-ResilientDirectoryTree.

    Large payload + staggered child startups + throttled copy so writers overlap on one
    destination leaf. Each child persists its summary so the parent can assert peer-win
    semantics (all succeed when final bytes match).
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

function global:New-ResilientCopyTestPayload {
    param (
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [int] $SizeBytes
    )

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $buffer = New-Object byte[] (1024 * 1024)
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        try {
            $remaining = $SizeBytes
            while ($remaining -gt 0) {
                $chunk = [Math]::Min($buffer.Length, $remaining)
                $rng.GetBytes($buffer, 0, $chunk)
                $stream.Write($buffer, 0, $chunk)
                $remaining -= $chunk
            }
        }
        finally {
            $stream.Dispose()
        }
    }
    finally {
        $rng.Dispose()
    }
}

function global:Start-ResilientCopyTestWriter {
    param (
        [Parameter(Mandatory)] [int] $WriterIndex,
        [Parameter(Mandatory)] [string] $SourceRoot,
        [Parameter(Mandatory)] [string] $DestinationRoot,
        [Parameter(Mandatory)] [string] $ResultPath,
        [Parameter(Mandatory)] [string] $ResilientScript,
        [int] $DelayMilliseconds = 0,
        [long] $TargetBytesPerSecond = 3145728,
        [int] $RetryCount = 6
    )

    $argumentList = @(
        '-NoProfile'
        '-NonInteractive'
        '-ExecutionPolicy', 'Bypass'
        '-Command'
        @"
`$ErrorActionPreference = 'Stop'
Start-Sleep -Milliseconds $DelayMilliseconds
. '$ResilientScript'
`$outputs = @()
`$summary = `$null
`$fileResult = `$null
`$failureResult = `$null
`$errorText = `$null
try {
    `$outputs = @(Copy-ResilientDirectoryTree ``
        -SourceDirectory '$SourceRoot' ``
        -DestinationDirectory '$DestinationRoot' ``
        -ComparisonMode Hash ``
        -PartialIdentityMode FullHash ``
        -FlushPolicy EndOfCopy ``
        -TargetBytesPerSecond $TargetBytesPerSecond ``
        -RetryCount $RetryCount ``
        -WaitSeconds 1 ``
        -RetryBackoffPolicy Fixed ``
        -ProgressIntervalMilliseconds 60000 ``
        -OutputMode Both)
    `$summary = @(`$outputs | Where-Object { `$_.PSObject.Properties['OperationSummary'] -and `$_.OperationSummary }) | Select-Object -Last 1
    `$fileResult = @(`$outputs | Where-Object { `$_.PSObject.Properties['Outcome'] }) | Select-Object -Last 1
    `$failureResult = @(`$outputs | Where-Object { `$_.PSObject.Properties['ErrorMessage'] -and -not `$_.Completed }) | Select-Object -Last 1
    if (`$failureResult) { `$errorText = `$failureResult.ErrorMessage }
}
catch {
    `$errorText = `$_.Exception.Message
}
`$payload = [pscustomobject]@{
    WriterIndex = $WriterIndex
    DelayMilliseconds = $DelayMilliseconds
    Succeeded = if (`$null -ne `$summary) { [bool]`$summary.Succeeded } else { `$false }
    FilesCopied = if (`$null -ne `$summary) { [int]`$summary.FilesCopied } else { 0 }
    FilesSkipped = if (`$null -ne `$summary) { [int]`$summary.FilesSkipped } else { 0 }
    FilesFailed = if (`$null -ne `$summary) { [int]`$summary.FilesFailed } else { 0 }
    Attempts = if (`$null -ne `$summary) { [int]`$summary.Attempts } else { 0 }
    Retries = if (`$null -ne `$summary) { [int]`$summary.Retries } else { 0 }
    FilesComparisonDeferred = if (`$null -ne `$summary) { [int]`$summary.FilesComparisonDeferred } else { 0 }
    Outcome = if (`$null -ne `$fileResult) { [string]`$fileResult.Outcome } else { `$null }
    WriterToken = if (`$null -ne `$fileResult) { [string]`$fileResult.WriterToken } else { `$null }
    PartialPath = if (`$null -ne `$fileResult) { [string]`$fileResult.PartialPath } else { `$null }
    Error = `$errorText
}
`$payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath '$ResultPath' -Encoding utf8
if (-not `$payload.Succeeded -or `$payload.FilesFailed -gt 0) { exit 2 }
exit 0
"@
    )

    return [pscustomobject]@{
        WriterIndex = $WriterIndex
        ResultPath  = $ResultPath
        Process     = Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentList -PassThru -WindowStyle Hidden
    }
}

function global:Wait-ResilientCopyTestWriters {
    param (
        [Parameter(Mandatory)] [object[]] $Writers,
        [TimeSpan] $Timeout = ([TimeSpan]::FromMinutes(3))
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($writer in $Writers) {
        $remainingMilliseconds = [Math]::Max(1000, [int]($Timeout.TotalMilliseconds - $stopwatch.Elapsed.TotalMilliseconds))
        $null = $writer.Process.WaitForExit($remainingMilliseconds)
        if (-not $writer.Process.HasExited) {
            try { $writer.Process.Kill() } catch { }
            throw "Writer $($writer.WriterIndex) did not exit within $($Timeout.TotalSeconds)s."
        }
    }
}

Invoke-TestPackageDescribe -Name 'Copy-ResilientDirectoryTree concurrent writers' -Body {

    It 'succeeds when staggered processes publish the same large file to one destination' {
        $workRoot = Join-Path $TestDrive ('resilient-concurrent-' + [guid]::NewGuid().ToString('N'))
        $sourceRoot = Join-Path $workRoot 'source'
        $destinationRoot = Join-Path $workRoot 'destination'
        $resultsRoot = Join-Path $workRoot 'results'
        $null = New-Item -ItemType Directory -Path $sourceRoot, $destinationRoot, $resultsRoot -Force

        $payloadName = 'payload.bin'
        $sourceFile = Join-Path $sourceRoot $payloadName
        $payloadBytes = 24 * 1024 * 1024
        New-ResilientCopyTestPayload -Path $sourceFile -SizeBytes $payloadBytes

        $sourceHash = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash.ToLowerInvariant()
        $resilientScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.ResilientDirectoryTree.ps1'
        Test-Path -LiteralPath $resilientScript | Should -BeTrue

        $writerCount = 3
        $startDelayMilliseconds = @(0, 750, 1500)
        $targetBytesPerSecond = 3 * 1024 * 1024
        $processes = @()

        for ($writerIndex = 0; $writerIndex -lt $writerCount; $writerIndex++) {
            $resultPath = Join-Path $resultsRoot ("writer-{0}.json" -f $writerIndex)
            $delayMs = $startDelayMilliseconds[$writerIndex]
            $processes += Start-ResilientCopyTestWriter `
                -WriterIndex $writerIndex `
                -SourceRoot $sourceRoot `
                -DestinationRoot $destinationRoot `
                -ResultPath $resultPath `
                -ResilientScript $resilientScript `
                -DelayMilliseconds $delayMs `
                -TargetBytesPerSecond $targetBytesPerSecond
        }

        $observedPartialNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        $observationDeadline = [DateTime]::UtcNow.AddSeconds(12)
        while ([DateTime]::UtcNow -lt $observationDeadline -and @($processes | Where-Object { -not $_.Process.HasExited }).Count -gt 0) {
            foreach ($partial in @(Get-ChildItem -LiteralPath $destinationRoot -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like ($payloadName + '.partial.*') })) {
                $null = $observedPartialNames.Add($partial.Name)
            }
            Start-Sleep -Milliseconds 100
        }
        Wait-ResilientCopyTestWriters -Writers $processes

        $writerResults = @()
        foreach ($entry in $processes) {
            Test-Path -LiteralPath $entry.ResultPath | Should -BeTrue -Because "writer $($entry.WriterIndex) must persist a result file"
            $writerResults += Get-Content -LiteralPath $entry.ResultPath -Raw | ConvertFrom-Json
        }

        $destinationFile = Join-Path $destinationRoot $payloadName
        Test-Path -LiteralPath $destinationFile -PathType Leaf | Should -BeTrue
        $destinationHash = (Get-FileHash -LiteralPath $destinationFile -Algorithm SHA256).Hash.ToLowerInvariant()
        $destinationHash | Should -Be $sourceHash

        $failedWriters = @($writerResults | Where-Object { -not $_.Succeeded -or $_.FilesFailed -gt 0 })
        $failedWriters | Should -BeNullOrEmpty -Because (
            'all staggered writers must succeed when final content matches; got: {0}' -f (
                ($writerResults | ConvertTo-Json -Compress -Depth 4)
            )
        )

        @($writerResults | Where-Object { $_.Outcome -eq 'Copied' }).Count | Should -Be 1 -Because 'one no-clobber promotion must win'
        @($writerResults | Where-Object { $_.Outcome -eq 'PeerWon' }).Count | Should -Be ($writerCount - 1)
        @($writerResults.WriterToken | Select-Object -Unique).Count | Should -Be $writerCount
        $observedPartialNames.Count | Should -BeGreaterThan 1 -Because 'overlapping writers must own distinct partial paths'
        foreach ($partialName in $observedPartialNames) {
            $partialName | Should -Match ('^' + [regex]::Escape($payloadName) + '\.partial\.[0-9a-f]{16}\.[0-9a-f]{8}$')
        }

        $partials = @(Get-ChildItem -LiteralPath $destinationRoot -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like ($payloadName + '.partial.*') })
        $partials | Should -BeNullOrEmpty -Because 'no writer-owned partials should remain after successful concurrent publish'
    }

    It 'removes only unlocked redundant same-content partials after the final file is verified' {
        $workRoot = Join-Path $TestDrive ('resilient-partial-cleanup-' + [guid]::NewGuid().ToString('N'))
        $sourceRoot = Join-Path $workRoot 'source'
        $destinationRoot = Join-Path $workRoot 'destination'
        $null = New-Item -ItemType Directory -Path $sourceRoot, $destinationRoot -Force
        $sourceFile = Join-Path $sourceRoot 'payload.bin'
        New-ResilientCopyTestPayload -Path $sourceFile -SizeBytes (1024 * 1024)

        $firstOutputs = @(Copy-ResilientDirectoryTree `
            -SourceDirectory $sourceRoot `
            -DestinationDirectory $destinationRoot `
            -ComparisonMode Hash `
            -PartialIdentityMode FullHash `
            -FlushPolicy EndOfCopy `
            -OutputMode Both)
        $firstFileResult = @($firstOutputs | Where-Object { $_.PSObject.Properties['Outcome'] }) | Select-Object -Last 1
        $firstFileResult.Outcome | Should -Be 'Copied'

        $stalePartialPath = $firstFileResult.PartialPath.Substring(0, $firstFileResult.PartialPath.Length - 8) + [guid]::NewGuid().ToString('N').Substring(0, 8)
        [System.IO.File]::Copy($sourceFile, $stalePartialPath)
        $activeStream = [System.IO.FileStream]::new(
            $stalePartialPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::Read
        )
        try {
            $lockedOutputs = @(Copy-ResilientDirectoryTree `
                -SourceDirectory $sourceRoot `
                -DestinationDirectory $destinationRoot `
                -ComparisonMode Hash `
                -PartialIdentityMode FullHash `
                -OutputMode Both)
            $lockedSummary = @($lockedOutputs | Where-Object { $_.PSObject.Properties['OperationSummary'] -and $_.OperationSummary }) | Select-Object -Last 1
            $lockedFileResult = @($lockedOutputs | Where-Object { $_.PSObject.Properties['Outcome'] }) | Select-Object -Last 1
            $lockedSummary.Succeeded | Should -BeTrue
            $lockedFileResult.Outcome | Should -Be 'AlreadyPresent'
            $lockedFileResult.RedundantPartialsSkipped | Should -Be 1
            @($lockedFileResult.RedundantPartialCleanupErrors).Count | Should -Be 1
            $lockedFileResult.RedundantPartialCleanupErrors[0].Path | Should -Be $stalePartialPath
            Test-Path -LiteralPath $stalePartialPath -PathType Leaf | Should -BeTrue -Because 'an active peer still owns its partial'
        }
        finally {
            $activeStream.Dispose()
        }

        $cleanupOutputs = @(Copy-ResilientDirectoryTree `
            -SourceDirectory $sourceRoot `
            -DestinationDirectory $destinationRoot `
            -ComparisonMode Hash `
            -PartialIdentityMode FullHash `
            -OutputMode Both)
        $cleanupSummary = @($cleanupOutputs | Where-Object { $_.PSObject.Properties['OperationSummary'] -and $_.OperationSummary }) | Select-Object -Last 1
        $cleanupFileResult = @($cleanupOutputs | Where-Object { $_.PSObject.Properties['Outcome'] }) | Select-Object -Last 1
        $cleanupSummary.Succeeded | Should -BeTrue
        $cleanupFileResult.Outcome | Should -Be 'AlreadyPresent'
        $cleanupSummary.RedundantPartialsRemoved | Should -Be 1
        $cleanupFileResult.RedundantPartialsSkipped | Should -Be 0
        @($cleanupFileResult.RedundantPartialCleanupErrors).Count | Should -Be 0
        Test-Path -LiteralPath $stalePartialPath | Should -BeFalse
    }

    It 'does not overwrite a verified final when different content writers race' {
        $workRoot = Join-Path $TestDrive ('resilient-conflict-' + [guid]::NewGuid().ToString('N'))
        $sourceRootA = Join-Path $workRoot 'source-a'
        $sourceRootB = Join-Path $workRoot 'source-b'
        $destinationRoot = Join-Path $workRoot 'destination'
        $resultsRoot = Join-Path $workRoot 'results'
        $null = New-Item -ItemType Directory -Path $sourceRootA, $sourceRootB, $destinationRoot, $resultsRoot -Force
        $sourceFileA = Join-Path $sourceRootA 'payload.bin'
        $sourceFileB = Join-Path $sourceRootB 'payload.bin'
        New-ResilientCopyTestPayload -Path $sourceFileA -SizeBytes (6 * 1024 * 1024)
        New-ResilientCopyTestPayload -Path $sourceFileB -SizeBytes (6 * 1024 * 1024)
        $hashA = (Get-FileHash -LiteralPath $sourceFileA -Algorithm SHA256).Hash.ToLowerInvariant()
        $hashB = (Get-FileHash -LiteralPath $sourceFileB -Algorithm SHA256).Hash.ToLowerInvariant()
        $hashA | Should -Not -Be $hashB

        $resilientScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.ResilientDirectoryTree.ps1'
        $writers = @(
            Start-ResilientCopyTestWriter -WriterIndex 0 -SourceRoot $sourceRootA -DestinationRoot $destinationRoot `
                -ResultPath (Join-Path $resultsRoot 'writer-0.json') -ResilientScript $resilientScript `
                -TargetBytesPerSecond (2 * 1024 * 1024) -RetryCount 3
            Start-ResilientCopyTestWriter -WriterIndex 1 -SourceRoot $sourceRootB -DestinationRoot $destinationRoot `
                -ResultPath (Join-Path $resultsRoot 'writer-1.json') -ResilientScript $resilientScript `
                -TargetBytesPerSecond (2 * 1024 * 1024) -RetryCount 3
        )
        Wait-ResilientCopyTestWriters -Writers $writers

        $writerResults = @($writers | ForEach-Object { Get-Content -LiteralPath $_.ResultPath -Raw | ConvertFrom-Json })
        @($writerResults | Where-Object { $_.Succeeded -and $_.FilesFailed -eq 0 }).Count | Should -Be 1
        $losers = @($writerResults | Where-Object { -not $_.Succeeded -or $_.FilesFailed -gt 0 })
        $losers.Count | Should -Be 1
        $losers[0].Error | Should -Match 'promotion failed.*does not match source'

        $destinationHash = (Get-FileHash -LiteralPath (Join-Path $destinationRoot 'payload.bin') -Algorithm SHA256).Hash.ToLowerInvariant()
        (@($hashA, $hashB) -contains $destinationHash) | Should -BeTrue -Because 'the final must be one complete source, never mixed or truncated'

        $conflictPartials = @(Get-ChildItem -LiteralPath $destinationRoot -File |
            Where-Object { $_.Name -like 'payload.bin.partial.*' })
        $conflictPartials.Count | Should -Be 1 -Because 'the losing writer must reuse one stable owned partial across retries'

        $winningSourceRoot = if ($destinationHash -eq $hashA) { $sourceRootA } else { $sourceRootB }
        $winnerRecheck = @(Copy-ResilientDirectoryTree `
            -SourceDirectory $winningSourceRoot `
            -DestinationDirectory $destinationRoot `
            -ComparisonMode Hash `
            -PartialIdentityMode FullHash `
            -OutputMode Both)
        $winnerSummary = @($winnerRecheck | Where-Object { $_.PSObject.Properties['OperationSummary'] -and $_.OperationSummary }) | Select-Object -Last 1
        $winnerSummary.Succeeded | Should -BeTrue
        Test-Path -LiteralPath $conflictPartials[0].FullName -PathType Leaf | Should -BeTrue -Because 'a valid final must not erase a different content identity'
    }

    It 'retries a transiently locked matching final instead of failing during comparison' {
        $workRoot = Join-Path $TestDrive ('resilient-locked-final-' + [guid]::NewGuid().ToString('N'))
        $sourceRoot = Join-Path $workRoot 'source'
        $destinationRoot = Join-Path $workRoot 'destination'
        $resultsRoot = Join-Path $workRoot 'results'
        $null = New-Item -ItemType Directory -Path $sourceRoot, $destinationRoot, $resultsRoot -Force
        $sourceFile = Join-Path $sourceRoot 'payload.bin'
        $destinationFile = Join-Path $destinationRoot 'payload.bin'
        New-ResilientCopyTestPayload -Path $sourceFile -SizeBytes (1024 * 1024)
        [System.IO.File]::Copy($sourceFile, $destinationFile)

        $lockedStream = [System.IO.FileStream]::new(
            $destinationFile,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::None
        )
        try {
            $resilientScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.ResilientDirectoryTree.ps1'
            $writer = Start-ResilientCopyTestWriter `
                -WriterIndex 0 `
                -SourceRoot $sourceRoot `
                -DestinationRoot $destinationRoot `
                -ResultPath (Join-Path $resultsRoot 'writer-0.json') `
                -ResilientScript $resilientScript `
                -RetryCount 6
            Start-Sleep -Milliseconds 2500
        }
        finally {
            $lockedStream.Dispose()
        }

        Wait-ResilientCopyTestWriters -Writers @($writer)
        $result = Get-Content -LiteralPath $writer.ResultPath -Raw | ConvertFrom-Json
        $result.Succeeded | Should -BeTrue
        $result.FilesFailed | Should -Be 0
        $result.Outcome | Should -Be 'AlreadyPresent'
        $result.FilesComparisonDeferred | Should -Be 1
        $result.Retries | Should -BeGreaterThan 0
        (Get-FileHash -LiteralPath $destinationFile -Algorithm SHA256).Hash | Should -Be (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash
    }

    It 'reports actual and expected lengths when a stale final blocks promotion' {
        $workRoot = Join-Path $TestDrive ('resilient-stale-final-' + [guid]::NewGuid().ToString('N'))
        $sourceRoot = Join-Path $workRoot 'source'
        $destinationRoot = Join-Path $workRoot 'destination'
        $null = New-Item -ItemType Directory -Path $sourceRoot, $destinationRoot -Force

        $sourceFile = Join-Path $sourceRoot 'payload.bin'
        $destinationFile = Join-Path $destinationRoot 'payload.bin'
        New-ResilientCopyTestPayload -Path $sourceFile -SizeBytes (1024 * 1024)
        [System.IO.File]::WriteAllBytes($destinationFile, (New-Object byte[] 64))

        {
            Copy-ResilientDirectoryTree -SourceDirectory $sourceRoot -DestinationDirectory $destinationRoot -ComparisonMode Length -RetryCount 1 -WaitSeconds 0 -FailFast
        } | Should -Throw "*existing final length '64' bytes differs from source length '1048576' bytes; SHA-256 was not computed*File.Move error*Destination: '$destinationFile'*"
    }

    It 'reports computed non-empty SHA values when an equal-length final differs' {
        $workRoot = Join-Path $TestDrive ('resilient-equal-length-final-' + [guid]::NewGuid().ToString('N'))
        $sourceRoot = Join-Path $workRoot 'source'
        $destinationRoot = Join-Path $workRoot 'destination'
        $null = New-Item -ItemType Directory -Path $sourceRoot, $destinationRoot -Force

        $sourceFile = Join-Path $sourceRoot 'payload.bin'
        $destinationFile = Join-Path $destinationRoot 'payload.bin'
        [System.IO.File]::WriteAllBytes($sourceFile, [byte[]](1..64))
        [System.IO.File]::WriteAllBytes($destinationFile, [byte[]](65..128))
        $sourceHash = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash.ToLowerInvariant()
        $destinationHash = (Get-FileHash -LiteralPath $destinationFile -Algorithm SHA256).Hash.ToLowerInvariant()
        $sourceHash | Should -Not -Be $destinationHash

        {
            Copy-ResilientDirectoryTree -SourceDirectory $sourceRoot -DestinationDirectory $destinationRoot -SkipIfUnchanged:$false -RetryCount 1 -WaitSeconds 0 -FailFast
        } | Should -Throw "*existing final SHA-256 '$destinationHash' does not match source '$sourceHash' at equal length '64' bytes*"
    }
}
