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

# Embedded from the sibling Eigenverft.Manifested.Drydock version helper so module
# self-update reporting has no runtime dependency on Drydock.
function Convert-64SecVersionComponentsToDateTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VersionBuild,

        [Parameter(Mandatory = $true)]
        [int]$VersionMajor,

        [Parameter(Mandatory = $true)]
        [int]$VersionMinor,

        [Parameter(Mandatory = $true)]
        [int]$VersionRevision
    )

    if ($VersionMinor -lt 0) {
        throw 'VersionMinor must be >= 0.'
    }

    $year = [int]($VersionMinor / 10)
    $high = $VersionMinor - ($year * 10)
    if ($high -lt 0) {
        $year -= 1
        $high += 10
    }
    elseif ($high -gt 9) {
        $year += 1
        $high -= 10
    }

    if ($year -lt 1 -or $year -gt 9999) {
        throw "Decoded year $year out of 1..9999."
    }
    if ($high -lt 0 -or $high -gt 7) {
        throw "HighPart $high out of range 0..7 not an encoded 64s version."
    }

    $low = $VersionRevision -band 0xFFFF
    if ($VersionRevision -ne $low) {
        throw "VersionRevision $VersionRevision exceeds 16 bits."
    }

    $shifted = ($high -shl 16) -bor $low
    $secondsInYear = if ([datetime]::IsLeapYear($year)) { 31622400 } else { 31536000 }
    $maxShifted = [int][math]::Floor(($secondsInYear - 1) / 64)
    if ($shifted -gt $maxShifted) {
        throw "ShiftedSeconds $shifted exceeds max $maxShifted for year $year components invalid."
    }

    $startOfYearUtc = New-Object datetime ($year, 1, 1, 0, 0, 0, [datetimekind]::Utc)
    return @{
        VersionBuild     = $VersionBuild
        VersionMajor     = $VersionMajor
        ComputedDateTime = $startOfYearUtc.AddSeconds($shifted * 64)
    }
}

function Convert-64SecPowershellVersionToDateTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VersionBuild,

        [Parameter(Mandatory = $true)]
        [int]$VersionMajor,

        [Parameter(Mandatory = $true)]
        [int]$VersionMinor
    )

    $result = Convert-64SecVersionComponentsToDateTime `
        -VersionBuild $VersionBuild `
        -VersionMajor 0 `
        -VersionMinor $VersionMajor `
        -VersionRevision $VersionMinor

    return @{
        VersionFull      = "$VersionBuild.$VersionMajor.$VersionMinor"
        VersionBuild     = $VersionBuild
        ComputedDateTime = $result.ComputedDateTime
    }
}

function Format-PackageVersionWithBuildDate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [version]$Version
    )

    try {
        $dateResult = Convert-64SecPowershellVersionToDateTime `
            -VersionBuild $Version.Major `
            -VersionMajor $Version.Minor `
            -VersionMinor $Version.Build
        $buildTimeUtc = $dateResult.ComputedDateTime.ToUniversalTime().ToString(
            'yyyy-MM-dd HH:mm:ss',
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        return ('{0} (built {1} UTC)' -f $Version, $buildTimeUtc)
    }
    catch {
        Write-Verbose ("The optional build-date conversion for version '{0}' was skipped: {1}" -f
            $Version,
            $_.Exception.Message)
        return [string]$Version
    }
}

function Select-PackageCommandParameters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandInfo]$Command,

        [Parameter(Mandatory = $true)]
        [hashtable]$CandidateParameters,

        [string[]]$RequiredParameters = @()
    )

    foreach ($requiredParameter in @($RequiredParameters)) {
        if (-not $Command.Parameters.ContainsKey($requiredParameter)) {
            throw "Command '$($Command.Name)' does not support required parameter '-$requiredParameter'. Install a supported PowerShellGet version and retry."
        }
    }

    $selectedParameters = @{}
    foreach ($entry in $CandidateParameters.GetEnumerator()) {
        if ($Command.Parameters.ContainsKey([string]$entry.Key)) {
            $selectedParameters[[string]$entry.Key] = $entry.Value
        }
        else {
            Write-Verbose ("Command '{0}' does not support optional parameter '-{1}'; omitting it." -f $Command.Name, $entry.Key)
        }
    }

    return $selectedParameters
}

function Get-PackageModuleVersionState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [System.Management.Automation.PSModuleInfo]$ExecutingModule
    )

    $loadedModules = @(Get-Module -Name $ModuleName -ErrorAction SilentlyContinue)
    $installedModules = @(Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue)
    $versions = New-Object System.Collections.Generic.List[version]

    if ($null -ne $ExecutingModule -and $null -ne $ExecutingModule.Version) {
        $versions.Add([version]$ExecutingModule.Version) | Out-Null
    }

    foreach ($module in @($loadedModules + $installedModules)) {
        if ($null -eq $module -or $null -eq $module.Version) {
            continue
        }

        try {
            $versions.Add([version]([string]$module.Version)) | Out-Null
        }
        catch {
            Write-Verbose ("Ignoring unreadable module version '{0}' from '{1}'." -f $module.Version, $module.Path)
        }
    }

    $highestVersion = @($versions | Sort-Object -Descending | Select-Object -First 1)

    return [pscustomobject]@{
        ExecutingModule        = $ExecutingModule
        ExecutingVersion       = if ($null -ne $ExecutingModule) { [version]$ExecutingModule.Version } else { $null }
        LoadedModules          = @($loadedModules)
        InstalledModules       = @($installedModules)
        HighestRelevantVersion = if ($highestVersion.Count -gt 0) { [version]$highestVersion[0] } else { $null }
    }
}

function Test-PackageModuleInstallationScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Module,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope
    )

    $modulePath = [string]$Module.Path
    if ([string]::IsNullOrWhiteSpace($modulePath)) {
        return [pscustomobject]@{ Known = $false; Matches = $false; ScopeRoot = $null }
    }

    $packageScopeIsWindows = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
    $scopeRoot = $null
    if ($packageScopeIsWindows) {
        $shellModuleDirectory = if ($PSVersionTable.PSEdition -eq 'Desktop') {
            'WindowsPowerShell\Modules'
        }
        else {
            'PowerShell\Modules'
        }

        if ($Scope -eq 'CurrentUser') {
            $documentsPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)
            if (-not [string]::IsNullOrWhiteSpace($documentsPath)) {
                $scopeRoot = Join-Path -Path $documentsPath -ChildPath $shellModuleDirectory
            }
        }
        elseif (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
            $scopeRoot = Join-Path -Path $env:ProgramFiles -ChildPath $shellModuleDirectory
        }
    }
    elseif ($Scope -eq 'CurrentUser' -and -not [string]::IsNullOrWhiteSpace($HOME)) {
        $scopeRoot = Join-Path -Path $HOME -ChildPath '.local/share/powershell/Modules'
    }
    elseif ($Scope -eq 'AllUsers') {
        $scopeRoot = '/usr/local/share/powershell/Modules'
    }

    if ([string]::IsNullOrWhiteSpace($scopeRoot)) {
        return [pscustomobject]@{ Known = $false; Matches = $false; ScopeRoot = $null }
    }

    $fullModulePath = [System.IO.Path]::GetFullPath($modulePath)
    $fullScopeRoot = [System.IO.Path]::GetFullPath($scopeRoot).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $pathComparison = if ($packageScopeIsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }
    $scopePrefix = $fullScopeRoot + [System.IO.Path]::DirectorySeparatorChar

    return [pscustomobject]@{
        Known = $true
        Matches = $fullModulePath.StartsWith($scopePrefix, $pathComparison)
        ScopeRoot = $fullScopeRoot
    }
}

function Enable-PackageUpdatedModuleVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $true)]
        [version]$Version,

        [Parameter(Mandatory = $true)]
        [object]$InstalledModule
    )

    if ([string]::IsNullOrWhiteSpace([string]$InstalledModule.Path) -or
        -not (Test-Path -LiteralPath $InstalledModule.Path -PathType Leaf)) {
        return [pscustomobject]@{
            Active = $false
            Reason = 'The exact installed module manifest could not be resolved.'
            CommandVersion = $null
            PreviousModuleStateLoaded = $false
        }
    }

    try {
        $installedModuleBase = if (-not [string]::IsNullOrWhiteSpace([string]$InstalledModule.ModuleBase)) {
            [System.IO.Path]::GetFullPath([string]$InstalledModule.ModuleBase)
        }
        else {
            [System.IO.Path]::GetFullPath((Split-Path -Parent $InstalledModule.Path))
        }
        $loadedBefore = @(Get-Module -Name $ModuleName -ErrorAction SilentlyContinue)
        if ($loadedBefore.Count -gt 1) {
            $currentCommand = Get-Command -Name 'Update-PackageVersion' -ErrorAction SilentlyContinue
            return [pscustomobject]@{
                Active = $false
                Reason = 'Multiple module instances were already loaded, so same-session replacement was not attempted.'
                CommandVersion = if ($currentCommand -and $currentCommand.Module) { [version]$currentCommand.Module.Version } else { $null }
                PreviousModuleStateLoaded = $true
            }
        }

        Import-Module -Name $InstalledModule.Path -Force -Global -DisableNameChecking -ErrorAction Stop | Out-Null

        $activeCommand = Get-Command -Name 'Update-PackageVersion' -ErrorAction Stop
        $activeModule = $activeCommand.Module
        $activeVersionMatches =
            $null -ne $activeModule -and
            [string]::Equals($activeModule.Name, $ModuleName, [System.StringComparison]::OrdinalIgnoreCase) -and
            $null -ne $activeModule.Version -and
            ([version]$activeModule.Version -eq $Version)
        $activeModuleBaseMatches =
            $activeVersionMatches -and
            -not [string]::IsNullOrWhiteSpace([string]$activeModule.ModuleBase) -and
            [string]::Equals(
                [System.IO.Path]::GetFullPath($activeModule.ModuleBase),
                $installedModuleBase,
                [System.StringComparison]::OrdinalIgnoreCase
            )
        $loadedAfter = @(Get-Module -Name $ModuleName -ErrorAction SilentlyContinue)
        $matchingLoadedModules = @(
            $loadedAfter | Where-Object {
                $null -ne $_.Version -and
                [version]$_.Version -eq $Version -and
                -not [string]::IsNullOrWhiteSpace([string]$_.ModuleBase) -and
                [string]::Equals(
                    [System.IO.Path]::GetFullPath($_.ModuleBase),
                    $installedModuleBase,
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            }
        )
        $otherLoadedModules = @(
            $loadedAfter | Where-Object {
                $null -eq $_.Version -or
                [version]$_.Version -ne $Version -or
                [string]::IsNullOrWhiteSpace([string]$_.ModuleBase) -or
                -not [string]::Equals(
                    [System.IO.Path]::GetFullPath($_.ModuleBase),
                    $installedModuleBase,
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            }
        )
        $previousModuleStateLoaded = $false
        $otherLoadedStateMatches = $otherLoadedModules.Count -eq 0
        $activeCommandMatchesPreviousModule = $false

        if ($loadedBefore.Count -eq 1 -and $otherLoadedModules.Count -eq 1) {
            $previousModule = $loadedBefore[0]
            $otherModule = $otherLoadedModules[0]
            $previousModuleBase = if (-not [string]::IsNullOrWhiteSpace([string]$previousModule.ModuleBase)) {
                [System.IO.Path]::GetFullPath([string]$previousModule.ModuleBase)
            }
            else {
                $null
            }
            $previousModuleStateLoaded =
                $null -ne $previousModule.Version -and
                $null -ne $otherModule.Version -and
                [version]$otherModule.Version -eq [version]$previousModule.Version -and
                -not [string]::IsNullOrWhiteSpace($previousModuleBase) -and
                -not [string]::IsNullOrWhiteSpace([string]$otherModule.ModuleBase) -and
                [string]::Equals(
                    [System.IO.Path]::GetFullPath([string]$otherModule.ModuleBase),
                    $previousModuleBase,
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            $otherLoadedStateMatches = $previousModuleStateLoaded
            $activeCommandMatchesPreviousModule =
                $previousModuleStateLoaded -and
                $null -ne $activeModule -and
                $null -ne $activeModule.Version -and
                [version]$activeModule.Version -eq [version]$previousModule.Version -and
                -not [string]::IsNullOrWhiteSpace([string]$activeModule.ModuleBase) -and
                [string]::Equals(
                    [System.IO.Path]::GetFullPath([string]$activeModule.ModuleBase),
                    $previousModuleBase,
                    [System.StringComparison]::OrdinalIgnoreCase
                )
        }

        $loadedStateMatches = $matchingLoadedModules.Count -eq 1 -and $otherLoadedStateMatches

        if ($loadedStateMatches -and ($activeModuleBaseMatches -or $activeCommandMatchesPreviousModule)) {
            return [pscustomobject]@{
                Active = $true
                Reason = $null
                CommandVersion = $Version
                PreviousModuleStateLoaded = $previousModuleStateLoaded
            }
        }

        return [pscustomobject]@{
            Active = $false
            Reason = if (-not $activeModuleBaseMatches) {
                'The active Update-PackageVersion command did not resolve to the newly installed module.'
            }
            else {
                'The new command resolved correctly, but duplicate or mismatched loaded module state remained.'
            }
            CommandVersion = if ($null -ne $activeModule -and $null -ne $activeModule.Version) { [version]$activeModule.Version } else { $null }
            PreviousModuleStateLoaded = $previousModuleStateLoaded
        }
    }
    catch {
        Write-Verbose ("The new module was installed but could not be activated safely in this session: {0}" -f $_.Exception.Message)
        return [pscustomobject]@{
            Active = $false
            Reason = $_.Exception.Message
            CommandVersion = $null
            PreviousModuleStateLoaded = $false
        }
    }
}

function Update-PackageVersion {
<#
.SYNOPSIS
Update Eigenverft.Manifested.Package from the PowerShell Gallery when a newer stable version exists.

.DESCRIPTION
Queries PSGallery for the latest stable version, compares it with the highest version currently
running, loaded, or installed, and installs only when PSGallery is newer. The command requests the
exact discovered version when the installed PowerShellGet supports RequiredVersion and verifies that
the version is visible after installation.

On Windows, the internal proxy bootstrap first probes the PSGallery API and prepares session proxy
settings. Find-Module and Install-Module then run as separate PowerShellGet operations. Their
parameters are filtered independently against the commands available in the current session so old
PowerShellGet versions do not receive unsupported optional parameters such as AllowClobber.

After installation, the command imports the exact installed module globally. Subsequent commands can
therefore use the new version while the currently executing older module instance remains loaded. The
command reports that transition separately from a failed activation and recommends a new PowerShell
session only to clear retained module state. Every final outcome uses the standard timestamped status
format and includes the decoded UTC build time for encoded Eigenverft versions.

.PARAMETER Scope
CurrentUser (default) or AllUsers (elevation normally required). Scope controls where a newer version
is installed; version comparison still considers every visible copy so the command never downgrades or
needlessly reinstalls the module into another scope.

.EXAMPLE
Update-PackageVersion -Scope CurrentUser

Checks PSGallery and updates the current-user installation only when a newer stable version exists.

.EXAMPLE
Update-PackageVersion -Scope AllUsers -WhatIf

Performs proxy preparation, gallery discovery, and version comparison, then previews the installation
without changing the installed module.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser'
    )

    $moduleName = 'Eigenverft.Manifested.Package'
    $repository = 'PSGallery'
    $galleryApiUri = [uri]'https://www.powershellgallery.com/api/v2/'
    $proxyModuleParameters = @{}
    $packageIsWindows = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
    $executingModule = $MyInvocation.MyCommand.Module
    $beforeState = Get-PackageModuleVersionState -ModuleName $moduleName -ExecutingModule $executingModule
    $executingVersion = $beforeState.ExecutingVersion
    $relevantVersion = $beforeState.HighestRelevantVersion

    if ($null -eq $relevantVersion) {
        throw "The version of the currently executing '$moduleName' module could not be determined."
    }

    Write-Verbose ("Executing version/path: {0} / {1}; loaded versions/paths: {2}; installed versions/paths: {3}." -f
        $executingVersion,
        $executingModule.Path,
        (@($beforeState.LoadedModules | ForEach-Object { '{0} [{1}]' -f $_.Version, $_.Path }) -join '; '),
        (@($beforeState.InstalledModules | ForEach-Object { '{0} [{1}]' -f $_.Version, $_.Path }) -join '; '))

    if ($packageIsWindows) {
        # Proxy preparation is connectivity setup, not the requested module installation.
        # Prevent an outer -WhatIf from leaking into the helper's internal Set-Variable calls.
        $callerWhatIfPreference = $WhatIfPreference
        try {
            $WhatIfPreference = $false

            # Manual proxy UI and non-interactive failure are handled by the private proxy bootstrap.
            Initialize-ProxyAccessProfile -TestUri $galleryApiUri -SuppressStatus

            if ($null -ne $Global:ProxyParamsPrepareSession) {
                $null = $Global:ProxyParamsPrepareSession.Invoke()
            }
            $installGv = Get-Variable -Scope Global -Name ProxyParamsInstallModule -ErrorAction SilentlyContinue
            if ($installGv -and $installGv.Value -is [hashtable] -and $installGv.Value.Count -gt 0) {
                foreach ($entry in $installGv.Value.GetEnumerator()) {
                    $proxyModuleParameters[[string]$entry.Key] = $entry.Value
                }
            }
        }
        finally {
            $WhatIfPreference = $callerWhatIfPreference
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

    $findCommand = Get-Command -Name 'Find-Module' -ErrorAction Stop
    $findCandidateParameters = @{}
    foreach ($entry in $proxyModuleParameters.GetEnumerator()) {
        $findCandidateParameters[[string]$entry.Key] = $entry.Value
    }
    $findCandidateParameters['Name'] = $moduleName
    $findCandidateParameters['Repository'] = $repository
    $findCandidateParameters['ErrorAction'] = 'Stop'
    $findParameters = Select-PackageCommandParameters `
        -Command $findCommand `
        -CandidateParameters $findCandidateParameters `
        -RequiredParameters @('Name', 'Repository')

    Write-Verbose ("Querying repository '{0}' with Find-Module {1} from '{2}'; reachability is handled separately by the proxy bootstrap." -f
        $repository,
        $findCommand.Version,
        $findCommand.Source)
    Write-Verbose ("Supported Find-Module parameters: {0}." -f (@($findCommand.Parameters.Keys | Sort-Object) -join ', '))
    Write-Verbose ("Effective Find-Module parameter names: {0}; proxy parameter names: {1}." -f
        (@($findParameters.Keys | Sort-Object) -join ', '),
        (@($proxyModuleParameters.Keys | Sort-Object) -join ', '))
    $activePackageManagementModules = @(Get-Module -Name 'PackageManagement' -ErrorAction SilentlyContinue)
    if ($activePackageManagementModules.Count -gt 0) {
        Write-Verbose ("Loaded PackageManagement versions/paths: {0}." -f
            (@($activePackageManagementModules | ForEach-Object { '{0} [{1}]' -f $_.Version, $_.Path }) -join '; '))
    }
    $repositoryModules = @(& $findCommand @findParameters)
    $repositoryVersions = @(
        foreach ($repositoryModule in $repositoryModules) {
            if ($null -eq $repositoryModule -or
                -not [string]::Equals([string]$repositoryModule.Name, $moduleName, [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            try {
                [pscustomobject]@{
                    Module  = $repositoryModule
                    Version = [version]([string]$repositoryModule.Version)
                }
            }
            catch {
                throw "PSGallery returned an invalid version '$($repositoryModule.Version)' for '$moduleName'."
            }
        }
    )

    $latestRepositoryModule = @($repositoryVersions | Sort-Object -Property Version -Descending | Select-Object -First 1)
    if ($latestRepositoryModule.Count -eq 0) {
        throw "PSGallery did not return a stable version for '$moduleName'."
    }

    $latestRepositoryVersion = [version]$latestRepositoryModule[0].Version
    $latestRepositoryVersionDisplay = Format-PackageVersionWithBuildDate -Version $latestRepositoryVersion
    $relevantVersionDisplay = Format-PackageVersionWithBuildDate -Version $relevantVersion
    Write-Verbose ("Highest relevant local version: {0}; latest stable PSGallery version: {1}." -f
        $relevantVersion, $latestRepositoryVersion)

    if ($latestRepositoryVersion -le $relevantVersion) {
        Write-StandardMessage `
            -Message "No newer version was found. Installed version: $relevantVersionDisplay." `
            -Level INF
        return
    }

    if (-not $PSCmdlet.ShouldProcess($moduleName, "Install version $latestRepositoryVersion for scope $Scope from $repository")) {
        Write-StandardMessage `
            -Message "A newer version was found. Installed version: $relevantVersionDisplay. Available version: $latestRepositoryVersionDisplay. No installation was performed." `
            -Level INF
        return
    }

    $installCommand = Get-Command -Name 'Install-Module' -ErrorAction Stop
    $installCandidateParameters = @{}
    foreach ($entry in $proxyModuleParameters.GetEnumerator()) {
        $installCandidateParameters[[string]$entry.Key] = $entry.Value
    }
    $installCandidateParameters['Name'] = $moduleName
    $installCandidateParameters['Repository'] = $repository
    $installCandidateParameters['Scope'] = $Scope
    $installCandidateParameters['RequiredVersion'] = $latestRepositoryVersion
    $installCandidateParameters['Force'] = $true
    $installCandidateParameters['AllowClobber'] = $true
    $installCandidateParameters['PassThru'] = $true
    $installCandidateParameters['ErrorAction'] = 'Stop'
    $installParameters = Select-PackageCommandParameters `
        -Command $installCommand `
        -CandidateParameters $installCandidateParameters `
        -RequiredParameters @('Name', 'Repository', 'Scope')

    $exactVersionRequested = $installParameters.ContainsKey('RequiredVersion')
    Write-Verbose ("Installing with Install-Module {0} from '{1}'; effective parameter names: {2}." -f
        $installCommand.Version,
        $installCommand.Source,
        (@($installParameters.Keys | Sort-Object) -join ', '))
    $installResult = @(& $installCommand @installParameters)
    if ($installResult.Count -gt 0) {
        Write-Verbose ("Install-Module returned version/location: {0}." -f
            (@($installResult | ForEach-Object { '{0} [{1}]' -f $_.Version, $_.InstalledLocation }) -join '; '))
    }

    $afterState = Get-PackageModuleVersionState -ModuleName $moduleName -ExecutingModule $executingModule
    $installedCandidates = @(
        $afterState.InstalledModules |
            Where-Object {
                $null -ne $_.Version -and
                $(if ($exactVersionRequested) {
                    [version]$_.Version -eq $latestRepositoryVersion
                }
                else {
                    [version]$_.Version -gt $relevantVersion
                })
            } |
            Sort-Object -Property Version -Descending
    )

    if ($installedCandidates.Count -eq 0) {
        if ($exactVersionRequested) {
            throw "Install-Module completed, but '$moduleName' version '$latestRepositoryVersion' was not visible through Get-Module -ListAvailable."
        }

        throw "Install-Module completed, but no newer '$moduleName' version was visible through Get-Module -ListAvailable."
    }

    $scopeEvaluations = @(
        foreach ($candidate in $installedCandidates) {
            [pscustomobject]@{
                Module = $candidate
                Scope = Test-PackageModuleInstallationScope -Module $candidate -Scope $Scope
            }
        }
    )
    $scopeMatchedCandidates = @($scopeEvaluations | Where-Object { $_.Scope.Matches })
    if ($scopeMatchedCandidates.Count -gt 0) {
        $installedModule = $scopeMatchedCandidates[0].Module
    }
    elseif (@($scopeEvaluations | Where-Object { $_.Scope.Known }).Count -gt 0) {
        $expectedScopeRoot = @($scopeEvaluations | Where-Object { $_.Scope.Known } | Select-Object -First 1)[0].Scope.ScopeRoot
        throw "Install-Module completed, but the newer '$moduleName' version was not visible in requested scope '$Scope' below '$expectedScopeRoot'."
    }
    else {
        Write-Verbose ("The requested installation scope path could not be determined; continuing with version/path verification only.")
        $installedModule = $installedCandidates[0]
    }

    $installedVersion = [version]$installedModule.Version
    Write-Verbose ("Verified installed version/path/scope: {0} / {1} / {2}." -f
        $installedVersion, $installedModule.Path, $Scope)
    $activation = Enable-PackageUpdatedModuleVersion `
        -ModuleName $moduleName `
        -Version $installedVersion `
        -InstalledModule $installedModule
    $installedVersionDisplay = Format-PackageVersionWithBuildDate -Version $installedVersion

    if ($activation.Active) {
        if ($activation.PreviousModuleStateLoaded) {
            Write-StandardMessage `
                -Message "$moduleName was updated from $relevantVersionDisplay to $installedVersionDisplay. Subsequent commands use the new version. The previous module version remains loaded; open a new PowerShell session to clear it." `
                -Level INF
            return
        }

        Write-StandardMessage `
            -Message "$moduleName was updated from $relevantVersionDisplay to $installedVersionDisplay. The new version is active for subsequent commands in this session." `
            -Level INF
        return
    }

    Write-Verbose ("Restart required after update: {0}" -f $activation.Reason)
    if ($null -ne $activation.CommandVersion -and [version]$activation.CommandVersion -eq $installedVersion) {
        Write-StandardMessage `
            -Message "$moduleName was updated from $relevantVersionDisplay to $installedVersionDisplay. Subsequent commands resolve to the new version, but older module state is still loaded. Open a new PowerShell session to clear it." `
            -Level INF
        return
    }

    Write-StandardMessage `
        -Message "$moduleName was updated from $relevantVersionDisplay to $installedVersionDisplay. This session is still using $executingVersion. Open a new PowerShell session to activate the update." `
        -Level INF
}
