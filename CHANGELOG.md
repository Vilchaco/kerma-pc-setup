# Historial de cambios

Todas las versiones de Kerma PC Setup, de la más reciente a la más antigua. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y la numeración sigue el [versionado semántico](https://semver.org/lang/es/).

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
