<#
    Public package definition endpoint (scan root) management surface.

    Endpoints are discovery locations. Publisher trust is managed separately
    through PackagePublisherInventory.json and the PackagePublisher commands.
#>

function Get-PackageEndpoint {
    [CmdletBinding()]
    param(
        [string]$EndpointName
    )

    $endpoints = @(Get-PackageEndpointSummaries)
    if ([string]::IsNullOrWhiteSpace($EndpointName)) {
        return $endpoints
    }

    $match = @($endpoints | Where-Object { [string]::Equals([string]$_.EndpointName, $EndpointName, [System.StringComparison]::OrdinalIgnoreCase) })
    if ($match.Count -eq 0) {
        throw "Package endpoint '$EndpointName' was not found in '$((Get-PackageEndpointInventoryPath))'."
    }

    return $match
}

function Get-PackageEndpointDiscoveredPublisherIds {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$ResolvedRootPath
    )

    if ([string]::IsNullOrWhiteSpace($ResolvedRootPath) -or
        -not (Test-Path -LiteralPath $ResolvedRootPath -PathType Container)) {
        return @()
    }

    $publisherIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($jsonFile in @(Get-ChildItem -LiteralPath $ResolvedRootPath -Filter '*.json' -File -Recurse -ErrorAction SilentlyContinue)) {
        try {
            $document = Get-Content -LiteralPath $jsonFile.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($document.PSObject.Properties['definitionPublication'] -and
                $document.definitionPublication.PSObject.Properties['publisherId'] -and
                -not [string]::IsNullOrWhiteSpace([string]$document.definitionPublication.publisherId)) {
                $publisherIds.Add([string]$document.definitionPublication.publisherId) | Out-Null
            }
        }
        catch {
            continue
        }
    }

    return @($publisherIds | Sort-Object)
}

function Add-PackageEndpoint {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$EndpointName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BasePath,

        [int]$SearchOrder = -1,

        [string]$After,

        [switch]$Disabled
    )

    Assert-PackageEndpointName -EndpointName $EndpointName

    $documentInfo = Get-PackageEndpointInventoryEditInfo
    if (Get-PackageEndpointSourceProperty -Document $documentInfo.Document -EndpointName $EndpointName) {
        throw "Package endpoint '$EndpointName' already exists in '$($documentInfo.Path)'. Use Set-PackageEndpoint to modify it."
    }

    $resolvedSearchOrder = if ($SearchOrder -ge 0) {
        $SearchOrder
    }
    elseif (-not [string]::IsNullOrWhiteSpace($After)) {
        Get-PackageEndpointSearchOrderAfter -Document $documentInfo.Document -AfterEndpointName $After
    }
    else {
        Get-PackageNextEndpointSearchOrder -Document $documentInfo.Document
    }

    $source = New-PackageFilesystemEndpointSource -EndpointName $EndpointName -BasePath $BasePath -SearchOrder $resolvedSearchOrder -Enabled (-not $Disabled.IsPresent)

    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Add package endpoint '$EndpointName'")) {
        $documentInfo.Document.endpoints = @($documentInfo.Document.endpoints) + $source
        Save-PackageEndpointInventoryDocument -DocumentInfo $documentInfo
    }

    $afterSummary = Get-PackageEndpoint -EndpointName $EndpointName
    $notes = New-Object System.Collections.Generic.List[string]
    if ($Disabled.IsPresent) {
        $notes.Add("Endpoint '$EndpointName' was added disabled; package commands will not scan it until enabled.") | Out-Null
    }
    else {
        $notes.Add("Endpoint '$EndpointName' was added as a scan location. Package execution still requires a trusted publisher in PackagePublisherInventory.json.") | Out-Null
    }

    $publisherIds = @(Get-PackageEndpointDiscoveredPublisherIds -ResolvedRootPath $afterSummary.ResolvedRootPath)
    if ($publisherIds.Count -gt 0) {
        $notes.Add("Discovered publisher id(s): $($publisherIds -join ', '). Use Add-TeamPackagePublisher -PublisherId '<publisherId>' for a trusted team publisher, or Add/Set-PackagePublisher for custom policy.") | Out-Null
    }
    else {
        $notes.Add("No package definition publishers were discovered at '$($afterSummary.ResolvedRootPath)' yet.") | Out-Null
    }

    return New-PackageEndpointCommandResult -Action 'Add' -EndpointName $EndpointName -InventoryPath $documentInfo.Path -Before $null -After $afterSummary -Status 'Added' -Notes @($notes.ToArray())
}

function Add-TeamPackageEndpoint {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BasePath,

        [ValidateNotNullOrEmpty()]
        [string]$EndpointName = 'teamPackageEndpoint',

        [int]$SearchOrder = -1,

        [string]$After,

        [switch]$Disabled
    )

    $parameters = @{
        EndpointName = $EndpointName
        BasePath     = $BasePath
    }
    if ($SearchOrder -ge 0) {
        $parameters.SearchOrder = $SearchOrder
    }
    elseif (-not [string]::IsNullOrWhiteSpace($After)) {
        $parameters.After = $After
    }
    else {
        $parameters.SearchOrder = 150
    }
    if ($Disabled.IsPresent) {
        $parameters.Disabled = $true
    }
    if ($PSBoundParameters.ContainsKey('WhatIf')) {
        $parameters.WhatIf = [bool]$PSBoundParameters.WhatIf
    }
    if ($PSBoundParameters.ContainsKey('Confirm')) {
        $parameters.Confirm = [bool]$PSBoundParameters.Confirm
    }

    return Add-PackageEndpoint @parameters
}

function Set-PackageEndpoint {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$EndpointName,

        [string]$BasePath,

        [Nullable[int]]$SearchOrder,

        [switch]$Enable,

        [switch]$Disable
    )

    Assert-PackageEndpointName -EndpointName $EndpointName
    if ($Enable.IsPresent -and $Disable.IsPresent) { throw 'Use either -Enable or -Disable, not both.' }

    $before = Get-PackageEndpoint -EndpointName $EndpointName
    $documentInfo = Get-PackageEndpointInventoryEditInfo
    $sourceProperty = Get-PackageEndpointSourceProperty -Document $documentInfo.Document -EndpointName $EndpointName
    if (-not $sourceProperty) {
        throw "Package endpoint '$EndpointName' was not found in '$($documentInfo.Path)'. Use Add-PackageEndpoint to create it."
    }

    $source = $sourceProperty.Value
    if ($PSBoundParameters.ContainsKey('BasePath')) {
        if (-not [string]::Equals([string]$source.kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Package endpoint '$EndpointName' is kind '$($source.kind)'. Only filesystem endpoints support -BasePath."
        }
        $source | Add-Member -MemberType NoteProperty -Name 'basePath' -Value $BasePath -Force
    }
    if ($PSBoundParameters.ContainsKey('SearchOrder')) { $source | Add-Member -MemberType NoteProperty -Name 'searchOrder' -Value ([int]$SearchOrder.Value) -Force }
    if ($Enable.IsPresent) { $source | Add-Member -MemberType NoteProperty -Name 'enabled' -Value $true -Force }
    if ($Disable.IsPresent) { $source | Add-Member -MemberType NoteProperty -Name 'enabled' -Value $false -Force }

    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Set package endpoint '$EndpointName'")) {
        Save-PackageEndpointInventoryDocument -DocumentInfo $documentInfo
    }

    $after = Get-PackageEndpoint -EndpointName $EndpointName
    $notes = New-Object System.Collections.Generic.List[string]
    if (-not [bool]$after.Enabled) {
        $notes.Add("Endpoint '$EndpointName' was updated but remains disabled; package commands will not scan it until enabled.") | Out-Null
    }
    if ($PSBoundParameters.ContainsKey('BasePath')) {
        $notes.Add("Endpoint '$EndpointName' base path is now '$($after.BasePath)' and resolves to '$($after.ResolvedRootPath)'.") | Out-Null
    }
    $notes.Add("Publisher trust is managed separately with Add-PackagePublisher and Set-PackagePublisher.") | Out-Null

    return New-PackageEndpointCommandResult -Action 'Set' -EndpointName $EndpointName -InventoryPath $documentInfo.Path -Before $before -After $after -Status 'Updated' -Notes @($notes.ToArray())
}

function Remove-PackageEndpoint {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$EndpointName,

        [switch]$Force
    )

    Assert-PackageEndpointName -EndpointName $EndpointName
    if ([string]::Equals($EndpointName, (Get-PackageDefaultEndpointName), [System.StringComparison]::OrdinalIgnoreCase) -and -not $Force.IsPresent) {
        throw "Removing '$EndpointName' can leave Package without its shipped definition scan endpoint. Re-run with -Force if this is intentional."
    }

    $before = Get-PackageEndpoint -EndpointName $EndpointName
    $documentInfo = Get-PackageEndpointInventoryEditInfo
    $sourceProperty = Get-PackageEndpointSourceProperty -Document $documentInfo.Document -EndpointName $EndpointName
    if (-not $sourceProperty) {
        throw "Package endpoint '$EndpointName' was not found in '$($documentInfo.Path)'."
    }

    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Remove package endpoint '$EndpointName'")) {
        $documentInfo.Document.endpoints = @($documentInfo.Document.endpoints | Where-Object {
                -not ([string]::Equals([string]$_.endpointName, $EndpointName, [System.StringComparison]::OrdinalIgnoreCase))
            })
        Save-PackageEndpointInventoryDocument -DocumentInfo $documentInfo
    }

    return New-PackageEndpointCommandResult -Action 'Remove' -EndpointName $EndpointName -InventoryPath $documentInfo.Path -Before $before -After $null -Status 'Removed' -Notes @(
        "Endpoint '$EndpointName' was removed from configuration only. Endpoint files, installed packages, publisher policy, and local definition snapshots were not deleted."
    )
}
