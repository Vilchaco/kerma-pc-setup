@echo off
setlocal enabledelayedexpansion

:: =====================================================================
::  Kerma Games - Full PC Setup Script  (v2.0.0)
::  1) Select which PC this is (table PCs, supervisor PCs, office PCs)
::  2) Optionally rename local username + computer name (hostname) +
::     Full Name to match the standard naming convention. Answer N to
::     keep the names and only do login / app autostart.
::  3) Login setup: remove the password entirely (recommended) or
::     store it for classic auto-login
::  4) Windows Update: manual-only / fully disabled / restore
::  5) Network: pick an adapter and give it a static IP (or DHCP)
::  6) Choose which apps auto-start at logon, with optional maximize
::
::  MUST run as Administrator (checked below).
::
::  v2.0.0 changes vs v1:
::   - Login section offers "no password at all" (blank password +
::     auto-login, nothing stored) as the default
::   - Admin check at startup
::   - PowerShell errors are now actually detected (try/catch + exit 1)
::   - Auto-login uses the NEW hostname (v1 wrote the old one, which
::     broke auto-login after the rename + restart)
::   - Re-running is safe: skips rename if names already correct
::   - Warns if an app path does not exist before creating its task
::   - App sections deduplicated into one subroutine (same task names)
:: =====================================================================

:: ---------------------------------------------------------------------
::  EDIT THESE PATHS / DELAYS FOR YOUR APPS
:: ---------------------------------------------------------------------
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

:: Office PC (Hector's office: cameras on the TV + Deskflow client
:: controlled from his Mac)
set DESKFLOW_EXE=C:\Program Files\Deskflow\deskflow.exe
set CAMERAS_EXE=C:\Path\To\CamerasApp.exe

set DESKFLOW_DELAY=10
set CAMERAS_DELAY=25
:: ---------------------------------------------------------------------

:: ---- Require Administrator ----
fltmc >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [ERROR] This script must be run as Administrator.
    echo  Right-click the .bat file and choose "Run as administrator".
    echo.
    pause
    exit /b 1
)

echo.
echo ===============================================
echo   KERMA GAMES - PC SETUP
echo ===============================================
echo.
echo   Current computer name : %COMPUTERNAME%
echo   Current username      : %USERNAME%
echo.
echo ===============================================
echo   Select which PC this is:
echo ===============================================
echo   --- Table PCs ---
echo   1. Roulette 01
echo   2. Blackjack 01
echo   3. Blackjack 02
echo   4. Blackjack 03
echo   5. Blackjack 04
echo   6. Blackjack Unlimited 01
echo   7. Craps 01
echo   --- Supervisor PCs ---
echo   8. Supervisor 01
echo   9. Supervisor 02
echo   --- Office PCs ---
echo  10. Hector office PC (cameras on TV + Deskflow)
echo.
set /p TABLE_CHOICE="Enter a number (1-10): "

if "%TABLE_CHOICE%"=="1" (
    set PC_TYPE=TABLE
    set NEW_HOSTNAME=KG-TBL-RL-01
    set NEW_USERNAME=kg-tbl-rl-01
    set NEW_FULLNAME=Roulette Table 01
) else if "%TABLE_CHOICE%"=="2" (
    set PC_TYPE=TABLE
    set NEW_HOSTNAME=KG-TBL-BJ-01
    set NEW_USERNAME=kg-tbl-bj-01
    set NEW_FULLNAME=Blackjack Table 01
) else if "%TABLE_CHOICE%"=="3" (
    set PC_TYPE=TABLE
    set NEW_HOSTNAME=KG-TBL-BJ-02
    set NEW_USERNAME=kg-tbl-bj-02
    set NEW_FULLNAME=Blackjack Table 02
) else if "%TABLE_CHOICE%"=="4" (
    set PC_TYPE=TABLE
    set NEW_HOSTNAME=KG-TBL-BJ-03
    set NEW_USERNAME=kg-tbl-bj-03
    set NEW_FULLNAME=Blackjack Table 03
) else if "%TABLE_CHOICE%"=="5" (
    set PC_TYPE=TABLE
    set NEW_HOSTNAME=KG-TBL-BJ-04
    set NEW_USERNAME=kg-tbl-bj-04
    set NEW_FULLNAME=Blackjack Table 04
) else if "%TABLE_CHOICE%"=="6" (
    set PC_TYPE=TABLE
    set NEW_HOSTNAME=KG-TBL-BJUNL-01
    set NEW_USERNAME=kg-tbl-bjunl-01
    set NEW_FULLNAME=Blackjack Unlimited 01
) else if "%TABLE_CHOICE%"=="7" (
    set PC_TYPE=TABLE
    set NEW_HOSTNAME=KG-TBL-CR-01
    set NEW_USERNAME=kg-tbl-cr-01
    set NEW_FULLNAME=Craps Table 01
) else if "%TABLE_CHOICE%"=="8" (
    set PC_TYPE=STAFF
    set NEW_HOSTNAME=KG-SUP-01
    set NEW_USERNAME=kg-sup-01
    set NEW_FULLNAME=Supervisor 01
) else if "%TABLE_CHOICE%"=="9" (
    set PC_TYPE=STAFF
    set NEW_HOSTNAME=KG-SUP-02
    set NEW_USERNAME=kg-sup-02
    set NEW_FULLNAME=Supervisor 02
) else if "%TABLE_CHOICE%"=="10" (
    set PC_TYPE=OFFICE
    set NEW_HOSTNAME=KG-OFC-HECTOR
    set NEW_USERNAME=kg-ofc-hector
    set NEW_FULLNAME=Hector Office PC
) else (
    echo Invalid choice. Exiting.
    pause
    exit /b 1
)

echo.
echo ===============================================
echo   Standard names for this PC:
echo     Computer name : %COMPUTERNAME%  -^>  !NEW_HOSTNAME!
echo     Username      : %USERNAME%  -^>  !NEW_USERNAME!
echo     Full Name     : -^>  !NEW_FULLNAME!
echo ===============================================
echo.
echo   Answer N to keep the current names and only set up
echo   login / app autostart for this PC.
set /p CONFIRM_RENAME="Rename this PC now? (Y/N): "
if /i not "%CONFIRM_RENAME%"=="Y" (
    echo   [SKIPPED] Names left as they are.
    goto :skiprename
)

:: ---- Rename local username (safer to do before the computer name) ----
echo.
if /i "%USERNAME%"=="!NEW_USERNAME!" (
    echo   [SKIP] Username is already !NEW_USERNAME!.
    set USER_RENAMED=1
    goto :fullname
)
echo Renaming local username...
set KG_OLDUSER=%USERNAME%
set KG_NEWUSER=!NEW_USERNAME!
powershell -NoProfile -Command "try { Rename-LocalUser -Name $env:KG_OLDUSER -NewName $env:KG_NEWUSER -ErrorAction Stop } catch { Write-Host ('  [ERROR] ' + $_.Exception.Message); exit 1 }"
if !errorlevel! neq 0 (
    echo   [ERROR] Username rename failed - see message above.
    echo   Common cause: the new name is already taken. You can also
    echo   rename it manually via lusrmgr.msc if this keeps failing.
    pause
) else (
    set USER_RENAMED=1
    echo   [OK] Username renamed to !NEW_USERNAME!
    echo   NOTE: the profile folder stays as C:\Users\%USERNAME% -
    echo   that is normal Windows behavior and safe to leave as-is.
)

:fullname
echo.
echo Setting Full Name...
set KG_NEWUSER=!NEW_USERNAME!
set KG_FULLNAME=!NEW_FULLNAME!
powershell -NoProfile -Command "try { Set-LocalUser -Name $env:KG_NEWUSER -FullName $env:KG_FULLNAME -ErrorAction Stop } catch { Write-Host ('  [ERROR] ' + $_.Exception.Message); exit 1 }"
if !errorlevel! neq 0 (
    echo   [ERROR] Full Name change failed. Not critical - continuing.
) else (
    echo   [OK] Full Name set to !NEW_FULLNAME!
)

:: ---- Rename computer ----
echo.
if /i "%COMPUTERNAME%"=="!NEW_HOSTNAME!" (
    echo   [SKIP] Computer name is already !NEW_HOSTNAME!.
    set HOST_RENAMED=1
    goto :renamedone
)
echo Renaming computer name...
set KG_NEWHOST=!NEW_HOSTNAME!
powershell -NoProfile -Command "try { Rename-Computer -NewName $env:KG_NEWHOST -Force -ErrorAction Stop } catch { Write-Host ('  [ERROR] ' + $_.Exception.Message); exit 1 }"
if !errorlevel! neq 0 (
    echo   [ERROR] Computer rename failed - see message above.
    pause
) else (
    set HOST_RENAMED=1
    echo   [OK] Computer renamed to !NEW_HOSTNAME! ^(needs a restart to take effect^)
)

:renamedone
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
::  LOGIN SETUP (optional) - boot straight to the desktop
:: =====================================================================
echo.
echo ===============================================
echo   LOGIN SETUP (optional)
echo ===============================================
echo.
echo   1. Remove the password entirely  (RECOMMENDED for table PCs)
echo      - the account gets a BLANK password and the PC boots
echo        straight to the desktop after any power cut.
echo        Nothing is stored anywhere.
echo      - NOTE: Windows blocks remote use ^(RDP, shared folders^)
echo        of local accounts with a blank password.
echo   2. Keep the password, store it for auto-login
echo      - the password is saved in the registry in PLAIN TEXT
echo        ^(same as netplwiz^). Use only if you need RDP into
echo        this account.
echo   3. Skip - leave login exactly as it is now.
echo.
if "!PC_TYPE!"=="STAFF" (
    echo   ^>^> This is a SUPERVISOR / STAFF PC. Option 1 is NOT
    echo   ^>^> recommended here: anyone could open it and read
    echo   ^>^> this person's email, files and the supervisor tools.
    echo   ^>^> Prefer 3 ^(keep a password^) unless told otherwise.
    echo.
)
set /p LOGIN_CHOICE="Enter a number (1-3): "

:: Use the new names only if the rename really happened (or the names
:: already matched); otherwise the account/machine still has the old
:: names. A stale DefaultDomainName silently breaks auto-login.
set AUTOLOGIN_USER=%USERNAME%
if "!USER_RENAMED!"=="1" set AUTOLOGIN_USER=!NEW_USERNAME!
set AUTOLOGIN_DOMAIN=%COMPUTERNAME%
if "!HOST_RENAMED!"=="1" set AUTOLOGIN_DOMAIN=!NEW_HOSTNAME!
set WINLOGON_KEY=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon

if "%LOGIN_CHOICE%"=="1" goto :login_nopass
if "%LOGIN_CHOICE%"=="2" goto :login_storedpass
echo   [SKIPPED] Login left unchanged.
goto :autologindone

:: ---- Option 1: blank password + auto-login, nothing stored ----
:login_nopass
echo.
set /p CONFIRM_NOPASS="Remove the Windows password for !AUTOLOGIN_USER!? (Y/N): "
if /i not "!CONFIRM_NOPASS!"=="Y" (
    echo   [SKIPPED] Login left unchanged.
    goto :autologindone
)
net user "!AUTOLOGIN_USER!" ""
if !errorlevel! neq 0 (
    echo   [FAILED] Could not remove the password - see error above.
    echo   If it mentions a password policy, check secpol.msc.
    pause
    goto :autologindone
)
echo   [OK] Password removed for !AUTOLOGIN_USER!.
reg add "%WINLOGON_KEY%" /v AutoAdminLogon /t REG_SZ /d 1 /f >nul
reg add "%WINLOGON_KEY%" /v DefaultUserName /t REG_SZ /d "!AUTOLOGIN_USER!" /f >nul
reg add "%WINLOGON_KEY%" /v DefaultDomainName /t REG_SZ /d "!AUTOLOGIN_DOMAIN!" /f >nul
reg delete "%WINLOGON_KEY%" /v DefaultPassword /f >nul 2>&1
echo   [OK] Auto-login enabled - no password stored anywhere.
goto :autologindone

:: ---- Option 2: keep password, store it for auto-login ----
:login_storedpass
:: The password is read hidden inside PowerShell so special characters
:: are never mangled by cmd's variable expansion and never shown on screen.
set KG_PS1=%TEMP%\kg_autologon.ps1
>  "%KG_PS1%" echo try {
>> "%KG_PS1%" echo   $u = $env:KG_AUTOUSER
>> "%KG_PS1%" echo   $d = $env:KG_AUTODOMAIN
>> "%KG_PS1%" echo   $sec = Read-Host -Prompt "Enter the Windows password for $u - input is hidden" -AsSecureString
>> "%KG_PS1%" echo   $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
>> "%KG_PS1%" echo   $p = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b)
>> "%KG_PS1%" echo   $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
>> "%KG_PS1%" echo   Set-ItemProperty -Path $k -Name AutoAdminLogon    -Value '1' -Type String
>> "%KG_PS1%" echo   Set-ItemProperty -Path $k -Name DefaultUserName   -Value $u  -Type String
>> "%KG_PS1%" echo   Set-ItemProperty -Path $k -Name DefaultPassword   -Value $p  -Type String
>> "%KG_PS1%" echo   Set-ItemProperty -Path $k -Name DefaultDomainName -Value $d  -Type String
>> "%KG_PS1%" echo } catch { Write-Host "ERROR: $_" ; exit 1 }

set KG_AUTOUSER=!AUTOLOGIN_USER!
set KG_AUTODOMAIN=!AUTOLOGIN_DOMAIN!
powershell -NoProfile -ExecutionPolicy Bypass -File "%KG_PS1%"
if !errorlevel! equ 0 (
    echo   [OK] Auto-login configured for !AUTOLOGIN_DOMAIN!\!AUTOLOGIN_USER!.
) else (
    echo   [FAILED] Could not configure auto-login - see error above.
)
del "%KG_PS1%" >nul 2>&1

:autologindone
echo.

:: =====================================================================
::  WINDOWS UPDATE (optional)
:: =====================================================================
set WIN_EDITION=unknown
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul ^| find "EditionID"') do set WIN_EDITION=%%a
echo.
echo ===============================================
echo   WINDOWS UPDATE (optional)   [edition: !WIN_EDITION!]
echo ===============================================
echo.
echo   1. Manual updates only  (RECOMMENDED for table / office PCs)
echo      - Windows never downloads, installs or reboots on its
echo        own, and stops pushing drivers through Windows Update.
echo        You still can install updates by hand in
echo        Settings ^> Windows Update during maintenance.
echo   2. Disable Windows Update completely
echo      - same as 1, plus the Windows Update service is stopped
echo        and disabled. No patches at all until you undo it.
echo   3. Restore automatic updates  (undo 1 or 2)
echo   4. Skip - leave Windows Update as it is now.
echo.
if "!PC_TYPE!"=="STAFF" (
    echo   ^>^> Supervisor PC: keep automatic updates ^(option 4^)
    echo   ^>^> unless there is a specific reason not to.
    echo.
)
if /i "!WIN_EDITION!"=="Core" (
    echo   ^>^> Windows HOME edition detected: Home does not fully
    echo   ^>^> honor the policy used by option 1. Option 2 is the
    echo   ^>^> reliable choice on Home.
    echo.
)
set /p WU_CHOICE="Enter a number (1-4): "
set WU_KEY=HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate

if "%WU_CHOICE%"=="1" goto :wu_manual
if "%WU_CHOICE%"=="2" goto :wu_disable
if "%WU_CHOICE%"=="3" goto :wu_restore
echo   [SKIPPED] Windows Update left unchanged.
goto :wu_done

:: ---- Option 1: manual only ----
:wu_manual
call :wu_apply_policy
sc config wuauserv start= demand >nul
echo   [OK] Windows Update set to MANUAL ONLY - no auto download,
echo        install, reboot or driver updates. Update by hand from
echo        Settings ^> Windows Update when convenient.
goto :wu_done

:: ---- Option 2: fully disabled ----
:wu_disable
call :wu_apply_policy
sc stop wuauserv >nul 2>&1
sc config wuauserv start= disabled >nul
echo   [OK] Windows Update DISABLED - policy applied and service
echo        stopped/disabled. Run this script again with option 3
echo        to bring updates back.
goto :wu_done

:: ---- Option 3: restore defaults ----
:wu_restore
reg delete "%WU_KEY%\AU" /v NoAutoUpdate /f >nul 2>&1
reg delete "%WU_KEY%\AU" /v NoAutoRebootWithLoggedOnUsers /f >nul 2>&1
reg delete "%WU_KEY%" /v ExcludeWUDriversInQualityUpdate /f >nul 2>&1
sc config wuauserv start= demand >nul
sc start wuauserv >nul 2>&1
echo   [OK] Automatic updates restored to Windows defaults.
goto :wu_done

:: ---- shared: policy keys used by options 1 and 2 ----
:wu_apply_policy
reg add "%WU_KEY%\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f >nul
reg add "%WU_KEY%\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f >nul
reg add "%WU_KEY%" /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f >nul
goto :eof

:wu_done
echo.

:: =====================================================================
::  NETWORK - STATIC IP (optional)
::  The interactive part is the PowerShell block at the very end of
::  this file (after the last goto :eof), extracted and run here so
::  the whole setup stays in one .bat.
:: =====================================================================
echo.
echo ===============================================
echo   NETWORK - STATIC IP (optional)
echo ===============================================
echo.
set /p DO_NET="Configure the network adapter / static IP now? (Y/N): "
if /i not "!DO_NET!"=="Y" (
    echo   [SKIPPED] Network left unchanged.
    goto :net_done
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText('%~f0'); $b=$s.LastIndexOf('#PS_NET_'+'BEGIN'); $e=$s.LastIndexOf('#PS_NET_'+'END'); Invoke-Expression $s.Substring($b, $e-$b)"
if !errorlevel! neq 0 (
    echo   [FAILED] Network configuration did not complete - see above.
    pause
)
:net_done
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
if "!PC_TYPE!"=="STAFF" (
    echo   [SKIPPED] App autostart does not apply to
    echo   supervisor PCs - nothing changed here.
    echo.
    goto :end
)
set /p DO_APPS="Configure app autostart now? (Y/N): "
if /i not "!DO_APPS!"=="Y" (
    echo   [SKIPPED] App autostart section - existing tasks left untouched.
    echo.
    goto :end
)

set TABLE_NAME=%COMPUTERNAME%
if "!HOST_RENAMED!"=="1" set TABLE_NAME=!NEW_HOSTNAME!
set SCRIPT_DIR=C:\KermaStartup\!TABLE_NAME!

echo.
echo ===============================================
echo   App Autostart Setup for !TABLE_NAME!
echo ===============================================
echo.
echo Answer Y or N for each app below.
echo.

if not exist "!SCRIPT_DIR!" mkdir "!SCRIPT_DIR!"

if "!PC_TYPE!"=="OFFICE" goto :apps_office

:: ---- Table PCs ----
::            display name     file id          delay                  target                       workdir (optional)
call :setup_app "Card Scanner" "01_scanner"    "%SCANNER_DELAY%"    "%SCANNER_BAT%"    ""
call :setup_app "StreamDeck"   "02_streamdeck" "%STREAMDECK_DELAY%" "%STREAMDECK_EXE%" ""
call :setup_app "Dealer App"   "03_dealerapp"  "%DEALERAPP_DELAY%"  "%DEALERAPP_EXE%"  ""
call :setup_app "Mirror App"   "04_mirror"     "%MIRROR_DELAY%"     "%MIRROR_EXE%"     ""
call :setup_app "OBS"          "05_obs"        "%OBS_DELAY%"        "%OBS_FOLDER%\%OBS_EXE%" "%OBS_FOLDER%"
goto :apps_done

:: ---- Office PC (cameras + Deskflow) ----
:apps_office
echo   NOTE on Deskflow: if "Start Deskflow on login" is already
echo   enabled inside Deskflow's own settings, answer N here so
echo   it is not launched twice.
echo.
call :setup_app "Deskflow" "01_deskflow" "%DESKFLOW_DELAY%" "%DESKFLOW_EXE%" ""
call :setup_app "Cameras"  "02_cameras"  "%CAMERAS_DELAY%"  "%CAMERAS_EXE%"  ""

:apps_done
echo ===============================================
echo   ALL DONE for !TABLE_NAME!
echo ===============================================
echo.
echo Reminder:
echo  - RESTART the PC now so the username/computer
echo    name changes and login settings fully apply,
echo    and to test that everything autostarts.
echo  - To make an app open on the correct monitor,
echo    move its window there by hand once - most apps
echo    (OBS included) remember that position on their own.
echo.
goto :restartprompt

:end
echo.
echo ===============================================
echo   Done. No app tasks were changed.
echo ===============================================
echo.
echo Restart the PC now if you changed the username,
echo computer name, login or Windows Update settings above.
echo (Network changes are already live - no restart needed.)
echo.

:restartprompt
set /p DO_RESTART="Restart this PC now? (Y/N): "
if /i "!DO_RESTART!"=="Y" (
    echo Restarting in 10 seconds - abort with: shutdown /a
    shutdown /r /t 10
) else (
    echo Remember to restart later.
    pause
)
goto :eof

:: =====================================================================
::  Subroutine: prompt for one app, write its delayed-launch batch and
::  create/delete its logon scheduled task.
::    %1 display name   %2 file id   %3 delay seconds
::    %4 target to launch   %5 working dir (empty = none)
::  Task names are identical to v1, so old tasks are replaced/removed.
:: =====================================================================
:setup_app
set APP_NAME=%~1
set APP_ID=%~2
set APP_DELAY=%~3
set APP_TARGET=%~4
set APP_WORKDIR=%~5
set APP_TASK=!TABLE_NAME! - !APP_NAME! Startup

set APP_ENABLE=
set /p APP_ENABLE="Enable !APP_NAME! auto-start? (Y/N): "
if /i not "!APP_ENABLE!"=="Y" (
    schtasks /delete /tn "!APP_TASK!" /f >nul 2>&1
    echo   [SKIPPED] !APP_NAME!.
    echo.
    goto :eof
)

if not exist "!APP_TARGET!" (
    echo   [WARN] Path not found: "!APP_TARGET!"
    echo          Creating the task anyway - if the path is wrong, edit
    echo          the EDIT THESE PATHS section at the top of this script.
)

set APP_MAX=
set /p APP_MAX="  -^> Open maximized? (Y/N): "
set STARTFLAG=
if /i "!APP_MAX!"=="Y" set STARTFLAG=/max

set APP_SCRIPT=!SCRIPT_DIR!\!APP_ID!.bat
>  "!APP_SCRIPT!" echo @echo off
>> "!APP_SCRIPT!" echo timeout /t !APP_DELAY! /nobreak ^>nul
if not "!APP_WORKDIR!"=="" >> "!APP_SCRIPT!" echo cd /d "!APP_WORKDIR!"
>> "!APP_SCRIPT!" echo start !STARTFLAG! "" "!APP_TARGET!"

schtasks /create /tn "!APP_TASK!" /tr "\"!APP_SCRIPT!\"" /sc onlogon /rl highest /f >nul
if !errorlevel! equ 0 (
    echo   [OK] !APP_NAME! task created.
) else (
    echo   [FAILED] !APP_NAME! task NOT created - see error above.
)
echo.
goto :eof

:: =====================================================================
::  PowerShell block for the NETWORK section. cmd never executes past
::  the goto :eof above; the NETWORK section reads this file, extracts
::  the text between the two markers and runs it with PowerShell.
:: =====================================================================
#PS_NET_BEGIN
$ErrorActionPreference = 'Stop'

function Test-IPv4 ($s) {
  return ($s -match '^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$')
}
function Read-IPv4 ($prompt, $default, [switch]$Optional) {
  while ($true) {
    $p = $prompt
    if ($default) { $p += " [$default]" }
    $v = Read-Host $p
    if ([string]::IsNullOrWhiteSpace($v)) {
      if ($default)  { return $default }
      if ($Optional) { return '' }
      Write-Host '    This value is required.'
      continue
    }
    $v = $v.Trim()
    if (Test-IPv4 $v) { return $v }
    Write-Host "    '$v' is not a valid IPv4 address (example: 192.168.1.50)."
  }
}

Write-Host ''
Write-Host '  Network adapters found on this PC:'
Write-Host ''
$adapters = @(Get-NetAdapter -Physical | Sort-Object -Property ifIndex)
if ($adapters.Count -eq 0) { Write-Host '  [WARN] No physical network adapters found.'; exit 0 }
$i = 1
foreach ($a in $adapters) {
  $ipInfo = Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
  $ip = if ($ipInfo) { $ipInfo.IPAddress } else { '(no IPv4)' }
  $ipIf = Get-NetIPInterface -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
  $mode = if ($ipIf -and $ipIf.Dhcp -eq 'Enabled') { 'DHCP' } else { 'Static' }
  Write-Host ("  {0}. {1,-20} {2,-12} {3,-16} {4,-7} {5}" -f $i, $a.Name, $a.Status, $ip, $mode, $a.InterfaceDescription)
  $i++
}
Write-Host ''
Write-Host '  0. Skip - leave the network as it is'
Write-Host ''
$choice = Read-Host '  Which adapter do you want to configure? (number)'
if ($choice -notmatch '^\d+$' -or [int]$choice -gt $adapters.Count) {
  Write-Host '  Invalid choice - network left unchanged.'; exit 0
}
if ([int]$choice -eq 0) { Write-Host '  [SKIPPED] Network left unchanged.'; exit 0 }
$nic  = $adapters[[int]$choice - 1]
$name = $nic.Name

Write-Host ''
Write-Host "  Selected: $name  ($($nic.InterfaceDescription))"
Write-Host ''
Write-Host '  1. Set a STATIC IP on this adapter'
Write-Host '  2. Set this adapter back to DHCP (automatic)'
Write-Host '  3. Skip'
$action = Read-Host '  Enter a number (1-3)'
if ($action -eq '2') {
  netsh interface ipv4 set address    name="$name" source=dhcp | Out-Null
  netsh interface ipv4 set dnsservers name="$name" source=dhcp | Out-Null
  Write-Host "  [OK] $name set back to DHCP."
  exit 0
}
if ($action -ne '1') { Write-Host '  [SKIPPED] Network left unchanged.'; exit 0 }

Write-Host ''
$ip   = Read-IPv4 '  IP address'
$mask = Read-IPv4 '  Subnet mask' '255.255.255.0'
$gw   = Read-IPv4 '  Default gateway'
$dns1 = Read-IPv4 '  Primary DNS'
$dns2 = Read-IPv4 '  Secondary DNS (Enter to skip)' -Optional

# Sanity check: IP and gateway must be in the same subnet
$ipB = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
$gwB = [System.Net.IPAddress]::Parse($gw).GetAddressBytes()
$mB  = [System.Net.IPAddress]::Parse($mask).GetAddressBytes()
$sameSubnet = $true
for ($k = 0; $k -lt 4; $k++) {
  if (($ipB[$k] -band $mB[$k]) -ne ($gwB[$k] -band $mB[$k])) { $sameSubnet = $false }
}
if (-not $sameSubnet) {
  Write-Host ''
  Write-Host "  [WARN] $ip and gateway $gw are NOT in the same subnet with mask $mask."
  Write-Host '         This is usually a typo - the PC would have no internet.'
}

Write-Host ''
Write-Host '  About to apply:'
Write-Host "    Adapter : $name"
Write-Host "    IP      : $ip"
Write-Host "    Mask    : $mask"
Write-Host "    Gateway : $gw"
Write-Host "    DNS     : $dns1 $dns2"
Write-Host ''
$ok = Read-Host '  Apply? (Y/N)'
if ($ok -notmatch '^[Yy]$') { Write-Host '  [SKIPPED] Network left unchanged.'; exit 0 }

netsh interface ipv4 set address name="$name" source=static address=$ip mask=$mask gateway=$gw gwmetric=1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host '  [FAILED] Could not set the IP address.'; exit 1 }
netsh interface ipv4 set dnsservers name="$name" source=static address=$dns1 register=primary validate=no | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host '  [FAILED] Could not set the primary DNS.'; exit 1 }
if ($dns2) {
  netsh interface ipv4 add dnsservers name="$name" address=$dns2 index=2 validate=no | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Host '  [WARN] Could not set the secondary DNS.' }
}
Write-Host ''
Write-Host "  [OK] $name is now static: $ip / $mask, gateway $gw, DNS $dns1 $dns2"
exit 0
#PS_NET_END
