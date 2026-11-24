# =====================================================================
#  Kerma - arranque de la mesa (pantalla "PREPARING THE TABLE")
#  Lo lanza el .bat de arranque de la Dealer App (11-Autoarranque.ps1) al
#  iniciar sesion. Tapa TODOS los monitores (pantalla del dealer, prompter y
#  el dummy; encima de todo, tambien de la barra de Windows) mientras arrancan las demas apps del PC; cuando estan
#  listas (OBS: con su WebSocket escuchando) abre la Dealer App, la maximiza,
#  ensena "TABLE READY" unos segundos, se quita y deja el foco en el login.
#  - Si las apps no estan en TimeoutSec, abre la Dealer App igual.
#  - Si la Dealer App ya esta abierta: solo le da el foco. Si la relanza el
#    vigilante a mitad de turno (todo lo demas ya abierto): sin pantalla.
#  - Doble clic en la pantalla = quitarla ya (para tecnicos). No se cierra con
#    teclas: el lector de cartas escribe como un teclado.
#  - Se pone encima UNA vez y no vuelve a reclamarlo: el HDMI Mirror reafirma
#    su ventana cada poco y pelearse con el hacia parpadear. Tampoco se excluye
#    de las capturas: si el espejo copia la pantalla, copia esta pantalla.
#  - Si este script falla, el .bat abre la Dealer App a la antigua.
#  Config: startup.json al lado (lo escribe el setup). Textos en ASCII.
# =====================================================================
param([string]$Config = (Join-Path $PSScriptRoot 'startup.json'))

$ErrorActionPreference = 'Stop'
$cfg = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
$proc      = [string]$cfg.proc
$timeout   = if ($cfg.timeoutSec) { [int]$cfg.timeoutSec } else { 180 }
$readySec  = if ($cfg.readySec)   { [int]$cfg.readySec }   else { 5 }
$maxSec    = if ($cfg.maxSec)     { [int]$cfg.maxSec }     else { 420 }
$waits     = @($cfg.waits | Where-Object { $_ -and $_.proc })

Add-Type -Namespace KS -Name W -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr h, int c);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(System.IntPtr h);
[DllImport("user32.dll")] public static extern bool BringWindowToTop(System.IntPtr h);
[DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(System.IntPtr h, out uint p);
[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool x);
[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
[DllImport("user32.dll")] public static extern void keybd_event(byte v, byte s, uint f, System.UIntPtr e);
[DllImport("user32.dll")] public static extern bool SetWindowDisplayAffinity(System.IntPtr h, uint a);
'@

function Get-Win([string]$n) { Get-Process -Name $n -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1 }
function Test-Running([string]$n) { [bool](Get-Process -Name $n -ErrorAction SilentlyContinue) }

# Puerto del WebSocket de OBS (el setup conserva el que tuviera): de su config.json
$obsPort = 0
try {
    $wsCfg = Join-Path $env:APPDATA 'obs-studio\plugin_config\obs-websocket\config.json'
    if (Test-Path -LiteralPath $wsCfg) {
        $ws = Get-Content -LiteralPath $wsCfg -Raw | ConvertFrom-Json
        if ($ws.server_enabled -and $ws.server_port) { $obsPort = [int]$ws.server_port }
    }
} catch { $obsPort = 0 }

$script:firstWin = @{}
function Test-Ready($w) {
    $win = Get-Win ([string]$w.proc)
    if ([string]$w.proc -ne 'obs64') { return (Test-Running ([string]$w.proc)) }
    if (-not $win) { return $false }
    if (-not $script:firstWin.ContainsKey('obs64')) { $script:firstWin['obs64'] = Get-Date }
    if ($obsPort -gt 0) {
        $listen = $false
        try { $listen = [bool](Get-NetTCPConnection -LocalPort $obsPort -State Listen -ErrorAction Stop) } catch { }
        if ($listen) { return $true }
        return (((Get-Date) - $script:firstWin['obs64']).TotalSeconds -ge 30)
    }
    return $true
}

function Start-Dealer {
    if (Test-Running $proc) { return }
    $path = [Environment]::ExpandEnvironmentVariables([string]$cfg.app)
    Start-Process -FilePath $path -WorkingDirectory (Split-Path -Path $path -Parent) -WindowStyle Maximized
}

function Set-DealerFocus {
    $p = Get-Win $proc
    if (-not $p) { return }
    $h = $p.MainWindowHandle
    [void][KS.W]::ShowWindow($h, 3)
    $fp = [uint32]0
    $ft = [KS.W]::GetWindowThreadProcessId([KS.W]::GetForegroundWindow(), [ref]$fp)
    $me = [KS.W]::GetCurrentThreadId()
    $at = ($ft -ne 0 -and $ft -ne $me) -and [KS.W]::AttachThreadInput($me, $ft, $true)
    [void][KS.W]::BringWindowToTop($h); [void][KS.W]::SetForegroundWindow($h)
    if ($at) { [void][KS.W]::AttachThreadInput($me, $ft, $false) }
    Start-Sleep -Milliseconds 200
    if ([KS.W]::GetForegroundWindow() -ne $h) { [KS.W]::keybd_event(0x12, 0, 0, [System.UIntPtr]::Zero); [void][KS.W]::SetForegroundWindow($h); [KS.W]::keybd_event(0x12, 0, 2, [System.UIntPtr]::Zero) }
    [void][KS.W]::ShowWindow($h, 3)
}

# Abre (si hace falta), espera su ventana, maximiza y da el foco (otra vez a los 5 s: las apps tipo Electron se redimensionan al cargar)
function Complete-Dealer {
    Start-Dealer
    for ($i = 0; $i -lt 120 -and -not (Get-Win $proc); $i++) { Start-Sleep -Seconds 1 }
    if (-not (Get-Win $proc)) { return }
    Start-Sleep -Seconds 1
    Set-DealerFocus
    Start-Sleep -Seconds 5
    Set-DealerFocus
}

# ---- ya abierta: solo el foco. Relanzada a mitad de turno: sin pantalla.
if (Test-Running $proc) { Set-DealerFocus; exit 0 }
$pending = @($waits | Where-Object { -not (Test-Running ([string]$_.proc)) })
if ($pending.Count -eq 0) { Complete-Dealer; exit 0 }

# ------------------------------------------------------------- pantalla
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$start = Get-Date
$script:state = 'waiting'   # waiting -> launching -> ready -> done
$script:launchedAt = $null
$script:readyAt = $null
$script:pulse = $true

$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$famTitle = $null; $famText = $null
try {
    foreach ($f in @('Orbitron-Bold.ttf', 'Sora-Regular.ttf')) {   # titulos en Orbitron Bold (700) como el panel y KermaOS; texto en Sora
        $p = Join-Path $PSScriptRoot $f
        if (Test-Path -LiteralPath $p) { $pfc.AddFontFile($p) }
    }
    foreach ($fam in $pfc.Families) { if ($fam.Name -like 'Orbitron*') { $famTitle = $fam } elseif ($fam.Name -like 'Sora*') { $famText = $fam } }
} catch { }
if (-not $famTitle) { $famTitle = New-Object System.Drawing.FontFamily 'Segoe UI' }
if (-not $famText)  { $famText  = New-Object System.Drawing.FontFamily 'Segoe UI' }
$logo = $null
$logoPath = Join-Path $PSScriptRoot 'logo.png'
if (Test-Path -LiteralPath $logoPath) { try { $logo = [System.Drawing.Image]::FromFile($logoPath) } catch { $logo = $null } }
# Perro de Kerma corriendo (el mismo bucle que el arranque de KermaOS): hoja de 59 fotogramas
# de 273x221 en 8 columnas, 24 fps. Sin el archivo, sale el logo.
$dog = $null
$dogPath = Join-Path $PSScriptRoot 'perro.png'
if (Test-Path -LiteralPath $dogPath) { try { $dog = New-Object System.Drawing.Bitmap $dogPath } catch { $dog = $null } }
$DogSheet = @{ W = 273; H = 221; Cols = 8; N = 59; Fps = 24 }   # OJO: no llamarlo $DOG (PowerShell no distingue mayusculas)

$C = @{
    Bg = [System.Drawing.ColorTranslator]::FromHtml('#0A0712'); Txt = [System.Drawing.Color]::White
    Mut = [System.Drawing.ColorTranslator]::FromHtml('#CFCED2'); Mut2 = [System.Drawing.ColorTranslator]::FromHtml('#56525F')
    Acc = [System.Drawing.ColorTranslator]::FromHtml('#EA7F2B')
}

# una ventana por monitor; la del principal manda (al cerrarla se cierran todas)
function New-SplashForm($bounds) {
    $f = New-Object System.Windows.Forms.Form
    $f.FormBorderStyle = 'None'
    $f.StartPosition = 'Manual'
    $f.Bounds = $bounds
    $f.TopMost = $true
    $f.ShowInTaskbar = $false
    $f.BackColor = $C.Bg
    $f.Tag = [System.Drawing.Rectangle]::Empty   # recuadro del perro en esta ventana
    [System.Windows.Forms.Form].GetProperty('DoubleBuffered', [Reflection.BindingFlags]'NonPublic,Instance').SetValue($f, $true, $null)
    return $f
}
$form = New-SplashForm ([System.Windows.Forms.Screen]::PrimaryScreen.Bounds)
$others = @([System.Windows.Forms.Screen]::AllScreens | Where-Object { -not $_.Primary } | ForEach-Object { New-SplashForm $_.Bounds })
$forms = @($form) + $others

function Get-Items {
    $items = @()
    foreach ($w in $waits) {
        $ready = Test-Ready $w
        $st = if ($ready) { 'ok' } elseif (Test-Running ([string]$w.proc)) { 'now' } else { 'wait' }
        $items += @{ Name = [string]$w.name; St = $st }
    }
    $dst = if (Get-Win $proc) { 'ok' } elseif ($script:state -ne 'waiting') { 'now' } else { 'wait' }
    $items += @{ Name = 'Dealer App'; St = $dst }
    return $items
}
$script:items = Get-Items

$paint = {
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $W = $s.ClientSize.Width; $H = $s.ClientSize.Height
    $k = $H / 540.0
    $ready = ($script:state -eq 'ready' -or $script:state -eq 'done')
    $fTitle = New-Object System.Drawing.Font($famTitle, [float](30 * $k), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $fSub   = New-Object System.Drawing.Font($famText, [float](16 * $k), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $fRow   = New-Object System.Drawing.Font($famText, [float](16 * $k), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $fSmall = New-Object System.Drawing.Font($famText, [float](13 * $k), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $center = New-Object System.Drawing.StringFormat; $center.Alignment = 'Center'
    $title = if ($ready) { 'TABLE READY' } else { 'PREPARING THE TABLE' }
    $sub   = if ($ready) { 'You can log in to the Dealer App now.' } else { "Please don't touch anything. This takes about a minute and a half." }
    $showDog = ($dog -and -not $ready)
    $logoH = if ($showDog) { 110 * $k } else { 46 * $k }
    $rowH = 22 * $k; $rowGap = 12 * $k
    $listH = if ($ready) { 0 } else { $script:items.Count * $rowH + ($script:items.Count - 1) * $rowGap + 36 * $k }
    $gapTop = if ($showDog) { 28 * $k } else { 44 * $k }
    $total = $logoH + $gapTop + 38 * $k + 10 * $k + 22 * $k + $listH
    $y = ($H - $total) / 2
    if ($showDog) {
        $i = [int][Math]::Floor(((Get-Date) - $start).TotalSeconds * $DogSheet.Fps) % $DogSheet.N
        $src = New-Object System.Drawing.Rectangle (($i % $DogSheet.Cols) * $DogSheet.W), ([Math]::Floor($i / $DogSheet.Cols) * $DogSheet.H), $DogSheet.W, $DogSheet.H
        $dw = [int]($DogSheet.W * ($logoH / $DogSheet.H))
        $s.Tag = New-Object System.Drawing.Rectangle ([int](($W - $dw) / 2)), ([int]$y), $dw, ([int]$logoH)
        $g.InterpolationMode = 'HighQualityBicubic'
        $g.DrawImage($dog, $s.Tag, $src, [System.Drawing.GraphicsUnit]::Pixel)
    } elseif ($logo) {
        $lw = $logo.Width * ($logoH / $logo.Height)
        $g.DrawImage($logo, [float](($W - $lw) / 2), [float]$y, [float]$lw, [float]$logoH)
    }
    $y += $logoH + $gapTop
    $tb = New-Object System.Drawing.SolidBrush ($(if ($ready) { $C.Acc } else { $C.Txt }))
    $g.DrawString($title, $fTitle, $tb, [System.Drawing.RectangleF]::new(0, [float]$y, [float]$W, [float](40 * $k)), $center)
    $y += 38 * $k + 10 * $k
    $mb = New-Object System.Drawing.SolidBrush $C.Mut
    $g.DrawString($sub, $fSub, $mb, [System.Drawing.RectangleF]::new(0, [float]$y, [float]$W, [float](24 * $k)), $center)
    $y += 22 * $k + 36 * $k
    if (-not $ready) {
        $lw = 300 * $k; $x0 = ($W - $lw) / 2; $d = 10 * $k
        foreach ($it in $script:items) {
            $col = switch ($it.St) { 'ok' { $C.Mut } 'now' { $C.Txt } default { $C.Mut2 } }
            $cy = $y + ($rowH - $d) / 2
            if ($it.St -eq 'ok') { $g.FillEllipse((New-Object System.Drawing.SolidBrush $C.Mut), [float]$x0, [float]$cy, [float]$d, [float]$d) }
            elseif ($it.St -eq 'now') { $a = if ($script:pulse) { 255 } else { 70 }; $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($a, $C.Acc))), [float]$x0, [float]$cy, [float]$d, [float]$d) }
            else { $g.DrawEllipse((New-Object System.Drawing.Pen($C.Mut2, [float](1.5 * $k))), [float]$x0, [float]$cy, [float]$d, [float]$d) }
            $g.DrawString($it.Name, $fRow, (New-Object System.Drawing.SolidBrush $col), [float]($x0 + 22 * $k), [float]($y))
            $right = switch ($it.St) { 'ok' { 'ready' } 'now' { 'starting...' } default { '' } }
            if ($right) {
                $sz = $g.MeasureString($right, $fSmall)
                $g.DrawString($right, $fSmall, (New-Object System.Drawing.SolidBrush $C.Mut2), [float]($x0 + $lw - $sz.Width), [float]($y + 2 * $k))
            }
            $y += $rowH + $rowGap
        }
    }
    $foot = (@([string]$cfg.label, [string]$cfg.host) | Where-Object { $_ }) -join ' - '
    if ($foot) { $g.DrawString($foot, $fSmall, (New-Object System.Drawing.SolidBrush $C.Mut2), [System.Drawing.RectangleF]::new(0, [float]($H - 40 * $k), [float]$W, [float](20 * $k)), $center) }
}
foreach ($f in $forms) { $f.add_Paint($paint); $f.add_DoubleClick({ $form.Close() }) }

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500
$timer.add_Tick({
    try {
        $el = ((Get-Date) - $start).TotalSeconds
        $script:pulse = -not $script:pulse
        if ($el -ge $maxSec) { $script:state = 'done'; $form.Close(); return }
        switch ($script:state) {
            'waiting' {
                $script:items = Get-Items
                $allOk = -not ($script:items | Select-Object -First ($script:items.Count - 1) | Where-Object { $_.St -ne 'ok' })
                if ($allOk -or $el -ge $timeout) {
                    $script:state = 'launching'; $script:launchedAt = Get-Date
                    Start-Dealer
                    $script:items = Get-Items
                }
            }
            'launching' {
                $script:items = Get-Items
                $dw = Get-Win $proc
                $since = ((Get-Date) - $script:launchedAt).TotalSeconds
                if ($dw) { [void][KS.W]::ShowWindow($dw.MainWindowHandle, 3) }
                if (($dw -and $since -ge 2) -or $since -ge 120) { $script:state = 'ready'; $script:readyAt = Get-Date }
            }
            'ready' {
                if (((Get-Date) - $script:readyAt).TotalSeconds -ge $readySec) { $script:state = 'done'; $form.Close(); return }
            }
        }
        foreach ($f in $forms) { $f.Invalidate() }
    } catch { $script:state = 'done'; $form.Close() }
})
# animacion del perro: solo se repinta su recuadro
$anim = New-Object System.Windows.Forms.Timer
$anim.Interval = 42
$anim.add_Tick({ if ($dog -and ($script:state -eq 'waiting' -or $script:state -eq 'launching')) { foreach ($f in $forms) { if (-not $f.Tag.IsEmpty) { $f.Invalidate($f.Tag) } } } })
$form.add_Shown({
    foreach ($f in $others) { try { $f.Show() } catch { } }
    $form.Activate()
    $timer.Start()
    $anim.Start()
})

try {
    [System.Windows.Forms.Application]::Run($form)
} finally {
    try { $timer.Stop(); $anim.Stop() } catch { }
    foreach ($f in $forms) { try { $f.Hide() } catch { } }
    # lo primero: la Dealer App (nada de lo que hay detras puede impedirlo)
    try { Complete-Dealer } catch { }
    foreach ($f in $others) { try { $f.Close(); $f.Dispose() } catch { } }
    try { if ($logo) { $logo.Dispose() }; if ($dog) { $dog.Dispose() } } catch { }
}
$pfc.Dispose()
