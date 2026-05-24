<#
Default PSGallery bootstrapper variant for installing/importing Eigenverft.Manifested.Sandbox,
then opening a new Windows PowerShell console and invoking the default follow-up command.

Current defaults:

$i='PowerShellGet','PackageManagement','Eigenverft.Manifested.Sandbox'
$c='Get-SandboxVersion'

Use via (Proxy-aware for corporate environments, skips TLS certificate validation):

$u='https://raw.githubusercontent.com/eigenverft/Eigenverft.Manifested.Sandbox/refs/heads/<branch>/iwr/bootstrapper.skipcert.ps1';try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{};try{[Net.ServicePointManager]::ServerCertificateValidationCallback={$true}}catch{};$p=[Net.WebRequest]::GetSystemWebProxy();if(-not $p.IsBypassed($u)){iwr $u -Proxy ($p.GetProxy($u).AbsoluteUri) -ProxyUseDefaultCredentials -UseBasicParsing|iex}else{iwr $u -UseBasicParsing|iex}

Use this variant only in Windows PowerShell 5.1 environments where TLS interception or
broken enterprise trust chains require bypassing certificate validation for the bootstrap
download and PSGallery install path. This is intentionally insecure.

This is the published bootstrapper entrypoint that skips TLS certificate validation.
For the standard bootstrapper, see iwr/bootstrapper.ps1.
For the configurable variant, see iwr/bootstrapper.sandbox.generic.ps1.

#>

$c='Get-SandboxVersion';$i='PackageManagement','PowerShellGet','Eigenverft.Manifested.Sandbox';$s='CurrentUser';$g='PSGallery';$u='https://www.powershellgallery.com/api/v2';if($PSVersionTable.PSVersion.Major -ne 5){return};try{Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force}catch{};try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{};[Net.WebRequest]::DefaultWebProxy=[Net.WebRequest]::GetSystemWebProxy();if([Net.WebRequest]::DefaultWebProxy){[Net.WebRequest]::DefaultWebProxy.Credentials=[Net.CredentialCache]::DefaultNetworkCredentials};if(-not('BootstrapperCertificateValidationHelper'-as[type])){Add-Type 'using System.Net.Security;using System.Security.Cryptography.X509Certificates;public static class BootstrapperCertificateValidationHelper{public static bool AcceptAll(object sender,X509Certificate certificate,X509Chain chain,SslPolicyErrors sslPolicyErrors){return true;}}'};if(-not($m=[BootstrapperCertificateValidationHelper].GetMethod('AcceptAll',[Reflection.BindingFlags]'Public,Static'))){throw 'Failed to resolve BootstrapperCertificateValidationHelper.AcceptAll.'};$prev=[Net.ServicePointManager]::ServerCertificateValidationCallback;try{[Net.ServicePointManager]::ServerCertificateValidationCallback=[Net.Security.RemoteCertificateValidationCallback]([Delegate]::CreateDelegate([Net.Security.RemoteCertificateValidationCallback],$m));$v=[version]'2.8.5.201';Install-PackageProvider NuGet -MinimumVersion $v -Scope $s -Force -ForceBootstrap|Out-Null;try{Set-PSRepository $g -InstallationPolicy Trusted -ea Stop}catch{Register-PSRepository $g -SourceLocation $u -ScriptSourceLocation $u -InstallationPolicy Trusted -ea Stop};Find-Module $i -Repository $g|select Name,Version|?{-not(Get-Module -ListAvailable $_.Name|sort Version -desc|select -f 1|? Version -eq $_.Version)}|%{$p=@{RequiredVersion=$_.Version;Repository=$g;Scope=$s;Force=$true;AllowClobber=$true};if((gcm Install-Module).Parameters.ContainsKey('SkipPublisherCheck')){$p['SkipPublisherCheck']=$true};Install-Module $_.Name @p;try{Remove-Module $_.Name -ea 0}catch{};Import-Module $_.Name -MinimumVersion $_.Version -Force}}finally{[Net.ServicePointManager]::ServerCertificateValidationCallback=$prev};Start-Process cmd "/c start `"`" powershell -NoExit -Command `"$c;`"";exit
