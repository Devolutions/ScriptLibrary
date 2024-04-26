#Requires -RunAsAdministrator
<#
.SYNOPSIS
Configures the TCP port for a specified SQL Server instance.

.DESCRIPTION
This script updates the TCP port for a specified SQL Server instance by modifying the Windows Registry. It ensures that TCP/IP is enabled for the instance and sets the specified port. If the changes are made successfully, the SQL Server instance service is restarted to apply the changes.

.PARAMETER InstanceName
Specifies the name of the SQL Server instance to configure. This parameter is mandatory.

.PARAMETER Port
Specifies the TCP port number to set for the SQL Server instance. This parameter is mandatory.

.EXAMPLE
PS> .\Set-SqlServerPort.ps1 -InstanceName "MSSQLSERVER" -Port 1433

This command sets the TCP port of the SQL Server instance named MSSQLSERVER to 1433.

.INPUTS
None. You cannot pipe input to this script.

.OUTPUTS
None. This script does not produce any output.

.NOTES



.LINK
https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/configure-a-server-to-listen-on-a-specific-tcp-port

#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param (
    [Parameter(Mandatory)]
    [string]$InstanceName,

    [Parameter(Mandatory)]
    [int]$Port
)

# Find SQL Server instances and their versions
$instances = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'

# Determine the version and registry path for each instance
foreach ($instance in $instances.PSObject.Properties) {
    if ($instance.Name -eq $InstanceName) {
        $instanceID = $instance.Value
        $rootKeyPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceID\MSSQLServer\SuperSocketNetLib\Tcp"
        $ipKeys = Get-ChildItem $rootKeyPath -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'IP[0-9]+$' }

        $anyIPEnabled = $false
        foreach ($ipKey in $ipKeys) {
            $ipEnabled = (Get-ItemProperty -Path $ipKey.PSPath -Name "Enabled").Enabled
            if ($ipEnabled -eq '1') {
                $anyIPEnabled = $true
                $tcpKeyPath = $ipKey.PSPath
                if ($PSCmdlet.ShouldProcess("$tcpKeyPath (Enabled IP)", "Set TCP Port")) {
                    Set-ItemProperty -Path $tcpKeyPath -Name "TcpPort" -Value "$Port"
                    Set-ItemProperty -Path $tcpKeyPath -Name "TcpDynamicPorts" -Value ""
                }
            }
        }

        if (-not $anyIPEnabled) {
            throw "No enabled IP addresses found for instance $InstanceName. Enable TCP/IP in SQL Server Configuration Manager."
        }

        $serviceName = "MSSQL`$$InstanceName"
        if ($PSCmdlet.ShouldProcess("$serviceName service", 'Restart')) {
            Restart-Service -Name $serviceName -Force
        }
    }
}
