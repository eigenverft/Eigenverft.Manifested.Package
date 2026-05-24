<#
    Root entry helpers: Get-SandboxVersion and Sandbox (-Update / -Version bootstrap).
    Imported by Eigenverft.Manifested.Sandbox.psm1.
#>

function Get-SandboxVersion {
<#
.SYNOPSIS
Shows the resolved module version, shipped package-definition examples, and other exported commands.

.DESCRIPTION
Resolves the highest available or loaded Eigenverft.Manifested.Sandbox module version, lists
example Invoke-Package lines for each shipped definition JSON discovered under the packaged
endpoint defaults tree (when package bootstrap commands are available), then lists remaining exported
commands in alphabetical order.

.EXAMPLE
Get-SandboxVersion

Displays module information, per-definition Invoke-Package examples, and other exported commands.
#>
    [CmdletBinding()]
    param()

    $moduleName = 'Eigenverft.Manifested.Sandbox'
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
            ('Shipped package definitions (trusted publisher ''{0}''; optional ''Invoke-Package -PublisherId'' pins a publisher; endpoints live in PackageEndpointInventory.json):' -f $defaultDefinitionPublisherId)
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
        $outputLines += "- Add-TeamPackagePublisher -PublisherId 'My Team'"
        $outputLines += "Team package JSON files must set definitionPublication.publisherId to 'My Team'."
        $outputLines += "- Invoke-Package -DefinitionId 'OtherTextEditorFromTeamRepos'"
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

function Sandbox {
<#
.SYNOPSIS
Install or update Eigenverft.Manifested.Sandbox from the PowerShell Gallery, or print module version information.

.DESCRIPTION
Thin bootstrap surface (similar intent to Eigenverft.Manifested.Drydock). Main switches are mutually exclusive:
- -Update : Install/update from PSGallery (stable; -Scope). On Windows, the internal proxy bootstrap prepares session + Install-Module proxy parameters; manual proxy UI is allowed when automatic resolution cannot reach the gallery. Non-Windows: minimal TLS/proxy only. Requires network.
- -Version : Print the same summary as Get-SandboxVersion (module version, shipped package examples, and exported commands).

Without a main switch, prints a short usage note.

.PARAMETER Update
Install or update the module from PSGallery.

.PARAMETER Version
Show module version, shipped Invoke-Package examples, and exported command names (delegates to Get-SandboxVersion).

.PARAMETER Scope
With -Update, CurrentUser (default) or AllUsers (elevation required).

.EXAMPLE
Sandbox -Update -Scope CurrentUser

.EXAMPLE
Sandbox -Version
#>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Manual')]
    param(
        [Parameter(ParameterSetName = 'UpdateSet', Mandatory = $true)]
        [switch]$Update,

        [Parameter(ParameterSetName = 'VersionSet', Mandatory = $true)]
        [Alias('v')]
        [switch]$Version,

        [Parameter(ParameterSetName = 'UpdateSet')]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser'
    )

    $ModuleName = 'Eigenverft.Manifested.Sandbox'
    $Repository = 'PSGallery'

    function Show-SandboxManual {
        @(
            "-Update   : Install/update module from $Repository (stable; supports -Scope)."
            "  Example : Sandbox -Update -Scope CurrentUser"
            "  -Scope  : CurrentUser (default) or AllUsers (elevation)."
            ""
            "-Version  : Show module version, shipped package Invoke-Package examples, and exported commands (same as Get-SandboxVersion)."
            "  Example : Sandbox -Version"
        ) | ForEach-Object { Write-Output $_ }
    }

    switch ($PSCmdlet.ParameterSetName) {
        'Manual' {
            Show-SandboxManual
            return
        }
        'VersionSet' {
            Get-SandboxVersion
            return
        }
        'UpdateSet' {
            $params = @{
                Name         = $ModuleName
                Repository   = $Repository
                Scope        = $Scope
                Force        = $true
                AllowClobber = $true
                ErrorAction  = 'Stop'
            }

            $proxyModuleParams = @{}
            $sandboxIsWindows = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

            if ($sandboxIsWindows) {
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

            if ($PSCmdlet.ShouldProcess($params.Name, "Install ($Scope) from $Repository")) {
                Install-Module @proxyModuleParams @params
            }
            return
        }
    }
}
