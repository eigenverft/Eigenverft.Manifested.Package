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
