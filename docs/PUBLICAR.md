# Cómo publicar una versión nueva

Guía para quien mantiene el script. Los técnicos solo necesitan descargar la última release.

## 1. Hacer el cambio

> La línea de instalación descarga siempre la **última release**, no lo que haya en `main`. Un cambio no llega a los PCs hasta que publicas una versión. La excepción es `bootstrap.ps1`, que se lee directamente de `main`: cualquier cambio en él afecta al momento.

- Para añadir un PC o cambiar qué se hace en cada tipo, edita `src/config/*.psd1`: no hace falta tocar código.
- Para cambiar el comportamiento de una sección, edita su archivo en `src/sections`.
- Antes de publicar, `Kerma-PCSetup.bat -ValidateConfig` comprueba la configuración. GitHub lo ejecuta también.
- Sube el número de versión en dos sitios del propio script: la línea `$ScriptVersion = '...'` y la cabecera `Kerma Games - PC Setup (vX.Y.Z - PowerShell)`.
- Los archivos con tildes o eñes se guardan como **UTF-8 con BOM**. Sin BOM, Windows PowerShell 5.1 los lee mal, y la comprobación automática lo rechaza.

## 2. Elegir el número

| Tipo de cambio | Ejemplo | Número |
|---|---|---|
| Arreglo de un fallo | La tarea de una app no se crea | 3.2.0 pasa a 3.2.1 |
| Función nueva | Sección nueva o pregunta nueva | 3.2.0 pasa a 3.3.0 |
| Cambio grande que rompe lo anterior | Reescritura, nombres de tareas distintos | 3.2.0 pasa a 4.0.0 |

## 3. Escribir las notas en `CHANGELOG.md`

Añade arriba una sección con este formato exacto. El título que va detrás de la fecha es el nombre de la release:

```markdown
## [3.2.1] - 2026-10-20 - Arreglo del autoarranque

### Corregido
- Qué fallaba y qué hace ahora, en una o dos frases.
```

## 4. Publicar

```bash
git add -A
git commit -m "v3.2.1: arreglo del autoarranque"
git tag -a v3.2.1 -m "v3.2.1"
git push --follow-tags
```

GitHub hace el resto solo:

- **Lint** comprueba el script con el mismo Windows PowerShell 5.1 de los PCs del casino.
- **Release** construye `Kerma_PC_Setup-v3.2.1.zip`, crea la release con las notas del CHANGELOG y la marca como la última.

Revisa la pestaña **Actions**. Si Lint sale en rojo, abre el error, corrígelo y publica un arreglo con un número nuevo.
