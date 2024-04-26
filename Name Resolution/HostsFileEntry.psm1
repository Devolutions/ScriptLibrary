$script:hostFilePath = "$Env:SystemRoot\System32\drivers\etc\hosts"

function Get-HostsFileEntry {
    <#
    .SYNOPSIS
    Gets the entries from the hosts file.

    .DESCRIPTION
    The Get-HostsFileEntry cmdlet gets the entries from the hosts file. The hosts file is a text file that maps hostnames to
    IP addresses. It is typically used to resolve hostnames that cannot be resolved using DNS.

    .PARAMETER HostFilePath
    The path to the hosts file. The default value is "$Env:SystemRoot\System32\drivers\etc\hosts".

    .OUTPUTS
    The cmdlet outputs an array of custom objects. Each custom object represents a single entry in the hosts file. The 
    custom object has the following properties:

    * IPAddress: The IP address of the host.
    * HostName: The hostname of the host.
    * Comment: The comment associated with the host.

    .EXAMPLE
    Get the entries from the hosts file:
    .\Get-HostsFileEntry.ps1

    #>
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            { Test-Path -Path $_.FullName },
            ErrorMessage = "The hosts file at [{0}] could not be found."
        )]
        [string]$HostFilePath = $script:hostFilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$HostName
    )

    $ErrorActionPreference = 'Stop'

    $regex = '^(?<ipAddress>[0-9.]+)\s+(?<hostname>[^\s#]+)(\s*#\s*(?<comment>.*))?$'

    $whereFilter = '$_'
    if ($PSBoundParameters.ContainsKey('HostName')) {
        $whereFilter = "`$_.HostName -eq '$Hostname'"
    }
    $whereFilter = [scriptblock]::Create($whereFilter)

    Get-Content -Path $HostFilePath | ForEach-Object {
        if ($_ -match $regex) {
            [pscustomobject]@{
                IPAddress = $matches['ipAddress']
                HostName  = $matches['hostname']
                Comment   = $matches['comment']
            }
        }
    } | Where-Object -FilterScript $whereFilter
}

function Remove-HostsFileEntry {
    <#
    .SYNOPSIS
    Removes an entry from the hosts file.

    .DESCRIPTION
    The Remove-HostsFileEntry cmdlet removes an entry from the hosts file based on the specified hostname. It is designed
    to safely modify the hosts file by utilizing a temporary file during the deletion process to prevent data loss.

    .PARAMETER HostName
    Specifies the hostname of the entry to remove from the hosts file. This parameter is mandatory.

    .PARAMETER HostFilePath
    Specifies the path to the hosts file. The default is set to a script-scoped variable ($script:hostFilePath) which 
    is predefined in the module.

    .EXAMPLE
    Remove-HostsFileEntry -HostName "examplehost"

    This example removes the entry for 'examplehost' from the default hosts file.

    .EXAMPLE
    Remove-HostsFileEntry -HostName "testhost" -HostFilePath "C:\Windows\System32\drivers\etc\hosts"

    This example demonstrates how to specify both the hostname and the path of the hosts file from which to remove an entry.

    .NOTES
    Ensure that the PowerShell session running this cmdlet has adequate permissions to modify the hosts file, typically 
    requiring administrative rights.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$HostName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$HostFilePath = $script:hostFilePath
    )

    $regex = "^(?<ipAddress>[0-9.]+)[^\w]*($HostName)(`$|[\W]{0,}#\s+(?<comment>.*))"
    $toRemove = (Get-Content -Path $HostFilePath | Select-String -Pattern $regex).Line

    # Safer to create a temp file.
    $tempFile = "$Env:SystemRoot\System32\drivers\etc\hosts.temp"
    (Get-Content -Path $HostFilePath | Where-Object { $_ -ne $toRemove }) | Add-Content -Path $tempFile
    if (Test-Path -Path $tempFile -PathType Leaf) {
        Remove-Item -Path $HostFilePath
        Move-Item -Path $tempFile -Destination $HostFilePath
    } else {
        throw 'Failed to create temp hosts file to make the change'
    }
}

function Set-HostsFileEntry {
    <#
    .SYNOPSIS
    Sets or updates an entry in the hosts file.

    .DESCRIPTION
    The Set-HostsFileEntry cmdlet adds or updates an entry in the hosts file for a specified hostname and IP address.
    If the hostname exists but with a different IP address, the existing entry is updated. This cmdlet also handles 
    fully qualified domain names (FQDNs) by resolving them to IP addresses if no IP address is provided.

    .PARAMETER HostName
    Specifies the hostname for the entry in the hosts file. This parameter is mandatory.

    .PARAMETER IPAddress
    Specifies the IP address for the hostname. If not provided and the hostname is a FQDN, the cmdlet attempts to resolve 
    the IP address.

    .PARAMETER Comment
    Allows adding a comment for the hosts file entry. This is optional and can be used for documentation or clarification 
    purposes.

    .PARAMETER HostFilePath
    Specifies the path to the hosts file. The default is set to a script-scoped variable ($script:hostFilePath), which 
    is provided in the module.

    .EXAMPLE
    Set-HostsFileEntry -HostName "example.com" -IPAddress "192.168.1.1"

    This example adds an entry to the hosts file linking "example.com" with the IP address "192.168.1.1".

    .EXAMPLE
    Set-HostsFileEntry -HostName "example.com" -IPAddress "192.168.1.1" -Comment "Test server"

    This example does the same as the previous one but includes a comment "Test server" for the entry.

    .EXAMPLE
    Set-HostsFileEntry -HostName "example.com"

    If "example.com" is a FQDN and no IP address is provided, this example tries to resolve "example.com" and adds the 
    resulting IP address to the hosts file.

    .NOTES
    Ensure that you have the necessary administrative rights to modify the hosts file, as this operation typically 
    requires elevated privileges.

    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$HostName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ipaddress]$IPAddress,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Comment,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$HostFilePath = $script:hostFilePath
    )

    $ErrorActionPreference = 'Stop'

    $isFqdn = $false
    if ($PSBoundParameters.HostName -match '\.+') {
        $isFqdn = $true
        $shortHostName = $HostName.Split('.')[0].ToUpper()
    } else {
        $HostName = $HostName.ToUpper()
    }

    $vals = @()
    ## If a FQDN was passed, grab the hostname and IP address that resolves and use that
    if ($isFqdn) {
        if (-not $PSBoundParameters.ContainsKey('IPAddress')) {
            $ip = (Resolve-DnsName -Name $HostName -DnsOnly -ErrorAction SilentlyContinue).IPAddress
            if (-not $ip) {
                throw 'No IP address provided and hostname could not be resolved'
            }
            $HostName = $shortHostName
            $IPAddress = $ip
        }
    } elseif (-not $PSBoundParameters.ContainsKey('IPAddress')) {
        throw 'Hostname is not a FQDN and no IP address provided.'
    }

    $vals += $IPAddress
    $vals += $HostName

    if ($PSBoundParameters.ContainsKey('Comment')) {
        $vals += "# $Comment"
    }

    $existingEntry = Get-HostsFileEntry -HostName $HostName
    if ($existingEntry) {
        if ($existingEntry.IPAddress -eq $IPAddress) {
            Write-Verbose "The hostname '$HostName' already exists on computer $ComputerName"
            return
        } else {
            Write-Verbose "Removing hostname '$HostName' on computer $ComputerName' because IP address does not match"
            $null = Remove-HostsFileEntry -HostName $HostName
        }
    }

    ## If the hosts file doesn't end with a blank line, make it so
    if ((Get-Content -Path $HostFilePath -Raw) -notmatch '\n$') {
        Add-Content -Path $HostFilePath -Value ''
    }

    Add-Content -Path $HostFilePath -Value ($vals -join "`t")
}