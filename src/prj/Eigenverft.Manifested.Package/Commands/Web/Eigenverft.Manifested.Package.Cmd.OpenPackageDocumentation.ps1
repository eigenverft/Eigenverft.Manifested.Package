function Open-PackageDocumentation {
    <#
    .SYNOPSIS
        Opens the documentation installed with the active module version.

    .DESCRIPTION
        Resolves Documentation\index.html from the exact Eigenverft.Manifested.Package
        module instance that exported this command, then delegates browser selection and
        process launching to Open-UrlInBrowser.

    .PARAMETER Browser
        Uses the operating-system default browser unless Edge, Chrome, Firefox, or Safari is selected.

    .PARAMETER BrowserPath
        Uses an explicit browser executable, command, or macOS application name/path.

    .EXAMPLE
        Open-PackageDocumentation

    .EXAMPLE
        Open-PackageDocumentation -Browser Edge
    #>
    [CmdletBinding()]
    param(
        [switch]$Wait,

        [ValidateSet('Default', 'Edge', 'Chrome', 'Firefox', 'Safari')]
        [string]$Browser = 'Default',

        [AllowNull()]
        [string]$BrowserPath = $null
    )

    $moduleInfo = $MyInvocation.MyCommand.Module
    $moduleBase = if ($moduleInfo) { [string]$moduleInfo.ModuleBase } else { $null }
    if ([string]::IsNullOrWhiteSpace($moduleBase)) {
        throw 'Unable to resolve the active Eigenverft.Manifested.Package module directory.'
    }

    $documentationPath = Join-Path (Join-Path $moduleBase 'Documentation') 'index.html'
    if (-not (Test-Path -LiteralPath $documentationPath -PathType Leaf)) {
        throw "Packaged documentation index was not found for module version '$($moduleInfo.Version)' at '$documentationPath'."
    }

    Open-UrlInBrowser -Path $documentationPath -Wait:$Wait -Browser $Browser -BrowserPath $BrowserPath
}
