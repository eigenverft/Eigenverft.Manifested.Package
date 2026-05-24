<#
Generic sandbox PSGallery bootstrapper for installing/importing configurable modules,
then opening a new Windows PowerShell console and invoking a configurable command.

Configure:

$i = modules to install and import
$c = command to invoke in the new console after bootstrap

Current defaults:

$i='PowerShellGet','PackageManagement','Eigenverft.Manifested.Sandbox'
$c=''

If $i or $c are already set before invocation, this script keeps those values.

Use via (Proxy-aware for corporate environments):

$u='https://raw.githubusercontent.com/eigenverft/Eigenverft.Manifested.Sandbox/refs/heads/<branch>/iwr/bootstrapper.sandbox.generic.ps1';try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{};$p=[System.Net.WebRequest]::GetSystemWebProxy();if(-not $p.IsBypassed($u)){iwr $u -Proxy ($p.GetProxy($u).AbsoluteUri) -ProxyUseDefaultCredentials -UseBasicParsing|iex}else{iwr $u -UseBasicParsing|iex}

This is the configurable variant of iwr/bootstrapper.ps1.
For the certificate-bypass variant, see iwr/bootstrapper.sandbox.generic.skipcert.ps1.
The published bootstrapper one-liner stays unchanged.

#>

if ($null -eq $c) { $c = '' }; if ($null -eq $i) { $i = 'PackageManagement','PowerShellGet','Eigenverft.Manifested.Sandbox' }; $s = 'CurrentUser'; $g = 'PSGallery'; $u = 'https://www.powershellgallery.com/api/v2'; if ($PSVersionTable.PSVersion.Major -ne 5) { return }; try { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force }catch {}; try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 }catch {}; [System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebRequest]::GetSystemWebProxy(); if ([System.Net.WebRequest]::DefaultWebProxy) { [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials }; $v = [version]'2.8.5.201'; Install-PackageProvider NuGet -MinimumVersion $v -Scope $s -Force -ForceBootstrap | Out-Null; try { Set-PSRepository $g -InstallationPolicy Trusted -ea Stop }catch { Register-PSRepository $g -SourceLocation $u -ScriptSourceLocation $u -InstallationPolicy Trusted -ea Stop }; Find-Module $i -Repository $g | select Name, Version | ? { -not(Get-Module -ListAvailable $_.Name | sort Version -desc | select -f 1 | ? Version -eq $_.Version) } | % { Install-Module $_.Name -RequiredVersion $_.Version -Repository $g -Scope $s -Force -AllowClobber; try { Remove-Module $_.Name -ea 0 }catch {}; Import-Module $_.Name -MinimumVersion $_.Version -Force }; Start-Process cmd "/c start `"`" powershell -NoExit -Command `"$c;`""; exit
