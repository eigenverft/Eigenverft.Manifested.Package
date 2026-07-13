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
        $result.Package.version | Should -Be '9934'
        $result.Package.releaseTag | Should -Be 'b9934'
        $result.Package.packageFile.fileName | Should -Be 'llama-b9934-bin-win-cpu-x64.zip'
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
            'MinGit-2.55.0.2-arm64.zip'
        }
        else {
            'MinGit-2.55.0.2-64-bit.zip'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '0b2b81fdce284efd174cbb51b886ccea2fd271679c4b5c21f07d9e03bae51413'
        }
        else {
            'e3ea2944cea4b3fabcd69c7c1669ef69b1b66c05ac7806d81224d0abad2dec31'
        }

        $config.DefinitionId | Should -Be 'GitRuntime'
        $sourceDefinition.Kind | Should -Be 'githubRelease'
        $sourceDefinition.GitHubOwner | Should -Be 'git-for-windows'
        $sourceDefinition.GitHubRepository | Should -Be 'git'
        $result.Package.version | Should -Be '2.55.0'
        $result.Package.releaseTag | Should -Be 'v2.55.0.windows.2'
        $result.Package.packageFile.fileName | Should -Be $expectedFileName
        $result.Package.packageFile.contentHash.value | Should -Be $expectedSha256
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        $config.Definition.discovery.presence.commands[0].name | Should -Be 'git'
    }

    It 'loads the shipped GHCli definition and selects the fixed GitHub-backed release' {

        $config = Get-PackageConfig -DefinitionId 'GHCli'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'gitHubCliGitHub' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'gh_2.96.0_windows_arm64.zip'
        }
        else {
            'gh_2.96.0_windows_amd64.zip'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'c517e0b32c98a4ba90ac95af8d12cc3ac55781ab4ab72f9a91ce3de0541d2b09'
        }
        else {
            'c2d6acc935cd2f00e2144d7e036d5cd82e6b6bd5594e8c75aa75ef2a4ed6aac3'
        }

        $config.DefinitionId | Should -Be 'GHCli'
        $sourceDefinition.Kind | Should -Be 'githubRelease'
        $sourceDefinition.GitHubOwner | Should -Be 'cli'
        $sourceDefinition.GitHubRepository | Should -Be 'cli'
        $result.Package.version | Should -Be '2.96.0'
        $result.Package.releaseTag | Should -Be 'v2.96.0'
        $result.Package.packageFile.fileName | Should -Be $expectedFileName
        $result.Package.packageFile.contentHash.value | Should -Be $expectedSha256
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
            'npp.8.9.6.4.Installer.arm64.exe'
        }
        else {
            'npp.8.9.6.4.Installer.x64.exe'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'c318d51a5777bf3488ca10198f338d3bd92cb5768f49b5350a774c7767035aca'
        }
        else {
            'cb902f8a9628324dbe5233b5202e716ea469720c9a1ac968007df2288e4ed2ea'
        }

        $config.DefinitionId | Should -Be 'NotepadPlusPlus'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/'
        $result.Package.version | Should -Be '8.9.6.4'
        $result.Package.assigned.install.kind | Should -Be 'nsisInstaller'
        $result.Package.assigned.install.targetDirectoryArgument.prefix | Should -Be '/D='
        $result.Package.discovery.existingInstall.searchLocations[0].kind | Should -Be 'windowsUninstallRegistryKey'
        $result.Package.discovery.existingInstall.searchLocations[0].installDirectorySource | Should -Be 'displayIconDirectory'
        $result.Package.packageFile.fileName | Should -Be $expectedFileName
        $result.Package.packageFile.contentHash.value | Should -Be $expectedSha256
    }

    It 'loads the shipped VSCodeUser definition with Inno Setup uninstall registry removal' {

        $config = Get-PackageConfig -DefinitionId 'VSCodeUser'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result

        $config.DefinitionId | Should -Be 'VSCodeUser'
        $config.SchemaVersion | Should -Be '1.9'
        @($result.Package.acquisitionCandidates | ForEach-Object { $_.kind }) | Should -Be @('packageDepot', 'vendorDownload')
        $result.Package.assigned.install.kind | Should -Be 'innoSetupInstaller'
        $result.Package.removed.operation.kind | Should -Be 'innoSetupUninstaller'
        $result.Package.discovery.existingInstall.enabled | Should -Be $true
        $result.Package.discovery.existingInstall.searchLocations[0].kind | Should -Be 'windowsUninstallRegistryKey'
        @($result.Package.discovery.existingInstall.searchLocations[0].paths)[0] | Should -Match '^HKCU:'
        $result.Package.discovery.existingInstall.searchLocations[0].installDirectorySource | Should -Be 'installLocation'
        $result.Package.removed.policy.allowedInventoryOwnershipKinds | Should -Contain 'AdoptedExternal'
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
        $result.Package.packageFile.fileName | Should -Be '7z2602-x64.msi'
        $result.Package.packageFile.contentHash.algorithm | Should -Be 'sha256'
        $result.Package.packageFile.contentHash.value | Should -Be 'db407a4f6d4999e5c7bc00ce8a882be94717b56e7fa68140fe3f12605d91643e'
        $result.Package.assigned.install.kind | Should -Be 'msiInstaller'
        $result.Package.assigned.install.targetDirectoryProperty.name | Should -Be 'INSTALLDIR'
        $result.Package.removed.operation.kind | Should -Be 'msiUninstaller'
        $result.Package.discovery.existingInstall.searchLocations[0].kind | Should -Be 'windowsUninstallRegistrySearch'
        $result.Package.discovery.existingInstall.searchLocations[0].displayNamePatterns | Should -Contain '7-Zip* (x64)*'
        $result.Package.removed.policy.allowedInventoryOwnershipKinds | Should -Contain 'AdoptedExternal'
        $result.AcquisitionPlan.PackageFileRequired | Should -BeTrue
        @($result.AcquisitionPlan.Candidates | ForEach-Object { $_.kind }) | Should -Be @('packageDepot', 'vendorDownload')
    }

    It 'loads the shipped NodeRuntime definition and selects the fixed Node.js archive release' {

        $config = Get-PackageConfig -DefinitionId 'NodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'nodeJsRelease' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'node-v26.5.0-win-arm64.zip'
        }
        else {
            'node-v26.5.0-win-x64.zip'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'c0cfa5877b6de743301e622f5abc4d26fb0ff8798adffc8fffd2885f426008ba'
        }
        else {
            'd3b2277dbcccfdf24ef6302928f64f484cff1d77a6d3caa3a28f4d20ce9158f6'
        }

        $config.DefinitionId | Should -Be 'NodeRuntime'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://nodejs.org/dist/'
        $result.Package.version | Should -Be '26.5.0'
        $result.Package.releaseTag | Should -Be 'v26.5.0'
        $result.Package.packageFile.fileName | Should -Be $expectedFileName
        $result.Package.packageFile.contentHash.value | Should -Be $expectedSha256
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
            'dotnet-sdk-10.0.301-win-arm64.zip'
        }
        else {
            'dotnet-sdk-10.0.301-win-x64.zip'
        }
        $expectedSha512 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'cd2aabcf089d76c6f904e2b77ed06b9f397e105f8a9b8fb425ce6b8ab01413a01d59a1c298c58c627db3e8d197280825d7c2cfc8b8345a149ed5b86457cf5c5b'
        }
        else {
            '38456e992c4df0ff0ac9fc5f28ff09a88543c0fc4e4deedffda9c4ebaf852c4519addacf28814ea77ea42ce2d37db812fae5ba1fe25f06364ca5a6027036387f'
        }

        $config.DefinitionId | Should -Be 'DotNetSdk10'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://builds.dotnet.microsoft.com/dotnet/'
        $result.Package.version | Should -Be '10.0.301'
        $result.Package.releaseTag | Should -Be '10.0.9'
        $result.Package.packageFile.fileName | Should -Be $expectedFileName
        $result.Package.packageFile.contentHash.algorithm | Should -Be 'sha512'
        $result.Package.packageFile.contentHash.value | Should -Be $expectedSha512
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
            'agent-cli-package-2026.07.08-0c04a8a-win32-arm64.zip'
        }
        else {
            'agent-cli-package-2026.07.08-0c04a8a-win32-x64.zip'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '9a9c5dced83765c8579b27e01419c2b1fe09857bd715267cf03bd55d16d53aa4'
        }
        else {
            '9379c6f6fcac1d863c9fd578602a1b3e6d99634c599e74bf101003371ff59c10'
        }

        $config.DefinitionId | Should -Be 'CursorCli'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://downloads.cursor.com/lab/'
        $result.Package.version | Should -Be '2026.07.08-0c04a8a'
        $result.Package.assigned.install.kind | Should -Be 'expandArchive'
        $result.Package.assigned.install.expandedRoot | Should -Be 'dist-package'
        $result.Package.packageFile.fileName | Should -Be $expectedFileName
        $result.Package.packageFile.contentHash.value | Should -Be $expectedSha256
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        $config.Definition.discovery.presence.commands[0].name | Should -Be 'agent'
        $config.Definition.discovery.presence.commands[0].relativePath | Should -Be 'cursor-agent.cmd'
    }

    It 'loads the shipped materialized npm definitions without authored package-file acquisition' {

        $cases = @(
            [pscustomobject]@{ DefinitionId = 'CodexCli'; PackageSpec = '@openai/codex@{version}'; Version = '0.143.0'; Command = 'codex'; RelativePath = 'codex.cmd'; Dependencies = @('VisualCppRedistributable', 'NodeRuntime') }
            [pscustomobject]@{ DefinitionId = 'OpenCodeCli'; PackageSpec = 'opencode-ai@{version}'; Version = '1.17.15'; Command = 'opencode'; RelativePath = 'opencode.cmd'; Dependencies = @('NodeRuntime') }
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
            $result.Package.packageFile | Should -BeNullOrEmpty
            $result.Package.assigned.install.PSObject.Properties.Name | Should -Not -Contain 'additionalTarballs'
            $result.AcquisitionPlan.PackageFileRequired | Should -BeFalse
            @($result.AcquisitionPlan.Candidates).Count | Should -Be 0
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
        $latest.Package.version | Should -Be '1.17.15'

        $explicitLatest = New-PackageResult -PackageConfig $config -PackageVersionSelector 'latestByVersion'
        $explicitLatest = Resolve-PackagePackage -PackageResult $explicitLatest
        $explicitLatest.PackageVersionSelectionSource | Should -Be 'command'
        $explicitLatest.PackageVersionSelector | Should -Be 'latestByVersion'
        $explicitLatest.Package.version | Should -Be '1.17.15'

        $previous = New-PackageResult -PackageConfig $config -PackageVersionSelector 'previousByVersion'
        $previous = Resolve-PackagePackage -PackageResult $previous
        $previous.PackageVersionSelectionSource | Should -Be 'command'
        $previous.PackageVersionSelector | Should -Be 'previousByVersion'
        $previous.Package.version | Should -Be '1.17.9'

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
        $result.Package.version | Should -Be '2.54.0'
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
            $result.Package.packageFile.fileName | Should -Be ('{0}.{1}.nupkg' -f $case.ModuleName, $case.Version)
            $result.Package.packageFile.contentHash.value | Should -Be $case.Hash
            $result.InstallDirectory | Should -BeNullOrEmpty
            $result.AcquisitionPlan.PackageFileRequired | Should -BeTrue
            @($result.AcquisitionPlan.Candidates | ForEach-Object { $_.kind }) | Should -Be @('packageDepot', 'vendorDownload')
        }
    }

}
