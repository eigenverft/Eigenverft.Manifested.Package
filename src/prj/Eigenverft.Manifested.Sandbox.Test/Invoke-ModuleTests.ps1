<#
    Runs the module Pester suite with low-noise output by default.

    The package commands write operator messages directly, so plain
    Invoke-Pester -Output None is still noisy. This wrapper runs Pester in
    a clean child PowerShell process, redirects all output to a log, and
    prints only the counts we need during normal iteration.
#>

[CmdletBinding()]
param(
    [string]$Path,

    [string[]]$FullName,

    [ValidateSet('Quiet', 'Detailed')]
    [string]$Mode = 'Quiet',

    [string]$LogPath
)

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = $PSScriptRoot
}

$resolvedTestPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path

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
    Passed      = $result.PassedCount
    Failed      = $result.FailedCount
    Skipped     = $result.SkippedCount
    Duration    = $result.Duration.ToString()
    Path        = $TestPath
    FullName    = @($fullNames)
    FailedTests = $failedTests
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $SummaryPath -Encoding UTF8

if ($result.FailedCount -gt 0) {
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

try {
    & $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $runnerPath -TestPath $resolvedTestPath -OutputMode $outputMode -FullNameJson $fullNameJson -SummaryPath $summaryPath *> $resolvedLogPath
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

$scopeText = if ($FullName -and $FullName.Count -gt 0) {
    'targeted'
}
else {
    'full'
}

'Pester {0}: Passed={1} Failed={2} Skipped={3} Duration={4}' -f $scopeText, $summary.Passed, $summary.Failed, $summary.Skipped, $summary.Duration
'Pester log: {0}' -f $resolvedLogPath

if ([int]$summary.Failed -gt 0) {
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
    exit 1
}

