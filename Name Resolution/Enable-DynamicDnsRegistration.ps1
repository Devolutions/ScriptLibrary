<#
    .SYNOPSIS
    Enables dynamic DNS registration on network adapters that are IP enabled and have a default gateway configured.

    .DESCRIPTION
    Configures network adapters on a specified computer to enable dynamic 
    DNS registration. This setting is particularly useful in environments where IP addresses are dynamically assigned 
    and network changes are frequent.

    .PARAMETER ComputerName
    Specifies the name of the computer on which the network adapters will be configured. This parameter is mandatory.

    .PARAMETER Credential
    Specifies the credentials to use when connecting to the remote computer. This parameter is optional. If not provided, 
    the current user's credentials are used.

    .EXAMPLE
    PS> .\Enable-DynamicDnsRegistration.ps1 -ComputerName "Server01"
    Enables dynamic DNS registration on all IP-enabled network adapters with a default gateway on the computer named 
    Server01 using the current user's credentials.

    .EXAMPLE
    PS> .\Enable-DynamicDnsRegistration.ps1 -ComputerName "Server01" -Credential (Get-Credential)
    Enables dynamic DNS registration on the computer named "Server01", using specified credentials. The command prompts 
    for credentials.

    .OUTPUTS
    None. Outputs are directed to the Verbose stream or error messages are thrown as exceptions.

    #>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ComputerName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [pscredential]$Credential
)

$icmParams = @{
    ComputerName = $ComputerName
}
if ($PSBoundParameters.ContainsKey('Credential')) {
    $icmParams.Credential = $Credential
}

$icmParams.ScriptBlock = {
    Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled='true'" | Where-Object { $_.DefaultIPGateway.Count -gt 0 } | ForEach-Object {
        Write-Verbose -Message "Setting DDNS registration..."
        $result = $_.SetDynamicDNSRegistration($true)
        if ($result.ReturnValue -ne 0) {
            throw "Failed to set DDNS registration on with return code [$($result.ReturnValue)]"
        }
    }
}
Invoke-Command @icmParams