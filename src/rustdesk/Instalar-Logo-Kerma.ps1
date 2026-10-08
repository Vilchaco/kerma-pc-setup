#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Coloca el logo Kerma Games en la pantalla principal del cliente RustDesk Flutter.
.DESCRIPTION
    Cambia solo los recursos de imagen de esta instalacion Windows. No modifica
    el ejecutable, la configuracion de conexiones ni el servicio RustDesk.
    La compatibilidad depende de la version instalada; hay que verificarla en GUI.
#>
[CmdletBinding()]
param(
    [string]$RutaRustDesk,
    [switch]$Restaurar
)

$ErrorActionPreference = 'Stop'
$logo = Join-Path $PSScriptRoot 'logo-kerma-games.png'
if (-not $Restaurar -and -not (Test-Path -LiteralPath $logo -PathType Leaf)) {
    throw "Falta el archivo de imagen: $logo"
}

if (-not $RutaRustDesk) {
    $servicio = Get-CimInstance Win32_Service -Filter "Name='RustDesk'" -ErrorAction SilentlyContinue
    if ($servicio -and $servicio.PathName) {
        $texto = [string]$servicio.PathName
        if ($texto -match '^\s*"([^"]+\.exe)"') {
            $RutaRustDesk = $Matches[1]
        } elseif ($texto -match '^\s*(.+?\.exe)(?:\s|$)') {
            $RutaRustDesk = $Matches[1]
        }
    }
}
if (-not $RutaRustDesk -or -not (Test-Path -LiteralPath $RutaRustDesk -PathType Leaf)) {
    $rutas = @((Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'))
    if (${env:ProgramFiles(x86)}) {
        $rutas += Join-Path ${env:ProgramFiles(x86)} 'RustDesk\rustdesk.exe'
    }
    $RutaRustDesk = $rutas | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $RutaRustDesk -or -not (Test-Path -LiteralPath $RutaRustDesk -PathType Leaf)) {
    throw 'No se encontro rustdesk.exe. Ejecuta el script con -RutaRustDesk "C:\ruta\rustdesk.exe".'
}
if ([System.IO.Path]::GetFileName($RutaRustDesk) -notmatch '(?i)^rustdesk.*\.exe$') {
    throw "El archivo indicado no parece ser RustDesk: $RutaRustDesk"
}

$carpeta = Join-Path (Split-Path -Parent $RutaRustDesk) 'data\flutter_assets\assets'
if (-not (Test-Path -LiteralPath $carpeta -PathType Container)) {
    throw "Esta instalacion no contiene recursos Flutter en $carpeta. No se modifico nada."
}
$respaldo = Join-Path $carpeta '_kerma_respaldo'
$nombres = @('logo.png', 'logo_light.png', 'logo_dark.png')

if ($Restaurar) {
    if (-not (Test-Path -LiteralPath $respaldo -PathType Container)) {
        throw 'No existe un respaldo de logos de Kerma Games para restaurar.'
    }
    foreach ($nombre in $nombres) {
        $destino = Join-Path $carpeta $nombre
        $original = Join-Path $respaldo $nombre
        $ausente = Join-Path $respaldo "$nombre.ausente"
        if (Test-Path -LiteralPath $original -PathType Leaf) {
            Copy-Item -LiteralPath $original -Destination $destino -Force
        } elseif (Test-Path -LiteralPath $ausente -PathType Leaf) {
            Remove-Item -LiteralPath $destino -Force -ErrorAction SilentlyContinue
        } else {
            throw "Falta el estado original de $nombre; no se puede completar la restauracion."
        }
    }
    Write-Host 'Logos originales restaurados. Cierra y vuelve a abrir la ventana de RustDesk.'
    exit 0
}

New-Item -Path $respaldo -ItemType Directory -Force | Out-Null
foreach ($nombre in $nombres) {
    $destino = Join-Path $carpeta $nombre
    $original = Join-Path $respaldo $nombre
    $ausente = Join-Path $respaldo "$nombre.ausente"
    if (-not (Test-Path -LiteralPath $original -PathType Leaf) -and
        -not (Test-Path -LiteralPath $ausente -PathType Leaf)) {
        if (Test-Path -LiteralPath $destino -PathType Leaf) {
            Copy-Item -LiteralPath $destino -Destination $original
        } else {
            New-Item -Path $ausente -ItemType File | Out-Null
        }
    }
    Copy-Item -LiteralPath $logo -Destination $destino -Force
    $esperado = (Get-FileHash -LiteralPath $logo -Algorithm SHA256).Hash
    $actual = (Get-FileHash -LiteralPath $destino -Algorithm SHA256).Hash
    if ($actual -ne $esperado) { throw "No se pudo verificar el archivo $destino" }
    Write-Host "Logo instalado: $destino"
}
$version = (Get-Item -LiteralPath $RutaRustDesk).VersionInfo.ProductVersion
Write-Host "RustDesk: $RutaRustDesk (version $version)"
Write-Host 'Cierra y vuelve a abrir la ventana de RustDesk para ver el logo en la pantalla principal.'
Write-Warning 'Si no aparece, esta version de RustDesk no carga estos recursos. El script no puede confirmar la compatibilidad visual desde esta Mac.'
Write-Host 'Para deshacer el cambio: .\Instalar-Logo-Kerma.ps1 -Restaurar'
