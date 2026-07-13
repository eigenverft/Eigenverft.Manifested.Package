<#
    Eigenverft.Manifested.Package Package - source and selection
#>

. "$PSScriptRoot\\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - source and selection' -Body {

    It 'filters depot inventory sources by enabled flag and semicolon site-code list' {
        $rootPath = Join-Path $TestDrive 'depot-inventory-sites'
        $depotInventory = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory (Join-Path $rootPath 'default-depot') -EnvironmentSources @{
            disabledDepot = @{
                kind     = 'filesystem'
                enabled  = $false
                searchOrder = 50
                basePath = (Join-Path $rootPath 'disabled')
            }
            departmentDepot = @{
                kind      = 'filesystem'
                enabled   = $true
                searchOrder  = 150
                siteCodes = @('BER-ENG')
                basePath  = (Join-Path $rootPath 'department')
            }
            otherSiteDepot = @{
                kind      = 'filesystem'
                enabled   = $true
                searchOrder  = 100
                siteCodes = @('PD')
                basePath  = (Join-Path $rootPath 'other-site')
            }
            globalDepot = @{
                kind     = 'filesystem'
                enabled  = $true
                searchOrder = 400
                basePath = (Join-Path $rootPath 'global')
            }
        }
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DepotInventoryDocument $depotInventory -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @(
                New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                    @{
                        kind        = 'packageDepot'
                        searchOrder    = 100
                        verification = @{ mode = 'none' }
                    }
                )
            ))
        [Environment]::SetEnvironmentVariable($script:SiteCodeEnvVarName, 'BER;BER-ENG', 'Process')

        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $sourceNames = @($config.EnvironmentSources.PSObject.Properties.Name)
        $depotSources = @(Get-PackagePackageDepotSources -PackageConfig $config)

        $sourceNames | Should -Contain 'defaultPackageDepot'
        $sourceNames | Should -Contain 'departmentDepot'
        $sourceNames | Should -Contain 'globalDepot'
        $sourceNames | Should -Not -Contain 'disabledDepot'
        $sourceNames | Should -Not -Contain 'otherSiteDepot'
        @($depotSources.id) | Should -Be @('departmentDepot', 'defaultPackageDepot', 'globalDepot')
    }

    It 'rejects a selected release when compatibility.checks are not satisfied with onFail fail' {
        $rootPath = Join-Path $TestDrive 'requirements-checks-fail'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Compatibility @{
            checks = @(
                @{
                    kind    = 'osFamily'
                    allowed = @('linux')
                }
            )
        } -Readiness (New-TestReadiness -Version '2.0.0')
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config

        { Resolve-PackagePackage -PackageResult $result } | Should -Throw '*compatibility.checks*'
    }

    It 'resolves environment and definition source refs from the effective acquisition environment and upstream sources' {
        $rootPath = Join-Path $TestDrive 'source-resolution'
        $depotInventory = New-TestDepotInventoryDocument -DefaultPackageDepotDirectory (Join-Path $rootPath 'default-depot') -EnvironmentSources @{
            remotePackageDepot = @{
                kind        = 'filesystem'
                searchOrder = 150
                basePath    = (Join-Path $TestDrive 'remote-depot')
            }
        }
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DepotInventoryDocument $depotInventory -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @(
                New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -Install @{ kind = 'reuseExisting' } -Readiness (New-TestReadiness -Version '2.0.0')
            ) -UpstreamBaseUri 'https://example.invalid/vscode/')
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $environmentSource = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'environment'; id = 'remotePackageDepot' })
        $definitionSource = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'vsCodeUpdateService' })

        $environmentSource.Kind | Should -Be 'filesystem'
        $environmentSource.BasePath | Should -Be (Join-Path $TestDrive 'remote-depot')
        $definitionSource.Kind | Should -Be 'download'
        $definitionSource.BaseUri | Should -Be 'https://example.invalid/vscode/'
    }

    It 'loads GitHub release upstream sources and keeps releaseTag separate from version' {
        $rootPath = Join-Path $TestDrive 'github-release-source'
        $release = New-TestPackageRelease -Id 'llama-cpu-x64-stable' -Version '0.0.1' -ReleaseTag 'b8863' -Architecture 'x64' -ArtifactDistributionVariant 'win-cpu-x64' -FileName 'llama-b8863-bin-win-cpu-x64.zip' -AcquisitionCandidates @(
            @{
                kind         = 'vendorDownload'
                sourceId     = 'llamaCppGitHub'
                searchOrder     = 100
                verification = @{ mode = 'required' }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '0.0.1') -UpstreamSources @{
            llamaCppGitHub = @{
                kind            = 'githubRelease'
                githubOwner      = 'ggml-org'
                githubRepository = 'llama.cpp'
            }
        })
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $definitionSource = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'llamaCppGitHub' })

        $definitionSource.Kind | Should -Be 'githubRelease'
        $definitionSource.GitHubOwner | Should -Be 'ggml-org'
        $definitionSource.GitHubRepository | Should -Be 'llama.cpp'
        $result.Package.version | Should -Be '0.0.1'
        $result.Package.releaseTag | Should -Be 'b8863'
    }

    It 'requires releaseTag for GitHub-backed releases' {
        $rootPath = Join-Path $TestDrive 'github-release-tag-required'
        $release = New-TestPackageRelease -Id 'llama-cpu-x64-stable' -Version '0.0.1' -Architecture 'x64' -ArtifactDistributionVariant 'win-cpu-x64' -FileName 'llama-b8863-bin-win-cpu-x64.zip' -AcquisitionCandidates @(
            @{
                kind         = 'vendorDownload'
                sourceId     = 'llamaCppGitHub'
                searchOrder     = 100
                verification = @{ mode = 'required' }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '0.0.1') -UpstreamSources @{
            llamaCppGitHub = @{
                kind            = 'githubRelease'
                githubOwner      = 'ggml-org'
                githubRepository = 'llama.cpp'
            }
        })
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        { Get-PackageConfig -DefinitionId 'VSCodeRuntime' } | Should -Throw '*requires releaseTag*'
    }

    It 'resolves a GitHub release asset URL from releaseTag and packageFile.fileName' {
        $rootPath = Join-Path $TestDrive 'github-release-resolve'
        $release = New-TestPackageRelease -Id 'llama-cpu-x64-stable' -Version '0.0.1' -ReleaseTag 'b8863' -Architecture 'x64' -ArtifactDistributionVariant 'win-cpu-x64' -FileName 'llama-b8863-bin-win-cpu-x64.zip' -AcquisitionCandidates @(
            @{
                kind         = 'vendorDownload'
                sourceId     = 'llamaCppGitHub'
                searchOrder     = 100
                verification = @{ mode = 'required' }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '0.0.1') -UpstreamSources @{
            llamaCppGitHub = @{
                kind            = 'githubRelease'
                githubOwner      = 'ggml-org'
                githubRepository = 'llama.cpp'
            }
        })
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }
        Mock Get-GitHubRelease {
            [pscustomobject]@{
                RepositoryOwner = 'ggml-org'
                RepositoryName  = 'llama.cpp'
                ReleaseTag      = 'b8863'
                Assets          = @(
                    [pscustomobject]@{
                        Name        = 'llama-b8863-bin-win-cpu-x64.zip'
                        DownloadUrl = 'https://example.invalid/ggml-org/llama.cpp/releases/download/b8863/llama-b8863-bin-win-cpu-x64.zip'
                    }
                )
            }
        }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $sourceDefinition = Get-PackageSourceDefinition -PackageConfig $config -SourceRef ([pscustomobject]@{ scope = 'definition'; id = 'llamaCppGitHub' })
        $resolvedSource = Resolve-PackageSource -SourceDefinition $sourceDefinition -AcquisitionCandidate $result.Package.acquisitionCandidates[0] -Package $result.Package

        $resolvedSource.Kind | Should -Be 'download'
        $resolvedSource.ResolvedSource | Should -Be 'https://example.invalid/ggml-org/llama.cpp/releases/download/b8863/llama-b8863-bin-win-cpu-x64.zip'
        Assert-MockCalled Get-GitHubRelease -Times 1 -Exactly
    }

    It 'fails clearly when a GitHub release tag cannot be resolved' {
        Mock Invoke-WebRequestEx { throw '404 Not Found' }

        { Get-GitHubRelease -RepositoryOwner 'ggml-org' -RepositoryName 'llama.cpp' -ReleaseTag 'b9999' } | Should -Throw "*repository 'ggml-org/llama.cpp'*release tag 'b9999'*"
    }

    It 'normalizes GitHub release API metadata and assets' {
        $responseBody = @{
            id           = 42
            tag_name     = 'b8863'
            name         = 'b8863'
            html_url     = 'https://github.com/ggml-org/llama.cpp/releases/tag/b8863'
            published_at = '2026-04-20T23:54:06Z'
            draft        = $false
            prerelease   = $false
            immutable    = $false
            assets       = @(
                @{
                    id                   = 99
                    name                 = 'llama-b8863-bin-win-cpu-x64.zip'
                    browser_download_url = 'https://example.invalid/llama-b8863-bin-win-cpu-x64.zip'
                    content_type         = 'application/zip'
                    size                 = 12345
                    digest               = 'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
                    created_at           = '2026-04-20T23:54:06Z'
                    updated_at           = '2026-04-20T23:54:06Z'
                }
            )
        } | ConvertTo-Json -Depth 10

        Mock Invoke-WebRequestEx {
            [pscustomobject]@{
                Content = $responseBody
            }
        }

        $release = Get-GitHubRelease -RepositoryOwner 'ggml-org' -RepositoryName 'llama.cpp' -ReleaseTag 'b8863'

        $release.ReleaseId | Should -Be '42'
        $release.ReleaseTag | Should -Be 'b8863'
        $release.RepositoryOwner | Should -Be 'ggml-org'
        $release.RepositoryName | Should -Be 'llama.cpp'
        $release.Assets.Count | Should -Be 1
        $release.Assets[0].Name | Should -Be 'llama-b8863-bin-win-cpu-x64.zip'
        $release.Assets[0].DownloadUrl | Should -Be 'https://example.invalid/llama-b8863-bin-win-cpu-x64.zip'
        $release.Assets[0].Sha256 | Should -Be '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
    }

    It 'fails clearly when the GitHub release asset is missing' {
        $sourceDefinition = [pscustomobject]@{
            Scope           = 'definition'
            Id              = 'llamaCppGitHub'
            Kind            = 'githubRelease'
            GitHubOwner      = 'ggml-org'
            GitHubRepository = 'llama.cpp'
        }
        $package = ConvertTo-TestPsObject @{
            id         = 'llama-cpu-x64-stable'
            releaseTag = 'b8863'
            packageFile = @{
                fileName = 'llama-b8863-bin-win-cpu-x64.zip'
            }
        }
        $candidate = ConvertTo-TestPsObject @{
            kind     = 'vendorDownload'
            sourceId = 'llamaCppGitHub'
        }

        Mock Get-GitHubRelease {
            [pscustomobject]@{
                RepositoryOwner = 'ggml-org'
                RepositoryName  = 'llama.cpp'
                ReleaseTag      = 'b8863'
                Assets          = @(
                    [pscustomobject]@{
                        Name        = 'llama-b8863-bin-win-cuda-12.4-x64.zip'
                        DownloadUrl = 'https://example.invalid/other.zip'
                    }
                )
            }
        }

        { Resolve-PackageSource -SourceDefinition $sourceDefinition -AcquisitionCandidate $candidate -Package $package } | Should -Throw '*does not contain asset*llama-b8863-bin-win-cpu-x64.zip*'
    }

    It 'builds an effective release from shared defaults and uses ReleaseTrack in path resolution' {
        $rootPath = Join-Path $TestDrive 'effective-release'
        $packageArchive = New-TestPackageArchiveInfo -RootPath (Join-Path $rootPath 'archive') -Version '2.0.0'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind        = 'packageDepot'
                searchOrder    = 10
                verification = @{ mode = 'optional'; algorithm = 'sha256'; sha256 = $packageArchive.Sha256 }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -ReleaseTrack 'stable') -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result

        $result.EffectiveRelease | Should -Not -BeNullOrEmpty
        $result.Package.assigned.install.kind | Should -Be 'expandArchive'
        $result.Package.readiness.commandChecks[0].expectedValue | Should -Be '{version}'
        $result.PackageWorkSlotDirectory | Should -Match '^VSCodeRuntime-[0-9a-f]{8}$'
        $result.PackageFilePath | Should -Match '\\FileStage\\VSCodeRuntime-[0-9a-f]{8}\\'
        $result.PackageInstallStageDirectory | Should -Match '\\InstStage\\VSCodeRuntime-[0-9a-f]{8}$'
        (Split-Path -Leaf $result.PackageFileStagingDirectory) | Should -Be (Split-Path -Leaf $result.PackageInstallStageDirectory)
        $result.PackageDepotRelativeDirectory | Should -Be 'VSCodeRuntime\stable\2.0.0\win32-x64'
        $result.DefaultPackageDepotFilePath | Should -Match '\\stable\\2\.0\.0\\win32-x64\\'
    }

    It 'writes resolved paths as separate console lines' {
        $rootPath = Join-Path $TestDrive 'resolved-path-lines'
        $release = New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
            @{
                kind         = 'packageDepot'
                searchOrder     = 10
                verification = @{ mode = 'none' }
            }
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @($release) -SharedReadiness (New-TestReadiness -Version '2.0.0'))
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $messages = New-Object System.Collections.Generic.List[string]
        Mock Write-StandardMessage {
            param([string]$Message, [string]$Level)
            $messages.Add($Message) | Out-Null
        }

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $null = Resolve-PackagePaths -PackageResult $result

        @($messages) | Should -Contain '[STATE] Resolved paths:'
        @($messages | Where-Object { $_.StartsWith('[PATH] Package file staging:') }).Count | Should -Be 1
        @($messages | Where-Object { $_.StartsWith('[PATH] Package install stage:') }).Count | Should -Be 1
        @($messages | Where-Object { $_.StartsWith('[PATH] Target install directory:') }).Count | Should -Be 1
        @($messages | Where-Object { $_.StartsWith('[PATH] Package file:') }).Count | Should -Be 1
        @($messages | Where-Object { $_.StartsWith('[PATH] Default package depot file:') }).Count | Should -Be 1
    }

}
