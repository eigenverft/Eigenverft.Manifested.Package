<#
    Eigenverft.Manifested.Sandbox.Package - PackageEndpointInventory.json management helpers.
#>

function Assert-PackageEndpointName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EndpointName
    )

    if ([string]::IsNullOrWhiteSpace($EndpointName)) {
        throw 'Package endpoint name must not be empty.'
    }
    if ($EndpointName -notmatch '^[A-Za-z][A-Za-z0-9_-]*$') {
        throw "Package endpoint name '$EndpointName' is invalid. Use letters, numbers, '-' or '_' and start with a letter."
    }
}

function Get-PackageEndpointSourceEntries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document
    )

    if (-not $Document.PSObject.Properties['endpoints'] -or $null -eq $Document.endpoints) {
        return @()
    }
    if ($Document.endpoints -isnot [System.Array]) {
        throw "Package endpoint inventory must define endpoints as an array of objects with endpointName. The keyed-object endpoints shape is retired."
    }

    return @($Document.endpoints)
}

function Assert-PackageEndpointSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EndpointName,

        [Parameter(Mandatory = $true)]
        [psobject]$SourceValue,

        [Parameter(Mandatory = $true)]
        [string]$DocumentPath
    )

    foreach ($requiredProperty in @('endpointName', 'kind', 'enabled', 'searchOrder')) {
        if (-not $SourceValue.PSObject.Properties[$requiredProperty]) {
            throw "Package endpoint '$EndpointName' in '$DocumentPath' is missing '$requiredProperty'."
        }
    }
    if (-not [string]::Equals([string]$SourceValue.endpointName, $EndpointName, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Package endpoint '$EndpointName' in '$DocumentPath' has mismatched endpointName '$($SourceValue.endpointName)'."
    }
    if ($SourceValue.PSObject.Properties['priority']) {
        throw "Package endpoint '$EndpointName' in '$DocumentPath' still uses retired property 'priority'. Use 'searchOrder'."
    }
    foreach ($retiredTrustProperty in @('trusted', 'trustMode', 'trustedAtUtc', 'trustReason')) {
        if ($SourceValue.PSObject.Properties[$retiredTrustProperty]) {
            throw "Package endpoint '$EndpointName' in '$DocumentPath' still uses retired property '$retiredTrustProperty'. Endpoint inventory defines scan locations only; use PackagePublisherInventory.json for publisher trust."
        }
    }

    $kind = [string]$SourceValue.kind
    if ($kind -notin @('moduleLocal', 'filesystem', 'httpsCatalog')) {
        throw "Package endpoint '$EndpointName' in '$DocumentPath' has unsupported kind '$kind'."
    }

    if ([string]::Equals($kind, 'moduleLocal', [System.StringComparison]::OrdinalIgnoreCase)) {
        if (-not $SourceValue.PSObject.Properties['definitionRoot'] -or [string]::IsNullOrWhiteSpace([string]$SourceValue.definitionRoot)) {
            throw "Package endpoint '$EndpointName' in '$DocumentPath' is missing definitionRoot."
        }
    }
    elseif ([string]::Equals($kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
        if (-not $SourceValue.PSObject.Properties['basePath'] -or [string]::IsNullOrWhiteSpace([string]$SourceValue.basePath)) {
            throw "Package endpoint '$EndpointName' in '$DocumentPath' is missing basePath."
        }
    }
    elseif ([string]::Equals($kind, 'httpsCatalog', [System.StringComparison]::OrdinalIgnoreCase)) {
        foreach ($requiredHttpsProperty in @('baseUri', 'catalogPath')) {
            if (-not $SourceValue.PSObject.Properties[$requiredHttpsProperty] -or [string]::IsNullOrWhiteSpace([string]$SourceValue.$requiredHttpsProperty)) {
                throw "Package endpoint '$EndpointName' in '$DocumentPath' kind httpsCatalog is missing $requiredHttpsProperty."
            }
        }
    }
}

function Assert-PackageEndpointInventorySchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$EndpointInventoryDocumentInfo
    )

    $document = $EndpointInventoryDocumentInfo.Document
    if (-not $document.PSObject.Properties['inventoryVersion']) {
        throw "Package endpoint inventory '$($EndpointInventoryDocumentInfo.Path)' is missing inventoryVersion."
    }
    if (-not $document.PSObject.Properties['endpoints'] -or $null -eq $document.endpoints) {
        throw "Package endpoint inventory '$($EndpointInventoryDocumentInfo.Path)' is missing endpoints."
    }

    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($source in @(Get-PackageEndpointSourceEntries -Document $document)) {
        if (-not $source.PSObject.Properties['endpointName'] -or [string]::IsNullOrWhiteSpace([string]$source.endpointName)) {
            throw "Package endpoint inventory '$($EndpointInventoryDocumentInfo.Path)' has an endpoint without endpointName."
        }
        $endpointName = [string]$source.endpointName
        if (-not $seen.Add($endpointName)) {
            throw "Package endpoint inventory '$($EndpointInventoryDocumentInfo.Path)' defines duplicate endpointName '$endpointName'."
        }
        Assert-PackageEndpointSource -EndpointName $endpointName -SourceValue $source -DocumentPath $EndpointInventoryDocumentInfo.Path
    }
}

function Get-PackageEndpointInventoryInfo {
    [CmdletBinding()]
    param()

    $inventoryPath = Get-PackageEndpointInventoryPath
    $documentInfo = Read-PackageJsonDocument -Path $inventoryPath
    Assert-PackageEndpointInventorySchema -EndpointInventoryDocumentInfo $documentInfo
    $documentInfo | Add-Member -MemberType NoteProperty -Name Exists -Value $true -Force
    return $documentInfo
}

function Get-PackageEndpointInventoryEditInfo {
    [CmdletBinding()]
    param()

    $documentInfo = Get-PackageEndpointInventoryInfo
    if (-not $documentInfo.Document.PSObject.Properties['endpoints'] -or $null -eq $documentInfo.Document.endpoints) {
        $documentInfo.Document | Add-Member -MemberType NoteProperty -Name 'endpoints' -Value @() -Force
    }
    return $documentInfo
}

function Save-PackageEndpointInventoryDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DocumentInfo
    )

    Assert-PackageEndpointInventorySchema -EndpointInventoryDocumentInfo $DocumentInfo

    $directory = Split-Path -Parent $DocumentInfo.Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        $null = New-Item -ItemType Directory -Path $directory -Force
    }

    $temporaryPath = '{0}.{1}.tmp' -f $DocumentInfo.Path, ([guid]::NewGuid().ToString('N'))
    try {
        $DocumentInfo.Document | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
        Move-Item -LiteralPath $temporaryPath -Destination $DocumentInfo.Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-PackageEndpointSourceProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document,

        [Parameter(Mandatory = $true)]
        [string]$EndpointName
    )

    foreach ($source in @(Get-PackageEndpointSourceEntries -Document $Document)) {
        if ($source.PSObject.Properties['endpointName'] -and
            [string]::Equals([string]$source.endpointName, $EndpointName, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{
                Name  = [string]$source.endpointName
                Value = $source
            }
        }
    }

    return $null
}

function Get-PackageNextEndpointSearchOrder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document
    )

    $maxSearchOrder = 0
    foreach ($source in @(Get-PackageEndpointSourceEntries -Document $Document)) {
        if ($source -and $source.PSObject.Properties['searchOrder']) {
            $current = [int]$source.searchOrder
            if ($current -gt $maxSearchOrder) {
                $maxSearchOrder = $current
            }
        }
    }

    return ([int]([Math]::Ceiling(($maxSearchOrder + 1) / 100.0) * 100))
}

function Get-PackageEndpointSearchOrderAfter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document,

        [Parameter(Mandatory = $true)]
        [string]$AfterEndpointName
    )

    $afterProperty = Get-PackageEndpointSourceProperty -Document $Document -EndpointName $AfterEndpointName
    if (-not $afterProperty) {
        throw "Package endpoint '$AfterEndpointName' was not found, so no searchOrder can be placed after it."
    }
    if (-not $afterProperty.Value.PSObject.Properties['searchOrder']) {
        throw "Package endpoint '$AfterEndpointName' has no searchOrder."
    }

    $afterOrder = [int]$afterProperty.Value.searchOrder
    $nextHigherOrder = $null
    foreach ($source in @(Get-PackageEndpointSourceEntries -Document $Document)) {
        if (-not $source -or -not $source.PSObject.Properties['searchOrder']) {
            continue
        }

        $currentOrder = [int]$source.searchOrder
        if ($currentOrder -gt $afterOrder -and ($null -eq $nextHigherOrder -or $currentOrder -lt $nextHigherOrder)) {
            $nextHigherOrder = $currentOrder
        }
    }

    if ($null -eq $nextHigherOrder) {
        return ($afterOrder + 100)
    }

    $candidate = [int][Math]::Floor(($afterOrder + $nextHigherOrder) / 2)
    if ($candidate -le $afterOrder -or $candidate -ge $nextHigherOrder) {
        throw "No integer searchOrder slot is available between '$AfterEndpointName' ($afterOrder) and the next endpoint ($nextHigherOrder). Use -SearchOrder explicitly."
    }

    return $candidate
}

function New-PackageFilesystemEndpointSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EndpointName,

        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [int]$SearchOrder,

        [bool]$Enabled = $true
    )

    if ([string]::IsNullOrWhiteSpace($BasePath)) {
        throw 'BasePath must not be empty.'
    }

    $source = [ordered]@{
        endpointName = $EndpointName
        kind        = 'filesystem'
        enabled     = $Enabled
        searchOrder = $SearchOrder
        basePath    = $BasePath
    }

    return [pscustomobject]$source
}

function Resolve-PackageEndpointRootForDisplay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Source,

        [AllowNull()]
        [string]$ApplicationRootDirectory = $null
    )

    $kind = [string]$Source.kind
    try {
        if ([string]::Equals($kind, 'moduleLocal', [System.StringComparison]::OrdinalIgnoreCase)) {
            return Resolve-ConfiguredPath -PathValue ([string]$Source.definitionRoot) -BaseDirectory (Split-Path -Parent (Get-PackageConfigurationRoot)) -Tokens @{}
        }
        if ([string]::Equals($kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
            if (-not [string]::IsNullOrWhiteSpace($ApplicationRootDirectory)) {
                return Resolve-PackageConfiguredPath -PathValue ([string]$Source.basePath) -ApplicationRootDirectory $ApplicationRootDirectory
            }
            return Resolve-PackagePathValue -PathValue ([string]$Source.basePath)
        }
    }
    catch {
        return $null
    }

    return $null
}

function Get-PackageFileSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Select-PackageEndpointSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EndpointName,

        [Parameter(Mandatory = $true)]
        [psobject]$Source,

        [Parameter(Mandatory = $true)]
        [string]$InventoryPath,

        [AllowNull()]
        [string]$ApplicationRootDirectory = $null
    )

    $enabled = if ($Source.PSObject.Properties['enabled']) { [bool]$Source.enabled } else { $true }
    $kind = if ($Source.PSObject.Properties['kind']) { [string]$Source.kind } else { $null }

    $notes = New-Object System.Collections.Generic.List[string]
    if (-not $enabled) {
        $notes.Add('Disabled; package commands will not use this endpoint.') | Out-Null
    }
    if ($kind -eq 'httpsCatalog') {
        $notes.Add('HTTPS catalog endpoints are reserved for future support and are not executable in v1.') | Out-Null
    }
    $notes.Add('Definition execution is controlled by PackagePublisherInventory.json publisher trust.') | Out-Null

    return [pscustomobject]@{
        SourceId         = $EndpointName
        EndpointName     = $EndpointName
        Kind             = $kind
        Enabled          = $enabled
        Effective        = ($enabled -and $kind -in @('moduleLocal', 'filesystem'))
        SearchOrder      = if ($Source.PSObject.Properties['searchOrder']) { [int]$Source.searchOrder } else { $null }
        DefinitionRoot   = if ($Source.PSObject.Properties['definitionRoot']) { [string]$Source.definitionRoot } else { $null }
        BasePath         = if ($Source.PSObject.Properties['basePath']) { [string]$Source.basePath } else { $null }
        ResolvedRootPath = Resolve-PackageEndpointRootForDisplay -Source $Source -ApplicationRootDirectory $ApplicationRootDirectory
        InventoryPath    = $InventoryPath
        Notes            = @($notes.ToArray())
    }
}

function Get-PackageEndpointSummaries {
    [CmdletBinding()]
    param()

    $documentInfo = Get-PackageEndpointInventoryEditInfo
    $applicationRootDirectory = $null
    try {
        $globalDocumentInfo = Read-PackageJsonDocument -Path (Get-PackageConfigPath)
        Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalDocumentInfo
        $applicationRootDirectory = Resolve-PackageApplicationRootDirectory -PackageConfiguration $globalDocumentInfo.Document.package
    }
    catch {
        Write-Warning "Endpoint summaries could not resolve application root. Showing raw endpoint inventory only. $($_.Exception.Message)"
    }

    foreach ($source in @(Get-PackageEndpointSourceEntries -Document $documentInfo.Document)) {
        Select-PackageEndpointSummary -EndpointName ([string]$source.endpointName) -Source $source -InventoryPath $documentInfo.Path -ApplicationRootDirectory $applicationRootDirectory
    }
}

function New-PackageEndpointCommandResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$EndpointName,

        [Parameter(Mandatory = $true)]
        [string]$InventoryPath,

        [AllowNull()]
        [psobject]$Before,

        [AllowNull()]
        [psobject]$After,

        [string]$Status = 'Updated',

        [string[]]$Notes = @()
    )

    foreach ($note in @($Notes)) {
        if (-not [string]::IsNullOrWhiteSpace($note)) {
            Write-Warning $note
        }
    }

    return [pscustomobject]@{
        Action               = $Action
        EndpointName         = $EndpointName
        SourceId             = $EndpointName
        InventoryPath        = $InventoryPath
        Status               = $Status
        Before               = $Before
        After                = $After
        Notes                = @($Notes)
    }
}

function Resolve-PackageEndpointRootPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EndpointName,

        [Parameter(Mandatory = $true)]
        [psobject]$Source,

        [AllowNull()]
        [string]$ApplicationRootDirectory = $null
    )

    $kind = [string]$Source.kind
    if (-not [bool]$Source.enabled) {
        throw "Package endpoint '$EndpointName' is disabled in PackageEndpointInventory.json."
    }

    if ([string]::Equals($kind, 'moduleLocal', [System.StringComparison]::OrdinalIgnoreCase)) {
        return Resolve-ConfiguredPath -PathValue ([string]$Source.definitionRoot) -BaseDirectory (Split-Path -Parent (Get-PackageConfigurationRoot)) -Tokens @{}
    }

    if ([string]::Equals($kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
        if (-not [string]::IsNullOrWhiteSpace($ApplicationRootDirectory)) {
            return Resolve-PackageConfiguredPath -PathValue ([string]$Source.basePath) -ApplicationRootDirectory $ApplicationRootDirectory
        }
        return Resolve-PackagePathValue -PathValue ([string]$Source.basePath)
    }

    if ([string]::Equals($kind, 'httpsCatalog', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Package endpoint '$EndpointName' uses kind 'httpsCatalog', which is reserved for future support and is not implemented yet."
    }

    throw "Package endpoint '$EndpointName' uses unsupported kind '$kind'."
}

function Resolve-PackageDefinitionSnapshotReference {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$PublisherId = $null,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [Parameter(Mandatory = $true)]
        [string]$PackageAssignmentInventoryFilePath,

        [AllowNull()]
        [string]$LiveResolutionError = $null
    )

    if (-not (Test-Path -LiteralPath $PackageAssignmentInventoryFilePath -PathType Leaf)) {
        throw "Package definition '$DefinitionId' could not be resolved from package inventory because '$PackageAssignmentInventoryFilePath' does not exist. Live error: $LiveResolutionError"
    }

    $inventoryInfo = Read-PackageJsonDocument -Path $PackageAssignmentInventoryFilePath
    $records = @(
        foreach ($record in @($inventoryInfo.Document.records)) {
            if (-not [string]::Equals([string]$record.definitionId, $DefinitionId, [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }
            if (-not [string]::IsNullOrWhiteSpace($PublisherId)) {
                $recordPublisherId = if ($record.PSObject.Properties['definitionPublisherId']) { [string]$record.definitionPublisherId } else { $null }
                if (-not [string]::Equals($recordPublisherId, $PublisherId, [System.StringComparison]::OrdinalIgnoreCase)) {
                    continue
                }
            }

            $snapshotPath = if ($record.PSObject.Properties['definitionAssignedSnapshotPath']) { [string]$record.definitionAssignedSnapshotPath } else { $null }
            if (-not [string]::IsNullOrWhiteSpace($snapshotPath) -and (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) {
                $record
            }
        }
    )

    if ($records.Count -eq 0) {
        throw "Package definition '$DefinitionId' could not be resolved from configured endpoints, and no usable assigned definition snapshot was found in '$PackageAssignmentInventoryFilePath'. Live error: $LiveResolutionError"
    }

    $selectedRecord = @($records | Sort-Object -Property updatedAtUtc -Descending | Select-Object -First 1)[0]
    $selectedSnapshotPath = [string]$selectedRecord.definitionAssignedSnapshotPath
    $endpointName = if ($selectedRecord.PSObject.Properties['definitionEndpointName']) { [string]$selectedRecord.definitionEndpointName } else { $null }

    return [pscustomobject]@{
        EndpointName       = $endpointName
        DefinitionId       = [string]$DefinitionId
        DefinitionPath     = [System.IO.Path]::GetFullPath($selectedSnapshotPath)
        SourceKind         = 'assignedSnapshot'
        SourcePath         = if ($selectedRecord.PSObject.Properties['definitionSourcePath']) { [string]$selectedRecord.definitionSourcePath } else { $null }
        SourceHash         = if ($selectedRecord.PSObject.Properties['definitionSourceHash']) { [string]$selectedRecord.definitionSourceHash } else { $null }
        SnapshotPath       = [System.IO.Path]::GetFullPath($selectedSnapshotPath)
        SnapshotHash       = Get-PackageFileSha256 -Path $selectedSnapshotPath
        CandidatePath      = if ($selectedRecord.PSObject.Properties['definitionCandidatePath']) { [string]$selectedRecord.definitionCandidatePath } else { $null }
        CandidateHash      = if ($selectedRecord.PSObject.Properties['definitionCandidateHash']) { [string]$selectedRecord.definitionCandidateHash } else { $null }
        ResolvedAtUtc      = [DateTime]::UtcNow.ToString('o')
        SnapshotFallback   = $true
        FallbackReason     = $LiveResolutionError
        InventoryRecord    = $selectedRecord
        PublisherId        = if ($selectedRecord.PSObject.Properties['definitionPublisherId']) { [string]$selectedRecord.definitionPublisherId } else { $null }
        PublisherName      = if ($selectedRecord.PSObject.Properties['definitionPublisherName']) { [string]$selectedRecord.definitionPublisherName } else { $null }
        DefinitionRevision = if ($selectedRecord.PSObject.Properties['definitionRevision']) { [int]$selectedRecord.definitionRevision } else { 0 }
        PublishedAtUtc     = if ($selectedRecord.PSObject.Properties['definitionPublishedAtUtc']) { [string]$selectedRecord.definitionPublishedAtUtc } else { $null }
    }
}
