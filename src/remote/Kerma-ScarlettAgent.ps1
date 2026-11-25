#Requires -RunAsAdministrator
param([Parameter(Mandatory = $true)][string]$ConfigPath)

$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
. (Join-Path $env:ProgramData 'Kerma\Kerma-ScarlettReset.ps1')

function Test-ScarlettToken([string]$received) {
    $expected = [string]$config.token
    if (-not $expected -or $received.Length -ne $expected.Length) { return $false }
    $difference = 0
    for ($i = 0; $i -lt $expected.Length; $i++) {
        $difference = $difference -bor ([int]$expected[$i] -bxor [int]$received[$i])
    }
    return $difference -eq 0
}

$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add('http://+:8765/')
$listener.Start()
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $request = $context.Request
            $peer = $request.RemoteEndPoint.Address
            if ($peer.IsIPv4MappedToIPv6) { $peer = $peer.MapToIPv4() }
            if (-not ([Net.IPAddress]::IsLoopback($peer) -or $peer.ToString() -eq $config.controller)) {
                $status = 403
                $result = @{ ok = $false; error = 'forbidden' }
            } elseif (-not (Test-ScarlettToken ($request.Headers['X-UsbReset-Token']))) {
                $status = 401
                $result = @{ ok = $false; error = 'unauthorized' }
            } elseif ($request.HttpMethod -eq 'GET' -and $request.Url.AbsolutePath -eq '/usb-reset/health') {
                $info = Get-KsScarlettInfo
                $status = 200
                $result = @{
                    ok = $true; healthy = ($info.status -eq 'OK'); computer = $env:COMPUTERNAME
                    device = $info.device; status = $(if ($info.status) { $info.status } else { $info.error })
                }
            } elseif ($request.HttpMethod -eq 'POST' -and $request.Url.AbsolutePath -eq '/usb-reset/restart') {
                $reset = Invoke-KsScarlettReset 'mcr'
                $accepted = $reset.ok -or $reset.skipped
                $status = if ($accepted) { 200 } elseif ($reset.busy) { 409 } else { 503 }
                $result = @{ ok = [bool]$accepted; computer = $env:COMPUTERNAME; result = $reset; error = $reset.msg }
            } else {
                $status = 404
                $result = @{ ok = $false; error = 'not_found' }
            }
        } catch {
            Write-KsLog ('Agent error: ' + $_.Exception.Message)
            $status = 500
            $result = @{ ok = $false; error = 'agent_error' }
        }
        try {
            $bytes = [Text.Encoding]::UTF8.GetBytes(($result | ConvertTo-Json -Compress -Depth 5))
            $context.Response.StatusCode = $status
            $context.Response.ContentType = 'application/json; charset=utf-8'
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        } catch {
            Write-KsLog ('Agent response failed: ' + $_.Exception.Message)
        } finally {
            $context.Response.Close()
        }
    }
} finally {
    $listener.Close()
}
