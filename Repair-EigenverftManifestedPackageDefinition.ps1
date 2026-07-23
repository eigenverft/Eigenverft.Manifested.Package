[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Cert,

    [AllowNull()]
    [securestring]$Password = $null,

    [string]$DefinitionPath = $null,

    [string]$PackagePath = $null
)

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSCommandPath
$moduleRoot = Join-Path $repoRoot 'src\prj\Eigenverft.Manifested.Package'
$moduleManifestPath = Join-Path $moduleRoot 'Eigenverft.Manifested.Package.psd1'
if ([string]::IsNullOrWhiteSpace($DefinitionPath)) {
    $DefinitionPath = Join-Path $moduleRoot 'Endpoint\Defaults\Eigenverft\EigenverftManifestedPackage.json'
}

$DefinitionPath = [System.IO.Path]::GetFullPath($DefinitionPath)
$moduleManifestPath = [System.IO.Path]::GetFullPath($moduleManifestPath)

$newVersion = '1.20264.12503'
$newPackageSha256 = '5cd195928f3a2523d6c20d6f7c968992473d8d3d8b1693a95a3ec0c030d76156'
$packageManagementSha256 = '7e1f8a75b6bc8a83d8abff79f6690fc1dfbd534fd3e5733d97e19bcb5954c13e'
$powerShellGetSha256 = '6b8cebf2a464eaeb31b0a6d627355c30d9d1899dba0ce3bdd0d4e7afca148673'
$historicalBootstrapPowerShellSha256 = 'f89ecd624ee437b37dbb9b99d9a8e23ab9e830d3c6473bc1f52d95a2327b04e3'
$currentBootstrapPowerShellSha256 = 'da40bff7b27a56a74ac7ddc340b21032604399cfbcde12119cec02cfbe6e1b3e'
$bootstrapCommandSha256 = '1bd294dc0b6522974d069af7a8b78a0c672fb264de18e73e78a1fb6596a880ab'
$historicalBootstrapCommit = '6f95fefe409fd5b26116fb672a1f947919253ef8'
$repositoryRawRoot = 'https://raw.githubusercontent.com/eigenverft/Eigenverft.Manifested.Package'
$bootstrapRelativeRoot = 'src/prj/Eigenverft.Manifested.Package/Bootstrap'
$historicalBootstrapRoot = "$repositoryRawRoot/$historicalBootstrapCommit/$bootstrapRelativeRoot"
$currentBootstrapRoot = "$repositoryRawRoot/refs/tags/v$newVersion/$bootstrapRelativeRoot"

function Get-Sha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

function Assert-Sha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Expected,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $actual = Get-Sha256 -Path $Path
    if (-not [string]::Equals($actual, $Expected, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description SHA-256 mismatch. Expected '$Expected', actual '$actual', path '$Path'."
    }

    Write-Host "Verified $Description SHA-256 '$actual'." -ForegroundColor Green
}

function Invoke-DownloadAndVerify {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedSha256,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $invokeParameters = @{
        Uri         = $Uri
        OutFile     = $DestinationPath
        ErrorAction = 'Stop'
    }
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        $invokeParameters.UseBasicParsing = $true
    }

    Invoke-WebRequest @invokeParameters
    Assert-Sha256 -Path $DestinationPath -Expected $ExpectedSha256 -Description $Description
}

function Get-ReleaseByVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition,

        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $matches = @($Definition.artifacts.releases | Where-Object { [string]$_.version -eq $Version })
    if ($matches.Count -ne 1) {
        throw "Expected exactly one release '$Version', found '$($matches.Count)'."
    }

    return $matches[0]
}

function Set-BootstrapArtifactReference {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Release,

        [Parameter(Mandatory = $true)]
        [string]$BootstrapRoot,

        [Parameter(Mandatory = $true)]
        [string]$PowerShellSha256
    )

    $artifactFiles = $Release.targetArtifacts.'EigenverftManifestedPackage-psmodule-stable'.artifactFiles
    $artifactFiles.bootstrapCommand.url = "$BootstrapRoot/Eigenverft.Manifested.Package.Bootstrap.cmd"
    $artifactFiles.bootstrapCommand.contentHash.algorithm = 'sha256'
    $artifactFiles.bootstrapCommand.contentHash.value = $bootstrapCommandSha256
    $artifactFiles.bootstrapPowerShell.url = "$BootstrapRoot/Eigenverft.Manifested.Package.Bootstrap.ps1"
    $artifactFiles.bootstrapPowerShell.contentHash.algorithm = 'sha256'
    $artifactFiles.bootstrapPowerShell.contentHash.value = $PowerShellSha256
}

if (-not (Test-Path -LiteralPath $DefinitionPath -PathType Leaf)) {
    throw "Definition file was not found at '$DefinitionPath'."
}
if (-not (Test-Path -LiteralPath $moduleManifestPath -PathType Leaf)) {
    throw "Module manifest was not found at '$moduleManifestPath'."
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('EigenverftManifestedPackageDefinitionRepair-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tempRoot -Force
$backupPath = "$DefinitionPath.before-$newVersion-signing.bak"

try {
    if ([string]::IsNullOrWhiteSpace($PackagePath)) {
        $PackagePath = Join-Path $tempRoot "Eigenverft.Manifested.Package.$newVersion.nupkg"
        Invoke-DownloadAndVerify -Uri "https://www.powershellgallery.com/api/v2/package/Eigenverft.Manifested.Package/$newVersion" -DestinationPath $PackagePath -ExpectedSha256 $newPackageSha256 -Description "PowerShell Gallery package $newVersion"
    }
    else {
        $PackagePath = [System.IO.Path]::GetFullPath($PackagePath)
        Assert-Sha256 -Path $PackagePath -Expected $newPackageSha256 -Description "provided package $newVersion"
    }

    Invoke-DownloadAndVerify -Uri "$historicalBootstrapRoot/Eigenverft.Manifested.Package.Bootstrap.ps1" -DestinationPath (Join-Path $tempRoot 'historical-bootstrap.ps1') -ExpectedSha256 $historicalBootstrapPowerShellSha256 -Description 'historical Bootstrap PowerShell payload'
    Invoke-DownloadAndVerify -Uri "$historicalBootstrapRoot/Eigenverft.Manifested.Package.Bootstrap.cmd" -DestinationPath (Join-Path $tempRoot 'historical-bootstrap.cmd') -ExpectedSha256 $bootstrapCommandSha256 -Description 'historical Bootstrap command payload'
    Invoke-DownloadAndVerify -Uri "$currentBootstrapRoot/Eigenverft.Manifested.Package.Bootstrap.ps1" -DestinationPath (Join-Path $tempRoot 'current-bootstrap.ps1') -ExpectedSha256 $currentBootstrapPowerShellSha256 -Description "Bootstrap PowerShell payload for $newVersion"
    Invoke-DownloadAndVerify -Uri "$currentBootstrapRoot/Eigenverft.Manifested.Package.Bootstrap.cmd" -DestinationPath (Join-Path $tempRoot 'current-bootstrap.cmd') -ExpectedSha256 $bootstrapCommandSha256 -Description "Bootstrap command payload for $newVersion"

    $definition = Get-Content -LiteralPath $DefinitionPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([int]$definition.definitionPublication.definitionRevision -ne 13) {
        throw "Expected definitionRevision 13 before repair, found '$($definition.definitionPublication.definitionRevision)'."
    }

    $oldRelease5748 = Get-ReleaseByVersion -Definition $definition -Version '1.20264.5748'
    $oldRelease4323 = Get-ReleaseByVersion -Definition $definition -Version '1.20264.4323'
    Set-BootstrapArtifactReference -Release $oldRelease5748 -BootstrapRoot $historicalBootstrapRoot -PowerShellSha256 $historicalBootstrapPowerShellSha256
    Set-BootstrapArtifactReference -Release $oldRelease4323 -BootstrapRoot $historicalBootstrapRoot -PowerShellSha256 $historicalBootstrapPowerShellSha256

    $newRelease = [pscustomobject][ordered]@{
        version         = $newVersion
        releaseTracks   = @('stable')
        targetArtifacts = [pscustomobject][ordered]@{
            'EigenverftManifestedPackage-psmodule-stable' = [pscustomobject][ordered]@{
                artifactId    = 'eigenverft-manifested-package-psmodule-stable'
                artifactFiles = [pscustomobject][ordered]@{
                    package                  = [pscustomobject][ordered]@{ contentHash = [pscustomobject][ordered]@{ algorithm = 'sha256'; value = $newPackageSha256 } }
                    packageManagementPackage = [pscustomobject][ordered]@{ contentHash = [pscustomobject][ordered]@{ algorithm = 'sha256'; value = $packageManagementSha256 } }
                    powerShellGetPackage     = [pscustomobject][ordered]@{ contentHash = [pscustomobject][ordered]@{ algorithm = 'sha256'; value = $powerShellGetSha256 } }
                    bootstrapCommand         = [pscustomobject][ordered]@{
                        url         = "$currentBootstrapRoot/Eigenverft.Manifested.Package.Bootstrap.cmd"
                        contentHash = [pscustomobject][ordered]@{ algorithm = 'sha256'; value = $bootstrapCommandSha256 }
                    }
                    bootstrapPowerShell      = [pscustomobject][ordered]@{
                        url         = "$currentBootstrapRoot/Eigenverft.Manifested.Package.Bootstrap.ps1"
                        contentHash = [pscustomobject][ordered]@{ algorithm = 'sha256'; value = $currentBootstrapPowerShellSha256 }
                    }
                }
            }
        }
    }

    $remainingReleases = @($definition.artifacts.releases | Where-Object { [string]$_.version -ne $newVersion })
    $definition.artifacts.releases = @($newRelease) + $remainingReleases
    $definition.discovery.presence.powerShellModules[0].requiredVersion = $newVersion
    $definition.discovery.existingInstall.searchLocations[0].requiredVersion = $newVersion
    $definition.packageOperations.assigned.install.requiredVersion = $newVersion
    $definition.definitionPublication.definitionRevision = 14
    $definition.definitionPublication.publishedAtUtc = [DateTime]::UtcNow.ToString('o')

    if (-not $PSCmdlet.ShouldProcess($DefinitionPath, "write release $newVersion and re-sign definition revision 14")) {
        Write-Host 'WhatIf completed. No definition file was changed.' -ForegroundColor Yellow
        return
    }

    Copy-Item -LiteralPath $DefinitionPath -Destination $backupPath -Force
    try {
        $definition | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $DefinitionPath -Encoding UTF8

        Import-Module -Name $moduleManifestPath -Force -DisableNameChecking -ErrorAction Stop
        $signParameters = @{
            Path        = $DefinitionPath
            Cert        = $Cert
            ErrorAction = 'Stop'
        }
        if ($null -ne $Password) {
            $signParameters.Password = $Password
        }

        $signResult = Resign-PackageDefinition @signParameters
        $verification = Verify-PackageDefinitionSignature -Path $DefinitionPath -RequireTrusted -ErrorOnFailure
        $catalogReport = Test-PackageDefinitionCatalog -Path $DefinitionPath -RequireTrusted -ErrorOnFailure

        if (-not [bool]$verification.Valid -or -not [bool]$verification.Trusted) {
            throw "Definition signature verification did not return valid and trusted. Status '$($verification.Status)'."
        }
        if (-not [bool]$catalogReport.Valid) {
            throw "Package definition catalog validation did not return valid."
        }

        Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
        Write-Host "Definition repair completed and signed for release '$newVersion'." -ForegroundColor Green
        Write-Host "Definition revision: $($definition.definitionPublication.definitionRevision)" -ForegroundColor Green
        Write-Host "Signing key: $($signResult.KeyThumbprint)" -ForegroundColor Green
        Write-Host "Verification status: $($verification.Status)" -ForegroundColor Green
        Write-Host "Next: review git diff, commit the changed JSON, push the branch, then deploy the signed definition to the endpoint." -ForegroundColor Cyan
    }
    catch {
        if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
            Copy-Item -LiteralPath $backupPath -Destination $DefinitionPath -Force
        }
        throw
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
