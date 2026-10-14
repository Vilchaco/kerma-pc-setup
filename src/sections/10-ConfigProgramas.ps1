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

# Nombre del perfil dentro de un .streamDeckProfile (zip: Profiles\<UUID>.sdProfile\manifest.json)
function Get-StreamDeckProfileName([string]$file) {
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($file)
        try {
            $e = $zip.Entries | Where-Object { $_.FullName -match '^Profiles/[^/]+\.sdProfile/manifest\.json$' } | Select-Object -First 1
            if (-not $e) { return '' }
            $r = New-Object IO.StreamReader($e.Open())
            try { return [string]($r.ReadToEnd() | ConvertFrom-Json).Name } finally { $r.Dispose() }
        } finally { $zip.Dispose() }
    } catch { return '' }
}
# Carpetas de los perfiles de la app de Stream Deck de este usuario que se llaman asi.
# Solo el primer nivel (<UUID>.sdProfile\manifest.json): las paginas de dentro
# (carpeta del PIN) tienen su propio manifest y no cuentan.
function Get-StreamDeckProfileDirs([string]$name) {
    $dirs = @()
    foreach ($v in @('ProfilesV3', 'ProfilesV2')) {
        $root = Join-Path $env:APPDATA "Elgato\StreamDeck\$v"
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory -Filter '*.sdProfile' -ErrorAction SilentlyContinue)) {
            $m = Join-Path $d.FullName 'manifest.json'
            if (-not (Test-Path -LiteralPath $m)) { continue }
            try { if ((Get-Content -LiteralPath $m -Raw | ConvertFrom-Json).Name -eq $name) { $dirs += $d.FullName } } catch { }
        }
    }
    return $dirs
}

# Id del Stream Deck conectado a este PC, sacado de los perfiles que ya tiene la app
# ("@(1)[4057/128/A00SA...]"). Vacio si la app aun no lo ha visto.
function Get-StreamDeckDeviceId([string]$model) {
    $root = Join-Path $env:APPDATA 'Elgato\StreamDeck\ProfilesV3'
    foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory -Filter '*.sdProfile' -ErrorAction SilentlyContinue)) {
        try {
            $m = Get-Content -LiteralPath (Join-Path $d.FullName 'manifest.json') -Raw | ConvertFrom-Json
            if ($m.Device -and [string]$m.Device.UUID -and (-not $model -or $m.Device.Model -eq $model)) { return [string]$m.Device.UUID }
        } catch { }
    }
    return ''
}

# Abre la app de Stream Deck como el usuario (no elevada)
function Start-StreamDeckApp([string]$exe) { Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$exe`"" }

# Instala el perfil sin que la app pregunte: con la app cerrada, copia la carpeta
# <UUID>.sdProfile del .streamDeckProfile (un zip) en ProfilesV3 y le pone el id
# del Stream Deck de este PC. En un PC nuevo abre antes la app una vez para que
# cree su carpeta y reconozca el aparato. $false = no se pudo (sin Stream Deck).
function Install-StreamDeckProfileDirect([string]$file, [string]$exe, [string]$target) {
    $tmp = Get-KermaTemp ('sdprofile-' + [IO.Path]::GetFileNameWithoutExtension($file))
    try {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($file, $tmp)
        $src = Get-ChildItem -LiteralPath (Join-Path $tmp 'Profiles') -Directory -Filter '*.sdProfile' | Select-Object -First 1
        if (-not $src) { return $false }
        $manifest = Join-Path $src.FullName 'manifest.json'
        $model = [string]((Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).Device.Model)

        $dev = Get-StreamDeckDeviceId $model
        if (-not $dev) {
            # app recien instalada: que arranque una vez y vea el Stream Deck
            if (-not (Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue)) { Start-StreamDeckApp $exe }
            for ($i = 0; $i -lt 30 -and -not $dev; $i++) { Start-Sleep -Seconds 2; $dev = Get-StreamDeckDeviceId $model }
        }
        if (-not $dev) { return $false }

        Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        $text = [IO.File]::ReadAllText($manifest)
        $text = [regex]::Replace($text, '("Device"\s*:\s*\{[^}]*?"UUID"\s*:\s*")[^"]*(")', [Text.RegularExpressions.MatchEvaluator] { param($m) $m.Groups[1].Value + $dev + $m.Groups[2].Value })
        [IO.File]::WriteAllText($manifest, $text, (New-Object Text.UTF8Encoding $false))
        # en la carpeta del perfil que ya usa el Stream Deck: la app recuerda el perfil
        # elegido por esa carpeta, asi que el aparato sigue mostrandolo (BJ01)
        $dst = if ($target) { $target } else { Join-Path $env:APPDATA "Elgato\StreamDeck\ProfilesV3\$($src.Name)" }
        if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
        Copy-Item -LiteralPath $src.FullName -Destination $dst -Recurse -Force
        Start-StreamDeckApp $exe
        return $true
    } catch {
        Write-Warn ((L 'Stream Deck (direct install): {0}' 'Stream Deck (instalación directa): {0}') -f $_.Exception.Message)
        return $false
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
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
    # siempre: "Iniciar el espejo al abrir la app" marcado (IniciarAlAbrir), con o sin
    # configuracion guardada: el arranque de la mesa solo abre HdmiMirror.exe
    if (Test-Path -LiteralPath $hmExe) {
        try {
            $cfgFile = Join-Path (Split-Path -Path $hmExe -Parent) 'hdmimirror.config.json'
            $j = if (Test-Path -LiteralPath $cfgFile) { Get-Content -LiteralPath $cfgFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
            if ($j.IniciarAlAbrir -ne $true) {
                $running = [bool](Get-Process -Name 'HdmiMirror' -ErrorAction SilentlyContinue)
                # cerrada: al salir guarda su configuracion y pisaria el cambio
                Get-Process -Name 'HdmiMirror' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
                if ($j.PSObject.Properties['IniciarAlAbrir']) { $j.IniciarAlAbrir = $true } else { $j | Add-Member -NotePropertyName 'IniciarAlAbrir' -NotePropertyValue $true }
                [IO.File]::WriteAllText($cfgFile, ($j | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
                if ($running) { Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$hmExe`"" }
                Write-Ok (L "HDMI Mirror: 'Start the mirror when the app opens' turned on." "HDMI Mirror: 'Iniciar el espejo al abrir la app' marcado.")
                Add-Change (L 'Settings: HDMI Mirror starts the mirror when it opens' 'Configuración: HDMI Mirror inicia el espejo al abrirse')
            } else {
                Write-Ok (L "HDMI Mirror: 'Start the mirror when the app opens' already on." "HDMI Mirror: 'Iniciar el espejo al abrir la app' ya estaba marcado.")
            }
        } catch { Write-Warn ((L 'HDMI Mirror settings: {0}' 'Ajustes de HDMI Mirror: {0}') -f $_.Exception.Message) }
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
        # Se sustituye por huella: si el perfil del repositorio cambia, el de la app se
        # cambia (con copia); si no, no se toca. Volver a importar el mismo crearia "Craps 2".
        $sdName  = Get-StreamDeckProfileName $sdProfile
        $hash    = (Get-FileHash -LiteralPath $sdProfile -Algorithm SHA256).Hash
        $hashFile = Join-Path (Initialize-KermaDataDir) "streamdeck-$($pc.Game).sha256"
        $oldHash = if (Test-Path -LiteralPath $hashFile) { (Get-Content -LiteralPath $hashFile -Raw).Trim() } else { '' }
        # @(...) por fuera: un "if" con un solo resultado lo devuelve suelto (texto), y [0] seria la "C"
        $existing = @(if ($sdName) { Get-StreamDeckProfileDirs $sdName })
        # "Default Profile" es el que muestra el Stream Deck si no se elige otro: mientras
        # exista, el perfil de la mesa se escribe encima de el (decision de Fran, BJ01)
        $defaults = @(Get-StreamDeckProfileDirs 'Default Profile')
        if ($existing.Count -and $oldHash -eq $hash -and $defaults.Count -eq 0) {
            Write-Ok ((L "Stream Deck: profile '{0}' is already the current one." "Stream Deck: el perfil '{0}' ya es el actual.") -f $sdName)
        } else {
            $go = $true
            if ($existing.Count) {
                Write-Note ((L "  The Stream Deck app has an older '{0}' profile: it is replaced (a copy is kept)." "  La app de Stream Deck tiene otro perfil '{0}': se sustituye (se guarda copia).") -f $sdName)
                $go = Ask-YesNo (L '  Replace it with the new one?' '  ¿Sustituirlo por el nuevo?') $true
            }
            if ($go) {
                # Destino: la carpeta del "Default Profile" (el que muestra el Stream Deck) o,
                # si ya no hay (se piso en otra pasada), la del perfil con este nombre. Se
                # reutiliza la carpeta para que el aparato lo siga mostrando.
                $target = if ($defaults.Count) { $defaults[0] } elseif ($existing.Count) { $existing[0] } else { '' }
                $touch = @($existing) + @($target) | Where-Object { $_ } | Select-Object -Unique
                if ($touch.Count) {
                    Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 3
                    $bak = "C:\KermaSetup\backup\streamdeck-$stamp"
                    New-Item -ItemType Directory -Path $bak -Force | Out-Null
                    foreach ($d in $touch) { Copy-Item -LiteralPath $d -Destination $bak -Recurse -Force }
                    # las demas copias con ese nombre sobran: el Stream Deck queda en una sola
                    foreach ($d in @($existing | Where-Object { $_ -ne $target })) { Remove-Item -LiteralPath $d -Recurse -Force }
                    Write-Ok ((L 'Stream Deck: previous profile saved in {0}.' 'Stream Deck: perfil anterior guardado en {0}.') -f $bak)
                }
                # 1) directo, sin preguntas: el perfil se copia en la carpeta de la app con el
                #    Stream Deck de este PC; 2) si no se puede, se abre el archivo y la app pregunta
                $direct = Install-StreamDeckProfileDirect $sdProfile $sdExe ([string]$target)
                if ($direct) {
                    Set-Content -LiteralPath $hashFile -Value $hash -Encoding Ascii
                    Write-Ok ((L "Stream Deck: profile '{0}' installed in the Stream Deck app." "Stream Deck: perfil '{0}' instalado en la app de Stream Deck.") -f $sdName)
                    Write-Note (L '  If the Stream Deck shows another profile, pick it in the app (once).' '  Si el Stream Deck muestra otro perfil, elígelo en la app (una vez).')
                    Add-Change ((L 'Settings: Stream Deck profile {0}' 'Configuración: perfil de Stream Deck {0}') -f $pc.Game)
                } else {
                    Write-Note (L '  Could not install it directly (is the Stream Deck plugged in?): the app will ask to import it - accept.' '  No se pudo instalar directamente (¿está conectado el Stream Deck?): la app preguntará si importarlo; acepta.')
                    # explorer.exe: SIN permisos de administrador; abierto desde este PowerShell
                    # elevado, la app del usuario no recibe el perfil (BJ01)
                    Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$sdProfile`""
                    $seen = @()
                    for ($i = 0; $i -lt 30 -and $seen.Count -eq 0; $i++) { Start-Sleep -Seconds 2; if ($sdName) { $seen = @(Get-StreamDeckProfileDirs $sdName) } }
                    if ($seen.Count -or -not $sdName) {
                        Set-Content -LiteralPath $hashFile -Value $hash -Encoding Ascii
                        Write-Ok ((L "Stream Deck: profile '{0}' imported into the Stream Deck app." "Stream Deck: perfil '{0}' importado en la app de Stream Deck.") -f $sdName)
                        Add-Change ((L 'Settings: Stream Deck profile {0}' 'Configuración: perfil de Stream Deck {0}') -f $pc.Game)
                    } else {
                        Write-Warn ((L "Stream Deck: the app did not save the '{0}' profile within 60 s. If it is asking to import it, accept; if not, double-click {1}" "Stream Deck: la app no guardó el perfil '{0}' en 60 s. Si está preguntando si importarlo, acepta; si no, haz doble clic en {1}") -f $sdName, $sdProfile)
                    }
                }
            } else { Write-Skip (L 'Stream Deck: profile kept.' 'Stream Deck: se conserva el perfil.') }
        }
    }
}
