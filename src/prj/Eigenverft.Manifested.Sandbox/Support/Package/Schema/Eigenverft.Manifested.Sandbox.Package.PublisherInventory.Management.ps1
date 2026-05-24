<#
    Eigenverft.Manifested.Sandbox.Package - PackagePublisherInventory.json management helpers.
#>

function Assert-PackagePublisherId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PublisherId
    )

    if ([string]::IsNullOrWhiteSpace($PublisherId)) {
        throw 'Package publisher id must not be empty.'
    }
    if ($PublisherId -notmatch '^[A-Za-z][A-Za-z0-9_.-]*( [A-Za-z0-9_.-]+)*$') {
        throw "Package publisher '$PublisherId' is invalid. Use letters, numbers, spaces, '.', '-' or '_' and start with a letter. Spaces must separate non-empty words."
    }
}

function Get-PackagePublisherEntries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document
    )

    if (-not $Document.PSObject.Properties['publishers'] -or $null -eq $Document.publishers) {
        return @()
    }
    if ($Document.publishers -isnot [System.Array]) {
        throw "Package publisher inventory must define publishers as an array of objects with publisherId."
    }

    return @($Document.publishers)
}

function Assert-PackagePublisherInventorySchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PublisherInventoryDocumentInfo
    )

    $document = $PublisherInventoryDocumentInfo.Document
    if (-not $document.PSObject.Properties['inventoryVersion']) {
        throw "Package publisher inventory '$($PublisherInventoryDocumentInfo.Path)' is missing inventoryVersion."
    }
    if (-not $document.PSObject.Properties['publishers'] -or $null -eq $document.publishers) {
        throw "Package publisher inventory '$($PublisherInventoryDocumentInfo.Path)' is missing publishers."
    }

    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($publisher in @(Get-PackagePublisherEntries -Document $document)) {
        foreach ($requiredProperty in @('publisherId', 'publisherName', 'enabled', 'trusted', 'trustMode')) {
            if (-not $publisher.PSObject.Properties[$requiredProperty] -or
                ($requiredProperty -in @('publisherId', 'publisherName', 'trustMode') -and [string]::IsNullOrWhiteSpace([string]$publisher.$requiredProperty))) {
                throw "Package publisher inventory '$($PublisherInventoryDocumentInfo.Path)' has a publisher missing '$requiredProperty'."
            }
        }
        if ($publisher.PSObject.Properties['searchOrder']) {
            throw "Package publisher '$($publisher.publisherId)' in '$($PublisherInventoryDocumentInfo.Path)' still uses retired property 'searchOrder'. Publisher trust is permission, not ranking; endpoint searchOrder controls source precedence."
        }

        $publisherId = [string]$publisher.publisherId
        if (-not $seen.Add($publisherId)) {
            throw "Package publisher inventory '$($PublisherInventoryDocumentInfo.Path)' defines duplicate publisherId '$publisherId'."
        }
        Assert-PackagePublisherId -PublisherId $publisherId

        $trustMode = [string]$publisher.trustMode
        if ($trustMode -notin @('moduleShipped', 'unsigned', 'unsignedExplicit')) {
            throw "Package publisher '$publisherId' in '$($PublisherInventoryDocumentInfo.Path)' has unsupported trustMode '$trustMode'."
        }
        if ([string]::Equals($trustMode, 'moduleShipped', [System.StringComparison]::OrdinalIgnoreCase) -and -not [bool]$publisher.trusted) {
            throw "Package publisher '$publisherId' uses trustMode='moduleShipped' but trusted is false."
        }
        if ([string]::Equals($trustMode, 'unsigned', [System.StringComparison]::OrdinalIgnoreCase) -and [bool]$publisher.trusted) {
            throw "Package publisher '$publisherId' uses trustMode='unsigned' but trusted is true."
        }
        if ([string]::Equals($trustMode, 'unsignedExplicit', [System.StringComparison]::OrdinalIgnoreCase) -and -not [bool]$publisher.trusted) {
            throw "Package publisher '$publisherId' uses trustMode='unsignedExplicit' but trusted is false."
        }
    }
}

function Get-PackagePublisherInventoryInfo {
    [CmdletBinding()]
    param()

    $inventoryPath = Get-PackagePublisherInventoryPath
    $documentInfo = Read-PackageJsonDocument -Path $inventoryPath
    Assert-PackagePublisherInventorySchema -PublisherInventoryDocumentInfo $documentInfo
    $documentInfo | Add-Member -MemberType NoteProperty -Name Exists -Value $true -Force
    return $documentInfo
}

function Get-PackagePublisherInventoryEditInfo {
    [CmdletBinding()]
    param()

    $documentInfo = Get-PackagePublisherInventoryInfo
    if (-not $documentInfo.Document.PSObject.Properties['publishers'] -or $null -eq $documentInfo.Document.publishers) {
        $documentInfo.Document | Add-Member -MemberType NoteProperty -Name 'publishers' -Value @() -Force
    }
    return $documentInfo
}

function Save-PackagePublisherInventoryDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DocumentInfo
    )

    Assert-PackagePublisherInventorySchema -PublisherInventoryDocumentInfo $DocumentInfo

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

function Get-PackagePublisherProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document,

        [Parameter(Mandatory = $true)]
        [string]$PublisherId
    )

    foreach ($publisher in @(Get-PackagePublisherEntries -Document $Document)) {
        if ($publisher.PSObject.Properties['publisherId'] -and
            [string]::Equals([string]$publisher.publisherId, $PublisherId, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{
                Name  = [string]$publisher.publisherId
                Value = $publisher
            }
        }
    }

    return $null
}

function New-PackagePublisherEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PublisherId,

        [AllowNull()]
        [string]$PublisherName = $null,

        [bool]$Enabled = $true,

        [bool]$Trusted = $false,

        [string]$TrustMode = 'unsigned',

        [AllowNull()]
        [string]$TrustReason = $null
    )

    Assert-PackagePublisherId -PublisherId $PublisherId
    if ([string]::IsNullOrWhiteSpace($PublisherName)) {
        $PublisherName = $PublisherId
    }

    $entry = [ordered]@{
        publisherId   = $PublisherId
        publisherName = $PublisherName
        enabled       = $Enabled
        trusted       = $Trusted
        trustMode     = $TrustMode
    }
    if ($Trusted) {
        $entry['trustedAtUtc'] = [DateTime]::UtcNow.ToString('o')
        if (-not [string]::IsNullOrWhiteSpace($TrustReason)) {
            $entry['trustReason'] = $TrustReason
        }
    }

    return [pscustomobject]$entry
}

function Get-PackageEnabledTrustedPublisherRows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PublisherInventoryDocument
    )

    $rows = @(
        foreach ($publisher in @(Get-PackagePublisherEntries -Document $PublisherInventoryDocument)) {
            if (-not [bool]$publisher.enabled) {
                continue
            }
            if (-not [bool]$publisher.trusted) {
                continue
            }

            [pscustomobject]@{
                PublisherId   = [string]$publisher.publisherId
                PublisherName = [string]$publisher.publisherName
                TrustMode     = [string]$publisher.trustMode
                Source        = $publisher
            }
        }
    )

    return @($rows | Sort-Object -Property PublisherId)
}

function Select-PackagePublisherSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Publisher,

        [Parameter(Mandatory = $true)]
        [string]$InventoryPath
    )

    $enabled = if ($Publisher.PSObject.Properties['enabled']) { [bool]$Publisher.enabled } else { $true }
    $trusted = if ($Publisher.PSObject.Properties['trusted']) { [bool]$Publisher.trusted } else { $false }
    $trustMode = if ($Publisher.PSObject.Properties['trustMode']) { [string]$Publisher.trustMode } else { 'unsigned' }
    $notes = New-Object System.Collections.Generic.List[string]
    if (-not $enabled) {
        $notes.Add('Disabled; matching definitions from this publisher are ignored.') | Out-Null
    }
    if (-not $trusted) {
        $notes.Add('Untrusted; matching definitions from this publisher cannot be executed.') | Out-Null
    }
    if ($trusted -and [string]::Equals($trustMode, 'unsignedExplicit', [System.StringComparison]::OrdinalIgnoreCase)) {
        $notes.Add('Unsigned definitions are trusted by explicit local publisher policy.') | Out-Null
    }

    return [pscustomobject]@{
        PublisherId   = [string]$Publisher.publisherId
        PublisherName = [string]$Publisher.publisherName
        Enabled       = $enabled
        Trusted       = $trusted
        TrustMode     = $trustMode
        InventoryPath = $InventoryPath
        TrustedAtUtc  = if ($Publisher.PSObject.Properties['trustedAtUtc']) { [string]$Publisher.trustedAtUtc } else { $null }
        TrustReason   = if ($Publisher.PSObject.Properties['trustReason']) { [string]$Publisher.trustReason } else { $null }
        Notes         = @($notes.ToArray())
    }
}

function Get-PackagePublisherSummaries {
    [CmdletBinding()]
    param()

    $documentInfo = Get-PackagePublisherInventoryEditInfo
    foreach ($publisher in @(Get-PackagePublisherEntries -Document $documentInfo.Document)) {
        Select-PackagePublisherSummary -Publisher $publisher -InventoryPath $documentInfo.Path
    }
}

function New-PackagePublisherCommandResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$PublisherId,

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
        Action        = $Action
        PublisherId   = $PublisherId
        InventoryPath = $InventoryPath
        Status        = $Status
        Before        = $Before
        After         = $After
        Notes         = @($Notes)
    }
}
