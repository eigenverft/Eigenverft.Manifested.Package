<#
    Public package command surface.

    Optional -PublisherId narrows definition resolution to one trusted publisher.
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

        [switch]$FailFast
    )

    $packageVersionOverrideSpecified = $PSBoundParameters.ContainsKey('PackageVersion') -and -not [string]::IsNullOrWhiteSpace([string]$PackageVersion)
    $normalizedPackageVersion = if ($packageVersionOverrideSpecified) { ([string]$PackageVersion).Trim() } else { $null }

    if ([string]::Equals($DesiredState, 'Removed', [System.StringComparison]::OrdinalIgnoreCase) -and
        $packageVersionOverrideSpecified -and
        -not [string]::Equals($normalizedPackageVersion, 'latestByVersion', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Invoke-Package -PackageVersion can only override version selection for DesiredState Assigned. Omit -PackageVersion or use 'latestByVersion' with DesiredState Removed."
    }

    foreach ($definition in $DefinitionId) {
        $invokeParams = @{
            PublisherId   = $PublisherId
            DefinitionId  = $definition
            DesiredState  = $DesiredState
        }
        if ($packageVersionOverrideSpecified) {
            $invokeParams.PackageVersion = $normalizedPackageVersion
        }
        $result = Invoke-PackageDefinitionCommandCore @invokeParams
        $result
        if ($FailFast -and $result -and -not [string]::Equals([string]$result.Status, 'Ready', [System.StringComparison]::OrdinalIgnoreCase)) {
            break
        }
    }
}
