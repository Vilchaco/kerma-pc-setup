# Kerma PC Setup - v2.0.0

> Esta es la versión 2.0.0, publicada el 2026-09-10. Descarga siempre la **[última versión](https://github.com/Vilchaco/kerma-pc-setup/releases/latest)**.

Auditoría y nuevas secciones.

## Archivos

- `kerma-pc-setup.bat`
- `kerma-quitar-password.bat`

## Uso

1. En el PC con Windows: clic derecho en el zip, **Propiedades**, marca **Desbloquear** y acepta.
2. Clic derecho en el zip y **Extraer todo**.
3. Clic derecho en `kerma-pc-setup.bat` y **Ejecutar como administrador**.

## Novedades de esta versión

#### Corregido
- El auto-login dejaba de funcionar después de renombrar el equipo, porque se guardaba el nombre antiguo.
- Los errores de PowerShell no se detectaban, así que el script mostraba `[OK]` aunque el renombrado fallara.
- Las contraseñas con caracteres especiales como `!` o `%` se guardaban mal. Ahora se escriben ocultas.
- Saltar el renombrado hacía que se ofrecieran las apps de mesa en cualquier PC.

#### Añadido
- Comprobación de permisos de administrador al empezar.
- Login sin contraseña, recomendado en las mesas, además del auto-login con contraseña guardada.
- `kerma-quitar-password.bat` para quitar la contraseña en los PCs ya configurados.
- PCs de supervisores y PC del despacho de Hector, con cámaras y Deskflow, cada uno con sus propias apps.
- Sección de **Windows Update**: solo manual, desactivado del todo o restaurar.
- Sección de **red**: elegir el adaptador y poner una IP fija o volver a DHCP, con validación de cada dato.
- Aviso si la ruta de una app no existe, y oferta de reinicio al final.

#### Cambiado
- Siempre se elige qué PC es, y el renombrado pasa a ser opcional.
- Las secciones de cada app se unifican en una sola subrutina.

Historial completo en [CHANGELOG.md](CHANGELOG.md).
