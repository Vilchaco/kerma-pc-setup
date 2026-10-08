<#
.SYNOPSIS
    Selecciona Scale adaptive en Settings > Display para este usuario Windows.
.DESCRIPTION
    Edita RustDesk_default.toml, que almacena el valor de la opcion visual
    Default View Style. Conserva las otras opciones y respalda el archivo.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
if (-not $env:APPDATA) { throw 'APPDATA no esta definido; ejecuta esto en Windows con el usuario de RustDesk.' }
$configDir = Join-Path (Join-Path $env:APPDATA 'RustDesk') 'config'
$archivo = Join-Path $configDir 'RustDesk_default.toml'
New-Item -Path $configDir -ItemType Directory -Force | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$contenido = if (Test-Path -LiteralPath $archivo -PathType Leaf) {
    [System.IO.File]::ReadAllText($archivo, [System.Text.Encoding]::UTF8)
} else { '' }

$secciones = [regex]::Matches($contenido, '(?m)^[ \t]*\[options\][ \t]*(?:\#.*)?\r?$')
if ($secciones.Count -gt 1) { throw "Hay varias secciones [options] en $archivo; no se modifico." }

if ($secciones.Count -eq 1) {
    $inicio = $secciones[0].Index + $secciones[0].Length
    $saltoAntes = ''
    if ($inicio -lt $contenido.Length -and $contenido[$inicio] -eq "`n") {
        $inicio++
    } else {
        $saltoAntes = if ($inicio -gt 0 -and $contenido[$inicio - 1] -eq "`r") { "`n" } else { "`r`n" }
    }
    $resto = $contenido.Substring($inicio)
    $siguiente = [regex]::Match($resto, '(?m)^[ \t]*\[[^\r\n]+\][ \t]*(?:\#.*)?\r?$')
    $fin = if ($siguiente.Success) { $inicio + $siguiente.Index } else { $contenido.Length }
    $opciones = $contenido.Substring($inicio, $fin - $inicio)
    $vistas = [regex]::Matches($opciones, '(?m)^[ \t]*view_style[ \t]*=[^\r\n]*')
    if ($vistas.Count -gt 1) { throw "Hay varias opciones view_style en $archivo; no se modifico." }
    if ($vistas.Count -eq 1) {
        $vista = $vistas[0]
        $actual = $vista.Value
        $deseado = "view_style = 'adaptive'"
        if ($actual -eq $deseado) {
            Write-Host "Scale adaptive ya esta seleccionado en $archivo"
            return
        }
        $pos = $inicio + $vista.Index
        $contenido = $contenido.Substring(0, $pos) + $deseado +
            $contenido.Substring($pos + $vista.Length)
    } else {
        $contenido = $contenido.Substring(0, $inicio) + $saltoAntes + "view_style = 'adaptive'`r`n" +
            $contenido.Substring($inicio)
    }
} else {
    if ($contenido.Length -gt 0 -and -not $contenido.EndsWith("`n")) {
        $contenido += "`r`n"
    }
    $contenido += "[options]`r`nview_style = 'adaptive'`r`n"
}

if (Test-Path -LiteralPath $archivo -PathType Leaf) {
    $respaldo = "$archivo.$(Get-Date -Format yyyyMMdd-HHmmss).bak"
    Copy-Item -LiteralPath $archivo -Destination $respaldo -ErrorAction Stop
    Write-Host "Respaldo: $respaldo"
}
$temporal = "$archivo.tmp-$PID"
try {
    [System.IO.File]::WriteAllText($temporal, $contenido, $utf8)
    Move-Item -LiteralPath $temporal -Destination $archivo -Force
} finally {
    if (Test-Path -LiteralPath $temporal) { Remove-Item -LiteralPath $temporal -Force }
}

$verificado = [System.IO.File]::ReadAllText($archivo, [System.Text.Encoding]::UTF8)
if ($verificado -notmatch '(?m)^[ \t]*view_style[ \t]*=[ \t]*''adaptive''[ \t]*\r?$') {
    throw "No se pudo verificar Scale adaptive en $archivo"
}
Write-Host "Scale adaptive seleccionado en Settings > Display: $archivo"
Write-Host 'Reabre Settings > Display para ver el cambio. Las sesiones ya abiertas conservan su escala actual.'
