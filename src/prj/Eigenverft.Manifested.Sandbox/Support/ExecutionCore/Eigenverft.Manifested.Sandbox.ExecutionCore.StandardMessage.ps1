<#
    Eigenverft.Manifested.Sandbox.ExecutionEngine.StandardMessage
#>

function Write-StandardMessage {
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

