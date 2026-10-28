# Historial de cambios

Todas las versiones de Kerma PC Setup, de la más reciente a la más antigua. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y la numeración sigue el [versionado semántico](https://semver.org/lang/es/).

## [5.14.0] - 2026-10-28 - Actualizar los programas al repasar un PC

### Añadido
- **Al volver a pasar el script, los programas que ya están instalados se actualizan si hay versión nueva.** Antes solo se actualizaban HDMI Mirror y atkAudio; el resto se daba por bueno si ya estaba instalado.
  - **Stream Deck, OBS y Focusrite Control 2:** winget mira si hay versión nueva; si la hay, cierra el programa y lo actualiza (`antes -> después` en pantalla y en el log). Si está al día, sigue sin tardar.
  - **Companion Satellite:** se compara con la última versión de Bitfocus y se actualiza igual.
  - **HDMI Mirror y atkAudio:** como antes, a la última release de GitHub.
- La lista de programas del principio dice qué se va a buscar: «instalado: buscar actualización» o «instalado (versión fija)».

### Sin cambios a propósito
- **Chrome** se actualiza solo (Google Update).
- **RustDesk** no se actualiza solo: hacerlo corta la conexión de RustDesk y reinstala su servicio. Se actualiza a mano.
- **Alt Denoiser** (v1.0.1) e **iVMS-4200** (v3.14.1.4) son versiones fijas.

## [5.13.0] - 2026-10-28 - Brandbook de Kerma Games 2026

### Cambiado
- **Colores y letra del Brandbook 2026**: fondo #0A0712, superficies #110C1F / #161029, bordes #353041, texto blanco y gris #CFCED2, y acento naranja #EA7F2B (Pantone 158 C) en lugar del dorado. Sora como letra principal y Orbitron en los títulos.
  - **Panel de estado y página de bienvenida.** Los avisos pasan a amarillo (#F4C95D) para no confundirse con el naranja. El verde y el rojo de los estados se quedan: en un panel de vigilancia, rojo significa que algo falla.
  - **Windows:** el color de énfasis pasa a ser el naranja Kerma.
  - **Fondo de pantalla:** la tarjeta usa los colores del brandbook. Por juego: Blackjack naranja, Blackjack Unlimited amarillo, Ruleta crema y Craps naranja claro; supervisores, MCR y oficina en gris.
  - **Tema Kerma de OBS:** mismos colores. El identificador del tema no cambia.
- No cambia ninguna función. En los PCs, el fondo, el color de Windows y el tema de OBS se aplican la próxima vez que se pase el setup.

## [5.12.8] - 2026-10-20 - Favoritos de RustDesk al repetir el setup

### Corregido
- **En el MCR solo aparecía Craps en Favoritos de RustDesk.** Al pasar el setup por segunda vez, el script de Favoritos (de David) no encontraba la línea `view_style` de cada ficha, porque los saltos de línea son de Windows, y añadía otra. Con la clave repetida, RustDesk descartaba esas fichas y solo quedaba la de Craps, que tenía ficha propia por haberte conectado a ella. Ahora se quitan todas las `view_style` y se pone una. Las fichas que se perdieron se vuelven a crear al pasar el setup. Hay que avisar a David para que lo corrija también en su repositorio.

## [5.12.7] - 2026-10-20 - Barra fija en el MCR

### Cambiado
- **El MCR lleva la barra de tareas fija** con Explorador, Chrome, RustDesk e iVMS-4200.
- **La barra fija también quita el buscador, la Vista de tareas, los Widgets y Reanudar**, como en las mesas, aunque el PC no lleve el resto de ajustes de mesa (energía, notificaciones...). Afecta al MCR y a los PCs de oficina. Las notificaciones de Windows se mantienen en el MCR, para los avisos de Telegram.

## [5.12.6] - 2026-10-20 - Barra de tareas en los PCs de oficina

### Cambiado
- **Los PCs de oficina llevan la barra de tareas fija, como las mesas,** pero solo con Explorador, Chrome y RustDesk: sin OBS, Stream Deck, HDMI Mirror ni Focusrite. Se quitan Edge, la Tienda y el resto de iconos de Windows.

## [5.12.5] - 2026-10-20 - Arreglos de la instalación del MCR

### Corregido
- **Chrome no se instaló en el MCR** y el error salía sin código. En PowerShell 5.1 hay que tocar el proceso al lanzarlo para poder leer luego su código de salida; ahora se hace, y el log dice por qué falla winget. Si winget falla con Chrome, el script prueba con el instalador oficial de Google (.msi para empresas).
- **La comprobación final mostraba un error rojo** por un archivo del vigilante que aún no existía (`watchdog.json`). Era inofensivo; ya no sale.

## [5.12.4] - 2026-10-19 - MCR en 192.168.0.101

### Cambiado
- **El PC del MCR pasa a 192.168.0.101** (antes 192.168.1.79), por indicación de David. El script la pone al pasar el setup en ese PC.

## [5.12.3] - 2026-10-19 - Cámaras Hikvision en el MCR

### Añadido
- **iVMS-4200 en el PC del MCR**, para ver y gestionar las cámaras Hikvision de la red. No está en winget: el script descarga la versión oficial 3.14.1.4 de la web de Hikvision y prueba a instalarla en silencio. Si su instalador abre una ventana, hay que terminarla a mano. Se da por instalado cuando aparece en los programas de Windows.
- Nuevo tipo de programa `url` (descarga directa del fabricante) para los que no están en winget ni en GitHub.

## [5.12.2] - 2026-10-19 - RustDesk en el MCR

### Cambiado
- **El PC del MCR (técnicos) lleva RustDesk en modo MASTER**, como los supervisores: lo instala, guarda la contraseña común y pone en Favoritos la lista de equipos para entrar a las mesas. Hasta ahora el MCR no tenía RustDesk.

## [5.12.1] - 2026-10-16 - El vigilante respeta el setup y el modo mantenimiento

### Corregido
- **El vigilante ya no reabre apps mientras corre el setup.** En Blackjack 01 y Blackjack Unlimited 01 volvió a abrir OBS en mitad del setup, que lo había cerrado para copiar su configuración.

### Cambiado
- **Modo mantenimiento en el panel**, con ese nombre, en el detalle de cada PC (apartado "Vigilante de apps y mantenimiento"). Durante 2 horas el vigilante no reabre nada y Telegram no avisa de apps cerradas. La tarjeta del PC lo indica. Solo aparece en los PCs con la 5.12 o posterior.

## [5.12.0] - 2026-10-15 - Vigilante de apps y avisos por Telegram

### Añadido
- **Vigilante de apps en cada PC.** Si una app que arranca con Windows está cerrada (OBS, Dealer App, HDMI Mirror, Stream Deck o Kerma Remote), el informe de cada 5 minutos vuelve a lanzar su tarea de arranque. Se abre igual que al encender: OBS sin el aviso de modo seguro tras un cierre inesperado. Lo hace como mucho 3 veces por hora y app. Desde el panel se puede pausar 2 horas por PC, para mantenimiento. Lo provocó Ruleta 01: OBS se cerró solo y la mesa estuvo sin audio sin que nadie lo supiera.
- **Avisos por Telegram** (y Slack más adelante) desde el panel, las 24 horas, solo cuando algo cambia: una app que debe estar abierta lleva 10 minutos cerrada, el vigilante no consigue abrirla o la ha reabierto, un PC deja de reportar o el reloj se desvía más de 2 s. Se avisa también cuando se arregla.
- En el panel, cada PC muestra su vigilante: si está activo o en pausa, qué ha reabierto en las últimas 24 horas y qué no consigue abrir.

## [5.11.0] - 2026-10-15 - Companion central, Satellite y Burn Hand remoto

### Cambiado
- **Kerma Remote solo acepta órdenes del Companion central** (servidor 192.168.3.254), no de toda la red. Para pruebas desde otro PC hay que añadir su IP en `ajustes.psd1`.
- **Supervisores con Companion Satellite en vez de Companion completo.** Satellite conecta el Stream Deck del supervisor al Companion central (192.168.3.254, puerto 16622) y arranca con Windows. Como no está en winget y su GitHub no trae instaladores, se descarga de la web oficial de Bitfocus. El script le deja puesta la dirección del servidor y el nombre del PC.
- **Supervisores con IP fija:** Supervisor 01 en 192.168.0.200 y Supervisor 02 en 192.168.0.202.

### Añadido
- **Burn Hand desde los Stream Deck de supervisor** en Blackjack y Blackjack Unlimited (`burn_hand`), a petición de Fran. Es la acción más común de los supervisores.

## [5.10.15] - 2026-10-14 - Ruta de la Dealer App comprobada

### Corregido
- **En Blackjack Unlimited 01 la "Dealer App" abría el Card Scanner:** al configurarla se había elegido el .bat del escáner. Ahora cada app tiene un nombre de archivo obligatorio (`dealer-control.exe` para la Dealer App y `Start-Matrix120-Keyboard.bat` para el Card Scanner) y una ruta guardada con otro nombre no se usa. Además, la Dealer App se busca sola en su sitio de siempre (`%LOCALAPPDATA%\Dealer Control\dealer-control.exe`), así que en modo Automático ya no hay que elegirla a mano.

## [5.10.14] - 2026-10-14 - Craps sin HDMI Mirror

### Cambiado
- **Craps 01 no lleva HDMI Mirror:** tiene dos pantallas tipo prompter. Ya no se instala ni se configura, no arranca con Windows, no tiene icono en la barra de tareas y el panel no lo vigila. Si ya tenía la tarea de arranque, el setup la quita.
- **Nuevo campo `Without` en el inventario** para que un PC concreto no lleve algo de su perfil (programas, apps de arranque o iconos), por ejemplo `Without = @('HdmiMirror')`.

## [5.10.13] - 2026-10-14 - En la mesa, solo el perfil de su juego

### Corregido
- **Craps 01 seguía mostrando el diseño viejo del Stream Deck.** El perfil viejo tenía otro nombre y el aparato lo seguía mostrando, aunque el nuevo se había instalado bien. Ahora la app de Stream Deck de la mesa se queda solo con el perfil de su juego: los demás perfiles se quitan, guardando antes una copia en `C:\KermaSetup\backup`, y el aparato vuelve al de la mesa.

## [5.10.12] - 2026-10-14 - IP fija repetida en otro adaptador

### Corregido
- **En Craps 01 no se pudo poner la 192.168.0.150** (*The object already exists*): esa IP ya estaba puesta, fija, en el Wi-Fi, que está desconectado. Ahora, si la IP de la mesa está en otro adaptador desconectado, el script se la quita y lo deja en DHCP antes de ponerla en el cable. Si ese otro adaptador está conectado, no toca nada y lo avisa, porque sería un choque de verdad.

## [5.10.11] - 2026-10-14 - Craps 01 en 192.168.0.150

### Corregido
- **La IP buena de Craps 01 es 192.168.0.150**, no la .160 de la 5.10.10.

## [5.10.10] - 2026-10-14 - Craps 01 a su IP nueva

### Cambiado
- **Craps 01 pasa a 192.168.0.160** (antes 192.168.1.86), según el plan de red: 1.x quedará para el DHCP. Lo aprobó David. El script la pone al pasar el setup en esa mesa; el fondo de pantalla y el panel la muestran ya.

## [5.10.9] - 2026-10-14 - HDMI Mirror inicia el espejo solo

### Cambiado
- **HDMI Mirror con "Iniciar el espejo al abrir la app" siempre marcado** en todas las mesas, haya o no configuración guardada para esa mesa. El arranque solo abre HdmiMirror.exe, y así la app espera a la Dealer App e inicia el espejo sola. El resto de su configuración no se toca.

## [5.10.8] - 2026-10-14 - Perfil de Stream Deck en Ruleta

### Corregido
- **En Ruleta 01 no se cargó el perfil** y la sección acabó con *Cannot find path 'C'*. Si la app tenía un solo perfil con ese nombre y no había "Default Profile", PowerShell devolvía la ruta como texto suelto en vez de como lista, y el script tomaba su primera letra ("C") como carpeta. No se llegó a tocar nada de la app.

## [5.10.7] - 2026-10-14 - El perfil de la mesa pisa el Default Profile

### Cambiado
- **El perfil de la mesa sustituye al "Default Profile" de la app de Stream Deck**, que es el que muestra el aparato si no se elige otro. Así el Stream Deck enseña siempre el de Kerma, sin elegirlo a mano. Las demás copias con el mismo nombre se quitan, y antes se guarda todo en `C:\KermaSetup\backup`. Mientras haya un "Default Profile", el script lo sustituye aunque el perfil de Kerma ya estuviera instalado: así se arregla Blackjack 01.

## [5.10.6] - 2026-10-14 - El Stream Deck sigue mostrando el perfil de Kerma

### Corregido
- **Al sustituir el perfil, el Stream Deck pasaba a mostrar otro** (Blackjack 01). La app de Stream Deck recuerda el perfil elegido por su carpeta, y el script borraba esa carpeta y creaba otra. Ahora el perfil nuevo se escribe dentro de la carpeta del que ya existía, así el aparato lo sigue mostrando. En un PC nuevo se escribe en la del "Default Profile", que es el que muestra el Stream Deck al principio. Antes de tocar nada se guarda una copia en `C:\KermaSetup\backup`.

## [5.10.5] - 2026-10-14 - ENTRAR pulsa Enter

### Cambiado
- **Stream Deck: la tecla ENTRAR del teclado del PIN** (`{SIGN_IN}`) pulsa Enter después de pegar, en los perfiles de Craps, Ruleta, Blackjack y Blackjack Unlimited. Las demás teclas siguen sin Enter. Como el perfil ha cambiado, el setup lo sustituye en las mesas que ya lo tenían.

## [5.10.4] - 2026-10-14 - Perfil de Stream Deck sin preguntar

### Cambiado
- **El perfil de Stream Deck se instala sin que la app pregunte.** El script cierra la app de Stream Deck, copia el perfil directamente en su carpeta de perfiles asociado al Stream Deck de ese PC y la vuelve a abrir. En un PC recién instalado, antes abre la app una vez para que cree su carpeta y reconozca el aparato. Si no se puede (por ejemplo, porque el Stream Deck no está conectado), vuelve al método anterior: la app pregunta si importarlo.

## [5.10.3] - 2026-10-14 - Foco en la Dealer App y perfil de Stream Deck

### Añadido
- **La Dealer App se queda delante al arrancar.** Cuando ya se han abierto las demás apps de la mesa (Stream Deck, HDMI Mirror y OBS, que sale la última), el arranque le da el foco a la Dealer App y la maximiza. Así se puede escribir el PIN sin tocar el ratón, siempre que la propia app deje el cursor en su cuadro.

### Corregido
- **El perfil de Stream Deck no llegaba a la app** (Blackjack 01). El script lo abría con permisos de administrador y la app de Stream Deck del usuario no lo recibía. Ahora se abre como el usuario, a través del Explorador. Además, el script comprueba que la app lo ha guardado; si en 60 s no aparece, lo avisa y lo intenta de nuevo en la siguiente pasada.

## [5.10.2] - 2026-10-14 - La Dealer App arranca maximizada

### Corregido
- **Dealer App maximizada al arrancar.** Ya se abría con la opción de maximizar de Windows, pero la Dealer App la ignora y recuerda su propio tamaño. Ahora, después de abrirla, el arranque espera a que salga su ventana y la maximiza; a los 5 s lo repite, por si la app se redimensiona al cargar. Vale para cualquier app con "Abrir maximizada" (en las mesas, la Dealer App).

## [5.10.1] - 2026-10-14 - Clave de Kerma Remote en el panel

### Cambiado
- **Una sola clave de Kerma Remote, guardada en el panel de estado** (en Netlify, nunca en el repositorio). El setup la recoge sola, con el PIN o con la clave de escritura del PC si ya está registrado, así que ya no hay que escribirla en cada mesa. Todas las mesas acaban con la misma, también las que tenían otra de las pruebas. Solo si el panel no responde se pide a mano.
- **Botón "Clave Kerma Remote" en el panel** (con el PIN), para configurar Companion: la muestra o la copia.

## [5.10.0] - 2026-10-14 - Stream Deck definitivos y Kerma Remote

### Añadido
- **Perfiles de Stream Deck definitivos** de Craps, Ruleta, Blackjack y Blackjack Unlimited (el mismo que Blackjack), cerrados con los supervisores. Pegan el comando sin Enter y llevan EMERGENCY, PIT MANAGER y SIGN (teclado del PIN) en la última columna.
- **Kerma Remote en las mesas.** Recibe en el puerto 10010 las órdenes de los Stream Deck de los supervisores (Companion) y las pega en la Dealer App: pausar, reanudar, abrir y cerrar apuestas, recuperar la ronda y, en Craps y Ruleta, las cámaras. Solo acepta las órdenes de la lista de su juego, desde la red del casino y con la clave común. En modo Automático la clave se pide al empezar y solo se guarda en el PC. Programa: Kerma Remote v0.1.2.
- El panel de estado muestra **Kerma Remote** entre las apps de cada mesa: en verde si está escuchando, en rojo si no.
- **Bitfocus Companion en los PCs de supervisor.** Se instala y arranca con Windows, para los Stream Deck de supervisor.

### Cambiado
- **El perfil de Stream Deck se sustituye si ha cambiado.** Antes, si la app ya tenía un perfil con ese nombre, no se tocaba, y las mesas se quedaban con el viejo. Ahora se compara su huella: si es otro, se cierra la app, se guarda una copia del anterior en `C:\KermaSetup\backup` y se importa el nuevo. Si es el mismo, no se vuelve a importar.
- Blackjack 04 tiene su IP en el inventario (192.168.0.154).

## [5.9.2] - 2026-10-10 - Usuarios con espacios en el nombre de su carpeta

### Corregido
- **RustDesk en Blackjack Unlimited 01.** La configuración de RustDesk se aplicaba bien, pero la sección acababa con el error *An object at the specified path C:\Users\BJUNL~1 does not exist*. Cuando el nombre de la carpeta del usuario tiene espacios ("BJ UNL"), Windows da su carpeta temporal en formato corto, y PowerShell no podía borrar los archivos temporales con esa ruta. Ahora el script usa su propia carpeta temporal (`C:\KermaSetup\tmp`) y los borra sin pasar por PowerShell.

## [5.9.1] - 2026-10-09 - Logo de Kerma en la pantalla de bloqueo

### Añadido
- **Pantalla de bloqueo con el logo de Kerma**: la misma imagen del fondo, sin la tarjeta del PC. Se quitan Windows Spotlight y los "datos curiosos" que Windows pone encima. Se aplica junto con el fondo en todos los tipos de PC.

## [5.9.0] - 2026-10-09 - Windows con el aspecto de Kerma

### Añadido
- **Aspecto Kerma en Windows**, junto con el fondo de pantalla: modo oscuro en Windows y en las apps, y el dorado de Kerma (#C8A96E) como color de énfasis. Ese dorado aparece en las barras de título de las ventanas, los botones, las casillas y la selección. La barra de tareas y el menú Inicio se quedan oscuros. El color está en `ajustes.psd1` (`Wallpaper.Accent`); vacío deja los colores como estén.

## [5.8.0] - 2026-10-09 - OBS listo en todas las mesas

### Añadido
- **Configuración de OBS de las mesas** (exportada de Blackjack 01): una fuente de audio de la Scarlett con monitorización y los filtros Compressor y atkAudio con **Alt Denoiser**, el perfil a 1920x1080 / 30 fps, y la posición de las ventanas y paneles, incluido el de Alt Denoiser. Las mesas abren OBS ya así.
- **Alt Denoiser** se instala solo en las mesas. Se descarga de su release oficial en GitHub, en la versión probada (v1.0.1), y queda donde lo busca el filtro de OBS.

### Cambiado
- Al copiar la configuración de OBS, el micro y la salida de monitorización se cambian por el dispositivo **predeterminado** de Windows, porque el identificador de un dispositivo concreto solo existe en el PC donde se eligió. En las mesas el predeterminado es la Scarlett.
- Los programas de una release de GitHub admiten una versión fija (`Tag`) y copiar un solo archivo del zip (`File` / `FileAs`).

## [5.7.0] - 2026-10-08 - Iconos fijos en la barra de tareas

### Añadido
- **Barra de tareas de las mesas.** Solo lleva estos iconos, en este orden: Explorador, Chrome, RustDesk, OBS, Stream Deck, HDMI Mirror y Focusrite Control 2. Se quitan Edge, la Tienda y el resto de lo que trae Windows. La barra queda fija: nadie puede añadir ni quitar iconos en la mesa. Si un programa no está instalado (Focusrite en un PC sin Scarlett), su icono no se pone. Se usa el acceso directo del propio programa, para que su ventana se agrupe en su icono; si no tiene, el script crea uno en Inicio > Kerma (HDMI Mirror).
- La lista y el bloqueo se eligen por tipo de PC en `perfiles.psd1` (`Taskbar`, `TaskbarLocked`), y los iconos se definen en `programas.psd1` (`Pins`). Si el perfil no lleva iconos, el script libera una barra fijada por una versión anterior.

## [5.6.7] - 2026-10-08 - Card Scanner aparece como abierta

### Corregido
- **Apps que arrancan con un .bat** (Card Scanner). No hay ningún proceso con el nombre del .bat, así que el panel no sabía si estaba abierta. Ahora el informe busca un programa que se esté ejecutando desde la carpeta del .bat o que lo nombre al arrancar, y si lo encuentra la marca como abierta. Si no encuentra nada, sigue como "no se puede saber" en lugar de "cerrada".

## [5.6.6] - 2026-10-08 - Ventana de Stream Deck visible al arrancar

### Cambiado
- **Stream Deck se ve al encender.** Al arrancar con Windows, Stream Deck se queda escondido en la bandeja del sistema. Ahora la tarea de arranque lo abre y, 20 s después, lo abre otra vez, lo que trae su ventana delante. Como solo admite una copia abierta, no se duplica.

## [5.6.5] - 2026-10-08 - Panel de estado renovado

### Cambiado
- **Panel nuevo** (mismo estilo de Kerma). Cada PC es una tarjeta con su estado (Bien, Revisar, Problema, Sin reportar), los avisos explicados ("OBS Studio cerrada", "Reloj desfasado"), el reloj con el botón Sincronizar, cuándo reportó, cuánto lleva encendido, el disco libre y las apps. Arriba aparece la lista "Necesitan atención" de todos los PCs; los contadores sirven de filtro y hay un buscador por PC, IP o app. Funciona en el móvil.
- **Detalle en un panel lateral** con pestañas: Resumen, Apps y tareas (con los resultados de las tareas traducidos: OK, en marcha, aún no se ha ejecutado...), Red, Logs del setup y Datos completos.
- **Menos falsas alarmas.** Un PC apagado ya no muestra avisos con datos viejos. En los primeros 3 minutos tras encenderse, las apps que todavía se están abriendo salen como "abriéndose", no en rojo. Card Scanner, que arranca con un .bat, sale como "no se puede saber" en vez de "cerrada". El ATEM Mini por USB sale marcado como aparato y no como la red del PC: el informe incluye ahora el nombre del adaptador.

## [5.6.4] - 2026-10-08 - El ATEM Mini ya no se confunde con la red

### Corregido
- **Adaptador de red en modo Automático.** En Blackjack 01, el ATEM Mini Pro conectado por USB aparece en Windows como un Ethernet conectado, y el script lo eligió como "primer Ethernet" para ponerle la IP fija de la mesa. Windows lo rechazó porque esa IP ya estaba en el cable de red, pero el adaptador del ATEM se quedó en IP fija y sin dirección. Ahora el script elige primero el adaptador que ya tiene la IP del PC, después el que sale a internet y, por último, el primer Ethernet que no sea un aparato. El ATEM y los adaptadores virtuales no se eligen nunca solos.
- **Sin quedarse a medias.** Si Windows rechaza la IP fija, el adaptador vuelve a DHCP si estaba así, y el log muestra el motivo que da Windows.
- Los ajustes de energía y encendido por red ya no se aplican al ATEM ni a los adaptadores virtuales.

## [5.6.3] - 2026-10-08 - Focusrite sin preguntar por el reinicio

### Corregido
- **Focusrite Control 2.** Al terminar de instalarse, su instalador preguntaba "Would you like to restart now?" y el setup se quedaba esperando a que alguien pulsara. Su paquete de winget solo lo instala en modo /silent, así que el script ahora lo instala en modo totalmente silencioso y sin reinicio. Ya no sale la ventana, y el PC se reinicia al final del setup, como con el cambio de nombre.
- El informe del panel ya no deja en el log un error rojo cuando todavía no se ha sincronizado nunca el reloj desde el panel.

## [5.6.2] - 2026-10-08 - Stream Deck con tarea de arranque, como OBS

### Cambiado
- **Stream Deck se abre con una tarea propia,** igual que OBS y HDMI Mirror: 15 s después de iniciar sesión. Tiene que estar abierta para que lleguen los comandos de los botones, y su propio arranque no es fiable en un PC recién instalado. Sustituye a la entrada de inicio de la 5.6.1. Si Stream Deck también se arranca por su cuenta no se duplica: solo admite una copia abierta.

## [5.6.1] - 2026-10-08 - Stream Deck arranca al iniciar sesión

### Corregido
- **Arranque de Stream Deck.** El script daba por hecho que Stream Deck arranca solo con Windows. Pero esa entrada de inicio la crea el propio programa la primera vez que se abre con cada usuario, y en un PC recién instalado todavía no existía. Ahora el script la busca y, si no está, la crea ("Elgato Stream Deck", en segundo plano). Si se había desactivado en el Administrador de tareas, la vuelve a activar.

## [5.6.0] - 2026-10-08 - Sincronizar el reloj desde el panel

### Añadido
- **Botón Sincronizar en el panel.** En la columna Reloj de cada PC. Los PCs están en la red del casino y el panel no puede llamarlos, así que la orden queda pendiente ("sincronizando…", con ✕ para cancelar). El PC la recoge en su siguiente reporte, como mucho a los 5 minutos: sincroniza con la hora de internet y, si sigue a más de 1 s, ajusta el reloj directamente. Después vuelve a reportar enseguida, así que el panel muestra el desfase nuevo al momento.
- **Corrección automática.** Si en un reporte el reloj se ha desviado más de 1 s, el PC lo corrige solo sin esperar a nadie. La última sincronización, automática o desde el panel, con el desfase antes y después, sale al pasar el ratón por el reloj y en el detalle del PC.
- Solo se aceptan acciones conocidas; el PC nunca ejecuta texto que venga del panel. Los PCs con un setup anterior muestran "setup antiguo" en lugar del botón: hay que pasarles el setup una vez.

## [5.5.5] - 2026-10-08 - IP de Blackjack 03

### Cambiado
- **Inventario.** Blackjack 03 ya tiene su IP fija, 192.168.0.153, y no hay que escribirla al reinstalar.

## [5.5.4] - 2026-10-08 - Ajustes tras la segunda prueba en Blackjack 03

### Corregido
- **Apps preinstaladas.** Si Windows responde que no encuentra una app al quitarla, es que ya no estaba. Antes contaba como fallo y salía "0 apps quitadas"; ahora el script comprueba si queda algo de verdad.
- **Log más limpio.** La comprobación final ya no llena el log de errores rojos por cada programa cerrado o por un adaptador sin puerta de enlace.

## [5.5.3] - 2026-10-08 - Un clic ya no congela el script

### Corregido
- **Modo selección de la consola.** Hacer clic dentro de la ventana de PowerShell activa el modo selección de Windows, que pausa el script hasta pulsar Esc. En Blackjack 03 pareció un cuelgue. Ahora el script desactiva ese modo al empezar.

## [5.5.2] - 2026-10-08 - Tiempo máximo para cada instalación

### Corregido
- **Instalaciones colgadas.** En la prueba de Blackjack 03, el instalador de Stream Deck pasó más de 30 minutos sin terminar y dejó el setup parado, sin que Ctrl+C pudiera cortarlo. Ahora cada instalación con winget tiene un máximo de 15 minutos. Si se pasa, el script cierra winget y su instalador, lo avisa y sigue con el siguiente programa. Si al final el programa sí quedó instalado, cuenta como instalado.

## [5.5.1] - 2026-10-08 - Ver el progreso de la instalación de programas

### Cambiado
- **Progreso visible.** Antes el script guardaba en silencio lo que decía winget, y por eso no se veía su barra de descarga: con programas grandes, como Chrome o Stream Deck, parecía colgado. Ahora winget escribe directamente en la ventana, con los MB descargados y el %.
- **Contador por programa.** Cada programa aparece como `[3/7] Stream Deck` y, al terminar, se muestra cuánto ha tardado ese programa y el total acumulado.
- **Errores de winget.** Si una instalación falla, se muestran el código, también en hexadecimal, y las últimas líneas del log de winget, que se guarda en `C:\KermaSetup\logs`. Así el error también queda en el log del panel.

## [5.5.0] - 2026-10-08 - Arreglos de la primera prueba en una mesa

### Corregido
- **Nombres al final.** Renombrar la cuenta con la que corre el script hacía que Windows dejara de reconocerla hasta reiniciar, y eso rompía casi todo lo que venía después con el error *No mapping between account names and security IDs*: la IP fija, los ajustes de red y la lista de apps, y probablemente también winget. Ahora el nombre del equipo y del usuario se decide al principio, pero se cambia al final, en una nueva fase 7, junto con el inicio de sesión. Las tareas de arranque y el fondo ya usan el nombre nuevo.
- **Catálogo de winget.** En un PC recién instalado el catálogo de winget puede no estar listo (error `0x8a15000f`), y no se instalaban Chrome, Stream Deck ni OBS. El script lo comprueba antes de instalar y, si falla, lo repara.
- **Servicio de RustDesk.** El instalador no siempre crea el servicio, y la forma de crearlo de la versión anterior dejaba el setup colgado. Ahora se crea como indica la documentación de RustDesk: sin esperar al proceso y comprobando cada pocos segundos si ya existe. Después se arranca y se espera a que esté listo antes de configurarlo.

## [5.4.1] - 2026-10-08 - RustDesk ya no puede bloquear el setup

### Corregido
- En la primera prueba en una mesa, el setup se quedó colgado en la sección de RustDesk y no respondía ni a Ctrl+C. La configuración de RustDesk se ejecuta ahora en un proceso aparte con un tiempo máximo de 3 minutos. Si RustDesk no responde, el script lo corta, lo avisa y sigue con las demás secciones. La contraseña pasa al proceso aparte sin aparecer en la línea de comandos ni escribirse en disco.

## [5.4.0] - 2026-10-08 - Log de cada instalación en el panel

### Añadido
- Al terminar, el script sube el log completo de la ejecución al panel de estado, también si alguna sección falló. El panel guarda los 10 últimos logs de cada PC, y se leen desde el detalle del PC con el botón **Logs del setup**. Hace falta que el PC esté registrado en el panel.

### Corregido
- La sección de red decía que la IP venía "del inventario" cuando se había escrito al empezar.

## [5.3.1] - 2026-10-08 - Arreglo del modo Automático

### Corregido
- En modo Automático el script se paraba en la fase 0 con el error *The variable cannot be validated because the value Automático is not a valid value for the Mode variable*. El texto del modo se guardaba en una variable con el mismo nombre que el parámetro `-Mode`. En modo Manual no pasaba.
- La comprobación de GitHub detecta ahora este tipo de choque entre variables y parámetros del script.

## [5.3.0] - 2026-10-08 - Nuevo diseño del fondo de pantalla

### Cambiado
- **El mismo fondo para todos los PCs.** Una sola plantilla, `assets/wallpaper/base.jpg`, con el logo de Kerma más pequeño y alineado a la izquierda, y los personajes como estaban.
- Debajo del logo, el script dibuja una **tarjeta** con:
  - El tipo de PC en su color: blackjack en dorado, ruleta en verde, craps en rojo, y supervisor, Master Control Room y oficina en sus colores.
  - El nombre del PC en grande. Si no cabe, se parte en dos líneas o se reduce la letra.
  - La IP, bien visible, y el nombre de equipo.
- La versión del script ya no aparece en el fondo.
- Los colores y textos de cada tipo están en `src/config/ajustes.psd1`, en `Wallpaper.Tags`.
- El nombre de la tarjeta es el `Label` del inventario, o `WallpaperText` si se define. En modo Manual se puede escribir otro.

### Eliminado
- Las plantillas con el nombre de cada mesa ya dibujado y la plantilla sin texto: las sustituye `base.jpg`. Siguen en el historial del repositorio.

### Añadido
- La comprobación de GitHub genera en Windows los fondos de varios PCs reales y de un nombre escrito a mano, y los adjunta al resultado para poder revisarlos.

## [5.2.0] - 2026-10-08 - Fuentes del MCR en el fondo

### Cambiado
- El nombre que escribe el script en el fondo usa **Orbitron Black**, y la línea con el nombre del equipo, la IP y la versión usa **Sora**: las fuentes del MCR, propuestas por David. Se aplica a los PCs sin plantilla propia y a los nombres escritos a mano. Las fuentes van en `assets/fonts`, con licencia libre SIL OFL, y Windows las carga solo para el fondo, sin instalarlas. Si no se pudieran cargar, se usan Bahnschrift y Segoe UI, como antes.

## [5.1.0] - 2026-10-08 - Otro PC y nombre del fondo a mano

### Añadido
- **Otro PC (no está en la lista):** nueva opción al elegir el PC, para equipos sueltos como el de la Office Manager. El script pide el nombre y el tipo de PC, y propone el nombre de equipo, el usuario y la IP, que se pueden cambiar. No hace falta añadirlo antes al inventario.
- **Nombre del fondo a mano:** en modo Manual, la sección del fondo enseña el nombre que va a poner y deja escribir otro. Con `|` se parte en dos líneas, como en la plantilla de Blackjack Unlimited, por ejemplo `OFFICE | MANAGER`.
- Campo opcional `WallpaperText` en el inventario, para fijar el nombre del fondo de un PC también en modo Automático.

## [5.0.2] - 2026-10-08 - Fondos de pantalla a resolución completa

### Cambiado
- Plantillas de fondo de Blackjack 01 a 04, Blackjack Unlimited 01 y Roulette 01 sustituidas por los originales de 1920x1080. Las anteriores eran copias ampliadas desde 1600x900.
- La plantilla sin texto, que usan Craps, supervisores, oficina y MCR, se ha rehecho a partir de los originales.
- La línea con el nombre del equipo, la IP y la versión baja unos píxeles para no quedar pegada al nombre de dos líneas de Blackjack Unlimited.

## [5.0.1] - 2026-10-08 - Kerma RustDesk actualizado

### Cambiado
- Scripts de RustDesk de David actualizados a su último commit (`24be0b3`):
  - Los MASTER que ya tenían el MCR en Favoritos lo pierden al volver a pasar el script.
  - En modo MASTER ya no se exige que RustDesk confirme la contraseña de salida por línea de comandos. Se sigue escribiendo y comprobando en el perfil del usuario.

## [5.0.0] - 2026-10-08 - Reorganización: perfiles, idioma y modos

El script deja de ser un único archivo de 2.200 líneas. Hace lo mismo que la 4.7.1, pero organizado para crecer y para trabajar solo.

### Cambiado
- **Configuración separada del código** en `src/config`:
  - `inventario.psd1`: cada PC, con su clave, nombres, perfil, juego, scanner e IP de respaldo.
  - `perfiles.psd1`: qué se hace en cada tipo de PC (mesa, supervisor, oficina, MCR).
  - `programas.psd1`: qué se instala, qué arranca y qué apps se quitan.
  - `ajustes.psd1`: hora, red, RustDesk, audio, panel y tema de OBS.
- **El código, por secciones** en `src/sections`, una por archivo, y las funciones comunes en `src/lib`.
- Las secciones toman su valor por defecto del **perfil** del PC, no de reglas repartidas por el código.
- Fases con un orden lógico: comprobaciones previas, sistema base, limpieza y ajustes, programas, configuración, vigilancia y comprobación final.

### Añadido
- **Idioma al empezar:** español o English. Todos los mensajes del script están en los dos idiomas.
- **Modo al empezar:**
  - **Automático:** aplica el perfil del PC sin preguntar. Al principio pide solo lo que no puede saber: la contraseña de RustDesk, el PIN del panel, la IP si no la conoce y los programas que no instala, como la Dealer App o el scanner. Después se puede dejar el PC trabajando.
  - **Manual:** pregunta en cada sección, como hasta ahora.
  - **Revisión:** muestra el estado del PC sin cambiar nada.
- Las **IPs se leen de la lista de David** al empezar y ganan sobre las del inventario. Si no se puede leer, se usa el inventario y el script lo avisa.
- **Comprobación final:** el script termina mostrando el estado real del PC, con el mismo informe del modo revisión.
- **Validación de la configuración** con `-ValidateConfig`, que GitHub ejecuta en Windows en cada cambio. Comprueba claves, nombres e IPs repetidos, perfiles que nombran programas inexistentes, plantillas, el tema de OBS, el autoarranque de OBS y que la versión coincide con este historial. Muestra además el plan de cada PC.
- Parámetros `-Lang` y `-Mode` para lanzarlo sin menús.

## [4.7.1] - 2026-10-07 - El MCR fuera de RustDesk

### Cambiado
- El Master Control Room queda fuera de RustDesk: no aparece en los Favoritos de los MASTER, aunque esté en la lista de David, y en el propio MCR no se instala ni se configura RustDesk. Sigue en la tabla de PCs para todo lo demás.

## [4.7.0] - 2026-10-07 - MCR y lista de equipos desde el repositorio de David

### Añadido
- **Master Control Room** en la tabla de PCs, con su IP 192.168.1.79. Se configura como MASTER de RustDesk, igual que los supervisores, y aparece en su propio apartado del panel.
- Los MASTER leen la lista de equipos de RustDesk del repositorio de David (`Equipos.ejemplo.csv`, columnas Nombre, IP y Puerto). Las IPs se mantienen allí. Si no se puede leer, porque su repositorio es privado o no hay internet, se usan los PCs de la tabla del script que tienen IP.

### Cambiado
- El panel agrupa los PCs por grupo: Mesas, Oficina, Supervisores y Master Control Room.

## [4.6.0] - 2026-10-07 - Acceso remoto con Kerma RustDesk

Integra el trabajo de David ([restidavid/kerma-rust](https://github.com/restidavid/kerma-rust)), que configura RustDesk para conectarse por IP directa dentro de la red de la oficina, sin servidores externos.

### Añadido
- Nueva sección **Acceso remoto**, después de instalar los programas:
  - **Mesas y oficina, modo CLIENT:** aceptan conexiones por IP en el puerto 21118 con la contraseña común, sin que nadie tenga que aceptar en pantalla. Teclado, portapapeles, archivos, audio y reinicio remoto activados. El servicio de RustDesk arranca solo. Regla de cortafuegos solo para la red de la oficina.
  - **Supervisores, modo MASTER:** además guardan la contraseña común para conectarse sin escribirla, y tienen en Favoritos todos los PCs de la tabla del script que tienen IP, más el MCR.
  - Logo de Kerma dentro de RustDesk.
- La contraseña común se pide al configurar, dos veces para evitar errores, y nunca se guarda en el script ni en el repositorio. Modo desatendido: `-RustDeskPassword`.
- IPs fijas de Blackjack 01 y 02, Blackjack Unlimited 01, Roulette 01 y Craps 01 en la tabla de PCs, tomadas de la lista de David. Se ofrecen al configurar la red y alimentan los Favoritos del MASTER.
- El panel de estado muestra si el servicio de RustDesk está activo y si el puerto 21118 acepta conexiones, y marca para revisar las mesas donde no.

### Cambiado
- La comprobación automática acepta scripts con tildes si están guardados como UTF-8 con BOM, que Windows PowerShell 5.1 lee bien.

## [4.5.0] - 2026-10-07 - Fondo de pantalla de cada mesa

### Añadido
- Nueva sección **Fondo de pantalla**: pone la plantilla de Kerma de cada mesa y, debajo del nombre de la mesa, el nombre del equipo, la IP y la versión del script. Quien entra por RustDesk sabe al momento en qué PC está.
- Plantillas de Blackjack 01 a 04, Blackjack Unlimited 01 y Roulette 01 en `assets/wallpaper`. Los PCs sin plantilla propia, como Craps, supervisores y oficina, usan la plantilla sin texto y el script escribe su nombre.

### Cambiado
- La Scarlett es también la salida de audio predeterminada, no solo el micrófono.

## [4.4.0] - 2026-10-07 - Panel de estado, modo revisión, audio y red

### Añadido
- **Panel de estado** en [kermasetup.netlify.app/estado](https://kermasetup.netlify.app/estado), protegido con PIN. Cada PC envía su estado cada 5 minutos y al arrancar: desfase del reloj, apps instaladas y abiertas, espacio en disco, red con IP y MAC, versión de Windows, equipo y número de serie, tareas del script y Scarlett. Se abre desde cualquier navegador, también el móvil, y marca en rojo los PCs con problemas o que dejan de reportar.
- Nueva sección **Panel de estado**: registra el PC con el PIN del panel, que no se guarda en el PC, e instala la tarea *Kerma - Status*, que se ejecuta como sistema.
- **Modo revisión**: `Kerma-PCSetup.bat -Check` muestra el estado del PC en pantalla sin cambiar nada.
- Nueva sección **Audio**: quita los sonidos de Windows y el sonido de inicio, y pone la Scarlett como micrófono predeterminado si está conectada.
- **Red** en Ajustes del PC: activa el encendido por red, impide que Windows apague la tarjeta para ahorrar energía, desactiva el Ethernet de bajo consumo y el inicio rápido, y marca la red como privada.
- Modo desatendido: parámetro `-PanelPin` para registrar el PC en el panel.

## [4.3.0] - 2026-10-07 - OBS arranca solo tras un cierre inesperado, y con el tema Kerma

### Corregido
- Si OBS se cerraba mal (un fallo, un corte de luz o un reinicio forzado), al volver a arrancar se quedaba parado en el aviso *Iniciar normalmente / Modo seguro* y la mesa no terminaba de arrancar sola. Ahora el autoarranque borra antes la marca que deja OBS al cerrarse mal, igual que hace OBS al cerrarse bien, y abre directamente. Si alguien abre OBS a mano desde el menú Inicio, sí sigue ofreciendo el modo seguro. Hay que volver a pasar el script en las mesas ya montadas para que se rehaga la tarea de OBS.
- OBS ya no muestra al arrancar el aviso de versión nueva, que también paraba el autoarranque. Las actualizaciones siguen llegando con winget.

### Añadido
- **Tema Kerma para OBS**: los colores de Kerma Shifts (fondo casi negro y dorado). El script lo instala y pregunta si dejarlo elegido; siempre se puede cambiar en *Ajustes › Apariencia*. Si OBS no pudiera cargarlo, abre con su tema normal.

## [4.2.2] - 2026-10-07 - Arreglos de la primera prueba real

### Corregido
- Un error en una sección ya no detiene el script. Cada sección queda aislada: si falla, lo avisa en rojo, lo anota en el resumen y el script sigue con las demás. En la primera prueba, un error en *Quitar apps preinstaladas* impidió que se ejecutaran la instalación de programas, la configuración, el autoarranque y el resumen.
- *Quitar apps preinstaladas* fallaba con *No mapping between account names and security IDs was done* cuando Windows no podía resolver alguna cuenta, por ejemplo justo después de renombrar el usuario. Ahora quita las apps de la cuenta actual y de las cuentas nuevas.
- Crear una clave del registro que ya existía la vaciaba. Eso provocaba el error *Cannot delete a subkey tree* al desactivar las notificaciones, y además restablecía otros ajustes de Windows de esas claves. Ahora las claves solo se crean si no existen.
- El ajuste de ahorro de energía USB no existe en todos los PCs. Ahora se informa como "no presente" en lugar de mostrar un aviso.
- Los errores de las herramientas de Windows se muestran con su mensaje limpio, sin el texto técnico de PowerShell.

## [4.2.1] - 2026-10-07 - Office y OneDrive fuera también en supervisores

### Cambiado
- Microsoft 365 y OneDrive se quitan por defecto también en los PCs de supervisores, que no los usan. Se sigue preguntando antes de quitarlos.

## [4.2.0] - 2026-10-07 - Fuera la basura preinstalada y barra de tareas limpia

### Añadido
- Nueva sección **Quitar apps preinstaladas**, con tres preguntas independientes:
  - **Apps de la Tienda:** Solitario, Xbox, Teams, Outlook nuevo, Correo y Calendario, OneNote, el acceso a Office, noticias y tiempo de Bing, Consejos, Mapas, Phone Link, Clipchamp, Cortana, Copilot, Dev Home y similares. También Candy Crush, Spotify, TikTok, Netflix y demás apps de promoción. Se quitan para todos los usuarios y para los que se creen después, y Windows deja de instalar apps sugeridas.
  - **Microsoft 365 / Office de prueba:** se desinstala sin ventanas.
  - **OneDrive:** se desinstala.
- En los PCs de supervisores, Microsoft 365 y OneDrive se conservan por defecto.
- Hay apps que nunca se tocan: la Tienda, el instalador de programas (winget), Calculadora, Fotos, Bloc de notas, Paint, Recortes, Terminal, Seguridad de Windows, Notas rápidas, Alarmas, Grabadora y Cámara.
- **Barra de tareas** en Ajustes del PC: sin cuadro de búsqueda, sin Vista de tareas, sin Widgets y sin Reanudar. Los cambios se ven al momento.

## [4.1.1] - 2026-10-07 - Dealer App y scanner vuelven al autoarranque

### Corregido
- La 4.1.0 quitó Dealer App y Card Scanner del autoarranque de las mesas, cuando solo había que dejar de instalarlos. Vuelven a configurarse: el script pide su programa como antes. Las tareas que ya existían en los PCs nunca se borraron.

### Cambiado
- Card Scanner solo se ofrece en las mesas de blackjack, que son las que escanean cartas. Ruleta y craps ya no lo preguntan.

## [4.1.0] - 2026-10-06 - Audio de OBS y Scarlett

### Añadido
- **atkAudio** en las mesas: el plugin gratuito que permite usar plugins VST3 dentro de OBS. Se instala en la carpeta de OBS desde su última release en GitHub, y se actualiza solo cuando sale una versión nueva.
- **Focusrite Control 2** para las Scarlett Solo de tercera generación. Se instala en cualquier PC que tenga una Focusrite conectada.
- Los plugins VST3 que haya en `assets/vst3` se copian en `C:\Program Files\Common Files\VST3`.
- Protección para el repositorio público: el script nunca copia el `service.json` de OBS, que guarda la clave de emisión, y la comprobación automática rechaza cualquier cambio que lo incluya.

### Cambiado
- Supervisores y PCs de oficina instalan Google Chrome y RustDesk.
- Deskflow deja de instalarse y de arrancar en el PC del despacho. Era una prueba.
- Card Scanner y Dealer App salen del autoarranque de las mesas. El scanner solo se usa en algunas mesas y se configura a mano, y la Dealer App la gestionan los desarrolladores.

## [4.0.0] - 2026-10-06 - Instalación completa con una línea

El script pasa a ser el instalador maestro de los PCs de la empresa. En un PC recién instalado basta con pegar una línea en PowerShell: descarga la última versión, instala los programas, los configura y deja el PC listo tras reiniciar.

### Añadido
- **Instalación con una línea** mediante `bootstrap.ps1`. Descarga la última release en `C:\KermaSetup\app` y la ejecuta con permisos de administrador.
- Sección **Instalar programas** según el tipo de PC:
  - Mesas: Google Chrome, RustDesk, Stream Deck, HDMI Mirror y OBS Studio.
  - Despacho: Google Chrome, RustDesk y Deskflow.
  - Supervisores: Google Chrome.
- Los programas del catálogo de Windows se instalan con winget. Si winget no está activo en un PC nuevo, el script intenta activarlo.
- RustDesk y HDMI Mirror se descargan de su última release en GitHub. HDMI Mirror se instala en `C:\Kerma\HdmiMirror` y se actualiza solo cuando sale una versión nueva, conservando su configuración.
- Si hay una Focusrite conectada, el script la detecta y la muestra. Su software se instalará cuando se confirme la generación de las Scarlett.
- Sección **Ajustes del PC**: la pantalla nunca se apaga, el PC no entra en suspensión, los USB no se suspenden, y se desactivan las notificaciones y el salvapantallas.
- Sección **Configuración de programas**, que aplica lo que haya en la carpeta `assets`:
  - La configuración de HDMI Mirror de cada mesa.
  - Las escenas, el perfil y los ajustes de OBS.
  - El perfil de Stream Deck del juego de cada mesa.

### Cambiado
- HDMI Mirror sustituye a Mirror App en el autoarranque de las mesas. La tarea antigua de Mirror App se elimina.
- Stream Deck ya no tiene tarea de autoarranque, porque se abre sola al iniciar sesión. Así no se abre dos veces.
- Las rutas de las apps que instala el script ya no se preguntan: el script sabe dónde están.
- Las rutas recordadas se guardan también en `C:\KermaSetup`, para conservarlas entre versiones.

## [3.2.0] - 2026-10-02 - Sincronización de la hora

Las cuentas atrás de la Dealer App dependen del reloj de Windows. Con unos segundos de desfase terminan antes de tiempo, por ejemplo de 40 a 27 en vez de 13 a 0, o se quedan paradas en 1 s.

### Añadido
- Nueva sección **Fecha y hora**, la primera después de elegir el PC. Se aplica a todos los tipos de PC.
- Zona horaria de Monterrey: UTC-6 todo el año, sin horario de verano. Si los datos de zona horaria de Windows son antiguos y todavía aplican el horario de verano abolido en 2022, usa una zona equivalente y lo avisa.
- El servicio de hora de Windows queda siempre activo y sincroniza **cada hora**. Antes lo hacía cada 7 días, que era la causa del desfase.
- Mide el desfase directamente contra un servidor de hora de internet antes y después de sincronizar. El resultado sale el primero en el resumen final.
- Avisa si la red bloquea la hora de internet, que usa el puerto UDP 123.
- Tarea en segundo plano **Kerma - Time Sync**. Se ejecuta al encender el PC, esperando a que haya red tras un apagón, y cada día a las 07:00. Deja un registro en `C:\ProgramData\Kerma\timesync.log`.

### Corregido
- Si una herramienta de Windows como `w32tm` o `schtasks` escribía un error, el script entero podía detenerse y saltarse todas las secciones siguientes.

### A tener en cuenta
- La primera sincronización corrige el reloj de golpe. Ejecútala con la mesa sin juego.

## [3.1.0] - 2026-09-22 - Rutas de las apps al vuelo

### Añadido
- Ya no hay que editar el script para poner las rutas de las apps. Al activar una app, el script pide su programa: se puede pegar la ruta o pulsar **B** para buscarla con la ventana de Windows.
- Comprobación de cada ruta: que existe, que es un programa `.exe`, `.bat` o `.cmd`, y que es una ruta completa. Muestra el nombre y el fabricante del programa para confirmar que es el correcto.
- Si se elige un acceso directo, se usa el programa al que apunta.
- Prueba opcional que abre la app una vez para ver que arranca.
- Las rutas se recuerdan en `app-paths.json` junto al script. En las siguientes mesas basta con pulsar Enter, y el modo desatendido también las usa.
- Si una ruta recordada está en el Escritorio de otra mesa, se busca en el mismo sitio del perfil de la mesa actual.

### Cambiado
- Cada app arranca desde su propia carpeta. Antes solo lo hacía OBS.

### Corregido
- Crear la tarea de autoarranque fallaba con *The parameter is incorrect*. Las tareas se asocian ahora al grupo Usuarios de Windows, que no depende del nombre de la cuenta ni del idioma. Si aun así falla, se intenta con `schtasks.exe`, y si fallan los dos se muestran ambos errores.

## [3.0.0] - 2026-09-10 - Migración a PowerShell

### Cambiado
- El script se reescribe en PowerShell: `Kerma-PCSetup.ps1`, con el lanzador `Kerma-PCSetup.bat` para seguir usándolo con doble clic. Pide permisos de administrador por sí mismo.
- Mismos menús, nombres de tareas y carpetas que la v2, así que las tareas ya creadas se reemplazan sin problema.

### Añadido
- Tabla de PCs en la cabecera del script con el nombre, el usuario, el tipo, las apps y la IP de cada equipo.
- Tabla de apps con el retardo de arranque y si se abren maximizadas.
- Valores de red por defecto: máscara 255.255.252.0, puerta de enlace 192.168.0.10, DNS 8.8.8.8 y 1.1.1.1. Solo hay que teclear la IP.
- Registro de cada ejecución en `C:\KermaSetup\logs`.
- Modo desatendido: `Kerma-PCSetup.bat -PC RL01 -Unattended`, con `-Restart` opcional.
- Resumen final con todo lo que se ha cambiado.

### Eliminado
- `kerma-quitar-password.bat`. Su función está en la sección de login.

## [2.0.0] - 2026-09-10 - Auditoría y nuevas secciones

### Corregido
- El auto-login dejaba de funcionar después de renombrar el equipo, porque se guardaba el nombre antiguo.
- Los errores de PowerShell no se detectaban, así que el script mostraba `[OK]` aunque el renombrado fallara.
- Las contraseñas con caracteres especiales como `!` o `%` se guardaban mal. Ahora se escriben ocultas.
- Saltar el renombrado hacía que se ofrecieran las apps de mesa en cualquier PC.

### Añadido
- Comprobación de permisos de administrador al empezar.
- Login sin contraseña, recomendado en las mesas, además del auto-login con contraseña guardada.
- `kerma-quitar-password.bat` para quitar la contraseña en los PCs ya configurados.
- PCs de supervisores y PC del despacho de Hector, con cámaras y Deskflow, cada uno con sus propias apps.
- Sección de **Windows Update**: solo manual, desactivado del todo o restaurar.
- Sección de **red**: elegir el adaptador y poner una IP fija o volver a DHCP, con validación de cada dato.
- Aviso si la ruta de una app no existe, y oferta de reinicio al final.

### Cambiado
- Siempre se elige qué PC es, y el renombrado pasa a ser opcional.
- Las secciones de cada app se unifican en una sola subrutina.

## [1.0.0] - 2026-08-28 - Versión inicial

### Añadido
- Script `.bat` original: elegir la mesa, renombrar el usuario, el equipo y el nombre completo, auto-login con contraseña guardada, y autoarranque de cinco apps con retardo y opción de abrirlas maximizadas.
