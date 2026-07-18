function Open-UrlInBrowser {
    <#
    .SYNOPSIS
        Opens local files or web URLs in the default or a selected browser.

    .DESCRIPTION
        Resolves each input as an existing local file or an absolute HTTP, HTTPS, or file URI.
        Supports Windows, macOS, and Linux in Windows PowerShell 5.1 and PowerShell 7+.

    .PARAMETER Browser
        Uses the operating-system default browser unless Edge, Chrome, Firefox, or Safari is selected.

    .PARAMETER BrowserPath
        Uses an explicit browser executable, command, or macOS application name/path.

    .EXAMPLE
        Open-UrlInBrowser -Path 'https://example.org'

    .EXAMPLE
        Open-UrlInBrowser -Path '.\report.html'

    .EXAMPLE
        Open-UrlInBrowser -Path 'https://example.org' -Browser Edge -Wait
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('FullName', 'LiteralPath')]
        [ValidateNotNullOrEmpty()]
        [string[]]$Path,

        [switch]$Wait,

        [ValidateSet('Default', 'Edge', 'Chrome', 'Firefox', 'Safari')]
        [string]$Browser = 'Default',

        [AllowNull()]
        [string]$BrowserPath = $null
    )

    function local:Get-BrowserPlatform {
        [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseApprovedVerbs', '')]
        param()

        $runtimeInformationType = [type]::GetType('System.Runtime.InteropServices.RuntimeInformation')
        if ($runtimeInformationType) {
            return [pscustomobject]@{
                Windows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
                MacOS   = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)
                Linux   = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)
            }
        }

        $windows = [string]::Equals([string]$env:OS, 'Windows_NT', [System.StringComparison]::OrdinalIgnoreCase)
        return [pscustomobject]@{ Windows = $windows; MacOS = $false; Linux = -not $windows }
    }

    function local:Resolve-BrowserTarget {
        [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseApprovedVerbs', '')]
        param(
            [Parameter(Mandatory = $true)]
            [string]$InputPath
        )

        $uri = $null
        if ([System.Uri]::TryCreate($InputPath, [System.UriKind]::Absolute, [ref]$uri)) {
            if ([string]::Equals($uri.Scheme, 'file', [System.StringComparison]::OrdinalIgnoreCase)) {
                $InputPath = $uri.LocalPath
            }
            elseif ($uri.Scheme -in @('http', 'https')) {
                return [pscustomobject]@{ Kind = 'Web'; Value = $InputPath }
            }
        }

        try {
            $resolvedPath = Resolve-Path -LiteralPath $InputPath -ErrorAction Stop
            $item = Get-Item -LiteralPath $resolvedPath.ProviderPath -ErrorAction Stop
        }
        catch {
            throw "File not found or invalid URL: $InputPath"
        }
        if ($item.PSIsContainer) {
            throw "Expected a file but got a directory: $InputPath"
        }
        return [pscustomobject]@{ Kind = 'File'; Value = $item.FullName }
    }

    function local:Resolve-BrowserCommand {
        [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseApprovedVerbs', '')]
        param(
            [Parameter(Mandatory = $true)]
            [string]$RequestedBrowser,

            [Parameter(Mandatory = $true)]
            [psobject]$Platform,

            [AllowNull()]
            [string]$RequestedBrowserPath
        )

        if (-not [string]::IsNullOrWhiteSpace($RequestedBrowserPath)) {
            if ($Platform.MacOS -and
                ($RequestedBrowserPath -like '*.app' -or $RequestedBrowserPath -in @('Safari', 'Firefox', 'Google Chrome'))) {
                return [pscustomobject]@{ Mode = 'MacApp'; App = $RequestedBrowserPath }
            }

            $requestedCommand = Get-Command -Name $RequestedBrowserPath -ErrorAction SilentlyContinue
            if ($requestedCommand) {
                $commandPath = if ($requestedCommand.PSObject.Properties['Path']) { [string]$requestedCommand.Path } else { [string]$requestedCommand.Source }
                return [pscustomobject]@{ Mode = 'Executable'; Path = $commandPath }
            }
            if (Test-Path -LiteralPath $RequestedBrowserPath -PathType Leaf) {
                return [pscustomobject]@{ Mode = 'Executable'; Path = (Resolve-Path -LiteralPath $RequestedBrowserPath).Path }
            }
            throw "BrowserPath '$RequestedBrowserPath' was not found."
        }

        if ([string]::Equals($RequestedBrowser, 'Default', [System.StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{ Mode = 'Default' }
        }

        if ($Platform.Windows) {
            $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
            if ([string]::IsNullOrWhiteSpace($programFilesX86)) { $programFilesX86 = $env:ProgramFiles }
            $candidates = switch -Exact ($RequestedBrowser) {
                'Edge' { @('msedge.exe', (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'), (Join-Path $programFilesX86 'Microsoft\Edge\Application\msedge.exe')) }
                'Chrome' { @('chrome.exe', (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'), (Join-Path $programFilesX86 'Google\Chrome\Application\chrome.exe')) }
                'Firefox' { @('firefox.exe', (Join-Path $env:ProgramFiles 'Mozilla Firefox\firefox.exe'), (Join-Path $programFilesX86 'Mozilla Firefox\firefox.exe')) }
                default { @() }
            }
            foreach ($candidate in @($candidates | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })) {
                $candidateCommand = Get-Command -Name $candidate -ErrorAction SilentlyContinue
                if ($candidateCommand) {
                    $commandPath = if ($candidateCommand.PSObject.Properties['Path']) { [string]$candidateCommand.Path } else { [string]$candidateCommand.Source }
                    return [pscustomobject]@{ Mode = 'Executable'; Path = $commandPath }
                }
                if ([System.IO.Path]::IsPathRooted($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                    return [pscustomobject]@{ Mode = 'Executable'; Path = $candidate }
                }
            }
            throw "Requested browser '$RequestedBrowser' was not found on Windows. Install it or use -BrowserPath."
        }

        if ($Platform.MacOS) {
            $application = switch -Exact ($RequestedBrowser) {
                'Safari' { 'Safari' }
                'Chrome' { 'Google Chrome' }
                'Firefox' { 'Firefox' }
                default { $null }
            }
            if (-not $application) {
                throw "Requested browser '$RequestedBrowser' is not available on macOS."
            }
            return [pscustomobject]@{ Mode = 'MacApp'; App = $application }
        }

        $linuxCandidates = switch -Exact ($RequestedBrowser) {
            'Chrome' { @('google-chrome', 'google-chrome-stable', 'chromium-browser', 'chromium') }
            'Firefox' { @('firefox') }
            'Edge' { @('microsoft-edge', 'microsoft-edge-stable') }
            default { @() }
        }
        foreach ($candidate in $linuxCandidates) {
            $candidateCommand = Get-Command -Name $candidate -ErrorAction SilentlyContinue
            if ($candidateCommand) {
                $commandPath = if ($candidateCommand.PSObject.Properties['Path']) { [string]$candidateCommand.Path } else { [string]$candidateCommand.Source }
                return [pscustomobject]@{ Mode = 'Executable'; Path = $commandPath }
            }
        }
        throw "Requested browser '$RequestedBrowser' was not found on Linux. Install it or use -BrowserPath."
    }

    $platform = Get-BrowserPlatform
    $browserCommand = Resolve-BrowserCommand -RequestedBrowser $Browser -Platform $platform -RequestedBrowserPath $BrowserPath
    foreach ($inputPath in $Path) {
        $target = Resolve-BrowserTarget -InputPath $inputPath
        if ([string]::Equals([string]$browserCommand.Mode, 'Default', [System.StringComparison]::OrdinalIgnoreCase)) {
            if ($platform.MacOS) {
                if (-not (Get-Command -Name 'open' -ErrorAction SilentlyContinue)) {
                    throw "Missing required tool 'open'."
                }
                $argumentList = @($target.Value)
                if ($Wait.IsPresent) { $argumentList = @('-W') + $argumentList }
                Start-Process -FilePath 'open' -ArgumentList $argumentList | Out-Null
            }
            elseif ($platform.Linux) {
                if (-not (Get-Command -Name 'xdg-open' -ErrorAction SilentlyContinue)) {
                    throw "Missing required tool 'xdg-open'. Install package 'xdg-utils'."
                }
                Start-Process -FilePath 'xdg-open' -ArgumentList @($target.Value) -Wait:$Wait | Out-Null
            }
            else {
                Start-Process -FilePath $target.Value -Wait:$Wait | Out-Null
            }
            Write-Host ("Opening {0} with the default browser: {1}" -f $target.Kind, $target.Value)
            continue
        }

        if ($platform.MacOS -and [string]::Equals([string]$browserCommand.Mode, 'MacApp', [System.StringComparison]::OrdinalIgnoreCase)) {
            if (-not (Get-Command -Name 'open' -ErrorAction SilentlyContinue)) {
                throw "Missing required tool 'open'."
            }
            $argumentList = @('-a', [string]$browserCommand.App, $target.Value)
            if ($Wait.IsPresent) { $argumentList = @('-W') + $argumentList }
            Start-Process -FilePath 'open' -ArgumentList $argumentList | Out-Null
            Write-Host ("Opening {0} with {1}: {2}" -f $target.Kind, $browserCommand.App, $target.Value)
            continue
        }

        Start-Process -FilePath ([string]$browserCommand.Path) -ArgumentList @($target.Value) -Wait:$Wait | Out-Null
        Write-Host ("Opening {0} with {1}: {2}" -f $target.Kind, $browserCommand.Path, $target.Value)
    }
}
