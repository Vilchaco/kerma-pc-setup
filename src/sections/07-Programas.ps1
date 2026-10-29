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

# Paquete de la web de descargas de Bitfocus (Companion Satellite no esta en winget
# y sus releases de GitHub no traen binarios): el mas reciente para ese target.
function Get-BitfocusPackage([string]$product, [string]$target) {
    $r = Invoke-RestMethod -Uri "https://api.bitfocus.io/v1/product/$product/packages?limit=50" -UseBasicParsing -Headers @{ 'User-Agent' = 'Kerma-PCSetup' }
    $pkg = @($r.packages | Where-Object { $_.target -eq $target }) | Select-Object -First 1
    if (-not $pkg) { throw ((L "no '{0}' package of {1} in the Bitfocus downloads" "no hay paquete '{0}' de {1} en las descargas de Bitfocus") -f $target, $product) }
    return @{ Tag = [string]$pkg.version; Name = [string](Split-Path -Path ([uri]$pkg.uri).AbsolutePath -Leaf); Url = [string]$pkg.uri }
}

function Get-LatestReleaseAsset([string]$repo, [string]$pattern, [string]$tag) {
    # Tag fija una version concreta (la probada); si no, la ultima
    $which = if ($tag) { "tags/$tag" } else { 'latest' }
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/$which" -UseBasicParsing -Headers @{ 'User-Agent' = 'Kerma-PCSetup' }
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
    $null = $proc.Handle   # en PowerShell 5.1, sin esto ExitCode sale vacio (MCR: "codigo  (0x)")
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
    if ($null -eq $code) { $code = -1 }
    $tail = ''
    if ($code -ne 0 -and (Test-Path -LiteralPath $log)) {
        $tail = ((Get-Content -LiteralPath $log -Tail 8 -ErrorAction SilentlyContinue) | ForEach-Object { '    ' + $_ }) -join [Environment]::NewLine
    }
    return @{ ExitCode = $code; Code = ('{0} (0x{1:X8})' -f $code, $code); Tail = $tail }
}

# Programa instalado segun "Programas y caracteristicas" (DisplayName con comodines)
function Test-InstalledProgram([string]$pattern) {
    if (-not $pattern) { return $false }
    foreach ($k in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
        if (@(Get-ItemProperty -Path $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pattern }).Count) { return $true }
    }
    return $false
}

# Codigos de winget upgrade que no son un fallo (lista oficial de winget: returnCodes.md)
$WingetUpToDate = @('8A15002B', '8A15004F') | ForEach-Object { [Convert]::ToInt32($_, 16) }                         # no hay version mas nueva
$WingetNoUpgrade = @('8A150014', '8A150050', '8A150068', '8A15008E', '8A150114') | ForEach-Object { [Convert]::ToInt32($_, 16) }   # winget no sabe actualizarlo
$WingetRebootOk = @('8A150109', '8A15010B') | ForEach-Object { [Convert]::ToInt32($_, 16) }                         # actualizado, falta reiniciar

# Cierra el programa antes de instalar encima: sus procesos (Process) y, con ProcessDir /
# ProcessModules, todo lo que corre desde esas carpetas o tiene cargada una DLL suya. OBS:
# su instalador se niega (codigo 6, winget 0x8A150111) si la captura de juego dejo su
# graphics-hook en otra app (la Dealer App) o la camara virtual esta cargada (BJUNL01).
function Stop-PackageProcesses($p) {
    $closed = @()
    if ($p.Process) {
        foreach ($x in @(Get-Process -Name $p.Process -ErrorAction SilentlyContinue)) { $closed += $x.ProcessName; Stop-Process -Id $x.Id -Force -ErrorAction SilentlyContinue }
    }
    $dirs = @($p.ProcessDir | Where-Object { $_ } | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') + '\' })
    $mods = @($p.ProcessModules | Where-Object { $_ })
    if ($dirs.Count -or $mods.Count) {
        foreach ($x in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID -and $_.Id -gt 4 })) {
            $files = @()
            try { if ($x.Path) { $files += $x.Path } } catch { }
            try { $files += @($x.Modules | ForEach-Object { $_.FileName }) } catch { }
            $hit = $false
            foreach ($f in $files) {
                if (-not $f) { continue }
                foreach ($d in $dirs) { if ($f.StartsWith($d, [StringComparison]::OrdinalIgnoreCase)) { $hit = $true } }
                $leaf = [IO.Path]::GetFileName($f)
                foreach ($m in $mods) { if ($leaf -like $m) { $hit = $true } }
                if ($hit) { break }
            }
            if ($hit) { $closed += $x.ProcessName; Stop-Process -Id $x.Id -Force -ErrorAction SilentlyContinue }
        }
    }
    $closed = @($closed | Select-Object -Unique)
    if ($closed.Count) {
        Write-Host ((L '  Closed: {0}' '  Cerrados: {0}') -f ($closed -join ', '))
        Start-Sleep -Seconds 3
    }
}

# Programa de winget ya instalado: si hay version nueva, se cierra y se actualiza
function Update-WingetPackage($key, $p) {
    $chk = Invoke-Native $script:Winget @('list', '--id', $p.Id, '--exact', '--upgrade-available', '--accept-source-agreements', '--disable-interactivity')
    if ($chk.ExitCode -ne 0) { Write-Ok ((L '{0}: installed and up to date.' '{0}: instalado y al día.') -f $p.Name); return }
    # tabla de winget: Nombre  Id  Version  Disponible  Origen
    $from = ''; $to = ''
    $row = @($chk.Text -split "`r?`n" | Where-Object { $_ -match ('(^|\s)' + [regex]::Escape($p.Id) + '\s') }) | Select-Object -First 1
    if ($row) {
        $t = @(($row -split [regex]::Escape($p.Id), 2)[1].Trim() -split '\s+')
        if ($t.Count -ge 2) { $from = $t[0]; $to = $t[1] }
    }
    $vers = if ($from -and $to) { " $from -> $to" } else { '' }
    Write-Host ((L '  {0}: new version, updating{1}...' '  {0}: hay versión nueva, actualizando{1}...') -f $p.Name, $vers)
    Stop-PackageProcesses $p
    $upArgs = @('upgrade', '--id', $p.Id, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    if ($p.Override) { $upArgs += @('--override', $p.Override) }
    $r = Invoke-WingetLive $key $upArgs
    if ($r.ExitCode -eq 0 -or $WingetRebootOk -contains $r.ExitCode) {
        Write-Ok ((L '{0} updated{1}.' '{0} actualizado{1}.') -f $p.Name, $vers)
        if ($p.Restart -or $r.ExitCode -ne 0) { $State.NeedsRestart = $true }
        Add-Change ((L 'Updated: {0}{1}' 'Actualizado: {0}{1}') -f $p.Name, $vers)
    } elseif ($WingetUpToDate -contains $r.ExitCode) {
        # winget lista una version nueva pero ninguna aplica a este PC (Focusrite en BJUNL01)
        Write-Ok ((L '{0}: installed; winget lists a newer version but none applies to this PC.' '{0}: instalado; winget anuncia otra versión pero ninguna vale para este PC.') -f $p.Name)
    } elseif ($WingetNoUpgrade -contains $r.ExitCode) {
        Write-Warn ((L '{0}: winget cannot update it (code {1}); the installed version stays.' '{0}: winget no puede actualizarlo (código {1}); se queda la versión instalada.') -f $p.Name, $r.Code)
    } else {
        Write-Fail ((L '{0} not updated (winget code {1}); the installed version stays.' '{0} no se actualizó (código de winget {1}); se queda la versión instalada.') -f $p.Name, $r.Code)
        if ($r.Tail) { Write-Host $r.Tail }
    }
}

# Version de un programa instalado sin marca del script (instalado a mano): la del exe
function Get-ExeVersion([string]$path) {
    try {
        $vi = (Get-Item -LiteralPath $path -ErrorAction Stop).VersionInfo
        $v = if ($vi.ProductVersion) { $vi.ProductVersion } else { $vi.FileVersion }
        return ([string]$v).Trim()
    } catch { return '' }
}

# $true si la release $tag es mas nueva que $current (v1.2.3, 1.2.3.0...). Si no se
# pueden comparar como version, basta con que sean distintas.
function Test-NewerTag([string]$current, [string]$tag) {
    $a = ($current -replace '^[vV]', '' -replace '[-+ ].*$', '').Trim()
    $b = ($tag -replace '^[vV]', '' -replace '[-+ ].*$', '').Trim()
    $va = $null; $vb = $null
    if ([version]::TryParse($a, [ref]$va) -and [version]::TryParse($b, [ref]$vb)) {
        $va = [version]('{0}.{1}.{2}' -f $va.Major, $va.Minor, [Math]::Max($va.Build, 0))
        $vb = [version]('{0}.{1}.{2}' -f $vb.Major, $vb.Minor, [Math]::Max($vb.Build, 0))
        return ($vb -gt $va)
    }
    return ($a -ne $b)
}

function Install-KermaPackage($key, $p) {
    $marker = if ($p.Check) { Join-Path (Split-Path -Path $p.Check -Parent) ".kerma-version-$key" } else { '' }
    if ($p.Requires -and -not (Test-Path -LiteralPath $Packages[$p.Requires].Check)) {
        Write-Skip ((L '{0}: needs {1}, which is not installed.' '{0}: necesita {1}, que no está instalado.') -f $p.Name, $Packages[$p.Requires].Name)
        return
    }

    if ($p.Source -eq 'url') {
        # instalador de la web del fabricante (iVMS-4200 de Hikvision): solo se descarga
        # con cabeceras de navegador; se instala si no aparece en Programas de Windows
        if (Test-InstalledProgram $p.CheckReg) { Write-Ok ((L '{0}: already installed.' '{0}: ya estaba instalado.') -f $p.Name); return }
        $dl = 'C:\KermaSetup\downloads'
        New-Item -ItemType Directory -Path $dl -Force | Out-Null
        $file = Join-Path $dl ([IO.Path]::GetFileName(([uri]$p.Url).AbsolutePath))
        Write-Host ((L '  Downloading {0}...' '  Descargando {0}...') -f $p.Name)
        $h = @{}
        if ($p.Referer) { $h['Referer'] = $p.Referer }
        Invoke-WebRequest -Uri $p.Url -OutFile $file -UseBasicParsing -Headers $h -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36'
        Write-Host ((L '  Installing {0} (if its installer shows a window, finish it by hand)...' '  Instalando {0} (si su instalador muestra una ventana, termínala a mano)...') -f $p.Name)
        $proc = Start-Process -FilePath $file -ArgumentList ([string]$p.Args) -PassThru
        $mins = if ($p.TimeoutMin) { [int]$p.TimeoutMin } else { 20 }
        if (-not $proc.WaitForExit($mins * 60000)) { Write-Warn ((L '{0}: the installer is still open after {1} min - left running.' '{0}: el instalador sigue abierto tras {1} min; se deja abierto.') -f $p.Name, $mins) }
        if (Test-InstalledProgram $p.CheckReg) {
            Write-Ok ((L '{0} installed.' '{0} instalado.') -f $p.Name)
            Add-Change ((L 'Installed: {0}' 'Instalado: {0}') -f $p.Name)
        } else { Write-Fail ((L '{0}: not found in Windows programs after the installer.' '{0}: no aparece en los programas de Windows tras el instalador.') -f $p.Name) }
        return
    }

    if ($p.Source -eq 'winget') {
        $installed = [bool]($p.Check -and (Test-Path -LiteralPath $p.Check))
        if ($installed -and $p.NoUpdate) { Write-Ok ((L '{0}: already installed.' '{0}: ya estaba instalado.') -f $p.Name); return }
        if (-not $script:Winget) {
            $script:Winget = Initialize-Winget
            if ($script:Winget -and -not (Initialize-WingetSource $script:Winget)) { $script:WingetBroken = $true }
        }
        if ($script:WingetBroken) {
            if ($installed) { Write-Ok ((L '{0}: already installed (winget catalog not available: updates not checked).' '{0}: ya estaba instalado (sin catálogo de winget: no se buscan actualizaciones).') -f $p.Name); return }
            Write-Skip ((L '{0}: winget catalog not available.' '{0}: catálogo de winget no disponible.') -f $p.Name); return
        }
        if (-not $script:Winget) {
            if ($installed) { Write-Ok ((L '{0}: already installed (no winget: updates not checked).' '{0}: ya estaba instalado (sin winget: no se buscan actualizaciones).') -f $p.Name); return }
            Write-Fail ((L '{0}: winget is not available on this PC, so it cannot be installed automatically.' '{0}: este PC no tiene winget, no se puede instalar solo.') -f $p.Name)
            Write-Note (L '  Windows LTSC / IoT editions do not include winget. Install it by hand.' '  Las ediciones LTSC / IoT de Windows no traen winget. Instálalo a mano.')
            return
        }
        if (-not $p.Check) {
            $pre = Invoke-Native $script:Winget @('list', '--id', $p.Id, '--exact', '--accept-source-agreements', '--disable-interactivity')
            $installed = $pre.ExitCode -eq 0
            if ($installed -and $p.NoUpdate) { Write-Ok ((L '{0}: already installed.' '{0}: ya estaba instalado.') -f $p.Name); return }
        }
        if ($installed) { Update-WingetPackage $key $p; return }
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
            # plan B: el .msi oficial del fabricante (Chrome en el MCR: winget fallo en 4 s)
            if ($p.FallbackMsi) {
                try {
                    $dl = 'C:\KermaSetup\downloads'
                    New-Item -ItemType Directory -Path $dl -Force | Out-Null
                    $msi = Join-Path $dl ([IO.Path]::GetFileName(([uri]$p.FallbackMsi).AbsolutePath))
                    Write-Host ((L '  Trying the official installer of {0} instead...' '  Probando con el instalador oficial de {0}...') -f $p.Name)
                    Invoke-WebRequest -Uri $p.FallbackMsi -OutFile $msi -UseBasicParsing
                    $mp = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -PassThru
                    if ($p.Check -and (Test-Path -LiteralPath $p.Check)) {
                        Write-Ok ((L '{0} installed (official installer).' '{0} instalado (instalador oficial).') -f $p.Name)
                        Add-Change ((L 'Installed: {0}' 'Instalado: {0}') -f $p.Name)
                    } else { Write-Fail ((L '{0}: the official installer did not work either (code {1}).' '{0}: tampoco funcionó el instalador oficial (código {1}).') -f $p.Name, $mp.ExitCode) }
                } catch { Write-Fail ((L '{0}: official installer: {1}' '{0}: instalador oficial: {1}') -f $p.Name, $_.Exception.Message) }
            }
        }
        return
    }

    # ---- release de GitHub (.msi o .zip) o paquete de Bitfocus (.exe)
    if ($p.NoUpdate -and $p.Check -and (Test-Path -LiteralPath $p.Check)) { Write-Ok ((L '{0}: already installed.' '{0}: ya estaba instalado.') -f $p.Name); return }
    $rel = if ($p.Source -eq 'bitfocus') { Get-BitfocusPackage $p.Product $p.Target } else { Get-LatestReleaseAsset $p.Repo $p.Asset $p.Tag }
    $installedTag = ''
    if ($marker -and (Test-Path -LiteralPath $marker)) { $installedTag = (Get-Content -LiteralPath $marker -Raw).Trim() }
    $updating = $false
    if ($p.Check -and (Test-Path -LiteralPath $p.Check)) {
        # version instalada: la marca que deja el script; si no hay (instalado a mano), la del
        # exe en .msi / .exe (un .zip sin marca se reemplaza, como antes)
        $current = $installedTag
        if (-not $current -and $rel.Name -notmatch '\.zip$') { $current = Get-ExeVersion $p.Check }
        $upToDate = if ($current) { -not (Test-NewerTag $current $rel.Tag) } else { $rel.Name -notmatch '\.zip$' }
        if ($upToDate) {
            $ver = if ($current) { " ($current)" } else { '' }
            Write-Ok ((L '{0}: installed and up to date{1}.' '{0}: instalado y al día{1}.') -f $p.Name, $ver); return
        }
        $from = if ($current) { $current } else { L 'installed copy' 'la copia instalada' }
        Write-Host ((L '  {0}: updating {1} -> {2}' '  {0}: actualizando {1} -> {2}') -f $p.Name, $from, $rel.Tag)
        $updating = $true
    }
    $dl = 'C:\KermaSetup\downloads'
    New-Item -ItemType Directory -Path $dl -Force | Out-Null
    $file = Join-Path $dl $rel.Name
    Write-Host ((L '  Downloading {0} {1} ({2})...' '  Descargando {0} {1} ({2})...') -f $p.Name, $rel.Tag, $rel.Name)
    Invoke-WebRequest -Uri $rel.Url -OutFile $file -UseBasicParsing

    if ($updating -and $rel.Name -notmatch '\.zip$') { Stop-PackageProcesses $p }
    if ($rel.Name -match '\.exe$') {
        # instalador NSIS de electron-builder (Companion Satellite): /S = silencioso, para todo el equipo
        $proc = Start-Process -FilePath $file -ArgumentList '/S' -Wait -PassThru
        if ($proc.ExitCode -ne 0) { Write-Fail ((L '{0}: the installer returned code {1}.' '{0}: el instalador devolvió el código {1}.') -f $p.Name, $proc.ExitCode); return }
    } elseif ($rel.Name -match '\.msi$') {
        $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$file`" /qn /norestart" -Wait -PassThru
        if ($proc.ExitCode -eq 3010) { $State.NeedsRestart = $true }
        if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) { Write-Fail ((L '{0}: the installer returned code {1}.' '{0}: el instalador devolvió el código {1}.') -f $p.Name, $proc.ExitCode); return }
    } elseif ($rel.Name -match '\.zip$') {
        Stop-PackageProcesses $p
        New-Item -ItemType Directory -Path $p.InstallTo -Force | Out-Null
        if ($p.File) {
            # solo un archivo del zip, con el nombre que espera la configuracion (Alt Denoiser)
            $tmp = Join-Path $dl "$key-$($rel.Tag)"
            Expand-Archive -LiteralPath $file -DestinationPath $tmp -Force
            $one = Get-ChildItem -LiteralPath $tmp -Recurse -File | Where-Object { $_.FullName.Substring($tmp.Length + 1) -match $p.File } | Select-Object -First 1
            if (-not $one) { Write-Fail ((L "{0}: no file matching '{1}' inside {2}." "{0}: no hay ningún '{1}' dentro de {2}.") -f $p.Name, $p.File, $rel.Name); return }
            Copy-Item -LiteralPath $one.FullName -Destination (Join-Path $p.InstallTo $p.FileAs) -Force
        } elseif ($p.Inner) {
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
    if ($updating) {
        Write-Ok ((L '{0} updated to {1}.' '{0} actualizado a {1}.') -f $p.Name, $rel.Tag)
        Add-Change ((L 'Updated: {0} {1}' 'Actualizado: {0} {1}') -f $p.Name, $rel.Tag)
    } else {
        Write-Ok ((L '{0} {1} installed.' '{0} {1} instalado.') -f $p.Name, $rel.Tag)
        Add-Change ((L 'Installed: {0} {1}' 'Instalado: {0} {1}') -f $p.Name, $rel.Tag)
    }
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
    $list = @($list | Where-Object { @($pc.Without) -notcontains $_ })
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
        $fixed = $p.NoUpdate -or $p.Tag -or $p.Source -eq 'url'
        $st = if (-not $p.Check) { L 'install / check for updates' 'instalar / buscar actualización' }
              elseif (-not (Test-Path -LiteralPath $p.Check)) { L 'to install' 'por instalar' }
              elseif ($fixed) { L 'installed (fixed version)' 'instalado (versión fija)' }
              else { L 'installed: check for updates' 'instalado: buscar actualización' }
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
