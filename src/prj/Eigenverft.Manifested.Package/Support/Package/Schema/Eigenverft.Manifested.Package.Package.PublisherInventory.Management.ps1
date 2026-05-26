<#
    Publisher-id validation helpers.

    Publisher ids are labels carried by definitionPublication.publisherId and
    trust inventory rows. They are not a separate runtime authority inventory.
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
