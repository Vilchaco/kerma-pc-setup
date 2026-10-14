#Requires -Version 5.1
<#
.SYNOPSIS
    Kerma Remote: receptor de comandos remotos para la Dealer App de las mesas.

.DESCRIPTION
    Escucha peticiones HTTP en la red local (por defecto en el puerto 10010) y,
    si vienen de una IP permitida y con la clave correcta, pega en la ventana de
    la Dealer App el texto del comando pedido, sin Enter.

    Por la red solo viaja el NOMBRE del comando (por ejemplo atem_auto). El texto
    real ({ATEM_AUTO}) sale de la lista "commands" del config.json de este PC:
    esa lista es la lista blanca. Si un comando no esta en ella, se rechaza.

    Tiene que ejecutarse en la sesion del usuario de la mesa (no como SYSTEM),
    porque escribe en el escritorio. El instalador crea una tarea al iniciar sesion.

    Rutas (en C:\ProgramData\Kerma\remote):
      config.json   configuracion (puerto, IPs permitidas, proceso, comandos)
      remote.key    clave compartida con Companion (cabecera X-Kerma-Key)
      remote.log    registro: fecha, IP, puesto, comando, ventana, resultado

    Peticiones:
      GET  /health            estado (pide clave)
      POST /cmd/<nombre>      ejecuta un comando de la lista (tambien vale GET)
    Cabeceras: X-Kerma-Key (obligatoria), X-Kerma-Station (opcional, se registra).

.PARAMETER TestCommand
    Prueba local sin red: espera 3 segundos y pega ese comando en la ventana del
    proceso configurado. Ejemplo: .\KermaRemote.ps1 -TestCommand atem_auto

.PARAMETER Target
    Sustituye el proceso de destino del config. Util para probar con notepad.

.PARAMETER DryRun
    Ensayo: hace todo (red, IPs, clave, lista blanca, registro) pero NO toca
    ventanas ni teclado; responde como si hubiera pegado. Sirve para probar la
    red sin molestar a la Dealer App.
#>
[CmdletBinding()]
param(
    [string]$ConfigDir = 'C:\ProgramData\Kerma\remote',
    [string]$TestCommand,
    [string]$Target,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$KrVersion = '0.1.2'

if (-not $DryRun) { Add-Type -AssemblyName System.Windows.Forms }
if (-not $DryRun -and -not ('KrWin' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class KrWin {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
'@
}

# ---------------------------------------------------------------- configuracion
$DefaultConfig = [ordered]@{
    port          = 10010
    allow         = @('192.168.1.79')       # IPs o rangos (192.168.0.0/22) que pueden mandar comandos
    targetProcess = 'dealer-control'        # nombre del proceso, sin .exe
    mode          = 'paste'                 # paste = pegar (lo que piden los devs) | type = escribir
    restoreFocus  = $true                   # devolver el foco a la ventana que estaba delante
    commands      = [ordered]@{ atem_auto = '{ATEM_AUTO}' }
}

$ConfigFile = Join-Path $ConfigDir 'config.json'
$KeyFile    = Join-Path $ConfigDir 'remote.key'
$LogFile    = Join-Path $ConfigDir 'remote.log'

# IP permitida: igual a una de la lista o dentro de un rango "red/bits" (192.168.0.0/22)
function Test-KrAllowed([string]$ip, [string[]]$allow) {
    if ($ip -eq '127.0.0.1') { return $true }
    $addr = $null
    if (-not [System.Net.IPAddress]::TryParse($ip, [ref]$addr)) { return $false }
    $ipBytes = $addr.GetAddressBytes()
    foreach ($a in $allow) {
        if ($a -eq $ip) { return $true }
        if ($a -notmatch '^([0-9.]+)/([0-9]{1,2})$') { continue }
        $net = $null
        if (-not [System.Net.IPAddress]::TryParse($Matches[1], [ref]$net)) { continue }
        $bits = [int]$Matches[2]
        $netBytes = $net.GetAddressBytes()
        if ($netBytes.Length -ne $ipBytes.Length) { continue }
        $ok = $true
        for ($i = 0; $i -lt $ipBytes.Length -and $ok; $i++) {
            $take = [Math]::Max(0, [Math]::Min(8, $bits - 8 * $i))
            $mask = [byte]((0xFF -shl (8 - $take)) -band 0xFF)
            if (($ipBytes[$i] -band $mask) -ne ($netBytes[$i] -band $mask)) { $ok = $false }
        }
        if ($ok) { return $true }
    }
    return $false
}

function Read-KrConfig {
    $c = $DefaultConfig
    if (Test-Path -LiteralPath $ConfigFile) {
        $j = Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json
        foreach ($k in @('port', 'allow', 'targetProcess', 'mode', 'restoreFocus')) {
            if ($null -ne $j.$k) { $c[$k] = $j.$k }
        }
        if ($null -ne $j.commands) {
            $cmds = [ordered]@{}
            foreach ($p in $j.commands.PSObject.Properties) { $cmds[$p.Name.ToLowerInvariant()] = [string]$p.Value }
            $c['commands'] = $cmds
        }
    }
    $c['allow'] = @($c['allow'] | ForEach-Object { [string]$_ })
    return $c
}

function Write-KrLog([string]$msg) {
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Host $line
    try {
        if (-not (Test-Path -LiteralPath $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
        if ((Test-Path -LiteralPath $LogFile) -and ((Get-Item -LiteralPath $LogFile).Length -gt 1MB)) {
            Move-Item -LiteralPath $LogFile -Destination ($LogFile + '.1') -Force
        }
        Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    } catch { Write-Host "  (no se pudo escribir el log: $($_.Exception.Message))" }
}

# ---------------------------------------------------------------- ventana y teclado
function Get-KrTarget([string]$name) {
    $procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue |
               Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
    if ($procs.Count -eq 0) { return $null }
    # Electron abre varios procesos con el mismo nombre: el bueno tiene ventana con titulo
    $withTitle = @($procs | Where-Object { $_.MainWindowTitle })
    if ($withTitle.Count -gt 0) { return $withTitle[0] }
    return $procs[0]
}

function Set-KrFocus([IntPtr]$hwnd) {
    if ([KrWin]::IsIconic($hwnd)) { [void][KrWin]::ShowWindow($hwnd, 9) }   # SW_RESTORE
    if ([KrWin]::GetForegroundWindow() -eq $hwnd) { return $true }

    # 1) enganchar nuestra entrada a la de la ventana de delante y pedir el foco
    $fg = [KrWin]::GetForegroundWindow()
    $fgPid = [uint32]0
    $fgThread = [KrWin]::GetWindowThreadProcessId($fg, [ref]$fgPid)
    $me = [KrWin]::GetCurrentThreadId()
    $attached = $false
    if ($fgThread -ne 0 -and $fgThread -ne $me) { $attached = [KrWin]::AttachThreadInput($me, $fgThread, $true) }
    try {
        [void][KrWin]::BringWindowToTop($hwnd)
        [void][KrWin]::SetForegroundWindow($hwnd)
    } finally {
        if ($attached) { [void][KrWin]::AttachThreadInput($me, $fgThread, $false) }
    }
    Start-Sleep -Milliseconds 120
    if ([KrWin]::GetForegroundWindow() -eq $hwnd) { return $true }

    # 2) plan B: Windows deja cambiar el foco a quien acaba de "pulsar" una tecla (Alt)
    [KrWin]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)          # Alt abajo
    [void][KrWin]::SetForegroundWindow($hwnd)
    [KrWin]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)          # Alt arriba
    Start-Sleep -Milliseconds 120
    return ([KrWin]::GetForegroundWindow() -eq $hwnd)
}

function Send-KrTyped([string]$text) {
    # SendKeys usa {} + ^ % ~ ( ) [ ] como especiales: se escapan entre llaves
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $text.ToCharArray()) {
        if ('{}+^%~()[]'.IndexOf($ch) -ge 0) { [void]$sb.Append('{').Append($ch).Append('}') } else { [void]$sb.Append($ch) }
    }
    [System.Windows.Forms.SendKeys]::SendWait($sb.ToString())
}

# Intenta poner texto en el portapapeles varias veces: RustDesk y otros programas
# lo abren a menudo y Windows devuelve "Requested Clipboard operation did not succeed".
function Set-KrClipboard([string]$text) {
    for ($i = 1; $i -le 12; $i++) {
        try { [System.Windows.Forms.Clipboard]::SetDataObject($text, $true, 3, 40); return $true }
        catch { Start-Sleep -Milliseconds 120 }
    }
    return $false
}

# Devuelve como se envio: 'paste' o 'type' (si el portapapeles estaba ocupado).
function Send-KrText([string]$text, [string]$mode) {
    if ($mode -eq 'type') { Send-KrTyped $text; return 'type' }
    $saved = $null
    try { if ([System.Windows.Forms.Clipboard]::ContainsText()) { $saved = [System.Windows.Forms.Clipboard]::GetText() } } catch { $saved = $null }
    if (-not (Set-KrClipboard $text)) {
        Write-Host '  (portapapeles ocupado: se escribe tecla a tecla)'
        Send-KrTyped $text
        return 'type'
    }
    Start-Sleep -Milliseconds 60
    [System.Windows.Forms.SendKeys]::SendWait('^v')
    Start-Sleep -Milliseconds 300
    if ($null -ne $saved) { [void](Set-KrClipboard $saved) }
    else { try { [System.Windows.Forms.Clipboard]::Clear() } catch { } }
    return 'paste'
}

# Ejecuta un comando de la lista. Devuelve un hashtable con el resultado.
function Invoke-KrCommand([string]$id, $cfg) {
    $id = $id.ToLowerInvariant()
    if (-not $cfg.commands.Contains($id)) { return @{ ok = $false; status = 404; error = 'comando no permitido'; command = $id } }
    $text = $cfg.commands[$id]
    if ($DryRun) { return @{ ok = $true; status = 200; command = $id; window = 'ENSAYO, no se ha pegado nada'; text = $text } }
    $p = Get-KrTarget $cfg.targetProcess
    if (-not $p) { return @{ ok = $false; status = 409; error = "no esta abierta la app ($($cfg.targetProcess))"; command = $id } }
    $hwnd = $p.MainWindowHandle
    $prev = [KrWin]::GetForegroundWindow()
    if (-not (Set-KrFocus $hwnd)) { return @{ ok = $false; status = 409; error = 'no se pudo poner la app delante'; command = $id; window = $p.MainWindowTitle } }
    $via = Send-KrText $text $cfg.mode
    if ($cfg.restoreFocus -and $prev -ne [IntPtr]::Zero -and $prev -ne $hwnd) {
        Start-Sleep -Milliseconds 150
        [void][KrWin]::SetForegroundWindow($prev)
    }
    return @{ ok = $true; status = 200; command = $id; window = $p.MainWindowTitle; via = $via }
}

# ---------------------------------------------------------------- arranque
$cfg = Read-KrConfig
if ($Target) { $cfg.targetProcess = $Target }

if ($TestCommand) {
    Write-Host "Kerma Remote $KrVersion - prueba local de '$TestCommand' en '$($cfg.targetProcess)' (modo $($cfg.mode))"
    Write-Host 'Tienes 3 segundos para poner otra ventana delante si quieres probar el cambio de foco...'
    Start-Sleep -Seconds 3
    $r = Invoke-KrCommand $TestCommand $cfg
    Write-KrLog ("PRUEBA local  cmd={0}  ok={1}  {2}" -f $TestCommand, $r.ok, ($(if ($r.ok) { "ventana='$($r.window)'" } else { $r.error })))
    exit ([int](-not $r.ok))
}

if (-not (Test-Path -LiteralPath $KeyFile)) { Write-KrLog "ERROR: falta la clave en $KeyFile. Ejecuta el instalador."; exit 2 }
$Key = (Get-Content -LiteralPath $KeyFile -Raw).Trim()
if ($Key.Length -lt 12) { Write-KrLog 'ERROR: la clave de remote.key es demasiado corta (minimo 12 caracteres).'; exit 2 }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$($cfg.port)/")
try { $listener.Start() } catch {
    Write-KrLog "ERROR: no se pudo abrir el puerto $($cfg.port): $($_.Exception.Message). Falta la reserva urlacl o el puerto esta ocupado."
    exit 3
}
Write-KrLog ("Kerma Remote {0}{5} escuchando en el puerto {1}. Permitidas: {2}. App: {3}. Comandos: {4}" -f `
    $KrVersion, $cfg.port, ($cfg.allow -join ', '), $cfg.targetProcess, (@($cfg.commands.Keys) -join ', '), $(if ($DryRun) { ' (ENSAYO)' } else { '' }))

$lastRun = @{}
function Send-KrReply($ctx, [int]$status, $obj) {
    $json = $obj | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $ctx.Response.StatusCode = $status
    $ctx.Response.ContentType = 'application/json; charset=utf-8'
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.OutputStream.Close()
}

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    try {
        $req = $ctx.Request
        if ($null -eq $req -or $null -eq $req.RemoteEndPoint -or $null -eq $req.Url) {
            try { $ctx.Response.Abort() } catch { }
            continue
        }
        $addr = $req.RemoteEndPoint.Address
        if ($addr.IsIPv4MappedToIPv6) { $addr = $addr.MapToIPv4() }
        $ip = $addr.ToString()
        $station = [string]$req.Headers['X-Kerma-Station']
        if (-not $station) { $station = '-' }
        $path = $req.Url.AbsolutePath.TrimEnd('/').ToLowerInvariant()

        if (-not (Test-KrAllowed $ip $cfg.allow)) {
            Write-KrLog "RECHAZADA  ip=$ip  puesto=$station  ruta=$path  (IP no permitida)"
            Send-KrReply $ctx 403 @{ ok = $false; error = 'ip no permitida' }; continue
        }
        if ([string]$req.Headers['X-Kerma-Key'] -cne $Key) {
            Write-KrLog "RECHAZADA  ip=$ip  puesto=$station  ruta=$path  (clave incorrecta)"
            Send-KrReply $ctx 401 @{ ok = $false; error = 'clave incorrecta' }; continue
        }

        if ($path -eq '/health') {
            $p = Get-KrTarget $cfg.targetProcess
            Send-KrReply $ctx 200 @{ ok = $true; version = $KrVersion; host = $env:COMPUTERNAME; app = $cfg.targetProcess; appOpen = [bool]$p; window = $(if ($p) { $p.MainWindowTitle } else { '' }); commands = @($cfg.commands.Keys) }
            continue
        }

        if ($path -like '/cmd/*') {
            $id = $path.Substring(5)
            $now = Get-Date
            if ($lastRun.ContainsKey($id) -and ($now - $lastRun[$id]).TotalSeconds -lt 2) {
                Write-KrLog "IGNORADA  ip=$ip  puesto=$station  cmd=$id  (repetida en menos de 2 s)"
                Send-KrReply $ctx 429 @{ ok = $false; error = 'repetido, espera 2 s'; command = $id }; continue
            }
            $lastRun[$id] = $now
            $r = Invoke-KrCommand $id $cfg
            Write-KrLog ("COMANDO  ip={0}  puesto={1}  cmd={2}  ok={3}  {4}" -f $ip, $station, $id, $r.ok, ($(if ($r.ok) { "ventana='$($r.window)' via=$($r.via)" } else { $r.error })))
            $status = $r.status; $r.Remove('status')
            Send-KrReply $ctx $status $r; continue
        }

        Send-KrReply $ctx 404 @{ ok = $false; error = 'ruta desconocida' }
    } catch {
        Write-KrLog "ERROR interno: $($_.Exception.Message)"
        try { Send-KrReply $ctx 500 @{ ok = $false; error = 'error interno' } } catch { }
    }
}
