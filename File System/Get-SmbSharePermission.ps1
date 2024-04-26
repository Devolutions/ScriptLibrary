<#
.SYNOPSIS
Retrieves and formats the access control list (ACL) of a Windows file share.

.DESCRIPTION
This script checks if the specified file share exists. If it does, it retrieves the share's 
security descriptor and enumerates the access control entries (ACEs). For each ACE, it displays 
the principal (user or group), domain, and the assigned permission level.

.PARAMETER Name
The name of the file share to query.

.EXAMPLE
Get the ACL for the share named "Documents":
.\Get-SmbSharePermission.ps1 -Name "Documents"
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name
)

# Verify that the share exists
$existingShare = Get-SmbShare -Name $Name -ErrorAction 'SilentlyContinue'
if (-not $existingShare) {
    throw "The share [$($Name)] does not exist."
}

# Define a lookup table for translating access mask values into permission names
$accessRights = @{
    2032127 = 'Full Control' 
    1245631 = 'Change'       
    1179817 = 'Read'         
}

# Retrieve the share's security descriptor
$shareParams = @{
    ClassName = 'Win32_LogicalShareSecuritySetting'
    Filter    = "Name = '$Name'"
}
$shareSecurityDescriptor = (Get-CimInstance @shareParams).GetSecurityDescriptor()

# Access the DACL (Discretionary Access Control List)
$dacl = $shareSecurityDescriptor.Descriptor.DACL

# Process each ACE (Access Control Entry)
foreach ($ace in $dacl) {
    $trustee = $ace.Trustee

    # Construct a custom output object with Principal, Domain, and Permission 
    [pscustomobject]@{
        Principal  = $trustee.Name -or $trustee.SIDString # Use SID if the user/group name is unavailable
        Domain     = $trustee.Domain
        Permission = $accessRights[$ace.AccessMask]
    }
}