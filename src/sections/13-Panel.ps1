# =====================================================================
#  PANEL DE ESTADO: el PC envia su estado cada 5 minutos a
#  https://kermasetup.netlify.app/estado (tarea "Kerma - Status")
# =====================================================================

# Lo que el recolector debe buscar en este PC (pc.json)
function Get-StatusConfig($pc) {
    $saved = Get-SavedAppPaths
    $list = [ordered]@{}
    foreach ($k in (Get-ProgramList $pc)) {
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
        key = $pc.Key; label = $pc.Label; type = $pc.Type; group = $pc.Group; game = $pc.Game; profile = $pc.Profile
        script_version = $ScriptVersion; apps = @($list.Values)
    }
}

function Test-PanelRegistered { return (Test-Path -LiteralPath (Join-Path $env:ProgramData 'Kerma\status.key')) }

function Invoke-StatusPanel($pc) {
    Write-Section (L 'STATUS PANEL  (kermasetup.netlify.app/estado)' 'PANEL DE ESTADO  (kermasetup.netlify.app/estado)')
    Write-Host (L '  This PC will send its state every 5 minutes: clock, apps, disk, network, RustDesk.' '  Este PC enviará su estado cada 5 minutos: hora, apps, disco, red, RustDesk.')
    Write-Host ''
    if (-not (Ask-YesNo (L '  Register this PC in the status panel?' '  ¿Registrar este PC en el panel de estado?') ([bool]$Prof.Panel))) { Write-Skip (L 'Not registered.' 'No registrado.'); return }

    $dir = Initialize-KermaDataDir
    $collector = Join-Path $dir 'Kerma-Status.ps1'
    Copy-Item -LiteralPath (Join-Path $Root 'Kerma-Status.ps1') -Destination $collector -Force
    (Get-StatusConfig $pc) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $dir 'pc.json') -Encoding UTF8

    # ---- clave de escritura: se pide una vez con el PIN; el PIN no se guarda
    $keyFile = Join-Path $dir 'status.key'
    if (Test-Path -LiteralPath $keyFile) {
        Write-Ok (L 'This PC is already registered in the panel.' 'Este PC ya estaba registrado en el panel.')
    } else {
        $pin = $script:Secrets.PanelPin
        if (-not $pin -and -not $script:Auto) { $pin = Read-Secret (L '  Panel PIN (input is hidden; Enter to skip)' '  PIN del panel (no se ve al escribir; Enter para saltar)') }
        if (-not $pin) { Write-Skip (L 'No PIN given - not registered (run the script again to do it).' 'Sin PIN: no se registró (vuelve a pasar el script para hacerlo).'); return }
        try {
            $resp = Invoke-RestMethod -Uri "$PanelBase/api/register" -Method Post -Headers @{ 'x-pin' = $pin } -UseBasicParsing -TimeoutSec 20
            Set-Content -LiteralPath $keyFile -Value $resp.key -Encoding Ascii
            Write-Ok (L 'PC registered in the status panel.' 'PC registrado en el panel de estado.')
        } catch {
            $code = 0
            try { $code = [int]$_.Exception.Response.StatusCode } catch { }
            if ($code -eq 401) { Write-Fail (L 'Wrong panel PIN - not registered.' 'PIN del panel incorrecto: no se registró.') }
            elseif ($code -eq 429) { Write-Fail (L 'Too many wrong PINs: the panel is locked for 15 minutes.' 'Demasiados PIN incorrectos: el panel queda bloqueado 15 minutos.') }
            else { Write-Fail ((L 'Could not reach the panel: {0}' 'No se pudo contactar con el panel: {0}') -f $_.Exception.Message) }
            return
        } finally { $pin = $null }
    }

    # ---- tarea: cada 5 minutos y al encender, como SYSTEM
    $taskName = 'Kerma - Status'
    $triggers = @((New-ScheduledTaskTrigger -AtStartup), (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5)))
    $err = Register-SystemTask $taskName $collector $triggers 3 @('/sc', 'minute', '/mo', '5')
    if ($err) { Write-Fail ((L 'Status task NOT created: {0}' 'La tarea del panel NO se creó: {0}') -f $err); return }

    # ---- primer informe ya
    try {
        $res = Invoke-TaskAndWait $taskName
        if ($res -eq 0) { Write-Ok ((L 'First report sent. See it at {0}/estado' 'Primer informe enviado. Míralo en {0}/estado') -f $PanelBase) }
        else { Write-Warn ((L 'The first report failed (code {0}). See {1}\status.log' 'El primer informe falló (código {0}). Mira {1}\status.log') -f $res, $dir) }
    } catch { Write-Warn ((L 'Could not send the first report now: {0}' 'No se pudo enviar el primer informe ahora: {0}') -f $_.Exception.Message) }
    Add-Change (L 'Status panel: reports every 5 minutes' 'Panel de estado: informa cada 5 minutos')
}
