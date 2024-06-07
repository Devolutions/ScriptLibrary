<#
.SYNOPSIS
    Retrieves user session information from event logs, including logon and logoff times.

.DESCRIPTION
    This script queries the event logs to determine user session activity, including logon and logoff events. It handles various
    session start and stop events, processes the events to extract relevant information such as username, logon ID, and logon type,
    and attempts to match logoff events to logon events to calculate session duration.

.NOTES
    More information about XPath queries in event logs: https://docs.microsoft.com/en-us/windows/win32/wes/querying-for-event-data

.EXAMPLE
    PS> Get-UserLogonHistory

    Retrieves a list of historical user sessions.
#>

[CmdletBinding()]
param
()

function Get-LoggedInUser {
    Get-Process -IncludeUserName | Where-Object { $_.UserName -and $_.UserName -notmatch "^NT *|^Window Manager" } | Select-Object -ExpandProperty UserName -Unique
}

function GetEventUserName {
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$EventRecord
    )

    $script:eventNamespace.AddNamespace("evt", "http://schemas.microsoft.com/win/2004/08/events/event")
    $targetUserName = $EventRecord.SelectSingleNode("//evt:Data[@Name='TargetUserName']", $script:eventNamespace).InnerText
    $targetDomainName = $EventRecord.SelectSingleNode("//evt:Data[@Name='TargetDomainName']", $script:eventNamespace).InnerText

    if ($targetDomainName) {
        "$targetDomainName\$targetUserName"
    } else {
        $targetUserName
    }
    
}

function GetEventLogonType {
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$EventRecord
    )

    ($EventRecord.Event.EventData.Data | Where-Object { $_.Name -eq 'LogonType' }).'#text'
}

function GetUserLogonId {
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$EventRecord
    )

    $userLogonId = ($EventRecord.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetLogonId' }).'#text'
    if (-not $userLogonId) {
        $userLogonId = ($EventRecord.Event.EventData.Data | Where-Object { $_.Name -eq 'LogonId' }).'#text'
    }

    $userLogonId
}

function GetLogoffEvent {
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [datetime]$LogonStartTime,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$UserLogonId
    )

    ## This assumes event is the most recent one that matches the criteria
    @($script:Events).where({ 
            $xEvt = [xml]$_.ToXml()
            [datetime]$_.TimeCreated -gt $LogonStartTime -and
            $_.ID -in $script:sessionStopIds -and
            (GetUserLogonId -EventRecord $xEvt) -eq $UserLogonId
        }) | Select-Object -Last 1
}

try {
	
    #region Defie all of the events to indicate session start or top
    $sessionEvents = @(
        @{ 'Label' = 'Logon'; 'EventType' = 'SessionStart'; 'LogName' = 'Security'; 'ID' = 4624 } ## Advanced Audit Policy --> System Audit Policies --> Logon/Logoff --> Audit Logon
        @{ 'Label' = 'Logoff'; 'EventType' = 'SessionStop'; 'LogName' = 'Security'; 'ID' = 4647 } ## Advanced Audit Policy --> System Audit Policies --> Logon/Logoff --> Audit Logoff
        @{ 'Label' = 'Startup'; 'EventType' = 'SessionStop'; 'LogName' = 'System'; 'ID' = 6005 } ## Audit Policy --> Audit System Events
        @{ 'Label' = 'RdpSessionReconnect'; 'EventType' = 'SessionStart'; 'LogName' = 'Security'; 'ID' = 4778 } ## Advanced Audit Policy --> System Audit Policies --> Logon/Logoff --> Audit Other Logon/Logoff Events
        @{ 'Label' = 'RdpSessionDisconnect'; 'EventType' = 'SessionStop'; 'LogName' = 'Security'; 'ID' = 4779 } ## Advanced Audit Policy --> System Audit Policies --> Logon/Logoff --> Audit Other Logon/Logoff Events
        @{ 'Label' = 'Locked'; 'EventType' = 'SessionStop'; 'LogName' = 'Security'; 'ID' = 4800 } ## Advanced Audit Policy --> System Audit Policies --> Logon/Logoff --> Audit Other Logon/Logoff Events
        @{ 'Label' = 'Unlocked'; 'EventType' = 'SessionStart'; 'LogName' = 'Security'; 'ID' = 4801 } ## Advanced Audit Policy --> System Audit Policies --> Logon/Logoff --> Audit Other Logon/Logoff Events
    )
    
    ## All of the IDs that designate when user activity starts
    $sessionStartIds = ($sessionEvents | Where-Object { $_.EventType -eq 'SessionStart' }).ID
    ## All of the IDs that designate when user activity stops
    $script:sessionStopIds = ($sessionEvents | Where-Object { $_.EventType -eq 'SessionStop' }).ID
    #endregion
	
    ## Define all of the log names we'll be querying
    $logNames = ($sessionEvents.LogName | Select-Object -Unique)

    ## These are not all logon types but only those that are relevant to user activity (not internal services)
    $userLogonTypes = @{
        2  = "Interactive"
        7  = "Unlock"
        10 = "RemoteInteractive"
        11 = "CachedInteractive"
    }
		
    ## Build the XPath query for the security event log in order to query events as fast as possible
    ## It would be better if TargetDomainName could be filtered by anything with a space in it but due to XPath 1.0
    ## restrictions, it's not possible.
    $xPath = @"
*[
    (
        EventData[Data[@Name='TargetDomainName'] != 'Window Manager'] and
        EventData[Data[@Name='TargetDomainName'] != 'NT AUTHORITY'] and
        EventData[Data[@Name='TargetDomainName'] != 'Font Driver Host']
    ) and 
        (EventData[Data[@Name='LogonType'] = '$($userLogonTypes.Keys -join "'] or 
        EventData[Data[@Name='LogonType'] = '")']
    ) or
    (
        System[
            (EventID=$($script:sessionStopIds -join " or EventID="))
        ]
    )
]
"@
    ## Query the computer's event logs using the Xpath filter
    if (-not ($script:events = Get-WinEvent -LogName $logNames -FilterXPath $xPath)) {
        Write-Warning -Message 'No logon events found'.
    } else {
        $script:eventNamespace = New-Object System.Xml.XmlNamespaceManager(([xml]$script:events[0].ToXml()).NameTable)
        Write-Verbose -Message "Found [$($script:events.Count)] events to look through"
        
        $loggedInUsers = Get-LoggedInUser

        ## Find all user start activity events and begin parsing
        @($script:events).where({ $_.Id -in $sessionStartIds }).foreach({
                try {
                    $xEvt = [xml]$_.ToXml()

                    $userName = GetEventUserName -Event $xEvt
                    $logonEvtId = $_.Id

                    $startTime = $_.TimeCreated

                    $userLogonId = GetUserLogonId -EventRecord $xEvt

                    $userLogonType = GetEventLogonType -EventRecord $xEvt

                    Write-Verbose -Message "New session start event found: event ID [$logonEvtId] username [$userName] user logonID [$($userLogonId)] user logon type [$userLogonType] time [$($startTime)]"
                    ## Try to match up the user activity end event with the start event we're processing
                    if (-not ($logoffEvent = GetLogoffEvent -LogonStartTime $startTime -UserLogonId $userLogonId)) {
                        ## If no logoff event is found, the user might still be logged in
                        if ($userName -in $loggedInUsers) {
                            $stopTime = Get-Date
                            $stopAction = 'Still logged in'
                        } else {
                            throw "Could not find a session end event for logon ID [$($userLogonId)] username [$userName] start event time [$startTime]."
                        }
                    } else {
                        ## Capture the user activity end time
                        $stopTime = $logoffEvent.TimeCreated
                        Write-Verbose -Message "Session stop event ID is [$($logoffEvent.Id)]"
                        $stopAction = @($sessionEvents).where({ $_.ID -eq $logoffEvent.Id }).Label
                    }

                    $sessionTimespan = New-TimeSpan -Start $startTime -End $stopTime

                    [pscustomobject]@{
                        'Username'            = $userName
                        'UserLogonId'         = $userLogonId
                        'StartTime'           = $startTime
                        'StartAction'         = @($sessionEvents).where({ $_.ID -eq $logonEvtId }).Label
                        'StopTime'            = $stopTime ? $stopTime : 'Still logged in'
                        'StopAction'          = $stopTime ? $stopAction : 'Still logged in'
                        'Session Active Time' = $sessionTimespan
                    }
                } catch {
                    Write-Warning -Message $_.Exception.Message
                }
            })
    }
} catch {
    $PSCmdlet.ThrowTerminatingError($_)
}