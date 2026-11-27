@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar-Certificado-MCR.ps1"
set "result=%ERRORLEVEL%"
pause
exit /b %result%
