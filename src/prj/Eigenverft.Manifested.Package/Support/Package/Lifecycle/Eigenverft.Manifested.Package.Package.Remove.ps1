<#
    Eigenverft.Manifested.Package.Package.Remove - DesiredState Removed orchestration.
    Dot-sourced from Eigenverft.Manifested.Package.psm1 after Package.CommandFlow.ps1.

    Removal safety: other inventory rows are scanned by loading each row's assigned
    definition snapshot and matching dependencies against the target definition.
    Persisted dependencyInstallSlotIds on inventory rows (see Update-PackageInventoryRecord)
    documents direct dependency slots for operators; blocking is driven by definition
    metadata so stale slot lists cannot bypass the check.
#>

function Get-PackageInventoryDependentBlockingRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig,

        [Parameter(Mandatory = $true)]
        [string]$ExcludeInstallSlotId,

        [Parameter(Mandatory = $true)]
        [string]$TargetPublisherId,

        [Parameter(Mandatory = $true)]
        [string]$TargetDefinitionId
    )

    $index = Get-PackageInventory -PackageConfig $PackageConfig
    $blockers = New-Object System.Collections.Generic.List[object]

    foreach ($record in @($index.Records)) {
        $slot = [string]$record.installSlotId
        if ([string]::Equals($slot, $ExcludeInstallSlotId, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $parentPublisherId = if ($record.PSObject.Properties['definitionPublisherId'] -and -not [string]::IsNullOrWhiteSpace([string]$record.definitionPublisherId)) {
            [string]$record.definitionPublisherId
        }
        else { $null }
        $parentDefinitionId = [string]$record.definitionId
        $parentSnapshotPath = if ($record.PSObject.Properties['definitionAssignedSnapshotPath'] -and -not [string]::IsNullOrWhiteSpace([string]$record.definitionAssignedSnapshotPath)) {
            [string]$record.definitionAssignedSnapshotPath
        }
        else {
            $null
        }

        if ([string]::IsNullOrWhiteSpace($parentSnapshotPath) -or -not (Test-Path -LiteralPath $parentSnapshotPath -PathType Leaf)) {
            throw "Package removal dependency scan failed for inventory installSlotId '$slot': assigned definition snapshot is missing."
        }

        try {
            $definitionDocumentInfo = Read-PackageJsonDocument -Path $parentSnapshotPath
            Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionDocumentInfo -DefinitionId $parentDefinitionId -PublisherId $parentPublisherId
        }
        catch {
            throw "Package removal dependency scan failed while reading assigned definition snapshot '$parentSnapshotPath' for inventory installSlotId '$slot': $($_.Exception.Message)"
        }

        $definition = $definitionDocumentInfo.Document
        if (-not $definition.PSObject.Properties['dependencies'] -or $null -eq $definition.dependencies) {
            continue
        }

        foreach ($dependency in @($definition.dependencies)) {
            if ($null -eq $dependency) {
                continue
            }

            $depDefinitionId = if ($dependency.PSObject.Properties['definitionId']) { [string]$dependency.definitionId } else { $null }
            if ([string]::IsNullOrWhiteSpace($depDefinitionId)) {
                continue
            }

            $depPublisherId = if ($dependency.PSObject.Properties['publisherId'] -and -not [string]::IsNullOrWhiteSpace([string]$dependency.publisherId)) {
                [string]$dependency.publisherId
            }
            else {
                $null
            }

            $definitionMatches = [string]::Equals($depDefinitionId, $TargetDefinitionId, [System.StringComparison]::OrdinalIgnoreCase)
            $publisherMatches = [string]::IsNullOrWhiteSpace($depPublisherId) -or
                [string]::Equals($depPublisherId, $TargetPublisherId, [System.StringComparison]::OrdinalIgnoreCase)
            if ($definitionMatches -and $publisherMatches) {
                $blockers.Add([pscustomobject]@{
                    DependentInstallSlotId = $slot
                    DependentDefinitionId  = $parentDefinitionId
                    DependentPublisherId   = $parentPublisherId
                }) | Out-Null
                break
            }
        }
    }

    return @($blockers.ToArray())
}

function Assert-PackageRemovalDependencyDependents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if ($PackageResult.PSObject.Properties['InventoryRemovalSkipped'] -and [bool]$PackageResult.InventoryRemovalSkipped) {
        return $PackageResult
    }

    $targetPublisherId = Get-PackageResultPublisherId -PackageResult $PackageResult
    $targetDefinitionId = [string]$PackageResult.DefinitionId
    $excludeSlotId = Get-PackageInstallSlotId -PackageResult $PackageResult
    $blockers = @(Get-PackageInventoryDependentBlockingRecords -PackageConfig $PackageResult.PackageConfig -ExcludeInstallSlotId $excludeSlotId -TargetPublisherId $targetPublisherId -TargetDefinitionId $targetDefinitionId)
    if ($blockers.Count -gt 0) {
        $summaries = @(
            foreach ($b in @($blockers)) {
                "'$($b.DependentPublisherId)/$($b.DependentDefinitionId)' (installSlotId=$($b.DependentInstallSlotId))"
            }
        )
        throw ("Package removal blocked: '{0}/{1}' is still declared as a dependency by installed package(s): {2}. Remove those packages first (or implement removeDependencies)." -f $targetPublisherId, $targetDefinitionId, ($summaries -join '; '))
    }

    return $PackageResult
}

function Get-PackageExistingInstallSearchLocationById {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition,

        [Parameter(Mandatory = $true)]
        [string]$SearchLocationId
    )

    $discovery = $Definition.discovery.existingInstall
    if (-not $discovery -or -not $discovery.PSObject.Properties['searchLocations']) {
        $label = if ($Definition.PSObject.Properties['definitionPublication'] -and $Definition.definitionPublication.PSObject.Properties['definitionId']) { [string]$Definition.definitionPublication.definitionId } else { '<unknown>' }
        throw "Package definition '$label' is missing discovery.existingInstall.searchLocations required for removal uninstall discovery."
    }

    foreach ($searchLocation in @(Get-PackageExistingInstallSearchLocations -SearchLocations @($discovery.searchLocations))) {
        if ($searchLocation.PSObject.Properties['id'] -and
            [string]::Equals([string]$searchLocation.id, $SearchLocationId, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $searchLocation
        }
    }

    $label = if ($Definition.PSObject.Properties['definitionPublication'] -and $Definition.definitionPublication.PSObject.Properties['definitionId']) { [string]$Definition.definitionPublication.definitionId } else { '<unknown>' }
    throw "Package definition '$label' has no discovery.existingInstall.searchLocations entry with id '$SearchLocationId'."
}

function Get-PackageUninstallExecutableAndArgumentTail {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$RawText
    )

    if ([string]::IsNullOrWhiteSpace($RawText)) {
        return [pscustomobject]@{
            Executable     = $null
            ArgumentTokens = @()
        }
    }

    $expanded = [Environment]::ExpandEnvironmentVariables(([string]$RawText).Trim())
    $exe = Get-WindowsRegistryExecutablePathFromText -Text $expanded
    if ([string]::IsNullOrWhiteSpace($exe)) {
        return [pscustomobject]@{
            Executable     = $null
            ArgumentTokens = @()
        }
    }

    $idx = $expanded.IndexOf($exe, [System.StringComparison]::OrdinalIgnoreCase)
    $tailStart = if ($idx -lt 0) { -1 } else { $idx + $exe.Length }
    if ($tailStart -ge 0 -and
        $idx -gt 0 -and
        $expanded[$idx - 1] -eq '"' -and
        $expanded.Length -gt $tailStart -and
        $expanded[$tailStart] -eq '"') {
        $tailStart++
    }

    $after = if ($tailStart -lt 0) { '' } else { $expanded.Substring($tailStart).Trim() }
    $tokens = if ([string]::IsNullOrWhiteSpace($after)) {
        @()
    }
    else {
        @($after -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    return [pscustomobject]@{
        Executable     = $exe
        ArgumentTokens = @($tokens)
    }
}

function ConvertFrom-PackageAssignmentInventoryPathRegistrationRecord {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$PathRegistrationRecord
    )

    if ($null -eq $PathRegistrationRecord) {
        return $null
    }

    $sourceValues = if ($PathRegistrationRecord.PSObject.Properties['sourceValues'] -and $null -ne $PathRegistrationRecord.sourceValues) {
        @($PathRegistrationRecord.sourceValues | ForEach-Object { [string]$_ })
    }
    else {
        @()
    }

    $cleanupDirectories = if ($PathRegistrationRecord.PSObject.Properties['cleanupDirectories'] -and $null -ne $PathRegistrationRecord.cleanupDirectories) {
        @($PathRegistrationRecord.cleanupDirectories | ForEach-Object { [string]$_ })
    }
    else {
        @()
    }

    return [pscustomobject]@{
        Status             = if ($PathRegistrationRecord.PSObject.Properties['status']) { [string]$PathRegistrationRecord.status } else { $null }
        Mode               = if ($PathRegistrationRecord.PSObject.Properties['mode']) { [string]$PathRegistrationRecord.mode } else { $null }
        SourceKind         = if ($PathRegistrationRecord.PSObject.Properties['sourceKind']) { [string]$PathRegistrationRecord.sourceKind } else { $null }
        SourceValue        = if ($PathRegistrationRecord.PSObject.Properties['sourceValue']) { [string]$PathRegistrationRecord.sourceValue } else { $null }
        SourceValues       = @($sourceValues)
        SourcePath         = if ($PathRegistrationRecord.PSObject.Properties['sourcePath']) { [string]$PathRegistrationRecord.sourcePath } else { $null }
        RegisteredPath     = if ($PathRegistrationRecord.PSObject.Properties['registeredPath']) { [string]$PathRegistrationRecord.registeredPath } else { $null }
        CleanupDirectories = @($cleanupDirectories)
        CleanedTargets     = @()
        UpdatedTargets     = @()
    }
}

function Resolve-PackageRemovalInstallContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $definition = $PackageResult.PackageConfig.Definition
    $removed = $definition.packageOperations.removed
    $policy = $removed.policy
    $index = Get-PackageInventory -PackageConfig $PackageResult.PackageConfig
    $installSlotId = Get-PackageInstallSlotId -PackageResult $PackageResult

    $record = $null
    foreach ($candidate in @($index.Records)) {
        if ([string]::Equals([string]$candidate.installSlotId, $installSlotId, [System.StringComparison]::OrdinalIgnoreCase)) {
            $record = $candidate
            break
        }
    }

    if ($null -eq $record) {
        if ([string]::Equals([string]$policy.whenNotInInventory, 'fail', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Package removal failed for '$($PackageResult.DefinitionId)': no inventory record for install slot '$installSlotId' and policy.whenNotInInventory is 'fail'."
        }

        $PackageResult | Add-Member -Force -MemberType NoteProperty -Name 'InventoryRemovalSkipped' -Value $true
        Write-PackageExecutionMessage -Message ("[STATE] Removal skipped destructive work: no inventory record for install slot '{0}' (whenNotInInventory='succeed')." -f $installSlotId)
        return $PackageResult
    }

    $PackageResult | Add-Member -Force -MemberType NoteProperty -Name 'InventoryRemovalSkipped' -Value $false

    if ([string]::IsNullOrWhiteSpace([string]$record.installDirectory)) {
        throw "Package removal failed for '$($PackageResult.DefinitionId)': inventory record is missing installDirectory."
    }

    $normalizedInstallDirectory = [System.IO.Path]::GetFullPath([string]$record.installDirectory)
    $PackageResult.InstallDirectory = $normalizedInstallDirectory

    $ownershipKind = if ($record.PSObject.Properties['ownershipKind']) { [string]$record.ownershipKind } else { $null }
    $installOrigin = switch -Exact ($ownershipKind) {
        'PackageInstalled' { 'PackageInstalled'; break }
        'PackageApplied' { 'PackageApplied'; break }
        'AdoptedExternal' { 'AdoptedExternal'; break }
        default { $ownershipKind }
    }
    $PackageResult.InstallOrigin = $installOrigin

    $PackageResult.Ownership = [pscustomobject]@{
        InventoryPath   = $index.Path
        InstallSlotId   = $installSlotId
        Classification  = 'PackageTarget'
        OwnershipRecord = $record
    }

    $PackageResult.ExistingPackage = [pscustomobject]@{
        SearchKind       = 'packageTargetInstallPath'
        CandidatePath    = $normalizedInstallDirectory
        InstallDirectory = $normalizedInstallDirectory
        Decision         = 'Pending'
        Readiness       = $null
        Classification   = 'PackageTarget'
        OwnershipRecord  = $record
    }

    $pathRegistration = if ($record.PSObject.Properties['pathRegistration'] -and $null -ne $record.pathRegistration) {
        ConvertFrom-PackageAssignmentInventoryPathRegistrationRecord -PathRegistrationRecord $record.pathRegistration
    }
    else {
        $null
    }

    if ($pathRegistration) {
        if ($PackageResult.PSObject.Properties['PathRegistration']) {
            $PackageResult.PathRegistration = $pathRegistration
        }
        else {
            $PackageResult | Add-Member -MemberType NoteProperty -Name PathRegistration -Value $pathRegistration
        }
    }

    Write-PackageExecutionMessage -Message ("[STATE] Removal inventory context: installSlotId='{0}', installDirectory='{1}', ownershipKind='{2}'." -f $installSlotId, $normalizedInstallDirectory, $ownershipKind)

    return $PackageResult
}

function Assert-PackageRemovalPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $definition = $PackageResult.PackageConfig.Definition
    $policy = $definition.packageOperations.removed.policy

    if ($policy.removeDependencies -is [bool] -and [bool]$policy.removeDependencies) {
        throw "Package removal for '$($PackageResult.DefinitionId)' requested policy.removeDependencies=true, which is not implemented yet. Set removeDependencies to false for v1 removal."
    }

    if ($PackageResult.PSObject.Properties['InventoryRemovalSkipped'] -and [bool]$PackageResult.InventoryRemovalSkipped) {
        return $PackageResult
    }

    $record = $PackageResult.Ownership.OwnershipRecord
    $allowedKinds = @($policy.allowedInventoryOwnershipKinds | ForEach-Object { [string]$_ })
    $kind = if ($record -and $record.PSObject.Properties['ownershipKind']) { [string]$record.ownershipKind } else { $null }
    if ([string]::IsNullOrWhiteSpace($kind)) {
        throw "Package removal failed for '$($PackageResult.DefinitionId)': inventory record is missing ownershipKind."
    }

    $allowed = $false
    foreach ($allowedKind in @($allowedKinds)) {
        if ([string]::Equals($allowedKind, $kind, [System.StringComparison]::OrdinalIgnoreCase)) {
            $allowed = $true
            break
        }
    }

    if (-not $allowed) {
        throw "Package removal failed for '$($PackageResult.DefinitionId)': inventory ownershipKind '$kind' is not allowed by removed.policy.allowedInventoryOwnershipKinds."
    }

    return $PackageResult
}

function Test-PackageProcessArgumentPresent {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string[]]$Arguments,

        [AllowNull()]
        [string]$Argument
    )

    if ([string]::IsNullOrWhiteSpace($Argument)) {
        return $true
    }

    $normalizedArgument = ([string]$Argument).Trim().Trim('"')
    foreach ($existingArgument in @($Arguments)) {
        if ([string]::Equals(([string]$existingArgument).Trim().Trim('"'), $normalizedArgument, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Invoke-PackageTrackedInstallDirectoryRemoval {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [AllowNull()]
        [string]$Reason
    )

    $target = [string]$PackageResult.InstallDirectory
    if ([string]::IsNullOrWhiteSpace($target)) {
        throw "Package removed operation 'deleteInstallDirectory' requires a resolved inventory installDirectory."
    }

    if (Test-Path -LiteralPath $target) {
        Remove-PathIfExists -Path $target | Out-Null
        $reasonText = if ([string]::IsNullOrWhiteSpace($Reason)) { '' } else { " ($Reason)" }
        Write-PackageExecutionMessage -Message ("[ACTION] Deleted tracked install directory '{0}'{1}." -f $target, $reasonText)
    }
    else {
        Write-PackageExecutionMessage -Message ("[STATE] tracked install directory removal skipped; path does not exist: '{0}'." -f $target)
    }

    $ceiling = Get-EmptyParentPruneCeilingDirectory -InstallLeafPath $target -PreferredInstallRootDirectory ([string]$PackageResult.PackageConfig.PreferredTargetInstallRootDirectory)
    if (-not [string]::IsNullOrWhiteSpace($ceiling)) {
        Remove-EmptyParentDirectoryChain -DeletedLeafPath $target -AncestorCeilingDirectory $ceiling
        Write-PackageExecutionMessage -Message '[ACTION] Pruned empty parent directories after tracked install directory removal (up to configured install root when under it, otherwise up to volume or share root).'
    }
    else {
        Write-PackageExecutionMessage -Level 'WRN' -Message '[WARN] Could not resolve empty-parent prune ceiling; skipping prune after tracked install directory removal.'
    }

    return $PackageResult
}

function Invoke-PackageRegistryUninstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [psobject]$Operation,

        [Parameter(Mandatory = $true)]
        [string]$InstallerKind
    )

    $definition = $PackageResult.PackageConfig.Definition
    $searchLocation = Get-PackageExistingInstallSearchLocationById -Definition $definition -SearchLocationId ([string]$Operation.commandSource.searchLocationId)
    $resolved = Resolve-PackageExistingUninstallRegistryCandidate -SearchLocation $searchLocation -PackageResult $PackageResult
    if (-not $resolved -or -not $resolved.RegistryEntry) {
        return [pscustomobject]@{
            Status        = 'CommandNotFound'
            InstallerKind = $InstallerKind
            CommandPath   = $null
        }
    }

    $entry = $resolved.RegistryEntry
    $chosenText = $null
    foreach ($registryValueName in @($Operation.commandSource.registryValueOrder)) {
        $prop = if ([string]::Equals([string]$registryValueName, 'QuietUninstallString', [System.StringComparison]::OrdinalIgnoreCase)) {
            'QuietUninstallString'
        }
        else {
            'UninstallString'
        }
        if (-not $entry.PSObject.Properties[$prop]) {
            continue
        }
        $text = [string]$entry.$prop
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            $chosenText = $text
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($chosenText)) {
        return [pscustomobject]@{
            Status        = 'CommandNotFound'
            InstallerKind = $InstallerKind
            CommandPath   = $null
        }
    }

    $parsed = Get-PackageUninstallExecutableAndArgumentTail -RawText $chosenText
    if ([string]::IsNullOrWhiteSpace($parsed.Executable) -or -not (Test-Path -LiteralPath $parsed.Executable -PathType Leaf)) {
        return [pscustomobject]@{
            Status        = 'CommandNotFound'
            InstallerKind = $InstallerKind
            CommandPath   = $parsed.Executable
        }
    }

    $argumentTexts = New-Object System.Collections.Generic.List[string]
    $commandArguments = New-Object System.Collections.Generic.List[string]
    foreach ($token in @($parsed.ArgumentTokens)) {
        $argumentTexts.Add([string]$token) | Out-Null
        $commandArguments.Add((Format-PackageProcessArgument -Value $token)) | Out-Null
    }

    foreach ($argument in @($Operation.commandArguments)) {
        $resolvedArgument = Resolve-PackageTemplateText -Text ([string]$argument) -PackageConfig $PackageResult.PackageConfig -Package $PackageResult.Package -ExtraTokens @{
            packageFilePath                = $PackageResult.PackageFilePath
            installDirectory               = $PackageResult.InstallDirectory
            packageFileStagingDirectory    = $PackageResult.PackageFileStagingDirectory
            packageInstallStageDirectory   = $PackageResult.PackageInstallStageDirectory
            downloadDirectory              = $PackageResult.PackageFileStagingDirectory
        }
        if (Test-PackageProcessArgumentPresent -Arguments @($argumentTexts.ToArray()) -Argument $resolvedArgument) {
            continue
        }
        $argumentTexts.Add([string]$resolvedArgument) | Out-Null
        $commandArguments.Add((Format-PackageProcessArgument -Value $resolvedArgument)) | Out-Null
    }

    $timeoutSec = [int]$Operation.timeoutSec
    $successExitCodes = @($Operation.successExitCodes | ForEach-Object { [int]$_ })
    $restartExitCodes = @($Operation.restartExitCodes | ForEach-Object { [int]$_ })
    $uiMode = [string]$Operation.uiMode
    $workingDirectory = if (-not [string]::IsNullOrWhiteSpace([string]$PackageResult.InstallDirectory) -and (Test-Path -LiteralPath $PackageResult.InstallDirectory -PathType Container)) {
        [string]$PackageResult.InstallDirectory
    }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$PackageResult.PackageInstallStageDirectory)) {
        [string]$PackageResult.PackageInstallStageDirectory
    }
    else {
        [System.IO.Path]::GetTempPath()
    }

    $elevationMode = if ($Operation.PSObject.Properties['elevation'] -and -not [string]::IsNullOrWhiteSpace([string]$Operation.elevation)) {
        [string]$Operation.elevation
    }
    else {
        $null
    }

    $null = Invoke-PackageInstallerCommand -PackageResult $PackageResult -CommandPath $parsed.Executable -CommandArguments @($commandArguments.ToArray()) -WorkingDirectory $workingDirectory -TimeoutSec $timeoutSec -SuccessExitCodes @($successExitCodes) -RestartExitCodes @($restartExitCodes) -TargetKind 'directory' -InstallerKind $InstallerKind -UiMode $uiMode -LogPath $null -ElevationMode $elevationMode
    Write-PackageExecutionMessage -Message ("[ACTION] Completed {0} uninstall command '{1}'." -f $InstallerKind, $parsed.Executable)

    return [pscustomobject]@{
        Status        = 'Invoked'
        InstallerKind = $InstallerKind
        CommandPath   = $parsed.Executable
    }
}

function Invoke-PackageMsiRegistryUninstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [psobject]$Operation
    )

    $definition = $PackageResult.PackageConfig.Definition
    $searchLocation = Get-PackageExistingInstallSearchLocationById -Definition $definition -SearchLocationId ([string]$Operation.commandSource.searchLocationId)
    $resolved = Resolve-PackageExistingUninstallRegistryCandidate -SearchLocation $searchLocation -PackageResult $PackageResult
    if (-not $resolved -or -not $resolved.RegistryEntry) {
        return [pscustomobject]@{
            Status        = 'CommandNotFound'
            InstallerKind = 'msi'
            CommandPath   = $null
            ProductCode   = $null
        }
    }

    $productCode = Get-WindowsInstallerProductCodeFromUninstallEntry -Entry $resolved.RegistryEntry
    if ([string]::IsNullOrWhiteSpace($productCode)) {
        return [pscustomobject]@{
            Status        = 'CommandNotFound'
            InstallerKind = 'msi'
            CommandPath   = $null
            ProductCode   = $null
        }
    }

    $commandPath = Get-PackageWindowsInstallerExecutablePath
    $argumentTexts = New-Object System.Collections.Generic.List[string]
    $commandArguments = New-Object System.Collections.Generic.List[string]
    foreach ($argument in @('/x', $productCode)) {
        $argumentTexts.Add([string]$argument) | Out-Null
        $commandArguments.Add((Format-PackageProcessArgument -Value $argument)) | Out-Null
    }

    foreach ($argument in @($Operation.commandArguments)) {
        $resolvedArgument = Resolve-PackageTemplateText -Text ([string]$argument) -PackageConfig $PackageResult.PackageConfig -Package $PackageResult.Package -ExtraTokens @{
            packageFilePath                = $PackageResult.PackageFilePath
            installDirectory               = $PackageResult.InstallDirectory
            packageFileStagingDirectory    = $PackageResult.PackageFileStagingDirectory
            packageInstallStageDirectory   = $PackageResult.PackageInstallStageDirectory
            downloadDirectory              = $PackageResult.PackageFileStagingDirectory
        }
        if (Test-PackageProcessArgumentPresent -Arguments @($argumentTexts.ToArray()) -Argument $resolvedArgument) {
            continue
        }
        $argumentTexts.Add([string]$resolvedArgument) | Out-Null
        $commandArguments.Add((Format-PackageProcessArgument -Value $resolvedArgument)) | Out-Null
    }

    $timeoutSec = [int]$Operation.timeoutSec
    $successExitCodes = @($Operation.successExitCodes | ForEach-Object { [int]$_ })
    $restartExitCodes = @($Operation.restartExitCodes | ForEach-Object { [int]$_ })
    $uiMode = [string]$Operation.uiMode
    $workingDirectory = if (-not [string]::IsNullOrWhiteSpace([string]$PackageResult.InstallDirectory) -and (Test-Path -LiteralPath $PackageResult.InstallDirectory -PathType Container)) {
        [string]$PackageResult.InstallDirectory
    }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$PackageResult.PackageInstallStageDirectory)) {
        [string]$PackageResult.PackageInstallStageDirectory
    }
    else {
        [System.IO.Path]::GetTempPath()
    }

    $elevationMode = if ($Operation.PSObject.Properties['elevation'] -and -not [string]::IsNullOrWhiteSpace([string]$Operation.elevation)) {
        [string]$Operation.elevation
    }
    else {
        $null
    }

    $null = Invoke-PackageInstallerCommand -PackageResult $PackageResult -CommandPath $commandPath -CommandArguments @($commandArguments.ToArray()) -WorkingDirectory $workingDirectory -TimeoutSec $timeoutSec -SuccessExitCodes @($successExitCodes) -RestartExitCodes @($restartExitCodes) -TargetKind 'directory' -InstallerKind 'msi' -UiMode $uiMode -LogPath $null -ElevationMode $elevationMode
    Write-PackageExecutionMessage -Message ("[ACTION] Completed MSI uninstall for product code '{0}'." -f $productCode)

    return [pscustomobject]@{
        Status        = 'Invoked'
        InstallerKind = 'msi'
        CommandPath   = $commandPath
        ProductCode   = $productCode
    }
}

function Invoke-PackageRemovedOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $definition = $PackageResult.PackageConfig.Definition
    $operation = $definition.packageOperations.removed.operation
    $kind = [string]$operation.kind

    if ($PackageResult.PSObject.Properties['InventoryRemovalSkipped'] -and [bool]$PackageResult.InventoryRemovalSkipped) {
        Write-PackageExecutionMessage -Message '[STATE] Removed operation skipped because no inventory record was found.'
        return $PackageResult
    }

    switch -Exact ($kind) {
        'none' {
            Write-PackageExecutionMessage -Message '[STATE] Removed operation kind is none; nothing to execute.'
        }
        'deleteInstallDirectory' {
            $PackageResult = Invoke-PackageTrackedInstallDirectoryRemoval -PackageResult $PackageResult -Reason 'removed.operation.kind=deleteInstallDirectory'
        }
        { $_ -in @('nsisUninstaller', 'innoSetupUninstaller') } {
            $installerKind = if ([string]::Equals($kind, 'innoSetupUninstaller', [System.StringComparison]::OrdinalIgnoreCase)) { 'innoSetup' } else { 'nsis' }
            $uninstallResult = Invoke-PackageRegistryUninstaller -PackageResult $PackageResult -Operation $operation -InstallerKind $installerKind
            if ([string]::Equals([string]$uninstallResult.Status, 'CommandNotFound', [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Original installer uninstall command was not found for '{0}'; falling back to tracked install directory removal." -f $PackageResult.DefinitionId)
                $PackageResult = Invoke-PackageTrackedInstallDirectoryRemoval -PackageResult $PackageResult -Reason 'installer uninstall command not found'
            }
        }
        'msiUninstaller' {
            $uninstallResult = Invoke-PackageMsiRegistryUninstaller -PackageResult $PackageResult -Operation $operation
            if ([string]::Equals([string]$uninstallResult.Status, 'CommandNotFound', [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "MSI uninstall registry entry or product code was not found for '$($PackageResult.DefinitionId)'; refusing to delete the tracked install directory without Windows Installer."
            }
        }
        default {
            throw "Unsupported removed.operation.kind '$kind'."
        }
    }

    return $PackageResult
}

function Invoke-PackagePostRemoveCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $flags = $PackageResult.PackageConfig.Definition.packageOperations.removed.postRemoveCleanup

    if ($flags.generatedShims) {
        $null = Remove-PackageCommandShimsForDefinition -PackageResult $PackageResult
    }
    else {
        Write-PackageExecutionMessage -Message '[STATE] postRemoveCleanup.generatedShims is false; skipping shim removal.'
    }

    if ($flags.pathEntries) {
        $null = Unregister-PackagePathForRemoval -PackageResult $PackageResult
    }
    else {
        Write-PackageExecutionMessage -Message '[STATE] postRemoveCleanup.pathEntries is false; skipping PATH cleanup.'
    }

    if ($flags.packageInventoryRecord) {
        if ($PackageResult.PSObject.Properties['InventoryRemovalSkipped'] -and [bool]$PackageResult.InventoryRemovalSkipped) {
            Write-PackageExecutionMessage -Message '[STATE] postRemoveCleanup.packageInventoryRecord skipped because there was no inventory record.'
        }
        else {
            $null = Remove-PackageInventoryRecordForInstallSlot -PackageResult $PackageResult
        }
    }
    else {
        Write-PackageExecutionMessage -Message '[STATE] postRemoveCleanup.packageInventoryRecord is false; skipping inventory record removal.'
    }

    if ($flags.workDirectories) {
        $null = Clear-PackageWorkDirectories -PackageResult $PackageResult
    }
    else {
        Write-PackageExecutionMessage -Message '[STATE] postRemoveCleanup.workDirectories is false; skipping staging directory cleanup.'
    }

    return $PackageResult
}

function Invoke-PackageRemovedFlow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    try {
        Write-PackageExecutionMessage -Message ("[START] Invoke-Package publisher='{0}' endpoint='{1}' definition='{2}' desiredState='{3}'." -f $PackageResult.DefinitionPublisherId, $PackageResult.DefinitionEndpointName, $PackageResult.DefinitionId, $PackageResult.DesiredState)

        if (-not $PackageResult.LocalEnvironment) {
            $PackageResult.CurrentStep = 'InitializeLocalEnvironment'
            $PackageResult.LocalEnvironment = Initialize-PackageCommandLocalEnvironment -PackageConfig $PackageResult.PackageConfig
        }

        $PackageResult.CurrentStep = 'ResolvePackage'
        Write-PackageExecutionMessage -Message '[STEP] Resolving package selection.'
        $PackageResult = Resolve-PackagePackage -PackageResult $PackageResult

        $PackageResult.CurrentStep = 'ResolvePaths'
        Write-PackageExecutionMessage -Message '[STEP] Resolving package paths.'
        $PackageResult = Resolve-PackagePaths -PackageResult $PackageResult

        $PackageResult.CurrentStep = 'ResolveRemovalInstallContext'
        Write-PackageExecutionMessage -Message '[STEP] Resolving removal inventory context.'
        $PackageResult = Resolve-PackageRemovalInstallContext -PackageResult $PackageResult

        $PackageResult.CurrentStep = 'AssertRemovalPolicy'
        Write-PackageExecutionMessage -Message '[STEP] Evaluating removal policy.'
        $PackageResult = Assert-PackageRemovalPolicy -PackageResult $PackageResult

        $PackageResult.CurrentStep = 'AssertRemovalDependencyDependents'
        Write-PackageExecutionMessage -Message '[STEP] Checking for installed packages that still declare this package as a dependency.'
        $PackageResult = Assert-PackageRemovalDependencyDependents -PackageResult $PackageResult

        $PackageResult.CurrentStep = 'ExecuteRemovedOperation'
        Write-PackageExecutionMessage -Message '[STEP] Executing removed.operation.'
        $PackageResult = Invoke-PackageRemovedOperation -PackageResult $PackageResult

        $PackageResult.CurrentStep = 'VerifyRemovedAbsence'
        Write-PackageExecutionMessage -Message '[STEP] Verifying removed absence.'
        $PackageResult = Test-PackageRemovedAbsence -PackageResult $PackageResult

        $PackageResult.CurrentStep = 'PostRemoveCleanup'
        Write-PackageExecutionMessage -Message '[STEP] Running post-remove cleanup.'
        $PackageResult = Invoke-PackagePostRemoveCleanup -PackageResult $PackageResult

        Write-PackageExecutionMessage -Message ("[OK] Package removal completed for definition '{0}'." -f $PackageResult.DefinitionId)
    }
    catch {
        $PackageResult.Status = 'Failed'
        $PackageResult.ErrorMessage = $_.Exception.Message
        Write-PackageExecutionMessage -Level 'ERR' -Message ("[FAIL] Step '{0}' failed: {1}" -f $PackageResult.CurrentStep, $_.Exception.Message)
        $PackageResult.FailureReason = Get-PackageCommandFailureReason -CurrentStep ([string]$PackageResult.CurrentStep)
    }

    return $PackageResult
}
