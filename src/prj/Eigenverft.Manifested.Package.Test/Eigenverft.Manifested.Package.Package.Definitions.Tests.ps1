<#
    Eigenverft.Manifested.Package Package - shipped definitions
#>

. "$PSScriptRoot\\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - shipped definitions' -Body {

    It 'fails clearly when global config still uses retired ownershipTracking' {
        $globalConfigPath = Join-Path $TestDrive 'Global-old-ownership.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.ownershipTracking = @{
            indexFilePath = Join-Path $TestDrive 'ownership-index.json'
        }
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*ownershipTracking*'
    }

    It 'fails clearly when global config still uses retired artifactIndexFilePath' {
        $globalConfigPath = Join-Path $TestDrive 'Global-old-artifact.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.acquisitionEnvironment.tracking = @{}
        $badGlobal.package.acquisitionEnvironment.tracking.artifactIndexFilePath = Join-Path $TestDrive 'artifact-index.json'
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*artifactIndexFilePath*'
    }

    It 'fails clearly when global config still uses retired packageFileIndexFilePath' {
        $globalConfigPath = Join-Path $TestDrive 'Global-old-package-file-index.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.acquisitionEnvironment.tracking = @{
            packageFileIndexFilePath = Join-Path $TestDrive 'package-file-index.json'
        }
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*packageFileIndexFilePath*'
    }

    It 'fails clearly when global config still uses retired installWorkspaceDirectory' {
        $globalConfigPath = Join-Path $TestDrive 'Global-old-install-workspace.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.acquisitionEnvironment.stores.Remove('packageFileStagingDirectory')
        $badGlobal.package.acquisitionEnvironment.stores.installWorkspaceDirectory = Join-Path $TestDrive 'InstallWorkspace'
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*installWorkspaceDirectory*'
    }

    It 'fails clearly when global config still uses retired installPreparationDirectory' {
        $globalConfigPath = Join-Path $TestDrive 'Global-old-install-preparation.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.acquisitionEnvironment.stores.Remove('packageFileStagingDirectory')
        $badGlobal.package.acquisitionEnvironment.stores.Remove('packageInstallStageDirectory')
        $badGlobal.package.acquisitionEnvironment.stores.installPreparationDirectory = Join-Path $TestDrive 'InstallPreparation'
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*installPreparationDirectory*'
    }

    It 'fails clearly when global config still uses retired mirrorDownloadedArtifactsToDefaultPackageDepot' {
        $globalConfigPath = Join-Path $TestDrive 'Global-old-mirror-default.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.acquisitionEnvironment.defaults.mirrorDownloadedArtifactsToDefaultPackageDepot = $true
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*mirrorDownloadedArtifactsToDefaultPackageDepot*'
    }

    It 'rejects unsupported depot distribution modes' {
        $globalConfigPath = Join-Path $TestDrive 'Global-invalid-depot-distribution-mode.json'
        $badGlobal = New-TestPackageGlobalDocument
        $badGlobal.package.acquisitionEnvironment.defaults.depotDistributionMode = 'surpriseMe'
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*depotDistributionMode*'
    }

    It 'rejects filesystem depot inventory entries without explicit capability fields' {
        $depotInventoryPath = Join-Path $TestDrive 'DepotInventory-missing-capability.json'
        $badDepotInventory = New-TestDepotInventoryDocument
        $badDepotInventory.acquisitionEnvironment.environmentSources.defaultPackageDepot.Remove('readable')
        Write-TestJsonDocument -Path $depotInventoryPath -Document $badDepotInventory

        $depotInfo = Read-PackageJsonDocument -Path $depotInventoryPath
        { Assert-PackageDepotInventorySchema -DepotInventoryDocumentInfo $depotInfo } | Should -Throw '*readable*'
    }

    It 'rejects depot inventory mirror and ensure flags when a filesystem depot is not writable' {
        $depotInventoryPath = Join-Path $TestDrive 'DepotInventory-invalid-capabilities.json'
        $badDepotInventory = New-TestDepotInventoryDocument
        $badDepotInventory.acquisitionEnvironment.environmentSources.defaultPackageDepot.writable = $false
        $badDepotInventory.acquisitionEnvironment.environmentSources.defaultPackageDepot.mirrorTarget = $true
        $badDepotInventory.acquisitionEnvironment.environmentSources.defaultPackageDepot.ensureExists = $true
        Write-TestJsonDocument -Path $depotInventoryPath -Document $badDepotInventory

        $depotInfo = Read-PackageJsonDocument -Path $depotInventoryPath
        { Assert-PackageDepotInventorySchema -DepotInventoryDocumentInfo $depotInfo } | Should -Throw '*mirrorTarget=true*'

        $badDepotInventory.acquisitionEnvironment.environmentSources.defaultPackageDepot.mirrorTarget = $false
        Write-TestJsonDocument -Path $depotInventoryPath -Document $badDepotInventory
        $depotInfo = Read-PackageJsonDocument -Path $depotInventoryPath
        { Assert-PackageDepotInventorySchema -DepotInventoryDocumentInfo $depotInfo } | Should -Throw '*ensureExists=true*'
    }

    It 'loads the shipped LlamaCppRuntime definition and selects the fixed GitHub-backed release' {

        $config = Get-PackageConfig -DefinitionId 'LlamaCppRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'llamaCppGitHub' })

        $config.DefinitionId | Should -Be 'LlamaCppRuntime'
        @($config.Definition.dependency.requires.definitionId) | Should -Be @('VisualCppRedistributable')
        @($config.Definition.dependency.requires.publisherId) | Should -Be @($null)
        $sourceDefinition.Kind | Should -Be 'githubRelease'
        $sourceDefinition.GitHubOwner | Should -Be 'ggml-org'
        $sourceDefinition.GitHubRepository | Should -Be 'llama.cpp'
        $result.PackageId | Should -Be 'llama-cpp-win-cpu-x64-stable'
        $result.Package.version | Should -Be '10470'
        $result.Package.releaseTag | Should -Be 'b10470'
        $result.Package.artifactFiles[0].relativePath | Should -Be 'llama-b10470-bin-win-cpu-x64.zip'
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        @($config.Definition.discovery.presence.commands.name) | Should -Be @('llama-cli', 'llama-server', 'llama-quantize', 'llama-bench', 'llama-tokenize')
    }

    It 'loads the shipped GitRuntime definition and selects the fixed GitHub-backed release' {

        $config = Get-PackageConfig -DefinitionId 'GitRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'gitForWindowsGitHub' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'MinGit-2.55.0.4-arm64.zip'
        }
        else {
            'MinGit-2.55.0.4-64-bit.zip'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '033eb6b927d804558ae479a6ae6c6ed86da42cabc0d424844a3e108c780a58cc'
        }
        else {
            '4e03f94c2ffbf70be337e005cee02661c732dbfc81031a078bda9299b9a7d644'
        }

        $config.DefinitionId | Should -Be 'GitRuntime'
        $sourceDefinition.Kind | Should -Be 'githubRelease'
        $sourceDefinition.GitHubOwner | Should -Be 'git-for-windows'
        $sourceDefinition.GitHubRepository | Should -Be 'git'
        $result.Package.version | Should -Be '2.55.0.4'
        $result.Package.reportedVersion | Should -Be '2.55.0.windows.4'
        $result.Package.releaseTag | Should -Be 'v2.55.0.windows.4'
        $result.Package.artifactFiles[0].relativePath | Should -Be $expectedFileName
        $result.Package.artifactFiles[0].contentHash.value | Should -Be $expectedSha256
        $result.Package.readiness.commandChecks[0].expectedValue | Should -Be '{reportedVersion}'
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        $config.Definition.discovery.presence.commands[0].name | Should -Be 'git'
        $config.Definition.discovery.presence.commands[0].stateChecks[0].outputPattern | Should -Match '\\.windows\\.'
    }

    It 'loads the shipped GHCli definition and selects the fixed GitHub-backed release' {

        $config = Get-PackageConfig -DefinitionId 'GHCli'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'gitHubCliGitHub' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'gh_2.97.0_windows_arm64.zip'
        }
        else {
            'gh_2.97.0_windows_amd64.zip'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '3e2d4a166da4ee5020c592737b65eec0e724946d5d5b962f5fe59d99116dc4bf'
        }
        else {
            '35d7fe05c4dd1411ffda1e73dfc7c6f44b75c936ca51fa6595c657fdc0350cec'
        }

        $config.DefinitionId | Should -Be 'GHCli'
        $sourceDefinition.Kind | Should -Be 'githubRelease'
        $sourceDefinition.GitHubOwner | Should -Be 'cli'
        $sourceDefinition.GitHubRepository | Should -Be 'cli'
        $result.Package.version | Should -Be '2.97.0'
        $result.Package.releaseTag | Should -Be 'v2.97.0'
        $result.Package.artifactFiles[0].relativePath | Should -Be $expectedFileName
        $result.Package.artifactFiles[0].contentHash.value | Should -Be $expectedSha256
        $result.Package.assigned.install.kind | Should -Be 'expandArchive'
        $result.Package.assigned.install.expandedRoot | Should -Be 'auto'
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        $config.Definition.discovery.presence.commands[0].name | Should -Be 'gh'
        $config.Definition.discovery.presence.commands[0].relativePath | Should -Be 'bin/gh.exe'
    }

    It 'loads the shipped NotepadPlusPlus definition and selects the fixed NSIS installer release' {

        $config = Get-PackageConfig -DefinitionId 'NotepadPlusPlus'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'notepadPlusPlusGitHubRelease' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'npp.8.9.7.Installer.arm64.exe'
        }
        else {
            'npp.8.9.7.Installer.x64.exe'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '4bb261857e22505c36e1196b4f6326df41b4c0fffc527dc9933fe0b210f7cb02'
        }
        else {
            '1884e093bae261c4942210334e1f2eae71354913e4ded3cc1a4a18c5320741ec'
        }

        $config.DefinitionId | Should -Be 'NotepadPlusPlus'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/'
        $result.Package.version | Should -Be '8.9.7'
        $result.Package.assigned.install.kind | Should -Be 'nsisInstaller'
        $result.Package.assigned.install.targetDirectoryArgument.prefix | Should -Be '/D='
        $result.Package.discovery.existingInstall.searchLocations[0].kind | Should -Be 'windowsUninstallRegistryKey'
        $result.Package.discovery.existingInstall.searchLocations[0].installDirectorySource | Should -Be 'displayIconDirectory'
        $result.Package.artifactFiles[0].relativePath | Should -Be $expectedFileName
        $result.Package.artifactFiles[0].contentHash.value | Should -Be $expectedSha256
    }

    It 'loads the shipped VSCodeUser definition with Inno Setup uninstall registry removal' {

        $config = Get-PackageConfig -DefinitionId 'VSCodeUser'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result

        $config.DefinitionId | Should -Be 'VSCodeUser'
        $config.SchemaVersion | Should -Be '2.0'
        @($result.Package.artifactFiles[0].acquisitionCandidates | ForEach-Object { $_.kind }) | Should -Be @('packageDepot', 'vendorDownload')
        $result.Package.assigned.install.kind | Should -Be 'innoSetupInstaller'
        $result.Package.removed.operation.kind | Should -Be 'innoSetupUninstaller'
        $result.Package.discovery.existingInstall.enabled | Should -Be $true
        $result.Package.discovery.existingInstall.searchLocations[0].kind | Should -Be 'windowsUninstallRegistryKey'
        @($result.Package.discovery.existingInstall.searchLocations[0].paths)[0] | Should -Match '^HKCU:'
        $result.Package.discovery.existingInstall.searchLocations[0].installDirectorySource | Should -Be 'installLocation'
        $result.Package.removed.policy.allowedInventoryOwnershipKinds | Should -Contain 'AdoptedExternal'
    }

    It 'loads the shipped ImageMagick definition with Inno Setup install, shim PATH, and registry uninstall search' {

        $config = Get-PackageConfig -DefinitionId 'ImageMagick'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'imageMagickGitHubRelease' })

        $config.DefinitionId | Should -Be 'ImageMagick'
        $config.SchemaVersion | Should -Be '2.0'
        $config.DepotNamespace | Should -Be 'evf'
        $sourceDefinition.Kind | Should -Be 'githubRelease'
        $sourceDefinition.GitHubOwner | Should -Be 'ImageMagick'
        $sourceDefinition.GitHubRepository | Should -Be 'ImageMagick'
        $result.Package.version | Should -Be '7.1.2.29'
        $result.Package.reportedVersion | Should -Be '7.1.2-29'
        $result.Package.artifactFiles[0].relativePath | Should -Be 'ImageMagick-7.1.2-29-Q16-HDRI-x64-dll.exe'
        $result.Package.artifactFiles[0].contentHash.algorithm | Should -Be 'sha256'
        $result.Package.artifactFiles[0].contentHash.value | Should -Be '94c025d0f572b1f7db03c380002485b49069c6d02796f462ffd7052874ba7467'
        $result.Package.artifactFiles[0].publisherSignature.kind | Should -Be 'authenticode'
        $result.Package.artifactFiles[0].publisherSignature.subjectContains | Should -Be 'ImageMagick Studio LLC'
        @($result.Package.artifactFiles[0].acquisitionCandidates | ForEach-Object { $_.kind }) | Should -Be @('packageDepot', 'vendorDownload')
        $result.Package.assigned.install.kind | Should -Be 'innoSetupInstaller'
        $result.Package.assigned.install.elevation | Should -Be 'required'
        $result.Package.assigned.install.commandArguments | Should -Contain '/MERGETASKS=!modifypath'
        $result.Package.assigned.install.targetDirectoryArgument.prefix | Should -Be '/DIR='
        $result.Package.assigned.pathRegistration.mode | Should -Be 'user'
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        $result.Package.discovery.presence.commands[0].name | Should -Be 'magick'
        $result.Package.discovery.presence.commands[0].relativePath | Should -Be 'magick.exe'
        $result.Package.discovery.existingInstall.searchLocations[0].kind | Should -Be 'windowsUninstallRegistrySearch'
        $result.Package.discovery.existingInstall.searchLocations[0].installDirectorySource | Should -Be 'installLocation'
        $result.Package.removed.operation.kind | Should -Be 'innoSetupUninstaller'
        $result.Package.removed.policy.allowedInventoryOwnershipKinds | Should -Contain 'PackageInstalled'
        $result.Package.removed.policy.allowedInventoryOwnershipKinds | Should -Not -Contain 'AdoptedExternal'
    }

    It 'loads the shipped SevenZip definition with MSI install and uninstall registry search' {

        $config = Get-PackageConfig -DefinitionId 'SevenZip'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'sevenZipGitHubRelease' })

        $config.DefinitionId | Should -Be 'SevenZip'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://github.com/ip7z/7zip/releases/download/'
        $result.Package.version | Should -Be '26.02'
        $result.Package.releaseTag | Should -Be '2602'
        $result.Package.artifactFiles[0].relativePath | Should -Be '7z2602-x64.msi'
        $result.Package.artifactFiles[0].contentHash.algorithm | Should -Be 'sha256'
        $result.Package.artifactFiles[0].contentHash.value | Should -Be 'db407a4f6d4999e5c7bc00ce8a882be94717b56e7fa68140fe3f12605d91643e'
        $result.Package.assigned.install.kind | Should -Be 'msiInstaller'
        $result.Package.assigned.install.targetDirectoryProperty.name | Should -Be 'INSTALLDIR'
        $result.Package.removed.operation.kind | Should -Be 'msiUninstaller'
        $result.Package.discovery.existingInstall.searchLocations[0].kind | Should -Be 'windowsUninstallRegistrySearch'
        $result.Package.discovery.existingInstall.searchLocations[0].displayNamePatterns | Should -Contain '7-Zip* (x64)*'
        $result.Package.removed.policy.allowedInventoryOwnershipKinds | Should -Contain 'AdoptedExternal'
        $result.ArtifactAcquisitionPlan.ArtifactFilesRequired | Should -BeTrue
        @($result.ArtifactFiles[0].AcquisitionPlan.Candidates | ForEach-Object { $_.kind }) | Should -Be @('packageDepot', 'vendorDownload')
    }

    It 'loads the shipped NodeRuntime definition and selects the fixed Node.js archive release' {

        $config = Get-PackageConfig -DefinitionId 'NodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'nodeJsRelease' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'node-v26.7.0-win-arm64.zip'
        }
        else {
            'node-v26.7.0-win-x64.zip'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'be8775204cfceca5a73c30f91bf0de5e85274c01b776dc13f16b91aa251ebb01'
        }
        else {
            'd3bd72755141ed32bbcd841228ee81897c8a98d50dfa7dae2179399a0a7c90f8'
        }

        $config.DefinitionId | Should -Be 'NodeRuntime'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://nodejs.org/dist/'
        $result.Package.version | Should -Be '26.7.0'
        $result.Package.releaseTag | Should -Be 'v26.7.0'
        $result.Package.artifactFiles[0].relativePath | Should -Be $expectedFileName
        $result.Package.artifactFiles[0].contentHash.value | Should -Be $expectedSha256
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        @($config.Definition.discovery.presence.commands.name) | Should -Be @('node', 'npm', 'npx')
    }

    It 'loads the shipped DotNetSdk10 definition and selects the fixed Microsoft archive release' {

        $config = Get-PackageConfig -DefinitionId 'DotNetSdk10'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'dotNetBuilds' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'dotnet-sdk-10.0.400-win-arm64.zip'
        }
        else {
            'dotnet-sdk-10.0.400-win-x64.zip'
        }
        $expectedSha512 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '9d4ecd7439f15c7797d6f46d368cb7aa6513755c5fc3d6de7621bc4878a1805f6b8ffb60ffb9d3e72a049cca87edb252f7c8c03023b643e333544c4606509d7f'
        }
        else {
            '9b8b88590e4da131bfd0da7aa089d0fc04d5418d5f8607ec13d55dc5a17b4399afd54d496c12657fa05c6c6546dc5eab930f26ac6c50f2d3a7712c0fb378c366'
        }

        $config.DefinitionId | Should -Be 'DotNetSdk10'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://builds.dotnet.microsoft.com/dotnet/'
        $result.Package.version | Should -Be '10.0.400'
        $result.Package.releaseTag | Should -Be '10.0.11'
        $result.Package.artifactFiles[0].relativePath | Should -Be $expectedFileName
        $result.Package.artifactFiles[0].contentHash.algorithm | Should -Be 'sha512'
        $result.Package.artifactFiles[0].contentHash.value | Should -Be $expectedSha512
        $result.Package.assigned.install.kind | Should -Be 'expandArchive'
        $result.Package.assigned.install.installDirectory | Should -Be 'dotnet-sdk10/{releaseTrack}/{version}/{artifactDistributionVariant}'
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        @($config.Definition.discovery.presence.commands.name) | Should -Be @('dotnet')
    }

    It 'loads the shipped CursorCli definition and selects the fixed Cursor lab archive release' {

        $config = Get-PackageConfig -DefinitionId 'CursorCli'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'cursorAgentCliLab' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'agent-cli-package-2026.08.11-e8db854-win32-arm64.zip'
        }
        else {
            'agent-cli-package-2026.08.11-e8db854-win32-x64.zip'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '67a0228a76fc631e132004007d384f95f32f2c77c7cf9cfaeadd53ae868efbe0'
        }
        else {
            '0458981ffe0fda840d19b97d7cbcb26832dafcf01a9c229f3fb0e0d233d66c4b'
        }

        $config.DefinitionId | Should -Be 'CursorCli'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://downloads.cursor.com/lab/'
        $result.Package.version | Should -Be '2026.08.11-e8db854'
        $result.Package.assigned.install.kind | Should -Be 'expandArchive'
        $result.Package.assigned.install.expandedRoot | Should -Be 'dist-package'
        $result.Package.artifactFiles[0].relativePath | Should -Be $expectedFileName
        $result.Package.artifactFiles[0].contentHash.value | Should -Be $expectedSha256
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        $config.Definition.discovery.presence.commands[0].name | Should -Be 'agent'
        $config.Definition.discovery.presence.commands[0].relativePath | Should -Be 'cursor-agent.cmd'
    }

    It 'loads the shipped materialized npm definitions without authored package-file acquisition' {

        $cases = @(
            [pscustomobject]@{ DefinitionId = 'CodexCli'; PackageSpec = '@openai/codex@{version}'; Version = '0.147.0'; Command = 'codex'; RelativePath = 'codex.cmd'; Dependencies = @('VisualCppRedistributable', 'NodeRuntime') }
            [pscustomobject]@{ DefinitionId = 'OpenCodeCli'; PackageSpec = 'opencode-ai@{version}'; Version = '1.18.18'; Command = 'opencode'; RelativePath = 'opencode.cmd'; Dependencies = @('NodeRuntime') }
        )

        foreach ($case in $cases) {
            $config = Get-PackageConfig -DefinitionId $case.DefinitionId
            $result = New-PackageResult -PackageConfig $config
            $result = Resolve-PackagePackage -PackageResult $result
            $result = Resolve-PackagePaths -PackageResult $result
            $result = Build-PackageAcquisitionPlan -PackageResult $result

            $config.DefinitionId | Should -Be $case.DefinitionId
            @($config.Definition.dependency.requires.definitionId) | Should -Be $case.Dependencies
            $result.Package.version | Should -Be $case.Version
            $result.Package.assigned.install.kind | Should -Be 'npmMaterializedInstallGlobalPackage'
            $result.Package.assigned.install.packageSpec | Should -Be $case.PackageSpec
            $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
            $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
            $config.Definition.discovery.presence.commands[0].name | Should -Be $case.Command
            $config.Definition.discovery.presence.commands[0].relativePath | Should -Be $case.RelativePath
            foreach ($dep in @($config.Definition.dependency.requires)) {
                $dep.PSObject.Properties.Name | Should -Not -Contain 'repositoryId'
            }
            @($result.Package.artifactFiles).Count | Should -Be 0
            $result.Package.assigned.install.PSObject.Properties.Name | Should -Not -Contain 'additionalTarballs'
            $result.ArtifactAcquisitionPlan.ArtifactFilesRequired | Should -BeFalse
            @($result.ArtifactAcquisitionPlan.Files).Count | Should -Be 0
        }

        { Get-PackageConfig -DefinitionId 'OpenCodeCliDepot' } | Should -Throw
        { Get-PackageConfig -DefinitionId 'OpenCodePlatformNpmPackage' } | Should -Throw
    }

    It 'selects OpenCode package versions from definition policy and command overrides' {

        $config = Get-PackageConfig -DefinitionId 'OpenCodeCli'

        $latest = New-PackageResult -PackageConfig $config
        $latest = Resolve-PackagePackage -PackageResult $latest
        $latest.PackageVersionSelectionSource | Should -Be 'definition'
        $latest.PackageVersionSelector | Should -Be 'latestByVersion'
        $latest.PackageVersionOrderingKind | Should -Be 'normalVersion'
        $latest.Package.version | Should -Be '1.18.18'

        $explicitLatest = New-PackageResult -PackageConfig $config -PackageVersionSelector 'latestByVersion'
        $explicitLatest = Resolve-PackagePackage -PackageResult $explicitLatest
        $explicitLatest.PackageVersionSelectionSource | Should -Be 'command'
        $explicitLatest.PackageVersionSelector | Should -Be 'latestByVersion'
        $explicitLatest.Package.version | Should -Be '1.18.18'

        $previous = New-PackageResult -PackageConfig $config -PackageVersionSelector 'previousByVersion'
        $previous = Resolve-PackagePackage -PackageResult $previous
        $previous.PackageVersionSelectionSource | Should -Be 'command'
        $previous.PackageVersionSelector | Should -Be 'previousByVersion'
        $previous.Package.version | Should -Be '1.18.15'

        $pinned = New-PackageResult -PackageConfig $config -PackageVersionSelector '1.14.46'
        $pinned = Resolve-PackagePackage -PackageResult $pinned
        $pinned.PackageVersionSelectionSource | Should -Be 'command'
        $pinned.PackageVersionSelector | Should -Be '1.14.46'
        $pinned.RequestedPackageVersion | Should -Be '1.14.46'
        $pinned.Package.version | Should -Be '1.14.46'
        $pinned.Package.assigned.install.packageSpec | Should -Be 'opencode-ai@{version}'

        $missing = New-PackageResult -PackageConfig $config -PackageVersionSelector '0.0.1'
        { Resolve-PackagePackage -PackageResult $missing } | Should -Throw "*Package version '0.0.1' is not authored*"
    }

    It 'selects the previous compatible GitRuntime version for previousByVersion' {

        $config = Get-PackageConfig -DefinitionId 'GitRuntime'
        $result = New-PackageResult -PackageConfig $config -PackageVersionSelector 'previousByVersion'
        $result = Resolve-PackagePackage -PackageResult $result

        $result.PackageVersionSelectionSource | Should -Be 'command'
        $result.PackageVersionSelector | Should -Be 'previousByVersion'
        $result.Package.version | Should -Be '2.55.0.3'
        $result.Package.reportedVersion | Should -Be '2.55.0.windows.3'
        $result.Package.releaseTag | Should -Be 'v2.55.0.windows.3'
        $result.Package.artifactFiles[0].relativePath | Should -Match 'MinGit-2\.55\.0\.3-'
    }

    It 'pins exact GitRuntime MinGit rebuild versions and keeps template paths distinct' {

        $config = Get-PackageConfig -DefinitionId 'GitRuntime'

        $latest = New-PackageResult -PackageConfig $config
        $latest = Resolve-PackagePackage -PackageResult $latest
        $latest = Resolve-PackagePaths -PackageResult $latest
        $latest.Package.version | Should -Be '2.55.0.4'
        $latest.PackageDepotRelativeDirectory | Should -Match '\\2\.55\.0\.4\\'
        Resolve-PackageTemplateText -Text '{reportedVersion}' -PackageConfig $config -Package $latest.Package | Should -Be '2.55.0.windows.4'

        $pin25502 = New-PackageResult -PackageConfig $config -PackageVersionSelector '2.55.0.2'
        $pin25502 = Resolve-PackagePackage -PackageResult $pin25502
        $pin25502 = Resolve-PackagePaths -PackageResult $pin25502
        $pin25502.Package.version | Should -Be '2.55.0.2'
        $pin25502.Package.reportedVersion | Should -Be '2.55.0.windows.2'
        $pin25502.Package.artifactFiles[0].relativePath | Should -Match 'MinGit-2\.55\.0\.2-'
        $pin25502.PackageDepotRelativeDirectory | Should -Match '\\2\.55\.0\.2\\'
        $pin25502.InstallDirectory | Should -Match '\\2\.55\.0\.2\\'

        $pin254 = New-PackageResult -PackageConfig $config -PackageVersionSelector '2.54.0'
        $pin254 = Resolve-PackagePackage -PackageResult $pin254
        $pin254.Package.version | Should -Be '2.54.0'
        $pin254.Package.reportedVersion | Should -Be '2.54.0.windows.1'
        $pin254.Package.artifactFiles[0].relativePath | Should -Match 'MinGit-2\.54\.0-'

        { Resolve-PackagePackage -PackageResult (New-PackageResult -PackageConfig $config -PackageVersionSelector '2.55.0') } | Should -Throw "*Package version '2.55.0' is not authored*"
    }

    It 'defaults reportedVersion to version when the release omits it' {

        $rootPath = Join-Path $TestDrive 'reported-version-default'
        $release = New-TestPackageRelease -Id 'tool-win-x64-stable' -Version '9.8.7' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'tool-9.8.7.zip' -Readiness (New-TestReadiness -Version '9.8.7')
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument (New-TestVSCodeDefinitionDocument -DefinitionId 'ReportedVersionTool' -Releases @($release) -SharedReadiness (New-TestReadiness -Version '9.8.7'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'ReportedVersionTool'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result

        $result.Package.version | Should -Be '9.8.7'
        $result.Package.reportedVersion | Should -Be '9.8.7'
        Resolve-PackageTemplateText -Text '{reportedVersion}' -PackageConfig $config -Package $result.Package | Should -Be '9.8.7'
    }

    It 'accepts the selected GitRuntime reportedVersion and rejects another rebuild string' {

        $config = Get-PackageConfig -DefinitionId 'GitRuntime'
        $result = New-PackageResult -PackageConfig $config -PackageVersionSelector '2.55.0.3'
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result

        $installRoot = $result.InstallDirectory
        $cmdDir = Join-Path $installRoot 'cmd'
        $null = New-Item -ItemType Directory -Path $cmdDir -Force
        Write-TestTextFile -Path (Join-Path $cmdDir 'git.cmd') -Content "@echo off`r`necho git version 2.55.0.windows.3`r`n"
        $result.Package.readiness.commandChecks[0] | Add-Member -MemberType NoteProperty -Name 'relativePath' -Value 'cmd/git.cmd' -Force
        $result.Package.readiness.files = @('cmd/git.cmd')

        $ready = Test-PackageAssignedReadiness -PackageResult $result
        $ready.Readiness.Accepted | Should -BeTrue
        $ready.Readiness.Commands[0].ActualValue | Should -Be '2.55.0.windows.3'
        $ready.Readiness.Commands[0].ExpectedValue | Should -Be '2.55.0.windows.3'

        Write-TestTextFile -Path (Join-Path $cmdDir 'git.cmd') -Content "@echo off`r`necho git version 2.55.0.windows.2`r`n"
        $failed = Test-PackageAssignedReadiness -PackageResult $result
        $failed.Readiness.Accepted | Should -BeFalse
        $failed.Readiness.Commands[0].ActualValue | Should -Be '2.55.0.windows.2'
        $failed.Readiness.Commands[0].ExpectedValue | Should -Be '2.55.0.windows.3'
    }

    It 'loads shipped depot-backed PowerShell module definitions with package-file acquisition' {

        $cases = @(
            [pscustomobject]@{ DefinitionId = 'PackageManagement'; ModuleName = 'PackageManagement'; Version = '1.4.8.1'; Hash = '7e1f8a75b6bc8a83d8abff79f6690fc1dfbd534fd3e5733d97e19bcb5954c13e'; Dependencies = @() }
            [pscustomobject]@{ DefinitionId = 'PowerShellGet'; ModuleName = 'PowerShellGet'; Version = '2.2.5'; Hash = '6b8cebf2a464eaeb31b0a6d627355c30d9d1899dba0ce3bdd0d4e7afca148673'; Dependencies = @('PackageManagement') }
            [pscustomobject]@{ DefinitionId = 'EigenverftManifestedAgent'; ModuleName = 'Eigenverft.Manifested.Agent'; Version = '1.20261.39327'; Hash = 'dd4eacf33d5eb8e6fc0a706fb2e18941b07d9466ae9532e7f94f2c5bcfe1727f'; Dependencies = @('PowerShellGet') }
        )

        foreach ($case in $cases) {
            $config = Get-PackageConfig -DefinitionId $case.DefinitionId
            $result = New-PackageResult -PackageConfig $config
            $result = Resolve-PackagePackage -PackageResult $result
            $result = Resolve-PackagePaths -PackageResult $result
            $result = Build-PackageAcquisitionPlan -PackageResult $result

            $config.DefinitionId | Should -Be $case.DefinitionId
            @($config.Definition.dependency.requires.definitionId) | Should -Be $case.Dependencies
            $result.Package.version | Should -Be $case.Version
            $result.Package.assigned.install.kind | Should -Be 'powershellModuleInstaller'
            $result.Package.assigned.install.moduleName | Should -Be $case.ModuleName
            $result.Package.assigned.install.requiredVersion | Should -Be $case.Version
            $config.Definition.discovery.presence.powerShellModules[0].name | Should -Be $case.ModuleName
            $result.Package.readiness.powerShellModules[0].RequiredVersion | Should -Be $case.Version
            $result.Package.ownershipPolicy.allowAdoptExternal | Should -BeTrue
            $result.Package.ownershipPolicy.requirePackageOwnership | Should -BeFalse
            $result.Package.artifactFiles[0].relativePath | Should -Be ('{0}.{1}.nupkg' -f $case.ModuleName, $case.Version)
            $result.Package.artifactFiles[0].contentHash.value | Should -Be $case.Hash
            $result.InstallDirectory | Should -BeNullOrEmpty
            $result.ArtifactAcquisitionPlan.ArtifactFilesRequired | Should -BeTrue
            @($result.ArtifactFiles[0].AcquisitionPlan.Candidates | ForEach-Object { $_.kind }) | Should -Be @('packageDepot', 'vendorDownload')
        }
    }

}
