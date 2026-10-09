# =====================================================================
#  PROGRAMAS: instalar / actualizar los del perfil (winget o releases de
#  GitHub), mas Focusrite Control 2 si hay una Scarlett conectada.
# =====================================================================

function Get-WingetPath {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -LiteralPath $alias) { return $alias }
    # En ventanas elevadas a veces falta el alias: usar la carpeta del App Installer
    $pkg = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Filter 'Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe' -Directory -ErrorAction SilentlyContinue |
        Sort-Object -Property Name -Descending | Select-Object -First 1
    if ($pkg -and (Test-Path -LiteralPath (Join-Path $pkg.FullName 'winget.exe'))) { return (Join-Path $pkg.FullName 'winget.exe') }
    return $null
}

# Busca winget; en un PC nuevo intenta activarlo o repararlo antes.
function Initialize-Winget {
    $w = Get-WingetPath
    if ($w) { return $w }
    Write-Host (L '  winget not found - trying to activate it (can take a minute)...' '  No se encuentra winget: intentando activarlo (puede tardar un minuto)...')
    try { Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop; Start-Sleep -Seconds 3 } catch { }
    $w = Get-WingetPath
    if ($w) { return $w }
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Repository PSGallery -Force -Scope AllUsers -AllowClobber
        Import-Module Microsoft.WinGet.Client
        Repair-WinGetPackageManager -AllUsers -Latest -Force | Out-Null
    } catch { Write-Warn ((L 'Could not repair winget: {0}' 'No se pudo reparar winget: {0}') -f $_.Exception.Message) }
    return (Get-WingetPath)
}

# El catalogo de winget puede no estar listo en un PC recien instalado
# (error 0x8a15000f "Data required by the source is missing"). Se prueba
# una busqueda y, si falla, se reinicia y se reinstala el catalogo.
function Initialize-WingetSource([string]$w) {
    $probe = @('search', '--id', 'Google.Chrome', '--exact', '--accept-source-agreements', '--disable-interactivity')
    if ((Invoke-Native $w $probe).ExitCode -eq 0) { return $true }
    Write-Host (L '  The winget catalog is not ready - repairing it (can take a minute)...' '  El catálogo de winget no está listo: reparándolo (puede tardar un minuto)...')
    Invoke-Native $w @('source', 'reset', '--force', '--disable-interactivity') | Out-Null
    try { Add-AppxPackage -Path 'https://cdn.winget.microsoft.com/cache/source.msix' -ErrorAction Stop } catch { }
    Invoke-Native $w @('source', 'update', '--disable-interactivity') | Out-Null
    $r = Invoke-Native $w $probe
    if ($r.ExitCode -eq 0) { Write-Ok (L 'winget catalog repaired.' 'Catálogo de winget reparado.'); return $true }
    Write-Fail ((L 'The winget catalog still does not work (code {0}). Programs from winget cannot be installed now.' 'El catálogo de winget sigue sin funcionar (código {0}). Ahora no se pueden instalar los programas de winget.') -f $r.ExitCode)
    return $false
}

function Get-LatestReleaseAsset([string]$repo, [string]$pattern) {
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -UseBasicParsing -Headers @{ 'User-Agent' = 'Kerma-PCSetup' }
    $asset = $rel.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
    if (-not $asset) { throw ((L "no file matching '{0}' in the latest release of {1} ({2})" "no hay ningún archivo '{0}' en la última release de {1} ({2})") -f $pattern, $repo, $rel.tag_name) }
    return @{ Tag = [string]$rel.tag_name; Name = [string]$asset.name; Url = [string]$asset.browser_download_url }
}

# Instala con winget dejando su salida en la consola (barra de descarga con
# MB y %). Al capturar la salida winget no dibuja la barra y parece colgado.
# Su log va a C:\KermaSetup\logs para poner el error en el log del setup.
$WingetTimeoutMin = 15
function Invoke-WingetLive([string]$key, [string[]]$arguments) {
    $logDir = 'C:\KermaSetup\logs'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $log = Join-Path $logDir ("winget-{0}-{1}.log" -f $key, (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $argLine = (($arguments + @('--log', $log)) | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $proc = Start-Process -FilePath $script:Winget -ArgumentList $argLine -NoNewWindow -PassThru
    # tiempo maximo: un instalador colgado (Stream Deck tardo mas de 30 min)
    # no puede parar el setup, y Ctrl+C no corta un programa externo
    if (-not $proc.WaitForExit($WingetTimeoutMin * 60 * 1000)) {
        Stop-ProcessTree $proc.Id
        Get-Process -Name 'msiexec' -ErrorAction SilentlyContinue | Where-Object { try { $_.StartTime -gt $proc.StartTime } catch { $false } } | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host ''
        Write-Warn ((L 'winget took more than {0} min - stopped.' 'winget tardó más de {0} min: cortado.') -f $WingetTimeoutMin)
        return @{ ExitCode = -1; Code = (L 'timeout' 'tiempo agotado'); Tail = ''; TimedOut = $true }
    }
    $code = $proc.ExitCode
    $tail = ''
    if ($code -ne 0 -and (Test-Path -LiteralPath $log)) {
        $tail = ((Get-Content -LiteralPath $log -Tail 8 -ErrorAction SilentlyContinue) | ForEach-Object { '    ' + $_ }) -join [Environment]::NewLine
    }
    return @{ ExitCode = $code; Code = ('{0} (0x{1:X8})' -f $code, $code); Tail = $tail }
}

function Install-KermaPackage($key, $p) {
    $marker = if ($p.Check) { Join-Path (Split-Path -Path $p.Check -Parent) ".kerma-version-$key" } else { '' }
    if ($p.Requires -and -not (Test-Path -LiteralPath $Packages[$p.Requires].Check)) {
        Write-Skip ((L '{0}: needs {1}, which is not installed.' '{0}: necesita {1}, que no está instalado.') -f $p.Name, $Packages[$p.Requires].Name)
        return
    }

    if ($p.Source -eq 'winget') {
        if ($p.Check -and (Test-Path -LiteralPath $p.Check)) { Write-Ok ((L '{0}: already installed.' '{0}: ya estaba instalado.') -f $p.Name); return }
        if (-not $script:Winget) {
            $script:Winget = Initialize-Winget
            if ($script:Winget -and -not (Initialize-WingetSource $script:Winget)) { $script:WingetBroken = $true }
        }
        if ($script:WingetBroken) { Write-Skip ((L '{0}: winget catalog not available.' '{0}: catálogo de winget no disponible.') -f $p.Name); return }
        if (-not $script:Winget) {
            Write-Fail ((L '{0}: winget is not available on this PC, so it cannot be installed automatically.' '{0}: este PC no tiene winget, no se puede instalar solo.') -f $p.Name)
            Write-Note (L '  Windows LTSC / IoT editions do not include winget. Install it by hand.' '  Las ediciones LTSC / IoT de Windows no traen winget. Instálalo a mano.')
            return
        }
        if (-not $p.Check) {
            $pre = Invoke-Native $script:Winget @('list', '--id', $p.Id, '--exact', '--accept-source-agreements', '--disable-interactivity')
            if ($pre.ExitCode -eq 0) { Write-Ok ((L '{0}: already installed.' '{0}: ya estaba instalado.') -f $p.Name); return }
        }
        $base = @('install', '--id', $p.Id, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
        if ($p.Override) { $base += @('--override', $p.Override) }
        Write-Host ((L '  Installing {0} (winget {1})...' '  Instalando {0} (winget {1})...') -f $p.Name, $p.Id)
        Write-Note (L '  (winget shows its own download bar below; big programs can take several minutes)' '  (winget enseña abajo su barra de descarga; los programas grandes pueden tardar varios minutos)')
        $r = Invoke-WingetLive $key ($base + @('--scope', 'machine'))
        if ($r.ExitCode -ne 0 -and -not $r.TimedOut -and -not ($p.Check -and (Test-Path -LiteralPath $p.Check))) {
            # algunos paquetes no tienen instalador para todo el equipo: probar el normal
            $r = Invoke-WingetLive $key $base
        }
        $listed = (Invoke-Native $script:Winget @('list', '--id', $p.Id, '--exact', '--accept-source-agreements', '--disable-interactivity')).ExitCode -eq 0
        $ok = if ($p.Check) { Test-Path -LiteralPath $p.Check } else { $listed }
        if ($ok -or $listed) {
            Write-Ok ((L '{0} installed.' '{0} instalado.') -f $p.Name)
            if ($p.Restart) { $State.NeedsRestart = $true }
            Add-Change ((L 'Installed: {0}' 'Instalado: {0}') -f $p.Name)
        } else {
            Write-Fail ((L '{0} not installed (winget code {1}).' '{0} no se instaló (código de winget {1}).') -f $p.Name, $r.Code)
            if ($r.Tail) { Write-Host $r.Tail }
        }
        return
    }

    # ---- release de GitHub (.msi o .zip)
    $rel = Get-LatestReleaseAsset $p.Repo $p.Asset
    $installedTag = ''
    if ($marker -and (Test-Path -LiteralPath $marker)) { $installedTag = (Get-Content -LiteralPath $marker -Raw).Trim() }
    if ($p.Check -and (Test-Path -LiteralPath $p.Check)) {
        if ($rel.Name -notmatch '\.zip$' -or $installedTag -eq $rel.Tag) {
            $ver = if ($installedTag) { " ($installedTag)" } else { '' }
            Write-Ok ((L '{0}: already installed{1}.' '{0}: ya estaba instalado{1}.') -f $p.Name, $ver); return
        }
        $from = if ($installedTag) { $installedTag } else { L 'installed copy' 'la copia instalada' }
        Write-Host ((L '  {0}: updating {1} -> {2}' '  {0}: actualizando {1} -> {2}') -f $p.Name, $from, $rel.Tag)
    }
    $dl = 'C:\KermaSetup\downloads'
    New-Item -ItemType Directory -Path $dl -Force | Out-Null
    $file = Join-Path $dl $rel.Name
    Write-Host ((L '  Downloading {0} {1} ({2})...' '  Descargando {0} {1} ({2})...') -f $p.Name, $rel.Tag, $rel.Name)
    Invoke-WebRequest -Uri $rel.Url -OutFile $file -UseBasicParsing

    if ($rel.Name -match '\.msi$') {
        $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$file`" /qn /norestart" -Wait -PassThru
        if ($proc.ExitCode -eq 3010) { $State.NeedsRestart = $true }
        if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) { Write-Fail ((L '{0}: the installer returned code {1}.' '{0}: el instalador devolvió el código {1}.') -f $p.Name, $proc.ExitCode); return }
    } elseif ($rel.Name -match '\.zip$') {
        if ($p.Process) { Get-Process -Name $p.Process -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1 }
        New-Item -ItemType Directory -Path $p.InstallTo -Force | Out-Null
        if ($p.Inner) {
            # el zip trae un zip por plataforma: se usa el de Windows
            $tmp = Join-Path $dl "$key-$($rel.Tag)"
            Expand-Archive -LiteralPath $file -DestinationPath $tmp -Force
            $inner = Get-ChildItem -LiteralPath $tmp -Recurse -File | Where-Object { $_.Name -match $p.Inner } | Select-Object -First 1
            if (-not $inner) { Write-Fail ((L "{0}: no file matching '{1}' inside {2}." "{0}: no hay ningún '{1}' dentro de {2}.") -f $p.Name, $p.Inner, $rel.Name); return }
            Expand-Archive -LiteralPath $inner.FullName -DestinationPath $p.InstallTo -Force
        } else {
            Expand-Archive -LiteralPath $file -DestinationPath $p.InstallTo -Force   # su propia configuracion se conserva
        }
        if ($p.UserWritable) {
            $r = Invoke-Native 'icacls.exe' @($p.UserWritable, '/grant', '*S-1-5-32-545:(OI)(CI)M')
            if ($r.ExitCode -ne 0) { Write-Warn ((L 'Could not let users write in {0}: {1}' 'No se pudo dar permiso de escritura en {0}: {1}') -f $p.UserWritable, $r.Text) }
        }
    } else {
        Write-Fail ((L "{0}: do not know how to install '{1}'." "{0}: no sé cómo instalar '{1}'.") -f $p.Name, $rel.Name)
        return
    }
    if ($p.Check -and -not (Test-Path -LiteralPath $p.Check)) { Write-Fail ((L '{0}: installed, but {1} is missing.' '{0}: instalado, pero falta {1}.') -f $p.Name, $p.Check); return }
    if ($marker) { Set-Content -LiteralPath $marker -Value $rel.Tag -Encoding Ascii }
    Write-Ok ((L '{0} {1} installed.' '{0} {1} instalado.') -f $p.Name, $rel.Tag)
    Add-Change ((L 'Installed: {0} {1}' 'Instalado: {0} {1}') -f $p.Name, $rel.Tag)
}

# Focusrite conectadas (USB vendor 1235). Devuelve cuantas.
function Show-FocusriteDevices {
    $dev = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like 'USB\VID_1235*' })
    foreach ($d in $dev) { Write-Host ((L '  Focusrite connected: {0}  [{1}]' '  Focusrite conectada: {0}  [{1}]') -f $d.FriendlyName, $d.InstanceId) }
    return $dev.Count
}

function Get-ProgramList($pc) {
    $list = @($Prof.Programs)
    if (-not $pc.RustDesk) { $list = @($list | Where-Object { $_ -ne 'RustDesk' }) }
    return $list
}

function Invoke-InstallPrograms($pc) {
    Write-Section (L 'INSTALL PROGRAMS' 'INSTALAR PROGRAMAS')
    $list = Get-ProgramList $pc
    $focusrite = Show-FocusriteDevices
    if ($ScarlettPackageId -and ($focusrite -gt 0 -or ($ScarlettPcTypes -contains $pc.Type))) {
        $Packages['Focusrite'].Id = $ScarlettPackageId
        $list += 'Focusrite'
    }
    if ($list.Count -eq 0) { Write-Skip (L 'No programs for this PC.' 'No hay programas para este PC.'); return }

    Write-Host (L '  Programs for this PC:' '  Programas de este PC:')
    foreach ($k in $list) {
        $p = $Packages[$k]
        $st = if (-not $p.Check) { L 'install / check' 'instalar / comprobar' } elseif (Test-Path -LiteralPath $p.Check) { L 'installed' 'instalado' } else { L 'to install' 'por instalar' }
        Write-Host ("    - {0,-32} {1}" -f $p.Name, $st)
    }
    Write-Host ''
    if (-not (Ask-YesNo (L '  Install / update them now?' '  ¿Instalarlos / actualizarlos ahora?') $true)) { Write-Skip (L 'Programs left as they are.' 'Programas sin cambios.'); return }
    if (-not (Test-Internet)) {
        Write-Fail (L 'No internet (github.com does not answer) - programs NOT installed.' 'Sin internet (github.com no contesta): NO se instalaron los programas.')
        Write-Note (L '  Check the network, then run the script again.' '  Revisa la red y vuelve a pasar el script.')
        return
    }
    $script:Winget = $null
    $script:WingetBroken = $false
    $i = 0
    $all = [Diagnostics.Stopwatch]::StartNew()
    foreach ($k in $list) {
        $i++
        Write-Host ''
        Write-Host ('  [{0}/{1}] {2}' -f $i, $list.Count, $Packages[$k].Name) -ForegroundColor Cyan
        $one = [Diagnostics.Stopwatch]::StartNew()
        try { Install-KermaPackage $k $Packages[$k] }
        catch { Write-Fail "$($Packages[$k].Name): $($_.Exception.Message)" }
        Write-Host ('        {0}: {1:mm\:ss} min  (total {2:mm\:ss})' -f $Packages[$k].Name, $one.Elapsed, $all.Elapsed) -ForegroundColor DarkGray
    }
}
