# =====================================================================
#  IDENTIDAD: nombre de equipo, usuario y nombre completo estandar;
#  inicio de sesion (sin contrasena = arranca solo tras un apagon)
# =====================================================================

function Invoke-Rename($pc) {
    Write-Section (L 'NAMES  (computer, user, full name)' 'NOMBRES  (equipo, usuario, nombre completo)')
    Write-Host ((L '    Computer name : {0}  ->  {1}' '    Nombre de equipo : {0}  ->  {1}') -f $env:COMPUTERNAME, $pc.Hostname)
    Write-Host ((L '    Username      : {0}  ->  {1}' '    Usuario          : {0}  ->  {1}') -f $env:USERNAME, $pc.Username)
    Write-Host ((L '    Full name     : {0}' '    Nombre completo  : {0}') -f $pc.FullName)
    Write-Host ''
    if (-not (Ask-YesNo (L '  Rename this PC now?' '  ¿Renombrar este PC ahora?') ([bool]$Prof.Rename))) { Write-Skip (L 'Names left as they are.' 'Nombres sin cambios.'); return }
    Write-Host ''

    # -- usuario (primero: mas seguro que renombrar antes el equipo)
    if ($env:USERNAME -ieq $pc.Username) {
        Write-Ok ((L 'Username is already {0}.' 'El usuario ya es {0}.') -f $pc.Username)
        $State.UserRenamed = $true
    } else {
        try {
            Rename-LocalUser -Name $env:USERNAME -NewName $pc.Username
            $State.UserRenamed = $true
            Write-Ok ((L 'Username renamed to {0}.' 'Usuario renombrado a {0}.') -f $pc.Username)
            Write-Note ((L 'The profile folder stays as C:\Users\{0} - normal Windows behavior.' 'La carpeta del perfil sigue siendo C:\Users\{0}: es lo normal en Windows.') -f $env:USERNAME)
            Add-Change ((L 'Username: {0} -> {1}' 'Usuario: {0} -> {1}') -f $env:USERNAME, $pc.Username)
        } catch {
            Write-Fail ((L 'Username rename: {0}' 'Renombrar usuario: {0}') -f $_.Exception.Message)
            Write-Note (L 'Common cause: the new name is already taken. You can rename it by hand in lusrmgr.msc.' 'Causa habitual: el nombre nuevo ya existe. Se puede renombrar a mano en lusrmgr.msc.')
        }
    }

    # -- nombre completo
    if ($State.UserRenamed) {
        try {
            Set-LocalUser -Name $pc.Username -FullName $pc.FullName
            Write-Ok ((L 'Full name set to {0}.' 'Nombre completo: {0}.') -f $pc.FullName)
        } catch { Write-Warn ((L 'Full name not set (not critical): {0}' 'No se puso el nombre completo (no es grave): {0}') -f $_.Exception.Message) }
    }

    # -- nombre de equipo
    if ($env:COMPUTERNAME -ieq $pc.Hostname) {
        Write-Ok ((L 'Computer name is already {0}.' 'El equipo ya se llama {0}.') -f $pc.Hostname)
        $State.HostRenamed = $true
    } else {
        try {
            Rename-Computer -NewName $pc.Hostname -Force -WarningAction SilentlyContinue
            $State.HostRenamed  = $true
            $State.NeedsRestart = $true
            Write-Ok ((L 'Computer renamed to {0} (applies after the restart).' 'Equipo renombrado a {0} (se aplica al reiniciar).') -f $pc.Hostname)
            Add-Change ((L 'Computer name: {0} -> {1} (after restart)' 'Nombre de equipo: {0} -> {1} (al reiniciar)') -f $env:COMPUTERNAME, $pc.Hostname)
        } catch { Write-Fail ((L 'Computer rename: {0}' 'Renombrar equipo: {0}') -f $_.Exception.Message) }
    }
}

function Invoke-LoginSetup($pc) {
    Write-Section (L 'LOGIN  (boot straight to the desktop)' 'INICIO DE SESIÓN  (arrancar directo al escritorio)')
    # Nombres nuevos solo si el renombrado se hizo de verdad (o ya coincidian):
    # un DefaultDomainName viejo rompe el inicio automatico sin avisar.
    $user   = if ($State.UserRenamed) { $pc.Username } else { $env:USERNAME }
    $domain = if ($State.HostRenamed) { $pc.Hostname } else { $env:COMPUTERNAME }

    $options = @(
        (L "Remove the password entirely  (tables / office)`n     - blank password + auto-login: boots straight to the desktop after a power cut. Nothing stored.`n     - Windows blocks remote use (RDP, shared folders) of blank-password accounts." `
           "Quitar la contraseña del todo  (mesas / oficina)`n     - contraseña en blanco + inicio automático: arranca solo tras un apagón. No se guarda nada.`n     - Windows bloquea el uso remoto (RDP, carpetas compartidas) de cuentas sin contraseña."),
        (L "Keep the password, store it for auto-login`n     - saved in the registry in PLAIN TEXT (same as netplwiz). Only if you need RDP into this account." `
           "Mantener la contraseña y guardarla para el inicio automático`n     - se guarda en el registro SIN CIFRAR (igual que netplwiz). Solo si necesitas RDP en esta cuenta."),
        (L 'Leave login exactly as it is now.' 'Dejar el inicio de sesión como está.')
    )
    if ($Prof.Login -eq 'Keep') {
        Write-Note (L '>> This PC type keeps its password: anyone could open it otherwise. Option 3 is the default.' '>> Este tipo de PC conserva su contraseña: si no, cualquiera podría abrirlo. La opción 3 es la recomendada.')
        Write-Host ''
    }
    $default = if ($Prof.Login -eq 'NoPassword') { 0 } else { 2 }
    $choice  = Ask-Choice (L '  Choose' '  Elige') $options $default
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

    switch ($choice) {
        0 {
            if (-not (Ask-YesNo ((L '  Remove the Windows password of {0}?' '  ¿Quitar la contraseña de Windows de {0}?') -f $user) $true)) { Write-Skip (L 'Login left unchanged.' 'Inicio de sesión sin cambios.'); return }
            try {
                Set-LocalUser -Name $user -Password (New-Object System.Security.SecureString)
            } catch {
                Write-Fail ((L 'Could not remove the password: {0}' 'No se pudo quitar la contraseña: {0}') -f $_.Exception.Message)
                Write-Note (L 'If it mentions a password policy, check secpol.msc.' 'Si habla de una directiva de contraseñas, revisa secpol.msc.')
                return
            }
            Write-Ok ((L 'Password removed for {0}.' 'Contraseña quitada a {0}.') -f $user)
            Set-ItemProperty -Path $key -Name AutoAdminLogon    -Value '1'     -Type String
            Set-ItemProperty -Path $key -Name DefaultUserName   -Value $user   -Type String
            Set-ItemProperty -Path $key -Name DefaultDomainName -Value $domain -Type String
            Remove-ItemProperty -Path $key -Name DefaultPassword -ErrorAction SilentlyContinue
            Write-Ok (L 'Auto-login enabled - no password stored anywhere.' 'Inicio automático activado, sin contraseña guardada en ningún sitio.')
            Add-Change ((L 'Login: no password for {0}, auto-login on' 'Inicio de sesión: {0} sin contraseña, inicio automático') -f $user)
            $State.NeedsRestart = $true
        }
        1 {
            if ($script:Auto) { Write-Skip (L 'Stored-password auto-login needs a typed password - not available in automatic mode.' 'El inicio automático con contraseña guardada necesita escribirla: no disponible en modo automático.'); return }
            $plain = Read-Secret ((L '  Windows password of {0} (input is hidden)' '  Contraseña de Windows de {0} (no se ve al escribir)') -f $user)
            Set-ItemProperty -Path $key -Name AutoAdminLogon    -Value '1'     -Type String
            Set-ItemProperty -Path $key -Name DefaultUserName   -Value $user   -Type String
            Set-ItemProperty -Path $key -Name DefaultDomainName -Value $domain -Type String
            Set-ItemProperty -Path $key -Name DefaultPassword   -Value $plain  -Type String
            $plain = $null
            Write-Ok ((L 'Auto-login configured for {0}\{1} (password stored in the registry).' 'Inicio automático para {0}\{1} (contraseña guardada en el registro).') -f $domain, $user)
            Add-Change ((L 'Login: auto-login with stored password for {0}' 'Inicio de sesión: automático con contraseña guardada para {0}') -f $user)
            $State.NeedsRestart = $true
        }
        default { Write-Skip (L 'Login left unchanged.' 'Inicio de sesión sin cambios.') }
    }
}
