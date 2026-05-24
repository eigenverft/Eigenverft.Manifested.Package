param(
    [Parameter(Mandatory = $true)]
    [string]$RequestPath,

    [Parameter(Mandatory = $true)]
    [string]$ResultPath
)

$ErrorActionPreference = 'Stop'

function Write-Result {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Data
    )

    $directory = Split-Path -Parent $ResultPath
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $Data | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
}

function Enable-Tls12 {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch {
    }
}

function Initialize-SystemProxyDefaultCredentials {
    try {
        $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
        if ($proxy) {
            $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
            [System.Net.WebRequest]::DefaultWebProxy = $proxy
        }
    }
    catch {
    }
}

function Test-ProcessIsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-EffectiveModuleScope {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Scope
    )

    if ([string]::Equals($Scope, 'AllUsers', [System.StringComparison]::OrdinalIgnoreCase)) {
        if (-not (Test-ProcessIsAdministrator)) {
            throw 'PowerShell module scope AllUsers requires an elevated process.'
        }
        return 'AllUsers'
    }

    if (-not [string]::Equals($Scope, 'CurrentUser', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsupported PowerShell module scope '$Scope'. Use CurrentUser or AllUsers."
    }

    return 'CurrentUser'
}

function Find-InstalledModuleExact {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $true)]
        [string]$RequiredVersion
    )

    $required = [Version]$RequiredVersion
    Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue |
        Where-Object { $_.Version -eq $required } |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1
}

function Get-NuGetProviderTargetRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Scope
    )

    if ((Test-ProcessIsAdministrator) -or [string]::Equals($Scope, 'AllUsers', [System.StringComparison]::OrdinalIgnoreCase)) {
        return (Join-Path $env:ProgramFiles 'PackageManagement\ProviderAssemblies\NuGet')
    }

    return (Join-Path $env:LOCALAPPDATA 'PackageManagement\ProviderAssemblies\NuGet')
}

function Expand-NuGetProviderFromPackageManagementNupkg {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NugetDirectory,

        [Parameter(Mandatory = $true)]
        [string]$ProviderDirectory
    )

    $providerDll = Join-Path $ProviderDirectory 'Microsoft.PackageManagement.NuGetProvider.dll'
    if (Test-Path -LiteralPath $providerDll -PathType Leaf) {
        return $providerDll
    }

    $packageManagementPackage = Get-ChildItem -LiteralPath $NugetDirectory -Filter 'PackageManagement.*.nupkg' -File -ErrorAction SilentlyContinue |
        Sort-Object -Property Name -Descending |
        Select-Object -First 1
    if (-not $packageManagementPackage) {
        return $null
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($packageManagementPackage.FullName)
    try {
        $entry = $archive.Entries |
            Where-Object { [string]::Equals($_.FullName, 'fullclr/Microsoft.PackageManagement.NuGetProvider.dll', [System.StringComparison]::OrdinalIgnoreCase) } |
            Select-Object -First 1
        if (-not $entry) {
            return $null
        }

        if (-not (Test-Path -LiteralPath $ProviderDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $ProviderDirectory -Force | Out-Null
        }
        if (Test-Path -LiteralPath $providerDll -PathType Leaf) {
            Remove-Item -LiteralPath $providerDll -Force
        }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $providerDll)
        return $providerDll
    }
    finally {
        $archive.Dispose()
    }
}

function Ensure-NuGetProvider {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Scope,

        [Parameter(Mandatory = $true)]
        [string]$NugetDirectory,

        [Parameter(Mandatory = $true)]
        [string]$ProviderDirectory
    )

    $nuget = $null
    try {
        $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }
    catch {
        $nuget = $null
    }
    if ($nuget) {
        return 'AlreadyAvailable'
    }

    $providerDlls = @(Get-ChildItem -LiteralPath $ProviderDirectory -Filter '*.dll' -File -ErrorAction SilentlyContinue)
    if ($providerDlls.Count -eq 0) {
        $null = Expand-NuGetProviderFromPackageManagementNupkg -NugetDirectory $NugetDirectory -ProviderDirectory $ProviderDirectory
        $providerDlls = @(Get-ChildItem -LiteralPath $ProviderDirectory -Filter '*.dll' -File -ErrorAction SilentlyContinue)
    }
    if ($providerDlls.Count -eq 0) {
        throw "NuGet provider is not available and no provider DLLs were staged under '$ProviderDirectory'."
    }

    $targetRoot = Get-NuGetProviderTargetRoot -Scope $Scope
    if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $ProviderDirectory '*') -Destination $targetRoot -Recurse -Force -ErrorAction Stop

    $nuget = $null
    try {
        $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }
    catch {
        $nuget = $null
    }
    if (-not $nuget) {
        throw "NuGet provider bootstrap failed after copying provider files to '$targetRoot'."
    }

    return "Bootstrapped:$targetRoot"
}

function Register-TemporaryRepository {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryName,

        [Parameter(Mandatory = $true)]
        [string]$NugetDirectory
    )

    $existing = Get-PSRepository -Name $RepositoryName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-PSRepository -Name $RepositoryName -ErrorAction SilentlyContinue
    }

    Register-PSRepository -Name $RepositoryName -SourceLocation $NugetDirectory -PublishLocation $NugetDirectory -InstallationPolicy Trusted -ErrorAction Stop
}

function Install-ModuleFromLocalRepository {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Request
    )

    $moduleName = [string]$Request.moduleName
    $requiredVersion = [string]$Request.requiredVersion
    $scope = Get-EffectiveModuleScope -Scope ([string]$Request.scope)
    $nugetStatus = Ensure-NuGetProvider -Scope $scope -NugetDirectory ([string]$Request.nugetDirectory) -ProviderDirectory ([string]$Request.providerDirectory)
    $repositoryName = [string]$Request.repositoryName

    Register-TemporaryRepository -RepositoryName $repositoryName -NugetDirectory ([string]$Request.nugetDirectory)
    try {
        $installCommand = Get-Command Install-Module -ErrorAction Stop
        $installParameters = @{
            Name            = $moduleName
            RequiredVersion = $requiredVersion
            Repository      = $repositoryName
            Scope           = $scope
            Force           = $true
            ErrorAction     = 'Stop'
        }
        if ([bool]$Request.allowClobber -and $installCommand.Parameters.ContainsKey('AllowClobber')) {
            $installParameters['AllowClobber'] = $true
        }
        if ([bool]$Request.skipPublisherCheck -and $installCommand.Parameters.ContainsKey('SkipPublisherCheck')) {
            $installParameters['SkipPublisherCheck'] = $true
        }

        Install-Module @installParameters
    }
    finally {
        Unregister-PSRepository -Name $repositoryName -ErrorAction SilentlyContinue
    }

    $installed = Find-InstalledModuleExact -ModuleName $moduleName -RequiredVersion $requiredVersion
    if (-not $installed) {
        throw "PowerShell module '$moduleName' version '$requiredVersion' was not found after installation."
    }

    return @{
        module             = $installed
        scope              = $scope
        nugetProviderStatus = $nugetStatus
    }
}

function Get-HelperDiagnostics {
    param(
        [AllowNull()]
        [psobject]$Request,

        [AllowNull()]
        [string]$NuGetProviderStatus
    )

    $installModuleCommand = $null
    try {
        $installModuleCommand = Get-Command Install-Module -ErrorAction SilentlyContinue
    }
    catch {
        $installModuleCommand = $null
    }

    $nugetDirectory = if ($Request -and $Request.PSObject.Properties['nugetDirectory']) { [string]$Request.nugetDirectory } else { $null }
    $nupkgFiles = @()
    if (-not [string]::IsNullOrWhiteSpace($nugetDirectory) -and (Test-Path -LiteralPath $nugetDirectory -PathType Container)) {
        $nupkgFiles = @(Get-ChildItem -LiteralPath $nugetDirectory -Filter '*.nupkg' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    }

    return [pscustomobject]@{
        psVersion                          = [string]$PSVersionTable.PSVersion
        operation                          = if ($Request -and $Request.PSObject.Properties['operation']) { [string]$Request.operation } else { $null }
        repositoryName                     = if ($Request -and $Request.PSObject.Properties['repositoryName']) { [string]$Request.repositoryName } else { $null }
        nugetDirectory                     = $nugetDirectory
        nupkgCount                         = @($nupkgFiles).Count
        nupkgFiles                         = @($nupkgFiles)
        nugetProviderStatus                = $NuGetProviderStatus
        installModuleCommandSource         = if ($installModuleCommand) { [string]$installModuleCommand.Source } else { $null }
        installModuleCommandVersion        = if ($installModuleCommand -and $installModuleCommand.Module) { [string]$installModuleCommand.Module.Version } else { $null }
        installModuleHasAllowClobber       = if ($installModuleCommand) { $installModuleCommand.Parameters.ContainsKey('AllowClobber') } else { $false }
        installModuleHasSkipPublisherCheck = if ($installModuleCommand) { $installModuleCommand.Parameters.ContainsKey('SkipPublisherCheck') } else { $false }
    }
}

try {
    if (-not (Test-Path -LiteralPath $RequestPath -PathType Leaf)) {
        throw "Request JSON '$RequestPath' was not found."
    }
    $request = Get-Content -LiteralPath $RequestPath -Raw | ConvertFrom-Json
    Enable-Tls12
    Initialize-SystemProxyDefaultCredentials

    $operation = [string]$request.operation
    $installed = Find-InstalledModuleExact -ModuleName ([string]$request.moduleName) -RequiredVersion ([string]$request.requiredVersion)
    if ([string]::Equals($operation, 'Check', [System.StringComparison]::OrdinalIgnoreCase)) {
        $requireNuGetProvider = $false
        if ($request.PSObject.Properties['requireNuGetProvider']) {
            $requireNuGetProvider = [bool]$request.requireNuGetProvider
        }
        # Align with Eigenverft.Manifested.Drydock Initialize-PackageManagement: local module detection via
        # Get-Module only first; do not touch OneGet until a module is present and NuGet is policy-relevant.
        # Get-PackageProvider loads PackageManagement and can fault on hosts that still need that bootstrap.
        $nugetProviderAvailable = $true
        if ($requireNuGetProvider -and $installed) {
            try {
                $nugetProvider = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                $nugetProviderAvailable = [bool]$nugetProvider
            }
            catch {
                $nugetProviderAvailable = $false
            }
        }
        $accepted = [bool]$installed
        if ($requireNuGetProvider -and $installed -and -not $nugetProviderAvailable) {
            $accepted = $false
        }
        $status = if (-not $installed) {
            'NotInstalled'
        }
        elseif ($requireNuGetProvider -and -not $nugetProviderAvailable) {
            'NuGetProviderMissing'
        }
        else {
            'AlreadyInstalled'
        }
        Write-Result @{
            success          = $true
            status           = $status
            installed        = $accepted
            moduleInstalled  = [bool]$installed
            moduleName       = [string]$request.moduleName
            requiredVersion  = [string]$request.requiredVersion
            installedVersion = if ($installed) { [string]$installed.Version } else { $null }
            moduleBase       = if ($installed) { [string]$installed.ModuleBase } else { $null }
            scope            = [string]$request.scope
            requireNuGetProvider = $requireNuGetProvider
            nugetProviderAvailable = $nugetProviderAvailable
        }
        exit 0
    }

    if (-not [string]::Equals($operation, 'Install', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsupported helper operation '$operation'."
    }

    $installResult = Install-ModuleFromLocalRepository -Request $request
    $module = $installResult.module
    Write-Result @{
        success             = $true
        status              = 'Installed'
        installed           = $true
        moduleName          = [string]$request.moduleName
        requiredVersion     = [string]$request.requiredVersion
        installedVersion    = [string]$module.Version
        moduleBase          = [string]$module.ModuleBase
        scope               = [string]$installResult.scope
        repositoryName      = [string]$request.repositoryName
        nugetProviderStatus = [string]$installResult.nugetProviderStatus
    }
    exit 0
}
catch {
    $errorRecord = $_
    $invocation = $errorRecord.InvocationInfo
    Write-Result @{
        success                 = $false
        status                  = 'Failed'
        installed               = $false
        moduleName              = if ($request) { [string]$request.moduleName } else { $null }
        requiredVersion         = if ($request) { [string]$request.requiredVersion } else { $null }
        errorMessage            = $errorRecord.Exception.Message
        exceptionType           = $errorRecord.Exception.GetType().FullName
        failingCommandName      = if ($invocation) { [string]$invocation.MyCommand.Name } else { $null }
        scriptLineNumber        = if ($invocation) { [int]$invocation.ScriptLineNumber } else { $null }
        offsetInLine            = if ($invocation) { [int]$invocation.OffsetInLine } else { $null }
        diagnostics             = Get-HelperDiagnostics -Request $request -NuGetProviderStatus $null
    }
    exit 1
}
