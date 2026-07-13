<#
    Eigenverft.Manifested.Package Package - test isolation
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - test isolation' -Body {

    It "keeps test package documents in Pester's isolated local endpoint inventory" {
        $rootPath = Join-Path $TestDrive 'test-package-document-isolation'
        $bootstrapEndpointInventoryPath = Get-PackageLocalEndpointInventoryPath

        $bootstrapEndpointInventoryPath | Should -BeLike "$TestDrive*"
        Test-Path -LiteralPath $bootstrapEndpointInventoryPath -PathType Leaf | Should -BeFalse

        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument (New-TestPackageGlobalDocument) -DefinitionDocument (New-TestVSCodeDefinitionDocument -Releases @(
                New-TestPackageRelease -Id 'isolation-win-x64-stable' -Version '1.0.0' -Architecture 'x64'
        ))

        Test-Path -LiteralPath $documents.EndpointInventoryPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapEndpointInventoryPath -PathType Leaf | Should -BeTrue
    }
}
