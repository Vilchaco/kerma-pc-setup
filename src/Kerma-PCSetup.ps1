<#
=====================================================================
  Kerma Games - PC Setup  (v4.5.0 - PowerShell)
=====================================================================
  Fresh PC, one line in PowerShell (downloads the latest release and
  starts it - see README):
    irm https://raw.githubusercontent.com/Vilchaco/kerma-pc-setup/main/bootstrap.ps1 | iex
  Or double-click "Kerma-PCSetup.bat" next to this file. The script
  asks for administrator rights by itself.

  What it does, in order (every section can be skipped):
    1) Select which PC this is (table / supervisor / office)
    2) Date / time: Monterrey time zone + clock kept in sync with
       internet time (every hour, at every startup and daily), so
       the Dealer App countdowns are exact
    3) Rename username + computer name + Full Name to the standard
    4) Login: remove the password (boot straight to desktop) or
       store it for auto-login, or leave it
    5) Windows Update: manual-only / disabled / restore defaults
    6) Network: pick an adapter, set a static IP (or back to DHCP)
    7) PC tuning: screen never off, no sleep, USB never suspended,
       no notifications, no screen saver, taskbar, network adapter
       (wake-on-LAN, never powered off, no energy-efficient Ethernet)
    7b) Remove preinstalled junk: Solitaire, Xbox, Teams, Bing apps,
       Candy Crush & co., Microsoft 365 trial, OneDrive
    8) Install programs for this PC type (winget / GitHub releases)
    9) Program settings: HDMI Mirror config, OBS scenes/profile,
       VST3 plugins, Stream Deck profile of the table's game
       (all from assets\)
   10) App autostart: one scheduled task per app at logon
   10b) Audio: Windows sounds off, Scarlett as default microphone
       and speakers
   10d) Wallpaper: the table's Kerma template + computer name, IP
       and script version (assets\wallpaper)
   10c) Status panel: this PC reports every 5 min to
       https://kermasetup.netlify.app/estado
   11) Summary + optional restart

  Review mode (changes nothing, shows the state of this PC):
    Kerma-PCSetup.bat -Check

  Everything applied is logged to C:\KermaSetup\logs\setup-<date>.log

  Unattended mode (no questions, sensible defaults per PC type):
    Kerma-PCSetup.bat -PC RL01 -Unattended
    Kerma-PCSetup.bat -PC HECTOR -Unattended -Restart
  Defaults used unattended: date/time = fix + keep synced; rename =
  yes; login = remove password
  (supervisor PCs: leave as is); Windows Update = manual only
  (supervisor PCs: leave as is); network = static only if this PC
  has an IP filled in the table below, else untouched; tuning = yes
  (supervisor PCs: no); remove junk apps = yes (also Microsoft 365
  and OneDrive, on every PC type); install = yes; program settings = yes (an
  existing HDMI Mirror config is kept); apps = all
  of this PC's apps whose path is known and valid (apps without a
  valid path are skipped and reported), maximized as in the APPS table.

  APP PATHS:   no need to edit anything. When you enable an app, the
               script asks for its program file (paste a path or press
               B to browse), checks it, and remembers it in
               app-paths.json next to this script, so the next PC
               already suggests it.
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
    [switch]$Restart,       # unattended only: restart when finished
    [switch]$Check,         # review mode: show the state of this PC, change nothing
    [string]$PanelPin       # status panel PIN (unattended registration)
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '4.5.0'

# =====================================================================
#  CONFIG: APPS  (delays / default maximize)
#  Path is only a first suggestion - leave it '' if unknown. The real
#  path is asked (and checked) while the script runs, then remembered
#  in app-paths.json next to this script. Apps always start with their
#  own folder as working directory (OBS needs this).
# =====================================================================
#  SelfStarts: the program registers its own start at logon, so no task
#  is created (and an old one is removed) to avoid opening it twice.
#  Replaces: name of an older app whose autostart task is removed.
$Apps = [ordered]@{
    Scanner    = @{ Name = 'Card Scanner'; Id = '01_scanner';    Path = '';                                                 Delay = 10; Maximize = $false }
    StreamDeck = @{ Name = 'StreamDeck';   Id = '02_streamdeck'; Path = 'C:\Program Files\Elgato\StreamDeck\StreamDeck.exe';  Delay = 15; Maximize = $false; SelfStarts = $true }
    DealerApp  = @{ Name = 'Dealer App';   Id = '03_dealerapp';  Path = '';                                                 Delay = 30; Maximize = $true  }
    HdmiMirror = @{ Name = 'HDMI Mirror';  Id = '04_hdmimirror'; Path = 'C:\Kerma\HdmiMirror\HdmiMirror.exe';               Delay = 45; Maximize = $false; Replaces = 'Mirror App' }
    # OBS: if it was not closed cleanly (crash, power cut, forced restart) it
    # leaves %APPDATA%\obs-studio\.sentinel\run_* behind and the next start
    # stops on the "Launch normally / Safe Mode" dialog. The autostart deletes
    # those files first (what a clean exit does), so the table starts alone.
    # Opened by hand from the Start menu, OBS still offers Safe Mode.
    # (--disable-shutdown-check did this up to OBS 31; it no longer exists.)
    OBS        = @{ Name = 'OBS';          Id = '05_obs';        Path = 'C:\Program Files\obs-studio\bin\64bit\obs64.exe'; Delay = 60; Maximize = $false
                    Args = '--disable-updater'
                    PreLaunch = @('del /q "%APPDATA%\obs-studio\.sentinel\run_*" >nul 2>&1') }
    # Deskflow: no longer used (was a test on Hector's office PC); kept for reference
    Deskflow   = @{ Name = 'Deskflow';     Id = '01_deskflow';   Path = 'C:\Program Files\Deskflow\deskflow.exe';          Delay = 10; Maximize = $false
                    Note = 'If "start Deskflow on login" is already enabled inside Deskflow, answer N here so it is not launched twice.' }
    Cameras    = @{ Name = 'Cameras';      Id = '02_cameras';    Path = '';                                                 Delay = 25; Maximize = $true  }
}
# Card Scanner and Dealer App are NOT installed by the script (the devs
# manage the Dealer App; the scanner needs a manual setup), but their
# autostart is configured: the script asks for their program file.
# The card scanner is only used on the tables that scan cards.
$TableApps            = @('StreamDeck', 'DealerApp', 'HdmiMirror', 'OBS')
$TableAppsWithScanner = @('Scanner') + $TableApps
$OfficeApps = @('Cameras')
# OBS theme shipped in assets\obs\themes\ (id must match the @OBSThemeMeta id)
$ObsThemeFile = 'Kerma.ovt'
$ObsThemeId   = 'com.kerma.Yami.Kerma'

# =====================================================================
#  CONFIG: PROGRAMS TO INSTALL
#  Source 'winget' : Id = winget package id (search: winget search <name>)
#  Source 'github' : Repo = owner/name of a PUBLIC repo, Asset = regex of
#                    the release file. .msi = silent install; .zip =
#                    extracted into InstallTo (and updated when a newer
#                    release exists).
#  Check           : file that exists once installed (then it is skipped)
# =====================================================================
$Packages = [ordered]@{
    Chrome     = @{ Name = 'Google Chrome'; Source = 'winget'; Id = 'Google.Chrome';        Check = 'C:\Program Files\Google\Chrome\Application\chrome.exe' }
    RustDesk   = @{ Name = 'RustDesk';      Source = 'github'; Repo = 'rustdesk/rustdesk';  Asset = '^rustdesk-[0-9.]+-x86_64\.msi$';  Check = 'C:\Program Files\RustDesk\rustdesk.exe' }
    StreamDeck = @{ Name = 'Stream Deck';   Source = 'winget'; Id = 'Elgato.StreamDeck';    Check = 'C:\Program Files\Elgato\StreamDeck\StreamDeck.exe' }
    HdmiMirror = @{ Name = 'HDMI Mirror';   Source = 'github'; Repo = 'Vilchaco/kerma-hdmi-mirror'; Asset = '^HdmiMirror-v[0-9.]+\.zip$'
                    InstallTo = 'C:\Kerma'; Check = 'C:\Kerma\HdmiMirror\HdmiMirror.exe'; Process = 'HdmiMirror'
                    UserWritable = 'C:\Kerma\HdmiMirror' }   # it saves hdmimirror.config.json next to its exe
    OBS        = @{ Name = 'OBS Studio';    Source = 'winget'; Id = 'OBSProject.OBSStudio'; Check = 'C:\Program Files\obs-studio\bin\64bit\obs64.exe' }
    # atkAudio: adds VST3 support to OBS (free, AGPL). The release zip holds
    # one zip per platform; the portable Windows one goes into the OBS folder.
    AtkAudio   = @{ Name = 'atkAudio (VST3 in OBS)'; Source = 'github'; Repo = 'atkAudio/PluginForObsRelease'; Asset = '^atkAudio-PluginForObs\.zip$'
                    Inner = '^portable-atkaudio-pluginforobs-[0-9.]+-Windows\.zip$'; InstallTo = 'C:\Program Files\obs-studio'
                    Check = 'C:\Program Files\obs-studio\obs-plugins\64bit\atkaudio-pluginforobs.dll'; Process = 'obs64'; Requires = 'OBS' }
    Deskflow   = @{ Name = 'Deskflow';      Source = 'winget'; Id = 'Deskflow.Deskflow';    Check = 'C:\Program Files\Deskflow\deskflow.exe' }
    Focusrite  = @{ Name = 'Focusrite Control 2 (Scarlett)'; Source = 'winget'; Id = ''; Check = '' }   # Id comes from $ScarlettPackageId
}
# Programs per PC type (keys of $Packages)
$InstallByType = @{
    Table  = @('Chrome', 'RustDesk', 'StreamDeck', 'HdmiMirror', 'OBS', 'AtkAudio')
    Office = @('Chrome', 'RustDesk')
    Staff  = @('Chrome', 'RustDesk')
}
# Focusrite Scarlett software. Our Scarletts are Solo 3rd Gen, which
# Focusrite now supports in Focusrite Control 2. It is installed on any
# PC with a Focusrite device connected (USB vendor 1235), plus on the PC
# types listed in $ScarlettPcTypes, e.g. @('Table'). '' = never install.
$ScarlettPackageId = 'FocusriteAudioEngineeringLtd.FocusriteControl2'
$ScarlettPcTypes   = @()

# =====================================================================
#  CONFIG: PREINSTALLED APPS TO REMOVE  (Store apps; * = wildcard)
#  $NeverRemove always wins, so a careless pattern cannot hit them.
#  App Installer (= winget) must never be removed: the install section
#  needs it.
# =====================================================================
$RemoveApps = @(
    # Microsoft 365 / Office promos, mail, Teams
    'Microsoft.MicrosoftOfficeHub', 'Microsoft.Office.OneNote', 'Microsoft.OutlookForWindows',
    'microsoft.windowscommunicationsapps', 'MicrosoftTeams', 'MSTeams', 'Microsoft.SkypeApp', 'Microsoft.People',
    # games and Xbox
    'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.GamingApp', 'Microsoft.XboxApp', 'Microsoft.Edge.GameAssist',
    # news, tips, help, misc
    'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingSearch', 'Microsoft.GetHelp', 'Microsoft.Getstarted',
    'Microsoft.WindowsFeedbackHub', 'Microsoft.WindowsMaps', 'Microsoft.ZuneVideo', 'Microsoft.ZuneMusic',
    'Microsoft.YourPhone', 'Microsoft.Todos', 'Microsoft.PowerAutomateDesktop', 'MicrosoftCorporationII.MicrosoftFamily',
    'MicrosoftCorporationII.QuickAssist', 'Microsoft.549981C3F5F10', 'Clipchamp.Clipchamp', 'Microsoft.Windows.DevHome',
    'Microsoft.Copilot', 'Microsoft.Microsoft3DViewer', 'Microsoft.MixedReality.Portal', 'Microsoft.Wallet',
    # third-party promos
    'king.com.*', 'SpotifyAB.*', 'Disney.*', '*TikTok*', 'Facebook.*', '*Instagram*', 'AmazonVideo.*', '*LinkedIn*', '*Netflix*'
)
$NeverRemove = @(
    'Microsoft.DesktopAppInstaller', 'Microsoft.WindowsStore', 'Microsoft.StorePurchaseApp', 'Microsoft.WindowsCalculator',
    'Microsoft.Windows.Photos', 'Microsoft.WindowsNotepad', 'Microsoft.Paint', 'Microsoft.ScreenSketch', 'Microsoft.WindowsTerminal',
    'Microsoft.VCLibs.*', 'Microsoft.UI.Xaml.*', 'Microsoft.NET.Native.*', 'Microsoft.WindowsAppRuntime.*', 'Microsoft.SecHealthUI',
    'Microsoft.Windows.ShellExperienceHost', 'Microsoft.Windows.StartMenuExperienceHost', 'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxIdentityProvider', 'Microsoft.Xbox.TCUI', 'Microsoft.MicrosoftStickyNotes', 'Microsoft.WindowsAlarms',
    'Microsoft.WindowsSoundRecorder', 'Microsoft.WindowsCamera'
)

# =====================================================================
#  CONFIG: AUDIO + STATUS PANEL
# =====================================================================
$ScarlettAsDefaultPlayback = $true    # the Scarlett is also the default speakers ($false = microphone only)
$PanelBase = 'https://kermasetup.netlify.app'

# =====================================================================
#  CONFIG: NETWORK DEFAULTS  (used for every PC unless its line overrides)
# =====================================================================
$NetDefaults = @{ Mask = '255.255.252.0'; Gateway = '192.168.0.10'; DNS1 = '8.8.8.8'; DNS2 = '1.1.1.1' }

# =====================================================================
#  CONFIG: DATE / TIME
# =====================================================================
$TimeZoneId         = 'Central Standard Time (Mexico)'  # Monterrey: UTC-6, no daylight saving since 2022
$TimeZoneFallbackId = 'Central America Standard Time'   # UTC-6, never daylight saving - used if this PC's time zone data is outdated
$TimeServers        = @('time.cloudflare.com', 'time.windows.com')  # internet time servers, in order of preference
$TimeSyncDailyAt    = '07:00'                           # daily safety-net sync (it also runs at every startup)

# =====================================================================
#  CONFIG: PCs  (one line per PC - Type is Table / Staff / Office)
#  Net: leave IP empty to be asked interactively (or skipped unattended)
#  Game: picks assets\streamdeck\<Game>.streamDeckProfile for the table
# =====================================================================
$PCs = @(
    @{ Key = 'RL01';    Group = 'Table PCs';      Label = 'Roulette 01';                          Type = 'Table';  Hostname = 'KG-TBL-RL-01';    Username = 'kg-tbl-rl-01';    FullName = 'Roulette Table 01';      Apps = $TableApps;  Game = 'roulette';  Net = @{ IP = '' } }
    @{ Key = 'BJ01';    Group = 'Table PCs';      Label = 'Blackjack 01';                         Type = 'Table';  Hostname = 'KG-TBL-BJ-01';    Username = 'kg-tbl-bj-01';    FullName = 'Blackjack Table 01';     Apps = $TableAppsWithScanner;  Game = 'blackjack';  Net = @{ IP = '' } }
    @{ Key = 'BJ02';    Group = 'Table PCs';      Label = 'Blackjack 02';                         Type = 'Table';  Hostname = 'KG-TBL-BJ-02';    Username = 'kg-tbl-bj-02';    FullName = 'Blackjack Table 02';     Apps = $TableAppsWithScanner;  Game = 'blackjack';  Net = @{ IP = '' } }
    @{ Key = 'BJ03';    Group = 'Table PCs';      Label = 'Blackjack 03';                         Type = 'Table';  Hostname = 'KG-TBL-BJ-03';    Username = 'kg-tbl-bj-03';    FullName = 'Blackjack Table 03';     Apps = $TableAppsWithScanner;  Game = 'blackjack';  Net = @{ IP = '' } }
    @{ Key = 'BJ04';    Group = 'Table PCs';      Label = 'Blackjack 04';                         Type = 'Table';  Hostname = 'KG-TBL-BJ-04';    Username = 'kg-tbl-bj-04';    FullName = 'Blackjack Table 04';     Apps = $TableAppsWithScanner;  Game = 'blackjack';  Net = @{ IP = '' } }
    @{ Key = 'BJUNL01'; Group = 'Table PCs';      Label = 'Blackjack Unlimited 01';               Type = 'Table';  Hostname = 'KG-TBL-BJUNL-01'; Username = 'kg-tbl-bjunl-01'; FullName = 'Blackjack Unlimited 01'; Apps = $TableAppsWithScanner;  Game = 'blackjack-unlimited';  Net = @{ IP = '' } }
    @{ Key = 'CR01';    Group = 'Table PCs';      Label = 'Craps 01';                             Type = 'Table';  Hostname = 'KG-TBL-CR-01';    Username = 'kg-tbl-cr-01';    FullName = 'Craps Table 01';         Apps = $TableApps;  Game = 'craps';  Net = @{ IP = '' } }
    @{ Key = 'SUP01';   Group = 'Supervisor PCs'; Label = 'Supervisor 01';                        Type = 'Staff';  Hostname = 'KG-SUP-01';       Username = 'kg-sup-01';       FullName = 'Supervisor 01';          Apps = @();         Net = @{ IP = '' } }
    @{ Key = 'SUP02';   Group = 'Supervisor PCs'; Label = 'Supervisor 02';                        Type = 'Staff';  Hostname = 'KG-SUP-02';       Username = 'kg-sup-02';       FullName = 'Supervisor 02';          Apps = @();         Net = @{ IP = '' } }
    @{ Key = 'HECTOR';  Group = 'Office PCs';     Label = 'Hector office PC (cameras on TV)'; Type = 'Office'; Hostname = 'KG-OFC-HECTOR'; Username = 'kg-ofc-hector'; FullName = 'Hector Office PC';    Apps = $OfficeApps; Net = @{ IP = '' } }
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

# Runs a Windows command-line tool and returns its output + exit code.
# Needed because with ErrorActionPreference=Stop, Windows PowerShell 5.1
# turns any line a tool writes to stderr into a script-stopping error.
function Invoke-Native([string]$exe, [string[]]$arguments) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = (& $exe @arguments 2>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ }
            } | Out-String)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    return @{ Output = $out; ExitCode = $code; Text = (($out -replace '\s+', ' ').Trim()) }
}

# Creates a registry key only if it is missing. (New-Item -Force on an
# existing registry key would DELETE it with all its values.)
function Initialize-RegistryKey([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
}

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

# ======================== 2) DATE / TIME =============================
# Script run by the background task "Kerma - Time Sync" (as SYSTEM, at
# every startup and once a day). It waits for the network after a power
# cut and forces a sync. Written to C:\ProgramData\Kerma by the setup.
$TimeSyncScript = @'
# Kerma Games - Time Sync. Created by Kerma-PCSetup.ps1 - do not edit here.
$log = Join-Path $PSScriptRoot 'timesync.log'
function Log($m) { Add-Content -LiteralPath $log -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) }
$ok = $false
$out = ''
try {
    if ((Get-Service -Name w32time).Status -ne 'Running') { Start-Service -Name w32time; Start-Sleep -Seconds 2 }
    # up to 12 tries x 5 s: after a power cut the network may still be coming up
    for ($i = 1; $i -le 12; $i++) {
        $out = (& w32tm.exe /resync 2>&1 | Out-String)
        if ($LASTEXITCODE -eq 0) { $ok = $true; Log "OK - clock synced (attempt $i)"; break }
        Start-Sleep -Seconds 5
    }
    if (-not $ok) { Log ('FAILED after 12 attempts: ' + (($out -replace '\s+', ' ').Trim())) }
} catch { Log ('ERROR: ' + $_.Exception.Message) }
# keep the log small
try {
    $lines = @(Get-Content -LiteralPath $log -ErrorAction Stop)
    if ($lines.Count -gt 500) { $lines | Select-Object -Last 300 | Set-Content -LiteralPath $log }
} catch { }
if ($ok) { exit 0 } else { exit 1 }
'@

function ConvertFrom-NtpTimestamp([byte[]]$b, [int]$o) {
    [double]$sec = 0
    [double]$frac = 0
    for ($i = 0; $i -lt 4; $i++) {
        $sec  = ($sec * 256)  + $b[$o + $i]
        $frac = ($frac * 256) + $b[$o + 4 + $i]
    }
    $ms = ($sec * 1000) + (($frac * 1000) / 4294967296)
    return (New-Object DateTime 1900, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)).AddMilliseconds($ms)
}

# Asks an internet time server directly (raw NTP over UDP port 123).
# Returns how many seconds this PC's clock is BEHIND (+) or AHEAD (-),
# or $null if the server did not answer. Independent of the Windows
# language, and doubles as the firewall check.
function Get-NtpOffset([string]$server) {
    $udp = $null
    try {
        $req = New-Object byte[] 48
        $req[0] = 0x1B                       # NTP version 3, client mode
        $udp = New-Object System.Net.Sockets.UdpClient
        $udp.Client.ReceiveTimeout = 3000
        $udp.Connect($server, 123)
        $t1 = [DateTime]::UtcNow
        [void]$udp.Send($req, $req.Length)
        $ep = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any), 0
        $resp = $udp.Receive([ref]$ep)
        $t4 = [DateTime]::UtcNow
        if ($resp.Length -lt 48) { return $null }
        $t2 = ConvertFrom-NtpTimestamp $resp 32   # server receive time
        $t3 = ConvertFrom-NtpTimestamp $resp 40   # server transmit time
        return ((($t2 - $t1).TotalSeconds + ($t3 - $t4).TotalSeconds) / 2)
    } catch {
        return $null
    } finally {
        if ($udp) { $udp.Close() }
    }
}

# First server in $TimeServers that answers. Returns @{ Server; Offset } or $null.
function Get-ClockOffset {
    foreach ($srv in $TimeServers) {
        $off = Get-NtpOffset $srv
        if ($null -ne $off) { return @{ Server = $srv; Offset = $off } }
    }
    return $null
}

function Format-Offset([double]$sec) {
    $txt = [Math]::Abs($sec).ToString('0.000', [Globalization.CultureInfo]::InvariantCulture) + ' s'
    if ([Math]::Abs($sec) -lt 0.0005) { return '0.000 s (exact)' }
    if ($sec -gt 0) { return "$txt BEHIND" } else { return "$txt AHEAD" }
}

function Invoke-TimeSetup($pc) {
    Write-Section 'DATE / TIME  (Monterrey - UTC-6, no daylight saving)'
    Write-Host '  The Dealer App countdowns use this PC''s clock. If it is a few seconds'
    Write-Host '  off, a countdown ends early (40 -> 27 instead of 13 -> 0) or freezes at 1s.'
    Write-Host ''

    $before = Get-ClockOffset
    if ($before) {
        Write-Host "  Clock right now : $(Format-Offset $before.Offset)  (checked against $($before.Server))"
    } else {
        Write-Warn "No internet time server answered ($($TimeServers -join ', '))."
        Write-Note 'The network may be blocking internet time (UDP port 123). The clock cannot stay in'
        Write-Note 'sync until that is allowed on the router / firewall. Setting it up anyway.'
    }
    Write-Host "  Time zone now   : $((Get-TimeZone).DisplayName)"
    Write-Host ''
    if (-not (Ask-YesNo '  Fix the time zone and keep the clock in sync automatically?' $true)) {
        Write-Skip 'Date / time left unchanged.'
        return
    }
    Write-Host ''

    # ---- 1. time zone
    $tzOk = $false
    try {
        Set-TimeZone -Id $TimeZoneId -ErrorAction Stop
        # Outdated data still applies the abolished summer time: next July would be UTC-5
        $tz   = Get-TimeZone
        $july = Get-Date -Year ((Get-Date).Year + 1) -Month 7 -Day 1 -Hour 12 -Minute 0 -Second 0
        if ($tz.GetUtcOffset($july) -ne $tz.BaseUtcOffset) {
            Write-Warn 'This PC''s time zone data is outdated: it still has the daylight saving time Mexico abolished in 2022.'
            Write-Note 'Using "(UTC-06:00) Central America" instead - same time as Monterrey all year.'
        } else { $tzOk = $true }
    } catch {
        Write-Warn "Time zone '$TimeZoneId' not found on this PC - using the fallback."
    }
    if (-not $tzOk) {
        try { Set-TimeZone -Id $TimeZoneFallbackId -ErrorAction Stop; $tzOk = $true }
        catch { Write-Fail "Could not set the time zone: $($_.Exception.Message)" }
    }
    if ($tzOk) {
        Write-Ok "Time zone: $((Get-TimeZone).DisplayName)"
        Add-Change "Time zone: $((Get-TimeZone).Id)"
    }
    # stop Windows from changing the time zone by itself based on location
    try { Set-Service -Name tzautoupdate -StartupType Disabled -ErrorAction Stop } catch { }

    # ---- 2. Windows Time service: always running, sync every hour
    try {
        $cfg = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config'
        $ntp = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient'
        Set-Service -Name w32time -StartupType Automatic
        Invoke-Native 'sc.exe' @('triggerinfo', 'w32time', 'delete') | Out-Null   # do not let it stop when "idle"
        Start-Service -Name w32time -ErrorAction SilentlyContinue
        $peers = ($TimeServers | ForEach-Object { "$_,0x9" }) -join ' '
        $r = Invoke-Native 'w32tm.exe' @('/config', "/manualpeerlist:$peers", '/syncfromflags:manual', '/reliable:no', '/update')
        if ($r.ExitCode -ne 0) { throw "w32tm /config failed: $($r.Text)" }
        Set-ItemProperty -Path $ntp -Name SpecialPollInterval   -Value 3600 -Type DWord  # every hour (default: every 7 days)
        Set-ItemProperty -Path $cfg -Name MaxAllowedPhaseOffset -Value 1    -Type DWord  # more than 1 s off: correct at once
        Set-ItemProperty -Path $cfg -Name MaxPosPhaseCorrection -Value -1   -Type DWord  # -1 = 0xFFFFFFFF: correct any error,
        Set-ItemProperty -Path $cfg -Name MaxNegPhaseCorrection -Value -1   -Type DWord  #   even a clock reset by a dead BIOS battery
        Restart-Service -Name w32time -Force
        Write-Ok "Windows Time service: always on, syncs every hour with $($TimeServers -join ', ')."
        Add-Change 'Clock: Windows Time syncs every hour'
    } catch {
        Write-Fail "Windows Time service: $($_.Exception.Message)"
    }

    # ---- 3. sync now (retry: right after a service restart w32tm often says "no data yet")
    $synced = $false
    $r = $null
    for ($i = 1; $i -le 5; $i++) {
        Start-Sleep -Seconds 2
        $r = Invoke-Native 'w32tm.exe' @('/resync')
        if ($r.ExitCode -eq 0) { $synced = $true; break }
    }
    if (-not $synced) { Write-Warn "Windows could not sync yet: $($r.Text)" }
    Start-Sleep -Seconds 1
    $after = Get-ClockOffset
    # Safety net: if the clock is still off by more than 1 s, correct it with the measured offset
    if ($after -and [Math]::Abs($after.Offset) -gt 1) {
        try {
            Set-Date -Adjust ([TimeSpan]::FromSeconds($after.Offset)) | Out-Null
            Start-Sleep -Seconds 1
            $after = Get-ClockOffset
        } catch { Write-Warn "Could not correct the clock directly: $($_.Exception.Message)" }
    }
    if ($after) {
        $line = if ($before) { "before $(Format-Offset $before.Offset), now $(Format-Offset $after.Offset)" } else { "now $(Format-Offset $after.Offset)" }
        if ([Math]::Abs($after.Offset) -le 1) {
            Write-Ok "Clock in sync: $line"
        } else {
            Write-Fail "Clock still off: $line"
        }
        # first in the summary list: this is the number that matters for the countdowns
        $State.Changes = @("Clock: $line") + $State.Changes
    } else {
        Write-Fail 'Could not check the clock: no internet time server answered (UDP port 123 blocked?).'
    }

    # ---- 4. background task: at every startup + daily
    $dir = Join-Path $env:ProgramData 'Kerma'
    $syncScript = Join-Path $dir 'Kerma-TimeSync.ps1'
    try {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        # Runs as SYSTEM, so only SYSTEM / Administrators may change it (Users: read only)
        $r = Invoke-Native 'icacls.exe' @($dir, '/inheritance:r', '/grant:r', '*S-1-5-18:(OI)(CI)F', '*S-1-5-32-544:(OI)(CI)F', '*S-1-5-32-545:(OI)(CI)RX')
        if ($r.ExitCode -ne 0) { Write-Warn "Could not lock down $dir permissions: $($r.Text)" }
        Set-Content -LiteralPath $syncScript -Value $TimeSyncScript -Encoding Ascii
    } catch {
        Write-Fail "Could not write $syncScript : $($_.Exception.Message)"
        return
    }
    $taskName = 'Kerma - Time Sync'
    $psArgs   = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$syncScript`""
    $created  = $false
    $err1 = ''
    $err2 = ''
    try {
        $a  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $psArgs
        $tS = New-ScheduledTaskTrigger -AtStartup
        $tD = New-ScheduledTaskTrigger -Daily -At $TimeSyncDailyAt
        $p  = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $st = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
        Register-ScheduledTask -TaskName $taskName -Action $a -Trigger @($tS, $tD) -Principal $p -Settings $st -Force -ErrorAction Stop | Out-Null
        $created = $true
    } catch { $err1 = ($_.Exception.Message -replace '\s+', ' ').Trim() }
    if (-not $created) {
        # fallback: schtasks.exe (one task per trigger)
        $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $syncScript"
        $r1 = Invoke-Native 'schtasks.exe' @('/create', '/tn', $taskName, '/tr', $tr, '/sc', 'onstart', '/ru', 'SYSTEM', '/rl', 'highest', '/f')
        $r2 = Invoke-Native 'schtasks.exe' @('/create', '/tn', "$taskName (daily)", '/tr', $tr, '/sc', 'daily', '/st', $TimeSyncDailyAt, '/ru', 'SYSTEM', '/rl', 'highest', '/f')
        if ($r1.ExitCode -eq 0 -and $r2.ExitCode -eq 0) { $created = $true }
        else { $err2 = "$($r1.Text) $($r2.Text)".Trim() }
    }
    if (-not $created) {
        Write-Fail 'Background time sync task NOT created.'
        Write-Note "  Method 1 (Task Scheduler): $err1"
        Write-Note "  Method 2 (schtasks.exe)  : $err2"
        return
    }

    # test-run it once so we know it really works
    try {
        Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
        $deadline = (Get-Date).AddSeconds(90)
        do { Start-Sleep -Seconds 2 } while ((Get-ScheduledTask -TaskName $taskName).State -eq 'Running' -and (Get-Date) -lt $deadline)
        $res = (Get-ScheduledTaskInfo -TaskName $taskName).LastTaskResult
        if ($res -eq 0) {
            Write-Ok "Background task '$taskName' created and tested: syncs at every startup and daily at $TimeSyncDailyAt."
        } else {
            Write-Warn "Task '$taskName' created, but its test run reported code $res. See $dir\timesync.log"
        }
    } catch {
        Write-Ok "Background task '$taskName' created (startup + daily at $TimeSyncDailyAt). Test run not possible: $($_.Exception.Message)"
    }
    Add-Change "Clock: background sync at startup + daily $TimeSyncDailyAt (log: $dir\timesync.log)"
}

# ============================== 3) RENAME ============================
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

# =============================== 4) LOGIN ============================
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

# =========================== 5) WINDOWS UPDATE =======================
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
        Initialize-RegistryKey $au
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

# ============================== 6) NETWORK ===========================
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

# ------------------------- app path helpers --------------------------
# Remembered paths live next to the script (so they travel on the USB
# stick to the next PC) and in C:\KermaSetup (kept across versions when
# the script is started with the one-line bootstrap).
$AppPathsFiles = @((Join-Path $PSScriptRoot 'app-paths.json'), 'C:\KermaSetup\app-paths.json')

function Get-SavedAppPaths {
    $h = @{}
    foreach ($f in $AppPathsFiles) {
        if (-not (Test-Path -LiteralPath $f)) { continue }
        try {
            $obj = Get-Content -LiteralPath $f -Raw | ConvertFrom-Json
            foreach ($prop in $obj.PSObject.Properties) { $h[$prop.Name] = [string]$prop.Value }
            return $h
        } catch { Write-Warn "Could not read $f - ignoring it." }
    }
    return $h
}

function Save-AppPaths($h) {
    $json = $h | ConvertTo-Json
    $saved = $false
    foreach ($f in $AppPathsFiles) {
        try {
            New-Item -ItemType Directory -Path (Split-Path -Path $f -Parent) -Force | Out-Null
            Set-Content -LiteralPath $f -Value $json -Encoding UTF8
            $saved = $true
        } catch { }
    }
    if (-not $saved) { Write-Warn 'Could not save the app paths (not critical - they will be asked again next time).' }
}

# Checks a path typed / pasted / browsed by the user.
# Returns @{ Ok; Path (full, resolved); Error; Info (product name etc.) }
function Test-AppPath([string]$raw) {
    $r = @{ Ok = $false; Path = ''; Error = ''; Info = '' }
    if ([string]::IsNullOrWhiteSpace($raw)) { $r.Error = 'no path given'; return $r }
    # accept Explorer's "Copy as path" (with quotes) and %VARIABLES%
    $p = [Environment]::ExpandEnvironmentVariables($raw.Trim().Trim('"').Trim("'").Trim())
    if (-not ($p -match '^[A-Za-z]:\\' -or $p -match '^\\\\')) {
        $r.Error = 'not a full path - it must start with a drive letter, e.g. C:\...'; return $r
    }
    # a shortcut (.lnk): use the program it points to
    if ([IO.Path]::GetExtension($p) -ieq '.lnk' -and (Test-Path -LiteralPath $p -PathType Leaf)) {
        $target = ''
        try { $target = (New-Object -ComObject WScript.Shell).CreateShortcut($p).TargetPath } catch { }
        if ([string]::IsNullOrWhiteSpace($target)) {
            $r.Error = 'this shortcut does not point to a normal program file - browse to the real .exe instead'; return $r
        }
        Write-Host "    (shortcut points to: $target)"
        $p = $target
    }
    if (Test-Path -LiteralPath $p -PathType Container) { $r.Error = 'that is a folder, not a program - pick the .exe inside it'; return $r }
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { $r.Error = 'file not found'; return $r }
    $ext = [IO.Path]::GetExtension($p).ToLower()
    if (@('.exe', '.bat', '.cmd') -notcontains $ext) { $r.Error = "'$ext' files are not programs - use a .exe, .bat or .cmd file"; return $r }

    $r.Ok   = $true
    $r.Path = (Resolve-Path -LiteralPath $p).ProviderPath
    if ($ext -eq '.exe') {
        $vi = (Get-Item -LiteralPath $r.Path).VersionInfo
        $parts = @($vi.ProductName, $vi.CompanyName) | Where-Object { $_ -and $_.Trim() }
        if ($vi.ProductVersion -and $vi.ProductVersion.Trim()) { $parts += "version $($vi.ProductVersion.Trim())" }
        $r.Info = if ($parts) { $parts -join ' - ' } else { 'program found (it has no product name inside)' }
    } else {
        $r.Info = 'batch script found'
    }
    return $r
}

# Opens the standard Windows "Open file" window. Returns '' if cancelled.
function Select-AppFile([string]$appName, [string]$near) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title            = "Kerma setup - select the program for: $appName"
        $dlg.Filter           = 'Programs and shortcuts (*.exe;*.bat;*.cmd;*.lnk)|*.exe;*.bat;*.cmd;*.lnk|All files (*.*)|*.*'
        $dlg.DereferenceLinks = $true
        $dlg.InitialDirectory = $env:ProgramFiles
        if ($near) {
            $d = Split-Path -Path $near -Parent -ErrorAction SilentlyContinue
            if ($d -and (Test-Path -LiteralPath $d -PathType Container)) { $dlg.InitialDirectory = $d }
        }
        # invisible top-most owner so the window never opens behind the console
        $owner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; ShowInTaskbar = $false }
        try { $res = $dlg.ShowDialog($owner) } finally { $owner.Dispose() }
        if ($res -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.FileName }
    } catch {
        Write-Warn "The file browser could not be opened ($($_.Exception.Message)). Paste the path instead."
    }
    return ''
}

# Asks until it gets a valid program path. Returns '' if the user skips.
function Get-AppPathInteractive($app, [string]$suggested) {
    $candidate = $suggested
    while ($true) {
        $chk = $null
        if ($candidate) { $chk = Test-AppPath $candidate }
        if ($chk -and $chk.Ok) {
            Write-Host "    Path : $($chk.Path)"
            Write-Host "    Check: OK - $($chk.Info)" -ForegroundColor Green
            $v = Read-Host '    [Enter] use it   [B] browse for another   [S] skip this app   or paste another path'
            if ([string]::IsNullOrWhiteSpace($v)) { return $chk.Path }
        } else {
            if ($candidate) { Write-Warn "$candidate  ->  $($chk.Error)" }
            else            { Write-Host "    No path known yet for $($app.Name)." }
            $v = Read-Host '    [Enter/B] browse for the file   [S] skip this app   or paste the full path'
            if ([string]::IsNullOrWhiteSpace($v)) { $v = 'B' }
        }
        $v = $v.Trim()
        if ($v -ieq 'S') { return '' }
        if ($v -ieq 'B') {
            Write-Host '    Opening the file browser...'
            $near   = if ($chk -and $chk.Ok) { $chk.Path } else { $candidate }
            $picked = Select-AppFile $app.Name $near
            if ($picked) { $candidate = $picked } else { Write-Host '    Nothing selected.' }
            continue
        }
        $candidate = $v
    }
}

# Wired adapters: wake-on-LAN on, never powered off to save energy, no
# energy-efficient Ethernet. Advanced properties are set with -NoRestart
# (applied after the restart) so the network does not drop mid-setup.
function Invoke-NetworkTuning {
    $done = @()
    $nics = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.MediaType -eq '802.3' })
    foreach ($n in $nics) {
        try { Set-NetAdapterPowerManagement -Name $n.Name -WakeOnMagicPacket Enabled -ErrorAction Stop } catch { }
        try { Set-NetAdapterPowerManagement -Name $n.Name -AllowComputerToTurnOffDevice Disabled -ErrorAction Stop } catch { }
        $props = @{ '*WakeOnMagicPacket' = '1'; '*ModernStandbyWoLMagicPacket' = '1'; '*EEE' = '0'; 'EnableGreenEthernet' = '0' }
        foreach ($kw in $props.Keys) {
            if (Get-NetAdapterAdvancedProperty -Name $n.Name -RegistryKeyword $kw -ErrorAction SilentlyContinue) {
                try { Set-NetAdapterAdvancedProperty -Name $n.Name -RegistryKeyword $kw -RegistryValue $props[$kw] -NoRestart -ErrorAction Stop } catch { }
            }
        }
        $done += "$($n.Name) (MAC $($n.MacAddress))"
    }
    try {
        $pw = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
        Set-ItemProperty -Path $pw -Name HiberbootEnabled -Value 0 -Type DWord   # fast startup off: wake-on-LAN works from shutdown
    } catch { }
    try {
        Get-NetConnectionProfile -ErrorAction Stop | Where-Object { $_.NetworkCategory -eq 'Public' } |
            ForEach-Object { Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private -ErrorAction Stop }
    } catch { }
    if ($done.Count) {
        Write-Ok "Network: wake-on-LAN on, power saving off for $($done -join ', ')."
        Write-Note '  Wake-on-LAN must also be enabled in the BIOS (see the README checklist).'
        Add-Change "Tuning: wake-on-LAN on ($($done -join ', '))"
    } else {
        Write-Skip 'Network: no wired adapter found.'
    }
}

# ============================ 7) PC TUNING ============================
function Invoke-PcTuning($pc) {
    Write-Section 'PC TUNING  (power, USB, notifications)'
    Write-Host '  - Screen never turns off, the PC never sleeps or hibernates'
    Write-Host '  - USB devices are never suspended (avoids Stream Deck / Scarlett dropouts)'
    Write-Host '  - Windows notifications and the screen saver are turned off'
    Write-Host '  - Taskbar: no search box, no Task view, no Widgets, no Resume'
    Write-Host '  - Wired network: wake-on-LAN on, never powered off, no energy-efficient Ethernet'
    Write-Host ''
    $isStaff = ($pc.Type -eq 'Staff')
    if ($isStaff) { Write-Note '>> Supervisor PC: these settings are meant for table / office PCs. Default here is N.'; Write-Host '' }
    if (-not (Ask-YesNo '  Apply these settings?' (-not $isStaff))) { Write-Skip 'PC tuning left unchanged.'; return }

    $sub = '2a737441-1930-4402-8d77-b2bebba308a3'   # USB settings
    $sel = '48e6b7a6-50f5-4782-a5d4-53bb50f7e206'   # USB selective suspend
    $cmds = @(
        @('/change', 'monitor-timeout-ac', '0'),
        @('/change', 'standby-timeout-ac', '0'),
        @('/change', 'hibernate-timeout-ac', '0'),
        @('/hibernate', 'off')
    )
    $bad = 0
    foreach ($c in $cmds) {
        $r = Invoke-Native 'powercfg.exe' $c
        if ($r.ExitCode -ne 0) { $bad++; Write-Warn "powercfg $($c -join ' '): $($r.Text)" }
    }
    # USB selective suspend: some PCs / power plans do not have this setting at all
    Invoke-Native 'powercfg.exe' @('/attributes', $sub, $sel, '-ATTRIB_HIDE') | Out-Null
    $usb = Invoke-Native 'powercfg.exe' @('/setacvalueindex', 'SCHEME_CURRENT', $sub, $sel, '0')
    $usbText = if ($usb.ExitCode -eq 0) { 'USB never suspended' } else { 'USB suspend setting not present on this PC (nothing to change)' }
    Invoke-Native 'powercfg.exe' @('/setactive', 'SCHEME_CURRENT') | Out-Null
    if ($bad -eq 0) {
        Write-Ok "Power: screen always on, no sleep / hibernation. $usbText."
        Add-Change "Tuning: screen always on, no sleep. $usbText"
    }

    # Per-user settings (HKCU = the account this elevated window runs as)
    try {
        $pn = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'
        Initialize-RegistryKey $pn
        Set-ItemProperty -Path $pn -Name ToastEnabled -Value 0 -Type DWord
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name ScreenSaveActive -Value '0' -Type String
        Write-Ok "Notifications and screen saver off for user '$env:USERNAME'."
        Add-Change "Tuning: notifications + screen saver off ($env:USERNAME)"
    } catch { Write-Warn "Notifications / screen saver: $($_.Exception.Message)" }

    # Taskbar: Search = Hide, Task view / Widgets / Resume = Off
    $tb = @()
    try {
        $sr = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
        Initialize-RegistryKey $sr
        Set-ItemProperty -Path $sr -Name SearchboxTaskbarMode -Value 0 -Type DWord
        $tb += 'search hidden'
    } catch { Write-Warn "Taskbar search: $($_.Exception.Message)" }
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    try { Set-ItemProperty -Path $adv -Name ShowTaskViewButton -Value 0 -Type DWord; $tb += 'Task view off' }
    catch { Write-Warn "Task view: $($_.Exception.Message)" }
    # Recent Windows 11 blocks writing TaskbarDa directly, so Widgets is also turned off by policy
    try { Set-ItemProperty -Path $adv -Name TaskbarDa -Value 0 -Type DWord -ErrorAction Stop } catch { }
    try {
        $dsh = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
        Initialize-RegistryKey $dsh
        Set-ItemProperty -Path $dsh -Name AllowNewsAndInterests -Value 0 -Type DWord
        $tb += 'Widgets off'
    } catch { Write-Warn "Widgets: $($_.Exception.Message)" }
    try {
        $res = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'
        Initialize-RegistryKey $res
        Set-ItemProperty -Path $res -Name IsResumeAllowed -Value 0 -Type DWord
        $tb += 'Resume off'
    } catch { Write-Warn "Resume: $($_.Exception.Message)" }
    if ($tb.Count) {
        Write-Ok "Taskbar: $($tb -join ', ')."
        Add-Change "Tuning: taskbar $($tb -join ', ')"
        # restart Explorer so the taskbar shows the change now (it comes back by itself)
        $console0 = ''
        try { $console0 = [string](Get-CimInstance Win32_ComputerSystem).UserName } catch { }
        if (-not $console0 -or ($console0 -split '\\')[-1] -ieq $env:USERNAME) {
            Get-Process -Name 'explorer' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }
    Invoke-NetworkTuning

    $console = ''
    try { $console = [string](Get-CimInstance Win32_ComputerSystem).UserName } catch { }
    if ($console -and ($console -split '\\')[-1] -ine $env:USERNAME) {
        Write-Warn "The PC is logged on as '$console' but this window runs as '$env:USERNAME' (another admin"
        Write-Note '  account was used at the permission prompt). Notifications / screen saver were changed for'
        Write-Note "  '$env:USERNAME' only. Run the script from the table account itself to apply them there."
    }
}

# ====================== 7b) REMOVE PREINSTALLED APPS ==================
function Test-AppNameMatch([string]$name, [string[]]$patterns) {
    foreach ($pat in $patterns) { if ($name -like $pat) { return $true } }
    return $false
}

# Microsoft 365 / Office installed with Click-to-Run (not a Store app)
function Get-ClickToRunOffice {
    $keys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
    return @(Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.UninstallString -and $_.UninstallString -match 'OfficeClickToRun\.exe' -and $_.DisplayName })
}

function Invoke-RemoveJunk($pc) {
    Write-Section 'REMOVE PREINSTALLED APPS  (Solitaire, Xbox, Teams, Office trial...)'
    # ---- 1. Store apps (installed for any user, or provisioned for new users)
    # -AllUsers fails when Windows cannot resolve an account (for example
    # right after the user rename above): then work on this user only.
    $allUsers = $true
    try { $installed = @(Get-AppxPackage -AllUsers -ErrorAction Stop) }
    catch {
        $allUsers = $false
        Write-Note "  (Windows could not list the apps of every account: $($_.Exception.Message)"
        Write-Note '   Removing them for this account and for new accounts instead.)'
        $installed = @(Get-AppxPackage -ErrorAction SilentlyContinue)
    }
    $provisioned = @()
    try { $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop) }
    catch { Write-Warn "Could not list the apps for new accounts: $($_.Exception.Message)" }
    $names = @(@($installed | ForEach-Object { $_.Name }) + @($provisioned | ForEach-Object { $_.DisplayName }) | Sort-Object -Unique |
        Where-Object { (Test-AppNameMatch $_ $RemoveApps) -and -not (Test-AppNameMatch $_ $NeverRemove) })
    if ($names.Count -eq 0) {
        Write-Ok 'No junk Store apps found.'
    } else {
        Write-Host "  Found $($names.Count) preinstalled apps to remove:"
        Write-Host ('    ' + ($names -join ', '))
        Write-Host ''
        if (Ask-YesNo '  Remove them (and stop Windows from installing suggested apps)?' $true) {
            $removed = 0
            $failed = @()
            foreach ($n in $names) {
                $ok = $true
                foreach ($pkg in @($installed | Where-Object { $_.Name -eq $n })) {
                    try {
                        if ($allUsers) {
                            try { Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop }
                            catch { Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop }
                        } else { Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop }
                    } catch { $ok = $false }
                }
                foreach ($pp in @($provisioned | Where-Object { $_.DisplayName -eq $n })) {
                    try { Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null } catch { $ok = $false }
                }
                if ($ok) { $removed++ } else { $failed += $n }
            }
            Write-Ok "$removed apps removed."
            if ($failed.Count) { Write-Warn "Windows did not let these be removed (harmless): $($failed -join ', ')" }
            Add-Change "Removed $removed preinstalled apps"

            # stop suggested apps (Candy Crush & co.) from coming back
            try {
                $cc = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
                Initialize-RegistryKey $cc
                Set-ItemProperty -Path $cc -Name DisableWindowsConsumerFeatures -Value 1 -Type DWord
                $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
                Initialize-RegistryKey $cdm
                foreach ($v in @('SilentInstalledAppsEnabled', 'PreInstalledAppsEnabled', 'OemPreInstalledAppsEnabled',
                                 'SystemPaneSuggestionsEnabled', 'SubscribedContent-338388Enabled')) {
                    Set-ItemProperty -Path $cdm -Name $v -Value 0 -Type DWord
                }
                Write-Ok 'Windows will no longer install suggested apps by itself.'
            } catch { Write-Warn "Could not turn off suggested apps: $($_.Exception.Message)" }
        } else { Write-Skip 'Store apps kept.' }
    }

    # ---- 2. Microsoft 365 / Office trial (Click-to-Run)
    Write-Host ''
    $office = Get-ClickToRunOffice
    if ($office.Count -eq 0) {
        Write-Ok 'No Microsoft 365 / Office installed.'
    } else {
        foreach ($o in $office) { Write-Host "  Installed: $($o.DisplayName)" }
        if (Ask-YesNo '  Uninstall Microsoft 365 / Office? (takes a few minutes)' $true) {
            Get-Process -Name 'WINWORD', 'EXCEL', 'POWERPNT', 'OUTLOOK', 'ONENOTE', 'MSACCESS', 'MSPUB' -ErrorAction SilentlyContinue |
                Stop-Process -Force -ErrorAction SilentlyContinue
            foreach ($o in $office) {
                Write-Host "  Uninstalling $($o.DisplayName)..."
                $cmd = "$($o.UninstallString) DisplayLevel=False"
                Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$cmd`"" -Wait -WindowStyle Hidden
            }
            $left = Get-ClickToRunOffice
            if ($left.Count -eq 0) {
                Write-Ok 'Microsoft 365 / Office uninstalled.'
                Add-Change 'Removed Microsoft 365 / Office'
                $State.NeedsRestart = $true
            } else {
                Write-Warn "Still installed: $(@($left | ForEach-Object { $_.DisplayName }) -join ', '). Remove it from Settings > Apps."
            }
        } else { Write-Skip 'Microsoft 365 / Office kept.' }
    }

    # ---- 3. OneDrive (per user on Windows 11: removed for the account running this window)
    Write-Host ''
    $odPaths = @("$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe", "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
                 "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe")
    $odSetup = @("$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    $odPresent = [bool](@($odPaths | Where-Object { Test-Path -LiteralPath $_ }).Count)
    if (-not $odPresent) {
        Write-Ok 'OneDrive is not installed.'
    } else {
        if (Ask-YesNo '  Uninstall OneDrive?' $true) {
            Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            $w = Get-WingetPath
            if ($w) { Invoke-Native $w @('uninstall', '--id', 'Microsoft.OneDrive', '--exact', '--silent', '--accept-source-agreements', '--disable-interactivity') | Out-Null }
            if (@($odPaths | Where-Object { Test-Path -LiteralPath $_ }).Count -and $odSetup) {
                Start-Process -FilePath $odSetup -ArgumentList '/uninstall' -Wait -WindowStyle Hidden
            }
            if (@($odPaths | Where-Object { Test-Path -LiteralPath $_ }).Count) {
                Write-Warn 'OneDrive is still there. Remove it from Settings > Apps.'
            } else {
                Write-Ok "OneDrive uninstalled (for user '$env:USERNAME')."
                Add-Change 'Removed OneDrive'
            }
        } else { Write-Skip 'OneDrive kept.' }
    }
}

# ========================= 8) INSTALL PROGRAMS =======================
function Test-Internet {
    try {
        Invoke-WebRequest -Uri 'https://api.github.com' -Method Head -UseBasicParsing -TimeoutSec 15 | Out-Null
        return $true
    } catch { return $false }
}

function Get-WingetPath {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -LiteralPath $alias) { return $alias }
    # Elevated windows sometimes miss the alias: use the App Installer package folder
    $pkg = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Filter 'Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe' -Directory -ErrorAction SilentlyContinue |
        Sort-Object -Property Name -Descending | Select-Object -First 1
    if ($pkg -and (Test-Path -LiteralPath (Join-Path $pkg.FullName 'winget.exe'))) { return (Join-Path $pkg.FullName 'winget.exe') }
    return $null
}

# Finds winget; on a fresh PC tries to register / repair it first.
function Initialize-Winget {
    $w = Get-WingetPath
    if ($w) { return $w }
    Write-Host '  winget not found - trying to activate it (can take a minute)...'
    try { Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop; Start-Sleep -Seconds 3 } catch { }
    $w = Get-WingetPath
    if ($w) { return $w }
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Repository PSGallery -Force -Scope AllUsers -AllowClobber
        Import-Module Microsoft.WinGet.Client
        Repair-WinGetPackageManager -AllUsers -Latest -Force | Out-Null
    } catch { Write-Warn "Could not repair winget: $($_.Exception.Message)" }
    return (Get-WingetPath)
}

function Get-LatestReleaseAsset([string]$repo, [string]$pattern) {
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -UseBasicParsing -Headers @{ 'User-Agent' = 'Kerma-PCSetup' }
    $asset = $rel.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
    if (-not $asset) { throw "no file matching '$pattern' in the latest release of $repo ($($rel.tag_name))" }
    return @{ Tag = [string]$rel.tag_name; Name = [string]$asset.name; Url = [string]$asset.browser_download_url }
}

function Install-KermaPackage($key, $p) {
    $marker = if ($p.Check) { Join-Path (Split-Path -Path $p.Check -Parent) ".kerma-version-$key" } else { '' }
    if ($p.Requires -and -not (Test-Path -LiteralPath $Packages[$p.Requires].Check)) {
        Write-Skip "$($p.Name): needs $($Packages[$p.Requires].Name), which is not installed."
        return
    }

    if ($p.Source -eq 'winget') {
        if ($p.Check -and (Test-Path -LiteralPath $p.Check)) { Write-Ok "$($p.Name): already installed."; return }
        if (-not $script:Winget) { $script:Winget = Initialize-Winget }
        if (-not $script:Winget) {
            Write-Fail "$($p.Name): winget is not available on this PC, so it cannot be installed automatically."
            Write-Note '  On Windows LTSC / IoT editions winget is not included. Install it by hand.'
            return
        }
        if (-not $p.Check) {
            $pre = Invoke-Native $script:Winget @('list', '--id', $p.Id, '--exact', '--accept-source-agreements', '--disable-interactivity')
            if ($pre.ExitCode -eq 0) { Write-Ok "$($p.Name): already installed."; return }
        }
        $base = @('install', '--id', $p.Id, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
        Write-Host "  Installing $($p.Name) (winget $($p.Id))..."
        $r = Invoke-Native $script:Winget ($base + @('--scope', 'machine'))
        if ($r.ExitCode -ne 0 -and -not ($p.Check -and (Test-Path -LiteralPath $p.Check))) {
            # some packages have no machine-wide installer: try the default scope
            $r = Invoke-Native $script:Winget $base
        }
        $listed = (Invoke-Native $script:Winget @('list', '--id', $p.Id, '--exact', '--accept-source-agreements', '--disable-interactivity')).ExitCode -eq 0
        $ok = if ($p.Check) { Test-Path -LiteralPath $p.Check } else { $listed }
        if ($ok -or $listed) {
            Write-Ok "$($p.Name) installed."
            Add-Change "Installed: $($p.Name)"
        } else {
            $tail = if ($r.Text.Length -gt 300) { $r.Text.Substring($r.Text.Length - 300) } else { $r.Text }
            Write-Fail "$($p.Name) not installed (winget exit code $($r.ExitCode)): $tail"
        }
        return
    }

    # ---- GitHub release (.msi or .zip)
    $rel = Get-LatestReleaseAsset $p.Repo $p.Asset
    $installedTag = ''
    if ($marker -and (Test-Path -LiteralPath $marker)) { $installedTag = (Get-Content -LiteralPath $marker -Raw).Trim() }
    if ($p.Check -and (Test-Path -LiteralPath $p.Check)) {
        if ($rel.Name -notmatch '\.zip$' -or $installedTag -eq $rel.Tag) { Write-Ok "$($p.Name): already installed$(if ($installedTag) { " ($installedTag)" })."; return }
        Write-Host "  $($p.Name): updating $(if ($installedTag) { $installedTag } else { 'installed copy' }) -> $($rel.Tag)"
    }
    $dl = 'C:\KermaSetup\downloads'
    New-Item -ItemType Directory -Path $dl -Force | Out-Null
    $file = Join-Path $dl $rel.Name
    Write-Host "  Downloading $($p.Name) $($rel.Tag) ($($rel.Name))..."
    Invoke-WebRequest -Uri $rel.Url -OutFile $file -UseBasicParsing

    if ($rel.Name -match '\.msi$') {
        $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$file`" /qn /norestart" -Wait -PassThru
        if ($proc.ExitCode -eq 3010) { $State.NeedsRestart = $true }
        if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) { Write-Fail "$($p.Name): the installer returned code $($proc.ExitCode)."; return }
    } elseif ($rel.Name -match '\.zip$') {
        if ($p.Process) { Get-Process -Name $p.Process -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1 }
        New-Item -ItemType Directory -Path $p.InstallTo -Force | Out-Null
        if ($p.Inner) {
            # the release zip contains one zip per platform: take the Windows one
            $tmp = Join-Path $dl "$key-$($rel.Tag)"
            Expand-Archive -LiteralPath $file -DestinationPath $tmp -Force
            $inner = Get-ChildItem -LiteralPath $tmp -Recurse -File | Where-Object { $_.Name -match $p.Inner } | Select-Object -First 1
            if (-not $inner) { Write-Fail "$($p.Name): no file matching '$($p.Inner)' inside $($rel.Name)."; return }
            Expand-Archive -LiteralPath $inner.FullName -DestinationPath $p.InstallTo -Force
        } else {
            Expand-Archive -LiteralPath $file -DestinationPath $p.InstallTo -Force   # its own config file is kept
        }
        if ($p.UserWritable) {
            $r = Invoke-Native 'icacls.exe' @($p.UserWritable, '/grant', '*S-1-5-32-545:(OI)(CI)M')
            if ($r.ExitCode -ne 0) { Write-Warn "Could not let users write in $($p.UserWritable): $($r.Text)" }
        }
    } else {
        Write-Fail "$($p.Name): do not know how to install '$($rel.Name)'."
        return
    }
    if ($p.Check -and -not (Test-Path -LiteralPath $p.Check)) { Write-Fail "$($p.Name): installed, but $($p.Check) is missing."; return }
    if ($marker) { Set-Content -LiteralPath $marker -Value $rel.Tag -Encoding Ascii }
    Write-Ok "$($p.Name) $($rel.Tag) installed."
    Add-Change "Installed: $($p.Name) $($rel.Tag)"
}

# Lists connected Focusrite devices (USB vendor 1235). Returns how many.
function Show-FocusriteDevices {
    $dev = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like 'USB\VID_1235*' })
    foreach ($d in $dev) { Write-Host "  Focusrite device connected: $($d.FriendlyName)  [$($d.InstanceId)]" }
    return $dev.Count
}

function Invoke-InstallPrograms($pc) {
    Write-Section 'INSTALL PROGRAMS'
    $list = @($InstallByType[$pc.Type])
    $focusrite = Show-FocusriteDevices
    if ($ScarlettPackageId -and ($focusrite -gt 0 -or ($ScarlettPcTypes -contains $pc.Type))) {
        $Packages['Focusrite'].Id = $ScarlettPackageId
        $list += 'Focusrite'
    }
    if ($list.Count -eq 0) { Write-Skip 'No programs defined for this PC type.'; return }

    Write-Host '  Programs for this PC:'
    foreach ($k in $list) {
        $p = $Packages[$k]
        $st = if (-not $p.Check) { 'install / check' } elseif (Test-Path -LiteralPath $p.Check) { 'installed' } else { 'to install' }
        Write-Host ("    - {0,-30} {1}" -f $p.Name, $st)
    }
    Write-Host ''
    if (-not (Ask-YesNo '  Install / update them now?' $true)) { Write-Skip 'Programs left as they are.'; return }
    if (-not (Test-Internet)) {
        Write-Fail 'No internet connection (github.com does not answer) - programs NOT installed.'
        Write-Note '  Check the network section above, then run the script again.'
        return
    }
    $script:Winget = $null
    foreach ($k in $list) {
        Write-Host ''
        try { Install-KermaPackage $k $Packages[$k] }
        catch { Write-Fail "$($Packages[$k].Name): $($_.Exception.Message)" }
    }
}

# ========================= 9) PROGRAM SETTINGS =======================
function Get-AssetsDir {
    foreach ($d in @((Join-Path $PSScriptRoot 'assets'), (Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'assets'))) {
        if (Test-Path -LiteralPath $d -PathType Container) { return (Resolve-Path -LiteralPath $d).ProviderPath }
    }
    return $null
}

# Sets [Appearance] Theme=<id> in OBS's user.ini (OBS 31+ keeps the theme
# there), leaving every other line as it is. Returns $true if it was set.
function Set-ObsTheme([string]$obsDir, [string]$themeId) {
    $userIni   = Join-Path $obsDir 'user.ini'
    $globalIni = Join-Path $obsDir 'global.ini'
    if (-not (Test-Path -LiteralPath $userIni) -and (Test-Path -LiteralPath $globalIni)) {
        # OBS older than 31 kept everything in global.ini and copies it to
        # user.ini on its first start after updating; if user.ini already
        # exists at that moment the copy fails with an error box. So only
        # create user.ini when that copy is already done or not needed.
        $g = Get-Content -LiteralPath $globalIni -ErrorAction SilentlyContinue
        $last = 0L
        $m = $g | Select-String -Pattern '^\s*LastVersion\s*=\s*(\d+)' | Select-Object -First 1
        if ($m) { $last = [long]$m.Matches[0].Groups[1].Value }
        $migrated = [bool]($g | Select-String -Pattern '^\s*Pre31Migrated\s*=\s*true' -Quiet)
        if ($last -gt 0 -and $last -lt (31L * 16777216) -and -not $migrated) { return $false }
    }
    $lines = @()
    $bom = $true
    $nl = "`r`n"
    if (Test-Path -LiteralPath $userIni) {
        $bytes = [IO.File]::ReadAllBytes($userIni)
        $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $text = [Text.Encoding]::UTF8.GetString($bytes)
        if ($bom) { $text = $text.Substring(1) }
        if ($text -notmatch "`r`n") { $nl = "`n" }
        $lines = @($text -split "`r?`n")
        if ($lines.Count -gt 0 -and $lines[-1] -eq '') { $lines = @($lines[0..($lines.Count - 2)]) }
    }
    $out = New-Object System.Collections.Generic.List[string]
    $inSection = $false; $done = $false
    foreach ($l in $lines) {
        if ($l -match '^\s*\[(.+)\]\s*$') {
            if ($inSection -and -not $done) { $out.Add("Theme=$themeId"); $done = $true }
            $inSection = ($Matches[1] -eq 'Appearance')
        } elseif ($inSection -and $l -match '^\s*Theme\s*=') {
            if (-not $done) { $out.Add("Theme=$themeId"); $done = $true }
            continue
        }
        $out.Add($l)
    }
    if (-not $done) {
        if ($inSection) { $out.Add("Theme=$themeId") }
        else {
            if ($out.Count -gt 0 -and $out[$out.Count - 1] -ne '') { $out.Add('') }
            $out.Add('[Appearance]'); $out.Add("Theme=$themeId")
        }
    }
    [IO.File]::WriteAllText($userIni, (($out -join $nl) + $nl), (New-Object System.Text.UTF8Encoding($bom)))
    return $true
}

function Invoke-ProgramSettings($pc) {
    Write-Section 'PROGRAM SETTINGS  (HDMI Mirror, OBS, Stream Deck)'
    if ($pc.Type -eq 'Staff') { Write-Skip 'Does not apply to supervisor PCs.'; return }
    $assets = Get-AssetsDir
    if (-not $assets) { Write-Skip 'No assets folder next to the script - nothing to apply.'; return }
    if (-not (Ask-YesNo '  Apply the saved settings for this PC?' $true)) { Write-Skip 'Program settings left unchanged.'; return }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    # ---- HDMI Mirror: assets\hdmi-mirror\<PC key>.json (or default.json)
    $hmExe = $Packages['HdmiMirror'].Check
    $hmSrc = @((Join-Path $assets "hdmi-mirror\$($pc.Key).json"), (Join-Path $assets 'hdmi-mirror\default.json')) |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    Write-Host ''
    if (-not (Test-Path -LiteralPath $hmExe)) {
        Write-Skip 'HDMI Mirror: not installed on this PC.'
    } elseif (-not $hmSrc) {
        Write-Skip "HDMI Mirror: no saved config (assets\hdmi-mirror\$($pc.Key).json)."
    } else {
        $dst = Join-Path (Split-Path -Path $hmExe -Parent) 'hdmimirror.config.json'
        $go = $true
        if (Test-Path -LiteralPath $dst) {
            Write-Note '  HDMI Mirror already has a config on this PC (it may have been adjusted by hand).'
            $go = Ask-YesNo '  Replace it with the saved one? (a backup is kept)' $false
            if ($go) { Copy-Item -LiteralPath $dst -Destination "$dst.bak-$stamp" -Force }
        }
        if ($go) {
            Get-Process -Name 'HdmiMirror' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Copy-Item -LiteralPath $hmSrc -Destination $dst -Force
            Write-Ok "HDMI Mirror: config applied from $(Split-Path -Path $hmSrc -Leaf)."
            Add-Change "Settings: HDMI Mirror config $(Split-Path -Path $hmSrc -Leaf)"
        } else { Write-Skip 'HDMI Mirror: config kept.' }
    }

    # ---- OBS: assets\obs\ is copied into %APPDATA%\obs-studio\ (scenes, profiles, global.ini, plugin settings)
    Write-Host ''
    $obsSrc = Join-Path $assets 'obs'
    # service.json holds the stream key: it is never taken from the (public) repo
    $obsFiles = @(Get-ChildItem -LiteralPath $obsSrc -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'README.md' -and $_.Name -ne 'service.json' })
    if (-not (Test-Path -LiteralPath $Packages['OBS'].Check)) {
        Write-Skip 'OBS: not installed on this PC.'
    } elseif ($obsFiles.Count -eq 0) {
        Write-Skip 'OBS: no saved scenes / profile in assets\obs.'
    } else {
        $obsDst = Join-Path $env:APPDATA 'obs-studio'
        if (Get-Process -Name 'obs64' -ErrorAction SilentlyContinue) {
            Write-Note '  OBS is open. It must be closed so it does not overwrite the copied files.'
            if (Ask-YesNo '  Close OBS now?' $true) { Get-Process -Name 'obs64' | Stop-Process -Force; Start-Sleep -Seconds 2 }
        }
        if (Get-Process -Name 'obs64' -ErrorAction SilentlyContinue) {
            Write-Skip 'OBS: still open - settings not copied.'
        } else {
            if (Test-Path -LiteralPath $obsDst) {
                Copy-Item -LiteralPath $obsDst -Destination "$obsDst.bak-$stamp" -Recurse -Force
            }
            foreach ($f in $obsFiles) {
                $rel = $f.FullName.Substring($obsSrc.Length).TrimStart('\')
                $to = Join-Path $obsDst $rel
                New-Item -ItemType Directory -Path (Split-Path -Path $to -Parent) -Force | Out-Null
                Copy-Item -LiteralPath $f.FullName -Destination $to -Force
            }
            Write-Ok "OBS: $($obsFiles.Count) settings files copied to $obsDst (backup: obs-studio.bak-$stamp)."
            Add-Change 'Settings: OBS scenes / profile / theme'
            # Kerma look: themes\Kerma.ovt was just copied; make it the active theme
            if (Test-Path -LiteralPath (Join-Path $obsDst "themes\$ObsThemeFile")) {
                if (Ask-YesNo '  Use the Kerma theme (colors) in OBS?' $true) {
                    try {
                        if (Set-ObsTheme $obsDst $ObsThemeId) {
                            Write-Ok 'OBS: Kerma theme selected.'
                            Add-Change 'Settings: OBS Kerma theme'
                        } else {
                            Write-Warn 'OBS: settings from an older OBS not migrated yet. Open OBS once, close it and run this again (or pick Settings > Appearance > Kerma).'
                        }
                    } catch { Write-Fail "OBS theme: $($_.Exception.Message)" }
                } else { Write-Skip 'OBS: theme left as it was (Kerma is still available in Settings > Appearance).' }
            }
        }
    }

    # ---- VST3 plugins: assets\vst3\* -> C:\Program Files\Common Files\VST3
    Write-Host ''
    $vstSrc = Join-Path $assets 'vst3'
    $vstItems = @(Get-ChildItem -LiteralPath $vstSrc -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*.vst3' })
    if ($vstItems.Count -eq 0) {
        Write-Skip 'VST3: no plugins in assets\vst3.'
    } else {
        $vstDst = Join-Path $env:CommonProgramFiles 'VST3'
        New-Item -ItemType Directory -Path $vstDst -Force | Out-Null
        if (Get-Process -Name 'obs64' -ErrorAction SilentlyContinue) { Write-Note '  OBS is open: restart it to load new VST3 plugins.' }
        foreach ($v in $vstItems) { Copy-Item -LiteralPath $v.FullName -Destination $vstDst -Recurse -Force }
        Write-Ok "VST3: $(@($vstItems | ForEach-Object { $_.Name }) -join ', ') copied to $vstDst."
        Add-Change "Settings: VST3 $(@($vstItems | ForEach-Object { $_.Name }) -join ', ')"
    }

    # ---- Stream Deck: assets\streamdeck\<Game>.streamDeckProfile
    Write-Host ''
    $sdExe = $Packages['StreamDeck'].Check
    $sdProfile = if ($pc.Game) { Join-Path $assets "streamdeck\$($pc.Game).streamDeckProfile" } else { '' }
    if (-not (Test-Path -LiteralPath $sdExe)) {
        Write-Skip 'Stream Deck: not installed on this PC.'
    } elseif (-not $pc.Game) {
        Write-Skip 'Stream Deck: no game set for this PC.'
    } elseif (-not (Test-Path -LiteralPath $sdProfile)) {
        Write-Skip "Stream Deck: no saved profile (assets\streamdeck\$($pc.Game).streamDeckProfile)."
    } else {
        # Opening the profile file makes the Stream Deck app import it
        Start-Process -FilePath $sdProfile
        Write-Ok "Stream Deck: profile '$($pc.Game)' sent to the Stream Deck app."
        Write-Note '  If the Stream Deck app asks to import the profile, accept it.'
        Add-Change "Settings: Stream Deck profile $($pc.Game)"
    }
}

# ============================ 10) APP AUTOSTART =======================
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

    # Tasks are tied to the built-in Users group by its fixed SID
    # (S-1-5-32-545), not to one account: this works whatever the
    # account is called, survives user / computer renames, and does not
    # depend on the Windows language ("Users" vs "Usuarios").
    # The apps start in the session of whoever logs on (table PCs have
    # a single account), elevated if that account is an administrator.

    Write-Host "  Tasks will be named '$tableName - <App> Startup', scripts in $dir"
    $saved = Get-SavedAppPaths

    foreach ($k in $pc.Apps) {
        $app      = $Apps[$k]
        $taskName = "$tableName - $($app.Name) Startup"
        Write-Host ''
        if ($app.Replaces) {
            $old = "$tableName - $($app.Replaces) Startup"
            if (Get-ScheduledTask -TaskName $old -ErrorAction SilentlyContinue) {
                Unregister-ScheduledTask -TaskName $old -Confirm:$false -ErrorAction SilentlyContinue
                Write-Ok "Old '$($app.Replaces)' autostart task removed - replaced by $($app.Name)."
            }
        }
        if ($app.SelfStarts) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Skip "$($app.Name): it starts by itself at logon - no task needed (an old one was removed, if any)."
            continue
        }
        if ($app.Note) { Write-Note $app.Note }

        if (-not (Ask-YesNo "  Enable $($app.Name) auto-start?" $true)) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Skip "$($app.Name) (existing task removed, if there was one)."
            continue
        }
        # -- which program file? (remembered path first, then the table's suggestion)
        $suggested = ''
        $cands = @($saved[$k], $app.Path)
        # A path remembered on another table may live in THAT PC's user
        # folder (C:\Users\<other>\Desktop\...): try the same place here.
        if ($saved[$k] -match '^[A-Za-z]:\\Users\\[^\\]+\\(.+)$') {
            $cands = @($saved[$k], (Join-Path $env:USERPROFILE $Matches[1]), $app.Path)
        }
        foreach ($cand in $cands) {
            if ($cand -and (Test-AppPath $cand).Ok) { $suggested = $cand; break }
        }
        if (-not $suggested -and $saved[$k]) { $suggested = $saved[$k] }   # show why it broke

        $path = ''
        if ($Unattended) {
            $chk = if ($suggested) { Test-AppPath $suggested } else { $null }
            if (-not ($chk -and $chk.Ok)) {
                Write-Warn "$($app.Name): no valid path known - SKIPPED (existing task left untouched). Run once interactively to set it."
                continue
            }
            $path = $chk.Path
            Write-Host "    Path -> $path (unattended)"
        } else {
            while ($true) {
                $path = Get-AppPathInteractive $app $suggested
                if (-not $path) { break }
                if (Ask-YesNo '    -> Test it now? (opens the app once so you can see it starts)' $false) {
                    try {
                        Start-Process -FilePath $path -WorkingDirectory (Split-Path -Path $path -Parent)
                        if (Ask-YesNo '    Did it open correctly? (close it again afterwards)' $true) { break }
                        Write-Host '    OK - pick the right file then.'
                        $suggested = $path
                        continue
                    } catch {
                        Write-Fail "It did not start: $($_.Exception.Message)"
                        $suggested = $path
                        continue
                    }
                }
                break
            }
            if (-not $path) {
                Write-Skip "$($app.Name) (no path chosen - existing task left untouched)."
                continue
            }
        }
        if ($saved[$k] -ne $path) { $saved[$k] = $path; Save-AppPaths $saved }

        $max  = Ask-YesNo '    -> Open maximized?' ([bool]$app.Maximize)
        $flag = if ($max) { '/max' } else { '' }

        $lines = @('@echo off', "timeout /t $($app.Delay) /nobreak >nul")
        $lines += "cd /d `"$(Split-Path -Path $path -Parent)`""
        if ($app.PreLaunch) { $lines += $app.PreLaunch }
        $start = "start $flag `"`" `"$path`""
        if ($app.Args) { $start += " $($app.Args)" }
        $lines += $start
        $bat = Join-Path $dir "$($app.Id).bat"
        Set-Content -LiteralPath $bat -Value $lines -Encoding Ascii

        $err1 = ''
        $err2 = ''
        $created = $false
        # Method 1: logon task for the Users group (see note above)
        try {
            $taskAction    = New-ScheduledTaskAction -Execute $bat -WorkingDirectory $dir
            $taskTrigger   = New-ScheduledTaskTrigger -AtLogOn
            $taskPrincipal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest
            $taskSettings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
            Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Force -ErrorAction Stop | Out-Null
            $created = $true
        } catch {
            $err1 = ($_.Exception.Message -replace '\s+', ' ').Trim()
        }
        # Method 2 (fallback): schtasks.exe, same as the old .bat version
        if (-not $created) {
            $r = Invoke-Native 'schtasks.exe' @('/create', '/tn', $taskName, '/tr', "`"$bat`"", '/sc', 'onlogon', '/rl', 'highest', '/f')
            if ($r.ExitCode -eq 0) { $created = $true }
            else { $err2 = $r.Text }
        }
        if ($created) {
            Write-Ok "$($app.Name) task created (delay $($app.Delay)s$(if ($max) { ', maximized' }))."
            Add-Change "Autostart: $($app.Name)"
        } else {
            Write-Fail "$($app.Name) task NOT created."
            Write-Note "  Method 1 (Task Scheduler): $err1"
            Write-Note "  Method 2 (schtasks.exe)  : $err2"
            Write-Note '  Send these two lines to IT. The launcher script is ready in:'
            Write-Note "  $bat"
        }
    }
    Write-Host ''
    Write-Note 'To make an app open on the correct monitor, move its window there by hand once - most apps (OBS included) remember the position.'
}

# =========================== 10b) AUDIO ===============================
function Initialize-AudioModule {
    if (Get-Module -ListAvailable -Name AudioDeviceCmdlets) { Import-Module AudioDeviceCmdlets; return $true }
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        Install-Module -Name AudioDeviceCmdlets -Repository PSGallery -Force -Scope AllUsers -AllowClobber
        Import-Module AudioDeviceCmdlets
        return $true
    } catch {
        Write-Warn "Could not install the audio module (AudioDeviceCmdlets): $($_.Exception.Message)"
        return $false
    }
}

function Invoke-AudioSetup($pc) {
    Write-Section 'AUDIO  (Windows sounds, Scarlett)'
    Write-Host '  - Windows sounds off (no beeps or chimes on the stream), no startup sound'
    Write-Host '  - Focusrite Scarlett as the default microphone and speakers, if one is connected'
    Write-Host ''
    if (-not (Ask-YesNo '  Apply these audio settings?' $true)) { Write-Skip 'Audio left unchanged.'; return }

    # ---- Windows sounds: scheme "No sounds" for this account + no startup sound
    try {
        Set-ItemProperty -Path 'HKCU:\AppEvents\Schemes' -Name '(Default)' -Value '.None'
        Get-ChildItem -Path 'HKCU:\AppEvents\Schemes\Apps' -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -eq '.Current' } |
            ForEach-Object { Set-ItemProperty -Path $_.PSPath -Name '(Default)' -Value '' -ErrorAction SilentlyContinue }
        $boot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation'
        Initialize-RegistryKey $boot
        Set-ItemProperty -Path $boot -Name DisableStartupSound -Value 1 -Type DWord
        Write-Ok "Windows sounds off (user '$env:USERNAME') and no startup sound."
        Add-Change "Audio: Windows sounds off ($env:USERNAME)"
    } catch { Write-Warn "Windows sounds: $($_.Exception.Message)" }

    # ---- Scarlett as default microphone
    Write-Host ''
    $fr = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like 'USB\VID_1235*' })
    if ($fr.Count -eq 0) { Write-Skip 'Scarlett: no Focusrite connected.'; return }
    if (-not (Initialize-AudioModule)) { return }
    $devs = @(Get-AudioDevice -List | Where-Object { $_.Name -match 'Focusrite|Scarlett' })
    $rec  = $devs | Where-Object { $_.Type -eq 'Recording' } | Select-Object -First 1
    $play = $devs | Where-Object { $_.Type -eq 'Playback' } | Select-Object -First 1
    if (-not $rec) {
        Write-Warn 'The Scarlett is connected but Windows does not show it as a microphone yet.'
        Write-Note '  Unplug and plug it again (or restart) after Focusrite Control 2 is installed, then run the script again.'
        return
    }
    Set-AudioDevice -ID $rec.ID | Out-Null
    Write-Ok "Default microphone: $($rec.Name)"
    Add-Change "Audio: default microphone $($rec.Name)"
    if ($ScarlettAsDefaultPlayback -and $play) {
        Set-AudioDevice -ID $play.ID | Out-Null
        Write-Ok "Default speakers: $($play.Name)"
        Add-Change "Audio: default speakers $($play.Name)"
    }
}

# =========================== 10d) WALLPAPER ===========================
# assets\wallpaper\<PC key>.jpg = the table's template (name already in
# the picture). Otherwise default.jpg + the PC label drawn by the script.
# Under it: computer name, IP and script version, so anyone connecting
# with RustDesk sees at once which PC it is.
function New-KermaWallpaper([string]$template, [string]$label, [string]$info, [string]$out) {
    Add-Type -AssemblyName System.Drawing
    $src = [System.Drawing.Image]::FromFile($template)
    $bmp = New-Object System.Drawing.Bitmap 1920, 1080
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $g.DrawImage($src, 0, 0, 1920, 1080)
        $px = [System.Drawing.GraphicsUnit]::Pixel
        if ($label) {
            $family = 'Segoe UI'
            try { [void](New-Object System.Drawing.FontFamily 'Bahnschrift'); $family = 'Bahnschrift' } catch { }
            $f1 = New-Object System.Drawing.Font($family, 32, [System.Drawing.FontStyle]::Bold, $px)
            $g.DrawString($label.ToUpper(), $f1, [System.Drawing.Brushes]::White, 146, 826)
            $f1.Dispose()
        }
        $f2 = New-Object System.Drawing.Font('Segoe UI', 21, [System.Drawing.FontStyle]::Regular, $px)
        $br = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(215, 196, 186, 236))
        $g.DrawString($info, $f2, $br, 146, 905)
        $f2.Dispose()
        $br.Dispose()
    } finally { $g.Dispose(); $src.Dispose() }
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 95L
    $bmp.Save($out, $codec, $ep)
    $bmp.Dispose()
}

function Invoke-Wallpaper($pc) {
    Write-Section 'WALLPAPER'
    $assets = Get-AssetsDir
    $own = if ($assets) { Join-Path $assets "wallpaper\$($pc.Key).jpg" } else { '' }
    $def = if ($assets) { Join-Path $assets 'wallpaper\default.jpg' } else { '' }
    if ($own -and (Test-Path -LiteralPath $own)) { $template = $own; $label = '' }
    elseif ($def -and (Test-Path -LiteralPath $def)) { $template = $def; $label = $pc.FullName }
    else { Write-Skip 'No wallpaper templates in assets\wallpaper.'; return }
    $host_ = if ($State.HostRenamed) { $pc.Hostname } else { $env:COMPUTERNAME }
    $ip = ''
    try {
        $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Sort-Object -Property RouteMetric | Select-Object -First 1
        $ip = (Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -ErrorAction Stop | Select-Object -First 1).IPAddress
    } catch { }
    $info = "$host_    $(if ($ip) { $ip } else { 'no IP' })    Kerma PC Setup v$ScriptVersion"
    Write-Host "  Template : $(Split-Path -Path $template -Leaf)$(if ($label) { "  + label '$label'" })"
    Write-Host "  Text     : $info"
    Write-Host ''
    if (-not (Ask-YesNo '  Set this wallpaper?' $true)) { Write-Skip 'Wallpaper left unchanged.'; return }

    $dir = Join-Path $env:ProgramData 'Kerma'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $out = Join-Path $dir 'wallpaper.jpg'
    New-KermaWallpaper $template $label $info $out

    $desk = 'HKCU:\Control Panel\Desktop'
    Set-ItemProperty -Path $desk -Name WallpaperStyle -Value '10' -Type String   # fill
    Set-ItemProperty -Path $desk -Name TileWallpaper -Value '0' -Type String
    if (-not ('KermaWallpaperApi' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class KermaWallpaperApi {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SystemParametersInfo(int action, int param, string value, int flags);
}
'@
    }
    # SPI_SETDESKWALLPAPER = 20, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE = 3
    if ([KermaWallpaperApi]::SystemParametersInfo(20, 0, $out, 3)) {
        Write-Ok "Wallpaper set for user '$env:USERNAME' ($out)."
        Add-Change "Wallpaper: $(Split-Path -Path $template -Leaf) + $info"
    } else {
        Write-Warn "Windows did not accept the wallpaper. The picture is ready in $out."
    }
    if ($State.HostRenamed -and $pc.Hostname -ne $env:COMPUTERNAME) {
        Write-Note '  The wallpaper already shows the new computer name, which applies after the restart.'
    }
}

# ========================= 10c) STATUS PANEL ==========================
# What the status collector should look for on this PC (pc.json)
function Get-StatusConfig($pc) {
    $saved = Get-SavedAppPaths
    $list = [ordered]@{}
    foreach ($k in @($InstallByType[$pc.Type])) {
        $p = $Packages[$k]
        if (-not $p -or -not $p.Check) { continue }
        $proc = if ($p.Process) { $p.Process } elseif ($p.Check -match '\.exe$') { [IO.Path]::GetFileNameWithoutExtension($p.Check) } else { '' }
        $list[$k] = @{ name = $p.Name; check = $p.Check; process = $proc; autostart = $false }
    }
    foreach ($k in @($pc.Apps)) {
        $a = $Apps[$k]
        $path = if ($saved[$k]) { $saved[$k] } else { $a.Path }
        if (-not $path) { continue }
        $proc = if ($path -match '\.exe$') { [IO.Path]::GetFileNameWithoutExtension($path) } else { '' }
        if ($list.Contains($k)) { $list[$k].autostart = $true; continue }
        $list[$k] = @{ name = $a.Name; check = $path; process = $proc; autostart = $true }
    }
    return [ordered]@{
        key = $pc.Key; label = $pc.Label; type = $pc.Type; game = $pc.Game
        script_version = $ScriptVersion; apps = @($list.Values)
    }
}

function Invoke-StatusPanel($pc) {
    Write-Section 'STATUS PANEL  (kermasetup.netlify.app/estado)'
    Write-Host '  This PC will send its state every 5 minutes: clock, apps, disk, network.'
    Write-Host ''
    if (-not (Ask-YesNo '  Register this PC in the status panel?' $true)) { Write-Skip 'Not registered.'; return }

    $dir = Join-Path $env:ProgramData 'Kerma'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $r = Invoke-Native 'icacls.exe' @($dir, '/inheritance:r', '/grant:r', '*S-1-5-18:(OI)(CI)F', '*S-1-5-32-544:(OI)(CI)F', '*S-1-5-32-545:(OI)(CI)RX')
    if ($r.ExitCode -ne 0) { Write-Warn "Could not lock down $dir permissions: $($r.Text)" }
    $collector = Join-Path $dir 'Kerma-Status.ps1'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Kerma-Status.ps1') -Destination $collector -Force
    (Get-StatusConfig $pc) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $dir 'pc.json') -Encoding Ascii

    # ---- write key: asked once with the panel PIN, the PIN itself is never stored
    $keyFile = Join-Path $dir 'status.key'
    if (Test-Path -LiteralPath $keyFile) {
        Write-Ok 'This PC is already registered in the panel.'
    } else {
        $pin = $PanelPin
        if (-not $pin -and -not $Unattended) {
            $sec = Read-Host '  Panel PIN (input is hidden; Enter to skip)' -AsSecureString
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
            try { $pin = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        }
        if (-not $pin) { Write-Skip 'No PIN given - the PC is not registered (run the script again to do it).'; return }
        try {
            $resp = Invoke-RestMethod -Uri "$PanelBase/api/register" -Method Post -Headers @{ 'x-pin' = $pin } -UseBasicParsing -TimeoutSec 20
            Set-Content -LiteralPath $keyFile -Value $resp.key -Encoding Ascii
            Write-Ok 'PC registered in the status panel.'
        } catch {
            $code = 0
            try { $code = [int]$_.Exception.Response.StatusCode } catch { }
            if ($code -eq 401) { Write-Fail 'Wrong panel PIN - the PC is not registered.' }
            elseif ($code -eq 429) { Write-Fail 'Too many wrong PINs: the panel is locked for 15 minutes.' }
            else { Write-Fail "Could not reach the panel: $($_.Exception.Message)" }
            return
        }
        $pin = $null
    }

    # ---- task: every 5 minutes and at startup, as SYSTEM
    $taskName = 'Kerma - Status'
    $psArgs   = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$collector`""
    $created = $false
    $err1 = ''
    try {
        $a  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $psArgs
        $tS = New-ScheduledTaskTrigger -AtStartup
        $tR = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5)
        $p  = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $st = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 3)
        Register-ScheduledTask -TaskName $taskName -Action $a -Trigger @($tS, $tR) -Principal $p -Settings $st -Force -ErrorAction Stop | Out-Null
        $created = $true
    } catch { $err1 = ($_.Exception.Message -replace '\s+', ' ').Trim() }
    if (-not $created) {
        $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $collector"
        $r2 = Invoke-Native 'schtasks.exe' @('/create', '/tn', $taskName, '/tr', $tr, '/sc', 'minute', '/mo', '5', '/ru', 'SYSTEM', '/rl', 'highest', '/f')
        if ($r2.ExitCode -eq 0) { $created = $true } else { Write-Fail "Status task NOT created: $err1 / $($r2.Text)"; return }
    }

    # ---- send the first report now
    try {
        Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
        $deadline = (Get-Date).AddSeconds(90)
        do { Start-Sleep -Seconds 2 } while ((Get-ScheduledTask -TaskName $taskName).State -eq 'Running' -and (Get-Date) -lt $deadline)
        $res = (Get-ScheduledTaskInfo -TaskName $taskName).LastTaskResult
        if ($res -eq 0) { Write-Ok "First report sent. See it at $PanelBase/estado" }
        else { Write-Warn "The first report failed (code $res). See $dir\status.log" }
    } catch { Write-Warn "Could not send the first report now: $($_.Exception.Message)" }
    Add-Change 'Status panel: reports every 5 minutes'
}

# ============================== 11) FINISH ===========================
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
# -- review mode: show the state of this PC, change nothing
if ($Check) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $installed = Join-Path $env:ProgramData 'Kerma\Kerma-Status.ps1'
    $collector = if (Test-Path -LiteralPath $installed) { $installed } else { Join-Path $PSScriptRoot 'Kerma-Status.ps1' }
    & $collector -Print -NoSend
    Write-Host ''
    Read-Host '  Press Enter to close' | Out-Null
    exit
}

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

# -- downloads: GitHub needs TLS 1.2; the progress bar makes big downloads very slow
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

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

    # Each section is isolated: if one fails, it is reported and the rest still runs
    $sections = @('Invoke-TimeSetup', 'Invoke-Rename', 'Invoke-LoginSetup', 'Invoke-WindowsUpdateSetup',
                  'Invoke-NetworkSetup', 'Invoke-PcTuning', 'Invoke-RemoveJunk', 'Invoke-InstallPrograms',
                  'Invoke-AudioSetup', 'Invoke-ProgramSettings', 'Invoke-AppAutostart', 'Invoke-Wallpaper', 'Invoke-StatusPanel')
    foreach ($sec in $sections) {
        try { & $sec $selected }
        catch {
            Write-Host ''
            Write-Fail "Section stopped by an error: $($_.Exception.Message)"
            Write-Note "  ($sec, line $($_.InvocationInfo.ScriptLineNumber)). Continuing with the next section."
            Add-Change "ERROR in $($sec -replace '^Invoke-', ''): $($_.Exception.Message)"
        }
    }
    Invoke-Finish
} catch {
    Write-Host ''
    Write-Fail $_.Exception.Message
} finally {
    try { Stop-Transcript | Out-Null } catch { }
    if (-not $Unattended) { Write-Host ''; Read-Host '  Press Enter to close' | Out-Null }
}
