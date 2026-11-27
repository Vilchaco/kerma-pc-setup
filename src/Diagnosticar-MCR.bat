@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Diagnosticar-MCR.ps1"
set "result=%ERRORLEVEL%"
pause
exit /b %result%
