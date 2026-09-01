@echo off
setlocal
cd /d "%~dp0"
title GreenCursor Uninstaller
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1"
set "rc=%errorlevel%"
endlocal & exit /b %rc%
