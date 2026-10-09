# =====================================================================
#  BARRA DE TAREAS: iconos fijos (Taskbar del perfil, Pins de programas.psd1)
#  Windows 11: archivo de diseno (LayoutModification) + directiva
#  "Diseño de Inicio". PinListPlacement=Replace quita Edge, la Tienda y lo
#  que trae Windows de serie. Con TaskbarLocked nadie puede cambiarla.
# =====================================================================

$StartMenuDirs = @(
    (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'),
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs')
)

# Acceso directo de una app: el del propio programa (agrupa bien su ventana
# con el icono fijado), y si no hay, uno propio en el menu Inicio de todos.
function Get-PinShortcut($key, $pin, $shell) {
    $lnks = @(foreach ($d in $StartMenuDirs) { if (Test-Path -LiteralPath $d) { Get-ChildItem -LiteralPath $d -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue } })
    $exe = $pin.Exe
    if ($exe -and (Test-Path -LiteralPath $exe)) {
        foreach ($l in $lnks) {
            try { if ($shell.CreateShortcut($l.FullName).TargetPath -ieq $exe) { return $l.FullName } } catch { }
        }
    }
    if ($pin.Lnk) {
        $hit = $lnks | Where-Object { $_.BaseName -like $pin.Lnk -and $_.BaseName -notmatch 'Uninstall|Desinstalar' } | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    if ($exe -and (Test-Path -LiteralPath $exe)) {
        $dir = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Kerma'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $path = Join-Path $dir "$($pin.Name).lnk"
        $s = $shell.CreateShortcut($path)
        $s.TargetPath = $exe
        $s.WorkingDirectory = Split-Path -Path $exe -Parent
        $s.Save()
        return $path
    }
    return ''
}

function Invoke-TaskbarPins($pc) {
    Write-Section (L 'TASKBAR ICONS' 'ICONOS DE LA BARRA DE TAREAS')
    $keys = @($Prof.Taskbar | Where-Object { $_ })
    $pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
    if ($keys.Count -eq 0) {
        # sin iconos en el perfil: si una version anterior la fijo, se libera
        if ((Get-ItemProperty -Path $pol -ErrorAction SilentlyContinue).StartLayoutFile) {
            Remove-ItemProperty -Path $pol -Name StartLayoutFile, LockedStartLayout -ErrorAction SilentlyContinue
            if (Test-SameUserAsConsole) { Get-Process -Name 'explorer' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
            Write-Ok (L 'Taskbar released: icons can be changed by hand again.' 'Barra de tareas liberada: los iconos se pueden volver a cambiar a mano.')
            Add-Change (L 'Taskbar: released' 'Barra de tareas: liberada')
            return
        }
        Write-Skip (L 'This PC type keeps the taskbar icons as they are.' 'En este tipo de PC los iconos de la barra no se tocan.'); return
    }
    Write-Host ((L '  Only these icons, in this order: {0}' '  Solo estos iconos, en este orden: {0}') -f (($keys | ForEach-Object { $Pins[$_].Name }) -join ', '))
    Write-Host (L '  (Edge, the Store and the rest of the Windows icons are removed)' '  (se quitan Edge, la Tienda y el resto de iconos de Windows)')
    if ($Prof.TaskbarLocked) { Write-Host (L '  Locked: nobody can add or remove icons on this PC.' '  Fija: en este PC nadie puede añadir ni quitar iconos.') }
    Write-Host ''
    if (-not (Ask-YesNo (L '  Set the taskbar icons?' '  ¿Poner los iconos de la barra?') $true)) { Write-Skip (L 'Taskbar icons left as they are.' 'Iconos de la barra sin cambios.'); return }

    $shell = New-Object -ComObject WScript.Shell
    $items = @()
    $names = @()
    $missing = @()
    foreach ($k in $keys) {
        $pin = $Pins[$k]
        if ($pin.AppId) { $items += "        <taskbar:DesktopApp DesktopApplicationID=`"$($pin.AppId)`" />"; $names += $pin.Name; continue }
        $lnk = Get-PinShortcut $k $pin $shell
        if (-not $lnk) { $missing += $pin.Name; continue }
        $items += "        <taskbar:DesktopApp DesktopApplicationLinkPath=`"$([Security.SecurityElement]::Escape($lnk))`" />"
        $names += $pin.Name
    }
    if ($missing.Count) { Write-Note ((L '  Not installed, left out: {0}' '  No están instalados, se quedan fuera: {0}') -f ($missing -join ', ')) }

    $xml = @(
        '<?xml version="1.0" encoding="utf-8"?>'
        '<LayoutModificationTemplate xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" Version="1">'
        '  <CustomTaskbarLayoutCollection PinListPlacement="Replace">'
        '    <defaultlayout:TaskbarLayout>'
        '      <taskbar:TaskbarPinList>'
    ) + $items + @(
        '      </taskbar:TaskbarPinList>'
        '    </defaultlayout:TaskbarLayout>'
        '  </CustomTaskbarLayoutCollection>'
        '</LayoutModificationTemplate>'
    )
    $dir = Initialize-KermaDataDir
    $file = Join-Path $dir 'taskbar.xml'
    Set-Content -LiteralPath $file -Value $xml -Encoding UTF8

    Initialize-RegistryKey $pol
    New-ItemProperty -Path $pol -Name StartLayoutFile -Value $file -PropertyType ExpandString -Force | Out-Null
    New-ItemProperty -Path $pol -Name LockedStartLayout -Value ([int][bool]$Prof.TaskbarLocked) -PropertyType DWord -Force | Out-Null
    # los iconos que el usuario fijo a mano dejan de valer: que no se mezclen
    if (Test-SameUserAsConsole) {
        Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband' -Recurse -Force -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar') -Filter '*.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-Process -Name 'explorer' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    $State.NeedsRestart = $true

    Write-Ok ((L 'Taskbar: {0}{1}. Fully applied after the restart.' 'Barra de tareas: {0}{1}. Queda del todo al reiniciar.') -f ($names -join ', '), $(if ($Prof.TaskbarLocked) { L ' (locked)' ' (fija)' } else { '' }))
    Add-Change ((L 'Taskbar: {0}' 'Barra de tareas: {0}') -f ($names -join ', '))
}
