@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Start-OpenBubblesGoogleRehearsal.ps1"
exit /b %ERRORLEVEL%
