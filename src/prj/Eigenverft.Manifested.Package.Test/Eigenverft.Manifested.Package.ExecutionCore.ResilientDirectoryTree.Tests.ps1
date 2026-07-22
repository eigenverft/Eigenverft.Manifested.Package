. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Copy-ResilientDirectoryTree large-file arithmetic' -Body {

    It 'calculates remaining bytes above the Int32 limit without overflow' {
        $totalBytes = 7457252576L
        $processedBytes = 1048576L

        $remainingBytes = Get-ResilientCopyRemainingBytes `
            -TotalBytes $totalBytes `
            -ProcessedBytes $processedBytes

        $remainingBytes.GetType().FullName | Should -Be 'System.Int64'
        $remainingBytes | Should -Be 7456204000L
        (Get-ResilientCopyRemainingBytes -TotalBytes 10L -ProcessedBytes 11L) | Should -Be 0L
    }
}

Invoke-TestPackageDescribe -Name 'Copy-ResilientDirectoryTree progress formatting' -Body {

    It 'formats adaptive IEC byte rates at unit boundaries' {
        (Format-ResilientCopyByteRate -BytesPerSecond 0) | Should -Be '0 B/s'
        (Format-ResilientCopyByteRate -BytesPerSecond 1023) | Should -Be '1023 B/s'
        (Format-ResilientCopyByteRate -BytesPerSecond 1024) | Should -Be '1.00 KiB/s'
        (Format-ResilientCopyByteRate -BytesPerSecond (1024L * 1024L)) | Should -Be '1.00 MiB/s'
        (Format-ResilientCopyByteRate -BytesPerSecond (1024L * 1024L * 1024L)) | Should -Be '1.00 GiB/s'
        (Format-ResilientCopyByteRate -BytesPerSecond 32167296) | Should -Be '30.68 MiB/s'
    }

    It 'formats operation status without composite placeholders and uses pending wording' {
        $status = Format-ResilientCopyOperationProgressStatus `
            -Phase 'Copy' `
            -FilesDiscovered 1 `
            -FilesSelected 1 `
            -FilesCopied 0 `
            -FilesFailed 0 `
            -DirectoriesPreflighted 1 `
            -RemovedCount 0 `
            -PendingCount 0 `
            -PendingBytes 0

        $status | Should -Be 'Phase: Copy | files discovered 1; selected 1; copied 0; failed 0; preflighted 1; removed 0; pending 0 (0 B)'
        $status | Should -Not -Match '\{[0-9]'
        $status | Should -Not -Match 'queued'
    }

    It 'places all status arguments in the expected positions' {
        $status = Format-ResilientCopyOperationProgressStatus `
            -Phase 'Preflight' `
            -FilesDiscovered 11 `
            -FilesSelected 22 `
            -FilesCopied 33 `
            -FilesFailed 44 `
            -DirectoriesPreflighted 55 `
            -RemovedCount 66 `
            -PendingCount 77 `
            -PendingBytes 2048

        $status | Should -Match '^Phase: Preflight \|'
        $status | Should -Match 'files discovered 11;'
        $status | Should -Match 'selected 22;'
        $status | Should -Match 'copied 33;'
        $status | Should -Match 'failed 44;'
        $status | Should -Match 'preflighted 55;'
        $status | Should -Match 'removed 66;'
        $status | Should -Match 'pending 77 \(2\.00 KiB\)$'
    }

    It 'keeps structured numeric result properties as raw byte values during a one-file copy' {
        $root = Join-Path $TestDrive 'resilient-progress-semantics'
        $source = Join-Path $root 'source'
        $destination = Join-Path $root 'destination'
        New-Item -ItemType Directory -Path $source | Out-Null
        New-Item -ItemType Directory -Path $destination | Out-Null

        $payload = New-Object byte[] (2 * 1024 * 1024)
        (New-Object Random 19).NextBytes($payload)
        [System.IO.File]::WriteAllBytes((Join-Path $source 'payload.bin'), $payload)

        $progressSnapshots = [System.Collections.Generic.List[object]]::new()
        $outputs = @(Copy-ResilientDirectoryTree `
            -SourceDirectory $source `
            -DestinationDirectory $destination `
            -ChunkSizeBytes (64 * 1024) `
            -ProgressIntervalMilliseconds 50 `
            -WorkQueueOrderPolicy SmallestFirst `
            -OutputMode Both `
            -ProgressCallback {
                param($progress)
                if ($progress.OperationProgress -and $progress.Phase -eq 'Copy' -and $progress.CurrentFilePath) {
                    $progressSnapshots.Add($progress)
                }
            })

        $summary = @($outputs | Where-Object { $_.OperationSummary })[0]
        $fileResult = @($outputs | Where-Object {
                $_.PSObject.Properties['AverageBytesPerSecond'] -and
                $_.PSObject.Properties['Outcome'] -and
                -not $_.OperationSummary
            })[0]

        $summary | Should -Not -BeNullOrEmpty
        $fileResult | Should -Not -BeNullOrEmpty
        ($fileResult.AverageBytesPerSecond -is [string]) | Should -BeFalse
        $fileResult.AverageBytesPerSecond | Should -BeGreaterThan 0

        $copyWhileActive = @($progressSnapshots | Where-Object {
                $_.FilesSelected -ge 1 -and $_.FilesCopied -eq 0 -and $_.QueueSize -eq 0
            })
        $copyWhileActive.Count | Should -BeGreaterThan 0
        $copyWhileActive[0].QueueBytes | Should -Be 0
        ($copyWhileActive[0].QueueBytes -is [string]) | Should -BeFalse
        $copyWhileActive[0].CurrentFilePath | Should -Be (Join-Path $source 'payload.bin')
        $copyWhileActive[0].CurrentOperation | Should -Match '^Copying '

        $detailedLine = @($outputs | Where-Object { $_ -is [string] -and $_ -match 'MiB/s|KiB/s|GiB/s|B/s' })[0]
        $detailedLine | Should -Not -BeNullOrEmpty
        $detailedLine | Should -Match 'attempt \d+; \d+(\.\d+)? (B|KiB|MiB|GiB)/s; elapsed'
    }
}
