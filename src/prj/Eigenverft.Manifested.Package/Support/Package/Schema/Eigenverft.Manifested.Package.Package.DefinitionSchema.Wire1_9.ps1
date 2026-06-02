<#
    Eigenverft.Manifested.Package.Package.DefinitionSchema.Wire1_9
    Shared validators and runtime projection for the current package definition wire shape.
#>

function Get-PackageObjectPropertyValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not $InputObject -or -not $InputObject.PSObject.Properties[$Name]) {
        return $null
    }

    return $InputObject.$Name
}

function Test-PackageObjectHasProperty {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [psobject]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return ($InputObject -and $InputObject.PSObject.Properties[$Name])
}

function Get-PackageDiscoveryPresenceEntryPoints {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition,

        [Parameter(Mandatory = $true)]
        [ValidateSet('commands', 'apps')]
        [string]$ToolKind,

        [switch]$ExposedOnly
    )

    if (-not (Test-PackageObjectHasProperty -InputObject $Definition -Name 'discovery') -or
        -not (Test-PackageObjectHasProperty -InputObject $Definition.discovery -Name 'presence') -or
        -not (Test-PackageObjectHasProperty -InputObject $Definition.discovery.presence -Name $ToolKind)) {
        return @()
    }

    $exposedPropertyName = if ([string]::Equals($ToolKind, 'commands', [System.StringComparison]::Ordinal)) {
        'exposeCommand'
    }
    else {
        'exposeApp'
    }

    return @(
        foreach ($entryPoint in @($Definition.discovery.presence.$ToolKind)) {
            if ($null -eq $entryPoint) {
                continue
            }
            if ($ExposedOnly -and (
                    -not $entryPoint.PSObject.Properties[$exposedPropertyName] -or
                    -not [bool]$entryPoint.$exposedPropertyName)) {
                continue
            }
            $entryPoint
        }
    )
}

function Get-PackageDiscoveryPresenceEntryPoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition,

        [Parameter(Mandatory = $true)]
        [ValidateSet('commands', 'apps')]
        [string]$ToolKind,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [switch]$ExposedOnly
    )

    foreach ($entryPoint in @(Get-PackageDiscoveryPresenceEntryPoints -Definition $Definition -ToolKind $ToolKind -ExposedOnly:$ExposedOnly)) {
        if ([string]::Equals([string]$entryPoint.name, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $entryPoint
        }
    }

    return $null
}

function Resolve-PackagePresenceEntryPointPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$EntryPoint,

        [Parameter(Mandatory = $true)]
        [string]$InstallDirectory
    )

    return (Join-Path $InstallDirectory (([string]$EntryPoint.relativePath) -replace '/', '\'))
}

function Resolve-PackagePresenceToolPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition,

        [Parameter(Mandatory = $true)]
        [ValidateSet('commands', 'apps')]
        [string]$ToolKind,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$InstallDirectory
    )

    $entryPoint = Get-PackageDiscoveryPresenceEntryPoint -Definition $Definition -ToolKind $ToolKind -Name $Name
    if (-not $entryPoint) {
        return $null
    }

    return (Resolve-PackagePresenceEntryPointPath -EntryPoint $entryPoint -InstallDirectory $InstallDirectory)
}

function Assert-PackageDefinitionNoRetiredNestedProperty_1_9 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [AllowNull()]
        [psobject]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName,

        [Parameter(Mandatory = $true)]
        [string]$PropertyPath,

        [Parameter(Mandatory = $true)]
        [string]$ReplacementPath
    )

    if ($InputObject -and $InputObject.PSObject.Properties[$PropertyName]) {
        throw "Package definition '$DefinitionId' still uses retired property '$PropertyPath'. Use '$ReplacementPath'."
    }
}

function Assert-PackageArtifactTrustMetadata_1_9 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$TargetId,

        [AllowNull()]
        [psobject]$Artifact
    )

    if (-not $Artifact) {
        return
    }

    foreach ($retiredProperty in @('autoUpdateSupported', 'integrity', 'authenticode')) {
        if ($Artifact.PSObject.Properties[$retiredProperty]) {
            throw "Package definition '$DefinitionId' version '$Version' artifact '$TargetId' still uses retired packageFile.$retiredProperty. Use artifact contentHash or publisherSignature metadata."
        }
    }

    if ($Artifact.PSObject.Properties['contentHash']) {
        $contentHash = $Artifact.contentHash
        if (-not $contentHash -or
            -not $contentHash.PSObject.Properties['algorithm'] -or
            [string]::IsNullOrWhiteSpace([string]$contentHash.algorithm)) {
            throw "Package definition '$DefinitionId' version '$Version' artifact '$TargetId' defines packageFile.contentHash without algorithm."
        }
        if ([string]$contentHash.algorithm -notin @('sha256', 'sha512')) {
            throw "Package definition '$DefinitionId' version '$Version' artifact '$TargetId' uses unsupported packageFile.contentHash algorithm '$($contentHash.algorithm)'. Use sha256 or sha512."
        }
        if (-not $contentHash.PSObject.Properties['value'] -or [string]::IsNullOrWhiteSpace([string]$contentHash.value)) {
            throw "Package definition '$DefinitionId' version '$Version' artifact '$TargetId' defines packageFile.contentHash without value."
        }
    }

    if ($Artifact.PSObject.Properties['publisherSignature']) {
        $publisherSignature = $Artifact.publisherSignature
        if (-not $publisherSignature -or
            -not $publisherSignature.PSObject.Properties['kind'] -or
            [string]::IsNullOrWhiteSpace([string]$publisherSignature.kind)) {
            throw "Package definition '$DefinitionId' version '$Version' artifact '$TargetId' defines packageFile.publisherSignature without kind."
        }
        if (-not [string]::Equals([string]$publisherSignature.kind, 'authenticode', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Package definition '$DefinitionId' version '$Version' artifact '$TargetId' uses unsupported packageFile.publisherSignature kind '$($publisherSignature.kind)'. Use authenticode."
        }
        if (-not $publisherSignature.PSObject.Properties['requireValid']) {
            throw "Package definition '$DefinitionId' version '$Version' artifact '$TargetId' defines packageFile.publisherSignature without requireValid."
        }
        if (-not $publisherSignature.PSObject.Properties['subjectContains'] -or [string]::IsNullOrWhiteSpace([string]$publisherSignature.subjectContains)) {
            throw "Package definition '$DefinitionId' version '$Version' artifact '$TargetId' defines packageFile.publisherSignature without subjectContains."
        }
    }
}

function Assert-PackagePresenceRequirementFlags_1_9 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [Parameter(Mandatory = $true)]
        [string]$PropertyPath,

        [Parameter(Mandatory = $true)]
        [psobject]$Require
    )

    $requiredRequirements = @('files', 'directories', 'commands', 'apps', 'metadataFiles', 'signatures', 'fileDetails', 'registry', 'powerShellModules')
    foreach ($required in @($requiredRequirements)) {
        if (-not $Require.PSObject.Properties[$required]) {
            throw "Package definition '$DefinitionId' requires '$PropertyPath.require.$required'."
        }
        if ($Require.$required -isnot [bool]) {
            throw "Package definition '$DefinitionId' field '$PropertyPath.require.$required' must be boolean."
        }
    }
}

function Test-PackageDefinitionTextPropertyPresent_1_9 {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [psobject]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName
    )

    return ($InputObject -and
        $InputObject.PSObject.Properties[$PropertyName] -and
        -not [string]::IsNullOrWhiteSpace([string]$InputObject.$PropertyName))
}

function Get-PackageDefinitionDependencyModel_1_9 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition,

        [AllowNull()]
        [string]$DefinitionId = $null
    )

    $label = if (-not [string]::IsNullOrWhiteSpace($DefinitionId)) {
        $DefinitionId
    }
    elseif ($Definition.PSObject.Properties['definitionPublication'] -and
        $Definition.definitionPublication.PSObject.Properties['definitionId'] -and
        -not [string]::IsNullOrWhiteSpace([string]$Definition.definitionPublication.definitionId)) {
        [string]$Definition.definitionPublication.definitionId
    }
    else {
        '<unknown>'
    }

    if (Test-PackageObjectHasProperty -InputObject $Definition -Name 'dependencies') {
        throw "Package definition '$label' uses retired top-level property 'dependencies'. Use dependency.requires."
    }
    if (Test-PackageObjectHasProperty -InputObject $Definition -Name 'dependencyPolicy') {
        throw "Package definition '$label' uses retired top-level property 'dependencyPolicy'. Use dependency.policy."
    }
    if (-not (Test-PackageObjectHasProperty -InputObject $Definition -Name 'dependency') -or -not $Definition.dependency) {
        throw "Package definition '$label' is missing required dependency object."
    }
    if (-not (Test-PackageObjectHasProperty -InputObject $Definition.dependency -Name 'requires') -or $null -eq $Definition.dependency.requires) {
        throw "Package definition '$label' is missing required dependency.requires array."
    }

    $policy = if (Test-PackageObjectHasProperty -InputObject $Definition.dependency -Name 'policy') { $Definition.dependency.policy } else { $null }
    return [pscustomobject]@{
        Shape          = 'Unified'
        Requires       = @($Definition.dependency.requires)
        Policy         = $policy
        ConflictsWith  = if ($policy -and (Test-PackageObjectHasProperty -InputObject $policy -Name 'conflictsWith')) { @($policy.conflictsWith) } else { @() }
        RequiresAbsent = if ($policy -and (Test-PackageObjectHasProperty -InputObject $policy -Name 'requiresAbsent')) { @($policy.requiresAbsent) } else { @() }
    }
}

function Assert-PackageDiscoveryExistingInstall_1_9 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [Parameter(Mandatory = $true)]
        [psobject]$DiscoveryExistingInstall
    )

    foreach ($required in @('enabled', 'searchLocations', 'installRootRules')) {
        if (-not $DiscoveryExistingInstall.PSObject.Properties[$required]) {
            throw "Package definition '$DefinitionId' is missing discovery.existingInstall.$required."
        }
    }

    $searchLocationIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($location in @($DiscoveryExistingInstall.searchLocations)) {
        foreach ($required in @('id', 'kind', 'searchOrder')) {
            if (-not $location.PSObject.Properties[$required] -or [string]::IsNullOrWhiteSpace([string]$location.$required)) {
                throw "Package definition '$DefinitionId' discovery.existingInstall.searchLocations entry is missing '$required'."
            }
        }
        if (-not $searchLocationIds.Add([string]$location.id)) {
            throw "Package definition '$DefinitionId' has duplicate discovery.existingInstall.searchLocations id '$($location.id)'."
        }
        switch -Exact ([string]$location.kind) {
            'command' {
                if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $location -PropertyName 'name')) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' kind command requires name."
                }
            }
            'path' {
                if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $location -PropertyName 'path')) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' kind path requires path."
                }
            }
            'directory' {
                if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $location -PropertyName 'path')) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' kind directory requires path."
                }
            }
            'windowsUninstallRegistryKey' {
                if (-not $location.PSObject.Properties['paths'] -or @($location.paths).Count -eq 0) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' kind windowsUninstallRegistryKey requires paths."
                }
                foreach ($path in @($location.paths)) {
                    if ([string]::IsNullOrWhiteSpace([string]$path)) {
                        throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' has an empty registry path."
                    }
                }
                if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $location -PropertyName 'installDirectorySource')) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' kind windowsUninstallRegistryKey requires installDirectorySource."
                }
                if ([string]$location.installDirectorySource -notin @('installLocation', 'displayIcon', 'displayIconDirectory', 'uninstallString', 'uninstallStringDirectory')) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' uses unsupported installDirectorySource '$($location.installDirectorySource)'."
                }
            }
            'windowsUninstallRegistrySearch' {
                if (-not $location.PSObject.Properties['rootPaths'] -or @($location.rootPaths).Count -eq 0) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' kind windowsUninstallRegistrySearch requires rootPaths."
                }
                foreach ($rootPath in @($location.rootPaths)) {
                    if ([string]::IsNullOrWhiteSpace([string]$rootPath)) {
                        throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' has an empty registry root path."
                    }
                }
                if (-not $location.PSObject.Properties['displayNamePatterns'] -or @($location.displayNamePatterns).Count -eq 0) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' kind windowsUninstallRegistrySearch requires displayNamePatterns."
                }
                foreach ($pattern in @($location.displayNamePatterns)) {
                    if ([string]::IsNullOrWhiteSpace([string]$pattern)) {
                        throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' has an empty displayNamePatterns entry."
                    }
                }
                if ($location.PSObject.Properties['publisherPatterns']) {
                    foreach ($pattern in @($location.publisherPatterns)) {
                        if ([string]::IsNullOrWhiteSpace([string]$pattern)) {
                            throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' has an empty publisherPatterns entry."
                        }
                    }
                }
                if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $location -PropertyName 'installDirectorySource')) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' kind windowsUninstallRegistrySearch requires installDirectorySource."
                }
                if ([string]$location.installDirectorySource -notin @('installLocation', 'displayIcon', 'displayIconDirectory', 'uninstallString', 'uninstallStringDirectory')) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' uses unsupported installDirectorySource '$($location.installDirectorySource)'."
                }
            }
            'powershellModule' {
                if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $location -PropertyName 'name')) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' kind powershellModule requires name."
                }
                if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $location -PropertyName 'requiredVersion')) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' kind powershellModule requires requiredVersion."
                }
                if ($location.PSObject.Properties['scope'] -and
                    -not [string]::Equals([string]$location.scope, 'CurrentUser', [System.StringComparison]::OrdinalIgnoreCase) -and
                    -not [string]::Equals([string]$location.scope, 'AllUsers', [System.StringComparison]::OrdinalIgnoreCase)) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' kind powershellModule uses unsupported scope '$($location.scope)'. Use CurrentUser or AllUsers."
                }
                if ($location.PSObject.Properties['requireNuGetProvider'] -and $location.requireNuGetProvider -isnot [bool]) {
                    throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' kind powershellModule requireNuGetProvider must be boolean."
                }
            }
            default {
                throw "Package definition '$DefinitionId' discovery.existingInstall search '$($location.id)' uses unsupported kind '$($location.kind)'."
            }
        }
    }

    foreach ($rule in @($DiscoveryExistingInstall.installRootRules)) {
        if (-not $rule.PSObject.Properties['match'] -or -not $rule.match) {
            throw "Package definition '$DefinitionId' installRootRules entry requires match."
        }
        if (-not $rule.match.PSObject.Properties['kind'] -or -not [string]::Equals([string]$rule.match.kind, 'fileName', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Package definition '$DefinitionId' installRootRules.match currently supports only kind 'fileName'."
        }
        if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $rule.match -PropertyName 'value')) {
            throw "Package definition '$DefinitionId' installRootRules.match kind fileName requires value."
        }
        if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $rule -PropertyName 'installRootRelativePath')) {
            throw "Package definition '$DefinitionId' installRootRules entry requires installRootRelativePath."
        }
    }
}

function Assert-PackageAssignedInstallOperation_1_9 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [Parameter(Mandatory = $true)]
        [psobject]$AssignedInstall
    )

    if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $AssignedInstall -PropertyName 'kind')) {
        throw "Package definition '$DefinitionId' is missing packageOperations.assigned.install.kind."
    }

    switch -Exact ([string]$AssignedInstall.kind) {
        'expandArchive' {
        }
        'placePackageFile' {
        }
        'runInstaller' {
        }
        'reuseExisting' {
        }
        'nsisInstaller' {
            if ($AssignedInstall.PSObject.Properties['installerKind'] -and
                -not [string]::Equals([string]$AssignedInstall.installerKind, 'nsis', [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Package definition '$DefinitionId' nsisInstaller cannot use installerKind '$($AssignedInstall.installerKind)'. Use innoSetupInstaller for Inno Setup packages."
            }
            if (-not $AssignedInstall.PSObject.Properties['targetDirectoryArgument'] -or -not $AssignedInstall.targetDirectoryArgument) {
                throw "Package definition '$DefinitionId' nsisInstaller requires targetDirectoryArgument."
            }
            $targetArgument = $AssignedInstall.targetDirectoryArgument
            if (-not $targetArgument.PSObject.Properties['enabled'] -or $targetArgument.enabled -isnot [bool]) {
                throw "Package definition '$DefinitionId' nsisInstaller targetDirectoryArgument.enabled must be boolean."
            }
            if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $targetArgument -PropertyName 'prefix')) {
                throw "Package definition '$DefinitionId' nsisInstaller targetDirectoryArgument.prefix must not be empty."
            }
        }
        'innoSetupInstaller' {
            foreach ($required in @('installDirectory', 'commandArguments', 'targetDirectoryArgument')) {
                if (-not $AssignedInstall.PSObject.Properties[$required]) {
                    throw "Package definition '$DefinitionId' innoSetupInstaller requires $required."
                }
            }
            $targetArgument = $AssignedInstall.targetDirectoryArgument
            if (-not $targetArgument.PSObject.Properties['enabled'] -or $targetArgument.enabled -isnot [bool]) {
                throw "Package definition '$DefinitionId' innoSetupInstaller targetDirectoryArgument.enabled must be boolean."
            }
            if ($targetArgument.enabled) {
                if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $targetArgument -PropertyName 'prefix')) {
                    throw "Package definition '$DefinitionId' innoSetupInstaller targetDirectoryArgument.prefix is required when enabled."
                }
                if (-not $targetArgument.PSObject.Properties['quoteValue'] -or $targetArgument.quoteValue -isnot [bool]) {
                    throw "Package definition '$DefinitionId' innoSetupInstaller targetDirectoryArgument.quoteValue must be boolean."
                }
            }
        }
        'msiInstaller' {
            foreach ($required in @('installDirectory', 'commandArguments', 'targetDirectoryProperty')) {
                if (-not $AssignedInstall.PSObject.Properties[$required]) {
                    throw "Package definition '$DefinitionId' msiInstaller requires $required."
                }
            }
            $targetDirectoryProperty = $AssignedInstall.targetDirectoryProperty
            if (-not $targetDirectoryProperty.PSObject.Properties['enabled'] -or $targetDirectoryProperty.enabled -isnot [bool]) {
                throw "Package definition '$DefinitionId' msiInstaller targetDirectoryProperty.enabled must be boolean."
            }
            if ($targetDirectoryProperty.enabled) {
                if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $targetDirectoryProperty -PropertyName 'name')) {
                    throw "Package definition '$DefinitionId' msiInstaller targetDirectoryProperty.name is required when enabled."
                }
                if (-not [regex]::IsMatch([string]$targetDirectoryProperty.name, '^[A-Z][A-Z0-9_]*$')) {
                    throw "Package definition '$DefinitionId' msiInstaller targetDirectoryProperty.name must be an MSI public property name."
                }
            }
        }
        'npmMaterializedInstallGlobalPackage' {
            foreach ($required in @('installerCommand', 'packageSpec', 'installDirectory')) {
                if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $AssignedInstall -PropertyName $required)) {
                    throw "Package definition '$DefinitionId' npmMaterializedInstallGlobalPackage requires $required."
                }
            }
        }
        'powershellModuleInstaller' {
            foreach ($required in @('moduleName', 'requiredVersion')) {
                if (-not (Test-PackageDefinitionTextPropertyPresent_1_9 -InputObject $AssignedInstall -PropertyName $required)) {
                    throw "Package definition '$DefinitionId' powershellModuleInstaller requires $required."
                }
            }
            if ($AssignedInstall.PSObject.Properties['scope'] -and
                -not [string]::Equals([string]$AssignedInstall.scope, 'CurrentUser', [System.StringComparison]::OrdinalIgnoreCase) -and
                -not [string]::Equals([string]$AssignedInstall.scope, 'AllUsers', [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Package definition '$DefinitionId' powershellModuleInstaller uses unsupported scope '$($AssignedInstall.scope)'. Use CurrentUser or AllUsers."
            }
            if ($AssignedInstall.PSObject.Properties['timeoutSec'] -and [int]$AssignedInstall.timeoutSec -lt 1) {
                throw "Package definition '$DefinitionId' powershellModuleInstaller timeoutSec must be greater than zero."
            }
        }
        default {
            throw "Package definition '$DefinitionId' uses unsupported packageOperations.assigned.install.kind '$($AssignedInstall.kind)'."
        }
    }
}

function Assert-PackageRemovedOperation_1_9 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [Parameter(Mandatory = $true)]
        [psobject]$RemovedOperation
    )

    if (-not $RemovedOperation.PSObject.Properties['policy']) {
        throw "Package definition '$DefinitionId' is missing packageOperations.removed.policy."
    }
    if (-not $RemovedOperation.PSObject.Properties['operation']) {
        throw "Package definition '$DefinitionId' is missing packageOperations.removed.operation."
    }
    if (-not $RemovedOperation.PSObject.Properties['absenceVerification']) {
        throw "Package definition '$DefinitionId' is missing packageOperations.removed.absenceVerification."
    }
    if (-not $RemovedOperation.PSObject.Properties['postRemoveCleanup']) {
        throw "Package definition '$DefinitionId' is missing packageOperations.removed.postRemoveCleanup."
    }

    $policy = $RemovedOperation.policy
    foreach ($requiredPolicyProperty in @('whenNotInInventory', 'allowedInventoryOwnershipKinds', 'allowUntrackedExternalRemoval', 'removeDependencies')) {
        if (-not $policy.PSObject.Properties[$requiredPolicyProperty]) {
            throw "Package definition '$DefinitionId' is missing packageOperations.removed.policy.$requiredPolicyProperty."
        }
    }
    if (-not [string]::Equals([string]$policy.whenNotInInventory, 'succeed', [System.StringComparison]::OrdinalIgnoreCase) -and
        -not [string]::Equals([string]$policy.whenNotInInventory, 'fail', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Package definition '$DefinitionId' uses unsupported packageOperations.removed.policy.whenNotInInventory value '$($policy.whenNotInInventory)'."
    }
    foreach ($kind in @($policy.allowedInventoryOwnershipKinds)) {
        if ([string]::IsNullOrWhiteSpace([string]$kind)) {
            throw "Package definition '$DefinitionId' has empty packageOperations.removed.policy.allowedInventoryOwnershipKinds entry."
        }
        if (-not [string]::Equals([string]$kind, 'PackageInstalled', [System.StringComparison]::OrdinalIgnoreCase) -and
            -not [string]::Equals([string]$kind, 'PackageApplied', [System.StringComparison]::OrdinalIgnoreCase) -and
            -not [string]::Equals([string]$kind, 'AdoptedExternal', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Package definition '$DefinitionId' uses unsupported packageOperations.removed.policy.allowedInventoryOwnershipKinds value '$kind'."
        }
    }
    if ($policy.allowUntrackedExternalRemoval -isnot [bool]) {
        throw "Package definition '$DefinitionId' requires packageOperations.removed.policy.allowUntrackedExternalRemoval to be boolean."
    }
    if ($policy.removeDependencies -isnot [bool]) {
        throw "Package definition '$DefinitionId' requires packageOperations.removed.policy.removeDependencies to be boolean."
    }

    $operation = $RemovedOperation.operation
    if (-not $operation.PSObject.Properties['kind']) {
        throw "Package definition '$DefinitionId' is missing packageOperations.removed.operation.kind."
    }
    $operationKind = [string]$operation.kind
    switch ($operationKind) {
        'deleteInstallDirectory' {
            if (-not $operation.PSObject.Properties['pathSource'] -or
                -not [string]::Equals([string]$operation.pathSource, 'inventory.installDirectory', [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Package definition '$DefinitionId' removed.operation.kind 'deleteInstallDirectory' requires pathSource = 'inventory.installDirectory'."
            }
        }
        { $_ -in @('nsisUninstaller', 'innoSetupUninstaller', 'msiUninstaller') } {
            foreach ($required in @('commandSource', 'commandArguments', 'elevation', 'timeoutSec', 'successExitCodes', 'restartExitCodes', 'uiMode')) {
                if (-not $operation.PSObject.Properties[$required]) {
                    throw "Package definition '$DefinitionId' missing packageOperations.removed.operation.$required."
                }
            }
            if (-not $operation.commandSource.PSObject.Properties['use'] -or -not [string]::Equals([string]$operation.commandSource.use, 'discovery.existingInstall', [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Package definition '$DefinitionId' packageOperations.removed.operation.commandSource.use must be 'discovery.existingInstall'."
            }
            if (-not $operation.commandSource.PSObject.Properties['searchLocationId'] -or [string]::IsNullOrWhiteSpace([string]$operation.commandSource.searchLocationId)) {
                throw "Package definition '$DefinitionId' packageOperations.removed.operation.commandSource.searchLocationId is missing."
            }
            if (-not $operation.commandSource.PSObject.Properties['registryValueOrder'] -or @($operation.commandSource.registryValueOrder).Count -eq 0) {
                throw "Package definition '$DefinitionId' packageOperations.removed.operation.commandSource.registryValueOrder is missing."
            }
            foreach ($registryValue in @($operation.commandSource.registryValueOrder)) {
                if (-not [string]::Equals([string]$registryValue, 'QuietUninstallString', [System.StringComparison]::OrdinalIgnoreCase) -and
                    -not [string]::Equals([string]$registryValue, 'UninstallString', [System.StringComparison]::OrdinalIgnoreCase)) {
                    throw "Package definition '$DefinitionId' packageOperations.removed.operation.commandSource.registryValueOrder contains unsupported value '$registryValue'."
                }
            }
            if (($operation.timeoutSec -isnot [int] -and $operation.timeoutSec -isnot [long]) -or $operation.timeoutSec -le 0) {
                throw "Package definition '$DefinitionId' packageOperations.removed.operation.timeoutSec must be a positive integer."
            }
            if (-not ($operation.successExitCodes -is [array])) {
                throw "Package definition '$DefinitionId' packageOperations.removed.operation.successExitCodes must be an array."
            }
            if (-not ($operation.restartExitCodes -is [array])) {
                throw "Package definition '$DefinitionId' packageOperations.removed.operation.restartExitCodes must be an array."
            }
        }
        'none' {
            # no operation-specific fields required.
        }
        default {
            throw "Package definition '$DefinitionId' uses unsupported packageOperations.removed.operation.kind '$operationKind'."
        }
    }

    $absence = $RemovedOperation.absenceVerification
    if (-not $absence.PSObject.Properties['use'] -or -not [string]::Equals([string]$absence.use, 'discovery.presence', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Package definition '$DefinitionId' requires packageOperations.removed.absenceVerification.use = 'discovery.presence'."
    }
    if (-not $absence.PSObject.Properties['require']) {
        throw "Package definition '$DefinitionId' is missing packageOperations.removed.absenceVerification.require."
    }
    Assert-PackagePresenceRequirementFlags_1_9 -DefinitionId $DefinitionId -PropertyPath 'packageOperations.removed.absenceVerification' -Require $absence.require

    $postRemoveCleanup = $RemovedOperation.postRemoveCleanup
    foreach ($requiredPost in @('packageInventoryRecord', 'generatedShims', 'pathEntries', 'workDirectories')) {
        if (-not $postRemoveCleanup.PSObject.Properties[$requiredPost]) {
            throw "Package definition '$DefinitionId' requires packageOperations.removed.postRemoveCleanup.$requiredPost."
        }
        if ($postRemoveCleanup.$requiredPost -isnot [bool]) {
            throw "Package definition '$DefinitionId' packageOperations.removed.postRemoveCleanup.$requiredPost must be boolean."
        }
    }
}

function Assert-PackageDefinitionSchema_1_9 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DefinitionDocumentInfo,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [AllowNull()]
        [string]$PublisherId = $null
    )

    $definition = $DefinitionDocumentInfo.Document
    foreach ($retiredProperty in @('releases', 'providedTools', 'shared', 'releaseDefaults', 'installedStateDiscovery', 'installedStateCheck', 'existingInstallPolicy')) {
        if ($definition.PSObject.Properties[$retiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' still uses retired property '$retiredProperty'."
        }
    }

    foreach ($retiredProperty in @('id')) {
        if ($definition.PSObject.Properties[$retiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' still uses retired top-level property 'id'. Use definitionPublication.definitionId instead."
        }
    }

    $retiredRootReplacements = @{
        presenceDiscovery        = 'discovery.presence'
        existingInstallDiscovery = 'discovery.existingInstall'
    }
    foreach ($retiredProperty in @($retiredRootReplacements.Keys)) {
        if ($definition.PSObject.Properties[$retiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' still uses retired root property '$retiredProperty'. Use '$($retiredRootReplacements[$retiredProperty])'."
        }
    }

    foreach ($requiredProperty in @('schemaVersion', 'definitionPublication', 'display', 'dependency', 'artifacts', 'discovery', 'packageOperations')) {
        if (-not $definition.PSObject.Properties[$requiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' is missing required schemaVersion 1.9 property '$requiredProperty'."
        }
    }
    foreach ($requiredDiscoveryProperty in @('presence', 'existingInstall')) {
        if (-not $definition.discovery.PSObject.Properties[$requiredDiscoveryProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' is missing required schemaVersion 1.9 property 'discovery.$requiredDiscoveryProperty'."
        }
    }
    foreach ($retiredProperty in @('definitionId', 'repositoryId')) {
        if ($definition.PSObject.Properties[$retiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' still uses retired schema 1.4 root property '$retiredProperty'. Move definition identity to definitionPublication."
        }
    }

    foreach ($requiredPublicationProperty in @('publisherId', 'publisherName', 'definitionId', 'definitionRevision', 'publishedAtUtc')) {
        if (-not $definition.definitionPublication.PSObject.Properties[$requiredPublicationProperty]) {
            throw "Package definition '$DefinitionId' is missing definitionPublication.$requiredPublicationProperty."
        }
    }
    if ([string]::IsNullOrWhiteSpace([string]$definition.definitionPublication.publisherId)) {
        throw "Package definition '$DefinitionId' definitionPublication.publisherId must not be empty."
    }
    Assert-PackagePublisherId -PublisherId ([string]$definition.definitionPublication.publisherId)
    if ([string]::IsNullOrWhiteSpace([string]$definition.definitionPublication.publisherName)) {
        throw "Package definition '$DefinitionId' definitionPublication.publisherName must not be empty."
    }
    if ([string]::IsNullOrWhiteSpace([string]$definition.definitionPublication.definitionId)) {
        throw "Package definition '$DefinitionId' definitionPublication.definitionId must not be empty."
    }
    if (-not [string]::Equals([string]$definition.definitionPublication.definitionId, $DefinitionId, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Package definition definitionPublication.definitionId '$($definition.definitionPublication.definitionId)' does not match expected id '$DefinitionId'."
    }
    if (-not [string]::IsNullOrWhiteSpace($PublisherId) -and
        -not [string]::Equals([string]$definition.definitionPublication.publisherId, [string]$PublisherId, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Package definition '$DefinitionId' publisher '$($definition.definitionPublication.publisherId)' does not match expected publisher '$PublisherId'."
    }
    $revision = 0
    if (-not [int]::TryParse([string]$definition.definitionPublication.definitionRevision, [ref]$revision) -or $revision -lt 1) {
        throw "Package definition '$DefinitionId' definitionPublication.definitionRevision must be a positive integer."
    }
    $pubRaw = $definition.definitionPublication.publishedAtUtc
    $publishedAtUtc = [DateTime]::MinValue
    if ($pubRaw -is [datetime]) {
        $publishedAtUtc = [datetime]$pubRaw
    }
    elseif (-not [DateTime]::TryParse([string]$pubRaw, [CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$publishedAtUtc) -and
        -not [DateTime]::TryParse([string]$pubRaw, [ref]$publishedAtUtc)) {
        throw "Package definition '$DefinitionId' definitionPublication.publishedAtUtc must be a valid UTC timestamp."
    }

    if (-not $definition.artifacts.PSObject.Properties['targets']) {
        throw "Package definition '$DefinitionId' is missing required artifacts.targets array."
    }
    if (-not $definition.artifacts.PSObject.Properties['releases']) {
        throw "Package definition '$DefinitionId' is missing required artifacts.releases array."
    }
    Assert-PackageDiscoveryExistingInstall_1_9 -DefinitionId $DefinitionId -DiscoveryExistingInstall $definition.discovery.existingInstall

    $targetIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $targetsById = @{}
    foreach ($target in @($definition.artifacts.targets)) {
        if (-not $target.PSObject.Properties['id'] -or [string]::IsNullOrWhiteSpace([string]$target.id)) {
            throw "Package definition '$DefinitionId' has artifact target without id."
        }
        if (-not $targetIds.Add([string]$target.id)) {
            throw "Package definition '$DefinitionId' has duplicate artifact target id '$($target.id)'."
        }
        $targetsById[[string]$target.id] = $target
        foreach ($requiredTargetProperty in @('releaseTrack', 'artifactDistributionVariant', 'constraints', 'versionSelection')) {
            if (-not $target.PSObject.Properties[$requiredTargetProperty]) {
                throw "Package definition '$DefinitionId' artifact target '$($target.id)' is missing '$requiredTargetProperty'."
            }
        }
        if (-not [string]::Equals([string]$target.versionSelection.strategy, 'latestByVersion', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Package definition '$DefinitionId' artifact target '$($target.id)' uses unsupported versionSelection.strategy '$($target.versionSelection.strategy)'. Use latestByVersion."
        }
    }

    $dependencyModel = Get-PackageDefinitionDependencyModel_1_9 -Definition $definition -DefinitionId $DefinitionId
    foreach ($dependency in @($dependencyModel.Requires)) {
        if ($null -eq $dependency) {
            continue
        }
        if ($dependency.PSObject.Properties['repositoryId']) {
            throw "Package definition '$DefinitionId' dependency still uses retired property 'repositoryId'. Use dependency.publisherId or omit it."
        }
        if ($dependency.PSObject.Properties['repositorySourceId']) {
            throw "Package definition '$DefinitionId' dependency still uses retired property 'repositorySourceId'. Use dependency.publisherId or omit it."
        }
        if ($dependency.PSObject.Properties['publisherId'] -and [string]::IsNullOrWhiteSpace([string]$dependency.publisherId)) {
            throw "Package definition '$DefinitionId' has dependency with empty publisherId."
        }
        if ($dependency.PSObject.Properties['publisherId']) {
            Assert-PackagePublisherId -PublisherId ([string]$dependency.publisherId)
        }
        if (-not $dependency.PSObject.Properties['definitionId'] -or [string]::IsNullOrWhiteSpace([string]$dependency.definitionId)) {
            throw "Package definition '$DefinitionId' has dependency without definitionId."
        }
        if ($dependency.PSObject.Properties['versionRange']) {
            if ([string]::IsNullOrWhiteSpace([string]$dependency.versionRange)) {
                throw "Package definition '$DefinitionId' dependency '$($dependency.definitionId)' has empty versionRange."
            }
            try {
                $null = Resolve-PackageVersionRangeTerms -VersionRange ([string]$dependency.versionRange)
            }
            catch {
                throw "Package definition '$DefinitionId' dependency '$($dependency.definitionId)' has invalid versionRange '$($dependency.versionRange)': $($_.Exception.Message)"
            }
        }
    }

    if ($dependencyModel.Policy) {
        $dependencyPolicy = $dependencyModel.Policy
        foreach ($policyPropertyName in @('conflictsWith', 'requiresAbsent')) {
            $policyReferences = if ($dependencyPolicy -and (Test-PackageObjectHasProperty -InputObject $dependencyPolicy -Name $policyPropertyName)) { @($dependencyPolicy.$policyPropertyName) } else { @() }
            foreach ($policyReference in @($policyReferences)) {
                if ($null -eq $policyReference) {
                    continue
                }
                if ($policyReference.PSObject.Properties['publisherId'] -and [string]::IsNullOrWhiteSpace([string]$policyReference.publisherId)) {
                    throw "Package definition '$DefinitionId' dependency.policy.$policyPropertyName entry has empty publisherId."
                }
                if ($policyReference.PSObject.Properties['publisherId']) {
                    Assert-PackagePublisherId -PublisherId ([string]$policyReference.publisherId)
                }
                if (-not $policyReference.PSObject.Properties['definitionId'] -or [string]::IsNullOrWhiteSpace([string]$policyReference.definitionId)) {
                    throw "Package definition '$DefinitionId' dependency.policy.$policyPropertyName entry is missing definitionId."
                }
                if ($policyReference.PSObject.Properties['versionRange']) {
                    if ([string]::IsNullOrWhiteSpace([string]$policyReference.versionRange)) {
                        throw "Package definition '$DefinitionId' dependency.policy.$policyPropertyName entry '$($policyReference.definitionId)' has empty versionRange."
                    }
                    try {
                        $null = Resolve-PackageVersionRangeTerms -VersionRange ([string]$policyReference.versionRange)
                    }
                    catch {
                        throw "Package definition '$DefinitionId' dependency.policy.$policyPropertyName entry '$($policyReference.definitionId)' has invalid versionRange '$($policyReference.versionRange)': $($_.Exception.Message)"
                    }
                }
            }
        }
    }

    $sharedOperation = if ($definition.packageOperations.PSObject.Properties['policy']) { $definition.packageOperations.policy } else { $null }
    $ownershipPolicy = if ($sharedOperation -and $sharedOperation.PSObject.Properties['ownershipPolicy']) { $sharedOperation.ownershipPolicy } else { $null }
    Assert-PackageDefinitionNoRetiredNestedProperty_1_9 -DefinitionId $DefinitionId -InputObject $ownershipPolicy -PropertyName 'requireManagedOwnership' -PropertyPath 'packageOperations.policy.ownershipPolicy.requireManagedOwnership' -ReplacementPath 'packageOperations.policy.ownershipPolicy.requirePackageOwnership'

    $assignedOperation = if ($definition.packageOperations.PSObject.Properties['assigned']) { $definition.packageOperations.assigned } else { $null }
    $assignedInstall = if ($assignedOperation -and $assignedOperation.PSObject.Properties['install']) { $assignedOperation.install } else { $null }
    Assert-PackageDefinitionNoRetiredNestedProperty_1_9 -DefinitionId $DefinitionId -InputObject $assignedOperation -PropertyName 'managerDependency' -PropertyPath 'packageOperations.assigned.managerDependency' -ReplacementPath 'dependency.requires plus packageOperations.assigned.install.installerCommand'
    Assert-PackageDefinitionNoRetiredNestedProperty_1_9 -DefinitionId $DefinitionId -InputObject $assignedInstall -PropertyName 'managerDependency' -PropertyPath 'packageOperations.assigned.install.managerDependency' -ReplacementPath 'dependency.requires plus packageOperations.assigned.install.installerCommand'
    Assert-PackageDefinitionNoRetiredNestedProperty_1_9 -DefinitionId $DefinitionId -InputObject $assignedOperation -PropertyName 'managerKind' -PropertyPath 'packageOperations.assigned.managerKind' -ReplacementPath 'packageOperations.assigned.install.kind = npmMaterializedInstallGlobalPackage'
    Assert-PackageDefinitionNoRetiredNestedProperty_1_9 -DefinitionId $DefinitionId -InputObject $assignedInstall -PropertyName 'managerKind' -PropertyPath 'packageOperations.assigned.install.managerKind' -ReplacementPath 'packageOperations.assigned.install.kind = npmMaterializedInstallGlobalPackage'
    if (-not $assignedInstall) {
        throw "Package definition '$DefinitionId' is missing packageOperations.assigned.install."
    }
    Assert-PackageAssignedInstallOperation_1_9 -DefinitionId $DefinitionId -AssignedInstall $assignedInstall
    if (-not $definition.packageOperations.PSObject.Properties['removed']) {
        throw "Package definition '$DefinitionId' is missing required packageOperations.removed."
    }
    Assert-PackageRemovedOperation_1_9 -DefinitionId $DefinitionId -RemovedOperation $definition.packageOperations.removed

    if (-not $definition.artifacts.sources) {
        throw "Package definition '$DefinitionId' is missing artifacts.sources map."
    }

    foreach ($sourceProperty in @($definition.artifacts.sources.PSObject.Properties)) {
        $source = $sourceProperty.Value
        if (-not $source.PSObject.Properties['kind'] -or [string]::IsNullOrWhiteSpace([string]$source.kind)) {
            throw "Package definition '$DefinitionId' artifacts source '$($sourceProperty.Name)' is missing kind."
        }
    }

    foreach ($versionEntry in @($definition.artifacts.releases)) {
        if ($versionEntry.PSObject.Properties['artifactsByTarget']) {
            throw "Package definition '$DefinitionId' release '$($versionEntry.version)' still uses retired property 'artifactsByTarget'."
        }
        Assert-PackageDefinitionNoRetiredNestedProperty_1_9 -DefinitionId $DefinitionId -InputObject $versionEntry -PropertyName 'artifactsByTarget' -PropertyPath 'artifacts.releases[].artifactsByTarget' -ReplacementPath 'targetArtifacts'
        if (-not $versionEntry.PSObject.Properties['version'] -or [string]::IsNullOrWhiteSpace([string]$versionEntry.version)) {
            throw "Package definition '$DefinitionId' has release entry without version."
        }
        if (-not $versionEntry.PSObject.Properties['releaseTracks'] -or $null -eq $versionEntry.releaseTracks) {
            throw "Package definition '$DefinitionId' release '$($versionEntry.version)' is missing releaseTracks."
        }
        if (-not $versionEntry.PSObject.Properties['targetArtifacts'] -or $null -eq $versionEntry.targetArtifacts) {
            throw "Package definition '$DefinitionId' release '$($versionEntry.version)' is missing targetArtifacts."
        }

        foreach ($artifactProperty in @($versionEntry.targetArtifacts.PSObject.Properties)) {
            if (-not $targetIds.Contains([string]$artifactProperty.Name)) {
                throw "Package definition '$DefinitionId' release '$($versionEntry.version)' references unknown artifact target '$($artifactProperty.Name)'."
            }

            $artifact = $artifactProperty.Value
            if (-not $artifact -or -not $artifact.PSObject.Properties['artifactId'] -or [string]::IsNullOrWhiteSpace([string]$artifact.artifactId)) {
                throw "Package definition '$DefinitionId' release '$($versionEntry.version)' artifact '$($artifactProperty.Name)' is missing artifactId."
            }

            Assert-PackageArtifactTrustMetadata_1_9 -DefinitionId $DefinitionId -Version ([string]$versionEntry.version) -TargetId ([string]$artifactProperty.Name) -Artifact $artifact

            $artifactAcquisitionCandidates = if ($artifact.PSObject.Properties['acquisitionCandidates']) { @($artifact.acquisitionCandidates) } else { @() }
            if (-not $artifactAcquisitionCandidates -and $targetsById[[string]$artifactProperty.Name] -and $targetsById[[string]$artifactProperty.Name].PSObject.Properties['acquisitionCandidates']) {
                $artifactAcquisitionCandidates = @($targetsById[[string]$artifactProperty.Name].acquisitionCandidates)
            }

            foreach ($candidate in @($artifactAcquisitionCandidates)) {
                if ($candidate.PSObject.Properties['priority']) {
                    throw "Package definition '$DefinitionId' release '$($versionEntry.version)' artifact '$($artifactProperty.Name)' still uses retired acquisitionCandidate property 'priority'. Use searchOrder."
                }
            }
        }
    }

    $exposedCommands = @(Get-PackageDiscoveryPresenceEntryPoints -Definition $definition -ToolKind 'commands' -ExposedOnly)
    $assigned = $definition.packageOperations.assigned
    if ($assigned.PSObject.Properties['readyStateCheck']) {
        if (-not $assigned.readyStateCheck.PSObject.Properties['use'] -or -not [string]::Equals([string]$assigned.readyStateCheck.use, 'discovery.presence', [System.StringComparison]::Ordinal)) {
            throw "Package definition '$DefinitionId' packageOperations.assigned.readyStateCheck.use must be 'discovery.presence'."
        }
    }
    if ($assigned.PSObject.Properties['pathRegistration'] -and
        $assigned.pathRegistration.PSObject.Properties['source'] -and
        [string]::Equals([string]$assigned.pathRegistration.source.kind, 'shim', [System.StringComparison]::OrdinalIgnoreCase)) {
        if (-not [string]::Equals([string]$assigned.pathRegistration.source.use, 'discovery.presence.commands', [System.StringComparison]::Ordinal)) {
            throw "Package definition '$DefinitionId' pathRegistration.source kind 'shim' requires use='discovery.presence.commands'."
        }
        if ($exposedCommands.Count -eq 0) {
            throw "Package definition '$DefinitionId' uses shim PATH registration but has no exposed discovery.presence.commands."
        }
    }
}
function Get-PackageArtifactForTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$VersionEntry,

        [Parameter(Mandatory = $true)]
        [string]$TargetId
    )

    foreach ($property in @($VersionEntry.targetArtifacts.PSObject.Properties)) {
        if ([string]::Equals([string]$property.Name, $TargetId, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $property.Value
        }
    }

    return $null
}

function Resolve-PackageTargetArtifactText {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [psobject]$ArtifactTarget,

        [Parameter(Mandatory = $true)]
        [psobject]$VersionEntry,

        [AllowNull()]
        [psobject]$UpstreamRelease
    )

    if ($null -eq $Text) {
        return $null
    }

    return Resolve-TemplateText -Text $Text -Tokens @{
        version                 = [string]$VersionEntry.version
        releaseTag              = if ($UpstreamRelease -and $UpstreamRelease.PSObject.Properties['releaseTag']) { [string]$UpstreamRelease.releaseTag } else { $null }
        releaseTrack            = [string]$ArtifactTarget.releaseTrack
        artifactDistributionVariant = [string]$ArtifactTarget.artifactDistributionVariant
    }
}

function New-PackageReadinessFromDiscoveryPresence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition,

        [Parameter(Mandatory = $true)]
        [psobject]$Assigned
    )

    $require = if ($Assigned.PSObject.Properties['readyStateCheck'] -and $Assigned.readyStateCheck.PSObject.Properties['require']) {
        $Assigned.readyStateCheck.require
    }
    else {
        [pscustomobject]@{}
    }
    $presence = $Definition.discovery.presence

    $commandChecks = New-Object System.Collections.Generic.List[object]
    if ($require.PSObject.Properties['commands'] -and [bool]$require.commands) {
        foreach ($command in @($presence.commands)) {
            foreach ($stateCheck in @($command.stateChecks)) {
                if ($null -eq $stateCheck) {
                    continue
                }
                $check = ConvertTo-PackageObject -InputObject $stateCheck
                $check | Add-Member -MemberType NoteProperty -Name 'entryPoint' -Value ([string]$command.name) -Force
                $commandChecks.Add($check) | Out-Null
            }
        }
    }

    return [pscustomobject]@{
        files          = if ($require.PSObject.Properties['files'] -and [bool]$require.files) { @($presence.files) } else { @() }
        directories    = if ($require.PSObject.Properties['directories'] -and [bool]$require.directories) { @($presence.directories) } else { @() }
        commandChecks  = @($commandChecks.ToArray())
        metadataFiles  = if ($require.PSObject.Properties['metadataFiles'] -and [bool]$require.metadataFiles) { @($presence.metadataFiles) } else { @() }
        signatures     = if ($require.PSObject.Properties['signatures'] -and [bool]$require.signatures) { @($presence.signatures) } else { @() }
        fileDetails    = if ($require.PSObject.Properties['fileDetails'] -and [bool]$require.fileDetails) { @($presence.fileDetails) } else { @() }
        registryChecks = if ($require.PSObject.Properties['registry'] -and [bool]$require.registry) { @($presence.registry) } else { @() }
        powerShellModules = if ($require.PSObject.Properties['powerShellModules'] -and [bool]$require.powerShellModules) { @($presence.powerShellModules) } else { @() }
    }
}

function Resolve-PackageEffectivePackage_1_9 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig,

        [AllowNull()]
        [string]$PackageVersionOverride = $null,

        [AllowNull()]
        [string]$PackageVersionRange = $null
    )

    $definition = $PackageConfig.Definition
    $releaseTrack = if ([string]::IsNullOrWhiteSpace([string]$PackageConfig.ReleaseTrack)) { 'none' } else { [string]$PackageConfig.ReleaseTrack }
    $matchState = New-Object System.Collections.Generic.List[object]
    $candidateIndex = 0

    foreach ($target in @($definition.artifacts.targets)) {
        $releaseIndex = -1
        $constraints = $target.constraints
        $osConstraints = if ($constraints.PSObject.Properties['os']) { @($constraints.os) } else { @() }
        $cpuConstraints = if ($constraints.PSObject.Properties['cpu']) { @($constraints.cpu) } else { @() }
        if (-not [string]::Equals([string]$target.releaseTrack, $releaseTrack, [System.StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-PackageConstraintSetMatch -Values $osConstraints -ActualValue $PackageConfig.Platform) -or
            -not (Test-PackageConstraintSetMatch -Values $cpuConstraints -ActualValue $PackageConfig.Architecture)) {
            continue
        }

        foreach ($versionEntry in @($definition.artifacts.releases)) {
            $releaseIndex++
            $releaseTracks = if ($versionEntry.PSObject.Properties['releaseTracks']) { @($versionEntry.releaseTracks) } else { @() }
            $versionIsInTrack = $false
            foreach ($releaseTrackName in @($releaseTracks)) {
                if ([string]::Equals([string]$releaseTrackName, [string]$target.releaseTrack, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $versionIsInTrack = $true
                    break
                }
            }
            if (-not $versionIsInTrack) {
                continue
            }

            $artifact = Get-PackageArtifactForTarget -VersionEntry $versionEntry -TargetId ([string]$target.id)
            if ($artifact) {
                $matchState.Add([pscustomobject]@{
                    ArtifactTarget  = $target
                    VersionEntry   = $versionEntry
                    Artifact      = $artifact
                    VersionOrdering = Get-PackageVersionOrderingInfo -VersionText ([string]$versionEntry.version) -AuthorIndex $releaseIndex -CandidateIndex $candidateIndex
                }) | Out-Null
                $candidateIndex++
            }
        }
    }

    $selection = Resolve-PackageVersionCandidateSelection -Candidates @($matchState.ToArray()) -CommandSelector $PackageVersionOverride -DefinitionId ([string]$PackageConfig.DefinitionId) -Platform ([string]$PackageConfig.Platform) -Architecture ([string]$PackageConfig.Architecture) -ReleaseTrack $releaseTrack -AllVersionEntries @($definition.artifacts.releases) -VersionRange $PackageVersionRange
    $selected = $selection.Candidate
    $target = $selected.ArtifactTarget
    $versionEntry = $selected.VersionEntry
    $artifact = $selected.Artifact
    $assigned = ConvertTo-PackageObject -InputObject $definition.packageOperations.assigned
    $upstreamRelease = if ($versionEntry.PSObject.Properties['upstreamRelease']) { $versionEntry.upstreamRelease } else { $null }

    $fileName = if ($artifact.PSObject.Properties['fileName'] -and -not [string]::IsNullOrWhiteSpace([string]$artifact.fileName)) {
        [string]$artifact.fileName
    }
    elseif ($target.PSObject.Properties['fileNameTemplate']) {
        Resolve-PackageTargetArtifactText -Text ([string]$target.fileNameTemplate) -ArtifactTarget $target -VersionEntry $versionEntry -UpstreamRelease $upstreamRelease
    }
    else {
        $null
    }

    $packageFile = $null
    if (-not [string]::IsNullOrWhiteSpace($fileName) -or
        $artifact.PSObject.Properties['contentHash'] -or
        $artifact.PSObject.Properties['publisherSignature']) {
        $packageFile = [ordered]@{}
        if (-not [string]::IsNullOrWhiteSpace($fileName)) { $packageFile.fileName = $fileName }
        if ($artifact.PSObject.Properties['contentHash']) { $packageFile.contentHash = ConvertTo-PackageObject -InputObject $artifact.contentHash }
        if ($artifact.PSObject.Properties['publisherSignature']) { $packageFile.publisherSignature = ConvertTo-PackageObject -InputObject $artifact.publisherSignature }
    }

    $artifactAcquisitionCandidates = if ($artifact.PSObject.Properties['acquisitionCandidates']) { @($artifact.acquisitionCandidates) } else { @() }
    if (-not $artifactAcquisitionCandidates -and $target.PSObject.Properties['acquisitionCandidates']) {
        $artifactAcquisitionCandidates = @($target.acquisitionCandidates)
    }
    $artifactSourcePath = if ($artifact.PSObject.Properties['sourcePath']) {
        Resolve-PackageTargetArtifactText -Text ([string]$artifact.sourcePath) -ArtifactTarget $target -VersionEntry $versionEntry -UpstreamRelease $upstreamRelease
    }
    else {
        $null
    }
    $artifactUrl = if ($artifact.PSObject.Properties['urlTemplate'] -and -not [string]::IsNullOrWhiteSpace([string]$artifact.urlTemplate)) {
        Resolve-PackageTargetArtifactText -Text ([string]$artifact.urlTemplate) -ArtifactTarget $target -VersionEntry $versionEntry -UpstreamRelease $upstreamRelease
    }
    elseif ($artifact.PSObject.Properties['url'] -and -not [string]::IsNullOrWhiteSpace([string]$artifact.url)) {
        Resolve-PackageTargetArtifactText -Text ([string]$artifact.url) -ArtifactTarget $target -VersionEntry $versionEntry -UpstreamRelease $upstreamRelease
    }
    else {
        $null
    }
    $acquisitionCandidates = @(
        foreach ($source in @($artifactAcquisitionCandidates)) {
            $candidate = ConvertTo-PackageObject -InputObject $source
            if ([string]::Equals([string]$candidate.kind, 'vendorDownload', [System.StringComparison]::OrdinalIgnoreCase)) {
                if ($candidate.PSObject.Properties['urlTemplate'] -and -not [string]::IsNullOrWhiteSpace([string]$candidate.urlTemplate)) {
                    $candidate | Add-Member -MemberType NoteProperty -Name 'url' -Value (Resolve-PackageTargetArtifactText -Text ([string]$candidate.urlTemplate) -ArtifactTarget $target -VersionEntry $versionEntry -UpstreamRelease $upstreamRelease) -Force
                }
                elseif ($candidate.PSObject.Properties['url'] -and -not [string]::IsNullOrWhiteSpace([string]$candidate.url)) {
                    $candidate.url = Resolve-PackageTargetArtifactText -Text ([string]$candidate.url) -ArtifactTarget $target -VersionEntry $versionEntry -UpstreamRelease $upstreamRelease
                }
                elseif (-not [string]::IsNullOrWhiteSpace($artifactUrl)) {
                    $candidate | Add-Member -MemberType NoteProperty -Name 'url' -Value $artifactUrl -Force
                }
                elseif ($candidate.PSObject.Properties['sourcePath'] -and -not [string]::IsNullOrWhiteSpace([string]$candidate.sourcePath)) {
                    $candidate.sourcePath = Resolve-PackageTargetArtifactText -Text ([string]$candidate.sourcePath) -ArtifactTarget $target -VersionEntry $versionEntry -UpstreamRelease $upstreamRelease
                }
                elseif (-not [string]::IsNullOrWhiteSpace($artifactSourcePath)) {
                    $candidate | Add-Member -MemberType NoteProperty -Name 'sourcePath' -Value $artifactSourcePath -Force
                }
            }
            $candidate
        }
    )

    $packageId = if ($artifact.PSObject.Properties['artifactId'] -and -not [string]::IsNullOrWhiteSpace([string]$artifact.artifactId)) {
        [string]$artifact.artifactId
    }
    else {
        '{0}-{1}-{2}' -f [string]$definition.definitionPublication.definitionId, [string]$target.id, [string]$versionEntry.version
    }

    return [pscustomobject]@{
        id                      = $packageId
        artifactId              = [string]$artifact.artifactId
        version                 = [string]$versionEntry.version
        releaseTag              = if ($upstreamRelease -and $upstreamRelease.PSObject.Properties['releaseTag']) { [string]$upstreamRelease.releaseTag } else { $null }
        releaseTrack            = [string]$target.releaseTrack
        artifactDistributionVariant = [string]$target.artifactDistributionVariant
        artifactTargetId        = [string]$target.id
        constraints             = ConvertTo-PackageObject -InputObject $target.constraints
        packageFile             = if ($packageFile) { [pscustomobject]$packageFile } else { $null }
        upstreamRelease         = ConvertTo-PackageObject -InputObject $upstreamRelease
        acquisitionCandidates   = @($acquisitionCandidates | Sort-Object -Property @{ Expression = { if ($_.PSObject.Properties['searchOrder']) { [int]$_.searchOrder } else { [int]::MaxValue } } })
        compatibility           = ConvertTo-PackageObject -InputObject $definition.packageOperations.policy.compatibility
        discovery               = [pscustomobject]@{
            presence        = ConvertTo-PackageObject -InputObject $definition.discovery.presence
            existingInstall = ConvertTo-PackageObject -InputObject $definition.discovery.existingInstall
        }
        ownershipPolicy         = ConvertTo-PackageObject -InputObject $definition.packageOperations.policy.ownershipPolicy
        assigned                = $assigned
        removed                 = ConvertTo-PackageObject -InputObject $definition.packageOperations.removed
            readiness               = New-PackageReadinessFromDiscoveryPresence -Definition $definition -Assigned $assigned
        versionSelection        = [pscustomobject]@{
            source           = [string]$selection.Source
            selector         = [string]$selection.Selector
            kind             = [string]$selection.SelectionKind
            orderingKind     = [string]$selection.OrderingKind
            requestedVersion = $selection.RequestedVersion
            versionRange     = $selection.VersionRange
        }
    }
}


