@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Start-OpenBubblesDatabaseInspection.ps1"
if errorlevel 1 pause
endlocal
