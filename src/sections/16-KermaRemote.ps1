# =====================================================================
#  KERMA REMOTE: recibe por la red ordenes de los Stream Deck de los
#  supervisores (Companion) y las pega en la Dealer App de la mesa.
#  Programa en src\remote\KermaRemote.ps1 (copia del repo kerma-remote).
#  Por la red solo viaja el NOMBRE de la orden; el texto sale de la lista
#  del juego en ajustes.psd1 (Remote.Commands). Hace falta la clave.
# =====================================================================

$RemoteDir = 'C:\ProgramData\Kerma\remote'

function Get-RemoteCommands($pc) {
    if (-not $RemoteCfg -or -not $pc.Game) { return $null }
    return $RemoteCfg.Commands[$pc.Game]
}

# Clave que ya tiene este PC (se mantiene entre pasadas del setup)
function Get-RemoteKeyOnPC {
    $f = Join-Path $RemoteDir 'remote.key'
    if (Test-Path -LiteralPath $f) { return ((Get-Content -LiteralPath $f -Raw).Trim()) }
    return ''
}

# Clave comun de las mesas, guardada en el panel (variable KERMA_REMOTE_KEY de Netlify,
# nunca en el repositorio). Se pide con el PIN o, si el PC ya esta registrado, con su
# clave de escritura del panel.
function Get-PanelRemoteKey {
    $h = @{}
    if ($script:Secrets.PanelPin) { $h['x-pin'] = $script:Secrets.PanelPin }
    else {
        $kf = Join-Path $env:ProgramData 'Kerma\status.key'
        if (Test-Path -LiteralPath $kf) { $h['x-kerma-key'] = (Get-Content -LiteralPath $kf -Raw).Trim() }
    }
    if ($h.Count -eq 0) { return '' }
    try { return [string](Invoke-RestMethod -Uri "$PanelBase/api/remote-key" -Headers $h -UseBasicParsing -TimeoutSec 15).remoteKey } catch { return '' }
}

function Stop-KermaRemote {
    Stop-ScheduledTask -TaskName 'Kerma - Remote' -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*KermaRemote.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Invoke-KermaRemote($pc) {
    Write-Section (L 'KERMA REMOTE  (orders from the supervisors'' Stream Decks)' 'KERMA REMOTE  (órdenes desde los Stream Deck de los supervisores)')
    $cmds = Get-RemoteCommands $pc
    if (-not $Prof.Remote -or -not $cmds -or $cmds.Count -eq 0) {
        Write-Skip (L 'This PC does not receive remote orders.' 'Este PC no recibe órdenes remotas.')
        return
    }
    $allow = @($RemoteCfg.Allow)
    $port = [int]$RemoteCfg.Port
    Write-Host ((L '  Port {0}, from {1}, into {2}. Orders: {3}' '  Puerto {0}, desde {1}, en {2}. Órdenes: {3}') -f $port, ($allow -join ', '), $RemoteCfg.TargetProcess, (@($cmds.Keys | Sort-Object) -join ', '))
    Write-Host ''
    if (-not (Ask-YesNo (L '  Install / update Kerma Remote?' '  ¿Instalar / actualizar Kerma Remote?') $true)) { Write-Skip (L 'Kerma Remote left as it is.' 'Kerma Remote sin cambios.'); return }

    # la del panel manda: asi todas las mesas tienen la misma (tambien las de pruebas)
    $key = $script:Secrets.RemoteKey
    if (-not $key) { $key = Get-PanelRemoteKey; if ($key) { Write-Ok (L 'Kerma Remote key taken from the status panel.' 'Clave de Kerma Remote tomada del panel de estado.') } }
    if (-not $key) { $key = Get-RemoteKeyOnPC }
    if (-not $key -and -not $script:Auto) { $key = Read-NewSecret (L '  Kerma Remote key (the same one Companion uses, 12+ characters)' '  Clave de Kerma Remote (la misma que usa Companion, 12 caracteres o más)') }
    if (-not $key) { Write-Skip (L 'No key - Kerma Remote not installed (run the script again to do it).' 'Sin clave: Kerma Remote no se instaló (vuelve a pasar el script para hacerlo).'); return }
    if ($key.Length -lt 12) { Write-Fail (L 'The key must have at least 12 characters - Kerma Remote not installed.' 'La clave tiene que tener al menos 12 caracteres: Kerma Remote no se instaló.'); return }

    # 1. programa (parando antes el que corre: el archivo estaria bloqueado)
    Stop-KermaRemote
    New-Item -ItemType Directory -Path $RemoteDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $Root 'remote\KermaRemote.ps1') -Destination (Join-Path $RemoteDir 'KermaRemote.ps1') -Force
    $r = Invoke-Native 'icacls.exe' @($RemoteDir, '/grant', '*S-1-5-32-545:(OI)(CI)M', '/T', '/Q')
    if ($r.ExitCode -ne 0) { Write-Warn ((L 'Permissions on {0}: {1}' 'Permisos en {0}: {1}') -f $RemoteDir, $r.Text) }

    # 2. configuracion: siempre la del repositorio (una prueba a mano pudo dejar otra, p. ej. el Bloc de notas)
    $cfg = [ordered]@{
        port          = $port
        allow         = $allow
        targetProcess = [string]$RemoteCfg.TargetProcess
        mode          = 'paste'
        restoreFocus  = $true
        commands      = [ordered]@{}
    }
    foreach ($k in ($cmds.Keys | Sort-Object)) { $cfg.commands[$k] = [string]$cmds[$k] }
    $cfg | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $RemoteDir 'config.json') -Encoding Ascii
    Set-Content -LiteralPath (Join-Path $RemoteDir 'remote.key') -Value $key -Encoding Ascii -NoNewline

    # 3. puerto reservado para los usuarios (sin ser administrador)
    Invoke-Native 'netsh.exe' @('http', 'delete', 'urlacl', "url=http://+:$port/") | Out-Null
    $r = Invoke-Native 'netsh.exe' @('http', 'add', 'urlacl', "url=http://+:$port/", 'sddl=D:(A;;GX;;;BU)')
    if ($r.ExitCode -ne 0) { Write-Warn ((L 'Port reservation: {0}' 'Reserva del puerto: {0}') -f $r.Text) }

    # 4. firewall: solo desde las IPs / rangos permitidos
    Remove-NetFirewallRule -DisplayName 'Kerma Remote' -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName 'Kerma Remote' -Direction Inbound -Protocol TCP -LocalPort $port -RemoteAddress $allow -Action Allow -Profile Any | Out-Null

    # 5. tarea al iniciar sesion, oculta, se reinicia si cae; y arrancarla ya
    $taskArgs = "-STA -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RemoteDir\KermaRemote.ps1`""
    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgs -WorkingDirectory $RemoteDir
    $trigger   = New-ScheduledTaskTrigger -AtLogOn
    $trigger.Delay = 'PT20S'
    $principal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew `
                    -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1)
    Unregister-ScheduledTask -TaskName 'Kerma - Remote' -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName 'Kerma - Remote' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -ErrorAction Stop | Out-Null
    if (Test-SameUserAsConsole) {
        Start-ScheduledTask -TaskName 'Kerma - Remote' -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 4
        try {
            $h = Invoke-RestMethod -Uri "http://127.0.0.1:$port/health" -Headers @{ 'X-Kerma-Key' = $key; 'X-Kerma-Station' = 'setup' } -UseBasicParsing -TimeoutSec 5
            $appState = if ($h.appOpen) { L 'Dealer App open' 'Dealer App abierta' } else { L 'Dealer App not open now' 'Dealer App cerrada ahora' }
            Write-Ok ((L 'Kerma Remote {0} listening on port {1} ({2}).' 'Kerma Remote {0} escuchando en el puerto {1} ({2}).') -f $h.version, $port, $appState)
        } catch { Write-Warn ((L 'Kerma Remote does not answer yet ({0}). It starts at the next logon; see {1}\remote.log' 'Kerma Remote aún no responde ({0}). Arranca al iniciar sesión; mira {1}\remote.log') -f $_.Exception.Message, $RemoteDir) }
    } else {
        Write-Note (L '  It starts when the table user logs on.' '  Arranca cuando inicie sesión el usuario de la mesa.')
    }
    Add-Change ((L 'Kerma Remote: port {0}, orders {1}' 'Kerma Remote: puerto {0}, órdenes {1}') -f $port, (@($cmds.Keys | Sort-Object) -join ', '))
}

# ---------------------------------------------------------------------
#  COMPANION SATELLITE (PCs de supervisor): su Stream Deck se conecta al
#  Companion central. Config en %APPDATA%\Companion Satellite\config.json
#  (electron-store; claves de satellite/src/config.ts del repo de Bitfocus).
# ---------------------------------------------------------------------
function Invoke-SatelliteSetup($pc) {
    $p = $Packages['CompanionSatellite']
    if (@(Get-ProgramList $pc) -notcontains 'CompanionSatellite') { return }
    Write-Section (L 'COMPANION SATELLITE  (supervisor Stream Deck)' 'COMPANION SATELLITE  (Stream Deck del supervisor)')
    if (-not $SatelliteCfg -or -not $SatelliteCfg.Server) { Write-Skip (L 'No Satellite server in ajustes.psd1.' 'No hay servidor de Satellite en ajustes.psd1.'); return }
    if (-not (Test-Path -LiteralPath $p.Check)) { Write-Skip (L 'Companion Satellite is not installed.' 'Companion Satellite no está instalado.'); return }
    Write-Host ((L '  Connects to the central Companion {0}:{1}.' '  Se conecta al Companion central {0}:{1}.') -f $SatelliteCfg.Server, $SatelliteCfg.Port)
    if (-not (Ask-YesNo (L '  Configure it?' '  ¿Configurarlo?') $true)) { Write-Skip (L 'Satellite left as it is.' 'Satellite sin cambios.'); return }
    try {
        $dir = Join-Path $env:APPDATA 'Companion Satellite'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $file = Join-Path $dir 'config.json'
        $j = if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
        $hostName = if ($State.HostRenamed -or $State.RenameWanted) { $pc.Hostname } else { $env:COMPUTERNAME }
        $set = [ordered]@{ remoteProtocol = 'tcp'; remoteIp = [string]$SatelliteCfg.Server; remotePort = [int]$SatelliteCfg.Port; installationName = "Satellite $hostName" }
        foreach ($k in $set.Keys) {
            if ($j.PSObject.Properties[$k]) { $j.$k = $set[$k] } else { $j | Add-Member -NotePropertyName $k -NotePropertyValue $set[$k] }
        }
        # cerrado mientras se escribe (guarda su configuracion) y abierto despues como el usuario
        $running = [bool](Get-Process -Name $p.Process -ErrorAction SilentlyContinue)
        Get-Process -Name $p.Process -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        [IO.File]::WriteAllText($file, ($j | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding $false))
        if ($running -or (Test-SameUserAsConsole)) { Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$($p.Check)`"" }
        Write-Ok ((L 'Companion Satellite: connects to {0}:{1} as "{2}".' 'Companion Satellite: se conecta a {0}:{1} como "{2}".') -f $SatelliteCfg.Server, $SatelliteCfg.Port, $set.installationName)
        Write-Note (L '  In the central Companion (Surfaces), give this Stream Deck page 5 (SUPERVISOR) as start page.' '  En el Companion central (Surfaces), ponle a este Stream Deck la página 5 (SUPERVISOR) como página de inicio.')
        Add-Change ((L 'Companion Satellite -> {0}:{1}' 'Companion Satellite -> {0}:{1}') -f $SatelliteCfg.Server, $SatelliteCfg.Port)
    } catch { Write-Fail ((L 'Companion Satellite: {0}' 'Companion Satellite: {0}') -f $_.Exception.Message) }
}
