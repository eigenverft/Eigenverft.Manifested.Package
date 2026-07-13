<#
    Eigenverft.Manifested.Package Package - PATH registration shims
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - PATH registration shims' -Body {

    It 'skips PATH registration for adopted external installs' {
        $installRoot = Join-Path $TestDrive 'path-registration-adopted-external'
        $binDirectory = Join-Path $installRoot 'bin'
        $null = New-Item -ItemType Directory -Path $binDirectory -Force
        Write-TestTextFile -Path (Join-Path $binDirectory 'code.cmd') -Content '@echo off'

        $packageResult = [pscustomobject]@{
            PackageConfig = ConvertTo-TestPsObject @{
                Definition = @{
                    discovery = @{
                      presence = @{
                        commands = @(
                            @{
                                name         = 'code'
                                relativePath = 'bin/code.cmd'
                        exposeCommand = $true
                            }
                        )
                        apps = @()
                    }
                    }
                }
            }
            Package = ConvertTo-TestPsObject @{
                assigned = @{
                    pathRegistration = @{
                        mode   = 'user'
                        source = @{
                            kind  = 'commandEntryPoint'
                            value = 'code'
                        }
                    }
                }
            }
            InstallDirectory = $installRoot
            InstallOrigin    = 'AdoptedExternal'
        }

        Mock Get-EnvironmentVariableValue {}
        Mock Set-EnvironmentVariableValue {}

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $packageResult.PathRegistration.Status | Should -Be 'SkippedNotPackageOwned'
        Assert-MockCalled Set-EnvironmentVariableValue -Times 0
    }

    It 'removes stale Package-owned paths for the same install slot before registering the active path' {
        $oldInstallRoot = Join-Path $TestDrive 'path-registration-stale-owned\old'
        $newInstallRoot = Join-Path $TestDrive 'path-registration-stale-owned\new'
        $oldBinDirectory = Join-Path $oldInstallRoot 'bin'
        $newBinDirectory = Join-Path $newInstallRoot 'bin'
        $null = New-Item -ItemType Directory -Path $oldBinDirectory -Force
        $null = New-Item -ItemType Directory -Path $newBinDirectory -Force
        Write-TestTextFile -Path (Join-Path $newBinDirectory 'code.cmd') -Content '@echo off'

        $packageResult = [pscustomobject]@{
            PackageConfig = ConvertTo-TestPsObject @{
                Definition = @{
                    discovery = @{
                      presence = @{
                        commands = @(
                            @{
                                name         = 'code'
                                relativePath = 'bin/code.cmd'
                        exposeCommand = $true
                            }
                        )
                        apps = @()
                    }
                    }
                }
            }
            Package = ConvertTo-TestPsObject @{
                assigned = @{
                    pathRegistration = @{
                        mode   = 'user'
                        source = @{
                            kind  = 'commandEntryPoint'
                            value = 'code'
                        }
                    }
                }
            }
            ExistingPackage = [pscustomobject]@{
                InstallDirectory = $oldInstallRoot
                Classification   = 'PackageTarget'
                Decision         = 'ReplacePackageOwnedInstall'
            }
            Ownership = [pscustomobject]@{
                InstallSlotId   = 'VSCodeRuntime:stable:win32-x64'
                Classification  = 'PackageTarget'
                OwnershipRecord = [pscustomobject]@{
                    installDirectory = $oldInstallRoot
                    ownershipKind    = 'PackageInstalled'
                }
            }
            InstallDirectory = $newInstallRoot
            InstallOrigin    = 'PackageInstalled'
        }

        $writes = New-Object System.Collections.Generic.List[object]
        Mock Get-EnvironmentVariableValue {
            param([string]$Name, [string]$Target)
            switch ($Target) {
                'Process' { "C:\\Windows\\System32;$oldBinDirectory" }
                'User' { "C:\\Users\\Test\\bin;$oldBinDirectory;C:\\Users\\Test\\ExternalVSCode\\bin" }
                default { $null }
            }
        }
        Mock Set-EnvironmentVariableValue {
            param([string]$Name, [string]$Value, [string]$Target)
            $writes.Add([pscustomobject]@{
                Name   = $Name
                Value  = $Value
                Target = $Target
            }) | Out-Null
        }

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $packageResult.PathRegistration.Status | Should -Be 'Registered'
        @($packageResult.PathRegistration.CleanedTargets) | Should -Be @('Process', 'User')
        $packageResult.PathRegistration.CleanupDirectories | Should -Contain $oldBinDirectory
        @($writes | ForEach-Object { $_.Target }) | Should -Be @('Process', 'User')
        @($writes | Where-Object { $_.Target -eq 'Process' })[0].Value | Should -Not -Match ([regex]::Escape($oldBinDirectory))
        @($writes | Where-Object { $_.Target -eq 'Process' })[0].Value | Should -Match ([regex]::Escape($newBinDirectory))
        @($writes | Where-Object { $_.Target -eq 'User' })[0].Value | Should -Not -Match ([regex]::Escape($oldBinDirectory))
        @($writes | Where-Object { $_.Target -eq 'User' })[0].Value | Should -Match ([regex]::Escape($newBinDirectory))
    }

    It 'registers an install-relative directory in Process and Machine PATH for machine mode' {
        $installRoot = Join-Path $TestDrive 'path-registration-machine'
        $null = New-Item -ItemType Directory -Path $installRoot -Force

        $packageResult = [pscustomobject]@{
            PackageConfig = ConvertTo-TestPsObject @{
                Definition = @{
                    discovery = @{
                      presence = @{
                        commands = @()
                        apps     = @()
                    }
                    }
                }
            }
            Package = ConvertTo-TestPsObject @{
                assigned = @{
                    pathRegistration = @{
                        mode   = 'machine'
                        source = @{
                            kind  = 'installRelativeDirectory'
                            value = '.'
                        }
                    }
                }
            }
            InstallDirectory = $installRoot
            InstallOrigin    = 'PackageInstalled'
        }

        $writes = New-Object System.Collections.Generic.List[object]
        Mock Get-EnvironmentVariableValue {
            param([string]$Name, [string]$Target)
            switch ($Target) {
                'Process' { 'C:\Windows\System32' }
                'Machine' { 'C:\Program Files\Common Files' }
                default { $null }
            }
        }
        Mock Set-EnvironmentVariableValue {
            param([string]$Name, [string]$Value, [string]$Target)
            $writes.Add([pscustomobject]@{
                Name   = $Name
                Value  = $Value
                Target = $Target
            }) | Out-Null
        }

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $packageResult.PathRegistration.Status | Should -Be 'Registered'
        @($packageResult.PathRegistration.UpdatedTargets) | Should -Be @('Process', 'Machine')
        $packageResult.PathRegistration.RegisteredPath | Should -Be $installRoot
        @($writes | ForEach-Object { $_.Target }) | Should -Be @('Process', 'Machine')
    }

    It 'creates a command shim and registers the shim directory' {
        $installRoot = Join-Path $TestDrive 'path-registration-shim'
        $shimDirectory = Join-Path $TestDrive 'Shims'
        $null = New-Item -ItemType Directory -Path $installRoot -Force
        Write-TestTextFile -Path (Join-Path $installRoot 'code.cmd') -Content '@echo off'

        $packageResult = [pscustomobject]@{
            PackageConfig = ConvertTo-TestPsObject @{
                DefinitionId = 'VSCodeRuntime'
                ShimDirectory = $shimDirectory
                Definition = @{
                    discovery = @{
                      presence = @{
                        commands = @(
                            @{
                                name         = 'code'
                                relativePath = 'code.cmd'
                                exposeCommand = $true
                            }
                        )
                        apps     = @()
                    }
                    }
                }
            }
            Package = ConvertTo-TestPsObject @{
                assigned = @{
                    pathRegistration = @{
                        mode   = 'user'
                        source = @{
                            kind = 'shim'
                            use = 'discovery.presence.commands'
                        }
                    }
                }
            }
            DefinitionId      = 'VSCodeRuntime'
            InstallDirectory = $installRoot
            InstallOrigin    = 'PackageInstalled'
        }

        Mock Get-EnvironmentVariableValue {}
        Mock Set-EnvironmentVariableValue {}

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $expectedShimPath = Join-Path $shimDirectory 'code.cmd'
        $packageResult.PathRegistration.Status | Should -Be 'Registered'
        $packageResult.PathRegistration.SourceKind | Should -Be 'shim'
        $packageResult.PathRegistration.SourcePath | Should -Be $expectedShimPath
        $packageResult.PathRegistration.RegisteredPath | Should -Be $shimDirectory
        Test-Path -LiteralPath $expectedShimPath -PathType Leaf | Should -BeTrue
        $shimContent = Get-Content -LiteralPath $expectedShimPath -Raw
        $shimContent | Should -Match 'Eigenverft\.Manifested\.Package Package Shim'
        $shimContent | Should -Match 'definitionId=VSCodeRuntime'
        $shimContent | Should -Match ([regex]::Escape((Join-Path $installRoot 'code.cmd')))
    }

    It 'reads Package command shim ownership metadata' {
        $installRoot = Join-Path $TestDrive 'path-registration-shim-metadata'
        $shimDirectory = Join-Path $TestDrive 'ShimMetadata'
        $null = New-Item -ItemType Directory -Path $installRoot -Force
        $targetPath = Join-Path $installRoot 'code.cmd'
        Write-TestTextFile -Path $targetPath -Content '@echo off'

        $packageResult = [pscustomobject]@{
            PackageConfig = ConvertTo-TestPsObject @{
                DefinitionId = 'VSCodeRuntime'
                ShimDirectory = $shimDirectory
                Definition = @{
                    discovery = @{
                      presence = @{
                        commands = @(
                            @{
                                name         = 'code'
                                relativePath = 'code.cmd'
                                exposeCommand = $true
                            }
                        )
                        apps     = @()
                    }
                    }
                }
            }
            Package = ConvertTo-TestPsObject @{
                assigned = @{
                    pathRegistration = @{
                        mode   = 'user'
                        source = @{
                            kind = 'shim'
                            use = 'discovery.presence.commands'
                        }
                    }
                }
            }
            DefinitionId      = 'VSCodeRuntime'
            InstallDirectory = $installRoot
            InstallOrigin    = 'PackageInstalled'
        }

        Mock Get-EnvironmentVariableValue {}
        Mock Set-EnvironmentVariableValue {}

        $packageResult = Register-PackagePath -PackageResult $packageResult
        $shimMetadata = Get-PackageCommandShimMetadata -ShimPath $packageResult.PathRegistration.SourcePath

        $shimMetadata.Exists | Should -BeTrue
        $shimMetadata.IsPackageShim | Should -BeTrue
        $shimMetadata.DefinitionId | Should -Be 'VSCodeRuntime'
        $shimMetadata.CommandName | Should -Be 'code'
        $shimMetadata.TargetPath | Should -Be ([System.IO.Path]::GetFullPath($targetPath))
    }

    It 'does not overwrite a non-Package-owned command shim' {
        $installRoot = Join-Path $TestDrive 'path-registration-shim-collision'
        $shimDirectory = Join-Path $TestDrive 'ShimCollision'
        $null = New-Item -ItemType Directory -Path $installRoot -Force
        Write-TestTextFile -Path (Join-Path $installRoot 'code.cmd') -Content '@echo off'
        Write-TestTextFile -Path (Join-Path $shimDirectory 'code.cmd') -Content '@echo foreign'

        $packageResult = [pscustomobject]@{
            PackageConfig = ConvertTo-TestPsObject @{
                DefinitionId = 'VSCodeRuntime'
                ShimDirectory = $shimDirectory
                Definition = @{
                    discovery = @{
                      presence = @{
                        commands = @(
                            @{
                                name         = 'code'
                                relativePath = 'code.cmd'
                                exposeCommand = $true
                            }
                        )
                        apps     = @()
                    }
                    }
                }
            }
            Package = ConvertTo-TestPsObject @{
                assigned = @{
                    pathRegistration = @{
                        mode   = 'user'
                        source = @{
                            kind = 'shim'
                            use = 'discovery.presence.commands'
                        }
                    }
                }
            }
            DefinitionId      = 'VSCodeRuntime'
            InstallDirectory = $installRoot
            InstallOrigin    = 'PackageInstalled'
        }

        { Register-PackagePath -PackageResult $packageResult } | Should -Throw '*not owned*'
    }

    It 'does not overwrite a command shim owned by another package definition' {
        $installRoot = Join-Path $TestDrive 'path-registration-shim-package-collision'
        $shimDirectory = Join-Path $TestDrive 'ShimPackageCollision'
        $null = New-Item -ItemType Directory -Path $installRoot -Force
        $targetPath = Join-Path $installRoot 'code.cmd'
        $otherTargetPath = Join-Path $installRoot 'other-code.cmd'
        Write-TestTextFile -Path $targetPath -Content '@echo off'
        Write-TestTextFile -Path $otherTargetPath -Content '@echo other'

        $existingShimContent = @(
            '@echo off'
            'rem Eigenverft.Manifested.Package Package Shim'
            'rem definitionId=OtherDefinition'
            'rem commandName=code'
            "rem targetPath=$otherTargetPath"
            "call `"$otherTargetPath`" %*"
            'exit /b %ERRORLEVEL%'
        ) -join "`r`n"
        Write-TestTextFile -Path (Join-Path $shimDirectory 'code.cmd') -Content $existingShimContent

        $packageResult = [pscustomobject]@{
            PackageConfig = ConvertTo-TestPsObject @{
                DefinitionId = 'VSCodeRuntime'
                ShimDirectory = $shimDirectory
                Definition = @{
                    discovery = @{
                      presence = @{
                        commands = @(
                            @{
                                name         = 'code'
                                relativePath = 'code.cmd'
                                exposeCommand = $true
                            }
                        )
                        apps     = @()
                    }
                    }
                }
            }
            Package = ConvertTo-TestPsObject @{
                assigned = @{
                    pathRegistration = @{
                        mode   = 'user'
                        source = @{
                            kind = 'shim'
                            use = 'discovery.presence.commands'
                        }
                    }
                }
            }
            DefinitionId      = 'VSCodeRuntime'
            InstallDirectory = $installRoot
            InstallOrigin    = 'PackageInstalled'
        }

        { Register-PackagePath -PackageResult $packageResult } | Should -Throw "*already owned by definition 'OtherDefinition'*"

        $shimContent = Get-Content -LiteralPath (Join-Path $shimDirectory 'code.cmd') -Raw
        $shimContent | Should -Match ([regex]::Escape($otherTargetPath))
        $shimContent | Should -Not -Match ([regex]::Escape($targetPath))
    }

    It 'updates an owned command shim when the command target changes' {
        $oldInstallRoot = Join-Path $TestDrive 'path-registration-shim-owned-update\old'
        $newInstallRoot = Join-Path $TestDrive 'path-registration-shim-owned-update\new'
        $shimDirectory = Join-Path $TestDrive 'ShimOwnedUpdate'
        $null = New-Item -ItemType Directory -Path $oldInstallRoot -Force
        $null = New-Item -ItemType Directory -Path $newInstallRoot -Force
        $oldTargetPath = Join-Path $oldInstallRoot 'code.cmd'
        $newTargetPath = Join-Path $newInstallRoot 'code.cmd'
        Write-TestTextFile -Path $oldTargetPath -Content '@echo old'
        Write-TestTextFile -Path $newTargetPath -Content '@echo new'

        $existingShimContent = @(
            '@echo off'
            'rem Eigenverft.Manifested.Package Package Shim'
            'rem definitionId=VSCodeRuntime'
            'rem commandName=code'
            "rem targetPath=$oldTargetPath"
            "call `"$oldTargetPath`" %*"
            'exit /b %ERRORLEVEL%'
        ) -join "`r`n"
        Write-TestTextFile -Path (Join-Path $shimDirectory 'code.cmd') -Content $existingShimContent

        $packageResult = [pscustomobject]@{
            PackageConfig = ConvertTo-TestPsObject @{
                DefinitionId = 'VSCodeRuntime'
                ShimDirectory = $shimDirectory
                Definition = @{
                    discovery = @{
                      presence = @{
                        commands = @(
                            @{
                                name         = 'code'
                                relativePath = 'code.cmd'
                                exposeCommand = $true
                            }
                        )
                        apps     = @()
                    }
                    }
                }
            }
            Package = ConvertTo-TestPsObject @{
                assigned = @{
                    pathRegistration = @{
                        mode   = 'user'
                        source = @{
                            kind = 'shim'
                            use = 'discovery.presence.commands'
                        }
                    }
                }
            }
            DefinitionId      = 'VSCodeRuntime'
            InstallDirectory = $newInstallRoot
            InstallOrigin    = 'PackageInstalled'
        }

        Mock Get-EnvironmentVariableValue {}
        Mock Set-EnvironmentVariableValue {}

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $shimContent = Get-Content -LiteralPath $packageResult.PathRegistration.SourcePath -Raw
        $shimContent | Should -Match ([regex]::Escape($newTargetPath))
        $shimContent | Should -Not -Match ([regex]::Escape($oldTargetPath))
    }

    It 'cleans the old direct command directory when switching to shim PATH registration' {
        $installRoot = Join-Path $TestDrive 'path-registration-shim-migration'
        $shimDirectory = Join-Path $TestDrive 'ShimMigration'
        $null = New-Item -ItemType Directory -Path $installRoot -Force
        Write-TestTextFile -Path (Join-Path $installRoot 'codex.cmd') -Content '@echo off'

        $packageResult = [pscustomobject]@{
            PackageConfig = ConvertTo-TestPsObject @{
                DefinitionId = 'CodexCli'
                ShimDirectory = $shimDirectory
                Definition = @{
                    discovery = @{
                      presence = @{
                        commands = @(
                            @{
                                name         = 'codex'
                                relativePath = 'codex.cmd'
                                exposeCommand = $true
                            }
                        )
                        apps     = @()
                    }
                    }
                }
            }
            Package = ConvertTo-TestPsObject @{
                assigned = @{
                    pathRegistration = @{
                        mode   = 'user'
                        source = @{
                            kind = 'shim'
                            use = 'discovery.presence.commands'
                        }
                    }
                }
            }
            DefinitionId      = 'CodexCli'
            InstallDirectory = $installRoot
            InstallOrigin    = 'PackageInstalled'
        }

        $writes = New-Object System.Collections.Generic.List[object]
        Mock Get-EnvironmentVariableValue {
            param([string]$Name, [string]$Target)
            switch ($Target) {
                'Process' { "C:\Windows\System32;$installRoot" }
                'User' { "C:\Users\Test\bin;$installRoot" }
                default { $null }
            }
        }
        Mock Set-EnvironmentVariableValue {
            param([string]$Name, [string]$Value, [string]$Target)
            $writes.Add([pscustomobject]@{
                Name   = $Name
                Value  = $Value
                Target = $Target
            }) | Out-Null
        }

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $packageResult.PathRegistration.RegisteredPath | Should -Be $shimDirectory
        $packageResult.PathRegistration.CleanupDirectories | Should -Contain $installRoot
        @($packageResult.PathRegistration.CleanedTargets) | Should -Be @('Process', 'User')
        @($writes | Where-Object { $_.Target -eq 'Process' })[0].Value | Should -Not -Match ([regex]::Escape($installRoot))
        @($writes | Where-Object { $_.Target -eq 'Process' })[0].Value | Should -Match ([regex]::Escape($shimDirectory))
    }

}
