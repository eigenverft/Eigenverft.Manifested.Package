<#
    Eigenverft.Manifested.Package.Package.EntryPoints
#>

function Resolve-PackageEntryPoints {
<#
.SYNOPSIS
Resolves the install-relative discovered entry points for a Package result.

.DESCRIPTION
Maps exposed definition discovery command and app entries into absolute paths
beneath the final install directory and attaches them to the Package result.

.PARAMETER PackageResult
The Package result object to enrich.

.EXAMPLE
Resolve-PackageEntryPoints -PackageResult $result
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $definition = $PackageResult.PackageConfig.Definition
    $commands = @(
        foreach ($entryPoint in @(Get-PackageDiscoveryPresenceEntryPoints -Definition $definition -ToolKind 'commands' -ExposedOnly)) {
            $path = Resolve-PackagePresenceEntryPointPath -EntryPoint $entryPoint -InstallDirectory $PackageResult.InstallDirectory
            [pscustomobject]@{
                Name   = $entryPoint.name
                Path   = $path
                Exists = (Test-Path -LiteralPath $path)
            }
        }
    )

    $apps = @(
        foreach ($entryPoint in @(Get-PackageDiscoveryPresenceEntryPoints -Definition $definition -ToolKind 'apps' -ExposedOnly)) {
            $path = Resolve-PackagePresenceEntryPointPath -EntryPoint $entryPoint -InstallDirectory $PackageResult.InstallDirectory
            [pscustomobject]@{
                Name   = $entryPoint.name
                Path   = $path
                Exists = (Test-Path -LiteralPath $path)
            }
        }
    )

    $PackageResult.EntryPoints = [pscustomobject]@{
        Commands = $commands
        Apps     = $apps
    }

    Write-PackageExecutionMessage -Message '[STATE] Resolved entry points:'
    if (@($commands).Count -eq 0) {
        Write-PackageExecutionMessage -Message '[PATH] Command entry points: <none>'
    }
    else {
        foreach ($command in $commands) {
            Write-PackageExecutionMessage -Message ("[PATH] Command {0}: {1} (exists={2})" -f [string]$command.Name, [string]$command.Path, [bool]$command.Exists)
        }
    }

    if (@($apps).Count -eq 0) {
        Write-PackageExecutionMessage -Message '[PATH] App entry points: <none>'
    }
    else {
        foreach ($app in $apps) {
            Write-PackageExecutionMessage -Message ("[PATH] App {0}: {1} (exists={2})" -f [string]$app.Name, [string]$app.Path, [bool]$app.Exists)
        }
    }

    return $PackageResult
}

function Complete-PackageResult {
<#
.SYNOPSIS
Finalizes a Package result for output.

.DESCRIPTION
Applies final status and failure details, then removes the internal config
state before returning the user-facing Package result object.

.PARAMETER PackageResult
The Package result object to finalize.

.EXAMPLE
Complete-PackageResult -PackageResult $result
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if (-not [string]::IsNullOrWhiteSpace($PackageResult.ErrorMessage)) {
        $PackageResult.Status = 'Failed'
    }
    elseif ($PackageResult.PSObject.Properties['CommandMode'] -and
        [string]::Equals([string]$PackageResult.CommandMode, 'MaterializeOnly', [System.StringComparison]::OrdinalIgnoreCase) -and
        $PackageResult.PSObject.Properties['Materialization'] -and
        $PackageResult.Materialization -and
        $PackageResult.Materialization.PSObject.Properties['Success'] -and
        [bool]$PackageResult.Materialization.Success) {
        $PackageResult.Status = 'Materialized'
    }
    elseif ([string]::Equals([string]$PackageResult.DesiredState, 'Removed', [System.StringComparison]::OrdinalIgnoreCase) -and
        $PackageResult.Removed -and $PackageResult.Removed.PSObject.Properties['Accepted'] -and [bool]$PackageResult.Removed.Accepted) {
        $PackageResult.Status = 'Ready'
    }
    elseif ($PackageResult.Readiness -and $PackageResult.Readiness.Accepted) {
        $PackageResult.Status = 'Ready'
    }
    else {
        $PackageResult.Status = 'Failed'
        if ([string]::IsNullOrWhiteSpace($PackageResult.FailureReason)) {
            $PackageResult.FailureReason = 'AssignedPackageReadinessFailed'
        }
    }

    $null = $PackageResult.PSObject.Properties.Remove('PackageConfig')
    $null = $PackageResult.PSObject.Properties.Remove('CurrentStep')
    $null = $PackageResult.PSObject.Properties.Remove('EffectiveRelease')
    $null = $PackageResult.PSObject.Properties.Remove('AcquisitionPlan')
    $null = $PackageResult.PSObject.Properties.Remove('DependencyPlan')
    return [pscustomobject]$PackageResult
}

