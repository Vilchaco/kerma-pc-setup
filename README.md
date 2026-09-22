# Kerma PC Setup - v3.1.0

> Esta es la versión 3.1.0, publicada el 2026-09-22. Descarga siempre la **[última versión](https://github.com/Vilchaco/kerma-pc-setup/releases/latest)**.

Rutas de las apps al vuelo.

## Archivos

- `Kerma-PCSetup.bat`
- `Kerma-PCSetup.ps1`

## Uso

1. En el PC con Windows: clic derecho en el zip, **Propiedades**, marca **Desbloquear** y acepta.
2. Clic derecho en el zip y **Extraer todo**.
3. Doble clic en `Kerma-PCSetup.bat`, que pide permisos de administrador solo.

## Novedades de esta versión

#### Añadido
- Ya no hay que editar el script para poner las rutas de las apps. Al activar una app, el script pide su programa: se puede pegar la ruta o pulsar **B** para buscarla con la ventana de Windows.
- Comprobación de cada ruta: que existe, que es un programa `.exe`, `.bat` o `.cmd`, y que es una ruta completa. Muestra el nombre y el fabricante del programa para confirmar que es el correcto.
- Si se elige un acceso directo, se usa el programa al que apunta.
- Prueba opcional que abre la app una vez para ver que arranca.
- Las rutas se recuerdan en `app-paths.json` junto al script. En las siguientes mesas basta con pulsar Enter, y el modo desatendido también las usa.
- Si una ruta recordada está en el Escritorio de otra mesa, se busca en el mismo sitio del perfil de la mesa actual.

#### Cambiado
- Cada app arranca desde su propia carpeta. Antes solo lo hacía OBS.

#### Corregido
- Crear la tarea de autoarranque fallaba con *The parameter is incorrect*. Las tareas se asocian ahora al grupo Usuarios de Windows, que no depende del nombre de la cuenta ni del idioma. Si aun así falla, se intenta con `schtasks.exe`, y si fallan los dos se muestran ambos errores.

Historial completo en [CHANGELOG.md](CHANGELOG.md).
