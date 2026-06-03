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

    It 'surfaces AuthoringTarget on endpoint summaries' {
        $root = Join-Path $TestDrive 'endpoint-authoring-summary'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageEndpointInventory.json'
        $inventory = New-TestEndpointInventoryDocument -EndpointSources @{
            draftEndpoint = @{
                kind            = 'filesystem'
                enabled         = $false
                searchOrder     = 250
                basePath        = (Join-Path $TestDrive 'draft-endpoint-root')
                authoringTarget = $true
            }
        }
        Write-TestJsonDocument -Path $inventoryPath -Document $inventory
        Mock Get-PackageEndpointInventoryPath { $inventoryPath }

        $summary = Get-PackageEndpoint -EndpointName 'draftEndpoint'
        $summary.AuthoringTarget | Should -BeTrue
    }

    It 'persists authoring target switches on add and set' {
        $root = Join-Path $TestDrive 'endpoint-authoring-switches'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageEndpointInventory.json'
        Write-TestJsonDocument -Path $inventoryPath -Document (New-TestEndpointInventoryDocument)
        Mock Get-PackageEndpointInventoryPath { $inventoryPath }

        Add-PackageEndpoint -EndpointName 'authorEndpoint' -BasePath (Join-Path $TestDrive 'author-root') -AuthoringTarget -WarningAction SilentlyContinue | Out-Null
        (Get-TestEndpointSource -Document (Read-PackageJsonDocument -Path $inventoryPath).Document -SourceId 'authorEndpoint').authoringTarget | Should -BeTrue

        Set-PackageEndpoint -EndpointName 'authorEndpoint' -NoAuthoringTarget -WarningAction SilentlyContinue | Out-Null
        (Get-TestEndpointSource -Document (Read-PackageJsonDocument -Path $inventoryPath).Document -SourceId 'authorEndpoint').authoringTarget | Should -BeFalse

        Set-PackageEndpoint -EndpointName 'authorEndpoint' -AuthoringTarget -WarningAction SilentlyContinue | Out-Null
        (Get-TestEndpointSource -Document (Read-PackageJsonDocument -Path $inventoryPath).Document -SourceId 'authorEndpoint').authoringTarget | Should -BeTrue
    }

    It 'selects a Ready authoring target when writable' {
        $readyRoot = Join-Path $TestDrive 'endpoint-authoring-ready-root'
        New-Item -ItemType Directory -Path $readyRoot -Force | Out-Null
        $root = Join-Path $TestDrive 'endpoint-authoring-ready'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageEndpointInventory.json'
        $inventory = New-TestEndpointInventoryDocument -EndpointSources @{
            readyEndpoint = @{
                kind            = 'filesystem'
                enabled         = $true
                searchOrder     = 50
                basePath        = $readyRoot
                authoringTarget = $true
            }
        }
        Write-TestJsonDocument -Path $inventoryPath -Document $inventory
        Mock Get-PackageEndpointInventoryPath { $inventoryPath }

        $evaluation = Get-PackageAuthoringTargetEvaluation -EndpointPreference First
        $evaluation.SelectedTarget | Should -Not -BeNullOrEmpty
        $evaluation.SelectedTarget.Status | Should -Be 'Ready'
        $evaluation.SelectedTarget.EndpointName | Should -Be 'readyEndpoint'
    }

    It 'selects DraftOnly when the only writable marked target is disabled' {
        $draftRoot = Join-Path $TestDrive 'endpoint-authoring-draftonly-root'
        New-Item -ItemType Directory -Path $draftRoot -Force | Out-Null
        $root = Join-Path $TestDrive 'endpoint-authoring-draftonly'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageEndpointInventory.json'
        $inventory = New-TestEndpointInventoryDocument -EndpointSources @{
            draftOnlyEndpoint = @{
                kind            = 'filesystem'
                enabled         = $false
                searchOrder     = 120
                basePath        = $draftRoot
                authoringTarget = $true
            }
        }
        Write-TestJsonDocument -Path $inventoryPath -Document $inventory
        Mock Get-PackageEndpointInventoryPath { $inventoryPath }

        $evaluation = Get-PackageAuthoringTargetEvaluation -EndpointPreference First
        $evaluation.SelectedTarget.Status | Should -Be 'DraftOnly'
        $evaluation.Warnings -join "`n" | Should -Match 'DraftOnly'
    }

    It 'reports NoMarkedTarget when no endpoint is marked for authoring' {
        $root = Join-Path $TestDrive 'endpoint-authoring-none-marked'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageEndpointInventory.json'
        Write-TestJsonDocument -Path $inventoryPath -Document (New-TestEndpointInventoryDocument)
        Mock Get-PackageEndpointInventoryPath { $inventoryPath }

        $evaluation = Get-PackageAuthoringTargetEvaluation
        $evaluation.TroubleshootingKind | Should -Be 'NoMarkedTarget'
        $evaluation.SelectedTarget | Should -BeNullOrEmpty
    }

    It 'reports AllMarkedBlocked when marked targets are not usable' {
        $root = Join-Path $TestDrive 'endpoint-authoring-all-blocked'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageEndpointInventory.json'
        $inventory = New-TestEndpointInventoryDocument -EndpointSources @{
            blockedEndpoint = @{
                kind            = 'filesystem'
                enabled         = $true
                searchOrder     = 120
                basePath        = '\\missing-share\PackageEndpoint'
                authoringTarget = $true
            }
        }
        Write-TestJsonDocument -Path $inventoryPath -Document $inventory
        Mock Get-PackageEndpointInventoryPath { $inventoryPath }

        $evaluation = Get-PackageAuthoringTargetEvaluation
        $evaluation.TroubleshootingKind | Should -Be 'AllMarkedBlocked'
        $evaluation.Candidates[0].Status | Should -Be 'Blocked'
        $evaluation.Candidates[0].SkipReason | Should -Not -BeNullOrEmpty
    }

    It 'classifies httpsCatalog authoring targets as Unsupported' {
        $root = Join-Path $TestDrive 'endpoint-authoring-https'
        $inventoryPath = Join-Path $root 'Configuration\Internal\PackageEndpointInventory.json'
        $inventory = New-TestEndpointInventoryDocument -EndpointSources @{
            httpsEndpoint = @{
                kind            = 'httpsCatalog'
                enabled         = $true
                searchOrder     = 400
                baseUri         = 'https://catalog.example'
                catalogPath     = '/packages'
                authoringTarget = $true
            }
        }
        Write-TestJsonDocument -Path $inventoryPath -Document $inventory
        Mock Get-PackageEndpointInventoryPath { $inventoryPath }

        $evaluation = Get-PackageAuthoringTargetEvaluation
        $evaluation.TroubleshootingKind | Should -Be 'AllMarkedBlocked'
        $evaluation.Candidates[0].Status | Should -Be 'Unsupported'
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

