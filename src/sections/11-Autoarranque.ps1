# =====================================================================
#  AUTOARRANQUE: una tarea programada por app al iniciar sesion
# =====================================================================

# Ruta sugerida de una app: la recordada primero, luego la de programas.psd1.
# Una ruta recordada en otra mesa puede estar en el perfil de ESE usuario
# (C:\Users\<otro>\Desktop\...): se prueba el mismo sitio en este PC.
function Get-SuggestedAppPath([string]$k, $saved) {
    $app = $Apps[$k]
    $cands = @($saved[$k], $app.Path)
    if ($saved[$k] -match '^[A-Za-z]:\\Users\\[^\\]+\\(.+)$') {
        $cands = @($saved[$k], (Join-Path $env:USERPROFILE $Matches[1]), $app.Path)
    }
    foreach ($cand in $cands) { if ($cand -and (Test-AppPath $cand).Ok) { return $cand } }
    if ($saved[$k]) { return $saved[$k] }   # para que se vea por que falla
    return ''
}

# Apps del arranque que el script NO instala (Dealer App, scanner, camaras):
# en modo Automatico se piden al principio, para no parar a mitad.
function Get-ManualApps($pc) {
    $installed = @($Prof.Programs)
    return @($pc.Apps | Where-Object { -not $Apps[$_].SelfStarts -and $installed -notcontains $_ })
}

function Resolve-AutostartPathsUpfront($pc) {
    $saved = Get-SavedAppPaths
    $changed = $false
    foreach ($k in (Get-ManualApps $pc)) {
        $app = $Apps[$k]
        $sug = Get-SuggestedAppPath $k $saved
        if ($sug -and (Test-AppPath $sug).Ok) { $saved[$k] = (Test-AppPath $sug).Path; continue }
        Write-Host ''
        Write-Host ((L '  Program file of {0} (it starts with Windows; the script does not install it):' '  Programa de {0} (arranca con Windows; el script no lo instala):') -f $app.Name) -ForegroundColor Cyan
        $p = Get-AppPathInteractive $app $sug
        if ($p) { $saved[$k] = $p; $changed = $true }
    }
    if ($changed) { Save-AppPaths $saved }
}

function Invoke-AppAutostart($pc) {
    Write-Section (L 'APP AUTOSTART' 'ARRANQUE DE APPS')
    if (@($pc.Apps).Count -eq 0) { Write-Skip (L 'No apps start with Windows on this PC.' 'En este PC no arranca ninguna app con Windows.'); return }

    Write-Note (L 'If you answer N to an app, its existing autostart task (if any) is DELETED.' 'Si respondes N a una app, se BORRA su tarea de arranque si existía.')
    Write-Host ''
    if (-not (Ask-YesNo (L '  Configure app autostart now?' '  ¿Configurar el arranque de apps ahora?') $true)) { Write-Skip (L 'Autostart tasks left untouched.' 'Tareas de arranque sin tocar.'); return }

    $tableName = if ($State.HostRenamed -or $State.RenameWanted) { $pc.Hostname } else { $env:COMPUTERNAME }
    $dir       = "C:\KermaStartup\$tableName"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    # Las tareas van al grupo Usuarios por su SID fijo (S-1-5-32-545), no a una
    # cuenta: vale con cualquier nombre de cuenta, sobrevive a renombrados y no
    # depende del idioma de Windows. Abren la app en la sesion de quien entra.
    Write-Host ((L "  Tasks: '{0} - <App> Startup', scripts in {1}" "  Tareas: '{0} - <App> Startup', scripts en {1}") -f $tableName, $dir)
    $saved = Get-SavedAppPaths

    foreach ($k in $pc.Apps) {
        $app      = $Apps[$k]
        $taskName = "$tableName - $($app.Name) Startup"
        Write-Host ''
        if ($app.Replaces) {
            $old = "$tableName - $($app.Replaces) Startup"
            if (Get-ScheduledTask -TaskName $old -ErrorAction SilentlyContinue) {
                Unregister-ScheduledTask -TaskName $old -Confirm:$false -ErrorAction SilentlyContinue
                Write-Ok ((L "Old '{0}' autostart task removed - replaced by {1}." "Tarea antigua de '{0}' quitada: la sustituye {1}.") -f $app.Replaces, $app.Name)
            }
        }
        if ($app.SelfStarts) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Skip ((L '{0}: it starts by itself at logon - no task needed.' '{0}: ya arranca sola al iniciar sesión, no hace falta tarea.') -f $app.Name)
            continue
        }
        if (-not (Ask-YesNo ((L '  Start {0} with Windows?' '  ¿Arrancar {0} con Windows?') -f $app.Name) $true)) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Skip ((L '{0} (existing task removed, if any).' '{0} (tarea anterior quitada, si existía).') -f $app.Name)
            continue
        }

        # -- que programa
        $suggested = Get-SuggestedAppPath $k $saved
        $path = ''
        if ($script:Auto) {
            $chk = if ($suggested) { Test-AppPath $suggested } else { $null }
            if (-not ($chk -and $chk.Ok)) {
                Write-Warn ((L '{0}: no valid program file known - SKIPPED (existing task left untouched).' '{0}: no hay un programa válido: OMITIDA (la tarea anterior se queda).') -f $app.Name)
                continue
            }
            $path = $chk.Path
            Write-Host ((L '    Program -> {0}' '    Programa -> {0}') -f $path) -ForegroundColor DarkGray
        } else {
            while ($true) {
                $path = Get-AppPathInteractive $app $suggested
                if (-not $path) { break }
                if (Ask-YesNo (L '    -> Test it now? (opens the app once)' '    -> ¿Probarla ahora? (abre la app una vez)') $false) {
                    try {
                        Start-Process -FilePath $path -WorkingDirectory (Split-Path -Path $path -Parent)
                        if (Ask-YesNo (L '    Did it open correctly? (close it afterwards)' '    ¿Se abrió bien? (ciérrala después)') $true) { break }
                        $suggested = $path
                        continue
                    } catch {
                        Write-Fail ((L 'It did not start: {0}' 'No arrancó: {0}') -f $_.Exception.Message)
                        $suggested = $path
                        continue
                    }
                }
                break
            }
            if (-not $path) { Write-Skip ((L '{0} (no program chosen - existing task left untouched).' '{0} (sin programa elegido: la tarea anterior se queda).') -f $app.Name); continue }
        }
        if ($saved[$k] -ne $path) { $saved[$k] = $path; Save-AppPaths $saved }

        $max  = Ask-YesNo (L '    -> Open maximized?' '    -> ¿Abrir maximizada?') ([bool]$app.Maximize)
        $flag = if ($max) { '/max' } else { '' }

        # .bat en ASCII; PreLaunch va literal (%APPDATA% lo resuelve cmd del usuario)
        $lines = @('@echo off', "timeout /t $($app.Delay) /nobreak >nul")
        $lines += "cd /d `"$(Split-Path -Path $path -Parent)`""
        if ($app.PreLaunch) { $lines += $app.PreLaunch }
        $start = "start $flag `"`" `"$path`""
        if ($app.Args) { $start += " $($app.Args)" }
        $lines += $start
        if ($app.ShowAfter) {
            # arranca en la bandeja: abrirla otra vez trae su ventana delante (solo admite una copia)
            $lines += "timeout /t $($app.ShowAfter) /nobreak >nul"
            $lines += $start
        }
        $bat = Join-Path $dir "$($app.Id).bat"
        Set-Content -LiteralPath $bat -Value $lines -Encoding Ascii

        $err1 = ''
        $err2 = ''
        $created = $false
        try {
            $taskAction    = New-ScheduledTaskAction -Execute $bat -WorkingDirectory $dir
            $taskTrigger   = New-ScheduledTaskTrigger -AtLogOn
            $taskPrincipal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest
            $taskSettings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
            Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Force -ErrorAction Stop | Out-Null
            $created = $true
        } catch { $err1 = ($_.Exception.Message -replace '\s+', ' ').Trim() }
        if (-not $created) {
            # respaldo: schtasks.exe, como la version .bat antigua
            $r = Invoke-Native 'schtasks.exe' @('/create', '/tn', $taskName, '/tr', "`"$bat`"", '/sc', 'onlogon', '/rl', 'highest', '/f')
            if ($r.ExitCode -eq 0) { $created = $true } else { $err2 = $r.Text }
        }
        if ($created) {
            $maxTxt = if ($max) { L ', maximized' ', maximizada' } else { '' }
            Write-Ok ((L '{0} task created (delay {1}s{2}).' 'Tarea de {0} creada (espera {1} s{2}).') -f $app.Name, $app.Delay, $maxTxt)
            Add-Change ((L 'Autostart: {0}' 'Arranque: {0}') -f $app.Name)
        } else {
            Write-Fail ((L '{0} task NOT created.' 'La tarea de {0} NO se creó.') -f $app.Name)
            Write-Note "  Task Scheduler: $err1"
            Write-Note "  schtasks.exe  : $err2"
        }
    }
    Write-Host ''
    Write-Note (L 'To make an app open on the right monitor, move its window there by hand once - most apps (OBS included) remember it.' 'Para que una app se abra en el monitor correcto, mueve su ventana allí una vez: la mayoría (OBS incluido) lo recuerdan.')
}
