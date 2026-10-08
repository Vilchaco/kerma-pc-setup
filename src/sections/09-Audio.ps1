# =====================================================================
#  AUDIO: sin sonidos de Windows; la Scarlett como micro y salida
# =====================================================================

function Initialize-AudioModule {
    if (Get-Module -ListAvailable -Name AudioDeviceCmdlets) { Import-Module AudioDeviceCmdlets; return $true }
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        Install-Module -Name AudioDeviceCmdlets -Repository PSGallery -Force -Scope AllUsers -AllowClobber
        Import-Module AudioDeviceCmdlets
        return $true
    } catch {
        Write-Warn ((L 'Could not install the audio module (AudioDeviceCmdlets): {0}' 'No se pudo instalar el módulo de audio (AudioDeviceCmdlets): {0}') -f $_.Exception.Message)
        return $false
    }
}

function Invoke-AudioSetup($pc) {
    Write-Section (L 'AUDIO  (Windows sounds, Scarlett)' 'AUDIO  (sonidos de Windows, Scarlett)')
    Write-Host (L '  - Windows sounds off (no beeps on the stream), no startup sound' '  - Sin sonidos de Windows (nada de pitidos en la emisión) ni sonido de inicio')
    Write-Host (L '  - Focusrite Scarlett as the default microphone and speakers, if connected' '  - La Focusrite Scarlett como micro y salida predeterminados, si está conectada')
    Write-Host ''
    if (-not (Ask-YesNo (L '  Apply these audio settings?' '  ¿Aplicar estos ajustes de audio?') ([bool]$Prof.Audio))) { Write-Skip (L 'Audio left unchanged.' 'Audio sin cambios.'); return }

    # ---- sonidos de Windows: esquema "Sin sonidos" para esta cuenta + sin sonido de inicio
    try {
        Set-ItemProperty -Path 'HKCU:\AppEvents\Schemes' -Name '(Default)' -Value '.None'
        Get-ChildItem -Path 'HKCU:\AppEvents\Schemes\Apps' -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -eq '.Current' } |
            ForEach-Object { Set-ItemProperty -Path $_.PSPath -Name '(Default)' -Value '' -ErrorAction SilentlyContinue }
        $boot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation'
        Initialize-RegistryKey $boot
        Set-ItemProperty -Path $boot -Name DisableStartupSound -Value 1 -Type DWord
        Write-Ok ((L "Windows sounds off (user '{0}') and no startup sound." "Sonidos de Windows quitados ('{0}') y sin sonido de inicio.") -f $env:USERNAME)
        Add-Change ((L 'Audio: Windows sounds off ({0})' 'Audio: sin sonidos de Windows ({0})') -f $env:USERNAME)
    } catch { Write-Warn ((L 'Windows sounds: {0}' 'Sonidos de Windows: {0}') -f $_.Exception.Message) }

    # ---- Scarlett predeterminada
    Write-Host ''
    $fr = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like 'USB\VID_1235*' })
    if ($fr.Count -eq 0) { Write-Skip (L 'Scarlett: no Focusrite connected.' 'Scarlett: no hay ninguna Focusrite conectada.'); return }
    if (-not (Initialize-AudioModule)) { return }
    $devs = @(Get-AudioDevice -List | Where-Object { $_.Name -match 'Focusrite|Scarlett' })
    $rec  = $devs | Where-Object { $_.Type -eq 'Recording' } | Select-Object -First 1
    $play = $devs | Where-Object { $_.Type -eq 'Playback' } | Select-Object -First 1
    if (-not $rec) {
        Write-Warn (L 'The Scarlett is connected but Windows does not show it as a microphone yet.' 'La Scarlett está conectada, pero Windows aún no la muestra como micro.')
        Write-Note (L '  Unplug and plug it again (or restart) after Focusrite Control 2 is installed, then run the script again.' '  Desenchúfala y vuelve a enchufarla (o reinicia) tras instalar Focusrite Control 2, y pasa otra vez el script.')
        return
    }
    Set-AudioDevice -ID $rec.ID | Out-Null
    Write-Ok ((L 'Default microphone: {0}' 'Micro predeterminado: {0}') -f $rec.Name)
    Add-Change ((L 'Audio: default microphone {0}' 'Audio: micro predeterminado {0}') -f $rec.Name)
    if ($ScarlettAsDefaultPlayback -and $play) {
        Set-AudioDevice -ID $play.ID | Out-Null
        Write-Ok ((L 'Default speakers: {0}' 'Salida predeterminada: {0}') -f $play.Name)
        Add-Change ((L 'Audio: default speakers {0}' 'Audio: salida predeterminada {0}') -f $play.Name)
    }
}
