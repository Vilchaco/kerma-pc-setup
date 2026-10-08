# =====================================================================
#  Kerma PC Setup - AJUSTES generales
# =====================================================================
@{
    # Hora: Monterrey, UTC-6 sin horario de verano desde 2022
    Time = @{
        ZoneId         = 'Central Standard Time (Mexico)'
        FallbackZoneId = 'Central America Standard Time'   # UTC-6 siempre; si los datos de zona de Windows son viejos
        Servers        = @('time.cloudflare.com', 'time.windows.com')
        DailyAt        = '07:00'                           # sincronizacion diaria de respaldo (tambien al encender)
    }

    # Red: valores por defecto de la IP fija (la IP de cada PC va en el inventario
    # o en la lista de David)
    Network = @{ Mask = '255.255.252.0'; Gateway = '192.168.0.10'; DNS1 = '8.8.8.8'; DNS2 = '1.1.1.1' }

    # RustDesk por IP directa (scripts de David en src\rustdesk)
    RustDesk = @{
        Port        = 21118
        AllowedFrom = @('LocalSubnet', '192.168.0.0/22')        # quien puede conectarse: la red de la oficina
        # Lista de equipos de David (columnas Nombre, IP, Puerto). Fuente de las IPs:
        # gana sobre el inventario. Mientras su repositorio sea privado devuelve 404
        # y se usa el inventario.
        PeersUrl    = 'https://raw.githubusercontent.com/restidavid/kerma-rust/main/Equipos.ejemplo.csv'
        ExtraPeers  = @()                                          # @(@{ Nombre = 'PC impresora'; IP = '192.168.1.90' })
    }

    # Audio: Scarlett Solo 3rd Gen -> Focusrite Control 2
    Audio = @{
        ScarlettPackageId         = 'FocusriteAudioEngineeringLtd.FocusriteControl2'
        ScarlettPcTypes           = @()       # tipos donde instalarlo aunque no este conectada
        ScarlettAsDefaultPlayback = $true     # la Scarlett tambien es la salida predeterminada
    }

    # Panel de estado
    Panel = @{ Base = 'https://kermasetup.netlify.app' }

    # Tema de OBS: Id debe ser EXACTAMENTE el id de @OBSThemeMeta en assets\obs\themes\<ThemeFile>
    Obs = @{ ThemeFile = 'Kerma.ovt'; ThemeId = 'com.kerma.Yami.Kerma' }
}
