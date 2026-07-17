<#
    Public package command surface.

    Optional -PublisherId narrows definition resolution to one signed definitionPublication.publisherId label.
#>

function Invoke-Package {
    <#
    .SYNOPSIS
        Runs package definition lifecycle for one or more definitions.

    .PARAMETER FailFast
        When set, stops after the first result whose Status is not 'Ready'.
        By default every DefinitionId is attempted and each result is written to the pipeline.

    .PARAMETER PackageVersion
        Optional command override for Assigned version selection. Omit to use the package
        definition's versionSelection.strategy; pass 'latestByVersion', 'previousByVersion',
        or an exact authored package version such as '1.14.46'.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$PublisherId = $null,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$DefinitionId,

        [ValidateSet('Assigned', 'Removed')]
        [string]$DesiredState = 'Assigned',

        [AllowNull()]
        [string]$PackageVersion = $null,

        [switch]$AcceptUnknownSigningKey,

        [Parameter(DontShow = $true)]
        [switch]$RequireAlreadyTrusted,

        [switch]$Offline,

        [switch]$MaterializeOnly,

        [switch]$FailFast
    )

    $packageVersionOverrideSpecified = $PSBoundParameters.ContainsKey('PackageVersion') -and -not [string]::IsNullOrWhiteSpace([string]$PackageVersion)
    $normalizedPackageVersion = if ($packageVersionOverrideSpecified) { ([string]$PackageVersion).Trim() } else { $null }

    if ($AcceptUnknownSigningKey.IsPresent -and $RequireAlreadyTrusted.IsPresent) {
        throw 'AcceptUnknownSigningKey and RequireAlreadyTrusted are mutually exclusive trust modes.'
    }

    if ([string]::Equals($DesiredState, 'Removed', [System.StringComparison]::OrdinalIgnoreCase) -and
        $packageVersionOverrideSpecified -and
        -not [string]::Equals($normalizedPackageVersion, 'latestByVersion', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Invoke-Package -PackageVersion can only override version selection for DesiredState Assigned. Omit -PackageVersion or use 'latestByVersion' with DesiredState Removed."
    }
    if ($MaterializeOnly.IsPresent -and $PSBoundParameters.ContainsKey('DesiredState')) {
        throw "Invoke-Package -MaterializeOnly is its own command mode. Do not combine it with -DesiredState Assigned or -DesiredState Removed."
    }

    $dependencyPlan = $null
    $shouldPlanDependencies = $MaterializeOnly.IsPresent -or [string]::Equals($DesiredState, 'Assigned', [System.StringComparison]::OrdinalIgnoreCase)
    if ($shouldPlanDependencies) {
        Write-PackageExecutionMessage -Message ("[STEP] Planning package dependencies for {0} root definition(s)." -f @($DefinitionId).Count)
        $assignmentPlanCore = New-PackageAssignmentPlanCore -PublisherId $PublisherId -DefinitionId $DefinitionId -PackageVersion $normalizedPackageVersion -PackageVersionOverrideSpecified $packageVersionOverrideSpecified -Purpose Execution -AcceptUnknownSigningKey:$AcceptUnknownSigningKey -RequireAlreadyTrusted:$RequireAlreadyTrusted -Offline:$Offline -MaterializeOnly:$MaterializeOnly
        $dependencyPlan = $assignmentPlanCore.DependencyPlan
        if (-not $dependencyPlan.Accepted) {
            Write-PackageExecutionMessage -Level 'ERR' -Message ("[FAIL] Dependency plan rejected with {0} violation(s)." -f $dependencyPlan.Violations.Count)
            New-PackageDependencyPlanFailureResults -Plan $dependencyPlan -DesiredState $DesiredState -Offline:$Offline -MaterializeOnly:$MaterializeOnly -PackageVersion $normalizedPackageVersion
            return
        }
        Write-PackageExecutionMessage -Message ("[STATE] Dependency plan approved with {0} node(s) and {1} edge(s)." -f $dependencyPlan.Nodes.Count, $dependencyPlan.Edges.Count)
    }

    foreach ($definition in $DefinitionId) {
        $invokeParams = @{
            PublisherId              = $PublisherId
            DefinitionId             = $definition
            DesiredState             = $DesiredState
            AcceptUnknownSigningKey  = $AcceptUnknownSigningKey
            RequireAlreadyTrusted    = $RequireAlreadyTrusted
            Offline                  = $Offline
            MaterializeOnly          = $MaterializeOnly
        }
        if ($packageVersionOverrideSpecified) {
            $invokeParams.PackageVersion = $normalizedPackageVersion
        }
        if ($dependencyPlan) {
            $invokeParams.DependencyPlan = $dependencyPlan
            $invokeParams.DependencyPlanNodeKey = Get-PackageDependencyPlanRootNodeKey -Plan $dependencyPlan -DefinitionId $definition
        }
        $result = Invoke-PackageDefinitionCommandCore @invokeParams
        $result
        $resultSucceeded = [string]::Equals([string]$result.Status, 'Ready', [System.StringComparison]::OrdinalIgnoreCase) -or
            [string]::Equals([string]$result.Status, 'Materialized', [System.StringComparison]::OrdinalIgnoreCase)
        if ($FailFast -and $result -and (-not $resultSucceeded)) {
            break
        }
    }
}
