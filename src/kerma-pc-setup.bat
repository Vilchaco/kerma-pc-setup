@echo off
setlocal enabledelayedexpansion

:: =====================================================================
::  Kerma Games - Full PC Setup Script
::  1) Select which table this PC is
::  2) Rename local username + computer name (hostname) + Full Name
::     to match the standard naming convention
::  3) Optionally set up auto-login (skip Windows password screen)
::  4) Choose which apps auto-start at logon, with optional maximize
::
::  MUST run as Administrator.
:: =====================================================================

echo.
echo ===============================================
echo   KERMA GAMES - PC SETUP
echo ===============================================
echo.
echo   Current computer name : %COMPUTERNAME%
echo   Current username      : %USERNAME%
echo.
echo ===============================================
echo   Select which table this PC belongs to:
echo ===============================================
echo   1. Roulette 01
echo   2. Blackjack 01
echo   3. Blackjack 02
echo   4. Blackjack 03
echo   5. Blackjack 04
echo   6. Blackjack Unlimited 01
echo   7. Craps 01
echo   8. Skip renaming (only set up autologin / apps)
echo.
set /p TABLE_CHOICE="Enter a number (1-8): "

if "%TABLE_CHOICE%"=="1" (
    set NEW_HOSTNAME=KG-TBL-RL-01
    set NEW_USERNAME=kg-tbl-rl-01
    set NEW_FULLNAME=Roulette Table 01
) else if "%TABLE_CHOICE%"=="2" (
    set NEW_HOSTNAME=KG-TBL-BJ-01
    set NEW_USERNAME=kg-tbl-bj-01
    set NEW_FULLNAME=Blackjack Table 01
) else if "%TABLE_CHOICE%"=="3" (
    set NEW_HOSTNAME=KG-TBL-BJ-02
    set NEW_USERNAME=kg-tbl-bj-02
    set NEW_FULLNAME=Blackjack Table 02
) else if "%TABLE_CHOICE%"=="4" (
    set NEW_HOSTNAME=KG-TBL-BJ-03
    set NEW_USERNAME=kg-tbl-bj-03
    set NEW_FULLNAME=Blackjack Table 03
) else if "%TABLE_CHOICE%"=="5" (
    set NEW_HOSTNAME=KG-TBL-BJ-04
    set NEW_USERNAME=kg-tbl-bj-04
    set NEW_FULLNAME=Blackjack Table 04
) else if "%TABLE_CHOICE%"=="6" (
    set NEW_HOSTNAME=KG-TBL-BJUNL-01
    set NEW_USERNAME=kg-tbl-bjunl-01
    set NEW_FULLNAME=Blackjack Unlimited 01
) else if "%TABLE_CHOICE%"=="7" (
    set NEW_HOSTNAME=KG-TBL-CR-01
    set NEW_USERNAME=kg-tbl-cr-01
    set NEW_FULLNAME=Craps Table 01
) else if "%TABLE_CHOICE%"=="8" (
    goto :skiprename
) else (
    echo Invalid choice. Exiting.
    pause
    exit /b 1
)

echo.
echo ===============================================
echo   About to apply:
echo     Computer name : %COMPUTERNAME%  -^>  !NEW_HOSTNAME!
echo     Username      : %USERNAME%  -^>  !NEW_USERNAME!
echo     Full Name     : -^>  !NEW_FULLNAME!
echo ===============================================
echo.
set /p CONFIRM_RENAME="Proceed with rename? (Y/N): "
if /i not "%CONFIRM_RENAME%"=="Y" goto :skiprename

echo.
echo Renaming local username first (safer order)...
powershell -NoProfile -Command "Rename-LocalUser -Name '%USERNAME%' -NewName '!NEW_USERNAME!'"
if !errorlevel! neq 0 (
    echo   [ERROR] Username rename failed. Check the error above.
    echo   Common cause: this account is currently in an elevated/locked
    echo   state, or the new name is already taken. You can also rename
    echo   it manually via lusrmgr.msc if this keeps failing.
    pause
) else (
    echo   [OK] Username renamed to !NEW_USERNAME!
)

echo.
echo Setting Full Name...
powershell -NoProfile -Command "Set-LocalUser -Name '!NEW_USERNAME!' -FullName '!NEW_FULLNAME!'"
if !errorlevel! neq 0 (
    echo   [ERROR] Full Name change failed. Not critical - continuing.
) else (
    echo   [OK] Full Name set to !NEW_FULLNAME!
)

echo.
echo Renaming computer name...
powershell -NoProfile -Command "Rename-Computer -NewName '!NEW_HOSTNAME!' -Force"
if !errorlevel! neq 0 (
    echo   [ERROR] Computer rename failed. Check the error above.
    pause
) else (
    echo   [OK] Computer renamed to !NEW_HOSTNAME! ^(needs a restart to take effect^)
)

echo.
echo ===============================================
echo   NOTE: Username/computer name changes need a
echo   restart to fully apply. Keep going for now -
echo   you can restart once at the very end.
echo ===============================================
echo.
pause

:skiprename

:: =====================================================================
::  AUTO-LOGIN SETUP (optional) - skip the Windows password screen
:: =====================================================================
echo.
echo ===============================================
echo   AUTO-LOGIN SETUP (optional)
echo ===============================================
echo.
echo   IMPORTANT: this stores the Windows password in
echo   PLAIN TEXT in the registry. This is how Windows
echo   auto-login works - there is no way around it,
echo   whether done here or manually via netplwiz.
echo.
set /p SETUP_AUTOLOGIN="Set up auto-login now (skip password screen)? (Y/N): "
if /i "!SETUP_AUTOLOGIN!"=="Y" (
    set AUTOLOGIN_USER=!NEW_USERNAME!
    if "!AUTOLOGIN_USER!"=="" set AUTOLOGIN_USER=%USERNAME%
    set /p WIN_PASSWORD="Enter the Windows password for !AUTOLOGIN_USER!: "
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 1 /f >nul
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d "!AUTOLOGIN_USER!" /f >nul
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /t REG_SZ /d "!WIN_PASSWORD!" /f >nul
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultDomainName /t REG_SZ /d "%COMPUTERNAME%" /f >nul
    if !errorlevel! equ 0 (
        echo   [OK] Auto-login configured for !AUTOLOGIN_USER!.
    ) else (
        echo   [FAILED] Could not write registry keys - check permissions.
    )
) else (
    echo   [SKIPPED] Auto-login not configured.
)
echo.

:: =====================================================================
::  PART 2 - APP AUTOSTART SETUP
:: =====================================================================
echo.
echo ===============================================
echo   APP AUTOSTART SETUP
echo ===============================================
echo.
echo   WARNING: if you go through this section and
echo   answer N to an app, it WILL DELETE that app's
echo   existing autostart task if one is already set up.
echo   Only continue if you actually want to review/
echo   change the app list right now.
echo.
set /p DO_APPS="Configure app autostart now? (Y/N): "
if /i not "!DO_APPS!"=="Y" (
    echo   [SKIPPED] App autostart section - existing tasks left untouched.
    echo.
    goto :end
)

:: ---- EDIT THESE PATHS FOR THIS TABLE ----
if "!NEW_HOSTNAME!"=="" (set TABLE_NAME=%COMPUTERNAME%) else (set TABLE_NAME=!NEW_HOSTNAME!)

set SCANNER_BAT=C:\Path\To\CardScanner.bat
set STREAMDECK_EXE=C:\Path\To\StreamDeckApp.exe
set DEALERAPP_EXE=C:\Path\To\DealerApp.exe
set MIRROR_EXE=C:\Path\To\MirrorApp.exe
set OBS_FOLDER=C:\Program Files\obs-studio\bin\64bit
set OBS_EXE=obs64.exe

set SCANNER_DELAY=10
set STREAMDECK_DELAY=15
set DEALERAPP_DELAY=30
set MIRROR_DELAY=45
set OBS_DELAY=60
:: -------------------------------------------

set SCRIPT_DIR=C:\KermaStartup\%TABLE_NAME%

echo.
echo ===============================================
echo   App Autostart Setup for %TABLE_NAME%
echo ===============================================
echo.
echo Answer Y or N for each app below.
echo.

if not exist "%SCRIPT_DIR%" mkdir "%SCRIPT_DIR%"

:: ============ CARD SCANNER ============
set /p ENABLE_SCANNER="Enable Card Scanner auto-start? (Y/N): "
if /i "%ENABLE_SCANNER%"=="Y" (
    set /p MAX_SCANNER="  -> Open maximized? (Y/N): "
    set STARTFLAG=
    if /i "!MAX_SCANNER!"=="Y" set STARTFLAG=/max
    (
        echo @echo off
        echo timeout /t %SCANNER_DELAY% /nobreak ^>nul
        echo start !STARTFLAG! "" "%SCANNER_BAT%"
    ) > "%SCRIPT_DIR%\01_scanner.bat"
    schtasks /create /tn "%TABLE_NAME% - Card Scanner Startup" /tr "\"%SCRIPT_DIR%\01_scanner.bat\"" /sc onlogon /rl highest /f
    if !errorlevel! equ 0 (echo   [OK] Card Scanner task created.) else (echo   [FAILED] Card Scanner task NOT created - see error above.)
) else (
    schtasks /delete /tn "%TABLE_NAME% - Card Scanner Startup" /f >nul 2>&1
    echo   [SKIPPED] Card Scanner.
)
echo.

:: ============ STREAM DECK ============
set /p ENABLE_SD="Enable StreamDeck App auto-start? (Y/N): "
if /i "%ENABLE_SD%"=="Y" (
    set /p MAX_SD="  -> Open maximized? (Y/N): "
    set STARTFLAG=
    if /i "!MAX_SD!"=="Y" set STARTFLAG=/max
    (
        echo @echo off
        echo timeout /t %STREAMDECK_DELAY% /nobreak ^>nul
        echo start !STARTFLAG! "" "%STREAMDECK_EXE%"
    ) > "%SCRIPT_DIR%\02_streamdeck.bat"
    schtasks /create /tn "%TABLE_NAME% - StreamDeck Startup" /tr "\"%SCRIPT_DIR%\02_streamdeck.bat\"" /sc onlogon /rl highest /f
    if !errorlevel! equ 0 (echo   [OK] StreamDeck task created.) else (echo   [FAILED] StreamDeck task NOT created - see error above.)
) else (
    schtasks /delete /tn "%TABLE_NAME% - StreamDeck Startup" /f >nul 2>&1
    echo   [SKIPPED] StreamDeck.
)
echo.

:: ============ DEALER APP ============
set /p ENABLE_DA="Enable Dealer App auto-start? (Y/N): "
if /i "%ENABLE_DA%"=="Y" (
    set /p MAX_DA="  -> Open maximized? (Y/N): "
    set STARTFLAG=
    if /i "!MAX_DA!"=="Y" set STARTFLAG=/max
    (
        echo @echo off
        echo timeout /t %DEALERAPP_DELAY% /nobreak ^>nul
        echo start !STARTFLAG! "" "%DEALERAPP_EXE%"
    ) > "%SCRIPT_DIR%\03_dealerapp.bat"
    schtasks /create /tn "%TABLE_NAME% - Dealer App Startup" /tr "\"%SCRIPT_DIR%\03_dealerapp.bat\"" /sc onlogon /rl highest /f
    if !errorlevel! equ 0 (echo   [OK] Dealer App task created.) else (echo   [FAILED] Dealer App task NOT created - see error above.)
) else (
    schtasks /delete /tn "%TABLE_NAME% - Dealer App Startup" /f >nul 2>&1
    echo   [SKIPPED] Dealer App.
)
echo.

:: ============ MIRROR APP ============
set /p ENABLE_MIRROR="Enable Mirror App auto-start? (Y/N): "
if /i "%ENABLE_MIRROR%"=="Y" (
    set /p MAX_MIRROR="  -> Open maximized? (Y/N): "
    set STARTFLAG=
    if /i "!MAX_MIRROR!"=="Y" set STARTFLAG=/max
    (
        echo @echo off
        echo timeout /t %MIRROR_DELAY% /nobreak ^>nul
        echo start !STARTFLAG! "" "%MIRROR_EXE%"
    ) > "%SCRIPT_DIR%\04_mirror.bat"
    schtasks /create /tn "%TABLE_NAME% - Mirror App Startup" /tr "\"%SCRIPT_DIR%\04_mirror.bat\"" /sc onlogon /rl highest /f
    if !errorlevel! equ 0 (echo   [OK] Mirror App task created.) else (echo   [FAILED] Mirror App task NOT created - see error above.)
) else (
    schtasks /delete /tn "%TABLE_NAME% - Mirror App Startup" /f >nul 2>&1
    echo   [SKIPPED] Mirror App.
)
echo.

:: ============ OBS ============
set /p ENABLE_OBS="Enable OBS auto-start? (Y/N): "
if /i "%ENABLE_OBS%"=="Y" (
    set /p MAX_OBS="  -> Open maximized? (Y/N): "
    set STARTFLAG=
    if /i "!MAX_OBS!"=="Y" set STARTFLAG=/max
    (
        echo @echo off
        echo timeout /t %OBS_DELAY% /nobreak ^>nul
        echo cd /d "%OBS_FOLDER%"
        echo start !STARTFLAG! "" "%OBS_EXE%"
    ) > "%SCRIPT_DIR%\05_obs.bat"
    schtasks /create /tn "%TABLE_NAME% - OBS Startup" /tr "\"%SCRIPT_DIR%\05_obs.bat\"" /sc onlogon /rl highest /f
    if !errorlevel! equ 0 (echo   [OK] OBS task created.) else (echo   [FAILED] OBS task NOT created - see error above.)
) else (
    schtasks /delete /tn "%TABLE_NAME% - OBS Startup" /f >nul 2>&1
    echo   [SKIPPED] OBS.
)
echo.

echo ===============================================
echo   ALL DONE for %TABLE_NAME%
echo ===============================================
echo.
echo Reminder:
echo  - RESTART the PC now so the username/computer
echo    name changes and auto-login fully apply, and
echo    to test that everything autostarts.
echo  - To make an app open on the correct monitor,
echo    move its window there by hand once - most apps
echo    (OBS included) remember that position on their own.
echo.
pause
goto :eof

:end
echo.
echo ===============================================
echo   Done. No app tasks were changed.
echo ===============================================
echo.
echo Restart the PC now if you changed the username,
echo computer name, or auto-login settings above.
echo.
pause
