function Read-ScarlettInvitation($pc) {
    if ($pc.Type -ne 'Table' -or $Unattended -or $script:Secrets.ScarlettInvitation) { return }
    $configPath = Join-Path $env:ProgramData 'KermaGames\ScarlettReset\config.json'
    try {
        $current = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop | ConvertFrom-Json
        if ($current.mcrDeviceId -and $current.mcrSetupKey -eq $pc.Key -and $current.mcrSetupAddress -eq $pc.Net.IP) { return }
    } catch { }
    $script:Secrets.ScarlettInvitation = Read-Secret (L '  MCR invitation for this table (Enter to register later)' '  Invitacion de MCR para esta mesa (Enter para registrar despues)')
}

function Invoke-ScarlettMcr($pc) {
    if ($pc.Type -ne 'Table') { return }
    Write-Section (L 'SCARLETT IN KERMA MCR' 'SCARLETT EN KERMA MCR')
    if (-not $script:Auto) { Read-ScarlettInvitation $pc }

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

    $invite = $script:Secrets.ScarlettInvitation
    if (-not $invite) {
        if ($config.mcrDeviceId -and $config.mcrSetupKey -eq $pc.Key -and $config.mcrSetupAddress -eq $pc.Net.IP) {
            Write-Ok ((L 'Scarlett already enrolled: {0}' 'Scarlett ya registrada: {0}') -f $config.mcrDeviceId)
        } else {
            Write-Warn (L 'MCR enrollment pending: run Setup with a table invitation.' 'Registro en MCR pendiente: ejecuta Setup con una invitacion de mesa.')
        }
        return
    }
    if ($invite -cnotmatch '^[A-Za-z0-9_-]{43}$') { throw 'Invalid Scarlett MCR invitation format.' }
    $headers['X-Scarlett-Invitation'] = $invite
    $headers['X-Scarlett-Setup-Key'] = [string]$pc.Key
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $result = Invoke-RestMethod -Method Post -Uri 'https://mcr.kermagames.local/api/scarlett/enroll' `
                -Headers $headers -UseBasicParsing -TimeoutSec 15 -MaximumRedirection 0
            break
        } catch {
            $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 'network/TLS' }
            if ($attempt -eq 3 -or $status -notin @(502, 503, 504, 'network/TLS')) {
                throw "Scarlett MCR enrollment pending ($status). Retry Setup with the same invitation before it expires."
            }
            Start-Sleep -Seconds 2
        }
    }
    if (-not $result.ok -or -not $result.id) { throw 'MCR returned an invalid enrollment response.' }
    $config.mcrDeviceId = [string]$result.id
    $config.mcrSetupKey = $pc.Key
    $config.mcrSetupAddress = $pc.Net.IP
    $config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$configPath.new" -Encoding UTF8
    [IO.File]::Replace("$configPath.new", $configPath, [NullString]::Value)
    Add-Change ((L 'Scarlett enrolled in MCR: {0}' 'Scarlett registrada en MCR: {0}') -f $result.id)
}
