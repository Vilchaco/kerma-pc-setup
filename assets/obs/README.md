# OBS Studio

Todo lo que pongas aquí se copia tal cual dentro de `%APPDATA%\obs-studio\` del PC, respetando las carpetas. Antes se guarda una copia de seguridad de lo que hubiera.

Cópialo desde una mesa ya configurada, con OBS cerrado:

| Copia esto de la mesa | Aquí |
|---|---|
| `%APPDATA%\obs-studio\global.ini` | `obs/global.ini` |
| *(ya incluido)* | `obs/themes/Kerma.ovt` |
| `%APPDATA%\obs-studio\basic\scenes\<Escenas>.json` | `obs/basic/scenes/<Escenas>.json` |
| `%APPDATA%\obs-studio\basic\profiles\<Perfil>\` | `obs/basic/profiles/<Perfil>/` |

Con `global.ini` incluido, OBS no muestra el asistente de primera configuración y abre directamente con esas escenas y ese perfil.

Desde OBS 31, el idioma, el tema y la posición de las ventanas van en `user.ini`. Si lo incluyes aquí se copia como los demás, y después el script cambia solo su línea del tema.

## Tema Kerma

`themes/Kerma.ovt` es el aspecto de Kerma para OBS: los colores de Kerma Shifts (fondo casi negro y dorado) sobre el tema normal de OBS. El script lo copia a `%APPDATA%\obs-studio\themes\` y, si contestas que sí, lo deja elegido. Siempre se puede cambiar en *Ajustes › Apariencia*.

Para probar cambios de colores en una mesa sin pasar el script: copia `Kerma.ovt` a `%APPDATA%\obs-studio\themes\`, abre OBS y elige *Kerma* en *Ajustes › Apariencia*. Si el archivo tuviera un error, OBS abre con su tema normal; nunca deja de arrancar.

Los filtros de audio de cada fuente, incluido el de atkAudio con el VST3 de cancelación de ruido, se guardan dentro del archivo de escenas. El plugin atkAudio lo instala el script y el VST3 va en la carpeta `vst3`.

No copies `service.json`: guarda la clave de emisión y el repositorio es público. El script lo ignora y la comprobación automática lo rechaza.
