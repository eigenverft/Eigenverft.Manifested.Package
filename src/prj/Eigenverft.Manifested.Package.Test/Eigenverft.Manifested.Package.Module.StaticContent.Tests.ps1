<#
    Eigenverft.Manifested.Package module static-content guards.
#>

Describe 'Eigenverft.Manifested.Package module static content' {
    BeforeAll {
        $script:ModuleProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\Eigenverft.Manifested.Package') -ErrorAction Stop).Path
        $script:RepositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..') -ErrorAction Stop).Path
    }

    It 'ships JSON documents parseable by Windows PowerShell 5.1' {
        $jsonPaths = @(
            Get-ChildItem -Path $script:ModuleProjectRoot -Recurse -File -Filter '*.json' |
                Sort-Object FullName |
                Select-Object -ExpandProperty FullName
        )

        $jsonPaths.Count | Should -BeGreaterThan 0

        $trailingCommaMatches = @(
            foreach ($jsonPath in $jsonPaths) {
                $rawContent = Get-Content -LiteralPath $jsonPath -Raw
                if ($rawContent -match ',\s*[\}\]]') {
                    $jsonPath
                }
            }
        )
        $trailingCommaMatches | Should -BeNullOrEmpty

        $windowsPowerShellPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $windowsPowerShellPath -PathType Leaf)) {
            return
        }

        $pathListPath = Join-Path $TestDrive 'module-json-paths.txt'
        $parserPath = Join-Path $TestDrive 'Test-ModuleJsonWithWindowsPowerShell.ps1'
        $jsonPaths | Set-Content -LiteralPath $pathListPath -Encoding UTF8

        @'
param(
    [Parameter(Mandatory = $true)]
    [string]$PathListPath
)

$ErrorActionPreference = 'Stop'
$failures = @()

foreach ($jsonPath in @(Get-Content -LiteralPath $PathListPath)) {
    try {
        Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json | Out-Null
    }
    catch {
        $failures += '{0}: {1}' -f $jsonPath, $_.Exception.Message
    }
}

if ($failures.Count -gt 0) {
    $failures
    exit 1
}

exit 0
'@ | Set-Content -LiteralPath $parserPath -Encoding UTF8

        $output = & $windowsPowerShellPath -NoProfile -ExecutionPolicy Bypass -File $parserPath -PathListPath $pathListPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
    }

    It 'routes the command bootstrap through the adjacent PowerShell script' {
        $bootstrapCommandPath = Join-Path $script:ModuleProjectRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.cmd'
        $content = Get-Content -LiteralPath $bootstrapCommandPath -Raw

        $content | Should -Match 'powershell\.exe\s+-NoLogo\s+-NoProfile\s+-ExecutionPolicy\s+Bypass\s+-NoExit\s+-File\s+"%~dp0Eigenverft\.Manifested\.Package\.Bootstrap\.ps1"\s+%\*'
        $content | Should -Match 'exit /b %ERRORLEVEL%'
    }

    It 'keeps the complete offline bootstrap bundle in one Eigenverft artifact directory' {
        $definitionPath = Join-Path $script:ModuleProjectRoot 'Endpoint\Defaults\Eigenverft\EigenverftManifestedPackage.json'
        $definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
        $target = $definition.artifacts.targets | Where-Object { $_.id -eq 'EigenverftManifestedPackage-psmodule-stable' } | Select-Object -First 1
        $releaseArtifact = $definition.artifacts.releases[0].targetArtifacts.'EigenverftManifestedPackage-psmodule-stable'
        $expectedIds = @('package', 'packageManagementPackage', 'powerShellGetPackage', 'bootstrapCommand', 'bootstrapPowerShell')

        @($target.artifactFiles.PSObject.Properties).Count | Should -Be $expectedIds.Count
        @($releaseArtifact.artifactFiles.PSObject.Properties).Count | Should -Be $expectedIds.Count
        foreach ($artifactId in $expectedIds) {
            $target.artifactFiles.PSObject.Properties.Name | Should -Contain $artifactId
            $releaseArtifact.artifactFiles.PSObject.Properties.Name | Should -Contain $artifactId
            $relativePath = [string]$target.artifactFiles.$artifactId.relativePathTemplate
            [System.IO.Path]::GetFileName($relativePath) | Should -Be $relativePath
        }

        $bootstrapScriptPath = Join-Path $script:ModuleProjectRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.ps1'
        $bootstrapCommandPath = Join-Path $script:ModuleProjectRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.cmd'
        (Get-FileHash -LiteralPath $bootstrapScriptPath -Algorithm SHA256).Hash.ToLowerInvariant() |
            Should -Be ([string]$releaseArtifact.artifactFiles.bootstrapPowerShell.contentHash.value)
        (Get-FileHash -LiteralPath $bootstrapCommandPath -Algorithm SHA256).Hash.ToLowerInvariant() |
            Should -Be ([string]$releaseArtifact.artifactFiles.bootstrapCommand.contentHash.value)

        $bootstrapContent = Get-Content -LiteralPath $bootstrapScriptPath -Raw
        $bootstrapContent | Should -Match 'function Get-BootstrapNupkgMetadata'
        $bootstrapContent | Should -Match 'function Find-LatestInstalledBootstrapModule'
        $bootstrapContent | Should -Match 'function Install-BootstrapPackageManagementSeed'
        $bootstrapContent | Should -Match 'Import-Module -Name \$packageCheck\.Path -Force -DisableNameChecking -ErrorAction Stop'
        $bootstrapContent | Should -Match 'Write-Host \(Get-PackageVersion\)'
        foreach ($packageArtifactId in @('package', 'packageManagementPackage', 'powerShellGetPackage')) {
            $packageFile = ([string]$target.artifactFiles.$packageArtifactId.relativePathTemplate).Replace('{version}', [string]$definition.artifacts.releases[0].version)
            $packageHash = [string]$releaseArtifact.artifactFiles.$packageArtifactId.contentHash.value
            $bootstrapContent | Should -Not -Match ([regex]::Escape($packageFile))
            $bootstrapContent | Should -Not -Match ([regex]::Escape($packageHash))
        }
    }

    It 'disables name checking only on repository-owned explicit imports of this module' {
        $bootstrapContent = Get-Content -LiteralPath (Join-Path $script:ModuleProjectRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.ps1') -Raw
        $proxyBootstrapContent = Get-Content -LiteralPath (Join-Path $script:ModuleProjectRoot 'Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.InitializeProxyAccessProfile.ps1') -Raw
        $iwrBootstrapContent = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'iwr\bootstrapper.ps1') -Raw

        $bootstrapContent | Should -Match 'Import-Module -Name \$packageCheck\.Path -Force -DisableNameChecking -ErrorAction Stop'
        $proxyBootstrapContent | Should -Match 'Import-Module \$_\.Name -MinimumVersion \$_\.Version -Force -DisableNameChecking'
        $iwrBootstrapContent | Should -Match 'Import-Module \$_\.Name -MinimumVersion \$_\.Version -Force -DisableNameChecking'
    }

    It 'reports every missing package when the offline bootstrap bundle is incomplete' {
        $windowsPowerShellPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $windowsPowerShellPath -PathType Leaf)) {
            return
        }

        $bootstrapScriptPath = Join-Path $script:ModuleProjectRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.ps1'
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = @(& $windowsPowerShellPath -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $bootstrapScriptPath -ValidateOnly 2>&1)
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        $LASTEXITCODE | Should -Be 1
        $text = $output -join [Environment]::NewLine
        $text | Should -Match 'packageManagementPackage'
        $text | Should -Match 'powerShellGetPackage'
        $text | Should -Match "artifact 'package'"
    }

    It 'selects the highest materialized nupkg version from package metadata' {
        $windowsPowerShellPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $windowsPowerShellPath -PathType Leaf)) {
            return
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $bundlePath = Join-Path $TestDrive 'bootstrap-multiple-versions'
        $null = New-Item -ItemType Directory -Path $bundlePath -Force
        $bootstrapScriptPath = Join-Path $script:ModuleProjectRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.ps1'
        $bundleScriptPath = Join-Path $bundlePath 'Eigenverft.Manifested.Package.Bootstrap.ps1'
        Copy-Item -LiteralPath $bootstrapScriptPath -Destination $bundleScriptPath

        function New-BootstrapTestNupkg {
            param(
                [string]$Id,
                [string]$Version,
                [bool]$IncludeInstallerHelper = $false
            )

            $layoutPath = Join-Path $TestDrive ('nupkg-' + [Guid]::NewGuid().ToString('N'))
            $null = New-Item -ItemType Directory -Path $layoutPath -Force
            @"
<?xml version="1.0" encoding="utf-8"?>
<package><metadata><id>$Id</id><version>$Version</version></metadata></package>
"@ | Set-Content -LiteralPath (Join-Path $layoutPath ($Id + '.nuspec')) -Encoding UTF8
            if ($IncludeInstallerHelper) {
                $helperPath = Join-Path $layoutPath 'Support\Package\Execution\Invoke-PackagePowerShellModuleInstall.ps1'
                $null = New-Item -ItemType Directory -Path (Split-Path -Parent $helperPath) -Force
                'param()' | Set-Content -LiteralPath $helperPath -Encoding UTF8
            }

            $packagePath = Join-Path $bundlePath ("$Id.$Version.nupkg")
            [System.IO.Compression.ZipFile]::CreateFromDirectory($layoutPath, $packagePath)
        }

        New-BootstrapTestNupkg -Id 'PackageManagement' -Version '1.4.8.1'
        New-BootstrapTestNupkg -Id 'PackageManagement' -Version '1.5.0'
        New-BootstrapTestNupkg -Id 'PowerShellGet' -Version '2.2.5'
        New-BootstrapTestNupkg -Id 'Eigenverft.Manifested.Package' -Version '1.0.0' -IncludeInstallerHelper $true
        New-BootstrapTestNupkg -Id 'Eigenverft.Manifested.Package' -Version '2.0.0' -IncludeInstallerHelper $true

        $output = @(& $windowsPowerShellPath -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $bundleScriptPath -ValidateOnly 2>&1)

        $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
        $text = $output -join [Environment]::NewLine
        $text | Should -Match 'Selected PackageManagement 1\.5\.0 '
        $text | Should -Match 'Selected Eigenverft\.Manifested\.Package 2\.0\.0 '
    }

    It 'selects the highest installed module version from multiple version directories' {
        $moduleName = 'BootstrapVersionSelectionTest'
        $moduleRoot = Join-Path $TestDrive 'Modules'
        foreach ($version in @('1.0.0', '3.0.0', '2.0.0')) {
            $versionRoot = Join-Path $moduleRoot (Join-Path $moduleName $version)
            $null = New-Item -ItemType Directory -Path $versionRoot -Force
            New-ModuleManifest -Path (Join-Path $versionRoot ($moduleName + '.psd1')) -ModuleVersion $version
        }

        $bootstrapScriptPath = Join-Path $script:ModuleProjectRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.ps1'
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($bootstrapScriptPath, [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty
        $functionAst = $ast.Find({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                    $node.Name -eq 'Find-LatestInstalledBootstrapModule'
            }, $true)
        $functionAst | Should -Not -BeNullOrEmpty

        $originalModulePath = $env:PSModulePath
        try {
            $env:PSModulePath = $moduleRoot
            $latest = & $functionAst.Body.GetScriptBlock() -Name $moduleName
        }
        finally {
            $env:PSModulePath = $originalModulePath
        }

        $latest.Version.ToString() | Should -Be '3.0.0'
        $latest.ModuleBase | Should -Be (Join-Path $moduleRoot (Join-Path $moduleName '3.0.0'))
    }

    It 'seeds PackageManagement directly into the requested module root without NuGet packaging metadata' {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $layoutPath = Join-Path $TestDrive 'package-management-seed-layout'
        $packagePath = Join-Path $TestDrive 'PackageManagement.1.4.8.1.nupkg'
        $workDirectory = Join-Path $TestDrive 'package-management-seed-work'
        $moduleInstallRoot = Join-Path $TestDrive 'package-management-seed-modules'
        $null = New-Item -ItemType Directory -Path (Join-Path $layoutPath '_rels') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $layoutPath 'package\services') -Force
        "@{ RootModule = 'PackageManagement.psm1'; ModuleVersion = '1.4.8.1' }" | Set-Content -LiteralPath (Join-Path $layoutPath 'PackageManagement.psd1') -Encoding UTF8
        '' | Set-Content -LiteralPath (Join-Path $layoutPath 'PackageManagement.psm1') -Encoding UTF8
        '<package />' | Set-Content -LiteralPath (Join-Path $layoutPath 'PackageManagement.nuspec') -Encoding UTF8
        '<Types />' | Set-Content -LiteralPath (Join-Path $layoutPath '[Content_Types].xml') -Encoding UTF8
        '<Relationships />' | Set-Content -LiteralPath (Join-Path $layoutPath '_rels\.rels') -Encoding UTF8
        'metadata' | Set-Content -LiteralPath (Join-Path $layoutPath 'package\services\metadata.txt') -Encoding UTF8
        [System.IO.Compression.ZipFile]::CreateFromDirectory($layoutPath, $packagePath)

        $bootstrapScriptPath = Join-Path $script:ModuleProjectRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.ps1'
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($bootstrapScriptPath, [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty
        $functionAst = $ast.Find({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                    $node.Name -eq 'Install-BootstrapPackageManagementSeed'
            }, $true)
        $functionAst | Should -Not -BeNullOrEmpty

        $artifact = [pscustomobject]@{
            ModuleName      = 'PackageManagement'
            RequiredVersion = '1.4.8.1'
            Path            = $packagePath
        }
        $targetRoot = & $functionAst.Body.GetScriptBlock() -Artifact $artifact -WorkDirectory $workDirectory -Scope CurrentUser -ModuleInstallRoot $moduleInstallRoot
        $expectedRoot = Join-Path $moduleInstallRoot 'PackageManagement\1.4.8.1'

        $targetRoot | Should -Be ([System.IO.Path]::GetFullPath($expectedRoot))
        Test-Path -LiteralPath (Join-Path $expectedRoot 'PackageManagement.psd1') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $expectedRoot 'PackageManagement.psm1') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $expectedRoot 'PackageManagement.nuspec') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $expectedRoot '[Content_Types].xml') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $expectedRoot '_rels') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $expectedRoot 'package') | Should -BeFalse
    }

    It 'shows the installed package version summary before returning an interactive prompt' {
        $windowsPowerShellPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $windowsPowerShellPath -PathType Leaf)) {
            return
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $bundlePath = Join-Path $TestDrive 'bootstrap-ready-console'
        $moduleRoot = Join-Path $TestDrive 'bootstrap-ready-modules'
        $null = New-Item -ItemType Directory -Path $bundlePath -Force
        $bootstrapScriptPath = Join-Path $script:ModuleProjectRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.ps1'
        $bundleScriptPath = Join-Path $bundlePath 'Eigenverft.Manifested.Package.Bootstrap.ps1'
        Copy-Item -LiteralPath $bootstrapScriptPath -Destination $bundleScriptPath

        function New-ReadyConsoleTestNupkg {
            param(
                [string]$Id,
                [bool]$IncludeInstallerHelper = $false
            )

            $layoutPath = Join-Path $TestDrive ('ready-nupkg-' + [Guid]::NewGuid().ToString('N'))
            $null = New-Item -ItemType Directory -Path $layoutPath -Force
            "<package><metadata><id>$Id</id><version>1.0.0</version></metadata></package>" |
                Set-Content -LiteralPath (Join-Path $layoutPath ($Id + '.nuspec')) -Encoding UTF8
            if ($IncludeInstallerHelper) {
                $helperPath = Join-Path $layoutPath 'Support\Package\Execution\Invoke-PackagePowerShellModuleInstall.ps1'
                $null = New-Item -ItemType Directory -Path (Split-Path -Parent $helperPath) -Force
                'param()' | Set-Content -LiteralPath $helperPath -Encoding UTF8
            }
            [System.IO.Compression.ZipFile]::CreateFromDirectory($layoutPath, (Join-Path $bundlePath ($Id + '.1.0.0.nupkg')))
        }

        function New-ReadyConsoleTestModule {
            param(
                [string]$Name,
                [bool]$PackageModule = $false
            )

            $versionRoot = Join-Path $moduleRoot (Join-Path $Name '2.0.0')
            $null = New-Item -ItemType Directory -Path $versionRoot -Force
            $rootModuleName = $Name + '.psm1'
            $rootModulePath = Join-Path $versionRoot $rootModuleName
            $functionsToExport = @()
            if ($PackageModule) {
                @'
function Get-PackageVersion { 'BOOTSTRAP_VERSION_SUMMARY' }
function Invoke-Package { }
Export-ModuleMember -Function Get-PackageVersion,Invoke-Package
'@ | Set-Content -LiteralPath $rootModulePath -Encoding UTF8
                $functionsToExport = @('Get-PackageVersion', 'Invoke-Package')
            }
            else {
                '' | Set-Content -LiteralPath $rootModulePath -Encoding UTF8
            }
            New-ModuleManifest -Path (Join-Path $versionRoot ($Name + '.psd1')) -RootModule $rootModuleName -ModuleVersion '2.0.0' -FunctionsToExport $functionsToExport
        }

        New-ReadyConsoleTestNupkg -Id 'PackageManagement'
        New-ReadyConsoleTestNupkg -Id 'PowerShellGet'
        New-ReadyConsoleTestNupkg -Id 'Eigenverft.Manifested.Package' -IncludeInstallerHelper $true
        New-ReadyConsoleTestModule -Name 'PackageManagement'
        New-ReadyConsoleTestModule -Name 'PowerShellGet'
        New-ReadyConsoleTestModule -Name 'Eigenverft.Manifested.Package' -PackageModule $true

        $originalModulePath = $env:PSModulePath
        try {
            $env:PSModulePath = $moduleRoot
            $output = @(& $windowsPowerShellPath -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $bundleScriptPath 2>&1)
        }
        finally {
            $env:PSModulePath = $originalModulePath
        }

        $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
        $text = $output -join [Environment]::NewLine
        $text | Should -Match 'BOOTSTRAP_VERSION_SUMMARY'
        $text | Should -Match 'The package console is ready'
        $text | Should -Match 'You can now run Invoke-Package'
    }
}

