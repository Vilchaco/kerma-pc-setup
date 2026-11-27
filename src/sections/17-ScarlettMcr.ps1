function Invoke-ScarlettMcr($pc) {
    if ($pc.Type -ne 'Table') { return }
    Write-Section (L 'SCARLETT IN KERMA MCR' 'SCARLETT EN KERMA MCR')

    $shared = Initialize-KermaDataDir
    Copy-Item -LiteralPath (Join-Path $Root 'Kerma-ScarlettReset.ps1') -Destination $shared -Force
    $dir = Join-Path $env:ProgramData 'KermaGames\ScarlettReset'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $acl = Invoke-Native 'icacls.exe' @($dir, '/inheritance:r', '/grant:r', '*S-1-5-18:(OI)(CI)F', '*S-1-5-32-544:(OI)(CI)F')
    if ($acl.ExitCode -ne 0) { throw 'Could not protect Scarlett agent configuration.' }
    $configPath = Join-Path $dir 'config.json'
    $config = @{}
    if (Test-Path -LiteralPath $configPath) {
        $previous = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        if (-not $previous.token) { throw 'Existing Scarlett agent configuration is missing its token.' }
        foreach ($field in $previous.PSObject.Properties) { $config[$field.Name] = $field.Value }
    } else {
        $bytes = New-Object byte[] 32
        $random = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $random.GetBytes($bytes) } finally { $random.Dispose() }
        $config.token = [Convert]::ToBase64String($bytes)
    }
    $controller = '192.168.3.254'
    $config.controller = $controller
    $config.port = 8765
    if (-not $config.deviceInstanceId) {
        . (Join-Path $shared 'Kerma-ScarlettReset.ps1')
        $selection = Resolve-KsScarlett
        if ($selection.Device) {
            $config.deviceInstanceId = [string]$selection.Device.InstanceId
            $config.deviceFriendlyName = [string]$selection.Device.FriendlyName
        }
    }

    $taskName = 'Kerma Games Scarlett Solo Reset Agent'
    $agent = Join-Path $dir 'Kerma-ScarlettAgent.ps1'
    $action = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$agent`" -ConfigPath `"$configPath`""
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

    Copy-Item -LiteralPath (Join-Path $Root 'remote\Kerma-ScarlettAgent.ps1') -Destination $agent -Force
    $config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$configPath.new" -Encoding UTF8
    $rule = 'Kerma Games Scarlett Solo Reset TCP 8765'
    $rules = @(Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue)
    if ($rules.Count) {
        $rules | Get-NetFirewallAddressFilter | Set-NetFirewallAddressFilter -RemoteAddress $controller | Out-Null
        $rules | Set-NetFirewallRule -Enabled True -EdgeTraversalPolicy Block | Out-Null
    } else {
        New-NetFirewallRule -DisplayName $rule -Direction Inbound -Action Allow -Protocol TCP `
            -LocalPort 8765 -RemoteAddress $controller -Profile Any -EdgeTraversalPolicy Block | Out-Null
    }
    $previousTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($previousTask.State -eq 'Running') { Stop-ScheduledTask -TaskName $taskName }
    if (Test-Path -LiteralPath $configPath) {
        [IO.File]::Replace("$configPath.new", $configPath, [NullString]::Value)
    } else {
        [IO.File]::Move("$configPath.new", $configPath)
    }
    try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger (New-ScheduledTaskTrigger -AtStartup) `
            -Principal $principal -Settings $settings -Force | Out-Null
    } catch {
        if ($previousTask) { Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue }
        throw
    }
    Start-ScheduledTask -TaskName $taskName

    $headers = @{ 'X-UsbReset-Token' = $config.token }
    $health = $null
    for ($i = 0; $i -lt 6 -and -not $health; $i++) {
        try {
            $health = Invoke-RestMethod -Uri 'http://127.0.0.1:8765/usb-reset/health' -Headers $headers `
                -UseBasicParsing -TimeoutSec 3 -MaximumRedirection 0
        } catch { Start-Sleep -Seconds 1 }
    }
    if (-not $health.ok) { throw 'Scarlett agent did not answer its local health check on port 8765.' }
    Add-Change (L 'Scarlett agent installed' 'Agente Scarlett instalado')

    $invite = ([string]$script:Secrets.ScarlettInvitation) -replace '\s', ''
    if (-not $invite -and $config.mcrDeviceId -and $pc.Net.IP -and
        $config.mcrSetupKey -eq $pc.Key -and $config.mcrSetupAddress -eq $pc.Net.IP) {
        Write-Ok (L 'Scarlett agent updated. Existing MCR registration retained.' 'Agente Scarlett actualizado. Se conservó el registro existente en MCR.')
        return
    }
    $headers['X-Scarlett-Setup-Key'] = [string]$pc.Key
    $endpoint = "https://$controller/api/scarlett/auto-enroll"
    if ($invite) {
        if ($invite -cnotmatch '^[A-Za-z0-9_-]{43}$') {
            throw ((L 'Copy the full 43-character invitation from MCR (received {0} characters).' 'Copia la invitacion completa de 43 caracteres desde MCR (se recibieron {0}).') -f $invite.Length)
        }
        $headers['X-Scarlett-Invitation'] = $invite
        $endpoint = "https://$controller/api/scarlett/enroll"
    }
    $deadline = [datetime]::UtcNow.AddSeconds(90)
    $failures = 0
    $approvalShown = $false
    do {
        try {
            $result = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers `
                -UseBasicParsing -TimeoutSec 12 -MaximumRedirection 0
            $failures = 0
        } catch {
            $failure = $_.Exception
            $status = if ($failure.Response) { [int]$failure.Response.StatusCode } else { [string]$failure.Status }
            $failures++
            if ($failures -ge 3 -or $status -notin @(502, 503, 504, 'ConnectFailure', 'Timeout', 'ReceiveFailure', 'ConnectionClosed')) {
                $message = switch ($status) {
                    'TrustFailure' { L 'Windows could not validate the MCR certificate. Run Diagnosticar-MCR.bat and check the certificate and date.' 'Windows no pudo validar el certificado de MCR. Ejecuta Diagnosticar-MCR.bat y revisa el certificado y la fecha.' }
                    'SecureChannelFailure' { L 'The TLS handshake with MCR failed. Run Diagnosticar-MCR.bat.' 'Falló la negociación TLS con MCR. Ejecuta Diagnosticar-MCR.bat.' }
                    { $_ -in @('ConnectFailure', 'Timeout', 'ReceiveFailure', 'ConnectionClosed', 'NameResolutionFailure', 'ProxyNameResolutionFailure') } {
                        L 'Check access to 192.168.3.254 on TCP 443 with Diagnosticar-MCR.bat.' 'Comprueba el acceso a 192.168.3.254 por TCP 443 con Diagnosticar-MCR.bat.'
                    }
                    401 {
                        if ($invite) { L 'Verify the table key or generate a new invitation in MCR.' 'Verifica la clave de mesa o genera una nueva invitación en MCR.' }
                        else { L 'MCR rejected the enrollment credentials.' 'MCR rechazó las credenciales de alta.' }
                    }
                    403 {
                        if ($invite) { L 'Verify that MCR allows enrollment by invitation from this PC.' 'Verifica que MCR permita el alta por invitación desde esta PC.' }
                        else { L 'Confirm the Setup key and reserved IP in Scarlett automatic enrollment.' 'Confirma la clave de Setup y la IP reservada en Alta automática de Scarlett.' }
                    }
                    404 {
                        if ($invite) { L 'Enrollment by invitation is unavailable on this MCR.' 'Este MCR no tiene disponible el alta por invitación.' }
                        else { L 'Automatic enrollment is unavailable on this MCR.' 'Este MCR no tiene disponible el alta automática.' }
                    }
                    409 {
                        if ($invite) { L 'Check the existing registration in MCR. If the invitation was already used, generate another one.' 'Revisa el registro existente en MCR. Si la invitación ya se usó, genera otra.' }
                        else { L 'Check the pending request or table assignment in MCR.' 'Revisa la solicitud pendiente o la asignación de la mesa en MCR.' }
                    }
                    default { L 'Check the MCR connection with Diagnosticar-MCR.bat and retry Setup.' 'Comprueba la conexión con Diagnosticar-MCR.bat y vuelve a ejecutar Setup.' }
                }
                $label = L 'Scarlett enrollment failed' 'Falló el alta de Scarlett'
                throw "${label} ($status). $message"
            }
            Start-Sleep -Seconds 2
            continue
        }
        if (-not $result.pending) { break }
        if (-not $approvalShown) {
            $sha = [Security.Cryptography.SHA256]::Create()
            try {
                $bytes = $sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($config.token))
                $fingerprint = [BitConverter]::ToString($bytes, 0, 8).Replace('-', '')
            } finally { $sha.Dispose() }
            if ($fingerprint -cne $result.fingerprint) { throw 'MCR returned a different Scarlett fingerprint.' }
            Write-Note ((L 'Approve {0} in Scarlett automatic enrollment. Fingerprint: {1}' 'Aprueba {0} en Alta automatica de Scarlett. Huella: {1}') -f $pc.Key, $fingerprint)
            $approvalShown = $true
        }
        Start-Sleep -Seconds 5
    } while ([datetime]::UtcNow -lt $deadline)
    if (-not $result.id -and $approvalShown) {
        Write-Warn (L 'MCR enrollment pending approval. After approving, run Setup again.' 'Registro pendiente de aprobacion en MCR. Despues de aprobarlo, vuelve a ejecutar Setup.')
        Add-Change (L 'Scarlett enrollment pending approval' 'Registro de Scarlett pendiente de aprobacion')
        return
    }
    if (-not $result.ok -or -not $result.id) { throw 'MCR returned an invalid enrollment response.' }
    $config.mcrDeviceId = [string]$result.id
    $config.mcrSetupKey = $pc.Key
    $config.mcrSetupAddress = $pc.Net.IP
    $config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$configPath.new" -Encoding UTF8
    [IO.File]::Replace("$configPath.new", $configPath, [NullString]::Value)
    Add-Change ((L 'Scarlett enrolled in MCR: {0}' 'Scarlett registrada en MCR: {0}') -f $result.id)
}
