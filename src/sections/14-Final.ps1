# =====================================================================
#  FINAL: comprobacion del PC (el mismo informe del modo revision),
#  resumen de cambios y reinicio
# =====================================================================

function Invoke-Verification($pc) {
    Write-Section (L 'CHECK  (state of this PC now)' 'COMPROBACIÓN  (estado del PC ahora)')
    $collector = Join-Path $Root 'Kerma-Status.ps1'
    $cfgFile = Join-Path $env:ProgramData 'Kerma\pc.json'
    if (-not (Test-Path -LiteralPath $cfgFile)) {
        # sin panel no hay pc.json: se crea uno temporal para poder comprobar
        $tmp = Get-KermaTemp 'kerma-pc.json'
        (Get-StatusConfig $pc) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $tmp -Encoding UTF8
        & $collector -Print -NoSend -Lang $script:Lang -Config $tmp
        Remove-FileQuiet $tmp
    } else {
        & $collector -Print -NoSend -Lang $script:Lang -Config $cfgFile
    }
}

function Invoke-Finish {
    Write-Section (L 'SUMMARY' 'RESUMEN')
    if ($State.Changes.Count -eq 0) { Write-Host (L '  Nothing was changed.' '  No se cambió nada.') }
    else { foreach ($c in $State.Changes) { Write-Host "  - $c" } }
    Write-Host ''
    Write-Host ((L '  Log: {0}' '  Registro: {0}') -f $script:LogFile)
    Write-Host ''
    if ($State.NeedsRestart) { Write-Note (L 'A RESTART is needed for the name / login changes to apply.' 'Hace falta REINICIAR para que se apliquen el nombre y el inicio de sesión.') }

    if ($Unattended) {
        if ($Restart) { Write-Host (L '  Restarting in 10 seconds.' '  Reiniciando en 10 segundos.'); shutdown.exe /r /t 10 }
        return
    }
    if (Ask-YesNo (L '  Restart this PC now?' '  ¿Reiniciar este PC ahora?') $State.NeedsRestart) {
        Write-Host (L '  Restarting in 10 seconds - cancel with: shutdown /a' '  Reiniciando en 10 segundos. Para cancelar: shutdown /a')
        shutdown.exe /r /t 10
    } else {
        Write-Host (L '  Remember to restart later.' '  Acuérdate de reiniciar después.')
    }
}
