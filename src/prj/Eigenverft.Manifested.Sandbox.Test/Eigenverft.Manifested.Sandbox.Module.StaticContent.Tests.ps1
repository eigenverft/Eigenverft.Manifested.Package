<#
    Eigenverft.Manifested.Sandbox module static-content guards.
#>

Describe 'Eigenverft.Manifested.Sandbox module static content' {
    BeforeAll {
        $script:ModuleProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\Eigenverft.Manifested.Sandbox') -ErrorAction Stop).Path
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
}

