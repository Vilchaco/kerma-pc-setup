<#
=====================================================================
  Kerma Games - PC Setup  (v5.5.5 - PowerShell)
=====================================================================
  PC nuevo, una linea en PowerShell (descarga la ultima version):
    irm https://kermasetup.netlify.app | iex
  O doble clic en Kerma-PCSetup.bat. Pide permisos de administrador solo.

  Al empezar se elige:
    - Idioma: espanol / English
    - Modo:   Automatico (aplica el perfil del PC; solo pregunta al
              principio lo que no puede saber: PC, contrasenas, programas
              que no instala) / Manual (pregunta en cada seccion) /
              Revision (muestra el estado del PC y no cambia nada)
    - PC:     de config\inventario.psd1

  Fases:
    0. Comprobaciones previas: permisos, internet, lista de IPs de David
    1. Sistema base: hora, nombres, inicio de sesion, red, Windows Update
    2. Limpieza y ajustes: ajustes del PC, apps preinstaladas
    3. Programas: instalar / actualizar
    4. Configuracion: RustDesk, audio, programas, arranque, fondo
    5. Vigilancia: panel de estado
    6. Comprobacion final, resumen y reinicio

  Configuracion (sin tocar codigo): config\inventario.psd1 (PCs),
  config\perfiles.psd1 (que se hace en cada tipo), config\programas.psd1,
  config\ajustes.psd1. Archivos: assets\. Registro: C:\KermaSetup\logs.

  Desde la linea de comandos:
    Kerma-PCSetup.bat -Lang es -Mode Auto -PC BJ01           (pregunta solo secretos y rutas)
    Kerma-PCSetup.bat -PC BJ01 -Unattended -RustDeskPassword ... -PanelPin ... -Restart
    Kerma-PCSetup.bat -Check                                 (revision)
    Kerma-PCSetup.bat -ValidateConfig                        (comprueba config\, lo usa GitHub)
=====================================================================
#>
[CmdletBinding()]
param(
    [ValidateSet('', 'es', 'en')][string]$Lang = '',
    [ValidateSet('', 'Auto', 'Manual')][string]$Mode = '',
    [string]$PC,                # clave del inventario, p. ej. BJ01
    [switch]$Unattended,        # sin ninguna pregunta (necesita -PC); como Auto
    [switch]$Restart,           # con -Unattended: reiniciar al terminar
    [switch]$Check,             # modo revision: muestra el estado, no cambia nada
    [switch]$ValidateConfig,    # comprueba config\ y muestra el plan de cada PC
    [string]$PanelPin,          # PIN del panel (para registrar el PC sin preguntar)
    [string]$RustDeskPassword   # contrasena comun de RustDesk (nunca se guarda)
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '5.5.5'
$Root = $PSScriptRoot           # las secciones cargadas con dot-source tienen otro $PSScriptRoot
$State = @{ UserRenamed = $false; HostRenamed = $false; RenameWanted = $false; NeedsRestart = $false; Changes = @() }
$Secrets = @{ RustDesk = $RustDeskPassword; PanelPin = $PanelPin }
$Auto = [bool]$Unattended -or $Mode -eq 'Auto'
$script:Lang = if ($Lang) { $Lang } else { 'es' }

. (Join-Path $Root 'lib\Comun.ps1')
. (Join-Path $Root 'lib\Config.ps1')
foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $Root 'sections') -Filter '*.ps1' | Sort-Object -Property Name)) { . $f.FullName }

# ----------------------------------------------- comprobar config (GitHub / tecnicos)
if ($ValidateConfig) {
    Import-KermaConfig
    if (Test-KermaConfig) { exit 0 } else { exit 1 }
}

# ----------------------------------------------- idioma (antes de nada, tambien para la revision)
if (-not $Lang -and -not $Unattended) {
    Write-Host ''
    Write-Host '  KERMA GAMES - PC SETUP' -ForegroundColor Cyan
    Write-Host '  1. Español'
    Write-Host '  2. English'
    $script:Lang = if ((Read-MenuChoice '  Idioma / Language' 2) -eq 1) { 'en' } else { 'es' }
}

# ----------------------------------------------- modo revision
if ($Check) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $installed = Join-Path $env:ProgramData 'Kerma\Kerma-Status.ps1'
    $collector = if (Test-Path -LiteralPath $installed) { $installed } else { Join-Path $Root 'Kerma-Status.ps1' }
    & $collector -Print -NoSend -Lang $script:Lang
    Write-Host ''
    Read-Host (L '  Press Enter to close' '  Pulsa Enter para cerrar') | Out-Null
    exit
}

# ----------------------------------------------- permisos de administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Lang', $script:Lang)
    foreach ($kv in $PSBoundParameters.GetEnumerator()) {
        if ($kv.Key -eq 'Lang') { continue }
        if ($kv.Value -is [switch]) { if ($kv.Value) { $argList += "-$($kv.Key)" } }
        else { $argList += "-$($kv.Key)"; $argList += "`"$($kv.Value)`"" }
    }
    Write-Host (L 'Requesting administrator rights...' 'Pidiendo permisos de administrador...')
    try { Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ($argList -join ' ') }
    catch { Write-Host (L 'Administrator rights were refused - nothing was changed.' 'Se rechazaron los permisos de administrador: no se cambió nada.'); Start-Sleep 3 }
    exit
}

# descargas: GitHub necesita TLS 1.2; la barra de progreso hace lentisimas las descargas grandes
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
Disable-ConsoleQuickEdit

$logDir = 'C:\KermaSetup\logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$script:LogFile = Join-Path $logDir ("setup-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
try { Start-Transcript -Path $script:LogFile | Out-Null } catch { $script:LogFile = '(-)' }

# Ejecuta una seccion aislada: si falla, lo avisa y sigue con la siguiente
function Invoke-Step([string]$fn, $pc) {
    try { & $fn $pc }
    catch {
        Write-Host ''
        Write-Fail ((L 'Section stopped by an error: {0}' 'La sección se paró por un error: {0}') -f $_.Exception.Message)
        Write-Note ((L '  ({0}, line {1}). Continuing with the next section.' '  ({0}, línea {1}). Se sigue con la siguiente sección.') -f $fn, $_.InvocationInfo.ScriptLineNumber)
        Add-Change ((L 'ERROR in {0}: {1}' 'ERROR en {0}: {1}') -f ($fn -replace '^Invoke-', ''), $_.Exception.Message)
    }
}

try {
    Import-KermaConfig
    Write-Section "KERMA GAMES - PC SETUP  v$ScriptVersion"
    Write-Host ((L '  Computer : {0}' '  Equipo   : {0}') -f $env:COMPUTERNAME)
    Write-Host ((L '  User     : {0}' '  Usuario  : {0}') -f $env:USERNAME)

    # ------------------------------------------- modo
    if (-not $Unattended -and -not $Mode) {
        Write-Host ''
        Write-Host (L '  1. Automatic - applies this PC''s profile. Only asks at the start what it cannot know.' '  1. Automático: aplica el perfil del PC. Solo pregunta al principio lo que no puede saber.')
        Write-Host (L '  2. Manual    - asks in every section, step by step.' '  2. Manual: pregunta en cada sección, paso a paso.')
        Write-Host (L '  3. Review    - shows the state of this PC and changes nothing.' '  3. Revisión: muestra el estado del PC y no cambia nada.')
        $m = Read-MenuChoice (L '  Mode' '  Modo') 3
        if ($m -eq 2) {
            $col = Join-Path $Root 'Kerma-Status.ps1'
            & $col -Print -NoSend -Lang $script:Lang
            return
        }
        $script:Auto = ($m -eq 0)
    }

    # ------------------------------------------- PC
    if ($PC) {
        $selected = $PCs | Where-Object { $_.Key -ieq $PC } | Select-Object -First 1
        if (-not $selected) { throw ((L "Unknown PC '{0}'. Valid: {1}" "PC '{0}' desconocido. Válidos: {1}") -f $PC, (($PCs | ForEach-Object { $_.Key }) -join ', ')) }
    } else {
        if ($Unattended) { throw (L '-Unattended needs -PC <key> (e.g. -PC BJ01).' '-Unattended necesita -PC <clave> (p. ej. -PC BJ01).') }
        Write-Section (L 'Which PC is this?' '¿Qué PC es este?')
        $group = ''
        for ($i = 0; $i -lt $PCs.Count; $i++) {
            if ($PCs[$i].Group -ne $group) { $group = $PCs[$i].Group; Write-Host "  --- $group ---" -ForegroundColor DarkCyan }
            Write-Host ("  {0,2}. {1}" -f ($i + 1), $PCs[$i].Label)
        }
        Write-Host "  --- $(L 'Other' 'Otro') ---" -ForegroundColor DarkCyan
        Write-Host ("  {0,2}. {1}" -f ($PCs.Count + 1), (L 'Other PC (not in the list)' 'Otro PC (no está en la lista)'))
        Write-Host ''
        $n = Read-MenuChoice (L '  Number' '  Número') ($PCs.Count + 1)
        $selected = if ($n -eq $PCs.Count) { New-AdHocPC } else { $PCs[$n] }
    }
    $script:Prof = $Profiles[$selected.Profile]

    # ------------------------------------------- fase 0: comprobaciones previas
    Write-Phase (L 'PHASE 0 - CHECKS' 'FASE 0 - COMPROBACIONES')
    $online = Test-Internet
    if ($online) { Write-Ok (L 'Internet: OK' 'Internet: OK') } else { Write-Warn (L 'No internet: programs, time sync and the panel will fail. Check the cable / network.' 'Sin internet: fallarán los programas, la hora y el panel. Revisa el cable o la red.') }
    if ($online -and (Merge-DavidIPs)) { Write-Ok (L "IPs taken from David's list." 'IPs tomadas de la lista de David.') }
    else { Write-Note (L "  David's list could not be read (private repo or no internet): using the inventory IPs." '  No se pudo leer la lista de David (repositorio privado o sin internet): se usan las IPs del inventario.') }
    # ojo: no llamar $mode a esta variable: es el parametro -Mode (ValidateSet) y fallaria
    $modeText = if ($Auto) { L 'Automatic' 'Automático' } else { 'Manual' }
    Write-Host ''
    Write-Host ((L '  PC       : {0}  [{1}]' '  PC       : {0}  [{1}]') -f $selected.Label, (Get-ProfileName $Prof)) -ForegroundColor Cyan
    Write-Host ((L '  Mode     : {0}' '  Modo     : {0}') -f $modeText) -ForegroundColor Cyan
    Write-Host ((L '  IP       : {0}' '  IP       : {0}') -f $(if ($selected.Net.IP) { $selected.Net.IP } else { L '(none - network left as it is)' '(ninguna: la red se queda como está)' })) -ForegroundColor Cyan

    # ------------------------------------------- en Automatico: todo lo que hay que preguntar, ahora
    if ($Auto -and -not $Unattended) {
        Write-Section (L 'BEFORE STARTING  (then you can leave the PC working)' 'ANTES DE EMPEZAR  (luego puedes dejar el PC trabajando)')
        if ($Prof.RustDesk -ne 'None' -and $selected.RustDesk -and -not $Secrets.RustDesk) {
            $Secrets.RustDesk = Read-NewSecret (L 'RustDesk common password' 'Contraseña común de RustDesk')
        }
        if ($Prof.Panel -and -not (Test-PanelRegistered) -and -not $Secrets.PanelPin) {
            $Secrets.PanelPin = Read-Secret ('  ' + (L 'Status panel PIN (input is hidden; Enter to skip)' 'PIN del panel de estado (no se ve al escribir; Enter para saltar)'))
        }
        if (-not $selected.Net.IP -and $Prof.StaticIP) {
            $ipNew = Read-Host (L '  Static IP for this PC (Enter = leave the network as it is)' '  IP fija para este PC (Enter = dejar la red como está)')
            if (Test-IPv4 $ipNew) { $selected.Net.IP = $ipNew.Trim(); $selected.IPSource = 'typed' }
        }
        Resolve-AutostartPathsUpfront $selected
        Write-Host ''
        Write-Ok (L 'All set - from here on it runs by itself.' 'Listo: a partir de aquí funciona solo.')
    }

    # ------------------------------------------- fases
    Write-Phase (L 'PHASE 1 - BASE SYSTEM' 'FASE 1 - SISTEMA BASE')
    foreach ($s in @('Invoke-TimeSetup', 'Invoke-Rename', 'Invoke-NetworkSetup', 'Invoke-WindowsUpdateSetup')) { Invoke-Step $s $selected }
    Write-Phase (L 'PHASE 2 - CLEAN-UP AND SETTINGS' 'FASE 2 - LIMPIEZA Y AJUSTES')
    foreach ($s in @('Invoke-PcTuning', 'Invoke-RemoveJunk')) { Invoke-Step $s $selected }
    Write-Phase (L 'PHASE 3 - PROGRAMS' 'FASE 3 - PROGRAMAS')
    Invoke-Step 'Invoke-InstallPrograms' $selected
    Write-Phase (L 'PHASE 4 - CONFIGURATION' 'FASE 4 - CONFIGURACIÓN')
    foreach ($s in @('Invoke-RemoteAccess', 'Invoke-AudioSetup', 'Invoke-ProgramSettings', 'Invoke-AppAutostart', 'Invoke-Wallpaper')) { Invoke-Step $s $selected }
    Write-Phase (L 'PHASE 5 - MONITORING' 'FASE 5 - VIGILANCIA')
    Invoke-Step 'Invoke-StatusPanel' $selected
    Write-Phase (L 'PHASE 6 - CHECK AND SUMMARY' 'FASE 6 - COMPROBACIÓN Y RESUMEN')
    Invoke-Step 'Invoke-Verification' $selected
    # nombres e inicio de sesion, lo ultimo: renombrar la cuenta en uso deja a Windows sin reconocerla hasta reiniciar
    Write-Phase (L 'PHASE 7 - NAMES AND LOGIN' 'FASE 7 - NOMBRES E INICIO DE SESIÓN')
    foreach ($s in @('Invoke-RenameApply', 'Invoke-LoginSetup')) { Invoke-Step $s $selected }
    $Secrets.RustDesk = $null; $Secrets.PanelPin = $null
    $script:Auto = [bool]$Unattended    # la pregunta de reiniciar se hace siempre (salvo -Unattended)
    Invoke-Finish
} catch {
    Write-Host ''
    Write-Fail $_.Exception.Message
} finally {
    try { Stop-Transcript | Out-Null } catch { }
    # el log completo de esta ejecucion va al panel (tambien si algo fallo)
    try { Send-SetupLog $(if ($selected) { $selected.Key } else { '' }) } catch { }
    if (-not $Unattended) { Write-Host ''; Read-Host (L '  Press Enter to close' '  Pulsa Enter para cerrar') | Out-Null }
}
