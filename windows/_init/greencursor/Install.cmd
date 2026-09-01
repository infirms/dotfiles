@echo off
setlocal
cd /d "%~dp0"
title GreenCursor Installer
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"
set "rc=%errorlevel%"
endlocal & exit /b %rc%
