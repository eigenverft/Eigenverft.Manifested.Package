<#
    Default quiet test entrypoint for local and agent workflows.

    Use -Detailed only when the compact summary points to a failure that needs
    live Pester output. Full logs are always written by Invoke-ModuleTests.ps1.
#>

[CmdletBinding()]
param(
    [string]$Path,

    [string[]]$FullName,

    [switch]$Detailed,

    [string]$LogPath
)

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

$runnerPath = Join-Path $PSScriptRoot 'Invoke-ModuleTests.ps1'
$parameters = @{
    Mode = if ($Detailed.IsPresent) { 'Detailed' } else { 'Quiet' }
}

if ($Detailed.IsPresent) {
    Write-Output 'Running tests in detailed mode. Careful: this can produce large output and burn tokens fast.'
}
else {
    Write-Output 'Running tests in muted mode. Use -Detailed only when the compact summary/log path is not enough.'
}

if (-not [string]::IsNullOrWhiteSpace($Path)) {
    $parameters.Path = $Path
}
if ($FullName -and $FullName.Count -gt 0) {
    $parameters.FullName = $FullName
}
if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $parameters.LogPath = $LogPath
}

& $runnerPath @parameters
