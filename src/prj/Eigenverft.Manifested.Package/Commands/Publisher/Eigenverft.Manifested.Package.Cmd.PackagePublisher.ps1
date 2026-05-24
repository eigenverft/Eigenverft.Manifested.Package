<#
    Public package publisher policy management surface.

    Publishers are definition identities. Endpoints only decide where definitions
    are discovered; publisher policy decides which identities are executable.
#>

function Get-PackagePublisher {
    [CmdletBinding()]
    param(
        [string]$PublisherId
    )

    $publishers = @(Get-PackagePublisherSummaries)
    if ([string]::IsNullOrWhiteSpace($PublisherId)) {
        return $publishers
    }

    $match = @($publishers | Where-Object { [string]::Equals([string]$_.PublisherId, $PublisherId, [System.StringComparison]::OrdinalIgnoreCase) })
    if ($match.Count -eq 0) {
        throw "Package publisher '$PublisherId' was not found in '$((Get-PackagePublisherInventoryPath))'."
    }

    return $match
}

function Add-PackagePublisher {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PublisherId,

        [AllowNull()]
        [string]$PublisherName = $null,

        [switch]$Disabled,

        [switch]$AllowUnsignedDefinitions
    )

    Assert-PackagePublisherId -PublisherId $PublisherId

    $documentInfo = Get-PackagePublisherInventoryEditInfo
    if (Get-PackagePublisherProperty -Document $documentInfo.Document -PublisherId $PublisherId) {
        throw "Package publisher '$PublisherId' already exists in '$($documentInfo.Path)'. Use Set-PackagePublisher to modify it."
    }

    $trusted = $AllowUnsignedDefinitions.IsPresent
    $trustMode = if ($trusted) { 'unsignedExplicit' } else { 'unsigned' }
    $trustReason = if ($trusted) { 'Trusted by Add-PackagePublisher -AllowUnsignedDefinitions.' } else { $null }
    $publisher = New-PackagePublisherEntry `
        -PublisherId $PublisherId `
        -PublisherName $PublisherName `
        -Enabled (-not $Disabled.IsPresent) `
        -Trusted $trusted `
        -TrustMode $trustMode `
        -TrustReason $trustReason

    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Add package publisher '$PublisherId'")) {
        $documentInfo.Document.publishers = @($documentInfo.Document.publishers) + $publisher
        Save-PackagePublisherInventoryDocument -DocumentInfo $documentInfo
    }

    $after = Get-PackagePublisher -PublisherId $PublisherId
    $notes = New-Object System.Collections.Generic.List[string]
    if ($Disabled.IsPresent) {
        $notes.Add("Publisher '$PublisherId' was added disabled; matching definitions are ignored until enabled.") | Out-Null
    }
    if ($trusted) {
        $notes.Add("Publisher '$PublisherId' now trusts unsigned definitions by explicit local policy.") | Out-Null
    }
    else {
        $notes.Add("Publisher '$PublisherId' was added untrusted. Run Set-PackagePublisher -PublisherId '$PublisherId' -AllowUnsignedDefinitions before executing unsigned definitions from it.") | Out-Null
    }

    return New-PackagePublisherCommandResult -Action 'Add' -PublisherId $PublisherId -InventoryPath $documentInfo.Path -Before $null -After $after -Status 'Added' -Notes @($notes.ToArray())
}

function Add-TeamPackagePublisher {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$PublisherId = 'My Team',

        [AllowNull()]
        [string]$PublisherName = $null,

        [switch]$Disabled
    )

    $publisherParameters = @{
        PublisherId = $PublisherId
        AllowUnsignedDefinitions = $true
    }
    if ($PSBoundParameters.ContainsKey('PublisherName')) {
        $publisherParameters['PublisherName'] = $PublisherName
    }
    if ($Disabled.IsPresent) {
        $publisherParameters['Disabled'] = $true
    }

    $result = Add-PackagePublisher @publisherParameters
    $hint = "Team package definition JSON files must set definitionPublication.publisherId to '$PublisherId'."
    Write-Warning $hint

    $notes = @($result.Notes) + $hint
    $result | Add-Member -MemberType NoteProperty -Name Notes -Value $notes -Force
    return $result
}

function Set-PackagePublisher {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PublisherId,

        [string]$PublisherName,

        [switch]$Enable,

        [switch]$Disable,

        [switch]$AllowUnsignedDefinitions,

        [switch]$Untrust
    )

    Assert-PackagePublisherId -PublisherId $PublisherId
    if ($Enable.IsPresent -and $Disable.IsPresent) { throw 'Use either -Enable or -Disable, not both.' }
    if ($AllowUnsignedDefinitions.IsPresent -and $Untrust.IsPresent) { throw 'Use either -AllowUnsignedDefinitions or -Untrust, not both.' }

    $before = Get-PackagePublisher -PublisherId $PublisherId
    $documentInfo = Get-PackagePublisherInventoryEditInfo
    $publisherProperty = Get-PackagePublisherProperty -Document $documentInfo.Document -PublisherId $PublisherId
    if (-not $publisherProperty) {
        throw "Package publisher '$PublisherId' was not found in '$($documentInfo.Path)'. Use Add-PackagePublisher to create it."
    }

    $publisher = $publisherProperty.Value
    if ($PSBoundParameters.ContainsKey('PublisherName')) {
        if ([string]::IsNullOrWhiteSpace($PublisherName)) {
            throw 'PublisherName must not be empty.'
        }
        $publisher | Add-Member -MemberType NoteProperty -Name 'publisherName' -Value $PublisherName -Force
    }
    if ($Enable.IsPresent) { $publisher | Add-Member -MemberType NoteProperty -Name 'enabled' -Value $true -Force }
    if ($Disable.IsPresent) { $publisher | Add-Member -MemberType NoteProperty -Name 'enabled' -Value $false -Force }
    if ($AllowUnsignedDefinitions.IsPresent) {
        if ([string]::Equals([string]$publisher.trustMode, 'moduleShipped', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Package publisher '$PublisherId' is moduleShipped and already trusted by the module."
        }
        $publisher | Add-Member -MemberType NoteProperty -Name 'trusted' -Value $true -Force
        $publisher | Add-Member -MemberType NoteProperty -Name 'trustMode' -Value 'unsignedExplicit' -Force
        $publisher | Add-Member -MemberType NoteProperty -Name 'trustedAtUtc' -Value ([DateTime]::UtcNow.ToString('o')) -Force
        $publisher | Add-Member -MemberType NoteProperty -Name 'trustReason' -Value 'Trusted by Set-PackagePublisher -AllowUnsignedDefinitions.' -Force
    }
    if ($Untrust.IsPresent) {
        if ([string]::Equals([string]$publisher.trustMode, 'moduleShipped', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Package publisher '$PublisherId' is moduleShipped and cannot be untrusted."
        }
        $publisher | Add-Member -MemberType NoteProperty -Name 'trusted' -Value $false -Force
        $publisher | Add-Member -MemberType NoteProperty -Name 'trustMode' -Value 'unsigned' -Force
        if ($publisher.PSObject.Properties['trustedAtUtc']) { $publisher.PSObject.Properties.Remove('trustedAtUtc') }
        if ($publisher.PSObject.Properties['trustReason']) { $publisher.PSObject.Properties.Remove('trustReason') }
    }

    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Set package publisher '$PublisherId'")) {
        Save-PackagePublisherInventoryDocument -DocumentInfo $documentInfo
    }

    $after = Get-PackagePublisher -PublisherId $PublisherId
    $notes = New-Object System.Collections.Generic.List[string]
    if (-not [bool]$after.Enabled) {
        $notes.Add("Publisher '$PublisherId' is disabled; matching definitions are ignored.") | Out-Null
    }
    if (-not [bool]$after.Trusted) {
        $notes.Add("Publisher '$PublisherId' is untrusted; matching definitions cannot be executed.") | Out-Null
    }
    if ($AllowUnsignedDefinitions.IsPresent) {
        $notes.Add("Publisher '$PublisherId' now trusts unsigned definitions by explicit local policy.") | Out-Null
    }

    return New-PackagePublisherCommandResult -Action 'Set' -PublisherId $PublisherId -InventoryPath $documentInfo.Path -Before $before -After $after -Status 'Updated' -Notes @($notes.ToArray())
}

function Remove-PackagePublisher {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PublisherId,

        [switch]$Force
    )

    Assert-PackagePublisherId -PublisherId $PublisherId
    if ([string]::Equals($PublisherId, (Get-PackageDefaultPublisherId), [System.StringComparison]::OrdinalIgnoreCase) -and -not $Force.IsPresent) {
        throw "Removing '$PublisherId' can leave Package without its shipped trusted publisher. Re-run with -Force if this is intentional."
    }

    $before = Get-PackagePublisher -PublisherId $PublisherId
    $documentInfo = Get-PackagePublisherInventoryEditInfo
    $publisherProperty = Get-PackagePublisherProperty -Document $documentInfo.Document -PublisherId $PublisherId
    if (-not $publisherProperty) {
        throw "Package publisher '$PublisherId' was not found in '$($documentInfo.Path)'."
    }

    if ($PSCmdlet.ShouldProcess($documentInfo.Path, "Remove package publisher '$PublisherId'")) {
        $documentInfo.Document.publishers = @($documentInfo.Document.publishers | Where-Object {
                -not ([string]::Equals([string]$_.publisherId, $PublisherId, [System.StringComparison]::OrdinalIgnoreCase))
            })
        Save-PackagePublisherInventoryDocument -DocumentInfo $documentInfo
    }

    return New-PackagePublisherCommandResult -Action 'Remove' -PublisherId $PublisherId -InventoryPath $documentInfo.Path -Before $before -After $null -Status 'Removed' -Notes @(
        "Publisher '$PublisherId' was removed from policy only. Endpoints, installed packages, and local definition snapshots were not deleted."
    )
}
