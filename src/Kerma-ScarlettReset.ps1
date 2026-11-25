<#
=====================================================================
  Kerma Games - reinicio remoto de la Scarlett (Focusrite) de la mesa
=====================================================================
  La logica del reinicio es la del agente de David
  (restidavid/Kerma-Scarlett-Remote-Reset, ScarlettResetAgent.ps1):
  pnputil /restart-device y, si la Scarlett no vuelve bien, desactivar y
  activar el dispositivo y buscar cambios de hardware.

  Lo usan:
    - Agente Scarlett de MCR (puerto 8765, como SYSTEM).
    - Kerma Remote (boton de Companion): -File ... -By "remote ..."
    - Kerma-Status (boton del panel, como SYSTEM): lo carga con ". " y
      llama a Invoke-KsScarlettReset / Get-KsScarlettInfo.

  Que Scarlett: la que tiene configurada el agente de David (solo se lee
  deviceInstanceId y deviceFriendlyName de su config.json, nunca su clave).
  Si no hay, la regla de David: una sola Focusrite/Scarlett USB; si hay
  mas de una, no se toca nada.

  No se pisa con otro reinicio: ni con uno nuestro en marcha (cerrojo) ni
  con uno del agente de David (se mira el final de su agent.log, sin
  escribir en el).

    -Check   solo dice que Scarlett usaria, sin reiniciar nada
    -By      quien lo pide (se guarda en el registro)
    -Since   (panel) fecha de la orden: si ya se reinicio despues, no repite

  Necesita administrador (o SYSTEM). Texto plano ASCII (PowerShell 5.1).
  Salida: una linea JSON con el resultado.
=====================================================================
#>
[CmdletBinding()]
param([switch]$Check, [string]$By = 'manual', [string]$Since)

$KsDir       = Join-Path $env:ProgramData 'Kerma'
$KsLast      = Join-Path $KsDir 'scarlett-last.json'
$KsLog       = Join-Path $KsDir 'scarlett.log'
$KsLock      = Join-Path $KsDir 'scarlett.lock'
$KsDavidDir  = Join-Path $env:ProgramData 'KermaGames\ScarlettReset'
$KsDavidTask = 'Kerma Games Scarlett Solo Reset Agent'

function Write-KsLog([string]$m) {
    try { Add-Content -LiteralPath $KsLog -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -Encoding UTF8 } catch { }
}

function Test-KsAdmin {
    try { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { return $false }
}

# Solo los dos campos del dispositivo: el config de David tambien lleva su clave
function Get-KsDavidDevice {
    $f = Join-Path $KsDavidDir 'config.json'
    if (-not (Test-Path -LiteralPath $f)) { return $null }
    try {
        $j = Get-Content -LiteralPath $f -Raw | ConvertFrom-Json
        return @{ InstanceId = [string]$j.deviceInstanceId; Name = [string]$j.deviceFriendlyName }
    } catch { return $null }
}

function Test-KsDavidAgent { return [bool](Get-ScheduledTask -TaskName $KsDavidTask -ErrorAction SilentlyContinue) }

# Que Scarlett: la de David si esta conectada; si no, una sola Focusrite/Scarlett USB
function Resolve-KsScarlett {
    $d = Get-KsDavidDevice
    if ($d -and $d.InstanceId) {
        $dev = Get-PnpDevice -PresentOnly -InstanceId $d.InstanceId -ErrorAction SilentlyContinue
        if ($dev) { return @{ Device = $dev; Source = 'david' } }
    }
    $c = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
        $_.InstanceId -like 'USB*' -and ($_.FriendlyName -like '*Scarlett*' -or $_.FriendlyName -like '*Focusrite*') })
    if ($d -and $d.Name) {
        $same = @($c | Where-Object { $_.FriendlyName -eq $d.Name })
        if ($same.Count -eq 1) { return @{ Device = $same[0]; Source = 'david-name' } }
    }
    if ($c.Count -eq 1) { return @{ Device = $c[0]; Source = 'auto' } }
    if ($c.Count -eq 0) { return @{ Error = 'Windows no ve ninguna Scarlett conectada' } }
    return @{ Error = ('hay {0} dispositivos Focusrite/Scarlett: no se toca ninguno para no equivocarse' -f $c.Count) }
}

function Get-KsLast {
    if (-not (Test-Path -LiteralPath $KsLast)) { return $null }
    try { return (Get-Content -LiteralPath $KsLast -Raw | ConvertFrom-Json) } catch { return $null }
}

# Otro reinicio en marcha: el nuestro (cerrojo de menos de 90 s) o el de David
# (en su agent.log, un "Restart requested" de hace menos de 60 s sin cerrar)
function Test-KsBusy {
    $log = Join-Path $KsDavidDir 'agent.log'
    if (Test-Path -LiteralPath $log) {
        try {
            $tail = @(Get-Content -LiteralPath $log -Tail 20 -ErrorAction Stop)
            $open = $null
            foreach ($l in $tail) {
                if ($l -match '^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\dZ) (.*)$') {
                    $t = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]'AdjustToUniversal,AssumeUniversal')
                    if ($Matches[2] -like 'Restart requested*') { $open = $t }
                    elseif ($Matches[2] -like 'Restart completed*' -or $Matches[2] -like 'Request error*') { $open = $null }
                }
            }
            if ($open -and ((Get-Date).ToUniversalTime() - $open).TotalSeconds -lt 60) { return 'ya se esta reiniciando desde el panel de David' }
        } catch { }
    }
    return $null
}

function Get-KsState([string]$id) {
    try { return (Get-PnpDevice -PresentOnly -InstanceId $id -ErrorAction Stop) } catch { return $null }
}

# Para el panel (Kerma-Status): que Scarlett hay, como esta y el ultimo reinicio
function Get-KsScarlettInfo {
    $r = Resolve-KsScarlett
    $info = [ordered]@{ v = 1; device = $null; status = $null; source = $null; error = $null; david_agent = (Test-KsDavidAgent); last = (Get-KsLast) }
    if ($r.Error) { $info.error = $r.Error } else { $info.device = [string]$r.Device.FriendlyName; $info.status = [string]$r.Device.Status; $info.source = $r.Source }
    return $info
}

function Save-KsResult($res) {
    try { $res | ConvertTo-Json -Compress | Set-Content -LiteralPath $KsLast -Encoding UTF8 } catch { }
    Write-KsLog ('{0}  por={1}  {2}  {3}' -f $(if ($res.ok) { 'OK' } elseif ($res.skipped) { 'OMITIDO' } else { 'FALLO' }), $res.by, $res.device, $res.msg)
}

function Invoke-KsScarlettReset([string]$by = 'manual', [string]$since) {
    $res = [ordered]@{ at = (Get-Date).ToUniversalTime().ToString('o'); by = $by; ok = $false; skipped = $false; busy = $false; device = $null; method = $null; status = $null; msg = '' }
    if (-not (Test-KsAdmin)) { $res.msg = 'hace falta administrador para reiniciar la Scarlett'; return $res }
    try {
        $lock = [IO.File]::Open($KsLock, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    } catch [IO.IOException] {
        $res.busy = $true
        $res.msg = 'ya se esta reiniciando o no se puede abrir el cerrojo'
        return $res
    }
    try {
        $last = Get-KsLast
        if ($last -and $last.ok) {
            $lastAt = ([datetime]$last.at).ToUniversalTime()
            $requestedAt = [datetime]::MinValue
            $alreadyRun = $since -and [datetime]::TryParse($since, [ref]$requestedAt) -and $lastAt -gt $requestedAt.ToUniversalTime()
            if ($alreadyRun -or
                $lastAt -gt [datetime]::UtcNow.AddSeconds(-10)) {
                $res.skipped = $true
                $res.msg = 'ya se reinicio recientemente'
                Write-KsLog ('OMITIDO  por={0}  reinicio reciente' -f $by)
                return $res
            }
        }
        $busy = Test-KsBusy
        if ($busy) { $res.busy = $true; $res.msg = $busy; return $res }
        $r = Resolve-KsScarlett
        if ($r.Error) { $res.msg = $r.Error; Save-KsResult $res; return $res }
        $dev = $r.Device
        $id = $dev.InstanceId
        $res.device = [string]$dev.FriendlyName
        try {
            Write-KsLog ("Reinicio pedido por {0}: '{1}' [{2}] estado {3}" -f $by, $dev.FriendlyName, $id, $dev.Status)
            $out = & "$env:WINDIR\System32\pnputil.exe" /restart-device $id 2>&1
            $code = $LASTEXITCODE
            Start-Sleep -Seconds 3
            $cur = Get-KsState $id
            if ($code -eq 0 -and $cur -and $cur.Status -eq 'OK') {
                $res.ok = $true; $res.method = 'pnputil'; $res.status = 'OK'; $res.msg = 'reiniciada'
            } else {
                $st = if ($cur) { $cur.Status } else { 'no aparece' }
                Write-KsLog ("pnputil no la recupero (codigo {0}, estado {1}): desactivar y activar" -f $code, $st)
                Disable-PnpDevice -InstanceId $id -Confirm:$false -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                Enable-PnpDevice -InstanceId $id -Confirm:$false -ErrorAction Stop
                & "$env:WINDIR\System32\pnputil.exe" /scan-devices 2>&1 | Out-Null
                Start-Sleep -Seconds 4
                $cur = Get-KsState $id
                $res.method = 'desactivar/activar'
                if (-not $cur) { $res.msg = 'la Scarlett no volvio a aparecer: desconecta y conecta su cable USB' }
                elseif ($cur.Status -ne 'OK') { $res.status = [string]$cur.Status; $res.msg = "Windows sigue viendola con estado '$($cur.Status)'" }
                else { $res.ok = $true; $res.status = 'OK'; $res.msg = 'reiniciada (desactivar/activar)' }
            }
        } catch {
            $res.msg = 'error: ' + $_.Exception.Message
        }
        $res.at = [datetime]::UtcNow.ToString('o')
        Save-KsResult $res
        return $res
    } finally {
        $lock.Dispose()
    }
}

# ------------------------------------------------------------- ejecutado con -File
if ($MyInvocation.InvocationName -ne '.') {
    if ($Check) {
        $i = Get-KsScarlettInfo
        $i['elevated'] = (Test-KsAdmin)
        $d = Get-KsDavidDevice
        $i['david_device'] = if ($d) { $d.Name } else { $null }
        $i | ConvertTo-Json -Compress -Depth 4
        exit 0
    }
    $r = Invoke-KsScarlettReset $By $Since
    $r | ConvertTo-Json -Compress
    if ($r.ok -or $r.skipped) { exit 0 } elseif ($r.busy) { exit 2 } else { exit 1 }
}
