# Configuración de los programas

Todo lo que pongas aquí viaja dentro de la release y el script lo aplica en la sección **Program settings**. Si falta un archivo, el script lo dice y sigue.

| Carpeta | Qué va dentro | Dónde lo pone el script |
|---|---|---|
| `hdmi-mirror/` | La configuración de HDMI Mirror de cada mesa | Junto a `C:\Kerma\HdmiMirror\HdmiMirror.exe` |
| `obs/` | Escenas, perfil y ajustes de OBS | `%APPDATA%\obs-studio\` del usuario de la mesa |
| `streamdeck/` | Un perfil de Stream Deck por juego | Se abre con la app de Stream Deck para importarlo |
| `vst3/` | Plugins VST3 para OBS | `C:\Program Files\Common Files\VST3\` |

Cada carpeta tiene su propio README con los nombres de archivo exactos.

> **Este repositorio es público.** No subas nada secreto. El script nunca copia el `service.json` de OBS, que guarda la clave de emisión, y la comprobación automática rechaza cualquier cambio que lo incluya.
