<#
    Eigenverft.Manifested.Sandbox.Package.CommandFlow
#>

function Get-PackageOutcomeSummary {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $assignedStatusText = if ($PackageResult.Assigned -and $PackageResult.Assigned.PSObject.Properties['Status']) {
        [string]$PackageResult.Assigned.Status
    }
    else {
        '<none>'
    }
    $assignedRestartText = if ($PackageResult.Assigned -and $PackageResult.Assigned.PSObject.Properties['Installer'] -and $PackageResult.Assigned.Installer.PSObject.Properties['RestartRequired']) {
        [string]$PackageResult.Assigned.Installer.RestartRequired
    }
    else {
        '<none>'
    }

    $installDirectoryText = if ([string]::IsNullOrWhiteSpace([string]$PackageResult.InstallDirectory)) {
        '<none>'
    }
    else {
        [string]$PackageResult.InstallDirectory
    }
    $packageFileStatusText = if ($PackageResult.PackageFilePreparation -and $PackageResult.PackageFilePreparation.PSObject.Properties['Status']) {
        [string]$PackageResult.PackageFilePreparation.Status
    }
    else {
        '<none>'
    }
    $existingDecisionText = if ($PackageResult.ExistingPackage -and $PackageResult.ExistingPackage.PSObject.Properties['Decision']) {
        [string]$PackageResult.ExistingPackage.Decision
    }
    else {
        '<none>'
    }

    switch -Exact ([string]$PackageResult.InstallOrigin) {
        'PackageReused' {
            return ("[OUTCOME] Reused Package-owned install '{0}' (existingDecision='{1}', packageFileStep='{2}')." -f $installDirectoryText, $existingDecisionText, $packageFileStatusText)
        }
        'AdoptedExternal' {
            return ("[OUTCOME] Adopted external install '{0}' (existingDecision='{1}', packageFileStep='{2}')." -f $installDirectoryText, $existingDecisionText, $packageFileStatusText)
        }
        'PackageInstalled' {
            return ("[OUTCOME] Completed Package-owned install into '{0}' with installStatus='{1}' and packageFileStep='{2}'." -f $installDirectoryText, $assignedStatusText, $packageFileStatusText)
        }
        'PackageApplied' {
            return ("[OUTCOME] Applied Package prerequisite with installStatus='{0}', packageFileStep='{1}', restartRequired='{2}'." -f $assignedStatusText, $packageFileStatusText, $assignedRestartText)
        }
        'AlreadySatisfied' {
            return ("[OUTCOME] Package prerequisite already satisfied; installer and package-file acquisition were skipped.")
        }
        default {
            return ("[OUTCOME] Completed Package run with installOrigin='{0}', installStatus='{1}', packageFileStep='{2}', installDirectory='{3}'." -f [string]$PackageResult.InstallOrigin, $assignedStatusText, $packageFileStatusText, $installDirectoryText)
        }
    }
}

function Get-PackageCommandFailureReason {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentStep
    )

    switch -Exact ($CurrentStep) {
        'InitializeLocalEnvironment' { return 'LocalEnvironmentInitializationFailed' }
        'ResolveDesiredState' { return 'PackageDesiredStateNotImplemented' }
        'ResolvePackage' { return 'PackageSelectionFailed' }
        'ResolveDependencies' { return 'PackageDependencyFailed' }
        'ResolvePaths' { return 'PackagePathResolutionFailed' }
        'ResolvePreAssignmentSatisfaction' { return 'PreAssignmentSatisfactionCheckFailed' }
        'BuildAcquisitionPlan' { return 'AcquisitionPlanBuildFailed' }
        'FindExistingPackage' { return 'ExistingPackageDiscoveryFailed' }
        'ClassifyExistingPackage' { return 'ExistingPackageOwnershipClassificationFailed' }
        'ResolveExistingPackageDecision' { return 'ExistingPackageDecisionFailed' }
        'PreparePackageAssignedFile' { return 'PackageFilePreparationFailed' }
        'AssignPackage' { return 'PackageAssignFailed' }
        'CheckAssignedReadiness' { return 'AssignedPackageReadinessFailed' }
        'RegisterPath' { return 'PathRegistrationFailed' }
        'ResolveEntryPoints' { return 'EntryPointResolutionFailed' }
        'UpdateInventory' { return 'PackageInventoryUpdateFailed' }
        'ClearPackageWorkDirectories' { return 'PackageWorkDirectoryCleanupFailed' }
        'ResolveRemovalInstallContext' { return 'RemovalInventoryResolutionFailed' }
        'AssertRemovalPolicy' { return 'RemovalPolicyRejected' }
        'AssertRemovalDependencyDependents' { return 'RemovalDependencyDependentsBlocked' }
        'ExecuteRemovedOperation' { return 'RemovedOperationFailed' }
        'PostRemoveCleanup' { return 'PostRemoveCleanupFailed' }
        'VerifyRemovedAbsence' { return 'RemovedAbsenceVerificationFailed' }
        default { return 'PackageCommandFailed' }
    }
}

function Clear-PackageWorkDirectories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    foreach ($cleanupTarget in @(
            [pscustomobject]@{ Label = 'package file staging'; Path = [string]$PackageResult.PackageFileStagingDirectory; RootPath = [string]$PackageResult.PackageFileStagingRootDirectory }
            [pscustomobject]@{ Label = 'package install stage'; Path = [string]$PackageResult.PackageInstallStageDirectory; RootPath = [string]$PackageResult.PackageInstallStageRootDirectory }
        )) {
        if ([string]::IsNullOrWhiteSpace($cleanupTarget.Path)) {
            Write-PackageExecutionMessage -Message ("[STATE] {0} cleanup skipped because no directory was resolved." -f $cleanupTarget.Label)
            continue
        }

        try {
            $removed = Remove-PathIfExists -Path $cleanupTarget.Path
            if ($removed) {
                Write-PackageExecutionMessage -Message ("[ACTION] Cleaned {0} directory '{1}'." -f $cleanupTarget.Label, $cleanupTarget.Path)
            }
            else {
                Write-PackageExecutionMessage -Message ("[STATE] {0} cleanup skipped because '{1}' does not exist." -f $cleanupTarget.Label, $cleanupTarget.Path)
            }

            if (-not [string]::IsNullOrWhiteSpace($cleanupTarget.RootPath)) {
                Remove-EmptyParentDirectoryChain -DeletedLeafPath $cleanupTarget.Path -AncestorCeilingDirectory $cleanupTarget.RootPath
            }
        }
        catch {
            Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Failed to clean {0} directory '{1}': {2}" -f $cleanupTarget.Label, $cleanupTarget.Path, $_.Exception.Message)
        }
    }

    return $PackageResult
}

function Invoke-PackageAssignedFlow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [object[]]$DependencyStack = @()
    )

    $steps = @(
        [pscustomobject]@{ Name = 'ResolvePackage'; Message = '[STEP] Resolving package selection.'; Action = { param($r) Resolve-PackagePackage -PackageResult $r } },
        [pscustomobject]@{ Name = 'ResolveDependencies'; Message = '[STEP] Ensuring package dependencies.'; Action = { param($r) Resolve-PackageDependencies -PackageResult $r -DependencyStack $DependencyStack } },
        [pscustomobject]@{ Name = 'ResolvePaths'; Message = '[STEP] Resolving package paths.'; Action = { param($r) Resolve-PackagePaths -PackageResult $r } },
        [pscustomobject]@{ Name = 'ResolvePreAssignmentSatisfaction'; Message = '[STEP] Checking pre-assignment satisfaction.'; Action = { param($r) Resolve-PackagePreAssignmentSatisfaction -PackageResult $r } },
        [pscustomobject]@{ Name = 'BuildAcquisitionPlan'; Message = '[STEP] Building acquisition plan.'; Action = { param($r) Build-PackageAcquisitionPlan -PackageResult $r } },
        [pscustomobject]@{ Name = 'FindExistingPackage'; Message = '[STEP] Discovering existing installs.'; Action = { param($r) Find-PackageExistingPackage -PackageResult $r } },
        [pscustomobject]@{ Name = 'ClassifyExistingPackage'; Message = '[STEP] Classifying install ownership.'; Action = { param($r) Set-PackageExistingPackage -PackageResult $r } },
        [pscustomobject]@{ Name = 'ResolveExistingPackageDecision'; Message = '[STEP] Deciding reuse, adoption, or replacement.'; Action = { param($r) Resolve-PackageExistingPackageDecision -PackageResult $r } },
        [pscustomobject]@{ Name = 'PreparePackageAssignedFile'; Message = '[STEP] Ensuring package file is available.'; Action = { param($r) Resolve-PackageInstallFile -PackageResult $r } },
        [pscustomobject]@{ Name = 'DistributePackageFileToDepots'; Message = '[STEP] Reconciling package file depot mirrors.'; Action = { param($r) Invoke-PackageDepotDistribution -PackageResult $r } },
        [pscustomobject]@{ Name = 'MaterializeNpmPackage'; Message = '[STEP] Materializing npm package metadata and tarballs.'; Action = { param($r) Invoke-PackageNpmMaterialization -PackageResult $r } },
        [pscustomobject]@{ Name = 'AssignPackage'; Message = '[STEP] Assigning the package (install or reuse per assigned install operation).'; Action = { param($r) Set-PackageAssignedState -PackageResult $r } },
        [pscustomobject]@{ Name = 'CheckAssignedReadiness'; Message = '[STEP] Checking assigned package readiness.'; Action = { param($r) Test-PackageAssignedReadiness -PackageResult $r } },
        [pscustomobject]@{ Name = 'RegisterPath'; Message = '[STEP] Applying PATH registration.'; Action = { param($r) $r = Register-PackagePath -PackageResult $r; Remove-PackageReplacedPackageOwnedInstallDirectory -PackageResult $r } },
        [pscustomobject]@{ Name = 'ResolveEntryPoints'; Message = '[STEP] Resolving entry points.'; Action = { param($r) Resolve-PackageEntryPoints -PackageResult $r } },
        [pscustomobject]@{ Name = 'UpdateInventory'; Message = '[STEP] Updating package inventory.'; Action = { param($r) Update-PackageInventoryRecord -PackageResult $r } },
        [pscustomobject]@{ Name = 'ClearPackageWorkDirectories'; Message = '[STEP] Cleaning package staging directories.'; Action = { param($r) Clear-PackageWorkDirectories -PackageResult $r } }
    )

    try {
        Write-PackageExecutionMessage -Message ("[START] Invoke-Package publisher='{0}' endpoint='{1}' definition='{2}' desiredState='{3}'." -f $PackageResult.DefinitionPublisherId, $PackageResult.DefinitionEndpointName, $PackageResult.DefinitionId, $PackageResult.DesiredState)
        $PackageResult.CurrentStep = 'InitializeLocalEnvironment'
        Write-PackageExecutionMessage -Message '[STEP] Initializing local package environment.'
        $PackageResult.LocalEnvironment = Initialize-PackageLocalEnvironment -PackageConfig $PackageResult.PackageConfig
        if ($PackageResult.LocalEnvironment.InitializedNow) {
            Write-PackageExecutionMessage -Message ("[STATE] Local package environment initialized: created={0}, existing={1}, skippedSources={2}." -f @($PackageResult.LocalEnvironment.CreatedDirectories).Count, @($PackageResult.LocalEnvironment.ExistingDirectories).Count, @($PackageResult.LocalEnvironment.SkippedSources).Count)
        }
        else {
            Write-PackageExecutionMessage -Message '[STATE] Local package environment already initialized.'
        }

        foreach ($step in $steps) {
            $PackageResult.CurrentStep = $step.Name
            Write-PackageExecutionMessage -Message $step.Message
            $PackageResult = & $step.Action $PackageResult
            if ($step.Name -eq 'CheckAssignedReadiness' -and (-not $PackageResult.Readiness -or -not $PackageResult.Readiness.Accepted)) {
                $failedCount = if ($PackageResult.Readiness -and $PackageResult.Readiness.PSObject.Properties['FailedChecks']) { @($PackageResult.Readiness.FailedChecks).Count } else { 0 }
                throw ("Package readiness failed for '{0}' with {1} failed check(s)." -f $PackageResult.PackageId, $failedCount)
            }
        }
        Write-PackageExecutionMessage -Message (Get-PackageOutcomeSummary -PackageResult $PackageResult)
        $okStatus = if ($PackageResult.Assigned -and $PackageResult.Assigned.PSObject.Properties['Status']) { [string]$PackageResult.Assigned.Status } else { '<n/a>' }
        Write-PackageExecutionMessage -Message ("[OK] Package completed with InstallOrigin='{0}' and InstallStatus='{1}'." -f $PackageResult.InstallOrigin, $okStatus)
    }
    catch {
        $PackageResult.Status = 'Failed'
        $PackageResult.ErrorMessage = $_.Exception.Message
        Write-PackageExecutionMessage -Level 'ERR' -Message ("[FAIL] Step '{0}' failed: {1}" -f $PackageResult.CurrentStep, $_.Exception.Message)
        $PackageResult.FailureReason = Get-PackageCommandFailureReason -CurrentStep ([string]$PackageResult.CurrentStep)
    }

    return $PackageResult
}

function Invoke-PackageDefinitionCommandCore {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$PublisherId = $null,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DefinitionId,

        [ValidateSet('Assigned', 'Removed')]
        [string]$DesiredState = 'Assigned',

        [AllowNull()]
        [string]$PackageVersion = $null,

        [object[]]$DependencyStack = @()
    )

    $packageVersionOverrideSpecified = $PSBoundParameters.ContainsKey('PackageVersion') -and -not [string]::IsNullOrWhiteSpace([string]$PackageVersion)
    $normalizedPackageVersion = if ($packageVersionOverrideSpecified) { ([string]$PackageVersion).Trim() } else { $null }

    if ([string]::Equals($DesiredState, 'Removed', [System.StringComparison]::OrdinalIgnoreCase) -and
        $packageVersionOverrideSpecified -and
        -not [string]::Equals($normalizedPackageVersion, 'latestByVersion', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Invoke-Package -PackageVersion can only override version selection for DesiredState Assigned. Omit -PackageVersion or use 'latestByVersion' with DesiredState Removed."
    }

    $packageConfig = Get-PackageConfig -PublisherId $PublisherId -DefinitionId $DefinitionId -DesiredState $DesiredState
    $newResultParams = @{
        DesiredState   = $DesiredState
        PackageConfig  = $packageConfig
    }
    if ($packageVersionOverrideSpecified) {
        $newResultParams.PackageVersionSelector = $normalizedPackageVersion
    }
    $result = New-PackageResult @newResultParams

    if ([string]::Equals($DesiredState, 'Removed', [System.StringComparison]::OrdinalIgnoreCase)) {
        $result = Invoke-PackageRemovedFlow -PackageResult $result
        $failedStep = if ([string]::Equals([string]$result.Status, 'Failed', [System.StringComparison]::OrdinalIgnoreCase)) { [string]$result.CurrentStep } else { $null }
        $completedResult = Complete-PackageResult -PackageResult $result
        if ([string]::Equals([string]$completedResult.Status, 'Failed', [System.StringComparison]::OrdinalIgnoreCase) -and [string]::IsNullOrWhiteSpace($failedStep)) {
            $failedStep = [string]$result.CurrentStep
        }
        Add-PackageOperationHistoryRecord -PackageConfig $packageConfig -PackageResult $completedResult -FailedStep $failedStep
        return $completedResult
    }

    $result = Invoke-PackageAssignedFlow -PackageResult $result -DependencyStack $DependencyStack
    $failedStep = if ([string]::Equals([string]$result.Status, 'Failed', [System.StringComparison]::OrdinalIgnoreCase)) { [string]$result.CurrentStep } else { $null }
    $completedResult = Complete-PackageResult -PackageResult $result
    if ([string]::Equals([string]$completedResult.Status, 'Failed', [System.StringComparison]::OrdinalIgnoreCase) -and [string]::IsNullOrWhiteSpace($failedStep)) {
        $failedStep = [string]$result.CurrentStep
    }
    Add-PackageOperationHistoryRecord -PackageConfig $packageConfig -PackageResult $completedResult -FailedStep $failedStep
    return $completedResult
}
