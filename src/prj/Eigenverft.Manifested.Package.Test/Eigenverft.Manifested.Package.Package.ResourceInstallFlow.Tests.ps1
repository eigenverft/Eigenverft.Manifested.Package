<#
    Eigenverft.Manifested.Package Package - resource install flow
#>

. "$PSScriptRoot\\Eigenverft.Manifested.Package.Package.InstallAndNpm.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - resource install flow' -Body {

    It 'installs a single package file into the configured target-relative path' {
        $rootPath = Join-Path $TestDrive 'package-install-file-route'
        $packageFilePath = Join-Path $rootPath 'package\Qwen3.5-9B-Q6_K.gguf'
        $installDirectory = Join-Path $rootPath 'install'
        Write-TestTextFile -Path $packageFilePath -Content 'gguf-binary'

        $packageResult = [pscustomobject]@{
            PackageId        = 'Qwen35_9B_Q6_K_Model'
            OperationArtifactFilePath = $packageFilePath
            InstallDirectory = $installDirectory
            Package          = [pscustomobject]@{
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
            schemaVersion = '2.0'
            definitionPublication = @{
                publisherId = 'Eigenverft'
                publisherName = 'Eigenverft Module'
                definitionId = 'Qwen35_9B_Q6_K_Model'
                definitionRevision = 1
                publishedAtUtc = '2026-05-13T12:00:00Z'
                definitionSignature = @{
                    kind = 'unsigned'
                    format = 'embedded-json-rsa-sha256-v1'
                    signedContent = 'canonicalDefinitionExcludingSignatureValue'
                }
            }
            display = @{
                default = @{
                    name = 'Qwen 3.5 2B Q8_0'
                    publisher = 'Unsloth'
                    corporation = 'Unsloth AI'
                    summary = 'Quantized GGUF model resource'
                }
            }
            dependency = @{
                requires = @()
            }
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
                        artifactFiles = @{
                            package = @{
                                relativePathTemplate = 'Qwen3.5-9B-Q6_K.gguf'
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
                        }
                    }
                )
                releases = @(
                    @{
                        version = '3.5.0'
                        releaseTracks = @('stable')
                        targetArtifacts = @{
                            'Qwen35_9B_Q6_K_Model-q6-k-stable' = @{
                                artifactId = 'qwen35-9b-q6-k-stable'
                                artifactFiles = @{
                                    package = @{}
                                }
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
                        artifactFileId = 'package'
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

        $artifactFile = $result.ArtifactFiles[0]
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $artifactFile.DefaultDepotPath) -Force
        Write-TestTextFile -Path $artifactFile.DefaultDepotPath -Content 'gguf-binary'

        $result = Resolve-PackageArtifactFiles -PackageResult $result
        $result = Set-PackageAssignedState -PackageResult $result
        $result = Test-PackageAssignedReadiness -PackageResult $result

        $result.ArtifactFiles[0].Preparation.Status | Should -Be 'HydratedFromDefaultPackageDepot'
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
                ArtifactStagingDirectory = $preparationDirectory
                PackageInstallStageDirectory = $installStageDirectory
                ArtifactStagingRootDirectory = $fileStageRoot
                PackageInstallStageRootDirectory = $installStageRoot
            })

        $result.ArtifactStagingDirectory | Should -Be $preparationDirectory
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
        $depotFilePath = Join-Path $defaultPackageDepotDirectory 'default\VSCodeRuntime\stable\2.0.0\win32-x64\VSCode-win32-x64-2.0.0.zip'
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
        Test-Path -LiteralPath $result.ArtifactStagingDirectory -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $result.ArtifactFiles[0].StagingPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $result.PackageInstallStageDirectory -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $packageStateIndexFilePath -PathType Leaf | Should -BeFalse
        Test-Path -LiteralPath $operationHistoryFilePath -PathType Leaf | Should -BeTrue
        $historyDocument = Read-PackageJsonDocument -Path $operationHistoryFilePath
        @($historyDocument.Document.records).Count | Should -Be 1
        $historyDocument.Document.records[0].status | Should -Be 'Failed'
        $historyDocument.Document.records[0].failureReason | Should -Be 'AssignedPackageReadinessFailed'
        $historyDocument.Document.records[0].failedStep | Should -Be 'CheckAssignedReadiness'
        $historyDocument.Document.records[0].artifactPreparation.status | Should -Be 'Prepared'
        $historyDocument.Document.records[0].artifactPreparation.files[0].stagingPath | Should -Be $result.ArtifactFiles[0].StagingPath
        $historyDocument.Document.records[0].depotDistribution.status | Should -Be 'Completed'
        $historyDocument.Document.records[0].depotDistribution.targetCount | Should -Be 1
        $historyDocument.Document.records[0].depotDistribution.allMirrorsComplete | Should -BeTrue
        $historyDocument.Document.records[0].depotDistribution.targets[0].status | Should -Be 'Complete'
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
                        ArtifactFiles = @([pscustomobject]@{ DefaultDepotPath = $dependencyDepotFile })
                        OperationArtifactFilePath = Join-Path $rootPath 'FileStage\PackageManagement.1.4.8.1.nupkg'
                        Assigned = [pscustomobject]@{
                            InstallKind = 'powershellModuleInstaller'
                            OperationArtifactFilePath = Join-Path $rootPath 'FileStage\PackageManagement.1.4.8.1.nupkg'
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
