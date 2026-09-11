# Kerma PC Setup - v3.0.0

> Esta es la versión 3.0.0, publicada el 2026-09-10. Descarga siempre la **[última versión](https://github.com/Vilchaco/kerma-pc-setup/releases/latest)**.

Migración a PowerShell.

## Archivos

- `Kerma-PCSetup.bat`
- `Kerma-PCSetup.ps1`

## Uso

1. En el PC con Windows: clic derecho en el zip, **Propiedades**, marca **Desbloquear** y acepta.
2. Clic derecho en el zip y **Extraer todo**.
3. Doble clic en `Kerma-PCSetup.bat`, que pide permisos de administrador solo.

## Novedades de esta versión

#### Cambiado
- El script se reescribe en PowerShell: `Kerma-PCSetup.ps1`, con el lanzador `Kerma-PCSetup.bat` para seguir usándolo con doble clic. Pide permisos de administrador por sí mismo.
- Mismos menús, nombres de tareas y carpetas que la v2, así que las tareas ya creadas se reemplazan sin problema.

#### Añadido
- Tabla de PCs en la cabecera del script con el nombre, el usuario, el tipo, las apps y la IP de cada equipo.
- Tabla de apps con el retardo de arranque y si se abren maximizadas.
- Valores de red por defecto: máscara 255.255.252.0, puerta de enlace 192.168.0.10, DNS 8.8.8.8 y 1.1.1.1. Solo hay que teclear la IP.
- Registro de cada ejecución en `C:\KermaSetup\logs`.
- Modo desatendido: `Kerma-PCSetup.bat -PC RL01 -Unattended`, con `-Restart` opcional.
- Resumen final con todo lo que se ha cambiado.

#### Eliminado
- `kerma-quitar-password.bat`. Su función está en la sección de login.

Historial completo en [CHANGELOG.md](CHANGELOG.md).
