<#
    Eigenverft.Manifested.Package Package - npm materialization
#>

. "$PSScriptRoot\\Eigenverft.Manifested.Package.Package.InstallAndNpm.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - npm materialization' -Body {

    It 'routes Package archive installs through PackageInstallStage' {
        $rootPath = Join-Path $TestDrive 'package-install-archive-route'
        $packageFilePath = Join-Path $rootPath 'package.zip'
        $stagePath = Join-Path $rootPath 'stage'
        $layoutRoot = Join-Path $rootPath 'layout\payload'
        $installDirectory = Join-Path $rootPath 'install'
        $null = New-Item -ItemType Directory -Path $layoutRoot -Force
        Write-TestTextFile -Path (Join-Path $layoutRoot 'Code.exe') -Content 'binary'
        Write-TestZipFromDirectory -SourceDirectory (Join-Path $rootPath 'layout') -ZipPath $packageFilePath

        $packageResult = [pscustomobject]@{
            PackageId                    = 'VSCodeRuntime'
            PackageFilePath              = $packageFilePath
            PackageInstallStageDirectory = $stagePath
            InstallDirectory             = $installDirectory
            Package                      = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind              = 'expandArchive'
                        expandedRoot      = 'auto'
                        createDirectories = @('data')
                    }
                }
            }
            ExistingPackage = $null
        }

        $installResult = Install-PackageArchive -PackageResult $packageResult

        $installResult.InstallKind | Should -Be 'expandArchive'
        Test-Path -LiteralPath $stagePath -PathType Container | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $installDirectory 'Code.exe') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $installDirectory 'data') -PathType Container | Should -BeTrue
    }

    It 'reads text entries from tar gzip archives without extracting' {
        $archivePath = Join-Path $TestDrive 'archive-read\package.tgz'
        Write-TestTarGzipEntry -Path $archivePath -EntryName 'package/package.json' -Content '{"name":"demo","version":"1.0.0"}'

        Read-TarGzipArchiveEntryText -ArchivePath $archivePath -EntryPath '.\package\package.json' | Should -Be '{"name":"demo","version":"1.0.0"}'
        { Read-TarGzipArchiveEntryText -ArchivePath $archivePath -EntryPath 'package/missing.json' } | Should -Throw '*does not contain entry*'
    }

    It 'packs materialized npm tarballs through npm instead of raw tarball urls' {
        $rootPath = Join-Path $TestDrive 'npm-materialized-pack'
        $targetDirectory = Join-Path $rootPath 'materialized'
        $fakeNpmPath = Join-Path $rootPath 'node\npm.cmd'
        $fakeNpmScriptPath = Join-Path $rootPath 'fake-npm.ps1'
        $argumentsFile = Join-Path $rootPath 'npm-pack-arguments.txt'
        Write-TestTextFile -Path $fakeNpmPath -Content @"
@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$fakeNpmScriptPath" %*
"@
        Write-TestTextFile -Path $fakeNpmScriptPath -Content @"
param([Parameter(ValueFromRemainingArguments = `$true)][string[]]`$NpmArgs)
`$NpmArgs -join ' ' | Add-Content -LiteralPath '$argumentsFile'
if (`$NpmArgs[0] -eq 'install') {
    `$lock = @{
        name = 'materialized-test'
        lockfileVersion = 3
        packages = [ordered]@{
            '' = @{ dependencies = @{ 'opencode-ai' = '1.14.46' } }
            'node_modules/opencode-ai' = @{
                version = '1.14.46'
                resolved = 'https://registry.npmjs.org/opencode-ai/-/opencode-ai-1.14.46.tgz'
                integrity = 'sha512-root'
            }
            'node_modules/opencode-windows-x64-baseline' = @{
                version = '1.14.46'
                resolved = 'https://registry.npmjs.org/opencode-windows-x64-baseline/-/opencode-windows-x64-baseline-1.14.46.tgz'
                integrity = 'sha512-win'
                optional = `$true
                os = @('win32')
                cpu = @('x64')
            }
            'node_modules/opencode-darwin-arm64' = @{
                version = '1.14.46'
                resolved = 'https://registry.npmjs.org/opencode-darwin-arm64/-/opencode-darwin-arm64-1.14.46.tgz'
                integrity = 'sha512-mac'
                optional = `$true
                os = @('darwin')
                cpu = @('arm64')
            }
        }
    }
    `$lock | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path (Get-Location) 'package-lock.json') -Encoding UTF8
    exit 0
}
if (`$NpmArgs[0] -ne 'pack') { exit 9 }
`$packageSpec = `$NpmArgs[1]
`$destinationIndex = [Array]::IndexOf(`$NpmArgs, '--pack-destination')
if (`$destinationIndex -lt 0) { exit 8 }
`$destination = `$NpmArgs[`$destinationIndex + 1]
`$name = `$packageSpec.Substring(0, `$packageSpec.LastIndexOf('@'))
`$version = `$packageSpec.Substring(`$packageSpec.LastIndexOf('@') + 1)
`$fileName = ('{0}-{1}.tgz' -f `$name, `$version)
`$targetPath = Join-Path `$destination `$fileName
New-Item -ItemType Directory -Path `$destination -Force | Out-Null
Set-Content -LiteralPath `$targetPath -Value ('packed-' + `$packageSpec) -NoNewline -Encoding UTF8
`$sha512 = [System.Security.Cryptography.SHA512]::Create()
`$stream = [System.IO.File]::OpenRead(`$targetPath)
try {
    `$integrity = 'sha512-' + [Convert]::ToBase64String(`$sha512.ComputeHash(`$stream))
}
finally {
    `$stream.Dispose()
    `$sha512.Dispose()
}
@([pscustomobject]@{ name = `$name; version = `$version; filename = `$fileName; integrity = `$integrity }) | ConvertTo-Json -Compress
exit 0
"@

        $packageResult = [pscustomobject]@{
            PackageId = 'opencode-runtime-win32-x64-stable'
            DefinitionId = 'OpenCodeCli'
            PackageFileStagingDirectory = (Join-Path $rootPath 'FileStage\OpenCodeCli')
            PackageDepotRelativeDirectory = 'OpenCodeCli\stable\1.14.46\win32-x64'
            PackageConfig = [pscustomobject]@{
                DefinitionId = 'OpenCodeCli'
                Platform = 'windows'
                Architecture = 'x64'
                PackageAssignmentInventoryFilePath = (Join-Path $rootPath 'State\PackageAssignmentInventory.json')
            }
            Dependencies = @(
                [pscustomobject]@{
                    DefinitionId = 'NodeRuntime'
                    Commands = @(
                        [pscustomobject]@{ Name = 'npm'; Path = $fakeNpmPath }
                    )
                }
            )
            Package = [pscustomobject]@{
                id = 'opencode-runtime-win32-x64-stable'
                version = '1.14.46'
                releaseTrack = 'stable'
                artifactDistributionVariant = 'win32-x64'
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind = 'npmMaterializedInstallGlobalPackage'
                        installerCommand = 'npm'
                        packageSpec = 'opencode-ai@{version}'
                    }
                }
            }
        }

        $result = New-PackageNpmMaterializationFromRegistry -PackageResult $packageResult -PackageSpec 'opencode-ai@1.14.46' -NpmPlatform 'win32' -NpmArchitecture 'x64' -TargetDirectory $targetDirectory

        $tarballNames = @($result.TarballPaths | ForEach-Object { Split-Path -Leaf $_ })
        $tarballNames | Should -Contain 'opencode-ai-1.14.46.tgz'
        $tarballNames | Should -Contain 'opencode-windows-x64-baseline-1.14.46.tgz'
        $tarballNames | Should -Not -Contain 'opencode-darwin-arm64-1.14.46.tgz'
        $arguments = Get-Content -LiteralPath $argumentsFile -Raw
        $arguments | Should -Match 'pack opencode-ai@1\.14\.46'
        $arguments | Should -Match 'pack opencode-windows-x64-baseline@1\.14\.46'
        $arguments | Should -Match '--pack-destination'
        $arguments | Should -Not -Match 'opencode-ai opencode-windows'
        $arguments | Should -Not -Match 'https://registry\.npmjs\.org'
    }

    It 'uses lock entry name when node_modules path differs from registry package name' {
        $lockDirectory = Join-Path $TestDrive 'npm-lock-alias-name'
        $null = New-Item -ItemType Directory -Path $lockDirectory -Force
        $lockFilePath = Join-Path $lockDirectory 'package-lock.json'
        $lock = @{
            name            = 'alias-name-test'
            lockfileVersion = 3
            packages        = [ordered]@{
                '' = @{
                    dependencies = @{
                        '@openai/codex' = '0.133.0'
                    }
                }
                'node_modules/@openai/codex' = @{
                    version   = '0.133.0'
                    resolved  = 'https://registry.npmjs.org/@openai/codex/-/codex-0.133.0.tgz'
                    integrity = 'sha512-root'
                }
                'node_modules/@openai/codex-win32-x64' = @{
                    name      = '@openai/codex'
                    version   = '0.133.0-win32-x64'
                    resolved  = 'https://registry.npmjs.org/@openai/codex/-/codex-0.133.0-win32-x64.tgz'
                    integrity = 'sha512-platform'
                    optional  = $true
                    os        = @('win32')
                    cpu       = @('x64')
                }
            }
        }
        $lock | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $lockFilePath -Encoding UTF8

        $packages = @(Get-PackageNpmMaterializedPackagesFromLock -LockFilePath $lockFilePath -NpmPlatform 'win32' -NpmArchitecture 'x64')

        $packages.Count | Should -Be 2
        $platformPackage = @($packages | Where-Object { $_.Version -eq '0.133.0-win32-x64' } | Select-Object -First 1)
        $platformPackage.Name | Should -Be '@openai/codex'
        $platformPackage.Name | Should -Not -Be '@openai/codex-win32-x64'
        $platformPackage.FileName | Should -Be 'codex-0.133.0-win32-x64.tgz'
    }

    It 'parses npm package specs, alias targets, and local file specs' {
        $rootSpec = Resolve-PackageNpmPackageSpecParts -PackageSpec '@openai/codex@0.133.0'
        $rootSpec.Name | Should -Be '@openai/codex'
        $rootSpec.Version | Should -Be '0.133.0'

        $aliasTarget = Resolve-PackageNpmDependencyTarget -DependencyKey '@openai/codex-win32-x64' -DependencySpec 'npm:@openai/codex@0.133.0-win32-x64'
        $aliasTarget.InstallKey | Should -Be '@openai/codex-win32-x64'
        $aliasTarget.TargetName | Should -Be '@openai/codex'
        $aliasTarget.TargetVersion | Should -Be '0.133.0-win32-x64'
        $aliasTarget.IsAlias | Should -BeTrue

        New-PackageNpmLocalFileSpec -PackageName '@openai/codex-win32-x64' -TarballPath (Join-Path $TestDrive 'codex platform.tgz') | Should -Match '^@openai/codex-win32-x64@file:.+codex platform\.tgz$'
    }

    It 'resolves alias-aware npm materialized install inputs from tarballs only' {
        $rootPath = Join-Path $TestDrive 'npm-alias-install-inputs'
        $rootTarball = Join-Path $rootPath 'openai-codex-0.133.0.tgz'
        $platformTarball = Join-Path $rootPath 'openai-codex-0.133.0-win32-x64.tgz'
        Write-TestNpmPackageTarball -Path $rootTarball -Name '@openai/codex' -Version '0.133.0' -OptionalDependencies @{ '@openai/codex-win32-x64' = 'npm:@openai/codex@0.133.0-win32-x64' }
        Write-TestNpmPackageTarball -Path $platformTarball -Name '@openai/codex' -Version '0.133.0-win32-x64' -OS @('win32') -CPU @('x64')

        $inputs = @(Resolve-PackageNpmMaterializedInstallInputsFromTarballs -PackageId 'codex-runtime-win32-x64-stable' -PackageSpec '@openai/codex@0.133.0' -TarballPaths @($rootTarball, $platformTarball) -NpmPlatform 'win32' -NpmArchitecture 'x64')
        $fileSpecs = @($inputs | ForEach-Object { $_.FileSpec })

        $inputs.Count | Should -Be 2
        $fileSpecs -join ' ' | Should -Match '@openai/codex@file:'
        $fileSpecs -join ' ' | Should -Match '@openai/codex-win32-x64@file:'
        $fileSpecs | Should -Not -Contain '@openai/codex@0.133.0'
        @($inputs | Where-Object { $_.InstallKey -eq '@openai/codex' })[0].Version | Should -Be '0.133.0'
        @($inputs | Where-Object { $_.InstallKey -eq '@openai/codex-win32-x64' })[0].Version | Should -Be '0.133.0-win32-x64'
    }

    It 'hydrates npm materialization from depot without invoking npm' {
        $rootPath = Join-Path $TestDrive 'npm-materialized-depot-hydration'
        $stageDirectory = Join-Path $rootPath 'FileStage\OpenCodeCli\npm-materialized'
        $defaultDepotRoot = Join-Path $rootPath 'PkgDepot'
        $depotDirectory = Join-Path $defaultDepotRoot 'OpenCodeCli\stable\1.14.46\win32-x64'
        $rootTarball = Join-Path $depotDirectory 'opencode-ai-1.14.46.tgz'
        $platformTarball = Join-Path $depotDirectory 'opencode-windows-x64-1.14.46.tgz'
        Write-TestNpmPackageTarball -Path $rootTarball -Name 'opencode-ai' -Version '1.14.46' -OptionalDependencies @{ 'opencode-windows-x64' = '1.14.46' }
        Write-TestNpmPackageTarball -Path $platformTarball -Name 'opencode-windows-x64' -Version '1.14.46' -OS @('win32') -CPU @('x64')

        $packageResult = [pscustomobject]@{
            PackageId = 'opencode-runtime-win32-x64-stable'
            DefinitionId = 'OpenCodeCli'
            PackageFileStagingDirectory = (Join-Path $rootPath 'FileStage\OpenCodeCli')
            PackageDepotRelativeDirectory = 'OpenCodeCli\stable\1.14.46\win32-x64'
            PackageConfig = [pscustomobject]@{
                DefinitionId = 'OpenCodeCli'
                Platform = 'windows'
                Architecture = 'x64'
                PackageAssignmentInventoryFilePath = (Join-Path $rootPath 'State\PackageAssignmentInventory.json')
                EnvironmentSources = [pscustomobject]@{
                    defaultPackageDepot = [pscustomobject]@{
                        kind = 'filesystem'
                        basePath = $defaultDepotRoot
                        readable = $true
                        writable = $false
                        mirrorTarget = $false
                        searchOrder = 100
                    }
                }
            }
            Package = [pscustomobject]@{
                id = 'opencode-runtime-win32-x64-stable'
                version = '1.14.46'
                releaseTrack = 'stable'
                artifactDistributionVariant = 'win32-x64'
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind = 'npmMaterializedInstallGlobalPackage'
                        installerCommand = 'npm'
                        packageSpec = 'opencode-ai@{version}'
                    }
                }
            }
        }

        $result = Invoke-PackageNpmMaterialization -PackageResult $packageResult

        $result.NpmMaterialization.Status | Should -Be 'HydratedFromDepot'
        @($result.NpmMaterialization.TarballPaths).Count | Should -Be 2
        @($result.NpmMaterialization.InstallInputs).Count | Should -Be 2
        @($result.NpmMaterialization.InstallInputs | ForEach-Object { $_.FileSpec }) -join ' ' | Should -Match 'opencode-ai@file:'
        @($result.NpmMaterialization.InstallInputs | ForEach-Object { $_.FileSpec }) -join ' ' | Should -Match 'opencode-windows-x64@file:'
        Test-Path -LiteralPath (Join-Path $stageDirectory 'npm-materialization.json') -PathType Leaf | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $stageDirectory 'opencode-windows-x64-1.14.46.tgz') -PathType Leaf | Should -BeTrue
    }

    It 'fails npm materialization offline when depots miss and does not use the registry' {
        $rootPath = Join-Path $TestDrive 'npm-materialized-offline-miss'
        $packageResult = [pscustomobject]@{
            PackageId = 'opencode-runtime-win32-x64-stable'
            DefinitionId = 'OpenCodeCli'
            Offline = $true
            PackageFileStagingDirectory = (Join-Path $rootPath 'FileStage\OpenCodeCli')
            PackageDepotRelativeDirectory = 'OpenCodeCli\stable\1.14.46\win32-x64'
            PackageConfig = [pscustomobject]@{
                DefinitionId = 'OpenCodeCli'
                Platform = 'windows'
                Architecture = 'x64'
                EnvironmentSources = [pscustomobject]@{
                    defaultPackageDepot = [pscustomobject]@{
                        kind = 'filesystem'
                        basePath = (Join-Path $rootPath 'PkgDepot')
                        readable = $true
                        writable = $false
                        mirrorTarget = $false
                        searchOrder = 100
                    }
                }
            }
            Package = [pscustomobject]@{
                id = 'opencode-runtime-win32-x64-stable'
                version = '1.14.46'
                releaseTrack = 'stable'
                artifactDistributionVariant = 'win32-x64'
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind = 'npmMaterializedInstallGlobalPackage'
                        installerCommand = 'npm'
                        packageSpec = 'opencode-ai@{version}'
                    }
                }
            }
        }
        Mock New-PackageNpmMaterializationFromRegistry { throw 'registry should not run in Offline mode' }

        { Invoke-PackageNpmMaterialization -PackageResult $packageResult } | Should -Throw '*Offline*npm materialization*depot*'
        Assert-MockCalled New-PackageNpmMaterializationFromRegistry -Times 0
    }

    It 'installs npmMaterializedInstallGlobalPackage from local materialized tarballs through a ready dependency command' {
        $rootPath = Join-Path $TestDrive 'npm-materialized-package-install'
        $fakeNpmPath = Join-Path $rootPath 'node\npm.cmd'
        $installDirectory = Join-Path $rootPath 'install'
        $workspaceDirectory = Join-Path $rootPath 'workspace'
        $stageDirectory = Join-Path $rootPath 'PackageInstallStage\packages\OpenCodeCli\stable\1.14.46\win32-x64'
        $fileStageDirectory = Join-Path $rootPath 'FileStage\OpenCodeCli'
        $packageStateIndexPath = Join-Path (Join-Path $rootPath 'State') 'PackageAssignmentInventory.json'
        $rootTarball = Join-Path $fileStageDirectory 'opencode-ai-1.14.46.tgz'
        $platformTarball = Join-Path $fileStageDirectory 'opencode-windows-x64-1.14.46.tgz'
        $argumentsFile = Join-Path $rootPath 'npm-arguments.txt'
        Write-TestNpmPackageTarball -Path $rootTarball -Name 'opencode-ai' -Version '1.14.46' -OptionalDependencies @{ 'opencode-windows-x64' = '1.14.46' }
        Write-TestNpmPackageTarball -Path $platformTarball -Name 'opencode-windows-x64' -Version '1.14.46' -OS @('win32') -CPU @('x64')
        Write-TestTextFile -Path $fakeNpmPath -Content @"
@echo off
set PREFIX=
echo CALL:%*>>"$argumentsFile"
if "%~1"=="cache" exit /b 0
:loop
if "%~1"=="" goto done
if "%~1"=="--prefix" (
  set PREFIX=%~2
  shift
)
shift
goto loop
:done
if "%PREFIX%"=="" exit /b 2
mkdir "%PREFIX%\node_modules\opencode-ai" >nul 2>nul
echo @echo off>"%PREFIX%\opencode.cmd"
echo {"name":"opencode-ai"}>"%PREFIX%\node_modules\opencode-ai\package.json"
exit /b 0
"@
        $packageResult = [pscustomobject]@{
            PackageId              = 'opencode-runtime-win32-x64-stable'
            DefinitionId           = 'OpenCodeCli'
            InstallDirectory       = $installDirectory
            PackageFileStagingDirectory = $fileStageDirectory
            PackageInstallStageDirectory = $stageDirectory
            ExistingPackage        = $null
            NpmMaterialization     = [pscustomobject]@{
                Success = $true
                TarballPaths = @($rootTarball, $platformTarball)
            }
            PackageConfig     = [pscustomobject]@{
                DefinitionId                  = 'OpenCodeCli'
                Platform                      = 'windows'
                Architecture                  = 'x64'
                PackageFileStagingRootDirectory = $workspaceDirectory
                PackageAssignmentInventoryFilePath     = $packageStateIndexPath
            }
            Dependencies           = @(
                [pscustomobject]@{
                    DefinitionId = 'NodeRuntime'
                    Commands     = @(
                        [pscustomobject]@{
                            Name = 'npm'
                            Path = $fakeNpmPath
                        }
                    )
                }
            )
            Package                = [pscustomobject]@{
                id           = 'opencode-runtime-win32-x64-stable'
                version      = '1.14.46'
                releaseTrack = 'stable'
                artifactDistributionVariant = 'win32-x64'
                assigned     = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind              = 'npmMaterializedInstallGlobalPackage'
                        installerCommand  = 'npm'
                        packageSpec       = 'opencode-ai@{version}'
                    }
                }
            }
        }

        $installResult = Install-PackageNpmMaterializedInstallGlobalPackage -PackageResult $packageResult

        $installResult.InstallKind | Should -Be 'npmMaterializedInstallGlobalPackage'
        $installResult.InstallerCommandPath | Should -Be ([System.IO.Path]::GetFullPath($fakeNpmPath))
        $installResult.CommandArguments | Should -Contain '--offline'
        $installResult.CommandArguments | Should -Not -Contain 'opencode-ai@1.14.46'
        $installArgumentsText = @($installResult.CommandArguments) -join ' '
        $installArgumentsText | Should -Match 'opencode-ai@file:'
        $installArgumentsText | Should -Match 'opencode-windows-x64@file:'
        @($installResult.MaterializedTarballPaths).Count | Should -Be 2
        @($installResult.MaterializedInstallInputs).Count | Should -Be 2
        Test-Path -LiteralPath (Join-Path $installDirectory 'opencode.cmd') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $installDirectory 'node_modules\opencode-ai\package.json') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $installResult.StagePath | Should -BeFalse
        (Get-Content -LiteralPath $argumentsFile -Raw) | Should -Match 'cache add'
        (Get-Content -LiteralPath $argumentsFile -Raw) | Should -Match 'opencode-windows-x64-1\.14\.46\.tgz'
        (Get-Content -LiteralPath $argumentsFile -Raw) | Should -Match 'install -g'
    }

    It 'does not use the single package-file acquisition path for npmMaterializedInstallGlobalPackage' {
        $package = [pscustomobject]@{
            assigned = [pscustomobject]@{
                install = [pscustomobject]@{
                    kind             = 'npmMaterializedInstallGlobalPackage'
                    installerCommand = 'npm'
                    packageSpec      = 'example@{version}'
                }
            }
        }

        Test-PackagePackageFileAcquisitionRequired -Package $package | Should -BeFalse
    }

}
