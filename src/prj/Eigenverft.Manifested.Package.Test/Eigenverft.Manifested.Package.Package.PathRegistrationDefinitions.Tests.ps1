<#
    Eigenverft.Manifested.Package Package - PATH registration definitions
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - PATH registration definitions' -Body {

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

}
