<#
    Eigenverft.Manifested.Package Package - install and npm
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

function global:Write-TestTarGzipEntry {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Path,

                [Parameter(Mandatory = $true)]
                [string]$EntryName,

                [Parameter(Mandatory = $true)]
                [string]$Content
            )

            $resolvedPath = [System.IO.Path]::GetFullPath($Path)
            $parent = Split-Path -Parent $resolvedPath
            if (-not [string]::IsNullOrWhiteSpace($parent)) {
                $null = New-Item -ItemType Directory -Path $parent -Force
            }

            Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
            $contentBytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
            $header = New-Object byte[] 512
            $nameBytes = [System.Text.Encoding]::ASCII.GetBytes(($EntryName -replace '\\', '/'))
            [Array]::Copy($nameBytes, 0, $header, 0, [Math]::Min($nameBytes.Length, 100))
            $modeBytes = [System.Text.Encoding]::ASCII.GetBytes('0000644')
            [Array]::Copy($modeBytes, 0, $header, 100, $modeBytes.Length)
            $uidBytes = [System.Text.Encoding]::ASCII.GetBytes('0000000')
            [Array]::Copy($uidBytes, 0, $header, 108, $uidBytes.Length)
            [Array]::Copy($uidBytes, 0, $header, 116, $uidBytes.Length)
            $sizeBytes = [System.Text.Encoding]::ASCII.GetBytes(('{0:00000000000}' -f [Convert]::ToString($contentBytes.Length, 8)))
            [Array]::Copy($sizeBytes, 0, $header, 124, $sizeBytes.Length)
            $mtimeBytes = [System.Text.Encoding]::ASCII.GetBytes('00000000000')
            [Array]::Copy($mtimeBytes, 0, $header, 136, $mtimeBytes.Length)
            for ($i = 148; $i -lt 156; $i++) {
                $header[$i] = 32
            }
            $header[156] = [byte][char]'0'
            $magicBytes = [System.Text.Encoding]::ASCII.GetBytes('ustar')
            [Array]::Copy($magicBytes, 0, $header, 257, $magicBytes.Length)

            $checksum = 0
            foreach ($value in $header) {
                $checksum += $value
            }
            $checksumBytes = [System.Text.Encoding]::ASCII.GetBytes(('{0:000000}' -f [Convert]::ToString($checksum, 8)))
            [Array]::Copy($checksumBytes, 0, $header, 148, $checksumBytes.Length)
            $header[154] = 0
            $header[155] = 32

            $paddingLength = (512 - ($contentBytes.Length % 512)) % 512
            $fileStream = [System.IO.File]::Create($resolvedPath)
            $gzipStream = $null
            try {
                $gzipStream = New-Object System.IO.Compression.GZipStream($fileStream, [System.IO.Compression.CompressionMode]::Compress)
                $gzipStream.Write($header, 0, $header.Length)
                $gzipStream.Write($contentBytes, 0, $contentBytes.Length)
                if ($paddingLength -gt 0) {
                    $padding = New-Object byte[] $paddingLength
                    $gzipStream.Write($padding, 0, $padding.Length)
                }
                $zeroBlocks = New-Object byte[] 1024
                $gzipStream.Write($zeroBlocks, 0, $zeroBlocks.Length)
            }
            finally {
                if ($gzipStream) {
                    $gzipStream.Dispose()
                }
                $fileStream.Dispose()
            }
        }

function global:Write-TestNpmPackageTarball {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Path,

                [Parameter(Mandatory = $true)]
                [string]$Name,

                [Parameter(Mandatory = $true)]
                [string]$Version,

                [AllowNull()]
                [hashtable]$Dependencies,

                [AllowNull()]
                [hashtable]$OptionalDependencies,

                [AllowNull()]
                [string[]]$OS,

                [AllowNull()]
                [string[]]$CPU
            )

            $package = [ordered]@{
                name    = $Name
                version = $Version
            }
            if ($Dependencies) {
                $package.dependencies = $Dependencies
            }
            if ($OptionalDependencies) {
                $package.optionalDependencies = $OptionalDependencies
            }
            if ($OS) {
                $package.os = @($OS)
            }
            if ($CPU) {
                $package.cpu = @($CPU)
            }

            Write-TestTarGzipEntry -Path $Path -EntryName 'package/package.json' -Content ($package | ConvertTo-Json -Depth 10 -Compress)
        }

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - install and npm' -Body {

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

    It 'requires package-file acquisition for powershellModuleInstaller' {
        $package = [pscustomobject]@{
            assigned = [pscustomobject]@{
                install = [pscustomobject]@{
                    kind            = 'powershellModuleInstaller'
                    moduleName      = 'PowerShellGet'
                    requiredVersion = '2.2.5'
                }
            }
        }

        Test-PackagePackageFileAcquisitionRequired -Package $package | Should -BeTrue
    }

    It 'resolves paths for powershellModuleInstaller without an install directory' {
        $rootPath = Join-Path $TestDrive 'psmodule-paths'
        $packageResult = [pscustomobject]@{
            PackageFileStagingDirectory = $null
            PackageInstallStageDirectory = $null
            InstallDirectory = $null
            PackageDepotRelativeDirectory = $null
            PackageWorkSlotDirectory = $null
            PackageFilePath = $null
            DefaultPackageDepotFilePath = $null
            PackageConfig = [pscustomobject]@{
                DefinitionId = 'PowerShellGet'
                Definition   = [pscustomobject]@{ id = 'PowerShellGet' }
                PackageFileStagingRootDirectory = Join-Path $rootPath 'FileStage'
                PackageInstallStageRootDirectory = Join-Path $rootPath 'InstStage'
                DefaultPackageDepotDirectory = Join-Path $rootPath 'PkgDepot'
                PreferredTargetInstallRootDirectory = Join-Path $rootPath 'Installed'
                ReleaseTrack = 'stable'
            }
            Package = [pscustomobject]@{
                id           = 'powershellget-psmodule-stable'
                version      = '2.2.5'
                releaseTrack = 'stable'
                artifactDistributionVariant = 'psmodule-any'
                packageFile  = [pscustomobject]@{
                    fileName = 'PowerShellGet.2.2.5.nupkg'
                }
                assigned     = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind            = 'powershellModuleInstaller'
                        moduleName      = 'PowerShellGet'
                        requiredVersion = '2.2.5'
                    }
                }
            }
        }

        $result = Resolve-PackagePaths -PackageResult $packageResult

        $result.InstallDirectory | Should -BeNullOrEmpty
        $result.PackageFilePath | Should -Match 'PowerShellGet\.2\.2\.5\.nupkg$'
        $result.DefaultPackageDepotFilePath | Should -Match 'PkgDepot\\PowerShellGet\\stable\\2\.2\.5\\psmodule-any\\PowerShellGet\.2\.2\.5\.nupkg$'
    }

    It 'invokes powershellModuleInstaller through a full helper script path and staged local repository' {
        $rootPath = Join-Path $TestDrive 'psmodule-helper'
        $packageFilePath = Join-Path $rootPath 'FileStage\Eigenverft.Manifested.Agent.1.20261.39327.nupkg'
        $stageDirectory = Join-Path $rootPath 'InstStage'
        Write-TestTextFile -Path $packageFilePath -Content 'nupkg'

        $invokeCalls = New-Object System.Collections.Generic.List[object]
        Mock Get-PackageWindowsPowerShellPath { Join-Path $rootPath 'WindowsPowerShell\v1.0\powershell.exe' }
        Mock Invoke-PackageInstallerCommand {
            param($PackageResult, $CommandPath, $CommandArguments, $WorkingDirectory, $TimeoutSec, $SuccessExitCodes, $RestartExitCodes, $TargetKind, $InstallerKind, $UiMode, $LogPath, $ElevationMode, $WindowStyle)
            $resultPath = [string]$CommandArguments[([array]::IndexOf($CommandArguments, '-ResultPath') + 1)]
            [pscustomobject]@{
                success = $true
                status = 'Installed'
                installed = $true
                moduleName = 'Eigenverft.Manifested.Agent'
                requiredVersion = '1.20261.39327'
                installedVersion = '1.20261.39327'
                moduleBase = Join-Path $rootPath 'Modules\Eigenverft.Manifested.Agent\1.20261.39327'
                scope = 'CurrentUser'
            } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding UTF8
            $invokeCalls.Add([pscustomobject]@{
                CommandPath = $CommandPath
                CommandArguments = @($CommandArguments)
                WorkingDirectory = $WorkingDirectory
                TimeoutSec = $TimeoutSec
                TargetKind = $TargetKind
                InstallerKind = $InstallerKind
                UiMode = $UiMode
                ElevationMode = $ElevationMode
                WindowStyle = $WindowStyle
            }) | Out-Null
            [pscustomobject]@{
                ExitCode = 0
                RestartRequired = $false
                CommandPath = $CommandPath
                CommandArguments = @($CommandArguments)
                TargetKind = $TargetKind
                InstallerKind = $InstallerKind
                UiMode = $UiMode
            }
        }

        $packageResult = [pscustomobject]@{
            DefinitionId = 'EigenverftManifestedAgent'
            PackageId = 'eigenverft-manifested-agent-psmodule-stable'
            PackageFilePath = $packageFilePath
            PackageInstallStageDirectory = $stageDirectory
            Package = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind = 'powershellModuleInstaller'
                        moduleName = 'Eigenverft.Manifested.Agent'
                        requiredVersion = '1.20261.39327'
                        scope = 'CurrentUser'
                        allowClobber = $true
                        skipPublisherCheck = $false
                        timeoutSec = 600
                    }
                }
            }
        }

        $result = Install-PackagePowerShellModule -PackageResult $packageResult

        $invokeCalls.Count | Should -Be 1
        $invokeCalls[0].CommandArguments | Should -Contain '-File'
        $helperPath = [string]$invokeCalls[0].CommandArguments[([array]::IndexOf($invokeCalls[0].CommandArguments, '-File') + 1)]
        [System.IO.Path]::IsPathRooted($helperPath) | Should -BeTrue
        $invokeCalls[0].WorkingDirectory | Should -Be ([System.IO.Path]::GetFullPath($stageDirectory))
        $invokeCalls[0].TargetKind | Should -Be 'powershellModule'
        $invokeCalls[0].InstallerKind | Should -Be 'powershellModuleInstaller'
        $invokeCalls[0].ElevationMode | Should -Be 'none'
        $invokeCalls[0].WindowStyle | Should -Be 'Hidden'
        Test-Path -LiteralPath (Join-Path $stageDirectory 'Nuget\Eigenverft.Manifested.Agent.1.20261.39327.nupkg') -PathType Leaf | Should -BeTrue
        $result.InstallKind | Should -Be 'powershellModuleInstaller'
        $result.Status | Should -Be 'Applied'
        $result.InstalledVersion | Should -Be '1.20261.39327'
    }

    It 'does not short-circuit powershellModuleInstaller before acquisition' {
        $packageResult = [pscustomobject]@{
            InstallOrigin = $null
            Assigned      = $null
            PackageInstallStageDirectory = Join-Path $TestDrive 'psmodule-check'
            Package       = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind            = 'powershellModuleInstaller'
                        moduleName      = 'PowerShellGet'
                        requiredVersion = '2.2.5'
                    }
                }
            }
        }

        $packageResult = Resolve-PackagePreAssignmentSatisfaction -PackageResult $packageResult

        $packageResult.InstallOrigin | Should -BeNullOrEmpty
        $packageResult.Assigned | Should -BeNullOrEmpty
    }

    It 'discovers and adopts an exact existing PowerShell module when policy allows it' {
        $moduleBase = Join-Path $TestDrive 'Modules\PowerShellGet\2.2.5'
        $inventoryPath = Join-Path $TestDrive 'State\PackageAssignmentInventory.json'
        $packageResult = [pscustomobject]@{
            DefinitionId = 'PowerShellGet'
            PackageId    = 'powershellget-psmodule-stable'
            PackageVersion = '2.2.5'
            ReleaseTrack = 'stable'
            InstallOrigin = $null
            InstallDirectory = $null
            Assigned = $null
            Readiness = $null
            PackageInstallStageDirectory = Join-Path $TestDrive 'psmodule-adopt-stage'
            ExistingPackage = $null
            Ownership = $null
            PackageConfig = ConvertTo-TestPsObject @{
                PackageAssignmentInventoryFilePath = $inventoryPath
                Definition = @{
                    discovery = @{
                      existingInstall = @{
                        enabled = $true
                        searchLocations = @(
                            @{
                                id = 'currentUserPowerShellModule'
                                kind = 'powershellModule'
                                searchOrder = 100
                                name = 'PowerShellGet'
                                requiredVersion = '2.2.5'
                                scope = 'CurrentUser'
                            }
                        )
                        installRootRules = @()
                    }
                    }
                }
            }
            Package = ConvertTo-TestPsObject @{
                id = 'powershellget-psmodule-stable'
                version = '2.2.5'
                releaseTrack = 'stable'
                artifactDistributionVariant = 'psmodule-any'
                readiness = @{
                    files = @()
                    directories = @()
                    commandChecks = @()
                    metadataFiles = @()
                    signatures = @()
                    fileDetails = @()
                    registryChecks = @()
                    powerShellModules = @(
                        @{
                            name = 'PowerShellGet'
                            requiredVersion = '2.2.5'
                            scope = 'CurrentUser'
                        }
                    )
                }
                ownershipPolicy = @{
                    allowAdoptExternal = $true
                    upgradeAdoptedInstall = $false
                    requirePackageOwnership = $false
                }
                assigned = @{
                    install = @{
                        kind = 'powershellModuleInstaller'
                        moduleName = 'PowerShellGet'
                        requiredVersion = '2.2.5'
                        scope = 'CurrentUser'
                    }
                }
            }
        }

        Mock Test-PackagePowerShellModulePresence {
            [pscustomobject]@{
                installed = $true
                moduleInstalled = $true
                status = 'AlreadyInstalled'
                moduleName = 'PowerShellGet'
                requiredVersion = '2.2.5'
                installedVersion = '2.2.5'
                moduleBase = $moduleBase
                scope = 'CurrentUser'
                nugetProviderAvailable = $true
            }
        }

        $packageResult = Find-PackageExistingPackage -PackageResult $packageResult
        $packageResult = Set-PackageExistingPackage -PackageResult $packageResult
        $packageResult = Resolve-PackageExistingPackageDecision -PackageResult $packageResult
        $packageResult = Set-PackageAssignedState -PackageResult $packageResult

        $packageResult.ExistingPackage.SearchKind | Should -Be 'powershellModule'
        $packageResult.ExistingPackage.InstallDirectory | Should -BeNullOrEmpty
        $packageResult.InstallOrigin | Should -Be 'AdoptedExternal'
        $packageResult.Assigned.InstallKind | Should -Be 'powershellModuleInstaller'
        $packageResult.Assigned.Status | Should -Be 'AdoptedExternal'
        $packageResult.Assigned.ModuleBase | Should -Be $moduleBase
    }

    It 'does not adopt PackageManagement when the NuGet provider is missing' {
        $packageResult = [pscustomobject]@{
            DefinitionId = 'PackageManagement'
            PackageInstallStageDirectory = Join-Path $TestDrive 'psmodule-provider-stage'
            PackageConfig = ConvertTo-TestPsObject @{
                Definition = @{
                    discovery = @{
                      existingInstall = @{
                        enabled = $true
                        searchLocations = @(
                            @{
                                id = 'currentUserPowerShellModule'
                                kind = 'powershellModule'
                                searchOrder = 100
                                name = 'PackageManagement'
                                requiredVersion = '1.4.8.1'
                                scope = 'CurrentUser'
                                requireNuGetProvider = $true
                            }
                        )
                        installRootRules = @()
                    }
                    }
                }
            }
            Package = ConvertTo-TestPsObject @{ id = 'package-management-psmodule-stable'; version = '1.4.8.1' }
        }

        Mock Test-PackagePowerShellModulePresence {
            [pscustomobject]@{
                installed = $false
                moduleInstalled = $true
                status = 'NuGetProviderMissing'
                moduleName = 'PackageManagement'
                requiredVersion = '1.4.8.1'
                installedVersion = '1.4.8.1'
                moduleBase = Join-Path $TestDrive 'Modules\PackageManagement\1.4.8.1'
                scope = 'CurrentUser'
                requireNuGetProvider = $true
                nugetProviderAvailable = $false
            }
        }

        $packageResult = Find-PackageExistingPackage -PackageResult $packageResult

        $packageResult.ExistingPackage | Should -BeNullOrEmpty
    }

    It 'keeps package-file acquisition active for adopted PowerShell modules' {
        $packageFilePath = Join-Path $TestDrive 'PowerShellGet.2.2.5.nupkg'
        Set-Content -LiteralPath $packageFilePath -Value 'nupkg' -Encoding UTF8
        $packageResult = [pscustomobject]@{
            ExistingPackage = [pscustomobject]@{
                Decision = 'AdoptExternal'
            }
            Package = ConvertTo-TestPsObject @{
                id = 'powershellget-psmodule-stable'
                assigned = @{
                    install = @{
                        kind = 'powershellModuleInstaller'
                    }
                }
            }
            PackageConfig = ConvertTo-TestPsObject @{
                AllowAcquisitionFallback = $true
            }
            PackageFilePath = $packageFilePath
            AcquisitionPlan = [pscustomobject]@{
                PackageFileRequired = $true
                Candidates = @(
                    [pscustomobject]@{
                        verification = [pscustomobject]@{
                            mode = 'none'
                        }
                    }
                )
            }
            PackageFilePreparation = $null
        }

        $packageResult = Resolve-PackageInstallFile -PackageResult $packageResult

        $packageResult.PackageFilePreparation.Status | Should -Be 'ReusedPackageFile'
    }

    It 'writes adopted PowerShell modules to package inventory without an install directory' {
        $inventoryPath = Join-Path $TestDrive 'State\PackageAssignmentInventory.json'
        $packageResult = [pscustomobject]@{
            DefinitionId = 'PowerShellGet'
            PackageId = 'powershellget-psmodule-stable'
            PackageVersion = '2.2.5'
            InstallOrigin = 'AdoptedExternal'
            InstallDirectory = $null
            Readiness = [pscustomobject]@{ Accepted = $true }
            Ownership = $null
            Dependencies = @()
            PackageConfig = [pscustomobject]@{
                PackageAssignmentInventoryFilePath = $inventoryPath
            }
            Package = [pscustomobject]@{
                releaseTrack = 'stable'
                artifactDistributionVariant = 'psmodule-any'
            }
        }

        Mock Copy-PackageDefinitionToAssignedSnapshot {
            [pscustomobject]@{
                EndpointName = 'moduleDefaults'
                PublisherId = 'Eigenverft'
                PublisherName = 'Eigenverft'
                DefinitionRevision = 1
                PublishedAtUtc = '2026-05-17T12:00:00Z'
                SourceKind = 'moduleLocal'
                SourcePath = 'source.json'
                SourceHash = 'sourcehash'
                CandidatePath = 'candidate.json'
                CandidateHash = 'candidatehash'
                AssignedSnapshotPath = 'assigned.json'
                AssignedSnapshotHash = 'assignedhash'
                ResolvedAtUtc = '2026-05-17T12:00:00Z'
            }
        }

        $packageResult = Update-PackageInventoryRecord -PackageResult $packageResult
        $inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json

        $inventory.records[0].ownershipKind | Should -Be 'AdoptedExternal'
        $inventory.records[0].installDirectory | Should -BeNullOrEmpty
        $packageResult.Ownership.Classification | Should -Be 'AdoptedExternal'
    }

    It 'classifies powershellModuleInstaller assignments as PackageApplied' {
        $packageResult = [pscustomobject]@{
            InstallOrigin = $null
            Assigned = $null
            PackageFilePreparation = [pscustomobject]@{ Success = $true }
            ExistingPackage = $null
            Package = [pscustomobject]@{
                id = 'powershellget-psmodule-stable'
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind            = 'powershellModuleInstaller'
                        moduleName      = 'PowerShellGet'
                        requiredVersion = '2.2.5'
                    }
                }
            }
        }

        Mock Install-PackagePowerShellModule {
            [pscustomobject]@{
                Status = 'Applied'
                InstallKind = 'powershellModuleInstaller'
                TargetKind = 'powershellModule'
                InstallDirectory = $null
                ReusedExisting = $false
            }
        }

        $result = Set-PackageAssignedState -PackageResult $packageResult

        $result.InstallOrigin | Should -Be 'PackageApplied'
        $result.Assigned.InstallKind | Should -Be 'powershellModuleInstaller'
    }

    It 'accepts package-file Authenticode verification without a SHA256 hash' {
        $packageFilePath = Join-Path $TestDrive 'authenticode-package\vc_redist.x64.exe'
        Write-TestTextFile -Path $packageFilePath -Content 'signed installer placeholder'

        Mock Get-AuthenticodeSignature {
            [pscustomobject]@{
                Status            = [System.Management.Automation.SignatureStatus]::Valid
                SignerCertificate = [pscustomobject]@{
                    Subject = 'CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US'
                }
            }
        }

        $verification = [pscustomobject]@{
            mode = 'required'
            authenticode = [pscustomobject]@{
                requireValid    = $true
                subjectContains = 'Microsoft Corporation'
            }
        }

        $result = Test-PackageSavedFile -Path $packageFilePath -Verification $verification

        $result.Accepted | Should -BeTrue
        $result.Status | Should -Be 'AuthenticodePassed'
        $result.SignatureStatus | Should -Be 'Valid'
    }

    It 'validates registry-only machine prerequisites without an install directory' {
        $registryPath = 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'
        $packageResult = [pscustomobject]@{
            InstallDirectory = $null
            Readiness = $null
            PackageConfig = [pscustomobject]@{}
            Package = [pscustomobject]@{
                readiness = [pscustomobject]@{
                    files = @()
                    directories = @()
                    commandChecks = @()
                    metadataFiles = @()
                    signatures = @()
                    fileDetails = @()
                    registryChecks = @(
                        [pscustomobject]@{
                            paths = @($registryPath)
                            valueName = 'Installed'
                            expectedValue = '1'
                        },
                        [pscustomobject]@{
                            paths = @($registryPath)
                            valueName = 'Version'
                            operator = '>='
                            expectedValue = '14.0'
                        }
                    )
                }
            }
        }

        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq $registryPath }
        Mock Get-ItemProperty {
            [pscustomobject]@{
                Installed = 1
                Version   = '14.44.35211.0'
            }
        } -ParameterFilter { $LiteralPath -eq $registryPath }

        $packageResult = Test-PackageAssignedReadiness -PackageResult $packageResult

        $packageResult.Readiness.Accepted | Should -BeTrue
        @($packageResult.Readiness.Registry | ForEach-Object { $_.Status }) | Should -Be @('Ready', 'Ready')
    }

    It 'resolves registry values through the generic execution-engine helper' {
        $registryPath = 'HKLM:\SOFTWARE\Vendor\Product'

        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq $registryPath }
        Mock Get-ItemProperty {
            [pscustomobject]@{
                Version = '1.2.3'
            }
        } -ParameterFilter { $LiteralPath -eq $registryPath -and $Name -eq 'Version' }

        $result = Resolve-RegistryValueFromPaths -Paths @($registryPath) -ValueName 'Version'

        $result.Path | Should -Be $registryPath
        $result.ActualValue | Should -Be '1.2.3'
        $result.Status | Should -Be 'Ready'
    }

    It 'returns missing when no registry candidate path exists' {
        $paths = @(
            'HKLM:\SOFTWARE\Vendor\MissingA',
            'HKLM:\SOFTWARE\Vendor\MissingB'
        )

        Mock Test-Path { $false }

        $result = Resolve-RegistryValueFromPaths -Paths $paths -ValueName 'Version'

        $result.Path | Should -Be $paths[0]
        $result.Paths | Should -Be $paths
        $result.ActualValue | Should -BeNullOrEmpty
        $result.Status | Should -Be 'Missing'
    }

    It 'reads a direct Windows uninstall registry key and resolves display-icon directory' {
        $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++'

        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq $registryPath }
        Mock Get-ItemProperty {
            [pscustomobject]@{
                DisplayName     = 'Notepad++ (64-bit x64)'
                DisplayVersion  = '8.9.4'
                Publisher       = 'Notepad++ Team'
                InstallLocation = ''
                DisplayIcon     = '"C:\Program Files\Notepad++\notepad++.exe",0'
                UninstallString = '"C:\Program Files\Notepad++\uninstall.exe" /S'
            }
        } -ParameterFilter { $LiteralPath -eq $registryPath }

        $entry = Get-WindowsUninstallRegistryEntry -Path $registryPath
        $displayIconDirectory = Resolve-WindowsUninstallRegistryEntryPath -Entry $entry -Source 'displayIconDirectory'
        $uninstallPath = Resolve-WindowsUninstallRegistryEntryPath -Entry $entry -Source 'uninstallString'

        $entry.Status | Should -Be 'Ready'
        $entry.DisplayVersion | Should -Be '8.9.4'
        $displayIconDirectory.Status | Should -Be 'Ready'
        $displayIconDirectory.ResolvedPath | Should -Be ([System.IO.Path]::GetFullPath('C:\Program Files\Notepad++'))
        $uninstallPath.ResolvedPath | Should -Be ([System.IO.Path]::GetFullPath('C:\Program Files\Notepad++\uninstall.exe'))
    }

    It 'resolves windows uninstall registry discovery to an install directory candidate' {
        $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++'
        $installDirectory = Join-Path $TestDrive 'Program Files\Notepad++'
        $displayIconPath = Join-Path $installDirectory 'notepad++.exe'
        $null = New-Item -ItemType Directory -Path $installDirectory -Force

        Mock Test-Path { $false }
        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq $registryPath }
        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq $installDirectory -and $PathType -eq 'Container' }
        Mock Get-ItemProperty {
            [pscustomobject]@{
                DisplayName    = 'Notepad++ (64-bit x64)'
                DisplayVersion = '8.9.4'
                DisplayIcon    = '"' + $displayIconPath + '",0'
            }
        } -ParameterFilter { $LiteralPath -eq $registryPath }

        $packageResult = [pscustomobject]@{
            InstallDirectory = $null
            PackageConfig = ConvertTo-TestPsObject @{
                Definition = @{
                    discovery = @{
                      existingInstall = @{
                        enabled = $true
                        searchLocations = @(
                            [pscustomobject]@{
                                kind = 'windowsUninstallRegistryKey'
                                paths = @($registryPath)
                                installDirectorySource = 'displayIconDirectory'
                            }
                        )
                        installRootRules = @(
                            [pscustomobject]@{
                                match = @{
                                    kind  = 'fileName'
                                    value = 'notepad++'
                                }
                                installRootRelativePath = '..'
                            }
                        )
                    }
                    }
                }
            }
            Package          = [pscustomobject]@{
                id = 'notepad-plus-plus-8.9.4-win-x64'
            }
            ExistingPackage  = $null
        }

        $packageResult = Find-PackageExistingPackage -PackageResult $packageResult

        $packageResult.ExistingPackage.SearchKind | Should -Be 'windowsUninstallRegistryKey'
        $packageResult.ExistingPackage.CandidatePath | Should -Be ([System.IO.Path]::GetFullPath($installDirectory))
        $packageResult.ExistingPackage.InstallDirectory | Should -Be ([System.IO.Path]::GetFullPath($installDirectory))
        $packageResult.ExistingPackage.DiscoveryDetails.RegistryEntry.DisplayName | Should -Be 'Notepad++ (64-bit x64)'
    }

    It 'resolves scanned windows uninstall registry discovery to an install directory candidate' {
        $installDirectory = Join-Path $TestDrive 'Program Files\7-Zip'
        $null = New-Item -ItemType Directory -Path $installDirectory -Force

        Mock Get-WindowsUninstallRegistryEntries {
            @(
                [pscustomobject]@{
                    Path = 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\{11111111-1111-1111-1111-111111111111}'
                    KeyName = '{11111111-1111-1111-1111-111111111111}'
                    Status = 'Ready'
                    DisplayName = 'Other App'
                    Publisher = 'Other'
                    InstallLocation = Join-Path $TestDrive 'Other'
                },
                [pscustomobject]@{
                    Path = 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\{22222222-2222-2222-2222-222222222222}'
                    KeyName = '{22222222-2222-2222-2222-222222222222}'
                    Status = 'Ready'
                    DisplayName = '7-Zip 26.01 (x64)'
                    Publisher = 'Igor Pavlov'
                    InstallLocation = $installDirectory
                }
            )
        }

        $packageResult = [pscustomobject]@{
            InstallDirectory = $null
            PackageConfig = ConvertTo-TestPsObject @{
                Definition = @{
                    discovery = @{
                      existingInstall = @{
                        enabled = $true
                        searchLocations = @(
                            @{
                                kind = 'windowsUninstallRegistrySearch'
                                rootPaths = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
                                displayNamePatterns = @('7-Zip* (x64)*')
                                publisherPatterns = @('Igor Pavlov')
                                installDirectorySource = 'installLocation'
                            }
                        )
                        installRootRules = @()
                    }
                    }
                }
            }
            Package = [pscustomobject]@{
                id = 'sevenzip-msi-win-x64-stable'
                version = '26.01'
            }
            ExistingPackage = $null
        }

        $packageResult = Find-PackageExistingPackage -PackageResult $packageResult

        $packageResult.ExistingPackage.SearchKind | Should -Be 'windowsUninstallRegistrySearch'
        $packageResult.ExistingPackage.InstallDirectory | Should -Be ([System.IO.Path]::GetFullPath($installDirectory))
        $packageResult.ExistingPackage.DiscoveryDetails.RegistryEntry.KeyName | Should -Be '{22222222-2222-2222-2222-222222222222}'
    }

    It 'marks a satisfied machine prerequisite so acquisition and installer execution can be skipped' {
        $packageResult = [pscustomobject]@{
            InstallOrigin = $null
            Assigned      = $null
            Readiness    = $null
            Package       = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind       = 'runInstaller'
                        targetKind = 'machinePrerequisite'
                    }
                }
            }
        }

        Mock Test-PackageAssignedReadiness {
            param([psobject]$PackageResult)
            $PackageResult.Readiness = [pscustomobject]@{
                Accepted      = $true
                Files         = @()
                Directories   = @()
                Commands      = @()
                MetadataFiles = @()
                Signatures    = @()
                FileDetails   = @()
                Registry      = @([pscustomobject]@{ Status = 'Ready' })
            }
            $PackageResult
        }

        $packageResult = Resolve-PackagePreAssignmentSatisfaction -PackageResult $packageResult

        $packageResult.InstallOrigin | Should -Be 'AlreadySatisfied'
        $packageResult.Assigned.Status | Should -Be 'AlreadySatisfied'
        $packageResult.Assigned.TargetKind | Should -Be 'machinePrerequisite'
    }

    It 'runs required-elevation installers with RunAs and quoted log-path arguments' {
        $rootPath = Join-Path $TestDrive 'installer path with space'
        $installerPath = Join-Path $rootPath 'vc_redist.x64.exe'
        $workspacePath = Join-Path $rootPath 'workspace'
        Write-TestTextFile -Path $installerPath -Content 'installer'

        $process = [pscustomobject]@{
            Id       = 42
            ExitCode = 0
        }
        $process | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param([int]$Timeout) $true }
        $process | Add-Member -MemberType ScriptMethod -Name Refresh -Value { }

        $startProcessCalls = New-Object System.Collections.Generic.List[object]
        Mock Test-ProcessElevation { $false }
        Mock Start-Process {
            param(
                [string]$FilePath,
                [object[]]$ArgumentList,
                [string]$WorkingDirectory,
                [switch]$PassThru,
                [string]$Verb
            )
            $startProcessCalls.Add([pscustomobject]@{
                FilePath         = $FilePath
                ArgumentList     = @($ArgumentList)
                WorkingDirectory = $WorkingDirectory
                Verb             = $Verb
            }) | Out-Null
            $process
        }

        $packageResult = [pscustomobject]@{
            PackageFilePath           = $installerPath
            PackageFileStagingDirectory = $workspacePath
            PackageInstallStageDirectory = $workspacePath
            InstallDirectory          = $null
            PackageConfig        = [pscustomobject]@{
                PreferredTargetInstallRootDirectory = $rootPath
                PackageAssignmentInventoryFilePath           = Join-Path (Join-Path $rootPath 'State') 'PackageAssignmentInventory.json'
            }
            Package = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind           = 'runInstaller'
                        targetKind     = 'machinePrerequisite'
                        installerKind  = 'burn'
                        uiMode         = 'quiet'
                        elevation      = 'required'
                        logRelativePath = 'visual-cpp-redist/{timestamp}.log'
                        commandArguments = @('/install', '/quiet', '/norestart', '/log', '{logPath}')
                        successExitCodes = @(0)
                        restartExitCodes = @(3010)
                    }
                }
            }
        }

        $result = Invoke-PackageInstallerProcess -PackageResult $packageResult

        $startProcessCalls.Count | Should -Be 1
        $startProcessCalls[0].Verb | Should -Be 'RunAs'
        $startProcessCalls[0].WorkingDirectory | Should -Be $workspacePath
        $startProcessCalls[0].ArgumentList[-1].StartsWith('"') | Should -BeTrue
        $startProcessCalls[0].ArgumentList[-1].EndsWith('"') | Should -BeTrue
        $result.TargetKind | Should -Be 'machinePrerequisite'
        $result.Elevation.ShouldElevate | Should -BeTrue
        $result.LogPath | Should -Match '\\Logs\\visual-cpp-redist\\[0-9]{8}-[0-9]{6}\.log$'
    }

    It 'runs NSIS installers from PackageInstallStage and appends target directory argument last without quoting' {
        $rootPath = Join-Path $TestDrive 'nsis installer path with space'
        $packageFilePath = Join-Path $rootPath 'file-stage\npp.8.9.4.Installer.x64.exe'
        $installStageDirectory = Join-Path $rootPath 'install-stage'
        $installDirectory = Join-Path $rootPath 'Inst\Notepad++ Target'
        Write-TestTextFile -Path $packageFilePath -Content 'installer'

        $process = [pscustomobject]@{
            Id       = 43
            ExitCode = 0
        }
        $process | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param([int]$Timeout) $true }
        $process | Add-Member -MemberType ScriptMethod -Name Refresh -Value { }

        $startProcessCalls = New-Object System.Collections.Generic.List[object]
        Mock Test-ProcessElevation { $false }
        Mock Start-Process {
            param(
                [string]$FilePath,
                [object[]]$ArgumentList,
                [string]$WorkingDirectory,
                [switch]$PassThru,
                [string]$Verb
            )
            $startProcessCalls.Add([pscustomobject]@{
                FilePath         = $FilePath
                ArgumentList     = @($ArgumentList)
                WorkingDirectory = $WorkingDirectory
                Verb             = $Verb
            }) | Out-Null
            $process
        }

        $packageResult = [pscustomobject]@{
            PackageId                    = 'NotepadPlusPlus'
            PackageFilePath              = $packageFilePath
            PackageFileStagingDirectory  = Split-Path -Parent $packageFilePath
            PackageInstallStageDirectory = $installStageDirectory
            InstallDirectory             = $installDirectory
            PackageConfig                = [pscustomobject]@{}
            Package                      = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind = 'nsisInstaller'
                        elevation = 'none'
                        commandArguments = @('/S', '/noUpdater', '/closeRunningNpp')
                        targetDirectoryArgument = [pscustomobject]@{
                            enabled = $true
                            prefix  = '/D='
                        }
                        successExitCodes = @(0)
                        restartExitCodes = @()
                    }
                }
            }
        }

        $result = Invoke-PackageNsisInstallerProcess -PackageResult $packageResult

        $stagedInstallerPath = Join-Path $installStageDirectory 'npp.8.9.4.Installer.x64.exe'
        $startProcessCalls.Count | Should -Be 1
        $startProcessCalls[0].FilePath | Should -Be $stagedInstallerPath
        $startProcessCalls[0].WorkingDirectory | Should -Be $installStageDirectory
        $startProcessCalls[0].ArgumentList | Should -Be @('/S', '/noUpdater', '/closeRunningNpp', ('/D=' + $installDirectory))
        $startProcessCalls[0].ArgumentList[-1].StartsWith('"') | Should -BeFalse
        Test-Path -LiteralPath $stagedInstallerPath -PathType Leaf | Should -BeTrue
        $result.InstallKind | Should -BeNullOrEmpty
        $result.InstallerKind | Should -Be 'nsis'
    }

    It 'runs MSI installers through system msiexec with staged package and target directory property' {
        $rootPath = Join-Path $TestDrive 'msi installer path with space'
        $packageFilePath = Join-Path $rootPath 'file-stage\7z2601-x64.msi'
        $installStageDirectory = Join-Path $rootPath 'install-stage'
        $installDirectory = Join-Path $rootPath 'Inst\7-Zip Target'
        $msiexecPath = Join-Path $rootPath 'Windows\System32\msiexec.exe'
        Write-TestTextFile -Path $packageFilePath -Content 'msi'
        Write-TestTextFile -Path $msiexecPath -Content 'msiexec'

        $invokeCalls = New-Object System.Collections.Generic.List[object]
        Mock Get-PackageWindowsInstallerExecutablePath { $msiexecPath }
        Mock Invoke-PackageInstallerCommand {
            param($PackageResult, $CommandPath, $CommandArguments, $WorkingDirectory, $TimeoutSec, $SuccessExitCodes, $RestartExitCodes, $TargetKind, $InstallerKind, $UiMode, $LogPath, $ElevationMode, $WindowStyle)
            $invokeCalls.Add([pscustomobject]@{
                CommandPath = $CommandPath
                CommandArguments = @($CommandArguments)
                WorkingDirectory = $WorkingDirectory
                SuccessExitCodes = @($SuccessExitCodes)
                RestartExitCodes = @($RestartExitCodes)
                InstallerKind = $InstallerKind
                ElevationMode = $ElevationMode
            }) | Out-Null
            [pscustomobject]@{ InstallerKind = $InstallerKind }
        }

        $packageResult = [pscustomobject]@{
            PackageId = 'SevenZip'
            PackageFilePath = $packageFilePath
            PackageFileStagingDirectory = Split-Path -Parent $packageFilePath
            PackageInstallStageDirectory = $installStageDirectory
            InstallDirectory = $installDirectory
            PackageConfig = [pscustomobject]@{}
            Package = [pscustomobject]@{
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind = 'msiInstaller'
                        elevation = 'required'
                        uiMode = 'silent'
                        timeoutSec = 600
                        commandArguments = @('/qn', '/norestart')
                        targetDirectoryProperty = [pscustomobject]@{
                            enabled = $true
                            name = 'INSTALLDIR'
                        }
                        successExitCodes = @(0, 3010)
                        restartExitCodes = @(3010)
                    }
                }
            }
        }

        $result = Invoke-PackageMsiInstallerProcess -PackageResult $packageResult

        $stagedInstallerPath = Join-Path $installStageDirectory '7z2601-x64.msi'
        $invokeCalls.Count | Should -Be 1
        $invokeCalls[0].CommandPath | Should -Be $msiexecPath
        $invokeCalls[0].WorkingDirectory | Should -Be $installStageDirectory
        $invokeCalls[0].CommandArguments | Should -Be @('/i', (Format-PackageProcessArgument -Value $stagedInstallerPath), '/qn', '/norestart', (Format-PackageProcessArgument -Value ('INSTALLDIR=' + $installDirectory)))
        $invokeCalls[0].InstallerKind | Should -Be 'msi'
        $invokeCalls[0].ElevationMode | Should -Be 'required'
        $invokeCalls[0].SuccessExitCodes | Should -Contain 3010
        $invokeCalls[0].RestartExitCodes | Should -Contain 3010
        Test-Path -LiteralPath $stagedInstallerPath -PathType Leaf | Should -BeTrue
        $result.InstallerKind | Should -Be 'msi'
    }

    It 'invokes a registry uninstaller and does not append duplicate configured arguments' {
        $uninstallerPath = Join-Path $TestDrive 'uninstall.exe'
        Write-TestTextFile -Path $uninstallerPath -Content 'uninstaller'
        $operation = [pscustomobject]@{
            commandSource = [pscustomobject]@{
                searchLocationId   = 'testRegistry'
                registryValueOrder = @('QuietUninstallString', 'UninstallString')
            }
            commandArguments = @('/S')
            elevation = 'none'
            timeoutSec = 300
            successExitCodes = @(0)
            restartExitCodes = @()
            uiMode = 'silent'
        }
        $packageResult = [pscustomobject]@{
            DefinitionId = 'NotepadPlusPlus'
            InstallDirectory = Join-Path $TestDrive 'npp'
            PackageFilePath = $null
            PackageFileStagingDirectory = Join-Path $TestDrive 'FileStage'
            PackageInstallStageDirectory = Join-Path $TestDrive 'InstStage'
            PackageConfig = [pscustomobject]@{ Definition = [pscustomobject]@{} }
            Package = [pscustomobject]@{}
        }

        $invokeCalls = New-Object System.Collections.Generic.List[object]
        Mock Get-PackageExistingInstallSearchLocationById { [pscustomobject]@{ id = 'testRegistry' } }
        Mock Resolve-PackageExistingUninstallRegistryCandidate {
            [pscustomobject]@{
                RegistryEntry = [pscustomobject]@{
                    QuietUninstallString = ('"{0}" /S' -f $uninstallerPath)
                    UninstallString = $null
                }
            }
        }
        Mock Invoke-PackageInstallerCommand {
            param($PackageResult, $CommandPath, $CommandArguments, $WorkingDirectory, $TimeoutSec, $SuccessExitCodes, $RestartExitCodes, $TargetKind, $InstallerKind, $UiMode, $LogPath, $ElevationMode, $WindowStyle)
            $invokeCalls.Add([pscustomobject]@{
                CommandPath = $CommandPath
                CommandArguments = @($CommandArguments)
                InstallerKind = $InstallerKind
                ElevationMode = $ElevationMode
            }) | Out-Null
        }

        $result = Invoke-PackageRegistryUninstaller -PackageResult $packageResult -Operation $operation -InstallerKind 'nsis'

        $result.Status | Should -Be 'Invoked'
        $invokeCalls.Count | Should -Be 1
        $invokeCalls[0].CommandPath | Should -Be $uninstallerPath
        $invokeCalls[0].CommandArguments | Should -Be @('/S')
        $invokeCalls[0].InstallerKind | Should -Be 'nsis'
    }

    It 'normalizes MSI uninstall registry commands to msiexec x product code' {
        $rootPath = Join-Path $TestDrive 'msi-uninstall'
        $msiexecPath = Join-Path $rootPath 'Windows\System32\msiexec.exe'
        Write-TestTextFile -Path $msiexecPath -Content 'msiexec'
        $productCode = '{12345678-1234-1234-1234-1234567890AB}'
        $operation = [pscustomobject]@{
            commandSource = [pscustomobject]@{
                searchLocationId = 'sevenZipUninstallRegistry'
                registryValueOrder = @('QuietUninstallString', 'UninstallString')
            }
            commandArguments = @('/qn', '/norestart')
            elevation = 'required'
            timeoutSec = 600
            successExitCodes = @(0, 1605, 3010)
            restartExitCodes = @(3010)
            uiMode = 'silent'
        }
        $packageResult = [pscustomobject]@{
            DefinitionId = 'SevenZip'
            InstallDirectory = Join-Path $rootPath '7-Zip'
            PackageFilePath = $null
            PackageFileStagingDirectory = Join-Path $rootPath 'FileStage'
            PackageInstallStageDirectory = Join-Path $rootPath 'InstStage'
            PackageConfig = [pscustomobject]@{ Definition = [pscustomobject]@{} }
            Package = [pscustomobject]@{}
        }

        $invokeCalls = New-Object System.Collections.Generic.List[object]
        Mock Get-PackageExistingInstallSearchLocationById { [pscustomobject]@{ id = 'sevenZipUninstallRegistry' } }
        Mock Resolve-PackageExistingUninstallRegistryCandidate {
            [pscustomobject]@{
                RegistryEntry = [pscustomobject]@{
                    Path = 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\' + $productCode
                    KeyName = $productCode
                    QuietUninstallString = "MsiExec.exe /I$productCode"
                    UninstallString = "MsiExec.exe /I$productCode"
                }
            }
        }
        Mock Get-PackageWindowsInstallerExecutablePath { $msiexecPath }
        Mock Invoke-PackageInstallerCommand {
            param($PackageResult, $CommandPath, $CommandArguments, $WorkingDirectory, $TimeoutSec, $SuccessExitCodes, $RestartExitCodes, $TargetKind, $InstallerKind, $UiMode, $LogPath, $ElevationMode, $WindowStyle)
            $invokeCalls.Add([pscustomobject]@{
                CommandPath = $CommandPath
                CommandArguments = @($CommandArguments)
                InstallerKind = $InstallerKind
                ElevationMode = $ElevationMode
            }) | Out-Null
        }

        $result = Invoke-PackageMsiRegistryUninstaller -PackageResult $packageResult -Operation $operation

        $result.Status | Should -Be 'Invoked'
        $result.ProductCode | Should -Be $productCode
        $invokeCalls.Count | Should -Be 1
        $invokeCalls[0].CommandPath | Should -Be $msiexecPath
        $invokeCalls[0].CommandArguments | Should -Be @('/x', $productCode, '/qn', '/norestart')
        $invokeCalls[0].CommandArguments | Should -Not -Contain '/I'
        $invokeCalls[0].InstallerKind | Should -Be 'msi'
        $invokeCalls[0].ElevationMode | Should -Be 'required'
    }

    It 'refuses MSI removal folder deletion when product code cannot be found' {
        $installDirectory = Join-Path $TestDrive 'missing-msi-uninstaller\App'
        Write-TestTextFile -Path (Join-Path $installDirectory '7z.exe') -Content '7z'
        $packageResult = [pscustomobject]@{
            DefinitionId = 'SevenZip'
            InstallDirectory = $installDirectory
            PackageConfig = [pscustomobject]@{
                PreferredTargetInstallRootDirectory = (Join-Path $TestDrive 'missing-msi-uninstaller')
                Definition = [pscustomobject]@{
                    packageOperations = [pscustomobject]@{
                        removed = [pscustomobject]@{
                            operation = [pscustomobject]@{ kind = 'msiUninstaller' }
                        }
                    }
                }
            }
        }

        Mock Invoke-PackageMsiRegistryUninstaller { [pscustomobject]@{ Status = 'CommandNotFound' } }

        { Invoke-PackageRemovedOperation -PackageResult $packageResult } | Should -Throw '*refusing to delete*'
        Test-Path -LiteralPath $installDirectory | Should -BeTrue
    }

    It 'falls back to tracked install directory removal when an installer uninstall command is missing' {
        $installDirectory = Join-Path $TestDrive 'missing-uninstaller-fallback\App'
        Write-TestTextFile -Path (Join-Path $installDirectory 'app.exe') -Content 'app'
        $packageResult = [pscustomobject]@{
            DefinitionId = 'NotepadPlusPlus'
            InstallDirectory = $installDirectory
            PackageConfig = [pscustomobject]@{
                PreferredTargetInstallRootDirectory = (Join-Path $TestDrive 'missing-uninstaller-fallback')
                Definition = [pscustomobject]@{
                    packageOperations = [pscustomobject]@{
                        removed = [pscustomobject]@{
                            operation = [pscustomobject]@{ kind = 'nsisUninstaller' }
                        }
                    }
                }
            }
        }

        Mock Invoke-PackageRegistryUninstaller { [pscustomobject]@{ Status = 'CommandNotFound' } }

        $result = Invoke-PackageRemovedOperation -PackageResult $packageResult

        $result | Should -Be $packageResult
        Test-Path -LiteralPath $installDirectory | Should -BeFalse
    }

    It 'does not fallback to directory deletion when a found uninstaller fails' {
        $installDirectory = Join-Path $TestDrive 'failing-uninstaller\App'
        Write-TestTextFile -Path (Join-Path $installDirectory 'app.exe') -Content 'app'
        $packageResult = [pscustomobject]@{
            DefinitionId = 'NotepadPlusPlus'
            InstallDirectory = $installDirectory
            PackageConfig = [pscustomobject]@{
                PreferredTargetInstallRootDirectory = (Join-Path $TestDrive 'failing-uninstaller')
                Definition = [pscustomobject]@{
                    packageOperations = [pscustomobject]@{
                        removed = [pscustomobject]@{
                            operation = [pscustomobject]@{ kind = 'nsisUninstaller' }
                        }
                    }
                }
            }
        }

        Mock Invoke-PackageRegistryUninstaller { throw 'uninstaller exit failed' }

        { Invoke-PackageRemovedOperation -PackageResult $packageResult } | Should -Throw '*uninstaller exit failed*'
        Test-Path -LiteralPath $installDirectory | Should -BeTrue
    }

    It 'installs a single package file into the configured target-relative path' {
        $rootPath = Join-Path $TestDrive 'package-install-file-route'
        $packageFilePath = Join-Path $rootPath 'package\Qwen3.5-9B-Q6_K.gguf'
        $installDirectory = Join-Path $rootPath 'install'
        Write-TestTextFile -Path $packageFilePath -Content 'gguf-binary'

        $packageResult = [pscustomobject]@{
            PackageId        = 'Qwen35_9B_Q6_K_Model'
            PackageFilePath  = $packageFilePath
            InstallDirectory = $installDirectory
            Package          = [pscustomobject]@{
                packageFile = [pscustomobject]@{
                    fileName = 'Qwen3.5-9B-Q6_K.gguf'
                }
                assigned = [pscustomobject]@{
                    install = [pscustomobject]@{
                        kind               = 'placePackageFile'
                        targetRelativePath = 'models/Qwen3.5-9B-Q6_K.gguf'
                    }
                }
            }
            ExistingPackage = $null
        }

        $installResult = Install-PackagePackageFile -PackageResult $packageResult

        $installResult.InstallKind | Should -Be 'placePackageFile'
        $installResult.InstalledFilePath | Should -Be (Join-Path $installDirectory 'models\Qwen3.5-9B-Q6_K.gguf')
        Test-Path -LiteralPath $installResult.InstalledFilePath -PathType Leaf | Should -BeTrue
        (Get-Content -LiteralPath $installResult.InstalledFilePath -Raw) | Should -Be 'gguf-binary'
    }

    It 'installs a shipped single-file resource from the default package depot and validates it' {
        $rootPath = Join-Path $TestDrive 'resource-package-flow'
        $packageFileStagingDirectory = Join-Path $rootPath 'workspace'
        $defaultPackageDepotDirectory = Join-Path $rootPath 'default-depot'
        $preferredTargetInstallDirectory = Join-Path $rootPath 'installs'
        $packageStateIndexFilePath = Join-Path $rootPath 'PackageAssignmentInventory.json'
        $definitionDocument = @{
            schemaVersion = '1.6'
            definitionPublication = @{
                publisherId = 'Eigenverft'
                publisherName = 'Eigenverft Module'
                definitionId = 'Qwen35_9B_Q6_K_Model'
                definitionRevision = 1
                publishedAtUtc = '2026-05-13T12:00:00Z'
            }
            display = @{
                default = @{
                    name = 'Qwen 3.5 2B Q8_0'
                    publisher = 'Unsloth'
                    corporation = 'Unsloth AI'
                    summary = 'Quantized GGUF model resource'
                }
            }
            dependencies = @()
            artifacts = @{
                targets = @(
                    @{
                        id = 'Qwen35_9B_Q6_K_Model-q6-k-stable'
                        releaseTrack = 'stable'
                        artifactDistributionVariant = 'q8-0'
                        constraints = @{
                            os = @('windows')
                            cpu = @('x64')
                        }
                        versionSelection = @{
                            strategy = 'latestByVersion'
                            allowPrerelease = $false
                        }
                        acquisitionCandidates = @(
                            @{
                                kind = 'packageDepot'
                                searchOrder = 250
                                verification = @{
                                    mode = 'none'
                                }
                            }
                        )
                    }
                )
                releases = @(
                    @{
                        version = '3.5.0'
                        releaseTracks = @('stable')
                        targetArtifacts = @{
                            'Qwen35_9B_Q6_K_Model-q6-k-stable' = @{
                                artifactId = 'qwen35-9b-q6-k-stable'
                                fileName = 'Qwen3.5-9B-Q6_K.gguf'
                            }
                        }
                    }
                )
                sources = @{
                    huggingFaceDownload = @{
                        kind = 'download'
                        baseUri = 'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/'
                    }
                }
            }
            discovery = @{
                presence = @{
                    files = @('Qwen3.5-9B-Q6_K.gguf')
                    directories = [object[]]@()
                    commands = [object[]]@()
                    apps = [object[]]@()
                    metadataFiles = [object[]]@()
                    signatures = [object[]]@()
                    fileDetails = [object[]]@()
                    registry = [object[]]@()
                    powerShellModules = [object[]]@()
                }
                existingInstall = @{
                    enabled = $false
                    searchLocations = [object[]]@()
                    installRootRules = [object[]]@()
                }
            }
            packageOperations = @{
                policy = @{
                    compatibility = @{
                        checks = @(
                            @{
                                kind = 'physicalOrVideoMemoryGiB'
                                operator = '>='
                                value = 4
                                onFail = 'warn'
                            }
                        )
                    }
                    ownershipPolicy = @{
                        allowAdoptExternal = $false
                        upgradeAdoptedInstall = $false
                        requirePackageOwnership = $false
                    }
                }
                assigned = @{
                    install = @{
                        kind = 'placePackageFile'
                        installDirectory = 'qwen35-2b/{releaseTrack}/{version}/{artifactDistributionVariant}'
                        targetRelativePath = 'Qwen3.5-9B-Q6_K.gguf'
                        pathRegistration = @{
                            mode = 'none'
                        }
                    }
                    readyStateCheck = @{
                        use = 'discovery.presence'
                        require = @{
                            files = $true
                            directories = $false
                            commands = $false
                            apps = $false
                            metadataFiles = $false
                            signatures = $false
                            fileDetails = $false
                            registry = $false
                            powerShellModules = $false
                        }
                    }
                }
                removed = @{
                    policy = @{
                        whenNotInInventory = 'succeed'
                        allowedInventoryOwnershipKinds = @('PackageInstalled')
                        allowUntrackedExternalRemoval = $false
                        removeDependencies = $false
                    }
                    operation = @{
                        kind = 'none'
                    }
                    absenceVerification = @{
                        use = 'discovery.presence'
                        require = @{
                            files = $true
                            directories = $false
                            commands = $false
                            apps = $false
                            metadataFiles = $false
                            signatures = $false
                            fileDetails = $false
                            registry = $false
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
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PackageFileStagingDirectory $packageFileStagingDirectory -DefaultPackageDepotDirectory $defaultPackageDepotDirectory -PreferredTargetInstallDirectory $preferredTargetInstallDirectory -PackageAssignmentInventoryFilePath $packageStateIndexFilePath) -DefinitionDocument $definitionDocument
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $config = Get-PackageConfig -DefinitionId 'Qwen35_9B_Q6_K_Model'
        $result = New-PackageResult -PackageConfig $config
        $result = Resolve-PackagePackage -PackageResult $result
        $result = Resolve-PackagePaths -PackageResult $result
        $result = Build-PackageAcquisitionPlan -PackageResult $result

        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $result.DefaultPackageDepotFilePath) -Force
        Write-TestTextFile -Path $result.DefaultPackageDepotFilePath -Content 'gguf-binary'

        $result = Resolve-PackageInstallFile -PackageResult $result
        $result = Set-PackageAssignedState -PackageResult $result
        $result = Test-PackageAssignedReadiness -PackageResult $result

        $result.PackageFilePreparation.Status | Should -Be 'HydratedFromDefaultPackageDepot'
        $result.Assigned.InstallKind | Should -Be 'placePackageFile'
        $result.Assigned.InstalledFilePath | Should -Be (Join-Path $result.InstallDirectory 'Qwen3.5-9B-Q6_K.gguf')
        Test-Path -LiteralPath $result.Assigned.InstalledFilePath -PathType Leaf | Should -BeTrue
        $result.Readiness.Accepted | Should -BeTrue
    }

    It 'cleans package-specific staging directories after a successful run' {
        $rootPath = Join-Path $TestDrive 'install-preparation-cleanup'
        $fileStageRoot = Join-Path $rootPath 'PackageFileStaging'
        $installStageRoot = Join-Path $rootPath 'PackageInstallStage'
        $preparationDirectory = Join-Path $fileStageRoot 'packages\VSCodeRuntime\stable\2.0.0\win32-x64'
        $installStageDirectory = Join-Path $installStageRoot 'packages\VSCodeRuntime\stable\2.0.0\win32-x64'
        $npmCacheDirectory = Join-Path $rootPath 'Caches\npm\CodexCli\stable\0.130.0\win32-x64'
        Write-TestTextFile -Path (Join-Path $preparationDirectory 'package.zip') -Content 'package'
        Write-TestTextFile -Path (Join-Path $installStageDirectory 'expanded\Code.exe') -Content 'binary'
        Write-TestTextFile -Path (Join-Path $npmCacheDirectory 'cache-entry') -Content 'cache'

        $result = Clear-PackageWorkDirectories -PackageResult ([pscustomobject]@{
                PackageFileStagingDirectory = $preparationDirectory
                PackageInstallStageDirectory = $installStageDirectory
                PackageFileStagingRootDirectory = $fileStageRoot
                PackageInstallStageRootDirectory = $installStageRoot
            })

        $result.PackageFileStagingDirectory | Should -Be $preparationDirectory
        Test-Path -LiteralPath $preparationDirectory | Should -BeFalse
        Test-Path -LiteralPath $installStageDirectory | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fileStageRoot 'packages') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $installStageRoot 'packages') | Should -BeFalse
        Test-Path -LiteralPath $fileStageRoot -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $installStageRoot -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $npmCacheDirectory -PathType Container | Should -BeTrue
    }

    It 'fails before ownership and cleanup when installed package readiness fails' {
        $rootPath = Join-Path $TestDrive 'readiness-failure-preserves-staging'
        $archiveInfo = New-TestPackageArchiveInfo -RootPath $rootPath -Version '2.0.0' -ArchiveFileName 'VSCode-win32-x64-2.0.0.zip'
        $packageFileStagingDirectory = Join-Path $rootPath 'FileStage'
        $packageInstallStageDirectory = Join-Path $rootPath 'InstStage'
        $defaultPackageDepotDirectory = Join-Path $rootPath 'PkgDepot'
        $packageStateIndexFilePath = Join-Path $rootPath 'State\PackageAssignmentInventory.json'
        $operationHistoryFilePath = Join-Path $rootPath 'State\PackageOperationHistory.json'
        $badReadiness = New-TestReadiness -Version '2.0.0'
        $badReadiness.files = @('missing-after-install.exe')
        $definitionDocument = New-TestVSCodeDefinitionDocument -SharedReadiness $badReadiness -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -PackageFileSha256 $archiveInfo.Sha256 -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                    verification = @{
                        mode = 'required'
                    }
                }
            )
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument -PackageFileStagingDirectory $packageFileStagingDirectory -PackageInstallStageDirectory $packageInstallStageDirectory -DefaultPackageDepotDirectory $defaultPackageDepotDirectory -PackageAssignmentInventoryFilePath $packageStateIndexFilePath -PackageOperationHistoryFilePath $operationHistoryFilePath) -DefinitionDocument $definitionDocument
        $depotFilePath = Join-Path $defaultPackageDepotDirectory 'VSCodeRuntime\stable\2.0.0\win32-x64\VSCode-win32-x64-2.0.0.zip'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $depotFilePath) -Force
        Copy-FileToPath -SourcePath $archiveInfo.ZipPath -TargetPath $depotFilePath -Overwrite | Out-Null
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $result = Invoke-PackageDefinitionCommandCore -DefinitionId 'VSCodeRuntime'

        $result.Status | Should -Be 'Failed'
        $result.FailureReason | Should -Be 'AssignedPackageReadinessFailed'
        $result.ErrorMessage | Should -Match 'Package readiness failed'
        @($result.Readiness.FailedChecks).Count | Should -Be 1
        $result.Readiness.FailedChecks[0].Kind | Should -Be 'files'
        Test-Path -LiteralPath $result.PackageFileStagingDirectory -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $result.PackageFilePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $result.PackageInstallStageDirectory -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $packageStateIndexFilePath -PathType Leaf | Should -BeFalse
        Test-Path -LiteralPath $operationHistoryFilePath -PathType Leaf | Should -BeTrue
        $historyDocument = Read-PackageJsonDocument -Path $operationHistoryFilePath
        @($historyDocument.Document.records).Count | Should -Be 1
        $historyDocument.Document.records[0].status | Should -Be 'Failed'
        $historyDocument.Document.records[0].failureReason | Should -Be 'AssignedPackageReadinessFailed'
        $historyDocument.Document.records[0].failedStep | Should -Be 'CheckAssignedReadiness'
        $historyDocument.Document.records[0].packageFilePreparation.status | Should -Be 'HydratedFromDefaultPackageDepot'
        $historyDocument.Document.records[0].packageFilePreparation.packageFilePath | Should -Be $result.PackageFilePath
        $historyDocument.Document.records[0].depotDistribution.status | Should -Be 'Planned'
        $historyDocument.Document.records[0].depotDistribution.skipped | Should -Be 1
    }

    It 'discovers command-based existing installs through Get-ResolvedApplicationPath' {
        $rootPath = Join-Path $TestDrive 'command-discovery-route'
        $installRoot = Join-Path $rootPath 'existing-install'
        $commandPath = Join-Path $installRoot 'bin\code.cmd'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $commandPath) -Force
        Write-TestTextFile -Path (Join-Path $installRoot 'Code.exe') -Content 'fake'
        Write-TestTextFile -Path $commandPath -Content '@echo off'

        $packageResult = [pscustomobject]@{
            InstallDirectory = $null
            ExistingPackage  = $null
            PackageConfig = ConvertTo-TestPsObject @{
                Definition = @{
                    discovery = @{
                      existingInstall = @{
                        enabled = $true
                        searchLocations = @(
                            [pscustomobject]@{
                                kind = 'command'
                                name = 'code'
                            }
                        )
                        installRootRules = @(
                            [pscustomobject]@{
                                match = @{
                                    kind  = 'fileName'
                                    value = 'code.cmd'
                                }
                                installRootRelativePath = '..'
                            }
                        )
                    }
                    }
                }
            }
            Package          = [pscustomobject]@{
                id = 'VSCodeRuntime'
            }
        }

        Mock Get-ResolvedApplicationPath { $commandPath } -ParameterFilter { $CommandName -eq 'code' }

        $packageResult = Find-PackageExistingPackage -PackageResult $packageResult

        Assert-MockCalled Get-ResolvedApplicationPath -Times 1 -ParameterFilter { $CommandName -eq 'code' }
        $packageResult.ExistingPackage.SearchKind | Should -Be 'command'
        $packageResult.ExistingPackage.CandidatePath | Should -Be $commandPath
        $packageResult.ExistingPackage.InstallDirectory | Should -Be ([System.IO.Path]::GetFullPath($installRoot))
    }

    It 'stages PowerShell module dependency nupkg files into the local repository' {
        $rootPath = Join-Path $TestDrive 'psmodule-dependency-local-repo'
        $dependencyDepotFile = Join-Path $rootPath 'PkgDepot\PackageManagement.1.4.8.1.nupkg'
        $nugetDirectory = Join-Path $rootPath 'InstStage\PowerShellGet\Nuget'
        Write-TestTextFile -Path $dependencyDepotFile -Content 'dependency package'

        $packageResult = [pscustomobject]@{
            Dependencies = @(
                [pscustomobject]@{
                    DefinitionId = 'PackageManagement'
                    Result = [pscustomobject]@{
                        DefaultPackageDepotFilePath = $dependencyDepotFile
                        PackageFilePath = Join-Path $rootPath 'FileStage\PackageManagement.1.4.8.1.nupkg'
                        Assigned = [pscustomobject]@{
                            InstallKind = 'powershellModuleInstaller'
                        }
                    }
                }
            )
        }

        $copied = Copy-PackagePowerShellModuleDependencyPackagesToLocalRepository -PackageResult $packageResult -NugetDirectory $nugetDirectory
        $expectedPath = Join-Path $nugetDirectory 'PackageManagement.1.4.8.1.nupkg'

        @($copied).Count | Should -Be 1
        @($copied)[0] | Should -Be ([System.IO.Path]::GetFullPath($expectedPath))
        Test-Path -LiteralPath $expectedPath -PathType Leaf | Should -BeTrue
    }

    It 'routes filesystem package saves through Copy-FileToPath' {
        $sourcePath = Join-Path $TestDrive 'filesystem-save\source.zip'
        $targetPath = Join-Path $TestDrive 'filesystem-save\target.zip'
        Write-TestTextFile -Path $sourcePath -Content 'archive'

        Mock Copy-FileToPath { $TargetPath } -ParameterFilter { $SourcePath -eq $sourcePath -and $TargetPath -eq $targetPath -and $Overwrite }

        $resolvedPath = Save-PackageFilesystemFile -SourcePath $sourcePath -TargetPath $targetPath

        Assert-MockCalled Copy-FileToPath -Times 1 -ParameterFilter { $SourcePath -eq $sourcePath -and $TargetPath -eq $targetPath -and $Overwrite }
        $resolvedPath | Should -Be $targetPath
    }

}


