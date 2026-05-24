function Initialize-ProxyAccessProfile {
<#
.SYNOPSIS
Resolves a usable outbound proxy access profile on Windows, persists the
result to a CliXml profile file, and stores ready-to-use values in global
variables.
Includes transient proxy-host DNS readiness retries for startup resilience
in Windows corporate and sandboxed environments.

.DESCRIPTION
Resolution order:
1. Direct access
2. Environment proxy from process environment variables
3. Local relay proxy on loopback
4. System proxy with default credentials
5. Manual proxy

Behavior:
- A second call exits early unless -ForceRefresh is used.
- If no in-session globals exist yet, the function first tries to load the stored
  profile file, validates that persisted profile with a live probe, and only then
  rebuilds the global variables from it.
- Global variables are still populated for easy re-use inside the current shell.
- If manual proxy entry would be required in a non-interactive session, the function throws.
- TLS 1.2 is ensured for proxy validation and discovery probes.
- Proxy validation and discovery probes start with normal TLS server certificate
  validation. If neither certificate switch is supplied and a probe fails because
  of certificate validation, that probe is retried once with certificate validation bypass.

This helper is primarily intended for Windows PowerShell 5.1 and PowerShell
7+ on Windows in corporate environments where direct access is not guaranteed.
#>
    [CmdletBinding()]
    param(
        [uri]$TestUri = 'https://www.powershellgallery.com/api/v2/',

        [ValidateRange(1,300)]
        [int]$TimeoutSec = 8,

        [string]$DefaultManualProxy = 'http://test.corp.com:8080',

        [string]$GlobalPrefix = 'ProxyParams',

        [string]$ProxyProfilePath = (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Programs\ProxyAccessProfile\ProxyAccessProfile.clixml'),

        [switch]$SkipManualProxyPrompt,

        [switch]$SkipSessionPreparation,

        [switch]$SkipCertificateCheck,

        [switch]$EnforceCertificateCheck,

        [switch]$ForceRefresh
    )

    function local:_Write-StandardMessage {
        [Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs","")]
        param(
            [Parameter(Mandatory=$true)][AllowEmptyString()][string]$Message,
            [Parameter()][ValidateSet('TRC','DBG','INF','WRN','ERR','FTL')][string]$Level='INF',
            [Parameter()][ValidateSet('TRC','DBG','INF','WRN','ERR','FTL')][string]$MinLevel
        )
        if ($null -eq $Message) { $Message = [string]::Empty }
        $sevMap=@{TRC=0;DBG=1;INF=2;WRN=3;ERR=4;FTL=5}
        if(-not $PSBoundParameters.ContainsKey('MinLevel')){
            $gv=Get-Variable ConsoleLogMinLevel -Scope Global -ErrorAction SilentlyContinue
            $MinLevel=if($gv -and $gv.Value -and -not [string]::IsNullOrEmpty([string]$gv.Value)){[string]$gv.Value}else{'INF'}
        }
        $lvl=$Level.ToUpperInvariant()
        $min=$MinLevel.ToUpperInvariant()
        $sev=$sevMap[$lvl];if($null -eq $sev){$lvl='INF';$sev=$sevMap['INF']}
        $gate=$sevMap[$min];if($null -eq $gate){$min='INF';$gate=$sevMap['INF']}
        if($sev -ge 4 -and $sev -lt $gate -and $gate -ge 4){$lvl=$min;$sev=$gate}
        if($sev -lt $gate){return}
        $ts=[DateTime]::UtcNow.ToString('yy-MM-dd HH:mm:ss')
        $stack=Get-PSCallStack ; $helperName=$MyInvocation.MyCommand.Name ; $helperScript=$MyInvocation.MyCommand.ScriptBlock.File ; $caller=$null
        if($stack){
            # 1: prefer first non-underscore function not defined in the helper's own file
            for($i=0;$i -lt $stack.Count;$i++){
                $f=$stack[$i];$fn=$f.FunctionName;$sn=$f.ScriptName
                if($fn -and $fn -ne $helperName -and -not $fn.StartsWith('_') -and (-not $helperScript -or -not $sn -or $sn -ne $helperScript)){$caller=$f;break}
            }
            # 2: fallback to first non-underscore function (any file)
            if(-not $caller){
                for($i=0;$i -lt $stack.Count;$i++){
                    $f=$stack[$i];$fn=$f.FunctionName
                    if($fn -and $fn -ne $helperName -and -not $fn.StartsWith('_')){$caller=$f;break}
                }
            }
            # 3: fallback to first non-helper frame not from helper's own file
            if(-not $caller){
                for($i=0;$i -lt $stack.Count;$i++){
                    $f=$stack[$i];$fn=$f.FunctionName;$sn=$f.ScriptName
                    if($fn -and $fn -ne $helperName -and (-not $helperScript -or -not $sn -or $sn -ne $helperScript)){$caller=$f;break}
                }
            }
            # 4: final fallback to first non-helper frame
            if(-not $caller){
                for($i=0;$i -lt $stack.Count;$i++){
                    $f=$stack[$i];$fn=$f.FunctionName
                    if($fn -and $fn -ne $helperName){$caller=$f;break}
                }
            }
        }
        if(-not $caller){$caller=[pscustomobject]@{ScriptName=$PSCommandPath;FunctionName=$null}}
        $lineNumber=$null ; 
        $p=$caller.PSObject.Properties['ScriptLineNumber'];if($p -and $p.Value){$lineNumber=[string]$p.Value}
        if(-not $lineNumber){
            $p=$caller.PSObject.Properties['Position']
            if($p -and $p.Value){
                $sp=$p.Value.PSObject.Properties['StartLineNumber'];if($sp -and $sp.Value){$lineNumber=[string]$sp.Value}
            }
        }
        if(-not $lineNumber){
            $p=$caller.PSObject.Properties['Location']
            if($p -and $p.Value){
                $m=[regex]::Match([string]$p.Value,':(\d+)\s+char:','IgnoreCase');if($m.Success -and $m.Groups.Count -gt 1){$lineNumber=$m.Groups[1].Value}
            }
        }
        $file=if($caller.ScriptName){Split-Path -Leaf $caller.ScriptName}else{'cmd'}
        if($file -ne 'console' -and $lineNumber){$file="{0}:{1}" -f $file,$lineNumber}
        $prefix="[$ts "
        #$suffix="] [$file] $Message"
        $suffix="] $Message"
        $cfg=@{TRC=@{Fore='DarkGray';Back=$null};DBG=@{Fore='Cyan';Back=$null};INF=@{Fore='Green';Back=$null};WRN=@{Fore='Yellow';Back=$null};ERR=@{Fore='Red';Back=$null};FTL=@{Fore='Red';Back='DarkRed'}}[$lvl]
        $fore=$cfg.Fore
        $back=$cfg.Back
        $isInteractive = [System.Environment]::UserInteractive
        if($isInteractive -and ($fore -or $back)){
            Write-Host -NoNewline $prefix
            if($fore -and $back){Write-Host -NoNewline $lvl -ForegroundColor $fore -BackgroundColor $back}
            elseif($fore){Write-Host -NoNewline $lvl -ForegroundColor $fore}
            elseif($back){Write-Host -NoNewline $lvl -BackgroundColor $back}
            Write-Host $suffix
        } else {
            Write-Host "$prefix$lvl$suffix"
        }

        if($sev -ge 4 -and $ErrorActionPreference -eq 'Stop'){throw ("ConsoleLog.{0}: {1}" -f $lvl,$Message)}
    }

    $isWindowsEnv = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
    if (-not $isWindowsEnv) {
        throw "Initialize-ProxyAccessProfile is intended for Windows PowerShell 5.1 and PowerShell 7+ on Windows. Current version: $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)."
    }

    $nativeInvokeWebRequestCommand = Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue
    $nativeSupportsNoProxy =
        ($null -ne $nativeInvokeWebRequestCommand) -and
        $nativeInvokeWebRequestCommand.Parameters.ContainsKey('NoProxy')

    $initialized = Get-Variable -Scope Global -Name ($GlobalPrefix + 'Initialized') -ErrorAction SilentlyContinue
    if (-not $ForceRefresh -and $initialized -and $initialized.Value) {
        _Write-StandardMessage -Message (
            "[STATUS] Proxy globals already initialized for prefix '{0}'. Skipping refresh." -f
            $GlobalPrefix
        ) -Level DBG
        return
    }

    $explicitSkipCertificateCheckSupplied = $PSBoundParameters.ContainsKey('SkipCertificateCheck')
    $explicitEnforceCertificateCheckSupplied = $PSBoundParameters.ContainsKey('EnforceCertificateCheck')

    $effectiveSkipCertificateCheck = if ($explicitSkipCertificateCheckSupplied) {
        [bool]$SkipCertificateCheck
    }
    elseif ($explicitEnforceCertificateCheckSupplied) {
        -not [bool]$EnforceCertificateCheck
    }
    else {
        $false
    }

    $automaticCertificateFallbackAllowed =
        (-not $explicitSkipCertificateCheckSupplied) -and
        (-not $explicitEnforceCertificateCheckSupplied)

    function Set-ProxyGlobals {
        param(
            [ValidateSet('Direct','EnvironmentProxy','LocalRelayProxy','SystemProxyDefaultCredentials','ManualProxy','NoResolvedProxyProfile')]
            [string]$Mode,

            [hashtable]$InstallPackageProvider = @{},

            [hashtable]$InstallModule = @{},

            [hashtable]$InvokeWebRequest = @{},

            [scriptblock]$PrepareSession = $null,

            [uri]$Proxy = $null,

            [pscredential]$ProxyCredential = $null,

            [bool]$UseDefaultProxyCredentials = $false,

            [bool]$SessionPrepared = $false,

            [string[]]$Diagnostics = @(),

            [string]$ProfileSource = $null,

            [datetime]$LastRefresh = [datetime]::MinValue
        )

        Set-Variable -Scope Global -Name ($GlobalPrefix + 'InstallPackageProvider') -Value $InstallPackageProvider -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'InstallModule') -Value $InstallModule -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'InvokeWebRequest') -Value $InvokeWebRequest -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'PrepareSession') -Value $PrepareSession -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'Mode') -Value $Mode -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'TestUri') -Value $TestUri -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'Proxy') -Value $Proxy -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'ProxyCredential') -Value $ProxyCredential -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'UseDefaultProxyCredentials') -Value $UseDefaultProxyCredentials -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'SessionPrepared') -Value $SessionPrepared -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'Diagnostics') -Value $Diagnostics -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'ProfileSource') -Value $ProfileSource -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'ProfilePath') -Value $ProxyProfilePath -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'Initialized') -Value $true -Force

        if ($LastRefresh -eq [datetime]::MinValue) {
            Set-Variable -Scope Global -Name ($GlobalPrefix + 'LastRefresh') -Value (Get-Date) -Force
        }
        else {
            Set-Variable -Scope Global -Name ($GlobalPrefix + 'LastRefresh') -Value $LastRefresh -Force
        }
    }

    function Reset-ProxyGlobals {
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'InstallPackageProvider') -Value @{} -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'InstallModule') -Value @{} -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'InvokeWebRequest') -Value @{} -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'PrepareSession') -Value $null -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'Mode') -Value $null -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'TestUri') -Value $null -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'Proxy') -Value $null -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'ProxyCredential') -Value $null -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'UseDefaultProxyCredentials') -Value $false -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'SessionPrepared') -Value $false -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'Diagnostics') -Value @() -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'ProfileSource') -Value $null -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'ProfilePath') -Value $ProxyProfilePath -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'Initialized') -Value $false -Force
        Set-Variable -Scope Global -Name ($GlobalPrefix + 'LastRefresh') -Value $null -Force
    }

    function Write-ProxyResolutionDiagnostics {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Mode,

            [Parameter(Mandatory = $true)]
            [string]$ProfileSource,

            [string[]]$Diagnostics = @(),

            [bool]$SessionPrepared = $false
        )

        _Write-StandardMessage -Message (
            "[STATUS] Proxy profile mode '{0}' from '{1}'. SessionPrepared={2}." -f
            $Mode, $ProfileSource, $SessionPrepared
        ) -Level INF

        foreach ($message in @($Diagnostics)) {
            $diagnosticText = [string]$message
            if ([string]::IsNullOrWhiteSpace($diagnosticText)) {
                continue
            }

            _Write-StandardMessage -Message ("[DIAG] {0}" -f $diagnosticText) -Level DBG
        }
    }

    function Get-AcceptAllCertificateValidationCallback {
        if (-not ('CertificateValidationHelper' -as [type])) {
            Add-Type -TypeDefinition @'
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

public static class CertificateValidationHelper
{
    public static bool AcceptAll(
        object sender,
        X509Certificate certificate,
        X509Chain chain,
        SslPolicyErrors sslPolicyErrors)
    {
        return true;
    }
}
'@
        }

        $bindingFlags =
            [System.Reflection.BindingFlags]::Public -bor
            [System.Reflection.BindingFlags]::Static

        $methodInfo = [CertificateValidationHelper].GetMethod('AcceptAll', $bindingFlags)
        if ($null -eq $methodInfo) {
            throw "Failed to resolve CertificateValidationHelper.AcceptAll."
        }

        return [System.Net.Security.RemoteCertificateValidationCallback](
            [System.Delegate]::CreateDelegate(
                [System.Net.Security.RemoteCertificateValidationCallback],
                $methodInfo
            )
        )
    }

    function Test-IsCertificateValidationFailure {
        param(
            [Parameter(Mandatory = $true)]
            [System.Exception]$Exception
        )

        $currentException = $Exception
        while ($null -ne $currentException) {
            if ($currentException -is [System.Security.Authentication.AuthenticationException]) {
                return $true
            }

            $currentException = $currentException.InnerException
        }

        return $false
    }

    function Ensure-ProfileDirectory {
        [Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs","")]
        param(
            [Parameter(Mandatory = $true)]
            [string]$ProfilePath
        )

        $directory = [System.IO.Path]::GetDirectoryName($ProfilePath)
        if (-not [string]::IsNullOrWhiteSpace($directory) -and -not [System.IO.Directory]::Exists($directory)) {
            [void][System.IO.Directory]::CreateDirectory($directory)
        }
    }

    function Wait-ProxyHostResolution {
        param(
            [Parameter(Mandatory = $true)]
            [uri]$ProxyUri
        )

        $hostName = $ProxyUri.DnsSafeHost

        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try {
                if ([System.Net.Dns]::GetHostAddresses($hostName).Count -gt 0) {
                    return $true
                }
            }
            catch {
            }

            if ($attempt -lt 3) {
                Start-Sleep -Milliseconds 750
            }
        }

        return $false
    }

    function Remove-PersistedProfile {
        param(
            [Parameter(Mandatory = $true)]
            [string]$ProfilePath
        )

        if (Test-Path -LiteralPath $ProfilePath) {
            Remove-Item -LiteralPath $ProfilePath -Force -ErrorAction SilentlyContinue
        }
    }

    function Save-PersistedProfile {
        param(
            [Parameter(Mandatory = $true)]
            [pscustomobject]$StoredProfile,

            [Parameter(Mandatory = $true)]
            [string]$ProfilePath
        )

        try {
            Ensure-ProfileDirectory -ProfilePath $ProfilePath
            Export-Clixml -InputObject $StoredProfile -LiteralPath $ProfilePath -Force -ErrorAction Stop

            if (-not (Test-Path -LiteralPath $ProfilePath)) {
                throw "The profile file could not be verified after export."
            }

            return $null
        }
        catch {
            return $_.Exception.Message
        }
    }

    function Load-PersistedProfile {
        [Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs","")]
        param(
            [Parameter(Mandatory = $true)]
            [string]$ProfilePath
        )

        if (-not (Test-Path -LiteralPath $ProfilePath)) {
            return $null
        }

        try {
            $storedProfile = Import-Clixml -LiteralPath $ProfilePath -ErrorAction Stop
            if ($null -eq $storedProfile) {
                return $null
            }

            return $storedProfile
        }
        catch {
            Remove-PersistedProfile -ProfilePath $ProfilePath
            return $null
        }
    }

    function New-StoredProfile {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('Direct','EnvironmentProxy','LocalRelayProxy','SystemProxyDefaultCredentials','ManualProxy','NoResolvedProxyProfile')]
            [string]$Mode,

            [Parameter(Mandatory = $true)]
            [uri]$DetectedTestUri,

            [uri]$ProxyUri,

            [pscredential]$ProxyCredential,

            [bool]$UseDefaultProxyCredentials = $false,

            [string[]]$Diagnostics = @()
        )

        [pscustomobject]@{
            Version                    = 1
            Mode                       = $Mode
            TestUri                    = [string]$DetectedTestUri
            ProxyUri                   = if ($null -ne $ProxyUri) { [string]$ProxyUri } else { $null }
            ProxyCredential            = $ProxyCredential
            UseDefaultProxyCredentials = $UseDefaultProxyCredentials
            LastRefreshUtc             = [DateTime]::UtcNow.ToString('o')
            Diagnostics                = @($Diagnostics)
        }
    }

    function Apply-StoredProfileToGlobals {
        [Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs","")]
        param(
            [Parameter(Mandatory = $true)]
            [pscustomobject]$StoredProfile,

            [Parameter(Mandatory = $true)]
            [string]$ProfileSource
        )

        $mode = [string]$StoredProfile.Mode
        $proxy = if ($StoredProfile.ProxyUri) { [uri][string]$StoredProfile.ProxyUri } else { $null }
        $proxyCredential = $null
        $useDefaultProxyCredentials = [bool]$StoredProfile.UseDefaultProxyCredentials
        $prepareSession = $null
        $sessionPrepared = $false

        if ($StoredProfile.ProxyCredential -is [System.Management.Automation.PSCredential]) {
            $proxyCredential = $StoredProfile.ProxyCredential
        }

        $installPackageProvider = @{}
        $installModule = @{}
        $invokeWebRequest = @{}

        switch ($mode) {
            'ManualProxy' {
                if ($null -ne $proxy -and $null -ne $proxyCredential) {
                    $installPackageProvider = @{
                        Proxy           = $proxy
                        ProxyCredential = $proxyCredential
                    }

                    $installModule = @{
                        Proxy           = $proxy
                        ProxyCredential = $proxyCredential
                    }

                    $invokeWebRequest = @{
                        Proxy           = $proxy
                        ProxyCredential = $proxyCredential
                    }

                    $capturedProxy = $proxy
                    $capturedCredential = $proxyCredential

                    $prepareSession = {
                        $webProxy = New-Object System.Net.WebProxy($capturedProxy.AbsoluteUri, $true)
                        $webProxy.Credentials = $capturedCredential.GetNetworkCredential()
                        [System.Net.WebRequest]::DefaultWebProxy = $webProxy
                    }.GetNewClosure()
                }
            }

            'EnvironmentProxy' {
                if ($null -ne $proxy) {
                    if ($useDefaultProxyCredentials -and $null -eq $proxyCredential) {
                        # Package cmdlets do not expose ProxyUseDefaultCredentials,
                        # so session preparation is the compatibility path here.
                        $invokeWebRequest = @{
                            Proxy = $proxy
                            ProxyUseDefaultCredentials = $true
                        }

                        $capturedProxy = $proxy

                        $prepareSession = {
                            $webProxy = New-Object System.Net.WebProxy($capturedProxy.AbsoluteUri, $true)
                            $webProxy.UseDefaultCredentials = $true
                            [System.Net.WebRequest]::DefaultWebProxy = $webProxy
                        }.GetNewClosure()
                    }
                    else {
                        $installPackageProvider = @{
                            Proxy = $proxy
                        }

                        $installModule = @{
                            Proxy = $proxy
                        }

                        $invokeWebRequest = @{
                            Proxy = $proxy
                        }

                        if ($null -ne $proxyCredential) {
                            $installPackageProvider['ProxyCredential'] = $proxyCredential
                            $installModule['ProxyCredential'] = $proxyCredential
                            $invokeWebRequest['ProxyCredential'] = $proxyCredential

                            $capturedProxy = $proxy
                            $capturedCredential = $proxyCredential

                            $prepareSession = {
                                $webProxy = New-Object System.Net.WebProxy($capturedProxy.AbsoluteUri, $true)
                                $webProxy.Credentials = $capturedCredential.GetNetworkCredential()
                                [System.Net.WebRequest]::DefaultWebProxy = $webProxy
                            }.GetNewClosure()
                        }
                        else {
                            $capturedProxy = $proxy

                            $prepareSession = {
                                [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($capturedProxy.AbsoluteUri, $true)
                            }.GetNewClosure()
                        }
                    }
                }
            }

            'LocalRelayProxy' {
                if ($null -ne $proxy) {
                    $installPackageProvider = @{
                        Proxy = $proxy
                    }

                    $installModule = @{
                        Proxy = $proxy
                    }

                    $invokeWebRequest = @{
                        Proxy = $proxy
                    }

                    $capturedProxy = $proxy

                    $prepareSession = {
                        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($capturedProxy.AbsoluteUri, $true)
                    }.GetNewClosure()
                }
            }

            'SystemProxyDefaultCredentials' {
                if ($null -ne $proxy) {
                    # Package cmdlets do not expose ProxyUseDefaultCredentials,
                    # so session preparation is the compatibility path here.
                    $invokeWebRequest = @{
                        Proxy                      = $proxy
                        ProxyUseDefaultCredentials = $true
                    }

                    $prepareSession = {
                        [System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
                        [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
                    }.GetNewClosure()
                }
            }

            'Direct' {
                if ($nativeSupportsNoProxy) {
                    $invokeWebRequest = @{
                        NoProxy = $true
                    }
                }

                $prepareSession = {
                    [System.Net.WebRequest]::DefaultWebProxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()
                }.GetNewClosure()
            }

            'NoResolvedProxyProfile' {
            }
        }

        if (-not $SkipSessionPreparation -and $null -ne $prepareSession) {
            & $prepareSession
            $sessionPrepared = $true
        }

        $lastRefresh = Get-Date
        if ($StoredProfile.LastRefreshUtc) {
            try {
                $lastRefresh = [datetime][string]$StoredProfile.LastRefreshUtc
            }
            catch {
            }
        }

        Set-ProxyGlobals `
            -Mode $mode `
            -InstallPackageProvider $installPackageProvider `
            -InstallModule $installModule `
            -InvokeWebRequest $invokeWebRequest `
            -PrepareSession $prepareSession `
            -Proxy $proxy `
            -ProxyCredential $proxyCredential `
            -UseDefaultProxyCredentials $useDefaultProxyCredentials `
            -SessionPrepared $sessionPrepared `
            -Diagnostics @($StoredProfile.Diagnostics) `
            -ProfileSource $ProfileSource `
            -LastRefresh $lastRefresh

        Write-ProxyResolutionDiagnostics `
            -Mode $mode `
            -ProfileSource $ProfileSource `
            -Diagnostics @($StoredProfile.Diagnostics) `
            -SessionPrepared:$sessionPrepared
    }

    function Test-Access {
        param(
            [Parameter(Mandatory = $true)]
            [uri]$Uri,

            [Parameter(Mandatory = $true)]
            [int]$TimeoutSec,

            [Parameter(Mandatory = $true)]
            [System.Net.IWebProxy]$Proxy
        )

        $certificateValidationBypassActive = [bool]$effectiveSkipCertificateCheck

        while ($true) {
            $response = $null

            try {
                $request = [System.Net.HttpWebRequest][System.Net.WebRequest]::Create($Uri)
                $request.Method = 'GET'
                $request.Timeout = $TimeoutSec * 1000
                $request.ReadWriteTimeout = $TimeoutSec * 1000
                $request.AllowAutoRedirect = $true
                $request.UserAgent = 'PowerShell Initialize-ProxyAccessProfile'
                # The caller controls whether this is a true direct test,
                # a loopback relay test, a system-proxy test, or a manual-proxy test.
                $request.Proxy = $Proxy

                if ($certificateValidationBypassActive -and $null -ne $acceptAllCallback) {
                    $request.ServerCertificateValidationCallback = $acceptAllCallback
                }

                $response = [System.Net.HttpWebResponse]$request.GetResponse()

                return [pscustomobject]@{
                    Success = $true
                    StatusCode = [int]$response.StatusCode
                    ErrorMessage = $null
                    IsCertificateValidationFailure = $false
                }
            }
            catch [System.Net.WebException] {
                $response = $null

                try {
                    if ($_.Exception.Response -is [System.Net.HttpWebResponse]) {
                        $response = [System.Net.HttpWebResponse]$_.Exception.Response
                    }
                }
                catch {
                    $response = $null
                }

                $isCertificateValidationFailure = Test-IsCertificateValidationFailure -Exception $_.Exception
                if (
                    -not $certificateValidationBypassActive -and
                    $automaticCertificateFallbackAllowed -and
                    $isCertificateValidationFailure -and
                    $null -ne $acceptAllCallback
                ) {
                    _Write-StandardMessage -Message (
                        "[WRN] TLS server certificate validation failed while probing '{0}'. Retrying once with certificate validation bypass enabled." -f
                        $Uri.AbsoluteUri
                    ) -Level WRN

                    $certificateValidationBypassActive = $true
                    continue
                }

                if ($null -ne $response) {
                    $statusCode = [int]$response.StatusCode
                    $isProxyAuthenticationRequired =
                        $statusCode -eq [int][System.Net.HttpStatusCode]::ProxyAuthenticationRequired

                    return [pscustomobject]@{
                        Success = -not $isProxyAuthenticationRequired
                        StatusCode = $statusCode
                        ErrorMessage = if ($isProxyAuthenticationRequired) { $_.Exception.Message } else { $null }
                        IsCertificateValidationFailure = $false
                    }
                }

                return [pscustomobject]@{
                    Success = $false
                    StatusCode = $null
                    ErrorMessage = $_.Exception.Message
                    IsCertificateValidationFailure = $isCertificateValidationFailure
                }
            }
            catch {
                $isCertificateValidationFailure = Test-IsCertificateValidationFailure -Exception $_.Exception
                if (
                    -not $certificateValidationBypassActive -and
                    $automaticCertificateFallbackAllowed -and
                    $isCertificateValidationFailure -and
                    $null -ne $acceptAllCallback
                ) {
                    _Write-StandardMessage -Message (
                        "[WRN] TLS server certificate validation failed while probing '{0}'. Retrying once with certificate validation bypass enabled." -f
                        $Uri.AbsoluteUri
                    ) -Level WRN

                    $certificateValidationBypassActive = $true
                    continue
                }

                return [pscustomobject]@{
                    Success = $false
                    StatusCode = $null
                    ErrorMessage = $_.Exception.Message
                    IsCertificateValidationFailure = $isCertificateValidationFailure
                }
            }
            finally {
                if ($response) {
                    $response.Close()
                }
            }
        }
    }

    function Get-EnvironmentVariableSetting {
        param(
            [Parameter(Mandatory = $true)]
            [string[]]$Names
        )

        foreach ($name in $Names) {
            $value = [System.Environment]::GetEnvironmentVariable($name)
            if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
                return [pscustomobject]@{
                    Name = $name
                    Value = [string]$value
                }
            }
        }

        return $null
    }

    function Get-NoProxyEntries {
        param(
            [string]$NoProxyValue
        )

        if ([string]::IsNullOrWhiteSpace($NoProxyValue)) {
            return @()
        }

        $entries = New-Object System.Collections.Generic.List[string]

        foreach ($rawEntry in ($NoProxyValue -split ',')) {
            $entry = [string]$rawEntry
            if (-not [string]::IsNullOrWhiteSpace($entry)) {
                [void]$entries.Add($entry.Trim())
            }
        }

        return @($entries.ToArray())
    }

    function Test-NoProxyEntryMatchesTarget {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Entry,

            [Parameter(Mandatory = $true)]
            [uri]$TargetUri
        )

        $entryText = [string]$Entry
        if ([string]::IsNullOrWhiteSpace($entryText)) {
            return $false
        }

        $entryText = $entryText.Trim()
        $targetHost = [string]$TargetUri.Host
        if ([string]::IsNullOrWhiteSpace($targetHost)) {
            return $false
        }

        $targetHostNormalized = $targetHost.Trim().Trim('.').ToLowerInvariant()
        $entryHostText = $entryText
        $entryPort = $null
        $entryHasLeadingDot = $entryText.StartsWith('.')

        if ($entryText -match '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
            try {
                $entryUri = [uri]$entryText
                $entryHostText = $entryUri.Host
                if (-not $entryUri.IsDefaultPort) {
                    $entryPort = [int]$entryUri.Port
                }
            }
            catch {
                return $false
            }
        }
        elseif ($entryText.StartsWith('[') -or $entryText -match '^[^:]+:\d+$') {
            try {
                $entryUri = [uri]("http://{0}" -f $entryText)
                $entryHostText = $entryUri.Host
                if (-not $entryUri.IsDefaultPort) {
                    $entryPort = [int]$entryUri.Port
                }
            }
            catch {
                return $false
            }
        }

        if ([string]::IsNullOrWhiteSpace($entryHostText)) {
            return $false
        }

        $entryHostNormalized = $entryHostText.Trim().Trim('.').ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($entryHostNormalized)) {
            return $false
        }

        if ($null -ne $entryPort -and $TargetUri.Port -ne $entryPort) {
            return $false
        }

        if ($entryHasLeadingDot) {
            $entryHostNormalized = $entryHostNormalized.TrimStart('.')
            if ([string]::IsNullOrWhiteSpace($entryHostNormalized)) {
                return $false
            }

            return $targetHostNormalized.EndsWith(".{0}" -f $entryHostNormalized)
        }

        return $targetHostNormalized -eq $entryHostNormalized
    }

    function Resolve-EnvironmentProxySetting {
        param(
            [Parameter(Mandatory = $true)]
            [uri]$TargetUri
        )

        $diagnostics = New-Object System.Collections.Generic.List[string]

        $proxyVariableNames = switch ($TargetUri.Scheme.ToLowerInvariant()) {
            'https' { @('https_proxy','HTTPS_PROXY','all_proxy','ALL_PROXY') }
            'http' { @('http_proxy','HTTP_PROXY','all_proxy','ALL_PROXY') }
            default { @('all_proxy','ALL_PROXY') }
        }

        $proxyVariable = Get-EnvironmentVariableSetting -Names $proxyVariableNames
        if ($null -eq $proxyVariable) {
            [void]$diagnostics.Add('No applicable environment proxy variable was found for the current target URI.')
            return [pscustomobject]@{
                Resolved = $false
                ProxyUri = $null
                ProxyCredential = $null
                SourceVariableName = $null
                Diagnostics = @($diagnostics.ToArray())
            }
        }

        $noProxyVariable = Get-EnvironmentVariableSetting -Names @('no_proxy','NO_PROXY')
        if ($null -ne $noProxyVariable) {
            foreach ($entry in (Get-NoProxyEntries -NoProxyValue $noProxyVariable.Value)) {
                if (Test-NoProxyEntryMatchesTarget -Entry $entry -TargetUri $TargetUri) {
                    [void]$diagnostics.Add("Environment proxy variable '$($proxyVariable.Name)' is bypassed for '$($TargetUri.Host)' by NO_PROXY entry '$entry'.")
                    return [pscustomobject]@{
                        Resolved = $false
                        ProxyUri = $null
                        ProxyCredential = $null
                        SourceVariableName = $proxyVariable.Name
                        Diagnostics = @($diagnostics.ToArray())
                    }
                }
            }
        }

        $proxyLiteral = ([string]$proxyVariable.Value).Trim()
        if ($proxyLiteral -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
            $proxyLiteral = "http://{0}" -f $proxyLiteral
        }

        try {
            $parsedProxyUri = [uri]$proxyLiteral
        }
        catch {
            [void]$diagnostics.Add("Environment proxy variable '$($proxyVariable.Name)' is invalid: $($_.Exception.Message)")
            return [pscustomobject]@{
                Resolved = $false
                ProxyUri = $null
                ProxyCredential = $null
                SourceVariableName = $proxyVariable.Name
                Diagnostics = @($diagnostics.ToArray())
            }
        }

        if (-not $parsedProxyUri.IsAbsoluteUri -or [string]::IsNullOrWhiteSpace($parsedProxyUri.Host)) {
            [void]$diagnostics.Add("Environment proxy variable '$($proxyVariable.Name)' does not contain a usable absolute proxy URI.")
            return [pscustomobject]@{
                Resolved = $false
                ProxyUri = $null
                ProxyCredential = $null
                SourceVariableName = $proxyVariable.Name
                Diagnostics = @($diagnostics.ToArray())
            }
        }

        $proxyScheme = $parsedProxyUri.Scheme.ToLowerInvariant()
        if (@('http','https') -notcontains $proxyScheme) {
            [void]$diagnostics.Add("Environment proxy variable '$($proxyVariable.Name)' uses unsupported proxy scheme '$proxyScheme'.")
            return [pscustomobject]@{
                Resolved = $false
                ProxyUri = $null
                ProxyCredential = $null
                SourceVariableName = $proxyVariable.Name
                Diagnostics = @($diagnostics.ToArray())
            }
        }

        if (($parsedProxyUri.AbsolutePath -ne '/') -or
            -not [string]::IsNullOrWhiteSpace($parsedProxyUri.Query) -or
            -not [string]::IsNullOrWhiteSpace($parsedProxyUri.Fragment)) {
            [void]$diagnostics.Add("Environment proxy variable '$($proxyVariable.Name)' contains unsupported path, query, or fragment text after the proxy host.")
            return [pscustomobject]@{
                Resolved = $false
                ProxyUri = $null
                ProxyCredential = $null
                SourceVariableName = $proxyVariable.Name
                Diagnostics = @($diagnostics.ToArray())
            }
        }

        $builder = New-Object System.UriBuilder($parsedProxyUri)
        $proxyCredential = $null

        if (-not [string]::IsNullOrWhiteSpace([string]$builder.UserName) -or
            -not [string]::IsNullOrWhiteSpace([string]$builder.Password)) {
            if ([string]::IsNullOrWhiteSpace([string]$builder.UserName)) {
                [void]$diagnostics.Add("Environment proxy variable '$($proxyVariable.Name)' contains proxy credentials without a user name.")
                return [pscustomobject]@{
                    Resolved = $false
                    ProxyUri = $null
                    ProxyCredential = $null
                    SourceVariableName = $proxyVariable.Name
                    Diagnostics = @($diagnostics.ToArray())
                }
            }

            try {
                $userName = [System.Uri]::UnescapeDataString([string]$builder.UserName)
                $password = [System.Uri]::UnescapeDataString([string]$builder.Password)
                $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
                $proxyCredential = New-Object System.Management.Automation.PSCredential($userName, $securePassword)
            }
            catch {
                [void]$diagnostics.Add("Environment proxy credentials from '$($proxyVariable.Name)' could not be parsed: $($_.Exception.Message)")
                return [pscustomobject]@{
                    Resolved = $false
                    ProxyUri = $null
                    ProxyCredential = $null
                    SourceVariableName = $proxyVariable.Name
                    Diagnostics = @($diagnostics.ToArray())
                }
            }

            $builder.UserName = ''
            $builder.Password = ''
        }

        $proxyUri = $builder.Uri
        [void]$diagnostics.Add("Environment proxy settings were resolved from '$($proxyVariable.Name)' as '$($proxyUri.AbsoluteUri)'.")

        return [pscustomobject]@{
            Resolved = $true
            ProxyUri = $proxyUri
            ProxyCredential = $proxyCredential
            SourceVariableName = $proxyVariable.Name
            Diagnostics = @($diagnostics.ToArray())
        }
    }

    function Try-ResolveEnvironmentProxy {
        [Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs","")]
        param(
            [Parameter(Mandatory = $true)]
            [uri]$Uri,

            [Parameter(Mandatory = $true)]
            [int]$TimeoutSec
        )

        $environmentProxy = Resolve-EnvironmentProxySetting -TargetUri $Uri
        $diagnostics = New-Object System.Collections.Generic.List[string]

        foreach ($message in $environmentProxy.Diagnostics) {
            [void]$diagnostics.Add($message)
        }

        if (-not $environmentProxy.Resolved -or $null -eq $environmentProxy.ProxyUri) {
            return [pscustomobject]@{
                Success = $false
                ProxyUri = $null
                ProxyCredential = $null
                UseDefaultProxyCredentials = $false
                StatusCode = $null
                Diagnostics = @($diagnostics.ToArray())
            }
        }

        if (-not (Wait-ProxyHostResolution -ProxyUri $environmentProxy.ProxyUri)) {
            [void]$diagnostics.Add(
                "Environment proxy host '$($environmentProxy.ProxyUri.DnsSafeHost)' did not resolve within the retry window."
            )

            return [pscustomobject]@{
                Success = $false
                ProxyUri = $environmentProxy.ProxyUri
                ProxyCredential = $environmentProxy.ProxyCredential
                UseDefaultProxyCredentials = $false
                StatusCode = $null
                Diagnostics = @($diagnostics.ToArray())
            }
        }

        try {
            $proxyObject = New-Object System.Net.WebProxy($environmentProxy.ProxyUri.AbsoluteUri, $true)
            if ($null -ne $environmentProxy.ProxyCredential) {
                $proxyObject.Credentials = $environmentProxy.ProxyCredential.GetNetworkCredential()
            }

            $result = Test-Access -Uri $Uri -TimeoutSec $TimeoutSec -Proxy $proxyObject

            if ($result.Success) {
                return [pscustomobject]@{
                    Success = $true
                    ProxyUri = $environmentProxy.ProxyUri
                    ProxyCredential = $environmentProxy.ProxyCredential
                    UseDefaultProxyCredentials = $false
                    StatusCode = $result.StatusCode
                    Diagnostics = @($diagnostics.ToArray())
                }
            }

            [void]$diagnostics.Add("Environment proxy '$($environmentProxy.ProxyUri.AbsoluteUri)' failed HTTP probe: $($result.ErrorMessage)")

            $canRetryWithDefaultProxyCredentials =
                ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) -and
                ($null -eq $environmentProxy.ProxyCredential)

            if ($canRetryWithDefaultProxyCredentials -and $result.StatusCode -eq [int][System.Net.HttpStatusCode]::ProxyAuthenticationRequired) {
                [void]$diagnostics.Add("Environment proxy '$($environmentProxy.ProxyUri.AbsoluteUri)' requested proxy authentication. Retrying once with default proxy credentials.")

                $defaultCredentialProxy = New-Object System.Net.WebProxy($environmentProxy.ProxyUri.AbsoluteUri, $true)
                $defaultCredentialProxy.UseDefaultCredentials = $true

                $defaultCredentialResult = Test-Access -Uri $Uri -TimeoutSec $TimeoutSec -Proxy $defaultCredentialProxy
                if ($defaultCredentialResult.Success) {
                    [void]$diagnostics.Add("Environment proxy '$($environmentProxy.ProxyUri.AbsoluteUri)' succeeded when retried with default proxy credentials.")
                    return [pscustomobject]@{
                        Success = $true
                        ProxyUri = $environmentProxy.ProxyUri
                        ProxyCredential = $null
                        UseDefaultProxyCredentials = $true
                        StatusCode = $defaultCredentialResult.StatusCode
                        Diagnostics = @($diagnostics.ToArray())
                    }
                }

                [void]$diagnostics.Add("Environment proxy '$($environmentProxy.ProxyUri.AbsoluteUri)' still failed after retry with default proxy credentials: $($defaultCredentialResult.ErrorMessage)")
            }
        }
        catch {
            [void]$diagnostics.Add("Environment proxy '$($environmentProxy.ProxyUri.AbsoluteUri)' check failed: $($_.Exception.Message)")
        }

        return [pscustomobject]@{
            Success = $false
            ProxyUri = $environmentProxy.ProxyUri
            ProxyCredential = $environmentProxy.ProxyCredential
            UseDefaultProxyCredentials = $false
            StatusCode = $null
            Diagnostics = @($diagnostics.ToArray())
        }
    }

    function Get-LocalRelayProxyCandidates {
        return @(
            [uri]'http://127.0.0.1:3128',
            [uri]'http://localhost:3128'
        )
    }

    function Test-LoopbackPortOpen {
        param(
            [Parameter(Mandatory = $true)]
            [uri]$ProxyUri,

            [ValidateRange(50,5000)]
            [int]$ConnectTimeoutMilliseconds = 400
        )

        $hostName = $ProxyUri.Host
        if (@('127.0.0.1', 'localhost', '::1') -notcontains $hostName) {
            return $false
        }

        $client = $null
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $asyncResult = $client.BeginConnect($hostName, $ProxyUri.Port, $null, $null)

            if (-not $asyncResult.AsyncWaitHandle.WaitOne($ConnectTimeoutMilliseconds, $false)) {
                return $false
            }

            [void]$client.EndConnect($asyncResult)
            return $client.Connected
        }
        catch {
            return $false
        }
        finally {
            if ($client) {
                $client.Close()
            }
        }
    }

    function Try-ResolveLocalRelayProxy {
        [Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs","")]
        param(
            [Parameter(Mandatory = $true)]
            [uri]$Uri,

            [Parameter(Mandatory = $true)]
            [int]$TimeoutSec
        )

        $diagnostics = New-Object System.Collections.Generic.List[string]

        foreach ($candidate in (Get-LocalRelayProxyCandidates)) {
            if (-not (Test-LoopbackPortOpen -ProxyUri $candidate)) {
                [void]$diagnostics.Add("Local relay proxy candidate '$($candidate.AbsoluteUri)' is not listening on loopback.")
                continue
            }

            try {
                $proxyObject = New-Object System.Net.WebProxy($candidate.AbsoluteUri, $true)
                $result = Test-Access -Uri $Uri -TimeoutSec $TimeoutSec -Proxy $proxyObject

                if ($result.Success) {
                    return [pscustomobject]@{
                        Success     = $true
                        ProxyUri    = $candidate
                        StatusCode  = $result.StatusCode
                        Diagnostics = @($diagnostics.ToArray())
                    }
                }

                [void]$diagnostics.Add("Local relay proxy candidate '$($candidate.AbsoluteUri)' failed HTTP probe: $($result.ErrorMessage)")
            }
            catch {
                [void]$diagnostics.Add("Local relay proxy candidate '$($candidate.AbsoluteUri)' check failed: $($_.Exception.Message)")
            }
        }

        return [pscustomobject]@{
            Success     = $false
            ProxyUri    = $null
            StatusCode  = $null
            Diagnostics = @($diagnostics.ToArray())
        }
    }

    function Test-PersistedProfile {
        [Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs","")]
        param(
            [Parameter(Mandatory = $true)]
            [pscustomobject]$StoredProfile,

            [Parameter(Mandatory = $true)]
            [uri]$ValidationUri,

            [Parameter(Mandatory = $true)]
            [int]$TimeoutSec
        )

        $diagnostics = New-Object System.Collections.Generic.List[string]
        $mode = [string]$StoredProfile.Mode

        switch ($mode) {
            'Direct' {
                $noProxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()
                $direct = Test-Access -Uri $ValidationUri -TimeoutSec $TimeoutSec -Proxy $noProxy

                if ($direct.Success) {
                    [void]$diagnostics.Add("Persisted direct profile validation succeeded with status code $($direct.StatusCode).")
                    return [pscustomobject]@{
                        Success     = $true
                        Diagnostics = @($diagnostics.ToArray())
                    }
                }

                [void]$diagnostics.Add("Persisted direct profile validation failed: $($direct.ErrorMessage)")
                return [pscustomobject]@{
                    Success     = $false
                    Diagnostics = @($diagnostics.ToArray())
                }
            }

            'EnvironmentProxy' {
                if (-not $StoredProfile.ProxyUri) {
                    [void]$diagnostics.Add('Persisted environment proxy profile is missing ProxyUri.')
                    return [pscustomobject]@{
                        Success     = $false
                        Diagnostics = @($diagnostics.ToArray())
                    }
                }

                $proxyCredential = $null
                if ($StoredProfile.ProxyCredential -is [System.Management.Automation.PSCredential]) {
                    $proxyCredential = [System.Management.Automation.PSCredential]$StoredProfile.ProxyCredential
                }
                elseif ($null -ne $StoredProfile.ProxyUserName) {
                    try {
                        $securePassword = ConvertTo-SecureString ([string]$StoredProfile.ProxyPassword) -AsPlainText -Force
                        $proxyCredential = New-Object System.Management.Automation.PSCredential(
                            [string]$StoredProfile.ProxyUserName,
                            $securePassword
                        )
                    }
                    catch {
                        $proxyCredential = $null
                    }
                }

                try {
                    $proxyUri = [uri][string]$StoredProfile.ProxyUri
                    if (-not (Wait-ProxyHostResolution -ProxyUri $proxyUri)) {
                        [void]$diagnostics.Add("Persisted environment proxy host '$($proxyUri.DnsSafeHost)' did not resolve within the retry window.")
                        return [pscustomobject]@{
                            Success     = $false
                            Diagnostics = @($diagnostics.ToArray())
                        }
                    }

                    $environmentProxy = New-Object System.Net.WebProxy($proxyUri.AbsoluteUri, $true)
                    if ([bool]$StoredProfile.UseDefaultProxyCredentials -and $null -eq $proxyCredential) {
                        $environmentProxy.UseDefaultCredentials = $true
                    }
                    elseif ($null -ne $proxyCredential) {
                        $environmentProxy.Credentials = $proxyCredential.GetNetworkCredential()
                    }

                    $result = Test-Access -Uri $ValidationUri -TimeoutSec $TimeoutSec -Proxy $environmentProxy

                    if ($result.Success) {
                        [void]$diagnostics.Add("Persisted environment proxy validation succeeded with status code $($result.StatusCode) via '$($proxyUri.AbsoluteUri)'.")
                        return [pscustomobject]@{
                            Success     = $true
                            Diagnostics = @($diagnostics.ToArray())
                        }
                    }

                    [void]$diagnostics.Add("Persisted environment proxy validation failed: $($result.ErrorMessage)")
                }
                catch {
                    [void]$diagnostics.Add("Persisted environment proxy validation check failed: $($_.Exception.Message)")
                }

                return [pscustomobject]@{
                    Success     = $false
                    Diagnostics = @($diagnostics.ToArray())
                }
            }

            'LocalRelayProxy' {
                if (-not $StoredProfile.ProxyUri) {
                    [void]$diagnostics.Add('Persisted local relay proxy profile is missing ProxyUri.')
                    return [pscustomobject]@{
                        Success     = $false
                        Diagnostics = @($diagnostics.ToArray())
                    }
                }

                try {
                    $proxyUri = [uri][string]$StoredProfile.ProxyUri
                }
                catch {
                    [void]$diagnostics.Add("Persisted local relay proxy URI could not be parsed: $($_.Exception.Message)")
                    return [pscustomobject]@{
                        Success     = $false
                        Diagnostics = @($diagnostics.ToArray())
                    }
                }

                if (-not (Test-LoopbackPortOpen -ProxyUri $proxyUri)) {
                    [void]$diagnostics.Add("Persisted local relay proxy '$($proxyUri.AbsoluteUri)' is not listening on loopback.")
                    return [pscustomobject]@{
                        Success     = $false
                        Diagnostics = @($diagnostics.ToArray())
                    }
                }

                try {
                    $proxyObject = New-Object System.Net.WebProxy($proxyUri.AbsoluteUri, $true)
                    $result = Test-Access -Uri $ValidationUri -TimeoutSec $TimeoutSec -Proxy $proxyObject

                    if ($result.Success) {
                        [void]$diagnostics.Add("Persisted local relay proxy validation succeeded with status code $($result.StatusCode) via '$($proxyUri.AbsoluteUri)'.")
                        return [pscustomobject]@{
                            Success     = $true
                            Diagnostics = @($diagnostics.ToArray())
                        }
                    }

                    [void]$diagnostics.Add("Persisted local relay proxy validation failed: $($result.ErrorMessage)")
                }
                catch {
                    [void]$diagnostics.Add("Persisted local relay proxy validation check failed: $($_.Exception.Message)")
                }

                return [pscustomobject]@{
                    Success     = $false
                    Diagnostics = @($diagnostics.ToArray())
                }
            }

            'SystemProxyDefaultCredentials' {
                try {
                    $systemProxy = [System.Net.WebRequest]::GetSystemWebProxy()
                    $resolvedProxy = $systemProxy.GetProxy($ValidationUri)

                    if ($systemProxy.IsBypassed($ValidationUri) -or
                        -not $resolvedProxy -or
                        $resolvedProxy.AbsoluteUri -eq $ValidationUri.AbsoluteUri) {
                        [void]$diagnostics.Add('Persisted system proxy profile validation found no distinct system proxy for the current test URI.')
                        return [pscustomobject]@{
                            Success     = $false
                            Diagnostics = @($diagnostics.ToArray())
                        }
                    }

                    $systemProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
                    $result = Test-Access -Uri $ValidationUri -TimeoutSec $TimeoutSec -Proxy $systemProxy

                    if ($result.Success) {
                        [void]$diagnostics.Add("Persisted system proxy validation succeeded with status code $($result.StatusCode) via '$($resolvedProxy.AbsoluteUri)'.")
                        return [pscustomobject]@{
                            Success     = $true
                            Diagnostics = @($diagnostics.ToArray())
                        }
                    }

                    [void]$diagnostics.Add("Persisted system proxy validation failed: $($result.ErrorMessage)")
                }
                catch {
                    [void]$diagnostics.Add("Persisted system proxy validation check failed: $($_.Exception.Message)")
                }

                return [pscustomobject]@{
                    Success     = $false
                    Diagnostics = @($diagnostics.ToArray())
                }
            }

            'ManualProxy' {
                if (-not $StoredProfile.ProxyUri) {
                    [void]$diagnostics.Add('Persisted manual proxy profile is missing ProxyUri.')
                    return [pscustomobject]@{
                        Success     = $false
                        Diagnostics = @($diagnostics.ToArray())
                    }
                }

                if (-not ($StoredProfile.ProxyCredential -is [System.Management.Automation.PSCredential])) {
                    [void]$diagnostics.Add('Persisted manual proxy profile is missing a usable PSCredential.')
                    return [pscustomobject]@{
                        Success     = $false
                        Diagnostics = @($diagnostics.ToArray())
                    }
                }

                try {
                    $proxyUri = [uri][string]$StoredProfile.ProxyUri
                    $proxyCredential = [System.Management.Automation.PSCredential]$StoredProfile.ProxyCredential

                    if (-not (Wait-ProxyHostResolution -ProxyUri $proxyUri)) {
                        [void]$diagnostics.Add("Persisted manual proxy host '$($proxyUri.DnsSafeHost)' did not resolve within the retry window.")
                        return [pscustomobject]@{
                            Success     = $false
                            Diagnostics = @($diagnostics.ToArray())
                        }
                    }

                    $manualProxy = New-Object System.Net.WebProxy($proxyUri.AbsoluteUri, $true)
                    $manualProxy.Credentials = $proxyCredential.GetNetworkCredential()
                    $result = Test-Access -Uri $ValidationUri -TimeoutSec $TimeoutSec -Proxy $manualProxy

                    if ($result.Success) {
                        [void]$diagnostics.Add("Persisted manual proxy validation succeeded with status code $($result.StatusCode) via '$($proxyUri.AbsoluteUri)'.")
                        return [pscustomobject]@{
                            Success     = $true
                            Diagnostics = @($diagnostics.ToArray())
                        }
                    }

                    [void]$diagnostics.Add("Persisted manual proxy validation failed: $($result.ErrorMessage)")
                }
                catch {
                    [void]$diagnostics.Add("Persisted manual proxy validation check failed: $($_.Exception.Message)")
                }

                return [pscustomobject]@{
                    Success     = $false
                    Diagnostics = @($diagnostics.ToArray())
                }
            }

            'NoResolvedProxyProfile' {
                [void]$diagnostics.Add('Persisted NoResolvedProxyProfile entries are not considered reusable.')
                return [pscustomobject]@{
                    Success     = $false
                    Diagnostics = @($diagnostics.ToArray())
                }
            }

            default {
                [void]$diagnostics.Add("Persisted profile mode '$mode' is not supported.")
                return [pscustomobject]@{
                    Success     = $false
                    Diagnostics = @($diagnostics.ToArray())
                }
            }
        }
    }

    function Get-ManualProxyEntry {
        param(
            [Parameter(Mandatory = $true)]
            [string]$DefaultProxy
        )

        Add-Type -AssemblyName System.Windows.Forms,System.Drawing
        [System.Windows.Forms.Application]::EnableVisualStyles()

        $form = New-Object System.Windows.Forms.Form
        $form.Text = 'Proxy settings'
        $form.StartPosition = 'CenterScreen'
        $form.TopMost = $true
        $form.FormBorderStyle = 'FixedDialog'
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
        $form.ClientSize = New-Object System.Drawing.Size(400,170)
        $form.Font = New-Object System.Drawing.Font('Segoe UI',10)

        $lbl1 = New-Object System.Windows.Forms.Label
        $lbl1.Text = 'Proxy address'
        $lbl1.Location = New-Object System.Drawing.Point(15,21)
        $lbl1.AutoSize = $true
        [void]$form.Controls.Add($lbl1)

        $txtProxy = New-Object System.Windows.Forms.TextBox
        $txtProxy.Location = New-Object System.Drawing.Point(120,18)
        $txtProxy.Size = New-Object System.Drawing.Size(260,23)
        $txtProxy.Text = $DefaultProxy
        [void]$form.Controls.Add($txtProxy)

        $lbl2 = New-Object System.Windows.Forms.Label
        $lbl2.Text = 'Username'
        $lbl2.Location = New-Object System.Drawing.Point(15,55)
        $lbl2.AutoSize = $true
        [void]$form.Controls.Add($lbl2)

        $txtUser = New-Object System.Windows.Forms.TextBox
        $txtUser.Location = New-Object System.Drawing.Point(120,52)
        $txtUser.Size = New-Object System.Drawing.Size(260,23)
        [void]$form.Controls.Add($txtUser)

        $lbl3 = New-Object System.Windows.Forms.Label
        $lbl3.Text = 'Password'
        $lbl3.Location = New-Object System.Drawing.Point(15,89)
        $lbl3.AutoSize = $true
        [void]$form.Controls.Add($lbl3)

        $txtPass = New-Object System.Windows.Forms.TextBox
        $txtPass.Location = New-Object System.Drawing.Point(120,86)
        $txtPass.Size = New-Object System.Drawing.Size(260,23)
        $txtPass.UseSystemPasswordChar = $true
        [void]$form.Controls.Add($txtPass)

        $ok = New-Object System.Windows.Forms.Button
        $ok.Text = 'OK'
        $ok.Location = New-Object System.Drawing.Point(224,124)
        $ok.Size = New-Object System.Drawing.Size(75,28)
        $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
        [void]$form.Controls.Add($ok)

        $cancel = New-Object System.Windows.Forms.Button
        $cancel.Text = 'Cancel'
        $cancel.Location = New-Object System.Drawing.Point(305,124)
        $cancel.Size = New-Object System.Drawing.Size(75,28)
        $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        [void]$form.Controls.Add($cancel)

        $form.AcceptButton = $ok
        $form.CancelButton = $cancel

        if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            return $null
        }

        [pscustomobject]@{
            ProxyUri = [uri]$txtProxy.Text
            ProxyCredential = New-Object System.Management.Automation.PSCredential(
                $txtUser.Text,
                (ConvertTo-SecureString $txtPass.Text -AsPlainText -Force)
            )
        }
    }

    $acceptAllCallback = $null
    $persistedProfileValidationDiagnostics = @()

    try {
        try {
            $tls12 = [System.Net.SecurityProtocolType]::Tls12
            $currentProtocols = [System.Net.ServicePointManager]::SecurityProtocol

            if (($currentProtocols -band $tls12) -ne $tls12) {
                [System.Net.ServicePointManager]::SecurityProtocol = $currentProtocols -bor $tls12
            }
        }
        catch {
        }

        if ($effectiveSkipCertificateCheck -or $automaticCertificateFallbackAllowed) {
            $acceptAllCallback = Get-AcceptAllCertificateValidationCallback
        }

        Ensure-ProfileDirectory -ProfilePath $ProxyProfilePath

        if (-not $ForceRefresh) {
            $storedProfile = Load-PersistedProfile -ProfilePath $ProxyProfilePath
            if ($null -ne $storedProfile) {
                $persistedValidation = Test-PersistedProfile `
                    -StoredProfile $storedProfile `
                    -ValidationUri $TestUri `
                    -TimeoutSec $TimeoutSec

                if ($persistedValidation.Success) {
                    Reset-ProxyGlobals
                    Apply-StoredProfileToGlobals -StoredProfile $storedProfile -ProfileSource 'ProfileFile'
                    return
                }

                $persistedProfileValidationDiagnostics = @($persistedValidation.Diagnostics)
                Remove-PersistedProfile -ProfilePath $ProxyProfilePath
            }
        }

        Reset-ProxyGlobals

        $diagnostics = New-Object System.Collections.Generic.List[string]
        foreach ($message in $persistedProfileValidationDiagnostics) {
            [void]$diagnostics.Add($message)
        }

        $isInteractive = [System.Environment]::UserInteractive

        # True direct test: use an empty proxy so the probe cannot silently fall back
        # to system proxy settings behind our back.
        $noProxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()
        $direct = Test-Access -Uri $TestUri -TimeoutSec $TimeoutSec -Proxy $noProxy

        if ($direct.Success) {
            $stored = New-StoredProfile `
                -Mode 'Direct' `
                -DetectedTestUri $TestUri `
                -Diagnostics @(
                    $diagnostics.ToArray() +
                    "Direct probe succeeded with status code $($direct.StatusCode)."
                )

            $saveError = Save-PersistedProfile -StoredProfile $stored -ProfilePath $ProxyProfilePath
            if ($saveError) {
                $stored.Diagnostics = @($stored.Diagnostics + "Profile file save failed: $saveError")
            }

            Apply-StoredProfileToGlobals -StoredProfile $stored -ProfileSource 'FreshDetection'
            return
        }

        [void]$diagnostics.Add("Direct probe failed: $($direct.ErrorMessage)")

        # Try process-environment proxy settings before heuristic local or system proxy discovery.
        $environmentProxy = Try-ResolveEnvironmentProxy -Uri $TestUri -TimeoutSec $TimeoutSec

        foreach ($message in $environmentProxy.Diagnostics) {
            [void]$diagnostics.Add($message)
        }

        if ($environmentProxy.Success -and $null -ne $environmentProxy.ProxyUri) {
            $stored = New-StoredProfile `
                -Mode 'EnvironmentProxy' `
                -DetectedTestUri $TestUri `
                -ProxyUri $environmentProxy.ProxyUri `
                -ProxyCredential $environmentProxy.ProxyCredential `
                -UseDefaultProxyCredentials $environmentProxy.UseDefaultProxyCredentials `
                -Diagnostics @(
                    $diagnostics.ToArray() +
                    "Environment proxy probe succeeded with status code $($environmentProxy.StatusCode) via '$($environmentProxy.ProxyUri.AbsoluteUri)'."
                )

            $saveError = Save-PersistedProfile -StoredProfile $stored -ProfilePath $ProxyProfilePath
            if ($saveError) {
                $stored.Diagnostics = @($stored.Diagnostics + "Profile file save failed: $saveError")
            }

            Apply-StoredProfileToGlobals -StoredProfile $stored -ProfileSource 'FreshDetection'
            return
        }

        # Try a local loopback relay before system proxy. This is useful when users
        # run tools like px or similar local proxy helpers.
        $localRelay = Try-ResolveLocalRelayProxy -Uri $TestUri -TimeoutSec $TimeoutSec

        foreach ($message in $localRelay.Diagnostics) {
            [void]$diagnostics.Add($message)
        }

        if ($localRelay.Success -and $null -ne $localRelay.ProxyUri) {
            $stored = New-StoredProfile `
                -Mode 'LocalRelayProxy' `
                -DetectedTestUri $TestUri `
                -ProxyUri $localRelay.ProxyUri `
                -Diagnostics @(
                    $diagnostics.ToArray() +
                    "Local relay proxy probe succeeded with status code $($localRelay.StatusCode) via '$($localRelay.ProxyUri.AbsoluteUri)'."
                )

            $saveError = Save-PersistedProfile -StoredProfile $stored -ProfilePath $ProxyProfilePath
            if ($saveError) {
                $stored.Diagnostics = @($stored.Diagnostics + "Profile file save failed: $saveError")
            }

            Apply-StoredProfileToGlobals -StoredProfile $stored -ProfileSource 'FreshDetection'
            return
        }

        $systemProxy = [System.Net.WebRequest]::GetSystemWebProxy()
        $resolvedProxy = $systemProxy.GetProxy($TestUri)

        if (-not $systemProxy.IsBypassed($TestUri) -and
            $resolvedProxy -and
            $resolvedProxy.AbsoluteUri -ne $TestUri.AbsoluteUri) {

            # In system-proxy mode we try integrated auth with the current Windows user.
            $systemProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
            $system = Test-Access -Uri $TestUri -TimeoutSec $TimeoutSec -Proxy $systemProxy

            if ($system.Success) {
                $stored = New-StoredProfile `
                    -Mode 'SystemProxyDefaultCredentials' `
                    -DetectedTestUri $TestUri `
                    -ProxyUri $resolvedProxy `
                    -UseDefaultProxyCredentials $true `
                    -Diagnostics @(
                        $diagnostics.ToArray() +
                        "System proxy probe succeeded with status code $($system.StatusCode)."
                    )

                $saveError = Save-PersistedProfile -StoredProfile $stored -ProfilePath $ProxyProfilePath
                if ($saveError) {
                    $stored.Diagnostics = @($stored.Diagnostics + "Profile file save failed: $saveError")
                }

                Apply-StoredProfileToGlobals -StoredProfile $stored -ProfileSource 'FreshDetection'
                return
            }

            [void]$diagnostics.Add("System proxy probe failed: $($system.ErrorMessage)")
        }
        else {
            [void]$diagnostics.Add('No distinct system proxy was resolved for the test URI.')
        }

        if (-not $SkipManualProxyPrompt) {
            if (-not $isInteractive) {
                Remove-PersistedProfile -ProfilePath $ProxyProfilePath
                throw "Manual proxy entry is required for '$($TestUri.AbsoluteUri)', but the current session is non-interactive. Provide proxy parameters explicitly or pre-stage a usable proxy profile file."
            }

            try {
                $manual = Get-ManualProxyEntry -DefaultProxy $DefaultManualProxy
            }
            catch {
                $manual = $null
                [void]$diagnostics.Add("Manual proxy prompt failed: $($_.Exception.Message)")
            }

            if ($manual) {
                if (-not (Wait-ProxyHostResolution -ProxyUri $manual.ProxyUri)) {
                    [void]$diagnostics.Add("Manual proxy host '$($manual.ProxyUri.DnsSafeHost)' did not resolve within the retry window.")
                }
                else {
                    $manualProxy = New-Object System.Net.WebProxy($manual.ProxyUri.AbsoluteUri, $true)
                    $manualProxy.Credentials = $manual.ProxyCredential.GetNetworkCredential()
                    $manualTest = Test-Access -Uri $TestUri -TimeoutSec $TimeoutSec -Proxy $manualProxy

                    if ($manualTest.Success) {
                        $stored = New-StoredProfile `
                            -Mode 'ManualProxy' `
                            -DetectedTestUri $TestUri `
                            -ProxyUri $manual.ProxyUri `
                            -ProxyCredential $manual.ProxyCredential `
                            -Diagnostics @(
                                $diagnostics.ToArray() +
                                "Manual proxy probe succeeded with status code $($manualTest.StatusCode)."
                            )

                        $saveError = Save-PersistedProfile -StoredProfile $stored -ProfilePath $ProxyProfilePath
                        if ($saveError) {
                            $stored.Diagnostics = @($stored.Diagnostics + "Profile file save failed: $saveError")
                        }

                        Apply-StoredProfileToGlobals -StoredProfile $stored -ProfileSource 'FreshDetection'
                        return
                    }

                    [void]$diagnostics.Add("Manual proxy probe failed: $($manualTest.ErrorMessage)")
                }
            }
            else {
                [void]$diagnostics.Add('Manual proxy entry was cancelled.')
            }
        }
        else {
            [void]$diagnostics.Add('Manual proxy prompt was skipped by caller.')
        }

        # We do not persist a NoResolvedProxyProfile state. That avoids carrying a bad result
        # across sessions after a temporary network problem.
        Remove-PersistedProfile -ProfilePath $ProxyProfilePath

        Set-ProxyGlobals `
            -Mode 'NoResolvedProxyProfile' `
            -Diagnostics $diagnostics.ToArray() `
            -ProfileSource 'FreshDetection'

        Write-ProxyResolutionDiagnostics `
            -Mode 'NoResolvedProxyProfile' `
            -ProfileSource 'FreshDetection' `
            -Diagnostics $diagnostics.ToArray() `
            -SessionPrepared:$false
    }
    finally {
        # No function-wide certificate validation callback state is retained.
    }
}

function Initialize-ProxyCompact{param([uri]$TestUri='https://www.powershellgallery.com/api/v2/',[int]$TimeoutSec=8,[string]$DefManProxy='http://test.corp.com:8080',[string]$DefManUser='',[string]$GlobalPrefix='ProxyParams',[string]$pf=($env:LOCALAPPDATA+'\Programs\ProxyAccessProfile\ProxyAccessProfile.clixml'));$wr=[Net.WebRequest];$cc=[Net.CredentialCache];$gp=[Net.GlobalProxySelection];$dc=$cc::DefaultCredentials;$p407=[int][Net.HttpStatusCode]::ProxyAuthenticationRequired;if((Get-Variable ($GlobalPrefix+'Initialized') -Scope Global -ea 0 -ValueOnly)){return};function ep{$gp::GetEmptyWebProxy()};function swp{$wr::GetSystemWebProxy()};function ws($x){[string]::IsNullOrWhiteSpace([string]$x)};function td{[pscustomobject]@{Success=$true}};function fd0{[pscustomobject]@{Success=$false}};function fs($p=$null,$pc=$null,[bool]$udc=$false,$sc0=$null){[pscustomobject]@{Success=$false;ProxyUri=$p;ProxyCredential=$pc;UseDefaultProxyCredentials=$udc;StatusCode=$sc0}};function nur($p=$null){[pscustomobject]@{Resolved=$false;ProxyUri=$null;ProxyCredential=$null;SourceVariableName=$p}};function g($h){$h.Keys|ForEach-Object {Set-Variable -Scope Global -Name ($GlobalPrefix+$_) -Value $h[$_] -Force}};function cf($e){while($e){if($e -is [Security.Authentication.AuthenticationException]){return $true};$e=$e.InnerException};$false};function ed($p){$d=[IO.Path]::GetDirectoryName($p);if($d -and -not [IO.Directory]::Exists($d)){[void][IO.Directory]::CreateDirectory($d)}};function dp($p){if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Force -ea 0}};function pt($x,$y){[Drawing.Point]::new($x,$y)};function sz($w,$h){[Drawing.Size]::new($w,$h)};function fp($x,$p){try{ed $p;Export-Clixml -InputObject $x -LiteralPath $p -Force -ea Stop}catch{}};function rap($o){fp $o $pf;ap $o};function wp([uri]$p,$pc=$null,[bool]$udc=$false){$w=[Net.WebProxy]::new($p.AbsoluteUri,$true);if($udc){$w.UseDefaultCredentials=$true}elseif($pc){$w.Credentials=$pc.GetNetworkCredential()};$w};function wpr{param([uri]$u)$h=$u.DnsSafeHost;for($i=1;$i-le 3;$i++){try{if([Net.Dns]::GetHostAddresses($h).Count){return $i}}catch{};if($i-lt 3){Start-Sleep -Milliseconds 750}}0};function ev($n){foreach($k in $n){$v=[Environment]::GetEnvironmentVariable($k);if(-not(ws $v)){return [pscustomobject]@{Name=$k;Value=[string]$v}}};$null};function lc{@([uri]'http://127.0.0.1:3128',[uri]'http://localhost:3128')};function z{g @{InstallPackageProvider=@{};InstallModule=@{};InvokeWebRequest=@{};PrepareSession=$null;Mode=$null;Proxy=$null;ProxyCredential=$null;UseDefaultProxyCredentials=$false;Initialized=$false}};function s($m,$ipp=@{},$im=@{},$iwr=@{},$ps=$null,[uri]$p=$null,[pscredential]$pc=$null,[bool]$udc=$false){g @{InstallPackageProvider=$ipp;InstallModule=$im;InvokeWebRequest=$iwr;PrepareSession=$ps;Mode=$m;Proxy=$p;ProxyCredential=$pc;UseDefaultProxyCredentials=$udc;Initialized=$true}};function cb{if(-not('CVH'-as[type])){Add-Type -TypeDefinition 'using System.Net.Security;using System.Security.Cryptography.X509Certificates;public static class CVH{public static bool A(object s,X509Certificate c,X509Chain h,SslPolicyErrors e){return true;}}'};$m=[CVH].GetMethod('A',[Reflection.BindingFlags]'Public,Static');if(!$m){throw'no CVH.A'};[Net.Security.RemoteCertificateValidationCallback]([Delegate]::CreateDelegate([Net.Security.RemoteCertificateValidationCallback],$m))};function xlp($p){if(!(Test-Path -LiteralPath $p)){return $null};try{$x=Import-Clixml -LiteralPath $p -ea Stop;if($null -eq $x){return $null};$x}catch{dp $p;$null}};function npf($m,[uri]$p,$pc,[bool]$udc=$false){[pscustomobject]@{Mode=$m;ProxyUri=if($p){[string]$p}else{$null};ProxyCredential=$pc;UseDefaultProxyCredentials=$udc}};function nx($v){if(ws $v){return @()};$r=New-Object System.Collections.ArrayList;foreach($x in ($v -split ',')){if(-not(ws $x)){[void]$r.Add($x.Trim())}};@($r.ToArray())};function nm0($e,[uri]$u){if(ws $e){return $false};$e=$e.Trim();$th=[string]$u.Host;if(ws $th){return $false};$tn=$th.Trim().Trim('.').ToLowerInvariant();$eh=$e;$ep=$null;$ld=$e.StartsWith('.');if($e -match '^[a-zA-Z][a-zA-Z0-9+.-]*://'){try{$x=[uri]$e;$eh=$x.Host;if(!$x.IsDefaultPort){$ep=[int]$x.Port}}catch{return $false}}elseif($e.StartsWith('[') -or $e -match '^[^:]+:\d+$'){try{$x=[uri]('http://{0}' -f $e);$eh=$x.Host;if(!$x.IsDefaultPort){$ep=[int]$x.Port}}catch{return $false}};if(ws $eh){return $false};$en=$eh.Trim().Trim('.').ToLowerInvariant();if(ws $en){return $false};if($null -ne $ep -and $u.Port -ne $ep){return $false};if($ld){$en=$en.TrimStart('.');if(ws $en){return $false};return $tn.EndsWith(('.{0}' -f $en))};$tn -eq $en};function ap($x){$m=[string]$x.Mode;$p=if($x.ProxyUri){[uri][string]$x.ProxyUri}else{$null};$pc=$null;if($x.ProxyCredential -is [pscredential]){$pc=$x.ProxyCredential};$udc=[bool]$x.UseDefaultProxyCredentials;$ipp=@{};$im=@{};$iwr=@{};$ps=$null;switch($m){'ManualProxy'{if($p -and $pc){$h=@{Proxy=$p;ProxyCredential=$pc};$ipp=$h;$im=$h;$iwr=$h;$pp=$p;$cc0=$pc;$ps={$w=[Net.WebProxy]::new($pp.AbsoluteUri,$true);$w.Credentials=$cc0.GetNetworkCredential();[Net.WebRequest]::DefaultWebProxy=$w}.GetNewClosure()}}'EnvironmentProxy'{if($p){if($udc -and !$pc){$iwr=@{Proxy=$p;ProxyUseDefaultCredentials=$true};$pp=$p;$ps={$w=[Net.WebProxy]::new($pp.AbsoluteUri,$true);$w.UseDefaultCredentials=$true;[Net.WebRequest]::DefaultWebProxy=$w}.GetNewClosure()}else{$h=@{Proxy=$p};if($pc){$h.ProxyCredential=$pc};$ipp=$h;$im=$h;$iwr=$h;if($pc){$pp=$p;$cc0=$pc;$ps={$w=[Net.WebProxy]::new($pp.AbsoluteUri,$true);$w.Credentials=$cc0.GetNetworkCredential();[Net.WebRequest]::DefaultWebProxy=$w}.GetNewClosure()}else{$pp=$p;$ps={[Net.WebRequest]::DefaultWebProxy=[Net.WebProxy]::new($pp.AbsoluteUri,$true)}.GetNewClosure()}}}}'LocalRelayProxy'{if($p){$h=@{Proxy=$p};$ipp=$h;$im=$h;$iwr=$h;$pp=$p;$ps={[Net.WebRequest]::DefaultWebProxy=[Net.WebProxy]::new($pp.AbsoluteUri,$true)}.GetNewClosure()}}'SystemProxyDefaultCredentials'{if($p){$iwr=@{Proxy=$p;ProxyUseDefaultCredentials=$true};$ps={[Net.WebRequest]::DefaultWebProxy=[Net.WebRequest]::GetSystemWebProxy();[Net.WebRequest]::DefaultWebProxy.Credentials=$dc}.GetNewClosure()}}'Direct'{$ps={[Net.WebRequest]::DefaultWebProxy=[Net.GlobalProxySelection]::GetEmptyWebProxy()}.GetNewClosure()}};if($ps){$null=$ps.Invoke()};s $m $ipp $im $iwr $ps $p $pc $udc};function a([uri]$u,[int]$t,[Net.IWebProxy]$p){$b=$false;while($true){$r=$null;try{$q=[Net.HttpWebRequest][Net.WebRequest]::Create($u);$q.Method='GET';$q.Timeout=$t*1000;$q.ReadWriteTimeout=$t*1000;$q.AllowAutoRedirect=$true;$q.UserAgent='ps';$q.Proxy=$p;if($b){$q.ServerCertificateValidationCallback=$cbk};$r=[Net.HttpWebResponse]$q.GetResponse();return [pscustomobject]@{Success=$true;StatusCode=[int]$r.StatusCode;ErrorMessage=$null}}catch [Net.WebException]{$r=$null;try{if($_.Exception.Response -is [Net.HttpWebResponse]){$r=[Net.HttpWebResponse]$_.Exception.Response}}catch{$r=$null};$ic=cf $_.Exception;if(!$b -and $ic){$b=$true;continue};if($r){$sc0=[int]$r.StatusCode;$pa=$sc0 -eq $p407;return [pscustomobject]@{Success=!$pa;StatusCode=$sc0;ErrorMessage=if($pa){$_.Exception.Message}else{$null}}};return [pscustomobject]@{Success=$false;StatusCode=$null;ErrorMessage=$_.Exception.Message}}catch{$ic=cf $_.Exception;if(!$b -and $ic){$b=$true;continue};return [pscustomobject]@{Success=$false;StatusCode=$null;ErrorMessage=$_.Exception.Message}}finally{if($r){$r.Close()}}}};function re([uri]$u){$pv=switch($u.Scheme.ToLowerInvariant()){'https'{@('https_proxy','HTTPS_PROXY','all_proxy','ALL_PROXY')}'http'{@('http_proxy','HTTP_PROXY','all_proxy','ALL_PROXY')}default{@('all_proxy','ALL_PROXY')}};$p=ev $pv;if(!$p){return (nur)};$n=ev @('no_proxy','NO_PROXY');if($n){foreach($e in (nx $n.Value)){if(nm0 $e $u){return (nur $p.Name)}}};$pl=([string]$p.Value).Trim();if($pl -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://'){$pl='http://'+$pl};try{$pp=[uri]$pl}catch{return (nur $p.Name)};if(!$pp.IsAbsoluteUri -or (ws $pp.Host)){return (nur $p.Name)};$ps0=$pp.Scheme.ToLowerInvariant();if(@('http','https') -notcontains $ps0){return (nur $p.Name)};if(($pp.AbsolutePath -ne '/') -or -not(ws $pp.Query) -or -not(ws $pp.Fragment)){return (nur $p.Name)};$b=[UriBuilder]::new($pp);$pc=$null;if(-not(ws ([string]$b.UserName)) -or -not(ws ([string]$b.Password))){if(ws ([string]$b.UserName)){return (nur $p.Name)};try{$un=[Uri]::UnescapeDataString([string]$b.UserName);$pw=[Uri]::UnescapeDataString([string]$b.Password);$pc=[pscredential]::new($un,(ConvertTo-SecureString $pw -AsPlainText -Force))}catch{return (nur $p.Name)};$b.UserName='';$b.Password=''};$pu=$b.Uri;[pscustomobject]@{Resolved=$true;ProxyUri=$pu;ProxyCredential=$pc;SourceVariableName=$p.Name}};function te([uri]$u,[int]$t){$e=re $u;if(!$e.Resolved -or !$e.ProxyUri -or !(wpr $e.ProxyUri)){return (fs $e.ProxyUri $e.ProxyCredential $false $null)};try{$w=wp $e.ProxyUri $e.ProxyCredential;$v=a $u $t $w;if($v.Success){return [pscustomobject]@{Success=$true;ProxyUri=$e.ProxyUri;ProxyCredential=$e.ProxyCredential;UseDefaultProxyCredentials=$false;StatusCode=$v.StatusCode}};$rd0=[Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT -and !$e.ProxyCredential;if($rd0 -and $v.StatusCode -eq $p407){$w=wp $e.ProxyUri $null $true;$v2=a $u $t $w;if($v2.Success){return [pscustomobject]@{Success=$true;ProxyUri=$e.ProxyUri;ProxyCredential=$null;UseDefaultProxyCredentials=$true;StatusCode=$v2.StatusCode}}}}catch{};fs $e.ProxyUri $e.ProxyCredential $false $null};function lo([uri]$p,[int]$ms=400){$h=$p.Host;if(@('127.0.0.1','localhost','::1') -notcontains $h){return $false};$c=$null;try{$c=[Net.Sockets.TcpClient]::new();$a0=$c.BeginConnect($h,$p.Port,$null,$null);if(!$a0.AsyncWaitHandle.WaitOne($ms,$false)){return $false};[void]$c.EndConnect($a0);$c.Connected}catch{$false}finally{if($c){$c.Close()}}};function tl([uri]$u,[int]$t){foreach($p in (lc)){if(!(lo $p)){continue};try{$v=a $u $t (wp $p);if($v.Success){return [pscustomobject]@{Success=$true;ProxyUri=$p;StatusCode=$v.StatusCode}}}catch{}};fs};function vp($x,[uri]$u,[int]$t){$m=[string]$x.Mode;switch($m){'Direct'{$v=a $u $t (ep);if($v.Success){return (td)};return (fd0)}'EnvironmentProxy'{if(!$x.ProxyUri){return (fd0)};$pc=$null;if($x.ProxyCredential -is [pscredential]){$pc=[pscredential]$x.ProxyCredential}elseif($null -ne $x.ProxyUserName){try{$pc=[pscredential]::new([string]$x.ProxyUserName,(ConvertTo-SecureString ([string]$x.ProxyPassword) -AsPlainText -Force))}catch{$pc=$null}};try{$p=[uri][string]$x.ProxyUri;if(!(wpr $p)){return (fd0)};$v=a $u $t (wp $p $pc ([bool]$x.UseDefaultProxyCredentials -and !$pc));if($v.Success){return (td)}}catch{};return (fd0)}'LocalRelayProxy'{if(!$x.ProxyUri){return (fd0)};try{$p=[uri][string]$x.ProxyUri}catch{return (fd0)};if(!(lo $p)){return (fd0)};try{$v=a $u $t (wp $p);if($v.Success){return (td)}}catch{};return (fd0)}'SystemProxyDefaultCredentials'{try{$w=swp;$p=$w.GetProxy($u);if($w.IsBypassed($u) -or !$p -or $p.AbsoluteUri -eq $u.AbsoluteUri){return (fd0)};$w.Credentials=$dc;$v=a $u $t $w;if($v.Success){return (td)}}catch{};return (fd0)}'ManualProxy'{if(!$x.ProxyUri){return (fd0)};if(!($x.ProxyCredential -is [pscredential])){return (fd0)};try{$p=[uri][string]$x.ProxyUri;if(!(wpr $p)){return (fd0)};$pc=[pscredential]$x.ProxyCredential;$v=a $u $t (wp $p $pc);if($v.Success){return (td)}}catch{};return (fd0)}default{return (fd0)}}};function me($d,$u=''){Add-Type -AssemblyName System.Windows.Forms,System.Drawing;[Windows.Forms.Application]::EnableVisualStyles();$f=New-Object Windows.Forms.Form -Property @{Text='Manual';StartPosition='CenterScreen';TopMost=$true;FormBorderStyle='FixedDialog';MaximizeBox=$false;MinimizeBox=$false;ClientSize=(sz 400 170);Font=(New-Object Drawing.Font 'Segoe UI',10)};function c($t,$p){$o=New-Object $t -Property $p;[void]$f.Controls.Add($o);$o};c Windows.Forms.Label @{Text='Proxy';Location=(pt 15 21);AutoSize=$true}|Out-Null;$tp=c Windows.Forms.TextBox @{Location=(pt 120 18);Size=(sz 260 23);Text=$d};c Windows.Forms.Label @{Text='User';Location=(pt 15 55);AutoSize=$true}|Out-Null;$tu=c Windows.Forms.TextBox @{Location=(pt 120 52);Size=(sz 260 23);Text=$u};c Windows.Forms.Label @{Text='Pass';Location=(pt 15 89);AutoSize=$true}|Out-Null;$ts=c Windows.Forms.TextBox @{Location=(pt 120 86);Size=(sz 260 23);UseSystemPasswordChar=$true};$ok=c Windows.Forms.Button @{Text='OK';Location=(pt 224 124);Size=(sz 75 28);DialogResult=[Windows.Forms.DialogResult]::OK};$cn=c Windows.Forms.Button @{Text='Abort';Location=(pt 305 124);Size=(sz 75 28);DialogResult=[Windows.Forms.DialogResult]::Cancel};$f.AcceptButton=$ok;$f.CancelButton=$cn;if($f.ShowDialog() -ne [Windows.Forms.DialogResult]::OK){return $null};[pscustomobject]@{ProxyUri=[uri]$tp.Text;ProxyCredential=[pscredential]::new($tu.Text,(ConvertTo-SecureString $ts.Text -AsPlainText -Force))}};$cbk=cb;try{try{$t12=[Net.SecurityProtocolType]::Tls12;$cp=[Net.ServicePointManager]::SecurityProtocol;if(($cp -band $t12) -ne $t12){[Net.ServicePointManager]::SecurityProtocol=$cp -bor $t12}}catch{};ed $pf;$p0=xlp $pf;if($p0){$vv=vp $p0 $TestUri $TimeoutSec;if($vv.Success){z;ap $p0;return};dp $pf};z;$v=a $TestUri $TimeoutSec (ep);if($v.Success){rap (npf Direct $null $null $false);return};$e0=te $TestUri $TimeoutSec;if($e0.Success -and $e0.ProxyUri){rap (npf EnvironmentProxy $e0.ProxyUri $e0.ProxyCredential $e0.UseDefaultProxyCredentials);return};$l0=tl $TestUri $TimeoutSec;if($l0.Success -and $l0.ProxyUri){rap (npf LocalRelayProxy $l0.ProxyUri $null $false);return};$w=swp;$wu=$w.GetProxy($TestUri);if(!$w.IsBypassed($TestUri) -and $wu -and $wu.AbsoluteUri -ne $TestUri.AbsoluteUri){$w.Credentials=$dc;$v=a $TestUri $TimeoutSec $w;if($v.Success){rap (npf SystemProxyDefaultCredentials $wu $null $true);return}};if(-not [Environment]::UserInteractive){dp $pf;throw('man need '+$TestUri.AbsoluteUri)};try{$m0=me $DefManProxy $DefManUser}catch{$m0=$null};if($m0 -and (wpr $m0.ProxyUri)){$v=a $TestUri $TimeoutSec (wp $m0.ProxyUri $m0.ProxyCredential);if($v.Success){rap (npf ManualProxy $m0.ProxyUri $m0.ProxyCredential $false);return}};dp $pf;s NoResolvedProxyProfile}finally{}}

function Initialize-Bootstrap {param([AllowNull()][string]$c = $null,[AllowNull()][string[]]$i = $null,[string]$s = 'CurrentUser',[string]$g = 'PSGallery',[string]$u='https://www.powershellgallery.com/api/v2')if($null -eq $c){$c=''};if($null -eq $i){$i='PackageManagement','PowerShellGet','Eigenverft.Manifested.Sandbox'};$pp=@{};$pm=@{};$pr=$null;try{$pp=$Global:ProxyParamsInstallPackageProvider;$pm=$Global:ProxyParamsInstallModule;$pr=$Global:ProxyParamsPrepareSession}catch{};if($PSVersionTable.PSVersion.Major -ne 5){return};try{Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force}catch{};try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{};if($pr){$null=$pr.Invoke()}else{[Net.WebRequest]::DefaultWebProxy=[Net.WebRequest]::GetSystemWebProxy();if([Net.WebRequest]::DefaultWebProxy){[Net.WebRequest]::DefaultWebProxy.Credentials=[Net.CredentialCache]::DefaultNetworkCredentials}};if(-not('BootstrapperCertificateValidationHelper'-as[type])){Add-Type 'using System.Net.Security;using System.Security.Cryptography.X509Certificates;public static class BootstrapperCertificateValidationHelper{public static bool AcceptAll(object sender,X509Certificate certificate,X509Chain chain,SslPolicyErrors sslPolicyErrors){return true;}}'};if(-not($m=[BootstrapperCertificateValidationHelper].GetMethod('AcceptAll',[Reflection.BindingFlags]'Public,Static'))){throw 'Failed to resolve BootstrapperCertificateValidationHelper.AcceptAll.'};$prev=[Net.ServicePointManager]::ServerCertificateValidationCallback;try{[Net.ServicePointManager]::ServerCertificateValidationCallback=[Net.Security.RemoteCertificateValidationCallback]([Delegate]::CreateDelegate([Net.Security.RemoteCertificateValidationCallback],$m));$v=[version]'2.8.5.201';Install-PackageProvider NuGet -MinimumVersion $v -Scope $s -Force -ForceBootstrap @pp|Out-Null;try{Set-PSRepository $g -InstallationPolicy Trusted -ea Stop}catch{Register-PSRepository $g -SourceLocation $u -ScriptSourceLocation $u -InstallationPolicy Trusted -ea Stop};Find-Module $i -Repository $g|select Name,Version|?{-not(Get-Module -ListAvailable $_.Name|sort Version -desc|select -f 1|? Version -eq $_.Version)}|%{$p=@{RequiredVersion=$_.Version;Repository=$g;Scope=$s;Force=$true;AllowClobber=$true};if($pm){$pm.GetEnumerator()|%{$p[$_.Key]=$_.Value}};if((gcm Install-Module).Parameters.ContainsKey('SkipPublisherCheck')){$p['SkipPublisherCheck']=$true};Install-Module $_.Name @p;try{Remove-Module $_.Name -ea 0}catch{};Import-Module $_.Name -MinimumVersion $_.Version -Force}}finally{[Net.ServicePointManager]::ServerCertificateValidationCallback=$prev};$q=[char]34;$arg='/c start '+$q+$q+' powershell -NoExit -Command '+$q+$c+';'+$q;Start-Process cmd $arg;exit}
