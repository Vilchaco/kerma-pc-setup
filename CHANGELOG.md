# Historial de cambios

Todas las versiones de Kerma PC Setup, de la más reciente a la más antigua. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y la numeración sigue el [versionado semántico](https://semver.org/lang/es/).

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
