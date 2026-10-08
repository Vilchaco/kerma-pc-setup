# =====================================================================
#  Kerma PC Setup - PERFILES: que se hace en cada tipo de PC
# ---------------------------------------------------------------------
#  En modo Automatico estos valores se aplican sin preguntar. En modo
#  Manual son la opcion que se ofrece por defecto en cada pregunta.
#
#  Type           Table / Staff / Office (como lo agrupa el panel)
#  Login          NoPassword  = sin contrasena + inicio automatico
#                 Keep        = no tocar el inicio de sesion
#  WindowsUpdate  Manual / Disabled / Automatic / Keep
#  Tuning         pantalla siempre encendida, sin suspension, USB, barra
#                 de tareas, notificaciones, red con encendido remoto
#  Remove*        quitar apps preinstaladas / Microsoft 365 / OneDrive
#  Programs       claves de config\programas.psd1, en orden de instalacion
#  RustDesk       Client / Master / None
#  Autostart      apps que arrancan al iniciar sesion (Apps de programas.psd1).
#                 Las mesas con Scanner = $true en el inventario anaden el scanner.
# =====================================================================
@{
    Table = @{
        Name = @{ es = 'Mesa de juego'; en = 'Game table' }
        Type = 'Table'
        Time = $true; Rename = $true; Login = 'NoPassword'; WindowsUpdate = 'Manual'; StaticIP = $true
        Tuning = $true; RemoveApps = $true; RemoveOffice = $true; RemoveOneDrive = $true
        Programs = @('Chrome', 'RustDesk', 'StreamDeck', 'HdmiMirror', 'OBS', 'AtkAudio')
        RustDesk = 'Client'
        Audio = $true; ProgramSettings = $true
        Autostart = @('StreamDeck', 'DealerApp', 'HdmiMirror', 'OBS')
        Wallpaper = $true; Panel = $true
    }
    Supervisor = @{
        Name = @{ es = 'Supervisor'; en = 'Supervisor' }
        Type = 'Staff'
        Time = $true; Rename = $true; Login = 'Keep'; WindowsUpdate = 'Keep'; StaticIP = $true
        Tuning = $false; RemoveApps = $true; RemoveOffice = $true; RemoveOneDrive = $true
        Programs = @('Chrome', 'RustDesk')
        RustDesk = 'Master'
        Audio = $true; ProgramSettings = $false
        Autostart = @()
        Wallpaper = $true; Panel = $true
    }
    MCR = @{
        Name = @{ es = 'Master Control Room'; en = 'Master Control Room' }
        Type = 'Staff'
        Time = $true; Rename = $true; Login = 'Keep'; WindowsUpdate = 'Keep'; StaticIP = $true
        Tuning = $false; RemoveApps = $true; RemoveOffice = $true; RemoveOneDrive = $true
        Programs = @('Chrome')
        RustDesk = 'None'
        Audio = $true; ProgramSettings = $false
        Autostart = @()
        Wallpaper = $true; Panel = $true
    }
    Office = @{
        Name = @{ es = 'Oficina'; en = 'Office' }
        Type = 'Office'
        Time = $true; Rename = $true; Login = 'NoPassword'; WindowsUpdate = 'Manual'; StaticIP = $true
        Tuning = $true; RemoveApps = $true; RemoveOffice = $true; RemoveOneDrive = $true
        Programs = @('Chrome', 'RustDesk')
        RustDesk = 'Client'
        Audio = $true; ProgramSettings = $false
        Autostart = @('Cameras')
        Wallpaper = $true; Panel = $true
    }
}
