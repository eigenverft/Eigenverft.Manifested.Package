<#
    Eigenverft.Manifested.Sandbox.Package - depot inventory management helpers.
#>

function Assert-PackageDepotId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DepotId
    )

    if ([string]::IsNullOrWhiteSpace($DepotId)) {
        throw 'DepotId must not be empty.'
    }
    if ($DepotId -notmatch '^[A-Za-z][A-Za-z0-9_-]*$') {
        throw "DepotId '$DepotId' is invalid. Use letters, numbers, '-' or '_' and start with a letter."
    }
}

function Get-PackageDepotInventoryEditInfo {
    [CmdletBinding()]
    param()

    $inventoryPath = Get-PackageDepotInventoryPath
    $documentInfo = Read-PackageJsonDocument -Path $inventoryPath
    Assert-PackageDepotInventorySchema -DepotInventoryDocumentInfo $documentInfo

    if (-not $documentInfo.Document.acquisitionEnvironment.PSObject.Properties['environmentSources'] -or
        $null -eq $documentInfo.Document.acquisitionEnvironment.environmentSources) {
        $documentInfo.Document.acquisitionEnvironment | Add-Member -MemberType NoteProperty -Name 'environmentSources' -Value ([pscustomobject]@{}) -Force
    }

    return $documentInfo
}

function Save-PackageDepotInventoryDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DocumentInfo
    )

    Assert-PackageDepotInventorySchema -DepotInventoryDocumentInfo $DocumentInfo

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

function Get-PackageDepotSourceProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document,

        [Parameter(Mandatory = $true)]
        [string]$DepotId
    )

    if (-not $Document.acquisitionEnvironment.PSObject.Properties['environmentSources'] -or
        $null -eq $Document.acquisitionEnvironment.environmentSources) {
        return $null
    }

    return $Document.acquisitionEnvironment.environmentSources.PSObject.Properties[$DepotId]
}

function Get-PackageNextDepotSearchOrder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document
    )

    $maxSearchOrder = 0
    if ($Document.acquisitionEnvironment.PSObject.Properties['environmentSources'] -and
        $null -ne $Document.acquisitionEnvironment.environmentSources) {
        foreach ($sourceProperty in @($Document.acquisitionEnvironment.environmentSources.PSObject.Properties)) {
            if ($sourceProperty.Value -and $sourceProperty.Value.PSObject.Properties['searchOrder']) {
                $current = [int]$sourceProperty.Value.searchOrder
                if ($current -gt $maxSearchOrder) {
                    $maxSearchOrder = $current
                }
            }
        }
    }

    return ([int]([Math]::Ceiling(($maxSearchOrder + 1) / 100.0) * 100))
}

function Get-PackageDepotSearchOrderAfter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document,

        [Parameter(Mandatory = $true)]
        [string]$AfterDepotId
    )

    $afterProperty = Get-PackageDepotSourceProperty -Document $Document -DepotId $AfterDepotId
    if (-not $afterProperty) {
        throw "Package depot '$AfterDepotId' was not found, so no searchOrder can be placed after it."
    }
    if (-not $afterProperty.Value.PSObject.Properties['searchOrder']) {
        throw "Package depot '$AfterDepotId' has no searchOrder."
    }

    $afterOrder = [int]$afterProperty.Value.searchOrder
    $nextHigherOrder = $null
    foreach ($sourceProperty in @($Document.acquisitionEnvironment.environmentSources.PSObject.Properties)) {
        if (-not $sourceProperty.Value -or -not $sourceProperty.Value.PSObject.Properties['searchOrder']) {
            continue
        }

        $currentOrder = [int]$sourceProperty.Value.searchOrder
        if ($currentOrder -gt $afterOrder -and ($null -eq $nextHigherOrder -or $currentOrder -lt $nextHigherOrder)) {
            $nextHigherOrder = $currentOrder
        }
    }

    if ($null -eq $nextHigherOrder) {
        return ($afterOrder + 100)
    }

    $candidate = [int][Math]::Floor(($afterOrder + $nextHigherOrder) / 2)
    if ($candidate -le $afterOrder -or $candidate -ge $nextHigherOrder) {
        throw "No integer searchOrder slot is available between '$AfterDepotId' ($afterOrder) and the next depot ($nextHigherOrder). Use -SearchOrder explicitly."
    }

    return $candidate
}

function New-PackageFilesystemDepotSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [int]$SearchOrder,

        [bool]$Enabled = $true,

        [string[]]$SiteCodes = @(),

        [bool]$Readable = $true,

        [bool]$Writable = $false,

        [bool]$MirrorTarget = $false,

        [bool]$EnsureExists = $false
    )

    if ([string]::IsNullOrWhiteSpace($BasePath)) {
        throw 'BasePath must not be empty.'
    }
    if ($MirrorTarget -and -not $Writable) {
        throw 'MirrorTarget requires Writable.'
    }
    if ($EnsureExists -and -not $Writable) {
        throw 'EnsureExists requires Writable.'
    }

    $source = [ordered]@{
        kind         = 'filesystem'
        enabled      = $Enabled
        searchOrder  = $SearchOrder
        basePath     = $BasePath
        readable     = $Readable
        writable     = $Writable
        mirrorTarget = $MirrorTarget
        ensureExists = $EnsureExists
    }

    $cleanSiteCodes = @($SiteCodes | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($cleanSiteCodes.Count -gt 0) {
        $source['siteCodes'] = @($cleanSiteCodes)
    }

    return [pscustomobject]$source
}

function Resolve-PackageDepotBasePathForDisplay {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$BasePath,

        [AllowNull()]
        [string]$ApplicationRootDirectory
    )

    if ([string]::IsNullOrWhiteSpace($BasePath)) {
        return $null
    }

    try {
        if (-not [string]::IsNullOrWhiteSpace($ApplicationRootDirectory)) {
            return Resolve-PackageConfiguredPath -PathValue $BasePath -ApplicationRootDirectory $ApplicationRootDirectory
        }
        return Resolve-PackagePathValue -PathValue $BasePath
    }
    catch {
        return $null
    }
}

function Select-PackageDepotSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DepotId,

        [Parameter(Mandatory = $true)]
        [psobject]$Source,

        [Parameter(Mandatory = $true)]
        [string]$InventoryPath,

        [AllowNull()]
        [psobject]$EffectiveSources = $null,

        [AllowNull()]
        [string]$ApplicationRootDirectory = $null,

        [AllowNull()]
        [string[]]$ActiveSiteCodes = @()
    )

    $enabled = if ($Source.PSObject.Properties['enabled']) { [bool]$Source.enabled } else { $true }
    $kind = if ($Source.PSObject.Properties['kind']) { [string]$Source.kind } else { $null }
    $searchOrder = if ($Source.PSObject.Properties['searchOrder']) { [int]$Source.searchOrder } else { $null }
    $basePath = if ($Source.PSObject.Properties['basePath']) { [string]$Source.basePath } else { $null }
    $siteCodes = if ($Source.PSObject.Properties['siteCodes'] -and $null -ne $Source.siteCodes) { @($Source.siteCodes) } else { @() }
    $isEffective = $false
    if ($EffectiveSources -and $EffectiveSources.PSObject.Properties[$DepotId]) {
        $isEffective = $true
    }

    $notes = New-Object System.Collections.Generic.List[string]
    if (-not $enabled) {
        $notes.Add('Disabled; package acquisition will not use this depot.') | Out-Null
    }
    elseif ($siteCodes.Count -gt 0 -and -not $isEffective) {
        $notes.Add(('Enabled, but filtered out by active site codes. Active site codes: {0}.' -f ($(if (@($ActiveSiteCodes).Count -gt 0) { @($ActiveSiteCodes) -join ';' } else { '<none>' })))) | Out-Null
    }
    elseif ($enabled -and -not $isEffective) {
        $notes.Add('Enabled, but not present in the effective acquisition environment.') | Out-Null
    }

    if ([string]::Equals($kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
        if ($Source.PSObject.Properties['readable'] -and -not [bool]$Source.readable) {
            $notes.Add('Not readable; it will not be used as an acquisition source.') | Out-Null
        }
        if ($Source.PSObject.Properties['mirrorTarget'] -and [bool]$Source.mirrorTarget) {
            $notes.Add('Mirror target; verified downloads may be copied here.') | Out-Null
        }
        if ($Source.PSObject.Properties['writable'] -and -not [bool]$Source.writable) {
            $notes.Add('Read-only from Package perspective; no depot directories will be created or mirrored here.') | Out-Null
        }
    }

    return [pscustomobject]@{
        DepotId          = $DepotId
        Kind             = $kind
        Enabled          = $enabled
        Effective        = $isEffective
        SearchOrder      = $searchOrder
        BasePath         = $basePath
        ResolvedBasePath = Resolve-PackageDepotBasePathForDisplay -BasePath $basePath -ApplicationRootDirectory $ApplicationRootDirectory
        Readable         = if ($Source.PSObject.Properties['readable']) { [bool]$Source.readable } else { $null }
        Writable         = if ($Source.PSObject.Properties['writable']) { [bool]$Source.writable } else { $null }
        MirrorTarget     = if ($Source.PSObject.Properties['mirrorTarget']) { [bool]$Source.mirrorTarget } else { $null }
        EnsureExists     = if ($Source.PSObject.Properties['ensureExists']) { [bool]$Source.ensureExists } else { $null }
        SiteCodes        = @($siteCodes)
        InventoryPath    = $InventoryPath
        Notes            = @($notes.ToArray())
    }
}

function Get-PackageDepotSummaries {
    [CmdletBinding()]
    param()

    $documentInfo = Get-PackageDepotInventoryEditInfo
    $stateConfig = $null
    try {
        $stateConfig = Get-PackageStateConfig
    }
    catch {
        Write-Warning "Depot summaries could not resolve the effective acquisition environment. Showing raw depot inventory only. $($_.Exception.Message)"
    }

    $effectiveSources = if ($stateConfig) { $stateConfig.EnvironmentSources } else { $null }
    $applicationRootDirectory = if ($stateConfig) { [string]$stateConfig.ApplicationRootDirectory } else { $null }
    $activeSiteCodes = if ($stateConfig -and $stateConfig.EffectiveAcquisitionEnvironment) { @($stateConfig.EffectiveAcquisitionEnvironment.SiteCodes) } else { @() }

    foreach ($sourceProperty in @($documentInfo.Document.acquisitionEnvironment.environmentSources.PSObject.Properties)) {
        Select-PackageDepotSummary -DepotId $sourceProperty.Name -Source $sourceProperty.Value -InventoryPath $documentInfo.Path -EffectiveSources $effectiveSources -ApplicationRootDirectory $applicationRootDirectory -ActiveSiteCodes $activeSiteCodes
    }
}

function New-PackageDepotCommandResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$DepotId,

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
        DepotId       = $DepotId
        InventoryPath = $InventoryPath
        Status        = $Status
        Before        = $Before
        After         = $After
        Notes         = @($Notes)
    }
}
