<#
    Eigenverft.Manifested.Sandbox Package - path registration
#>

. "$PSScriptRoot\Eigenverft.Manifested.Sandbox.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Sandbox Package - path registration' -Body {
    It 'skips PATH registration when mode is none' {
        $installRoot = Join-Path $TestDrive 'path-registration-none'
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
                        mode = 'none'
                    }
                }
            }
            InstallDirectory = $installRoot
            InstallOrigin    = 'PackageInstalled'
        }

        Mock Get-EnvironmentVariableValue {}
        Mock Set-EnvironmentVariableValue {}

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $packageResult.PathRegistration.Status | Should -Be 'Skipped'
        Assert-MockCalled Set-EnvironmentVariableValue -Times 0
    }

    It 'resolves discovered command and app tool paths through shared entry-point helpers' {
        $installRoot = Join-Path $TestDrive 'provided-tool-helper'
        $definition = ConvertTo-TestPsObject @{
            discovery = @{
              presence = @{
                commands = @(
                    @{
                        name         = 'code'
                        relativePath = 'bin/code.cmd'
                        exposeCommand = $true
                    }
                )
                apps = @(
                    @{
                        name         = 'Code'
                        relativePath = 'Code.exe'
                    }
                )
            }
            }
        }

        Resolve-PackagePresenceToolPath -Definition $definition -ToolKind 'commands' -Name 'CODE' -InstallDirectory $installRoot |
            Should -Be (Join-Path $installRoot 'bin\code.cmd')
        Resolve-PackagePresenceToolPath -Definition $definition -ToolKind 'apps' -Name 'code' -InstallDirectory $installRoot |
            Should -Be (Join-Path $installRoot 'Code.exe')
        Resolve-PackagePresenceToolPath -Definition $definition -ToolKind 'commands' -Name 'missing' -InstallDirectory $installRoot |
            Should -BeNullOrEmpty
    }

    It 'registers a command entry point directory in Process and User PATH for user mode' {
        $installRoot = Join-Path $TestDrive 'path-registration-user'
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
            InstallOrigin    = 'PackageInstalled'
        }

        $writes = New-Object System.Collections.Generic.List[object]
        Mock Get-EnvironmentVariableValue {
            param([string]$Name, [string]$Target)
            switch ($Target) {
                'Process' { 'C:\Windows\System32' }
                'User' { 'C:\Users\Test\bin' }
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
        @($packageResult.PathRegistration.UpdatedTargets) | Should -Be @('Process', 'User')
        $packageResult.PathRegistration.RegisteredPath | Should -Be $binDirectory
        @($writes | ForEach-Object { $_.Target }) | Should -Be @('Process', 'User')
        $expectedBinPattern = [regex]::Escape($binDirectory)
        @($writes | Where-Object { $_.Target -eq 'Process' })[0].Value | Should -Match $expectedBinPattern
        @($writes | Where-Object { $_.Target -eq 'User' })[0].Value | Should -Match $expectedBinPattern
    }

    It 'resolves shipped GitRuntime PATH registration to a command shim' {
        [Environment]::SetEnvironmentVariable($script:SourceInventoryEnvVarName, (Join-Path $TestDrive 'missing-inventory.json'), 'Process')

        $installRoot = Join-Path $TestDrive 'path-registration-shipped-git'
        $cmdDirectory = Join-Path $installRoot 'cmd'
        $null = New-Item -ItemType Directory -Path $cmdDirectory -Force
        Write-TestTextFile -Path (Join-Path $cmdDirectory 'git.exe') -Content 'fake git'

        $config = Get-PackageConfig -DefinitionId 'GitRuntime'
        $packageResult = New-PackageResult -PackageConfig $config
        $packageResult = Resolve-PackagePackage -PackageResult $packageResult
        $packageResult.InstallDirectory = $installRoot
        $packageResult.InstallOrigin = 'PackageInstalled'

        Mock Get-EnvironmentVariableValue {}
        Mock Set-EnvironmentVariableValue {}

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $packageResult.PathRegistration.Status | Should -Be 'Registered'
        $packageResult.PathRegistration.SourceKind | Should -Be 'shim'
        $packageResult.PathRegistration.RegisteredPath | Should -Be $config.ShimDirectory
        $packageResult.PathRegistration.SourcePath | Should -Be (Join-Path $config.ShimDirectory 'git.cmd')
        Get-Content -LiteralPath $packageResult.PathRegistration.SourcePath -Raw | Should -Match ([regex]::Escape((Join-Path $cmdDirectory 'git.exe')))
    }

    It 'resolves shipped NodeRuntime PATH registration to command shims' {
        [Environment]::SetEnvironmentVariable($script:SourceInventoryEnvVarName, (Join-Path $TestDrive 'missing-inventory.json'), 'Process')

        $installRoot = Join-Path $TestDrive 'path-registration-shipped-node'
        $null = New-Item -ItemType Directory -Path $installRoot -Force
        Write-TestTextFile -Path (Join-Path $installRoot 'node.exe') -Content 'fake node'
        Write-TestTextFile -Path (Join-Path $installRoot 'npm.cmd') -Content '@echo npm'
        Write-TestTextFile -Path (Join-Path $installRoot 'npx.cmd') -Content '@echo npx'

        $config = Get-PackageConfig -DefinitionId 'NodeRuntime'
        $packageResult = New-PackageResult -PackageConfig $config
        $packageResult = Resolve-PackagePackage -PackageResult $packageResult
        $packageResult.InstallDirectory = $installRoot
        $packageResult.InstallOrigin = 'PackageInstalled'

        Mock Get-EnvironmentVariableValue {}
        Mock Set-EnvironmentVariableValue {}

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $packageResult.PathRegistration.Status | Should -Be 'Registered'
        $packageResult.PathRegistration.SourceKind | Should -Be 'shim'
        $packageResult.PathRegistration.RegisteredPath | Should -Be $config.ShimDirectory
        @($packageResult.PathRegistration.SourceValues) | Should -Be @('node', 'npm', 'npx')
        foreach ($commandName in @('node', 'npm', 'npx')) {
            Test-Path -LiteralPath (Join-Path $config.ShimDirectory "$commandName.cmd") -PathType Leaf | Should -BeTrue
        }
    }

    It 'resolves shipped npm-backed CLI PATH registrations to command shims' {
        [Environment]::SetEnvironmentVariable($script:SourceInventoryEnvVarName, (Join-Path $TestDrive 'missing-inventory.json'), 'Process')

        $cases = @(
            [pscustomobject]@{ DefinitionId = 'CodexCli'; CommandName = 'codex'; CommandFile = 'codex.cmd' }
            [pscustomobject]@{ DefinitionId = 'OpenCodeCli'; CommandName = 'opencode'; CommandFile = 'opencode.cmd' }
            [pscustomobject]@{ DefinitionId = 'CursorCli'; CommandName = 'agent'; CommandFile = 'cursor-agent.cmd' }
        )

        foreach ($case in $cases) {
            $installRoot = Join-Path $TestDrive ("path-registration-shipped-" + $case.DefinitionId)
            $null = New-Item -ItemType Directory -Path $installRoot -Force
            Write-TestTextFile -Path (Join-Path $installRoot $case.CommandFile) -Content '@echo off'

            $config = Get-PackageConfig -DefinitionId $case.DefinitionId
            $packageResult = New-PackageResult -PackageConfig $config
            $packageResult = Resolve-PackagePackage -PackageResult $packageResult
            $packageResult.InstallDirectory = $installRoot
            $packageResult.InstallOrigin = 'PackageInstalled'

            Mock Get-EnvironmentVariableValue {}
            Mock Set-EnvironmentVariableValue {}

            $packageResult = Register-PackagePath -PackageResult $packageResult

            $packageResult.PathRegistration.Status | Should -Be 'Registered'
            $packageResult.PathRegistration.SourceKind | Should -Be 'shim'
            $packageResult.PathRegistration.RegisteredPath | Should -Be $config.ShimDirectory
            $packageResult.PathRegistration.SourcePath | Should -Be (Join-Path $config.ShimDirectory "$($case.CommandName).cmd")
            Test-Path -LiteralPath $packageResult.PathRegistration.SourcePath -PathType Leaf | Should -BeTrue
            Get-Content -LiteralPath $packageResult.PathRegistration.SourcePath -Raw | Should -Match ([regex]::Escape((Join-Path $installRoot $case.CommandFile)))
        }
    }

    It 'resolves shipped PythonRuntime PATH registration to a command shim' {
        [Environment]::SetEnvironmentVariable($script:SourceInventoryEnvVarName, (Join-Path $TestDrive 'missing-inventory.json'), 'Process')

        $installRoot = Join-Path $TestDrive 'path-registration-shipped-python'
        $null = New-Item -ItemType Directory -Path $installRoot -Force
        Write-TestTextFile -Path (Join-Path $installRoot 'python.exe') -Content 'fake python'

        $config = Get-PackageConfig -DefinitionId 'PythonRuntime'
        $packageResult = New-PackageResult -PackageConfig $config
        $packageResult = Resolve-PackagePackage -PackageResult $packageResult
        $packageResult.InstallDirectory = $installRoot
        $packageResult.InstallOrigin = 'PackageInstalled'

        Mock Get-EnvironmentVariableValue {}
        Mock Set-EnvironmentVariableValue {}

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $packageResult.PathRegistration.Status | Should -Be 'Registered'
        $packageResult.PathRegistration.SourceKind | Should -Be 'shim'
        $packageResult.PathRegistration.RegisteredPath | Should -Be $config.ShimDirectory
        $packageResult.PathRegistration.SourcePath | Should -Be (Join-Path $config.ShimDirectory 'python.cmd')
        Get-Content -LiteralPath $packageResult.PathRegistration.SourcePath -Raw | Should -Match ([regex]::Escape((Join-Path $installRoot 'python.exe')))
    }

    It 'resolves shipped PowerShell7 PATH registration to a command shim' {
        [Environment]::SetEnvironmentVariable($script:SourceInventoryEnvVarName, (Join-Path $TestDrive 'missing-inventory.json'), 'Process')

        $installRoot = Join-Path $TestDrive 'path-registration-shipped-ps7'
        $null = New-Item -ItemType Directory -Path $installRoot -Force
        Write-TestTextFile -Path (Join-Path $installRoot 'pwsh.exe') -Content 'fake pwsh'

        $config = Get-PackageConfig -DefinitionId 'PowerShell7'
        $packageResult = New-PackageResult -PackageConfig $config
        $packageResult = Resolve-PackagePackage -PackageResult $packageResult
        $packageResult.InstallDirectory = $installRoot
        $packageResult.InstallOrigin = 'PackageInstalled'

        Mock Get-EnvironmentVariableValue {}
        Mock Set-EnvironmentVariableValue {}

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $packageResult.PathRegistration.Status | Should -Be 'Registered'
        $packageResult.PathRegistration.SourceKind | Should -Be 'shim'
        $packageResult.PathRegistration.RegisteredPath | Should -Be $config.ShimDirectory
        $packageResult.PathRegistration.SourcePath | Should -Be (Join-Path $config.ShimDirectory 'pwsh.cmd')
        Get-Content -LiteralPath $packageResult.PathRegistration.SourcePath -Raw | Should -Match ([regex]::Escape((Join-Path $installRoot 'pwsh.exe')))
    }

    It 'resolves shipped DotNetSdk10 PATH registration to a command shim' {
        [Environment]::SetEnvironmentVariable($script:SourceInventoryEnvVarName, (Join-Path $TestDrive 'missing-inventory.json'), 'Process')

        $installRoot = Join-Path $TestDrive 'path-registration-shipped-dotnet'
        $null = New-Item -ItemType Directory -Path $installRoot -Force
        Write-TestTextFile -Path (Join-Path $installRoot 'dotnet.exe') -Content 'fake dotnet'

        $config = Get-PackageConfig -DefinitionId 'DotNetSdk10'
        $packageResult = New-PackageResult -PackageConfig $config
        $packageResult = Resolve-PackagePackage -PackageResult $packageResult
        $packageResult.InstallDirectory = $installRoot
        $packageResult.InstallOrigin = 'PackageInstalled'

        Mock Get-EnvironmentVariableValue {}
        Mock Set-EnvironmentVariableValue {}

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $packageResult.PathRegistration.Status | Should -Be 'Registered'
        $packageResult.PathRegistration.SourceKind | Should -Be 'shim'
        $packageResult.PathRegistration.RegisteredPath | Should -Be $config.ShimDirectory
        $packageResult.PathRegistration.SourcePath | Should -Be (Join-Path $config.ShimDirectory 'dotnet.cmd')
        Get-Content -LiteralPath $packageResult.PathRegistration.SourcePath -Raw | Should -Match ([regex]::Escape((Join-Path $installRoot 'dotnet.exe')))
    }

    It 'resolves shipped VSCodeRuntime PATH registration to a command shim' {
        [Environment]::SetEnvironmentVariable($script:SourceInventoryEnvVarName, (Join-Path $TestDrive 'missing-inventory.json'), 'Process')

        $installRoot = Join-Path $TestDrive 'path-registration-shipped-vscode'
        $binDirectory = Join-Path $installRoot 'bin'
        $null = New-Item -ItemType Directory -Path $binDirectory -Force
        Write-TestTextFile -Path (Join-Path $binDirectory 'code.cmd') -Content '@echo code'

        $config = Get-PackageConfig -DefinitionId 'VSCodeRuntime'
        $packageResult = New-PackageResult -PackageConfig $config
        $packageResult = Resolve-PackagePackage -PackageResult $packageResult
        $packageResult.InstallDirectory = $installRoot
        $packageResult.InstallOrigin = 'PackageInstalled'

        Mock Get-EnvironmentVariableValue {}
        Mock Set-EnvironmentVariableValue {}

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $packageResult.PathRegistration.Status | Should -Be 'Registered'
        $packageResult.PathRegistration.SourceKind | Should -Be 'shim'
        $packageResult.PathRegistration.RegisteredPath | Should -Be $config.ShimDirectory
        $packageResult.PathRegistration.SourcePath | Should -Be (Join-Path $config.ShimDirectory 'code.cmd')
        Get-Content -LiteralPath $packageResult.PathRegistration.SourcePath -Raw | Should -Match ([regex]::Escape((Join-Path $binDirectory 'code.cmd')))
    }

    It 'resolves shipped LlamaCppRuntime PATH registration to command shims' {
        [Environment]::SetEnvironmentVariable($script:SourceInventoryEnvVarName, (Join-Path $TestDrive 'missing-inventory.json'), 'Process')

        $installRoot = Join-Path $TestDrive 'path-registration-shipped-llama'
        $null = New-Item -ItemType Directory -Path $installRoot -Force
        $commandNames = @('llama-cli', 'llama-server', 'llama-quantize', 'llama-bench', 'llama-tokenize')
        foreach ($commandName in $commandNames) {
            Write-TestTextFile -Path (Join-Path $installRoot "$commandName.exe") -Content "fake $commandName"
        }

        $config = Get-PackageConfig -DefinitionId 'LlamaCppRuntime'
        $packageResult = New-PackageResult -PackageConfig $config
        $packageResult = Resolve-PackagePackage -PackageResult $packageResult
        $packageResult.InstallDirectory = $installRoot
        $packageResult.InstallOrigin = 'PackageInstalled'

        Mock Get-EnvironmentVariableValue {}
        Mock Set-EnvironmentVariableValue {}

        $packageResult = Register-PackagePath -PackageResult $packageResult

        $packageResult.PathRegistration.Status | Should -Be 'Registered'
        $packageResult.PathRegistration.SourceKind | Should -Be 'shim'
        $packageResult.PathRegistration.RegisteredPath | Should -Be $config.ShimDirectory
        @($packageResult.PathRegistration.SourceValues) | Should -Be $commandNames
        foreach ($commandName in $commandNames) {
            Test-Path -LiteralPath (Join-Path $config.ShimDirectory "$commandName.cmd") -PathType Leaf | Should -BeTrue
        }
    }

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
        $shimContent | Should -Match 'Eigenverft\.Manifested\.Sandbox Package Shim'
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
            'rem Eigenverft.Manifested.Sandbox Package Shim'
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
            'rem Eigenverft.Manifested.Sandbox Package Shim'
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

