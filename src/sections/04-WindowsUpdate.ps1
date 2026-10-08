# =====================================================================
#  WINDOWS UPDATE: solo manual / desactivado / automatico / sin tocar
# =====================================================================

function Invoke-WindowsUpdateSetup($pc) {
    Write-Section 'WINDOWS UPDATE'
    $edition = 'unknown'
    try { $edition = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID } catch { }
    Write-Host ((L '  Windows edition: {0}' '  Edición de Windows: {0}') -f $edition)
    Write-Host ''

    $options = @(
        (L "Manual updates only  (tables / office)`n     - Windows never downloads, installs or reboots on its own, and stops pushing drivers.`n     - You still install updates by hand in Settings > Windows Update during maintenance." `
           "Solo actualizaciones manuales  (mesas / oficina)`n     - Windows nunca descarga, instala ni reinicia por su cuenta, y no mete drivers.`n     - Se siguen pudiendo instalar a mano en Configuración > Windows Update en mantenimiento."),
        (L "Disable Windows Update completely`n     - same as 1, plus the Windows Update service is stopped and disabled." `
           "Desactivar Windows Update del todo`n     - lo mismo que 1 y además se para y desactiva el servicio."),
        (L 'Restore automatic updates  (undo 1 or 2)' 'Volver a las actualizaciones automáticas  (deshace 1 o 2)'),
        (L 'Leave Windows Update as it is now.' 'Dejar Windows Update como está.')
    )
    if ($edition -like 'Core*') {
        Write-Note (L '>> Windows HOME: Home does not fully honor the policy of option 1. Option 2 is the reliable one.' '>> Windows HOME: Home no respeta del todo la directiva de la opción 1. La opción 2 es la fiable.')
        Write-Host ''
    }
    $default = switch ($Prof.WindowsUpdate) { 'Manual' { 0 } 'Disabled' { 1 } 'Automatic' { 2 } default { 3 } }
    $choice  = Ask-Choice (L '  Choose' '  Elige') $options $default

    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $au = "$wu\AU"
    $applyPolicy = {
        Initialize-RegistryKey $au
        Set-ItemProperty -Path $au -Name NoAutoUpdate                    -Value 1 -Type DWord
        Set-ItemProperty -Path $au -Name NoAutoRebootWithLoggedOnUsers   -Value 1 -Type DWord
        Set-ItemProperty -Path $wu -Name ExcludeWUDriversInQualityUpdate -Value 1 -Type DWord
    }

    switch ($choice) {
        0 {
            & $applyPolicy
            Set-Service -Name wuauserv -StartupType Manual
            Write-Ok (L 'Windows Update: MANUAL ONLY - no automatic download, install, reboot or drivers.' 'Windows Update: SOLO MANUAL, sin descargas, instalaciones, reinicios ni drivers automáticos.')
            Add-Change (L 'Windows Update: manual only' 'Windows Update: solo manual')
        }
        1 {
            & $applyPolicy
            Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
            Set-Service  -Name wuauserv -StartupType Disabled
            Write-Ok (L 'Windows Update DISABLED - policy applied and service stopped. Run again with option 3 to undo.' 'Windows Update DESACTIVADO: directiva aplicada y servicio parado. Vuelve a pasar el script con la opción 3 para deshacerlo.')
            Add-Change (L 'Windows Update: disabled' 'Windows Update: desactivado')
        }
        2 {
            Remove-ItemProperty -Path $au -Name NoAutoUpdate                    -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $au -Name NoAutoRebootWithLoggedOnUsers   -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $wu -Name ExcludeWUDriversInQualityUpdate -ErrorAction SilentlyContinue
            Set-Service   -Name wuauserv -StartupType Manual
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
            Write-Ok (L 'Automatic updates restored to the Windows defaults.' 'Actualizaciones automáticas restauradas a lo normal de Windows.')
            Add-Change (L 'Windows Update: automatic' 'Windows Update: automático')
        }
        default { Write-Skip (L 'Windows Update left unchanged.' 'Windows Update sin cambios.') }
    }
}
