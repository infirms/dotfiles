@echo off
setlocal

set "TARGET_DISPLAY=\\.\DISPLAY2\Monitor0"
set "CONTROL_MY_MONITOR=%~dp0ControlMyMonitor.exe"

cd /d "%~dp0"

"%CONTROL_MY_MONITOR%" /SwitchValue "%TARGET_DISPLAY%" 60 15 17
exit /b %ERRORLEVEL%
