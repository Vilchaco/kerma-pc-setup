# Kerma PC Setup

[![Lint](https://github.com/Vilchaco/kerma-pc-setup/actions/workflows/lint.yml/badge.svg)](https://github.com/Vilchaco/kerma-pc-setup/actions/workflows/lint.yml)
[![Última versión](https://img.shields.io/badge/descargar-%C3%BAltima%20versi%C3%B3n-2ea44f)](https://github.com/Vilchaco/kerma-pc-setup/releases/latest)

Script para dejar listo un PC del casino de Kerma Games en unos minutos: mesas de juego, PC de supervisores y PC del despacho. Pregunta paso a paso, valida cada dato y deja un registro de todo lo que cambia.

## Instalar en un PC nuevo con una línea

1. Conecta el PC a internet.
2. Abre **PowerShell**: clic derecho en el botón de Inicio y **Terminal** o **Windows PowerShell**.
3. Escribe esta línea y pulsa Enter:

```powershell
irm https://kermasetup.netlify.app | iex
```

`kermasetup.netlify.app` solo redirige a [bootstrap.ps1](bootstrap.ps1) en `main`, así que nunca hay que volver a desplegarlo. La línea larga equivalente es:

```powershell
irm https://raw.githubusercontent.com/Vilchaco/kerma-pc-setup/main/bootstrap.ps1 | iex
```

Desde **CMD** la línea es esta:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://kermasetup.netlify.app | iex"
```

El script se descarga en `C:\KermaSetup\app`, pide permisos de administrador y empieza. Responde a cada sección y reinicia al final.

> **Seguridad.** Esa línea ejecuta como administrador lo que haya en este repositorio. Cualquiera con permiso de escritura en él decide lo que se instala en los PCs de la empresa. Revisa con cuidado quién tiene ese permiso.

## Acceso remoto con RustDesk

Los PCs se conectan entre sí con RustDesk por **IP directa** dentro de la red de la oficina, en el puerto 21118, sin pasar por servidores externos. La configuración es el trabajo de David, [Kerma RustDesk](https://github.com/restidavid/kerma-rust), copiado en `src/rustdesk` con la versión anotada en `VERSION.txt`.

| Tipo de PC | Modo | Qué hace |
|---|---|---|
| Mesas y oficina | CLIENT | Acepta conexiones con la contraseña común, sin que nadie acepte en pantalla. |
| Supervisores | MASTER | Lleva en Favoritos la lista de equipos y tiene la contraseña guardada para conectarse. |
| Master Control Room | Sin RustDesk | No se instala, no se configura y no aparece en los Favoritos. |

> **La contraseña común es la única llave de las mesas.** Con ella, cualquiera dentro de la red puede tomar el control de una mesa en juego sin aviso previo. Usa una contraseña larga, que la conozcan pocas personas, y cámbiala cuando alguien deje el equipo. Para cambiarla, vuelve a pasar el script con la nueva contraseña en todos los PCs.

La lista de equipos del MASTER se mantiene en el repositorio de David, en `Equipos.ejemplo.csv`. El script la lee al configurar cada MASTER, así que basta con actualizarla allí y volver a pasar el script en los MASTER. Para eso su repositorio tiene que ser público: solo contiene nombres e IPs, sin contraseñas. Mientras sea privado, el script usa las IPs de `src/config/inventario.psd1`, más `ExtraPeers` de `src/config/ajustes.psd1`.

## Panel de estado

Abre **[kermasetup.netlify.app/estado](https://kermasetup.netlify.app/estado)** desde cualquier navegador e introduce el PIN del panel. El PIN lo tiene quien mantiene el script, y se cambia en Netlify, en la variable `STATUS_PIN` del sitio `kermasetup`.

Cada PC registrado envía su estado cada 5 minutos: hora, apps, disco, red, equipo y tareas. Un PC que deja de reportar está apagado o sin red. Al configurar un PC, la sección *Panel de estado* pide el PIN una sola vez y lo cambia por una clave propia del PC. El PIN no se guarda en el PC.

Para ver lo mismo en el propio PC, sin enviar nada y sin cambiar nada:

```bat
Kerma-PCSetup.bat -Check
```

## Pasos manuales en la BIOS

El script no puede cambiar la BIOS. Hazlo una vez en cada PC:

- **Encendido tras un corte de luz.** Suele llamarse *Restore on AC Power Loss* o *AC Recovery*. Ponlo en *Power On*, para que el PC arranque solo cuando vuelve la luz.
- **Encendido por red.** Suele llamarse *Wake on LAN* o *Power On by PCI-E*. Actívalo si queréis encender los PCs a distancia. El script ya lo deja preparado en Windows.

## Descargar el zip

También puedes descargar la **[última versión](https://github.com/Vilchaco/kerma-pc-setup/releases/latest)** a mano. El zip está en el apartado **Assets** de la release. Las notas de cada versión están en [CHANGELOG.md](CHANGELOG.md).

## Uso con el zip

1. Copia el zip al PC con Windows, por ejemplo con un USB.
2. Clic derecho en el zip, **Propiedades**, marca **Desbloquear** y acepta. Sin esto Windows puede bloquear el script por venir de internet.
3. Clic derecho en el zip y **Extraer todo**. No lo ejecutes desde dentro del zip, porque así no puede recordar las rutas de las apps.
4. Doble clic en `Kerma-PCSetup.bat`. Acepta el aviso de permisos de administrador.

## Al empezar: idioma, modo y PC

El script pregunta tres cosas:

1. **Idioma:** español o English.
2. **Modo:**
   - **Automático.** Aplica el perfil del PC sin preguntar. Al principio pide solo lo que no puede saber: la contraseña de RustDesk, el PIN del panel, la IP si no la conoce y dónde están los programas que no instala, como la Dealer App o el scanner. Después puedes dejar el PC trabajando y volver al final para reiniciar.
   - **Manual.** Pregunta en cada sección. El valor que se ofrece por defecto es el del perfil.
   - **Revisión.** Muestra el estado del PC y no cambia nada.
3. **Qué PC es,** de la lista del inventario. Para un equipo que no está en la lista, como el de la Office Manager, elige **Otro PC**: el script pide su nombre y su tipo, y propone el resto.

En modo Manual, la sección del fondo deja escribir el nombre que aparece en la imagen. Con `|` se parte en dos líneas.

El script trabaja por fases y termina con una comprobación del estado real del PC y un resumen de lo que ha cambiado:

| Fase | Contenido |
|---|---|
| 0. Comprobaciones | Permisos, internet y lista de IPs de David |
| 1. Sistema base | Hora, nombres, inicio de sesión, red, Windows Update |
| 2. Limpieza y ajustes | Ajustes del PC, apps preinstaladas |
| 3. Programas | Instalar y actualizar |
| 4. Configuración | RustDesk, audio, programas, arranque de apps, fondo |
| 5. Vigilancia | Panel de estado |
| 6. Final | Comprobación, resumen y reinicio |

Si una sección falla, lo avisa en rojo, lo anota en el resumen y sigue con la siguiente.

Lleva la carpeta extraída en el USB de mesa en mesa. Las rutas de las apps que elijas en la primera se ofrecen solas en las siguientes.

## Qué hace

| Sección | Qué hace |
|---|---|
| Elegir PC | Define el nombre, el usuario y las apps de ese equipo. |
| Fecha y hora | Pone la hora de Monterrey y mantiene el reloj sincronizado con internet: cada hora, al encender y una vez al día. Las cuentas atrás de la Dealer App dependen de ello. |
| Renombrar | Cambia el nombre del equipo, el usuario y el nombre completo al estándar. Es opcional. |
| Login | Quita la contraseña para que arranque directo al escritorio tras un apagón, o guarda la contraseña para el auto-login. |
| Windows Update | Solo manual, desactivado del todo, o restaurar las actualizaciones automáticas. |
| Red | Muestra los adaptadores y pone una IP fija o vuelve a DHCP. Solo hay que teclear la IP. |
| Ajustes del PC | Pantalla siempre encendida, sin suspensión, USB sin ahorro de energía, sin notificaciones ni salvapantallas. Barra de tareas sin búsqueda, Vista de tareas, Widgets ni Reanudar. Red con encendido remoto y sin ahorro de energía. |
| Quitar apps preinstaladas | Quita Solitario, Xbox, Teams, apps de Bing, Candy Crush y similares, Microsoft 365 de prueba y OneDrive, en todos los tipos de PC. |
| Instalar programas | Instala o actualiza los programas de ese tipo de PC. |
| Acceso remoto | Configura RustDesk por IP directa: CLIENT en mesas, MASTER en supervisores. |
| Configuración de programas | Aplica la configuración guardada de HDMI Mirror, OBS y Stream Deck, y el tema Kerma de OBS. |
| Autoarranque | Crea una tarea por app para que se abra al iniciar sesión, con su retardo y maximizada si se quiere. OBS arranca sin el aviso de modo seguro aunque se haya cerrado mal, y sin el aviso de actualizaciones. |
| Audio | Quita los sonidos de Windows y pone la Scarlett como micrófono y salida predeterminados. |
| Fondo de pantalla | Pone la plantilla de Kerma de la mesa con el nombre del equipo, la IP y la versión. |
| Panel de estado | Registra el PC en el panel web y envía su estado cada 5 minutos. |
| Resumen | Lista todo lo que ha cambiado y ofrece reiniciar. |

## Tipos de PC

| Tipo | PCs | Comportamiento |
|---|---|---|
| Mesa | Ruleta, Blackjack, Blackjack Unlimited, Craps | Sin contraseña y actualizaciones manuales. Instala Chrome, RustDesk, Stream Deck, HDMI Mirror, OBS y atkAudio, con el perfil de Stream Deck de su juego. Configura el autoarranque de Dealer App y, en blackjack, del Card Scanner, que se instalan a mano. |
| Supervisor | Supervisor 01 y 02 | Recomienda mantener la contraseña y las actualizaciones automáticas. Instala Chrome y RustDesk. Sin autoarranque de apps. |
| Oficina | PC de Hector | Igual que una mesa, pero instala Chrome y RustDesk, y su app de inicio es el programa de cámaras. |

En cualquier PC con una Focusrite conectada se instala también Focusrite Control 2.

## Programas

| Programa | De dónde sale |
|---|---|
| Google Chrome | winget, `Google.Chrome` |
| RustDesk | Última release de [rustdesk/rustdesk](https://github.com/rustdesk/rustdesk) |
| Stream Deck | winget, `Elgato.StreamDeck` |
| HDMI Mirror | Última release de [Vilchaco/kerma-hdmi-mirror](https://github.com/Vilchaco/kerma-hdmi-mirror) |
| OBS Studio | winget, `OBSProject.OBSStudio` |
| atkAudio, VST3 en OBS | Última release de [atkAudio/PluginForObsRelease](https://github.com/atkAudio/PluginForObsRelease), versión portátil |
| Focusrite Control 2 | winget, `FocusriteAudioEngineeringLtd.FocusriteControl2`. Para las Scarlett Solo de tercera generación. |
| Plugins VST3 | Carpeta [assets/vst3](assets/vst3/README.md) |

Los programas de cada tipo de PC están en `src/config/perfiles.psd1`.

## Desde la línea de comandos

Abre una consola en la carpeta del script:

```bat
Kerma-PCSetup.bat -Lang es -Mode Auto -PC BJ01
Kerma-PCSetup.bat -PC BJ01 -Unattended -RustDeskPassword ... -PanelPin ... -Restart
Kerma-PCSetup.bat -Check
Kerma-PCSetup.bat -ValidateConfig
```

- `-Lang` y `-Mode` saltan los menús de idioma y de modo. `-PC` salta el de elegir PC.
- `-Unattended` no pregunta nada. Las contraseñas van como parámetros y la red solo se configura si se conoce la IP.
- `-Check` es el modo revisión.
- `-ValidateConfig` comprueba la configuración y muestra el plan de cada PC. GitHub lo ejecuta en cada cambio.

## Configuración

No hace falta tocar código. Todo está en `src/config`:

| Archivo | Qué contiene |
|---|---|
| `inventario.psd1` | Cada PC: clave, grupo, nombre, perfil, nombre de equipo y de usuario, juego, si usa scanner e IP de respaldo. **Para añadir un PC, copia un bloque y cambia sus datos.** |
| `perfiles.psd1` | Qué se hace en cada tipo de PC: inicio de sesión, Windows Update, ajustes, limpieza, programas, modo de RustDesk, apps que arrancan, fondo y panel. |
| `programas.psd1` | De dónde sale cada programa, cómo arranca cada app y qué apps preinstaladas se quitan. |
| `ajustes.psd1` | Hora, valores de red, RustDesk, audio, panel y tema de OBS. |

La configuración de los propios programas, como escenas de OBS, perfiles de Stream Deck o fondos, va en la carpeta [assets](assets/README.md).

El código está en `src/Kerma-PCSetup.ps1`, que organiza las fases, en `src/sections`, una sección por archivo, y en `src/lib`, las funciones comunes. Los scripts con tildes se guardan como UTF-8 con BOM, para que Windows PowerShell 5.1 los lea bien. La comprobación de GitHub rechaza tildes sin BOM.

## Qué deja en cada PC

| Ruta o elemento | Para qué |
|---|---|
| `C:\KermaSetup\app\<versión>\` | El script descargado con la línea de instalación. |
| `C:\KermaSetup\downloads\` | Los instaladores descargados. |
| `C:\Kerma\HdmiMirror\` | HDMI Mirror y su configuración. |
| `C:\KermaStartup\<equipo>\` | Un pequeño `.bat` por app con su retardo de arranque. |
| Tareas `<equipo> - <App> Startup` | Abren cada app al iniciar sesión. |
| Tarea `Kerma - Time Sync` | Sincroniza la hora al encender y cada día. |
| `C:\ProgramData\Kerma\` | El script de sincronización de hora y su registro. |
| `C:\KermaSetup\logs\` | Registro completo de cada ejecución del setup. |
| `app-paths.json` junto al script | Rutas de las apps recordadas para las siguientes mesas. |

## Si algo falla

- El script muestra los errores en rojo con el mensaje de Windows y sigue con las demás secciones.
- Abre una incidencia en **[Issues](https://github.com/Vilchaco/kerma-pc-setup/issues/new/choose)** con el formulario *Problema con el script* y pega el log más reciente de `C:\KermaSetup\logs`.

## Mantenimiento

Cómo publicar una versión nueva: [docs/PUBLICAR.md](docs/PUBLICAR.md).
