<#
.SYNOPSIS
Compares two folders and identifies files that are missing or have mismatched hashes.

.DESCRIPTION
This script analyzes two specified folders and provides a detailed report on differences. It identifies:

* Files present in the Reference Folder but absent in the Difference Folder.
* Files present in the Difference Folder but absent in the Reference Folder.
* Files with the same name in both folders but different content (hash mismatch).

The script allows for an optional ExcludeFilePath parameter to disregard a specific file during comparison.

.PARAMETER ReferenceFolder
The path to the reference folder used as the baseline for comparison. This parameter is mandatory.

.PARAMETER DifferenceFolder
The path to the folder that will be compared against the reference folder. This parameter is mandatory.

.PARAMETER ExcludeFilePath
An optional path (relative to the root of the folders) to a file that should be excluded from the comparison.  The path must start with a backslash (\).

.EXAMPLE
Compare folders C:\Source and C:\Target, excluding the file "temp.log" 

.\Compare-Folder.ps1 -ReferenceFolder "C:\Source" -DifferenceFolder "C:\Target" -ExcludeFilePath "\temp.log" 

.EXAMPLE
Compare folders C:\Documents and D:\Backup  

.\Compare-Folder.ps1 -ReferenceFolder "C:\Documents" -DifferenceFolder "D:\Backup"

.NOTES
 - The script uses the Get-FileHash cmdlet to calculate file hashes.
 - Ensure you have the necessary permissions to access both the reference and difference folders.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string]$ReferenceFolder,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string]$DifferenceFolder,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^\\')]
    [string]$ExcludeFilePath
)

function Get-FileHashesInFolder {
    param (
        [string]$Folder
    )
    $files = Get-ChildItem -Path $Folder -Recurse -File
    foreach ($s in $files) {
        $selectObjects = @('Hash', @{ n = 'Path'; e = { $_.Path.SubString($Folder.Length) } })
        Get-FileHash $s.Fullname | Select-Object $selectObjects -ExcludeProperty Path
    }
}
    
$refHashes = Get-FileHashesInFolder -Folder $ReferenceFolder
$destHashes = Get-FileHashesInFolder -Folder $DifferenceFolder
if ($PSBoundParameters.ContainsKey('ExcludeFilePath')) {
    $refHashes = $refHashes.Where({ $_.Path -ne $ExcludeFilePath })
    $destHashes = $destHashes.Where({ $_.Path -ne $ExcludeFilePath })
}

$refHashes.Where({ $_.Path -notin $destHashes.Path }).ForEach({
        [pscustomobject]@{
            'Path'   = $_.Path
            'Reason' = 'NotInDifferenceFolder'
        }
    })
$destHashes.Where({ $_.Path -notin $refHashes.Path }).ForEach({
        [pscustomobject]@{
            'Path'   = $_.Path
            'Reason' = 'NotInReferenceFolder'
        }
    })
$refHashes.Where({ $_.Hash -notin $destHashes.Hash -and $_.Path -in $destHashes.Path }).ForEach({
        [pscustomobject]@{
            'Path'   = $_.Path
            'Reason' = 'HashDifferent'
        }
    })
