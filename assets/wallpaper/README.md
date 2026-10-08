# Fondo de pantalla

`base.jpg` es la plantilla de todos los PCs: 1920x1080, con el logo de Kerma y los personajes. El script dibuja debajo del logo una tarjeta con el tipo de PC en su color, el nombre del PC, la IP y el nombre de equipo, usando las fuentes de `assets/fonts`.

- **Textos y colores de cada tipo:** `src/config/ajustes.psd1`, en `Wallpaper.Tags`.
- **Nombre de cada PC:** el `Label` del inventario, o `WallpaperText` si se quiere otro. Con `|` se parte en dos líneas.

Si se cambia `base.jpg`, deja libre la zona de la izquierda bajo el logo, a partir de unos 520 píxeles de altura, porque ahí va la tarjeta.
