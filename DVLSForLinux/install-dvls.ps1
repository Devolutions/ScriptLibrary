#!/usr/bin/env pwsh

Param(
    [string] $DVLSHostName,
    [string] $DVLSAdminEmail,
    [string] $DatabaseHost,
    [string] $DatabaseUsername,
    [string] $DatabasePassword,
    [Bool] $CreateDatabase = $True,
    [Bool] $EnableTelemetry = $True,
    [Bool] $Confirm = $True,
    [ValidateSet($Null, $True, $False)]
    [Bool] $DatabaseEncryptedConnection,
    [ValidateSet($Null, $True, $False)]
    [object] $DatabaseTrustServerCertificate,
    [ValidateSet($Null, $True, $False)]
    [object] $GenerateSelfSignedCertificate
)

$PwshExecutable = (Get-Process -Id $pid).Path
$DvlsForLinuxName = "Devolutions Server for Linux (Beta)"

Write-Host ("[{0}] Starting the $DvlsForLinuxName installation script" -F (Get-Date -Format "yyyyMMddHHmmss")) -ForegroundColor Green

# Test for sudo rights, without prompting for password
$sudoResult = & sudo -vn > /dev/null 2>&1 && sudo -ln > /dev/null 2>&1 

Switch ($sudoResult) {
    "*password is required*" {}
    "*may run*" {}
    "*sorry*" {
        Write-Error ("[{0}] $DvlsForLinuxName requires sudo privileges" -F (Get-Date -Format "yyyyMMddHHmmss"))
        Exit
    }
    Default {
        Write-Error ("[{0}] $DvlsForLinuxName requires sudo privileges" -F (Get-Date -Format "yyyyMMddHHmmss"))
        Exit
    }
}

$DVLSVariables = @{
    'DVLSProductURL'                 = "https://devolutions.net/productinfo.htm"
    'SystemDPath'                    = '/etc/systemd/system/dvls.service'
    'CurrentUser'                    = & logname
    'DVLSHostName'                   = ($DVLSHostName ? $DVLSHostName.Trim() : (Read-Host "Enter the hostname or IP of this server (what URL DVLS responds on)").Trim())
    'DVLSURI'                        = ""
    'DVLSAPP'                        = "dvls"
    'DVLSPath'                       = '/opt/devolutions/dvls'
    'DVLSExecutable'                 = '/opt/devolutions/dvls/Devolutions.Server'
    'DVLSUser'                       = 'dvls'
    'DVLSGroup'                      = 'dvls'
    'DatabaseHost'                   = ($DatabaseHost ? $DatabaseHost.Trim() : (Read-Host "Enter the database host").Trim())
    'DatabaseUsername'               = ($DatabaseUsername ? $DatabaseUsername.Trim() : (Read-Host "Enter the database username").Trim())
    'DatabasePassword'               = ($DatabasePassword ? $DatabasePassword.Trim() : (Read-Host "Enter the database user password" -MaskInput).Trim())
    'DatabaseEncryptedConnection'    = $Null
    'DatabaseTrustServerCertificate' = $Null
    'CreateDatabase'                 = $CreateDatabase
    'EnableTelemetry'                = $EnableTelemetry
    'DVLSAdminUsername'              = 'dvls-admin'
    'DVLSAdminPassword'              = 'dvls-admin'
    'DVLSAdminEmail'                 = ($DVLSAdminEmail ? $DVLSAdminEmail.Trim() : (Read-Host "Enter the email to use for the DVLS administrative user").Trim())
    'DVLSCertificate'                = $False
}

If (Test-Path -Path $DVLSVariables.SystemDPath) {
    Write-Error ("[{0}] An existing Devolutions Server of Linux (Beta) SystemD Unit file already appears, aborting installation" -F (Get-Date -Format "yyyyMMddHHmmss"))
    Exit
}

If ($GenerateSelfSignedCertificate -Is [Bool]) {
    $DVLSVariables.DVLSCertificate = [Bool]$GenerateSelfSignedCertificate
} Else {
    $DVLSVariables.DVLSCertificate = ($Host.UI.PromptForChoice("", "Generate self-signed certificate?", @('&Yes', '&No'), 1)) ? $False : $True
}

If ($DVLSVariables.DVLSCertificate) {
    $DVLSVariables.DVLSURI = ("https://{0}:5000/" -F $DVLSVariables.DVLSHostName)
} Else {
    $DVLSVariables.DVLSURI = ("http://{0}:5000/" -F $DVLSVariables.DVLSHostName)
}

If ($DatabaseEncryptedConnection -Is [Bool]) {
    $DVLSVariables.UseEncryptedConnection = [Bool]$DatabaseEncryptedConnection
} Else {
    # TODO: prompt
}

If ($DatabaseTrustServerCertificate -Is [Bool]) {
    $DVLSVariables.TrustServerCertificate = [Bool]$DatabaseTrustServerCertificate
} Else {
    # TODO: prompt
}

$DVLSVariables | Select-Object -Property @(
    'DVLSHostName'
    'DVLSURI'
    'DVLSPath'
    'DVLSUser'
    'DVLSGroup'
    'DVLSAdminUsername'
    'DVLSAdminPassword'
    'DVLSAdminEmail'
    'EnableTelemetry'
    'DVLSCertificate'
    'DatabaseHost'
    'DatabaseUsername'
    @{
        'Name'       = 'DatabaseEncryptedConnection'
        'Expression' = {
            If ($PSItem.DatabaseEncryptedConnection -Eq $Null) {
                'Undefined'
            } Else {
                $PSItem.DatabaseEncryptedConnection
            }
        }
    }
    @{
        'Name'       = 'DatabaseTrustServerCertificate'
        'Expression' = {
            If ($PSItem.DatabaseTrustServerCertificate -Eq $Null) {
                'Undefined'
            } Else {
                $PSItem.DatabaseTrustServerCertificate
            }
        }
    }
) | Format-List

If ($Confirm) {
    Write-Warning "If the above values look correct, enter [Y] or press Enter to continue" -WarningAction Inquire
}

Write-Verbose ("[{0}] Requesting 'sudo -v' for cached credentials" -F (Get-Date -Format "yyyyMMddHHmmss"))
& sudo -v

If (-Not [Bool](Get-Module -ListAvailable -Name 'Devolutions.PowerShell')) {
    Write-Host ("[{0}] Installing Devolutions.PowerShell module for all users" -F (Get-Date -Format "yyyyMMddHHmmss")) -ForegroundColor Green

    & sudo $PwshExecutable -Command {
        Install-Module -Name 'Devolutions.PowerShell' -Confirm:$False -Scope 'AllUsers' -Force
    }
}

Try {
    Import-Module -Name 'Devolutions.PowerShell' -Scope 'Global' -ErrorAction 'Stop'
} Catch {
    Write-Error ("[{0}] The Devolutions.PowerShell module failed to load, aborting installation" -F (Get-Date -Format "yyyyMMddHHmmss"))
    Exit
}

If (-Not [Bool](Get-Module -Name 'Devolutions.PowerShell')) {
    Write-Error ("[{0}] The Devolutions.PowerShell module failed to install, aborting installation" -F (Get-Date -Format "yyyyMMddHHmmss"))
    Exit
}

Write-Host ("[{0}] Creating user ({1}), group ({2}), and directory ({3})" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSUser, $DVLSVariables.DVLSGroup, $DVLSVariables.DVLSPath) -ForegroundColor Green

& sudo $PwshExecutable -Command {
    Param(
        $DVLSVariables
    )

    & useradd -N $DVLSVariables.DVLSUser
    & groupadd $DVLSVariables.DVLSGroup
    & usermod -a -G $DVLSVariables.DVLSGroup $DVLSVariables.DVLSUser
    & usermod -a -G $DVLSVariables.DVLSGroup $DVLSVariables.CurrentUser
    & mkdir -p $DVLSVariables.DVLSPath
    & chown -R ("{0}:{1}" -F $DVLSVariables.DVLSUser, $DVLSVariables.DVLSGroup) $DVLSVariables.DVLSPath
    & chmod 755 ([System.IO.DirectoryInfo]$DVLSVariables.DVLSPath).Parent
    & chmod 755 $DVLSVariables.DVLSPath
} -Args $DVLSVariables

Write-Verbose ("[{0}] Switching group to '{1}'" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSGroup)
& sg dvls -c "echo test > /dev/null 2>&1"

Write-Verbose ("[{0}] Validating users, groups, and directories" -F (Get-Date -Format "yyyyMMddHHmmss"))

$validateDVLSUser  = & id -u $DVLSVariables.DVLSUser
$validateDVLSGroup = & getent group $DVLSVariables.DVLSGroup

If (-Not $validateDVLSUser) {
    Write-Error ("[{0}] User, '{1}', is missing" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSUser)
    Exit
}

If (-Not $validateDVLSGroup) {
    Write-Error ("[{0}] Group, '{1}', is missing" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSGroup)
    Exit
}

$validateDVLSGroupUsers = (($validateDVLSGroup -Split ":")[-1] -Split ",")

If (-Not ($validateDVLSGroupUsers -Contains $DVLSVariables.DVLSUser -And $validateDVLSGroupUsers -Contains $DVLSVariables.CurrentUser)) {
    Write-Error ("[{0}] User, '{1}' and '{2}', are not members of the group, '{3}'" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSUser, $DVLSVariables.CurrentUser, $DVLSVariables.DVLSGroup)
    Exit
}

If (-Not ((& stat -c %a ([System.IO.DirectoryInfo]$DVLSVariables.DVLSPath).Parent) -EQ '755' -And (& stat -c %a $DVLSVariables.DVLSPath) -EQ '755')) {
    Write-Error ("[{0}] Permissions on '{1}' are incorrect" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSPath)
    Exit
}

If ( -Not
    (
        ((Get-Item -Path ([System.IO.DirectoryInfo]$DVLSVariables.DVLSPath).Parent).User -EQ $DVLSVariables.DVLSUser) -And
        ((Get-Item -Path ([System.IO.DirectoryInfo]$DVLSVariables.DVLSPath).Parent).Group -EQ $DVLSVariables.DVLSGroup) -And
        ((Get-Item -Path $DVLSVariables.DVLSPath).User -EQ $DVLSVariables.DVLSUser) -And
        ((Get-Item -Path $DVLSVariables.DVLSPath).Group -EQ $DVLSVariables.DVLSGroup)
    )
) {
    Write-Error ("[{0}] User and group assignments on directory, '{1}', are incorrect" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSPath)
    Exit
}

& sudo $PwshExecutable -Command {
    Param(
        $DVLSVariables
    )

    Set-Location -Path ([System.IO.DirectoryInfo]$DVLSVariables.DVLSPath).Parent | Out-Null

    $Result = (Invoke-RestMethod -Method 'GET' -Uri $DVLSVariables.DVLSProductURL) -Split "`r"

    $DVLSLinux = [PSCustomObject]@{
        "Version" = (($Result | Select-String DPSLinuxX64bin.Version) -Split "=")[-1].Trim()
        "URL"     = (($Result | Select-String DPSLinuxX64bin.Url) -Split "=")[-1].Trim()
        "Hash"    = (($Result | Select-String DPSLinuxX64bin.hash) -Split "=")[-1].Trim()
    }
    
    $DVLSDownloadPath = Join-Path -Path "/tmp" -ChildPath (([URI]$DVLSLinux.URL).Segments)[-1]

    Write-Host ("[{0}] Downloading and extracting latest $DvlsForLinuxName release: {1}" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSLinux.Version) -ForegroundColor Green

    Invoke-RestMethod -Method 'GET' -Uri $DVLSLinux.URL -OutFile $DVLSDownloadPath | Out-Null
    
    & tar -xzf $DVLSDownloadPath -C $DVLSVariables.DVLSPath --strip-components=1
    
    Remove-Item -Path $DVLSDownloadPath
} -Args $DVLSVariables

Write-Host ("[{0}] Modifying permissions on '{1}'" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSPath) -ForegroundColor Green

& sudo $PwshExecutable -Command {
    Param(
        $DVLSVariables
    )
    
    & chown -R ("{0}:{1}" -F $DVLSVariables.DVLSUser, $DVLSVariables.DVLSGroup) $DVLSVariables.DVLSPath
    & chmod -R o-rwx $DVLSVariables.DVLSPath
    & chmod 640 (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath 'appsettings.json')
    & chmod 750 (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath 'App_Data')
    & chown -R ("{0}:{1}" -F $DVLSVariables.DVLSUser, $DVLSVariables.DVLSGroup) $DVLSVariables.DVLSPath
} -Args $DVLSVariables

Write-Verbose ("[{0}] Validating appsettings.json exists" -F (Get-Date -Format "yyyyMMddHHmmss"))

$AppSettingsExists = & sudo $PwshExecutable -Command {
    Param(
        $DVLSVariables
    )

    Test-Path -Path (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath 'appsettings.json')
} -Args $DVLSVariables

If (-Not $AppSettingsExists) {
    Write-Error ("[{0}] appsettings.json does not exist or is inaccessible" -F (Get-Date -Format "yyyyMMddHHmmss"))
    Exit
}

Set-Location -Path $DVLSVariables.DVLSPath | Out-Null

Write-Host ("[{0}] Installing $DvlsForLinuxName" -F (Get-Date -Format "yyyyMMddHHmmss")) -ForegroundColor Green

$Params = @{
    "DatabaseHost"           = $DVLSVariables.DatabaseHost
    "DatabaseName"           = $DVLSVariables.DVLSAPP
    "DatabaseUserName"       = $DVLSVariables.DatabaseUsername
    "DatabasePassword"       = $DVLSVariables.DatabasePassword
    "ServerName"             = $DVLSVariables.DVLSAPP
    "AccessUri"              = $DVLSVariables.DVLSURI
    "HttpListenerUri"        = $DVLSVariables.DVLSURI
    "DPSPath"                = $DVLSVariables.DVLSPath
    "UseEncryptedConnection" = $DVLSVariables.UseEncryptedConnection
    "TrustServerCertificate" = $DVLSVariables.TrustServerCertificate
    "EnableTelemetry"        = $DVLSVariables.EnableTelemetry
    "DisableEncryptConfig"   = $True
}

$Configuration = New-DPSInstallConfiguration @Params

New-DPSAppsettings -Configuration $Configuration

$Settings = Get-DPSAppSettings -ApplicationPath $DVLSVariables.DVLSPath

If ($DVLSVariables.CreateDatabase) {
    New-DPSDatabase -ConnectionString $Settings.ConnectionStrings.LocalSqlServer
}

Update-DPSDatabase -ConnectionString $Settings.ConnectionStrings.LocalSqlServer -InstallationPath $DVLSVariables.DVLSPath

New-DPSDataSourceSettings -ConnectionString $Settings.ConnectionStrings.LocalSqlServer
New-DPSEncryptConfiguration -ApplicationPath $DVLSVariables.DVLSPath
New-DPSDatabaseAppSettings -Configuration $Configuration
New-DPSAdministrator -ConnectionString $Settings.ConnectionStrings.LocalSqlServer -Name $DVLSVariables.DVLSAdminUsername -Password $DVLSVariables.DVLSAdminPassword -Email $DVLSVariables.DVLSAdminEmail

If ($DVLSVariables.DVLSCertificate) {
    Write-Host ("[{0}] Generating self-signed certificate" -F (Get-Date -Format "yyyyMMddHHmmss")) -ForegroundColor Green

    & openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout cert.key -out cert.crt -subj ("/CN={0}" -F $DVLSVariables.DVLSHostName) -addext ("subjectAltName=IP:{0}" -F $DVLSVariables.DVLSHostName) > /dev/null 2>&1
    & openssl pkcs12 -export -out cert.pfx -inkey cert.key -in cert.crt -passout pass: > /dev/null 2>&1

    $JSON = Get-Content -Path (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath "appsettings.json") | ConvertFrom-JSON -Depth 100

    $JSON.Kestrel.Endpoints.Http | Add-Member -MemberType NoteProperty -Name "Certificate" -Value @{
        "Path"     = (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath "cert.pfx")
        "Password" = ""
    }

    $JSON | ConvertTo-JSON -Depth 100 | Set-Content -Path (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath "appsettings.json")

    Set-DPSAccessUri -ApplicationPath $DVLSVariables.DVLSPath -ConnectionString $Settings.ConnectionStrings.LocalSqlServer -AccessURI ("https://{0}:5000/" -F $DVLSVariables.DVLSHostName)

    & sudo $PwshExecutable -Command {
        Param(
            $DVLSVariables
        )
        
        & chown -R ("{0}:{1}" -F $DVLSVariables.DVLSUser, $DVLSVariables.DVLSGroup) (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath "cert.pfx")
    } -Args $DVLSVariables
}

Write-Host ("[{0}] Installing systemd unit file to '{1}'" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.SystemDPath) -ForegroundColor Green

$SystemDTemplate = @"
[Unit]
Description=DVLS
[Service]
Type=simple
Restart=always
RestartSec=10
User=$($DVLSVariables.DVLSUser)
ExecStart=$($DVLSVariables.DVLSExecutable)
WorkingDirectory=$($DVLSVariables.DVLSPath)
KillSignal=SIGINT
SyslogIdentifier=dvls
[Install]
WantedBy=multi-user.target
Alias=dvls.service
"@

& sudo $PwshExecutable -Command { Param($DVLSVariables, $SystemDTemplate); Set-Content -Path $DVLSVariables.SystemDPath -Value $SystemDTemplate -Force; & systemctl daemon-reload } -Args $DVLSVariables, $SystemDTemplate

If (-Not (Test-Path -Path $DVLSVariables.SystemDPath)) {
    Write-Error ("[{0}] systemd unit file missing at '{1}'" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.SystemDPath)
    Exit
}

Write-Host ("[{0}] Starting $DvlsForLinuxName at '{1}' - 15 Second Sleep" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSURI) -ForegroundColor Green

& sudo systemctl start dvls.service

Start-Sleep -Seconds 15

Write-Host ("[{0}] Restart $DvlsForLinuxName at '{1}'" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSURI) -ForegroundColor Green

& sudo systemctl restart dvls.service

$Result = & systemctl list-units --type=service --all --no-pager dvls.service --no-legend

If ($Result) {
    $ID, $Load, $Active, $Status, $Description = ($Result.Trim()) -Split '\s+', 5

    If ($ID -And $Active -And ($Status -EQ 'running')) {
        Write-Host ("[{0}] $DvlsForLinuxName is running" -F (Get-Date -Format "yyyyMMddHHmmss")) -ForegroundColor Green
    } Else {
        Write-Error ("[{0}] $DvlsForLinuxName service status was not found" -F (Get-Date -Format "yyyyMMddHHmmss"))
    }
} Else {
    Write-Error ("[{0}] $DvlsForLinuxName failed to start" -F (Get-Date -Format "yyyyMMddHHmmss"))
}
