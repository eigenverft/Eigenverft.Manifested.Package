<#
    Deprecated package publisher command surface.
#>

function Get-PackagePublisherCommandDeprecationMessage {
    [CmdletBinding()]
    param()

    return @(
        'Package publisher inventory commands are deprecated and no longer mutate trust state.'
        'Catalog authority now uses signed package definitions plus PackageTrustInventory.json.'
        'Use Import-PackageTrust or Trust-PackageSigningCertificate to trust signing keys.'
        "For temporary unsigned migration, set package.catalogTrust.policy='allowUnsigned' and add publisher ids to package.catalogTrust.allowUnsignedPublisherIds in PackageConfig.json."
    ) -join ' '
}

function Get-PackagePublisher {
    [CmdletBinding()]
    param(
        [string]$PublisherId
    )

    throw (Get-PackagePublisherCommandDeprecationMessage)
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

    throw (Get-PackagePublisherCommandDeprecationMessage)
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

    throw (Get-PackagePublisherCommandDeprecationMessage)
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

    throw (Get-PackagePublisherCommandDeprecationMessage)
}

function Remove-PackagePublisher {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PublisherId,

        [switch]$Force
    )

    throw (Get-PackagePublisherCommandDeprecationMessage)
}
