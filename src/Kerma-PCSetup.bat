@echo off
:: =====================================================================
::  Kerma Games - PC Setup launcher
::  Double-click this file. It runs Kerma-PCSetup.ps1 (must be in the
::  same folder). The script asks for administrator rights by itself.
::
::  Unattended examples (no questions):
::    Kerma-PCSetup.bat -PC RL01 -Unattended
::    Kerma-PCSetup.bat -PC HECTOR -Unattended -Restart
:: =====================================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Kerma-PCSetup.ps1" %*
