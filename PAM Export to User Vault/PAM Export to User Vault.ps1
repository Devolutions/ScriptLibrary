Param (
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[String]$PAMVaultName
)

$ds = (Get-RDMDataSource | Where-Object {$_.Type -eq 'RDMS'})[0]
$url = Get-RDMDatasourceProperty -DataSource $ds -Property Server
$Session = New-DSSession -BaseUri $url -UseOAuth
$PersonalPamVault = (Get-DSPamVault | Where-Object { $_.Name.ToLower() -match $PAMVaultName.ToLower() })[0]
If ($PersonalPamVault){
	$PersonalPamAccounts = Get-DSPamAccounts -AsBasicInformation | Where-Object {$_.TeamFolderID -eq $PersonalPamVault.ID}
	$PrivateRDMSessions = Get-RDMPrivateSession -IncludeSubFolders | Where-Object { ($_.ConnectionType -eq 'Credential') -and ($_.Credentials.CredentialType -eq 'DpsPam') }
	foreach ($PamAccount in $PersonalPamAccounts){
		#Create User vault entry it not exist
        If (-not($PrivateRDMSessions | Where-Object { $_.Name -eq $PamAccount.Label })){
			Write-Host $PamAccount.Label "is being created in RDM Private User vault"
			$session = New-RDMSession -Name $PamAccount.Label -Type Credential
			$Session.Credentials.CredentialType = 'DpsPam'
			$Session.Credentials.DPSServer = $DevolutionsURL
			$Session.Credentials.DPSPamUseMyAccountSettings = $true
			$Session.Credentials.DpsPamCredentialID = $PamAccount.ID
            $session.Credentials.DpsPamCredentialName = $PamAccount.Label
			Set-RDMPrivateSession $session -refresh -Verbose
		}
		Else{
			Write-Host $PamAccount.Label "allready exists in RDM Private User vault"
            $session = $PrivateRDMSessions | Where-Object { $_.Name -eq $PamAccount.Label }
            #Validate existing entry and update if required
			If (($session.Credentials.DpsPamCredentialID -ne $PamAccount.ID) `
                -or ($session.Credentials.DpsPamCredentialName -ne $PamAccount.Label)){
                    Write-Host "Updating entry" $PamAccount.Label
                    $Session.Credentials.DpsPamCredentialID = $PamAccount.ID
                    $session.Credentials.DpsPamCredentialName = $PamAccount.Label
                    Set-RDMPrivateSession $session -refresh -Verbose
            }
		}
	}
}

