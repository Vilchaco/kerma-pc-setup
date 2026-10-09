# =====================================================================
#  CONFIGURACION DE PROGRAMAS desde assets\: HDMI Mirror, OBS (escenas,
#  perfil, tema Kerma), plugins VST3 y perfil de Stream Deck del juego
# =====================================================================

# Pone [Appearance] Theme=<id> en el user.ini de OBS (OBS 31+ guarda ahi
# el tema), sin tocar ninguna otra linea. Devuelve $true si lo puso.
function Set-ObsTheme([string]$obsDir, [string]$themeId) {
    $userIni   = Join-Path $obsDir 'user.ini'
    $globalIni = Join-Path $obsDir 'global.ini'
    if (-not (Test-Path -LiteralPath $userIni) -and (Test-Path -LiteralPath $globalIni)) {
        # OBS anterior a 31 lo guardaba todo en global.ini y lo copia a user.ini
        # en su primer arranque tras actualizar; si user.ini ya existe en ese
        # momento la copia falla con un cuadro de error. Asi que user.ini solo
        # se crea cuando esa copia ya se hizo o no hace falta.
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
    Write-Section (L 'PROGRAM SETTINGS  (HDMI Mirror, OBS, VST3, Stream Deck)' 'CONFIGURACIÓN DE PROGRAMAS  (HDMI Mirror, OBS, VST3, Stream Deck)')
    $assets = Get-AssetsDir
    if (-not $assets) { Write-Skip (L 'No assets folder next to the script.' 'No hay carpeta assets junto al script.'); return }
    if (-not (Ask-YesNo (L '  Apply the saved settings for this PC?' '  ¿Aplicar la configuración guardada de este PC?') ([bool]$Prof.ProgramSettings))) { Write-Skip (L 'Program settings left unchanged.' 'Configuración de programas sin cambios.'); return }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    # ---- HDMI Mirror: assets\hdmi-mirror\<clave>.json (o default.json)
    $hmExe = $Packages['HdmiMirror'].Check
    $hmSrc = @((Join-Path $assets "hdmi-mirror\$($pc.Key).json"), (Join-Path $assets 'hdmi-mirror\default.json')) |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    Write-Host ''
    if (-not (Test-Path -LiteralPath $hmExe)) {
        Write-Skip (L 'HDMI Mirror: not installed on this PC.' 'HDMI Mirror: no está instalado en este PC.')
    } elseif (-not $hmSrc) {
        Write-Skip ((L 'HDMI Mirror: no saved config (assets\hdmi-mirror\{0}.json).' 'HDMI Mirror: no hay configuración guardada (assets\hdmi-mirror\{0}.json).') -f $pc.Key)
    } else {
        $dst = Join-Path (Split-Path -Path $hmExe -Parent) 'hdmimirror.config.json'
        $go = $true
        if (Test-Path -LiteralPath $dst) {
            Write-Note (L '  HDMI Mirror already has a config on this PC (it may have been adjusted by hand).' '  HDMI Mirror ya tiene configuración en este PC (puede estar ajustada a mano).')
            $go = Ask-YesNo (L '  Replace it with the saved one? (a backup is kept)' '  ¿Sustituirla por la guardada? (se guarda copia)') $false
            if ($go) { Copy-Item -LiteralPath $dst -Destination "$dst.bak-$stamp" -Force }
        }
        if ($go) {
            Get-Process -Name 'HdmiMirror' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Copy-Item -LiteralPath $hmSrc -Destination $dst -Force
            Write-Ok ((L 'HDMI Mirror: config applied from {0}.' 'HDMI Mirror: configuración aplicada desde {0}.') -f (Split-Path -Path $hmSrc -Leaf))
            Add-Change ((L 'Settings: HDMI Mirror {0}' 'Configuración: HDMI Mirror {0}') -f (Split-Path -Path $hmSrc -Leaf))
        } else { Write-Skip (L 'HDMI Mirror: config kept.' 'HDMI Mirror: se conserva su configuración.') }
    }

    # ---- OBS: assets\obs\ se copia en %APPDATA%\obs-studio\ (escenas, perfiles, global.ini, temas)
    Write-Host ''
    $obsSrc = Join-Path $assets 'obs'
    # service.json guarda la clave de emision: nunca sale del repositorio (publico)
    $obsFiles = @(Get-ChildItem -LiteralPath $obsSrc -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'README.md' -and $_.Name -ne 'service.json' })
    if (-not (Test-Path -LiteralPath $Packages['OBS'].Check)) {
        Write-Skip (L 'OBS: not installed on this PC.' 'OBS: no está instalado en este PC.')
    } elseif ($obsFiles.Count -eq 0) {
        Write-Skip (L 'OBS: no saved scenes / profile in assets\obs.' 'OBS: no hay escenas ni perfil guardados en assets\obs.')
    } else {
        $obsDst = Join-Path $env:APPDATA 'obs-studio'
        if (Get-Process -Name 'obs64' -ErrorAction SilentlyContinue) {
            Write-Note (L '  OBS is open. It must be closed so it does not overwrite the copied files.' '  OBS está abierto. Hay que cerrarlo para que no pise los archivos copiados.')
            if (Ask-YesNo (L '  Close OBS now?' '  ¿Cerrar OBS ahora?') $true) { Get-Process -Name 'obs64' | Stop-Process -Force; Start-Sleep -Seconds 2 }
        }
        if (Get-Process -Name 'obs64' -ErrorAction SilentlyContinue) {
            Write-Skip (L 'OBS: still open - settings not copied.' 'OBS: sigue abierto, no se copió la configuración.')
        } else {
            if (Test-Path -LiteralPath $obsDst) { Copy-Item -LiteralPath $obsDst -Destination "$obsDst.bak-$stamp" -Recurse -Force }
            foreach ($f in $obsFiles) {
                $rel = $f.FullName.Substring($obsSrc.Length).TrimStart('\')
                $to = Join-Path $obsDst $rel
                New-Item -ItemType Directory -Path (Split-Path -Path $to -Parent) -Force | Out-Null
                Copy-Item -LiteralPath $f.FullName -Destination $to -Force
            }
            # dispositivos de audio: el id de un micro / salida concreto solo existe en el PC
            # donde se eligio. "default" = el predeterminado de Windows (la Scarlett en las mesas)
            foreach ($f in $obsFiles) {
                $to = Join-Path $obsDst ($f.FullName.Substring($obsSrc.Length).TrimStart('\'))
                if ($f.Extension -eq '.json' -and $f.FullName -match '\\scenes\\') {
                    $t = [IO.File]::ReadAllText($to)
                    $n = [regex]::Replace($t, '"device_id"\s*:\s*"[^"]*"', '"device_id": "default"')
                    if ($n -ne $t) { [IO.File]::WriteAllText($to, $n, (New-Object Text.UTF8Encoding $false)) }
                } elseif ($f.Name -eq 'basic.ini') {
                    $t = [IO.File]::ReadAllText($to)
                    $n = [regex]::Replace([regex]::Replace($t, '(?m)^MonitoringDeviceId=[^\r\n]*', 'MonitoringDeviceId=default'), '(?m)^MonitoringDeviceName=[^\r\n]*', 'MonitoringDeviceName=Default')
                    if ($n -ne $t) { [IO.File]::WriteAllText($to, $n, (New-Object Text.UTF8Encoding $true)) }
                }
            }
            Write-Ok ((L 'OBS: {0} settings files copied to {1} (backup: obs-studio.bak-{2}).' 'OBS: {0} archivos de configuración copiados a {1} (copia: obs-studio.bak-{2}).') -f $obsFiles.Count, $obsDst, $stamp)
            Add-Change (L 'Settings: OBS scenes / profile / theme' 'Configuración: escenas, perfil y tema de OBS')
            # aspecto Kerma: themes\Kerma.ovt ya esta copiado; dejarlo elegido
            if (Test-Path -LiteralPath (Join-Path $obsDst "themes\$ObsThemeFile")) {
                if (Ask-YesNo (L '  Use the Kerma theme (colors) in OBS?' '  ¿Usar el tema Kerma (colores) en OBS?') $true) {
                    try {
                        if (Set-ObsTheme $obsDst $ObsThemeId) {
                            Write-Ok (L 'OBS: Kerma theme selected.' 'OBS: tema Kerma elegido.')
                            Add-Change (L 'Settings: OBS Kerma theme' 'Configuración: tema Kerma en OBS')
                        } else {
                            Write-Warn (L 'OBS: settings from an older OBS not migrated yet. Open OBS once, close it and run this again (or pick Settings > Appearance > Kerma).' 'OBS: la configuración de un OBS anterior aún no se migró. Abre OBS una vez, ciérralo y vuelve a pasar esto (o elige Ajustes > Apariencia > Kerma).')
                        }
                    } catch { Write-Fail ((L 'OBS theme: {0}' 'Tema de OBS: {0}') -f $_.Exception.Message) }
                } else { Write-Skip (L 'OBS: theme left as it was (Kerma is in Settings > Appearance).' 'OBS: tema sin cambios (Kerma está en Ajustes > Apariencia).') }
            }
        }
    }

    # ---- plugins VST3: assets\vst3\* -> C:\Program Files\Common Files\VST3
    Write-Host ''
    $vstItems = @(Get-ChildItem -LiteralPath (Join-Path $assets 'vst3') -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*.vst3' })
    if ($vstItems.Count -eq 0) {
        Write-Skip (L 'VST3: no plugins in assets\vst3.' 'VST3: no hay plugins en assets\vst3.')
    } else {
        $vstDst = Join-Path $env:CommonProgramFiles 'VST3'
        New-Item -ItemType Directory -Path $vstDst -Force | Out-Null
        if (Get-Process -Name 'obs64' -ErrorAction SilentlyContinue) { Write-Note (L '  OBS is open: restart it to load new VST3 plugins.' '  OBS está abierto: reinícialo para cargar los VST3 nuevos.') }
        foreach ($v in $vstItems) { Copy-Item -LiteralPath $v.FullName -Destination $vstDst -Recurse -Force }
        $names = @($vstItems | ForEach-Object { $_.Name }) -join ', '
        Write-Ok ((L 'VST3: {0} copied to {1}.' 'VST3: {0} copiados a {1}.') -f $names, $vstDst)
        Add-Change "VST3: $names"
    }

    # ---- Stream Deck: assets\streamdeck\<juego>.streamDeckProfile
    Write-Host ''
    $sdExe = $Packages['StreamDeck'].Check
    $sdProfile = if ($pc.Game) { Join-Path $assets "streamdeck\$($pc.Game).streamDeckProfile" } else { '' }
    if (-not (Test-Path -LiteralPath $sdExe)) {
        Write-Skip (L 'Stream Deck: not installed on this PC.' 'Stream Deck: no está instalado en este PC.')
    } elseif (-not $pc.Game) {
        Write-Skip (L 'Stream Deck: no game set for this PC.' 'Stream Deck: este PC no tiene juego asignado.')
    } elseif (-not (Test-Path -LiteralPath $sdProfile)) {
        Write-Skip ((L 'Stream Deck: no saved profile (assets\streamdeck\{0}.streamDeckProfile).' 'Stream Deck: no hay perfil guardado (assets\streamdeck\{0}.streamDeckProfile).') -f $pc.Game)
    } else {
        # al abrir el archivo, la app de Stream Deck lo importa
        Start-Process -FilePath $sdProfile
        Write-Ok ((L "Stream Deck: profile '{0}' sent to the Stream Deck app." "Stream Deck: perfil '{0}' enviado a la app de Stream Deck.") -f $pc.Game)
        Write-Note (L '  If the Stream Deck app asks to import the profile, accept it.' '  Si la app de Stream Deck pregunta si importar el perfil, acepta.')
        Add-Change ((L 'Settings: Stream Deck profile {0}' 'Configuración: perfil de Stream Deck {0}') -f $pc.Game)
    }
}
