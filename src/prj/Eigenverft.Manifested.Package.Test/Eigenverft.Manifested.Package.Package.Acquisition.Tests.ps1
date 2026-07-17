<#
    Eigenverft.Manifested.Package Package - artifact-file-set acquisition
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

function global:New-TestArtifactSetDefinition {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]$Files,

        [string]$InstallArtifactFileId = 'setup'
    )

    $release = New-TestPackageRelease -Id 'artifact-set-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -FileName 'placeholder.bin' -AcquisitionCandidates @(
        @{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } }
    )
    $definition = New-TestVSCodeDefinitionDocument -DefinitionId 'ArtifactSet' -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0')
    $definition.packageOperations.assigned.install.artifactFileId = $InstallArtifactFileId
    $target = $definition.artifacts.targets[0]
    $releaseArtifact = $definition.artifacts.releases[0].targetArtifacts['artifact-set-win-x64-stable']
    $target.artifactFiles = @{}
    $releaseArtifact.artifactFiles = @{}
    foreach ($file in $Files) {
        $target.artifactFiles[$file.id] = @{
            relativePathTemplate = $file.relativePath
            acquisitionCandidates = @($file.acquisitionCandidates)
        }
        $releaseFile = @{}
        if ($file.ContainsKey('contentHash')) { $releaseFile.contentHash = $file.contentHash }
        if ($file.ContainsKey('relativePathOverride')) { $releaseFile.relativePath = $file.relativePathOverride }
        $releaseArtifact.artifactFiles[$file.id] = $releaseFile
    }
    return $definition
}

function global:Get-TestArtifactSetResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $true)]
        [hashtable]$Definition,

        [AllowNull()]
        [hashtable]$DepotInventory = $null,

        [switch]$Offline
    )

    $global = New-TestPackageGlobalDocument -PackageFileStagingDirectory (Join-Path $RootPath 'FileStage') -PackageInstallStageDirectory (Join-Path $RootPath 'InstallStage') -DefaultPackageDepotDirectory (Join-Path $RootPath 'DefaultDepot')
    $writeArguments = @{
        RootPath = $RootPath
        GlobalDocument = $global
        DefinitionDocument = $Definition
    }
    if ($DepotInventory) { $writeArguments.DepotInventoryDocument = $DepotInventory }
    $documents = Write-TestPackageDocuments @writeArguments
    $script:ArtifactSetDocuments = $documents
    Mock Get-PackageConfigPath { $script:ArtifactSetDocuments.GlobalConfigPath }
    Mock Get-PackageDepotInventoryPath { $script:ArtifactSetDocuments.DepotInventoryPath }
    Mock Get-PackageDefinitionPath { param($DefinitionId) $script:ArtifactSetDocuments.DefinitionPath }

    $config = Get-PackageConfig -DefinitionId 'ArtifactSet'
    $result = New-PackageResult -PackageConfig $config -Offline:$Offline
    $result = Resolve-PackagePackage -PackageResult $result
    $result = Resolve-PackagePaths -PackageResult $result
    return (Build-PackageAcquisitionPlan -PackageResult $result)
}

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - artifact-file-set acquisition' -Body {

    It 'keeps artifact staging and depot paths distinct while preserving nested relative paths' {
        $rootPath = Join-Path $TestDrive 'paths'
        $definition = New-TestArtifactSetDefinition -Files @(
            @{ id = 'setup'; relativePath = 'installer/setup-2.0.0.exe'; acquisitionCandidates = @(@{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'none' } }) }
        )
        $result = Get-TestArtifactSetResult -RootPath $rootPath -Definition $definition

        @($result.ArtifactFiles).Count | Should -Be 1
        $result.ArtifactFiles[0].Id | Should -Be 'setup'
        $result.ArtifactFiles[0].RelativePath | Should -Be 'installer\setup-2.0.0.exe'
        $result.ArtifactFiles[0].StagingPath | Should -Not -Be $result.ArtifactFiles[0].DefaultDepotPath
        $result.ArtifactFiles[0].StagingPath | Should -Match '[\\]FileStage[\\]ArtifactSet-[0-9a-f]{8}[\\]installer[\\]setup-2\.0\.0\.exe$'
        $result.ArtifactFiles[0].DefaultDepotPath | Should -Match '[\\]PkgDepot[\\]ArtifactSet[\\]stable[\\]2\.0\.0[\\]win32-x64[\\]installer[\\]setup-2\.0\.0\.exe$'
        $result.OperationArtifactFile.Id | Should -Be 'setup'
        $result.OperationArtifactFilePath | Should -Be $result.ArtifactFiles[0].StagingPath
        @($result.PSObject.Properties.Name) | Should -Contain 'ArtifactStagingDirectory'
        @($result.PSObject.Properties.Name) | Should -Contain 'ArtifactStagingRootDirectory'
        foreach ($legacyProperty in @('PackageFile', 'PackageFileName', 'PackageFilePath', 'PackageFileStagingPath', 'PackageFileStagingDirectory', 'PackageFileStagingRootDirectory')) {
            @($result.PSObject.Properties.Name) | Should -Not -Contain $legacyProperty
        }
    }

    It 'verifies artifact files with sha512 content hashes' {
        $artifactPath = Join-Path $TestDrive 'sha512\artifact.bin'
        Write-TestTextFile -Path $artifactPath -Content 'sha512 artifact content'
        $sha512 = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA512).Hash.ToLowerInvariant()

        $verification = Test-PackageSavedFile -Path $artifactPath -Verification ([pscustomobject]@{
                mode = 'required'; algorithm = 'sha512'; sha512 = $sha512
            })

        $verification.Status | Should -Be 'VerificationPassed'
        $verification.Accepted | Should -BeTrue
        $verification.ExpectedHash | Should -Be $sha512
    }

    It 'materializes every file independently from different ordered sources' {
        $rootPath = Join-Path $TestDrive 'different-sources'
        $setupContent = 'setup-content'
        $partContent = 'part-content'
        $setupSource = Join-Path $rootPath 'sources\setup.exe'
        $partSource = Join-Path $rootPath 'sources\setup.001'
        Write-TestTextFile -Path $setupSource -Content $setupContent
        Write-TestTextFile -Path $partSource -Content $partContent
        $definition = New-TestArtifactSetDefinition -Files @(
            @{
                id = 'setup'; relativePath = 'setup.exe'
                contentHash = @{ algorithm = 'sha256'; value = (Get-FileHash $setupSource -Algorithm SHA256).Hash.ToLowerInvariant() }
                acquisitionCandidates = @(
                    @{ kind = 'vendorDownload'; url = 'https://example.invalid/missing-setup.exe'; searchOrder = 100; verification = @{ mode = 'required' } },
                    @{ kind = 'vendorDownload'; url = 'https://example.invalid/setup.exe'; searchOrder = 200; verification = @{ mode = 'required' } }
                )
            },
            @{
                id = 'part001'; relativePath = 'setup.001'
                contentHash = @{ algorithm = 'sha256'; value = (Get-FileHash $partSource -Algorithm SHA256).Hash.ToLowerInvariant() }
                acquisitionCandidates = @(
                    @{ kind = 'vendorDownload'; url = 'https://example.invalid/setup.001'; searchOrder = 100; verification = @{ mode = 'required' } }
                )
            }
        )
        Mock Save-PackageDownloadFile {
            param($Uri, $TargetPath)
            if ($Uri -like '*missing-*') { throw 'simulated first-source failure' }
            $source = if ($Uri -like '*.001') { $partSource } else { $setupSource }
            Copy-Item -LiteralPath $source -Destination $TargetPath -Force
            return $TargetPath
        }

        $result = Get-TestArtifactSetResult -RootPath $rootPath -Definition $definition
        $result = Resolve-PackageArtifactFiles -PackageResult $result

        $result.ArtifactPreparation.Success | Should -BeTrue
        @($result.ArtifactFiles | Where-Object { $_.Preparation.Success }).Count | Should -Be 2
        $setupArtifact = $result.ArtifactFiles | Where-Object Id -eq setup
        $partArtifact = $result.ArtifactFiles | Where-Object Id -eq part001
        @($setupArtifact.Preparation.Attempts | Where-Object Status -eq 'Failed').Count | Should -Be 1
        Get-Content -LiteralPath $setupArtifact.StagingPath -Raw | Should -Be $setupContent
        Get-Content -LiteralPath $partArtifact.StagingPath -Raw | Should -Be $partContent
    }

    It 'repairs a partial depot set, distributes every member, and is idempotent' {
        $rootPath = Join-Path $TestDrive 'partial-repair'
        $setupSource = Join-Path $rootPath 'sources\setup.exe'
        $partSource = Join-Path $rootPath 'sources\parts\setup.001'
        Write-TestTextFile -Path $setupSource -Content 'setup'
        Write-TestTextFile -Path $partSource -Content 'part001'
        $teamDepot = Join-Path $rootPath 'TeamDepot'
        $depotInventory = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory (Join-Path $rootPath 'DefaultDepot') -EnvironmentSources @{
            teamPackageDepot = @{
                kind = 'filesystem'; enabled = $true; searchOrder = 150; basePath = $teamDepot
                readable = $true; writable = $true; mirrorTarget = $true; ensureExists = $true
            }
        }
        $definition = New-TestArtifactSetDefinition -Files @(
            @{
                id = 'setup'; relativePath = 'setup.exe'
                contentHash = @{ algorithm = 'sha256'; value = (Get-FileHash $setupSource -Algorithm SHA256).Hash.ToLowerInvariant() }
                acquisitionCandidates = @(
                    @{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } },
                    @{ kind = 'vendorDownload'; url = 'https://example.invalid/setup.exe'; searchOrder = 900; verification = @{ mode = 'required' } }
                )
            },
            @{
                id = 'part001'; relativePath = 'parts/setup.001'
                contentHash = @{ algorithm = 'sha256'; value = (Get-FileHash $partSource -Algorithm SHA256).Hash.ToLowerInvariant() }
                acquisitionCandidates = @(
                    @{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } },
                    @{ kind = 'vendorDownload'; url = 'https://example.invalid/setup.001'; searchOrder = 900; verification = @{ mode = 'required' } }
                )
            }
        )
        Mock Save-PackageDownloadFile {
            param($Uri, $TargetPath)
            Copy-Item -LiteralPath $(if ($Uri -like '*.001') { $partSource } else { $setupSource }) -Destination $TargetPath -Force
            return $TargetPath
        }

        $result = Get-TestArtifactSetResult -RootPath $rootPath -Definition $definition -DepotInventory $depotInventory
        $defaultSetup = $result.ArtifactFiles | Where-Object Id -eq setup | Select-Object -ExpandProperty DefaultDepotPath
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $defaultSetup) -Force
        Copy-Item -LiteralPath $setupSource -Destination $defaultSetup -Force

        $result = Resolve-PackageArtifactFiles -PackageResult $result
        ($result.ArtifactFiles | Where-Object Id -eq setup).Preparation.Status | Should -Be 'HydratedFromDefaultPackageDepot'
        ($result.ArtifactFiles | Where-Object Id -eq part001).Preparation.Status | Should -Be 'SavedArtifactFile'
        $result = Invoke-PackageDepotDistribution -PackageResult $result
        $result.DepotDistribution.FailedCount | Should -Be 0
        $result.DepotDistribution.CopiedCount | Should -Be 3

        $teamPart = Join-Path (Join-Path $teamDepot $result.PackageDepotRelativeDirectory) 'parts\setup.001'
        Test-Path -LiteralPath $teamPart -PathType Leaf | Should -BeTrue
        $result = Invoke-PackageDepotDistribution -PackageResult $result
        $result.DepotDistribution.CopiedCount | Should -Be 0
        $result.DepotDistribution.SkippedCount | Should -Be 4
    }

    It 'reports every missing artifact ID and expected depot path in Offline mode' {
        $rootPath = Join-Path $TestDrive 'offline-missing'
        $definition = New-TestArtifactSetDefinition -Files @(
            @{ id = 'setup'; relativePath = 'setup.exe'; acquisitionCandidates = @(@{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } }) },
            @{ id = 'part001'; relativePath = 'parts/setup.001'; acquisitionCandidates = @(@{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } }) }
        )
        $result = Get-TestArtifactSetResult -RootPath $rootPath -Definition $definition -Offline

        { Resolve-PackageArtifactFiles -PackageResult $result } | Should -Throw '*Required artifact file acquisition failed*'
        $result.ArtifactPreparation.Success | Should -BeFalse
        @($result.ArtifactPreparation.MissingArtifactFiles).Count | Should -Be 2
        @($result.ArtifactPreparation.MissingArtifactFiles.Id) | Should -Contain 'setup'
        @($result.ArtifactPreparation.MissingArtifactFiles.Id) | Should -Contain 'part001'
        @($result.ArtifactPreparation.MissingArtifactFiles.ExpectedDepotPath | Where-Object { $_ -match 'setup\.exe$' }).Count | Should -Be 1
        @($result.ArtifactPreparation.MissingArtifactFiles.ExpectedDepotPath | Where-Object { $_ -match 'parts[\\]setup\.001$' }).Count | Should -Be 1
    }

    It 'extracts and independently verifies declared archive entries' {
        $rootPath = Join-Path $TestDrive 'archive-entry'
        $layoutRoot = Join-Path $rootPath 'layout'
        $bootstrapPath = Join-Path $layoutRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.ps1'
        $bootstrapCommandPath = Join-Path $layoutRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.cmd'
        $moduleRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $bootstrapPath) -Force
        Copy-Item -LiteralPath (Join-Path $moduleRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.ps1') -Destination $bootstrapPath
        Copy-Item -LiteralPath (Join-Path $moduleRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.cmd') -Destination $bootstrapCommandPath
        $archivePath = Join-Path $rootPath 'source\Eigenverft.Manifested.Package.2.0.0.nupkg'
        Write-TestZipFromDirectory -SourceDirectory $layoutRoot -ZipPath $archivePath
        $archiveHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $bootstrapHash = (Get-FileHash $bootstrapPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $bootstrapCommandHash = (Get-FileHash $bootstrapCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $definition = New-TestArtifactSetDefinition -InstallArtifactFileId modulePackage -Files @(
            @{
                id = 'modulePackage'; relativePath = 'Eigenverft.Manifested.Package.2.0.0.nupkg'
                contentHash = @{ algorithm = 'sha256'; value = $archiveHash }
                acquisitionCandidates = @(@{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } })
            },
            @{
                id = 'bootstrapPowerShell'; relativePath = 'Bootstrap/Eigenverft.Manifested.Package.Bootstrap.ps1'
                contentHash = @{ algorithm = 'sha256'; value = $bootstrapHash }
                acquisitionCandidates = @(
                    @{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } },
                    @{
                        kind = 'archiveEntry'; sourceArtifactFileId = 'modulePackage'
                        entryPath = 'Bootstrap/Eigenverft.Manifested.Package.Bootstrap.ps1'
                        searchOrder = 900; verification = @{ mode = 'required' }
                    }
                )
            },
            @{
                id = 'bootstrapCommand'; relativePath = 'Bootstrap/Eigenverft.Manifested.Package.Bootstrap.cmd'
                contentHash = @{ algorithm = 'sha256'; value = $bootstrapCommandHash }
                acquisitionCandidates = @(
                    @{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } },
                    @{
                        kind = 'archiveEntry'; sourceArtifactFileId = 'modulePackage'
                        entryPath = 'Bootstrap/Eigenverft.Manifested.Package.Bootstrap.cmd'
                        searchOrder = 900; verification = @{ mode = 'required' }
                    }
                )
            }
        )
        $result = Get-TestArtifactSetResult -RootPath $rootPath -Definition $definition
        $moduleFile = $result.ArtifactFiles | Where-Object Id -eq modulePackage
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $moduleFile.DefaultDepotPath) -Force
        Copy-Item -LiteralPath $archivePath -Destination $moduleFile.DefaultDepotPath -Force

        $result = Invoke-Package -PublisherId Eigenverft -DefinitionId ArtifactSet -MaterializeOnly

        $result.Status | Should -Be 'Materialized' -Because ([string]$result.ErrorMessage)
        $result.Materialization.Status | Should -Be 'Durable'
        ($result.ArtifactFiles | Where-Object Id -eq bootstrapPowerShell).Preparation.Status | Should -Be 'ExtractedArchiveEntry'
        ($result.ArtifactFiles | Where-Object Id -eq bootstrapPowerShell).Verification.Status | Should -Be 'VerificationPassed'
        Get-Content -LiteralPath ($result.ArtifactFiles | Where-Object Id -eq bootstrapPowerShell).DefaultDepotPath -Raw | Should -Match 'function Invoke-BootstrapInstallerHelper'
        ($result.ArtifactFiles | Where-Object Id -eq bootstrapCommand).Preparation.Status | Should -Be 'ExtractedArchiveEntry'
        Get-Content -LiteralPath ($result.ArtifactFiles | Where-Object Id -eq bootstrapCommand).DefaultDepotPath -Raw | Should -Match 'powershell\.exe.+Eigenverft\.Manifested\.Package\.Bootstrap\.ps1'

        @($result.ArtifactFiles | Where-Object { -not (Test-Path -LiteralPath $_.DefaultDepotPath -PathType Leaf) }).Count | Should -Be 0

        $offlineResult = Invoke-Package -PublisherId Eigenverft -DefinitionId ArtifactSet -MaterializeOnly -Offline

        $offlineResult.Status | Should -Be 'Materialized'
        $offlineResult.ArtifactPreparation.Success | Should -BeTrue
        ($offlineResult.ArtifactFiles | Where-Object Id -eq bootstrapPowerShell).Preparation.Status | Should -Be 'HydratedFromDefaultPackageDepot'
        ($offlineResult.ArtifactFiles | Where-Object Id -eq bootstrapCommand).Preparation.Status | Should -Be 'HydratedFromDefaultPackageDepot'
    }

    It 'skips distribution when no static artifact files are declared' {
        $result = [pscustomobject]@{
            ArtifactFiles = @(); ArtifactPreparation = [pscustomobject]@{ Success = $true }; DepotDistribution = $null
            PackageConfig = [pscustomobject]@{ DepotDistributionMode = 'packageFocused'; EnvironmentSources = [pscustomobject]@{} }
        }

        $result = Invoke-PackageDepotDistribution -PackageResult $result
        $result.DepotDistribution.Status | Should -Be 'Skipped'
        $result.DepotDistribution.Reason | Should -Be 'NoArtifactFiles'
    }
}
