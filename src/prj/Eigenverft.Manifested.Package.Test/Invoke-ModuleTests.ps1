<#
    Runs the module Pester suite with low-noise output by default.

    The package commands write operator messages directly, so plain
    Invoke-Pester -Output None is still noisy. This wrapper runs Pester in
    a clean child PowerShell process, redirects all output to a log, and
    prints only the counts we need during normal iteration. Use
    -IsolationMode PerFile to prove that every test file discovers and passes
    in its own process without setup or state inherited from another file.
#>

[CmdletBinding()]
param(
    [string]$Path,

    [string[]]$FullName,

    [ValidateSet('Quiet', 'Detailed')]
    [string]$Mode = 'Quiet',

    [ValidateSet('Suite', 'PerFile')]
    [string]$IsolationMode = 'Suite',

    [string]$LogPath
)

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = $PSScriptRoot
}

$resolvedTestPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path

if ($IsolationMode -eq 'PerFile' -and $FullName -and $FullName.Count -gt 0) {
    throw '-FullName cannot be combined with -IsolationMode PerFile because a name filter need not match every test file.'
}

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $logFileName = 'evf-pester-{0}.log' -f ([guid]::NewGuid().ToString('N'))
    $LogPath = Join-Path $env:TEMP $logFileName
}

$resolvedLogPath = [System.IO.Path]::GetFullPath($LogPath)
$logDirectory = Split-Path -Parent $resolvedLogPath
if (-not [string]::IsNullOrWhiteSpace($logDirectory)) {
    $null = New-Item -ItemType Directory -Path $logDirectory -Force
}

$summaryPath = [System.IO.Path]::ChangeExtension($resolvedLogPath, '.summary.json')
Remove-Item -LiteralPath $summaryPath -Force -ErrorAction SilentlyContinue

$runnerPath = Join-Path $env:TEMP ('evf-pester-runner-{0}.ps1' -f ([guid]::NewGuid().ToString('N')))
$runnerContent = @'
param(
    [Parameter(Mandatory = $true)]
    [string]$TestPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputMode,

    [Parameter(Mandatory = $true)]
    [string]$FullNameJson,

    [Parameter(Mandatory = $true)]
    [string]$SummaryPath
)

$ErrorActionPreference = 'Stop'

$fullNames = @()
if (-not [string]::IsNullOrWhiteSpace($FullNameJson)) {
    $fullNames = @(ConvertFrom-Json -InputObject $FullNameJson)
}

$invokePesterParameters = @{
    Path     = $TestPath
    PassThru = $true
    Output   = $OutputMode
}

if ($fullNames.Count -gt 0) {
    $invokePesterParameters['FullName'] = $fullNames
}

$result = Invoke-Pester @invokePesterParameters

$totalCount = if ($result.PSObject.Properties['TotalCount']) {
    [int]$result.TotalCount
}
else {
    [int]$result.PassedCount + [int]$result.FailedCount + [int]$result.SkippedCount
}

$failedTests = @()
if ($result.PSObject.Properties['Failed']) {
    $failedTests = @(
        foreach ($failedTest in @($result.Failed)) {
            $name = if ($failedTest.PSObject.Properties['ExpandedName']) {
                [string]$failedTest.ExpandedName
            }
            elseif ($failedTest.PSObject.Properties['Name']) {
                [string]$failedTest.Name
            }
            else {
                '<unknown>'
            }

            $message = if ($failedTest.PSObject.Properties['ErrorRecord'] -and $failedTest.ErrorRecord) {
                [string]$failedTest.ErrorRecord.Exception.Message
            }
            else {
                ''
            }

            [pscustomobject]@{
                Name    = $name
                Message = $message
            }
        }
    )
}

[pscustomobject]@{
    Total       = $totalCount
    Passed      = $result.PassedCount
    Failed      = $result.FailedCount
    Skipped     = $result.SkippedCount
    Duration    = $result.Duration.ToString()
    Path        = $TestPath
    FullName    = @($fullNames)
    FailedTests = $failedTests
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $SummaryPath -Encoding UTF8

if ($result.FailedCount -gt 0 -or $totalCount -le 0) {
    exit 1
}

exit 0
'@

Set-Content -LiteralPath $runnerPath -Value $runnerContent -Encoding UTF8

$powerShellExecutable = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$outputMode = if ($Mode -eq 'Detailed') { 'Detailed' } else { 'None' }
$fullNameJson = if ($FullName -and $FullName.Count -gt 0) {
    ConvertTo-Json -InputObject @($FullName) -Compress
}
else {
    '[]'
}

if ($IsolationMode -eq 'PerFile') {
    $testFiles = @(
        if (Test-Path -LiteralPath $resolvedTestPath -PathType Leaf) {
            Get-Item -LiteralPath $resolvedTestPath
        }
        else {
            Get-ChildItem -LiteralPath $resolvedTestPath -Filter '*.Tests.ps1' -File | Sort-Object Name
        }
    )

    if ($testFiles.Count -eq 0) {
        throw "No *.Tests.ps1 files were found under '$resolvedTestPath'."
    }

    # A normal suite run intentionally shares one host and can therefore reveal a
    # leak by failing a later file. This mode supplies the complementary proof:
    # every file must also discover and pass without state or setup from any peer.
    Set-Content -LiteralPath $resolvedLogPath -Value '' -Encoding UTF8
    $startedAt = [datetime]::UtcNow
    $passedCount = 0
    $failedCount = 0
    $skippedCount = 0
    $failedFiles = [System.Collections.Generic.List[object]]::new()

    for ($index = 0; $index -lt $testFiles.Count; $index++) {
        $testFile = $testFiles[$index]
        $fileToken = '{0:D3}-{1}' -f ($index + 1), ([System.IO.Path]::GetFileNameWithoutExtension($testFile.Name) -replace '[^A-Za-z0-9_.-]', '_')
        $fileLogPath = '{0}.{1}.tmp.log' -f $resolvedLogPath, $fileToken
        $fileSummaryPath = '{0}.{1}.tmp.json' -f $summaryPath, $fileToken
        Remove-Item -LiteralPath $fileLogPath, $fileSummaryPath -Force -ErrorAction SilentlyContinue

        $previousErrorActionPreference = $ErrorActionPreference
        try {
            # A failing Pester child can write ErrorRecord objects to stderr. They
            # belong in the captured log and must not terminate this orchestrator
            # before it can read and report the structured summary.
            $ErrorActionPreference = 'Continue'
            & $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $runnerPath `
                -TestPath $testFile.FullName `
                -OutputMode $outputMode `
                -FullNameJson '[]' `
                -SummaryPath $fileSummaryPath *> $fileLogPath
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        Add-Content -LiteralPath $resolvedLogPath -Value ('===== {0} =====' -f $testFile.FullName) -Encoding UTF8
        if (Test-Path -LiteralPath $fileLogPath -PathType Leaf) {
            Get-Content -LiteralPath $fileLogPath | Add-Content -LiteralPath $resolvedLogPath -Encoding UTF8
        }

        if (-not (Test-Path -LiteralPath $fileSummaryPath -PathType Leaf)) {
            $failedCount++
            $failedFiles.Add([pscustomobject]@{
                    File    = $testFile.Name
                    Name    = '<test process>'
                    Message = 'The isolated Pester process did not produce a summary.'
                }) | Out-Null
            Remove-Item -LiteralPath $fileLogPath -Force -ErrorAction SilentlyContinue
            continue
        }

        $fileSummary = Get-Content -LiteralPath $fileSummaryPath -Raw | ConvertFrom-Json
        Remove-Item -LiteralPath $fileSummaryPath, $fileLogPath -Force -ErrorAction SilentlyContinue

        $passedCount += [int]$fileSummary.Passed
        $failedCount += [int]$fileSummary.Failed
        $skippedCount += [int]$fileSummary.Skipped

        if ([int]$fileSummary.Total -le 0) {
            $failedCount++
            $failedFiles.Add([pscustomobject]@{
                    File    = $testFile.Name
                    Name    = '<test discovery>'
                    Message = 'The isolated file discovered zero tests.'
                }) | Out-Null
        }

        foreach ($failedTest in @($fileSummary.FailedTests)) {
            $failedFiles.Add([pscustomobject]@{
                    File    = $testFile.Name
                    Name    = [string]$failedTest.Name
                    Message = [string]$failedTest.Message
                }) | Out-Null
        }
    }

    $duration = ([datetime]::UtcNow - $startedAt).ToString()
    'Pester per-file: Passed={0} Failed={1} Skipped={2} Files={3} Duration={4}' -f `
        $passedCount, $failedCount, $skippedCount, $testFiles.Count, $duration

    if ($failedCount -gt 0) {
        'Pester log: {0}' -f $resolvedLogPath
        'Failed isolated files:'
        foreach ($failure in @($failedFiles | Select-Object -First 10)) {
            if ([string]::IsNullOrWhiteSpace([string]$failure.Message)) {
                '  - {0}: {1}' -f $failure.File, $failure.Name
            }
            else {
                '  - {0}: {1}: {2}' -f $failure.File, $failure.Name, $failure.Message
            }
        }
        if ($failedFiles.Count -gt 10) {
            '  ... {0} more failure(s), see log.' -f ($failedFiles.Count - 10)
        }
        exit 1
    }

    exit 0
}

try {
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $runnerPath -TestPath $resolvedTestPath -OutputMode $outputMode -FullNameJson $fullNameJson -SummaryPath $summaryPath *> $resolvedLogPath
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}
finally {
    Remove-Item -LiteralPath $runnerPath -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path -LiteralPath $summaryPath -PathType Leaf)) {
    'Pester run did not produce a summary. Log: {0}' -f $resolvedLogPath
    exit 1
}

$summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
Remove-Item -LiteralPath $summaryPath -Force -ErrorAction SilentlyContinue

$defaultTestPath = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$scopeText = if (($FullName -and $FullName.Count -gt 0) -or -not [string]::Equals($resolvedTestPath, $defaultTestPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    'targeted'
}
else {
    'full'
}

'Pester {0}: Passed={1} Failed={2} Skipped={3} Duration={4}' -f $scopeText, $summary.Passed, $summary.Failed, $summary.Skipped, $summary.Duration

if ([int]$summary.Failed -gt 0 -or [int]$summary.Total -le 0) {
    'Pester log: {0}' -f $resolvedLogPath
    if ([int]$summary.Total -le 0) {
        'Pester discovered zero tests; the run is invalid.'
    }
    if ($Mode -eq 'Detailed') {
        $failedTests = @($summary.FailedTests)
        if ($failedTests.Count -gt 0) {
            'Failed tests:'
            foreach ($failedTest in @($failedTests | Select-Object -First 10)) {
                if ([string]::IsNullOrWhiteSpace([string]$failedTest.Message)) {
                    '  - {0}' -f $failedTest.Name
                }
                else {
                    '  - {0}: {1}' -f $failedTest.Name, $failedTest.Message
                }
            }
            if ($failedTests.Count -gt 10) {
                '  ... {0} more failure(s), see log.' -f ($failedTests.Count - 10)
            }
        }
    }
    exit 1
}

