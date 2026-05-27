<#
    Root entry helpers: Get-PackageVersion and Update-PackageVersion.
    Imported by Eigenverft.Manifested.Package.psm1.
#>

function Get-PackageVersion {
<#
.SYNOPSIS
Shows the resolved module version, shipped package-definition examples, and other exported commands.

.DESCRIPTION
Resolves the highest available or loaded Eigenverft.Manifested.Package module version, lists
example Invoke-Package lines for each shipped definition JSON discovered under the packaged
endpoint defaults tree (when package bootstrap commands are available), then lists remaining exported
commands in alphabetical order.

.EXAMPLE
Get-PackageVersion

Displays module information, per-definition Invoke-Package examples, and other exported commands.
#>
    [CmdletBinding()]
    param()

    $moduleName = 'Eigenverft.Manifested.Package'
    $moduleInfo = @(Get-Module -ListAvailable -Name $moduleName | Sort-Object -Descending -Property Version | Select-Object -First 1)
    $loadedModule = @(Get-Module -Name $moduleName | Sort-Object -Descending -Property Version | Select-Object -First 1)

    if (-not $moduleInfo) {
        if ($loadedModule) {
            $moduleInfo = $loadedModule
        }
        elseif ($ExecutionContext.SessionState.Module -and $ExecutionContext.SessionState.Module.Name -eq $moduleName) {
            $moduleInfo = @($ExecutionContext.SessionState.Module)
        }
    }

    if (-not $moduleInfo) {
        throw "Could not resolve the installed or loaded version of module '$moduleName'."
    }

    $commandSourceModule = $loadedModule | Select-Object -First 1
    if (-not $commandSourceModule -and $ExecutionContext.SessionState.Module -and $ExecutionContext.SessionState.Module.Name -eq $moduleName) {
        $commandSourceModule = $ExecutionContext.SessionState.Module
    }

    $exportedCommandNames = @()
    if ($commandSourceModule -and $commandSourceModule.ExportedCommands) {
        $exportedCommandNames = @(
            $commandSourceModule.ExportedCommands.Keys |
                Sort-Object
        )
    }

    if (-not $exportedCommandNames) {
        $exportedCommandNames = @(
            Get-Command -Module $moduleName -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Name -Unique |
                Sort-Object
        )
    }

    $definitionIds = @()
    $defaultDefinitionPublisherId = 'Eigenverft'
    if (Get-Command Get-PackageDefaultPublisherId -ErrorAction SilentlyContinue) {
        try {
            $defaultDefinitionPublisherId = [string](Get-PackageDefaultPublisherId)
        }
        catch {
        }
    }

    if (Get-Command Get-PackageShippedEndpointRoot -ErrorAction SilentlyContinue) {
        try {
            $endpointRoot = Get-PackageShippedEndpointRoot
            $definitionRoot = Join-Path $endpointRoot 'Defaults'
            if (Test-Path -LiteralPath $definitionRoot -PathType Container) {
                foreach ($jsonFile in Get-ChildItem -LiteralPath $definitionRoot -Filter *.json -File -Recurse) {
                    try {
                        $doc = Get-Content -LiteralPath $jsonFile.FullName -Raw | ConvertFrom-Json
                        $sv = if ($doc.PSObject.Properties['schemaVersion']) { [string]$doc.schemaVersion } else { '' }
                        $id = if ($doc.PSObject.Properties['definitionPublication'] -and $doc.definitionPublication.PSObject.Properties['definitionId']) { [string]$doc.definitionPublication.definitionId } elseif ($doc.PSObject.Properties['id']) { [string]$doc.id } else { '' }
                        if (-not [string]::IsNullOrWhiteSpace($sv) -and -not [string]::IsNullOrWhiteSpace($id) -and $doc.PSObject.Properties['packageOperations']) {
                            $definitionIds += $id
                        }
                    }
                    catch {
                    }
                }
            }
        }
        catch {
        }
    }

    $definitionIds = @($definitionIds | Sort-Object -Unique)

    $outputLines = @(
        'Module: {0}' -f $moduleName
        'Version: {0}' -f $moduleInfo[0].Version.ToString()
    )

    if ($definitionIds.Count -gt 0) {
        $outputLines += @(
            ('Shipped package definitions (signed publisherId ''{0}''; optional ''Invoke-Package -PublisherId'' pins a definition publisher label; endpoints live in PackageEndpointInventory.json):' -f $defaultDefinitionPublisherId)
            ($definitionIds | ForEach-Object { "- Invoke-Package -DefinitionId '{0}'" -f $_ })
            'Use -DesiredState Removed to uninstall a package-owned install when the definition supports it.'
        )
        $bulkIds = @($definitionIds | Where-Object { $_ -ne 'VSCodeUser' })
        if ($bulkIds.Count -gt 0) {
            $outputLines += 'Assign many at once (comma-separated; VSCodeUser omitted here - use VSCodeRuntime for the portable layout or invoke VSCodeUser separately):'
            $outputLines += ("- Invoke-Package -DefinitionId {0}" -f ($bulkIds -join ','))
        }
        $outputLines += ''
        $outputLines += 'Team setup example:'
        $outputLines += "- Add-TeamPackageDepot -BasePath '\\team-share\PackageDepot'"
        $outputLines += "- Add-TeamPackageEndpoint -BasePath '\\team-share\PackageEndpoint'"
        $outputLines += "- Invoke-Package -DefinitionId 'OtherTextEditorFromTeamRepos'"
        $outputLines += "Valid unknown embedded signing certificates prompt for trust; admins can preseed trust with: Import-PackageTrust -Path '<public-signing-cert.cer>'"
        $outputLines += "Maintainers can create a local signing certificate with: New-PackageSigningCertificate -Name 'My Team' -PublisherId 'My Team' -CommonName 'My Team Package Catalog Signing' -Password <securestring>"
        $outputLines += "Then sign definitions with: Sign-PackageDefinition -Path '\\team-share\PackageEndpoint\MyPackage.json' -Cert 'MyTeam'"
        $outputLines += "Team package JSON files should be signed and set definitionPublication.publisherId to the signing-key publisher."
        $outputLines += ''
    }
    else {
        $outputLines += @(
            'Shipped package definitions: (none discovered; import the full module to scan Endpoint/Defaults.)'
            ''
        )
    }

    $outputLines += 'Other exported commands:'
    if ($exportedCommandNames) {
        $outputLines += @(
            $exportedCommandNames | ForEach-Object { '- {0}' -f $_ }
        )
    }
    else {
        $outputLines += '- None found'
    }

    return ($outputLines -join [Environment]::NewLine)
}

function Update-PackageVersion {
<#
.SYNOPSIS
Install or update Eigenverft.Manifested.Package from the PowerShell Gallery.

.DESCRIPTION
Installs or updates this module from PSGallery (stable; -Scope). On Windows, the internal proxy
bootstrap prepares session + Install-Module proxy parameters; manual proxy UI is allowed when
automatic resolution cannot reach the gallery. Non-Windows: minimal TLS/proxy only. Requires network.

.PARAMETER Scope
CurrentUser (default) or AllUsers (elevation required).

.EXAMPLE
Update-PackageVersion -Scope CurrentUser
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser'
    )

    $moduleName = 'Eigenverft.Manifested.Package'
    $repository = 'PSGallery'
    $params = @{
        Name         = $moduleName
        Repository   = $repository
        Scope        = $Scope
        Force        = $true
        AllowClobber = $true
        ErrorAction  = 'Stop'
    }

    $proxyModuleParams = @{}
    $packageIsWindows = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

    if ($packageIsWindows) {
        # Manual proxy UI and non-interactive failure are handled by the private proxy bootstrap.
        Initialize-ProxyAccessProfile -TestUri ([uri]'https://www.powershellgallery.com/api/v2/')

        if ($null -ne $Global:ProxyParamsPrepareSession) {
            $null = $Global:ProxyParamsPrepareSession.Invoke()
        }
        $installGv = Get-Variable -Scope Global -Name ProxyParamsInstallModule -ErrorAction SilentlyContinue
        if ($installGv -and $installGv.Value -is [hashtable] -and $installGv.Value.Count -gt 0) {
            $proxyModuleParams = $installGv.Value
        }
    }
    else {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
        try {
            $wp = [System.Net.WebRequest]::GetSystemWebProxy()
            [System.Net.WebRequest]::DefaultWebProxy = $wp
            if ($wp) { $wp.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials }
        } catch { }
    }

    if ($PSCmdlet.ShouldProcess($params.Name, "Install ($Scope) from $repository")) {
        Install-Module @proxyModuleParams @params
    }
}
