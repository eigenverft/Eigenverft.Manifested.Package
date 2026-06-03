<#
    Root entry helpers: Get-PackageVersion, Get-PackageDefinitionAuthoringGuide, and Update-PackageVersion.
    Imported by Eigenverft.Manifested.Package.psm1.
#>

function Get-PackageDefinitionAuthoringGuide {
<#
.SYNOPSIS
Prints package-definition authoring guidance and authoring target endpoint status.

.DESCRIPTION
Loads the module-local PackageDefinitionAuthoring.md skill, evaluates endpoints marked with
authoringTarget in PackageEndpointInventory.json, probes writable filesystem-backed targets,
selects the best usable target by search order preference, and appends the full authoring guide.

When no usable authoring target exists, the output includes troubleshooting text for the agent
to explain endpoint configuration to the user. The command does not throw for ordinary blocked
or unmarked target states.

.PARAMETER For
Optional package definition id inserted into a short task preface.

.PARAMETER EndpointName
Restrict evaluation to one named endpoint. The endpoint must still be marked authoringTarget
and pass the write probe to be selected.

.PARAMETER EndpointPreference
When multiple usable targets exist, First selects the lowest searchOrder and Last the highest.

.PARAMETER DraftOnly
Prepends draft-only mode instructions: keep the definition unsigned, skip signing and trusted verification, and use catalog validation only where helpful.

.EXAMPLE
Get-PackageDefinitionAuthoringGuide -For 'TotalCommander'

Shows task-specific preface, endpoint target guidance, and the full authoring guide.

.EXAMPLE
Get-PackageDefinitionAuthoringGuide -For 'TotalCommander' -DraftOnly

Same as above with an explicit draft-only mode block (unsigned JSON, no sign or RequireTrusted steps).

.EXAMPLE
Get-PackageDefinitionAuthoringGuide -EndpointName moduleDefaults -EndpointPreference First

Evaluates only moduleDefaults when it is marked as an authoring target.
#>
    [CmdletBinding()]
    param(
        [string]$For,

        [string]$EndpointName,

        [ValidateSet('First', 'Last')]
        [string]$EndpointPreference = 'First',

        [switch]$DraftOnly
    )

    $moduleProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $skillPath = Join-Path $moduleProjectRoot 'AgentSkills\PackageDefinitionAuthoring.md'
    if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
        throw "Package definition authoring guide was not found at '$skillPath'."
    }

    $skillText = Get-Content -LiteralPath $skillPath -Raw
    $evaluation = Get-PackageAuthoringTargetEvaluation -EndpointName $EndpointName -EndpointPreference $EndpointPreference

    foreach ($warning in @($evaluation.Warnings)) {
        if (-not [string]::IsNullOrWhiteSpace($warning)) {
            Write-Warning $warning
        }
    }

    $lines = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($For)) {
        $lines.Add("Task: create or update package definition '$For'.") | Out-Null
        $lines.Add('') | Out-Null
    }

    if ($DraftOnly) {
        $lines.Add('## Authoring mode') | Out-Null
        $lines.Add('') | Out-Null
        $lines.Add('Mode: **draft-only** (unsigned).') | Out-Null
        $lines.Add('') | Out-Null
        $lines.Add('AgentAction: You are in draft-only mode. Author or update JSON under **Selection** when available. Keep `definitionPublication.definitionSignature.kind` as `unsigned`. Do not run `Sign-PackageDefinition`, `Resign-PackageDefinition`, or trusted verification (`-RequireTrusted`, `Verify-PackageDefinitionSignature -RequireTrusted`, and similar) for this task unless the maintainer explicitly ends draft-only.') | Out-Null
        $lines.Add('') | Out-Null
        $lines.Add('Validation: `Test-PackageDefinitionCatalog` on the draft file is allowed and encouraged when it helps catch schema issues.') | Out-Null
        $lines.Add('') | Out-Null
    }

    $lines.Add('## Runtime endpoint status') | Out-Null
    $lines.Add('') | Out-Null

    if ($evaluation.SelectedTarget) {
        if ($DraftOnly) {
            $lines.Add('AgentAction: **Draft-only mode.** Proceed with **Start Here** step 3 onward; write under Selection path. Do not sign or require trusted verification.') | Out-Null
        }
        else {
            $lines.Add('AgentAction: Proceed with **Start Here** step 3 onward; write under Selection path.') | Out-Null
        }
    }
    elseif ([string]::Equals($evaluation.TroubleshootingKind, 'NoMarkedTarget', [System.StringComparison]::Ordinal)) {
        $lines.Add('AgentAction: Stop JSON edits. Read **Start Here** step 1 and **Troubleshooting for agents** (NoMarkedTarget).') | Out-Null
    }
    elseif ([string]::Equals($evaluation.TroubleshootingKind, 'AllMarkedBlocked', [System.StringComparison]::Ordinal)) {
        $lines.Add('AgentAction: Stop JSON edits. Read **Start Here** step 1 and **Troubleshooting for agents** (AllMarkedBlocked).') | Out-Null
    }
    else {
        $lines.Add('AgentAction: Read **Start Here** in the guide below before editing JSON.') | Out-Null
    }
    $lines.Add('') | Out-Null

    $lines.Add("InventoryPath: $($evaluation.InventoryPath)") | Out-Null
    if (-not [string]::Equals($evaluation.TroubleshootingKind, 'None', [System.StringComparison]::Ordinal)) {
        $lines.Add("TroubleshootingKind: $($evaluation.TroubleshootingKind)") | Out-Null
    }

    if ($evaluation.Candidates.Count -eq 0) {
        $lines.Add('MarkedCandidates: (none)') | Out-Null
    }
    else {
        $lines.Add('MarkedCandidates:') | Out-Null
        foreach ($candidate in @($evaluation.Candidates)) {
            $pathText = if ([string]::IsNullOrWhiteSpace([string]$candidate.ResolvedRootPath)) { '(unresolved)' } else { [string]$candidate.ResolvedRootPath }
            $skipText = if ([string]::IsNullOrWhiteSpace([string]$candidate.SkipReason)) { '' } else { " skipReason=$($candidate.SkipReason)" }
            $lines.Add("- $($candidate.EndpointName) | $($candidate.Kind) | order=$($candidate.SearchOrder) | enabled=$($candidate.Enabled) | effective=$($candidate.Effective) | $($candidate.Status) | $pathText$skipText") | Out-Null
        }
    }

    if ($evaluation.SelectedTarget) {
        $selected = $evaluation.SelectedTarget
        $lines.Add("Selection: $($selected.EndpointName) | $($selected.Status) | $($selected.ResolvedRootPath)") | Out-Null
    }
    else {
        $lines.Add('Selection: (none)') | Out-Null
    }

    if ($evaluation.Warnings.Count -gt 0) {
        $lines.Add('') | Out-Null
        $lines.Add('Warnings:') | Out-Null
        foreach ($warning in @($evaluation.Warnings)) {
            if (-not [string]::IsNullOrWhiteSpace($warning)) {
                $lines.Add("- $warning") | Out-Null
            }
        }
    }

    $lines.Add('') | Out-Null
    $lines.Add('See **Start Here** and **Authoring Targets And Endpoints** in the guide below.') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('---') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add($skillText.TrimEnd()) | Out-Null

    return ($lines -join [Environment]::NewLine)
}

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
