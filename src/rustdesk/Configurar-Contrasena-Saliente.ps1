[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Contrasena
)

$ErrorActionPreference = 'Stop'
$activos = @(Get-CimInstance Win32_Process -Filter "Name='rustdesk.exe'" -ErrorAction Stop |
    Where-Object {
        $_.SessionId -ne 0 -and
        [string]$_.CommandLine -notmatch '(?i)(?:^|\s)--(?:server|service|tray|cm|portable-service)(?:\s|$)'
    })
if ($activos.Count -gt 0) {
    throw 'La ventana principal de RustDesk sigue abierta. Cierra RustDesk para guardar su contrasena saliente.'
}

$carpeta = Join-Path (Join-Path $env:APPDATA 'RustDesk') 'config'
$archivo = Join-Path $carpeta 'RustDesk2.toml'
New-Item -ItemType Directory -Path $carpeta -Force | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$contenido = if (Test-Path -LiteralPath $archivo -PathType Leaf) {
    [System.IO.File]::ReadAllText($archivo, [System.Text.Encoding]::UTF8)
} else { '' }
$valor = ConvertTo-Json -InputObject $Contrasena -Compress
$linea = 'default-connect-password = ' + $valor
$secciones = [regex]::Matches($contenido, '(?m)^[ \t]*\[options\][ \t]*(?:\#.*)?\r?$')
if ($secciones.Count -gt 1) { throw 'RustDesk2.toml contiene varias secciones [options]. No se modifico.' }

if ($secciones.Count -eq 0) {
    if ($contenido.Length -gt 0 -and -not $contenido.EndsWith("`n")) { $contenido += "`r`n" }
    $contenido += "[options]`r`n$linea`r`n"
} else {
    $inicio = $secciones[0].Index + $secciones[0].Length
    if ($inicio -lt $contenido.Length -and $contenido[$inicio] -eq "`n") { $inicio++ }
    $resto = $contenido.Substring($inicio)
    $siguiente = [regex]::Match($resto, '(?m)^[ \t]*\[[^\r\n]+\][ \t]*(?:\#.*)?\r?$')
    $fin = if ($siguiente.Success) { $inicio + $siguiente.Index } else { $contenido.Length }
    $opciones = $contenido.Substring($inicio, $fin - $inicio)
    $coincidencias = [regex]::Matches($opciones, '(?m)^[ \t]*["'']?default-connect-password["'']?[ \t]*=[^\r\n]*')
    if ($coincidencias.Count -gt 1) { throw 'Hay varias contrasenas salientes en [options]. No se modifico.' }
    if ($coincidencias.Count -eq 1) {
        $coincidencia = $coincidencias[0]
        $posicion = $inicio + $coincidencia.Index
        $contenido = $contenido.Substring(0, $posicion) + $linea +
            $contenido.Substring($posicion + $coincidencia.Length)
    } else {
        $contenido = $contenido.Substring(0, $inicio) + "`r`n$linea`r`n" + $contenido.Substring($inicio)
    }
}

if (Test-Path -LiteralPath $archivo -PathType Leaf) {
    $respaldo = "$archivo.$(Get-Date -Format yyyyMMdd-HHmmss)-$PID.bak"
    Copy-Item -LiteralPath $archivo -Destination $respaldo -ErrorAction Stop
}
$temporal = "$archivo.tmp-$PID"
try {
    [System.IO.File]::WriteAllText($temporal, $contenido, $utf8)
    Move-Item -LiteralPath $temporal -Destination $archivo -Force
} finally {
    Remove-Item -LiteralPath $temporal -Force -ErrorAction SilentlyContinue
}
$comprobado = [System.IO.File]::ReadAllText($archivo, [System.Text.Encoding]::UTF8)
if (-not $comprobado.Contains($linea)) { throw 'RustDesk2.toml no conservo la contrasena saliente.' }
Write-Host 'Contrasena saliente predeterminada guardada en el perfil de este usuario. Se aplicara al reabrir RustDesk.'
