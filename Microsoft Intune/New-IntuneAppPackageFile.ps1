<#
.SYNOPSIS
    Prepares an application for deployment via Intune by packaging it using the Intune Content Preparation Tool.

.DESCRIPTION
    This script takes a specified setup folder containing the application files, a setup file, and the Intune Content
    Prep Tool to create a deployment package. The resulting package is saved to a specified output folder.

.PARAMETER SetupFolderPath
    Specifies the path to the setup folder containing the application files. This folder must exist.

.PARAMETER ContentPrepToolFilePath
    Specifies the path to the Intune Content Preparation Tool executable. This file must exist.

.PARAMETER SetupFileName
    Specifies the name of the main setup file within the setup folder. This file must exist within the setup folder.

.PARAMETER OutputFolderPath
    Specifies the output folder where the Intune package will be saved. This folder must exist.

.EXAMPLE
    PS> .\New-IntuneAppPackageFile.ps1 -SetupFolderPath "C:\Apps\MyApp" -ContentPrepToolFilePath "C:\Tools\IntuneWinAppUtil.exe"
    -SetupFileName "install.exe" -OutputFolderPath "C:\Output"

    This command runs the script with specified paths for the setup folder, Intune Content Preparation Tool, the setup file,
    and the output folder, packaging the application for Intune deployment.

.FUNCTIONALITY
    This script leverages the Intune Content Preparation Tool to package applications for deployment. It ensures that all
    prerequisites such as file and path validations are met before proceeding with the packaging process.

.INPUTS
    None. Parameters must be provided when the script is called.

.OUTPUTS
    None directly from the script. The Intune package output is written to the specified output folder.

.NOTES
    Ensure that the Intune Content Preparation Tool is downloaded and accessible. More information about this tool can be found at:
    https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management

.LINK
    https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management

#>
[CmdletBinding()]
param (
    # Path to the setup folder, must be a valid and existing path
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "Setup folder '$_' does not exist."
            }
            $true
        })]
    [string]$SetupFolderPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "The Intune Content Prep tool could not be found at '$_'."
            }
            $true
        })]
    [string]$ContentPrepToolFilePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
            if (-not (Test-Path (Join-Path $SetupFolderPath $SetupFileName))) {
                throw "Setup file '$_' is not located in the setup folder path '$SetupFolderPath'."
            }
            $true
        })]
    [string]$SetupFileName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "Output folder '$_' does not exist."
            }
            $true
        })]
    [string]$OutputFolderPath
)

#region functions

# Function to calculate the total size of the setup folder in GB
function Get-SetupFolderSize {
    param ()
    ((Get-ChildItem -Path $SetupFolderPath -Recurse -File).Size | Measure-Object -Sum).sum / 1GB
}

#endregion

#region Prerequisites

# Check if the total size of the setup folder exceeds 30 GB
if ((Get-SetupFolderSize) -ge 30GB) {
    throw "The total size of the setup folder path exceeds the 30 GB limit."
}

#endregion

# Prepare arguments for the Intune Content Prep tool
$intuneWinAppUtilArgs = '-c {0} -s {1} -o {2} -q' -f $SetupFolderPath, $SetupFileName, $OutputFolderPath

try {
    # Start the Intune Content Prep tool process
    $process = Start-Process -FilePath $ContentPrepToolFilePath -ArgumentList $intuneWinAppUtilArgs -Wait -NoNewWindow -PassThru
    # Check if the process exited with a non-zero exit code
    if ($process.ExitCode -ne 0) {
        throw "The Intune Content Prep tool failed with exit code $($process.ExitCode)."
    }
} catch {
    # Handle any errors that occur during the process execution
    throw "An error occurred while running the Intune Content Prep tool: $_"
}