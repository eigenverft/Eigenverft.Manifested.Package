[CmdletBinding()]
param(
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',

    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

$requiredArtifacts = @(
    [pscustomobject]@{
        Id                   = 'packageManagementPackage'
        ModuleName           = 'PackageManagement'
        RequiredVersion      = '1.4.8.1'
        FileName             = 'PackageManagement.1.4.8.1.nupkg'
        Sha256               = '7e1f8a75b6bc8a83d8abff79f6690fc1dfbd534fd3e5733d97e19bcb5954c13e'
        AllowClobber         = $true
        SkipPublisherCheck   = $true
        RequireNuGetProvider = $true
    }
    [pscustomobject]@{
        Id                   = 'powerShellGetPackage'
        ModuleName           = 'PowerShellGet'
        RequiredVersion      = '2.2.5'
        FileName             = 'PowerShellGet.2.2.5.nupkg'
        Sha256               = '6b8cebf2a464eaeb31b0a6d627355c30d9d1899dba0ce3bdd0d4e7afca148673'
        AllowClobber         = $true
        SkipPublisherCheck   = $false
        RequireNuGetProvider = $false
    }
    [pscustomobject]@{
        Id                   = 'package'
        ModuleName           = 'Eigenverft.Manifested.Package'
        RequiredVersion      = '1.20264.4323'
        FileName             = 'Eigenverft.Manifested.Package.1.20264.4323.nupkg'
        Sha256               = '59de7e2d2514d80ab917b9e22e369a0379c867c3d56a3f87e9f37ede1a294c89'
        AllowClobber         = $true
        SkipPublisherCheck   = $false
        RequireNuGetProvider = $false
    }
)

function Assert-BootstrapHost {
    if ($PSVersionTable.PSVersion -lt [Version]'5.1') {
        throw "Eigenverft.Manifested.Package bootstrap requires Windows PowerShell 5.1 or newer. Found '$($PSVersionTable.PSVersion)'."
    }
    if (-not [string]::Equals([string]$PSVersionTable.PSEdition, 'Desktop', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Run this bootstrap through Windows PowerShell (powershell.exe), not '$($PSVersionTable.PSEdition)' PowerShell."
    }
}

function Resolve-BootstrapArtifacts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArtifactDirectory,

        [Parameter(Mandatory = $true)]
        [object[]]$Artifacts
    )

    $resolvedArtifacts = New-Object System.Collections.Generic.List[object]
    $validationErrors = New-Object System.Collections.Generic.List[string]
    foreach ($artifact in $Artifacts) {
        $path = [System.IO.Path]::GetFullPath((Join-Path $ArtifactDirectory ([string]$artifact.FileName)))
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $validationErrors.Add("Missing required artifact '$($artifact.Id)': $path") | Out-Null
            continue
        }

        $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if (-not [string]::Equals($actualHash, [string]$artifact.Sha256, [System.StringComparison]::OrdinalIgnoreCase)) {
            $validationErrors.Add("Artifact '$($artifact.Id)' failed SHA-256 verification. Expected '$($artifact.Sha256)', found '$actualHash'.") | Out-Null
            continue
        }

        $resolvedArtifacts.Add([pscustomobject]@{
            Id                   = [string]$artifact.Id
            ModuleName           = [string]$artifact.ModuleName
            RequiredVersion      = [string]$artifact.RequiredVersion
            FileName             = [string]$artifact.FileName
            Path                 = $path
            Sha256               = [string]$artifact.Sha256
            AllowClobber         = [bool]$artifact.AllowClobber
            SkipPublisherCheck   = [bool]$artifact.SkipPublisherCheck
            RequireNuGetProvider = [bool]$artifact.RequireNuGetProvider
        }) | Out-Null
    }

    if ($validationErrors.Count -gt 0) {
        throw "Offline bootstrap artifact validation failed:`r`n - $([string]::Join("`r`n - ", @($validationErrors.ToArray())))"
    }

    return @($resolvedArtifacts.ToArray())
}

function Expand-BootstrapInstallerHelper {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $entryPath = 'Support/Package/Execution/Invoke-PackagePowerShellModuleInstall.ps1'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($PackagePath)
    try {
        $entry = $archive.Entries |
            Where-Object { [string]::Equals($_.FullName, $entryPath, [System.StringComparison]::OrdinalIgnoreCase) } |
            Select-Object -First 1
        if (-not $entry) {
            throw "Eigenverft package '$PackagePath' does not contain installer helper '$entryPath'."
        }

        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $DestinationPath)
    }
    finally {
        $archive.Dispose()
    }

    return $DestinationPath
}

function Invoke-BootstrapInstallerHelper {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Check', 'Install')]
        [string]$Operation,

        [Parameter(Mandatory = $true)]
        [psobject]$Artifact,

        [Parameter(Mandatory = $true)]
        [string]$HelperPath,

        [Parameter(Mandatory = $true)]
        [string]$WorkDirectory,

        [Parameter(Mandatory = $true)]
        [string]$NugetDirectory,

        [Parameter(Mandatory = $true)]
        [string]$ProviderDirectory,

        [Parameter(Mandatory = $true)]
        [string]$InstallScope
    )

    $requestId = '{0}-{1}' -f (($Artifact.ModuleName -replace '[^A-Za-z0-9.-]', '_')), $Operation.ToLowerInvariant()
    $requestPath = Join-Path $WorkDirectory ($requestId + '-request.json')
    $resultPath = Join-Path $WorkDirectory ($requestId + '-result.json')
    $request = [ordered]@{
        operation             = $Operation
        definitionId          = [string]$Artifact.ModuleName
        packageId             = [string]$Artifact.Id
        moduleName            = [string]$Artifact.ModuleName
        requiredVersion       = [string]$Artifact.RequiredVersion
        scope                 = $InstallScope
        allowClobber          = [bool]$Artifact.AllowClobber
        skipPublisherCheck    = [bool]$Artifact.SkipPublisherCheck
        requireNuGetProvider  = [bool]$Artifact.RequireNuGetProvider
        repositoryName        = 'EVFBootstrap_{0}' -f ([Guid]::NewGuid().ToString('N').Substring(0, 12))
        stageDirectory        = $WorkDirectory
        nugetDirectory        = $NugetDirectory
        providerDirectory     = $ProviderDirectory
    }
    $request | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $requestPath -Encoding UTF8

    $powerShellPath = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powerShellPath -PathType Leaf)) {
        throw "Windows PowerShell executable '$powerShellPath' was not found."
    }

    $helperOutput = @(
        & $powerShellPath -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $HelperPath -RequestPath $requestPath -ResultPath $resultPath 2>&1
    )
    $exitCode = $LASTEXITCODE
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
        throw "PowerShell module helper did not return a result for '$($Artifact.ModuleName)'. Exit code: $exitCode. Output: $([string]::Join(' | ', @($helperOutput)))"
    }

    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    if ($exitCode -ne 0 -or -not [bool]$result.success) {
        $message = if ($result.PSObject.Properties['errorMessage']) { [string]$result.errorMessage } else { [string]::Join(' | ', @($helperOutput)) }
        throw "PowerShell module helper $Operation failed for '$($Artifact.ModuleName)' version '$($Artifact.RequiredVersion)': $message"
    }

    return $result
}

Assert-BootstrapHost
$artifactDirectory = [System.IO.Path]::GetFullPath($PSScriptRoot)
$artifacts = @(Resolve-BootstrapArtifacts -ArtifactDirectory $artifactDirectory -Artifacts $requiredArtifacts)
$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$workDirectory = [System.IO.Path]::GetFullPath((Join-Path $tempBase ('Eigenverft.Manifested.Package.Bootstrap-' + [Guid]::NewGuid().ToString('N'))))
if (-not $workDirectory.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to create bootstrap work directory outside '$tempBase'."
}

try {
    $nugetDirectory = Join-Path $workDirectory 'Nuget'
    $providerDirectory = Join-Path $workDirectory 'Provider'
    New-Item -ItemType Directory -Path $nugetDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $providerDirectory -Force | Out-Null
    foreach ($artifact in $artifacts) {
        Copy-Item -LiteralPath $artifact.Path -Destination (Join-Path $nugetDirectory $artifact.FileName) -Force
    }

    $packageArtifact = $artifacts | Where-Object { $_.Id -eq 'package' } | Select-Object -First 1
    if (-not $packageArtifact) {
        throw "Offline bootstrap artifact set does not contain the Eigenverft package artifact."
    }
    $helperPath = Expand-BootstrapInstallerHelper -PackagePath $packageArtifact.Path -DestinationPath (Join-Path $workDirectory 'Invoke-PackagePowerShellModuleInstall.ps1')

    if ($ValidateOnly.IsPresent) {
        Write-Host "Eigenverft offline bootstrap bundle is valid. Verified $($artifacts.Count) module packages."
        return [pscustomobject]@{
            Status            = 'Valid'
            ArtifactDirectory = $artifactDirectory
            ArtifactCount     = $artifacts.Count
            Scope             = $Scope
        }
    }

    $installedModules = New-Object System.Collections.Generic.List[object]
    foreach ($artifact in $artifacts) {
        Write-Host "Checking $($artifact.ModuleName) $($artifact.RequiredVersion)..."
        $check = Invoke-BootstrapInstallerHelper -Operation Check -Artifact $artifact -HelperPath $helperPath -WorkDirectory $workDirectory -NugetDirectory $nugetDirectory -ProviderDirectory $providerDirectory -InstallScope $Scope
        if (-not [bool]$check.installed) {
            Write-Host "Installing $($artifact.ModuleName) $($artifact.RequiredVersion) from the offline bundle..."
            $install = Invoke-BootstrapInstallerHelper -Operation Install -Artifact $artifact -HelperPath $helperPath -WorkDirectory $workDirectory -NugetDirectory $nugetDirectory -ProviderDirectory $providerDirectory -InstallScope $Scope
            if (-not [bool]$install.installed) {
                throw "PowerShell module '$($artifact.ModuleName)' version '$($artifact.RequiredVersion)' was not installed."
            }
            $check = $install
        }
        else {
            Write-Host "Found $($artifact.ModuleName) $($artifact.RequiredVersion)."
        }
        $installedModules.Add([pscustomobject]@{
            Name       = [string]$artifact.ModuleName
            Version    = [string]$artifact.RequiredVersion
            ModuleBase = if ($check.PSObject.Properties['moduleBase']) { [string]$check.moduleBase } else { $null }
            Status     = [string]$check.status
        }) | Out-Null
    }

    $packageCheck = Invoke-BootstrapInstallerHelper -Operation Check -Artifact $packageArtifact -HelperPath $helperPath -WorkDirectory $workDirectory -NugetDirectory $nugetDirectory -ProviderDirectory $providerDirectory -InstallScope $Scope
    if (-not [bool]$packageCheck.installed) {
        throw "Eigenverft.Manifested.Package $($packageArtifact.RequiredVersion) was not discoverable after installation."
    }

    Write-Host "Eigenverft.Manifested.Package $($packageArtifact.RequiredVersion) offline bootstrap completed successfully."
    return [pscustomobject]@{
        Status            = 'Installed'
        ArtifactDirectory = $artifactDirectory
        Scope             = $Scope
        Modules           = @($installedModules.ToArray())
    }
}
finally {
    if ((Test-Path -LiteralPath $workDirectory -PathType Container) -and
        $workDirectory.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $workDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}
