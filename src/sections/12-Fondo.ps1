# =====================================================================
#  FONDO DE PANTALLA: plantilla de Kerma de la mesa + nombre de equipo,
#  IP y version. assets\wallpaper\<clave>.jpg; si no, default.jpg con el
#  nombre del PC escrito por el script.
# =====================================================================

function New-KermaWallpaper([string]$template, [string]$label, [string]$info, [string]$out) {
    Add-Type -AssemblyName System.Drawing
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
            $family = 'Segoe UI'
            try { [void](New-Object System.Drawing.FontFamily 'Bahnschrift'); $family = 'Bahnschrift' } catch { }
            $f1 = New-Object System.Drawing.Font($family, 32, [System.Drawing.FontStyle]::Bold, $px)
            $g.DrawString($label.ToUpper(), $f1, [System.Drawing.Brushes]::White, 146, 826)
            $f1.Dispose()
        }
        $f2 = New-Object System.Drawing.Font('Segoe UI', 21, [System.Drawing.FontStyle]::Regular, $px)
        $br = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(215, 196, 186, 236))
        $g.DrawString($info, $f2, $br, 146, 905)
        $f2.Dispose()
        $br.Dispose()
    } finally { $g.Dispose(); $src.Dispose() }
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
    if ($own -and (Test-Path -LiteralPath $own)) { $template = $own; $label = '' }
    elseif ($def -and (Test-Path -LiteralPath $def)) { $template = $def; $label = $pc.FullName }
    else { Write-Skip (L 'No wallpaper templates in assets\wallpaper.' 'No hay plantillas de fondo en assets\wallpaper.'); return }
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
