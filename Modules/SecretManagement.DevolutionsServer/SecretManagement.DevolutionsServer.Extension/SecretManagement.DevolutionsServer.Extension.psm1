#Requires -Version 7.0
<#
.SYNOPSIS
Read-only Microsoft.PowerShell.SecretManagement extension vault for Devolutions Server.

.DESCRIPTION
This module is loaded by SecretManagement after a DVLS vault is registered. It
authenticates to Devolutions Server with application credentials, enumerates
Credential entries, and returns matching entries as PSCredential objects.

The provider is intentionally read-only. Set-Secret and Remove-Secret reject
write operations because DVLS remains the system of record for credential
lifecycle management.

Future mutable operations: if this module later implements Set-Secret or
Remove-Secret against DVLS write APIs, treat that as a design change. Remove
read-only suppressions, add SupportsShouldProcess with WhatIf/Confirm tests,
document required DVLS write permissions, and add coverage for create, update,
delete, rollback/failure, and audit behavior before release.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop

$script:DefaultRequestTimeoutSeconds = 30
$script:DefaultPageSize = 100

#region Configuration and validation

<#
.SYNOPSIS
Parses optional SecretManagement boolean vault parameters safely.

.DESCRIPTION
PowerShell treats every non-empty string as true when cast to Boolean, including
the string 'false'. This parser accepts Boolean values and the strings 'true' or
'false', defaults missing values to false, and fails closed for anything else.

.PARAMETER Value
The untyped value received through SecretManagement VaultParameters.
#>
Function ConvertTo-DVLSBoolean {
    [CmdletBinding()]
    Param(
          [Object]$Value
    )
    Process {
        If ($Null -EQ $Value) {
            Return $False
        }

        If ($Value -IS [Bool]) {
            Return $Value
        }

        $parsed = $False
        If ([Bool]::TryParse([String]$Value, [ref]$parsed)) {
            Return $parsed
        }

        Throw "VaultParameters key 'AllowVaultEnumeration' must be true or false."
    }
}

<#
.SYNOPSIS
Validates and normalizes the DVLS server URL.

.PARAMETER AdditionalParameters
The SecretManagement VaultParameters hashtable supplied during vault
registration.
#>
Function Resolve-DVLSServerUrl {
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [Hashtable]$AdditionalParameters
    )
    Process {
        $rawServerUrl = $AdditionalParameters['ServerUrl']
        If (-NOT $rawServerUrl -OR [String]::IsNullOrWhiteSpace([String]$rawServerUrl)) {
            Throw "VaultParameters is missing required key 'ServerUrl'."
        }

        $serverUri = $Null
        If (-NOT [System.Uri]::TryCreate(([String]$rawServerUrl).Trim(), [System.UriKind]::Absolute, [ref]$serverUri)) {
            Throw 'ServerUrl must be a valid absolute URI.'
        }

        If ($serverUri.Scheme -NE 'https') {
            Throw 'ServerUrl must use HTTPS.'
        }

        If ($serverUri.Query -OR $serverUri.Fragment) {
            Throw 'ServerUrl must not include a query string or fragment.'
        }

        Return $serverUri.AbsoluteUri.TrimEnd('/')
    }
}

<#
.SYNOPSIS
Configuration parser for SecretManagement VaultParameters.

.DESCRIPTION
Validates required DVLS connection settings and normalizes optional runtime
controls. SecretManagement passes VaultParameters as an untyped hashtable, so
this function is the boundary where deployment configuration becomes a typed
internal object.

.PARAMETER AdditionalParameters
The SecretManagement VaultParameters hashtable. Required keys are ServerUrl,
AppKey, and AppSecret. VaultId is recommended and required unless
AllowVaultEnumeration is explicitly true.
#>
Function Get-DVLSVaultConfiguration {
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [Hashtable]$AdditionalParameters
    )
    Process {
        ForEach ($key in 'ServerUrl', 'AppKey', 'AppSecret') {
            If (-NOT $AdditionalParameters[$key] -OR [String]::IsNullOrWhiteSpace([String]$AdditionalParameters[$key])) {
                Throw "VaultParameters is missing required key '$key'."
            }
        }

        $allowVaultEnumeration = ConvertTo-DVLSBoolean -Value $AdditionalParameters['AllowVaultEnumeration']
        $vaultId = [String]($AdditionalParameters['VaultId'] ?? '')
        $requestTimeoutSeconds = $script:DefaultRequestTimeoutSeconds
        $pageSize = $script:DefaultPageSize

        If ([String]::IsNullOrWhiteSpace($vaultId)) {
            If (-NOT $allowVaultEnumeration) {
                Throw "VaultParameters is missing required key 'VaultId'. Set AllowVaultEnumeration=true only if cross-vault enumeration is explicitly intended."
            }

            $vaultId = ''
        }

        If ($Null -NE $AdditionalParameters['RequestTimeoutSeconds'] -AND -NOT [String]::IsNullOrWhiteSpace([String]$AdditionalParameters['RequestTimeoutSeconds'])) {
            $parsedRequestTimeoutSeconds = 0
            If (-NOT [Int]::TryParse([String]$AdditionalParameters['RequestTimeoutSeconds'], [ref]$parsedRequestTimeoutSeconds)) {
                Throw "VaultParameters key 'RequestTimeoutSeconds' must be a positive integer."
            }

            If ($parsedRequestTimeoutSeconds -LT 1 -OR $parsedRequestTimeoutSeconds -GT 300) {
                Throw "VaultParameters key 'RequestTimeoutSeconds' must be between 1 and 300."
            }

            $requestTimeoutSeconds = $parsedRequestTimeoutSeconds
        }

        If ($Null -NE $AdditionalParameters['PageSize'] -AND -NOT [String]::IsNullOrWhiteSpace([String]$AdditionalParameters['PageSize'])) {
            $parsedPageSize = 0
            If (-NOT [Int]::TryParse([String]$AdditionalParameters['PageSize'], [ref]$parsedPageSize)) {
                Throw "VaultParameters key 'PageSize' must be a positive integer."
            }

            If ($parsedPageSize -LT 1 -OR $parsedPageSize -GT 1000) {
                Throw "VaultParameters key 'PageSize' must be between 1 and 1000."
            }

            $pageSize = $parsedPageSize
        }

        Return [PSCustomObject]@{
            ServerUrl             = Resolve-DVLSServerUrl -AdditionalParameters $AdditionalParameters
            AppKey                = [String]$AdditionalParameters['AppKey']
            AppSecret             = [String]$AdditionalParameters['AppSecret']
            VaultId               = $vaultId
            AllowVaultEnumeration = $allowVaultEnumeration
            RequestTimeoutSeconds = $requestTimeoutSeconds
            PageSize              = $pageSize
        }
    }
}

Function Get-DVLSReadOnlyErrorMessage {
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [String]$Operation
    )
    Process {
        Return "SecretManagement.DevolutionsServer is read-only. '$Operation' is not supported; manage DVLS Credential entries in Devolutions Server."
    }
}

Function Get-DVLSSafeErrorMessage {
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [String]$Action,
          [System.Exception]$Exception
    )
    Process {
        If ($Null -EQ $Exception -OR [String]::IsNullOrWhiteSpace($Exception.Message)) {
            Return $Action
        }

        Return '{0}: {1}' -f $Action, $Exception.Message
    }
}

#endregion

#region URI and HTTP helpers

Function Join-DVLSApiUri {
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [String]$ServerUrl,
          [Parameter(Mandatory)]
          [String[]]$PathSegments,
          [Hashtable]$Query
    )
    Process {
        $encodedPath = ($PathSegments | ForEach-Object { [System.Uri]::EscapeDataString([String]$_) }) -join '/'
        $uriBuilder = [System.UriBuilder]::new("$ServerUrl/$encodedPath")

        If ($Query) {
            $uriBuilder.Query = (($Query.GetEnumerator() | ForEach-Object {
                '{0}={1}' -f [System.Uri]::EscapeDataString([String]$_.Key), [System.Uri]::EscapeDataString([String]$_.Value)
            }) -join '&')
        }

        Return $uriBuilder.Uri.AbsoluteUri
    }
}

Function Get-DVLSRequestOption {
    [CmdletBinding()]
    Param(
          [Object]$Configuration
    )
    Process {
        $timeoutSeconds = $script:DefaultRequestTimeoutSeconds
        If ($Null -NE $Configuration) {
            $timeoutProperty = $Configuration.PSObject.Properties | Where-Object { $_.Name -EQ 'RequestTimeoutSeconds' } | Select-Object -First 1
            If ($Null -NE $timeoutProperty -AND $Null -NE $timeoutProperty.Value) {
                $timeoutSeconds = [Int]$timeoutProperty.Value
            }
        }

        Return @{
            ContentType        = 'application/json'
            SkipHttpErrorCheck = $True
            TimeoutSec         = $timeoutSeconds
            HttpVersion        = '2.0'
        }
    }
}

Function Invoke-DVLSRestMethod {
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [ValidateSet('Get', 'Post')]
          [String]$Method,
          [Parameter(Mandatory)]
          [String]$Uri,
          [String]$Token,
          [Object]$Body,
          [Object]$Configuration
    )
    Process {
        $statusCode = 0
        $request = @{
            Method             = $Method
            Uri                = $Uri
            StatusCodeVariable = 'statusCode'
        }

        If ($Token) {
            $request['Headers'] = @{ tokenId = $Token }
        }

        If ($Null -NE $Body) {
            $request['Body'] = ($Body -IS [String]) ? $Body : ($Body | ConvertTo-Json -Compress -Depth 10)
        }

        $requestOptions = Get-DVLSRequestOption -Configuration $Configuration
        $response = Invoke-RestMethod @request @requestOptions

        # Pester mocks do not populate -StatusCodeVariable, so tests may provide StatusCode explicitly.
        $statusCodeProperty = $Null
        If ($statusCode -EQ 0 -AND $Null -NE $response) {
            $statusCodeProperty = $response.PSObject.Properties | Where-Object { $_.Name -EQ 'StatusCode' } | Select-Object -First 1
        }

        If ($Null -NE $statusCodeProperty) {
            $statusCode = [Int]$statusCodeProperty.Value
        }

        If ($statusCode -GE 400) {
            Throw "DVLS API error HTTP $statusCode during $Method request."
        }

        Return $response
    }
}

#endregion

#region DVLS session

Function Connect-DVLSSession {
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [Object]$Configuration
    )
    Process {
        $response = Invoke-DVLSRestMethod `
            -Method Post `
            -Uri (Join-DVLSApiUri -ServerUrl $Configuration.ServerUrl -PathSegments @('api', 'v1', 'login')) `
            -Body @{ appKey = $Configuration.AppKey; appSecret = $Configuration.AppSecret } `
            -Configuration $Configuration

        $tokenId = Get-DVLSObjectProperty -InputObject $response -Name @('tokenId', 'TokenId')
        If (-NOT $tokenId) {
            Throw 'Devolutions Server authentication failed.'
        }

        Return [PSCustomObject]@{
            TokenId       = [String]$tokenId
            ServerUrl     = $Configuration.ServerUrl
            Configuration = $Configuration
        }
    }
}

Function Close-DVLSSession {
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [Object]$Session
    )
    Process {
        Try {
            [Void](Invoke-DVLSRestMethod `
                -Method Post `
                -Uri (Join-DVLSApiUri -ServerUrl $Session.ServerUrl -PathSegments @('api', 'v1', 'logout')) `
                -Token $Session.TokenId `
                -Configuration $Session.Configuration)
        } Catch {
            Write-Warning (Get-DVLSSafeErrorMessage -Action 'Devolutions Server logout warning' -Exception $_.Exception)
        }
    }
}

#endregion

#region Vault and entry lookup

Function Get-DVLSObjectProperty {
    [CmdletBinding()]
    Param(
          [Object]$InputObject,
          [Parameter(Mandatory)]
          [String[]]$Name
    )
    Process {
        If ($Null -EQ $InputObject) {
            Return $Null
        }

        ForEach ($candidateName in $Name) {
            $property = $InputObject.PSObject.Properties | Where-Object { $_.Name -EQ $candidateName } | Select-Object -First 1
            If ($Null -NE $property) {
                Return $property.Value
            }
        }

        Return $Null
    }
}

Function Get-DVLSResponseData {
    [CmdletBinding()]
    Param(
          [Object]$Response
    )
    Process {
        $data = Get-DVLSObjectProperty -InputObject $Response -Name @('data', 'Data')
        If ($Null -NE $data) {
            Return $data
        }

        Return $Response
    }
}

Function Get-DVLSVaultId {
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [Object]$Session
    )
    Process {
        If ($Session.Configuration.VaultId) {
            Return @($Session.Configuration.VaultId)
        }

        $response = Invoke-DVLSRestMethod `
            -Method Get `
            -Uri (Join-DVLSApiUri -ServerUrl $Session.ServerUrl -PathSegments @('api', 'v1', 'vault')) `
            -Token $Session.TokenId `
            -Configuration $Session.Configuration

        $vaults = $response -IS [Array] ? $response : @(Get-DVLSResponseData -Response $response)
        Return @($vaults | ForEach-Object { Get-DVLSObjectProperty -InputObject $_ -Name @('id', 'Id') } | Where-Object { $_ })
    }
}

Function Get-DVLSCredentialEntry {
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [Object]$Session,
          [Parameter(Mandatory)]
          [String]$VaultId
    )
    Process {
        $entries = [System.Collections.Generic.List[Object]]::new()
        $pageNumber = 1

        Do {
            $response = Invoke-DVLSRestMethod `
                -Method Get `
                -Uri (Join-DVLSApiUri -ServerUrl $Session.ServerUrl -PathSegments @('api', 'v1', 'vault', $VaultId, 'entry') -Query @{
                    pageNumber = $pageNumber
                    pageSize   = $Session.Configuration.PageSize
                }) `
                -Token $Session.TokenId `
                -Configuration $Session.Configuration

            $data = @(Get-DVLSResponseData -Response $response)
            ForEach ($entry in $data) {
                If ((Get-DVLSObjectProperty -InputObject $entry -Name @('type', 'Type')) -EQ 'Credential') {
                    $entries.Add($entry)
                }
            }

            $currentPage = Get-DVLSObjectProperty -InputObject $response -Name @('currentPage', 'CurrentPage')
            $totalPage = Get-DVLSObjectProperty -InputObject $response -Name @('totalPage', 'TotalPage')
            $currentPage = $currentPage ?? 1
            $totalPage = $totalPage ?? 1
            $pageNumber++
        } While ($currentPage -LT $totalPage)

        Return $entries.ToArray()
    }
}

Function Get-DVLSCredentialEntryDetail {
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [Object]$Session,
          [Parameter(Mandatory)]
          [String]$VaultId,
          [Parameter(Mandatory)]
          [String]$EntryId
    )
    Process {
        $response = Invoke-DVLSRestMethod `
            -Method Get `
            -Uri (Join-DVLSApiUri -ServerUrl $Session.ServerUrl -PathSegments @('api', 'v1', 'vault', $VaultId, 'entry', $EntryId) -Query @{
                includePasswords     = 'true'
                includeSensitiveData = 'true'
            }) `
            -Token $Session.TokenId `
            -Configuration $Session.Configuration

        Return (Get-DVLSResponseData -Response $response)
    }
}

Function Find-DVLSCredentialEntry {
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [Object]$Session,
          [Parameter(Mandatory)]
          [String]$Name
    )
    Process {
        $vaultIds = @(Get-DVLSVaultId -Session $Session)

        ForEach ($vaultId in $vaultIds) {
            $match = Get-DVLSCredentialEntry -Session $Session -VaultId $vaultId |
                Where-Object { (Get-DVLSObjectProperty -InputObject $_ -Name @('name', 'Name')) -EQ $Name } |
                Select-Object -First 1

            If ($match) {
                Return [PSCustomObject]@{
                    Entry   = $match
                    VaultId = $vaultId
                    Detail  = $Null
                }
            }
        }

        $parsedGuid = [System.Guid]::Empty
        If (-NOT [System.Guid]::TryParse($Name, [ref]$parsedGuid)) {
            Return $Null
        }

        ForEach ($vaultId in $vaultIds) {
            Try {
                $detail = Get-DVLSCredentialEntryDetail -Session $Session -VaultId $vaultId -EntryId $Name
                $entryType = Get-DVLSObjectProperty -InputObject $detail -Name @('type', 'Type')
                If ($entryType -AND $entryType -NE 'Credential') {
                    Continue
                }

                Return [PSCustomObject]@{
                    Entry   = $detail
                    VaultId = $vaultId
                    Detail  = $detail
                }
            } Catch {
                Continue
            }
        }

        Return $Null
    }
}

#endregion

#region SecretManagement output conversion

Function ConvertTo-DVLSPsCredential {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        '',
        Justification = 'DVLS returns the credential value as plaintext and SecretManagement requires a PSCredential. The value is converted immediately and is not logged or persisted.'
    )]
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [Object]$EntryData
    )
    Process {
        $username = [String](Get-DVLSObjectProperty -InputObject $EntryData -Name @('username', 'Username'))
        $password = [String](Get-DVLSObjectProperty -InputObject $EntryData -Name @('password', 'Password'))
        $domain = [String](Get-DVLSObjectProperty -InputObject $EntryData -Name @('domain', 'Domain'))

        If ($domain -AND $username -NOTLIKE '*@*' -AND $username -NOTLIKE '*\*') {
            $username = "$username@$domain"
        }

        Return [System.Management.Automation.PSCredential]::new(
            $username,
            (ConvertTo-SecureString -String $password -AsPlainText -Force)
        )
    }
}

Function ConvertTo-DVLSSecretInformation {
    [CmdletBinding()]
    Param(
          [Parameter(Mandatory)]
          [String]$Name,
          [Parameter(Mandatory)]
          [String]$VaultName
    )
    Process {
        Return [Microsoft.PowerShell.SecretManagement.SecretInformation]::new(
            $Name,
            [Microsoft.PowerShell.SecretManagement.SecretType]::PSCredential,
            $VaultName
        )
    }
}

#endregion

#region SecretManagement required functions

<#
.SYNOPSIS
Retrieves a DVLS Credential entry as a PSCredential.

.DESCRIPTION
Called by Microsoft.PowerShell.SecretManagement. This provider is read-only and only returns DVLS entries of type Credential.

.PARAMETER Name
SecretManagement name to resolve. This can be the DVLS Credential entry name or,
as a fallback, the DVLS entry GUID.

.PARAMETER VaultName
The SecretManagement vault name supplied by the SecretManagement engine.

.PARAMETER AdditionalParameters
VaultParameters supplied when the vault was registered. The provider expects
ServerUrl, AppKey, AppSecret, and preferably VaultId.
#>
Function Get-Secret {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'VaultName',
        Justification = 'VaultName is required by the SecretManagement extension contract; DVLS lookup uses the registered VaultParameters instead.'
    )]
    [CmdletBinding()]
    Param(
          [String]$Name,
          [String]$VaultName,
          [Hashtable]$AdditionalParameters
    )
    Process {
        $configuration = Get-DVLSVaultConfiguration -AdditionalParameters $AdditionalParameters
        $session = Connect-DVLSSession -Configuration $configuration

        Try {
            $match = Find-DVLSCredentialEntry -Session $session -Name $Name
            If (-NOT $match) {
                Return $Null
            }

            $entryDetail = $match.Detail
            If (-NOT $entryDetail) {
                $entryId = Get-DVLSObjectProperty -InputObject $match.Entry -Name @('id', 'Id')
                If (-NOT $entryId) {
                    Return $Null
                }

                $entryDetail = Get-DVLSCredentialEntryDetail -Session $session -VaultId $match.VaultId -EntryId $entryId
            }

            Return (ConvertTo-DVLSPsCredential -EntryData $entryDetail)
        } Finally {
            Close-DVLSSession -Session $session
        }
    }
}

<#
.SYNOPSIS
Lists DVLS Credential entries available through the registered vault.

.DESCRIPTION
Called by Microsoft.PowerShell.SecretManagement. Results are metadata only; secret values are never returned by this function.

.PARAMETER Filter
SecretManagement wildcard filter applied to DVLS Credential entry names.

.PARAMETER VaultName
The SecretManagement vault name supplied by the SecretManagement engine.

.PARAMETER AdditionalParameters
VaultParameters supplied when the vault was registered. The provider expects
ServerUrl, AppKey, AppSecret, and preferably VaultId.
#>
Function Get-SecretInfo {
    [CmdletBinding()]
    Param(
          [String]$Filter,
          [String]$VaultName,
          [Hashtable]$AdditionalParameters
    )
    Process {
        $configuration = Get-DVLSVaultConfiguration -AdditionalParameters $AdditionalParameters
        $session = Connect-DVLSSession -Configuration $configuration
        $effectiveFilter = $Filter ? $Filter : '*'

        Try {
            $vaultIds = @(Get-DVLSVaultId -Session $session)
            ForEach ($vaultId in $vaultIds) {
                Get-DVLSCredentialEntry -Session $session -VaultId $vaultId |
                    ForEach-Object {
                        $entryName = [String](Get-DVLSObjectProperty -InputObject $_ -Name @('name', 'Name'))
                        If ([String]::IsNullOrWhiteSpace($entryName) -OR $entryName -NotLike $effectiveFilter) {
                            Return
                        }

                        ConvertTo-DVLSSecretInformation -Name $entryName -VaultName $VaultName
                    }
            }
        } Finally {
            Close-DVLSSession -Session $session
        }
    }
}

<#
.SYNOPSIS
Rejects write attempts because this DVLS provider is read-only.

.DESCRIPTION
DVLS remains the system of record for credential lifecycle management. This
function exists only because SecretManagement extension vaults must expose it.

.PARAMETER Name
Ignored. Included for SecretManagement extension compatibility.

.PARAMETER Secret
Ignored. Included for SecretManagement extension compatibility.

.PARAMETER VaultName
Ignored. Included for SecretManagement extension compatibility.

.PARAMETER Metadata
Ignored. Included for SecretManagement extension compatibility.

.PARAMETER AdditionalParameters
Ignored. Included for SecretManagement extension compatibility.
#>
Function Set-Secret {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'SecretManagement requires Set-Secret, but this read-only provider always throws and performs no state change.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        '',
        Justification = 'These parameters are required by the SecretManagement extension contract and remain unused while the provider is read-only.'
    )]
    [CmdletBinding()]
    Param(
          [String]$Name,
          [Object]$Secret,
          [String]$VaultName,
          [Hashtable]$Metadata,
          [Hashtable]$AdditionalParameters
    )
    Process {
        Throw (Get-DVLSReadOnlyErrorMessage -Operation 'Set-Secret')
    }
}

<#
.SYNOPSIS
Rejects delete attempts because this DVLS provider is read-only.

.DESCRIPTION
DVLS remains the system of record for credential lifecycle management. This
function exists only because SecretManagement extension vaults must expose it.

Future mutable operations must remove the read-only analyzer suppression, add
SupportsShouldProcess, and implement explicit DVLS write/delete permission and
test coverage before this function changes state.

.PARAMETER Name
Ignored. Included for SecretManagement extension compatibility.

.PARAMETER VaultName
Ignored. Included for SecretManagement extension compatibility.

.PARAMETER AdditionalParameters
Ignored. Included for SecretManagement extension compatibility.
#>
Function Remove-Secret {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'SecretManagement requires Remove-Secret, but this read-only provider always throws and performs no state change.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        '',
        Justification = 'These parameters are required by the SecretManagement extension contract and remain unused while the provider is read-only.'
    )]
    [CmdletBinding()]
    Param(
          [String]$Name,
          [String]$VaultName,
          [Hashtable]$AdditionalParameters
    )
    Process {
        Throw (Get-DVLSReadOnlyErrorMessage -Operation 'Remove-Secret')
    }
}

<#
.SYNOPSIS
Validates DVLS connectivity for the registered SecretManagement vault.

.DESCRIPTION
Returns exactly one Boolean to the pipeline. Diagnostic details are written only to the error stream.

.PARAMETER VaultName
The SecretManagement vault name supplied by the SecretManagement engine.

.PARAMETER AdditionalParameters
VaultParameters supplied when the vault was registered. The provider expects
ServerUrl, AppKey, AppSecret, and preferably VaultId.
#>
Function Test-SecretVault {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'VaultName',
        Justification = 'VaultName is required by the SecretManagement extension contract; validation uses the registered VaultParameters instead.'
    )]
    [CmdletBinding()]
    Param(
          [String]$VaultName,
          [Hashtable]$AdditionalParameters
    )
    Process {
        $session = $Null

        Try {
            $configuration = Get-DVLSVaultConfiguration -AdditionalParameters $AdditionalParameters
            $session = Connect-DVLSSession -Configuration $configuration
            $vaultIds = @(Get-DVLSVaultId -Session $session)

            If ($vaultIds.Count -EQ 0) {
                Throw 'No accessible DVLS vaults were found.'
            }

            [Void](Get-DVLSCredentialEntry -Session $session -VaultId $vaultIds[0])
            Return $True
        } Catch {
            Write-Error (Get-DVLSSafeErrorMessage -Action 'Devolutions Server vault test failed' -Exception $_.Exception)
            Return $False
        } Finally {
            If ($session) {
                Close-DVLSSession -Session $session
            }
        }
    }
}

#endregion
