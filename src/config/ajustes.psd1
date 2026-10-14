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

    # Fondo de pantalla: una plantilla (assets\wallpaper\base.jpg) para todos.
    # Tags: texto y color de la tarjeta, por juego del inventario (Game) y,
    # si no tiene, por perfil (Supervisor, MCR, Office). Color en #RRGGBB.
    Wallpaper = @{
        # Aspecto de Windows con el fondo: modo oscuro y este color de enfasis
        # (barras de titulo, botones, seleccion). Vacio = no tocar los colores.
        Accent = '#C8A96E'
        Tags = @{
            'blackjack'           = @{ Text = 'Blackjack';           Color = '#C8A96E' }
            'blackjack-unlimited' = @{ Text = 'Blackjack Unlimited'; Color = '#C8A96E' }
            'roulette'            = @{ Text = 'Roulette';            Color = '#5FB878' }
            'craps'               = @{ Text = 'Craps';               Color = '#E05555' }
            'Supervisor'          = @{ Text = 'Supervisor';          Color = '#8A88A0' }
            'MCR'                 = @{ Text = 'Control room';        Color = '#4FA3E0' }
            'Office'              = @{ Text = 'Office';              Color = '#968CC8' }
        }
    }

    # Kerma Remote en las mesas (Remote = $true en el perfil): ordenes desde Companion.
    # Por la red solo llega el NOMBRE de la orden; el texto que se pega en la Dealer App
    # sale de aqui, segun el juego. Nada de ordenes de resultado ni del dealer (dados,
    # numeros, SUBMIT, CLEAR, SIGN, escaneo, BURN, SHUFFLE): el lint las rechaza.
    # Allow: IPs o rangos que pueden mandar (ademas hace falta la clave, remote.key).
    Remote = @{
        Port          = 10010
        Allow         = @('192.168.0.0/22')
        TargetProcess = 'dealer-control'
        Commands = @{
            'craps'               = @{ atem_auto = '{ATEM_AUTO}'; pause = '{PAUSE}'; resume = '{RESUME}'; timer_start = '{TIMER_START}'; close_betting = '{CLOSE_BETTING}'; refresh_table = '{REFRESH_TABLE}' }
            'roulette'            = @{ atem_auto = '{ATEM_AUTO}'; make_cut = '{MAKE_CUT}'; pause = '{PAUSE}'; resume = '{RESUME}'; start_betting = '{START_BETTING}'; close_betting = '{CLOSE_BETTING}'; kickstart_round = '{KICKSTART_ROUND}' }
            'blackjack'           = @{ pause = '{PAUSE}'; resume = '{RESUME}'; start_betting = '{START_BETTING}'; kickstart_round = '{KICKSTART_ROUND}' }
            'blackjack-unlimited' = @{ pause = '{PAUSE}'; resume = '{RESUME}'; start_betting = '{START_BETTING}'; kickstart_round = '{KICKSTART_ROUND}' }
        }
    }

    # Tema de OBS: Id debe ser EXACTAMENTE el id de @OBSThemeMeta en assets\obs\themes\<ThemeFile>
    Obs = @{ ThemeFile = 'Kerma.ovt'; ThemeId = 'com.kerma.Yami.Kerma' }
}
