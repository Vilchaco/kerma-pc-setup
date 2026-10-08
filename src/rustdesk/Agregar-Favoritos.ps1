<#
.SYNOPSIS
    Agrega los equipos importados a los Favoritos locales de RustDesk.
.DESCRIPTION
    Conserva los favoritos existentes y crea solo los archivos de par que falten.
    Ejecutar con RustDesk cerrado para evitar que sobrescriba su configuracion.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [object[]]$Equipos
)

$ErrorActionPreference = 'Stop'
if ($Equipos.Count -eq 0) { throw 'No hay equipos para agregar.' }

$procesosUi = @(Get-CimInstance Win32_Process -Filter "Name='rustdesk.exe'" -ErrorAction Stop |
    Where-Object {
        $_.SessionId -ne 0 -and
        [string]$_.CommandLine -notmatch '(?i)(?:^|\s)--(?:server|service|tray|cm|portable-service)(?:\s|$)'
    })
if ($procesosUi.Count -gt 0) {
    throw 'Cierra la ventana principal de RustDesk antes de importar Favoritos; de otro modo la aplicación puede restaurar su lista anterior.'
}

& (Join-Path $PSScriptRoot 'Configurar-Display.ps1')

$configDir = Join-Path (Join-Path $env:APPDATA 'RustDesk') 'config'
$archivoLocal = Join-Path $configDir 'RustDesk_local.toml'
$carpetaPeers = Join-Path $configDir 'peers'
New-Item -ItemType Directory -Path $carpetaPeers -Force | Out-Null

$ids = New-Object 'System.Collections.Generic.List[string]'
foreach ($equipo in $Equipos) {
    $ip = [string]$equipo.IP
    $puerto = [int]$equipo.Puerto
    $direccion = $null
    if (-not [System.Net.IPAddress]::TryParse($ip, [ref]$direccion) -or
        $direccion.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork -or
        $puerto -lt 1 -or $puerto -gt 65535) {
        throw "Direccion invalida: $ip`:$puerto"
    }
    $id = if ($puerto -eq 21118) { $direccion.ToString() } else { "$($direccion.ToString()):$puerto" }
    if (-not $ids.Contains($id)) { $ids.Add($id) }
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$contenido = if (Test-Path -LiteralPath $archivoLocal) {
    [System.IO.File]::ReadAllText($archivoLocal, [System.Text.Encoding]::UTF8)
} else { '' }

$coincidenciasFav = [regex]::Matches($contenido, '(?m)^[ \t]*fav[ \t]*=[ \t]*\[')
if ($coincidenciasFav.Count -gt 1) {
    throw 'El archivo contiene mas de una lista de Favoritos. No se modifico.'
}
if ($coincidenciasFav.Count -eq 0 -and $contenido -match '(?m)^[ \t]*fav[ \t]*=') {
    throw 'RustDesk usa un formato de Favoritos no reconocido. No se modifico el archivo.'
}

$inicioArreglo = -1
$finArreglo = -1
$valoresExistentes = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList ([System.StringComparer]::Ordinal)
$ordenExistente = New-Object 'System.Collections.Generic.List[string]'
if ($coincidenciasFav.Count -eq 1) {
    $inicioArreglo = $coincidenciasFav[0].Index + $coincidenciasFav[0].Length - 1
    $profundidad = 0
    $comilla = ''
    $escape = $false
    $comentario = $false
    $valor = New-Object System.Text.StringBuilder
    for ($pos = $inicioArreglo; $pos -lt $contenido.Length; $pos++) {
        $caracter = $contenido[$pos]
        if ($comentario) {
            if ($caracter -eq "`n") { $comentario = $false }
            continue
        }
        if ($comilla) {
            if ($escape) {
                [void]$valor.Append($caracter)
                $escape = $false
            } elseif ($comilla -eq '"' -and $caracter -eq '\') {
                $escape = $true
            } elseif ($caracter -eq $comilla) {
                [void]$valoresExistentes.Add($valor.ToString())
                $ordenExistente.Add($valor.ToString())
                $comilla = ''
            } else {
                [void]$valor.Append($caracter)
            }
            continue
        }
        if ($caracter -eq '#') {
            $comentario = $true
        } elseif ($caracter -eq '"' -or $caracter -eq "'") {
            $comilla = [string]$caracter
            [void]$valor.Clear()
        } elseif ($caracter -eq '[') {
            $profundidad++
            if ($profundidad -gt 1) {
                throw 'La lista de Favoritos contiene una lista anidada inesperada. No se modifico.'
            }
        } elseif ($caracter -eq ']') {
            $profundidad--
            if ($profundidad -eq 0) {
                $finArreglo = $pos
                break
            }
        }
    }
    if ($finArreglo -lt 0 -or $comilla) {
        throw 'La lista de Favoritos no termina correctamente. No se modifico el archivo.'
    }
}

$pendientes = New-Object 'System.Collections.Generic.List[string]'
foreach ($id in $ids) {
    $literalDoble = '"' + $id + '"'
    if (-not $valoresExistentes.Contains($id)) {
        $pendientes.Add($literalDoble)
    }
}

$quitarMcr = $valoresExistentes.Contains('192.168.1.79')
if ($pendientes.Count -gt 0 -or $quitarMcr) {
    if ($quitarMcr) {
        $conservar = @($ordenExistente | Where-Object { $_ -ne '192.168.1.79' } |
            ForEach-Object { ConvertTo-Json -InputObject $_ -Compress })
        $nuevoArreglo = '[' + ((@($pendientes.ToArray()) + $conservar) -join ', ') + ']'
        $contenido = $contenido.Substring(0, $inicioArreglo) + $nuevoArreglo +
            $contenido.Substring($finArreglo + 1)
    } elseif ($inicioArreglo -ge 0) {
        $interior = $contenido.Substring($inicioArreglo + 1, $finArreglo - $inicioArreglo - 1)
        $separador = if ($valoresExistentes.Count -gt 0) { ', ' } else { '' }
        $nuevoArreglo = '[' + ($pendientes -join ', ') + $separador + $interior + ']'
        $contenido = $contenido.Substring(0, $inicioArreglo) + $nuevoArreglo +
            $contenido.Substring($finArreglo + 1)
    } else {
        $contenido = 'fav = [' + ($pendientes -join ', ') + "]`r`n" + $contenido
    }
    if (Test-Path -LiteralPath $archivoLocal) {
        $respaldo = "$archivoLocal.$(Get-Date -Format yyyyMMdd-HHmmss).bak"
        Copy-Item -LiteralPath $archivoLocal -Destination $respaldo -ErrorAction Stop
        Write-Host "Respaldo: $respaldo"
    }
    $temporal = "$archivoLocal.tmp-$PID"
    try {
        [System.IO.File]::WriteAllText($temporal, $contenido, $utf8)
        Move-Item -LiteralPath $temporal -Destination $archivoLocal -Force
    } finally {
        if (Test-Path -LiteralPath $temporal) { Remove-Item -LiteralPath $temporal -Force }
    }
}

$nuevosPeers = 0
$peersActualizados = 0
foreach ($equipo in $Equipos) {
    $id = if ([int]$equipo.Puerto -eq 21118) { [string]$equipo.IP } else { "$($equipo.IP):$($equipo.Puerto)" }
    $nombreArchivo = if ($id.Contains(':')) {
        'base64_' + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($id))
    } else { $id }
    $archivoPeer = Join-Path $carpetaPeers ($nombreArchivo + '.toml')
    if (Test-Path -LiteralPath $archivoPeer) {
        $textoActual = [System.IO.File]::ReadAllText($archivoPeer, [System.Text.Encoding]::UTF8)
        $vista = [regex]::Match($textoActual, '(?m)^[ \t]*view_style[ \t]*=[^\r\n]*$')
        if ($vista.Success) {
            $textoNuevo = $textoActual.Substring(0, $vista.Index) + "view_style = 'adaptive'" +
                $textoActual.Substring($vista.Index + $vista.Length)
        } else {
            $textoNuevo = "view_style = 'adaptive'`r`n" + $textoActual
        }
        if ($textoNuevo -ne $textoActual) {
            $respaldoPeer = "$archivoPeer.$(Get-Date -Format yyyyMMdd-HHmmss).bak"
            Copy-Item -LiteralPath $archivoPeer -Destination $respaldoPeer -ErrorAction Stop
            [System.IO.File]::WriteAllText($archivoPeer, $textoNuevo, $utf8)
            $peersActualizados++
        }
        continue
    }
    $alias = ([string]$equipo.Nombre).Replace('\', '\\').Replace('"', '\"')
    $textoPeer = "view_style = 'adaptive'`r`n[options]`r`nalias = `"$alias`"`r`n[info]`r`nplatform = 'Windows'`r`n"
    [System.IO.File]::WriteAllText($archivoPeer, $textoPeer, $utf8)
    $nuevosPeers++
}

$comprobado = [System.IO.File]::ReadAllText($archivoLocal, [System.Text.Encoding]::UTF8)
$arregloFav = [regex]::Match($comprobado, '(?ms)^[ \t]*fav[ \t]*=[ \t]*\[(.*?)\]')
if (-not $arregloFav.Success) { throw 'No se encontro la lista fav despues de guardar.' }
$favGuardados = $arregloFav.Groups[1].Value
$sinFavorito = @($ids | Where-Object {
    $literal = '"' + $_ + '"'
    $literalSimple = "'" + $_ + "'"
    -not $favGuardados.Contains($literal) -and -not $favGuardados.Contains($literalSimple)
})
$sinFicha = @($ids | Where-Object {
    $nombre = if ($_.Contains(':')) {
        'base64_' + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($_))
    } else { $_ }
    -not (Test-Path -LiteralPath (Join-Path $carpetaPeers ($nombre + '.toml')) -PathType Leaf)
})
if ($sinFavorito.Count -gt 0 -or $sinFicha.Count -gt 0) {
    throw "Verificacion incompleta. Favoritos faltantes: $($sinFavorito -join ', '). Fichas faltantes: $($sinFicha -join ', ')."
}
Write-Host "Favoritos verificados: $($ids.Count)/$($ids.Count). Favoritos nuevos: $($pendientes.Count). Fichas nuevas: $nuevosPeers. Fichas con vista adaptable actualizada: $peersActualizados."
Write-Host 'Abre RustDesk de nuevo y revisa la pestana Favoritos. MCR se retiro si estaba guardada.'
Write-Host 'Para recordar la contrasena, conecta una vez a cada Favorito y marca Remember password.'
