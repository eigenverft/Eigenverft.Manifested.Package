<#
    Package endpoint authoring target evaluation for Get-PackageDefinitionAuthoringGuide.
#>

function Test-PackageEndpointAuthoringPathContainer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedRootPath
    )

    if ([string]::IsNullOrWhiteSpace($ResolvedRootPath)) {
        return $false
    }

    try {
        return Test-Path -LiteralPath $ResolvedRootPath -PathType Container -ErrorAction Stop
    }
    catch {
        return $false
    }
}

function Test-PackageEndpointAuthoringWriteAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedRootPath
    )

    if ([string]::IsNullOrWhiteSpace($ResolvedRootPath)) {
        return $false
    }

    if (-not (Test-PackageEndpointAuthoringPathContainer -ResolvedRootPath $ResolvedRootPath)) {
        return $false
    }

    $markerName = '.eigenverft-authoring-write-probe-{0}.tmp' -f [Guid]::NewGuid().ToString('N')
    $markerPath = Join-Path $ResolvedRootPath $markerName
    try {
        [System.IO.File]::WriteAllText($markerPath, 'probe')
        return $true
    }
    catch {
        return $false
    }
    finally {
        try {
            if (Test-Path -LiteralPath $markerPath -PathType Leaf -ErrorAction Stop) {
                Remove-Item -LiteralPath $markerPath -Force -ErrorAction Stop
            }
        }
        catch {
        }
    }
}

function Get-PackageAuthoringTargetCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Summary,

        [Parameter(Mandatory = $true)]
        [psobject]$Source
    )

    $kind = [string]$Summary.Kind
    $resolvedRootPath = [string]$Summary.ResolvedRootPath
    $writable = $false
    $status = 'Blocked'
    $skipReason = $null

    if ($kind -notin @('moduleLocal', 'filesystem')) {
        $status = 'Unsupported'
        $skipReason = "Endpoint kind '$kind' does not support package-definition authoring in this module version."
        return [pscustomobject]@{
            EndpointName     = [string]$Summary.EndpointName
            Kind             = $kind
            SearchOrder      = $Summary.SearchOrder
            Enabled          = [bool]$Summary.Enabled
            Effective        = [bool]$Summary.Effective
            AuthoringTarget  = [bool]$Summary.AuthoringTarget
            ResolvedRootPath = $resolvedRootPath
            Status           = $status
            Writable         = $false
            Selected         = $false
            SkipReason       = $skipReason
        }
    }

    if ([string]::IsNullOrWhiteSpace($resolvedRootPath)) {
        $skipReason = 'Resolved target path is unavailable.'
        return [pscustomobject]@{
            EndpointName     = [string]$Summary.EndpointName
            Kind             = $kind
            SearchOrder      = $Summary.SearchOrder
            Enabled          = [bool]$Summary.Enabled
            Effective        = [bool]$Summary.Effective
            AuthoringTarget  = [bool]$Summary.AuthoringTarget
            ResolvedRootPath = $null
            Status           = $status
            Writable         = $false
            Selected         = $false
            SkipReason       = $skipReason
        }
    }

    if (-not [bool]$Summary.Enabled) {
        $skipReason = 'Endpoint is disabled in package endpoint inventory.'
        return [pscustomobject]@{
            EndpointName     = [string]$Summary.EndpointName
            Kind             = $kind
            SearchOrder      = $Summary.SearchOrder
            Enabled          = [bool]$Summary.Enabled
            Effective        = [bool]$Summary.Effective
            AuthoringTarget  = [bool]$Summary.AuthoringTarget
            ResolvedRootPath = $resolvedRootPath
            Status           = $status
            Writable         = $false
            Selected         = $false
            SkipReason       = $skipReason
        }
    }

    $writable = Test-PackageEndpointAuthoringWriteAccess -ResolvedRootPath $resolvedRootPath
    if (-not $writable) {
        if (-not (Test-PackageEndpointAuthoringPathContainer -ResolvedRootPath $resolvedRootPath)) {
            $skipReason = "Target path does not exist or is not reachable: '$resolvedRootPath'."
        }
        else {
            $skipReason = "Target path is not writable: '$resolvedRootPath'."
        }
        return [pscustomobject]@{
            EndpointName     = [string]$Summary.EndpointName
            Kind             = $kind
            SearchOrder      = $Summary.SearchOrder
            Enabled          = [bool]$Summary.Enabled
            Effective        = [bool]$Summary.Effective
            AuthoringTarget  = [bool]$Summary.AuthoringTarget
            ResolvedRootPath = $resolvedRootPath
            Status           = $status
            Writable         = $false
            Selected         = $false
            SkipReason       = $skipReason
        }
    }

    $status = 'Ready'

    return [pscustomobject]@{
        EndpointName     = [string]$Summary.EndpointName
        Kind             = $kind
        SearchOrder      = $Summary.SearchOrder
        Enabled          = [bool]$Summary.Enabled
        Effective        = [bool]$Summary.Effective
        AuthoringTarget  = [bool]$Summary.AuthoringTarget
        ResolvedRootPath = $resolvedRootPath
        Status           = $status
        Writable         = $true
        Selected         = $false
        SkipReason       = $null
    }
}

function Get-PackageAuthoringTargetEvaluation {
    [CmdletBinding()]
    param(
        [string]$EndpointName,

        [ValidateSet('First', 'Last')]
        [string]$EndpointPreference = 'First'
    )

    $null = Initialize-PackageLocalEnvironment

    $documentInfo = Get-PackageEndpointInventoryEditInfo
    $applicationRootDirectory = $null
    try {
        $globalDocumentInfo = Read-PackageJsonDocument -Path (Get-PackageConfigPath)
        Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalDocumentInfo
        $applicationRootDirectory = Resolve-PackageApplicationRootDirectory -PackageConfiguration $globalDocumentInfo.Document.package
    }
    catch {
    }

    $markedSummaries = New-Object System.Collections.Generic.List[object]
    foreach ($source in @(Get-PackageEndpointSourceEntries -Document $documentInfo.Document)) {
        $endpointNameValue = [string]$source.endpointName
        $authoringTarget = $false
        if ($source.PSObject.Properties['authoringTarget']) {
            $authoringTarget = [bool]$source.authoringTarget
        }
        if (-not $authoringTarget) {
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($EndpointName) -and
            -not [string]::Equals($endpointNameValue, $EndpointName, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        $summary = Select-PackageEndpointSummary -EndpointName $endpointNameValue -Source $source -InventoryPath $documentInfo.Path -ApplicationRootDirectory $applicationRootDirectory
        $markedSummaries.Add($summary) | Out-Null
    }

    if (-not [string]::IsNullOrWhiteSpace($EndpointName) -and $markedSummaries.Count -eq 0) {
        $explicitSource = Get-PackageEndpointSourceProperty -Document $documentInfo.Document -EndpointName $EndpointName
        if (-not $explicitSource) {
            throw "Package endpoint '$EndpointName' was not found in '$($documentInfo.Path)'."
        }
    }

    $candidates = New-Object System.Collections.Generic.List[object]
    foreach ($summary in @($markedSummaries.ToArray())) {
        $sourceProperty = Get-PackageEndpointSourceProperty -Document $documentInfo.Document -EndpointName ([string]$summary.EndpointName)
        $candidate = Get-PackageAuthoringTargetCandidate -Summary $summary -Source $sourceProperty.Value
        $candidates.Add($candidate) | Out-Null
    }

    $troubleshootingKind = 'None'
    if ($markedSummaries.Count -eq 0) {
        $troubleshootingKind = 'NoMarkedTarget'
    }

    $selectable = @($candidates | Where-Object { $_.Status -eq 'Ready' })
    $selected = $null
    $warnings = New-Object System.Collections.Generic.List[string]

    if ($selectable.Count -gt 0) {
        if ($EndpointPreference -ieq 'Last') {
            $selected = @($selectable | Sort-Object -Property @{ Expression = { $_.SearchOrder }; Descending = $true } | Select-Object -First 1)[0]
        }
        else {
            $selected = @($selectable | Sort-Object -Property SearchOrder | Select-Object -First 1)[0]
        }
    }
    elseif ($candidates.Count -gt 0) {
        $troubleshootingKind = 'AllMarkedBlocked'
    }

    foreach ($candidate in @($candidates.ToArray())) {
        $status = [string]$candidate.Status
        $skipReason = [string]$candidate.SkipReason
        if (($status -eq 'Blocked' -or $status -eq 'Unsupported') -and -not [string]::IsNullOrWhiteSpace($skipReason)) {
            $warnings.Add("Skipped authoring target '$($candidate.EndpointName)' ($status): $skipReason") | Out-Null
        }
    }

    return [pscustomobject]@{
        InventoryPath       = $documentInfo.Path
        Candidates          = @($candidates.ToArray())
        SelectedTarget      = $selected
        TroubleshootingKind = $troubleshootingKind
        Warnings            = @($warnings.ToArray())
    }
}
