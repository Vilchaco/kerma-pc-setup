<#
.SYNOPSIS
    Deja el usuario Windows sin equipos precargados para el modo Client.
.DESCRIPTION
    Respalda y vacia Favoritos, sesiones recientes, lista Kerma y contrasena
    saliente. Conserva todas las copias en el perfil del usuario.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$procesosUi = @(Get-CimInstance Win32_Process -Filter "Name='rustdesk.exe'" -ErrorAction Stop |
    Where-Object {
        $_.SessionId -ne 0 -and
        [string]$_.CommandLine -notmatch '(?i)(?:^|\s)--(?:server|service|tray|cm|portable-service)(?:\s|$)'
    })
if ($procesosUi.Count) { throw 'Cierra la ventana principal de RustDesk antes de limpiar la lista de Client.' }

$configDir = Join-Path (Join-Path $env:APPDATA 'RustDesk') 'config'
$local = Join-Path $configDir 'RustDesk_local.toml'
$config2 = Join-Path $configDir 'RustDesk2.toml'
$peers = Join-Path $configDir 'peers'
$kermaList = Join-Path (Join-Path $env:LOCALAPPDATA 'Kerma-RustDesk') 'Equipos.seguro.json'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Save-Config([string]$path, [string]$content) {
    $backup = "$path.kerma-$stamp-$PID.bak"
    Copy-Item -LiteralPath $path -Destination $backup -ErrorAction Stop
    $temporary = "$path.tmp-$PID"
    try {
        [IO.File]::WriteAllText($temporary, $content, $utf8)
        Move-Item -LiteralPath $temporary -Destination $path -Force
    } finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Respaldo: $backup"
}

if (Test-Path -LiteralPath $local -PathType Leaf) {
    $content = [IO.File]::ReadAllText($local, [Text.Encoding]::UTF8)
    $matches = [regex]::Matches($content, '(?m)^[ \t]*fav[ \t]*=[ \t]*\[')
    if ($matches.Count -gt 1) { throw 'Hay varias listas fav en RustDesk_local.toml. No se modifico.' }
    if ($matches.Count -eq 0 -and $content -match '(?m)^[ \t]*fav[ \t]*=') {
        throw 'La lista fav tiene un formato no reconocido. No se modifico.'
    }
    if ($matches.Count -eq 1) {
        $start = $matches[0].Index + $matches[0].Length - 1
        $end = -1
        $quote = ''
        $escape = $false
        $comment = $false
        $depth = 0
        for ($i = $start; $i -lt $content.Length; $i++) {
            $char = $content[$i]
            if ($comment) {
                if ($char -eq "`n") { $comment = $false }
                continue
            }
            if ($quote) {
                if ($escape) { $escape = $false }
                elseif ($quote -eq '"' -and $char -eq '\') { $escape = $true }
                elseif ($char -eq $quote) { $quote = '' }
                continue
            }
            if ($char -eq '#') { $comment = $true }
            elseif ($char -eq '"' -or $char -eq "'") { $quote = [string]$char }
            elseif ($char -eq '[') { $depth++ }
            elseif ($char -eq ']') {
                $depth--
                if ($depth -eq 0) { $end = $i; break }
            }
        }
        if ($end -lt 0 -or $quote) { throw 'No se pudo leer fav en RustDesk_local.toml. No se modifico.' }
        $updated = $content.Substring(0, $start) + '[]' + $content.Substring($end + 1)
        if ($updated -ne $content) { Save-Config $local $updated }
    }
}

if (Test-Path -LiteralPath $config2 -PathType Leaf) {
    $content = [IO.File]::ReadAllText($config2, [Text.Encoding]::UTF8)
    $sections = [regex]::Matches($content, '(?m)^[ \t]*\[options\][ \t]*(?:\#.*)?\r?$')
    if ($sections.Count -gt 1) { throw 'Hay varias secciones [options] en RustDesk2.toml. No se modifico.' }
    $options = if ($sections.Count) { $sections[0] } else { [regex]::Match('', 'a') }
    if ($options.Success) {
        $start = $options.Index + $options.Length
        $rest = $content.Substring($start)
        $next = [regex]::Match($rest, '(?m)^[ \t]*\[[^\r\n]+\][ \t]*(?:\#.*)?\r?$')
        $end = if ($next.Success) { $start + $next.Index } else { $content.Length }
        $part = $content.Substring($start, $end - $start)
        $updatedPart = [regex]::Replace($part, '(?m)^[ \t]*["'']?default-connect-password["'']?[ \t]*=[^\r\n]*(?:\r?\n)?', '')
        if ($updatedPart -ne $part) {
            Save-Config $config2 ($content.Substring(0, $start) + $updatedPart + $content.Substring($end))
        }
    }
}

if ((Test-Path -LiteralPath $peers -PathType Container) -and
    @(Get-ChildItem -LiteralPath $peers -Force -ErrorAction Stop).Count -gt 0) {
    $backup = "$peers.kerma-$stamp-$PID.bak"
    Move-Item -LiteralPath $peers -Destination $backup -ErrorAction Stop
    Write-Host "Sesiones recientes respaldadas: $backup"
}
New-Item -ItemType Directory -Path $peers -Force | Out-Null

if (Test-Path -LiteralPath $kermaList -PathType Leaf) {
    $backup = "$kermaList.kerma-$stamp-$PID.bak"
    Move-Item -LiteralPath $kermaList -Destination $backup -ErrorAction Stop
    Write-Host "Lista Kerma respaldada: $backup"
}

if (Test-Path -LiteralPath $local -PathType Leaf) {
    $check = [IO.File]::ReadAllText($local, [Text.Encoding]::UTF8)
    if ($check -match '(?ms)^[ \t]*fav[ \t]*=[ \t]*\[(?![ \t\r\n]*\])') {
        throw 'La lista de Favoritos no quedo vacia.'
    }
}
if (@(Get-ChildItem -LiteralPath $peers -File -ErrorAction Stop).Count) {
    throw 'Las sesiones recientes no quedaron vacias.'
}
if (Test-Path -LiteralPath $kermaList -PathType Leaf) { throw 'La lista Kerma aun existe.' }
if (Test-Path -LiteralPath $config2 -PathType Leaf) {
    $check = [IO.File]::ReadAllText($config2, [Text.Encoding]::UTF8)
    if ($check -match '(?m)^[ \t]*["'']?default-connect-password["'']?[ \t]*=') {
        throw 'La contrasena saliente aun existe en RustDesk2.toml.'
    }
}
Write-Host 'Modo Client: Favoritos, sesiones recientes y lista Kerma vacios; contrasena saliente quitada del perfil de este usuario.'
