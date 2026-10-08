#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configura el RustDesk instalado en esta PC Windows.
.DESCRIPTION
    Establece contrasena permanente, IP directa, ajuste remoto y vista adaptable.
    No reinicia el servicio para no interrumpir una sesion RustDesk activa.
#>
[CmdletBinding()]
param(
    [ValidateSet('Master', 'Client')]
    [string]$Modo = 'Master',
    [ValidateRange(1, 65535)]
    [int]$Puerto = 21118,
    [ValidateNotNullOrEmpty()]
    [string[]]$OrigenesPermitidos = @('LocalSubnet', '192.168.0.0/24', '192.168.1.0/24'),
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [string]$Contrasena,
    [switch]$ReiniciarServicio
)

$ErrorActionPreference = 'Stop'
$rutas = @((Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'))
if (${env:ProgramFiles(x86)}) {
    $rutas += Join-Path ${env:ProgramFiles(x86)} 'RustDesk\rustdesk.exe'
}
$servicio = Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue
if (-not $servicio) {
    $instalador = $rutas | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $instalador) { throw 'RustDesk debe estar instalado en Program Files para crear su servicio.' }
    Write-Host 'No se encontró el servicio RustDesk. Se intentará instalar con el ejecutable existente.'
    & $instalador --install-service | Out-String | Out-Null
    for ($espera = 0; $espera -lt 20; $espera++) {
        Start-Sleep -Seconds 1
        $servicio = Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue
        if ($servicio) { break }
    }
    if (-not $servicio) { throw 'RustDesk no creó su servicio. Instala RustDesk desde su interfaz y vuelve a ejecutar el asistente.' }
}
Set-Service -Name 'RustDesk' -StartupType Automatic -ErrorAction Stop
$servicioCim = Get-CimInstance Win32_Service -Filter "Name='RustDesk'" -ErrorAction SilentlyContinue
$rutaServicio = ''
if ($servicioCim -and $servicioCim.PathName) {
    $textoRuta = [string]$servicioCim.PathName
    if ($textoRuta -match '^\s*"([^"]+\.exe)"') {
        $rutaServicio = $Matches[1]
    } elseif ($textoRuta -match '^\s*(.+?\.exe)(?:\s|$)') {
        $rutaServicio = $Matches[1]
    }
}
if ($rutaServicio -and
    ([System.IO.Path]::GetFileName($rutaServicio) -match '(?i)^rustdesk.*\.exe$') -and
    (Test-Path -LiteralPath $rutaServicio -PathType Leaf)) {
    $rustdesk = $rutaServicio
} else {
    $rustdesk = $rutas | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $rustdesk) { throw 'No se encontro el ejecutable de RustDesk del servicio.' }
Write-Host "RustDesk: $rustdesk"

if ($ReiniciarServicio) {
    Write-Warning 'RustDesk se reiniciara en 8 segundos. La sesion remota se desconectara; este script continuara en la PC Windows.'
    Start-Sleep -Seconds 8
    Restart-Service -Name 'RustDesk' -Force -ErrorAction Stop
    (Get-Service -Name 'RustDesk').WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
    Start-Sleep -Seconds 3
} elseif ($servicio.Status -ne 'Running') {
    Start-Service -Name 'RustDesk'
    (Get-Service -Name 'RustDesk').WaitForStatus('Running', [TimeSpan]::FromSeconds(20))
    Start-Sleep -Seconds 2
}

$resultadoContrasena = ''
for ($intento = 1; $intento -le 4; $intento++) {
    $resultadoContrasena = (& $rustdesk --password $Contrasena | Out-String).Trim()
    if ($resultadoContrasena -match 'Done!') { break }
    if ($resultadoContrasena -match 'Installation and administrative privileges required|Settings are disabled|Changing permanent password is disabled') { break }
    if ($resultadoContrasena -notmatch 'os error 2|The system cannot find the file specified') { break }
    if ($intento -lt 4) { Start-Sleep -Seconds 2 }
}
if ($resultadoContrasena -match 'Installation and administrative privileges required|Settings are disabled|Changing permanent password is disabled') {
    throw "RustDesk rechazo la contrasena: $resultadoContrasena"
}
if ($resultadoContrasena -match 'os error 2|The system cannot find the file specified') {
    $estado = (Get-Service -Name 'RustDesk').Status
    $siguientePaso = if ($ReiniciarServicio) {
        'El reinicio tampoco restablecio IPC. Revisa el registro del servicio RustDesk y la instalacion.'
    } else {
        'Cuando termine la sesion remota, ejecuta Reiniciar-Servicio-y-Configurar.cmd en la PC Windows.'
    }
    throw "RustDesk no encontro su canal de comunicacion local (IPC) tras cuatro intentos. Servicio: $estado. Ejecutable: $rustdesk. No se cambiaron la contrasena ni las demas opciones. $siguientePaso Respuesta de RustDesk: $resultadoContrasena"
}
if ($resultadoContrasena -notmatch 'Done!') {
    throw "RustDesk no confirmo la contrasena permanente. Respuesta: '$resultadoContrasena'."
}

& $rustdesk --option direct-access-port "$Puerto" | Out-Null
& $rustdesk --option direct-server Y | Out-Null
& $rustdesk --option allow-remote-config-modification Y | Out-Null
& $rustdesk --option approve-mode password | Out-Null
& $rustdesk --option verification-method use-permanent-password | Out-Null
if ($Modo -eq 'Master') {
    & $rustdesk --option default-connect-password $Contrasena | Out-Null
} else {
    foreach ($permiso in @('enable-keyboard', 'enable-clipboard', 'enable-file-transfer', 'enable-audio', 'enable-remote-restart')) {
        & $rustdesk --option $permiso Y | Out-Null
    }
    & $rustdesk --option access-mode custom | Out-Null
}

$esperado = [ordered]@{
    'direct-access-port' = "$Puerto"
    'direct-server' = 'Y'
    'allow-remote-config-modification' = 'Y'
    'approve-mode' = 'password'
    'verification-method' = 'use-permanent-password'
}
if ($Modo -eq 'Client') {
    $esperado['access-mode'] = 'custom'
    foreach ($permiso in @('enable-keyboard', 'enable-clipboard', 'enable-file-transfer', 'enable-audio', 'enable-remote-restart')) {
        $esperado[$permiso] = 'Y'
    }
}
foreach ($nombre in $esperado.Keys) {
    $actual = (& $rustdesk --option $nombre | Out-String).Trim()
    if ($actual -ne $esperado[$nombre]) {
        throw "RustDesk no confirmo $nombre. Esperado '$($esperado[$nombre])'; actual '$actual'."
    }
}
if ($Modo -eq 'Master') {
    $passwordConexion = (& $rustdesk --option default-connect-password | Out-String).Trim()
    if ($passwordConexion -ne $Contrasena) {
        throw 'RustDesk no confirmo la contrasena predeterminada para conexiones salientes.'
    }
    $passwordConexion = $null
}

$nombreRegla = 'RustDesk-DirectIP-Local'
if (Get-NetFirewallRule -Name $nombreRegla -ErrorAction SilentlyContinue) {
    Remove-NetFirewallRule -Name $nombreRegla
}
$perfilesRegla = if ($Modo -eq 'Client') { @('Domain', 'Private', 'Public') } else { @('Domain', 'Private') }
New-NetFirewallRule `
    -Name $nombreRegla `
    -DisplayName 'RustDesk - IP directa desde LAN' `
    -Description 'Puerto de acceso directo a RustDesk desde la red local.' `
    -Enabled True `
    -Direction Inbound `
    -Action Allow `
    -Profile $perfilesRegla `
    -Protocol TCP `
    -LocalPort $Puerto `
    -RemoteAddress $OrigenesPermitidos | Out-Null

$escuchando = Get-NetTCPConnection -LocalPort $Puerto -State Listen -ErrorAction SilentlyContinue
if (-not $escuchando) {
    Write-Warning "El puerto $Puerto aun no escucha. Reinicia el servicio RustDesk cuando termines la sesion remota y vuelve a verificarlo."
}
$perfilesPublicos = Get-NetConnectionProfile -ErrorAction SilentlyContinue |
    Where-Object { $_.NetworkCategory -eq 'Public' }
if ($perfilesPublicos -and $Modo -eq 'Master') {
    Write-Warning 'Hay una red con perfil Publico. La regla creada solo permite perfiles Privado o Dominio.'
}

Write-Host "Configuracion aplicada en esta PC Windows ($Modo):"
Write-Host '- Contrasena permanente confirmada por RustDesk.'
Write-Host "- Acceso directo por IP en TCP $Puerto (origenes: $($OrigenesPermitidos -join ', '))."
Write-Host '- Modificacion remota de ajustes habilitada.'
Write-Host '- Acceso entrante por contrasena permanente, sin aprobacion manual.'
if ($Modo -eq 'Master') {
    Write-Host '- Scale adaptive se configura por usuario con Configurar-Display.ps1.'
    Write-Host '- Contrasena predeterminada para conexiones salientes configurada.'
} else {
    Write-Host '- Teclado, portapapeles, transferencia, audio y reinicio remoto habilitados.'
    Write-Host '- Acceso entrante permitido desde LocalSubnet en todos los perfiles de red.'
}
if ($ReiniciarServicio) {
    Write-Host 'El servicio se reinicio antes de aplicar los ajustes.'
} else {
    Write-Host 'El servicio no se reinicio; la sesion remota actual permanece conectada.'
}
