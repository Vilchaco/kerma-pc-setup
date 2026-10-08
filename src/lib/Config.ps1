# =====================================================================
#  Kerma PC Setup - carga y validacion de config\*.psd1
# =====================================================================

# Carga los .psd1 y deja las variables que usan las secciones.
function Import-KermaConfig {
    $dir = Join-Path $Root 'config'
    $script:CfgInventory = Import-PowerShellDataFile (Join-Path $dir 'inventario.psd1')
    $script:Profiles     = Import-PowerShellDataFile (Join-Path $dir 'perfiles.psd1')
    $prog                = Import-PowerShellDataFile (Join-Path $dir 'programas.psd1')
    $aj                  = Import-PowerShellDataFile (Join-Path $dir 'ajustes.psd1')

    $script:Packages    = $prog.Packages
    $script:Apps        = $prog.Apps
    $script:RemoveApps  = @($prog.RemoveApps)
    $script:NeverRemove = @($prog.NeverRemove)

    $script:TimeZoneId         = $aj.Time.ZoneId
    $script:TimeZoneFallbackId = $aj.Time.FallbackZoneId
    $script:TimeServers        = @($aj.Time.Servers)
    $script:TimeSyncDailyAt    = $aj.Time.DailyAt
    $script:NetDefaults        = $aj.Network
    $script:RustDeskPort        = [int]$aj.RustDesk.Port
    $script:RustDeskAllowedFrom = @($aj.RustDesk.AllowedFrom)
    $script:RustDeskPeersUrl    = $aj.RustDesk.PeersUrl
    $script:RustDeskExtraPeers  = @($aj.RustDesk.ExtraPeers)
    $script:ScarlettPackageId         = $aj.Audio.ScarlettPackageId
    $script:ScarlettPcTypes           = @($aj.Audio.ScarlettPcTypes)
    $script:ScarlettAsDefaultPlayback = [bool]$aj.Audio.ScarlettAsDefaultPlayback
    $script:PanelBase    = $aj.Panel.Base
    $script:ObsThemeFile = $aj.Obs.ThemeFile
    $script:ObsThemeId   = $aj.Obs.ThemeId

    # Filas de PC con lo que necesitan las secciones
    $script:PCs = @()
    foreach ($row in $CfgInventory.PCs) {
        $prof = $Profiles[$row.Profile]
        $apps = @()
        if ($row.Scanner) { $apps += 'Scanner' }
        if ($prof) { $apps += @($prof.Autostart) }
        $script:PCs += @{
            Key = $row.Key; Group = $row.Group; Label = $row.Label; Profile = $row.Profile
            Type = if ($prof) { $prof.Type } else { '' }
            Hostname = $row.Hostname; Username = $row.Username; FullName = $row.FullName; Game = $row.Game
            Apps = $apps; Net = @{ IP = [string]$row.IP }; IPSource = if ($row.IP) { 'inventory' } else { '' }
            DavidName = $row.DavidName; WallpaperText = $row.WallpaperText
            RustDesk = ($prof -and $prof.RustDesk -ne 'None')
        }
    }
}

# "Otro PC": un equipo que no esta en el inventario (p. ej. el de la Office
# Manager). Se pide su nombre y su tipo; el resto se propone a partir del nombre.
function New-AdHocPC {
    Write-Section (L 'OTHER PC  (not in the inventory)' 'OTRO PC  (no está en el inventario)')
    $label = ''
    while (-not $label) { $label = (Read-Host (L '  Name of this PC (e.g. Office Manager)' '  Nombre de este PC (p. ej. Office Manager)')).Trim() }
    $names = @($Profiles.Keys | Sort-Object)
    Write-Host ''
    Write-Host (L '  What type of PC is it?' '  ¿Qué tipo de PC es?')
    for ($i = 0; $i -lt $names.Count; $i++) { Write-Host ("  {0}. {1}" -f ($i + 1), (Get-ProfileName $Profiles[$names[$i]])) }
    $profName = $names[(Read-MenuChoice (L '  Number' '  Número') $names.Count)]
    $prof = $Profiles[$profName]

    # nombre de equipo: KG-<NOMBRE>, solo letras, numeros y guiones, 15 caracteres como mucho
    $slug = (($label.ToUpperInvariant() -replace '[^A-Z0-9]+', '-').Trim('-'))
    $defHost = ('KG-' + $slug)
    if ($defHost.Length -gt 15) { $defHost = $defHost.Substring(0, 15).TrimEnd('-') }
    Write-Host ''
    $h = (Read-Host ((L '  Computer name [{0}]' '  Nombre de equipo [{0}]') -f $defHost)).Trim()
    if (-not $h) { $h = $defHost }
    $h = ($h.ToUpperInvariant() -replace '[^A-Z0-9-]', '')
    if ($h.Length -gt 15) { $h = $h.Substring(0, 15) }
    $defUser = $h.ToLowerInvariant()
    $u = (Read-Host ((L '  Windows user name [{0}]' '  Usuario de Windows [{0}]') -f $defUser)).Trim()
    if (-not $u) { $u = $defUser }
    $ip = (Read-Host (L '  Static IP (Enter = leave the network as it is)' '  IP fija (Enter = dejar la red como está)')).Trim()
    if (-not (Test-IPv4 $ip)) { $ip = '' }

    return @{
        Key = $h; Group = (L 'Other PCs' 'Otros PCs'); Label = $label; Profile = $profName; Type = $prof.Type
        Hostname = $h; Username = $u; FullName = $label; Game = ''
        Apps = @($prof.Autostart); Net = @{ IP = $ip }; IPSource = if ($ip) { 'typed' } else { '' }
        DavidName = ''; WallpaperText = $label
        RustDesk = ($prof.RustDesk -ne 'None')
    }
}

# Normaliza un nombre para compararlo con la lista de David ('BJ UNL 01' = 'BJUNL01')
function ConvertTo-PcNameKey([string]$s) { return ($s -replace '[^A-Za-z0-9]', '').ToUpperInvariant() }

# Lee la lista de equipos de David (Nombre, IP, Puerto). Devuelve filas validas o @().
function Get-DavidList {
    if ($script:DavidList) { return $script:DavidList }
    $script:DavidList = @()
    if (-not $RustDeskPeersUrl) { return @() }
    try {
        $csv = (Invoke-WebRequest -Uri $RustDeskPeersUrl -UseBasicParsing -TimeoutSec 15).Content | ConvertFrom-Csv
        foreach ($r in $csv) {
            $ip = [string]$r.IP
            if (-not $r.Nombre -or -not (Test-IPv4 $ip)) { continue }
            $port = 0
            if (-not [int]::TryParse([string]$r.Puerto, [ref]$port) -or $port -lt 1 -or $port -gt 65535) { $port = $RustDeskPort }
            $script:DavidList += [pscustomobject]@{ Nombre = ([string]$r.Nombre).Trim(); IP = $ip; Puerto = $port }
        }
    } catch { }
    return $script:DavidList
}

# Las IPs de la lista de David ganan sobre las del inventario.
function Merge-DavidIPs {
    $list = @(Get-DavidList)
    if ($list.Count -eq 0) { return $false }
    foreach ($pc in $PCs) {
        $names = @($pc.Key, $pc.Label, $pc.DavidName) | Where-Object { $_ } | ForEach-Object { ConvertTo-PcNameKey $_ }
        $hit = $list | Where-Object { $names -contains (ConvertTo-PcNameKey $_.Nombre) } | Select-Object -First 1
        if ($hit) { $pc.Net.IP = $hit.IP; $pc.IPSource = 'david' }
    }
    return $true
}

function Get-ProfileName($prof) { if ($script:Lang -eq 'es') { return $prof.Name.es } else { return $prof.Name.en } }

# ---------------------------------------------------------------------
#  -ValidateConfig: comprueba la configuracion y muestra el plan de cada
#  PC. Lo ejecuta GitHub en cada cambio (Windows PowerShell 5.1).
# ---------------------------------------------------------------------
function Test-KermaConfig {
    $errors = New-Object System.Collections.Generic.List[string]
    $logins = @('NoPassword', 'Keep'); $wus = @('Manual', 'Disabled', 'Automatic', 'Keep'); $rds = @('Client', 'Master', 'None')
    $types  = @('Table', 'Staff', 'Office')
    $flags  = @('Time', 'Rename', 'StaticIP', 'Tuning', 'RemoveApps', 'RemoveOffice', 'RemoveOneDrive', 'Audio', 'ProgramSettings', 'Wallpaper', 'Panel')

    foreach ($pn in $Profiles.Keys) {
        $p = $Profiles[$pn]
        if (-not $p.Name -or -not $p.Name.es -or -not $p.Name.en) { $errors.Add("perfil ${pn}: falta Name.es / Name.en") }
        if ($types  -notcontains $p.Type)          { $errors.Add("perfil ${pn}: Type '$($p.Type)' no valido ($($types -join ', '))") }
        if ($logins -notcontains $p.Login)         { $errors.Add("perfil ${pn}: Login '$($p.Login)' no valido ($($logins -join ', '))") }
        if ($wus    -notcontains $p.WindowsUpdate) { $errors.Add("perfil ${pn}: WindowsUpdate '$($p.WindowsUpdate)' no valido ($($wus -join ', '))") }
        if ($rds    -notcontains $p.RustDesk)      { $errors.Add("perfil ${pn}: RustDesk '$($p.RustDesk)' no valido ($($rds -join ', '))") }
        foreach ($f in $flags) { if ($p[$f] -isnot [bool]) { $errors.Add("perfil ${pn}: $f debe ser `$true o `$false") } }
        foreach ($k in @($p.Programs))  { if (-not $Packages.ContainsKey($k)) { $errors.Add("perfil ${pn}: el programa '$k' no existe en programas.psd1") } }
        foreach ($k in @($p.Autostart)) { if (-not $Apps.ContainsKey($k))     { $errors.Add("perfil ${pn}: la app '$k' no existe en programas.psd1 (Apps)") } }
        if ($p.RustDesk -ne 'None' -and @($p.Programs) -notcontains 'RustDesk') { $errors.Add("perfil ${pn}: RustDesk '$($p.RustDesk)' pero RustDesk no esta en Programs") }
    }
    foreach ($k in $Packages.Keys) {
        $p = $Packages[$k]
        if (@('winget', 'github') -notcontains $p.Source) { $errors.Add("programa ${k}: Source '$($p.Source)' no valido") }
        if ($p.Source -eq 'github' -and (-not $p.Repo -or -not $p.Asset)) { $errors.Add("programa ${k}: falta Repo o Asset") }
        if ($p.Requires -and -not $Packages.ContainsKey($p.Requires)) { $errors.Add("programa ${k}: Requires '$($p.Requires)' no existe") }
    }

    $seen = @{}
    foreach ($pc in $PCs) {
        foreach ($field in @('Key', 'Hostname', 'Username')) {
            $v = ([string]$pc[$field]).ToUpperInvariant()
            if (-not $v) { $errors.Add("PC $($pc.Label): falta $field"); continue }
            if ($seen.ContainsKey("$field|$v")) { $errors.Add("PC ${v}: $field repetido") } else { $seen["$field|$v"] = $true }
        }
        if (-not $Profiles.ContainsKey($pc.Profile)) { $errors.Add("PC $($pc.Key): el perfil '$($pc.Profile)' no existe") }
        if ($pc.Hostname.Length -gt 15) { $errors.Add("PC $($pc.Key): el nombre de equipo '$($pc.Hostname)' pasa de 15 caracteres") }
        if ($pc.Net.IP) {
            if (-not (Test-IPv4 $pc.Net.IP)) { $errors.Add("PC $($pc.Key): IP '$($pc.Net.IP)' no valida") }
            elseif ($seen.ContainsKey("IP|$($pc.Net.IP)")) { $errors.Add("PC $($pc.Key): IP $($pc.Net.IP) repetida") }
            else { $seen["IP|$($pc.Net.IP)"] = $true }
        }
    }

    # Archivos que el script necesita
    $assets = Get-AssetsDir
    if (-not $assets) { $errors.Add('no se encuentra la carpeta assets') } else {
        $def = Test-Path -LiteralPath (Join-Path $assets 'wallpaper\default.jpg')
        if (-not $def) { $errors.Add('falta assets\wallpaper\default.jpg') }
        foreach ($f in @('Orbitron-Black.ttf', 'Sora-Regular.ttf')) {
            if (-not (Test-Path -LiteralPath (Join-Path $assets "fonts\$f"))) { $errors.Add("falta la fuente assets\fonts\$f") }
        }
        # Prueba real del fondo: cargar las fuentes y dibujar uno de dos lineas
        if ($def) {
            try {
                Add-Type -AssemblyName System.Drawing
                $wf = Get-WallpaperFonts
                if (-not $wf.Title) { $errors.Add('Windows no carga assets\fonts\Orbitron-Black.ttf') }
                if (-not $wf.Info)  { $errors.Add('Windows no carga assets\fonts\Sora-Regular.ttf') }
                if ($wf.Pfc) { $wf.Pfc.Dispose() }
                $tmp = Join-Path ([IO.Path]::GetTempPath()) 'kerma-wallpaper-test.jpg'
                New-KermaWallpaper (Join-Path $assets 'wallpaper\default.jpg') 'Office | Manager' 'KG-TEST    192.168.0.1    test' $tmp
                $img = [System.Drawing.Image]::FromFile($tmp)
                if ($img.Width -ne 1920 -or $img.Height -ne 1080) { $errors.Add("el fondo de prueba sale de $($img.Width)x$($img.Height)") }
                $img.Dispose()
                Write-Host "Fondo de prueba: OK ($((Get-Item $tmp).Length) bytes, fuentes $($wf.Title.Name) / $($wf.Info.Name))"
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            } catch { $errors.Add("no se pudo generar un fondo de prueba: $($_.Exception.Message)") }
        }
        $theme = Join-Path $assets "obs\themes\$ObsThemeFile"
        if (-not (Test-Path -LiteralPath $theme)) { $errors.Add("falta el tema de OBS assets\obs\themes\$ObsThemeFile") }
        elseif (-not (Select-String -LiteralPath $theme -SimpleMatch "id: '$ObsThemeId'" -Quiet)) { $errors.Add("el id del tema de OBS ($ObsThemeId) no coincide con @OBSThemeMeta de $ObsThemeFile") }
    }
    foreach ($f in @('Kerma-Status.ps1', 'rustdesk\Configurar-Esta-PC.ps1', 'rustdesk\Instalar-Logo-Kerma.ps1', 'rustdesk\Agregar-Favoritos.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $f))) { $errors.Add("falta $f") }
    }
    # El borrado de .sentinel de OBS debe llegar literal al .bat (lo resuelve cmd del usuario)
    $obsPre = @($Apps['OBS'].PreLaunch) -join ' '
    if ($obsPre -notmatch '%APPDATA%\\obs-studio\\\.sentinel\\run_\*') { $errors.Add('Apps.OBS.PreLaunch debe borrar "%APPDATA%\obs-studio\.sentinel\run_*" literal') }

    # La version del script = la primera del CHANGELOG (solo en el repositorio)
    $changelog = Join-Path (Split-Path -Path $Root -Parent) 'CHANGELOG.md'
    if (Test-Path -LiteralPath $changelog) {
        $first = Select-String -LiteralPath $changelog -Pattern '^## \[([0-9.]+)\]' | Select-Object -First 1
        if ($first -and $first.Matches[0].Groups[1].Value -ne $ScriptVersion) {
            $errors.Add("ScriptVersion $ScriptVersion no coincide con la primera version del CHANGELOG ($($first.Matches[0].Groups[1].Value))")
        }
    }

    # Plan de cada PC
    Write-Host ''
    Write-Host ("{0,-8} {1,-11} {2,-16} {3,-15} {4,-7} {5}" -f 'PC', 'Perfil', 'Equipo', 'IP', 'RustDesk', 'Programas / arranque')
    foreach ($pc in $PCs) {
        $p = $Profiles[$pc.Profile]
        if (-not $p) { continue }
        Write-Host ("{0,-8} {1,-11} {2,-16} {3,-15} {4,-7} {5} / {6}" -f $pc.Key, $pc.Profile, $pc.Hostname, $(if ($pc.Net.IP) { $pc.Net.IP } else { '-' }), $p.RustDesk,
            (@($p.Programs) -join ','), (@($pc.Apps) -join ','))
    }
    Write-Host ''
    foreach ($e in $errors) { Write-Host "::error::$e" }
    if ($errors.Count) { Write-Host "$($errors.Count) error(es) en la configuracion." -ForegroundColor Red; return $false }
    Write-Host 'Configuracion correcta.' -ForegroundColor Green
    return $true
}
