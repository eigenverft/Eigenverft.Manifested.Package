<#
    Public read-only package assignment/materialization preview.
#>

function Write-PackageAssignmentPlanView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Plan
    )

    Write-Host ("Package assignment plan: {0} | mode={1} | offline={2} | nodes={3}" -f $Plan.Status, $Plan.Mode, $Plan.Offline, @($Plan.Nodes).Count)
    if (@($Plan.Roots).Count -gt 0) {
        $rootText = @($Plan.Roots | Select-Object DefinitionId, Version, PlannedAction, Status | Format-Table -AutoSize | Out-String).TrimEnd()
        Write-Host $rootText
    }
    if (@($Plan.Blockers).Count -gt 0) {
        Write-Host 'Blockers:'
        $blockerText = @($Plan.Blockers | Select-Object Code, DefinitionId, ArtifactFileId, Message | Format-Table -Wrap -AutoSize | Out-String).TrimEnd()
        Write-Host $blockerText
    }
    if (@($Plan.Warnings).Count -gt 0) {
        Write-Host 'Warnings:'
        $warningText = @($Plan.Warnings | Select-Object Code, DefinitionId, Message | Format-Table -Wrap -AutoSize | Out-String).TrimEnd()
        Write-Host $warningText
    }
    Write-Host ("Next: {0}" -f $Plan.NextCommand)
}

function Get-PackageAssignmentPlan {
    <#
    .SYNOPSIS
        Previews package assignment or depot materialization without changing machine state.

    .DESCRIPTION
        Uses the same definition, trust, dependency, release, path, acquisition, discovery,
        ownership, and readiness rules as Invoke-Package. It performs no downloads and does
        not write trust, endpoint, depot, staging, inventory, history, PATH, or installation data.

    .PARAMETER VerifyDepotContent
        Hashes and verifies present depot files during an online preview. Offline previews
        always verify present depot content.

    .PARAMETER Raw
        Suppresses the compact console view. The returned structured plan is unchanged.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$PublisherId = $null,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$DefinitionId,

        [AllowNull()]
        [string]$PackageVersion = $null,

        [switch]$Offline,

        [switch]$MaterializeOnly,

        [switch]$VerifyDepotContent,

        [switch]$Raw
    )

    $packageVersionOverrideSpecified = $PSBoundParameters.ContainsKey('PackageVersion') -and -not [string]::IsNullOrWhiteSpace([string]$PackageVersion)
    $normalizedPackageVersion = if ($packageVersionOverrideSpecified) { ([string]$PackageVersion).Trim() } else { $null }
    $hadMessageSuppression = Test-Path Variable:script:SuppressPackageExecutionMessages
    $priorMessageSuppression = $script:SuppressPackageExecutionMessages
    try {
        $script:SuppressPackageExecutionMessages = $true
        $plan = New-PackageAssignmentPlanCore -PublisherId $PublisherId -DefinitionId $DefinitionId -PackageVersion $normalizedPackageVersion -PackageVersionOverrideSpecified $packageVersionOverrideSpecified -Purpose Inspection -Offline:$Offline -MaterializeOnly:$MaterializeOnly -VerifyDepotContent:$VerifyDepotContent
    }
    finally {
        if ($hadMessageSuppression) {
            $script:SuppressPackageExecutionMessages = $priorMessageSuppression
        }
        else {
            Remove-Variable -Name SuppressPackageExecutionMessages -Scope Script -ErrorAction SilentlyContinue
        }
    }

    if (-not $Raw.IsPresent) {
        Write-PackageAssignmentPlanView -Plan $plan
    }
    return $plan
}
