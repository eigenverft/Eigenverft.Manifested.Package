<#
    Eigenverft.Manifested.Sandbox.ExecutionEngine.Npm
#>

function Get-NpmRegistryUri {
<#
.SYNOPSIS
Resolves the active npm registry URI for an npm command.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NpmCommandPath,

        [AllowNull()]
        [string]$GlobalConfigPath
    )

    $defaultRegistryUri = [uri]'https://registry.npmjs.org/'
    $arguments = @('config', 'get', 'registry')
    if (-not [string]::IsNullOrWhiteSpace($GlobalConfigPath)) {
        $arguments += @('--globalconfig', $GlobalConfigPath)
    }

    $registryValue = $null
    try {
        $registryOutput = & $NpmCommandPath @arguments 2>$null
        if ($LASTEXITCODE -eq 0 -and $null -ne $registryOutput) {
            $registryValue = ($registryOutput | Select-Object -First 1).ToString().Trim()
        }
    }
    catch {
        $registryValue = $null
    }

    if ([string]::IsNullOrWhiteSpace($registryValue) -or $registryValue -in @('undefined', 'null')) {
        return $defaultRegistryUri
    }

    try {
        return [uri]$registryValue
    }
    catch {
        return $defaultRegistryUri
    }
}

function Resolve-NpmProxyRoute {
<#
.SYNOPSIS
Detects whether npm registry access is direct or proxied.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [uri]$RegistryUri
    )

    $proxyUri = $null
    try {
        $systemProxy = [System.Net.WebRequest]::GetSystemWebProxy()
        if ($null -ne $systemProxy) {
            $systemProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
            if (-not $systemProxy.IsBypassed($RegistryUri)) {
                $candidateProxyUri = $systemProxy.GetProxy($RegistryUri)
                if ($null -ne $candidateProxyUri -and $candidateProxyUri.AbsoluteUri -ne $RegistryUri.AbsoluteUri) {
                    $proxyUri = $candidateProxyUri
                }
            }
        }
    }
    catch {
        $proxyUri = $null
    }

    return [pscustomobject]@{
        RegistryUri   = $RegistryUri.AbsoluteUri
        RegistryHost  = $RegistryUri.Host
        ProxyUri      = if ($proxyUri) { $proxyUri.AbsoluteUri } else { $null }
        ProxyRequired = ($null -ne $proxyUri)
        Route         = if ($proxyUri) { 'Proxy' } else { 'Direct' }
    }
}

function Get-NpmConfigValue {
<#
.SYNOPSIS
Reads one npm config value.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NpmCommandPath,

        [Parameter(Mandatory = $true)]
        [string]$Key,

        [AllowNull()]
        [string]$GlobalConfigPath
    )

    $arguments = @('config', 'get', $Key)
    if (-not [string]::IsNullOrWhiteSpace($GlobalConfigPath)) {
        $arguments += @('--location=global', '--globalconfig', $GlobalConfigPath)
    }

    try {
        $output = & $NpmCommandPath @arguments 2>$null
        if ($LASTEXITCODE -ne 0 -or $null -eq $output) {
            return $null
        }

        $value = ($output | Select-Object -First 1).ToString().Trim()
        if ([string]::IsNullOrWhiteSpace($value) -or $value -in @('undefined', 'null')) {
            return $null
        }

        return $value
    }
    catch {
        return $null
    }
}

function Get-NpmGlobalConfigArguments {
<#
.SYNOPSIS
Builds npm command-line arguments for an explicit npm global config file.
#>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$GlobalConfigPath
    )

    if ([string]::IsNullOrWhiteSpace($GlobalConfigPath)) {
        return @()
    }

    return @('--globalconfig', [System.IO.Path]::GetFullPath($GlobalConfigPath))
}

