#!/usr/bin/env pwsh

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'DatabasePassword')]
Param(
    [String] $DVLSHostName,
    [String] $DVLSAdminEmail,
    [String] $DatabaseHost,
    [String] $DatabaseUsername,
    [String] $DatabasePassword,
    [String] $DatabaseName,
    [Bool] $CreateDatabase = $True,
    [Bool] $EnableTelemetry = $True,
    [Bool] $Confirm = $True,
    [ValidateSet($Null, $True, $False)]
    [Bool] $DatabaseEncryptedConnection,
    [ValidateSet($Null, $True, $False)]
    [Bool] $DatabaseTrustServerCertificate,
    [ValidateSet($Null, $True, $False)]
    [Bool] $GenerateSelfSignedCertificate,
    [String] $ZipFile
)

#region Setup variables

# Retrieve PowerShell executable to support PowerShell Preview
$PwshExecutable = (Get-Process -Id $pid).Path
$DvlsForLinuxName = "Devolutions Server for Linux (Beta)"
$originalLocation = (Get-Location).Path

Write-Host ("[{0}] Starting the $DvlsForLinuxName installation script" -F (Get-Date -Format "yyyyMMddHHmmss")) -ForegroundColor Green

# Test for sudo rights, without prompting for password.
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
    'DatabaseName'                   = ($DatabaseName ? $DatabaseName.Trim() : (Read-Host "Enter the database name (press enter to use the default: 'dvls')").Trim())
    'DatabaseEncryptedConnection'    = $Null
    'DatabaseTrustServerCertificate' = $Null
    'CreateDatabase'                 = $CreateDatabase
    'EnableTelemetry'                = $EnableTelemetry
    'DVLSAdminUsername'              = 'dvls-admin'
    'DVLSAdminPassword'              = 'dvls-admin'
    'DVLSAdminEmail'                 = ($DVLSAdminEmail ? $DVLSAdminEmail.Trim() : (Read-Host "Enter the email to use for the DVLS administrative user").Trim())
    'DVLSCertificate'                = $False
    'ZipFile'                        = ($ZipFile ? $ZipFile.Trim() : $Null)
    'TmpFolder'                      = "/tmp/devolutions-dvls-installation-script/"
}

if (-not (Test-Path -Path $DVLSVariables.TmpFolder)) {
    # Create the temporary directory we'll use across the script.
    New-Item -Path $DVLSVariables.TmpFolder -ItemType Directory | Out-Null
}

if (Test-Path -Path $DVLSVariables.SystemDPath) {
    Write-Error ("[{0}] An existing $DvlsForLinuxName SystemD Unit file already appears, aborting installation" -F (Get-Date -Format "yyyyMMddHHmmss"))
    Exit
}

if ($GenerateSelfSignedCertificate -is [Bool]) {
    $DVLSVariables.DVLSCertificate = [Bool]$GenerateSelfSignedCertificate
}
else {
    $DVLSVariables.DVLSCertificate = ($Host.UI.PromptForChoice("", "Generate self-signed certificate?", @('&Yes', '&No'), 1)) ? $False : $True
}

if ($DVLSVariables.DVLSCertificate) {
    $DVLSVariables.DVLSURI = ("https://{0}:5000/" -F $DVLSVariables.DVLSHostName)
}
else {
    $DVLSVariables.DVLSURI = ("http://{0}:5000/" -F $DVLSVariables.DVLSHostName)
}

if ([String]::IsNullOrWhiteSpace($DVLSVariables.DatabaseName)) {
    $DVLSVariables.DatabaseName = 'dvls'
}

if ($DatabaseEncryptedConnection -and $DatabaseEncryptedConnection -is [Bool]) {
    $DVLSVariables.DatabaseEncryptedConnection = [Bool]$DatabaseEncryptedConnection
}
else {
    $DVLSVariables.DatabaseEncryptedConnection = ($Host.UI.PromptForChoice("", "Is connection to DB encrypted (default is no)?", @('&Yes', '&No'), 1)) ? $False : $True
}

if ($DatabaseTrustServerCertificate -and $DatabaseTrustServerCertificate -is [Bool]) {
    $DVLSVariables.DatabaseTrustServerCertificate = [Bool]$DatabaseTrustServerCertificate
}
else {
    $DVLSVariables.DatabaseTrustServerCertificate = ($Host.UI.PromptForChoice("", "Trust the database server certificate (default is no)?", @('&Yes', '&No'), 1)) ? $False : $True
}

# Allow for pre-created databases
if ($CreateDatabase -and $CreateDatabase -is [Bool]) {
    $DVLSVariables.CreateDatabase = [Bool]$CreateDatabase
}
else {
    $DVLSVariables.CreateDatabase = ($Host.UI.PromptForChoice("", "Create the database (default is yes)?", @('&Yes', '&No'), 0)) ? $False : $True
}

if ($DVLSVariables.ZipFile -and -not ((Get-Item -Path $DVLSVariables.ZipFile -ErrorAction 'SilentlyContinue').FullName)) {
    Write-Error ("[{0}] Unable to locate passed zip file: {1}" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.ZipFile)
    Exit
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
    'CreateDatabase'
    'DatabaseHost'
    'DatabaseUsername'
    'DatabaseName'
    @{
        'Name'       = 'DatabaseEncryptedConnection'
        'Expression' = {
            if ($PSItem.DatabaseEncryptedConnection -eq $Null) {
                'Undefined'
            }
            else {
                $PSItem.DatabaseEncryptedConnection
            }
        }
    }
    @{
        'Name'       = 'DatabaseTrustServerCertificate'
        'Expression' = {
            if ($PSItem.DatabaseTrustServerCertificate -eq $Null) {
                'Undefined'
            }
            else {
                $PSItem.DatabaseTrustServerCertificate
            }
        }
    }
    @{
        'Name'       = 'ZipFile'
        'Expression' = {
            if ($PSItem.ZipFile -eq $Null) {
                'Undefined'
            }
            else {
                $PSItem.ZipFile
            }
        }
    }
) | Format-List

if ($Confirm) {
    Write-Warning "If the above values look correct, enter [Y] or press Enter to continue" -WarningAction Inquire
}

# Cache Sudo prompt for remainder of the script
Write-Verbose ("[{0}] Requesting 'sudo -v' for cached credentials" -F (Get-Date -Format "yyyyMMddHHmmss"))
& sudo -v

if (-not [Bool](Get-Module -ListAvailable -Name 'Devolutions.PowerShell')) {
    Write-Host ("[{0}] Installing Devolutions.PowerShell module for all users" -F (Get-Date -Format "yyyyMMddHHmmss")) -ForegroundColor Green

    & sudo $PwshExecutable -Command {
        Install-Module -Name 'Devolutions.PowerShell' -Confirm:$False -Scope 'AllUsers' -Force
    }
}

try {
    Import-Module -Name 'Devolutions.PowerShell' -Scope 'Global' -ErrorAction 'Stop'
}
catch {
    Write-Error ("[{0}] The Devolutions.PowerShell module failed to load, aborting installation" -F (Get-Date -Format "yyyyMMddHHmmss"))
    Exit
}

if (-not [Bool](Get-Module -Name 'Devolutions.PowerShell')) {
    Write-Error ("[{0}] The Devolutions.PowerShell module failed to install, aborting installation" -F (Get-Date -Format "yyyyMMddHHmmss"))
    Exit
}
#endregion

#region Setup users, groups, and directories
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
    & chmod 550 $DVLSVariables.DVLSPath
} -Args $DVLSVariables

# Allows user currently executing script to have membership in newly created group without relaunching script
Write-Verbose ("[{0}] Switching group to '{1}'" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSGroup)
& sg $DVLSVariables.DVLSGroup -c "echo test > /dev/null 2>&1"

Write-Verbose ("[{0}] Validating users, groups, and directories" -F (Get-Date -Format "yyyyMMddHHmmss"))

$validateDVLSUser = & id -u $DVLSVariables.DVLSUser
$validateDVLSGroup = & getent group $DVLSVariables.DVLSGroup

if (-not $validateDVLSUser) {
    Write-Error ("[{0}] User, '{1}', is missing" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSUser)
    Exit
}

if (-not $validateDVLSGroup) {
    Write-Error ("[{0}] Group, '{1}', is missing" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSGroup)
    Exit
}

$validateDVLSGroupUsers = (($validateDVLSGroup -Split ":")[-1] -Split ",")

if (-not ($validateDVLSGroupUsers -Contains $DVLSVariables.DVLSUser -and $validateDVLSGroupUsers -Contains $DVLSVariables.CurrentUser)) {
    Write-Error ("[{0}] User, '{1}' and '{2}', are not members of the group, '{3}'" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSUser, $DVLSVariables.CurrentUser, $DVLSVariables.DVLSGroup)
    Exit
}

if (-not ((& stat -c %a $DVLSVariables.DVLSPath) -eq '550')) {
    Write-Error ("[{0}] Permissions on '{1}' are incorrect" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSPath)
    Exit
}

if (-not
    (
        ((Get-Item -Path $DVLSVariables.DVLSPath).User -eq $DVLSVariables.DVLSUser) -and
        ((Get-Item -Path $DVLSVariables.DVLSPath).Group -eq $DVLSVariables.DVLSGroup)
    )
) {
    Write-Error ("[{0}] User and group assignments on directory, '{1}', are incorrect" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSPath)
    Exit
}
#endregion

#region Retrieve DVLS
& sudo $PwshExecutable -Command {
    Param(
        $DVLSVariables,
        $DVLSForLinuxName
    )

    if (-not $DVLSVariables.ZipFile) {
        $Result = (Invoke-RestMethod -Method 'GET' -Uri $DVLSVariables.DVLSProductURL) -Split "`r"

        $DVLSLinux = [PSCustomObject]@{
            "Version" = (($Result | Select-String DPSLinuxX64bin.Version) -Split "=")[-1].Trim()
            "URL"     = (($Result | Select-String DPSLinuxX64bin.Url) -Split "=")[-1].Trim()
            "Hash"    = (($Result | Select-String DPSLinuxX64bin.hash) -Split "=")[-1].Trim()
        }
        
        $DVLSFilePath = Join-Path -Path $DVLSVariables.TmpFolder -ChildPath (([URI]$DVLSLinux.URL).Segments)[-1]

        Write-Host ("[{0}] Downloading and extracting latest $DVLSForLinuxName release: {1}" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSLinux.Version) -ForegroundColor Green

        Invoke-RestMethod -Method 'GET' -Uri $DVLSLinux.URL -OutFile $DVLSFilePath | Out-Null
    }
    else {
        $ResolvedCopy = Copy-Item -Path $DVLSVariables.ZipFile -Destination $DVLSVariables.TmpFolder -PassThru

        $DVLSFilePath = $ResolvedCopy.FullName
    }
    
    & tar -xzf $DVLSFilePath -C $DVLSVariables.DVLSPath --strip-components=1
    
    Remove-Item -Path $DVLSFilePath
} -Args $DVLSVariables, $DVLSForLinuxName

Write-Host ("[{0}] Modifying permissions on '{1}'" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSPath) -ForegroundColor Green

& sudo $PwshExecutable -Command {
    Param(
        $DVLSVariables
    )
    
    & chown -R ("{0}:{1}" -F $DVLSVariables.DVLSUser, $DVLSVariables.DVLSGroup) $DVLSVariables.DVLSPath
    & chmod -R o-rwx $DVLSVariables.DVLSPath
    & chmod 660 (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath 'appsettings.json')
    & chmod 770 (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath 'App_Data')
    & chown -R ("{0}:{1}" -F $DVLSVariables.DVLSUser, $DVLSVariables.DVLSGroup) $DVLSVariables.DVLSPath
} -Args $DVLSVariables

Write-Verbose ("[{0}] Validating appsettings.json exists" -F (Get-Date -Format "yyyyMMddHHmmss"))

$AppSettingsExists = & sudo $PwshExecutable -Command {
    Param(
        $DVLSVariables
    )

    Test-Path -Path (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath 'appsettings.json')
} -Args $DVLSVariables

if (-not $AppSettingsExists) {
    Write-Error ("[{0}] appsettings.json does not exist or is inaccessible" -F (Get-Date -Format "yyyyMMddHHmmss"))
    Exit
}

Set-Location -Path $DVLSVariables.DVLSPath | Out-Null
#endregion

#region Install DVLS
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

if ($DVLSVariables.CreateDatabase) {
    New-DPSDatabase -ConnectionString $Settings.ConnectionStrings.LocalSqlServer
}

Update-DPSDatabase -ConnectionString $Settings.ConnectionStrings.LocalSqlServer -InstallationPath $DVLSVariables.DVLSPath

New-DPSDataSourceSettings -ConnectionString $Settings.ConnectionStrings.LocalSqlServer
New-DPSEncryptConfiguration -ApplicationPath $DVLSVariables.DVLSPath
New-DPSDatabaseAppSettings -Configuration $Configuration
New-DPSAdministrator -ConnectionString $Settings.ConnectionStrings.LocalSqlServer -Name $DVLSVariables.DVLSAdminUsername -Password $DVLSVariables.DVLSAdminPassword -Email $DVLSVariables.DVLSAdminEmail

if ($DVLSVariables.DVLSCertificate) {
    Write-Host ("[{0}] Generating self-signed certificate" -F (Get-Date -Format "yyyyMMddHHmmss")) -ForegroundColor Green

    $keyFile = "cert.key"
    $keyTmpPath = Join-Path -Path $DVLSVariables.TmpFolder -ChildPath $keyFile
    $keyDvlsPath = Join-Path -Path $DVLSVariables.DVLSPath -ChildPath $keyFile

    $crtFile = "cert.crt"
    $crtTmpPath = Join-Path -Path $DVLSVariables.TmpFolder -ChildPath $crtFile
    $crtDvlsPath = Join-Path -Path $DVLSVariables.DVLSPath -ChildPath $crtFile

    $pfxFile = "cert.pfx"
    $pfxTmpPath = Join-Path -Path $DVLSVariables.TmpFolder -ChildPath $pfxFile
    $pfxDvlsPath = Join-Path -Path $DVLSVariables.DVLSPath -ChildPath $pfxFile


    if ($DVLSVariables.DVLSHostName -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$" -and [Bool]($DVLSVariables.DVLSHostName -As [IPAddress])) {
        & openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout $keyTmpPath -out $crtTmpPath -subj ("/CN={0}" -F $DVLSVariables.DVLSHostName) -addext ("subjectAltName=IP:{0}" -F $DVLSVariables.DVLSHostName) > /dev/null 2>&1
    } else {
        & openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout $keyTmpPath -out $crtTmpPath -subj ("/CN={0}" -F $DVLSVariables.DVLSHostName) -addext ("subjectAltName=DNS:{0}" -F $DVLSVariables.DVLSHostName) > /dev/null 2>&1
    }

    & openssl pkcs12 -export -out $pfxTmpPath -inkey $keyTmpPath -in $crtTmpPath -passout pass: > /dev/null 2>&1

    & sudo $PwshExecutable -Command {
        Param(
            $keyTmpPath,
            $keyDvlsPath,
            $crtTmpPath,
            $crtDvlsPath,
            $pfxTmpPath,
            $pfxDvlsPath
        )

        Move-Item -Path $keyTmpPath -Destination $keyDvlsPath
        Move-Item -Path $crtTmpPath -Destination $crtDvlsPath
        Move-Item -Path $pfxTmpPath -Destination $pfxDvlsPath
    } -Args $keyTmpPath, $keyDvlsPath, $crtTmpPath, $crtDvlsPath, $pfxTmpPath, $pfxDvlsPath

    $JSON = Get-Content -Path (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath "appsettings.json") | ConvertFrom-Json -Depth 100

    $JSON.Kestrel.Endpoints.Http | Add-Member -MemberType NoteProperty -Name "Certificate" -Value @{
        "Path"     = $pfxDvlsPath
        "Password" = ""
    }

    $JSON | ConvertTo-Json -Depth 100 | Set-Content -Path (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath "appsettings.json")

    Set-DPSAccessUri -ApplicationPath $DVLSVariables.DVLSPath -ConnectionString $Settings.ConnectionStrings.LocalSqlServer -AccessURI ("https://{0}:5000/" -F $DVLSVariables.DVLSHostName)

    & sudo $PwshExecutable -Command {
        Param(
            $DVLSVariables
        )

        & chown ("{0}:{1}" -F $DVLSVariables.DVLSUser, $DVLSVariables.DVLSGroup) (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath "cert.pfx")
        & chown ("{0}:{1}" -F $DVLSVariables.DVLSUser, $DVLSVariables.DVLSGroup) (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath "cert.crt")
        & chown ("{0}:{1}" -F $DVLSVariables.DVLSUser, $DVLSVariables.DVLSGroup) (Join-Path -Path $DVLSVariables.DVLSPath -ChildPath "cert.key")
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

& sudo $PwshExecutable -Command {
    Param(
        $DVLSVariables,
        $SystemDTemplate
    )
    
    Set-Content -Path $DVLSVariables.SystemDPath -Value $SystemDTemplate -Force
    & systemctl daemon-reload
} -Args $DVLSVariables, $SystemDTemplate

if (-not (Test-Path -Path $DVLSVariables.SystemDPath)) {
    Write-Error ("[{0}] systemd unit file missing at '{1}'" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.SystemDPath)
    Exit
}

Set-Location -Path $originalLocation | Out-Null
#endregion

#region Start DVLS
Write-Host ("[{0}] Starting $DvlsForLinuxName at '{1}' - 15 Second Sleep" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSURI) -ForegroundColor Green

& sudo systemctl start dvls.service

Start-Sleep -Seconds 15

Write-Host ("[{0}] Restart $DvlsForLinuxName at '{1}'" -F (Get-Date -Format "yyyyMMddHHmmss"), $DVLSVariables.DVLSURI) -ForegroundColor Green

& sudo systemctl restart dvls.service

$Result = & systemctl list-units --type=service --all --no-pager dvls.service --no-legend

if ($Result) {
    $ID, $Load, $Active, $Status, $Description = ($Result.Trim()) -Split '\s+', 5

    if ($ID -and $Active -and ($Status -eq 'running')) {
        Write-Host ("[{0}] $DvlsForLinuxName is running" -F (Get-Date -Format "yyyyMMddHHmmss")) -ForegroundColor Green
    }
    else {
        Write-Error ("[{0}] $DvlsForLinuxName service status was not found" -F (Get-Date -Format "yyyyMMddHHmmss"))
    }
}
else {
    Write-Error ("[{0}] $DvlsForLinuxName failed to start" -F (Get-Date -Format "yyyyMMddHHmmss"))
}
#endregion
