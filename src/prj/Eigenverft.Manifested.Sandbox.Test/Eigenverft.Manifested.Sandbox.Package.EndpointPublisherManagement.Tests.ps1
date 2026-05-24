<#
    Eigenverft.Manifested.Sandbox Package - endpoint and publisher management
#>

. "$PSScriptRoot\Eigenverft.Manifested.Sandbox.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Sandbox Package - endpoint and publisher management' -Body {
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
        $result.Notes -join "`n" | Should -Match 'PackagePublisherInventory'
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

        { Assert-PackageEndpointInventorySchema -EndpointInventoryDocumentInfo $documentInfo } | Should -Throw '*PackagePublisherInventory.json*'
    }

    It 'adds and trusts a publisher through publisher policy' {
        $root = Join-Path $TestDrive 'publisher-add-trust'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackagePublisherInventory.json'
        Write-TestJsonDocument -Path $inventoryPath -Document @{ inventoryVersion = 1; publishers = @() }

        Mock Get-PackagePublisherInventoryPath { $inventoryPath }

        $added = Add-PackagePublisher -PublisherId 'Team' -PublisherName 'Team Packages' -WarningAction SilentlyContinue
        $trusted = Set-PackagePublisher -PublisherId 'Team' -AllowUnsignedDefinitions -WarningAction SilentlyContinue
        $source = (Read-PackageJsonDocument -Path $inventoryPath).Document.publishers | Select-Object -First 1

        $added.Status | Should -Be 'Added'
        $trusted.Status | Should -Be 'Updated'
        $source.publisherId | Should -Be 'Team'
        $source.publisherName | Should -Be 'Team Packages'
        $source.trusted | Should -BeTrue
        $source.trustMode | Should -Be 'unsignedExplicit'
        $source.PSObject.Properties['searchOrder'] | Should -BeNullOrEmpty
    }

    It 'adds a trusted team package publisher with the JSON publisher hint' {
        $root = Join-Path $TestDrive 'publisher-add-team'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackagePublisherInventory.json'
        Write-TestJsonDocument -Path $inventoryPath -Document @{ inventoryVersion = 1; publishers = @() }

        Mock Get-PackagePublisherInventoryPath { $inventoryPath }

        $result = Add-TeamPackagePublisher -PublisherId 'My Team' -WarningAction SilentlyContinue
        $source = (Read-PackageJsonDocument -Path $inventoryPath).Document.publishers | Select-Object -First 1

        $result.Status | Should -Be 'Added'
        $source.publisherId | Should -Be 'My Team'
        $source.publisherName | Should -Be 'My Team'
        $source.enabled | Should -BeTrue
        $source.trusted | Should -BeTrue
        $source.trustMode | Should -Be 'unsignedExplicit'
        $result.Notes -join "`n" | Should -Match 'definitionPublication.publisherId'
        $result.Notes -join "`n" | Should -Match 'My Team'
    }

    It 'removes publisher policy without touching endpoint files' {
        $root = Join-Path $TestDrive 'publisher-remove'
        $endpointRoot = Join-Path $root 'team-endpoint'
        $markerPath = Join-Path $endpointRoot 'keep.json'
        Write-TestJsonDocument -Path $markerPath -Document @{ keep = $true }
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackagePublisherInventory.json'
        Write-TestJsonDocument -Path $inventoryPath -Document @{
            inventoryVersion = 1
            publishers = @(
                @{
                    publisherId = 'Team'
                    publisherName = 'Team'
                    enabled = $true
                    trusted = $true
                    trustMode = 'unsignedExplicit'
                }
            )
        }

        Mock Get-PackagePublisherInventoryPath { $inventoryPath }

        $result = Remove-PackagePublisher -PublisherId 'Team' -Confirm:$false -WarningAction SilentlyContinue
        $publishers = (Read-PackageJsonDocument -Path $inventoryPath).Document.publishers

        $result.Status | Should -Be 'Removed'
        @($publishers).Count | Should -Be 0
        Test-Path -LiteralPath $markerPath -PathType Leaf | Should -BeTrue
    }
}

