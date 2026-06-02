<#
    Public package search command surface.
#>

function Get-PackageSearchSettings {
    [CmdletBinding()]
    param()

    $globalDocumentInfo = Read-PackageJsonDocument -Path (Get-PackageConfigPath)
    Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalDocumentInfo

    $packageGlobalConfig = $globalDocumentInfo.Document.package
    $applicationRootDirectory = Resolve-PackageApplicationRootDirectory -PackageConfiguration $packageGlobalConfig
    $catalogTrustPolicy = 'strict'
    $catalogTrustUnknownSignedKeyPolicy = 'prompt'
    $catalogTrustAllowUnsignedPublisherIds = @()
    $catalogTrustBlockedPublisherIds = @()
    if ($packageGlobalConfig.PSObject.Properties['catalogTrust'] -and $packageGlobalConfig.catalogTrust) {
        if ($packageGlobalConfig.catalogTrust.PSObject.Properties['policy'] -and
            -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.catalogTrust.policy)) {
            $catalogTrustPolicy = [string]$packageGlobalConfig.catalogTrust.policy
        }
        if ($packageGlobalConfig.catalogTrust.PSObject.Properties['unknownSignedKeyPolicy'] -and
            -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.catalogTrust.unknownSignedKeyPolicy)) {
            $catalogTrustUnknownSignedKeyPolicy = [string]$packageGlobalConfig.catalogTrust.unknownSignedKeyPolicy
        }
        if ($packageGlobalConfig.catalogTrust.PSObject.Properties['allowUnsignedPublisherIds'] -and
            $null -ne $packageGlobalConfig.catalogTrust.allowUnsignedPublisherIds) {
            $catalogTrustAllowUnsignedPublisherIds = @(
                foreach ($configuredPublisherId in @($packageGlobalConfig.catalogTrust.allowUnsignedPublisherIds)) {
                    $normalizedPublisherId = ([string]$configuredPublisherId).Trim()
                    if (-not [string]::IsNullOrWhiteSpace($normalizedPublisherId)) {
                        $normalizedPublisherId
                    }
                }
            )
        }
        if ($packageGlobalConfig.catalogTrust.PSObject.Properties['blockedPublisherIds'] -and
            $null -ne $packageGlobalConfig.catalogTrust.blockedPublisherIds) {
            $catalogTrustBlockedPublisherIds = @(
                foreach ($configuredPublisherId in @($packageGlobalConfig.catalogTrust.blockedPublisherIds)) {
                    $normalizedPublisherId = ([string]$configuredPublisherId).Trim()
                    if (-not [string]::IsNullOrWhiteSpace($normalizedPublisherId)) {
                        $normalizedPublisherId
                    }
                }
            )
        }
    }

    $releaseTrack = 'none'
    if ($packageGlobalConfig.PSObject.Properties['selectionDefaults'] -and
        $packageGlobalConfig.selectionDefaults -and
        $packageGlobalConfig.selectionDefaults.PSObject.Properties['releaseTrack'] -and
        -not [string]::IsNullOrWhiteSpace([string]$packageGlobalConfig.selectionDefaults.releaseTrack)) {
        $releaseTrack = [string]$packageGlobalConfig.selectionDefaults.releaseTrack
    }

    return [pscustomobject]@{
        ApplicationRootDirectory = $applicationRootDirectory
        ReleaseTrack             = $releaseTrack
        CatalogTrustPolicy       = $catalogTrustPolicy
        CatalogTrustAllowUnsignedPublisherIds = @($catalogTrustAllowUnsignedPublisherIds)
        CatalogTrustBlockedPublisherIds = @($catalogTrustBlockedPublisherIds)
        CatalogTrustUnknownSignedKeyPolicy = $catalogTrustUnknownSignedKeyPolicy
    }
}

function Get-PackageSearchCandidateRows {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$EndpointName = $null,

        [Parameter(Mandatory = $true)]
        [psobject]$Settings,

        [Parameter(Mandatory = $true)]
        [psobject]$TrustInventoryDocument
    )

    $endpointInventoryInfo = Get-PackageEndpointInventoryInfo
    $sourceRows = @(Get-PackageEnabledEndpointSources -EndpointInventoryDocument $endpointInventoryInfo.Document)
    if (-not [string]::IsNullOrWhiteSpace($EndpointName)) {
        $sourceRows = @($sourceRows | Where-Object {
                [string]::Equals([string]$_.EndpointName, [string]$EndpointName, [System.StringComparison]::OrdinalIgnoreCase)
            })
    }

    $candidateRows = New-Object System.Collections.Generic.List[object]
    foreach ($sourceRow in @($sourceRows)) {
        try {
            $scanRootPath = Resolve-PackageEndpointRootPath -EndpointName ([string]$sourceRow.EndpointName) -Source $sourceRow.Source -ApplicationRootDirectory ([string]$Settings.ApplicationRootDirectory)
            foreach ($candidate in @(Select-PackageDefinitionCandidatesFromEndpointScanRoot -EndpointName ([string]$sourceRow.EndpointName) -EndpointSource $sourceRow.Source -ScanRootPath $scanRootPath -TrustInventoryDocument $TrustInventoryDocument)) {
                $candidate | Add-Member -MemberType NoteProperty -Name EndpointSearchOrder -Value ([int]$sourceRow.SearchOrder) -Force
                $candidateRows.Add($candidate) | Out-Null
            }
        }
        catch {
            Write-Warning ("Skipped package endpoint '{0}' during search: {1}" -f [string]$sourceRow.EndpointName, $_.Exception.Message)
        }
    }

    return @($candidateRows.ToArray())
}

function Get-PackageSearchTextFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition
    )

    $fields = New-Object System.Collections.Generic.List[string]
    if ($Definition.PSObject.Properties['definitionPublication'] -and $Definition.definitionPublication) {
        foreach ($name in @('definitionId', 'publisherId', 'publisherName')) {
            if ($Definition.definitionPublication.PSObject.Properties[$name] -and
                -not [string]::IsNullOrWhiteSpace([string]$Definition.definitionPublication.$name)) {
                $fields.Add([string]$Definition.definitionPublication.$name) | Out-Null
            }
        }
    }
    if ($Definition.PSObject.Properties['display'] -and
        $Definition.display.PSObject.Properties['default'] -and $Definition.display.default) {
        foreach ($name in @('name', 'publisher', 'corporation', 'summary')) {
            if ($Definition.display.default.PSObject.Properties[$name] -and
                -not [string]::IsNullOrWhiteSpace([string]$Definition.display.default.$name)) {
                $fields.Add([string]$Definition.display.default.$name) | Out-Null
            }
        }
    }
    if ($Definition.PSObject.Properties['discovery'] -and
        $Definition.discovery.PSObject.Properties['presence'] -and $Definition.discovery.presence) {
        $presence = $Definition.discovery.presence
        foreach ($command in @($presence.commands)) {
            if ($null -eq $command) {
                continue
            }
            if ($command.PSObject.Properties['name'] -and -not [string]::IsNullOrWhiteSpace([string]$command.name)) {
                $fields.Add([string]$command.name) | Out-Null
            }
            if ($command.PSObject.Properties['relativePath'] -and -not [string]::IsNullOrWhiteSpace([string]$command.relativePath)) {
                $fields.Add([string]$command.relativePath) | Out-Null
            }
        }
        foreach ($app in @($presence.apps)) {
            if ($null -eq $app) {
                continue
            }
            if ($app.PSObject.Properties['name'] -and -not [string]::IsNullOrWhiteSpace([string]$app.name)) {
                $fields.Add([string]$app.name) | Out-Null
            }
        }
        foreach ($module in @($presence.powerShellModules)) {
            if ($null -eq $module) {
                continue
            }
            if ($module.PSObject.Properties['name'] -and -not [string]::IsNullOrWhiteSpace([string]$module.name)) {
                $fields.Add([string]$module.name) | Out-Null
            }
        }
        foreach ($file in @($presence.files)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$file)) {
                $fields.Add([string]$file) | Out-Null
            }
        }
    }

    return @($fields.ToArray() | Select-Object -Unique)
}

function Test-PackageSearchQueryMatch {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Query = $null,

        [AllowNull()]
        [string[]]$Fields = @()
    )

    if ([string]::IsNullOrWhiteSpace($Query)) {
        return $true
    }

    foreach ($term in @(([string]$Query).Split([char[]]@(' ', "`t", "`r", "`n"), [System.StringSplitOptions]::RemoveEmptyEntries))) {
        $termMatched = $false
        foreach ($field in @($Fields)) {
            if ($null -ne $field -and ([string]$field).IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $termMatched = $true
                break
            }
        }
        if (-not $termMatched) {
            return $false
        }
    }

    return $true
}

function Get-PackageSearchEntryPointNames {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$Definition
    )

    if (-not $Definition -or
        -not $Definition.PSObject.Properties['discovery'] -or
        -not $Definition.discovery.PSObject.Properties['presence'] -or
        -not $Definition.discovery.presence) {
        return [pscustomobject]@{ Commands = @(); Apps = @(); PowerShellModules = @() }
    }

    $presence = $Definition.discovery.presence
    return [pscustomobject]@{
        Commands = @($presence.commands | ForEach-Object {
                if ($null -ne $_ -and $_.PSObject.Properties['name'] -and -not [string]::IsNullOrWhiteSpace([string]$_.name)) { [string]$_.name }
            } | Select-Object -Unique)
        Apps = @($presence.apps | ForEach-Object {
                if ($null -ne $_ -and $_.PSObject.Properties['name'] -and -not [string]::IsNullOrWhiteSpace([string]$_.name)) { [string]$_.name }
            } | Select-Object -Unique)
        PowerShellModules = @($presence.powerShellModules | ForEach-Object {
                if ($null -ne $_ -and $_.PSObject.Properties['name'] -and -not [string]::IsNullOrWhiteSpace([string]$_.name)) { [string]$_.name }
            } | Select-Object -Unique)
    }
}

function Get-PackageSearchTargetSummaries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition
    )

    return @(
        foreach ($target in @($Definition.artifacts.targets)) {
            $constraints = if ($target.PSObject.Properties['constraints']) { $target.constraints } else { [pscustomobject]@{} }
            $os = if ($constraints.PSObject.Properties['os']) { @($constraints.os) } else { @('*') }
            $cpu = if ($constraints.PSObject.Properties['cpu']) { @($constraints.cpu) } else { @('*') }
            [pscustomobject]@{
                TargetId                    = [string]$target.id
                ReleaseTrack                = [string]$target.releaseTrack
                ArtifactDistributionVariant = [string]$target.artifactDistributionVariant
                Os                          = @($os)
                Cpu                         = @($cpu)
            }
        }
    )
}

function Resolve-PackageSearchSelectedVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [Parameter(Mandatory = $true)]
        [string]$Platform,

        [Parameter(Mandatory = $true)]
        [string]$Architecture,

        [Parameter(Mandatory = $true)]
        [string]$ReleaseTrack
    )

    try {
        $packageConfig = [pscustomobject]@{
            Definition   = $Definition
            DefinitionId = $DefinitionId
            Platform     = $Platform
            Architecture = $Architecture
            ReleaseTrack = $ReleaseTrack
        }
        $package = Resolve-PackageEffectivePackage_1_9 -PackageConfig $packageConfig
        return [pscustomobject]@{
            Available = $true
            Version   = [string]$package.version
            TargetId  = [string]$package.artifactTargetId
            ReleaseTrack = [string]$package.releaseTrack
            ArtifactDistributionVariant = [string]$package.artifactDistributionVariant
            Error     = $null
        }
    }
    catch {
        return [pscustomobject]@{
            Available = $false
            Version   = $null
            TargetId  = $null
            ReleaseTrack = $ReleaseTrack
            ArtifactDistributionVariant = $null
            Error     = $_.Exception.Message
        }
    }
}

function Search-Package {
    <#
    .SYNOPSIS
        Searches enabled package definition endpoints.

    .DESCRIPTION
        Scans enabled moduleLocal and filesystem endpoints, applies catalog trust
        eligibility, and returns package definition rows that match the query.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [string]$Query = $null,

        [AllowNull()]
        [string]$PublisherId = $null,

        [AllowNull()]
        [string]$EndpointName = $null,

        [AllowNull()]
        [string]$Platform = $null,

        [AllowNull()]
        [string]$Architecture = $null,

        [AllowNull()]
        [string]$ReleaseTrack = $null,

        [switch]$CurrentPlatformOnly,

        [switch]$IncludeIneligible
    )

    $settings = Get-PackageSearchSettings
    $runtimeContext = Get-PackageRuntimeContext
    $effectivePlatform = if ([string]::IsNullOrWhiteSpace($Platform)) { [string]$runtimeContext.Platform } else { ([string]$Platform).Trim() }
    $effectiveArchitecture = if ([string]::IsNullOrWhiteSpace($Architecture)) { [string]$runtimeContext.Architecture } else { ([string]$Architecture).Trim() }
    $effectiveReleaseTrack = if ([string]::IsNullOrWhiteSpace($ReleaseTrack)) { [string]$settings.ReleaseTrack } else { ([string]$ReleaseTrack).Trim() }
    $trustInventoryInfo = Get-PackageTrustInventoryInfo
    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($candidate in @(Get-PackageSearchCandidateRows -EndpointName $EndpointName -Settings $settings -TrustInventoryDocument $trustInventoryInfo.Document)) {
        if (-not [string]::IsNullOrWhiteSpace($PublisherId) -and
            -not [string]::Equals([string]$candidate.PublisherId, [string]$PublisherId, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $trust = Resolve-PackageDefinitionCandidateTrustEligibility -Candidate $candidate -CatalogTrustPolicy ([string]$settings.CatalogTrustPolicy) -CatalogTrustAllowUnsignedPublisherIds @($settings.CatalogTrustAllowUnsignedPublisherIds) -CatalogTrustBlockedPublisherIds @($settings.CatalogTrustBlockedPublisherIds) -UnknownSignedKeyPolicy ([string]$settings.CatalogTrustUnknownSignedKeyPolicy)
        if (-not $trust.Eligible -and -not $IncludeIneligible.IsPresent) {
            continue
        }

        try {
            $definitionInfo = Read-PackageJsonDocument -Path ([string]$candidate.DefinitionPath)
            Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId ([string]$candidate.DefinitionId) -PublisherId ([string]$candidate.PublisherId)
        }
        catch {
            Write-Warning ("Skipped package definition '{0}' during search: {1}" -f [string]$candidate.DefinitionPath, $_.Exception.Message)
            continue
        }

        $definition = $definitionInfo.Document
        $fields = @(Get-PackageSearchTextFields -Definition $definition)
        if (-not (Test-PackageSearchQueryMatch -Query $Query -Fields $fields)) {
            continue
        }

        $selection = Resolve-PackageSearchSelectedVersion -Definition $definition -DefinitionId ([string]$candidate.DefinitionId) -Platform $effectivePlatform -Architecture $effectiveArchitecture -ReleaseTrack $effectiveReleaseTrack
        if ($CurrentPlatformOnly.IsPresent -and -not [bool]$selection.Available) {
            continue
        }

        $display = $definition.display.default
        $entryPoints = Get-PackageSearchEntryPointNames -Definition $definition
        $targetSummaries = @(Get-PackageSearchTargetSummaries -Definition $definition)
        $invokeCommand = if ([string]::IsNullOrWhiteSpace([string]$candidate.PublisherId)) {
            "Invoke-Package -DefinitionId '$($candidate.DefinitionId)'"
        }
        else {
            "Invoke-Package -DefinitionId '$($candidate.DefinitionId)' -PublisherId '$($candidate.PublisherId)'"
        }

        $rows.Add([pscustomobject]@{
            DefinitionId               = [string]$candidate.DefinitionId
            PublisherId                = [string]$candidate.PublisherId
            PublisherName              = [string]$candidate.PublisherName
            Name                       = [string]$display.name
            DisplayPublisher           = [string]$display.publisher
            Corporation                = [string]$display.corporation
            Summary                    = [string]$display.summary
            Version                    = [string]$selection.Version
            PlatformAvailable          = [bool]$selection.Available
            Platform                   = $effectivePlatform
            Architecture               = $effectiveArchitecture
            ReleaseTrack               = $effectiveReleaseTrack
            SelectedTargetId           = [string]$selection.TargetId
            SelectedArtifactDistributionVariant = [string]$selection.ArtifactDistributionVariant
            SelectionError             = [string]$selection.Error
            Commands                   = @($entryPoints.Commands)
            Apps                       = @($entryPoints.Apps)
            PowerShellModules          = @($entryPoints.PowerShellModules)
            Targets                    = @($targetSummaries)
            EndpointName               = [string]$candidate.EndpointName
            EndpointSearchOrder        = [int]$candidate.EndpointSearchOrder
            EndpointSourceKind         = [string]$candidate.EndpointSourceKind
            DefinitionRevision         = [int]$candidate.DefinitionRevision
            PublishedAtUtc             = [string]$candidate.PublishedAtUtc
            CatalogTrustStatus         = [string]$trust.TrustStatus
            CatalogTrustReason         = [string]$trust.TrustReason
            CatalogTrustEligible       = [bool]$trust.Eligible
            SignatureStatus            = [string]$candidate.SignatureStatus
            SignatureValid             = [bool]$candidate.SignatureValid
            SignatureTrusted           = [bool]$candidate.SignatureTrusted
            SignatureKeyThumbprint     = if ([string]::IsNullOrWhiteSpace([string]$candidate.SignatureKeyThumbprint)) { $null } else { [string]$candidate.SignatureKeyThumbprint }
            DefinitionPath             = [string]$candidate.DefinitionPath
            InvokeCommand              = $invokeCommand
        }) | Out-Null
    }

    return @($rows.ToArray() | Sort-Object -Property DefinitionId, PublisherId, EndpointSearchOrder, EndpointName, DefinitionRevision)
}
