<#
.SYNOPSIS
    Restarts the specified computer(s).

.DESCRIPTION
    This script uses the Restart-Computer cmdlet from the Microsoft.PowerShell.Management module to restart one or more computers.
    It supports various authentication methods and can be configured to wait for the restart to complete, with options for timeout 
    and delay between checks.

.PARAMETER WsmanAuthentication
    Specifies the authentication method to be used for the WSMan connection. Valid values are 'Default', 'Basic', 'Negotiate', 
    'CredSSP', 'Digest', and 'Kerberos'.

.PARAMETER ComputerName
    Specifies the computer(s) to restart. This can be a name, alias, or IP address. This parameter supports pipeline input.

.PARAMETER Credential
    Specifies the user account credentials to use for the restart operation.

.PARAMETER Force
    Forces the restart of the computer(s) without prompting for confirmation.

.PARAMETER Wait
    Waits for the restart to complete before continuing.

.PARAMETER Timeout
    Specifies the maximum amount of time (in seconds) to wait for the computer(s) to restart. A value of -1 means to wait indefinitely.

.PARAMETER For
    Specifies the service types to wait for after the restart. This is used in conjunction with the Wait parameter.

.PARAMETER Delay
    Specifies the delay (in seconds) between checks to determine if the computer(s) have restarted.

.NOTES
    For more information, visit: https://go.microsoft.com/fwlink/?LinkID=2097060

.EXAMPLE
    PS> .\Restart-Computer.ps1 -ComputerName 'Server01' -Credential (Get-Credential) -Force -Wait -Timeout 300

    This example restarts 'Server01' using specified credentials, forces the restart without prompting for confirmation, 
    waits for the restart to complete, and specifies a timeout of 300 seconds.

.EXAMPLE
    PS> .\Restart-Computer.ps1 -ComputerName 'Server01','Server02' -WsmanAuthentication 'Kerberos' -Wait -Delay 10

    This example restarts 'Server01' and 'Server02' using Kerberos authentication, waits for the restart to complete, 
    and sets a delay of 10 seconds between checks.
#>


[CmdletBinding(DefaultParameterSetName = 'DefaultSet', SupportsShouldProcess = $true, ConfirmImpact = 'Medium', HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=2097060', RemotingCapability = 'OwnedByCommand')]
param(
    [Parameter(ParameterSetName = 'DefaultSet')]
    [ValidateSet('Default', 'Basic', 'Negotiate', 'CredSSP', 'Digest', 'Kerberos')]
    [string]
    ${WsmanAuthentication},

    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('CN', '__SERVER', 'Server', 'IPAddress')]
    [ValidateNotNullOrEmpty()]
    [string[]]
    ${ComputerName},

    [Parameter(Position = 1)]
    [ValidateNotNullOrEmpty()]
    [pscredential]
    [System.Management.Automation.CredentialAttribute()]
    ${Credential},

    [Alias('f')]
    [switch]
    ${Force},

    [Parameter(ParameterSetName = 'DefaultSet')]
    [switch]
    ${Wait},

    [Parameter(ParameterSetName = 'DefaultSet')]
    [Alias('TimeoutSec')]
    [ValidateRange(-1, 2147483647)]
    [int]
    ${Timeout},

    [Parameter(ParameterSetName = 'DefaultSet')]
    [Microsoft.PowerShell.Commands.WaitForServiceTypes]
    ${For},

    [Parameter(ParameterSetName = 'DefaultSet')]
    [ValidateRange(1, 32767)]
    [short]
    ${Delay})

begin {
    try {
        $outBuffer = $null
        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer)) {
            $PSBoundParameters['OutBuffer'] = 1
        }

        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Management\Restart-Computer', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = { & $wrappedCmd @PSBoundParameters }

        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)
    } catch {
        throw
    }
}

process {
    try {
        $steppablePipeline.Process($_)
    } catch {
        throw
    }
}

end {
    try {
        $steppablePipeline.End()
    } catch {
        throw
    }
}

clean {
    if ($null -ne $steppablePipeline) {
        $steppablePipeline.Clean()
    }
}
<#

.ForwardHelpTargetName Microsoft.PowerShell.Management\Restart-Computer
.ForwardHelpCategory Cmdlet

#>