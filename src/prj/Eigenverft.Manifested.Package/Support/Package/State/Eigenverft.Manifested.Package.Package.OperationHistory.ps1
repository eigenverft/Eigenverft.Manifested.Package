<#
    Eigenverft.Manifested.Package.Package.OperationHistory
#>

function Get-PackageOperationHistory {
<#
.SYNOPSIS
Loads the Package operation-history document.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig
    )

    $historyPath = $PackageConfig.PackageOperationHistoryFilePath
    if ([string]::IsNullOrWhiteSpace($historyPath)) {
        throw 'Package operation-history path is not configured.'
    }

    if (-not (Test-Path -LiteralPath $historyPath -PathType Leaf)) {
        return [pscustomobject]@{
            Path    = $historyPath
            Records = @()
        }
    }

    $documentInfo = Read-PackageJsonDocument -Path $historyPath
    $records = if ($documentInfo.Document.PSObject.Properties['records']) { @($documentInfo.Document.records) } else { @() }
    return [pscustomobject]@{
        Path    = $documentInfo.Path
        Records = $records
    }
}

function Save-PackageOperationHistory {
<#
.SYNOPSIS
Writes the Package operation-history document.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HistoryPath,

        [Parameter(Mandatory = $true)]
        [object[]]$Records
    )

    $directoryPath = Split-Path -Parent $HistoryPath
    if (-not [string]::IsNullOrWhiteSpace($directoryPath)) {
        $null = New-Item -ItemType Directory -Path $directoryPath -Force
    }

    [ordered]@{
        schemaVersion = 1
        records       = @($Records)
    } | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $HistoryPath -Encoding UTF8
}

function Select-PackageOperationDependencySummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Dependency
    )

    $dependencyResult = if ($Dependency.PSObject.Properties['Result']) { $Dependency.Result } else { $null }
    return [pscustomobject]@{
        publisherId   = if ($Dependency.PSObject.Properties['PublisherId']) { [string]$Dependency.PublisherId } elseif ($dependencyResult -and $dependencyResult.PSObject.Properties['DefinitionPublisherId']) { [string]$dependencyResult.DefinitionPublisherId } else { $null }
        endpointName  = if ($dependencyResult -and $dependencyResult.PSObject.Properties['DefinitionEndpointName']) { [string]$dependencyResult.DefinitionEndpointName } else { $null }
        definitionId  = if ($Dependency.PSObject.Properties['DefinitionId']) { [string]$Dependency.DefinitionId } elseif ($dependencyResult -and $dependencyResult.PSObject.Properties['DefinitionId']) { [string]$dependencyResult.DefinitionId } else { $null }
        desiredState  = if ($dependencyResult -and $dependencyResult.PSObject.Properties['DesiredState']) { [string]$dependencyResult.DesiredState } else { 'Assigned' }
        commandMode   = if ($Dependency.PSObject.Properties['CommandMode']) { [string]$Dependency.CommandMode } elseif ($dependencyResult -and $dependencyResult.PSObject.Properties['CommandMode']) { [string]$dependencyResult.CommandMode } else { $null }
        offline       = if ($Dependency.PSObject.Properties['Offline']) { [bool]$Dependency.Offline } elseif ($dependencyResult -and $dependencyResult.PSObject.Properties['Offline']) { [bool]$dependencyResult.Offline } else { $false }
        status        = if ($Dependency.PSObject.Properties['Status']) { [string]$Dependency.Status } elseif ($dependencyResult -and $dependencyResult.PSObject.Properties['Status']) { [string]$dependencyResult.Status } else { $null }
        failureReason = if ($dependencyResult -and $dependencyResult.PSObject.Properties['FailureReason']) { [string]$dependencyResult.FailureReason } else { $null }
        installOrigin = if ($Dependency.PSObject.Properties['InstallOrigin']) { [string]$Dependency.InstallOrigin } elseif ($dependencyResult -and $dependencyResult.PSObject.Properties['InstallOrigin']) { [string]$dependencyResult.InstallOrigin } else { $null }
    }
}

function Select-PackageOperationDepotDistributionSummary {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$Distribution
    )

    return [pscustomobject]@{
        mode               = if ($Distribution -and $Distribution.PSObject.Properties['Mode']) { [string]$Distribution.Mode } else { $null }
        status             = if ($Distribution -and $Distribution.PSObject.Properties['Status']) { [string]$Distribution.Status } else { $null }
        reason             = if ($Distribution -and $Distribution.PSObject.Properties['Reason']) { [string]$Distribution.Reason } else { $null }
        targetCount        = if ($Distribution -and $Distribution.PSObject.Properties['TargetCount']) { [int]$Distribution.TargetCount } else { 0 }
        allMirrorsComplete = if ($Distribution -and $Distribution.PSObject.Properties['AllMirrorsComplete']) { [bool]$Distribution.AllMirrorsComplete } else { $null }
        copied             = if ($Distribution -and $Distribution.PSObject.Properties['CopiedCount']) { [int]$Distribution.CopiedCount } else { 0 }
        skipped            = if ($Distribution -and $Distribution.PSObject.Properties['SkippedCount']) { [int]$Distribution.SkippedCount } else { 0 }
        failed             = if ($Distribution -and $Distribution.PSObject.Properties['FailedCount']) { [int]$Distribution.FailedCount } else { 0 }
        targets            = if ($Distribution -and $Distribution.PSObject.Properties['Targets']) {
            @($Distribution.Targets | ForEach-Object {
                    [pscustomobject]@{
                        depotId           = [string]$_.DepotId
                        transportKind     = [string]$_.TransportKind
                        status            = [string]$_.Status
                        requiredFileCount = [int]$_.RequiredFileCount
                        completeFileCount = [int]$_.CompleteFileCount
                        failedCount       = [int]$_.FailedCount
                        errorMessage      = [string]$_.ErrorMessage
                        files             = @($_.Actions | ForEach-Object {
                                [pscustomobject]@{
                                    id           = [string]$_.FileId
                                    relativePath = [string]$_.RelativePath
                                    targetPath   = [string]$_.TargetPath
                                    status       = [string]$_.Status
                                    reason       = [string]$_.Reason
                                    errorMessage = [string]$_.ErrorMessage
                                }
                            })
                    }
                })
        }
        else { @() }
    }
}

function New-PackageOperationHistoryRecord {
<#
.SYNOPSIS
Creates one operation-history record from a finalized Package result.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [AllowNull()]
        [string]$FailedStep,

        [Parameter(Mandatory = $true)]
        [string]$CompletedAtUtc
    )

    $artifactPreparation = $PackageResult.ArtifactPreparation
    $depotDistribution = if ($PackageResult.PSObject.Properties['DepotDistribution']) { $PackageResult.DepotDistribution } else { $null }
    $npmDepotDistribution = if ($PackageResult.PSObject.Properties['NpmMaterialization'] -and $PackageResult.NpmMaterialization -and $PackageResult.NpmMaterialization.PSObject.Properties['DepotDistribution']) { $PackageResult.NpmMaterialization.DepotDistribution } else { $null }
    $installStatus = if ($PackageResult.Assigned -and $PackageResult.Assigned.PSObject.Properties['Status']) { [string]$PackageResult.Assigned.Status } else { $null }
    $operationId = if ($PackageResult.PSObject.Properties['OperationId'] -and -not [string]::IsNullOrWhiteSpace([string]$PackageResult.OperationId)) {
        [string]$PackageResult.OperationId
    }
    else {
        [guid]::NewGuid().ToString('n')
    }
    $startedAtUtc = if ($PackageResult.PSObject.Properties['OperationStartedAtUtc'] -and -not [string]::IsNullOrWhiteSpace([string]$PackageResult.OperationStartedAtUtc)) {
        [string]$PackageResult.OperationStartedAtUtc
    }
    else {
        $CompletedAtUtc
    }

    return [pscustomobject]@{
        operationId                   = $operationId
        startedAtUtc                  = $startedAtUtc
        completedAtUtc                = $CompletedAtUtc
        definitionId                  = [string]$PackageResult.DefinitionId
        definitionPublisherId         = if ($PackageResult.PSObject.Properties['DefinitionPublisherId']) { [string]$PackageResult.DefinitionPublisherId } else { $null }
        definitionRevision            = if ($PackageResult.PSObject.Properties['DefinitionRevision']) { [int]$PackageResult.DefinitionRevision } else { $null }
        definitionEndpointName        = if ($PackageResult.PSObject.Properties['DefinitionEndpointName']) { [string]$PackageResult.DefinitionEndpointName } else { $null }
        definitionCandidatePath       = if ($PackageResult.PSObject.Properties['DefinitionCandidatePath']) { [string]$PackageResult.DefinitionCandidatePath } else { $null }
        definitionAssignedSnapshotPath = if ($PackageResult.PSObject.Properties['DefinitionAssignedSnapshotPath']) { [string]$PackageResult.DefinitionAssignedSnapshotPath } else { $null }
        desiredState                  = [string]$PackageResult.DesiredState
        commandMode                   = if ($PackageResult.PSObject.Properties['CommandMode']) { [string]$PackageResult.CommandMode } else { [string]$PackageResult.DesiredState }
        offline                       = if ($PackageResult.PSObject.Properties['Offline']) { [bool]$PackageResult.Offline } else { $false }
        materializeOnly               = if ($PackageResult.PSObject.Properties['MaterializeOnly']) { [bool]$PackageResult.MaterializeOnly } else { $false }
        status                        = [string]$PackageResult.Status
        failureReason                 = [string]$PackageResult.FailureReason
        errorMessage                  = [string]$PackageResult.ErrorMessage
        failedStep                    = $FailedStep
        packageId                     = [string]$PackageResult.PackageId
        packageVersion                = [string]$PackageResult.PackageVersion
        releaseTrack                  = [string]$PackageResult.ReleaseTrack
        artifactDistributionVariant    = if ($PackageResult.Package -and $PackageResult.Package.PSObject.Properties['artifactDistributionVariant']) { [string]$PackageResult.Package.artifactDistributionVariant } else { $null }
        installOrigin                 = [string]$PackageResult.InstallOrigin
        installStatus                 = $installStatus
        installDirectory              = [string]$PackageResult.InstallDirectory
        artifactPreparation           = [pscustomobject]@{
            status  = if ($artifactPreparation -and $artifactPreparation.PSObject.Properties['Status']) { [string]$artifactPreparation.Status } else { $null }
            success = if ($artifactPreparation -and $artifactPreparation.PSObject.Properties['Success']) { [bool]$artifactPreparation.Success } else { $null }
            files   = @($PackageResult.ArtifactFiles | ForEach-Object {
                    $selectedSource = if ($_.Preparation -and $_.Preparation.PSObject.Properties['SelectedSource']) { $_.Preparation.SelectedSource } else { $null }
                    [pscustomobject]@{
                        id = [string]$_.Id; relativePath = [string]$_.RelativePath; stagingPath = [string]$_.StagingPath
                        defaultDepotPath = [string]$_.DefaultDepotPath
                        status = if ($_.Preparation) { [string]$_.Preparation.Status } else { $null }
                        success = if ($_.Preparation) { [bool]$_.Preparation.Success } else { $null }
                        sourceScope = if ($selectedSource) { [string]$selectedSource.SourceScope } else { $null }
                        sourceId = if ($selectedSource) { [string]$selectedSource.SourceId } else { $null }
                        verificationStatus = if ($_.Verification) { [string]$_.Verification.Status } else { $null }
                    }
                })
        }
        depotDistribution             = Select-PackageOperationDepotDistributionSummary -Distribution $depotDistribution
        npmDepotDistribution          = Select-PackageOperationDepotDistributionSummary -Distribution $npmDepotDistribution
        dependencies                  = @($PackageResult.Dependencies | ForEach-Object { Select-PackageOperationDependencySummary -Dependency $_ })
    }
}

function Add-PackageOperationHistoryRecord {
<#
.SYNOPSIS
Appends one Package operation-history record.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig,

        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [AllowNull()]
        [string]$FailedStep
    )

    try {
        $completedAtUtc = [DateTime]::UtcNow.ToString('o')
        $history = Get-PackageOperationHistory -PackageConfig $PackageConfig
        $records = @($history.Records)
        $records += New-PackageOperationHistoryRecord -PackageResult $PackageResult -FailedStep $FailedStep -CompletedAtUtc $completedAtUtc
        Save-PackageOperationHistory -HistoryPath $history.Path -Records $records
        Write-PackageExecutionMessage -Message ("[STATE] Appended package operation-history record for definition '{0}' with status '{1}' at '{2}'." -f [string]$PackageResult.DefinitionId, [string]$PackageResult.Status, $history.Path)
    }
    catch {
        Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Failed to append package operation history for definition '{0}': {1}" -f [string]$PackageResult.DefinitionId, $_.Exception.Message)
    }
}
