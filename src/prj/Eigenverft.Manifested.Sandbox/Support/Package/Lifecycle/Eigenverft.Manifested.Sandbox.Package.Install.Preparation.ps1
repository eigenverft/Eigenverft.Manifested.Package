<#
    Eigenverft.Manifested.Sandbox.Package.Install - install-target metadata, elevation plan, machine-prerequisite short-circuit.
    Dot-sourced from Eigenverft.Manifested.Sandbox.psm1 (mirrored in TestImports.ps1) before Package.Install.ps1.
#>

function Get-PackageOwnedInstallStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if ($PackageResult.ExistingPackage) {
        switch -Exact ([string]$PackageResult.ExistingPackage.Decision) {
            'ExistingInstallReadinessFailed' {
                if ([string]::Equals([string]$PackageResult.ExistingPackage.SearchKind, 'packageTargetInstallPath', [System.StringComparison]::OrdinalIgnoreCase)) {
                    return 'RepairedPackageOwnedInstall'
                }
            }
            'ReplacePackageOwnedInstall' { return 'ReplacedPackageOwnedInstall' }
            'UpgradeAdoptedInstall' { return 'ReplacedAdoptedInstall' }
        }
    }

    return 'Installed'
}

function Get-PackageInstallTargetKind {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Package
    )

    $assignedInstall = Get-PackageAssignedInstallOperation -Release $Package
    if ($assignedInstall -and $assignedInstall.PSObject.Properties['targetKind'] -and
        -not [string]::IsNullOrWhiteSpace([string]$assignedInstall.targetKind)) {
        return [string]$assignedInstall.targetKind
    }

    return 'directory'
}

function Get-PackageInstallerElevationPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [AllowNull()]
        [string]$ElevationMode
    )

    if (-not [string]::IsNullOrWhiteSpace($ElevationMode)) {
        $mode = ([string]$ElevationMode).ToLowerInvariant()
    }
    else {
        $install = Get-PackageAssignedInstallOperation -Release $PackageResult.Package
        if (-not $install) {
            throw 'Get-PackageInstallerElevationPlan requires a selected release with an assigned block.'
        }
        $mode = if ($install.PSObject.Properties['elevation'] -and -not [string]::IsNullOrWhiteSpace([string]$install.elevation)) {
            ([string]$install.elevation).ToLowerInvariant()
        }
        else {
            'none'
        }
    }
    $processIsElevated = Test-ProcessElevation
    $shouldElevate = ($mode -in @('required', 'auto')) -and (-not $processIsElevated)

    return [pscustomobject]@{
        Mode              = $mode
        ProcessIsElevated = $processIsElevated
        ShouldElevate     = $shouldElevate
    }
}

function Resolve-PackagePreAssignmentSatisfaction {
<#
.SYNOPSIS
Checks whether a machine-prerequisite package is already satisfied.

.DESCRIPTION
Runs readiness before acquisition/assign for prerequisite-style packages that
do not own an install directory. When readiness succeeds, later acquisition
and installer steps are skipped.

.PARAMETER PackageResult
The Package result object to enrich.

.EXAMPLE
Resolve-PackagePreAssignmentSatisfaction -PackageResult $result
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $package = $PackageResult.Package
    $assignedInstall = Get-PackageAssignedInstallOperation -Release $package
    if (-not $package -or -not $assignedInstall) {
        return $PackageResult
    }

    $installKind = if ($assignedInstall.PSObject.Properties['kind']) { [string]$assignedInstall.kind } else { $null }
    $targetKind = Get-PackageInstallTargetKind -Package $package
    if (-not [string]::Equals($installKind, 'runInstaller', [System.StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals($targetKind, 'machinePrerequisite', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $PackageResult
    }

    $PackageResult = Test-PackageAssignedReadiness -PackageResult $PackageResult -FailedCheckLogLevel 'INF'
    if ($PackageResult.Readiness -and $PackageResult.Readiness.Accepted) {
        $PackageResult.InstallOrigin = 'AlreadySatisfied'
        $PackageResult.Assigned = [pscustomobject]@{
            Status           = 'AlreadySatisfied'
            InstallKind      = 'runInstaller'
            TargetKind       = 'machinePrerequisite'
            InstallDirectory = $null
            ReusedExisting   = $true
        }
        Write-PackageExecutionMessage -Message "[DECISION] Machine prerequisite is already satisfied; skipping acquisition and installer execution."
    }
    else {
        $failedCount = if ($PackageResult.Readiness) {
            @(
                @($PackageResult.Readiness.Files) +
                @($PackageResult.Readiness.Directories) +
                @($PackageResult.Readiness.Commands) +
                @($PackageResult.Readiness.MetadataFiles) +
                @($PackageResult.Readiness.Signatures) +
                @($PackageResult.Readiness.FileDetails) +
                @($PackageResult.Readiness.Registry) +
                @($PackageResult.Readiness.PowerShellModules) |
                    Where-Object { $_.Status -ne 'Ready' }
            ).Count
        }
        else {
            0
        }
        Write-PackageExecutionMessage -Message ("[STATE] Machine prerequisite is not satisfied yet; failedChecks={0}." -f $failedCount)
        $PackageResult.Readiness = $null
    }

    return $PackageResult
}
