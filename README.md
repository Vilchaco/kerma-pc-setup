# Kerma PC Setup

[![Lint](https://github.com/Vilchaco/kerma-pc-setup/actions/workflows/lint.yml/badge.svg)](https://github.com/Vilchaco/kerma-pc-setup/actions/workflows/lint.yml)
[![Última versión](https://img.shields.io/badge/descargar-%C3%BAltima%20versi%C3%B3n-2ea44f)](https://github.com/Vilchaco/kerma-pc-setup/releases/latest)

Script para dejar listo un PC del casino de Kerma Games en unos minutos: mesas de juego, PC de supervisores y PC del despacho. Pregunta paso a paso, valida cada dato y deja un registro de todo lo que cambia.

## Descargar

Descarga siempre la **[última versión](https://github.com/Vilchaco/kerma-pc-setup/releases/latest)**. El zip está en el apartado **Assets** de la release. Las notas de cada versión están en [CHANGELOG.md](CHANGELOG.md).

## Uso

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
| Autoarranque | Crea una tarea por app para que se abra al iniciar sesión, con su retardo y maximizada si se quiere. |
| Resumen | Lista todo lo que ha cambiado y ofrece reiniciar. |

## Tipos de PC

| Tipo | PCs | Comportamiento |
|---|---|---|
| Mesa | Ruleta, Blackjack, Blackjack Unlimited, Craps | Sin contraseña, actualizaciones manuales, apps de mesa: scanner, StreamDeck, Dealer App, Mirror y OBS. |
| Supervisor | Supervisor 01 y 02 | Recomienda mantener la contraseña y las actualizaciones automáticas. Sin autoarranque de apps. |
| Despacho | PC de Hector | Igual que una mesa, pero sus apps son Deskflow y el programa de cámaras. |

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

El script debe seguir siendo **solo ASCII**, sin tildes ni eñes. La comprobación automática de GitHub rechaza cualquier otro carácter.

## Qué deja en cada PC

| Ruta o elemento | Para qué |
|---|---|
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
