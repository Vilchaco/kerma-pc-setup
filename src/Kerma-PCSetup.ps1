<#
=====================================================================
  Kerma Games - PC Setup  (v3.0.0 - PowerShell)
=====================================================================
  Double-click "Kerma-PCSetup.bat" next to this file. The script asks
  for administrator rights by itself.

  What it does, in order (every section can be skipped):
    1) Select which PC this is (table / supervisor / office)
    2) Rename username + computer name + Full Name to the standard
    3) Login: remove the password (boot straight to desktop) or
       store it for auto-login, or leave it
    4) Windows Update: manual-only / disabled / restore defaults
    5) Network: pick an adapter, set a static IP (or back to DHCP)
    6) App autostart: one scheduled task per app at logon
    7) Summary + optional restart

  Everything applied is logged to C:\KermaSetup\logs\setup-<date>.log

  Unattended mode (no questions, sensible defaults per PC type):
    Kerma-PCSetup.bat -PC RL01 -Unattended
    Kerma-PCSetup.bat -PC HECTOR -Unattended -Restart
  Defaults used unattended: rename = yes; login = remove password
  (supervisor PCs: leave as is); Windows Update = manual only
  (supervisor PCs: leave as is); network = static only if this PC
  has an IP filled in the table below, else untouched; apps = all
  of this PC's apps, maximized as configured in the APPS table.

  TO ADD A PC: copy one line of the $PCs table below and edit it.
  TO SET IPs:  fill IP = '' in that PC's line. Mask, gateway and DNS
               come from $NetDefaults unless the PC line overrides them
               (e.g. Net = @{ IP = '192.168.1.50'; Gateway = '192.168.1.1' }).
=====================================================================
#>
[CmdletBinding()]
param(
    [string]$PC,            # key from the $PCs table, e.g. RL01
    [switch]$Unattended,    # apply defaults without asking (needs -PC)
    [switch]$Restart        # unattended only: restart when finished
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '3.0.0'

# =====================================================================
#  CONFIG: APPS  (edit paths / delays / default maximize here)
# =====================================================================
$Apps = [ordered]@{
    Scanner    = @{ Name = 'Card Scanner'; Id = '01_scanner';    Path = 'C:\Path\To\CardScanner.bat';                  WorkDir = '';                                     Delay = 10; Maximize = $false }
    StreamDeck = @{ Name = 'StreamDeck';   Id = '02_streamdeck'; Path = 'C:\Path\To\StreamDeckApp.exe';                WorkDir = '';                                     Delay = 15; Maximize = $false }
    DealerApp  = @{ Name = 'Dealer App';   Id = '03_dealerapp';  Path = 'C:\Path\To\DealerApp.exe';                    WorkDir = '';                                     Delay = 30; Maximize = $true  }
    Mirror     = @{ Name = 'Mirror App';   Id = '04_mirror';     Path = 'C:\Path\To\MirrorApp.exe';                    WorkDir = '';                                     Delay = 45; Maximize = $false }
    OBS        = @{ Name = 'OBS';          Id = '05_obs';        Path = 'C:\Program Files\obs-studio\bin\64bit\obs64.exe'; WorkDir = 'C:\Program Files\obs-studio\bin\64bit'; Delay = 60; Maximize = $false }
    # Office PC (Hector's office: cameras on the TV + Deskflow client controlled from his Mac)
    Deskflow   = @{ Name = 'Deskflow';     Id = '01_deskflow';   Path = 'C:\Program Files\Deskflow\deskflow.exe';      WorkDir = '';                                     Delay = 10; Maximize = $false
                    Note = 'If "start Deskflow on login" is already enabled inside Deskflow, answer N here so it is not launched twice.' }
    Cameras    = @{ Name = 'Cameras';      Id = '02_cameras';    Path = 'C:\Path\To\CamerasApp.exe';                   WorkDir = '';                                     Delay = 25; Maximize = $true  }
}
$TableApps  = @('Scanner', 'StreamDeck', 'DealerApp', 'Mirror', 'OBS')
$OfficeApps = @('Deskflow', 'Cameras')

# =====================================================================
#  CONFIG: NETWORK DEFAULTS  (used for every PC unless its line overrides)
# =====================================================================
$NetDefaults = @{ Mask = '255.255.252.0'; Gateway = '192.168.0.10'; DNS1 = '8.8.8.8'; DNS2 = '1.1.1.1' }

# =====================================================================
#  CONFIG: PCs  (one line per PC - Type is Table / Staff / Office)
#  Net: leave IP empty to be asked interactively (or skipped unattended)
# =====================================================================
$PCs = @(
    @{ Key = 'RL01';    Group = 'Table PCs';      Label = 'Roulette 01';                          Type = 'Table';  Hostname = 'KG-TBL-RL-01';    Username = 'kg-tbl-rl-01';    FullName = 'Roulette Table 01';      Apps = $TableApps;  Net = @{ IP = '' } }
    @{ Key = 'BJ01';    Group = 'Table PCs';      Label = 'Blackjack 01';                         Type = 'Table';  Hostname = 'KG-TBL-BJ-01';    Username = 'kg-tbl-bj-01';    FullName = 'Blackjack Table 01';     Apps = $TableApps;  Net = @{ IP = '' } }
    @{ Key = 'BJ02';    Group = 'Table PCs';      Label = 'Blackjack 02';                         Type = 'Table';  Hostname = 'KG-TBL-BJ-02';    Username = 'kg-tbl-bj-02';    FullName = 'Blackjack Table 02';     Apps = $TableApps;  Net = @{ IP = '' } }
    @{ Key = 'BJ03';    Group = 'Table PCs';      Label = 'Blackjack 03';                         Type = 'Table';  Hostname = 'KG-TBL-BJ-03';    Username = 'kg-tbl-bj-03';    FullName = 'Blackjack Table 03';     Apps = $TableApps;  Net = @{ IP = '' } }
    @{ Key = 'BJ04';    Group = 'Table PCs';      Label = 'Blackjack 04';                         Type = 'Table';  Hostname = 'KG-TBL-BJ-04';    Username = 'kg-tbl-bj-04';    FullName = 'Blackjack Table 04';     Apps = $TableApps;  Net = @{ IP = '' } }
    @{ Key = 'BJUNL01'; Group = 'Table PCs';      Label = 'Blackjack Unlimited 01';               Type = 'Table';  Hostname = 'KG-TBL-BJUNL-01'; Username = 'kg-tbl-bjunl-01'; FullName = 'Blackjack Unlimited 01'; Apps = $TableApps;  Net = @{ IP = '' } }
    @{ Key = 'CR01';    Group = 'Table PCs';      Label = 'Craps 01';                             Type = 'Table';  Hostname = 'KG-TBL-CR-01';    Username = 'kg-tbl-cr-01';    FullName = 'Craps Table 01';         Apps = $TableApps;  Net = @{ IP = '' } }
    @{ Key = 'SUP01';   Group = 'Supervisor PCs'; Label = 'Supervisor 01';                        Type = 'Staff';  Hostname = 'KG-SUP-01';       Username = 'kg-sup-01';       FullName = 'Supervisor 01';          Apps = @();         Net = @{ IP = '' } }
    @{ Key = 'SUP02';   Group = 'Supervisor PCs'; Label = 'Supervisor 02';                        Type = 'Staff';  Hostname = 'KG-SUP-02';       Username = 'kg-sup-02';       FullName = 'Supervisor 02';          Apps = @();         Net = @{ IP = '' } }
    @{ Key = 'HECTOR';  Group = 'Office PCs';     Label = 'Hector office PC (cameras on TV + Deskflow)'; Type = 'Office'; Hostname = 'KG-OFC-HECTOR'; Username = 'kg-ofc-hector'; FullName = 'Hector Office PC';    Apps = $OfficeApps; Net = @{ IP = '' } }
)

# =====================================================================
#  Nothing below this line normally needs editing.
# =====================================================================
$State = @{ UserRenamed = $false; HostRenamed = $false; NeedsRestart = $false; Changes = @() }

# ---------------------------- output helpers -------------------------
function Write-Section($title) {
    Write-Host ''
    Write-Host '===============================================' -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host '===============================================' -ForegroundColor Cyan
    Write-Host ''
}
function Write-Ok($m)   { Write-Host "  [OK] $m"      -ForegroundColor Green }
function Write-Skip($m) { Write-Host "  [SKIPPED] $m" -ForegroundColor DarkGray }
function Write-Warn($m) { Write-Host "  [WARN] $m"    -ForegroundColor Yellow }
function Write-Fail($m) { Write-Host "  [FAILED] $m"  -ForegroundColor Red }
function Write-Note($m) { Write-Host "  $m"           -ForegroundColor Yellow }
function Add-Change($m) { $State.Changes += $m }

# ---------------------------- input helpers --------------------------
function Ask-YesNo($prompt, [bool]$default = $false) {
    if ($Unattended) {
        $txt = if ($default) { 'Y' } else { 'N' }
        Write-Host "$prompt -> $txt (unattended)"
        return $default
    }
    $hint = if ($default) { '(Y/n)' } else { '(y/N)' }
    $v = Read-Host "$prompt $hint"
    if ([string]::IsNullOrWhiteSpace($v)) { return $default }
    return ($v.Trim() -match '^[Yy]')
}

# Shows numbered options, returns the 0-based index of the choice.
function Ask-Choice($prompt, [string[]]$options, [int]$default = 0) {
    for ($i = 0; $i -lt $options.Count; $i++) {
        Write-Host ("  {0}. {1}" -f ($i + 1), $options[$i])
    }
    Write-Host ''
    if ($Unattended) {
        Write-Host ("$prompt -> {0} (unattended)" -f ($default + 1))
        return $default
    }
    while ($true) {
        $v = Read-Host "$prompt (1-$($options.Count))"
        if ($v -match '^\d+$' -and [int]$v -ge 1 -and [int]$v -le $options.Count) { return ([int]$v - 1) }
        Write-Host '    Invalid choice.'
    }
}

function Test-IPv4($s) {
    return ($s -match '^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$')
}

# Asks for an IPv4 address, validating it. Enter accepts the default.
function Read-IPv4($prompt, $default, [switch]$Optional) {
    if ($Unattended) {
        if ($default -and (Test-IPv4 $default)) { return $default }
        return ''
    }
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

# ============================ 1) SELECT PC ===========================
function Select-PC {
    if ($PC) {
        $match = $PCs | Where-Object { $_.Key -ieq $PC }
        if (-not $match) { throw "Unknown PC key '$PC'. Valid keys: $(($PCs | ForEach-Object { $_.Key }) -join ', ')" }
        return $match
    }
    if ($Unattended) { throw '-Unattended requires -PC <key> (e.g. -PC RL01).' }

    Write-Section 'Select which PC this is'
    $group = ''
    for ($i = 0; $i -lt $PCs.Count; $i++) {
        if ($PCs[$i].Group -ne $group) { $group = $PCs[$i].Group; Write-Host "  --- $group ---" }
        Write-Host ("  {0,2}. {1}" -f ($i + 1), $PCs[$i].Label)
    }
    Write-Host ''
    while ($true) {
        $v = Read-Host "  Enter a number (1-$($PCs.Count))"
        if ($v -match '^\d+$' -and [int]$v -ge 1 -and [int]$v -le $PCs.Count) { return $PCs[[int]$v - 1] }
        Write-Host '    Invalid choice.'
    }
}

# ============================== 2) RENAME ============================
function Invoke-Rename($pc) {
    Write-Section 'RENAME (username / computer name)'
    Write-Host "    Computer name : $env:COMPUTERNAME  ->  $($pc.Hostname)"
    Write-Host "    Username      : $env:USERNAME  ->  $($pc.Username)"
    Write-Host "    Full Name     : $($pc.FullName)"
    Write-Host ''
    if (-not $Unattended) { Write-Host '  Answer N to keep the current names and only do the other sections.' }
    if (-not (Ask-YesNo '  Rename this PC now?' $true)) { Write-Skip 'Names left as they are.'; return }
    Write-Host ''

    # -- username (done first: safer than renaming the computer first)
    if ($env:USERNAME -ieq $pc.Username) {
        Write-Ok "Username is already $($pc.Username)."
        $State.UserRenamed = $true
    } else {
        try {
            Rename-LocalUser -Name $env:USERNAME -NewName $pc.Username
            $State.UserRenamed = $true
            Write-Ok "Username renamed to $($pc.Username)."
            Write-Note "The profile folder stays as C:\Users\$env:USERNAME - normal Windows behavior, safe to leave as-is."
            Add-Change "Username: $env:USERNAME -> $($pc.Username)"
        } catch {
            Write-Fail "Username rename: $($_.Exception.Message)"
            Write-Note 'Common cause: the new name is already taken. You can rename it manually in lusrmgr.msc.'
        }
    }

    # -- full name
    if ($State.UserRenamed) {
        try {
            Set-LocalUser -Name $pc.Username -FullName $pc.FullName
            Write-Ok "Full Name set to $($pc.FullName)."
        } catch { Write-Warn "Full Name not set (not critical): $($_.Exception.Message)" }
    }

    # -- computer name
    if ($env:COMPUTERNAME -ieq $pc.Hostname) {
        Write-Ok "Computer name is already $($pc.Hostname)."
        $State.HostRenamed = $true
    } else {
        try {
            Rename-Computer -NewName $pc.Hostname -Force -WarningAction SilentlyContinue
            $State.HostRenamed  = $true
            $State.NeedsRestart = $true
            Write-Ok "Computer renamed to $($pc.Hostname) (takes effect after restart)."
            Add-Change "Computer name: $env:COMPUTERNAME -> $($pc.Hostname) (after restart)"
        } catch { Write-Fail "Computer rename: $($_.Exception.Message)" }
    }
}

# =============================== 3) LOGIN ============================
function Invoke-LoginSetup($pc) {
    Write-Section 'LOGIN (boot straight to the desktop)'
    # Use the new names only if the rename really happened (or already
    # matched); a stale DefaultDomainName silently breaks auto-login.
    $user   = if ($State.UserRenamed) { $pc.Username } else { $env:USERNAME }
    $domain = if ($State.HostRenamed) { $pc.Hostname } else { $env:COMPUTERNAME }
    $isStaff = ($pc.Type -eq 'Staff')

    $options = @(
        "Remove the password entirely  (RECOMMENDED for table / office PCs)`n     - blank password + auto-login: boots straight to the desktop after a power cut. Nothing stored anywhere.`n     - Windows blocks remote use (RDP, shared folders) of blank-password accounts.",
        "Keep the password, store it for auto-login`n     - saved in the registry in PLAIN TEXT (same as netplwiz). Only if you need RDP into this account.",
        "Skip - leave login exactly as it is now."
    )
    if ($isStaff) {
        Write-Note '>> SUPERVISOR PC: option 1 is NOT recommended - anyone could open it and read'
        Write-Note '>> this person''s email, files and the supervisor tools. Prefer option 3.'
        Write-Host ''
    }
    $default = if ($isStaff) { 2 } else { 0 }
    $choice  = Ask-Choice '  Enter a number' $options $default
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

    switch ($choice) {
        0 {
            if (-not (Ask-YesNo "  Remove the Windows password for $user?" $true)) { Write-Skip 'Login left unchanged.'; return }
            try {
                Set-LocalUser -Name $user -Password (New-Object System.Security.SecureString)
            } catch {
                Write-Fail "Could not remove the password: $($_.Exception.Message)"
                Write-Note 'If it mentions a password policy, check secpol.msc (local password policy).'
                return
            }
            Write-Ok "Password removed for $user."
            Set-ItemProperty -Path $key -Name AutoAdminLogon    -Value '1'     -Type String
            Set-ItemProperty -Path $key -Name DefaultUserName   -Value $user   -Type String
            Set-ItemProperty -Path $key -Name DefaultDomainName -Value $domain -Type String
            Remove-ItemProperty -Path $key -Name DefaultPassword -ErrorAction SilentlyContinue
            Write-Ok 'Auto-login enabled - no password stored anywhere.'
            Add-Change "Login: password removed for $user, auto-login on"
            $State.NeedsRestart = $true
        }
        1 {
            if ($Unattended) { Write-Skip 'Stored-password auto-login needs a typed password - not available unattended.'; return }
            $sec  = Read-Host "  Enter the Windows password for $user (input is hidden)" -AsSecureString
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
            try   { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
            finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
            Set-ItemProperty -Path $key -Name AutoAdminLogon    -Value '1'     -Type String
            Set-ItemProperty -Path $key -Name DefaultUserName   -Value $user   -Type String
            Set-ItemProperty -Path $key -Name DefaultDomainName -Value $domain -Type String
            Set-ItemProperty -Path $key -Name DefaultPassword   -Value $plain  -Type String
            $plain = $null
            Write-Ok "Auto-login configured for $domain\$user (password stored in registry)."
            Add-Change "Login: auto-login with stored password for $user"
            $State.NeedsRestart = $true
        }
        default { Write-Skip 'Login left unchanged.' }
    }
}

# =========================== 4) WINDOWS UPDATE =======================
function Invoke-WindowsUpdateSetup($pc) {
    Write-Section 'WINDOWS UPDATE'
    $edition = 'unknown'
    try { $edition = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID } catch { }
    Write-Host "  Windows edition: $edition"
    Write-Host ''
    $isStaff = ($pc.Type -eq 'Staff')

    $options = @(
        "Manual updates only  (RECOMMENDED for table / office PCs)`n     - Windows never downloads, installs or reboots on its own, and stops pushing drivers.`n     - You still install updates by hand in Settings > Windows Update during maintenance.",
        "Disable Windows Update completely`n     - same as 1, plus the Windows Update service is stopped and disabled.",
        "Restore automatic updates  (undo 1 or 2)",
        "Skip - leave Windows Update as it is now."
    )
    if ($isStaff) { Write-Note '>> Supervisor PC: keep automatic updates (option 4) unless there is a specific reason not to.'; Write-Host '' }
    if ($edition -like 'Core*') { Write-Note '>> Windows HOME detected: Home does not fully honor the policy used by option 1. Option 2 is the reliable choice on Home.'; Write-Host '' }
    $default = if ($isStaff) { 3 } else { 0 }
    $choice  = Ask-Choice '  Enter a number' $options $default

    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $au = "$wu\AU"
    $applyPolicy = {
        New-Item -Path $au -Force | Out-Null
        Set-ItemProperty -Path $au -Name NoAutoUpdate                    -Value 1 -Type DWord
        Set-ItemProperty -Path $au -Name NoAutoRebootWithLoggedOnUsers   -Value 1 -Type DWord
        Set-ItemProperty -Path $wu -Name ExcludeWUDriversInQualityUpdate -Value 1 -Type DWord
    }

    switch ($choice) {
        0 {
            & $applyPolicy
            Set-Service -Name wuauserv -StartupType Manual
            Write-Ok 'Windows Update set to MANUAL ONLY - no auto download, install, reboot or driver updates.'
            Add-Change 'Windows Update: manual only'
        }
        1 {
            & $applyPolicy
            Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
            Set-Service  -Name wuauserv -StartupType Disabled
            Write-Ok 'Windows Update DISABLED - policy applied and service stopped/disabled. Run again with option 3 to undo.'
            Add-Change 'Windows Update: disabled'
        }
        2 {
            Remove-ItemProperty -Path $au -Name NoAutoUpdate                    -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $au -Name NoAutoRebootWithLoggedOnUsers   -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $wu -Name ExcludeWUDriversInQualityUpdate -ErrorAction SilentlyContinue
            Set-Service   -Name wuauserv -StartupType Manual
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
            Write-Ok 'Automatic updates restored to Windows defaults.'
            Add-Change 'Windows Update: restored to automatic'
        }
        default { Write-Skip 'Windows Update left unchanged.' }
    }
}

# ============================== 5) NETWORK ===========================
# Per-PC values win; anything blank falls back to $NetDefaults.
function Get-NetPlan($pc) {
    $plan = @{ IP = ''; Mask = ''; Gateway = ''; DNS1 = ''; DNS2 = '' }
    foreach ($k in @($plan.Keys)) {
        $v = $null
        if ($pc.Net -and $pc.Net.ContainsKey($k)) { $v = $pc.Net[$k] }
        if ([string]::IsNullOrWhiteSpace($v) -and $NetDefaults.ContainsKey($k)) { $v = $NetDefaults[$k] }
        if ($v) { $plan[$k] = $v }
    }
    return $plan
}

function Invoke-NetworkSetup($pc) {
    Write-Section 'NETWORK (static IP)'
    $net     = Get-NetPlan $pc
    $hasPlan = -not [string]::IsNullOrWhiteSpace($net.IP)

    if ($Unattended -and -not $hasPlan) { Write-Skip 'No IP defined for this PC in the table - network left unchanged.'; return }
    if (-not (Ask-YesNo '  Configure the network adapter / static IP now?' $hasPlan)) { Write-Skip 'Network left unchanged.'; return }

    $adapters = @(Get-NetAdapter -Physical | Sort-Object -Property ifIndex)
    if ($adapters.Count -eq 0) { Write-Warn 'No physical network adapters found.'; return }

    Write-Host ''
    Write-Host '  Network adapters found on this PC:'
    Write-Host ''
    for ($i = 0; $i -lt $adapters.Count; $i++) {
        $a = $adapters[$i]
        $ipInfo = Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
        $ip     = if ($ipInfo) { $ipInfo.IPAddress } else { '(no IPv4)' }
        $ipIf   = Get-NetIPInterface -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $mode   = if ($ipIf -and $ipIf.Dhcp -eq 'Enabled') { 'DHCP' } else { 'Static' }
        Write-Host ("  {0}. {1,-20} {2,-12} {3,-16} {4,-7} {5}" -f ($i + 1), $a.Name, $a.Status, $ip, $mode, $a.InterfaceDescription)
    }
    Write-Host ''
    Write-Host '  0. Skip - leave the network as it is'
    Write-Host ''

    # -- pick adapter
    $nic = $null
    if ($Unattended) {
        # prefer a connected Ethernet adapter, then any connected adapter
        $nic = $adapters | Where-Object { $_.Status -eq 'Up' -and $_.MediaType -eq '802.3' } | Select-Object -First 1
        if (-not $nic) { $nic = $adapters | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1 }
        if (-not $nic) { Write-Fail 'No connected adapter found - network left unchanged.'; return }
        Write-Host "  Adapter -> $($nic.Name) (unattended: first connected Ethernet adapter)"
    } else {
        while ($true) {
            $v = Read-Host '  Which adapter do you want to configure? (number)'
            if ($v -match '^\d+$' -and [int]$v -le $adapters.Count) { break }
            Write-Host '    Invalid choice.'
        }
        if ([int]$v -eq 0) { Write-Skip 'Network left unchanged.'; return }
        $nic = $adapters[[int]$v - 1]
    }
    $name = $nic.Name
    Write-Host ''
    Write-Host "  Selected: $name  ($($nic.InterfaceDescription))"
    Write-Host ''

    # -- static / dhcp / skip
    $action = Ask-Choice '  Enter a number' @('Set a STATIC IP on this adapter', 'Set this adapter back to DHCP (automatic)', 'Skip') 0
    if ($action -eq 1) {
        netsh interface ipv4 set address    name="$name" source=dhcp | Out-Null
        netsh interface ipv4 set dnsservers name="$name" source=dhcp | Out-Null
        Write-Ok "$name set back to DHCP."
        Add-Change "Network: $name -> DHCP"
        return
    }
    if ($action -ne 0) { Write-Skip 'Network left unchanged.'; return }

    Write-Host ''
    Write-Host '  Suggested values are shown in [brackets] - press Enter to accept, or type another.'
    Write-Host ''
    $ip   = Read-IPv4 '  IP address'      $net.IP
    $mask = Read-IPv4 '  Subnet mask'     $net.Mask
    $gw   = Read-IPv4 '  Default gateway' $net.Gateway
    $dns1 = Read-IPv4 '  Primary DNS'     $net.DNS1
    $dns2 = Read-IPv4 '  Secondary DNS (Enter to skip)' $net.DNS2 -Optional

    if (-not $ip -or -not $mask -or -not $gw -or -not $dns1) {
        Write-Fail 'IP, mask, gateway and primary DNS are all required - network left unchanged.'
        return
    }

    # -- sanity: IP and gateway in the same subnet
    $ipB = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
    $gwB = [System.Net.IPAddress]::Parse($gw).GetAddressBytes()
    $mB  = [System.Net.IPAddress]::Parse($mask).GetAddressBytes()
    $sameSubnet = $true
    for ($k = 0; $k -lt 4; $k++) {
        if (($ipB[$k] -band $mB[$k]) -ne ($gwB[$k] -band $mB[$k])) { $sameSubnet = $false }
    }
    if (-not $sameSubnet) {
        Write-Warn "$ip and gateway $gw are NOT in the same subnet with mask $mask. Usually a typo - the PC would have no internet."
        if ($Unattended) { Write-Fail 'Refusing to apply a broken network plan unattended.'; return }
    }

    Write-Host ''
    Write-Host '  About to apply:'
    Write-Host "    Adapter : $name"
    Write-Host "    IP      : $ip"
    Write-Host "    Mask    : $mask"
    Write-Host "    Gateway : $gw"
    Write-Host "    DNS     : $dns1 $dns2"
    Write-Host ''
    if (-not (Ask-YesNo '  Apply?' $true)) { Write-Skip 'Network left unchanged.'; return }

    netsh interface ipv4 set address name="$name" source=static address=$ip mask=$mask gateway=$gw gwmetric=1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Fail 'Could not set the IP address (netsh error).'; return }
    netsh interface ipv4 set dnsservers name="$name" source=static address=$dns1 register=primary validate=no | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Fail 'IP applied but the primary DNS could not be set (netsh error).'; return }
    if ($dns2) {
        netsh interface ipv4 add dnsservers name="$name" address=$dns2 index=2 validate=no | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warn 'Could not set the secondary DNS.' }
    }
    Write-Ok "$name is now static: $ip / $mask, gateway $gw, DNS $dns1 $dns2"
    Add-Change "Network: $name static $ip / $mask, gw $gw, DNS $dns1 $dns2"
}

# ============================ 6) APP AUTOSTART =======================
function Invoke-AppAutostart($pc) {
    Write-Section 'APP AUTOSTART'
    if ($pc.Type -eq 'Staff' -or $pc.Apps.Count -eq 0) { Write-Skip 'App autostart does not apply to this PC type.'; return }

    Write-Note 'If you answer N to an app, its existing autostart task (if any) is DELETED.'
    Write-Note 'Only continue if you want to review / change the app list right now.'
    Write-Host ''
    if (-not (Ask-YesNo '  Configure app autostart now?' $true)) { Write-Skip 'App autostart - existing tasks left untouched.'; return }

    $tableName = if ($State.HostRenamed) { $pc.Hostname } else { $env:COMPUTERNAME }
    $user      = if ($State.UserRenamed) { $pc.Username } else { $env:USERNAME }
    $dir       = "C:\KermaStartup\$tableName"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    # The task runs in this user's interactive session at logon. We
    # register it by SID so a later computer rename cannot break it.
    $principalId = "$env:COMPUTERNAME\$user"
    try { $principalId = (Get-LocalUser -Name $user).SID.Value } catch { }

    Write-Host "  Tasks will be named '$tableName - <App> Startup', scripts in $dir"

    foreach ($k in $pc.Apps) {
        $app      = $Apps[$k]
        $taskName = "$tableName - $($app.Name) Startup"
        Write-Host ''
        if ($app.Note) { Write-Note $app.Note }

        if (-not (Ask-YesNo "  Enable $($app.Name) auto-start?" $true)) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Skip "$($app.Name) (existing task removed, if there was one)."
            continue
        }
        if (-not (Test-Path -LiteralPath $app.Path)) {
            Write-Warn "Path not found: $($app.Path)"
            Write-Note 'Creating the task anyway - if the path is wrong, fix it in the CONFIG: APPS table at the top of this script.'
        }
        $max  = Ask-YesNo '    -> Open maximized?' ([bool]$app.Maximize)
        $flag = if ($max) { '/max' } else { '' }

        $lines = @('@echo off', "timeout /t $($app.Delay) /nobreak >nul")
        if ($app.WorkDir) { $lines += "cd /d `"$($app.WorkDir)`"" }
        $lines += "start $flag `"`" `"$($app.Path)`""
        $bat = Join-Path $dir "$($app.Id).bat"
        Set-Content -LiteralPath $bat -Value $lines -Encoding Ascii

        try {
            $taskAction    = New-ScheduledTaskAction -Execute $bat
            $taskTrigger   = New-ScheduledTaskTrigger -AtLogOn
            $taskPrincipal = New-ScheduledTaskPrincipal -UserId $principalId -LogonType Interactive -RunLevel Highest
            $taskSettings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
            Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Force | Out-Null
            Write-Ok "$($app.Name) task created (delay $($app.Delay)s$(if ($max) { ', maximized' }))."
            Add-Change "Autostart: $($app.Name)"
        } catch {
            Write-Fail "$($app.Name) task NOT created: $($_.Exception.Message)"
        }
    }
    Write-Host ''
    Write-Note 'To make an app open on the correct monitor, move its window there by hand once - most apps (OBS included) remember the position.'
}

# ============================== 7) FINISH ============================
function Invoke-Finish {
    Write-Section 'SUMMARY'
    if ($State.Changes.Count -eq 0) {
        Write-Host '  Nothing was changed.'
    } else {
        foreach ($c in $State.Changes) { Write-Host "  - $c" }
    }
    Write-Host ''
    Write-Host "  Log: $script:LogFile"
    Write-Host ''
    if ($State.NeedsRestart) { Write-Note 'A RESTART is needed for the name / login changes to fully apply.' }

    if ($Unattended) {
        if ($Restart) { Write-Host '  Restarting in 10 seconds (unattended -Restart).'; shutdown.exe /r /t 10 }
        elseif ($State.NeedsRestart) { Write-Note 'Restart this PC when convenient (run with -Restart to do it automatically).' }
        return
    }
    if (Ask-YesNo '  Restart this PC now?' $State.NeedsRestart) {
        Write-Host '  Restarting in 10 seconds - abort with: shutdown /a'
        shutdown.exe /r /t 10
    } else {
        Write-Host '  Remember to restart later.'
    }
}

# =============================== MAIN ================================
# -- self-elevate
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    foreach ($kv in $PSBoundParameters.GetEnumerator()) {
        if ($kv.Value -is [switch]) { if ($kv.Value) { $argList += "-$($kv.Key)" } }
        else { $argList += "-$($kv.Key)"; $argList += "`"$($kv.Value)`"" }
    }
    Write-Host 'Requesting administrator rights (UAC prompt)...'
    try { Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ($argList -join ' ') }
    catch { Write-Host 'Administrator rights were refused - nothing was changed.'; Start-Sleep 3 }
    exit
}

# -- log everything
$logDir = 'C:\KermaSetup\logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$script:LogFile = Join-Path $logDir ("setup-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
try { Start-Transcript -Path $script:LogFile | Out-Null } catch { $script:LogFile = '(transcript not available)' }

try {
    Write-Section "KERMA GAMES - PC SETUP  v$ScriptVersion"
    Write-Host "  Current computer name : $env:COMPUTERNAME"
    Write-Host "  Current username      : $env:USERNAME"
    if ($Unattended) { Write-Host '  Mode                  : UNATTENDED' }

    $selected = Select-PC
    Write-Host ''
    Write-Host "  Selected PC: $($selected.Label)  [$($selected.Type)]" -ForegroundColor Cyan

    Invoke-Rename             $selected
    Invoke-LoginSetup         $selected
    Invoke-WindowsUpdateSetup $selected
    Invoke-NetworkSetup       $selected
    Invoke-AppAutostart       $selected
    Invoke-Finish
} catch {
    Write-Host ''
    Write-Fail $_.Exception.Message
} finally {
    try { Stop-Transcript | Out-Null } catch { }
    if (-not $Unattended) { Write-Host ''; Read-Host '  Press Enter to close' | Out-Null }
}
