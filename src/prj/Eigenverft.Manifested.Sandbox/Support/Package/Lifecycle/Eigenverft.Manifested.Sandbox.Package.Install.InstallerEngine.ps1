<#
    Eigenverft.Manifested.Sandbox.Package.Install - installer process/NSIS helpers (shared execution mechanics).
    Dot-sourced from Eigenverft.Manifested.Sandbox.psm1 (mirrored in TestImports.ps1) before Package.Install.ps1.
#>

function Format-PackageProcessArgument {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    $text = [string]$Value
    if ($text.Length -ge 2 -and $text.StartsWith('"') -and $text.EndsWith('"')) {
        return $text
    }
    if ($text.IndexOfAny([char[]]@(' ', "`t", '"')) -lt 0) {
        return $text
    }

    return '"' + ($text -replace '"', '\"') + '"'
}

function Invoke-PackageInstallerCommand {
<#
.SYNOPSIS
Runs a prepared installer process command.

.DESCRIPTION
Owns the common process-launch, elevation, timeout, and exit-code mechanics for
installer adapters. Adapter-specific command path and arguments are resolved by
the caller.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [string]$CommandPath,

        [AllowEmptyCollection()]
        [object[]]$CommandArguments,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutSec,

        [Parameter(Mandatory = $true)]
        [int[]]$SuccessExitCodes,

        [AllowEmptyCollection()]
        [int[]]$RestartExitCodes,

        [Parameter(Mandatory = $true)]
        [string]$TargetKind,

        [Parameter(Mandatory = $true)]
        [string]$InstallerKind,

        [Parameter(Mandatory = $true)]
        [string]$UiMode,

        [AllowNull()]
        [string]$LogPath,

        [AllowNull()]
        [string]$ElevationMode,

        [ValidateSet('Normal', 'Hidden', 'Minimized', 'Maximized')]
        [string]$WindowStyle = 'Normal'
    )

    if ([string]::IsNullOrWhiteSpace($CommandPath)) {
        throw 'Package installer command path is empty.'
    }
    if (-not (Test-Path -LiteralPath $CommandPath -PathType Leaf)) {
        throw "Package installer command '$CommandPath' does not exist."
    }
    if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        throw 'Package installer working directory is empty.'
    }
    $null = New-Item -ItemType Directory -Path $WorkingDirectory -Force

    $elevationPlan = Get-PackageInstallerElevationPlan -PackageResult $PackageResult -ElevationMode $ElevationMode
    Write-PackageExecutionMessage -Message ("[STATE] Installer execution: targetKind='{0}', installerKind='{1}', uiMode='{2}', elevation='{3}', processIsElevated='{4}', willElevate='{5}'." -f $TargetKind, $InstallerKind, $UiMode, $elevationPlan.Mode, $elevationPlan.ProcessIsElevated, $elevationPlan.ShouldElevate)

    $startProcessParameters = @{
        FilePath         = $CommandPath
        ArgumentList     = @($CommandArguments)
        WorkingDirectory = $WorkingDirectory
        PassThru         = $true
    }
    if ($elevationPlan.ShouldElevate) {
        $startProcessParameters['Verb'] = 'RunAs'
    }
    if (-not [string]::Equals($WindowStyle, 'Normal', [System.StringComparison]::OrdinalIgnoreCase)) {
        $startProcessParameters['WindowStyle'] = $WindowStyle
    }

    $process = Start-Process @startProcessParameters
    if (-not $process.WaitForExit($TimeoutSec * 1000)) {
        try {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
        catch {
        }

        throw "Package installer command exceeded the timeout of $TimeoutSec seconds."
    }

    $process.Refresh()
    $exitCode = [int]$process.ExitCode
    $acceptedExitCodes = @($SuccessExitCodes) + @($RestartExitCodes)
    if ($exitCode -notin $acceptedExitCodes) {
        throw "Package installer command failed with exit code $exitCode."
    }

    return [pscustomobject]@{
        ExitCode         = $exitCode
        RestartRequired  = ($exitCode -in $RestartExitCodes)
        LogPath          = $LogPath
        CommandPath      = $CommandPath
        CommandArguments = @($CommandArguments)
        TargetKind       = $TargetKind
        InstallerKind    = $InstallerKind
        UiMode           = $UiMode
        Elevation        = $elevationPlan
    }
}

function Invoke-PackageInstallerProcess {
<#
.SYNOPSIS
Runs an installer-style package command and waits for completion.

.DESCRIPTION
Starts the configured installer command, applies timeout and exit-code rules,
and returns the install log path and restart flag when configured.

.PARAMETER PackageResult
The Package result object that owns the install.

.EXAMPLE
Invoke-PackageInstallerProcess -PackageResult $result
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $install = Get-PackageAssignedInstallOperation -Release $PackageResult.Package
    if (-not $install) {
        throw "Package installer for '$($PackageResult.PackageId)' requires an assigned block on the selected release."
    }
    $commandPath = if ($install.PSObject.Properties['commandPath'] -and -not [string]::IsNullOrWhiteSpace([string]$install.commandPath)) {
        Resolve-PackageTemplateText -Text ([string]$install.commandPath) -PackageConfig $PackageResult.PackageConfig -Package $PackageResult.Package
    }
    else {
        $PackageResult.PackageFilePath
    }

    $timestamp = (Get-Date -Format 'yyyyMMdd-HHmmss')
    $logPath = $null
    if ($install.PSObject.Properties['logRelativePath'] -and -not [string]::IsNullOrWhiteSpace([string]$install.logRelativePath)) {
        $logRelativePath = Resolve-PackageTemplateText -Text ([string]$install.logRelativePath) -PackageConfig $PackageResult.PackageConfig -Package $PackageResult.Package -ExtraTokens @{ timestamp = $timestamp }
        $packageRoot = Get-PackageRootFromInventoryPath -PackageAssignmentInventoryFilePath ([string]$PackageResult.PackageConfig.PackageAssignmentInventoryFilePath)
        $logRoot = [System.IO.Path]::GetFullPath((Join-Path $packageRoot 'Logs'))
        $logPath = [System.IO.Path]::GetFullPath((Join-Path $logRoot ($logRelativePath -replace '/', '\')))
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $logPath) -Force
    }

    $commandArguments = @()
    foreach ($argument in @($install.commandArguments)) {
        $resolvedArgument = Resolve-PackageTemplateText -Text ([string]$argument) -PackageConfig $PackageResult.PackageConfig -Package $PackageResult.Package -ExtraTokens @{
                packageFilePath   = $PackageResult.PackageFilePath
                installDirectory  = $PackageResult.InstallDirectory
                packageFileStagingDirectory = $PackageResult.PackageFileStagingDirectory
                packageInstallStageDirectory = $PackageResult.PackageInstallStageDirectory
                downloadDirectory = $PackageResult.PackageFileStagingDirectory
                logPath           = $logPath
                timestamp         = $timestamp
            }
        $commandArguments += (Format-PackageProcessArgument -Value $resolvedArgument)
    }

    $timeoutSec = if ($install.PSObject.Properties['timeoutSec']) { [int]$install.timeoutSec } else { 300 }
    $successExitCodes = if ($install.PSObject.Properties['successExitCodes']) { @($install.successExitCodes | ForEach-Object { [int]$_ }) } else { @(0) }
    $restartExitCodes = if ($install.PSObject.Properties['restartExitCodes']) { @($install.restartExitCodes | ForEach-Object { [int]$_ }) } else { @() }
    $targetKind = Get-PackageInstallTargetKind -Package $PackageResult.Package
    $workingDirectory = if (-not [string]::IsNullOrWhiteSpace([string]$PackageResult.InstallDirectory)) {
        $null = New-Item -ItemType Directory -Path $PackageResult.InstallDirectory -Force
        $PackageResult.InstallDirectory
    }
    else {
        $PackageResult.PackageInstallStageDirectory
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$workingDirectory)) {
        $null = New-Item -ItemType Directory -Path $workingDirectory -Force
    }

    $installerKind = if ($install.PSObject.Properties['installerKind'] -and -not [string]::IsNullOrWhiteSpace([string]$install.installerKind)) { [string]$install.installerKind } else { '<unspecified>' }
    $uiMode = if ($install.PSObject.Properties['uiMode'] -and -not [string]::IsNullOrWhiteSpace([string]$install.uiMode)) { [string]$install.uiMode } else { '<unspecified>' }

    return (Invoke-PackageInstallerCommand -PackageResult $PackageResult -CommandPath $commandPath -CommandArguments @($commandArguments) -WorkingDirectory $workingDirectory -TimeoutSec $timeoutSec -SuccessExitCodes @($successExitCodes) -RestartExitCodes @($restartExitCodes) -TargetKind $targetKind -InstallerKind $installerKind -UiMode $uiMode -LogPath $logPath)
}

function Copy-PackageInstallerToInstallStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if ([string]::IsNullOrWhiteSpace($PackageResult.PackageFilePath) -or -not (Test-Path -LiteralPath $PackageResult.PackageFilePath -PathType Leaf)) {
        throw "Package installer for '$($PackageResult.PackageId)' requires a saved package file."
    }
    if ([string]::IsNullOrWhiteSpace($PackageResult.PackageInstallStageDirectory)) {
        throw "Package installer for '$($PackageResult.PackageId)' requires a package install stage directory."
    }

    $stageDirectory = [System.IO.Path]::GetFullPath([string]$PackageResult.PackageInstallStageDirectory)
    $null = New-Item -ItemType Directory -Path $stageDirectory -Force
    $installerFileName = Split-Path -Leaf $PackageResult.PackageFilePath
    $stagedInstallerPath = Join-Path $stageDirectory $installerFileName
    return (Copy-FileToPath -SourcePath $PackageResult.PackageFilePath -TargetPath $stagedInstallerPath -Overwrite)
}

function Get-PackageWindowsInstallerExecutablePath {
    [CmdletBinding()]
    param()

    $systemRoot = if ([string]::IsNullOrWhiteSpace($env:SystemRoot)) {
        [Environment]::GetEnvironmentVariable('windir')
    }
    else {
        [string]$env:SystemRoot
    }
    if ([string]::IsNullOrWhiteSpace($systemRoot)) {
        throw 'Cannot resolve SystemRoot for Windows Installer.'
    }

    $msiexecPath = [System.IO.Path]::GetFullPath((Join-Path $systemRoot 'System32\msiexec.exe'))
    if (-not (Test-Path -LiteralPath $msiexecPath -PathType Leaf)) {
        throw "Windows Installer executable '$msiexecPath' was not found."
    }

    return $msiexecPath
}

function Assert-PackageMsiPropertyName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not [regex]::IsMatch($Name, '^[A-Z][A-Z0-9_]*$')) {
        throw "MSI public property name '$Name' is invalid. Use uppercase letters, digits, and underscores, starting with a letter."
    }
}

function Invoke-PackageMsiInstallerProcess {
<#
.SYNOPSIS
Runs an MSI package through msiexec from the isolated package install stage.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $install = Get-PackageAssignedInstallOperation -Release $PackageResult.Package
    if (-not $install) {
        throw "Package msiInstaller for '$($PackageResult.PackageId)' requires an assigned block on the selected release."
    }
    if ([string]::IsNullOrWhiteSpace([string]$PackageResult.InstallDirectory)) {
        throw "Package msiInstaller for '$($PackageResult.PackageId)' requires an install directory."
    }

    $stagedInstallerPath = Copy-PackageInstallerToInstallStage -PackageResult $PackageResult
    $commandPath = Get-PackageWindowsInstallerExecutablePath
    $commandArguments = @('/i', (Format-PackageProcessArgument -Value $stagedInstallerPath))
    foreach ($argument in @($install.commandArguments)) {
        $resolvedArgument = Resolve-PackageTemplateText -Text ([string]$argument) -PackageConfig $PackageResult.PackageConfig -Package $PackageResult.Package -ExtraTokens @{
                packageFilePath = $PackageResult.PackageFilePath
                installDirectory = $PackageResult.InstallDirectory
                packageFileStagingDirectory = $PackageResult.PackageFileStagingDirectory
                packageInstallStageDirectory = $PackageResult.PackageInstallStageDirectory
                downloadDirectory = $PackageResult.PackageFileStagingDirectory
            }
        $commandArguments += (Format-PackageProcessArgument -Value $resolvedArgument)
    }

    if ($install.PSObject.Properties['targetDirectoryProperty'] -and $null -ne $install.targetDirectoryProperty) {
        $targetDirectoryProperty = $install.targetDirectoryProperty
        $enabled = (-not $targetDirectoryProperty.PSObject.Properties['enabled']) -or [bool]$targetDirectoryProperty.enabled
        if ($enabled) {
            $propertyName = if ($targetDirectoryProperty.PSObject.Properties['name'] -and -not [string]::IsNullOrWhiteSpace([string]$targetDirectoryProperty.name)) {
                [string]$targetDirectoryProperty.name
            }
            else {
                'INSTALLDIR'
            }
            Assert-PackageMsiPropertyName -Name $propertyName
            $commandArguments += (Format-PackageProcessArgument -Value ('{0}={1}' -f $propertyName, [string]$PackageResult.InstallDirectory))
        }
    }

    $timeoutSec = if ($install.PSObject.Properties['timeoutSec']) { [int]$install.timeoutSec } else { 300 }
    $successExitCodes = if ($install.PSObject.Properties['successExitCodes']) { @($install.successExitCodes | ForEach-Object { [int]$_ }) } else { @(0) }
    $restartExitCodes = if ($install.PSObject.Properties['restartExitCodes']) { @($install.restartExitCodes | ForEach-Object { [int]$_ }) } else { @() }
    $targetKind = Get-PackageInstallTargetKind -Package $PackageResult.Package
    $uiMode = if ($install.PSObject.Properties['uiMode'] -and -not [string]::IsNullOrWhiteSpace([string]$install.uiMode)) { [string]$install.uiMode } else { 'silent' }
    $elevationMode = if ($install.PSObject.Properties['elevation'] -and -not [string]::IsNullOrWhiteSpace([string]$install.elevation)) { [string]$install.elevation } else { $null }

    return (Invoke-PackageInstallerCommand -PackageResult $PackageResult -CommandPath $commandPath -CommandArguments @($commandArguments) -WorkingDirectory $PackageResult.PackageInstallStageDirectory -TimeoutSec $timeoutSec -SuccessExitCodes @($successExitCodes) -RestartExitCodes @($restartExitCodes) -TargetKind $targetKind -InstallerKind 'msi' -UiMode $uiMode -LogPath $null -ElevationMode $elevationMode)
}

function Invoke-PackageNsisInstallerProcess {
<#
.SYNOPSIS
Runs an NSIS installer package through the isolated package install stage.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $install = Get-PackageAssignedInstallOperation -Release $PackageResult.Package
    if (-not $install) {
        throw "Package nsisInstaller for '$($PackageResult.PackageId)' requires an assigned block on the selected release."
    }
    if ([string]::IsNullOrWhiteSpace([string]$PackageResult.InstallDirectory)) {
        throw "Package nsisInstaller for '$($PackageResult.PackageId)' requires an install directory."
    }
    if ($install.PSObject.Properties['installerKind'] -and
        -not [string]::IsNullOrWhiteSpace([string]$install.installerKind) -and
        -not [string]::Equals([string]$install.installerKind, 'nsis', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Package nsisInstaller for '$($PackageResult.PackageId)' cannot use installerKind '$($install.installerKind)'. Use innoSetupInstaller for Inno Setup packages."
    }

    $commandPath = Copy-PackageInstallerToInstallStage -PackageResult $PackageResult
    $commandArguments = @()
    foreach ($argument in @($install.commandArguments)) {
        $resolvedArgument = Resolve-PackageTemplateText -Text ([string]$argument) -PackageConfig $PackageResult.PackageConfig -Package $PackageResult.Package -ExtraTokens @{
                packageFilePath = $PackageResult.PackageFilePath
                installDirectory = $PackageResult.InstallDirectory
                packageFileStagingDirectory = $PackageResult.PackageFileStagingDirectory
                packageInstallStageDirectory = $PackageResult.PackageInstallStageDirectory
                downloadDirectory = $PackageResult.PackageFileStagingDirectory
            }
        $commandArguments += (Format-PackageProcessArgument -Value $resolvedArgument)
    }

    if ($install.PSObject.Properties['targetDirectoryArgument'] -and $null -ne $install.targetDirectoryArgument) {
        $targetDirectoryArgument = $install.targetDirectoryArgument
        $targetDirectoryArgumentEnabled = (-not $targetDirectoryArgument.PSObject.Properties['enabled']) -or [bool]$targetDirectoryArgument.enabled
        if ($targetDirectoryArgumentEnabled) {
            $prefix = if ($targetDirectoryArgument.PSObject.Properties['prefix'] -and -not [string]::IsNullOrWhiteSpace([string]$targetDirectoryArgument.prefix)) {
                [string]$targetDirectoryArgument.prefix
            }
            else {
                '/D='
            }
            $commandArguments += ($prefix + [string]$PackageResult.InstallDirectory)
        }
    }

    $timeoutSec = if ($install.PSObject.Properties['timeoutSec']) { [int]$install.timeoutSec } else { 300 }
    $successExitCodes = if ($install.PSObject.Properties['successExitCodes']) { @($install.successExitCodes | ForEach-Object { [int]$_ }) } else { @(0) }
    $restartExitCodes = if ($install.PSObject.Properties['restartExitCodes']) { @($install.restartExitCodes | ForEach-Object { [int]$_ }) } else { @() }
    $targetKind = Get-PackageInstallTargetKind -Package $PackageResult.Package
    $installerKind = if ($install.PSObject.Properties['installerKind'] -and -not [string]::IsNullOrWhiteSpace([string]$install.installerKind)) { [string]$install.installerKind } else { 'nsis' }
    $uiMode = if ($install.PSObject.Properties['uiMode'] -and -not [string]::IsNullOrWhiteSpace([string]$install.uiMode)) { [string]$install.uiMode } else { 'silent' }

    return (Invoke-PackageInstallerCommand -PackageResult $PackageResult -CommandPath $commandPath -CommandArguments @($commandArguments) -WorkingDirectory $PackageResult.PackageInstallStageDirectory -TimeoutSec $timeoutSec -SuccessExitCodes @($successExitCodes) -RestartExitCodes @($restartExitCodes) -TargetKind $targetKind -InstallerKind $installerKind -UiMode $uiMode -LogPath $null)
}

function Invoke-PackageInnoSetupInstallerProcess {
<#
.SYNOPSIS
Runs an Inno Setup installer package through the isolated package install stage.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $install = Get-PackageAssignedInstallOperation -Release $PackageResult.Package
    if (-not $install) {
        throw "Package innoSetupInstaller for '$($PackageResult.PackageId)' requires an assigned block on the selected release."
    }
    if ([string]::IsNullOrWhiteSpace([string]$PackageResult.InstallDirectory)) {
        throw "Package innoSetupInstaller for '$($PackageResult.PackageId)' requires an install directory."
    }

    $commandPath = Copy-PackageInstallerToInstallStage -PackageResult $PackageResult
    $commandArguments = @()
    foreach ($argument in @($install.commandArguments)) {
        $resolvedArgument = Resolve-PackageTemplateText -Text ([string]$argument) -PackageConfig $PackageResult.PackageConfig -Package $PackageResult.Package -ExtraTokens @{
                packageFilePath = $PackageResult.PackageFilePath
                installDirectory = $PackageResult.InstallDirectory
                packageFileStagingDirectory = $PackageResult.PackageFileStagingDirectory
                packageInstallStageDirectory = $PackageResult.PackageInstallStageDirectory
                downloadDirectory = $PackageResult.PackageFileStagingDirectory
            }
        $commandArguments += (Format-PackageProcessArgument -Value $resolvedArgument)
    }

    if ($install.PSObject.Properties['targetDirectoryArgument'] -and $null -ne $install.targetDirectoryArgument) {
        $targetDirectoryArgument = $install.targetDirectoryArgument
        $targetDirectoryArgumentEnabled = $targetDirectoryArgument.PSObject.Properties['enabled'] -and [bool]$targetDirectoryArgument.enabled
        if ($targetDirectoryArgumentEnabled) {
            $prefix = if ($targetDirectoryArgument.PSObject.Properties['prefix'] -and -not [string]::IsNullOrWhiteSpace([string]$targetDirectoryArgument.prefix)) {
                [string]$targetDirectoryArgument.prefix
            }
            else {
                '/DIR='
            }
            $quoteValue = (-not $targetDirectoryArgument.PSObject.Properties['quoteValue']) -or [bool]$targetDirectoryArgument.quoteValue
            $targetValue = [string]$PackageResult.InstallDirectory
            $commandArguments += if ($quoteValue) {
                '{0}"{1}"' -f $prefix, ($targetValue -replace '"', '\"')
            }
            else {
                $prefix + $targetValue
            }
        }
    }

    $timeoutSec = if ($install.PSObject.Properties['timeoutSec']) { [int]$install.timeoutSec } else { 300 }
    $successExitCodes = if ($install.PSObject.Properties['successExitCodes']) { @($install.successExitCodes | ForEach-Object { [int]$_ }) } else { @(0) }
    $restartExitCodes = if ($install.PSObject.Properties['restartExitCodes']) { @($install.restartExitCodes | ForEach-Object { [int]$_ }) } else { @() }
    $targetKind = Get-PackageInstallTargetKind -Package $PackageResult.Package
    $uiMode = if ($install.PSObject.Properties['uiMode'] -and -not [string]::IsNullOrWhiteSpace([string]$install.uiMode)) { [string]$install.uiMode } else { 'silent' }

    return (Invoke-PackageInstallerCommand -PackageResult $PackageResult -CommandPath $commandPath -CommandArguments @($commandArguments) -WorkingDirectory $PackageResult.PackageInstallStageDirectory -TimeoutSec $timeoutSec -SuccessExitCodes @($successExitCodes) -RestartExitCodes @($restartExitCodes) -TargetKind $targetKind -InstallerKind 'innoSetup' -UiMode $uiMode -LogPath $null)
}
