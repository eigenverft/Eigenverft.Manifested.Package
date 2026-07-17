<#
    Eigenverft.Manifested.Package module static-content guards.
#>

Describe 'Eigenverft.Manifested.Package module static content' {
    BeforeAll {
        $script:ModuleProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\Eigenverft.Manifested.Package') -ErrorAction Stop).Path
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

        $content | Should -Match 'powershell\.exe\s+-NoLogo\s+-NoProfile\s+-ExecutionPolicy\s+Bypass\s+-File\s+"%~dp0Eigenverft\.Manifested\.Package\.Bootstrap\.ps1"\s+%\*'
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
        foreach ($packageArtifactId in @('package', 'packageManagementPackage', 'powerShellGetPackage')) {
            $packageFile = ([string]$target.artifactFiles.$packageArtifactId.relativePathTemplate).Replace('{version}', [string]$definition.artifacts.releases[0].version)
            $packageHash = [string]$releaseArtifact.artifactFiles.$packageArtifactId.contentHash.value
            $bootstrapContent | Should -Match ([regex]::Escape($packageFile))
            $bootstrapContent | Should -Match ([regex]::Escape($packageHash))
        }
    }

    It 'reports every missing package when the offline bootstrap bundle is incomplete' {
        $windowsPowerShellPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $windowsPowerShellPath -PathType Leaf)) {
            return
        }

        $bootstrapScriptPath = Join-Path $script:ModuleProjectRoot 'Bootstrap\Eigenverft.Manifested.Package.Bootstrap.ps1'
        $output = @(& $windowsPowerShellPath -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $bootstrapScriptPath -ValidateOnly 2>&1)

        $LASTEXITCODE | Should -Be 1
        $text = $output -join [Environment]::NewLine
        $text | Should -Match 'packageManagementPackage'
        $text | Should -Match 'powerShellGetPackage'
        $text | Should -Match "Missing required artifact 'package'"
    }
}

