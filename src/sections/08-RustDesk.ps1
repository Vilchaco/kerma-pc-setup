# =====================================================================
#  RUSTDESK por IP directa en la red de la oficina (scripts de David en
#  rustdesk\). CLIENT = acepta conexiones; MASTER = controla al resto,
#  con la lista de equipos de David en Favoritos. None = sin RustDesk.
# =====================================================================

# Ventanas principales de RustDesk de los usuarios (no el servicio ni la bandeja)
function Get-RustDeskWindows {
    return @(Get-CimInstance Win32_Process -Filter "Name='rustdesk.exe'" -ErrorAction SilentlyContinue | Where-Object {
        $_.SessionId -ne 0 -and [string]$_.CommandLine -notmatch '(?i)(?:^|\s)--(?:server|service|tray|cm|portable-service)(?:\s|$)'
    })
}

# Equipos para los Favoritos del MASTER: la lista de David si se puede
# leer; si no, el inventario. Nunca este PC ni los que no usan RustDesk.
function Get-RustDeskPeers($pc) {
    $own = @($pc.Net.IP) + @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object { $_.IPAddress })
    $own += @($PCs | Where-Object { -not $_.RustDesk -and $_.Net.IP } | ForEach-Object { $_.Net.IP })
    $peers = @()
    $source = L "David's list (kerma-rust)" 'la lista de David (kerma-rust)'
    foreach ($r in @(Get-DavidList)) {
        if ($own -contains $r.IP) { continue }
        $peers += [pscustomobject]@{ Nombre = $r.Nombre; IP = $r.IP; Puerto = $r.Puerto }
    }
    if (-not $peers.Count) {
        $source = L 'the inventory of this script' 'el inventario de este script'
        foreach ($row in $PCs) {
            if (-not $row.RustDesk -or -not $row.Net.IP -or $row.Key -eq $pc.Key -or $own -contains $row.Net.IP) { continue }
            $peers += [pscustomobject]@{ Nombre = $row.Label; IP = $row.Net.IP; Puerto = $RustDeskPort }
        }
        foreach ($x in $RustDeskExtraPeers) {
            if ($own -contains $x.IP) { continue }
            $peers += [pscustomobject]@{ Nombre = $x.Nombre; IP = $x.IP; Puerto = $RustDeskPort }
        }
    }
    return @{ Peers = $peers; Source = $source }
}

# Ejecuta Configurar-Esta-PC.ps1 (David) en un PowerShell aparte con tiempo
# maximo: si rustdesk.exe se queda esperando a su servicio, el script
# principal no se bloquea (Ctrl+C no puede cortar un programa externo).
# La contrasena va por una variable de entorno que hereda el proceso hijo:
# no aparece en la linea de comandos ni se escribe en disco.
function Invoke-RustDeskConfig([string]$rd, [string]$mode, [string]$pw, [int]$timeoutSec = 180) {
    $script = Join-Path $rd 'Configurar-Esta-PC.ps1'
    $allowed = ($RustDeskAllowedFrom -join ',')
    $cmd = "`$ErrorActionPreference = 'Stop'; try { & '$script' -Modo '$mode' -Contrasena `$env:KERMA_RD_PW -Puerto $RustDeskPort -OrigenesPermitidos ('$allowed' -split ','); exit 0 } catch { Write-Host ('ERROR: ' + `$_.Exception.Message); exit 1 }"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    $outFile = Join-Path $env:TEMP 'kerma-rustdesk-out.txt'
    $errFile = Join-Path $env:TEMP 'kerma-rustdesk-err.txt'
    $env:KERMA_RD_PW = $pw
    try {
        $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-OutputFormat', 'Text', '-EncodedCommand', $enc) `
            -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $null = $p.Handle   # necesario en PowerShell 5.1 para leer luego el codigo de salida
    } finally { Remove-Item Env:\KERMA_RD_PW -ErrorAction SilentlyContinue }
    Write-Host ((L '  Configuring RustDesk (up to {0} s)...' '  Configurando RustDesk (como mucho {0} s)...') -f $timeoutSec)
    $finished = $p.WaitForExit($timeoutSec * 1000)
    if (-not $finished) { Stop-ProcessTree $p.Id }
    foreach ($f in @($outFile, $errFile)) {
        if (Test-Path -LiteralPath $f) {
            # sin la contrasena ni el formato interno (CLIXML) que PowerShell usa para los errores
            Get-Content -LiteralPath $f -ErrorAction SilentlyContinue |
                Where-Object { $_ -and $_ -notmatch [regex]::Escape($pw) -and $_ -notmatch '^#< CLIXML' -and $_ -notmatch '^<Objs ' } |
                ForEach-Object { Write-Host "    $_" }
            Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
        }
    }
    if (-not $finished) {
        throw ((L 'RustDesk did not answer in {0} s (its service is probably not ready). It was stopped so the setup can go on. Restart the PC and run the script again.' 'RustDesk no respondió en {0} s (seguramente su servicio aún no estaba listo). Se cortó para que el setup siga. Reinicia el PC y vuelve a pasar el script.') -f $timeoutSec)
    }
    if ($p.ExitCode -ne 0) { throw (L 'RustDesk configuration failed (see the lines above).' 'La configuración de RustDesk falló (mira las líneas de arriba).') }
}

# El instalador .msi de RustDesk no siempre crea su servicio. Se crea como en
# la documentacion oficial: --install-service SIN esperar al proceso, y se
# comprueba cada pocos segundos si el servicio ya existe (esperar al proceso,
# como hacia la version anterior, deja el setup colgado).
function Initialize-RustDeskService([string]$exe) {
    $svc = Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Host (L '  Creating the RustDesk service...' '  Creando el servicio de RustDesk...')
        $p = Start-Process -FilePath $exe -ArgumentList '--install-service' -PassThru -WindowStyle Hidden
        for ($i = 0; $i -lt 30 -and -not $svc; $i++) { Start-Sleep -Seconds 2; $svc = Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue }
        if ($p -and -not $p.HasExited) { Stop-ProcessTree $p.Id }
        if (-not $svc) { throw (L 'RustDesk did not create its service. Restart the PC and run the script again.' 'RustDesk no creó su servicio. Reinicia el PC y vuelve a pasar el script.') }
    }
    Set-Service -Name 'RustDesk' -StartupType Automatic -ErrorAction SilentlyContinue
    if ((Get-Service -Name 'RustDesk').Status -ne 'Running') {
        Start-Service -Name 'RustDesk' -ErrorAction SilentlyContinue
        for ($i = 0; $i -lt 15 -and (Get-Service -Name 'RustDesk').Status -ne 'Running'; $i++) { Start-Sleep -Seconds 2 }
    }
    Start-Sleep -Seconds 5   # que el servicio termine de arrancar antes de hablar con el
    Write-Ok ((L 'RustDesk service: {0}.' 'Servicio de RustDesk: {0}.') -f (Get-Service -Name 'RustDesk').Status)
}

function Invoke-RemoteAccess($pc) {
    Write-Section (L 'REMOTE ACCESS  (RustDesk by direct IP on the LAN)' 'ACCESO REMOTO  (RustDesk por IP directa en la red)')
    $mode = $Prof.RustDesk
    if ($mode -eq 'None' -or -not $pc.RustDesk) { Write-Skip ((L '{0} is not part of RustDesk.' '{0} no forma parte de RustDesk.') -f $pc.Label); return }
    $exe = $Packages['RustDesk'].Check
    if (-not (Test-Path -LiteralPath $exe)) { Write-Skip (L 'RustDesk is not installed on this PC.' 'RustDesk no está instalado en este PC.'); return }
    $rd = Join-Path $Root 'rustdesk'
    if (-not (Test-Path -LiteralPath (Join-Path $rd 'Configurar-Esta-PC.ps1'))) { Write-Skip (L 'The Kerma RustDesk scripts are missing (rustdesk\).' 'Faltan los scripts de Kerma RustDesk (rustdesk\).'); return }

    if ($mode -eq 'Client') {
        Write-Host ((L '  CLIENT: accepts RustDesk connections from the office network by IP (port {0}),' '  CLIENT: acepta conexiones de RustDesk desde la red de la oficina por IP (puerto {0}),') -f $RustDeskPort)
        Write-Host (L '  with the common password and without anyone accepting on screen.' '  con la contraseña común y sin que nadie acepte en pantalla.')
    } else {
        Write-Host (L "  MASTER: controls the others. The PC list (David's) goes into its Favorites" '  MASTER: controla al resto. La lista de equipos (la de David) va a sus Favoritos')
        Write-Host (L '  and the common password is saved for connecting.' '  y se guarda la contraseña común para conectarse.')
    }
    Write-Host ''
    if (-not (Ask-YesNo ((L '  Configure RustDesk as {0}?' '  ¿Configurar RustDesk como {0}?') -f $mode) $true)) { Write-Skip (L 'RustDesk left unchanged.' 'RustDesk sin cambios.'); return }

    # contrasena: pedida al principio (modo Automatico), aqui (Manual) o por -RustDeskPassword
    $pw = $script:Secrets.RustDesk
    if (-not $pw -and -not $script:Auto) { $pw = Read-NewSecret (L 'RustDesk common password' 'Contraseña común de RustDesk') }
    if (-not $pw) { Write-Skip (L 'No password given - RustDesk left unchanged.' 'Sin contraseña: RustDesk sin cambios.'); return }

    try {
        # servicio, contrasena permanente, IP directa, permisos, cortafuegos (script de David: comprueba cada opcion)
        Initialize-RustDeskService $exe
        Invoke-RustDeskConfig $rd $mode $pw
        Write-Ok ((L 'RustDesk {0} configured: direct IP on port {1}, permanent password, service automatic.' 'RustDesk {0} configurado: IP directa en el puerto {1}, contraseña permanente, servicio automático.') -f $mode, $RustDeskPort)
        Add-Change ((L 'RustDesk: {0}, direct IP port {1}' 'RustDesk: {0}, IP directa puerto {1}') -f $mode, $RustDeskPort)

        # logo de Kerma dentro de RustDesk (solo imagenes, con copia)
        try {
            & (Join-Path $rd 'Instalar-Logo-Kerma.ps1') -RutaRustDesk $exe | Out-Null
            Write-Ok (L 'RustDesk: Kerma logo installed (a RustDesk update can bring the original back).' 'RustDesk: logo de Kerma puesto (una actualización de RustDesk puede devolver el original).')
        } catch { Write-Warn ((L 'RustDesk logo: {0}' 'Logo de RustDesk: {0}') -f $_.Exception.Message) }

        # listas del usuario: la ventana de RustDesk debe estar cerrada para que no las pise
        foreach ($w in (Get-RustDeskWindows)) { $proc = Get-Process -Id $w.ProcessId -ErrorAction SilentlyContinue; if ($proc) { [void]$proc.CloseMainWindow() } }
        for ($i = 0; $i -lt 10 -and (Get-RustDeskWindows).Count; $i++) { Start-Sleep -Seconds 1 }
        foreach ($w in (Get-RustDeskWindows)) { Stop-Process -Id $w.ProcessId -Force -ErrorAction SilentlyContinue }

        if ($mode -eq 'Client') {
            & (Join-Path $rd 'Limpiar-Perfil-Cliente.ps1') | Out-Null
            Write-Ok (L 'RustDesk: no saved PCs or outgoing password on this PC.' 'RustDesk: sin equipos guardados ni contraseña de salida en este PC.')
        } else {
            $list = Get-RustDeskPeers $pc
            $peers = @($list.Peers)
            Write-Host ((L '  PC list taken from {0}.' '  Lista de equipos tomada de {0}.') -f $list.Source)
            if ($peers.Count -eq 0) { Write-Warn (L 'No PCs with an IP to add to the Favorites.' 'No hay equipos con IP que añadir a Favoritos.'); return }
            & (Join-Path $rd 'Configurar-Contrasena-Saliente.ps1') -Contrasena $pw | Out-Null
            & (Join-Path $rd 'Agregar-Favoritos.ps1') -Equipos $peers | Out-Null
            Write-Ok ((L 'RustDesk: {0} PCs in Favorites ({1}).' 'RustDesk: {0} equipos en Favoritos ({1}).') -f $peers.Count, (@($peers | ForEach-Object { $_.Nombre }) -join ', '))
            Add-Change ((L 'RustDesk: {0} PCs in Favorites' 'RustDesk: {0} equipos en Favoritos') -f $peers.Count)
        }
        Write-Note ((L "  RustDesk lists were saved for user '{0}'. Open RustDesk again to use it." "  Las listas de RustDesk se guardaron para '{0}'. Vuelve a abrir RustDesk para usarlo.") -f $env:USERNAME)
    } finally {
        $pw = $null
    }
}
