<#
    Package-focused Pester coverage for the module.
#>

function global:Invoke-TestPackageDescribe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Body
    )

    Describe $Name {
        BeforeAll {
            . "$PSScriptRoot\Eigenverft.Manifested.Sandbox.TestImports.ps1"
            $script:ModuleManifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Sandbox\Eigenverft.Manifested.Sandbox.psd1'
            $script:SourceInventoryEnvVarName = Get-PackageSourceInventoryPathEnvironmentVariableName
            $script:SiteCodeEnvVarName = Get-PackageSiteCodeEnvironmentVariableName
        }

        BeforeEach {
            $script:OriginalSourceInventoryPath = [Environment]::GetEnvironmentVariable($script:SourceInventoryEnvVarName, 'Process')
            $script:OriginalSiteCode = [Environment]::GetEnvironmentVariable($script:SiteCodeEnvVarName, 'Process')
            $script:OriginalLocalAppData = [Environment]::GetEnvironmentVariable('LOCALAPPDATA', 'Process')
            [Environment]::SetEnvironmentVariable('LOCALAPPDATA', (Join-Path $TestDrive ('LocalAppData-' + [guid]::NewGuid().ToString('N'))), 'Process')
        }

        AfterEach {
            [Environment]::SetEnvironmentVariable($script:SourceInventoryEnvVarName, $script:OriginalSourceInventoryPath, 'Process')
            [Environment]::SetEnvironmentVariable($script:SiteCodeEnvVarName, $script:OriginalSiteCode, 'Process')
            [Environment]::SetEnvironmentVariable('LOCALAPPDATA', $script:OriginalLocalAppData, 'Process')
        }

        & $Body
    }
}

function global:ConvertTo-TestPsObject {
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )

    return (($InputObject | ConvertTo-Json -Depth 40) | ConvertFrom-Json)
}

function global:Get-TestFileContentSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    $bytes = $encoding.GetBytes($Content)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return (($sha256.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    finally {
        $sha256.Dispose()
    }
}

function global:Write-TestTextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $directoryPath = Split-Path -Parent $Path
    if ($directoryPath) {
        $null = New-Item -ItemType Directory -Path $directoryPath -Force
    }

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function global:Write-TestJsonDocument {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Document
    )

    $directoryPath = Split-Path -Parent $Path
    if ($directoryPath) {
        $null = New-Item -ItemType Directory -Path $directoryPath -Force
    }

    $Document | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function global:Write-TestZipFromDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$ZipPath
    )

    $zipDirectory = Split-Path -Parent $ZipPath
    if ($zipDirectory) {
        $null = New-Item -ItemType Directory -Path $zipDirectory -Force
    }

    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }

    Compress-Archive -Path (Join-Path $SourceDirectory '*') -DestinationPath $ZipPath -Force
}

function global:New-TestPackageArchiveInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [string]$ArchiveFileName = 'package.zip'
    )

    $layoutRoot = Join-Path $RootPath 'layout'
    $binDirectory = Join-Path $layoutRoot 'bin'
    $null = New-Item -ItemType Directory -Path $binDirectory -Force
    Write-TestTextFile -Path (Join-Path $layoutRoot 'Code.exe') -Content 'fake-vscode-binary'
    Write-TestTextFile -Path (Join-Path $binDirectory 'code.cmd') -Content "@echo off`r`necho $Version`r`n"

    $zipPath = Join-Path $RootPath $ArchiveFileName
    Write-TestZipFromDirectory -SourceDirectory $layoutRoot -ZipPath $zipPath

    return [pscustomobject]@{
        LayoutRoot = $layoutRoot
        ZipPath    = $zipPath
        Sha256     = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function global:New-TestPackageGlobalDocument {
    param(
        [string]$ApplicationRootDirectory,
        [string]$PackageFileStagingDirectory,
        [string]$PackageInstallStageDirectory,
        [string]$DefaultPackageDepotDirectory,
        [string]$PreferredTargetInstallDirectory,
        [string]$LocalEndpointRoot,
        [string]$ShimDirectory,
        [string]$PackageAssignmentInventoryFilePath,
        [string]$PackageOperationHistoryFilePath,
        [string]$PackageDepotRelativePath = '{definitionId}/{releaseTrack}/{version}/{artifactDistributionVariant}',
        [string]$PackageWorkSlotDirectory = '{definitionId}-{slotHash}',
        [bool]$AllowFallback = $true,
        [AllowNull()]
        [string]$DepotDistributionMode = 'packageFocused',
        [string]$EndpointMaterializationMode = 'packageFocused',
        [string]$DefinitionPublisherConflictMode = 'fail',
        [string]$ReleaseTrack = 'stable',
        [string]$Strategy = 'latestByVersion',
        [hashtable]$EnvironmentSources = $null
    )

    $acquisitionEnvironment = @{
        stores = @{
            packageFileStagingDirectory = if ($PSBoundParameters.ContainsKey('PackageFileStagingDirectory')) { $PackageFileStagingDirectory } else { '{applicationRootDirectory}/FileStage' }
            packageInstallStageDirectory = if ($PSBoundParameters.ContainsKey('PackageInstallStageDirectory')) { $PackageInstallStageDirectory } else { '{applicationRootDirectory}/InstStage' }
        }
        defaults = @{
            allowFallback = $AllowFallback
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($DepotDistributionMode)) {
        $acquisitionEnvironment.defaults.depotDistributionMode = $DepotDistributionMode
    }
    if ($PSBoundParameters.ContainsKey('EnvironmentSources') -and $null -ne $EnvironmentSources) {
        $acquisitionEnvironment.environmentSources = $EnvironmentSources
    }

    return @{
        package = @{
            applicationRootDirectory = if ($PSBoundParameters.ContainsKey('ApplicationRootDirectory')) { $ApplicationRootDirectory } else { '%LOCALAPPDATA%/Programs/Evf.Sandbox' }
            preferredTargetInstallDirectory = if ($PSBoundParameters.ContainsKey('PreferredTargetInstallDirectory')) { $PreferredTargetInstallDirectory } else { '{applicationRootDirectory}/Inst' }
            localEndpointRoot = if ($PSBoundParameters.ContainsKey('LocalEndpointRoot')) { $LocalEndpointRoot } else { '{applicationRootDirectory}/PkgEndpoint' }
            shimDirectory = if ($PSBoundParameters.ContainsKey('ShimDirectory')) { $ShimDirectory } else { '{applicationRootDirectory}/Shims' }
            layout = @{
                packageDepotRelativePath = $PackageDepotRelativePath
                packageWorkSlotDirectory = $PackageWorkSlotDirectory
            }
            acquisitionEnvironment = $acquisitionEnvironment
            endpointEnvironment = @{
                defaults = @{
                    endpointMaterializationMode = $EndpointMaterializationMode
                    definitionPublisherConflictMode = $DefinitionPublisherConflictMode
                }
            }
            packageState = @{
                inventoryFilePath = if ($PSBoundParameters.ContainsKey('PackageAssignmentInventoryFilePath')) { $PackageAssignmentInventoryFilePath } else { '{applicationRootDirectory}/State/PackageAssignmentInventory.json' }
                operationHistoryFilePath = if ($PSBoundParameters.ContainsKey('PackageOperationHistoryFilePath')) { $PackageOperationHistoryFilePath } else { '{applicationRootDirectory}/State/PackageOperationHistory.json' }
            }
            selectionDefaults = @{
                releaseTrack = $ReleaseTrack
                strategy     = $Strategy
            }
        }
    }
}

function global:New-TestEndpointInventoryDocument {
    param(
        [hashtable]$EndpointSources = @{}
    )

    $sources = New-Object System.Collections.Generic.List[object]
    $sources.Add(@{
            endpointName   = 'moduleDefaults'
            kind           = 'moduleLocal'
            enabled        = $true
            searchOrder    = 100
            definitionRoot = 'Endpoint/Defaults'
        }) | Out-Null

    foreach ($key in @($EndpointSources.Keys)) {
        $source = $EndpointSources[$key]
        if (-not $source.ContainsKey('endpointName')) {
            if ($source.ContainsKey('sourceId')) {
                $source.endpointName = [string]$source.sourceId
            }
            else {
                $source.endpointName = $key
            }
        }
        $sources.Add($source) | Out-Null
    }

    return @{
        inventoryVersion = 2
        endpoints = @($sources.ToArray())
    }
}

function global:Get-TestEndpointSource {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document,

        [Parameter(Mandatory = $true)]
        [Alias('SourceId')]
        [string]$EndpointName
    )

    $rows = if ($Document.PSObject.Properties['endpoints']) { @($Document.endpoints) } else { @() }
    return @($rows | Where-Object {
            [string]::Equals([string]$_.endpointName, $EndpointName, [System.StringComparison]::OrdinalIgnoreCase)
        } | Select-Object -First 1)[0]
}

function global:Add-TestFilesystemSourceCapabilities {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Source,

        [bool]$Readable = $true,
        [bool]$Writable = $false,
        [bool]$MirrorTarget = $false,
        [bool]$EnsureExists = $false
    )

    if (-not $Source.ContainsKey('readable')) {
        $Source.readable = $Readable
    }
    if (-not $Source.ContainsKey('writable')) {
        $Source.writable = $Writable
    }
    if (-not $Source.ContainsKey('mirrorTarget')) {
        $Source.mirrorTarget = $MirrorTarget
    }
    if (-not $Source.ContainsKey('ensureExists')) {
        $Source.ensureExists = $EnsureExists
    }

    return $Source
}

function global:New-TestDepotInventoryDocument {
    param(
        [string]$DefaultPackageDepotDirectory,
        [hashtable]$EnvironmentSources = @{}
    )

    $sources = @{}
    $sources.defaultPackageDepot = Add-TestFilesystemSourceCapabilities -Source @{
        kind         = 'filesystem'
        enabled      = $true
        searchOrder  = 300
        basePath     = if ($PSBoundParameters.ContainsKey('DefaultPackageDepotDirectory')) { $DefaultPackageDepotDirectory } else { '{applicationRootDirectory}/PkgDepot' }
    } -Writable $true -MirrorTarget $true -EnsureExists $true
    foreach ($key in @($EnvironmentSources.Keys)) {
        $sources[$key] = if ([string]::Equals([string]$EnvironmentSources[$key].kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-TestFilesystemSourceCapabilities -Source $EnvironmentSources[$key]
        }
        else {
            $EnvironmentSources[$key]
        }
    }

    return @{
        inventoryVersion = 1
        acquisitionEnvironment = @{
            environmentSources = $sources
        }
    }
}

function global:New-TestSourceInventoryDocument {
    param(
        [hashtable]$GlobalEnvironmentSources = @{},
        [hashtable]$SiteEnvironmentSources = @{},
        [string]$SiteCode = 'BER',
        [hashtable]$GlobalDefaults = @{},
        [hashtable]$SiteDefaults = @{}
    )

    $sites = @{}
    foreach ($key in @($GlobalEnvironmentSources.Keys)) {
        if ([string]::Equals([string]$GlobalEnvironmentSources[$key].kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
            $GlobalEnvironmentSources[$key] = Add-TestFilesystemSourceCapabilities -Source $GlobalEnvironmentSources[$key]
        }
    }
    foreach ($key in @($SiteEnvironmentSources.Keys)) {
        if ([string]::Equals([string]$SiteEnvironmentSources[$key].kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
            $SiteEnvironmentSources[$key] = Add-TestFilesystemSourceCapabilities -Source $SiteEnvironmentSources[$key]
        }
    }
    if ($SiteEnvironmentSources.Count -gt 0 -or $SiteDefaults.Count -gt 0) {
        $sites[$SiteCode] = @{}
        if ($SiteEnvironmentSources.Count -gt 0) {
            $sites[$SiteCode].acquisitionEnvironment = @{
                environmentSources = $SiteEnvironmentSources
            }
        }
        if ($SiteDefaults.Count -gt 0) {
            if (-not $sites[$SiteCode].ContainsKey('acquisitionEnvironment')) {
                $sites[$SiteCode].acquisitionEnvironment = @{}
            }
            $sites[$SiteCode].acquisitionEnvironment.defaults = $SiteDefaults
        }
    }

    $global = @{}
    if ($GlobalEnvironmentSources.Count -gt 0) {
        $global.acquisitionEnvironment = @{
            environmentSources = $GlobalEnvironmentSources
        }
    }
    if ($GlobalDefaults.Count -gt 0) {
        if (-not $global.ContainsKey('acquisitionEnvironment')) {
            $global.acquisitionEnvironment = @{}
        }
        $global.acquisitionEnvironment.defaults = $GlobalDefaults
    }

    return @{
        inventoryVersion = 1
        global           = $global
        sites            = $sites
    }
}

function global:New-TestReadiness {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,

        [string[]]$Directories = @('data')
    )

    return @{
        files = @(
            'Code.exe',
            'bin/code.cmd'
        )
        directories = $Directories
        commandChecks = @(
            @{
                entryPoint    = 'code'
                arguments     = @('--version')
                outputPattern = '(?m)^(?<value>\d+\.\d+\.\d+)\s*$'
                expectedValue = '{version}'
            }
        )
        metadataFiles = [object[]]@()
        signatures    = [object[]]@()
        fileDetails   = [object[]]@()
        registryChecks = [object[]]@()
    }
}

function global:New-TestExistingInstallDiscovery {
    param(
        [bool]$Enabled = $false,
        [array]$SearchLocations = [object[]]@(),
        [array]$InstallRootRules = [object[]]@()
    )

    return @{
        enabled         = $Enabled
        searchLocations = $SearchLocations
        installRootRules = $InstallRootRules
    }
}

function global:New-TestOwnershipPolicy {
    param(
        [bool]$AllowAdoptExternal = $false,
        [bool]$UpgradeAdoptedInstall = $false,
        [bool]$RequirePackageOwnership = $false
    )

    return @{
        allowAdoptExternal    = $AllowAdoptExternal
        upgradeAdoptedInstall = $UpgradeAdoptedInstall
        requirePackageOwnership = $RequirePackageOwnership
    }
}

function global:New-TestPackageRelease {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$Architecture,

        [string]$ArtifactDistributionVariant = 'win32-x64',

        [string]$ReleaseTrack = 'stable',

        [string]$ReleaseTag = '',

        [string]$FileName = '',

        [string]$PackageFileSha256 = '',

        [array]$AcquisitionCandidates = [object[]]@(),

        [hashtable]$Compatibility = $null,

        [hashtable]$Install = $null,

        [hashtable]$ReadyStateCheck = $null,

        [hashtable]$Readiness = $null,

        [hashtable]$ExistingInstallDiscovery = $null,

        [hashtable]$OwnershipPolicy = $null
    )

    $release = [ordered]@{
        id           = $Id
        version      = $Version
        releaseTrack = $ReleaseTrack
        artifactDistributionVariant = [string]$ArtifactDistributionVariant
        constraints  = @{
            os  = @('windows')
            cpu = @($Architecture)
        }
        packageFile  = if ([string]::IsNullOrWhiteSpace($FileName)) {
            $null
        }
        else {
            $packageFile = @{
                fileName = $FileName
            }
            if (-not [string]::IsNullOrWhiteSpace($PackageFileSha256)) {
                $packageFile.contentHash = @{
                    algorithm = 'sha256'
                    value     = $PackageFileSha256
                }
            }
            $packageFile
        }
        acquisitionCandidates = $AcquisitionCandidates
    }

    if (-not [string]::IsNullOrWhiteSpace($ReleaseTag)) {
        $release.releaseTag = $ReleaseTag
    }

    if ($PSBoundParameters.ContainsKey('Compatibility')) {
        $release.compatibility = $Compatibility
    }
    if ($PSBoundParameters.ContainsKey('Install')) {
        $release.assigned = @{
            install = $Install
        }
    }
    if ($PSBoundParameters.ContainsKey('ReadyStateCheck')) {
        $release.readyStateCheck = $ReadyStateCheck
    }
    if ($PSBoundParameters.ContainsKey('Readiness')) {
        $release.testReadiness = $Readiness
    }
    if ($PSBoundParameters.ContainsKey('ExistingInstallDiscovery')) {
        $release.existingInstallDiscovery = $ExistingInstallDiscovery
    }
    if ($PSBoundParameters.ContainsKey('OwnershipPolicy')) {
        $release.ownershipPolicy = $OwnershipPolicy
    }

    return (ConvertTo-TestPsObject $release)
}

function global:New-TestVSCodeDefinitionDocument {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Releases,

        [string]$DefinitionId = 'VSCodeRuntime',

        [string]$PublisherId = 'Eigenverft',

        [string]$PublisherName = 'Eigenverft',

        [int]$DefinitionRevision = 1,

        [string]$PublishedAtUtc = '2026-05-13T12:00:00Z',

        [string]$UpstreamBaseUri = 'https://update.code.visualstudio.com',

        [hashtable]$UpstreamSources = $null,

        [hashtable]$SharedInstall = $null,

        [hashtable]$SharedReadiness = $null,

        [hashtable]$SharedExistingInstallDiscovery = $null,

        [hashtable]$SharedOwnershipPolicy = $null
    )

    $firstRelease = $Releases | Where-Object { $null -ne $_ } | Select-Object -First 1

    if ($null -eq $SharedInstall) {
        $SharedInstall = @{
            install = @{
                kind             = 'expandArchive'
                installDirectory = 'vsc-rt/{releaseTrack}/{version}/{artifactDistributionVariant}'
                expandedRoot     = 'auto'
                createDirectories = @('data')
            }
            pathRegistration = @{
                mode   = 'user'
                source = @{
                    kind = 'shim'
                    use  = 'discovery.presence.commands'
                }
            }
        }
    }
    if ($null -eq $SharedReadiness) {
        $SharedReadiness = New-TestReadiness -Version '0.0.0'
    }
    if ($null -eq $SharedExistingInstallDiscovery) {
        $SharedExistingInstallDiscovery = New-TestExistingInstallDiscovery -Enabled $false
    }
    if ($null -eq $SharedOwnershipPolicy) {
        $SharedOwnershipPolicy = New-TestOwnershipPolicy
    }

    $rawAssigned = if ($firstRelease -and $firstRelease.PSObject.Properties['assigned']) {
        $firstRelease.assigned
    }
    else {
        $SharedInstall
    }
    $rawAssigned = ConvertTo-TestPsObject $rawAssigned

    $assigned = [ordered]@{}
    if ($rawAssigned.PSObject.Properties['install']) {
        $assigned.install = ConvertTo-TestPsObject $rawAssigned.install
    }
    else {
        throw "Test definition helper requires assigned.install. Use New-TestPackageRelease -Install or pass an assigned object with an install property."
    }

    if ($rawAssigned.PSObject.Properties['pathRegistration']) {
        $pathRegistration = ConvertTo-TestPsObject $rawAssigned.pathRegistration
        if ($pathRegistration.PSObject.Properties['source'] -and
            $pathRegistration.source -and
            [string]::Equals([string]$pathRegistration.source.kind, 'shim', [System.StringComparison]::OrdinalIgnoreCase)) {
            if (-not $pathRegistration.source.PSObject.Properties['use']) {
                $pathRegistration.source = ConvertTo-TestPsObject $pathRegistration.source
                $pathRegistration.source.use = 'discovery.presence.commands'
            }
        }
        $assigned.pathRegistration = $pathRegistration
    }

    $readyStateCheck = if ($rawAssigned.PSObject.Properties['readyStateCheck']) {
        ConvertTo-TestPsObject $rawAssigned.readyStateCheck
    }
    else { $null }

    $readiness = if ($firstRelease -and $firstRelease.PSObject.Properties['testReadiness']) {
        $firstRelease.testReadiness
    }
    else {
        $SharedReadiness
    }
    $readiness = ConvertTo-TestPsObject $readiness

    if (-not $readyStateCheck) {
        $readyStateCheck = [ordered]@{
            use             = 'discovery.presence'
            expectedVersion = '{version}'
            require         = [ordered]@{
                files         = (@($readiness.files).Count -gt 0)
                directories   = (@($readiness.directories).Count -gt 0)
                commands      = (@($readiness.commandChecks).Count -gt 0)
                apps          = $true
                metadataFiles = (@($readiness.metadataFiles).Count -gt 0)
                signatures    = (@($readiness.signatures).Count -gt 0)
                fileDetails   = (@($readiness.fileDetails).Count -gt 0)
                registry      = (@($readiness.registryChecks).Count -gt 0)
                powerShellModules = (@($readiness.powerShellModules).Count -gt 0)
            }
        }
    }
    else {
        if (-not $readyStateCheck.PSObject.Properties['use']) {
            $readyStateCheck.use = 'discovery.presence'
        }
    }
    $assigned.readyStateCheck = $readyStateCheck

    if ($rawAssigned.PSObject.Properties['versionUpdatePolicy']) {
        $assigned.versionUpdatePolicy = ConvertTo-TestPsObject $rawAssigned.versionUpdatePolicy
    }
    $compatibility = if ($firstRelease -and $firstRelease.PSObject.Properties['compatibility']) {
        $firstRelease.compatibility
    }
    else {
        @{ checks = [object[]]@() }
    }

    $rawExistingInstallDiscovery = if ($firstRelease -and $firstRelease.PSObject.Properties['existingInstallDiscovery']) {
        $firstRelease.existingInstallDiscovery
    }
    else {
        $SharedExistingInstallDiscovery
    }

    $discoveryPayload = ConvertTo-TestPsObject $rawExistingInstallDiscovery

    $existingInstallDiscovery = [ordered]@{
        enabled         = if ($discoveryPayload.PSObject.Properties['enabled']) { [bool]$discoveryPayload.enabled } else { $false }
        searchLocations = @($discoveryPayload.searchLocations)
        installRootRules = @($discoveryPayload.installRootRules)
    }

    $ownershipPolicy = if ($firstRelease -and $firstRelease.PSObject.Properties['ownershipPolicy']) {
        $firstRelease.ownershipPolicy
    }
    else {
        $SharedOwnershipPolicy
    }

    $compatibility = ConvertTo-TestPsObject $compatibility
    $ownershipPolicy = ConvertTo-TestPsObject $ownershipPolicy

    $commandStateChecksByName = @{}
    foreach ($commandCheck in @($readiness.commandChecks)) {
        if ($null -eq $commandCheck -or [string]::IsNullOrWhiteSpace([string]$commandCheck.entryPoint)) {
            continue
        }
        $entryPointName = [string]$commandCheck.entryPoint
        if (-not $commandStateChecksByName.ContainsKey($entryPointName)) {
            $commandStateChecksByName[$entryPointName] = New-Object System.Collections.Generic.List[object]
        }
        $stateCheck = [ordered]@{}
        foreach ($propertyName in @('arguments', 'outputPattern', 'expectedValue')) {
            if ($commandCheck.PSObject.Properties[$propertyName]) {
                $stateCheck[$propertyName] = $commandCheck.$propertyName
            }
        }
        $commandStateChecksByName[$entryPointName].Add($stateCheck) | Out-Null
    }
    if (-not $commandStateChecksByName.ContainsKey('code')) {
        $commandStateChecksByName['code'] = New-Object System.Collections.Generic.List[object]
    }

    $commands = @(
        foreach ($commandName in @($commandStateChecksByName.Keys)) {
            @{
                name         = [string]$commandName
                relativePath = if ([string]::Equals([string]$commandName, 'code', [System.StringComparison]::OrdinalIgnoreCase)) { 'bin/code.cmd' } else { "$commandName.cmd" }
                requiredForState = $true
                exposeCommand    = $true
                stateChecks  = @($commandStateChecksByName[$commandName].ToArray())
            }
        }
    )

    $artifactTargets = @()
    $artifactReleases = @()
    foreach ($release in @($Releases)) {
        if ($null -eq $release) {
            continue
        }

        $targetId = [string]$release.id
        $artifactSources = @(
            foreach ($candidate in @($release.acquisitionCandidates)) {
                if ($null -eq $candidate) { continue }
                $source = [ordered]@{ kind = [string]$candidate.kind }
                foreach ($propertyName in @('sourceId', 'sourcePath', 'searchOrder', 'priority', 'verification')) {
                    if ($candidate.PSObject.Properties[$propertyName]) {
                        $source[$propertyName] = $candidate.$propertyName
                    }
                }
                if (-not $source.Contains('sourceId') -and $candidate.PSObject.Properties['sourceRef'] -and $candidate.sourceRef.PSObject.Properties['id']) {
                    $source.sourceId = [string]$candidate.sourceRef.id
                }
                $source
            }
        )

        $packageTarget = @{
            id                         = $targetId
            releaseTrack               = [string]$release.releaseTrack
            artifactDistributionVariant = [string]$release.artifactDistributionVariant
            constraints                = $release.constraints
            versionSelection          = @{ strategy = 'latestByVersion'; allowPrerelease = $false }
        }
        if ($artifactSources.Count -gt 0) {
            $packageTarget.acquisitionCandidates = $artifactSources
        }

        $artifactTargets += $packageTarget

        $artifact = [ordered]@{
            artifactId = if ($release.PSObject.Properties['artifactId']) { [string]$release.artifactId } else { $targetId }
        }
        if ($release.packageFile -and $release.packageFile.PSObject.Properties['fileName']) {
            $artifact.fileName = [string]$release.packageFile.fileName
        }
        if ($release.packageFile -and $release.packageFile.PSObject.Properties['contentHash']) {
            $artifact.contentHash = $release.packageFile.contentHash
        }
        foreach ($packageFileProperty in @('publisherSignature', 'autoUpdateSupported', 'integrity', 'authenticode')) {
            if ($release.packageFile -and $release.packageFile.PSObject.Properties[$packageFileProperty]) {
                $artifact[$packageFileProperty] = $release.packageFile.$packageFileProperty
            }
        }
        if ($release.PSObject.Properties['sourcePath']) {
            $artifact.sourcePath = [string]$release.sourcePath
        }

        $versionEntry = [ordered]@{
            version           = [string]$release.version
            releaseTracks     = @([string]$release.releaseTrack)
            targetArtifacts   = @{
                $targetId = $artifact
            }
        }
        if ($release.PSObject.Properties['releaseTag'] -and -not [string]::IsNullOrWhiteSpace([string]$release.releaseTag)) {
            $versionEntry.upstreamRelease = @{
                sourceId   = if ($artifactSources.Count -gt 0 -and $artifactSources[0].sourceId) { [string]$artifactSources[0].sourceId } else { 'vsCodeUpdateService' }
                releaseTag = [string]$release.releaseTag
            }
        }
        if ($release.PSObject.Properties['release']) {
            $versionEntry.upstreamRelease = $release.release
        }
        $artifactReleases += $versionEntry
    }

    $sources = if ($PSBoundParameters.ContainsKey('UpstreamSources') -and $null -ne $UpstreamSources) {
        $UpstreamSources
    }
    else {
        @{
            vsCodeUpdateService = @{ kind = 'download'; baseUri = $UpstreamBaseUri }
        }
    }

    return @{
        schemaVersion = '1.6'
        definitionPublication = @{
            publisherId = $PublisherId
            publisherName = $PublisherName
            definitionId = $DefinitionId
            definitionRevision = $DefinitionRevision
            publishedAtUtc = $PublishedAtUtc
        }
        display       = @{
            default = @{
                name        = 'Visual Studio Code'
                publisher   = 'Microsoft'
                corporation = 'Microsoft Corporation'
                summary     = 'Code editor'
            }
        }
        dependencies  = @()
        artifacts     = @{
            targets  = $artifactTargets
            releases = $artifactReleases
            sources  = $sources
        }
        discovery = @{
            presence = @{
                files         = @($readiness.files)
                directories   = @($readiness.directories)
                commands      = $commands
                apps          = @(
                    @{
                        name         = 'Code'
                        relativePath = 'Code.exe'
                        requiredForState = $true
                        exposeApp        = $true
                    }
                )
                metadataFiles = @($readiness.metadataFiles)
                signatures    = @($readiness.signatures)
                fileDetails   = @($readiness.fileDetails)
                registry      = @($readiness.registryChecks)
                powerShellModules = @($readiness.powerShellModules)
            }
            existingInstall = $existingInstallDiscovery
        }
        packageOperations = @{
            policy = @{
                ownershipPolicy = $ownershipPolicy
                compatibility   = $compatibility
            }
            assigned = $assigned
            removed = @{
                policy = @{
                    whenNotInInventory = 'succeed'
                    allowedInventoryOwnershipKinds = @('PackageInstalled')
                    allowUntrackedExternalRemoval = $false
                    removeDependencies = $false
                }
                operation = @{
                    kind = 'deleteInstallDirectory'
                    pathSource = 'inventory.installDirectory'
                }
                absenceVerification = @{
                    use = 'discovery.presence'
                    require = @{
                        files         = $true
                        directories   = $false
                        commands      = $false
                        apps          = $false
                        metadataFiles = $false
                        signatures    = $false
                        fileDetails   = $false
                        registry      = $false
                        powerShellModules = $false
                    }
                }
                postRemoveCleanup = @{
                    packageInventoryRecord = $true
                    generatedShims = $true
                    pathEntries = $true
                    workDirectories = $true
                }
            }
        }
    }
}
function global:Write-TestPackageDocuments {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $true)]
        [object]$GlobalDocument,

        [Parameter(Mandatory = $true)]
        [object]$DefinitionDocument,

        [AllowNull()]
        [object]$DepotInventoryDocument,

        [AllowNull()]
        [object]$EndpointInventoryDocument,

        [AllowNull()]
        [object]$PublisherInventoryDocument,

        [AllowNull()]
        [object]$SourceInventoryDocument
    )

    $globalConfigPath = Join-Path $RootPath 'Configuration\Internal\PackageConfig.json'
    $depotInventoryPath = Join-Path $RootPath 'Configuration\Internal\PackageDepotInventory.json'
    $endpointInventoryPath = Join-Path $RootPath 'Configuration\Internal\PackageEndpointInventory.json'
    $publisherInventoryPath = Join-Path $RootPath 'Configuration\Internal\PackagePublisherInventory.json'
    $endpointDefinitionsRoot = Join-Path $RootPath 'EndpointDefinitions'
    $definitionPublisherId = if ($DefinitionDocument.PSObject.Properties['definitionPublication'] -and
        $DefinitionDocument.definitionPublication.PSObject.Properties['publisherId'] -and
        -not [string]::IsNullOrWhiteSpace([string]$DefinitionDocument.definitionPublication.publisherId)) {
        [string]$DefinitionDocument.definitionPublication.publisherId
    }
    else {
        'Eigenverft'
    }
    $definitionWireId = $null
    if ($DefinitionDocument -is [System.Collections.IDictionary]) {
        $dictKeys = @($DefinitionDocument.Keys | ForEach-Object { [string]$_ })
        if ($dictKeys -contains 'definitionPublication') {
            $publication = $DefinitionDocument['definitionPublication']
            if ($publication -is [System.Collections.IDictionary] -and $publication.Contains('definitionId') -and -not [string]::IsNullOrWhiteSpace([string]$publication['definitionId'])) {
                $definitionWireId = [string]$publication['definitionId']
            }
            elseif ($publication.PSObject.Properties['definitionId'] -and -not [string]::IsNullOrWhiteSpace([string]$publication.definitionId)) {
                $definitionWireId = [string]$publication.definitionId
            }
        }
        if ([string]::IsNullOrWhiteSpace($definitionWireId) -and $dictKeys -contains 'id' -and -not [string]::IsNullOrWhiteSpace([string]$DefinitionDocument['id'])) {
            $definitionWireId = [string]$DefinitionDocument['id']
        }
    }
    else {
        if ($DefinitionDocument.PSObject.Properties['definitionPublication'] -and
            $DefinitionDocument.definitionPublication.PSObject.Properties['definitionId'] -and
            -not [string]::IsNullOrWhiteSpace([string]$DefinitionDocument.definitionPublication.definitionId)) {
            $definitionWireId = [string]$DefinitionDocument.definitionPublication.definitionId
        }
        elseif ($DefinitionDocument.PSObject.Properties['id'] -and -not [string]::IsNullOrWhiteSpace([string]$DefinitionDocument.id)) {
            $definitionWireId = [string]$DefinitionDocument.id
        }
    }
    if ([string]::IsNullOrWhiteSpace($definitionWireId)) {
        throw 'Write-TestPackageDocuments requires DefinitionDocument.definitionPublication.definitionId (or legacy id).'
    }
    $definitionPath = Join-Path (Join-Path $endpointDefinitionsRoot $definitionPublisherId) "$definitionWireId.json"
    Write-TestJsonDocument -Path $globalConfigPath -Document $GlobalDocument
    if (-not $PSBoundParameters.ContainsKey('DepotInventoryDocument') -or $null -eq $DepotInventoryDocument) {
        $DepotInventoryDocument = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory (Join-Path $RootPath 'PkgDepot')
    }
    if (-not $PSBoundParameters.ContainsKey('EndpointInventoryDocument') -or $null -eq $EndpointInventoryDocument) {
        $EndpointInventoryDocument = @{
            inventoryVersion = 2
            endpoints = @(
                @{
                    endpointName = 'moduleDefaults'
                    kind = 'filesystem'
                    enabled = $true
                    searchOrder = 100
                    basePath = $endpointDefinitionsRoot
                }
            )
        }
    }
    if (-not $PSBoundParameters.ContainsKey('PublisherInventoryDocument') -or $null -eq $PublisherInventoryDocument) {
        $PublisherInventoryDocument = @{
            inventoryVersion = 1
            publishers = @(
                @{
                    publisherId = $definitionPublisherId
                    publisherName = $definitionPublisherId
                    enabled = $true
                    trusted = $true
                    trustMode = 'unsignedExplicit'
                }
            )
        }
    }
    Write-TestJsonDocument -Path $depotInventoryPath -Document $DepotInventoryDocument
    Write-TestJsonDocument -Path $endpointInventoryPath -Document $EndpointInventoryDocument
    Write-TestJsonDocument -Path $publisherInventoryPath -Document $PublisherInventoryDocument
    Write-TestJsonDocument -Path $definitionPath -Document $DefinitionDocument

    # Definition resolution no longer uses filename-based Get-PackageDefinitionPath.
    # Keep the bootstrap-local PackageEndpointInventory.json aligned for tests that mock
    # PackageConfig.json only.
    Write-TestJsonDocument -Path (Get-PackageLocalEndpointInventoryPath) -Document $EndpointInventoryDocument
    Write-TestJsonDocument -Path (Get-PackageLocalPublisherInventoryPath) -Document $PublisherInventoryDocument

    $sourceInventoryPath = $null
    if ($PSBoundParameters.ContainsKey('SourceInventoryDocument') -and $null -ne $SourceInventoryDocument) {
        $sourceInventoryPath = Join-Path $RootPath 'PackageSourceInventory.json'
        Write-TestJsonDocument -Path $sourceInventoryPath -Document $SourceInventoryDocument
    }

    return [pscustomobject]@{
        GlobalConfigPath        = $globalConfigPath
        DepotInventoryPath      = $depotInventoryPath
        EndpointInventoryPath   = $endpointInventoryPath
        PublisherInventoryPath  = $publisherInventoryPath
        DefinitionPath          = $definitionPath
        SourceInventoryPath    = $sourceInventoryPath
    }
}

