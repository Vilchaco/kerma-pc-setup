# =====================================================================
#  LIMPIEZA: apps preinstaladas de la Tienda, Microsoft 365 de prueba y
#  OneDrive. La lista de lo que se quita y de lo que nunca se toca esta
#  en config\programas.psd1.
# =====================================================================

function Test-AppNameMatch([string]$name, [string[]]$patterns) {
    foreach ($pat in $patterns) { if ($name -like $pat) { return $true } }
    return $false
}

# Microsoft 365 / Office instalado con Click-to-Run (no es de la Tienda)
function Get-ClickToRunOffice {
    $keys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
    return @(Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.UninstallString -and $_.UninstallString -match 'OfficeClickToRun\.exe' -and $_.DisplayName })
}

function Invoke-RemoveJunk($pc) {
    Write-Section (L 'REMOVE PREINSTALLED APPS  (Solitaire, Xbox, Teams, Office trial...)' 'QUITAR APPS PREINSTALADAS  (Solitario, Xbox, Teams, Office de prueba...)')

    # ---- 1. Apps de la Tienda (instaladas en alguna cuenta o preparadas para cuentas nuevas)
    # -AllUsers falla si Windows no resuelve alguna cuenta (por ejemplo justo
    # tras renombrar el usuario): entonces solo esta cuenta y las nuevas.
    $allUsers = $true
    try { $installed = @(Get-AppxPackage -AllUsers -ErrorAction Stop) }
    catch {
        $allUsers = $false
        Write-Note ((L '  (Windows could not list the apps of every account: {0}' '  (Windows no pudo listar las apps de todas las cuentas: {0}') -f $_.Exception.Message)
        Write-Note (L '   Removing them for this account and for new accounts.)' '   Se quitan de esta cuenta y de las cuentas nuevas.)')
        $installed = @(Get-AppxPackage -ErrorAction SilentlyContinue)
    }
    $provisioned = @()
    try { $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop) }
    catch { Write-Warn ((L 'Could not list the apps for new accounts: {0}' 'No se pudieron listar las apps de cuentas nuevas: {0}') -f $_.Exception.Message) }
    $names = @(@($installed | ForEach-Object { $_.Name }) + @($provisioned | ForEach-Object { $_.DisplayName }) | Sort-Object -Unique |
        Where-Object { (Test-AppNameMatch $_ $RemoveApps) -and -not (Test-AppNameMatch $_ $NeverRemove) })
    if ($names.Count -eq 0) {
        Write-Ok (L 'No junk Store apps found.' 'No hay apps de la Tienda que quitar.')
    } else {
        Write-Host ((L '  Found {0} preinstalled apps to remove:' '  Hay {0} apps preinstaladas que quitar:') -f $names.Count)
        Write-Host ('    ' + ($names -join ', '))
        Write-Host ''
        if (Ask-YesNo (L '  Remove them (and stop Windows from installing suggested apps)?' '  ¿Quitarlas (y que Windows deje de instalar apps sugeridas)?') ([bool]$Prof.RemoveApps)) {
            $removed = 0
            $failed = @()
            foreach ($n in $names) {
                $ok = $true
                foreach ($pkg in @($installed | Where-Object { $_.Name -eq $n })) {
                    try {
                        if ($allUsers) {
                            try { Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop }
                            catch { Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop }
                        } else { Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop }
                    } catch { $ok = $false }
                }
                foreach ($pp in @($provisioned | Where-Object { $_.DisplayName -eq $n })) {
                    try { Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null } catch { $ok = $false }
                }
                if ($ok) { $removed++ } else { $failed += $n }
            }
            Write-Ok ((L '{0} apps removed.' '{0} apps quitadas.') -f $removed)
            if ($failed.Count) { Write-Warn ((L 'Windows did not let these be removed (harmless): {0}' 'Windows no dejó quitar estas (no pasa nada): {0}') -f ($failed -join ', ')) }
            Add-Change ((L 'Removed {0} preinstalled apps' '{0} apps preinstaladas quitadas') -f $removed)

            # que no vuelvan las apps sugeridas (Candy Crush y similares)
            try {
                $cc = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
                Initialize-RegistryKey $cc
                Set-ItemProperty -Path $cc -Name DisableWindowsConsumerFeatures -Value 1 -Type DWord
                $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
                Initialize-RegistryKey $cdm
                foreach ($v in @('SilentInstalledAppsEnabled', 'PreInstalledAppsEnabled', 'OemPreInstalledAppsEnabled',
                                 'SystemPaneSuggestionsEnabled', 'SubscribedContent-338388Enabled')) {
                    Set-ItemProperty -Path $cdm -Name $v -Value 0 -Type DWord
                }
                Write-Ok (L 'Windows will no longer install suggested apps by itself.' 'Windows ya no instalará apps sugeridas por su cuenta.')
            } catch { Write-Warn ((L 'Could not turn off suggested apps: {0}' 'No se pudieron desactivar las apps sugeridas: {0}') -f $_.Exception.Message) }
        } else { Write-Skip (L 'Store apps kept.' 'Apps de la Tienda sin tocar.') }
    }

    # ---- 2. Microsoft 365 / Office de prueba (Click-to-Run)
    Write-Host ''
    $office = Get-ClickToRunOffice
    if ($office.Count -eq 0) {
        Write-Ok (L 'No Microsoft 365 / Office installed.' 'No hay Microsoft 365 / Office instalado.')
    } else {
        foreach ($o in $office) { Write-Host ((L '  Installed: {0}' '  Instalado: {0}') -f $o.DisplayName) }
        if (Ask-YesNo (L '  Uninstall Microsoft 365 / Office? (takes a few minutes)' '  ¿Desinstalar Microsoft 365 / Office? (tarda unos minutos)') ([bool]$Prof.RemoveOffice)) {
            Get-Process -Name 'WINWORD', 'EXCEL', 'POWERPNT', 'OUTLOOK', 'ONENOTE', 'MSACCESS', 'MSPUB' -ErrorAction SilentlyContinue |
                Stop-Process -Force -ErrorAction SilentlyContinue
            foreach ($o in $office) {
                Write-Host ((L '  Uninstalling {0}...' '  Desinstalando {0}...') -f $o.DisplayName)
                $cmd = "$($o.UninstallString) DisplayLevel=False"
                Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$cmd`"" -Wait -WindowStyle Hidden
            }
            $left = Get-ClickToRunOffice
            if ($left.Count -eq 0) {
                Write-Ok (L 'Microsoft 365 / Office uninstalled.' 'Microsoft 365 / Office desinstalado.')
                Add-Change (L 'Removed Microsoft 365 / Office' 'Microsoft 365 / Office quitado')
                $State.NeedsRestart = $true
            } else {
                Write-Warn ((L 'Still installed: {0}. Remove it from Settings > Apps.' 'Sigue instalado: {0}. Quítalo desde Configuración > Aplicaciones.') -f (@($left | ForEach-Object { $_.DisplayName }) -join ', '))
            }
        } else { Write-Skip (L 'Microsoft 365 / Office kept.' 'Microsoft 365 / Office se conserva.') }
    }

    # ---- 3. OneDrive (en Windows 11 es por usuario: se quita de la cuenta de esta ventana)
    Write-Host ''
    $odPaths = @("$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe", "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
                 "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe")
    $odSetup = @("$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not @($odPaths | Where-Object { Test-Path -LiteralPath $_ }).Count) {
        Write-Ok (L 'OneDrive is not installed.' 'OneDrive no está instalado.')
    } elseif (Ask-YesNo (L '  Uninstall OneDrive?' '  ¿Desinstalar OneDrive?') ([bool]$Prof.RemoveOneDrive)) {
        Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        $w = Get-WingetPath
        if ($w) { Invoke-Native $w @('uninstall', '--id', 'Microsoft.OneDrive', '--exact', '--silent', '--accept-source-agreements', '--disable-interactivity') | Out-Null }
        if (@($odPaths | Where-Object { Test-Path -LiteralPath $_ }).Count -and $odSetup) {
            Start-Process -FilePath $odSetup -ArgumentList '/uninstall' -Wait -WindowStyle Hidden
        }
        if (@($odPaths | Where-Object { Test-Path -LiteralPath $_ }).Count) {
            Write-Warn (L 'OneDrive is still there. Remove it from Settings > Apps.' 'OneDrive sigue ahí. Quítalo desde Configuración > Aplicaciones.')
        } else {
            Write-Ok ((L "OneDrive uninstalled (for user '{0}')." "OneDrive desinstalado (para '{0}').") -f $env:USERNAME)
            Add-Change (L 'Removed OneDrive' 'OneDrive quitado')
        }
    } else { Write-Skip (L 'OneDrive kept.' 'OneDrive se conserva.') }
}
