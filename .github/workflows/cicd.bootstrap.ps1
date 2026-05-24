function Test-PSGalleryConnectivity {
<#
.SYNOPSIS
Fast connectivity test to PowerShell Gallery with HEAD->GET fallback.
.DESCRIPTION
Attempts a HEAD request to https://www.powershellgallery.com/api/v2/.
If the server returns 405 (Method Not Allowed), retries with GET.
Considers HTTP 200-399 as reachable. Writes status and returns $true/$false.
.EXAMPLE
Test-PSGalleryConnectivity
.OUTPUTS
System.Boolean
#>
    [CmdletBinding()]
    param()

    $url = 'https://www.powershellgallery.com/api/v2/'
    $timeoutMs = 5000

    function Invoke-WebCheck {
        param([string]$Method)

        try {
            $req = [System.Net.HttpWebRequest]::Create($url)
            $req.Method            = $Method
            $req.Timeout           = $timeoutMs
            $req.ReadWriteTimeout  = $timeoutMs
            $req.AllowAutoRedirect = $true
            $req.UserAgent         = 'WindowsPowerShell/5.1 PSGalleryConnectivityCheck'

            # NOTE: No proxy credential munging here - use system defaults.
            $res = $req.GetResponse()
            $status = [int]$res.StatusCode
            $res.Close()

            if ($status -ge 200 -and $status -lt 400) {
                Write-ConsoleLog -Level INF -Message "PSGallery reachable via $Method (HTTP $status)."
                return $true
            } else {
                Write-ConsoleLog -Level WRN -Message "Error: PSGallery returned HTTP $status on $Method."
                return $false
            }
        } catch [System.Net.WebException] {
            $wex = $_.Exception
            $resp = $wex.Response
            if ($resp -and $resp -is [System.Net.HttpWebResponse]) {
                $status = [int]$resp.StatusCode
                $resp.Close()
                if ($status -eq 405 -and $Method -eq 'HEAD') {
                    # Fallback handled by caller
                    return $null
                }
                Write-ConsoleLog -Level WRN -Message "Error: PSGallery $Method failed (HTTP $status): $($wex.Message)"
                return $false
            } else {
                Write-ConsoleLog -Level WRN -Message "Error: PSGallery $Method failed: $($wex.Message)"
                return $false
            }
        } catch {
            Write-ConsoleLog -Level WRN -Message "Error: PSGallery $Method failed: $($_.Exception.Message)"
            return $false
        }
    }

    # Try HEAD first for speed; if 405, fall back to GET.
    $headResult = Invoke-WebCheck -Method 'HEAD'
    if ($headResult -eq $true) { return $true }
    if ($null -eq $headResult) {
        # 405 from HEAD -> retry with GET
        $getResult = Invoke-WebCheck -Method 'GET'
        return [bool]$getResult
    }

    return $false
}

function Test-GitHubConnectivity {
<#
.SYNOPSIS
    Tests connectivity to the GitHub REST API by issuing a documented GET request.

.DESCRIPTION
    Sends a GET request to https://api.github.com/rate_limit.
    This avoids the unreliable HEAD probe behavior previously used against the same endpoint.

    The function:
    - Enforces TLS 1.2 for Windows PowerShell 5.1 for the duration of the call.
    - Sends the required User-Agent header.
    - Sends Accept: application/vnd.github+json.
    - Sends X-GitHub-Api-Version: 2022-11-28.
    - Treats HTTP 200-399 as reachable.
    - Logs clear diagnostics for API-level failures and transport-level failures.

.EXAMPLE
    Test-GitHubConnectivity

.OUTPUTS
    System.Boolean
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $url = 'https://api.github.com/rate_limit'
    $timeoutMs = 5000

    # Preserve the caller's TLS configuration and add TLS 1.2 for this probe.
    $origTls = [System.Net.ServicePointManager]::SecurityProtocol

    try {
        [System.Net.ServicePointManager]::SecurityProtocol = $origTls -bor [System.Net.SecurityProtocolType]::Tls12

        try {
            # Use the documented GitHub REST endpoint instead of HEAD probing.
            $req = [System.Net.HttpWebRequest]::CreateHttp($url)
            $req.Method = 'GET'
            $req.Timeout = $timeoutMs
            $req.ReadWriteTimeout = $timeoutMs
            $req.AllowAutoRedirect = $true
            $req.UserAgent = 'WindowsPowerShell/5.1 GitHubConnectivityCheck'
            $req.Accept = 'application/vnd.github+json'
            $req.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
            $req.Headers['X-GitHub-Api-Version'] = '2022-11-28'

            # Keep proxy behavior aligned with system defaults; do not inject proxy credentials here.
            $res = [System.Net.HttpWebResponse]$req.GetResponse()

            try {
                $status = [int]$res.StatusCode

                if ($status -ge 200 -and $status -lt 400) {
                    Write-ConsoleLog -Level INF -Message "GitHub API reachable via GET /rate_limit (HTTP $status)."
                    return $true
                }

                Write-ConsoleLog -Level WRN -Message "Error: GitHub API returned unexpected HTTP $status on GET /rate_limit."
                return $false
            }
            finally {
                if ($null -ne $res) {
                    $res.Close()
                }
            }
        }
        catch [System.Net.WebException] {
            $wex = $_.Exception
            $resp = $wex.Response

            if ($resp -and $resp -is [System.Net.HttpWebResponse]) {
                try {
                    $status = [int]$resp.StatusCode

                    switch ($status) {
                        401 {
                            Write-ConsoleLog -Level WRN -Message "Error: GitHub API is reachable, but GET /rate_limit returned HTTP 401 (unauthorized)."
                            break
                        }
                        403 {
                            Write-ConsoleLog -Level WRN -Message "Error: GitHub API is reachable, but GET /rate_limit returned HTTP 403 (forbidden or rate-limited)."
                            break
                        }
                        404 {
                            Write-ConsoleLog -Level WRN -Message "Error: GitHub API GET /rate_limit returned HTTP 404. This is unexpected for the documented endpoint and can indicate proxy interception, content filtering, or an upstream rewrite."
                            break
                        }
                        429 {
                            Write-ConsoleLog -Level WRN -Message "Error: GitHub API is reachable, but GET /rate_limit returned HTTP 429 (too many requests)."
                            break
                        }
                        default {
                            Write-ConsoleLog -Level WRN -Message "Error: GitHub API GET /rate_limit failed (HTTP $status): $($wex.Message)"
                            break
                        }
                    }

                    return $false
                }
                finally {
                    $resp.Close()
                }
            }

            Write-ConsoleLog -Level WRN -Message "Error: GitHub API GET /rate_limit failed: $($wex.Message)"
            return $false
        }
        catch {
            Write-ConsoleLog -Level WRN -Message "Error: GitHub API probe failed: $($_.Exception.Message)"
            return $false
        }
    }
    finally {
        # Restore the caller's original TLS settings.
        [System.Net.ServicePointManager]::SecurityProtocol = $origTls
    }
}

function Test-RemoteResourcesAvailable {
<#
.SYNOPSIS
    Runs the existing PSGallery and GitHub connectivity checks and aggregates the result.

.DESCRIPTION
    Delegates to:
      - Test-PSGalleryConnectivity
      - Test-GitHubConnectivity
    Each dependency prints its own status. This wrapper returns a summary object or, with -Quiet, a single boolean.

.PARAMETER Quiet
    Return only a boolean (True iff both checks succeed).

.EXAMPLE
    Test-RemoteResourcesAvailable

.EXAMPLE
    Test-RemoteResourcesAvailable -Quiet

.OUTPUTS
    PSCustomObject (default) or System.Boolean (with -Quiet)
#>
    [CmdletBinding()]
    param(
        [switch]$Quiet
    )

    # Ensure the two dependency functions exist; if not, mark as failed and note it.
    $hasPSG = [bool](Get-Command -Name Test-PSGalleryConnectivity -CommandType Function -ErrorAction SilentlyContinue)
    $hasGH  = [bool](Get-Command -Name Test-GitHubConnectivity   -CommandType Function -ErrorAction SilentlyContinue)

    if (-not $hasPSG) { Write-Verbose "Dependency 'Test-PSGalleryConnectivity' not found in session." }
    if (-not $hasGH)  { Write-Verbose "Dependency 'Test-GitHubConnectivity' not found in session." }

    $psgOk = $false
    $ghOk  = $false

    if ($hasPSG) { $psgOk = [bool](Test-PSGalleryConnectivity) }
    if ($hasGH)  { $ghOk  = [bool](Test-GitHubConnectivity)   }

    $overall = $psgOk -and $ghOk

    if ($Quiet) {
        return $overall
    }

    [pscustomobject]@{
        PSGallery = $psgOk
        GitHub    = $ghOk
        Overall   = $overall
        Notes     = @(
            if (-not $hasPSG) { "Missing: Test-PSGalleryConnectivity" }
            if (-not $hasGH)  { "Missing: Test-GitHubConnectivity"   }
        ) -join '; '
    }
}

function Write-ConsoleLog {
    <#
    .SYNOPSIS
    Writes a standardized log message with level, timestamp, and caller context.

    .DESCRIPTION
    Formats and writes console messages with a severity level, including timestamp and caller file/line info.
    Uses an effective minimum log level from the MinLevel parameter or the global ConsoleLogMinLevel variable.
    For ERR/FTL messages and ErrorActionPreference 'Stop', an exception is thrown after writing.

    .PARAMETER Message
    The message text to write.

    .PARAMETER Level
    The severity level of the message. Valid: TRC, DBG, INF, WRN, ERR, FTL.

    .PARAMETER MinLevel
    The minimum severity level required to output a message. If omitted, ConsoleLogMinLevel or INF is used.

    .EXAMPLE
    Write-ConsoleLog -Message 'Initialization complete.' -Level INF

    Writes an informational message including timestamp, level, and caller context.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs","")]
    # This function is globally exempt from the GENERAL POWERSHELL REQUIREMENTS unless explicitly stated otherwise.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('TRC','DBG','INF','WRN','ERR','FTL')]
        [string]$Level = 'INF',

        [Parameter()]
        [ValidateSet('TRC','DBG','INF','WRN','ERR','FTL')]
        [string]$MinLevel
    )

    # Normalize null input defensively.
    if ($null -eq $Message) {
        $Message = [string]::Empty
    }

    # Severity mapping for gating.
    $sevMap = @{
        TRC = 0
        DBG = 1
        INF = 2
        WRN = 3
        ERR = 4
        FTL = 5
    }

    # Resolve effective minimum level (parameter > global var > default).
    if (-not $PSBoundParameters.ContainsKey('MinLevel')) {
        $gv = Get-Variable ConsoleLogMinLevel -Scope Global -ErrorAction SilentlyContinue
        $MinLevel = if ($gv -and $gv.Value -and -not [string]::IsNullOrEmpty([string]$gv.Value)) {
            [string]$gv.Value
        }
        else {
            'INF'
        }
    }

    $lvl = $Level.ToUpperInvariant()
    $min = $MinLevel.ToUpperInvariant()

    $sev = $sevMap[$lvl]
    if ($null -eq $sev) {
        $lvl = 'INF'
        $sev = $sevMap['INF']
    }

    $gate = $sevMap[$min]
    if ($null -eq $gate) {
        $min = 'INF'
        $gate = $sevMap['INF']
    }

    # If configuration demands a higher error-level minimum, align upward.
    if ($sev -ge 4 -and $sev -lt $gate -and $gate -ge 4) {
        $lvl = $min
        $sev = $gate
    }

    # Below threshold: do nothing.
    if ($sev -lt $gate) {
        return
    }

    $ts = [DateTime]::UtcNow.ToString('yy-MM-dd HH:mm:ss.ff')

    # Caller resolution: first frame that is not this function.
    $helperName = $MyInvocation.MyCommand.Name
    $stack      = Get-PSCallStack
    $caller     = $null

    if ($stack) {
        foreach ($frame in $stack) {
            if ($frame.FunctionName -and $frame.FunctionName -ne $helperName) {
                $caller = $frame
                break
            }
        }
    }

    if (-not $caller) {
        # Fallback when called from script/host directly.
        $caller = [pscustomobject]@{
            ScriptName   = $PSCommandPath
            FunctionName = $null
        }
    }

    # Try multiple strategies to get a line number from the caller metadata.
    $lineNumber = $null

    $p = $caller.PSObject.Properties['ScriptLineNumber']
    if ($p -and $p.Value) {
        $lineNumber = [string]$p.Value
    }

    if (-not $lineNumber) {
        $p = $caller.PSObject.Properties['Position']
        if ($p -and $p.Value) {
            $sp = $p.Value.PSObject.Properties['StartLineNumber']
            if ($sp -and $sp.Value) {
                $lineNumber = [string]$sp.Value
            }
        }
    }

    if (-not $lineNumber) {
        $p = $caller.PSObject.Properties['Location']
        if ($p -and $p.Value) {
            $m = [regex]::Match([string]$p.Value, ':(\d+)\s+char:', 'IgnoreCase')
            if ($m.Success -and $m.Groups.Count -gt 1) {
                $lineNumber = $m.Groups[1].Value
            }
        }
    }

    $file = if ($caller.ScriptName) { Split-Path -Leaf $caller.ScriptName } else { 'cmd' }

    if ($file -ne 'console' -and $lineNumber) {
        $file = '{0}:{1}' -f $file, $lineNumber
    }

    $prefix = "[$ts "
    $suffix = "] [$file] $Message"

    # Level-to-color configuration.
    $cfg = @{
        TRC = @{ Fore = 'DarkGray'; Back = $null     }
        DBG = @{ Fore = 'Cyan';     Back = $null     }
        INF = @{ Fore = 'Green';    Back = $null     }
        WRN = @{ Fore = 'Yellow';   Back = $null     }
        ERR = @{ Fore = 'Red';      Back = $null     }
        FTL = @{ Fore = 'Red';      Back = 'DarkRed' }
    }[$lvl]

    $fore = $cfg.Fore
    $back = $cfg.Back

    $isInteractive = [System.Environment]::UserInteractive

    if ($isInteractive -and ($fore -or $back)) {
        Write-Host -NoNewline $prefix

        if ($fore -and $back) {
            Write-Host -NoNewline $lvl -ForegroundColor $fore -BackgroundColor $back
        }
        elseif ($fore) {
            Write-Host -NoNewline $lvl -ForegroundColor $fore
        }
        elseif ($back) {
            Write-Host -NoNewline $lvl -BackgroundColor $back
        }

        Write-Host $suffix
    }
    else {
        Write-Host "$prefix$lvl$suffix"
    }

    # For high severities with strict error handling, escalate via exception.
    if ($sev -ge 4 -and $ErrorActionPreference -eq 'Stop') {
        throw ("ConsoleLog.{0}: {1}" -f $lvl, $Message)
    }
}

function Update-ModuleIfNeeded {
<#
.SYNOPSIS
Installs or updates a module only when a newer applicable version is available.

.DESCRIPTION
Determines installation scope based on elevation (Windows):
- Elevated session -> AllUsers
- Otherwise        -> CurrentUser

Uses PowerShellGet cmdlets (Find-Module, Get-InstalledModule, Install-Module) to
compare the latest gallery version with the highest installed version
(prerelease-aware) and installs/updates only when strictly newer.

AllowPrerelease (string: 'true' or 'false', default 'true'):

When 'true':
- Requires that Find-Module, Get-InstalledModule, and Install-Module support
  -AllowPrerelease.
- Considers the highest gallery version including prerelease.
- Updates only when the gallery version is strictly newer than the highest
  installed version (stable or prerelease).
- Does not replace a stable release with a prerelease of the same base version.

When 'false':
- Uses only stable versions from the gallery.
- Compares the latest stable against the highest installed (stable or prerelease):
  - Higher base version wins.
  - For equal base, stable is preferred over prerelease.
- Updates prerelease to stable when an equal-or-newer stable exists.
- Never downgrades from a newer prerelease to an older stable.

AllowClobber:
- Not exposed as a parameter.
- If Install-Module supports -AllowClobber, it is enabled by default for all
  install/update operations.

.PARAMETER ModuleName
The name of the module to install or update.

.PARAMETER Repository
The repository to query for the module. Defaults to PSGallery.

.PARAMETER AllowPrerelease
Controls whether prerelease versions are considered.
ValidateSet 'true','false'. Defaults to 'true'.

.EXAMPLE
Update-ModuleIfNeeded -ModuleName 'STROM.NANO.PSWH.CICD'

Uses prerelease-aware mode (if supported) to install or update only when a newer
version is available.

.EXAMPLE
Update-ModuleIfNeeded -ModuleName 'Pester' -AllowPrerelease 'false'

Uses stable-only policy. Updates only when a newer stable exists. If only
prerelease is available, no change is made.
#>
    [CmdletBinding()]
    [Alias('umn','Update-ModuleIfNewer')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Repository = 'PSGallery',

        [Parameter()]
        [ValidateSet('true','false')]
        [string]$AllowPrerelease = 'true'
    )

    function local:_Write-StandardMessage {
        [Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs","")]
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)][string]$Message,
            [Parameter()][ValidateSet('TRC','DBG','INF','WRN','ERR','FTL')][string]$Level='INF',
            [Parameter()][ValidateSet('TRC','DBG','INF','WRN','ERR','FTL')][string]$MinLevel
        )

        if ($null -eq $Message) {
            $Message = [string]::Empty
        }

        $sevMap = @{TRC=0;DBG=1;INF=2;WRN=3;ERR=4;FTL=5}

        if (-not $PSBoundParameters.ContainsKey('MinLevel')) {
            $gv = Get-Variable ConsoleLogMinLevel -Scope Global -ErrorAction SilentlyContinue
            if ($gv -and $gv.Value -and -not [string]::IsNullOrEmpty([string]$gv.Value)) {
                $MinLevel = [string]$gv.Value
            }
            else {
                $MinLevel = 'INF'
            }
        }

        $lvl = $Level.ToUpperInvariant()
        $min = $MinLevel.ToUpperInvariant()

        $sev = $sevMap[$lvl]
        if ($null -eq $sev) {
            $lvl = 'INF'
            $sev = $sevMap['INF']
        }

        $gate = $sevMap[$min]
        if ($null -eq $gate) {
            $min = 'INF'
            $gate = $sevMap['INF']
        }

        if ($sev -ge 4 -and $sev -lt $gate -and $gate -ge 4) {
            $lvl = $min
            $sev = $gate
        }

        if ($sev -lt $gate) {
            return
        }

        $ts = [DateTime]::UtcNow.ToString('yy-MM-dd HH:mm:ss.ff')
        $stack = Get-PSCallStack
        $helperName = $MyInvocation.MyCommand.Name
        $helperScript = $MyInvocation.MyCommand.ScriptBlock.File
        $caller = $null

        if ($stack) {
            for ($i = 0; $i -lt $stack.Count; $i++) {
                $f  = $stack[$i]
                $fn = $f.FunctionName
                $sn = $f.ScriptName
                if ($fn -and $fn -ne $helperName -and -not $fn.StartsWith('_') -and `
                    (-not $helperScript -or -not $sn -or $sn -ne $helperScript)) {
                    $caller = $f
                    break
                }
            }

            if (-not $caller) {
                for ($i = 0; $i -lt $stack.Count; $i++) {
                    $f  = $stack[$i]
                    $fn = $f.FunctionName
                    if ($fn -and $fn -ne $helperName -and -not $fn.StartsWith('_')) {
                        $caller = $f
                        break
                    }
                }
            }

            if (-not $caller) {
                for ($i = 0; $i -lt $stack.Count; $i++) {
                    $f  = $stack[$i]
                    $fn = $f.FunctionName
                    $sn = $f.ScriptName
                    if ($fn -and $fn -ne $helperName -and `
                        (-not $helperScript -or -not $sn -or $sn -ne $helperScript)) {
                        $caller = $f
                        break
                    }
                }
            }

            if (-not $caller) {
                for ($i = 0; $i -lt $stack.Count; $i++) {
                    $f  = $stack[$i]
                    $fn = $f.FunctionName
                    if ($fn -and $fn -ne $helperName) {
                        $caller = $f
                        break
                    }
                }
            }
        }

        if (-not $caller) {
            $caller = [pscustomobject]@{
                ScriptName   = $PSCommandPath
                FunctionName = $null
            }
        }

        $lineNumber = $null
        $p = $caller.PSObject.Properties['ScriptLineNumber']
        if ($p -and $p.Value) {
            $lineNumber = [string]$p.Value
        }

        if (-not $lineNumber) {
            $p = $caller.PSObject.Properties['Position']
            if ($p -and $p.Value) {
                $sp = $p.Value.PSObject.Properties['StartLineNumber']
                if ($sp -and $sp.Value) {
                    $lineNumber = [string]$sp.Value
                }
            }
        }

        if (-not $lineNumber) {
            $p = $caller.PSObject.Properties['Location']
            if ($p -and $p.Value) {
                $m = [regex]::Match([string]$p.Value,':(\d+)\s+char:','IgnoreCase')
                if ($m.Success -and $m.Groups.Count -gt 1) {
                    $lineNumber = $m.Groups[1].Value
                }
            }
        }

        $file = if ($caller.ScriptName) { Split-Path -Leaf $caller.ScriptName } else { 'cmd' }
        if ($file -ne 'console' -and $lineNumber) {
            $file = '{0}:{1}' -f $file, $lineNumber
        }

        $prefix = "[$ts "
        $suffix = "] [$file] $Message"

        $cfg = @{
            TRC = @{Fore='DarkGray';Back=$null}
            DBG = @{Fore='Cyan'   ;Back=$null}
            INF = @{Fore='Green'  ;Back=$null}
            WRN = @{Fore='Yellow' ;Back=$null}
            ERR = @{Fore='Red'    ;Back=$null}
            FTL = @{Fore='Red'    ;Back='DarkRed'}
        }[$lvl]

        $fore = $cfg.Fore
        $back = $cfg.Back

        $isInteractive = [System.Environment]::UserInteractive

        if ($isInteractive -and ($fore -or $back)) {
            Write-Host -NoNewline $prefix
            if ($fore -and $back) {
                Write-Host -NoNewline $lvl -ForegroundColor $fore -BackgroundColor $back
            }
            elseif ($fore) {
                Write-Host -NoNewline $lvl -ForegroundColor $fore
            }
            elseif ($back) {
                Write-Host -NoNewline $lvl -BackgroundColor $back
            }
            Write-Host $suffix
        }
        else {
            Write-Host "$prefix$lvl$suffix"
        }

        if ($sev -ge 4 -and $ErrorActionPreference -eq 'Stop') {
            throw ("ConsoleLog.{0}: {1}" -f $lvl, $Message)
        }
    }

    function _Get-VersionInfo {
        [Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs","")]
        param(
            [Parameter(Mandatory = $true)]
            $Module
        )

        if ($null -eq $Module -or -not $Module.PSObject.Properties['Version']) {
            return $null
        }

        $raw = [string]$Module.Version
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }

        $isPre = $false
        $label = $null

        $baseText = $raw
        $dashIndex = $raw.IndexOf('-')
        if ($dashIndex -ge 0) {
            $baseText = $raw.Substring(0, $dashIndex)
            if ($raw.Length -gt ($dashIndex + 1)) {
                $label = $raw.Substring($dashIndex + 1)
            }
            $isPre = $true
        }

        try {
            $baseVersion = [version]$baseText
        }
        catch {
            return $null
        }

        if ($Module.PSObject.Properties['IsPrerelease'] -and $Module.IsPrerelease) {
            $isPre = $true
        }
        elseif ($Module.PSObject.Properties['Prerelease'] -and $Module.Prerelease) {
            $isPre = $true
            if (-not $label) {
                $label = [string]$Module.Prerelease
            }
        }
        elseif ($Module.PSObject.Properties['PrivateData'] -and
                $Module.PrivateData -and
                $Module.PrivateData.PSObject.Properties['PSData'] -and
                $Module.PrivateData.PSData.PSObject.Properties['Prerelease'] -and
                $Module.PrivateData.PSData.Prerelease) {
            $isPre = $true
            if (-not $label) {
                $label = [string]$Module.PrivateData.PSData.Prerelease
            }
        }

        [pscustomobject]@{
            Version      = $baseVersion
            IsPrerelease = $isPre
            Label        = $label
        }
    }

    function _Compare-VersionInfo {
        [Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs","")]
        param(
            [Parameter(Mandatory = $true)]
            $A,
            [Parameter(Mandatory = $true)]
            $B
        )

        if ($null -eq $A -and $null -eq $B) { return 0 }
        if ($null -eq $A) { return -1 }
        if ($null -eq $B) { return 1 }

        if ($A.Version -gt $B.Version) { return 1 }
        if ($A.Version -lt $B.Version) { return -1 }

        if ($A.IsPrerelease -eq $B.IsPrerelease) {
            if ([string]::IsNullOrEmpty($A.Label) -and [string]::IsNullOrEmpty($B.Label)) {
                return 0
            }
            return [string]::Compare($A.Label, $B.Label, $true)
        }

        if (-not $A.IsPrerelease -and $B.IsPrerelease) { return 1 }
        return -1
    }

    function _Invoke-InstallModule {
        [Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs","")]
        param(
            [Parameter(Mandatory = $true)][string]$Name,
            [Parameter(Mandatory = $true)][string]$Repository,
            [Parameter(Mandatory = $true)][string]$Scope,
            [Parameter(Mandatory = $true)][bool]$UsePrerelease,
            [Parameter(Mandatory = $true)][bool]$IsRemotePrerelease,
            [Parameter(Mandatory = $true)][System.Management.Automation.CommandInfo]$InstallCmd
        )

        $p = @{
            Name        = $Name
            Repository  = $Repository
            Scope       = $Scope
            Force       = $true
            ErrorAction = 'Stop'
        }

        if ($InstallCmd.Parameters.ContainsKey('AllowClobber')) {
            $p['AllowClobber'] = $true
        }

        if ($UsePrerelease -and $IsRemotePrerelease -and $InstallCmd.Parameters.ContainsKey('AllowPrerelease')) {
            $p['AllowPrerelease'] = $true
        }

        Install-Module @p
    }

    $usePrerelease = ($AllowPrerelease -eq 'true')

    $findCmd = Get-Command -Name 'Find-Module' -ErrorAction SilentlyContinue
    $getCmd  = Get-Command -Name 'Get-InstalledModule' -ErrorAction SilentlyContinue
    $instCmd = Get-Command -Name 'Install-Module' -ErrorAction SilentlyContinue

    if (-not $findCmd -or -not $getCmd -or -not $instCmd) {
        $msg = "Find-Module, Get-InstalledModule, and Install-Module are required (PowerShellGet). Ensure PowerShellGet is installed and imported."
        _Write-StandardMessage -Message $msg -Level 'ERR'
        throw $msg
    }

    if ($usePrerelease) {
        if (-not $findCmd.Parameters.ContainsKey('AllowPrerelease') -or
            -not $getCmd.Parameters.ContainsKey('AllowPrerelease') -or
            -not $instCmd.Parameters.ContainsKey('AllowPrerelease')) {
            $msg = "AllowPrerelease='true' requested, but installed PowerShellGet does not support -AllowPrerelease. Update PowerShellGet and retry."
            _Write-StandardMessage -Message $msg -Level 'ERR'
            throw $msg
        }
    }

    $getAllVersionsSupported = $getCmd.Parameters.ContainsKey('AllVersions')

    # Scope detection (inline Test-InstallationScopeCapability)
    $scope = 'CurrentUser'
    try {
        $onWindows = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
        if ($onWindows) {
            $id  = [Security.Principal.WindowsIdentity]::GetCurrent()
            $pri = [Security.Principal.WindowsPrincipal]$id
            if ($pri.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                $scope = 'AllUsers'
            }
        }
    }
    catch {
        $scope = 'CurrentUser'
    }

    # Remote module
    try {
        $findParams = @{
            Name        = $ModuleName
            Repository  = $Repository
            ErrorAction = 'Stop'
        }
        if ($usePrerelease) {
            $findParams['AllowPrerelease'] = $true
        }

        $remoteModule = Find-Module @findParams
    }
    catch {
        $msg = "Failed to query repository '$Repository' for '$ModuleName'. Details: $($_.Exception.Message)"
        _Write-StandardMessage -Message $msg -Level 'ERR'
        throw $msg
    }

    if ($null -eq $remoteModule) {
        $msg = "Module '$ModuleName' was not found in repository '$Repository'."
        _Write-StandardMessage -Message $msg -Level 'WRN'
        return
    }

    $remoteInfo = _Get-VersionInfo -Module $remoteModule
    if ($null -eq $remoteInfo) {
        $msg = "Module '$ModuleName' from '$Repository' does not expose a valid version."
        _Write-StandardMessage -Message $msg -Level 'ERR'
        throw $msg
    }

    # Local modules
    $localModules = $null
    try {
        $getParams = @{
            Name        = $ModuleName
            ErrorAction = 'SilentlyContinue'
        }
        if ($getAllVersionsSupported) {
            $getParams['AllVersions'] = $true
        }
        if ($usePrerelease) {
            $getParams['AllowPrerelease'] = $true
        }

        $localModules = Get-InstalledModule @getParams
    }
    catch {
        $localModules = $null
    }

    $localInfo = $null
    if ($localModules) {
        $items = @()
        foreach ($lm in $localModules) {
            $info = _Get-VersionInfo -Module $lm
            if ($info) {
                $items += $info
            }
        }

        if ($items.Count -gt 0) {
            $best = $items[0]
            for ($i = 1; $i -lt $items.Count; $i++) {
                if ( (_Compare-VersionInfo -A $items[$i] -B $best) -gt 0 ) {
                    $best = $items[$i]
                }
            }
            $localInfo = $best
        }
    }

    if ($null -eq $localInfo) {
        $msg = "Module '$ModuleName' is not installed. Installing $($remoteInfo.Version) (AllowPrerelease=$usePrerelease) with scope '$scope'."
        _Write-StandardMessage -Message $msg -Level 'INF'
        try {
            _Invoke-InstallModule -Name $ModuleName -Repository $Repository -Scope $scope -UsePrerelease $usePrerelease -IsRemotePrerelease $remoteInfo.IsPrerelease -InstallCmd $instCmd
        }
        catch {
            $msg = "Failed to install module '$ModuleName'. Details: $($_.Exception.Message)"
            _Write-StandardMessage -Message $msg -Level 'ERR'
            throw $msg
        }
        return
    }

    $cmp = _Compare-VersionInfo -A $remoteInfo -B $localInfo

    if ($usePrerelease) {
        if ($cmp -gt 0) {
            $msg = "Updating '$ModuleName' from $($localInfo.Version) to $($remoteInfo.Version) (prerelease-aware) with scope '$scope'."
            _Write-StandardMessage -Message $msg -Level 'INF'
            try {
                _Invoke-InstallModule -Name $ModuleName -Repository $Repository -Scope $scope -UsePrerelease $true -IsRemotePrerelease $remoteInfo.IsPrerelease -InstallCmd $instCmd
            }
            catch {
                $msg = "Failed to update '$ModuleName' to $($remoteInfo.Version). Details: $($_.Exception.Message)"
                _Write-StandardMessage -Message $msg -Level 'ERR'
                throw $msg
            }
        }
        else {
            $msg = "Module '$ModuleName' is up to date (installed: $($localInfo.Version), remote: $($remoteInfo.Version)). No action taken."
            _Write-StandardMessage -Message $msg -Level 'INF'
        }
    }
    else {
        if ($remoteInfo.IsPrerelease) {
            $msg = "Latest gallery version for '$ModuleName' is prerelease, but AllowPrerelease='false'. Skipping update. Installed: $($localInfo.Version), remote prerelease: $($remoteInfo.Version)."
            _Write-StandardMessage -Message $msg -Level 'INF'
            return
        }

        if ($cmp -gt 0) {
            $msg = "Updating '$ModuleName' from $($localInfo.Version) to stable $($remoteInfo.Version) with scope '$scope'."
            _Write-StandardMessage -Message $msg -Level 'INF'
            try {
                _Invoke-InstallModule -Name $ModuleName -Repository $Repository -Scope $scope -UsePrerelease $false -IsRemotePrerelease $false -InstallCmd $instCmd
            }
            catch {
                $msg = "Failed to update '$ModuleName' to stable $($remoteInfo.Version). Details: $($_.Exception.Message)"
                _Write-StandardMessage -Message $msg -Level 'ERR'
                throw $msg
            }
        }
        else {
            $msg = "Module '$ModuleName' is up to date for stable policy (installed: $($localInfo.Version), latest stable: $($remoteInfo.Version)). No action taken."
            _Write-StandardMessage -Message $msg -Level 'INF'
        }
    }
}

