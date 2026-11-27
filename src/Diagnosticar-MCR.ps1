$ErrorActionPreference = 'Stop'
$server = '192.168.3.254'
$endpoint = "https://$server/api/scarlett/auto-enroll"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new((Join-Path $PSScriptRoot 'Kerma-MCR-HTTPS.cer'))
$machineTrust = Test-Path ("Cert:\LocalMachine\Root\" + $certificate.Thumbprint)
$userTrust = Test-Path ("Cert:\CurrentUser\Root\" + $certificate.Thumbprint)
Write-Host "Certificado exacto en Equipo local / Exact certificate in Local Computer: $machineTrust"
Write-Host "Certificado exacto en Usuario actual / Exact certificate in Current User: $userTrust"
$tcp = [Net.Sockets.TcpClient]::new()
try {
    $connection = $tcp.ConnectAsync($server, 443)
    if (-not $connection.Wait(4000) -or -not $tcp.Connected) { throw 'Tiempo agotado / Timed out' }
    Write-Host "TCP ${server}:443 accesible / reachable" -ForegroundColor Green
} catch {
    Write-Host "TCP ${server}:443 no accesible / unreachable: $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    exit 1
} finally { $tcp.Dispose() }
try {
    Invoke-WebRequest -Uri $endpoint -Method Post -UseBasicParsing -TimeoutSec 8 -MaximumRedirection 0 | Out-Null
    Write-Host 'HTTPS responde con validacion de certificado. / HTTPS responds with certificate validation.' -ForegroundColor Green
} catch {
    $exception = $_.Exception
    if ($exception.Response) {
        $code = [int]$exception.Response.StatusCode
        if ($code -eq 400) {
            Write-Host 'HTTPS verificado. MCR devolvio HTTP 400 sin credenciales. / HTTPS verified. MCR returned HTTP 400 without credentials.' -ForegroundColor Green
            exit 0
        }
        Write-Host "HTTPS responde. MCR devolvio HTTP $code. / HTTPS responds. MCR returned HTTP $code." -ForegroundColor Yellow
        exit 1
    }
    while ($exception) {
        if ($exception -is [Net.WebException]) { Write-Host "Estado / Status: $($exception.Status)" }
        Write-Host $exception.Message -ForegroundColor Red
        $exception = $exception.InnerException
    }
    exit 1
}
