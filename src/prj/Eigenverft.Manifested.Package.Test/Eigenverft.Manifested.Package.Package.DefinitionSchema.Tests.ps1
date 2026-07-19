<#
    Eigenverft.Manifested.Package Package - definition schema
#>

. "$PSScriptRoot\\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - definition schema' -Body {

    It 'loads the shipped PythonRuntime definition and selects the fixed NuGet package release' {

        $config = Get-PackageConfig -DefinitionId 'PythonRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'pythonNuGetPackage' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'pythonarm64.3.14.6.nupkg'
        }
        else {
            'python.3.14.6.nupkg'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'b31a716b6e3570c725c1d5f849f8c9427655760a139054d3837ba653fdd80347'
        }
        else {
            '77271b5958f88608884998c27df6f8dd2fa59faf72614bc1e2ffd1d72a3336c3'
        }

        $config.DefinitionId | Should -Be 'PythonRuntime'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://api.nuget.org/v3-flatcontainer/'
        $result.Package.version | Should -Be '3.14.6'
        $result.Package.releaseTag | Should -Be '3.14.6'
        $result.Package.artifactFiles[0].relativePath | Should -Be $expectedFileName
        $result.Package.artifactFiles[0].contentHash.value | Should -Be $expectedSha256
        $result.Package.assigned.install.expandedRoot | Should -Be 'tools'
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        $config.Definition.discovery.presence.commands[0].name | Should -Be 'python'
        $result.Package.readiness.commandChecks[1].arguments | Should -Be @('-m', 'pip', '--version')
    }

    It 'loads the shipped PowerShell7 definition and selects the fixed GitHub-backed release' {

        $config = Get-PackageConfig -DefinitionId 'PowerShell7'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'powerShellGitHub' })

        $expectedFileName = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            'PowerShell-7.6.3-win-arm64.zip'
        }
        else {
            'PowerShell-7.6.3-win-x64.zip'
        }
        $expectedSha256 = if ([string]::Equals([string]$config.Architecture, 'arm64', [System.StringComparison]::OrdinalIgnoreCase)) {
            '2ece90557c370bb5ee03275ef41f2a49e26ea85defcf2052aca32c20dadb62c2'
        }
        else {
            '07ddb0d00b660459560ef82a9841da7705b27cd5dcca5a0d7b025a98eca29eca'
        }

        $config.DefinitionId | Should -Be 'PowerShell7'
        $sourceDefinition.Kind | Should -Be 'githubRelease'
        $sourceDefinition.GitHubOwner | Should -Be 'PowerShell'
        $sourceDefinition.GitHubRepository | Should -Be 'PowerShell'
        $result.Package.version | Should -Be '7.6.3'
        $result.Package.releaseTag | Should -Be 'v7.6.3'
        $result.Package.artifactFiles[0].relativePath | Should -Be $expectedFileName
        $result.Package.artifactFiles[0].contentHash.value | Should -Be $expectedSha256
        $result.Package.assigned.pathRegistration.source.kind | Should -Be 'shim'
        $result.Package.assigned.pathRegistration.source.use | Should -Be 'discovery.presence.commands'
        $config.Definition.discovery.presence.commands[0].name | Should -Be 'pwsh'
    }

    It 'loads the shipped VisualCppRedistributable definition as an elevated machine prerequisite' {

        $config = Get-PackageConfig -DefinitionId 'VisualCppRedistributable'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'visualCppRedistributableDownload' })

        $config.DefinitionId | Should -Be 'VisualCppRedistributable'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://aka.ms/'
        $result.PackageId | Should -Be 'vc-runtime-x64-stable'
        $result.Package.assigned.install.kind | Should -Be 'runInstaller'
        $result.Package.assigned.install.targetKind | Should -Be 'machinePrerequisite'
        $result.Package.assigned.install.elevation | Should -Be 'required'
        $result.Package.assigned.install.commandArguments | Should -Be @('/install', '/quiet', '/norestart', '/log', '{logPath}')
        $result.Package.artifactFiles[0].relativePath | Should -Be 'vc_redist.x64.exe'
        $result.Package.artifactFiles[0].publisherSignature.subjectContains | Should -Be 'Microsoft Corporation'
    }

    It 'loads the shipped Qwen35_9B_Q6_K_Model definition and selects the fixed Hugging Face-backed resource release' {
        Mock Get-PhysicalMemoryGiB { 8.0 }
        Mock Get-VideoMemoryGiB { 2.0 }

        $config = Get-PackageConfig -DefinitionId 'Qwen35_9B_Q6_K_Model'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'huggingFaceDownload' })

        $config.DefinitionId | Should -Be 'Qwen35_9B_Q6_K_Model'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/'
        $result.PackageId | Should -Be 'qwen35-9b-q6-k-stable'
        $result.Package.version | Should -Be '3.5.0'
        $result.Package.artifactFiles[0].relativePath | Should -Be 'Qwen3.5-9B-Q6_K.gguf'
        $result.Package.artifactFiles[0].contentHash.algorithm | Should -Be 'sha256'
        $result.Package.artifactFiles[0].contentHash.value | Should -Be '91898433cf5ce0a8f45516a4cc3e9343b6e01d052d01f684309098c66a326c59'
        $result.Package.assigned.install.kind | Should -Be 'placePackageFile'
        $result.Compatibility.Count | Should -Be 1
        $result.Compatibility[0].Kind | Should -Be 'physicalOrVideoMemoryGiB'
        $result.Compatibility[0].OnFail | Should -Be 'warn'
        $result.Compatibility[0].Accepted | Should -BeFalse
    }

    It 'loads the shipped MiniCPM5_1B_Q8_Model definition and selects the fixed Hugging Face-backed resource release' {
        Mock Get-PhysicalMemoryGiB { 8.0 }
        Mock Get-VideoMemoryGiB { 2.0 }

        $config = Get-PackageConfig -DefinitionId 'MiniCPM5_1B_Q8_Model'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'huggingFaceDownload' })

        $config.DefinitionId | Should -Be 'MiniCPM5_1B_Q8_Model'
        $sourceDefinition.Kind | Should -Be 'download'
        $sourceDefinition.BaseUri | Should -Be 'https://huggingface.co/openbmb/MiniCPM5-1B-GGUF/resolve/main/'
        $result.PackageId | Should -Be 'minicpm5-1b-q8-0-stable'
        $result.Package.version | Should -Be '5.1.0'
        $result.Package.artifactFiles[0].relativePath | Should -Be 'MiniCPM5-1B-Q8_0.gguf'
        $result.Package.artifactFiles[0].contentHash.algorithm | Should -Be 'sha256'
        $result.Package.artifactFiles[0].contentHash.value | Should -Be '0dc7638539067268774c275a14a6ec9c7e01f7eeb2cff606c8590361fa527e4c'
        $result.Package.assigned.install.kind | Should -Be 'placePackageFile'
        $result.Compatibility.Count | Should -Be 1
        $result.Compatibility[0].Kind | Should -Be 'physicalOrVideoMemoryGiB'
        $result.Compatibility[0].OnFail | Should -Be 'warn'
        $result.Compatibility[0].Accepted | Should -BeTrue
    }

    It 'fails clearly when the shipped global config still defines vsCodeUpdateService as an environment source' {
        $globalConfigPath = Join-Path $TestDrive 'PackageConfig.json'
        $badGlobal = New-TestPackageGlobalDocument -EnvironmentSources @{
            vsCodeUpdateService = @{ kind = 'download'; baseUri = 'https://example.invalid/' }
        }
        Write-TestJsonDocument -Path $globalConfigPath -Document $badGlobal

        $globalInfo = Read-PackageJsonDocument -Path $globalConfigPath
        { Assert-PackageConfigSchema -PackageConfigDocumentInfo $globalInfo } | Should -Throw '*vsCodeUpdateService*'
    }

    It 'fails clearly when a definition still uses requireManagedOwnership' {
        $rootPath = Join-Path $TestDrive 'retired-require-managed-ownership'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0') -SharedOwnershipPolicy @{
            allowAdoptExternal    = $false
            upgradeAdoptedInstall = $false
            requireManagedOwnership = $false
        }
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument $definitionDocument

        $definitionInfo = Read-PackageJsonDocument -Path $documents.DefinitionPath
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*requireManagedOwnership*'
    }

    It 'fails clearly when npm install definitions use retired managerDependency fields' {
        $release = New-TestPackageRelease -Id 'cli-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{
            kind              = 'npmMaterializedInstallGlobalPackage'
            installerCommand  = 'npm'
            packageSpec       = 'example@{version}'
            managerDependency = @{
                definitionId = 'NodeRuntime'
                command      = 'npm'
            }
        } -Readiness (New-TestReadiness -Version '1.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '1.0.0')
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*packageOperations.assigned.install.managerDependency*'
    }

    It 'rejects retired npmGlobalPackage install definitions' {
        $release = New-TestPackageRelease -Id 'cli-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{
            kind             = 'npmGlobalPackage'
            installerCommand = 'npm'
            packageSpec      = 'example@{version}'
            installDirectory = 'example/{releaseTrack}/{version}/{artifactDistributionVariant}'
        } -Readiness (New-TestReadiness -Version '1.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '1.0.0')
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*npmGlobalPackage*'
    }

    It 'fails clearly when a definition is missing schemaVersion' {
        $rootPath = Join-Path $TestDrive 'missing-schema-version'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $null = $definitionDocument.Remove('schemaVersion')
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument $definitionDocument

        $definitionInfo = Read-PackageJsonDocument -Path $documents.DefinitionPath
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*schemaVersion*'
    }

    It 'validates optional classification tags and rejects invalid classification shapes' {
        $release = New-TestPackageRelease -Id 'vs-code-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        $taglessDefinition = New-TestVSCodeDefinitionDocument -Releases @($release)
        $taglessInfo = [pscustomobject]@{ Path = 'classification-absent.json'; Document = ConvertTo-TestPsObject $taglessDefinition }
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $taglessInfo -DefinitionId 'VSCodeRuntime' } | Should -Not -Throw

        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionDocument.classification = @{
            tags = @('ai', 'llama-cpp')
        }
        $definitionInfo = [pscustomobject]@{ Path = 'classification-valid.json'; Document = ConvertTo-TestPsObject $definitionDocument }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Not -Throw

        foreach ($classification in @(
                @{ tags = @() },
                @{ tags = 'ai' },
                @{ tags = @('AI') },
                @{ tags = @('ai', 'ai') },
                @{ tags = @('ai'); category = 'runtime' }
            )) {
            $invalidDefinition = New-TestVSCodeDefinitionDocument -Releases @($release)
            $invalidDefinition.classification = $classification
            $invalidInfo = [pscustomobject]@{ Path = 'classification-invalid.json'; Document = ConvertTo-TestPsObject $invalidDefinition }

            { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $invalidInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*classification*'
        }
    }

    It 'accepts schema 2.0 packageDepot and vendorDownload candidates' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder  = 100
                verification = @{ mode = 'optional' }
            },
            @{
                kind         = 'vendorDownload'
                sourceId     = 'vsCodeUpdateService'
                sourcePath   = '2.0.0/win32-x64-archive/stable'
                searchOrder  = 900
                verification = @{ mode = 'required' }
            }
        )
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionDocument.definitionPublication.definitionSignature = @{
            kind          = 'unsigned'
            format        = 'embedded-json-rsa-sha256-v1'
            signedContent = 'canonicalDefinitionExcludingSignatureValue'
        }
        $definitionInfo = [pscustomobject]@{ Path = 'test-2.0.json'; Document = ConvertTo-TestPsObject $definitionDocument }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Not -Throw
    }

    It 'rejects package-definition download and filesystem acquisition candidates in schema 2.0' {
        foreach ($kind in @('download', 'filesystem')) {
            $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind         = $kind
                    sourceId     = 'vsCodeUpdateService'
                    sourcePath   = '2.0.0/win32-x64-archive/stable'
                    searchOrder  = 100
                    verification = @{ mode = 'required' }
                }
            )
            $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
            $definitionDocument.definitionPublication.definitionSignature = @{
                kind          = 'unsigned'
                format        = 'embedded-json-rsa-sha256-v1'
                signedContent = 'canonicalDefinitionExcludingSignatureValue'
            }
            $definitionInfo = [pscustomobject]@{ Path = "test-2.0-$kind.json"; Document = ConvertTo-TestPsObject $definitionDocument }

            { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw "*retired*kind '$kind'*"
        }
    }

    It 'validates GitHub releaseTag requirements behind schema 2.0 vendorDownload' {
        $release = New-TestPackageRelease -Id 'llama-cpu-x64-stable' -Version '0.0.1' -Architecture 'x64' -ArtifactDistributionVariant 'win-cpu-x64' -FileName 'llama-b8863-bin-win-cpu-x64.zip' -AcquisitionCandidates @(
            @{
                kind         = 'vendorDownload'
                sourceId     = 'llamaCppGitHub'
                searchOrder  = 100
                verification = @{ mode = 'required' }
            }
        )
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '0.0.1') -UpstreamSources @{
            llamaCppGitHub = @{
                kind             = 'githubRelease'
                githubOwner      = 'ggml-org'
                githubRepository = 'llama.cpp'
            }
        }
        $definitionDocument.definitionPublication.definitionSignature = @{
            kind          = 'unsigned'
            format        = 'embedded-json-rsa-sha256-v1'
            signedContent = 'canonicalDefinitionExcludingSignatureValue'
        }
        $definitionInfo = [pscustomobject]@{ Path = 'test-2.0-github.json'; Document = ConvertTo-TestPsObject $definitionDocument }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*requires releaseTag*'
    }

    It 'rejects retired schema 1.6, 1.7, and 1.8 definitions' {
        foreach ($schemaVersion in @('1.6', '1.7', '1.8')) {
            $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind         = 'vendorDownload'
                    sourceId     = 'vsCodeUpdateService'
                    sourcePath   = '2.0.0/win32-x64-archive/stable'
                    searchOrder  = 100
                    verification = @{ mode = 'required' }
                }
            )
            $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
            $definitionDocument.schemaVersion = $schemaVersion
            $definitionInfo = [pscustomobject]@{ Path = "test-$schemaVersion.json"; Document = ConvertTo-TestPsObject $definitionDocument }

            { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw "*unsupported schemaVersion '$schemaVersion'*"
        }
    }

    It 'rejects schema 1.9 with an explicit manual-migration-required error' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -FileName 'VSCode-win32-x64-2.0.0.zip'
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionDocument.schemaVersion = '1.9'
        $definitionInfo = [pscustomobject]@{ Path = 'legacy-1.9.json'; Document = ConvertTo-TestPsObject $definitionDocument }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*manual migration*automatic conversion is not supported*'
    }

    It 'rejects retired download candidates in the only supported schema' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'download'
                sourceId     = 'vsCodeUpdateService'
                sourcePath   = '2.0.0/win32-x64-archive/stable'
                searchOrder  = 100
                verification = @{ mode = 'required' }
            }
        )
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionInfo = [pscustomobject]@{ Path = 'test-2.0-download.json'; Document = ConvertTo-TestPsObject $definitionDocument }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw "*retired kind 'download'*"
    }

    It 'fails clearly when a definition still uses retired root discovery properties' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)

        $definitionDocument['presenceDiscovery'] = @{ commands = @() }
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*presenceDiscovery*discovery.presence*'

        $null = $definitionDocument.Remove('presenceDiscovery')
        $definitionDocument['existingInstallDiscovery'] = @{ enabled = $false; searchLocations = @(); installRootRules = @() }
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*existingInstallDiscovery*discovery.existingInstall*'
    }

    It 'fails clearly when operations still reference retired discovery paths' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = $null
        }

        $definitionDocument.packageOperations.assigned.readyStateCheck.use = 'presenceDiscovery'
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*readyStateCheck.use*discovery.presence*'

        $definitionDocument.packageOperations.assigned.readyStateCheck.use = 'discovery.presence'
        $definitionDocument.packageOperations.assigned.pathRegistration = @{
            mode   = 'user'
            source = @{
                kind = 'shim'
                use  = 'discovery.presence.commands'
            }
        }
        $definitionDocument.packageOperations.assigned.pathRegistration.source.use = 'presenceDiscovery.commands'
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*pathRegistration.source*discovery.presence.commands*'

        $definitionDocument.packageOperations.assigned.pathRegistration.source.use = 'discovery.presence.commands'
        $definitionDocument.packageOperations.removed.absenceVerification.use = 'presenceDiscovery'
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*absenceVerification.use*discovery.presence*'

        $definitionDocument.packageOperations.removed.absenceVerification.use = 'discovery.presence'
        $definitionDocument.packageOperations.removed.operation = @{
            kind             = 'msiUninstaller'
            commandSource    = @{
                use                = 'existingInstallDiscovery'
                searchLocationId   = 'sevenZipUninstallRegistry'
                registryValueOrder = @('QuietUninstallString', 'UninstallString')
            }
            commandArguments = @('/qn', '/norestart')
            elevation        = 'required'
            timeoutSec       = 600
            successExitCodes = @(0, 1605, 3010)
            restartExitCodes = @(3010)
            uiMode           = 'silent'
        }
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*commandSource.use*discovery.existingInstall*'
    }

    It 'fails clearly when a definition still uses shared.requirements' {
        $rootPath = Join-Path $TestDrive 'retired-requirements-packages'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionDocument.shared = @{
            requirements = @{
                checks = [object[]]@()
            }
        }
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument $definitionDocument

        $definitionInfo = Read-PackageJsonDocument -Path $documents.DefinitionPath
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*shared*'
    }

    It 'fails clearly when a definition still uses retired root packageTargets' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionDocument.packageTargets = @()

        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*packageTargets*'
    }

    It 'fails clearly when a definition still uses retired root versionCatalog' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionDocument.versionCatalog = @()

        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*versionCatalog*'
    }

    It 'fails clearly when a release still uses retired artifactsByTarget' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionDocument.artifacts.releases[0].artifactsByTarget = @{}

        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*artifactsByTarget*'
    }

    It 'fails clearly when an acquisition candidate still uses retired priority' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                priority     = 100
                verification = @{ mode = 'none' }
            }
        )
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*priority*'
    }

    It 'fails clearly when an artifact file still uses retired raw-file trust properties' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder  = 100
                verification = @{ mode = 'required' }
            }
        )
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $artifact = $definitionDocument.artifacts.releases[0].targetArtifacts['vsCode-win-x64-stable']
        $artifactFile = $artifact.artifactFiles.package
        $artifactFile.integrity = @{ algorithm = 'sha256'; sha256 = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' }
        $artifactFile.authenticode = @{ requireValid = $true }
        $artifactFile.autoUpdateSupported = $false
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw "*retired property 'autoUpdateSupported'*"
        $null = $artifactFile.Remove('autoUpdateSupported')
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw "*retired property 'integrity'*"
        $null = $artifactFile.Remove('integrity')
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw "*retired property 'authenticode'*"
    }

    It 'rejects incomplete artifact-file contentHash and publisherSignature metadata' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder  = 100
                verification = @{ mode = 'required' }
            }
        )
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @($release)
        $artifact = $definitionDocument.artifacts.releases[0].targetArtifacts['vsCode-win-x64-stable']
        $artifactFile = $artifact.artifactFiles.package
        $artifactFile.contentHash = @{ algorithm = 'sha256' }
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'VSCodeRuntime.json'
            Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*contentHash without value*'
        $artifactFile.contentHash = @{
            algorithm = 'sha256'
            value     = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
        }
        $artifactFile.publisherSignature = @{
            requireValid = $true
        }
        $definitionInfo.Document = ConvertTo-TestPsObject -InputObject $definitionDocument
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'VSCodeRuntime' } | Should -Throw '*publisherSignature without kind*'
    }

    It 'accepts a schema 2.0 split-installer artifact file set with exact target and release IDs' {
        $release = New-TestPackageRelease -Id 'split-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -FileName 'setup-2.0.0.exe' -AcquisitionCandidates @(
            @{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } }
        )
        $definition = New-TestVSCodeDefinitionDocument -Releases @($release)
        $target = $definition.artifacts.targets[0]
        $target.artifactFiles.part001 = @{
            relativePathTemplate = 'parts/setup-{version}.001'
            acquisitionCandidates = @(@{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } })
        }
        $releaseArtifact = $definition.artifacts.releases[0].targetArtifacts['split-win-x64-stable']
        $releaseArtifact.artifactFiles.part001 = @{}
        $definition.packageOperations.assigned.install.artifactFileId = 'package'
        $info = [pscustomobject]@{ Path = 'split.json'; Document = ConvertTo-TestPsObject $definition }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $info -DefinitionId 'VSCodeRuntime' } | Should -Not -Throw
    }

    It 'rejects mismatched artifact file-ID sets and missing operation file IDs' {
        $release = New-TestPackageRelease -Id 'split-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -FileName 'setup.exe' -AcquisitionCandidates @(
            @{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } }
        )
        $definition = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definition.artifacts.targets[0].artifactFiles.part001 = @{
            relativePathTemplate = 'setup.001'
            acquisitionCandidates = @(@{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } })
        }
        $info = [pscustomobject]@{ Path = 'mismatch.json'; Document = ConvertTo-TestPsObject $definition }
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $info -DefinitionId 'VSCodeRuntime' } | Should -Throw '*artifactFiles must exactly match target files*part001*'

        $definition.packageOperations.assigned.install.artifactFileId = 'missing'
        $info.Document = ConvertTo-TestPsObject $definition
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $info -DefinitionId 'VSCodeRuntime' } | Should -Throw "*artifactFileId 'missing' is not declared*"
    }

    It 'rejects unsafe and case-insensitively colliding artifact paths' {
        $release = New-TestPackageRelease -Id 'split-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -FileName 'setup.exe' -AcquisitionCandidates @(
            @{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } }
        )
        $definition = New-TestVSCodeDefinitionDocument -Releases @($release)
        $definition.artifacts.targets[0].artifactFiles.package.relativePathTemplate = '../setup.exe'
        $info = [pscustomobject]@{ Path = 'unsafe.json'; Document = ConvertTo-TestPsObject $definition }
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $info -DefinitionId 'VSCodeRuntime' } | Should -Throw '*unsafe path segment*'

        $definition.artifacts.targets[0].artifactFiles.package.relativePathTemplate = 'Setup.exe'
        $definition.artifacts.targets[0].artifactFiles.part001 = @{
            relativePathTemplate = 'setup.EXE'
            acquisitionCandidates = @(@{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } })
        }
        $definition.artifacts.releases[0].targetArtifacts['split-win-x64-stable'].artifactFiles.part001 = @{}
        $info.Document = ConvertTo-TestPsObject $definition
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $info -DefinitionId 'VSCodeRuntime' } | Should -Throw '*colliding artifact file path template*'
    }

    It 'rejects missing archiveEntry references and dependency cycles before acquisition' {
        $release = New-TestPackageRelease -Id 'derived-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -FileName 'module.nupkg' -AcquisitionCandidates @(
            @{ kind = 'packageDepot'; searchOrder = 100; verification = @{ mode = 'required' } }
        )
        $definition = New-TestVSCodeDefinitionDocument -Releases @($release)
        $target = $definition.artifacts.targets[0]
        $target.artifactFiles.bootstrap = @{
            relativePathTemplate = 'Bootstrap/bootstrap.ps1'
            acquisitionCandidates = @(@{
                    kind = 'archiveEntry'; sourceArtifactFileId = 'missing'; entryPath = 'Bootstrap/bootstrap.ps1'
                    searchOrder = 900; verification = @{ mode = 'required' }
                })
        }
        $definition.artifacts.releases[0].targetArtifacts['derived-win-x64-stable'].artifactFiles.bootstrap = @{}
        $info = [pscustomobject]@{ Path = 'missing-reference.json'; Document = ConvertTo-TestPsObject $definition }
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $info -DefinitionId 'VSCodeRuntime' } | Should -Throw "*references unknown sourceArtifactFileId 'missing'*"

        $target.artifactFiles.bootstrap.acquisitionCandidates[0].sourceArtifactFileId = 'package'
        $target.artifactFiles.package.acquisitionCandidates = @(@{
                kind = 'archiveEntry'; sourceArtifactFileId = 'bootstrap'; entryPath = 'module.nupkg'
                searchOrder = 900; verification = @{ mode = 'required' }
            })
        $info.Document = ConvertTo-TestPsObject $definition
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $info -DefinitionId 'VSCodeRuntime' } | Should -Throw '*dependency cycle*'
    }

    It 'rejects duplicate release versions case-insensitively' {
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip'
        $definition = New-TestVSCodeDefinitionDocument -Releases @($release)
        $duplicateRelease = ConvertTo-TestPsObject $definition.artifacts.releases[0]
        $definition.artifacts.releases = @($definition.artifacts.releases[0], $duplicateRelease)
        $info = [pscustomobject]@{ Path = 'duplicate-version.json'; Document = ConvertTo-TestPsObject $definition }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $info -DefinitionId 'VSCodeRuntime' } | Should -Throw '*duplicate release version*'
    }

}
