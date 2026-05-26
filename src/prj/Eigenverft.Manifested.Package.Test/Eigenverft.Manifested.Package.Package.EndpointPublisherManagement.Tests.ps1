<#
    Eigenverft.Manifested.Package Package - endpoint and publisher management
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - endpoint and publisher management' -Body {
    It 'adds a team package endpoint as a location-only scan root' {
        $root = Join-Path $TestDrive 'endpoint-add-team'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageEndpointInventory.json'
        Write-TestJsonDocument -Path $inventoryPath -Document (New-TestEndpointInventoryDocument)

        Mock Get-PackageEndpointInventoryPath { $inventoryPath }

        $result = Add-TeamPackageEndpoint -BasePath '\\team-share\PackageEndpoint' -WarningAction SilentlyContinue
        $source = Get-TestEndpointSource -Document (Read-PackageJsonDocument -Path $inventoryPath).Document -SourceId 'teamPackageEndpoint'

        $result.Action | Should -Be 'Add'
        $source.kind | Should -Be 'filesystem'
        $source.enabled | Should -BeTrue
        $source.searchOrder | Should -Be 150
        $source.basePath | Should -Be '\\team-share\PackageEndpoint'
        $source.PSObject.Properties['trusted'] | Should -BeNullOrEmpty
        $source.PSObject.Properties['trustMode'] | Should -BeNullOrEmpty
        $result.Notes -join "`n" | Should -Match 'PackageTrustInventory'
    }

    It 'places a package endpoint after an existing endpoint when requested' {
        $root = Join-Path $TestDrive 'endpoint-add-after'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageEndpointInventory.json'
        $inventory = New-TestEndpointInventoryDocument -EndpointSources @{
            sitePackageEndpoint = @{
                kind        = 'filesystem'
                enabled     = $true
                searchOrder = 200
                basePath    = '\\site-share\PackageEndpoint'
            }
        }
        Write-TestJsonDocument -Path $inventoryPath -Document $inventory

        Mock Get-PackageEndpointInventoryPath { $inventoryPath }

        Add-PackageEndpoint -EndpointName 'betweenEndpoint' -BasePath '\\between-share\PackageEndpoint' -After 'moduleDefaults' -WarningAction SilentlyContinue | Out-Null
        $source = Get-TestEndpointSource -Document (Read-PackageJsonDocument -Path $inventoryPath).Document -SourceId 'betweenEndpoint'

        $source.searchOrder | Should -Be 150
    }

    It 'rejects retired endpoint trust fields' {
        $inventoryPath = Join-Path $TestDrive 'PackageEndpointInventory.json'
        $inventory = New-TestEndpointInventoryDocument -EndpointSources @{
            oldTrustEndpoint = @{
                kind        = 'filesystem'
                enabled     = $true
                searchOrder = 150
                basePath    = '\\team-share\PackageEndpoint'
                trusted     = $true
                trustMode   = 'unsignedExplicit'
            }
        }
        Write-TestJsonDocument -Path $inventoryPath -Document $inventory
        $documentInfo = Read-PackageJsonDocument -Path $inventoryPath

        { Assert-PackageEndpointInventorySchema -EndpointInventoryDocumentInfo $documentInfo } | Should -Throw '*PackageTrustInventory.json*catalogTrust*'
    }

    It 'hard-deprecates publisher commands with trust-only guidance and no inventory mutation' {
        $localPublisherInventoryPath = Join-Path (Join-Path (Get-PackageLocalRoot) 'Configuration\Internal') 'PackagePublisherInventory.json'

        { Add-PackagePublisher -PublisherId 'Team' -PublisherName 'Team Packages' -WarningAction SilentlyContinue } | Should -Throw '*Package publisher inventory commands are deprecated*Import-PackageTrust*allowUnsignedPublisherIds*'
        { Add-TeamPackagePublisher -PublisherId 'My Team' -WarningAction SilentlyContinue } | Should -Throw '*Package publisher inventory commands are deprecated*Trust-PackageSigningCertificate*allowUnsignedPublisherIds*'
        { Set-PackagePublisher -PublisherId 'Team' -AllowUnsignedDefinitions -WarningAction SilentlyContinue } | Should -Throw '*Package publisher inventory commands are deprecated*PackageTrustInventory.json*'
        { Get-PackagePublisher -PublisherId 'Team' -WarningAction SilentlyContinue } | Should -Throw '*Package publisher inventory commands are deprecated*'
        { Remove-PackagePublisher -PublisherId 'Team' -Confirm:$false -WarningAction SilentlyContinue } | Should -Throw '*Package publisher inventory commands are deprecated*'

        Test-Path -LiteralPath $localPublisherInventoryPath -PathType Leaf | Should -BeFalse
    }
}

