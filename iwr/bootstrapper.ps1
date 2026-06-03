<#
PSGallery bootstrapper for Windows PowerShell 5.1 when TLS interception or missing trust
roots block a normal Gallery install. Skips certificate validation for the bootstrap download
and install path only. Prefer Install-Module when trust works.

Optional before iex:
  $i = module names to install (default: PackageManagement, PowerShellGet, Eigenverft.Manifested.Package)
  $c = command to run in a new console after bootstrap (default: none)

Proxy-aware one-liner:

$u='https://raw.githubusercontent.com/eigenverft/Eigenverft.Manifested.Package/refs/heads/<branch>/iwr/bootstrapper.ps1';try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{};try{[Net.ServicePointManager]::ServerCertificateValidationCallback={$true}}catch{};$p=[Net.WebRequest]::GetSystemWebProxy();if($p){$p.Credentials=[Net.CredentialCache]::DefaultNetworkCredentials};$w=New-Object Net.WebClient;$w.Proxy=$p;try{$w.DownloadString($u)|iex}finally{$w.Dispose()}

Install, open a fresh console, and update the module:

$c='Update-PackageVersion -Scope CurrentUser';$u='https://raw.githubusercontent.com/eigenverft/Eigenverft.Manifested.Package/refs/heads/main/iwr/bootstrapper.ps1';try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{};try{[Net.ServicePointManager]::ServerCertificateValidationCallback={$true}}catch{};$p=[Net.WebRequest]::GetSystemWebProxy();if($p){$p.Credentials=[Net.CredentialCache]::DefaultNetworkCredentials};$w=New-Object Net.WebClient;$w.Proxy=$p;try{$w.DownloadString($u)|iex}finally{$w.Dispose()}

#>

if($null -eq $c){$c=''};if($null -eq $i){$i='PackageManagement','PowerShellGet','Eigenverft.Manifested.Package'};$s='CurrentUser';$g='PSGallery';$u='https://www.powershellgallery.com/api/v2';if($PSVersionTable.PSVersion.Major -ne 5){return};try{Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force}catch{};try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{};[Net.WebRequest]::DefaultWebProxy=[Net.WebRequest]::GetSystemWebProxy();if([Net.WebRequest]::DefaultWebProxy){[Net.WebRequest]::DefaultWebProxy.Credentials=[Net.CredentialCache]::DefaultNetworkCredentials};if(-not('BootstrapperCertificateValidationHelper'-as[type])){Add-Type 'using System.Net.Security;using System.Security.Cryptography.X509Certificates;public static class BootstrapperCertificateValidationHelper{public static bool AcceptAll(object sender,X509Certificate certificate,X509Chain chain,SslPolicyErrors sslPolicyErrors){return true;}}'};if(-not($m=[BootstrapperCertificateValidationHelper].GetMethod('AcceptAll',[Reflection.BindingFlags]'Public,Static'))){throw 'Failed to resolve BootstrapperCertificateValidationHelper.AcceptAll.'};$prev=[Net.ServicePointManager]::ServerCertificateValidationCallback;try{[Net.ServicePointManager]::ServerCertificateValidationCallback=[Net.Security.RemoteCertificateValidationCallback]([Delegate]::CreateDelegate([Net.Security.RemoteCertificateValidationCallback],$m));$v=[version]'2.8.5.201';Install-PackageProvider NuGet -MinimumVersion $v -Scope $s -Force -ForceBootstrap|Out-Null;try{Set-PSRepository $g -InstallationPolicy Trusted -ea Stop}catch{Register-PSRepository $g -SourceLocation $u -ScriptSourceLocation $u -InstallationPolicy Trusted -ea Stop};Find-Module $i -Repository $g|select Name,Version|?{-not(Get-Module -ListAvailable $_.Name|sort Version -desc|select -f 1|? Version -eq $_.Version)}|%{$p=@{RequiredVersion=$_.Version;Repository=$g;Scope=$s;Force=$true;AllowClobber=$true};if((gcm Install-Module).Parameters.ContainsKey('SkipPublisherCheck')){$p['SkipPublisherCheck']=$true};Install-Module $_.Name @p;try{Remove-Module $_.Name -ea 0}catch{};Import-Module $_.Name -MinimumVersion $_.Version -Force}}finally{[Net.ServicePointManager]::ServerCertificateValidationCallback=$prev};Start-Process cmd "/c start `"`" powershell -NoExit -Command `"$c;`"";exit
