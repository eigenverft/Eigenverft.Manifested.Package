@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Eigenverft.Manifested.Package.Bootstrap.ps1" %*
exit /b %ERRORLEVEL%
