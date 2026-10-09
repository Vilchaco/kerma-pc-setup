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

## Lo que hay ahora (exportado de BJ01, 9-oct-2026)

- **Escenas** `basic/scenes/Untitled.json`: una escena con una fuente *Audio Input Capture*. La fuente usa el dispositivo **Predeterminado** (la Scarlett, porque el setup la deja como micro predeterminado), con monitorización *Monitor and Output* y dos filtros: **Compressor** y **atkAudio PluginHost** con **Alt Denoiser**.
- **Perfil** `basic/profiles/Untitled/`: 1920x1080 a 30 fps y monitorización por la salida predeterminada.
- **Ventanas** `user.ini`: posición de la ventana y de los paneles, incluido el de Alt Denoiser, y el tema Kerma.
- `global.ini` sin la sección `[Locations]` (eran rutas del usuario de BJ01) y sin actualizaciones automáticas.

Al copiar, el script cambia cualquier micro o salida concreta (`device_id`, `MonitoringDeviceId`) por el **predeterminado**: el identificador de un dispositivo solo existe en el PC donde se eligió.

Alt Denoiser no tiene licencia publicada, así que no se sube aquí. El script lo baja de su release en GitHub (Altinus/Alt-Denoiser, versión fija v1.0.1) y lo deja en `C:\Program Files\Common Files\VST3\Alt-Denoiser.vst3`, que es donde lo busca el filtro. El plugin atkAudio también lo instala el script.

Para cambiar la configuración: déjala como quieras en una mesa, cierra OBS y vuelve a exportar `basic`, `global.ini` y `user.ini`.

No copies `service.json`: guarda la clave de emisión y el repositorio es público. El script lo ignora y la comprobación automática lo rechaza.
