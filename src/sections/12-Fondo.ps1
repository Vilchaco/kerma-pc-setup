# =====================================================================
#  FONDO DE PANTALLA: plantilla de Kerma de la mesa + nombre de equipo,
#  IP y version. assets\wallpaper\<clave>.jpg; si no, default.jpg con el
#  nombre del PC escrito por el script.
# =====================================================================

# Fuentes de assets\fonts (las del MCR): se cargan solo para dibujar, sin instalarlas.
# Si no se pueden cargar, se usan Bahnschrift / Segoe UI de Windows.
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

function New-KermaWallpaper([string]$template, [string]$label, [string]$info, [string]$out) {
    Add-Type -AssemblyName System.Drawing
    $fonts = Get-WallpaperFonts
    $src = [System.Drawing.Image]::FromFile($template)
    $bmp = New-Object System.Drawing.Bitmap 1920, 1080
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $g.DrawImage($src, 0, 0, 1920, 1080)
        $px = [System.Drawing.GraphicsUnit]::Pixel
        if ($label) {
            if ($fonts.Title) {
                $f1 = New-Object System.Drawing.Font($fonts.Title, 34, [System.Drawing.FontStyle]::Regular, $px)
            } else {
                $family = 'Segoe UI'
                try { [void](New-Object System.Drawing.FontFamily 'Bahnschrift'); $family = 'Bahnschrift' } catch { }
                $f1 = New-Object System.Drawing.Font($family, 32, [System.Drawing.FontStyle]::Bold, $px)
            }
            # "|" parte el nombre en dos lineas, como en las plantillas de las mesas
            $lines = @($label.Split('|') | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -First 2)
            $y = if ($lines.Count -gt 1) { 800 } else { 826 }
            foreach ($ln in $lines) { $g.DrawString($ln.ToUpper(), $f1, [System.Drawing.Brushes]::White, 146, $y); $y += 54 }
            $f1.Dispose()
        }
        $f2 = if ($fonts.Info) { New-Object System.Drawing.Font($fonts.Info, 21, [System.Drawing.FontStyle]::Regular, $px) }
              else { New-Object System.Drawing.Font('Segoe UI', 21, [System.Drawing.FontStyle]::Regular, $px) }
        $br = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(215, 196, 186, 236))
        $g.DrawString($info, $f2, $br, 146, 918)
        $f2.Dispose()
        $br.Dispose()
    } finally { $g.Dispose(); $src.Dispose(); if ($fonts.Pfc) { $fonts.Pfc.Dispose() } }
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 95L
    $bmp.Save($out, $codec, $ep)
    $bmp.Dispose()
}

function Invoke-Wallpaper($pc) {
    Write-Section (L 'WALLPAPER' 'FONDO DE PANTALLA')
    $assets = Get-AssetsDir
    $own = if ($assets) { Join-Path $assets "wallpaper\$($pc.Key).jpg" } else { '' }
    $def = if ($assets) { Join-Path $assets 'wallpaper\default.jpg' } else { '' }
    $hasOwn = $own -and (Test-Path -LiteralPath $own)
    $hasDef = $def -and (Test-Path -LiteralPath $def)
    if (-not $hasOwn -and -not $hasDef) { Write-Skip (L 'No wallpaper templates in assets\wallpaper.' 'No hay plantillas de fondo en assets\wallpaper.'); return }

    # Nombre del fondo: el de la plantilla de la mesa, el del inventario
    # (WallpaperText) o el nombre completo. En Manual se puede escribir otro.
    $suggest = if ($pc.WallpaperText) { $pc.WallpaperText } else { $pc.FullName }
    $custom = ''
    if (-not $script:Auto) {
        $shown = if ($hasOwn -and -not $pc.WallpaperText) { L "the one in the table's template" 'el de la plantilla de la mesa' } else { $suggest }
        Write-Host ((L '  Name on the wallpaper: {0}' '  Nombre en el fondo: {0}') -f $shown)
        $custom = (Read-Host (L '  Enter = keep it, or type another (use | for two lines)' '  Enter = mantenerlo, o escribe otro (usa | para dos líneas)')).Trim()
    }
    if ($custom) { $template = $(if ($hasDef) { $def } else { $own }); $label = $custom }
    elseif ($pc.WallpaperText -and $hasDef) { $template = $def; $label = $pc.WallpaperText }
    elseif ($hasOwn) { $template = $own; $label = '' }
    else { $template = $def; $label = $suggest }
    $host_ = if ($State.HostRenamed) { $pc.Hostname } else { $env:COMPUTERNAME }
    $ip = Get-PrimaryIPv4
    $info = "$host_    $(if ($ip) { $ip } else { L 'no IP' 'sin IP' })    Kerma PC Setup v$ScriptVersion"
    $lab = if ($label) { (L "  + label '{0}'" "  + nombre '{0}'") -f $label } else { '' }
    Write-Host ((L '  Template : {0}{1}' '  Plantilla : {0}{1}') -f (Split-Path -Path $template -Leaf), $lab)
    Write-Host ((L '  Text     : {0}' '  Texto     : {0}') -f $info)
    Write-Host ''
    if (-not (Ask-YesNo (L '  Set this wallpaper?' '  ¿Poner este fondo?') ([bool]$Prof.Wallpaper))) { Write-Skip (L 'Wallpaper left unchanged.' 'Fondo sin cambios.'); return }

    $dir = Join-Path $env:ProgramData 'Kerma'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $out = Join-Path $dir 'wallpaper.jpg'
    New-KermaWallpaper $template $label $info $out

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
        Add-Change ((L 'Wallpaper: {0}' 'Fondo: {0}') -f $info)
    } else {
        Write-Warn ((L 'Windows did not accept the wallpaper. The picture is ready in {0}.' 'Windows no aceptó el fondo. La imagen está lista en {0}.') -f $out)
    }
    if ($State.HostRenamed -and $pc.Hostname -ne $env:COMPUTERNAME) {
        Write-Note (L '  The wallpaper already shows the new computer name, which applies after the restart.' '  El fondo ya muestra el nombre nuevo del equipo, que se aplica al reiniciar.')
    }
}
