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
        AllowClobber         = $true
        SkipPublisherCheck   = $true
        RequireNuGetProvider = $true
    }
    [pscustomobject]@{
        Id                   = 'powerShellGetPackage'
        ModuleName           = 'PowerShellGet'
        AllowClobber         = $true
        SkipPublisherCheck   = $false
        RequireNuGetProvider = $false
    }
    [pscustomobject]@{
        Id                   = 'package'
        ModuleName           = 'Eigenverft.Manifested.Package'
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

function Get-BootstrapNupkgMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $nuspecEntry = $archive.Entries |
            Where-Object { $_.FullName -notmatch '[/\\]' -and [string]::Equals([System.IO.Path]::GetExtension($_.FullName), '.nuspec', [System.StringComparison]::OrdinalIgnoreCase) } |
            Select-Object -First 1
        if (-not $nuspecEntry) {
            throw "Package '$Path' does not contain a root .nuspec file."
        }

        $reader = New-Object System.IO.StreamReader($nuspecEntry.Open())
        try {
            [xml]$nuspec = $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }

        $packageId = [string]$nuspec.package.metadata.id
        $versionText = [string]$nuspec.package.metadata.version
        $version = $null
        if ([string]::IsNullOrWhiteSpace($packageId) -or -not [Version]::TryParse($versionText, [ref]$version)) {
            throw "Package '$Path' has invalid id or version metadata in '$($nuspecEntry.FullName)'."
        }

        return [pscustomobject]@{
            PackageId = $packageId
            Version   = $version
            FileName  = [System.IO.Path]::GetFileName($Path)
            Path      = [System.IO.Path]::GetFullPath($Path)
        }
    }
    finally {
        $archive.Dispose()
    }
}

function Resolve-BootstrapArtifacts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArtifactDirectory,

        [Parameter(Mandatory = $true)]
        [object[]]$Artifacts
    )

    $packageMetadata = @(
        Get-ChildItem -LiteralPath $ArtifactDirectory -Filter '*.nupkg' -File -ErrorAction SilentlyContinue |
            ForEach-Object { Get-BootstrapNupkgMetadata -Path $_.FullName }
    )
    $resolvedArtifacts = New-Object System.Collections.Generic.List[object]
    $validationErrors = New-Object System.Collections.Generic.List[string]
    foreach ($artifact in $Artifacts) {
        $matches = @(
            $packageMetadata |
                Where-Object { [string]::Equals([string]$_.PackageId, [string]$artifact.ModuleName, [System.StringComparison]::OrdinalIgnoreCase) } |
                Sort-Object -Property Version -Descending
        )
        if ($matches.Count -eq 0) {
            $validationErrors.Add("Missing required package '$($artifact.ModuleName)' for artifact '$($artifact.Id)' in '$ArtifactDirectory'.") | Out-Null
            continue
        }

        $selected = $matches[0]
        Write-Host "Selected $($artifact.ModuleName) $($selected.Version) from '$($selected.FileName)'."

        $resolvedArtifacts.Add([pscustomobject]@{
            Id                   = [string]$artifact.Id
            ModuleName           = [string]$artifact.ModuleName
            RequiredVersion      = [string]$selected.Version
            RequiredVersionValue = [Version]$selected.Version
            FileName             = [string]$selected.FileName
            Path                 = [string]$selected.Path
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

function Find-LatestInstalledBootstrapModule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1
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
        Write-Host "Eigenverft offline bootstrap bundle is valid. Discovered $($artifacts.Count) module packages."
        return [pscustomobject]@{
            Status            = 'Valid'
            ArtifactDirectory = $artifactDirectory
            ArtifactCount     = $artifacts.Count
            Scope             = $Scope
        }
    }

    $installedModules = New-Object System.Collections.Generic.List[object]
    foreach ($artifact in $artifacts) {
        $latestInstalled = Find-LatestInstalledBootstrapModule -Name $artifact.ModuleName
        if (-not $latestInstalled -or $latestInstalled.Version -lt $artifact.RequiredVersionValue) {
            Write-Host "Installing $($artifact.ModuleName) $($artifact.RequiredVersion) from the offline bundle..."
            $null = Invoke-BootstrapInstallerHelper -Operation Install -Artifact $artifact -HelperPath $helperPath -WorkDirectory $workDirectory -NugetDirectory $nugetDirectory -ProviderDirectory $providerDirectory -InstallScope $Scope
            $latestInstalled = Find-LatestInstalledBootstrapModule -Name $artifact.ModuleName
            if (-not $latestInstalled -or $latestInstalled.Version -lt $artifact.RequiredVersionValue) {
                throw "PowerShell module '$($artifact.ModuleName)' version '$($artifact.RequiredVersion)' was not installed."
            }
        }
        else {
            Write-Host "Using installed $($artifact.ModuleName) $($latestInstalled.Version); bundled seed is $($artifact.RequiredVersion)."
        }
        $installedModules.Add([pscustomobject]@{
            Name       = [string]$artifact.ModuleName
            Version    = [string]$latestInstalled.Version
            ModuleBase = [string]$latestInstalled.ModuleBase
            Status     = if ($latestInstalled.Version -gt $artifact.RequiredVersionValue) { 'UsingNewerInstalledVersion' } else { 'UsingBundledVersion' }
        }) | Out-Null
    }

    $packageCheck = Find-LatestInstalledBootstrapModule -Name $packageArtifact.ModuleName
    if (-not $packageCheck -or $packageCheck.Version -lt $packageArtifact.RequiredVersionValue) {
        throw "Eigenverft.Manifested.Package $($packageArtifact.RequiredVersion) was not discoverable after installation."
    }

    Write-Host "Eigenverft.Manifested.Package $($packageCheck.Version) offline bootstrap completed successfully."
    Import-Module -Name $packageCheck.Path -Force -ErrorAction Stop
    Write-Host ''
    Write-Host 'The package console is ready:'
    Write-Host (Get-PackageVersion)
    Write-Host ''
    Write-Host 'You can now run Invoke-Package or any other command listed above. Type exit to close this window.'
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
