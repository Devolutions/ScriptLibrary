<#
.SYNOPSIS
Uploads a file to an FTP server.

.DESCRIPTION
This cmdlet uploads a specified file to a given FTP server.  It requires FTP  server address, the local file path, and user credentials for authentication. 

.PARAMETER Uri
The FTP server address (e.g., ftp://myftpserver.com) to upload the file to.

.PARAMETER FilePath
The full path to the local file to be uploaded.

.PARAMETER Credential
A PSCredential object containing the username and password for FTP authentication. 
You can create this using the Get-Credential cmdlet.

.EXAMPLE
Upload a file named report.txt to an FTP server, using stored credentials:

$myCredentials = Get-Credential 
.\Send-FtpFile.ps1 -Uri "ftp://myftpserver.com/uploads/" -FilePath "C:\reports\report.txt" -Credential $myCredentials

.NOTES
- This cmdlet uses passive FTP mode, which is often required for compatibility with firewalls.
- The file is uploaded in binary mode to prevent any unwanted text conversions.
#>

[OutputType('void')]
[CmdletBinding()] 
param
(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Uri,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$FilePath,
        
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [pscredential]$Credential
)

try {
    $request = [System.Net.FtpWebRequest]::Create($Uri)  #  Initiate communication with the FTP server 

    $request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile  # Specify that we're uploading a file
    $request.Credentials = New-Object System.Net.NetworkCredential($Credential.UserName, $Credential.GetNetworkCredential().Password) # Provide authentication for access
    $request.UseBinary = $true  # Ensures accurate file transfer without text conversion 
    $request.UsePassive = $true # Improves compatibility through firewalls

    $fileContent = Get-Content -Encoding Byte -Path $FilePath  # Fetch file data in a suitable format for transfer

    $request.ContentLength = $fileContent.Length  # Communicate the expected file size to the server

    $run = $request.GetRequestStream()  # Open a channel to send the file content 
    $run.Write($fileContent, 0, $fileContent.Length)  # Transmit the file data
} catch {
    throw $_  # Propagate critical errors for proper handling
} finally {
    $run.Close()  # Properly terminate the data channel 
    $run.Dispose()  # Release resources for efficiency
}