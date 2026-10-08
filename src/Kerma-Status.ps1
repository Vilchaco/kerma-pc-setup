<#
=====================================================================
  Kerma Games - PC status (installed by Kerma-PCSetup.ps1)
=====================================================================
  Collects the state of this PC and sends it to the status panel
  (https://kermasetup.netlify.app/estado). Runs as SYSTEM every 5
  minutes and at startup (task "Kerma - Status"), from
  C:\ProgramData\Kerma, next to pc.json (what this PC should have)
  and status.key (write key, never the panel PIN).

    -Print   show the report on screen (review mode)
    -NoSend  do not send it to the panel

  Plain ASCII on purpose (Windows PowerShell 5.1).
=====================================================================
#>
[CmdletBinding()]
param([switch]$Print, [switch]$NoSend)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$PanelUrl    = 'https://kermasetup.netlify.app/api/status'
$TimeServers = @('time.cloudflare.com', 'time.windows.com')
$Here        = $PSScriptRoot
$Warnings    = New-Object System.Collections.ArrayList

function Get-Safe([scriptblock]$sb) { try { & $sb } catch { $null } }

# ------------------------------------------------------------- config
$cfg = $null
foreach ($f in @((Join-Path $Here 'pc.json'), 'C:\ProgramData\Kerma\pc.json')) {
    if (Test-Path -LiteralPath $f) { $cfg = Get-Safe { Get-Content -LiteralPath $f -Raw | ConvertFrom-Json }; if ($cfg) { break } }
}
if (-not $cfg) { [void]$Warnings.Add('pc.json not found: this PC was not configured with Kerma PC Setup 4.3 or later.') }

# ------------------------------------------------------------- clock (raw NTP, same as the setup script)
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
function Get-NtpOffset([string]$server) {
    $udp = $null
    try {
        $req = New-Object byte[] 48
        $req[0] = 0x1B
        $udp = New-Object System.Net.Sockets.UdpClient
        $udp.Client.ReceiveTimeout = 3000
        $udp.Connect($server, 123)
        $t1 = [DateTime]::UtcNow
        [void]$udp.Send($req, $req.Length)
        $ep = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any), 0
        $resp = $udp.Receive([ref]$ep)
        $t4 = [DateTime]::UtcNow
        if ($resp.Length -lt 48) { return $null }
        $t2 = ConvertFrom-NtpTimestamp $resp 32
        $t3 = ConvertFrom-NtpTimestamp $resp 40
        return ((($t2 - $t1).TotalSeconds + ($t3 - $t4).TotalSeconds) / 2)
    } catch { return $null } finally { if ($udp) { $udp.Close() } }
}

$clock = @{ offset_s = $null; server = $null; service = $null; timezone = (Get-Safe { (Get-TimeZone).Id }) }
foreach ($srv in $TimeServers) {
    $o = Get-NtpOffset $srv
    if ($null -ne $o) { $clock.offset_s = [Math]::Round($o, 3); $clock.server = $srv; break }
}
if ($null -eq $clock.offset_s) { [void]$Warnings.Add('No internet time server answered (UDP 123 blocked or no network).') }
$clock.service = [string](Get-Safe { (Get-Service -Name w32time).Status })

# ------------------------------------------------------------- system
$os   = Get-Safe { Get-CimInstance Win32_OperatingSystem }
$cs   = Get-Safe { Get-CimInstance Win32_ComputerSystem }
$bios = Get-Safe { Get-CimInstance Win32_BIOS }
$cpu  = Get-Safe { Get-CimInstance Win32_Processor | Select-Object -First 1 }
$cv   = Get-Safe { Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' }
$disk = Get-Safe { Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" }

$windows = @{
    caption         = if ($os) { [string]$os.Caption } else { $null }
    build           = if ($os) { [string]$os.BuildNumber } else { $null }
    display_version = if ($cv) { [string]$cv.DisplayVersion } else { $null }
    boot_time       = if ($os) { $os.LastBootUpTime.ToUniversalTime().ToString('o') } else { $null }
}
$hardware = @{
    manufacturer = if ($cs) { [string]$cs.Manufacturer } else { $null }
    model        = if ($cs) { [string]$cs.Model } else { $null }
    serial       = if ($bios) { [string]$bios.SerialNumber } else { $null }
    cpu          = if ($cpu) { ([string]$cpu.Name).Trim() } else { $null }
    ram_gb       = if ($cs) { [Math]::Round($cs.TotalPhysicalMemory / 1GB, 1) } else { $null }
}
$diskInfo = if ($disk) { @{ free_gb = [Math]::Round($disk.FreeSpace / 1GB, 1); total_gb = [Math]::Round($disk.Size / 1GB, 1) } } else { $null }
if ($diskInfo -and $diskInfo.free_gb -lt 10) { [void]$Warnings.Add("Low disk space on C: ($($diskInfo.free_gb) GB free).") }
$user = if ($cs -and $cs.UserName) { [string]$cs.UserName } else { $null }

# ------------------------------------------------------------- network
$network = @()
foreach ($a in @(Get-Safe { Get-NetAdapter -Physical | Sort-Object -Property ifIndex })) {
    if (-not $a) { continue }
    $ip  = Get-Safe { Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1 }
    $gw  = Get-Safe { Get-NetRoute -InterfaceIndex $a.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Select-Object -First 1 }
    $ipi = Get-Safe { Get-NetIPInterface -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction Stop }
    $dns = Get-Safe { (Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction Stop).ServerAddresses }
    $network += @{
        name    = [string]$a.Name
        status  = [string]$a.Status
        mac     = [string]$a.MacAddress
        ip      = if ($ip) { [string]$ip.IPAddress } else { $null }
        prefix  = if ($ip) { [int]$ip.PrefixLength } else { $null }
        gateway = if ($gw) { [string]$gw.NextHop } else { $null }
        dhcp    = if ($ipi) { [string]$ipi.Dhcp -eq 'Enabled' } else { $null }
        dns     = @($dns | Where-Object { $_ })
        speed   = [string]$a.LinkSpeed
        type    = [string]$a.MediaType
    }
}

# ------------------------------------------------------------- apps (from pc.json)
$apps = @()
if ($cfg -and $cfg.apps) {
    foreach ($app in $cfg.apps) {
        $installed = $false
        $version = $null
        if ($app.check) {
            $installed = Test-Path -LiteralPath $app.check
            if ($installed -and $app.check -match '\.exe$') { $version = Get-Safe { ([string](Get-Item -LiteralPath $app.check).VersionInfo.ProductVersion).Trim() } }
        }
        $running = $null
        if ($app.process) { $running = [bool](Get-Safe { Get-Process -Name $app.process -ErrorAction Stop }) }
        $apps += @{ name = [string]$app.name; installed = $installed; version = $version; running = $running; autostart = [bool]$app.autostart; path = [string]$app.check }
    }
}

# ------------------------------------------------------------- scheduled tasks created by the setup
$tasks = @()
foreach ($t in @(Get-Safe { Get-ScheduledTask | Where-Object { $_.TaskName -like 'Kerma - *' -or $_.TaskName -like '* Startup' } })) {
    if (-not $t) { continue }
    $info = Get-Safe { Get-ScheduledTaskInfo -TaskName $t.TaskName -TaskPath $t.TaskPath }
    $tasks += @{
        name        = [string]$t.TaskName
        state       = [string]$t.State
        last_result = if ($info) { [int64]$info.LastTaskResult } else { $null }
        last_run    = if ($info -and $info.LastRunTime -and $info.LastRunTime.Year -gt 2000) { $info.LastRunTime.ToUniversalTime().ToString('o') } else { $null }
    }
}

# ------------------------------------------------------------- audio
$focusrite = @(Get-Safe { Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object { $_.InstanceId -like 'USB\VID_1235*' } | ForEach-Object { [string]$_.FriendlyName } } | Where-Object { $_ })
$audio = @{ default_recording = $null; default_playback = $null }
if (Get-Module -ListAvailable -Name AudioDeviceCmdlets) {
    try {
        Import-Module AudioDeviceCmdlets -ErrorAction Stop
        $audio.default_recording = [string](Get-AudioDevice -Recording).Name
        $audio.default_playback  = [string](Get-AudioDevice -Playback).Name
    } catch { }
}

# ------------------------------------------------------------- report
$status = [ordered]@{
    schema         = 1
    key            = if ($cfg) { [string]$cfg.key } else { $null }
    label          = if ($cfg) { [string]$cfg.label } else { $env:COMPUTERNAME }
    type           = if ($cfg) { [string]$cfg.type } else { $null }
    game           = if ($cfg) { [string]$cfg.game } else { $null }
    hostname       = $env:COMPUTERNAME
    script_version = if ($cfg) { [string]$cfg.script_version } else { $null }
    collected_at   = (Get-Date).ToUniversalTime().ToString('o')
    user           = $user
    windows        = $windows
    hardware       = $hardware
    disk           = $diskInfo
    clock          = $clock
    network        = $network
    apps           = $apps
    tasks          = $tasks
    focusrite      = $focusrite
    audio          = $audio
    warnings       = @($Warnings)
}

if ($Print) {
    function Show([string]$k, $v, [string]$color = 'Gray') { Write-Host ('  {0,-18} ' -f $k) -NoNewline; Write-Host ([string]$v) -ForegroundColor $color }
    Write-Host ''
    Write-Host '===============================================' -ForegroundColor Cyan
    Write-Host "  PC REVIEW - $($status.label) ($env:COMPUTERNAME)" -ForegroundColor Cyan
    Write-Host '===============================================' -ForegroundColor Cyan
    Show 'Type / game'   "$($status.type) $($status.game)"
    Show 'Setup version' $status.script_version
    Show 'Windows'       "$($windows.caption) $($windows.display_version) (build $($windows.build))"
    Show 'Booted'        $(if ($os) { $os.LastBootUpTime } else { '?' })
    Show 'Logged on'     $(if ($user) { $user } else { 'nobody' })
    Show 'Hardware'      "$($hardware.manufacturer) $($hardware.model) - S/N $($hardware.serial)"
    if ($diskInfo) { Show 'Disk C:' "$($diskInfo.free_gb) GB free of $($diskInfo.total_gb) GB" $(if ($diskInfo.free_gb -lt 10) { 'Yellow' } else { 'Green' }) }
    if ($null -ne $clock.offset_s) {
        $c = if ([Math]::Abs($clock.offset_s) -le 0.5) { 'Green' } elseif ([Math]::Abs($clock.offset_s) -le 2) { 'Yellow' } else { 'Red' }
        Show 'Clock offset' "$($clock.offset_s) s ($($clock.server)), service $($clock.service), $($clock.timezone)" $c
    } else { Show 'Clock offset' 'unknown - no time server answered' 'Red' }
    foreach ($n in $network) {
        $mode = if ($n.dhcp) { 'DHCP' } else { 'static' }
        Show "Net $($n.name)" "$($n.status) $($n.ip) $mode gw $($n.gateway) dns $($n.dns -join ',') mac $($n.mac)" $(if ($n.status -eq 'Up') { 'Green' } else { 'DarkGray' })
    }
    foreach ($a in $apps) {
        $txt = if (-not $a.installed) { 'NOT installed' } elseif ($a.running) { "running  $($a.version)" } else { "installed, not running  $($a.version)" }
        $col = if (-not $a.installed) { 'Red' } elseif ($a.running) { 'Green' } elseif ($a.autostart -and $user) { 'Red' } else { 'Gray' }
        Show "App $($a.name)" $txt $col
    }
    foreach ($t in $tasks) { Show 'Task' "$($t.name): $($t.state), last result $($t.last_result)" $(if ($t.last_result -eq 0 -or $null -eq $t.last_result) { 'Gray' } else { 'Yellow' }) }
    Show 'Focusrite' $(if ($focusrite.Count) { $focusrite -join ', ' } else { 'not connected' })
    if ($audio.default_recording) { Show 'Microphone' $audio.default_recording }
    if ($audio.default_playback) { Show 'Speakers' $audio.default_playback }
    foreach ($w in $Warnings) { Write-Host "  [WARN] $w" -ForegroundColor Yellow }
    Write-Host ''
}

if ($NoSend) { return }
$keyFile = Join-Path $Here 'status.key'
if (-not (Test-Path -LiteralPath $keyFile)) {
    if ($Print) { Write-Host '  (not sent: this PC is not registered in the status panel)' -ForegroundColor DarkGray }
    return
}
$log = Join-Path $Here 'status.log'
try {
    $key = (Get-Content -LiteralPath $keyFile -Raw).Trim()
    $json = $status | ConvertTo-Json -Depth 6 -Compress
    $body = [Text.Encoding]::UTF8.GetBytes($json)
    Invoke-RestMethod -Uri $PanelUrl -Method Post -Headers @{ 'x-kerma-key' = $key } -Body $body -ContentType 'application/json; charset=utf-8' -TimeoutSec 20 -UseBasicParsing | Out-Null
    if ($Print) { Write-Host '  Sent to the status panel.' -ForegroundColor Green }
} catch {
    Add-Content -LiteralPath $log -Value ('{0}  send failed: {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $_.Exception.Message)
    try {
        $lines = @(Get-Content -LiteralPath $log)
        if ($lines.Count -gt 300) { $lines | Select-Object -Last 200 | Set-Content -LiteralPath $log }
    } catch { }
    if ($Print) { Write-Host "  Could not send to the status panel: $($_.Exception.Message)" -ForegroundColor Yellow }
    exit 1
}
