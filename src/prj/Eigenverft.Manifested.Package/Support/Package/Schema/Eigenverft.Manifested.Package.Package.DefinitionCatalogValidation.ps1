<#
    Eigenverft.Manifested.Package.Package.DefinitionCatalogValidation
    Read-only package-definition catalog validation helpers.
#>

function New-PackageDefinitionCatalogValidationIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Error', 'Warning')]
        [string]$Severity,

        [Parameter(Mandatory = $true)]
        [string]$Code,

        [AllowNull()]
        [string]$Path = $null,

        [AllowNull()]
        [string]$PublisherId = $null,

        [AllowNull()]
        [string]$DefinitionId = $null,

        [AllowNull()]
        [string]$JsonPath = $null,

        [AllowNull()]
        [string]$Concept = $null,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [AllowNull()]
        [string]$SuggestedFix = $null
    )

    return [pscustomobject]@{
        Severity     = $Severity
        Code         = $Code
        Path         = $Path
        PublisherId  = $PublisherId
        DefinitionId = $DefinitionId
        JsonPath     = $JsonPath
        Concept      = $Concept
        Message      = $Message
        SuggestedFix = $SuggestedFix
    }
}

function Add-PackageDefinitionCatalogValidationIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Issues,

        [Parameter(Mandatory = $true)]
        [psobject]$Issue
    )

    $Issues.Add($Issue) | Out-Null
    return $Issue
}

function ConvertTo-PackageDefinitionCatalogIdentityKey {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$PublisherId = $null,

        [AllowNull()]
        [string]$DefinitionId = $null
    )

    if ([string]::IsNullOrWhiteSpace($PublisherId) -or [string]::IsNullOrWhiteSpace($DefinitionId)) {
        return $null
    }

    return ('{0}|{1}' -f ([string]$PublisherId).Trim().ToUpperInvariant(), ([string]$DefinitionId).Trim().ToUpperInvariant())
}

function Get-PackageDefinitionCatalogValidationDisplayPath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Path = $null
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    try {
        return [System.IO.Path]::GetFullPath($Path)
    }
    catch {
        return $Path
    }
}

function Get-PackageDefinitionCatalogValidationPathSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $issues = New-Object 'System.Collections.Generic.List[object]'
    $displayPath = Get-PackageDefinitionCatalogValidationDisplayPath -Path $Path
    try {
        $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    }
    catch {
        Add-PackageDefinitionCatalogValidationIssue -Issues $issues -Issue (New-PackageDefinitionCatalogValidationIssue -Severity Error -Code CatalogNoJsonFiles -Path $displayPath -Concept 'catalog.path' -Message ("Package-definition catalog path '{0}' could not be resolved." -f $displayPath) -SuggestedFix 'Provide an existing package-definition JSON file or endpoint folder path.') | Out-Null
        return [pscustomobject]@{
            Path      = $displayPath
            Kind      = 'Missing'
            JsonPaths = @()
            Issues    = @($issues.ToArray())
        }
    }

    $kind = if (Test-Path -LiteralPath $resolvedPath -PathType Leaf) { 'File' } else { 'Directory' }
    $jsonPaths = if ([string]::Equals($kind, 'File', [System.StringComparison]::OrdinalIgnoreCase)) {
        @($resolvedPath)
    }
    else {
        @(Get-PackageDefinitionJsonPathsUnderDirectory -DirectoryPath $resolvedPath)
    }

    if ($jsonPaths.Count -eq 0) {
        Add-PackageDefinitionCatalogValidationIssue -Issues $issues -Issue (New-PackageDefinitionCatalogValidationIssue -Severity Error -Code CatalogNoJsonFiles -Path $resolvedPath -Concept 'catalog.files' -Message ("Package-definition catalog path '{0}' does not contain any JSON files." -f $resolvedPath) -SuggestedFix 'Point the command at a package-definition JSON file or an endpoint folder containing JSON package definitions.') | Out-Null
    }

    return [pscustomobject]@{
        Path      = $resolvedPath
        Kind      = $kind
        JsonPaths = @($jsonPaths)
        Issues    = @($issues.ToArray())
    }
}

function New-PackageDefinitionCatalogValidationEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [pscustomobject]@{
        Path             = $Path
        Parsed           = $false
        SchemaValid      = $false
        SchemaVersion    = $null
        PublisherId      = $null
        DefinitionId     = $null
        SignatureStatus  = $null
        SignatureValid   = $false
        SignatureTrusted = $false
        Document         = $null
        Issues           = (New-Object 'System.Collections.Generic.List[object]')
    }
}

function Update-PackageDefinitionCatalogValidationEntryIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Entry,

        [AllowNull()]
        [psobject]$Document = $null
    )

    if (-not $Document) {
        return
    }

    if ($Document.PSObject.Properties['schemaVersion']) {
        $Entry.SchemaVersion = [string]$Document.schemaVersion
    }

    if ($Document.PSObject.Properties['definitionPublication'] -and $Document.definitionPublication) {
        $publication = $Document.definitionPublication
        if ($publication.PSObject.Properties['publisherId']) {
            $Entry.PublisherId = [string]$publication.publisherId
        }
        if ($publication.PSObject.Properties['definitionId']) {
            $Entry.DefinitionId = [string]$publication.definitionId
        }
    }
}

function Add-PackageDefinitionCatalogSignatureIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Entry,

        [Parameter(Mandatory = $true)]
        [psobject]$SignatureInfo,

        [switch]$RequireTrusted
    )

    $status = [string]$SignatureInfo.Status
    $messageDetail = if ($SignatureInfo.PSObject.Properties['ErrorMessage'] -and -not [string]::IsNullOrWhiteSpace([string]$SignatureInfo.ErrorMessage)) {
        [string]$SignatureInfo.ErrorMessage
    }
    else {
        "Signature status is '$status'."
    }

    if ($status -in @('missingSignature', 'unsigned')) {
        $severity = if ($RequireTrusted.IsPresent) { 'Error' } else { 'Warning' }
        Add-PackageDefinitionCatalogValidationIssue -Issues $Entry.Issues -Issue (New-PackageDefinitionCatalogValidationIssue -Severity $severity -Code PackageDefinitionSignatureUnsigned -Path ([string]$Entry.Path) -PublisherId ([string]$Entry.PublisherId) -DefinitionId ([string]$Entry.DefinitionId) -JsonPath 'definitionPublication.definitionSignature' -Concept 'signature.trust' -Message ("Package definition '{0}' is unsigned or missing a signature." -f [string]$Entry.Path) -SuggestedFix 'Sign the package definition with Sign-PackageDefinition or omit -RequireTrusted for draft validation.') | Out-Null
        return
    }

    if ($status -in @('validUntrusted', 'unknownKey')) {
        $severity = if ($RequireTrusted.IsPresent) { 'Error' } else { 'Warning' }
        Add-PackageDefinitionCatalogValidationIssue -Issues $Entry.Issues -Issue (New-PackageDefinitionCatalogValidationIssue -Severity $severity -Code PackageDefinitionSignatureUntrusted -Path ([string]$Entry.Path) -PublisherId ([string]$Entry.PublisherId) -DefinitionId ([string]$Entry.DefinitionId) -JsonPath 'definitionPublication.definitionSignature' -Concept 'signature.trust' -Message ("Package definition '{0}' signature is not trusted. {1}" -f [string]$Entry.Path, $messageDetail) -SuggestedFix 'Trust the signing certificate, provide -CertificatePath for validation, or omit -RequireTrusted for non-strict validation.') | Out-Null
        return
    }

    if (-not [bool]$SignatureInfo.Valid) {
        Add-PackageDefinitionCatalogValidationIssue -Issues $Entry.Issues -Issue (New-PackageDefinitionCatalogValidationIssue -Severity Error -Code PackageDefinitionSignatureInvalid -Path ([string]$Entry.Path) -PublisherId ([string]$Entry.PublisherId) -DefinitionId ([string]$Entry.DefinitionId) -JsonPath 'definitionPublication.definitionSignature' -Concept 'signature.validity' -Message ("Package definition '{0}' signature is invalid. {1}" -f [string]$Entry.Path, $messageDetail) -SuggestedFix 'Re-sign the package definition after fixing its JSON content, certificate metadata, or signature value.') | Out-Null
        return
    }

    if (-not [bool]$SignatureInfo.Trusted) {
        $severity = if ($RequireTrusted.IsPresent) { 'Error' } else { 'Warning' }
        Add-PackageDefinitionCatalogValidationIssue -Issues $Entry.Issues -Issue (New-PackageDefinitionCatalogValidationIssue -Severity $severity -Code PackageDefinitionSignatureUntrusted -Path ([string]$Entry.Path) -PublisherId ([string]$Entry.PublisherId) -DefinitionId ([string]$Entry.DefinitionId) -JsonPath 'definitionPublication.definitionSignature' -Concept 'signature.trust' -Message ("Package definition '{0}' signature is valid but not trusted." -f [string]$Entry.Path) -SuggestedFix 'Trust the signing certificate or omit -RequireTrusted for non-strict validation.') | Out-Null
    }
}

function Test-PackageDefinitionCatalogDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [AllowNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate = $null,

        [AllowNull()]
        [psobject]$TrustInventoryDocument = $null,

        [switch]$RequireTrusted
    )

    $entry = New-PackageDefinitionCatalogValidationEntry -Path $Path
    try {
        $definitionInfo = Read-PackageJsonDocument -Path $Path
    }
    catch {
        Add-PackageDefinitionCatalogValidationIssue -Issues $entry.Issues -Issue (New-PackageDefinitionCatalogValidationIssue -Severity Error -Code CatalogJsonParseFailed -Path $Path -Concept 'json.parse' -Message $_.Exception.Message -SuggestedFix 'Fix the JSON syntax or file accessibility before validating schema and trust.') | Out-Null
        return $entry
    }

    $entry.Parsed = $true
    $entry.Document = $definitionInfo.Document
    Update-PackageDefinitionCatalogValidationEntryIdentity -Entry $entry -Document $definitionInfo.Document

    $expectedDefinitionId = if ([string]::IsNullOrWhiteSpace([string]$entry.DefinitionId)) { '<unknown>' } else { [string]$entry.DefinitionId }
    $expectedPublisherId = if ([string]::IsNullOrWhiteSpace([string]$entry.PublisherId)) { $null } else { [string]$entry.PublisherId }
    try {
        Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId $expectedDefinitionId -PublisherId $expectedPublisherId
        $entry.SchemaValid = $true
    }
    catch {
        Add-PackageDefinitionCatalogValidationIssue -Issues $entry.Issues -Issue (New-PackageDefinitionCatalogValidationIssue -Severity Error -Code PackageDefinitionSchemaInvalid -Path $Path -PublisherId ([string]$entry.PublisherId) -DefinitionId ([string]$entry.DefinitionId) -Concept 'schema.1.9' -Message $_.Exception.Message -SuggestedFix 'Update the package-definition JSON to satisfy the current schemaVersion 1.9 wire contract.') | Out-Null
    }

    try {
        $signatureInfo = Test-PackageDefinitionSignatureDocument -Definition $definitionInfo.Document -Certificate $Certificate -TrustInventoryDocument $TrustInventoryDocument
        $entry.SignatureStatus = [string]$signatureInfo.Status
        $entry.SignatureValid = [bool]$signatureInfo.Valid
        $entry.SignatureTrusted = [bool]$signatureInfo.Trusted
        Add-PackageDefinitionCatalogSignatureIssue -Entry $entry -SignatureInfo $signatureInfo -RequireTrusted:$RequireTrusted
    }
    catch {
        Add-PackageDefinitionCatalogValidationIssue -Issues $entry.Issues -Issue (New-PackageDefinitionCatalogValidationIssue -Severity Error -Code PackageDefinitionSignatureInvalid -Path $Path -PublisherId ([string]$entry.PublisherId) -DefinitionId ([string]$entry.DefinitionId) -JsonPath 'definitionPublication.definitionSignature' -Concept 'signature.validity' -Message $_.Exception.Message -SuggestedFix 'Fix the definition signature metadata or re-sign the package definition.') | Out-Null
    }

    return $entry
}

function Add-PackageDefinitionCatalogValidationReferenceIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Entry,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Dependency', 'Policy')]
        [string]$ReferenceKind,

        [Parameter(Mandatory = $true)]
        [string]$JsonPath,

        [AllowNull()]
        [string]$ReferencePublisherId = $null,

        [AllowNull()]
        [string]$ReferenceDefinitionId = $null,

        [Parameter(Mandatory = $true)]
        [bool]$SelfReference
    )

    if ([string]::Equals($ReferenceKind, 'Dependency', [System.StringComparison]::OrdinalIgnoreCase)) {
        $code = if ($SelfReference) { 'CatalogDependencySelfReference' } else { 'CatalogDependencyReferenceMissing' }
        $concept = 'dependency.requires'
        $message = if ($SelfReference) {
            "Package definition '$($Entry.DefinitionId)' references itself in dependency.requires."
        }
        else {
            "Package definition '$($Entry.DefinitionId)' references missing dependency '${ReferencePublisherId}:${ReferenceDefinitionId}'."
        }
        $fix = if ($SelfReference) { 'Remove the self dependency from dependency.requires.' } else { 'Add the referenced package definition to the validated endpoint folder or correct the dependency reference.' }
    }
    else {
        $code = if ($SelfReference) { 'CatalogPolicySelfReference' } else { 'CatalogPolicyReferenceMissing' }
        $concept = 'dependency.policy'
        $message = if ($SelfReference) {
            "Package definition '$($Entry.DefinitionId)' references itself in dependency.policy."
        }
        else {
            "Package definition '$($Entry.DefinitionId)' references missing dependency policy target '${ReferencePublisherId}:${ReferenceDefinitionId}'."
        }
        $fix = if ($SelfReference) { 'Remove the self reference from dependency.policy.' } else { 'Add the referenced package definition to the validated endpoint folder or correct the policy reference.' }
    }

    Add-PackageDefinitionCatalogValidationIssue -Issues $Entry.Issues -Issue (New-PackageDefinitionCatalogValidationIssue -Severity Error -Code $code -Path ([string]$Entry.Path) -PublisherId ([string]$Entry.PublisherId) -DefinitionId ([string]$Entry.DefinitionId) -JsonPath $JsonPath -Concept $concept -Message $message -SuggestedFix $fix) | Out-Null
}

function Add-PackageDefinitionCatalogSemanticWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Entry,

        [Parameter(Mandatory = $true)]
        [string]$Code,

        [Parameter(Mandatory = $true)]
        [string]$JsonPath,

        [Parameter(Mandatory = $true)]
        [string]$Concept,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [string]$SuggestedFix
    )

    Add-PackageDefinitionCatalogValidationIssue -Issues $Entry.Issues -Issue (New-PackageDefinitionCatalogValidationIssue -Severity Warning -Code $Code -Path ([string]$Entry.Path) -PublisherId ([string]$Entry.PublisherId) -DefinitionId ([string]$Entry.DefinitionId) -JsonPath $JsonPath -Concept $Concept -Message $Message -SuggestedFix $SuggestedFix) | Out-Null
}

function Get-PackageDefinitionCatalogRequiredPresenceNames {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$Require = $null
    )

    if (-not $Require) {
        return @()
    }

    return @(
        foreach ($name in @('files', 'directories', 'commands', 'apps', 'metadataFiles', 'signatures', 'fileDetails', 'registry', 'powerShellModules')) {
            if ($Require.PSObject.Properties[$name] -and [bool]$Require.$name) {
                $name
            }
        }
    )
}

function Test-PackageDefinitionCatalogSemanticWarnings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Entries
    )

    $schemaValidEntries = @($Entries | Where-Object { [bool]$_.SchemaValid })
    foreach ($entry in @($schemaValidEntries)) {
        $definition = $entry.Document
        if (-not $definition -or -not $definition.PSObject.Properties['packageOperations']) {
            continue
        }

        $assigned = $definition.packageOperations.assigned
        $install = if ($assigned -and $assigned.PSObject.Properties['install']) { $assigned.install } else { $null }
        if (-not $install) {
            continue
        }

        $installKind = if ($install.PSObject.Properties['kind']) { [string]$install.kind } else { $null }
        $targetKind = if ($install.PSObject.Properties['targetKind'] -and -not [string]::IsNullOrWhiteSpace([string]$install.targetKind)) {
            [string]$install.targetKind
        }
        else {
            'directory'
        }
        $hasInstallDirectory = $install.PSObject.Properties['installDirectory'] -and -not [string]::IsNullOrWhiteSpace([string]$install.installDirectory)
        $isMachinePrerequisite = [string]::Equals($targetKind, 'machinePrerequisite', [System.StringComparison]::OrdinalIgnoreCase)
        $installDirectoryOptionalKinds = @('reuseExisting', 'powershellModuleInstaller')
        $installKindAllowsMissingDirectory = @($installDirectoryOptionalKinds | Where-Object { [string]::Equals($_, $installKind, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0

        if (-not $hasInstallDirectory -and -not $isMachinePrerequisite -and -not $installKindAllowsMissingDirectory) {
            Add-PackageDefinitionCatalogSemanticWarning -Entry $entry -Code PackageDefinitionInstallTargetMissing -JsonPath 'packageOperations.assigned.install' -Concept 'install.targetPath' -Message ("Package definition '$($entry.DefinitionId)' uses assigned install kind '$installKind' without installDirectory and without targetKind='machinePrerequisite'. Runtime path resolution usually requires an install target path for this operation.") -SuggestedFix "Add packageOperations.assigned.install.installDirectory, change targetKind to machinePrerequisite only when readiness is install-root-free, or choose a schema operation that does not require a package-owned install directory."
        }

        $argumentsWithInstallDirectory = @(
            foreach ($argument in @($install.commandArguments)) {
                if ($null -ne $argument -and [string]$argument -match '\{installDirectory\}') {
                    [string]$argument
                }
            }
        )
        if ($argumentsWithInstallDirectory.Count -gt 0 -and (-not $hasInstallDirectory -or $isMachinePrerequisite)) {
            Add-PackageDefinitionCatalogSemanticWarning -Entry $entry -Code PackageDefinitionInstallDirectoryArgumentWithoutTarget -JsonPath 'packageOperations.assigned.install.commandArguments' -Concept 'install.arguments.installDirectory' -Message ("Package definition '$($entry.DefinitionId)' passes {installDirectory} in installer arguments, but the install operation does not own an installDirectory usable by that argument.") -SuggestedFix 'Remove the custom install-directory argument, add a real schema installDirectory only for package-managed installs, or stop if the installer-owned default location cannot be represented safely.'
        }

        $readyRequire = if ($assigned.PSObject.Properties['readyStateCheck'] -and $assigned.readyStateCheck.PSObject.Properties['require']) {
            $assigned.readyStateCheck.require
        }
        else {
            $null
        }
        $readyRequired = @(Get-PackageDefinitionCatalogRequiredPresenceNames -Require $readyRequire)
        $installRootReadinessNames = @($readyRequired | Where-Object { $_ -in @('files', 'directories', 'commands', 'apps', 'metadataFiles', 'signatures', 'fileDetails') })
        $installRootFree = $isMachinePrerequisite -or (-not $hasInstallDirectory -and -not $installKindAllowsMissingDirectory)
        if ($installRootFree -and $installRootReadinessNames.Count -gt 0) {
            Add-PackageDefinitionCatalogSemanticWarning -Entry $entry -Code PackageDefinitionInstallRootReadinessWithoutInstallRoot -JsonPath 'packageOperations.assigned.readyStateCheck.require' -Concept 'readiness.installRoot' -Message ("Package definition '$($entry.DefinitionId)' requires install-root readiness checks ($($installRootReadinessNames -join ', ')) but the install operation is install-root-free.") -SuggestedFix 'Use only registry, PowerShell module, or other install-root-free readiness signals, or stop until the schema/runtime can discover the installer-owned install root.'
        }

        $targets = if ($definition.PSObject.Properties['artifacts'] -and $definition.artifacts.PSObject.Properties['targets']) { @($definition.artifacts.targets) } else { @() }
        $cpuValues = @(
            foreach ($target in @($targets)) {
                if ($target.PSObject.Properties['constraints'] -and $target.constraints.PSObject.Properties['cpu']) {
                    foreach ($cpu in @($target.constraints.cpu)) {
                        if (-not [string]::IsNullOrWhiteSpace([string]$cpu)) {
                            [string]$cpu
                        }
                    }
                }
            }
        ) | Sort-Object -Unique
        $architectureSpecificReadinessPaths = @()
        if ($cpuValues.Count -gt 1 -and $installRootReadinessNames.Count -gt 0 -and $definition.PSObject.Properties['discovery'] -and $definition.discovery.PSObject.Properties['presence']) {
            $presence = $definition.discovery.presence
            $readinessPathCandidates = New-Object System.Collections.Generic.List[string]
            foreach ($pathText in @($presence.files) + @($presence.directories)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$pathText)) {
                    $readinessPathCandidates.Add([string]$pathText) | Out-Null
                }
            }
            foreach ($entryPoint in @($presence.commands) + @($presence.apps) + @($presence.signatures) + @($presence.fileDetails) + @($presence.metadataFiles)) {
                if ($entryPoint -and $entryPoint.PSObject.Properties['relativePath'] -and -not [string]::IsNullOrWhiteSpace([string]$entryPoint.relativePath)) {
                    $readinessPathCandidates.Add([string]$entryPoint.relativePath) | Out-Null
                }
            }
            $architectureSpecificReadinessPaths = @(
                $readinessPathCandidates.ToArray() |
                    Where-Object { [regex]::IsMatch([string]$_, '(?i)(x64|x86|amd64|arm64|aarch64|win64|win32|64(?=\.|_|-|$)|32(?=\.|_|-|$))') } |
                    Sort-Object -Unique
            )
        }
        if ($cpuValues.Count -gt 1 -and $architectureSpecificReadinessPaths.Count -gt 0) {
            Add-PackageDefinitionCatalogSemanticWarning -Entry $entry -Code PackageDefinitionSharedReadinessAcrossArchitectures -JsonPath 'discovery.presence' -Concept 'readiness.targetArchitecture' -Message ("Package definition '$($entry.DefinitionId)' has multiple CPU targets ($($cpuValues -join ', ')) but shared readiness contains architecture-specific install-root paths: $($architectureSpecificReadinessPaths -join ', '). A shared readiness model must be valid for every selectable target.") -SuggestedFix 'Use an artifact that satisfies one shared readiness model, make readiness target-independent, or stop for a schema/runtime decision before mixing architecture-specific executable/file expectations.'
        }

        $removed = if ($definition.packageOperations.PSObject.Properties['removed']) { $definition.packageOperations.removed } else { $null }
        if ($removed) {
            $operation = if ($removed.PSObject.Properties['operation']) { $removed.operation } else { $null }
            $operationKind = if ($operation -and $operation.PSObject.Properties['kind']) { [string]$operation.kind } else { $null }
            $absenceRequire = if ($removed.PSObject.Properties['absenceVerification'] -and $removed.absenceVerification.PSObject.Properties['require']) {
                $removed.absenceVerification.require
            }
            else {
                $null
            }
            $absenceRequired = @(Get-PackageDefinitionCatalogRequiredPresenceNames -Require $absenceRequire)
            if ([string]::Equals($operationKind, 'none', [System.StringComparison]::OrdinalIgnoreCase) -and $absenceRequired.Count -gt 0) {
                Add-PackageDefinitionCatalogSemanticWarning -Entry $entry -Code PackageDefinitionNoOpRemovalRequiresAbsence -JsonPath 'packageOperations.removed.absenceVerification.require' -Concept 'removed.noopAbsence' -Message ("Package definition '$($entry.DefinitionId)' uses removed.operation.kind='none' but still requires absence signals after removal: $($absenceRequired -join ', '). A no-op removal cannot make those signals absent.") -SuggestedFix 'Use a schema-supported uninstaller/removal operation, disable absence requirements that the no-op cannot change, or stop if removed state cannot be represented.'
            }
        }

        if ($isMachinePrerequisite -and -not $hasInstallDirectory) {
            Add-PackageDefinitionCatalogSemanticWarning -Entry $entry -Code PackageDefinitionMachinePrerequisiteRemovalInventoryRisk -JsonPath 'packageOperations.assigned.install.targetKind' -Concept 'removed.inventoryInstallDirectory' -Message ("Package definition '$($entry.DefinitionId)' is a machinePrerequisite without installDirectory. Assignment can create a PackageApplied inventory record without installDirectory, while removal flows currently require inventory.installDirectory before executing removed.operation.") -SuggestedFix 'Prove removed-state handling does not require inventory.installDirectory, avoid claiming removed-state support, or add schema/runtime support for machine-prerequisite forget/removal semantics.'
        }
    }
}

function Test-PackageDefinitionCatalogStaticReferences {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Entries
    )

    $schemaValidEntries = @($Entries | Where-Object { [bool]$_.SchemaValid })
    $targetsByKey = @{}
    foreach ($entry in @($schemaValidEntries)) {
        $key = ConvertTo-PackageDefinitionCatalogIdentityKey -PublisherId ([string]$entry.PublisherId) -DefinitionId ([string]$entry.DefinitionId)
        if ($key) {
            $targetsByKey[$key] = $entry
        }
    }

    foreach ($entry in @($schemaValidEntries)) {
        $sourceKey = ConvertTo-PackageDefinitionCatalogIdentityKey -PublisherId ([string]$entry.PublisherId) -DefinitionId ([string]$entry.DefinitionId)
        $dependencyModel = Get-PackageDefinitionDependencyModel_1_9 -Definition $entry.Document -DefinitionId ([string]$entry.DefinitionId)
        $dependencyIndex = 0
        foreach ($dependency in @($dependencyModel.Requires)) {
            if ($null -eq $dependency) {
                $dependencyIndex++
                continue
            }
            $referencePublisherId = if ($dependency.PSObject.Properties['publisherId'] -and -not [string]::IsNullOrWhiteSpace([string]$dependency.publisherId)) { [string]$dependency.publisherId } else { [string]$entry.PublisherId }
            $referenceDefinitionId = if ($dependency.PSObject.Properties['definitionId']) { [string]$dependency.definitionId } else { $null }
            $referenceKey = ConvertTo-PackageDefinitionCatalogIdentityKey -PublisherId $referencePublisherId -DefinitionId $referenceDefinitionId
            $jsonPath = 'dependency.requires[{0}]' -f $dependencyIndex
            if ($referenceKey -and [string]::Equals($referenceKey, $sourceKey, [System.StringComparison]::OrdinalIgnoreCase)) {
                Add-PackageDefinitionCatalogValidationReferenceIssue -Entry $entry -ReferenceKind Dependency -JsonPath $jsonPath -ReferencePublisherId $referencePublisherId -ReferenceDefinitionId $referenceDefinitionId -SelfReference $true
            }
            elseif ($referenceKey -and -not $targetsByKey.ContainsKey($referenceKey)) {
                Add-PackageDefinitionCatalogValidationReferenceIssue -Entry $entry -ReferenceKind Dependency -JsonPath $jsonPath -ReferencePublisherId $referencePublisherId -ReferenceDefinitionId $referenceDefinitionId -SelfReference $false
            }
            $dependencyIndex++
        }

        foreach ($policyPropertyName in @('conflictsWith', 'requiresAbsent')) {
            $policyReferences = if ($dependencyModel.Policy -and $dependencyModel.Policy.PSObject.Properties[$policyPropertyName]) { @($dependencyModel.Policy.$policyPropertyName) } else { @() }
            $policyIndex = 0
            foreach ($policyReference in @($policyReferences)) {
                if ($null -eq $policyReference) {
                    $policyIndex++
                    continue
                }
                $referencePublisherId = if ($policyReference.PSObject.Properties['publisherId'] -and -not [string]::IsNullOrWhiteSpace([string]$policyReference.publisherId)) { [string]$policyReference.publisherId } else { [string]$entry.PublisherId }
                $referenceDefinitionId = if ($policyReference.PSObject.Properties['definitionId']) { [string]$policyReference.definitionId } else { $null }
                $referenceKey = ConvertTo-PackageDefinitionCatalogIdentityKey -PublisherId $referencePublisherId -DefinitionId $referenceDefinitionId
                $jsonPath = 'dependency.policy.{0}[{1}]' -f $policyPropertyName, $policyIndex
                if ($referenceKey -and [string]::Equals($referenceKey, $sourceKey, [System.StringComparison]::OrdinalIgnoreCase)) {
                    Add-PackageDefinitionCatalogValidationReferenceIssue -Entry $entry -ReferenceKind Policy -JsonPath $jsonPath -ReferencePublisherId $referencePublisherId -ReferenceDefinitionId $referenceDefinitionId -SelfReference $true
                }
                elseif ($referenceKey -and -not $targetsByKey.ContainsKey($referenceKey)) {
                    Add-PackageDefinitionCatalogValidationReferenceIssue -Entry $entry -ReferenceKind Policy -JsonPath $jsonPath -ReferencePublisherId $referencePublisherId -ReferenceDefinitionId $referenceDefinitionId -SelfReference $false
                }
                $policyIndex++
            }
        }
    }
}

function Add-PackageDefinitionCatalogDuplicateIdentityIssues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Entries
    )

    $entriesByKey = @{}
    foreach ($entry in @($Entries | Where-Object { [bool]$_.SchemaValid })) {
        $key = ConvertTo-PackageDefinitionCatalogIdentityKey -PublisherId ([string]$entry.PublisherId) -DefinitionId ([string]$entry.DefinitionId)
        if (-not $key) {
            continue
        }
        if (-not $entriesByKey.ContainsKey($key)) {
            $entriesByKey[$key] = New-Object 'System.Collections.Generic.List[object]'
        }
        $entriesByKey[$key].Add($entry) | Out-Null
    }

    foreach ($key in @($entriesByKey.Keys)) {
        $duplicates = @($entriesByKey[$key].ToArray())
        if ($duplicates.Count -le 1) {
            continue
        }
        $paths = (@($duplicates) | ForEach-Object { [string]$_.Path }) -join ', '
        foreach ($entry in @($duplicates)) {
            Add-PackageDefinitionCatalogValidationIssue -Issues $entry.Issues -Issue (New-PackageDefinitionCatalogValidationIssue -Severity Error -Code CatalogDuplicateDefinitionIdentity -Path ([string]$entry.Path) -PublisherId ([string]$entry.PublisherId) -DefinitionId ([string]$entry.DefinitionId) -JsonPath 'definitionPublication' -Concept 'catalog.identity' -Message ("Package definition identity '{0}:{1}' appears more than once in this catalog: {2}" -f [string]$entry.PublisherId, [string]$entry.DefinitionId, $paths) -SuggestedFix 'Keep only one JSON file per publisherId and definitionId in the validated catalog folder.') | Out-Null
        }
    }
}

function Add-PackageDefinitionCatalogMixedSchemaVersionIssues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Entries,

        [switch]$StrictSchemaVersion
    )

    $schemaVersions = @($Entries | Where-Object { [bool]$_.Parsed -and -not [string]::IsNullOrWhiteSpace([string]$_.SchemaVersion) } | ForEach-Object { [string]$_.SchemaVersion } | Sort-Object -Unique)
    if ($schemaVersions.Count -le 1) {
        return
    }

    $severity = if ($StrictSchemaVersion.IsPresent) { 'Error' } else { 'Warning' }
    $message = "Package-definition catalog contains mixed schemaVersion values: $($schemaVersions -join ', ')."
    foreach ($entry in @($Entries | Where-Object { [bool]$_.Parsed -and -not [string]::IsNullOrWhiteSpace([string]$_.SchemaVersion) })) {
        Add-PackageDefinitionCatalogValidationIssue -Issues $entry.Issues -Issue (New-PackageDefinitionCatalogValidationIssue -Severity $severity -Code CatalogMixedSchemaVersion -Path ([string]$entry.Path) -PublisherId ([string]$entry.PublisherId) -DefinitionId ([string]$entry.DefinitionId) -JsonPath 'schemaVersion' -Concept 'catalog.schemaVersion' -Message $message -SuggestedFix 'Use one supported schemaVersion across the endpoint folder, currently schemaVersion 1.9.') | Out-Null
    }
}

function New-PackageDefinitionCatalogValidationFileResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Entry
    )

    $issues = @($Entry.Issues.ToArray())
    return [pscustomobject]@{
        Path             = [string]$Entry.Path
        Parsed           = [bool]$Entry.Parsed
        SchemaValid      = [bool]$Entry.SchemaValid
        SchemaVersion    = if ([string]::IsNullOrWhiteSpace([string]$Entry.SchemaVersion)) { $null } else { [string]$Entry.SchemaVersion }
        PublisherId      = if ([string]::IsNullOrWhiteSpace([string]$Entry.PublisherId)) { $null } else { [string]$Entry.PublisherId }
        DefinitionId     = if ([string]::IsNullOrWhiteSpace([string]$Entry.DefinitionId)) { $null } else { [string]$Entry.DefinitionId }
        SignatureStatus  = if ([string]::IsNullOrWhiteSpace([string]$Entry.SignatureStatus)) { $null } else { [string]$Entry.SignatureStatus }
        SignatureValid   = [bool]$Entry.SignatureValid
        SignatureTrusted = [bool]$Entry.SignatureTrusted
        ErrorCount       = @($issues | Where-Object { [string]$_.Severity -eq 'Error' }).Count
        WarningCount     = @($issues | Where-Object { [string]$_.Severity -eq 'Warning' }).Count
        Issues           = @($issues)
    }
}

function Invoke-PackageDefinitionCatalogValidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [AllowNull()]
        [string]$CertificatePath = $null,

        [switch]$RequireTrusted,

        [switch]$StrictSchemaVersion
    )

    $pathSet = Get-PackageDefinitionCatalogValidationPathSet -Path $Path
    $certificate = $null
    $trustInventoryDocument = $null
    $entries = New-Object 'System.Collections.Generic.List[object]'
    try {
        if (@($pathSet.JsonPaths).Count -gt 0) {
            if (-not [string]::IsNullOrWhiteSpace($CertificatePath)) {
                $certificate = Import-PackageCertificate -Path $CertificatePath
            }
            else {
                $trustInventoryDocument = (Get-PackageTrustInventoryInfo).Document
            }

            foreach ($jsonPath in @($pathSet.JsonPaths)) {
                $entries.Add((Test-PackageDefinitionCatalogDocument -Path $jsonPath -Certificate $certificate -TrustInventoryDocument $trustInventoryDocument -RequireTrusted:$RequireTrusted)) | Out-Null
            }
        }

        if ([string]::Equals([string]$pathSet.Kind, 'Directory', [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-PackageDefinitionCatalogDuplicateIdentityIssues -Entries @($entries.ToArray())
            Add-PackageDefinitionCatalogMixedSchemaVersionIssues -Entries @($entries.ToArray()) -StrictSchemaVersion:$StrictSchemaVersion
            Test-PackageDefinitionCatalogStaticReferences -Entries @($entries.ToArray())
        }
        Test-PackageDefinitionCatalogSemanticWarnings -Entries @($entries.ToArray())
    }
    finally {
        if ($certificate) {
            $certificate.Dispose()
        }
    }

    $results = @(
        foreach ($entry in @($entries.ToArray())) {
            New-PackageDefinitionCatalogValidationFileResult -Entry $entry
        }
    )
    $issues = @(@($pathSet.Issues) + @($results | ForEach-Object { @($_.Issues) }))
    $errorCount = @($issues | Where-Object { [string]$_.Severity -eq 'Error' }).Count
    $warningCount = @($issues | Where-Object { [string]$_.Severity -eq 'Warning' }).Count

    return [pscustomobject]@{
        Path                = [string]$pathSet.Path
        Kind                = [string]$pathSet.Kind
        Valid               = ($errorCount -eq 0)
        CheckedCount        = $results.Count
        ParsedCount         = @($results | Where-Object { [bool]$_.Parsed }).Count
        SchemaValidCount    = @($results | Where-Object { [bool]$_.SchemaValid }).Count
        TrustedCount        = @($results | Where-Object { [bool]$_.SignatureTrusted }).Count
        ErrorCount          = $errorCount
        WarningCount        = $warningCount
        RequireTrusted      = [bool]$RequireTrusted.IsPresent
        StrictSchemaVersion = [bool]$StrictSchemaVersion.IsPresent
        Issues              = @($issues)
        Results             = @($results)
    }
}
