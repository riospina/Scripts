# Ingreso de nombre de servidor DHCP o IP
$computerName = Read-Host -Prompt "Ingrese DHCP"

# Ingreso de scope ID
$scopeId = Read-Host -Prompt "Ingrese scope ID"

# Contadores
$successCounter = 0
$failureCounter = 0
$removedCounter = 0
$reservationCounter = 0

# Obtener fecha y hora actual
$currentDate = Get-Date -Format yyyy-MM-dd_HH-mm-ss

# Obtener nombre de usuario
$username = $env:USERNAME

# Obtener nombre de scope
$scopeName = (Get-DhcpServerv4Scope -ComputerName $computerName -ScopeId $scopeId).Name

# Archivo de log
$logfile = ".\RemovedIPs_$scopeName_$username.txt"

# Obtener reservas DHCP
$reservations = Get-DhcpServerv4Reservation -ComputerName $computerName -ScopeId $scopeId

# Obtener arrendamientos DHCP
$leases = Get-DhcpServerv4Lease -ComputerName $computerName -ScopeId $scopeId

# Inicializar contadores para barra de progreso
$total = $leases.Count
$current = 0

# Recorrer arrendamientos
foreach ($lease in $leases) {
    $current++
    $ip = $lease.IPAddress
    # Mostrar barra de progreso
    Write-Progress -Activity "Revisando arrendamientos DHCP" -CurrentOperation "$ip" -PercentComplete (($current / $total) * 100)
    
    # Revisar si es una reserva
    if ($reservations -match $ip) {
        # Incrementar contador de reservas
        $reservationCounter++
    } else {
        # Revisar conexión
        if (Test-Connection -ComputerName $ip -Quiet -Count 1) {
            # Incrementar contador de éxito
            $successCounter++
        } else {
            # Incrementar contador de fallo
            $failureCounter++
            # Eliminar arrendamiento
            Remove-DhcpServerv4Lease -ComputerName $computerName -IPAddress $ip
            $removedCounter++
            # Agregar a archivo de log
            $ip.IPAddressToString | Out-File -Append -FilePath $logfile -Force
        }
    }
}

Write-Host "IP leases success: $successCounter"
Write-Host "IP leases failure: $failureCounter"
Write-Host "IP leases removed: $removedCounter"
Write-Host "IP reservations: $reservationCounter"
Write-Host "Removed IP addresses have been logged to $logfile"
Get-DhcpServerv4ScopeStatistics -ComputerName $computerName -ScopeId $scopeId
start $logfile
