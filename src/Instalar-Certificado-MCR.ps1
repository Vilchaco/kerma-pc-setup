$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\ScarlettMcrCertificate.ps1')
try {
    if (-not (Install-ScarlettMcrCertificate (Join-Path $PSScriptRoot 'Kerma-MCR-HTTPS.cer'))) { exit 1 }
    Write-Host 'Ejecuta Diagnosticar-MCR.bat para verificar HTTPS. / Run Diagnosticar-MCR.bat to verify HTTPS.'
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
