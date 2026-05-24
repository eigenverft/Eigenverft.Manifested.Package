<#
    Eigenverft.Manifested.Sandbox.Package.Install - existing-install discovery, registry probe, and reuse/adopt decisions.
    Dot-sourced from Eigenverft.Manifested.Sandbox.psm1 (mirrored in TestImports.ps1) before Package.Install.ps1.
#>

function Resolve-PackageExistingInstallRoot {
<#
.SYNOPSIS
Resolves an install directory from a discovered existing-install candidate path.

.DESCRIPTION
Uses the existing-install root rules to turn a discovered file path such as
`code.cmd` into the install directory that owns that file.

.PARAMETER DiscoveryExistingInstall
The discovery.existingInstall definition object.

.PARAMETER CandidatePath
The discovered file or directory path.

.EXAMPLE
Resolve-PackageExistingInstallRoot -DiscoveryExistingInstall $packageConfig.Definition.discovery.existingInstall -CandidatePath $candidatePath
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DiscoveryExistingInstall,

        [Parameter(Mandatory = $true)]
        [string]$CandidatePath
    )

    if (Test-Path -LiteralPath $CandidatePath -PathType Container) {
        return (Resolve-Path -LiteralPath $CandidatePath -ErrorAction Stop).Path
    }

    $leafName = Split-Path -Leaf $CandidatePath
    foreach ($rule in @($DiscoveryExistingInstall.installRootRules)) {
        if (-not $rule.PSObject.Properties['match'] -or $null -eq $rule.match) {
            continue
        }

        $matchKind = if ($rule.match.PSObject.Properties['kind']) { [string]$rule.match.kind } else { $null }
        $matchValue = if ($rule.match.PSObject.Properties['value']) { [string]$rule.match.value } else { $null }
        if ([string]::Equals($matchKind, 'fileName', [System.StringComparison]::OrdinalIgnoreCase) -and
            [string]::Equals($matchValue, $leafName, [System.StringComparison]::OrdinalIgnoreCase)) {
            $candidateDirectory = Split-Path -Parent $CandidatePath
            $installRootRelativePath = if ($rule.PSObject.Properties['installRootRelativePath']) { [string]$rule.installRootRelativePath } else { '.' }
            return [System.IO.Path]::GetFullPath((Join-Path $candidateDirectory $installRootRelativePath))
        }
    }

    return (Split-Path -Parent $CandidatePath)
}

function Resolve-PackageExistingUninstallRegistryCandidate {
<#
.SYNOPSIS
Resolves an existing-install candidate from Windows uninstall registry keys.

.DESCRIPTION
Keeps Package JSON mapping separate from the generic registry helpers. The
search location provides concrete registry paths and the path source that should
be interpreted as the install directory.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$SearchLocation,

        [AllowNull()]
        [psobject]$PackageResult = $null
    )

    if (-not $SearchLocation.PSObject.Properties['installDirectorySource'] -or [string]::IsNullOrWhiteSpace([string]$SearchLocation.installDirectorySource)) {
        throw "Package discovery.existingInstall uninstall registry search is missing installDirectorySource."
    }

    $entries = New-Object System.Collections.Generic.List[object]
    switch -Exact ([string]$SearchLocation.kind) {
        'windowsUninstallRegistryKey' {
            if (-not $SearchLocation.PSObject.Properties['paths'] -or @($SearchLocation.paths).Count -eq 0) {
                throw "Package discovery.existingInstall windowsUninstallRegistryKey search is missing paths."
            }

            foreach ($registryPathTemplate in @($SearchLocation.paths | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
                $registryPath = if ($PackageResult) {
                    Resolve-PackageTemplateText -Text $registryPathTemplate -PackageConfig $PackageResult.PackageConfig -Package $PackageResult.Package
                }
                else {
                    $registryPathTemplate
                }
                $entry = Get-WindowsUninstallRegistryEntry -Path $registryPath
                if ($entry -and [string]::Equals([string]$entry.Status, 'Ready', [System.StringComparison]::OrdinalIgnoreCase)) {
                    $entries.Add($entry) | Out-Null
                }
            }
        }
        'windowsUninstallRegistrySearch' {
            if (-not $SearchLocation.PSObject.Properties['rootPaths'] -or @($SearchLocation.rootPaths).Count -eq 0) {
                throw "Package discovery.existingInstall windowsUninstallRegistrySearch search is missing rootPaths."
            }
            if (-not $SearchLocation.PSObject.Properties['displayNamePatterns'] -or @($SearchLocation.displayNamePatterns).Count -eq 0) {
                throw "Package discovery.existingInstall windowsUninstallRegistrySearch search is missing displayNamePatterns."
            }

            $rootPaths = @(
                foreach ($rootPathTemplate in @($SearchLocation.rootPaths)) {
                    if ([string]::IsNullOrWhiteSpace([string]$rootPathTemplate)) {
                        continue
                    }
                    if ($PackageResult) {
                        Resolve-PackageTemplateText -Text ([string]$rootPathTemplate) -PackageConfig $PackageResult.PackageConfig -Package $PackageResult.Package
                    }
                    else {
                        [string]$rootPathTemplate
                    }
                }
            )
            $displayNamePatterns = @(
                foreach ($pattern in @($SearchLocation.displayNamePatterns)) {
                    if ([string]::IsNullOrWhiteSpace([string]$pattern)) {
                        continue
                    }
                    if ($PackageResult) {
                        Resolve-PackageTemplateText -Text ([string]$pattern) -PackageConfig $PackageResult.PackageConfig -Package $PackageResult.Package
                    }
                    else {
                        [string]$pattern
                    }
                }
            )
            $publisherPatterns = @(
                foreach ($pattern in @($SearchLocation.publisherPatterns)) {
                    if ([string]::IsNullOrWhiteSpace([string]$pattern)) {
                        continue
                    }
                    if ($PackageResult) {
                        Resolve-PackageTemplateText -Text ([string]$pattern) -PackageConfig $PackageResult.PackageConfig -Package $PackageResult.Package
                    }
                    else {
                        [string]$pattern
                    }
                }
            )

            foreach ($entry in @(Get-WindowsUninstallRegistryEntries -RootPaths @($rootPaths))) {
                if (-not (Test-PackageWildcardTextMatch -Value ([string]$entry.DisplayName) -Patterns @($displayNamePatterns))) {
                    continue
                }
                if (@($publisherPatterns).Count -gt 0 -and -not (Test-PackageWildcardTextMatch -Value ([string]$entry.Publisher) -Patterns @($publisherPatterns))) {
                    continue
                }
                $entries.Add($entry) | Out-Null
            }
        }
        default {
            throw "Package discovery.existingInstall unsupported uninstall registry search kind '$($SearchLocation.kind)'."
        }
    }

    foreach ($entry in @($entries.ToArray())) {
        $pathResolution = Resolve-WindowsUninstallRegistryEntryPath -Entry $entry -Source ([string]$SearchLocation.installDirectorySource)
        if (-not $pathResolution -or -not [string]::Equals([string]$pathResolution.Status, 'Ready', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        if (Test-Path -LiteralPath $pathResolution.ResolvedPath -PathType Container) {
            return [pscustomobject]@{
                CandidatePath     = $pathResolution.ResolvedPath
                RegistryEntry     = $entry
                PathResolution    = $pathResolution
            }
        }
    }

    return $null
}

function Get-PackageExistingInstallSearchLocations {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object[]]$SearchLocations
    )

    $indexedLocations = New-Object System.Collections.Generic.List[object]
    $index = 0
    foreach ($searchLocation in @($SearchLocations)) {
        if ($null -eq $searchLocation) {
            continue
        }
        $indexedLocations.Add([pscustomobject]@{
            SearchLocation = $searchLocation
            SearchOrder    = if ($searchLocation.PSObject.Properties['searchOrder']) { [int]$searchLocation.searchOrder } else { [int]::MaxValue }
            Index          = $index
        }) | Out-Null
        $index++
    }

    return @($indexedLocations.ToArray() | Sort-Object -Property SearchOrder, Index | ForEach-Object { $_.SearchLocation })
}

function Find-PackageInventoryOwnedInstallCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if (-not $PackageResult.PackageConfig -or [string]::IsNullOrWhiteSpace([string]$PackageResult.PackageConfig.PackageAssignmentInventoryFilePath)) {
        return $null
    }

    $index = Get-PackageInventory -PackageConfig $PackageResult.PackageConfig
    $installSlotId = Get-PackageInstallSlotId -PackageResult $PackageResult
    foreach ($record in @($index.Records)) {
        if (-not [string]::Equals([string]$record.installSlotId, $installSlotId, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $ownershipKind = if ($record.PSObject.Properties['ownershipKind']) {
            Resolve-PackageOwnershipKindText -OwnershipKind ([string]$record.ownershipKind)
        }
        else {
            $null
        }
        if (-not [string]::Equals($ownershipKind, 'PackageInstalled', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        if (-not $record.PSObject.Properties['installDirectory'] -or [string]::IsNullOrWhiteSpace([string]$record.installDirectory)) {
            continue
        }

        $installDirectory = [System.IO.Path]::GetFullPath([string]$record.installDirectory)
        if (Test-Path -LiteralPath $installDirectory -PathType Container) {
            return [pscustomobject]@{
                InstallSlotId    = $installSlotId
                InstallDirectory = $installDirectory
                OwnershipRecord  = $record
            }
        }
    }

    return $null
}

function Test-PackageWildcardTextMatch {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value,

        [AllowEmptyCollection()]
        [string[]]$Patterns
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    foreach ($patternText in @($Patterns | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })) {
        $pattern = [System.Management.Automation.WildcardPattern]::new([string]$patternText, [System.Management.Automation.WildcardOptions]::IgnoreCase)
        if ($pattern.IsMatch([string]$Value)) {
            return $true
        }
    }

    return $false
}

function Find-PackageExistingPackage {
<#
.SYNOPSIS
Finds an existing package install that may be reused or adopted.

.DESCRIPTION
Searches command, path, and directory candidates from discovery.existingInstall
and attaches the first matching install
directory to the Package result.

.PARAMETER PackageResult
The Package result object to enrich.

.EXAMPLE
Find-PackageExistingPackage -PackageResult $result
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $package = $PackageResult.Package
    if (-not [string]::IsNullOrWhiteSpace([string]$PackageResult.InstallDirectory) -and
        (Test-Path -LiteralPath $PackageResult.InstallDirectory -PathType Container)) {
        $resolvedPackageOwnedInstallDirectory = [System.IO.Path]::GetFullPath([string]$PackageResult.InstallDirectory)
        $PackageResult.ExistingPackage = [pscustomobject]@{
            SearchKind       = 'packageTargetInstallPath'
            CandidatePath    = $resolvedPackageOwnedInstallDirectory
            InstallDirectory = $resolvedPackageOwnedInstallDirectory
            Decision         = 'Pending'
            Readiness       = $null
            Classification   = $null
            OwnershipRecord  = $null
        }
        Write-PackageExecutionMessage -Message ("[DISCOVERY] Found Package target install directory '{0}'." -f $resolvedPackageOwnedInstallDirectory)
        return $PackageResult
    }

    $inventoryCandidate = Find-PackageInventoryOwnedInstallCandidate -PackageResult $PackageResult
    if ($inventoryCandidate) {
        $PackageResult.ExistingPackage = [pscustomobject]@{
            SearchKind       = 'packageInventoryInstallSlot'
            CandidatePath    = $inventoryCandidate.InstallDirectory
            InstallDirectory = $inventoryCandidate.InstallDirectory
            Decision         = 'Pending'
            Readiness       = $null
            Classification   = $null
            OwnershipRecord  = $inventoryCandidate.OwnershipRecord
            DiscoveryDetails = [pscustomobject]@{
                InstallSlotId = $inventoryCandidate.InstallSlotId
            }
        }
        Write-PackageExecutionMessage -Message ("[DISCOVERY] Found Package-owned inventory install '{0}' for installSlotId '{1}'." -f $inventoryCandidate.InstallDirectory, $inventoryCandidate.InstallSlotId)
        return $PackageResult
    }

    $definition = $PackageResult.PackageConfig.Definition
    if (-not $definition -or -not $definition.PSObject.Properties['discovery'] -or
        -not $definition.discovery.PSObject.Properties['existingInstall'] -or
        $null -eq $definition.discovery.existingInstall) {
        return $PackageResult
    }

    $existingInstallInfo = $definition.discovery.existingInstall
    if ($existingInstallInfo.PSObject.Properties['enabled'] -and (-not [bool]$existingInstallInfo.enabled)) {
        return $PackageResult
    }

    foreach ($searchLocation in @(Get-PackageExistingInstallSearchLocations -SearchLocations @($existingInstallInfo.searchLocations))) {
        $candidatePath = $null
        $discoveryDetails = $null
        switch -Exact ([string]$searchLocation.kind) {
            'command' {
                if (-not $searchLocation.PSObject.Properties['name'] -or [string]::IsNullOrWhiteSpace([string]$searchLocation.name)) {
                    throw "Package discovery.existingInstall search for release '$($package.id)' is missing command name."
                }
                $candidatePath = Get-ResolvedApplicationPath -CommandName ([string]$searchLocation.name)
            }
            'path' {
                if (-not $searchLocation.PSObject.Properties['path'] -or [string]::IsNullOrWhiteSpace([string]$searchLocation.path)) {
                    throw "Package discovery.existingInstall search for release '$($package.id)' is missing path."
                }
                $resolvedPath = Resolve-PackagePathValue -PathValue ([string]$searchLocation.path)
                if (Test-Path -LiteralPath $resolvedPath) {
                    $candidatePath = $resolvedPath
                }
            }
            'directory' {
                if (-not $searchLocation.PSObject.Properties['path'] -or [string]::IsNullOrWhiteSpace([string]$searchLocation.path)) {
                    throw "Package discovery.existingInstall search for release '$($package.id)' is missing directory path."
                }
                $resolvedPath = Resolve-PackagePathValue -PathValue ([string]$searchLocation.path)
                if (Test-Path -LiteralPath $resolvedPath -PathType Container) {
                    $candidatePath = $resolvedPath
                }
            }
            { $_ -in @('windowsUninstallRegistryKey', 'windowsUninstallRegistrySearch') } {
                $registryCandidate = Resolve-PackageExistingUninstallRegistryCandidate -SearchLocation $searchLocation -PackageResult $PackageResult
                if ($registryCandidate) {
                    $candidatePath = $registryCandidate.CandidatePath
                    $discoveryDetails = $registryCandidate
                }
            }
            'powershellModule' {
                if (-not $searchLocation.PSObject.Properties['name'] -or [string]::IsNullOrWhiteSpace([string]$searchLocation.name)) {
                    throw "Package discovery.existingInstall search for release '$($package.id)' is missing PowerShell module name."
                }
                if (-not $searchLocation.PSObject.Properties['requiredVersion'] -or [string]::IsNullOrWhiteSpace([string]$searchLocation.requiredVersion)) {
                    throw "Package discovery.existingInstall search for release '$($package.id)' is missing PowerShell module requiredVersion."
                }
                $requiredVersion = Resolve-PackageTemplateText -Text ([string]$searchLocation.requiredVersion) -PackageConfig $PackageResult.PackageConfig -Package $package
                $scope = if ($searchLocation.PSObject.Properties['scope'] -and -not [string]::IsNullOrWhiteSpace([string]$searchLocation.scope)) { [string]$searchLocation.scope } else { 'CurrentUser' }
                $requireNuGetProvider = if ($searchLocation.PSObject.Properties['requireNuGetProvider']) { [bool]$searchLocation.requireNuGetProvider } else { $false }
                $moduleStatus = Test-PackagePowerShellModulePresence -PackageResult $PackageResult -Name ([string]$searchLocation.name) -RequiredVersion $requiredVersion -Scope $scope -RequireNuGetProvider $requireNuGetProvider -TreatFailureAsNotInstalled $true
                if ($moduleStatus -and $moduleStatus.PSObject.Properties['installed'] -and [bool]$moduleStatus.installed) {
                    $candidatePath = if ($moduleStatus.PSObject.Properties['moduleBase']) { [string]$moduleStatus.moduleBase } else { $null }
                    $discoveryDetails = $moduleStatus
                }
            }
            default {
                throw "Unsupported Package discovery.existingInstall search kind '$($searchLocation.kind)'."
            }
        }

        if ([string]::IsNullOrWhiteSpace($candidatePath)) {
            continue
        }

        if ([string]::Equals([string]$searchLocation.kind, 'powershellModule', [System.StringComparison]::OrdinalIgnoreCase)) {
            $PackageResult.ExistingPackage = [pscustomobject]@{
                SearchKind       = $searchLocation.kind
                CandidatePath    = $candidatePath
                InstallDirectory = $null
                Decision         = 'Pending'
                Readiness        = $null
                Classification   = $null
                OwnershipRecord  = $null
                DiscoveryDetails = $discoveryDetails
            }
            Write-PackageExecutionMessage -Message ("[DISCOVERY] Found existing PowerShell module '{0}' via '{1}'." -f $candidatePath, $searchLocation.kind)
            return $PackageResult
        }

        $installDirectory = Resolve-PackageExistingInstallRoot -DiscoveryExistingInstall $existingInstallInfo -CandidatePath $candidatePath
        if (-not (Test-Path -LiteralPath $installDirectory -PathType Container)) {
            continue
        }

        $PackageResult.ExistingPackage = [pscustomobject]@{
            SearchKind       = $searchLocation.kind
            CandidatePath    = $candidatePath
            InstallDirectory = $installDirectory
            Decision         = 'Pending'
            Readiness       = $null
            Classification   = $null
            OwnershipRecord  = $null
            DiscoveryDetails = $discoveryDetails
        }
        Write-PackageExecutionMessage -Message ("[DISCOVERY] Found existing package candidate '{0}' via '{1}'." -f $candidatePath, $searchLocation.kind)
        return $PackageResult
    }

    return $PackageResult
}

function Get-PackageAssignedVersionUpdatePolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $assigned = Get-PackageAssignedOperation -Release $PackageResult.Package
    if ($assigned -and $assigned.PSObject.Properties['versionUpdatePolicy'] -and $null -ne $assigned.versionUpdatePolicy) {
        return $assigned.versionUpdatePolicy
    }

    return [pscustomobject]@{
        whenAssigned          = 'trackSelectedVersion'
        onSameSelectedVersion = 'reuseOrRepair'
        onNewSelectedVersion  = 'replacePackageOwnedInstall'
    }
}

function Resolve-PackageOwnedSelectedVersionChange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [psobject]$OwnershipRecord,

        [AllowNull()]
        [string]$OriginalInstallDirectory
    )

    $policy = Get-PackageAssignedVersionUpdatePolicy -PackageResult $PackageResult
    $onNewSelectedVersion = if ($policy.PSObject.Properties['onNewSelectedVersion'] -and -not [string]::IsNullOrWhiteSpace([string]$policy.onNewSelectedVersion)) {
        [string]$policy.onNewSelectedVersion
    }
    else {
        'replacePackageOwnedInstall'
    }

    switch -Exact ($onNewSelectedVersion) {
        'replacePackageOwnedInstall' {
            $PackageResult.ExistingPackage.Decision = 'ReplacePackageOwnedInstall'
            $PackageResult.InstallDirectory = $OriginalInstallDirectory
            $PackageResult.Readiness = $null
            Write-PackageExecutionMessage -Level 'WRN' -Message ("[DECISION] Replacing Package-owned install at '{0}' because selected version changed from '{1}' to '{2}'." -f $PackageResult.ExistingPackage.InstallDirectory, [string]$OwnershipRecord.currentVersion, [string]$PackageResult.PackageVersion)
            Write-PackageExecutionMessage -Message ("[STATE] Existing install decision resolved to '{0}'." -f $PackageResult.ExistingPackage.Decision)
            return $PackageResult
        }
        'fail' {
            throw ("Package install slot '{0}' is already assigned to version '{1}', but selected version is '{2}' and versionUpdatePolicy.onNewSelectedVersion='fail'." -f (Get-PackageInstallSlotId -PackageResult $PackageResult), [string]$OwnershipRecord.currentVersion, [string]$PackageResult.PackageVersion)
        }
        default {
            throw "Unsupported versionUpdatePolicy.onNewSelectedVersion '$onNewSelectedVersion'."
        }
    }
}

function Resolve-PackageExistingPackageDecision {
<#
.SYNOPSIS
Evaluates how Package should react to a discovered existing install.

.DESCRIPTION
Validates the discovered install, combines the result with ownership
classification and release-specific policy switches, and records whether the
current run should reuse, adopt, ignore, or replace the install.

.PARAMETER PackageResult
The Package result object to enrich.

.EXAMPLE
Resolve-PackageExistingPackageDecision -PackageResult $result
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if (-not $PackageResult.ExistingPackage) {
        return $PackageResult
    }

    $package = $PackageResult.Package
    $ownershipPolicy = if ($package.PSObject.Properties['ownershipPolicy']) { $package.ownershipPolicy } else { [pscustomobject]@{} }
    $originalInstallDirectory = $PackageResult.InstallDirectory
    $ownershipRecord = if ($PackageResult.Ownership -and $PackageResult.Ownership.OwnershipRecord) {
        $PackageResult.Ownership.OwnershipRecord
    }
    else {
        $null
    }

    $classification = if ($PackageResult.Ownership -and $PackageResult.Ownership.Classification) {
        [string]$PackageResult.Ownership.Classification
    }
    else {
        'ExternalInstall'
    }

    $allowAdoptExternal = $false
    if ($ownershipPolicy.PSObject.Properties['allowAdoptExternal']) {
        $allowAdoptExternal = [bool]$ownershipPolicy.allowAdoptExternal
    }

    $upgradeAdoptedInstall = $false
    if ($ownershipPolicy.PSObject.Properties['upgradeAdoptedInstall']) {
        $upgradeAdoptedInstall = [bool]$ownershipPolicy.upgradeAdoptedInstall
    }

    $requirePackageOwnership = $false
    if ($ownershipPolicy.PSObject.Properties['requirePackageOwnership']) {
        $requirePackageOwnership = [bool]$ownershipPolicy.requirePackageOwnership
    }

    $sameRelease = $false
    if ($ownershipRecord) {
        $sameRelease = [string]::Equals([string]$ownershipRecord.currentReleaseId, [string]$PackageResult.PackageId, [System.StringComparison]::OrdinalIgnoreCase) -and
            [string]::Equals([string]$ownershipRecord.currentVersion, [string]$PackageResult.PackageVersion, [System.StringComparison]::OrdinalIgnoreCase)
    }

    $ownershipKind = if ($ownershipRecord -and $ownershipRecord.PSObject.Properties['ownershipKind']) {
        Resolve-PackageOwnershipKindText -OwnershipKind ([string]$ownershipRecord.ownershipKind)
    }
    else {
        $null
    }
    $isAdoptedRecord = [string]::Equals($ownershipKind, 'AdoptedExternal', [System.StringComparison]::OrdinalIgnoreCase)
    if ([string]::Equals($classification, 'PackageTarget', [System.StringComparison]::OrdinalIgnoreCase) -and
        $ownershipRecord -and
        (-not $sameRelease) -and
        (-not $isAdoptedRecord)) {
        return (Resolve-PackageOwnedSelectedVersionChange -PackageResult $PackageResult -OwnershipRecord $ownershipRecord -OriginalInstallDirectory $originalInstallDirectory)
    }

    $PackageResult.InstallDirectory = $PackageResult.ExistingPackage.InstallDirectory
    $PackageResult = Test-PackageAssignedReadiness -PackageResult $PackageResult
    $PackageResult.ExistingPackage.Readiness = $PackageResult.Readiness

    if (-not $PackageResult.Readiness.Accepted) {
        $PackageResult.ExistingPackage.Decision = 'ExistingInstallReadinessFailed'
        $PackageResult.InstallDirectory = $originalInstallDirectory
        $PackageResult.Readiness = $null
        return $PackageResult
    }

    if ([string]::Equals($classification, 'PackageTarget', [System.StringComparison]::OrdinalIgnoreCase) -and -not $ownershipRecord) {
        $PackageResult.ExistingPackage.Decision = 'ReusePackageOwned'
        $PackageResult.InstallOrigin = 'PackageReused'
        Write-PackageExecutionMessage -Message ("[DECISION] Reusing Package-owned target install '{0}'." -f $PackageResult.ExistingPackage.InstallDirectory)
        Write-PackageExecutionMessage -Message ("[STATE] Existing install decision resolved to '{0}' with installOrigin='{1}'." -f $PackageResult.ExistingPackage.Decision, $PackageResult.InstallOrigin)
        return $PackageResult
    }

    if ([string]::Equals($classification, 'PackageTarget', [System.StringComparison]::OrdinalIgnoreCase) -and $ownershipRecord) {
        if ($isAdoptedRecord) {
            if ($sameRelease -or (-not $upgradeAdoptedInstall)) {
                $PackageResult.ExistingPackage.Decision = 'AdoptExternal'
                $PackageResult.InstallOrigin = 'AdoptedExternal'
                Write-PackageExecutionMessage -Message ("[DECISION] Reusing adopted external install '{0}'." -f $PackageResult.ExistingPackage.InstallDirectory)
                Write-PackageExecutionMessage -Message ("[STATE] Existing install decision resolved to '{0}' with installOrigin='{1}'." -f $PackageResult.ExistingPackage.Decision, $PackageResult.InstallOrigin)
                return $PackageResult
            }

            $PackageResult.ExistingPackage.Decision = 'UpgradeAdoptedInstall'
            $PackageResult.InstallDirectory = $originalInstallDirectory
            $PackageResult.Readiness = $null
            Write-PackageExecutionMessage -Level 'WRN' -Message ("[DECISION] Replacing adopted install at '{0}' with a Package-owned install." -f $PackageResult.ExistingPackage.InstallDirectory)
            Write-PackageExecutionMessage -Message ("[STATE] Existing install decision resolved to '{0}'." -f $PackageResult.ExistingPackage.Decision)
            return $PackageResult
        }

        if ($sameRelease) {
            $PackageResult.ExistingPackage.Decision = 'ReusePackageOwned'
            $PackageResult.InstallOrigin = 'PackageReused'
            Write-PackageExecutionMessage -Message ("[DECISION] Reusing Package-owned install '{0}'." -f $PackageResult.ExistingPackage.InstallDirectory)
            Write-PackageExecutionMessage -Message ("[STATE] Existing install decision resolved to '{0}' with installOrigin='{1}'." -f $PackageResult.ExistingPackage.Decision, $PackageResult.InstallOrigin)
            return $PackageResult
        }

        return (Resolve-PackageOwnedSelectedVersionChange -PackageResult $PackageResult -OwnershipRecord $ownershipRecord -OriginalInstallDirectory $originalInstallDirectory)
    }

    if ($requirePackageOwnership) {
        $PackageResult.ExistingPackage.Decision = 'ExternalIgnored'
        $PackageResult.InstallDirectory = $originalInstallDirectory
        $PackageResult.Readiness = $null
        Write-PackageExecutionMessage -Level 'WRN' -Message ("[DECISION] Ignoring external install '{0}' because Package ownership is required." -f $PackageResult.ExistingPackage.InstallDirectory)
        Write-PackageExecutionMessage -Message ("[STATE] Existing install decision resolved to '{0}'." -f $PackageResult.ExistingPackage.Decision)
        return $PackageResult
    }

    if ($allowAdoptExternal) {
        $PackageResult.ExistingPackage.Decision = 'AdoptExternal'
        $PackageResult.InstallOrigin = 'AdoptedExternal'
        Write-PackageExecutionMessage -Message ("[DECISION] Adopting external install '{0}'." -f $PackageResult.ExistingPackage.InstallDirectory)
        Write-PackageExecutionMessage -Message ("[STATE] Existing install decision resolved to '{0}' with installOrigin='{1}'." -f $PackageResult.ExistingPackage.Decision, $PackageResult.InstallOrigin)
        return $PackageResult
    }

    $PackageResult.ExistingPackage.Decision = 'ExternalIgnored'
    $PackageResult.InstallDirectory = $originalInstallDirectory
    $PackageResult.Readiness = $null
    Write-PackageExecutionMessage -Level 'WRN' -Message ("[DECISION] Ignoring external install '{0}'." -f $PackageResult.ExistingPackage.InstallDirectory)
    Write-PackageExecutionMessage -Message ("[STATE] Existing install decision resolved to '{0}'." -f $PackageResult.ExistingPackage.Decision)
    return $PackageResult
}

function Remove-PackageReplacedPackageOwnedInstallDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if (-not $PackageResult.ExistingPackage -or
        -not [string]::Equals([string]$PackageResult.ExistingPackage.Decision, 'ReplacePackageOwnedInstall', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $PackageResult
    }

    $cleanup = [pscustomobject]@{
        Status       = 'Skipped'
        Reason       = 'Pending'
        TargetPath   = $null
        ErrorMessage = $null
    }
    if ($PackageResult.PSObject.Properties['ReplacementCleanup']) {
        $PackageResult.ReplacementCleanup = $cleanup
    }
    else {
        $PackageResult | Add-Member -MemberType NoteProperty -Name ReplacementCleanup -Value $cleanup
    }

    if (-not $PackageResult.Readiness -or -not $PackageResult.Readiness.Accepted) {
        $PackageResult.ReplacementCleanup.Reason = 'ReadinessNotAccepted'
        return $PackageResult
    }

    $oldInstallDirectory = [string]$PackageResult.ExistingPackage.InstallDirectory
    $newInstallDirectory = [string]$PackageResult.InstallDirectory
    if ([string]::IsNullOrWhiteSpace($oldInstallDirectory)) {
        $PackageResult.ReplacementCleanup.Reason = 'OldInstallDirectoryMissing'
        return $PackageResult
    }

    $oldInstallDirectory = [System.IO.Path]::GetFullPath($oldInstallDirectory)
    $PackageResult.ReplacementCleanup.TargetPath = $oldInstallDirectory
    if (-not [string]::IsNullOrWhiteSpace($newInstallDirectory) -and
        [string]::Equals($oldInstallDirectory, [System.IO.Path]::GetFullPath($newInstallDirectory), [System.StringComparison]::OrdinalIgnoreCase)) {
        $PackageResult.ReplacementCleanup.Reason = 'SameInstallDirectory'
        return $PackageResult
    }

    $ownershipRecord = if ($PackageResult.Ownership -and $PackageResult.Ownership.OwnershipRecord) { $PackageResult.Ownership.OwnershipRecord } else { $null }
    $ownershipKind = if ($ownershipRecord -and $ownershipRecord.PSObject.Properties['ownershipKind']) {
        Resolve-PackageOwnershipKindText -OwnershipKind ([string]$ownershipRecord.ownershipKind)
    }
    else {
        $null
    }
    if (-not [string]::Equals($ownershipKind, 'PackageInstalled', [System.StringComparison]::OrdinalIgnoreCase)) {
        $PackageResult.ReplacementCleanup.Reason = 'NotPackageInstalledOwnership'
        return $PackageResult
    }
    if (-not (Test-Path -LiteralPath $oldInstallDirectory -PathType Container)) {
        $PackageResult.ReplacementCleanup.Reason = 'OldInstallDirectoryNotFound'
        return $PackageResult
    }

    try {
        $removed = Remove-PathIfExists -Path $oldInstallDirectory
        if ($removed) {
            $ceiling = Get-EmptyParentPruneCeilingDirectory -InstallLeafPath $oldInstallDirectory -PreferredInstallRootDirectory ([string]$PackageResult.PackageConfig.PreferredTargetInstallRootDirectory)
            if (-not [string]::IsNullOrWhiteSpace($ceiling)) {
                Remove-EmptyParentDirectoryChain -DeletedLeafPath $oldInstallDirectory -AncestorCeilingDirectory $ceiling
            }
            $PackageResult.ReplacementCleanup.Status = 'Removed'
            $PackageResult.ReplacementCleanup.Reason = $null
            Write-PackageExecutionMessage -Message ("[ACTION] Removed replaced Package-owned install directory '{0}'." -f $oldInstallDirectory)
        }
        else {
            $PackageResult.ReplacementCleanup.Reason = 'OldInstallDirectoryNotFound'
        }
    }
    catch {
        $PackageResult.ReplacementCleanup.Status = 'Failed'
        $PackageResult.ReplacementCleanup.Reason = 'RemovalFailed'
        $PackageResult.ReplacementCleanup.ErrorMessage = $_.Exception.Message
        Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Failed to remove replaced Package-owned install directory '{0}': {1}" -f $oldInstallDirectory, $_.Exception.Message)
    }

    return $PackageResult
}
