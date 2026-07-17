@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0Eigenverft.Manifested.Package.Bootstrap.ps1" %*
exit /b %ERRORLEVEL%
