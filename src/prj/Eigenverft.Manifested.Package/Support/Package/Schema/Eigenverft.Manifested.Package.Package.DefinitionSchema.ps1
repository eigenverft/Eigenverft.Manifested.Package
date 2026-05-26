<#
    Eigenverft.Manifested.Package.Package.DefinitionSchema
    Package definition JSON validation for package definition wire models.

    Runtime validation is PowerShell-only (this module + DefinitionSchema.Wire1_6.ps1). The JSON schema file
    is the editor/agent contract (canonical examples under Endpoint/Defaults); keep schema and asserts aligned.
    Schema 1.7 root description and x-eigenverftAgentHint tell LLMs to author kind=unsigned drafts first and run
    Sign-PackageDefinition after content is final; runtime ignores those hints. See wrk/TEAM-CATALOG-TRUST-POST-IMPLEMENTATION-FINDINGS.md.
#>

$script:PackageDefinitionSupportedSchemaVersions = @(
    '1.6',
    '1.7'
)

function Assert-PackageDefinitionSchemaVersionSupported {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SchemaVersionText,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionDocumentPath
    )

    foreach ($supported in $script:PackageDefinitionSupportedSchemaVersions) {
        if ([string]::Equals($SchemaVersionText, $supported, [System.StringComparison]::Ordinal)) {
            return
        }
    }

    $supportedList = ($script:PackageDefinitionSupportedSchemaVersions | ForEach-Object { "'$_'" }) -join ', '
    throw "Package definition '$DefinitionDocumentPath' uses unsupported schemaVersion '$SchemaVersionText'. Supported schemaVersion values are $supportedList."
}

function Assert-PackageDefinitionSignatureSchema_1_7 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DefinitionDocumentInfo,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId
    )

    $definition = $DefinitionDocumentInfo.Document
    $publication = $definition.definitionPublication
    if (-not $publication.PSObject.Properties['definitionSignature'] -or -not $publication.definitionSignature) {
        throw "Package definition '$DefinitionId' schemaVersion 1.7 is missing definitionPublication.definitionSignature."
    }

    $signature = $publication.definitionSignature
    foreach ($requiredProperty in @('kind', 'format', 'signedContent')) {
        if (-not $signature.PSObject.Properties[$requiredProperty] -or [string]::IsNullOrWhiteSpace([string]$signature.$requiredProperty)) {
            throw "Package definition '$DefinitionId' definitionSignature is missing '$requiredProperty'."
        }
    }

    $kind = [string]$signature.kind
    if ($kind -notin @('signed', 'unsigned')) {
        throw "Package definition '$DefinitionId' definitionSignature.kind must be signed or unsigned."
    }
    if (-not [string]::Equals([string]$signature.format, $script:PackageDefinitionSignatureFormat, [System.StringComparison]::Ordinal)) {
        throw "Package definition '$DefinitionId' definitionSignature.format must be '$script:PackageDefinitionSignatureFormat'."
    }
    if (-not [string]::Equals([string]$signature.signedContent, $script:PackageDefinitionSignedContentKind, [System.StringComparison]::Ordinal)) {
        throw "Package definition '$DefinitionId' definitionSignature.signedContent must be '$script:PackageDefinitionSignedContentKind'."
    }

    if ([string]::Equals($kind, 'unsigned', [System.StringComparison]::OrdinalIgnoreCase)) {
        if ($signature.PSObject.Properties['signatureValue'] -and -not [string]::IsNullOrWhiteSpace([string]$signature.signatureValue)) {
            throw "Package definition '$DefinitionId' unsigned definitionSignature must not define signatureValue."
        }
        return
    }

    foreach ($requiredSignedProperty in @('keyThumbprint', 'signerDisplayName', 'signedAtUtc', 'signatureValue')) {
        if (-not $signature.PSObject.Properties[$requiredSignedProperty] -or [string]::IsNullOrWhiteSpace([string]$signature.$requiredSignedProperty)) {
            throw "Package definition '$DefinitionId' signed definitionSignature is missing '$requiredSignedProperty'."
        }
    }
    if (([string]$signature.keyThumbprint) -notmatch '^[A-Fa-f0-9]{40,128}$') {
        throw "Package definition '$DefinitionId' signed definitionSignature.keyThumbprint is not a hex thumbprint."
    }
    try {
        [Convert]::FromBase64String([string]$signature.signatureValue) | Out-Null
    }
    catch {
        throw "Package definition '$DefinitionId' signed definitionSignature.signatureValue must be base64."
    }
}

function Assert-PackageDefinitionSchema {
<#
.SYNOPSIS
Validates the Package definition schema for this package pass.

    .DESCRIPTION
Rejects retired top-level names, requires schemaVersion 1.6 fields, then
validates dependencies/artifacts/discovery/packageOperations references.

.PARAMETER DefinitionDocumentInfo
The loaded Package definition document info.

.PARAMETER DefinitionId
The expected definition id.

.EXAMPLE
Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId VSCodeRuntime
#>
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
    foreach ($retiredProperty in @(
            'classification',
            'target',
            'origins',
            'interfaces',
            'packageType',
            'paths',
            'sources',
            'packages',
            'entryPoints',
            'packageFamily',
            'managedPaths'
        )) {
        if ($definition.PSObject.Properties[$retiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' still uses retired property '$retiredProperty'."
        }
    }

    $schemaVersionText = [string]$definition.schemaVersion
    if ([string]::IsNullOrWhiteSpace($schemaVersionText)) {
        throw "Package definition '$($DefinitionDocumentInfo.Path)' defines schemaVersion, but it is empty."
    }
    Assert-PackageDefinitionSchemaVersionSupported -SchemaVersionText $schemaVersionText -DefinitionDocumentPath $DefinitionDocumentInfo.Path

    $retiredRootReplacements = @{
        presenceDiscovery        = 'discovery.presence'
        existingInstallDiscovery = 'discovery.existingInstall'
    }
    foreach ($retiredProperty in @($retiredRootReplacements.Keys)) {
        if ($definition.PSObject.Properties[$retiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' still uses retired root property '$retiredProperty'. Use '$($retiredRootReplacements[$retiredProperty])'."
        }
    }

    foreach ($requiredProperty in @('schemaVersion', 'definitionPublication', 'display', 'dependencies', 'artifacts', 'discovery', 'packageOperations')) {
        if (-not $definition.PSObject.Properties[$requiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' is missing required property '$requiredProperty'."
        }
    }
    foreach ($retiredProperty in @('definitionId', 'repositoryId')) {
        if ($definition.PSObject.Properties[$retiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' still uses retired schema 1.4 root property '$retiredProperty'. Move definition identity to definitionPublication."
        }
    }
    foreach ($retiredProperty in @(
            'packageTargets',
            'versionCatalog',
            'upstreamSources',
            'stateDiscovery',
            'installedStateCheck',
            'providedTools',
            'releaseDefaults',
            'existingInstallPolicy'
        )) {
        if ($definition.PSObject.Properties[$retiredProperty]) {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' still uses retired pre-1.3 property '$retiredProperty'."
        }
    }

    switch -Exact ($schemaVersionText) {
        '1.6' {
            Assert-PackageDefinitionSchema_1_6 -DefinitionDocumentInfo $DefinitionDocumentInfo -DefinitionId $DefinitionId -PublisherId $PublisherId
            return
        }
        '1.7' {
            Assert-PackageDefinitionSchema_1_6 -DefinitionDocumentInfo $DefinitionDocumentInfo -DefinitionId $DefinitionId -PublisherId $PublisherId
            Assert-PackageDefinitionSignatureSchema_1_7 -DefinitionDocumentInfo $DefinitionDocumentInfo -DefinitionId $DefinitionId
            return
        }
        default {
            throw "Package definition '$($DefinitionDocumentInfo.Path)' encountered unsupported schemaVersion '$schemaVersionText' after validation gate."
        }
    }
}
