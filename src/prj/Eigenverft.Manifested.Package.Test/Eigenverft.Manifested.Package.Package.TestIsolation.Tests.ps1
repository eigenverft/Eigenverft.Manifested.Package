<#
    Eigenverft.Manifested.Package Package - test isolation
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - test isolation' -Body {

    It "keeps test package documents in Pester's isolated local endpoint inventory" {
        $rootPath = Join-Path $TestDrive 'test-package-document-isolation'
        $bootstrapEndpointInventoryPath = Get-PackageLocalEndpointInventoryPath

        $bootstrapEndpointInventoryPath | Should -BeLike "$TestDrive*"
        Test-Path -LiteralPath $bootstrapEndpointInventoryPath -PathType Leaf | Should -BeFalse

        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @(
                New-TestPackageRelease -Id 'isolation-win-x64-stable' -Version '1.0.0' -Architecture 'x64'
        ))

        Test-Path -LiteralPath $documents.EndpointInventoryPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapEndpointInventoryPath -PathType Leaf | Should -BeTrue
    }

    It 'runs every test file in a fresh process so process state cannot leak between files' {
        $probeRoot = Join-Path $TestDrive 'per-file-isolation-probe'
        $null = New-Item -ItemType Directory -Path $probeRoot -Force
        $producerPath = Join-Path $probeRoot '01-StateProducer.Tests.ps1'
        $consumerPath = Join-Path $probeRoot '02-StateConsumer.Tests.ps1'
        $runnerPath = Join-Path $PSScriptRoot 'Invoke-ModuleTests.ps1'
        $logPath = Join-Path $TestDrive 'per-file-isolation-probe.log'

        @'
Describe 'state producer' {
    It 'sets process-global state' {
        $global:EvfTestIsolationSentinel = 'producer-state'
        $global:EvfTestIsolationSentinel | Should -Be 'producer-state'
    }
}
'@ | Set-Content -LiteralPath $producerPath -Encoding UTF8

        @'
Describe 'state consumer' {
    It 'starts without producer state' {
        Get-Variable -Name EvfTestIsolationSentinel -Scope Global -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }
}
'@ | Set-Content -LiteralPath $consumerPath -Encoding UTF8

        $powerShellExecutable = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $output = @(
            & $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $runnerPath `
                -Path $probeRoot -IsolationMode PerFile -Mode Quiet -LogPath $logPath 2>&1
        )

        $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
        ($output -join [Environment]::NewLine) | Should -Match 'Pester per-file: Passed=2 Failed=0 Skipped=0 Files=2'
    }

    It 'reports a test file that relies on process state produced by another file' {
        $probeRoot = Join-Path $TestDrive 'per-file-dependency-probe'
        $null = New-Item -ItemType Directory -Path $probeRoot -Force
        $producerPath = Join-Path $probeRoot '01-StateProducer.Tests.ps1'
        $dependentPath = Join-Path $probeRoot '02-DependentConsumer.Tests.ps1'
        $runnerPath = Join-Path $PSScriptRoot 'Invoke-ModuleTests.ps1'
        $logPath = Join-Path $TestDrive 'per-file-dependency-probe.log'

        @'
Describe 'state producer' {
    It 'sets process-global state' {
        $global:EvfTestIsolationSentinel = 'producer-state'
        $global:EvfTestIsolationSentinel | Should -Be 'producer-state'
    }
}
'@ | Set-Content -LiteralPath $producerPath -Encoding UTF8

        @'
Describe 'dependent consumer' {
    It 'incorrectly expects producer state' {
        $global:EvfTestIsolationSentinel | Should -Be 'producer-state'
    }
}
'@ | Set-Content -LiteralPath $dependentPath -Encoding UTF8

        $powerShellExecutable = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $output = @(
            & $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $runnerPath `
                -Path $probeRoot -IsolationMode PerFile -Mode Quiet -LogPath $logPath 2>&1
        )

        $LASTEXITCODE | Should -Be 1 -Because 'a test file with an undeclared dependency must fail in its clean process'
        ($output -join [Environment]::NewLine) | Should -Match 'Pester per-file: Passed=1 Failed=1 Skipped=0 Files=2'
        ($output -join [Environment]::NewLine) | Should -Match '02-DependentConsumer\.Tests\.ps1'
    }

    It 'rejects a Tests file that discovers no tests' {
        $probeRoot = Join-Path $TestDrive 'zero-test-discovery-probe'
        $null = New-Item -ItemType Directory -Path $probeRoot -Force
        $emptyTestPath = Join-Path $probeRoot 'Empty.Tests.ps1'
        $runnerPath = Join-Path $PSScriptRoot 'Invoke-ModuleTests.ps1'
        $logPath = Join-Path $TestDrive 'zero-test-discovery-probe.log'

        '<# This file intentionally contains no Pester tests. #>' |
            Set-Content -LiteralPath $emptyTestPath -Encoding UTF8

        $powerShellExecutable = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $powerShellExecutable
        $startInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Path "{1}" -IsolationMode PerFile -Mode Quiet -LogPath "{2}"' -f `
            $runnerPath, $probeRoot, $logPath
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        try {
            $null = $process.Start()
            $standardOutput = $process.StandardOutput.ReadToEnd()
            $standardError = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            $exitCode = $process.ExitCode
        }
        finally {
            $process.Dispose()
        }
        $outputText = @($standardOutput, $standardError) -join [Environment]::NewLine

        $exitCode | Should -Be 1 -Because 'a *.Tests.ps1 placeholder must not be reported as a successful test file'
        $outputText | Should -Match 'Empty\.Tests\.ps1: <test discovery>: The isolated file discovered zero tests\.'
    }
}
