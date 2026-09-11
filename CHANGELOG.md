# Historial de cambios

Todas las versiones de Kerma PC Setup, de la más reciente a la más antigua. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y la numeración sigue el [versionado semántico](https://semver.org/lang/es/).

## [3.0.0] - 2026-09-10 - Migración a PowerShell

### Cambiado
- El script se reescribe en PowerShell: `Kerma-PCSetup.ps1`, con el lanzador `Kerma-PCSetup.bat` para seguir usándolo con doble clic. Pide permisos de administrador por sí mismo.
- Mismos menús, nombres de tareas y carpetas que la v2, así que las tareas ya creadas se reemplazan sin problema.

### Añadido
- Tabla de PCs en la cabecera del script con el nombre, el usuario, el tipo, las apps y la IP de cada equipo.
- Tabla de apps con el retardo de arranque y si se abren maximizadas.
- Valores de red por defecto: máscara 255.255.252.0, puerta de enlace 192.168.0.10, DNS 8.8.8.8 y 1.1.1.1. Solo hay que teclear la IP.
- Registro de cada ejecución en `C:\KermaSetup\logs`.
- Modo desatendido: `Kerma-PCSetup.bat -PC RL01 -Unattended`, con `-Restart` opcional.
- Resumen final con todo lo que se ha cambiado.

### Eliminado
- `kerma-quitar-password.bat`. Su función está en la sección de login.

## [2.0.0] - 2026-09-10 - Auditoría y nuevas secciones

### Corregido
- El auto-login dejaba de funcionar después de renombrar el equipo, porque se guardaba el nombre antiguo.
- Los errores de PowerShell no se detectaban, así que el script mostraba `[OK]` aunque el renombrado fallara.
- Las contraseñas con caracteres especiales como `!` o `%` se guardaban mal. Ahora se escriben ocultas.
- Saltar el renombrado hacía que se ofrecieran las apps de mesa en cualquier PC.

### Añadido
- Comprobación de permisos de administrador al empezar.
- Login sin contraseña, recomendado en las mesas, además del auto-login con contraseña guardada.
- `kerma-quitar-password.bat` para quitar la contraseña en los PCs ya configurados.
- PCs de supervisores y PC del despacho de Hector, con cámaras y Deskflow, cada uno con sus propias apps.
- Sección de **Windows Update**: solo manual, desactivado del todo o restaurar.
- Sección de **red**: elegir el adaptador y poner una IP fija o volver a DHCP, con validación de cada dato.
- Aviso si la ruta de una app no existe, y oferta de reinicio al final.

### Cambiado
- Siempre se elige qué PC es, y el renombrado pasa a ser opcional.
- Las secciones de cada app se unifican en una sola subrutina.

## [1.0.0] - 2026-08-28 - Versión inicial

### Añadido
- Script `.bat` original: elegir la mesa, renombrar el usuario, el equipo y el nombre completo, auto-login con contraseña guardada, y autoarranque de cinco apps con retardo y opción de abrirlas maximizadas.
