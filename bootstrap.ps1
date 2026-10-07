# =====================================================================
#  Kerma Games - PC Setup bootstrap
#  Downloads the LATEST RELEASE of Kerma PC Setup to C:\KermaSetup\app
#  and starts it. Used by the one-line install:
#
#  PowerShell:
#    irm https://raw.githubusercontent.com/Vilchaco/kerma-pc-setup/main/bootstrap.ps1 | iex
#
#  CMD:
#    powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/Vilchaco/kerma-pc-setup/main/bootstrap.ps1 | iex"
#
#  Plain ASCII on purpose (Windows PowerShell 5.1).
# =====================================================================
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $repo = 'Vilchaco/kerma-pc-setup'
    $root = 'C:\KermaSetup'

    Write-Host ''
    Write-Host '===============================================' -ForegroundColor Cyan
    Write-Host '  KERMA GAMES - PC SETUP (download)' -ForegroundColor Cyan
    Write-Host '===============================================' -ForegroundColor Cyan
    try {
        Write-Host '  Looking for the latest version...'
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -UseBasicParsing -Headers @{ 'User-Agent' = 'Kerma-PCSetup-Bootstrap' }
        $asset = $rel.assets | Where-Object { $_.name -match '^Kerma_PC_Setup-v[0-9.]+\.zip$' } | Select-Object -First 1
        if (-not $asset) { throw "The latest release ($($rel.tag_name)) has no Kerma_PC_Setup zip." }

        $dl = Join-Path $root 'downloads'
        $dest = Join-Path $root "app\$($rel.tag_name)"
        New-Item -ItemType Directory -Path $dl -Force | Out-Null
        $zip = Join-Path $dl $asset.name
        Write-Host "  Downloading $($rel.tag_name)..."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
        Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force

        $script = Join-Path $dest 'Kerma_PC_Setup\Kerma-PCSetup.ps1'
        if (-not (Test-Path -LiteralPath $script)) { throw "Kerma-PCSetup.ps1 not found in $dest" }
        Write-Host "  Ready: $script" -ForegroundColor Green
        Write-Host ''

        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($isAdmin) {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script
        } else {
            Write-Host '  Starting it with administrator rights (accept the permission prompt)...'
            Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
        }
    } catch {
        Write-Host ''
        Write-Host "  [FAILED] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host '  Check the internet connection and try again.'
    }
}
