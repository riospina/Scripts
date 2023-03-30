# Scripts
Mantenimiento DHCP depuracion ips lease no que no estan en uso
Descripción General 
Este es un script de PowerShell para administrar el Protocolo de configuración dinámica de host (DHCP) en un servidor de Windows. El script primero enumera todos los servidores DHCP en el dominio de Active Directory, lo que permite al usuario seleccionar uno. Luego, el usuario ingresa el ID de alcance deseado. A continuación, el script recupera información sobre las concesiones y reservas de DHCP para el ámbito seleccionado, comprueba el estado de conexión de cada concesión y elimina las concesiones que no están conectadas. Las direcciones IP de las concesiones eliminadas se registran en un archivo y se muestran las estadísticas finales del alcance de DHCP.

Este script está escrito en PowerShell y realiza las siguientes acciones:
1.	Solicita al usuario que ingrese el nombre del servidor DHCP o la dirección IP y la ID del alcance.
2.	Inicializa los contadores de éxito, fracaso, eliminación y reserva.
3.	Crea un archivo de registro llamado "RemovedIPs.txt"
4.	Recupera las reservas y arrendamientos del servidor DHCP del nombre del servidor DHCP o la dirección IP y el ID de alcance ingresados.
5.	Itera a través de los arrendamientos y para cada arrendamiento:
 a. Muestra una barra de progreso que muestra el arrendamiento actual que se está verificando. 
b. Comprueba si el arrendamiento es una reserva. Si es así, incrementa el contador de reservas.
 C. Si no es una reserva, comprueba la conexión a la dirección IP.
6.	Si la conexión es exitosa, incrementa el contador de éxito.
7.	Si la conexión falla, incrementa el contador de fallas, elimina la concesión y registra la dirección IP eliminada en el archivo "RemovedIPs.txt".
8.	Muestra el recuento final de éxito, fracaso, eliminación y reserva.
9.	Muestra la estadística DHCP del scope
10.	Abre el archivo de registro "RemovedIPs.txt".



 
$DHCP_Servers = Get-DhcpServerInDC | Sort-Object -Property DnsName
$index = 1
Write-Host "Lista de Servidores DHCP:"
$table = New-Object System.Data.DataTable
$table.Columns.Add("No.") | Out-Null
$table.Columns.Add("Servidor DHCP") | Out-Null
foreach ($server in $DHCP_Servers) {
  $row = $table.NewRow()
  $row.Item("No.") = $index
  $row.Item("Servidor DHCP") = $server.DnsName
  $table.Rows.Add($row)
  $index++
}
$table | Format-Table -AutoSize

$selectedIndex = Read-Host "Ingrese el numero que corresponda a el servidor DHCP deseado"
$selectedServer = $DHCP_Servers[$selectedIndex - 1]
Write-Host "Servidor DHCP seleccionado: $($selectedServer.DnsName)"

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
 
