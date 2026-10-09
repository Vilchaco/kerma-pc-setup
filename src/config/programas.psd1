# =====================================================================
#  Kerma PC Setup - PROGRAMAS: que se instala, que arranca y que se quita
# =====================================================================
@{
    # -----------------------------------------------------------------
    #  Packages: programas que el script instala (el orden lo da el perfil)
    #  Source 'winget' : Id = paquete de winget (winget search <nombre>)
    #  Source 'github' : Repo = owner/name de un repositorio PUBLICO,
    #                    Asset = regex del archivo de la release. .msi =
    #                    instalacion silenciosa; .zip = se extrae en
    #                    InstallTo (y se actualiza si hay version nueva).
    #  Check           : archivo que existe una vez instalado
    #  Override        : (winget) argumentos del instalador en lugar de los
    #                    del paquete, si los suyos no son del todo silenciosos
    #  Restart         : $true = pide reiniciar al final si se instala
    # -----------------------------------------------------------------
    Packages = @{
        Chrome     = @{ Name = 'Google Chrome'; Source = 'winget'; Id = 'Google.Chrome';        Check = 'C:\Program Files\Google\Chrome\Application\chrome.exe' }
        RustDesk   = @{ Name = 'RustDesk';      Source = 'github'; Repo = 'rustdesk/rustdesk';  Asset = '^rustdesk-[0-9.]+-x86_64\.msi$';  Check = 'C:\Program Files\RustDesk\rustdesk.exe' }
        StreamDeck = @{ Name = 'Stream Deck';   Source = 'winget'; Id = 'Elgato.StreamDeck';    Check = 'C:\Program Files\Elgato\StreamDeck\StreamDeck.exe' }
        # HDMI Mirror guarda hdmimirror.config.json junto a su exe: la carpeta debe ser escribible
        HdmiMirror = @{ Name = 'HDMI Mirror';   Source = 'github'; Repo = 'Vilchaco/kerma-hdmi-mirror'; Asset = '^HdmiMirror-v[0-9.]+\.zip$'
                        InstallTo = 'C:\Kerma'; Check = 'C:\Kerma\HdmiMirror\HdmiMirror.exe'; Process = 'HdmiMirror'; UserWritable = 'C:\Kerma\HdmiMirror' }
        OBS        = @{ Name = 'OBS Studio';    Source = 'winget'; Id = 'OBSProject.OBSStudio'; Check = 'C:\Program Files\obs-studio\bin\64bit\obs64.exe' }
        # atkAudio: VST3 dentro de OBS (gratis, AGPL). El zip de la release trae un zip por
        # plataforma; el portable de Windows se extrae en la carpeta de OBS.
        AtkAudio   = @{ Name = 'atkAudio (VST3 in OBS)'; Source = 'github'; Repo = 'atkAudio/PluginForObsRelease'; Asset = '^atkAudio-PluginForObs\.zip$'
                        Inner = '^portable-atkaudio-pluginforobs-[0-9.]+-Windows\.zip$'; InstallTo = 'C:\Program Files\obs-studio'
                        Check = 'C:\Program Files\obs-studio\obs-plugins\64bit\atkaudio-pluginforobs.dll'; Process = 'obs64'; Requires = 'OBS' }
        Deskflow   = @{ Name = 'Deskflow';      Source = 'winget'; Id = 'Deskflow.Deskflow';    Check = 'C:\Program Files\Deskflow\deskflow.exe' }
        # Id sale de ajustes.psd1 (Audio.ScarlettPackageId); se instala si hay una Focusrite conectada.
        # Su paquete de winget solo pasa /silent y el instalador (Inno) pregunta si reiniciar: se
        # sustituye por el modo totalmente silencioso y el script reinicia al final.
        Focusrite  = @{ Name = 'Focusrite Control 2 (Scarlett)'; Source = 'winget'; Id = ''; Check = ''; Override = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'; Restart = $true }
    }

    # -----------------------------------------------------------------
    #  Apps: arranque al iniciar sesion (una tarea programada por app)
    #  Path       sugerencia; si esta vacia el script pide el programa
    #             (y la recuerda en app-paths.json)
    #  SelfStarts el programa ya arranca solo: no se crea tarea
    #             (Stream Deck NO: su propio inicio no es fiable en un PC
    #             nuevo y tiene que estar abierta para recibir los botones)
    #  Replaces   app antigua cuya tarea se elimina
    #  ShowAfter  segundos tras abrirla para abrirla otra vez: las apps que
    #             arrancan escondidas en la bandeja (Stream Deck) muestran
    #             asi su ventana
    #  PreLaunch  lineas del .bat antes de abrir la app. Van LITERALES:
    #             %APPDATA% lo resuelve cmd del usuario al iniciar sesion.
    # -----------------------------------------------------------------
    Apps = @{
        Scanner    = @{ Name = 'Card Scanner'; Id = '01_scanner';    Path = '';                                                 Delay = 10; Maximize = $false }
        StreamDeck = @{ Name = 'StreamDeck';   Id = '02_streamdeck'; Path = 'C:\Program Files\Elgato\StreamDeck\StreamDeck.exe';  Delay = 15; Maximize = $false; ShowAfter = 20 }
        DealerApp  = @{ Name = 'Dealer App';   Id = '03_dealerapp';  Path = '';                                                 Delay = 30; Maximize = $true }
        HdmiMirror = @{ Name = 'HDMI Mirror';  Id = '04_hdmimirror'; Path = 'C:\Kerma\HdmiMirror\HdmiMirror.exe';               Delay = 45; Maximize = $false; Replaces = 'Mirror App' }
        # OBS: si se cerro mal (fallo, corte de luz, reinicio forzado) deja
        # %APPDATA%\obs-studio\.sentinel\run_* y el siguiente arranque se para en el
        # aviso "Iniciar normalmente / Modo seguro". El autoarranque borra esa marca
        # antes, como hace OBS al cerrarse bien. Abierto a mano, OBS sigue ofreciendo
        # el modo seguro. (--disable-shutdown-check existia hasta OBS 31.) No usar
        # --multi en su lugar: tambien quita el aviso de "OBS ya esta abierto".
        OBS        = @{ Name = 'OBS';          Id = '05_obs';        Path = 'C:\Program Files\obs-studio\bin\64bit\obs64.exe'; Delay = 60; Maximize = $false
                        Args = '--disable-updater'
                        PreLaunch = @('del /q "%APPDATA%\obs-studio\.sentinel\run_*" >nul 2>&1') }
        Cameras    = @{ Name = 'Cameras';      Id = '02_cameras';    Path = '';                                                 Delay = 25; Maximize = $true }
        # Deskflow: ya no se usa (fue una prueba en el PC de Hector)
        Deskflow   = @{ Name = 'Deskflow';     Id = '01_deskflow';   Path = 'C:\Program Files\Deskflow\deskflow.exe';          Delay = 10; Maximize = $false }
    }

    # -----------------------------------------------------------------
    #  Apps preinstaladas de la Tienda que se quitan (* = comodin).
    #  NeverRemove siempre gana. App Installer (= winget) no se quita nunca.
    # -----------------------------------------------------------------
    RemoveApps = @(
        'Microsoft.MicrosoftOfficeHub', 'Microsoft.Office.OneNote', 'Microsoft.OutlookForWindows',
        'microsoft.windowscommunicationsapps', 'MicrosoftTeams', 'MSTeams', 'Microsoft.SkypeApp', 'Microsoft.People',
        'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.GamingApp', 'Microsoft.XboxApp', 'Microsoft.Edge.GameAssist',
        'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingSearch', 'Microsoft.GetHelp', 'Microsoft.Getstarted',
        'Microsoft.WindowsFeedbackHub', 'Microsoft.WindowsMaps', 'Microsoft.ZuneVideo', 'Microsoft.ZuneMusic',
        'Microsoft.YourPhone', 'Microsoft.Todos', 'Microsoft.PowerAutomateDesktop', 'MicrosoftCorporationII.MicrosoftFamily',
        'MicrosoftCorporationII.QuickAssist', 'Microsoft.549981C3F5F10', 'Clipchamp.Clipchamp', 'Microsoft.Windows.DevHome',
        'Microsoft.Copilot', 'Microsoft.Microsoft3DViewer', 'Microsoft.MixedReality.Portal', 'Microsoft.Wallet',
        'king.com.*', 'SpotifyAB.*', 'Disney.*', '*TikTok*', 'Facebook.*', '*Instagram*', 'AmazonVideo.*', '*LinkedIn*', '*Netflix*'
    )
    NeverRemove = @(
        'Microsoft.DesktopAppInstaller', 'Microsoft.WindowsStore', 'Microsoft.StorePurchaseApp', 'Microsoft.WindowsCalculator',
        'Microsoft.Windows.Photos', 'Microsoft.WindowsNotepad', 'Microsoft.Paint', 'Microsoft.ScreenSketch', 'Microsoft.WindowsTerminal',
        'Microsoft.VCLibs.*', 'Microsoft.UI.Xaml.*', 'Microsoft.NET.Native.*', 'Microsoft.WindowsAppRuntime.*', 'Microsoft.SecHealthUI',
        'Microsoft.Windows.ShellExperienceHost', 'Microsoft.Windows.StartMenuExperienceHost', 'Microsoft.XboxGamingOverlay',
        'Microsoft.XboxIdentityProvider', 'Microsoft.Xbox.TCUI', 'Microsoft.MicrosoftStickyNotes', 'Microsoft.WindowsAlarms',
        'Microsoft.WindowsSoundRecorder', 'Microsoft.WindowsCamera'
    )
}
