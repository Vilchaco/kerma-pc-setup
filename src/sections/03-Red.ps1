# =====================================================================
#  RED: IP fija del PC (o volver a DHCP). La IP sale de la lista de
#  David si se puede leer; si no, del inventario.
# =====================================================================

# Valores del PC; lo que falte sale de ajustes.psd1 (Network)
function Get-NetPlan($pc) {
    $plan = @{ IP = ''; Mask = ''; Gateway = ''; DNS1 = ''; DNS2 = '' }
    foreach ($k in @($plan.Keys)) {
        $v = $null
        if ($pc.Net -and $pc.Net.ContainsKey($k)) { $v = $pc.Net[$k] }
        if ([string]::IsNullOrWhiteSpace($v) -and $NetDefaults.ContainsKey($k)) { $v = $NetDefaults[$k] }
        if ($v) { $plan[$k] = $v }
    }
    return $plan
}

function Invoke-NetworkSetup($pc) {
    Write-Section (L 'NETWORK  (static IP)' 'RED  (IP fija)')
    $net     = Get-NetPlan $pc
    $hasPlan = -not [string]::IsNullOrWhiteSpace($net.IP)
    if ($hasPlan) {
        $src = if ($pc.IPSource -eq 'david') { L "David's list" 'la lista de David' } else { L 'the inventory' 'el inventario' }
        Write-Host ((L '  IP for this PC: {0}  (from {1})' '  IP de este PC: {0}  (de {1})') -f $net.IP, $src)
    }
    if ($script:Auto -and -not $hasPlan) { Write-Skip (L 'No IP known for this PC - network left unchanged.' 'No hay IP para este PC: la red queda como está.'); return }
    if (-not (Ask-YesNo (L '  Configure the network adapter / static IP now?' '  ¿Configurar el adaptador de red / IP fija ahora?') ($hasPlan -and [bool]$Prof.StaticIP))) {
        Write-Skip (L 'Network left unchanged.' 'Red sin cambios.'); return
    }

    $adapters = @(Get-NetAdapter -Physical | Sort-Object -Property ifIndex)
    if ($adapters.Count -eq 0) { Write-Warn (L 'No physical network adapters found.' 'No hay adaptadores de red físicos.'); return }

    Write-Host ''
    Write-Host (L '  Network adapters on this PC:' '  Adaptadores de red de este PC:')
    Write-Host ''
    for ($i = 0; $i -lt $adapters.Count; $i++) {
        $a = $adapters[$i]
        $ipInfo = Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
        $ip     = if ($ipInfo) { $ipInfo.IPAddress } else { L '(no IPv4)' '(sin IPv4)' }
        $ipIf   = Get-NetIPInterface -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $mode   = if ($ipIf -and $ipIf.Dhcp -eq 'Enabled') { 'DHCP' } else { L 'Static' 'Fija' }
        Write-Host ("  {0}. {1,-20} {2,-12} {3,-16} {4,-7} {5}" -f ($i + 1), $a.Name, $a.Status, $ip, $mode, $a.InterfaceDescription)
    }
    Write-Host ''
    Write-Host (L '  0. Skip - leave the network as it is' '  0. Saltar: dejar la red como está')
    Write-Host ''

    # -- adaptador
    $nic = $null
    if ($script:Auto) {
        # el primer Ethernet conectado; si no, cualquiera conectado
        $nic = $adapters | Where-Object { $_.Status -eq 'Up' -and $_.MediaType -eq '802.3' } | Select-Object -First 1
        if (-not $nic) { $nic = $adapters | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1 }
        if (-not $nic) { Write-Fail (L 'No connected adapter - network left unchanged.' 'Ningún adaptador conectado: la red queda como está.'); return }
        Write-Host ((L '  Adapter -> {0} (automatic: first connected Ethernet)' '  Adaptador -> {0} (automático: primer Ethernet conectado)') -f $nic.Name) -ForegroundColor DarkGray
    } else {
        while ($true) {
            $v = Read-Host (L '  Which adapter? (number)' '  ¿Qué adaptador? (número)')
            if ($v -match '^\d+$' -and [int]$v -le $adapters.Count) { break }
            Write-Host (L '    Invalid choice.' '    Opción no válida.')
        }
        if ([int]$v -eq 0) { Write-Skip (L 'Network left unchanged.' 'Red sin cambios.'); return }
        $nic = $adapters[[int]$v - 1]
    }
    $name = $nic.Name
    Write-Host ''
    Write-Host ((L '  Selected: {0}  ({1})' '  Elegido: {0}  ({1})') -f $name, $nic.InterfaceDescription)
    Write-Host ''

    # -- fija / DHCP / saltar
    $action = Ask-Choice (L '  Choose' '  Elige') @((L 'Set a STATIC IP on this adapter' 'Poner IP FIJA en este adaptador'), (L 'Back to DHCP (automatic)' 'Volver a DHCP (automática)'), (L 'Skip' 'Saltar')) 0
    if ($action -eq 1) {
        netsh interface ipv4 set address    name="$name" source=dhcp | Out-Null
        netsh interface ipv4 set dnsservers name="$name" source=dhcp | Out-Null
        Write-Ok ((L '{0} back to DHCP.' '{0} vuelve a DHCP.') -f $name)
        Add-Change ((L 'Network: {0} -> DHCP' 'Red: {0} -> DHCP') -f $name)
        return
    }
    if ($action -ne 0) { Write-Skip (L 'Network left unchanged.' 'Red sin cambios.'); return }

    Write-Host ''
    Write-Host (L '  Suggested values in [brackets] - press Enter to accept, or type another.' '  Los valores sugeridos van entre [corchetes]: Enter para aceptar o escribe otro.')
    Write-Host ''
    $ip   = Read-IPv4 (L '  IP address' '  Dirección IP')       $net.IP
    $mask = Read-IPv4 (L '  Subnet mask' '  Máscara de subred')  $net.Mask
    $gw   = Read-IPv4 (L '  Default gateway' '  Puerta de enlace') $net.Gateway
    $dns1 = Read-IPv4 (L '  Primary DNS' '  DNS principal')     $net.DNS1
    $dns2 = Read-IPv4 (L '  Secondary DNS (Enter to skip)' '  DNS secundaria (Enter para saltar)') $net.DNS2 -Optional

    if (-not $ip -or -not $mask -or -not $gw -or -not $dns1) {
        Write-Fail (L 'IP, mask, gateway and primary DNS are all required - network left unchanged.' 'IP, máscara, puerta de enlace y DNS principal son obligatorias: la red queda como está.')
        return
    }

    # -- comprobacion: IP y puerta de enlace en la misma subred
    $ipB = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
    $gwB = [System.Net.IPAddress]::Parse($gw).GetAddressBytes()
    $mB  = [System.Net.IPAddress]::Parse($mask).GetAddressBytes()
    $sameSubnet = $true
    for ($k = 0; $k -lt 4; $k++) { if (($ipB[$k] -band $mB[$k]) -ne ($gwB[$k] -band $mB[$k])) { $sameSubnet = $false } }
    if (-not $sameSubnet) {
        Write-Warn ((L '{0} and gateway {1} are NOT in the same subnet with mask {2}. Usually a typo - the PC would have no internet.' '{0} y la puerta de enlace {1} NO están en la misma subred con la máscara {2}. Suele ser una errata: el PC se quedaría sin internet.') -f $ip, $gw, $mask)
        if ($script:Auto) { Write-Fail (L 'Not applying a broken network plan in automatic mode.' 'En modo automático no se aplica una red incorrecta.'); return }
    }

    Write-Host ''
    Write-Host (L '  About to apply:' '  Se va a aplicar:')
    Write-Host ((L '    Adapter : {0}' '    Adaptador : {0}') -f $name)
    Write-Host "    IP      : $ip"
    Write-Host ((L '    Mask    : {0}' '    Máscara   : {0}') -f $mask)
    Write-Host ((L '    Gateway : {0}' '    Puerta    : {0}') -f $gw)
    Write-Host "    DNS     : $dns1 $dns2"
    Write-Host ''
    if (-not (Ask-YesNo (L '  Apply?' '  ¿Aplicar?') $true)) { Write-Skip (L 'Network left unchanged.' 'Red sin cambios.'); return }

    netsh interface ipv4 set address name="$name" source=static address=$ip mask=$mask gateway=$gw gwmetric=1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Fail (L 'Could not set the IP address (netsh error).' 'No se pudo poner la IP (error de netsh).'); return }
    netsh interface ipv4 set dnsservers name="$name" source=static address=$dns1 register=primary validate=no | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Fail (L 'IP applied but the primary DNS could not be set (netsh error).' 'IP puesta, pero no se pudo poner la DNS principal (error de netsh).'); return }
    if ($dns2) {
        netsh interface ipv4 add dnsservers name="$name" address=$dns2 index=2 validate=no | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warn (L 'Could not set the secondary DNS.' 'No se pudo poner la DNS secundaria.') }
    }
    Write-Ok ((L '{0} is now static: {1} / {2}, gateway {3}, DNS {4} {5}' '{0} con IP fija: {1} / {2}, puerta {3}, DNS {4} {5}') -f $name, $ip, $mask, $gw, $dns1, $dns2)
    Add-Change ((L 'Network: {0} static {1} / {2}, gw {3}' 'Red: {0} IP fija {1} / {2}, puerta {3}') -f $name, $ip, $mask, $gw)
}
