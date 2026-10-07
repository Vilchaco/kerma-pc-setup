# OBS Studio

Todo lo que pongas aquí se copia tal cual dentro de `%APPDATA%\obs-studio\` del PC, respetando las carpetas. Antes se guarda una copia de seguridad de lo que hubiera.

Cópialo desde una mesa ya configurada, con OBS cerrado:

| Copia esto de la mesa | Aquí |
|---|---|
| `%APPDATA%\obs-studio\global.ini` | `obs/global.ini` |
| `%APPDATA%\obs-studio\basic\scenes\<Escenas>.json` | `obs/basic/scenes/<Escenas>.json` |
| `%APPDATA%\obs-studio\basic\profiles\<Perfil>\` | `obs/basic/profiles/<Perfil>/` |

Con `global.ini` incluido, OBS no muestra el asistente de primera configuración y abre directamente con esas escenas y ese perfil.

Los filtros de audio de cada fuente, incluido el de atkAudio con el VST3 de cancelación de ruido, se guardan dentro del archivo de escenas. El plugin atkAudio lo instala el script y el VST3 va en la carpeta `vst3`.

No copies `service.json`: guarda la clave de emisión y el repositorio es público. El script lo ignora y la comprobación automática lo rechaza.
