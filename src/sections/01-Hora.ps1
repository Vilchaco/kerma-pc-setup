# =====================================================================
#  HORA: zona de Monterrey + reloj sincronizado con internet (cada hora,
#  al encender y a diario). Las cuentas atras de la Dealer App dependen
#  de ello.
# =====================================================================

# Script de la tarea "Kerma - Time Sync" (como SYSTEM, al encender y a
# diario). Tras un apagon espera a la red y fuerza la sincronizacion.
# Se escribe en ASCII en C:\ProgramData\Kerma: mensajes en ingles.
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

# Pregunta la hora directamente a un servidor (NTP por UDP 123). Devuelve
# los segundos que el reloj va ATRASADO (+) o ADELANTADO (-), o $null si
# no contesta. No depende del idioma de Windows y sirve de prueba del cortafuegos.
function Get-NtpOffset([string]$server) {
    $udp = $null
    try {
        $req = New-Object byte[] 48
        $req[0] = 0x1B                       # NTP v3, modo cliente
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
    } catch {
        return $null
    } finally {
        if ($udp) { $udp.Close() }
    }
}

# Primer servidor que contesta. Devuelve @{ Server; Offset } o $null.
function Get-ClockOffset {
    foreach ($srv in $TimeServers) {
        $off = Get-NtpOffset $srv
        if ($null -ne $off) { return @{ Server = $srv; Offset = $off } }
    }
    return $null
}

function Format-Offset([double]$sec) {
    $txt = [Math]::Abs($sec).ToString('0.000', [Globalization.CultureInfo]::InvariantCulture) + ' s'
    if ([Math]::Abs($sec) -lt 0.0005) { return (L '0.000 s (exact)' '0.000 s (exacto)') }
    if ($sec -gt 0) { return ("$txt " + (L 'BEHIND' 'ATRASADO')) } else { return ("$txt " + (L 'AHEAD' 'ADELANTADO')) }
}

function Invoke-TimeSetup($pc) {
    Write-Section (L 'DATE / TIME  (Monterrey - UTC-6, no daylight saving)' 'FECHA Y HORA  (Monterrey - UTC-6, sin horario de verano)')
    Write-Host (L '  The Dealer App countdowns use this PC''s clock. A few seconds off and a countdown' '  Las cuentas atrás de la Dealer App usan el reloj de este PC. Con unos segundos de')
    Write-Host (L '  ends early (40 -> 27 instead of 13 -> 0) or freezes at 1s.' '  desfase terminan antes (de 40 a 27 en vez de 13 a 0) o se quedan en 1 s.')
    Write-Host ''

    $before = Get-ClockOffset
    if ($before) {
        Write-Host ((L '  Clock right now : {0}  (checked against {1})' '  Reloj ahora     : {0}  (comparado con {1})') -f (Format-Offset $before.Offset), $before.Server)
    } else {
        Write-Warn ((L 'No internet time server answered ({0}).' 'Ningún servidor de hora de internet contesta ({0}).') -f ($TimeServers -join ', '))
        Write-Note (L 'The network may be blocking internet time (UDP port 123). Setting it up anyway.' 'Puede que la red bloquee la hora de internet (puerto UDP 123). Se configura igualmente.')
    }
    Write-Host ((L '  Time zone now   : {0}' '  Zona horaria    : {0}') -f (Get-TimeZone).DisplayName)
    Write-Host ''
    if (-not (Ask-YesNo (L '  Fix the time zone and keep the clock in sync automatically?' '  ¿Poner la zona horaria y mantener el reloj sincronizado?') ([bool]$Prof.Time))) {
        Write-Skip (L 'Date / time left unchanged.' 'Fecha y hora sin cambios.')
        return
    }
    Write-Host ''

    # ---- 1. zona horaria
    $tzOk = $false
    try {
        Set-TimeZone -Id $TimeZoneId -ErrorAction Stop
        # Datos viejos aplican aun el horario de verano abolido: julio seria UTC-5
        $tz   = Get-TimeZone
        $july = Get-Date -Year ((Get-Date).Year + 1) -Month 7 -Day 1 -Hour 12 -Minute 0 -Second 0
        if ($tz.GetUtcOffset($july) -ne $tz.BaseUtcOffset) {
            Write-Warn (L 'This PC''s time zone data is outdated (it still has the summer time Mexico abolished in 2022).' 'Los datos de zona horaria de este PC son viejos (aún tienen el horario de verano que México abolió en 2022).')
            Write-Note (L 'Using "(UTC-06:00) Central America" instead - same time as Monterrey all year.' 'Se usa "(UTC-06:00) América Central": la misma hora que Monterrey todo el año.')
        } else { $tzOk = $true }
    } catch {
        Write-Warn ((L "Time zone '{0}' not found on this PC - using the fallback." "Este PC no tiene la zona '{0}': se usa la alternativa.") -f $TimeZoneId)
    }
    if (-not $tzOk) {
        try { Set-TimeZone -Id $TimeZoneFallbackId -ErrorAction Stop; $tzOk = $true }
        catch { Write-Fail ((L 'Could not set the time zone: {0}' 'No se pudo poner la zona horaria: {0}') -f $_.Exception.Message) }
    }
    if ($tzOk) {
        Write-Ok ((L 'Time zone: {0}' 'Zona horaria: {0}') -f (Get-TimeZone).DisplayName)
        Add-Change ((L 'Time zone: {0}' 'Zona horaria: {0}') -f (Get-TimeZone).Id)
    }
    # que Windows no cambie la zona por su cuenta segun la ubicacion
    try { Set-Service -Name tzautoupdate -StartupType Disabled -ErrorAction Stop } catch { }

    # ---- 2. servicio de hora: siempre activo, sincroniza cada hora
    try {
        $cfg = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config'
        $ntp = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient'
        Set-Service -Name w32time -StartupType Automatic
        Invoke-Native 'sc.exe' @('triggerinfo', 'w32time', 'delete') | Out-Null   # que no se pare por "inactividad"
        Start-Service -Name w32time -ErrorAction SilentlyContinue
        $peers = ($TimeServers | ForEach-Object { "$_,0x9" }) -join ' '
        $r = Invoke-Native 'w32tm.exe' @('/config', "/manualpeerlist:$peers", '/syncfromflags:manual', '/reliable:no', '/update')
        if ($r.ExitCode -ne 0) { throw "w32tm /config: $($r.Text)" }
        Set-ItemProperty -Path $ntp -Name SpecialPollInterval   -Value 3600 -Type DWord  # cada hora (por defecto: cada 7 dias)
        Set-ItemProperty -Path $cfg -Name MaxAllowedPhaseOffset -Value 1    -Type DWord  # mas de 1 s: corregir de golpe
        Set-ItemProperty -Path $cfg -Name MaxPosPhaseCorrection -Value -1   -Type DWord  # -1 = 0xFFFFFFFF: corregir cualquier error,
        Set-ItemProperty -Path $cfg -Name MaxNegPhaseCorrection -Value -1   -Type DWord  #   incluso con la pila de la BIOS agotada
        Restart-Service -Name w32time -Force
        Write-Ok ((L 'Windows Time service: always on, syncs every hour with {0}.' 'Servicio de hora: siempre activo, sincroniza cada hora con {0}.') -f ($TimeServers -join ', '))
        Add-Change (L 'Clock: Windows Time syncs every hour' 'Reloj: sincroniza cada hora')
    } catch {
        Write-Fail ((L 'Windows Time service: {0}' 'Servicio de hora: {0}') -f $_.Exception.Message)
    }

    # ---- 3. sincronizar ya (tras reiniciar el servicio w32tm suele decir "aun no hay datos")
    $synced = $false
    $r = $null
    for ($i = 1; $i -le 5; $i++) {
        Start-Sleep -Seconds 2
        $r = Invoke-Native 'w32tm.exe' @('/resync')
        if ($r.ExitCode -eq 0) { $synced = $true; break }
    }
    if (-not $synced) { Write-Warn ((L 'Windows could not sync yet: {0}' 'Windows aún no pudo sincronizar: {0}') -f $r.Text) }
    Start-Sleep -Seconds 1
    $after = Get-ClockOffset
    # Red de seguridad: si sigue a mas de 1 s, corregir con el desfase medido
    if ($after -and [Math]::Abs($after.Offset) -gt 1) {
        try {
            Set-Date -Adjust ([TimeSpan]::FromSeconds($after.Offset)) | Out-Null
            Start-Sleep -Seconds 1
            $after = Get-ClockOffset
        } catch { Write-Warn ((L 'Could not correct the clock directly: {0}' 'No se pudo corregir el reloj directamente: {0}') -f $_.Exception.Message) }
    }
    if ($after) {
        $line = if ($before) { (L 'before {0}, now {1}' 'antes {0}, ahora {1}') -f (Format-Offset $before.Offset), (Format-Offset $after.Offset) } else { (L 'now {0}' 'ahora {0}') -f (Format-Offset $after.Offset) }
        if ([Math]::Abs($after.Offset) -le 1) { Write-Ok ((L 'Clock in sync: {0}' 'Reloj sincronizado: {0}') -f $line) }
        else { Write-Fail ((L 'Clock still off: {0}' 'El reloj sigue desfasado: {0}') -f $line) }
        # primero en el resumen: es el dato que importa para las cuentas atras
        $State.Changes = @(((L 'Clock: {0}' 'Reloj: {0}') -f $line)) + $State.Changes
    } else {
        Write-Fail (L 'Could not check the clock: no internet time server answered (UDP port 123 blocked?).' 'No se pudo comprobar el reloj: ningún servidor contesta (¿puerto UDP 123 bloqueado?).')
    }

    # ---- 4. tarea en segundo plano: al encender + a diario
    try {
        $dir = Initialize-KermaDataDir
        $syncScript = Join-Path $dir 'Kerma-TimeSync.ps1'
        Set-Content -LiteralPath $syncScript -Value $TimeSyncScript -Encoding Ascii
    } catch {
        Write-Fail ((L 'Could not write the time sync script: {0}' 'No se pudo escribir el script de hora: {0}') -f $_.Exception.Message)
        return
    }
    $taskName = 'Kerma - Time Sync'
    $err = Register-SystemTask $taskName $syncScript @((New-ScheduledTaskTrigger -AtStartup), (New-ScheduledTaskTrigger -Daily -At $TimeSyncDailyAt)) 10 @('/sc', 'onstart')
    if ($err) {
        Write-Fail ((L 'Background time sync task NOT created: {0}' 'La tarea de hora en segundo plano NO se creó: {0}') -f $err)
        return
    }
    try {
        $res = Invoke-TaskAndWait $taskName
        if ($res -eq 0) { Write-Ok ((L "Task '{0}' created and tested: syncs at every startup and daily at {1}." "Tarea '{0}' creada y probada: sincroniza al encender y a diario a las {1}.") -f $taskName, $TimeSyncDailyAt) }
        else { Write-Warn ((L "Task '{0}' created, but its test run reported code {1}. See {2}\timesync.log" "Tarea '{0}' creada, pero su prueba devolvió el código {1}. Mira {2}\timesync.log") -f $taskName, $res, $dir) }
    } catch {
        Write-Ok ((L "Task '{0}' created (startup + daily at {1})." "Tarea '{0}' creada (al encender y a diario a las {1}).") -f $taskName, $TimeSyncDailyAt)
    }
    Add-Change ((L 'Clock: background sync at startup + daily {0}' 'Reloj: sincronización al encender y a diario a las {0}') -f $TimeSyncDailyAt)
}
