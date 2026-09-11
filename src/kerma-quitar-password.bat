@echo off
setlocal enabledelayedexpansion

:: =====================================================================
::  Kerma Games - Remove password + no-password auto-login
::
::  Run this ONCE on each table PC that is ALREADY set up (correct
::  username / hostname). Log in as the table account and run this
::  as Administrator. It will:
::    1) Blank the password of the current account
::    2) Enable auto-login so the PC boots straight to the desktop
::       after a power cut - with NO password stored anywhere
::    3) Delete the plain-text DefaultPassword left in the registry
::       by the previous auto-login setup, if there is one
::
::  NOTE: Windows blocks remote use (RDP / shared folders) of local
::  accounts with a blank password. Console login is not affected.
:: =====================================================================

fltmc >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [ERROR] This script must be run as Administrator.
    echo  Right-click the .bat file and choose "Run as administrator".
    echo.
    pause
    exit /b 1
)

set WINLOGON_KEY=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon

echo.
echo ===============================================
echo   KERMA GAMES - REMOVE PASSWORD / AUTO-LOGIN
echo ===============================================
echo.
echo   Computer : %COMPUTERNAME%
echo   Account  : %USERNAME%
echo.
echo   This will REMOVE the Windows password of %USERNAME%
echo   and make the PC boot straight to the desktop.
echo.
set /p CONFIRM="Proceed? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Nothing changed.
    pause
    exit /b 0
)

echo.
echo Removing password...
net user "%USERNAME%" ""
if !errorlevel! neq 0 (
    echo   [FAILED] Could not remove the password - see error above.
    echo   If it mentions a password policy, this PC has a local policy
    echo   requiring passwords - check secpol.msc or ask IT.
    pause
    exit /b 1
)
echo   [OK] Password removed for %USERNAME%.

echo.
echo Enabling no-password auto-login...
reg add "%WINLOGON_KEY%" /v AutoAdminLogon /t REG_SZ /d 1 /f >nul
reg add "%WINLOGON_KEY%" /v DefaultUserName /t REG_SZ /d "%USERNAME%" /f >nul
reg add "%WINLOGON_KEY%" /v DefaultDomainName /t REG_SZ /d "%COMPUTERNAME%" /f >nul
reg delete "%WINLOGON_KEY%" /v DefaultPassword /f >nul 2>&1
echo   [OK] Auto-login enabled - no password stored anywhere.
echo   [OK] Old stored password removed from the registry (if any).

echo.
echo ===============================================
echo   DONE - restart to test it boots straight in.
echo ===============================================
echo.
set /p DO_RESTART="Restart this PC now? (Y/N): "
if /i "%DO_RESTART%"=="Y" (
    echo Restarting in 10 seconds - abort with: shutdown /a
    shutdown /r /t 10
) else (
    echo Remember to restart later to test it.
    pause
)
