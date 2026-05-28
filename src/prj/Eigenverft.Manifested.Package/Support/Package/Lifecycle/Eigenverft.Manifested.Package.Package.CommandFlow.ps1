<#
    Eigenverft.Manifested.Package.Package.CommandFlow
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
        'DistributePackageFileToDepots' { return 'DepotDistributionFailed' }
        'MaterializeNpmPackage' { return 'NpmMaterializationFailed' }
        'AssertDurableMaterialization' { return 'PackageMaterializationNotDurable' }
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

function Initialize-PackageCommandLocalEnvironment {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$PackageConfig = $null
    )

    Write-PackageExecutionMessage -Message '[STEP] Initializing local package environment.'
    $initializeParams = @{}
    if ($null -ne $PackageConfig) {
        $initializeParams.PackageConfig = $PackageConfig
    }
    $localEnvironment = Initialize-PackageLocalEnvironment @initializeParams
    if ($localEnvironment.InitializedNow) {
        Write-PackageExecutionMessage -Message ("[STATE] Local package environment initialized: created={0}, existing={1}, skippedSources={2}." -f @($localEnvironment.CreatedDirectories).Count, @($localEnvironment.ExistingDirectories).Count, @($localEnvironment.SkippedSources).Count)
    }
    else {
        Write-PackageExecutionMessage -Message '[STATE] Local package environment already initialized.'
    }

    return $localEnvironment
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
        if (-not $PackageResult.LocalEnvironment) {
            $PackageResult.CurrentStep = 'InitializeLocalEnvironment'
            $PackageResult.LocalEnvironment = Initialize-PackageCommandLocalEnvironment -PackageConfig $PackageResult.PackageConfig
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

function Find-PackageDurablePackageFileInDepot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if (-not $PackageResult.Package -or
        -not $PackageResult.Package.PSObject.Properties['packageFile'] -or
        -not $PackageResult.Package.packageFile -or
        -not $PackageResult.Package.packageFile.PSObject.Properties['fileName'] -or
        [string]::IsNullOrWhiteSpace([string]$PackageResult.Package.packageFile.fileName)) {
        return $null
    }

    $preferredVerification = Get-PackagePreferredVerification -AcquisitionCandidates @($PackageResult.AcquisitionPlan.Candidates)
    $packageFileName = [string]$PackageResult.Package.packageFile.fileName
    foreach ($depotSource in @(Get-PackagePackageDepotSources -PackageConfig $PackageResult.PackageConfig)) {
        if ([string]::IsNullOrWhiteSpace([string]$depotSource.basePath)) {
            continue
        }

        $candidateDirectory = [System.IO.Path]::GetFullPath((Join-Path ([string]$depotSource.basePath) $PackageResult.PackageDepotRelativeDirectory))
        $candidatePath = Join-Path $candidateDirectory $packageFileName
        if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
            continue
        }

        $verification = Test-PackageSavedFile -Path $candidatePath -Verification $preferredVerification
        if ($verification.Accepted) {
            return [pscustomobject]@{
                SourceId       = [string]$depotSource.id
                Path           = $candidatePath
                Verification   = $verification
            }
        }
    }

    return $null
}

function Assert-PackageMaterializationDurable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $requiresPackageFile = Test-PackagePackageFileAcquisitionRequired -Package $PackageResult.Package
    $npmMaterialized = Test-PackageNpmMaterializedInstallKind -Package $PackageResult.Package
    $durablePackageFile = $null
    $durableNpmMaterialization = $null

    if ($requiresPackageFile) {
        $durablePackageFile = Find-PackageDurablePackageFileInDepot -PackageResult $PackageResult
        if (-not $durablePackageFile) {
            throw "MaterializeOnly for '$($PackageResult.PackageId)' did not produce a verified package file in depot layout. Staging files alone are not durable materialization."
        }
    }

    if ($npmMaterialized) {
        $durableNpmMaterialization = Find-PackageNpmMaterializationInDepots -PackageResult $PackageResult
        if (-not $durableNpmMaterialization) {
            throw "MaterializeOnly for '$($PackageResult.PackageId)' did not produce npm materialized tarballs in depot layout. Staging files alone are not durable materialization."
        }
    }

    $PackageResult.InstallOrigin = 'MaterializedOnly'
    $PackageResult | Add-Member -MemberType NoteProperty -Name Materialization -Value ([pscustomobject]@{
        Success                = $true
        Status                 = if ($requiresPackageFile -or $npmMaterialized) { 'Durable' } else { 'NoDurableArtifactsRequired' }
        PackageFile            = $durablePackageFile
        NpmMaterialization     = $durableNpmMaterialization
        PackageFileRequired    = $requiresPackageFile
        NpmMaterializedPackage = $npmMaterialized
    }) -Force

    Write-PackageExecutionMessage -Message ("[STATE] Materialization durability accepted for package '{0}' with status '{1}'." -f $PackageResult.PackageId, [string]$PackageResult.Materialization.Status)
    return $PackageResult
}

function Invoke-PackageMaterializeOnlyFlow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [object[]]$DependencyStack = @()
    )

    $steps = @(
        [pscustomobject]@{ Name = 'ResolvePackage'; Message = '[STEP] Resolving package selection.'; Action = { param($r) Resolve-PackagePackage -PackageResult $r } },
        [pscustomobject]@{ Name = 'ResolveDependencies'; Message = '[STEP] Materializing package dependencies.'; Action = { param($r) Resolve-PackageDependencies -PackageResult $r -DependencyStack $DependencyStack } },
        [pscustomobject]@{ Name = 'ResolvePaths'; Message = '[STEP] Resolving package paths.'; Action = { param($r) Resolve-PackagePaths -PackageResult $r } },
        [pscustomobject]@{ Name = 'BuildAcquisitionPlan'; Message = '[STEP] Building acquisition plan.'; Action = { param($r) Build-PackageAcquisitionPlan -PackageResult $r } },
        [pscustomobject]@{ Name = 'PreparePackageAssignedFile'; Message = '[STEP] Materializing package file into staging.'; Action = { param($r) Resolve-PackageInstallFile -PackageResult $r } },
        [pscustomobject]@{ Name = 'DistributePackageFileToDepots'; Message = '[STEP] Reconciling package file depot mirrors.'; Action = { param($r) Invoke-PackageDepotDistribution -PackageResult $r } },
        [pscustomobject]@{ Name = 'MaterializeNpmPackage'; Message = '[STEP] Materializing npm package metadata and tarballs.'; Action = { param($r) Invoke-PackageNpmMaterialization -PackageResult $r } },
        [pscustomobject]@{ Name = 'AssertDurableMaterialization'; Message = '[STEP] Verifying durable depot materialization.'; Action = { param($r) Assert-PackageMaterializationDurable -PackageResult $r } },
        [pscustomobject]@{ Name = 'ClearPackageWorkDirectories'; Message = '[STEP] Cleaning package staging directories.'; Action = { param($r) Clear-PackageWorkDirectories -PackageResult $r } }
    )

    try {
        Write-PackageExecutionMessage -Message ("[START] Invoke-Package publisher='{0}' endpoint='{1}' definition='{2}' commandMode='MaterializeOnly' offline='{3}'." -f $PackageResult.DefinitionPublisherId, $PackageResult.DefinitionEndpointName, $PackageResult.DefinitionId, [bool]$PackageResult.Offline)
        if (-not $PackageResult.LocalEnvironment) {
            $PackageResult.CurrentStep = 'InitializeLocalEnvironment'
            $PackageResult.LocalEnvironment = Initialize-PackageCommandLocalEnvironment -PackageConfig $PackageResult.PackageConfig
        }

        foreach ($step in $steps) {
            $PackageResult.CurrentStep = $step.Name
            Write-PackageExecutionMessage -Message $step.Message
            $PackageResult = & $step.Action $PackageResult
            if ($step.Name -eq 'PreparePackageAssignedFile' -and
                $PackageResult.PackageFilePreparation -and
                $PackageResult.PackageFilePreparation.PSObject.Properties['Success'] -and
                -not [bool]$PackageResult.PackageFilePreparation.Success) {
                throw ([string]$PackageResult.PackageFilePreparation.ErrorMessage)
            }
        }

        Write-PackageExecutionMessage -Message ("[OK] Package materialized with status='{0}'." -f [string]$PackageResult.Materialization.Status)
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

        [switch]$AcceptUnknownSigningKey,

        [switch]$Offline,

        [switch]$MaterializeOnly,

        [object[]]$DependencyStack = @()
    )

    $packageVersionOverrideSpecified = $PSBoundParameters.ContainsKey('PackageVersion') -and -not [string]::IsNullOrWhiteSpace([string]$PackageVersion)
    $normalizedPackageVersion = if ($packageVersionOverrideSpecified) { ([string]$PackageVersion).Trim() } else { $null }

    if ([string]::Equals($DesiredState, 'Removed', [System.StringComparison]::OrdinalIgnoreCase) -and
        $packageVersionOverrideSpecified -and
        -not [string]::Equals($normalizedPackageVersion, 'latestByVersion', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Invoke-Package -PackageVersion can only override version selection for DesiredState Assigned. Omit -PackageVersion or use 'latestByVersion' with DesiredState Removed."
    }

    $localEnvironment = $null
    try {
        $localEnvironment = Initialize-PackageCommandLocalEnvironment
    }
    catch {
        Write-PackageExecutionMessage -Level 'ERR' -Message ("[FAIL] Step 'InitializeLocalEnvironment' failed: {0}" -f $_.Exception.Message)
        return [pscustomobject]@{
            OperationId                      = [guid]::NewGuid().ToString('n')
            OperationStartedAtUtc            = [DateTime]::UtcNow.ToString('o')
            DesiredState                     = $DesiredState
            CommandMode                      = if ($MaterializeOnly.IsPresent) { 'MaterializeOnly' } else { $DesiredState }
            Offline                          = [bool]$Offline
            MaterializeOnly                  = [bool]$MaterializeOnly
            PackageVersionOverrideSpecified  = $packageVersionOverrideSpecified
            PackageVersionSelectionSource    = if ($packageVersionOverrideSpecified) { 'command' } else { 'definition' }
            PackageVersionSelector           = $normalizedPackageVersion
            PublisherId                      = $PublisherId
            Status                           = 'Failed'
            FailureReason                    = 'LocalEnvironmentInitializationFailed'
            ErrorMessage                     = $_.Exception.Message
            CurrentStep                      = 'InitializeLocalEnvironment'
            DefinitionId                     = $DefinitionId
            LocalEnvironment                 = $localEnvironment
        }
    }

    $packageConfig = Get-PackageConfig -PublisherId $PublisherId -DefinitionId $DefinitionId -DesiredState $DesiredState -AcceptUnknownSigningKey:$AcceptUnknownSigningKey
    $newResultParams = @{
        DesiredState   = $DesiredState
        CommandMode    = if ($MaterializeOnly.IsPresent) { 'MaterializeOnly' } else { $DesiredState }
        Offline        = $Offline
        MaterializeOnly = $MaterializeOnly
        PackageConfig  = $packageConfig
    }
    if ($packageVersionOverrideSpecified) {
        $newResultParams.PackageVersionSelector = $normalizedPackageVersion
    }
    $result = New-PackageResult @newResultParams
    $result.LocalEnvironment = $localEnvironment

    if ($MaterializeOnly.IsPresent) {
        $result = Invoke-PackageMaterializeOnlyFlow -PackageResult $result -DependencyStack $DependencyStack
        $failedStep = if ([string]::Equals([string]$result.Status, 'Failed', [System.StringComparison]::OrdinalIgnoreCase)) { [string]$result.CurrentStep } else { $null }
        $completedResult = Complete-PackageResult -PackageResult $result
        if ([string]::Equals([string]$completedResult.Status, 'Failed', [System.StringComparison]::OrdinalIgnoreCase) -and [string]::IsNullOrWhiteSpace($failedStep)) {
            $failedStep = [string]$result.CurrentStep
        }
        Add-PackageOperationHistoryRecord -PackageConfig $packageConfig -PackageResult $completedResult -FailedStep $failedStep
        return $completedResult
    }

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
