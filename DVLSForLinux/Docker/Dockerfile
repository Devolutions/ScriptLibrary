# escape=`
# Make sure to save this with the LF carriage return, not CRLF (otherwise multi-line commands will not work)

FROM ubuntu:22.04

# Defining the ARG after the FROM command means that the variables do not get cleared and redefined
ARG DVLS_HOSTNAME `
    DVLS_ADMIN_EMAIL `
    DVLS_ADMIN_USERNAME `
    DVLS_ADMIN_PASSWORD `
    ENABLE_TELEMETRY `
    GENERATE_SELFSIGNED_CERTIFICATE `
    S6_OVERLAY_VERSION `
    POWERSHELL_VERSION `
    DEVOLUTIONS_MODULE_VERSION `
    DVLS_VERSION `
    DVLS_PATH

# Assigning the ARG values to ENV using the format of `${VARIABLE:-DEFAULTVALUE}` allows for overriding
# - S6_KEEP_ENV allows defined environmental variables in Docker to travel into sub-processes of s6-overlay
ENV DVLS_HOSTNAME=${DVLS_HOSTNAME:-"dvls"} `
    DVLS_ADMIN_EMAIL=${DVLS_ADMIN_EMAIL:-"admin@replaceme.com"} `
    DVLS_ADMIN_USERNAME=${DVLS_ADMIN_USERNAME:-"dvls-admin"} `
    DVLS_ADMIN_PASSWORD=${DVLS_ADMIN_PASSWORD:-"dvls-admin"} `
    ENABLE_TELEMETRY=${ENABLE_TELEMETRY:-"true"} `
    GENERATE_SELFSIGNED_CERTIFICATE=${GENERATE_SELFSIGNED_CERTIFICATE:-"false"} `
    S6_OVERLAY_VERSION=${S6_OVERLAY_VERSION:-"3.2.0.2"} `
    POWERSHELL_VERSION=${POWERSHELL_VERSION:-"7.4.6"} `
    DEVOLUTIONS_MODULE_VERSION=${DEVOLUTIONS_MODULE_VERSION:-"2024.3.5"} `
    DVLS_VERSION=${DVLS_VERSION:-"latest"} `
    DVLS_PATH=${DVLS_PATH:-"/opt/devolutions/dvls"} `
    DOTNET_RUNNING_IN_CONTAINER="true" `
    SCHEDULER_EMBEDDED="true" `
    S6_KEEP_ENV=1 ` 
    S6_LOGGING=2

RUN <<EOF
    apt update    
    apt install -y sudo wget curl

    curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
    wget -O /tmp/packages-microsoft-prod.deb -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
    dpkg -i /tmp/packages-microsoft-prod.deb
    rm /tmp/packages-microsoft-prod.deb

    apt update
    apt upgrade -y
    apt install -y apt-transport-https software-properties-common nano xz-utils apt-utils powershell openssl
EOF

# Install s6-overlay
ADD "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz
ENV PATH="${PATH}:/command"

# Add mssql-tools to image
RUN <<EOF
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
    sudo ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev
EOF

ENV PATH="${PATH}:/opt/mssql-tools/bin"

# Add the base DVLS installation
# Build-time environmental variables are available here
RUN <<"EOF"
cat <<'EOC' >> /tmp/prep.ps1
try
{
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -ErrorAction 'Stop'
    Install-Module -Name 'Devolutions.PowerShell' -RequiredVersion $($Env:DEVOLUTIONS_MODULE_VERSION) -Confirm:$False -ErrorAction 'Stop'
}
catch
{
    Write-Error ("[{0}] Failed to load Devolutions PowerShell module: {1}" -F (Get-Date -Format "yyyyMMddHHmmss"), $PSItem.Exception.Message) >> /proc/1/fd/1
    Exit
}

Import-Module -Name 'Devolutions.PowerShell'

$DVLSPath = "$($Env:DVLS_PATH)"
$DVLSProductURL = "https://devolutions.net/productinfo.htm"

New-Item -Itemtype 'Directory' -Path $DVLSPath

Set-Location -Path ([System.IO.DirectoryInfo]$DVLSPath).Parent | Out-Null

$Result = (Invoke-RestMethod -Method GET -Uri $DVLSProductURL) -Split "`r"

$DVLSLinux = [PSCustomObject]@{
    "Version" = (($Result | Select-String DPSLinuxX64bin.Version) -Split "=")[-1].Trim()
    "URL"     = (($Result | Select-String DPSLinuxX64bin.Url) -Split "=")[-1].Trim()
    "Hash"    = (($Result | Select-String DPSLinuxX64bin.hash) -Split "=")[-1].Trim()
}

if (-not [String]::IsNullOrWhiteSpace($($Env:DVLS_VERSION)) -and -not ($($Env:DVLS_VERSION) -eq 'latest'))
{
    $DVLSSpecificVersionURL = ($DVLSLinux.URL) -Replace $DVLSLinux.Version, $Env:DVLS_VERSION
}
else
{
    $DVLSSpecificVersionURL = $DVLSLinux.URL
}

Invoke-RestMethod -Method 'GET' -Uri $DVLSSpecificVersionURL -OutFile (([URI]$DVLSSpecificVersionURL).Segments)[-1] | Out-Null

& tar -xzf (([URI]$DVLSSpecificVersionURL).Segments)[-1] -C $DVLSPath --strip-components=1

Remove-Item -Path (Join-Path -Path ([System.IO.DirectoryInfo]$DVLSPath).Parent -ChildPath (([URI]$DVLSSpecificVersionURL).Segments)[-1]) -Force
EOC
EOF

RUN /usr/bin/pwsh -File /tmp/prep.ps1

# Install DVLS on first-run of the container
# - Run-time variables are not available here
# - Verify that the database container is accessible before proceeding
RUN <<"EOF"
cat <<'EOC' >> /tmp/init.ps1
& /opt/mssql-tools/bin/sqlcmd -S mssql -U sa -P $Env:MSSQL_SA_PASSWORD -Q "Select 1" -C -b -o /dev/null

if ($LASTEXITCODE -ne 0)
{
    & kill -s SIGTERM 1
}

$DBTest = & /opt/mssql-tools/bin/sqlcmd -S mssql -U sa -P $Env:MSSQL_SA_PASSWORD -Q "IF EXISTS (SELECT * FROM sys.databases WHERE name = 'dvls') BEGIN SELECT 1 END" -C -b

if ($DBTest -ne $null) {
    exit
}

if (-not [String]::IsNullOrWhiteSpace($($Env:DVLS_HOSTNAME)))
{
    $DVLSHostName = ($Env:DVLS_HOSTNAME).Trim()
}
else
{
    $DVLSHostName = (hostname -i).Trim()
}

if ($Env:GENERATE_SELFSIGNED_CERTIFICATE -eq 'true')
{
    $DVLSURI = ("https://{0}:5000/" -F $DVLSHostName)
}
else
{
    $DVLSURI = ("http://{0}:5000/" -F $DVLSHostName)
}

$DVLSAPP            = "dvls"
$DVLSPath           = "$($Env:DVLS_PATH)"
$DVLSAdminUsername  = "$($Env:DVLS_ADMIN_USERNAME)"
$DVLSAdminPassword  = "$($Env:DVLS_ADMIN_PASSWORD)"

if (-not [String]::IsNullOrWhiteSpace($($Env:DVLS_ADMIN_EMAIL)))
{
    $DVLSAdminEmail = ($($Env:DVLS_ADMIN_EMAIL)).Trim()
}
else
{
    $DVLSAdminEmail = 'admin@replaceme.com'
}

Set-Location -Path $DVLSPath | Out-Null

if ($Env:GENERATE_SELFSIGNED_CERTIFICATE -eq 'true')
{
    if ($DVLSHostName -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$" -and [bool]($DVLSHostName -as [System.Net.IPAddress]))
    {
        & openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout /tmp/cert.key -out /tmp/cert.crt -subj ("/CN={0}" -f $DVLSHostName) -addext ("subjectAltName=IP:{0}" -f $DVLSHostName) > /dev/null 2>&1
    }
    else
    {
        & openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout /tmp/cert.key -out /tmp/cert.crt -subj ("/CN={0}" -f $DVLSHostName) -addext ("subjectAltName=DNS:{0}" -f $DVLSHostName) > /dev/null 2>&1
    }
    
    & openssl pkcs12 -export -out ("{0}/cert.pfx" -F $DVLSPath) -inkey /tmp/cert.key -in /tmp/cert.crt -passout pass: > /dev/null 2>&1
}

$Params = @{
    "DatabaseHost"           = 'mssql'
    "DatabaseName"           = $DVLSAPP
    "DatabaseUserName"       = "sa"
    "DatabasePassword"       = $Env:MSSQL_SA_PASSWORD
    "ServerName"             = $DVLSAPP
    "AccessUri"              = $DVLSURI
    "HttpListenerUri"        = $DVLSURI
    "DPSPath"                = $DVLSPath
    "UseEncryptedconnection" = $true
    'TrustServerCertificate' = $true
    "DisableEncryptConfig"   = $true
    'EnableTelemetry'        = (($Env:ENABLE_TELEMETRY -eq 'true') ? $true : $false)
}

$Configuration = New-DPSInstallConfiguration @Params
New-DPSAppsettings -Configuration $Configuration
$Settings = Get-DPSAppSettings -ApplicationPath $DVLSPath

New-DPSDatabase -ConnectionString $Settings.ConnectionStrings.LocalSqlServer
Update-DPSDatabase -ConnectionString $Settings.ConnectionStrings.LocalSqlServer -InstallationPath $DVLSPath
New-DPSDataSourceSettings -ConnectionString $Settings.ConnectionStrings.LocalSqlServer

New-DPSEncryptConfiguration -ApplicationPath $DVLSPath
New-DPSDatabaseAppSettings -Configuration $Configuration

New-DPSAdministrator -ConnectionString $Settings.ConnectionStrings.LocalSqlServer -Name $DVLSAdminUsername -Password $DVLSAdminPassword -Email $DVLSAdminEmail

if ($Env:GENERATE_SELFSIGNED_CERTIFICATE -eq 'true')
{
    $JSON = Get-Content -Path (Join-Path -Path $DVLSPath -ChildPath 'appsettings.json') | ConvertFrom-Json -Depth 100

    $JSON.Kestrel.Endpoints.Http | Add-Member -MemberType NoteProperty -Name 'Certificate' -Value @{
        'Path'     = ("{0}/cert.pfx" -F $DVLSPath)
        'Password' = ''
    }

    $JSON | ConvertTo-Json -Depth 100 | Set-Content -Path (Join-Path -Path $DVLSPath -ChildPath 'appsettings.json')

    Set-DPSAccessUri -ConnectionString $Settings.ConnectionStrings.LocalSqlServer -ApplicationPath $DVLSPath -AdditionalAccessURIs @("https://localhost:5000/","https://127.0.0.1:5000/")
}
else
{
    Set-DPSAccessUri -ConnectionString $Settings.ConnectionStrings.LocalSqlServer -ApplicationPath $DVLSPath -AdditionalAccessURIs @("http://localhost:5000/","http://127.0.0.1:5000/")
}

EOC
EOF

# Configure s6-overlay prep and longrun tasks
# Useful commands: Check status of longrunning DVLS task, set DVLS up or (-d) for down, re-run the onetime init DVLS task
# - s6-svstat /var/run/s6-rc/servicedirs/svc-dvls
# - s6-svc -u /var/run/s6-rc/servicedirs/svc-dvls
# - s6-rc -a change init-dvls
RUN <<EOF
    mkdir -p /etc/s6-overlay/s6-rc.d/log-dvls
    mkdir -p /etc/s6-overlay/s6-rc.d/log-dvls/dependencies.d

    mkdir -p /etc/s6-overlay/s6-rc.d/init-dvls
    mkdir -p /etc/s6-overlay/s6-rc.d/init-dvls/dependencies.d

    mkdir -p /etc/s6-overlay/s6-rc.d/svc-dvls
    mkdir -p /etc/s6-overlay/s6-rc.d/svc-dvls/dependencies.d
    
    mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d

    echo "oneshot" >| /etc/s6-overlay/s6-rc.d/log-dvls/type
    
    touch /etc/s6-overlay/s6-rc.d/log-dvls/run
    echo "#!/command/execlineb -P" >| /etc/s6-overlay/s6-rc.d/log-dvls/run
    echo "if { mkdir -p /var/log/dvls }" >> /etc/s6-overlay/s6-rc.d/log-dvls/run
    echo "if { chown nobody:nogroup /var/log/dvls }" >> /etc/s6-overlay/s6-rc.d/log-dvls/run
    echo "chmod 02755 /var/log/dvls" >> /etc/s6-overlay/s6-rc.d/log-dvls/run
    chmod a+x /etc/s6-overlay/s6-rc.d/log-dvls/run

    touch /etc/s6-overlay/s6-rc.d/log-dvls/up
    echo "/etc/s6-overlay/s6-rc.d/log-dvls/run" >| /etc/s6-overlay/s6-rc.d/log-dvls/up

    echo "oneshot" >| /etc/s6-overlay/s6-rc.d/init-dvls/type
    echo "/usr/bin/pwsh -File /tmp/init.ps1" >| /etc/s6-overlay/s6-rc.d/init-dvls/up

    echo "longrun" >| /etc/s6-overlay/s6-rc.d/svc-dvls/type
    echo "#!/command/with-contenv bash" >| /etc/s6-overlay/s6-rc.d/svc-dvls/run
    echo "execline-cd $DVLS_PATH $DVLS_PATH/Devolutions.Server" >> /etc/s6-overlay/s6-rc.d/svc-dvls/run
    chmod a+x /etc/s6-overlay/s6-rc.d/svc-dvls/run

    touch /etc/s6-overlay/s6-rc.d/log-dvls/dependencies.d/base
    touch /etc/s6-overlay/s6-rc.d/init-dvls/dependencies.d/log-dvls
    touch /etc/s6-overlay/s6-rc.d/svc-dvls/dependencies.d/init-dvls

    touch /etc/s6-overlay/s6-rc.d/user/contents.d/log-dvls
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/init-dvls
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/svc-dvls
EOF

# Required for s6-overlay
ENTRYPOINT ["/init"]

# s6-overlay controls longrunning DVLS task
CMD ["bash"]