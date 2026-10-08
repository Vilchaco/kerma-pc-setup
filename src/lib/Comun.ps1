# =====================================================================
#  Kerma PC Setup - funciones comunes (se carga con dot-source desde
#  Kerma-PCSetup.ps1; usa las variables del script principal)
# =====================================================================

# ---------------------------- idioma ---------------------------------
# L 'English' 'Espanol' -> el texto del idioma elegido al empezar
function L([string]$en, [string]$es) { if ($script:Lang -eq 'es') { return $es } else { return $en } }

# ---------------------------- salida ---------------------------------
function Write-Section([string]$title) {
    Write-Host ''
    Write-Host '===============================================================' -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host '===============================================================' -ForegroundColor Cyan
    Write-Host ''
}
function Write-Phase([string]$title) {
    Write-Host ''
    Write-Host ''
    Write-Host "#################  $title  #################" -ForegroundColor Magenta
}
function Write-Ok($m)   { Write-Host "  [OK] $m"                          -ForegroundColor Green }
function Write-Skip($m) { Write-Host ("  [{0}] $m" -f (L 'SKIPPED' 'OMITIDO')) -ForegroundColor DarkGray }
function Write-Warn($m) { Write-Host ("  [{0}] $m" -f (L 'WARN' 'AVISO'))      -ForegroundColor Yellow }
function Write-Fail($m) { Write-Host ("  [{0}] $m" -f (L 'FAILED' 'ERROR'))    -ForegroundColor Red }
function Write-Note($m) { Write-Host "  $m"                               -ForegroundColor Yellow }
function Add-Change($m) { $State.Changes += $m }

# ---------------------------- herramientas de Windows ----------------
# Ejecuta una herramienta de linea de comandos y devuelve salida + codigo.
# Con ErrorActionPreference=Stop, PowerShell 5.1 convierte cualquier linea
# de stderr en un error que para el script: aqui no.
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

# Crea una clave del registro solo si falta. (New-Item -Force sobre una
# clave existente la BORRA con todos sus valores.)
function Initialize-RegistryKey([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
}

# Usuario que tiene la sesion abierta (puede no ser el de esta ventana
# si se uso otra cuenta de administrador en el aviso de permisos)
function Get-ConsoleUser {
    try { return [string](Get-CimInstance Win32_ComputerSystem).UserName } catch { return '' }
}
function Test-SameUserAsConsole {
    $c = Get-ConsoleUser
    return (-not $c -or ($c -split '\\')[-1] -ieq $env:USERNAME)
}

# ---------------------------- preguntas ------------------------------
# En modo Automatico no se pregunta: se usa el valor del perfil.
function Ask-YesNo([string]$prompt, [bool]$default = $false) {
    if ($script:Auto) {
        $txt = if ($default) { L 'yes' 'si' } else { 'no' }
        Write-Host ("$prompt -> $txt ({0})" -f (L 'automatic' 'automático')) -ForegroundColor DarkGray
        return $default
    }
    $hint = if ($default) { L '(Y/n)' '(S/n)' } else { L '(y/N)' '(s/N)' }
    $v = Read-Host "$prompt $hint"
    if ([string]::IsNullOrWhiteSpace($v)) { return $default }
    return ($v.Trim() -match '^[YySs]')
}

# Opciones numeradas; devuelve el indice (desde 0) elegido.
function Ask-Choice([string]$prompt, [string[]]$options, [int]$default = 0) {
    for ($i = 0; $i -lt $options.Count; $i++) { Write-Host ("  {0}. {1}" -f ($i + 1), $options[$i]) }
    Write-Host ''
    if ($script:Auto) {
        Write-Host ("$prompt -> {0} ({1})" -f ($default + 1), (L 'automatic' 'automático')) -ForegroundColor DarkGray
        return $default
    }
    while ($true) {
        $v = Read-Host "$prompt (1-$($options.Count))"
        if ($v -match '^\d+$' -and [int]$v -ge 1 -and [int]$v -le $options.Count) { return ([int]$v - 1) }
        Write-Host (L '    Invalid choice.' '    Opción no válida.')
    }
}

# Menu que se responde siempre (idioma, modo, PC), tambien en Automatico
function Read-MenuChoice([string]$prompt, [int]$count) {
    while ($true) {
        $v = Read-Host "$prompt (1-$count)"
        if ($v -match '^\d+$' -and [int]$v -ge 1 -and [int]$v -le $count) { return ([int]$v - 1) }
        Write-Host (L '    Invalid choice.' '    Opción no válida.')
    }
}

function Read-Secret([string]$prompt) {
    $sec = Read-Host $prompt -AsSecureString
    if ($sec.Length -eq 0) { return '' }
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

# Pide un secreto dos veces para evitar erratas. '' = saltar.
function Read-NewSecret([string]$what) {
    while ($true) {
        $x = Read-Secret ("  $what " + (L '(input is hidden; Enter to skip)' '(no se ve al escribir; Enter para saltar)'))
        if (-not $x) { return '' }
        $y = Read-Secret ('  ' + (L 'Type it again to confirm' 'Escríbela otra vez para confirmar'))
        if ($x -ceq $y) { return $x }
        Write-Warn (L 'They do not match - try again.' 'No coinciden. Prueba otra vez.')
    }
}

function Test-IPv4($s) {
    return ([string]$s -match '^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$')
}

# Pide una IPv4 valida. Enter acepta el valor sugerido.
function Read-IPv4([string]$prompt, [string]$default, [switch]$Optional) {
    if ($script:Auto) {
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
            Write-Host (L '    This value is required.' '    Este dato es obligatorio.')
            continue
        }
        $v = $v.Trim()
        if (Test-IPv4 $v) { return $v }
        Write-Host ((L "    '{0}' is not a valid IPv4 address (example: 192.168.1.50)." "    '{0}' no es una IPv4 válida (ejemplo: 192.168.1.50).") -f $v)
    }
}

# ---------------------------- rutas ----------------------------------
function Get-AssetsDir {
    foreach ($d in @((Join-Path $Root 'assets'), (Join-Path (Split-Path -Path $Root -Parent) 'assets'))) {
        if (Test-Path -LiteralPath $d -PathType Container) { return (Resolve-Path -LiteralPath $d).ProviderPath }
    }
    return $null
}

# Carpeta del sistema para los scripts que ejecuta Windows como SYSTEM:
# solo SYSTEM y Administradores pueden cambiarla (Usuarios: solo leer)
function Initialize-KermaDataDir {
    $dir = Join-Path $env:ProgramData 'Kerma'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $r = Invoke-Native 'icacls.exe' @($dir, '/inheritance:r', '/grant:r', '*S-1-5-18:(OI)(CI)F', '*S-1-5-32-544:(OI)(CI)F', '*S-1-5-32-545:(OI)(CI)RX')
    if ($r.ExitCode -ne 0) { Write-Warn ((L 'Could not lock down {0} permissions: {1}' 'No se pudieron proteger los permisos de {0}: {1}') -f $dir, $r.Text) }
    return $dir
}

# ---------------------------- rutas de apps recordadas ---------------
# Junto al script (viajan en el USB a la siguiente mesa) y en C:\KermaSetup
# (se conservan entre versiones con la instalacion de una linea).
function Get-AppPathsFiles { return @((Join-Path $Root 'app-paths.json'), 'C:\KermaSetup\app-paths.json') }

function Get-SavedAppPaths {
    $h = @{}
    foreach ($f in (Get-AppPathsFiles)) {
        if (-not (Test-Path -LiteralPath $f)) { continue }
        try {
            $obj = Get-Content -LiteralPath $f -Raw | ConvertFrom-Json
            foreach ($prop in $obj.PSObject.Properties) { $h[$prop.Name] = [string]$prop.Value }
            return $h
        } catch { Write-Warn ((L 'Could not read {0} - ignoring it.' 'No se pudo leer {0}: se ignora.') -f $f) }
    }
    return $h
}

function Save-AppPaths($h) {
    $json = $h | ConvertTo-Json
    $saved = $false
    foreach ($f in (Get-AppPathsFiles)) {
        try {
            New-Item -ItemType Directory -Path (Split-Path -Path $f -Parent) -Force | Out-Null
            Set-Content -LiteralPath $f -Value $json -Encoding UTF8
            $saved = $true
        } catch { }
    }
    if (-not $saved) { Write-Warn (L 'Could not save the app paths (they will be asked again next time).' 'No se pudieron guardar las rutas de las apps (se volverán a preguntar).') }
}

# Comprueba una ruta escrita, pegada o elegida. Devuelve @{ Ok; Path; Error; Info }
function Test-AppPath([string]$raw) {
    $r = @{ Ok = $false; Path = ''; Error = ''; Info = '' }
    if ([string]::IsNullOrWhiteSpace($raw)) { $r.Error = (L 'no path given' 'no hay ruta'); return $r }
    # admite "Copiar como ruta" del Explorador (con comillas) y %VARIABLES%
    $p = [Environment]::ExpandEnvironmentVariables($raw.Trim().Trim('"').Trim("'").Trim())
    if (-not ($p -match '^[A-Za-z]:\\' -or $p -match '^\\\\')) {
        $r.Error = (L 'not a full path - it must start with a drive letter, e.g. C:\...' 'no es una ruta completa: debe empezar por la unidad, por ejemplo C:\...'); return $r
    }
    # acceso directo (.lnk): se usa el programa al que apunta
    if ([IO.Path]::GetExtension($p) -ieq '.lnk' -and (Test-Path -LiteralPath $p -PathType Leaf)) {
        $target = ''
        try { $target = (New-Object -ComObject WScript.Shell).CreateShortcut($p).TargetPath } catch { }
        if ([string]::IsNullOrWhiteSpace($target)) {
            $r.Error = (L 'this shortcut does not point to a normal program file - browse to the real .exe instead' 'este acceso directo no apunta a un programa normal: busca el .exe real'); return $r
        }
        Write-Host ((L '    (shortcut points to: {0})' '    (el acceso directo apunta a: {0})') -f $target)
        $p = $target
    }
    if (Test-Path -LiteralPath $p -PathType Container) { $r.Error = (L 'that is a folder, not a program - pick the .exe inside it' 'es una carpeta, no un programa: elige el .exe de dentro'); return $r }
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { $r.Error = (L 'file not found' 'no existe el archivo'); return $r }
    $ext = [IO.Path]::GetExtension($p).ToLower()
    if (@('.exe', '.bat', '.cmd') -notcontains $ext) { $r.Error = ((L "'{0}' files are not programs - use a .exe, .bat or .cmd file" "los archivos '{0}' no son programas: usa un .exe, .bat o .cmd") -f $ext); return $r }

    $r.Ok   = $true
    $r.Path = (Resolve-Path -LiteralPath $p).ProviderPath
    if ($ext -eq '.exe') {
        $vi = (Get-Item -LiteralPath $r.Path).VersionInfo
        $parts = @($vi.ProductName, $vi.CompanyName) | Where-Object { $_ -and $_.Trim() }
        if ($vi.ProductVersion -and $vi.ProductVersion.Trim()) { $parts += ((L 'version {0}' 'versión {0}') -f $vi.ProductVersion.Trim()) }
        $r.Info = if ($parts) { $parts -join ' - ' } else { L 'program found (it has no product name inside)' 'programa encontrado (no tiene nombre de producto)' }
    } else {
        $r.Info = L 'batch script found' 'script .bat encontrado'
    }
    return $r
}

# Ventana normal de Windows "Abrir archivo". Devuelve '' si se cancela.
function Select-AppFile([string]$appName, [string]$near) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title            = (L 'Kerma setup - select the program for: {0}' 'Kerma setup - elige el programa de: {0}') -f $appName
        $dlg.Filter           = 'Programs (*.exe;*.bat;*.cmd;*.lnk)|*.exe;*.bat;*.cmd;*.lnk|All files (*.*)|*.*'
        $dlg.DereferenceLinks = $true
        $dlg.InitialDirectory = $env:ProgramFiles
        if ($near) {
            $d = Split-Path -Path $near -Parent -ErrorAction SilentlyContinue
            if ($d -and (Test-Path -LiteralPath $d -PathType Container)) { $dlg.InitialDirectory = $d }
        }
        # ventana invisible por encima de todo para que el dialogo no quede detras de la consola
        $owner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; ShowInTaskbar = $false }
        try { $res = $dlg.ShowDialog($owner) } finally { $owner.Dispose() }
        if ($res -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.FileName }
    } catch {
        Write-Warn ((L 'The file browser could not be opened ({0}). Paste the path instead.' 'No se pudo abrir el explorador de archivos ({0}). Pega la ruta.') -f $_.Exception.Message)
    }
    return ''
}

# Pregunta hasta tener una ruta valida. '' si el tecnico la salta.
function Get-AppPathInteractive($app, [string]$suggested) {
    $candidate = $suggested
    while ($true) {
        $chk = $null
        if ($candidate) { $chk = Test-AppPath $candidate }
        if ($chk -and $chk.Ok) {
            Write-Host ((L '    Path : {0}' '    Ruta : {0}') -f $chk.Path)
            Write-Host ((L '    Check: OK - {0}' '    Comprobado: OK - {0}') -f $chk.Info) -ForegroundColor Green
            $v = Read-Host (L '    [Enter] use it   [B] browse for another   [S] skip this app   or paste another path' '    [Enter] usarla   [B] buscar otra   [S] saltar esta app   o pega otra ruta')
            if ([string]::IsNullOrWhiteSpace($v)) { return $chk.Path }
        } else {
            if ($candidate) { Write-Warn "$candidate  ->  $($chk.Error)" }
            else            { Write-Host ((L '    No path known yet for {0}.' '    Todavía no hay ruta para {0}.') -f $app.Name) }
            $v = Read-Host (L '    [Enter/B] browse for the file   [S] skip this app   or paste the full path' '    [Enter/B] buscar el archivo   [S] saltar esta app   o pega la ruta completa')
            if ([string]::IsNullOrWhiteSpace($v)) { $v = 'B' }
        }
        $v = $v.Trim()
        if ($v -ieq 'S') { return '' }
        if ($v -ieq 'B') {
            Write-Host (L '    Opening the file browser...' '    Abriendo el explorador de archivos...')
            $near   = if ($chk -and $chk.Ok) { $chk.Path } else { $candidate }
            $picked = Select-AppFile $app.Name $near
            if ($picked) { $candidate = $picked } else { Write-Host (L '    Nothing selected.' '    No se eligió nada.') }
            continue
        }
        $candidate = $v
    }
}

# ---------------------------- tareas programadas ---------------------
# Registra una tarea que se ejecuta como SYSTEM. Con schtasks.exe de respaldo.
# $triggers = objetos de New-ScheduledTaskTrigger. $fallbacks = una lista de
# programaciones de schtasks (@('/sc', ...)): schtasks admite una por tarea,
# asi que la segunda y siguientes se crean como "<nombre> (<sc>)".
function Register-SystemTask([string]$name, [string]$script, $triggers, [int]$limitMin, [object[]]$fallbacks) {
    $psArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
    try {
        $a  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $psArgs
        $p  = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $st = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes $limitMin)
        Register-ScheduledTask -TaskName $name -Action $a -Trigger $triggers -Principal $p -Settings $st -Force -ErrorAction Stop | Out-Null
        return ''
    } catch { $err1 = ($_.Exception.Message -replace '\s+', ' ').Trim() }
    $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $script"
    $errs = @()
    for ($i = 0; $i -lt $fallbacks.Count; $i++) {
        $fb = @($fallbacks[$i])
        $n  = if ($i -eq 0) { $name } else { "$name ($($fb[1]))" }
        $r = Invoke-Native 'schtasks.exe' (@('/create', '/tn', $n, '/tr', $tr) + $fb + @('/ru', 'SYSTEM', '/rl', 'highest', '/f'))
        if ($r.ExitCode -ne 0) { $errs += $r.Text }
    }
    if ($errs.Count -eq 0) { return '' }
    return "$err1 / $($errs -join ' / ')"
}

# Lanza una tarea y espera a que termine. Devuelve su LastTaskResult (o $null).
function Invoke-TaskAndWait([string]$name, [int]$seconds = 90) {
    Start-ScheduledTask -TaskName $name -ErrorAction Stop
    $deadline = (Get-Date).AddSeconds($seconds)
    do { Start-Sleep -Seconds 2 } while ((Get-ScheduledTask -TaskName $name).State -eq 'Running' -and (Get-Date) -lt $deadline)
    return (Get-ScheduledTaskInfo -TaskName $name).LastTaskResult
}

# ---------------------------- red / descargas ------------------------
function Test-Internet {
    try {
        Invoke-WebRequest -Uri 'https://api.github.com' -Method Head -UseBasicParsing -TimeoutSec 15 | Out-Null
        return $true
    } catch { return $false }
}

function Get-PrimaryIPv4 {
    try {
        $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Sort-Object -Property RouteMetric | Select-Object -First 1
        return [string](Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -ErrorAction Stop | Select-Object -First 1).IPAddress
    } catch { return '' }
}
