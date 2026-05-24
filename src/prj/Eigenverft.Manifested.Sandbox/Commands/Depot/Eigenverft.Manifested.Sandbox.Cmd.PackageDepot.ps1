<#
    Public depot-management command surface.
#>

function Get-PackageDepot {
    [CmdletBinding()]
    param(
        [string]$DepotId
    )

    $depots = @(Get-PackageDepotSummaries)
    if ([string]::IsNullOrWhiteSpace($DepotId)) {
        return $depots
    }

    $match = @($depots | Where-Object { [string]::Equals([string]$_.DepotId, $DepotId, [System.StringComparison]::OrdinalIgnoreCase) })
    if ($match.Count -eq 0) {
        throw "Package depot '$DepotId' was not found in '$((Get-PackageDepotInventoryPath))'."
    }

    return $match
}

function Add-PackageDepot {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DepotId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BasePath,

        [int]$SearchOrder = -1,

        [string]$After,

        [string[]]$SiteCode = @(),

        [switch]$Disabled,

        [switch]$Writable,

        [switch]$MirrorTarget,

        [switch]$EnsureExists
    )

    Assert-PackageDepotId -DepotId $DepotId

    $documentInfo = Get-PackageDepotInventoryEditInfo
    if (Get-PackageDepotSourceProperty -Document $documentInfo.Document -DepotId $DepotId) {
        throw "Package depot '$DepotId' already exists in '$($documentInfo.Path)'. Use Set-PackageDepot to modify it."
    }

    $resolvedSearchOrder = if ($SearchOrder -ge 0) {
        $SearchOrder
    }
    elseif (-not [string]::IsNullOrWhiteSpace($After)) {
        Get-PackageDepotSearchOrderAfter -Document $documentInfo.Document -AfterDepotId $After
    }
    else {
        Get-PackageNextDepotSearchOrder -Document $documentInfo.Document
    }
    $source = New-PackageFilesystemDepotSource -BasePath $BasePath -SearchOrder $resolvedSearchOrder -Enabled (-not $Disabled.IsPresent) -SiteCodes $SiteCode -Writable $Writable.IsPresent -MirrorTarget $MirrorTarget.IsPresent -EnsureExists $EnsureExists.IsPresent

    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Add package depot '$DepotId'")) {
        $documentInfo.Document.acquisitionEnvironment.environmentSources | Add-Member -MemberType NoteProperty -Name $DepotId -Value $source -Force
        Save-PackageDepotInventoryDocument -DocumentInfo $documentInfo
    }

    $after = Get-PackageDepot -DepotId $DepotId
    $notes = New-Object System.Collections.Generic.List[string]
    if ($Disabled.IsPresent) {
        $notes.Add("Depot '$DepotId' was added disabled; package acquisition will not use it until enabled.") | Out-Null
    }
    if (-not $Writable.IsPresent) {
        $notes.Add("Depot '$DepotId' is read-only from Package perspective by default; downloads will not be mirrored there.") | Out-Null
    }

    return New-PackageDepotCommandResult -Action 'Add' -DepotId $DepotId -InventoryPath $documentInfo.Path -Before $null -After $after -Status 'Added' -Notes @($notes.ToArray())
}

function Add-TeamPackageDepot {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BasePath,

        [ValidateNotNullOrEmpty()]
        [string]$DepotId = 'teamPackageDepot',

        [int]$SearchOrder = -1,

        [string]$After,

        [string[]]$SiteCode = @(),

        [switch]$Disabled
    )

    $parameters = @{
        DepotId      = $DepotId
        BasePath     = $BasePath
        SiteCode     = $SiteCode
        Writable     = $true
        MirrorTarget = $true
        EnsureExists = $true
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

    return Add-PackageDepot @parameters
}

function Set-PackageDepot {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DepotId,

        [string]$BasePath,

        [Nullable[int]]$SearchOrder,

        [string[]]$SiteCode,

        [switch]$ClearSiteCode,

        [switch]$Enable,

        [switch]$Disable,

        [switch]$Readable,

        [switch]$NotReadable,

        [switch]$Writable,

        [switch]$ReadOnly,

        [switch]$MirrorTarget,

        [switch]$NoMirrorTarget,

        [switch]$EnsureExists,

        [switch]$NoEnsureExists
    )

    Assert-PackageDepotId -DepotId $DepotId
    if ($Enable.IsPresent -and $Disable.IsPresent) { throw 'Use either -Enable or -Disable, not both.' }
    if ($Readable.IsPresent -and $NotReadable.IsPresent) { throw 'Use either -Readable or -NotReadable, not both.' }
    if ($Writable.IsPresent -and $ReadOnly.IsPresent) { throw 'Use either -Writable or -ReadOnly, not both.' }
    if ($MirrorTarget.IsPresent -and $NoMirrorTarget.IsPresent) { throw 'Use either -MirrorTarget or -NoMirrorTarget, not both.' }
    if ($EnsureExists.IsPresent -and $NoEnsureExists.IsPresent) { throw 'Use either -EnsureExists or -NoEnsureExists, not both.' }
    if ($ClearSiteCode.IsPresent -and $PSBoundParameters.ContainsKey('SiteCode')) { throw 'Use either -SiteCode or -ClearSiteCode, not both.' }

    $before = Get-PackageDepot -DepotId $DepotId
    $documentInfo = Get-PackageDepotInventoryEditInfo
    $sourceProperty = Get-PackageDepotSourceProperty -Document $documentInfo.Document -DepotId $DepotId
    if (-not $sourceProperty) {
        throw "Package depot '$DepotId' was not found in '$($documentInfo.Path)'. Use Add-PackageDepot to create it."
    }

    $source = $sourceProperty.Value
    if (-not [string]::Equals([string]$source.kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Package depot '$DepotId' is kind '$($source.kind)'. Only filesystem depots can be modified by Set-PackageDepot."
    }

    if ($PSBoundParameters.ContainsKey('BasePath')) { $source | Add-Member -MemberType NoteProperty -Name 'basePath' -Value $BasePath -Force }
    if ($PSBoundParameters.ContainsKey('SearchOrder')) { $source | Add-Member -MemberType NoteProperty -Name 'searchOrder' -Value ([int]$SearchOrder.Value) -Force }
    if ($Enable.IsPresent) { $source | Add-Member -MemberType NoteProperty -Name 'enabled' -Value $true -Force }
    if ($Disable.IsPresent) { $source | Add-Member -MemberType NoteProperty -Name 'enabled' -Value $false -Force }
    if ($Readable.IsPresent) { $source | Add-Member -MemberType NoteProperty -Name 'readable' -Value $true -Force }
    if ($NotReadable.IsPresent) { $source | Add-Member -MemberType NoteProperty -Name 'readable' -Value $false -Force }
    if ($Writable.IsPresent) { $source | Add-Member -MemberType NoteProperty -Name 'writable' -Value $true -Force }
    if ($ReadOnly.IsPresent) {
        $source | Add-Member -MemberType NoteProperty -Name 'writable' -Value $false -Force
        $source | Add-Member -MemberType NoteProperty -Name 'mirrorTarget' -Value $false -Force
        $source | Add-Member -MemberType NoteProperty -Name 'ensureExists' -Value $false -Force
    }
    if ($MirrorTarget.IsPresent) { $source | Add-Member -MemberType NoteProperty -Name 'mirrorTarget' -Value $true -Force }
    if ($NoMirrorTarget.IsPresent) { $source | Add-Member -MemberType NoteProperty -Name 'mirrorTarget' -Value $false -Force }
    if ($EnsureExists.IsPresent) { $source | Add-Member -MemberType NoteProperty -Name 'ensureExists' -Value $true -Force }
    if ($NoEnsureExists.IsPresent) { $source | Add-Member -MemberType NoteProperty -Name 'ensureExists' -Value $false -Force }
    if ($PSBoundParameters.ContainsKey('SiteCode')) { $source | Add-Member -MemberType NoteProperty -Name 'siteCodes' -Value @($SiteCode | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -Force }
    if ($ClearSiteCode.IsPresent -and $source.PSObject.Properties['siteCodes']) { $source.PSObject.Properties.Remove('siteCodes') }

    if ([bool]$source.mirrorTarget -and -not [bool]$source.writable) {
        throw "Package depot '$DepotId' cannot use MirrorTarget=true while Writable=false. Add -Writable or remove -MirrorTarget."
    }
    if ([bool]$source.ensureExists -and -not [bool]$source.writable) {
        throw "Package depot '$DepotId' cannot use EnsureExists=true while Writable=false. Add -Writable or remove -EnsureExists."
    }

    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Set package depot '$DepotId'")) {
        Save-PackageDepotInventoryDocument -DocumentInfo $documentInfo
    }

    $after = Get-PackageDepot -DepotId $DepotId
    $notes = New-Object System.Collections.Generic.List[string]
    if (-not [bool]$after.Enabled) {
        $notes.Add("Depot '$DepotId' was updated but remains disabled; package acquisition will not use it until enabled.") | Out-Null
    }
    elseif (-not [bool]$after.Effective) {
        $notes.Add("Depot '$DepotId' is enabled but is not currently effective. Check site codes or config validation notes.") | Out-Null
    }
    if ($PSBoundParameters.ContainsKey('BasePath')) {
        $notes.Add("Depot '$DepotId' base path is now '$($after.BasePath)' and resolves to '$($after.ResolvedBasePath)'.") | Out-Null
    }

    return New-PackageDepotCommandResult -Action 'Set' -DepotId $DepotId -InventoryPath $documentInfo.Path -Before $before -After $after -Status 'Updated' -Notes @($notes.ToArray())
}

function Remove-PackageDepot {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DepotId,

        [switch]$Force
    )

    Assert-PackageDepotId -DepotId $DepotId
    if ([string]::Equals($DepotId, 'defaultPackageDepot', [System.StringComparison]::OrdinalIgnoreCase) -and -not $Force.IsPresent) {
        throw "Removing 'defaultPackageDepot' can leave Package without a local durable depot. Re-run with -Force if this is intentional."
    }

    $before = Get-PackageDepot -DepotId $DepotId
    $documentInfo = Get-PackageDepotInventoryEditInfo
    $sourceProperty = Get-PackageDepotSourceProperty -Document $documentInfo.Document -DepotId $DepotId
    if (-not $sourceProperty) {
        throw "Package depot '$DepotId' was not found in '$($documentInfo.Path)'."
    }

    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Remove package depot '$DepotId'")) {
        $documentInfo.Document.acquisitionEnvironment.environmentSources.PSObject.Properties.Remove($DepotId)
        Save-PackageDepotInventoryDocument -DocumentInfo $documentInfo
    }

    return New-PackageDepotCommandResult -Action 'Remove' -DepotId $DepotId -InventoryPath $documentInfo.Path -Before $before -After $null -Status 'Removed' -Notes @(
        "Depot '$DepotId' was removed from configuration only. Existing depot files were not deleted."
    )
}
