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
