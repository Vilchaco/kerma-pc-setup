function Install-ScarlettMcrCertificate([string]$path) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Ejecuta Instalar-Certificado-MCR.bat como administrador. / Run Instalar-Certificado-MCR.bat as administrator.'
    }

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw 'Falta Kerma-MCR-HTTPS.cer. Extrae el paquete completo. / Kerma-MCR-HTTPS.cer is missing. Extract the full package.'
    }
    $hash = '7ECA34DE220AAFF953FB6635332BC8A1A6FE1254293CC50DE8B07B112C69D771'
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $hash) {
        throw 'El SHA-256 del certificado no coincide. Descarga de nuevo el paquete oficial. / The certificate SHA-256 does not match. Download the official package again.'
    }

    $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new($path)
    $now = Get-Date
    if ($now -lt $certificate.NotBefore -or $now -gt $certificate.NotAfter) {
        throw 'El certificado no es vigente. Revisa la fecha de Windows y la vigencia del certificado. / The certificate is outside its validity period. Check the Windows date and certificate validity.'
    }

    $store = 'Cert:\LocalMachine\Root'
    $entry = Join-Path $store $certificate.Thumbprint
    if (-not (Test-Path -LiteralPath $entry)) {
        Write-Host 'Este paso agrega el certificado verificado a Raiz de Equipo local. / This adds the verified certificate to Local Computer Trusted Root.'
        $answer = Read-Host 'Instalar certificado? / Install certificate? [s/y/N]'
        if (([string]$answer).Trim() -notmatch '^[sy]$') {
            Write-Host 'Instalacion cancelada. / Installation cancelled.'
            return $false
        }
        Import-Certificate -FilePath $path -CertStoreLocation $store | Out-Null
        if (-not (Test-Path -LiteralPath $entry)) {
            throw 'Windows no guardo el certificado en Equipo local. / Windows did not store the certificate in Local Computer.'
        }
    }
    Write-Host 'Certificado presente en Equipo local. / Certificate present in Local Computer.'
    return $true
}
