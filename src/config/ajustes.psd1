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

    # Colores del Brandbook Kerma Games 2026 (pag. 26): acento #EA7F2B y sus tonos.
    # Fondo de pantalla: una plantilla (assets\wallpaper\base.jpg) para todos.
    # Tags: texto y color de la tarjeta, por juego del inventario (Game) y,
    # si no tiene, por perfil (Supervisor, MCR, Office). Color en #RRGGBB.
    Wallpaper = @{
        # Aspecto de Windows con el fondo: modo oscuro y este color de enfasis
        # (barras de titulo, botones, seleccion). Vacio = no tocar los colores.
        Accent = '#EA7F2B'
        Tags = @{
            'blackjack'           = @{ Text = 'Blackjack';           Color = '#EA7F2B' }
            'blackjack-unlimited' = @{ Text = 'Blackjack Unlimited'; Color = '#FEE396' }
            'roulette'            = @{ Text = 'Roulette';            Color = '#FFDFAC' }
            'craps'               = @{ Text = 'Craps';               Color = '#EE9956' }
            'Supervisor'          = @{ Text = 'Supervisor';          Color = '#CFCED2' }
            'MCR'                 = @{ Text = 'Control room';        Color = '#CFCED2' }
            'Office'              = @{ Text = 'Office';              Color = '#CFCED2' }
        }
    }

    # Kerma Remote en las mesas (Remote = $true en el perfil): ordenes desde Companion.
    # Por la red solo llega el NOMBRE de la orden; el texto que se pega en la Dealer App
    # sale de aqui, segun el juego. Nada de ordenes de resultado ni del dealer (dados,
    # numeros, SUBMIT, CLEAR, SIGN, escaneo, SHUFFLE): el lint las rechaza. BURN_HAND si
    # puede: es la accion mas comun de los supervisores (Fran, 15-oct).
    # Allow: IPs o rangos que pueden mandar (ademas hace falta la clave, remote.key).
    # Solo el Companion central (servidor 192.168.3.254); para pruebas desde MCR u otro
    # PC, anadir su IP, nunca toda la red.
    Remote = @{
        Port          = 10010
        Allow         = @('192.168.3.254')
        TargetProcess = 'dealer-control'
        Commands = @{
            'craps'               = @{ atem_auto = '{ATEM_AUTO}'; pause = '{PAUSE}'; resume = '{RESUME}'; timer_start = '{TIMER_START}'; close_betting = '{CLOSE_BETTING}'; refresh_table = '{REFRESH_TABLE}' }
            'roulette'            = @{ atem_auto = '{ATEM_AUTO}'; make_cut = '{MAKE_CUT}'; pause = '{PAUSE}'; resume = '{RESUME}'; start_betting = '{START_BETTING}'; close_betting = '{CLOSE_BETTING}'; kickstart_round = '{KICKSTART_ROUND}' }
            'blackjack'           = @{ burn_hand = '{BURN_HAND}'; pause = '{PAUSE}'; resume = '{RESUME}'; start_betting = '{START_BETTING}'; kickstart_round = '{KICKSTART_ROUND}' }
            'blackjack-unlimited' = @{ burn_hand = '{BURN_HAND}'; pause = '{PAUSE}'; resume = '{RESUME}'; start_betting = '{START_BETTING}'; kickstart_round = '{KICKSTART_ROUND}' }
        }
    }

    # Companion Satellite en los PCs de supervisor: conecta su Stream Deck al Companion
    # central (VM de Proxmox, 5.0.3). Alli, en Surfaces, cada Stream Deck nuevo hay que
    # ponerle la pagina 5 (SUPERVISOR) como pagina de inicio.
    Satellite = @{ Server = '192.168.3.254'; Port = 16622 }

    # Tema de OBS: Id debe ser EXACTAMENTE el id de @OBSThemeMeta en assets\obs\themes\<ThemeFile>
    Obs = @{ ThemeFile = 'Kerma.ovt'; ThemeId = 'com.kerma.Yami.Kerma' }
}
