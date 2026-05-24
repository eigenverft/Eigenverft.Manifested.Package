<#
    Runs PSScriptAnalyzer against all .ps1 files in the main module project
    using the shared workspace analyzer settings when available and writes
    a JSON summary to stdout.
#>

[CmdletBinding()]
param(
    [string]$ModuleProjectRoot,

    [string]$SettingsPath,

    [ValidateSet('Error', 'Warning', 'Information')]
    [string[]]$Severity
)

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ModuleProjectRoot)) {
    $ModuleProjectRoot = Join-Path $PSScriptRoot '..\Eigenverft.Manifested.Sandbox'
}

$resolvedModuleProjectRoot = (Resolve-Path -LiteralPath $ModuleProjectRoot -ErrorAction Stop).Path
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..') -ErrorAction Stop).Path

function Get-RelativePathSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolvedBasePath = [System.IO.Path]::GetFullPath($BasePath)
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)

    if (-not $resolvedBasePath.EndsWith('\')) {
        $resolvedBasePath = $resolvedBasePath + '\'
    }

    $baseUri = New-Object System.Uri($resolvedBasePath)
    $pathUri = New-Object System.Uri($resolvedPath)
    $relativeUri = $baseUri.MakeRelativeUri($pathUri)

    return ([System.Uri]::UnescapeDataString($relativeUri.ToString())).Replace('/', '\')
}

function Get-PathFromRepositoryRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string]$CandidatePath
    )

    $pathToResolve = $CandidatePath
    if (-not [System.IO.Path]::IsPathRooted($CandidatePath)) {
        $pathToResolve = Join-Path $RepositoryRoot $CandidatePath
    }

    return [System.IO.Path]::GetFullPath($pathToResolve)
}

function Resolve-AnalyzerSettingsInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [string]$RequestedSettingsPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedSettingsPath)) {
        $requestedSettingsFullPath = Get-PathFromRepositoryRoot -RepositoryRoot $RepositoryRoot -CandidatePath $RequestedSettingsPath

        if (Test-Path -LiteralPath $requestedSettingsFullPath -PathType Leaf) {
            return [ordered]@{
                Path          = (Resolve-Path -LiteralPath $requestedSettingsFullPath -ErrorAction Stop).Path
                Source        = 'Parameter'
                RequestedPath = $requestedSettingsFullPath
            }
        }

        return [ordered]@{
            Path          = $null
            Source        = 'ParameterMissing'
            RequestedPath = $requestedSettingsFullPath
        }
    }

    $defaultSettingsPath = Join-Path $RepositoryRoot '.vscode\PSScriptAnalyzerSettings.psd1'
    if (Test-Path -LiteralPath $defaultSettingsPath -PathType Leaf) {
        return [ordered]@{
            Path          = (Resolve-Path -LiteralPath $defaultSettingsPath -ErrorAction Stop).Path
            Source        = 'RepositoryDefault'
            RequestedPath = $defaultSettingsPath
        }
    }

    return [ordered]@{
        Path          = $null
        Source        = 'None'
        RequestedPath = $null
    }
}

function New-AnalyzerJsonResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [AllowNull()]
        [object]$SettingsPath,

        [AllowNull()]
        [object]$SettingsRequestedPath,

        [string]$SettingsSource = 'None',

        [string[]]$EffectiveSeverity = @(),

        [int]$ScannedFileCount = 0,

        [object[]]$Files = @()
    )

    $affectedFiles = @($Files | Where-Object { $_.IssueCount -gt 0 })
    $issues = @(
        foreach ($file in $affectedFiles) {
            @($file.Issues)
        }
    )
    $severitySummary = [ordered]@{}
    foreach ($level in @('Error', 'Warning', 'Information')) {
        $levelCount = @($issues | Where-Object { $_.Severity -eq $level }).Count
        if ($levelCount -gt 0) {
            $severitySummary[$level] = $levelCount
        }
    }

    $ruleSummary = [ordered]@{}
    foreach ($group in @(
        $issues |
            Group-Object { $_.RuleName } |
            Sort-Object -Property @(
                @{ Expression = 'Count'; Descending = $true },
                @{ Expression = 'Name'; Descending = $false }
            )
    )) {
        if ($group.Count -gt 0) {
            $ruleSummary[$group.Name] = $group.Count
        }
    }

    $result = [ordered]@{
        Status            = $Status
        ExitCode          = $ExitCode
        RepositoryRoot    = $repositoryRoot
        ModuleProjectRoot = $resolvedModuleProjectRoot
        SettingsPath      = $SettingsPath
        SettingsSource    = $SettingsSource
        Severity          = @($EffectiveSeverity)
        ScannedFileCount  = $ScannedFileCount
        AffectedFileCount = @($affectedFiles).Count
        IssueCount        = @($issues).Count
        Message           = $Message
    }

    if ($SettingsRequestedPath -and $SettingsRequestedPath -ne $SettingsPath) {
        $result['SettingsRequestedPath'] = $SettingsRequestedPath
    }

    if ($severitySummary.Count -gt 0 -or $ruleSummary.Count -gt 0) {
        $result['Summary'] = [ordered]@{}

        if ($severitySummary.Count -gt 0) {
            $result['Summary']['IssueCountBySeverity'] = $severitySummary
        }

        if ($ruleSummary.Count -gt 0) {
            $result['Summary']['IssueCountByRule'] = $ruleSummary
        }
    }

    if (@($affectedFiles).Count -gt 0) {
        $result['Files'] = @(
            $affectedFiles |
                Sort-Object -Property @(
                    @{ Expression = { [int]$_['IssueCount'] }; Descending = $true },
                    @{ Expression = { [string]$_['RelativePath'] }; Descending = $false }
                )
        )
    }

    return $result
}

$moduleScriptFiles = @(
    Get-ChildItem -Path $resolvedModuleProjectRoot -Recurse -File -Filter '*.ps1' |
        Sort-Object FullName
)

try {
    $settingsInfo = Resolve-AnalyzerSettingsInfo -RepositoryRoot $repositoryRoot -RequestedSettingsPath $SettingsPath
    $settingsResolutionWarning = $null
}
catch {
    $settingsInfo = [ordered]@{
        Path          = $null
        Source        = 'ResolutionFailed'
        RequestedPath = $SettingsPath
    }
    $settingsResolutionWarning = "Unable to resolve the shared analyzer settings path. $($_.Exception.Message)"
}

$resolvedSettingsPath = $settingsInfo.Path
$requestedSettingsPath = $settingsInfo.RequestedPath
$settingsSource = [string]$settingsInfo.Source
$effectiveSeverity = @('Error', 'Warning')

if (-not [string]::IsNullOrWhiteSpace($resolvedSettingsPath)) {
    try {
        $settingsData = Import-PowerShellDataFile -LiteralPath $resolvedSettingsPath -ErrorAction Stop
    }
    catch {
        $result = New-AnalyzerJsonResult `
            -Status 'InvalidSettings' `
        -ExitCode 1 `
        -Message "Unable to read analyzer settings from '$resolvedSettingsPath'. $($_.Exception.Message)" `
        -SettingsPath $resolvedSettingsPath `
        -SettingsRequestedPath $requestedSettingsPath `
        -SettingsSource $settingsSource `
        -EffectiveSeverity @() `
        -ScannedFileCount $moduleScriptFiles.Count

        $result | ConvertTo-Json -Depth 8
        return
    }

    if ($settingsData.ContainsKey('Severity') -and $settingsData.Severity) {
        $effectiveSeverity = @($settingsData.Severity | ForEach-Object { [string]$_ })
    }
}

if ($PSBoundParameters.ContainsKey('Severity')) {
    $effectiveSeverity = @($Severity)
}

try {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
}
catch {
    $result = New-AnalyzerJsonResult `
        -Status 'MissingDependency' `
        -ExitCode 1 `
        -Message 'PSScriptAnalyzer is required to analyze module project scripts. Install it first, then rerun this script.' `
        -SettingsPath $resolvedSettingsPath `
        -SettingsRequestedPath $requestedSettingsPath `
        -SettingsSource $settingsSource `
        -EffectiveSeverity $effectiveSeverity `
        -ScannedFileCount $moduleScriptFiles.Count

    $result | ConvertTo-Json -Depth 8
    return
}

if ($moduleScriptFiles.Count -eq 0) {
    $result = New-AnalyzerJsonResult `
        -Status 'NoFiles' `
        -ExitCode 0 `
        -Message "No .ps1 files were found under '$resolvedModuleProjectRoot'." `
        -SettingsPath $resolvedSettingsPath `
        -SettingsRequestedPath $requestedSettingsPath `
        -SettingsSource $settingsSource `
        -EffectiveSeverity $effectiveSeverity `
        -ScannedFileCount $moduleScriptFiles.Count

    $result | ConvertTo-Json -Depth 8
    return
}

$affectedFiles = @()

foreach ($moduleScriptFile in $moduleScriptFiles) {
    $relativePath = Get-RelativePathSafe -BasePath $resolvedModuleProjectRoot -Path $moduleScriptFile.FullName
    $invokeScriptAnalyzerParameters = @{
        Path        = $moduleScriptFile.FullName
        ErrorAction = 'Stop'
    }

    if (-not [string]::IsNullOrWhiteSpace($resolvedSettingsPath)) {
        $invokeScriptAnalyzerParameters['Settings'] = $resolvedSettingsPath
    }

    if ($PSBoundParameters.ContainsKey('Severity') -or [string]::IsNullOrWhiteSpace($resolvedSettingsPath)) {
        $invokeScriptAnalyzerParameters['Severity'] = $effectiveSeverity
    }

    $fileResults = @(Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters)

    if ($fileResults.Count -gt 0) {
        $issuesForFile = @(
            foreach ($fileResult in $fileResults) {
                [ordered]@{
                    Line     = if ($fileResult.PSObject.Properties['Line']) { [int]$fileResult.Line } else { $null }
                    Column   = if ($fileResult.PSObject.Properties['Column']) { [int]$fileResult.Column } else { $null }
                    Severity = [string]$fileResult.Severity
                    RuleName = [string]$fileResult.RuleName
                    Message  = [string]$fileResult.Message
                }
            }
        ) | Sort-Object Line, Column, RuleName, Message

        $affectedFiles += [ordered]@{
            RelativePath = $relativePath
            FullName     = $moduleScriptFile.FullName
            IssueCount   = $fileResults.Count
            Issues       = @($issuesForFile)
        }
    }
}

$issueCount = @(
    foreach ($affectedFile in $affectedFiles) {
        @($affectedFile.Issues)
    }
).Count

$exitCode = if ($issueCount -gt 0) { 1 } else { 0 }
$status = if ($issueCount -gt 0) { 'IssuesFound' } else { 'Clean' }
$message = if ($issueCount -gt 0) {
    "PSScriptAnalyzer reported $issueCount issue(s) across $($affectedFiles.Count) affected module script file(s)."
}
else {
    "PSScriptAnalyzer found no issues across $($moduleScriptFiles.Count) module script file(s)."
}

if (-not [string]::IsNullOrWhiteSpace($resolvedSettingsPath)) {
    $message = "$message Using analyzer settings from '$resolvedSettingsPath'."
}
elseif ($settingsSource -eq 'ParameterMissing' -and -not [string]::IsNullOrWhiteSpace($requestedSettingsPath)) {
    $message = "$message The requested analyzer settings file was not found at '$requestedSettingsPath'; default severity filtering was used."
}
elseif ($settingsSource -eq 'ResolutionFailed' -and -not [string]::IsNullOrWhiteSpace($settingsResolutionWarning)) {
    $message = "$message $settingsResolutionWarning Default severity filtering was used."
}
else {
    $message = "$message No shared analyzer settings file was found; default severity filtering was used."
}

$result = New-AnalyzerJsonResult `
    -Status $status `
    -ExitCode $exitCode `
    -Message $message `
    -SettingsPath $resolvedSettingsPath `
    -SettingsRequestedPath $requestedSettingsPath `
    -SettingsSource $settingsSource `
    -EffectiveSeverity $effectiveSeverity `
    -ScannedFileCount $moduleScriptFiles.Count `
    -Files $affectedFiles

$result | ConvertTo-Json -Depth 8

