# =====================================================================
#  Kerma PC Setup - INVENTARIO: un bloque por PC
# ---------------------------------------------------------------------
#  Key          clave corta y unica (nombre del fondo de pantalla, del
#               panel y del modo desatendido: -PC BJ01)
#  Group        apartado del menu y del panel
#  Label        nombre que ven los tecnicos
#  Profile      perfil de config\perfiles.psd1 (Table, Supervisor, Office, MCR)
#  Hostname     nombre de equipo estandar
#  Username     usuario de Windows estandar
#  FullName     nombre completo de la cuenta (y del fondo si no hay plantilla)
#  Game         perfil de Stream Deck: assets\streamdeck\<Game>.streamDeckProfile
#  Scanner      $true = la mesa usa el scanner de cartas (se configura su arranque)
#  IP           IP fija de respaldo. La buena vive en el repositorio de David
#               (ver ajustes.psd1, RustDesk.PeersUrl) y gana sobre esta.
#  DavidName    nombre del PC en la lista de David, si no coincide con Key
# =====================================================================
@{
    PCs = @(
        @{ Key = 'RL01';    Group = 'Table PCs';      Label = 'Roulette 01';            Profile = 'Table';      Hostname = 'KG-TBL-RL-01';    Username = 'kg-tbl-rl-01';    FullName = 'Roulette Table 01';      Game = 'roulette';            Scanner = $false; IP = '192.168.0.156' }
        @{ Key = 'BJ01';    Group = 'Table PCs';      Label = 'Blackjack 01';           Profile = 'Table';      Hostname = 'KG-TBL-BJ-01';    Username = 'kg-tbl-bj-01';    FullName = 'Blackjack Table 01';     Game = 'blackjack';           Scanner = $true;  IP = '192.168.0.151' }
        @{ Key = 'BJ02';    Group = 'Table PCs';      Label = 'Blackjack 02';           Profile = 'Table';      Hostname = 'KG-TBL-BJ-02';    Username = 'kg-tbl-bj-02';    FullName = 'Blackjack Table 02';     Game = 'blackjack';           Scanner = $true;  IP = '192.168.0.152' }
        @{ Key = 'BJ03';    Group = 'Table PCs';      Label = 'Blackjack 03';           Profile = 'Table';      Hostname = 'KG-TBL-BJ-03';    Username = 'kg-tbl-bj-03';    FullName = 'Blackjack Table 03';     Game = 'blackjack';           Scanner = $true;  IP = '' }
        @{ Key = 'BJ04';    Group = 'Table PCs';      Label = 'Blackjack 04';           Profile = 'Table';      Hostname = 'KG-TBL-BJ-04';    Username = 'kg-tbl-bj-04';    FullName = 'Blackjack Table 04';     Game = 'blackjack';           Scanner = $true;  IP = '' }
        @{ Key = 'BJUNL01'; Group = 'Table PCs';      Label = 'Blackjack Unlimited 01'; Profile = 'Table';      Hostname = 'KG-TBL-BJUNL-01'; Username = 'kg-tbl-bjunl-01'; FullName = 'Blackjack Unlimited 01'; Game = 'blackjack-unlimited'; Scanner = $true;  IP = '192.168.0.155'; DavidName = 'BJ UNL 01' }
        @{ Key = 'CR01';    Group = 'Table PCs';      Label = 'Craps 01';               Profile = 'Table';      Hostname = 'KG-TBL-CR-01';    Username = 'kg-tbl-cr-01';    FullName = 'Craps Table 01';         Game = 'craps';               Scanner = $false; IP = '192.168.1.86';  DavidName = 'CRAPS 01' }
        @{ Key = 'SUP01';   Group = 'Supervisor PCs'; Label = 'Supervisor 01';          Profile = 'Supervisor'; Hostname = 'KG-SUP-01';       Username = 'kg-sup-01';       FullName = 'Supervisor 01';          Game = '';                    Scanner = $false; IP = '' }
        @{ Key = 'SUP02';   Group = 'Supervisor PCs'; Label = 'Supervisor 02';          Profile = 'Supervisor'; Hostname = 'KG-SUP-02';       Username = 'kg-sup-02';       FullName = 'Supervisor 02';          Game = '';                    Scanner = $false; IP = '' }
        @{ Key = 'MCR';     Group = 'Control room';   Label = 'Master Control Room';    Profile = 'MCR';        Hostname = 'KG-MCR-01';       Username = 'kg-mcr-01';       FullName = 'Master Control Room';    Game = '';                    Scanner = $false; IP = '192.168.1.79' }
        @{ Key = 'HECTOR';  Group = 'Office PCs';     Label = 'Hector office PC';       Profile = 'Office';     Hostname = 'KG-OFC-HECTOR';   Username = 'kg-ofc-hector';   FullName = 'Hector Office PC';       Game = '';                    Scanner = $false; IP = '' }
    )
}
