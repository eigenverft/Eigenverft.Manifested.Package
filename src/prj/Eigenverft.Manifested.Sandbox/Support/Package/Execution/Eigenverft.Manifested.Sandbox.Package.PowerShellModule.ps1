<#
    Eigenverft.Manifested.Sandbox.Package.PowerShellModule
#>

$script:PackagePowerShellModuleExecutionRoot = $PSScriptRoot

function Get-PackageWindowsPowerShellPath {
    [CmdletBinding()]
    param()

    $systemRoot = if ([string]::IsNullOrWhiteSpace($env:SystemRoot)) {
        [Environment]::GetFolderPath('Windows')
    }
    else {
        [string]$env:SystemRoot
    }
    $powerShellPath = [System.IO.Path]::GetFullPath((Join-Path $systemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'))
    if (-not (Test-Path -LiteralPath $powerShellPath -PathType Leaf)) {
        throw "Windows PowerShell 5.1 executable '$powerShellPath' was not found."
    }

    return $powerShellPath
}

function Get-PackagePowerShellModuleHelperScriptPath {
    [CmdletBinding()]
    param()

    $helperPath = [System.IO.Path]::GetFullPath((Join-Path $script:PackagePowerShellModuleExecutionRoot 'Invoke-PackagePowerShellModuleInstall.ps1'))
    if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
        throw "PowerShell module installer helper '$helperPath' was not found."
    }

    return $helperPath
}

function Get-PackagePowerShellModuleInstallOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $install = Get-PackageAssignedInstallOperation -Release $PackageResult.Package
    if (-not $install -or -not [string]::Equals([string]$install.kind, 'powershellModuleInstaller', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Package '$($PackageResult.DefinitionId)' is not configured with packageOperations.assigned.install.kind powershellModuleInstaller."
    }
    foreach ($requiredProperty in @('moduleName', 'requiredVersion')) {
        if (-not $install.PSObject.Properties[$requiredProperty] -or [string]::IsNullOrWhiteSpace([string]$install.$requiredProperty)) {
            throw "Package '$($PackageResult.DefinitionId)' powershellModuleInstaller requires packageOperations.assigned.install.$requiredProperty."
        }
    }

    return $install
}

function New-PackagePowerShellModuleRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Check', 'Install')]
        [string]$Operation,

        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [psobject]$Install,

        [Parameter(Mandatory = $true)]
        [string]$StageDirectory,

        [Parameter(Mandatory = $true)]
        [string]$NugetDirectory,

        [Parameter(Mandatory = $true)]
        [string]$ProviderDirectory
    )

    $scope = if ($Install.PSObject.Properties['scope'] -and -not [string]::IsNullOrWhiteSpace([string]$Install.scope)) {
        [string]$Install.scope
    }
    else {
        'CurrentUser'
    }
    $allowClobber = if ($Install.PSObject.Properties['allowClobber']) { [bool]$Install.allowClobber } else { $false }
    $skipPublisherCheck = if ($Install.PSObject.Properties['skipPublisherCheck']) { [bool]$Install.skipPublisherCheck } else { $false }
    $repositoryName = 'EVFLocal_{0}' -f ([Guid]::NewGuid().ToString('N').Substring(0, 12))

    return [pscustomobject]@{
        operation          = $Operation
        definitionId       = [string]$PackageResult.DefinitionId
        packageId          = [string]$PackageResult.PackageId
        moduleName         = [string]$Install.moduleName
        requiredVersion    = [string]$Install.requiredVersion
        scope              = $scope
        allowClobber       = $allowClobber
        skipPublisherCheck = $skipPublisherCheck
        requireNuGetProvider = if ($Install.PSObject.Properties['requireNuGetProvider']) { [bool]$Install.requireNuGetProvider } else { $false }
        repositoryName     = $repositoryName
        stageDirectory     = [System.IO.Path]::GetFullPath($StageDirectory)
        nugetDirectory     = [System.IO.Path]::GetFullPath($NugetDirectory)
        providerDirectory  = [System.IO.Path]::GetFullPath($ProviderDirectory)
    }
}

function Get-PackagePowerShellModuleDependencyPackageFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Dependency
    )

    $dependencyResult = if ($Dependency.PSObject.Properties['Result']) { $Dependency.Result } else { $null }
    if (-not $dependencyResult) {
        return $null
    }

    $installKind = if ($dependencyResult.Assigned -and $dependencyResult.Assigned.PSObject.Properties['InstallKind']) {
        [string]$dependencyResult.Assigned.InstallKind
    }
    else {
        $null
    }
    if (-not [string]::Equals($installKind, 'powershellModuleInstaller', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }

    foreach ($candidatePath in @(
            $(if ($dependencyResult.PSObject.Properties['DefaultPackageDepotFilePath']) { [string]$dependencyResult.DefaultPackageDepotFilePath } else { $null })
            $(if ($dependencyResult.Assigned -and $dependencyResult.Assigned.PSObject.Properties['PackageFilePath']) { [string]$dependencyResult.Assigned.PackageFilePath } else { $null })
            $(if ($dependencyResult.PSObject.Properties['PackageFilePath']) { [string]$dependencyResult.PackageFilePath } else { $null })
        )) {
        if (-not [string]::IsNullOrWhiteSpace($candidatePath) -and
            [string]::Equals([System.IO.Path]::GetExtension($candidatePath), '.nupkg', [System.StringComparison]::OrdinalIgnoreCase) -and
            (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
            return [System.IO.Path]::GetFullPath($candidatePath)
        }
    }

    return $null
}

function Copy-PackagePowerShellModuleDependencyPackagesToLocalRepository {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [string]$NugetDirectory
    )

    $null = New-Item -ItemType Directory -Path $NugetDirectory -Force
    $copied = New-Object System.Collections.Generic.List[string]
    foreach ($dependency in @($PackageResult.Dependencies)) {
        if ($null -eq $dependency) {
            continue
        }

        $dependencyPackageFile = Get-PackagePowerShellModuleDependencyPackageFile -Dependency $dependency
        if ([string]::IsNullOrWhiteSpace($dependencyPackageFile)) {
            continue
        }

        $targetPath = [System.IO.Path]::GetFullPath((Join-Path $NugetDirectory (Split-Path -Leaf $dependencyPackageFile)))
        if ([string]::Equals($dependencyPackageFile, $targetPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $null = Copy-FileToPath -SourcePath $dependencyPackageFile -TargetPath $targetPath -Overwrite
        $copied.Add($targetPath) | Out-Null
    }

    if ($copied.Count -gt 0) {
        Write-PackageExecutionMessage -Message ("[PSMODULE-DIAG] Staged PowerShell module dependency package(s) into local repository: {0}" -f ([string]::Join(', ', @($copied.ToArray()))))
    }

    return @($copied.ToArray())
}

function Invoke-PackagePowerShellModuleHelper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [AllowNull()]
        [psobject]$Install,

        [ValidateSet('Check', 'Install')]
        [string]$Operation = 'Install'
    )

    if (-not $Install) {
        $Install = Get-PackagePowerShellModuleInstallOperation -PackageResult $PackageResult
    }
    foreach ($requiredProperty in @('moduleName', 'requiredVersion')) {
        if (-not $Install.PSObject.Properties[$requiredProperty] -or [string]::IsNullOrWhiteSpace([string]$Install.$requiredProperty)) {
            throw "Package '$($PackageResult.DefinitionId)' PowerShell module helper requires $requiredProperty."
        }
    }
    if ([string]::IsNullOrWhiteSpace([string]$PackageResult.PackageInstallStageDirectory)) {
        throw "Package '$($PackageResult.DefinitionId)' powershellModuleInstaller requires a package install stage directory."
    }

    $stageDirectory = [System.IO.Path]::GetFullPath([string]$PackageResult.PackageInstallStageDirectory)
    if ($Operation -eq 'Install') {
        if ([string]::IsNullOrWhiteSpace([string]$PackageResult.PackageFilePath) -or -not (Test-Path -LiteralPath $PackageResult.PackageFilePath -PathType Leaf)) {
            throw "Package '$($PackageResult.DefinitionId)' powershellModuleInstaller requires a staged .nupkg package file."
        }
        Remove-PathIfExists -Path $stageDirectory | Out-Null
    }
    $null = New-Item -ItemType Directory -Path $stageDirectory -Force

    $nugetDirectory = [System.IO.Path]::GetFullPath((Join-Path $stageDirectory 'Nuget'))
    $providerDirectory = [System.IO.Path]::GetFullPath((Join-Path $stageDirectory 'Provider'))
    $null = New-Item -ItemType Directory -Path $nugetDirectory -Force
    $null = New-Item -ItemType Directory -Path $providerDirectory -Force

    if ($Operation -eq 'Install') {
        $targetPackageFile = [System.IO.Path]::GetFullPath((Join-Path $nugetDirectory (Split-Path -Leaf ([string]$PackageResult.PackageFilePath))))
        $null = Copy-FileToPath -SourcePath ([string]$PackageResult.PackageFilePath) -TargetPath $targetPackageFile -Overwrite
        $null = Copy-PackagePowerShellModuleDependencyPackagesToLocalRepository -PackageResult $PackageResult -NugetDirectory $nugetDirectory
    }

    $requestPath = [System.IO.Path]::GetFullPath((Join-Path $stageDirectory 'powershell-module-install-request.json'))
    $resultPath = [System.IO.Path]::GetFullPath((Join-Path $stageDirectory 'powershell-module-install-result.json'))
    if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
        Remove-Item -LiteralPath $resultPath -Force
    }

    $request = New-PackagePowerShellModuleRequest -Operation $Operation -PackageResult $PackageResult -Install $Install -StageDirectory $stageDirectory -NugetDirectory $nugetDirectory -ProviderDirectory $providerDirectory
    $request | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $requestPath -Encoding UTF8

    $timeoutSec = if ($Install.PSObject.Properties['timeoutSec'] -and [int]$Install.timeoutSec -gt 0) { [int]$Install.timeoutSec } else { 600 }
    $powerShellPath = Get-PackageWindowsPowerShellPath
    $helperScriptPath = Get-PackagePowerShellModuleHelperScriptPath
    $commandArguments = @(
        '-NoLogo'
        '-NoProfile'
        '-NonInteractive'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        (Format-PackageProcessArgument -Value $helperScriptPath)
        '-RequestPath'
        (Format-PackageProcessArgument -Value $requestPath)
        '-ResultPath'
        (Format-PackageProcessArgument -Value $resultPath)
    )

    Write-PackageExecutionMessage -Message ("[STATE] PowerShell module helper operation='{0}', module='{1}', version='{2}'." -f $Operation, [string]$Install.moduleName, [string]$Install.requiredVersion)
    Write-PackageExecutionMessage -Message ("[PATH] PowerShell module helper: {0}" -f $helperScriptPath)
    Write-PackageExecutionMessage -Message ("[PATH] PowerShell module local repository: {0}" -f $nugetDirectory)
    Write-PackageExecutionMessage -Message ("[PSMODULE-DIAG] Helper launch: powershell='{0}', helper='{1}', request='{2}', result='{3}'." -f $powerShellPath, $helperScriptPath, $requestPath, $resultPath)
    Write-PackageExecutionMessage -Message ("[PSMODULE-DIAG] Helper command arguments: {0}" -f ([string]::Join(' ', @($commandArguments | ForEach-Object { [string]$_ }))))

    $installerResult = $null
    try {
        $installerResult = Invoke-PackageInstallerCommand `
            -PackageResult $PackageResult `
            -CommandPath $powerShellPath `
            -CommandArguments @($commandArguments) `
            -WorkingDirectory $stageDirectory `
            -TimeoutSec $timeoutSec `
            -SuccessExitCodes @(0) `
            -RestartExitCodes @() `
            -TargetKind 'powershellModule' `
            -InstallerKind 'powershellModuleInstaller' `
            -UiMode 'silent' `
            -LogPath $null `
            -ElevationMode 'none' `
            -WindowStyle 'Hidden'
    }
    catch {
        $resultJsonExists = Test-Path -LiteralPath $resultPath -PathType Leaf
        Write-PackageExecutionMessage -Level 'WRN' -Message ("[PSMODULE-DIAG] Helper process failed: resultJsonExists='{0}', error='{1}'." -f $resultJsonExists, $_.Exception.Message)
        if ($resultJsonExists) {
            try {
                $failedHelperResult = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
                $failedStatus = if ($failedHelperResult.PSObject.Properties['status']) { [string]$failedHelperResult.status } else { '<missing>' }
                $failedMessage = if ($failedHelperResult.PSObject.Properties['errorMessage']) { [string]$failedHelperResult.errorMessage } else { '<missing>' }
                Write-PackageExecutionMessage -Level 'WRN' -Message ("[PSMODULE-DIAG] Helper failure result: status='{0}', error='{1}'." -f $failedStatus, $failedMessage)
                if ($failedHelperResult.PSObject.Properties['diagnostics'] -and $failedHelperResult.diagnostics) {
                    $diag = $failedHelperResult.diagnostics
                    Write-PackageExecutionMessage -Level 'WRN' -Message ("[PSMODULE-DIAG] Helper failure environment: psVersion='{0}', installModuleSource='{1}', allowClobberParam='{2}', skipPublisherCheckParam='{3}', nugetProviderStatus='{4}', repository='{5}', nupkgCount='{6}', nupkgFiles='{7}'." -f $diag.psVersion, $diag.installModuleCommandSource, $diag.installModuleHasAllowClobber, $diag.installModuleHasSkipPublisherCheck, $diag.nugetProviderStatus, $diag.repositoryName, $diag.nupkgCount, ([string]::Join(',', @($diag.nupkgFiles | ForEach-Object { [string]$_ }))))
                }
                throw "PowerShell module helper failed: $failedMessage"
            }
            catch {
                if ($_.Exception.Message -like 'PowerShell module helper failed:*') {
                    throw
                }
                Write-PackageExecutionMessage -Level 'WRN' -Message ("[PSMODULE-DIAG] Failed to read helper failure result JSON '{0}': {1}" -f $resultPath, $_.Exception.Message)
            }
        }
        throw
    }

    Write-PackageExecutionMessage -Message ("[PSMODULE-DIAG] Helper exited: exitCode='{0}', resultJsonExists='{1}'." -f $installerResult.ExitCode, (Test-Path -LiteralPath $resultPath -PathType Leaf))

    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
        throw "PowerShell module helper did not write result JSON '$resultPath'."
    }

    $helperResult = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    Write-PackageExecutionMessage -Message ("[PSMODULE-DIAG] Helper result: success='{0}', status='{1}', installed='{2}'." -f $(if ($helperResult.PSObject.Properties['success']) { [string][bool]$helperResult.success } else { '<missing>' }), $(if ($helperResult.PSObject.Properties['status']) { [string]$helperResult.status } else { '<missing>' }), $(if ($helperResult.PSObject.Properties['installed']) { [string][bool]$helperResult.installed } else { '<missing>' }))
    if ($helperResult.PSObject.Properties['success'] -and -not [bool]$helperResult.success) {
        $message = if ($helperResult.PSObject.Properties['errorMessage']) { [string]$helperResult.errorMessage } else { 'unknown helper failure' }
        throw "PowerShell module helper failed: $message"
    }

    return [pscustomobject]@{
        HelperResult = $helperResult
        Installer    = $installerResult
        RequestPath  = $requestPath
        ResultPath   = $resultPath
        NugetDirectory = $nugetDirectory
        ProviderDirectory = $providerDirectory
    }
}

function Test-PackagePowerShellModulePresence {
<#
.SYNOPSIS
Checks for an exact PowerShell module version through the same PS5.1 helper used by the installer.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$RequiredVersion,

        [string]$Scope = 'CurrentUser',

        [bool]$RequireNuGetProvider = $false,

        [bool]$TreatFailureAsNotInstalled = $false
    )

    $install = [pscustomobject]@{
        kind                 = 'powershellModuleInstaller'
        moduleName           = $Name
        requiredVersion      = $RequiredVersion
        scope                = if ([string]::IsNullOrWhiteSpace($Scope)) { 'CurrentUser' } else { $Scope }
        allowClobber         = $false
        skipPublisherCheck   = $false
        timeoutSec           = 600
        requireNuGetProvider = $RequireNuGetProvider
    }

    try {
        $result = Invoke-PackagePowerShellModuleHelper -PackageResult $PackageResult -Install $install -Operation Check
    }
    catch {
        if (-not $TreatFailureAsNotInstalled) {
            throw
        }

        Write-PackageExecutionMessage -Level 'WRN' -Message ("[PSMODULE-DIAG] PowerShell module check failed for '{0}' version '{1}'; treating it as not installed for existing-install discovery: {2}" -f $Name, $RequiredVersion, $_.Exception.Message)
        return [pscustomobject]@{
            success                = $false
            status                 = 'ProbeFailed'
            installed              = $false
            moduleInstalled        = $false
            moduleName             = $Name
            requiredVersion        = $RequiredVersion
            installedVersion       = $null
            moduleBase             = $null
            scope                  = $Scope
            requireNuGetProvider   = $RequireNuGetProvider
            nugetProviderAvailable = $null
            errorMessage           = $_.Exception.Message
        }
    }
    return $result.HelperResult
}

function Install-PackagePowerShellModule {
<#
.SYNOPSIS
Installs an exact PowerShell module version from the staged .nupkg through a local PSRepository.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $install = Get-PackagePowerShellModuleInstallOperation -PackageResult $PackageResult
    $result = Invoke-PackagePowerShellModuleHelper -PackageResult $PackageResult -Operation Install
    $helperResult = $result.HelperResult

    return [pscustomobject]@{
        Status           = 'Applied'
        InstallKind      = 'powershellModuleInstaller'
        TargetKind       = 'powershellModule'
        InstallDirectory = $null
        ReusedExisting   = $false
        ModuleName       = [string]$install.moduleName
        RequiredVersion  = [string]$install.requiredVersion
        InstalledVersion = if ($helperResult.PSObject.Properties['installedVersion']) { [string]$helperResult.installedVersion } else { $null }
        ModuleBase       = if ($helperResult.PSObject.Properties['moduleBase']) { [string]$helperResult.moduleBase } else { $null }
        Scope            = if ($helperResult.PSObject.Properties['scope']) { [string]$helperResult.scope } else { $null }
        PackageFilePath  = $PackageResult.PackageFilePath
        NugetDirectory   = $result.NugetDirectory
        ProviderDirectory = $result.ProviderDirectory
        RequestPath      = $result.RequestPath
        ResultPath       = $result.ResultPath
        Installer        = $result.Installer
    }
}
