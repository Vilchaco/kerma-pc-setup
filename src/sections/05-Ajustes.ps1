# =====================================================================
#  AJUSTES DEL PC: energia, USB, notificaciones, barra de tareas y red
# =====================================================================

# Adaptadores con cable: encendido por red, nunca apagados para ahorrar,
# sin Ethernet de bajo consumo. Las propiedades avanzadas van con
# -NoRestart (se aplican al reiniciar) para no cortar la red ahora.
function Invoke-NetworkTuning {
    $done = @()
    # sin el ATEM Mini por USB ni adaptadores virtuales: son aparatos, no la red del PC
    $nics = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.MediaType -eq '802.3' -and $_.InterfaceDescription -notmatch 'Blackmagic|ATEM|Virtual|Hyper-V|VMware|VirtualBox|TAP-|Bluetooth' })
    foreach ($n in $nics) {
        try { Set-NetAdapterPowerManagement -Name $n.Name -WakeOnMagicPacket Enabled -ErrorAction Stop } catch { }
        try { Set-NetAdapterPowerManagement -Name $n.Name -AllowComputerToTurnOffDevice Disabled -ErrorAction Stop } catch { }
        $props = @{ '*WakeOnMagicPacket' = '1'; '*ModernStandbyWoLMagicPacket' = '1'; '*EEE' = '0'; 'EnableGreenEthernet' = '0' }
        foreach ($kw in $props.Keys) {
            if (Get-NetAdapterAdvancedProperty -Name $n.Name -RegistryKeyword $kw -ErrorAction SilentlyContinue) {
                try { Set-NetAdapterAdvancedProperty -Name $n.Name -RegistryKeyword $kw -RegistryValue $props[$kw] -NoRestart -ErrorAction Stop } catch { }
            }
        }
        $done += "$($n.Name) (MAC $($n.MacAddress))"
    }
    try {
        # inicio rapido apagado: el encendido por red funciona desde apagado
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0 -Type DWord
    } catch { }
    try {
        Get-NetConnectionProfile -ErrorAction Stop | Where-Object { $_.NetworkCategory -eq 'Public' } |
            ForEach-Object { Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private -ErrorAction Stop }
    } catch { }
    if ($done.Count) {
        Write-Ok ((L 'Network: wake-on-LAN on, power saving off for {0}.' 'Red: encendido por red activado y ahorro de energía quitado en {0}.') -f ($done -join ', '))
        Write-Note (L '  Wake-on-LAN must also be enabled in the BIOS (see the README).' '  El encendido por red también hay que activarlo en la BIOS (ver el README).')
        Add-Change ((L 'Tuning: wake-on-LAN on ({0})' 'Ajustes: encendido por red ({0})') -f ($done -join ', '))
    } else {
        Write-Skip (L 'Network: no wired adapter found.' 'Red: no hay adaptador con cable.')
    }
}

function Invoke-PcTuning($pc) {
    Write-Section (L 'PC SETTINGS  (power, USB, notifications, taskbar, network)' 'AJUSTES DEL PC  (energía, USB, notificaciones, barra de tareas, red)')
    Write-Host (L '  - Screen never turns off, the PC never sleeps or hibernates' '  - La pantalla nunca se apaga y el PC no se suspende ni hiberna')
    Write-Host (L '  - USB devices are never suspended (avoids Stream Deck / Scarlett dropouts)' '  - Los USB nunca se suspenden (evita cortes de la Stream Deck y la Scarlett)')
    Write-Host (L '  - Windows notifications and the screen saver are turned off' '  - Sin notificaciones de Windows ni salvapantallas')
    Write-Host (L '  - Taskbar: no search box, Task view, Widgets or Resume' '  - Barra de tareas sin búsqueda, Vista de tareas, Widgets ni Reanudar')
    Write-Host (L '  - Wired network: wake-on-LAN on, never powered off, no energy-efficient Ethernet' '  - Red con cable: encendido por red, nunca se apaga, sin Ethernet de bajo consumo')
    Write-Host ''
    if (-not (Ask-YesNo (L '  Apply these settings?' '  ¿Aplicar estos ajustes?') ([bool]$Prof.Tuning))) { Write-Skip (L 'PC settings left unchanged.' 'Ajustes del PC sin cambios.'); return }

    $sub = '2a737441-1930-4402-8d77-b2bebba308a3'   # ajustes USB
    $sel = '48e6b7a6-50f5-4782-a5d4-53bb50f7e206'   # suspension selectiva USB
    $bad = 0
    foreach ($c in @(@('/change', 'monitor-timeout-ac', '0'), @('/change', 'standby-timeout-ac', '0'), @('/change', 'hibernate-timeout-ac', '0'), @('/hibernate', 'off'))) {
        $r = Invoke-Native 'powercfg.exe' $c
        if ($r.ExitCode -ne 0) { $bad++; Write-Warn "powercfg $($c -join ' '): $($r.Text)" }
    }
    # la suspension selectiva USB no existe en todos los PCs / planes de energia
    Invoke-Native 'powercfg.exe' @('/attributes', $sub, $sel, '-ATTRIB_HIDE') | Out-Null
    $usb = Invoke-Native 'powercfg.exe' @('/setacvalueindex', 'SCHEME_CURRENT', $sub, $sel, '0')
    $usbText = if ($usb.ExitCode -eq 0) { L 'USB never suspended' 'USB nunca suspendidos' } else { L 'USB suspend setting not present on this PC' 'este PC no tiene el ajuste de suspensión USB' }
    Invoke-Native 'powercfg.exe' @('/setactive', 'SCHEME_CURRENT') | Out-Null
    if ($bad -eq 0) {
        Write-Ok ((L 'Power: screen always on, no sleep / hibernation. {0}.' 'Energía: pantalla siempre encendida, sin suspensión ni hibernación. {0}.') -f $usbText)
        Add-Change ((L 'Tuning: screen always on, no sleep. {0}' 'Ajustes: pantalla siempre encendida, sin suspensión. {0}') -f $usbText)
    }

    # Ajustes del usuario (HKCU = la cuenta con la que corre esta ventana)
    try {
        $pn = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'
        Initialize-RegistryKey $pn
        Set-ItemProperty -Path $pn -Name ToastEnabled -Value 0 -Type DWord
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name ScreenSaveActive -Value '0' -Type String
        Write-Ok ((L "Notifications and screen saver off for user '{0}'." "Notificaciones y salvapantallas quitados para '{0}'.") -f $env:USERNAME)
        Add-Change ((L 'Tuning: notifications + screen saver off ({0})' 'Ajustes: sin notificaciones ni salvapantallas ({0})') -f $env:USERNAME)
    } catch { Write-Warn ((L 'Notifications / screen saver: {0}' 'Notificaciones / salvapantallas: {0}') -f $_.Exception.Message) }

    # Barra de tareas: busqueda oculta; Vista de tareas, Widgets y Reanudar desactivados
    $tb = @()
    try {
        $sr = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
        Initialize-RegistryKey $sr
        Set-ItemProperty -Path $sr -Name SearchboxTaskbarMode -Value 0 -Type DWord
        $tb += (L 'search hidden' 'búsqueda oculta')
    } catch { Write-Warn ((L 'Taskbar search: {0}' 'Búsqueda de la barra: {0}') -f $_.Exception.Message) }
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    try { Set-ItemProperty -Path $adv -Name ShowTaskViewButton -Value 0 -Type DWord; $tb += (L 'Task view off' 'sin Vista de tareas') }
    catch { Write-Warn ((L 'Task view: {0}' 'Vista de tareas: {0}') -f $_.Exception.Message) }
    # Windows 11 reciente bloquea TaskbarDa: Widgets tambien se quita por directiva
    try { Set-ItemProperty -Path $adv -Name TaskbarDa -Value 0 -Type DWord -ErrorAction Stop } catch { }
    try {
        $dsh = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
        Initialize-RegistryKey $dsh
        Set-ItemProperty -Path $dsh -Name AllowNewsAndInterests -Value 0 -Type DWord
        $tb += (L 'Widgets off' 'sin Widgets')
    } catch { Write-Warn "Widgets: $($_.Exception.Message)" }
    try {
        $res = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'
        Initialize-RegistryKey $res
        Set-ItemProperty -Path $res -Name IsResumeAllowed -Value 0 -Type DWord
        $tb += (L 'Resume off' 'sin Reanudar')
    } catch { Write-Warn ((L 'Resume: {0}' 'Reanudar: {0}') -f $_.Exception.Message) }
    if ($tb.Count) {
        Write-Ok ((L 'Taskbar: {0}.' 'Barra de tareas: {0}.') -f ($tb -join ', '))
        Add-Change ((L 'Tuning: taskbar {0}' 'Ajustes: barra de tareas {0}') -f ($tb -join ', '))
        # reiniciar el Explorador para ver ya la barra nueva (vuelve solo)
        if (Test-SameUserAsConsole) { Get-Process -Name 'explorer' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
    }
    Invoke-NetworkTuning

    if (-not (Test-SameUserAsConsole)) {
        Write-Warn ((L "The PC is logged on as '{0}' but this window runs as '{1}'. User settings were changed for '{1}' only." "El PC tiene abierta la sesión de '{0}', pero esta ventana corre como '{1}'. Los ajustes de usuario solo se cambiaron para '{1}'.") -f (Get-ConsoleUser), $env:USERNAME)
        Write-Note (L '  Run the script from the table account itself to apply them there.' '  Pasa el script desde la cuenta de la mesa para aplicarlos allí.')
    }
}
