# =====================================================================
#  FONDO DE PANTALLA: el mismo diseno en todos los PCs. La plantilla
#  assets\wallpaper\base.jpg lleva el logo y los personajes; el script
#  dibuja debajo del logo una tarjeta con el tipo de PC en su color, el
#  nombre, la IP y el nombre de equipo. Colores y textos del tipo en
#  config\ajustes.psd1 (Wallpaper.Tags).
# =====================================================================

function Get-WallpaperFonts {
    $r = @{ Title = $null; Info = $null; Pfc = $null }
    $assets = Get-AssetsDir
    if (-not $assets) { return $r }
    try {
        $pfc = New-Object System.Drawing.Text.PrivateFontCollection
        foreach ($f in @('Orbitron-Black.ttf', 'Sora-Regular.ttf')) {
            $p = Join-Path $assets "fonts\$f"
            if (Test-Path -LiteralPath $p) { $pfc.AddFontFile($p) }
        }
        foreach ($fam in $pfc.Families) {
            if ($fam.Name -like 'Orbitron*') { $r.Title = $fam }
            elseif ($fam.Name -like 'Sora*') { $r.Info = $fam }
        }
        $r.Pfc = $pfc
    } catch { }
    return $r
}

# Rectangulo redondeado para System.Drawing
function New-RoundedRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

# Tipo de PC y color de la tarjeta: por juego y, si no, por perfil
function Get-WallpaperTag($pc) {
    foreach ($k in @($pc.Game, $pc.Profile)) {
        if ($k -and $WallpaperTags.ContainsKey($k)) { return $WallpaperTags[$k] }
    }
    return @{ Text = ''; Color = '#C8A96E' }
}

# Dibuja el fondo: plantilla + tarjeta. $name admite '|' para dos lineas;
# si es demasiado largo se parte solo o se reduce la letra.
function New-KermaWallpaper([string]$template, [string]$name, [string]$tag, [string]$color, [string]$ip, [string]$hostname, [string]$out) {
    Add-Type -AssemblyName System.Drawing
    $fonts = Get-WallpaperFonts
    $px = [System.Drawing.GraphicsUnit]::Pixel
    $fmt = [System.Drawing.StringFormat]::GenericTypographic
    $src = [System.Drawing.Image]::FromFile($template)
    $bmp = New-Object System.Drawing.Bitmap 1920, 1080
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $made = @()
    try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
        $g.DrawImage($src, 0, 0, 1920, 1080)

        $titleFam = if ($fonts.Title) { $fonts.Title } else { New-Object System.Drawing.FontFamily 'Segoe UI' }
        $infoFam  = if ($fonts.Info)  { $fonts.Info }  else { New-Object System.Drawing.FontFamily 'Segoe UI' }
        $titleStyle = if ($fonts.Title) { [System.Drawing.FontStyle]::Regular } else { [System.Drawing.FontStyle]::Bold }
        function NewFont($fam, [float]$size, $style) { $f = New-Object System.Drawing.Font($fam, $size, $style, $px); $script:madeFonts += $f; return $f }
        $script:madeFonts = @()
        $X = 150; $Y = 530; $pad = 40; $minW = 600; $maxW = 760; $textMax = $maxW - $pad - 36

        # nombre: lineas por '|'; si una linea no cabe, partirla por el espacio central
        $lines = @($name.Split('|') | ForEach-Object { $_.Trim().ToUpperInvariant() } | Where-Object { $_ } | Select-Object -First 2)
        if (-not $lines.Count) { $lines = @(' ') }
        $size = 54.0
        $fTitle = NewFont $titleFam $size $titleStyle
        if ($lines.Count -eq 1 -and $g.MeasureString($lines[0], $fTitle, 4000, $fmt).Width -gt $textMax -and $lines[0].Contains(' ')) {
            $words = $lines[0].Split(' '); $best = $null; $bestW = 1e9
            for ($i = 1; $i -lt $words.Count; $i++) {
                $a = ($words[0..($i - 1)] -join ' '); $b = ($words[$i..($words.Count - 1)] -join ' ')
                $w = [Math]::Max($g.MeasureString($a, $fTitle, 4000, $fmt).Width, $g.MeasureString($b, $fTitle, 4000, $fmt).Width)
                if ($w -lt $bestW) { $bestW = $w; $best = @($a, $b) }
            }
            $lines = $best
        }
        while ($size -gt 30 -and ($lines | ForEach-Object { $g.MeasureString($_, $fTitle, 4000, $fmt).Width } | Measure-Object -Maximum).Maximum -gt $textMax) {
            $size -= 2; $fTitle = NewFont $titleFam $size $titleStyle
        }
        $fTag  = NewFont $titleFam 21 $titleStyle
        $fIp   = NewFont $infoFam 30 ([System.Drawing.FontStyle]::Regular)
        $fHost = NewFont $infoFam 22 ([System.Drawing.FontStyle]::Regular)

        $lineH = [Math]::Round($size * 1.3)
        $wTitle = ($lines | ForEach-Object { $g.MeasureString($_, $fTitle, 4000, $fmt).Width } | Measure-Object -Maximum).Maximum
        $wIp = $g.MeasureString($ip, $fIp, 4000, $fmt).Width
        $wInfo = $wIp + 26 + $g.MeasureString($hostname, $fHost, 4000, $fmt).Width
        $wTag = $g.MeasureString($tag, $fTag, 4000, $fmt).Width
        $W = [Math]::Min($maxW, [Math]::Max($minW, [Math]::Max([Math]::Max($wTitle, $wInfo), $wTag) + $pad + 36))
        $hasTag = [bool]$tag
        $H = 28 + $(if ($hasTag) { 42 } else { 0 }) + $lines.Count * $lineH + 14 + 16 + 40 + 24

        # tarjeta semitransparente y barra de color
        $accent = [System.Drawing.ColorTranslator]::FromHtml($color)
        $card = New-RoundedRect $X $Y $W $H 20
        $fill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150, 12, 8, 40))
        $edge = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(40, 255, 255, 255)), 1
        $g.FillPath($fill, $card); $g.DrawPath($edge, $card)
        $bar = New-RoundedRect $X $Y 9 $H 4
        $barBrush = New-Object System.Drawing.SolidBrush $accent
        $g.FillPath($barBrush, $bar)

        $white = [System.Drawing.Brushes]::White
        $lav = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(215, 196, 186, 236))
        $tx = $X + $pad; $ty = $Y + 28
        if ($hasTag) { $g.DrawString($tag.ToUpperInvariant(), $fTag, $barBrush, $tx, $ty, $fmt); $ty += 42 }
        foreach ($l in $lines) { $g.DrawString($l, $fTitle, $white, $tx, $ty, $fmt); $ty += $lineH }
        $ty += 14
        $g.DrawLine($edge, $tx, $ty, $X + $W - 36, $ty)
        $ty += 16
        $g.DrawString($ip, $fIp, $white, $tx, $ty, $fmt)
        $g.DrawString($hostname, $fHost, $lav, ($tx + $wIp + 26), ($ty + 6), $fmt)
        foreach ($o in @($card, $fill, $edge, $bar, $barBrush, $lav)) { $o.Dispose() }
    } finally {
        foreach ($f in $script:madeFonts) { $f.Dispose() }
        $g.Dispose(); $src.Dispose(); if ($fonts.Pfc) { $fonts.Pfc.Dispose() }
    }
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 95L
    $bmp.Save($out, $codec, $ep)
    $bmp.Dispose()
}

# Aspecto Kerma de Windows: modo oscuro y color de enfasis dorado (como la web
# y OBS). Paleta de 8 tonos (mas claros -> color -> mas oscuros) que usa Windows.
function Set-KermaColors([string]$hex) {
    Add-Type -AssemblyName System.Drawing
    $c = [Drawing.ColorTranslator]::FromHtml($hex)
    $mix = { param($t, [double]$f) [byte][Math]::Round($c.$t + ($(if ($f -ge 0) { 255 } else { 0 }) - $c.$t) * [Math]::Abs($f)) }
    $shades = @(0.6, 0.4, 0.2, 0, -0.2, -0.4, -0.6)
    $pal = New-Object byte[] 32
    for ($i = 0; $i -lt 7; $i++) { $pal[$i * 4] = & $mix 'R' $shades[$i]; $pal[$i * 4 + 1] = & $mix 'G' $shades[$i]; $pal[$i * 4 + 2] = & $mix 'B' $shades[$i] }
    $pal[28] = 0x88; $pal[29] = 0x88; $pal[30] = 0x88
    # DWORD con el color: ABGR (lo que espera Windows) o ARGB; ToInt32 base 16 admite el bit alto
    $dw = { param([int]$a, [int]$x, [int]$y, [int]$z) [Convert]::ToInt32(('{0:X2}{1:X2}{2:X2}{3:X2}' -f $a, $x, $y, $z), 16) }
    $abgr = { param([int]$i) & $dw 0xFF $pal[$i * 4 + 2] $pal[$i * 4 + 1] $pal[$i * 4] }

    $pers = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Initialize-RegistryKey $pers
    Set-ItemProperty -Path $pers -Name AppsUseLightTheme -Value 0 -Type DWord
    Set-ItemProperty -Path $pers -Name SystemUsesLightTheme -Value 0 -Type DWord
    Set-ItemProperty -Path $pers -Name ColorPrevalence -Value 0 -Type DWord      # barra de tareas oscura, sin dorado
    $acc = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
    Initialize-RegistryKey $acc
    Set-ItemProperty -Path $acc -Name AccentPalette -Value $pal -Type Binary
    Set-ItemProperty -Path $acc -Name AccentColorMenu -Value (& $abgr 4) -Type DWord
    Set-ItemProperty -Path $acc -Name StartColorMenu -Value (& $abgr 5) -Type DWord
    $dwm = 'HKCU:\Software\Microsoft\Windows\DWM'
    Initialize-RegistryKey $dwm
    $argb = & $dw 0xC4 $c.R $c.G $c.B
    Set-ItemProperty -Path $dwm -Name AccentColor -Value (& $abgr 3) -Type DWord
    Set-ItemProperty -Path $dwm -Name ColorizationColor -Value $argb -Type DWord
    Set-ItemProperty -Path $dwm -Name ColorizationAfterglow -Value $argb -Type DWord
    Set-ItemProperty -Path $dwm -Name ColorPrevalence -Value 1 -Type DWord        # barras de titulo en dorado
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name AutoColorization -Value '0' -Type String
}

# Pantalla de bloqueo con la plantilla del fondo (logo de Kerma, sin tarjeta).
# PersonalizationCSP: funciona en Pro (la directiva LockScreenImage es solo Enterprise).
function Set-KermaLockScreen([string]$template) {
    $img = Join-Path $env:ProgramData 'Kerma\lockscreen.jpg'
    Copy-Item -LiteralPath $template -Destination $img -Force
    $csp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
    Initialize-RegistryKey $csp
    New-ItemProperty -Path $csp -Name LockScreenImagePath -Value $img -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $csp -Name LockScreenImageUrl -Value $img -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $csp -Name LockScreenImageStatus -Value 1 -PropertyType DWord -Force | Out-Null
    # sin Windows Spotlight ni "datos curiosos" encima de la imagen
    $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    Initialize-RegistryKey $cdm
    foreach ($n in @('RotatingLockScreenEnabled', 'RotatingLockScreenOverlayEnabled', 'SubscribedContent-338387Enabled')) {
        Set-ItemProperty -Path $cdm -Name $n -Value 0 -Type DWord
    }
}

function Invoke-Wallpaper($pc) {
    Write-Section (L 'WALLPAPER' 'FONDO DE PANTALLA')
    $assets = Get-AssetsDir
    $template = if ($assets) { Join-Path $assets 'wallpaper\base.jpg' } else { '' }
    if (-not $template -or -not (Test-Path -LiteralPath $template)) { Write-Skip (L 'No wallpaper template (assets\wallpaper\base.jpg).' 'No hay plantilla de fondo (assets\wallpaper\base.jpg).'); return }

    $name = if ($pc.WallpaperText) { $pc.WallpaperText } else { $pc.Label }
    if (-not $script:Auto) {
        Write-Host ((L '  Name on the wallpaper: {0}' '  Nombre en el fondo: {0}') -f $name)
        $custom = (Read-Host (L '  Enter = keep it, or type another (use | for two lines)' '  Enter = mantenerlo, o escribe otro (usa | para dos líneas)')).Trim()
        if ($custom) { $name = $custom }
    }
    $tagInfo = Get-WallpaperTag $pc
    $hostname = if ($State.HostRenamed -or $State.RenameWanted) { $pc.Hostname } else { $env:COMPUTERNAME }
    $ip = Get-PrimaryIPv4
    if ($pc.Net.IP -and $State.Changes -match [regex]::Escape($pc.Net.IP)) { $ip = $pc.Net.IP }
    if (-not $ip) { $ip = L 'no IP' 'sin IP' }
    Write-Host ((L '  Card: {0} / {1} / {2}  {3}' '  Tarjeta: {0} / {1} / {2}  {3}') -f $tagInfo.Text, ($name -replace '\s*\|\s*', ' '), $ip, $hostname)
    Write-Host ''
    if (-not (Ask-YesNo (L '  Set this wallpaper?' '  ¿Poner este fondo?') ([bool]$Prof.Wallpaper))) { Write-Skip (L 'Wallpaper left unchanged.' 'Fondo sin cambios.'); return }

    $dir = Join-Path $env:ProgramData 'Kerma'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $out = Join-Path $dir 'wallpaper.jpg'
    New-KermaWallpaper $template $name $tagInfo.Text $tagInfo.Color $ip $hostname $out

    $desk = 'HKCU:\Control Panel\Desktop'
    Set-ItemProperty -Path $desk -Name WallpaperStyle -Value '10' -Type String   # rellenar
    Set-ItemProperty -Path $desk -Name TileWallpaper -Value '0' -Type String
    if (-not ('KermaWallpaperApi' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class KermaWallpaperApi {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SystemParametersInfo(int action, int param, string value, int flags);
}
'@
    }
    # SPI_SETDESKWALLPAPER = 20, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE = 3
    if ([KermaWallpaperApi]::SystemParametersInfo(20, 0, $out, 3)) {
        Write-Ok ((L "Wallpaper set for user '{0}' ({1})." "Fondo puesto para '{0}' ({1}).") -f $env:USERNAME, $out)
        Add-Change ((L 'Wallpaper: {0} ({1})' 'Fondo: {0} ({1})') -f ($name -replace '\s*\|\s*', ' '), $ip)
    } else {
        Write-Warn ((L 'Windows did not accept the wallpaper. The picture is ready in {0}.' 'Windows no aceptó el fondo. La imagen está lista en {0}.') -f $out)
    }
    if ($AccentColor) {
        try {
            Set-KermaColors $AccentColor
            Write-Ok ((L 'Windows look: dark mode and Kerma gold accent ({0}). Fully applied after the restart.' 'Aspecto de Windows: modo oscuro y dorado Kerma ({0}). Queda del todo al reiniciar.') -f $AccentColor)
            Add-Change (L 'Look: dark mode + Kerma gold' 'Aspecto: modo oscuro + dorado Kerma')
        } catch { Write-Warn ((L 'Windows colors: {0}' 'Colores de Windows: {0}') -f $_.Exception.Message) }
    }
    try {
        Set-KermaLockScreen $template
        Write-Ok (L 'Lock screen: Kerma logo.' 'Pantalla de bloqueo: logo de Kerma.')
        Add-Change (L 'Lock screen: Kerma logo' 'Pantalla de bloqueo: logo de Kerma')
    } catch { Write-Warn ((L 'Lock screen: {0}' 'Pantalla de bloqueo: {0}') -f $_.Exception.Message) }
    if (($State.HostRenamed -or $State.RenameWanted) -and $pc.Hostname -ne $env:COMPUTERNAME) {
        Write-Note (L '  The wallpaper already shows the new computer name, which applies after the restart.' '  El fondo ya muestra el nombre nuevo del equipo, que se aplica al reiniciar.')
    }
}
