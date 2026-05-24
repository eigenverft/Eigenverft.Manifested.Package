param (
    [string]$PsGalleryApiKey,
    [string]$NuGetGitHubPush
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
$NuGetGitHubPush = Get-ConfigValue -Check $NuGetGitHubPush -FilePath (Join-Path $PSScriptRoot 'cicd.secrets.json') -Property 'NuGetGitHubPush'
$PsGalleryApiKey = Get-ConfigValue -Check $PsGalleryApiKey -FilePath (Join-Path $PSScriptRoot 'cicd.secrets.json') -Property 'PsGalleryApiKey'
Test-VariableValue -Variable { $NuGetGitHubPush } -WarnIfNullOrEmpty -HideValue
Test-VariableValue -Variable { $PsGalleryApiKey } -ExitIfNullOrEmpty -HideValue

# Verify required commands are available
$null = Test-CommandAvailable -Command "dotnet" -ExitIfNotFound
$null = Test-CommandAvailable -Command "git" -ExitIfNotFound

# Enable the .NET tools specified in the manifest file
# Enable-TempDotnetTools -ManifestFile "$PSScriptRoot\.config\dotnet-tools\dotnet-tools.json" -NoReturn

# Preload environment information
$runEnvironment = Get-RunEnvironment
$gitTopLevelDirectory = Get-GitTopLevelDirectory
$gitCurrentBranch = Get-GitCurrentBranch
$gitCurrentBranchRoot = Get-GitCurrentBranchRoot
$gitRepositoryName = Get-GitRepositoryName
$gitRemoteUrl = Get-GitRemoteUrl
$GitHubPackagesUser = "eigenverft"
$GitHubSourceName = "github"
$GitHubSourceUri = $null

# Failfast / guard if any of the required preloaded environment information is not available
Test-VariableValue -Variable { $runEnvironment } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitTopLevelDirectory } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitCurrentBranch } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitCurrentBranchRoot } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitRepositoryName } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitRemoteUrl } -ExitIfNullOrEmpty

if (-not [string]::IsNullOrWhiteSpace($NuGetGitHubPush))
{
    $GitHubSourceUri = "https://nuget.pkg.github.com/$GitHubPackagesUser/index.json"
    Test-VariableValue -Variable { $GitHubSourceUri } -ExitIfNullOrEmpty
}

# Generate deployment info based on the current branch name
$deploymentInfo = Convert-BranchToDeploymentInfo -BranchName "$gitCurrentBranch"

# Generates a version based on the current date time to verify the version functions work as expected
$generatedVersion = Convert-DateTimeTo64SecPowershellVersion -VersionBuild 1
$probeGeneratedVersion = Convert-64SecPowershellVersionToDateTime -VersionBuild $generatedVersion.VersionBuild -VersionMajor $generatedVersion.VersionMajor -VersionMinor $generatedVersion.VersionMinor 
Test-VariableValue -Variable { $generatedVersion } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $probeGeneratedVersion } -ExitIfNullOrEmpty

# Generate a local PowerShell Gallery repository to publish to.
$LocalPowershellGalleryName = "LocalPowershellGallery"
$LocalPowershellGalleryName = Register-LocalPSGalleryRepository -RepositoryName "$LocalPowershellGalleryName"

# Generate a local NuGet package source to publish to.
$LocalNugetSourceName = "LocalNuget"
$LocalNugetSourceName = Register-LocalNuGetDotNetPackageSource -SourceName "$LocalNugetSourceName"

##############################################################################
# Main CICD Logic

$manifestPath = Join-Path $gitTopLevelDirectory 'src\prj\Eigenverft.Manifested.Sandbox\Eigenverft.Manifested.Sandbox.psd1'
if (-not (Test-Path -LiteralPath $manifestPath))
{
    throw "Expected module manifest was not found at '$manifestPath'."
}

$manifestFile = Get-Item -LiteralPath $manifestPath -ErrorAction Stop
Update-ManifestModuleVersion -ManifestPath "$($manifestFile.DirectoryName)" -NewVersion "$($generatedVersion.VersionFull)"
Update-ManifestPrerelease -ManifestPath "$($manifestFile.DirectoryName)" -NewPrerelease "$($deploymentInfo.Affix.Label)"

Write-Host "===> Testing module manifest at: $($manifestFile.FullName)" -ForegroundColor Cyan
Test-ModuleManifest -Path $($manifestFile.FullName)



$pushToLocalSource = $true
$pushToGitHubSource = $false
$pushToPsGallery = $false

if ($remoteResourcesOk -and -not [string]::IsNullOrWhiteSpace($NuGetGitHubPush))
{
    $pushToGitHubSource = $true
}

if ($remoteResourcesOk)
{
    $pushToPsGallery = $true
}

# Deploy generated module packages to the appropriate destinations
if ($pushToLocalSource -eq $true)
{
    Write-Host "===> Publishing module to local source '$LocalPowershellGalleryName'" -ForegroundColor Cyan
    Publish-Module -Path $($manifestFile.DirectoryName) -Repository "$LocalPowershellGalleryName"
}

if ($pushToGitHubSource -eq $true)
{
    $GitHubSourceRegistration = @{
        Name                 = "$GitHubSourceName"
        SourceLocation       = "$GitHubSourceUri"
        PublishLocation      = "$GitHubSourceUri"
        ScriptSourceLocation = "$GitHubSourceUri"
        ScriptPublishLocation= "$GitHubSourceUri"
        InstallationPolicy   = 'Trusted'
    }

    try
    {
        Write-Host "===> Registering temporary GitHub source '$GitHubSourceName' at '$GitHubSourceUri'" -ForegroundColor Cyan
        $ExistingGitHubPsRepository = Get-PSRepository -Name "$GitHubSourceName" -ErrorAction SilentlyContinue
        if ($null -ne $ExistingGitHubPsRepository)
        {
            Unregister-PSRepository -Name "$GitHubSourceName" -ErrorAction Stop
        }

        Unregister-LocalNuGetDotNetPackageSource -SourceName "$GitHubSourceName"
        Invoke-ProcessTyped -Executable "dotnet" -Arguments @("nuget", "add", "source", "--username", "$GitHubPackagesUser", "--password", "$NuGetGitHubPush", "--store-password-in-clear-text", "--name", "$GitHubSourceName", "$GitHubSourceUri") -CaptureOutput $false -CaptureOutputDump $false -HideValues @($NuGetGitHubPush)
        Register-PSRepository @GitHubSourceRegistration -ErrorAction Stop | Out-Null
        Write-Host "===> Publishing module to GitHub source '$GitHubSourceName'" -ForegroundColor Cyan
        Publish-Module -Path $($manifestFile.DirectoryName) -Repository "$GitHubSourceName" -NuGetApiKey "$NuGetGitHubPush"
    }
    finally
    {
        $ExistingGitHubPsRepository = Get-PSRepository -Name "$GitHubSourceName" -ErrorAction SilentlyContinue
        if ($null -ne $ExistingGitHubPsRepository)
        {
            Write-Host "===> Unregistering temporary GitHub source '$GitHubSourceName'" -ForegroundColor Cyan
            Unregister-PSRepository -Name "$GitHubSourceName" -ErrorAction Stop
        }

        Unregister-LocalNuGetDotNetPackageSource -SourceName "$GitHubSourceName"
    }
}

if ($pushToPsGallery -eq $true)
{
    Write-Host "===> Publishing module to PSGallery" -ForegroundColor Cyan
    Publish-Module -Path $($manifestFile.DirectoryName) -Repository "PSGallery" -NuGetApiKey "$PsGalleryApiKey"
}

$commitDatePrefix = Get-Date -Format 'yyyy-MM-dd'

if ($remoteResourcesOk)
{
    if ($($runEnvironment.IsCI)) {
        Invoke-GitAddCommitPush -TopLevelDirectory "$gitTopLevelDirectory" -Folders @("$($manifestFile.DirectoryName)") -CurrentBranch "$gitCurrentBranch" -UserName "eigenverft" -UserEmail "227559461+eigenverft@users.noreply.github.com" -CommitMessage "[$commitDatePrefix] Auto ver bump from CICD to $($generatedVersion.VersionFull) [skip ci]" -Tags @( "v$($generatedVersion.VersionFull)$($deploymentInfo.Affix.Suffix)" ) -ErrorAction Stop

        if (($pushToGitHubSource -eq $true) -and ($deploymentInfo.Branch.FirstSegmentLower -eq 'main'))
        {
            $releaseTag = "v$($generatedVersion.VersionFull)$($deploymentInfo.Affix.Suffix)"
            $null = Test-CommandAvailable -Command "gh" -ExitIfNotFound
            Write-Host "===> Creating GitHub release for tag '$releaseTag'" -ForegroundColor Cyan
            Invoke-ProcessTyped -Executable "gh" -Arguments @("release", "create", "$releaseTag", "--verify-tag", "--generate-notes") -CaptureOutput $false -CaptureOutputDump $false
        }
    } else {
        Invoke-GitAddCommitPush -TopLevelDirectory "$gitTopLevelDirectory" -Folders @("$($manifestFile.DirectoryName)") -CurrentBranch "$gitCurrentBranch" -UserName "eigenverft" -UserEmail "eigenverft@outlook.com" -CommitMessage "[$commitDatePrefix] Auto ver bump from local to $($generatedVersion.VersionFull) [skip ci]" -Tags @( "v$($generatedVersion.VersionFull)$($deploymentInfo.Affix.Suffix)" ) -ErrorAction Stop
    }
}
