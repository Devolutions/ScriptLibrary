<#
.SYNOPSIS
Retrieves SQL Server instances and their listening ports on a Windows server.

.DESCRIPTION
This script retrieves information about SQL Server instances installed on a Windows server and their corresponding listening ports. It can retrieve information for all instances or a specific instance specified by the -InstanceName parameter.

.PARAMETER InstanceName
The name of a specific SQL Server instance to retrieve information for. If not provided, the script retrieves information for all instances.

.EXAMPLE
.\Get-SqlServerInstanceListeningPort.ps1

Retrieves information for all SQL Server instances on the server.

.EXAMPLE
.\Get-SqlServerInstanceListeningPort.ps1 -InstanceName "SQLEXPRESS"

Retrieves information for the SQL Server instance named "SQLEXPRESS".

.OUTPUTS
Returns an array of PSCustomObject with the following properties:
- InstanceName: The name of the SQL Server instance.
- Port: The listening port number of the instance. If the port is dynamically assigned, it will display "Dynamic".

.NOTES
- This script requires administrative privileges to access the Windows registry.
- The script assumes that the SQL Server instances are installed on the same server where the script is running.
- The script has only been tested with SQL Server Express 2019 and SQL Server 2019
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$InstanceName
)

$instanceNames = $null
$instanceNames = Get-Service -Name "MSSQL*" | Select-Object @{n = 'InstanceName'; e = { $_ -replace "^MSSQL\$" } } | Select-Object -ExpandProperty 'InstanceName'
if (!$instanceNames) {
    throw 'No SQL instances found.'
}
$instanceNames = $instanceNames.where({ !$InstanceName -or $_ -eq $InstanceName })

foreach ($instanceName in $instanceNames) {
    
    # Get the SQL Server configuration
    $sqlConfig = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL" -Name $instanceName -ErrorAction SilentlyContinue
    
    if ($sqlConfig) {
        # Get the instance ID
        $instanceId = $sqlConfig.$instanceName
        
        # Get the SQL Server network configuration
        $networkConfig = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\SuperSocketNetLib\Tcp\IPAll" -ErrorAction SilentlyContinue
        
        # Get the TCP port number
        $tcpPort = $networkConfig.TcpPort
        
        # If the TCP port is not explicitly set, use the default port
        if ([string]::IsNullOrEmpty($tcpPort)) {
            if ($instanceName -eq "MSSQLSERVER") {
                $tcpPort = "1433"  # Default port for the default instance
            } else {
                $tcpDynamicPorts = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\SuperSocketNetLib\Tcp\IPAll" -Name TcpDynamicPorts -ErrorAction SilentlyContinue
                if ($tcpDynamicPorts.TcpDynamicPorts -eq 0) {
                    $tcpPort = 'Dynamic'
                }
            }
        }

        [pscustomobject]@{
            InstanceName = $instanceName
            Port         = $tcpPort
        }
    }
}