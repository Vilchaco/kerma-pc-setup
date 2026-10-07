# OBS Studio

Todo lo que pongas aquí se copia tal cual dentro de `%APPDATA%\obs-studio\` del PC, respetando las carpetas. Antes se guarda una copia de seguridad de lo que hubiera.

Cópialo desde una mesa ya configurada, con OBS cerrado:

| Copia esto de la mesa | Aquí |
|---|---|
| `%APPDATA%\obs-studio\global.ini` | `obs/global.ini` |
| `%APPDATA%\obs-studio\basic\scenes\<Escenas>.json` | `obs/basic/scenes/<Escenas>.json` |
| `%APPDATA%\obs-studio\basic\profiles\<Perfil>\` | `obs/basic/profiles/<Perfil>/` |

Con `global.ini` incluido, OBS no muestra el asistente de primera configuración y abre directamente con esas escenas y ese perfil.

Si la cancelación de ruido es el filtro que trae OBS de serie, *Supresión de ruido*, se guarda dentro del archivo de escenas y no hace falta nada más. Si es un plugin aparte, hay que añadirlo a la instalación.
