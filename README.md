# Kerma PC Setup

[![Lint](https://github.com/Vilchaco/kerma-pc-setup/actions/workflows/lint.yml/badge.svg)](https://github.com/Vilchaco/kerma-pc-setup/actions/workflows/lint.yml)
[![Última versión](https://img.shields.io/badge/descargar-%C3%BAltima%20versi%C3%B3n-2ea44f)](https://github.com/Vilchaco/kerma-pc-setup/releases/latest)

Script para dejar listo un PC del casino de Kerma Games en unos minutos: mesas de juego, PC de supervisores y PC del despacho. Pregunta paso a paso, valida cada dato y deja un registro de todo lo que cambia.

## Instalar en un PC nuevo con una línea

1. Conecta el PC a internet.
2. Abre **PowerShell**: clic derecho en el botón de Inicio y **Terminal** o **Windows PowerShell**.
3. Pega esta línea y pulsa Enter:

```powershell
irm https://raw.githubusercontent.com/Vilchaco/kerma-pc-setup/main/bootstrap.ps1 | iex
```

Desde **CMD** la línea es esta:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/Vilchaco/kerma-pc-setup/main/bootstrap.ps1 | iex"
```

El script se descarga en `C:\KermaSetup\app`, pide permisos de administrador y empieza. Responde a cada sección y reinicia al final.

> **Seguridad.** Esa línea ejecuta como administrador lo que haya en este repositorio. Cualquiera con permiso de escritura en él decide lo que se instala en los PCs de la empresa. Revisa con cuidado quién tiene ese permiso.

## Descargar el zip

También puedes descargar la **[última versión](https://github.com/Vilchaco/kerma-pc-setup/releases/latest)** a mano. El zip está en el apartado **Assets** de la release. Las notas de cada versión están en [CHANGELOG.md](CHANGELOG.md).

## Uso con el zip

1. Copia el zip al PC con Windows, por ejemplo con un USB.
2. Clic derecho en el zip, **Propiedades**, marca **Desbloquear** y acepta. Sin esto Windows puede bloquear el script por venir de internet.
3. Clic derecho en el zip y **Extraer todo**. No lo ejecutes desde dentro del zip, porque así no puede recordar las rutas de las apps.
4. Doble clic en `Kerma-PCSetup.bat`. Acepta el aviso de permisos de administrador.
5. Elige qué PC es y responde a cada sección. Todas se pueden saltar.

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
| Ajustes del PC | Pantalla siempre encendida, sin suspensión, USB sin ahorro de energía, sin notificaciones ni salvapantallas. |
| Instalar programas | Instala o actualiza los programas de ese tipo de PC. |
| Configuración de programas | Aplica la configuración guardada de HDMI Mirror, OBS y Stream Deck. |
| Autoarranque | Crea una tarea por app para que se abra al iniciar sesión, con su retardo y maximizada si se quiere. |
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

Las listas por tipo de PC están en `$InstallByType`, en la cabecera del script.

## Modo desatendido

Para reinstalar un PC sin responder preguntas. Abre una consola en la carpeta del script:

```bat
Kerma-PCSetup.bat -PC RL01 -Unattended
Kerma-PCSetup.bat -PC HECTOR -Unattended -Restart
```

Las claves de cada PC están en la tabla de la cabecera del script. En este modo solo se configuran las apps con una ruta ya recordada, y la red solo si ese PC tiene IP en la tabla.

## Configuración

Todo se edita en los bloques `CONFIG` del principio de `Kerma-PCSetup.ps1`:

- **Añadir un PC:** copia una línea de la tabla `$PCs` y cambia sus datos.
- **IPs fijas:** rellena `IP` en la línea de cada PC. La máscara, la puerta de enlace y las DNS se toman de `$NetDefaults`.
- **Apps:** el retardo y si se abren maximizadas, en la tabla `$Apps`. Las rutas no hace falta ponerlas: se piden al configurar.
- **Hora:** zona horaria, servidores de hora y hora de la sincronización diaria.
- **Programas:** la tabla `$Packages` y las listas `$InstallByType`.
- **Configuración de los programas:** se guarda en la carpeta [assets](assets/README.md), no en el script.

El script debe seguir siendo **solo ASCII**, sin tildes ni eñes. La comprobación automática de GitHub rechaza cualquier otro carácter.

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
