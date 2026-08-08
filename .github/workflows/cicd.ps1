param (
    [string]$IntTestNuGetApiKey,
    [string]$NuGetApiKey,
    [string]$PowerShellGalleryApiKey,
    [string]$GitHubToken
)

# Fail-fast defaults for reliable CI/local runs:
# - StrictMode 3: treat uninitialized variables, unknown members, etc. as errors.
# - ErrorActionPreference='Stop': convert non-terminating errors into terminating ones (catchable).
# Error-handling guidance:
# - In catch{ }, prefer Write-Error or 'throw' to preserve fail-fast behavior.
#   * Write-Error (with ErrorActionPreference='Stop') is terminating and bubbles to the caller 'throw' is always terminating and keeps stack context.
# - Using Write-Host in catch{ } only logs and SWALLOWS the exception; execution continues, use a sentinel value (e.g., $null) explicitly.
# - Note: native tool exit codes on PS5 aren’t governed by ErrorActionPreference; use the Invoke-Exec wrapper to enforce policy.
Set-StrictMode -Version 3
$ErrorActionPreference     = 'Stop'   # errors become terminating
$Global:ConsoleLogMinLevel = 'INF'    # gate: TRC/DBG/INF/WRN/ERR/FTL

# Keep this script compatible with PowerShell 5.1 and PowerShell 7+
# Lean, pipeline-friendly style - simple, readable, and easy to modify, failfast on errors.
Write-Output "Powershell script $(Split-Path -Leaf $PSCommandPath) has started."

# Provides lightweight reachability guards for external services.
# Detection only - no installs, imports, network changes, or pushes. (e.g Test-PSGalleryConnectivity)
# Designed to short-circuit local and CI/CD workflows when dependencies are offline (e.g., skip a push if the Git host is unreachable).
. "$PSScriptRoot\cicd.bootstrap.ps1"

$remoteResourcesOk = Test-RemoteResourcesAvailable -Quiet

# Ensure connectivity to PowerShell Gallery before attempting module installation, if not assuming being offline, installation is present check existance with Test-ModuleAvailable
if ($remoteResourcesOk)
{
    # Install the required modules to run this script, Eigenverft.Manifested.Drydock needs to be Powershell 5.1 and Powershell 7+ compatible
    Update-ModuleIfNeeded -ModuleName 'Eigenverft.Manifested.Drydock'
    #Install-Module -Name 'Eigenverft.Manifested.Drydock' -Repository "PSGallery" -Scope CurrentUser -Force -AllowClobber -AllowPrerelease -ErrorAction Stop
}

# Verify the module is available, if not found exit the script with error
$null = Test-ModuleAvailable -Name 'Eigenverft.Manifested.Drydock' -IncludePrerelease -ExitIfNotFound -Quiet

# Required for updating PowerShellGet and PackageManagement providers in local PowerShell 5.x environments
Initialize-PowerShellMiniBootstrap

# Test TLS, NuGet, PackageManagement, PowerShellGet, and PSGallery publish endpoint
Test-PsGalleryPublishPrereqsOffline -ExitOnFailure

# Clean up previous versions of the module to avoid conflicts in local PowerShell environments
Uninstall-PreviousModuleVersions -ModuleName 'Eigenverft.Manifested.Drydock'

# In the case the secrets are not passed as parameters, try to get them from the secrets file, local development or CI/CD environment
# TBD https://learn.microsoft.com/de-de/powershell/utility-modules/secretmanagement/overview?view=ps-modules
$GitHubToken = Get-ConfigValue -Check $GitHubToken -FilePath (Join-Path $PSScriptRoot 'cicd.secrets.json') -Property 'NuGetGitHubPush'
$PowerShellGalleryApiKey = Get-ConfigValue -Check $PowerShellGalleryApiKey -FilePath (Join-Path $PSScriptRoot 'cicd.secrets.json') -Property 'PsGalleryApiKey'
Test-VariableValue -Variable { $GitHubToken } -WarnIfNullOrEmpty -HideValue
Test-VariableValue -Variable { $PowerShellGalleryApiKey } -ExitIfNullOrEmpty -HideValue

# Verify required commands are available
$null = Test-CommandAvailable -Command "dotnet" -ExitIfNotFound
$null = Test-CommandAvailable -Command "git" -ExitIfNotFound
$null = Test-CommandAvailable -Command "Publish-PowerShellModuleRelease" -ExitIfNotFound

# Enable the .NET tools specified in the manifest file
# Enable-TempDotnetTools -ManifestFile "$PSScriptRoot\.config\dotnet-tools\dotnet-tools.json" -NoReturn

# Preload environment information
$runEnvironment = Get-RunEnvironment
$gitTopLevelDirectory = Get-GitTopLevelDirectory
$gitCurrentBranch = Get-GitCurrentBranch
$gitCurrentBranchRoot = Get-GitCurrentBranchRoot
$gitRepositoryName = Get-GitRepositoryName
$gitRemoteUrl = Get-GitRemoteUrl

# Failfast / guard if any of the required preloaded environment information is not available
Test-VariableValue -Variable { $runEnvironment } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitTopLevelDirectory } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitCurrentBranch } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitCurrentBranchRoot } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitRepositoryName } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitRemoteUrl } -ExitIfNullOrEmpty



##############################################################################
# Phase 1: Resolve deployment context

$deploymentResolution = Convert-BranchToDeploymentInfo -BranchName "$gitCurrentBranch"

Write-Host "===> Resolved deployment context" -ForegroundColor Cyan
Write-Host "Branch.Name                      : $gitCurrentBranch"
Write-Host "Branch.Segments                  : $($deploymentResolution.Branch.Segments -join ', ')"
Write-Host "Branch.PathSegmentsSanitized     : $($deploymentResolution.Branch.PathSegmentsSanitized -join ', ')"
Write-Host "Branch.FirstSegmentLower         : $($deploymentResolution.Branch.FirstSegmentLower)"
Write-Host "Channel.Value                    : $($deploymentResolution.Channel.Value)"
Write-Host "Channel.Source                   : $($deploymentResolution.Channel.Source)"
Write-Host "Channel.SegmentsWithChannelFirst : $($deploymentResolution.Channel.SegmentsWithChannelFirst -join ', ')"
Write-Host "Affix.Label                      : $($deploymentResolution.Affix.Label)"
Write-Host "Affix.Prefix                     : $($deploymentResolution.Affix.Prefix)"
Write-Host "Affix.Suffix                     : $($deploymentResolution.Affix.Suffix)"
Write-Host "Affix.Separator                  : $($deploymentResolution.Affix.Separator)"
Write-Host "Affix.LabelCase                  : $($deploymentResolution.Affix.LabelCase)"
Write-Host "Affix.HasLabel                   : $($deploymentResolution.Affix.HasLabel)"

# Generates a version based on the current date time to verify the version functions work as expected
$generatedVersion = Convert-DateTimeTo64SecPowershellVersion -VersionBuild 1
$probeGeneratedVersion = Convert-64SecPowershellVersionToDateTime -VersionBuild $generatedVersion.VersionBuild -VersionMajor $generatedVersion.VersionMajor -VersionMinor $generatedVersion.VersionMinor 
Test-VariableValue -Variable { $generatedVersion } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $probeGeneratedVersion } -ExitIfNullOrEmpty



##############################################################################
# Phase 2: Resolve deployment decisions

switch ($deploymentResolution.Channel.Value)
{
    'production'
    {
        $deploymentDecisions = [pscustomobject][ordered]@{
            UpdateModuleManifestVersion = $true
            PublishLocalSource       = $true
            PublishGitHubSource      = [bool]($remoteResourcesOk -and -not [string]::IsNullOrWhiteSpace($GitHubToken))
            PublishPsGallery         = [bool]$remoteResourcesOk
            CommitVersionChange      = [bool]$remoteResourcesOk
            PushVersionCommit        = [bool]$remoteResourcesOk
            CreateGitTag             = [bool]$remoteResourcesOk
            CreateGitHubRelease      = [bool](
                $runEnvironment.IsCI -and
                $remoteResourcesOk -and
                -not [string]::IsNullOrWhiteSpace($GitHubToken) -and
                $deploymentResolution.Branch.FirstSegmentLower -eq 'main'
            )
        }
    }

    default
    {
        # Non-production channels currently build and publish locally only.
        # Staging, quality, and development can receive dedicated decision objects later
        # without changing the validation or execution phases below.
        $deploymentDecisions = [pscustomobject][ordered]@{
            UpdateModuleManifestVersion = $true
            PublishLocalSource       = $true
            PublishGitHubSource      = $false
            PublishPsGallery         = $false
            CommitVersionChange      = $false
            PushVersionCommit        = $false
            CreateGitTag             = $false
            CreateGitHubRelease      = $false
        }
    }
}

##############################################################################
# Phase 3: Prepare and validate deployment artifacts

$manifestFiles = @(Find-FilesByPattern -Path "$gitTopLevelDirectory" -Pattern "$gitRepositoryName.psd1")
if ($manifestFiles.Count -ne 1)
{
    throw "Expected exactly one module manifest named '$gitRepositoryName.psd1' under '$gitTopLevelDirectory', but found $($manifestFiles.Count)."
}

$manifestFile = $manifestFiles[0]

if ($deploymentDecisions.UpdateModuleManifestVersion)
{
    Update-ManifestModuleVersion -ManifestPath "$($manifestFile.DirectoryName)" -NewVersion "$($generatedVersion.VersionFull)"
    Update-ManifestPrerelease -ManifestPath "$($manifestFile.DirectoryName)" -NewPrerelease "$($deploymentResolution.Affix.Label)"
}

Write-Host "===> Testing module manifest at: $($manifestFile.FullName)" -ForegroundColor Cyan
Test-ModuleManifest -Path $($manifestFile.FullName)



##############################################################################
# Phase 4: Execute deployment decisions

Write-Host "===> Executing deployment decisions" -ForegroundColor Cyan

if ($deploymentDecisions.PublishLocalSource)
{
    Write-Host "===> Publishing module to local source 'LocalPowershellGallery'" -ForegroundColor Cyan
    Publish-PowerShellModuleRelease -Path $manifestFile.DirectoryName -Target 'Local' -RepositoryName 'LocalPowershellGallery' -ErrorAction Stop
}

if ($deploymentDecisions.PublishGitHubSource)
{
    Write-Host "===> Publishing module to GitHub source 'github'" -ForegroundColor Cyan
    Publish-PowerShellModuleRelease -Path $manifestFile.DirectoryName -Target 'GitHubPackages' -RepositoryName 'github' -GitHubOwner 'eigenverft' -GitHubToken $GitHubToken -ErrorAction Stop
}

if ($deploymentDecisions.PublishPsGallery)
{
    Write-Host "===> Publishing module to PSGallery" -ForegroundColor Cyan
    Publish-PowerShellModuleRelease -Path $manifestFile.DirectoryName -Target 'PSGallery' -ApiKey $PowerShellGalleryApiKey -ErrorAction Stop
}



##############################################################################
# Phase 5: Persist deployment results

$commitDatePrefix = Get-Date -Format 'yyyy-MM-dd'
$deploymentTags = @()

if ($deploymentDecisions.CreateGitTag)
{
    $deploymentTags = @("v$($generatedVersion.VersionFull)")
}

if ($deploymentDecisions.CommitVersionChange -and $deploymentDecisions.PushVersionCommit)
{
    if ($runEnvironment.IsCI)
    {
        Invoke-GitAddCommitPush -TopLevelDirectory "$gitTopLevelDirectory" -Folders @("$($manifestFile.DirectoryName)") -CurrentBranch "$gitCurrentBranch" -UserName "eigenverft" -UserEmail "227559461+eigenverft@users.noreply.github.com" -CommitMessage "[$commitDatePrefix] Auto ver bump from CICD to $($generatedVersion.VersionFull) [skip ci]" -Tags $deploymentTags -ErrorAction Stop
    }
    else
    {
        Invoke-GitAddCommitPush -TopLevelDirectory "$gitTopLevelDirectory" -Folders @("$($manifestFile.DirectoryName)") -CurrentBranch "$gitCurrentBranch" -UserName "eigenverft" -UserEmail "eigenverft@outlook.com" -CommitMessage "[$commitDatePrefix] Auto ver bump from local to $($generatedVersion.VersionFull) [skip ci]" -Tags $deploymentTags -ErrorAction Stop
    }
}
else
{
    Write-Host "===> Commit, push, and tag actions are disabled by the resolved deployment decisions." -ForegroundColor Yellow
}

if ($deploymentDecisions.CreateGitHubRelease)
{
    $releaseTag = "v$($generatedVersion.VersionFull)"
    $null = Test-CommandAvailable -Command "gh" -ExitIfNotFound
    Write-Host "===> Creating GitHub release for tag '$releaseTag'" -ForegroundColor Cyan
    Invoke-ProcessTyped -Executable "gh" -Arguments @("release", "create", "$releaseTag", "--verify-tag", "--generate-notes") -CaptureOutput $false -CaptureOutputDump $false
}
else
{
    Write-Host "===> GitHub release creation is disabled by the resolved deployment decisions." -ForegroundColor Yellow
}
