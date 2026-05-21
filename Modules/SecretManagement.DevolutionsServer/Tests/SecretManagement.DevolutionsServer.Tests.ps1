Set-StrictMode -Version Latest

Describe 'module manifests' {
    BeforeAll {
        $script:ParentManifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'SecretManagement.DevolutionsServer.psd1'
        $script:ExtensionManifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'SecretManagement.DevolutionsServer.Extension/SecretManagement.DevolutionsServer.Extension.psd1'
    }

    It 'targets PowerShell 7.0 in the parent manifest' {
        $manifest = Test-ModuleManifest $script:ParentManifestPath

        $manifest.PowerShellVersion.ToString() | Should -Be '7.0'
    }

    It 'targets PowerShell 7.0 in the extension manifest' {
        $manifest = Test-ModuleManifest $script:ExtensionManifestPath

        $manifest.PowerShellVersion.ToString() | Should -Be '7.0'
    }
}

Describe 'read-only operations' {
    BeforeAll {
        $script:ExtensionManifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'SecretManagement.DevolutionsServer.Extension/SecretManagement.DevolutionsServer.Extension.psd1'
        Import-Module $script:ExtensionManifestPath -Force
    }

    It 'rejects Set-Secret with a read-only error' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            { Set-Secret -Name 'Example' -Secret 'value' -VaultName 'DVLS' -AdditionalParameters @{} } |
                Should -Throw '*read-only*'
        }
    }

    It 'rejects Remove-Secret with a read-only error' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            { Remove-Secret -Name 'Example' -VaultName 'DVLS' -AdditionalParameters @{} } |
                Should -Throw '*read-only*'
        }
    }
}

Describe 'configuration and request helpers' {
    BeforeAll {
        $script:ExtensionManifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'SecretManagement.DevolutionsServer.Extension/SecretManagement.DevolutionsServer.Extension.psd1'
        Import-Module $script:ExtensionManifestPath -Force
    }

    It 'requires ServerUrl, AppKey, and AppSecret' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            { Get-DVLSVaultConfiguration -AdditionalParameters @{ ServerUrl = 'https://dvls.example.test'; AppSecret = 'secret'; VaultId = 'vault-1' } } |
                Should -Throw "*AppKey*"
        }
    }

    It 'requires HTTPS server URLs' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            { Get-DVLSVaultConfiguration -AdditionalParameters @{ ServerUrl = 'http://dvls.example.test'; AppKey = 'key'; AppSecret = 'secret'; VaultId = 'vault-1' } } |
                Should -Throw '*HTTPS*'
        }
    }

    It 'rejects server URLs with query strings or fragments' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            { Get-DVLSVaultConfiguration -AdditionalParameters @{ ServerUrl = 'https://dvls.example.test?tenant=prod'; AppKey = 'key'; AppSecret = 'secret'; VaultId = 'vault-1' } } |
                Should -Throw '*query string or fragment*'
        }
    }

    It 'requires VaultId unless vault enumeration is explicitly enabled' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            { Get-DVLSVaultConfiguration -AdditionalParameters @{ ServerUrl = 'https://dvls.example.test'; AppKey = 'key'; AppSecret = 'secret' } } |
                Should -Throw '*VaultId*'
        }
    }

    It 'rejects invalid boolean options without echoing caller-supplied values' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            $suppliedValue = 'secret-looking-value'
            $exception = $Null

            Try {
                Get-DVLSVaultConfiguration -AdditionalParameters @{
                    ServerUrl             = 'https://dvls.example.test'
                    AppKey                = 'key'
                    AppSecret             = 'secret'
                    AllowVaultEnumeration = $suppliedValue
                }
            } Catch {
                $exception = $_.Exception
            }

            $exception | Should -Not -BeNullOrEmpty
            $exception.Message | Should -Match 'AllowVaultEnumeration'
            $exception.Message | Should -Not -Match $suppliedValue
        }
    }

    It 'normalizes optional settings with production defaults' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            $configuration = Get-DVLSVaultConfiguration -AdditionalParameters @{
                ServerUrl             = 'https://dvls.example.test/'
                AppKey                = 'key'
                AppSecret             = 'secret'
                AllowVaultEnumeration = 'true'
            }

            $configuration.ServerUrl | Should -Be 'https://dvls.example.test'
            $configuration.AllowVaultEnumeration | Should -BeTrue
            $configuration.RequestTimeoutSeconds | Should -Be 30
            $configuration.PageSize | Should -Be 100
        }
    }

    It 'validates positive integer options' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            { Get-DVLSVaultConfiguration -AdditionalParameters @{
                ServerUrl             = 'https://dvls.example.test'
                AppKey                = 'key'
                AppSecret             = 'secret'
                AllowVaultEnumeration = $true
                PageSize              = 0
            } } | Should -Throw '*PageSize*'
        }
    }

    It 'escapes REST path segments and query string values' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            $uri = Join-DVLSApiUri `
                -ServerUrl 'https://dvls.example.test/base' `
                -PathSegments @('api', 'v1', 'vault', 'vault id', 'entry') `
                -Query ([ordered]@{ includePasswords = 'true'; name = 'domain user' })

            $uri | Should -Match '^https://dvls\.example\.test/base/api/v1/vault/vault%20id/entry\?'
            $uri | Should -Match 'includePasswords=true'
            $uri | Should -Match 'name=domain%20user'
        }
    }

    It 'uses bounded REST request defaults' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            $options = Get-DVLSRequestOption -Configuration ([pscustomobject]@{ RequestTimeoutSeconds = 12 })

            $options.ContentType | Should -Be 'application/json'
            $options.SkipHttpErrorCheck | Should -BeTrue
            $options.TimeoutSec | Should -Be 12
            $options.HttpVersion | Should -Be '2.0'
        }
    }
}

Describe 'REST session and entry lookup helpers' {
    BeforeAll {
        $script:ExtensionManifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'SecretManagement.DevolutionsServer.Extension/SecretManagement.DevolutionsServer.Extension.psd1'
        Import-Module $script:ExtensionManifestPath -Force
    }

    It 'logs in with app key and app secret' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            Mock Invoke-RestMethod {
                Set-Variable -Name $StatusCodeVariable -Scope 1 -Value 200
                [pscustomobject]@{ tokenId = 'token-value' }
            } -ParameterFilter { $Method -eq 'Post' -and $Uri -eq 'https://dvls.example.test/api/v1/login' }

            $configuration = Get-DVLSVaultConfiguration -AdditionalParameters @{
                ServerUrl = 'https://dvls.example.test'
                AppKey    = 'app-key'
                AppSecret = 'app-secret'
                VaultId   = 'vault-1'
            }

            $session = Connect-DVLSSession -Configuration $configuration

            $session.TokenId | Should -Be 'token-value'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Post' -and
                $Uri -eq 'https://dvls.example.test/api/v1/login' -and
                ($Body | ConvertFrom-Json).appKey -eq 'app-key' -and
                ($Body | ConvertFrom-Json).appSecret -eq 'app-secret'
            }
        }
    }

    It 'throws a safe authentication error when login response has no token' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            Mock Invoke-RestMethod {
                Set-Variable -Name $StatusCodeVariable -Scope 1 -Value 200
                [pscustomobject]@{ authenticated = $true }
            }

            $configuration = Get-DVLSVaultConfiguration -AdditionalParameters @{
                ServerUrl = 'https://dvls.example.test'
                AppKey    = 'app-key'
                AppSecret = 'app-secret'
                VaultId   = 'vault-1'
            }

            { Connect-DVLSSession -Configuration $configuration } | Should -Throw '*authentication failed*'
        }
    }

    It 'logs out with the active token' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            Mock Invoke-RestMethod {
                Set-Variable -Name $StatusCodeVariable -Scope 1 -Value 200
                [pscustomobject]@{}
            } -ParameterFilter { $Method -eq 'Post' -and $Uri -eq 'https://dvls.example.test/api/v1/logout' }

            $configuration = [pscustomobject]@{ ServerUrl = 'https://dvls.example.test'; RequestTimeoutSeconds = 30 }
            $session = [pscustomobject]@{ TokenId = 'token-value'; ServerUrl = 'https://dvls.example.test'; Configuration = $configuration }

            Close-DVLSSession -Session $session

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Post' -and
                $Uri -eq 'https://dvls.example.test/api/v1/logout' -and
                $Headers.tokenId -eq 'token-value'
            }
        }
    }

    It 'does not enumerate vaults when VaultId is configured' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            Mock Invoke-RestMethod { throw 'Vault enumeration should not be called.' }

            $session = [pscustomobject]@{
                TokenId       = 'token-value'
                ServerUrl     = 'https://dvls.example.test'
                Configuration = [pscustomobject]@{
                    ServerUrl             = 'https://dvls.example.test'
                    VaultId               = 'vault-1'
                    AllowVaultEnumeration = $false
                    RequestTimeoutSeconds = 30
                }
            }

            Get-DVLSVaultId -Session $session | Should -Be @('vault-1')
            Should -Not -Invoke Invoke-RestMethod
        }
    }

    It 'lists only Credential entries across pages' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            Mock Invoke-RestMethod {
                If ($Uri -like '*pageNumber=1*') {
                    Set-Variable -Name $StatusCodeVariable -Scope 1 -Value 200
                    Return [pscustomobject]@{
                        currentPage = 1
                        totalPage   = 2
                        data        = @(
                            [pscustomobject]@{ id = 'credential-1'; name = 'SqlProd'; type = 'Credential' },
                            [pscustomobject]@{ id = 'note-1'; name = 'Note'; type = 'SecureNote' }
                        )
                    }
                }

                Set-Variable -Name $StatusCodeVariable -Scope 1 -Value 200
                [pscustomobject]@{
                    currentPage = 2
                    totalPage   = 2
                    data        = @(
                        [pscustomobject]@{ id = 'credential-2'; name = 'ApiProd'; type = 'Credential' }
                    )
                }
            }

            $session = [pscustomobject]@{
                TokenId       = 'token-value'
                ServerUrl     = 'https://dvls.example.test'
                Configuration = [pscustomobject]@{
                    ServerUrl             = 'https://dvls.example.test'
                    VaultId               = 'vault-1'
                    PageSize              = 1
                    RequestTimeoutSeconds = 30
                }
            }

            $entries = @(Get-DVLSCredentialEntry -Session $session -VaultId 'vault-1')

            $entries.Name | Should -Be @('SqlProd', 'ApiProd')
            Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter {
                $Method -eq 'Get' -and $Uri -like 'https://dvls.example.test/api/v1/vault/vault-1/entry*'
            }
        }
    }

    It 'throws safe errors for HTTP failures' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            Mock Invoke-RestMethod {
                Set-Variable -Name $StatusCodeVariable -Scope 1 -Value 500
                [pscustomobject]@{ StatusCode = 500; message = 'server failed'; password = 'secret-password' }
            }

            $configuration = [pscustomobject]@{ RequestTimeoutSeconds = 30 }
            $errorRecord = $null

            Try {
                Invoke-DVLSRestMethod -Method Get -Uri 'https://dvls.example.test/api/v1/vault' -Token 'token-value' -Configuration $configuration
            } Catch {
                $errorRecord = $_
            }

            $errorRecord | Should -Not -BeNullOrEmpty
            $errorRecord.Exception.Message | Should -Match 'HTTP 500'
            $errorRecord.Exception.Message | Should -Not -Match 'token-value|secret-password'
        }
    }
}

Describe 'SecretManagement output behavior' {
    BeforeAll {
        $script:ExtensionManifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'SecretManagement.DevolutionsServer.Extension/SecretManagement.DevolutionsServer.Extension.psd1'
        Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
        Import-Module $script:ExtensionManifestPath -Force
    }

    It 'returns null when Get-Secret finds no matching entry' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            Mock Invoke-RestMethod {
                Set-Variable -Name $StatusCodeVariable -Scope 1 -Value 200
                Switch -Wildcard ($Uri) {
                    '*/login'  { Return [pscustomobject]@{ tokenId = 'token-value' } }
                    '*/logout' { Return [pscustomobject]@{} }
                    '*entry*'  { Return [pscustomobject]@{ currentPage = 1; totalPage = 1; data = @() } }
                }
            }

            $result = Get-Secret -Name 'Missing' -VaultName 'DVLS' -AdditionalParameters @{
                ServerUrl = 'https://dvls.example.test'
                AppKey    = 'app-key'
                AppSecret = 'app-secret'
                VaultId   = 'vault-1'
            }

            $result | Should -BeNullOrEmpty
        }
    }

    It 'returns a PSCredential for a matching DVLS Credential entry' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            Mock Invoke-RestMethod {
                Set-Variable -Name $StatusCodeVariable -Scope 1 -Value 200
                Switch -Wildcard ($Uri) {
                    '*/login'                    { Return [pscustomobject]@{ tokenId = 'token-value' } }
                    '*/logout'                   { Return [pscustomobject]@{} }
                    '*/entry/credential-1*'      { Return [pscustomobject]@{ data = [pscustomobject]@{ username = 'svc-sql'; password = 'P@ssw0rd!'; domain = 'example.test' } } }
                    '*vault/vault-1/entry*'      { Return [pscustomobject]@{ currentPage = 1; totalPage = 1; data = @([pscustomobject]@{ id = 'credential-1'; name = 'SqlProd'; type = 'Credential' }) } }
                }
            }

            $credential = Get-Secret -Name 'SqlProd' -VaultName 'DVLS' -AdditionalParameters @{
                ServerUrl = 'https://dvls.example.test'
                AppKey    = 'app-key'
                AppSecret = 'app-secret'
                VaultId   = 'vault-1'
            }

            $credential | Should -BeOfType ([System.Management.Automation.PSCredential])
            $credential.UserName | Should -Be 'svc-sql@example.test'
            $credential.GetNetworkCredential().Password | Should -Be 'P@ssw0rd!'
        }
    }

    It 'preserves already-qualified usernames when DVLS also returns a domain' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            Mock Invoke-RestMethod {
                Set-Variable -Name $StatusCodeVariable -Scope 1 -Value 200
                Switch -Wildcard ($Uri) {
                    '*/login'                    { Return [pscustomobject]@{ tokenId = 'token-value' } }
                    '*/logout'                   { Return [pscustomobject]@{} }
                    '*/entry/credential-1*'      { Return [pscustomobject]@{ data = [pscustomobject]@{ username = 'svc-sql@existing.test'; password = 'P@ssw0rd!'; domain = 'example.test' } } }
                    '*vault/vault-1/entry*'      { Return [pscustomobject]@{ currentPage = 1; totalPage = 1; data = @([pscustomobject]@{ id = 'credential-1'; name = 'SqlProd'; type = 'Credential' }) } }
                }
            }

            $credential = Get-Secret -Name 'SqlProd' -VaultName 'DVLS' -AdditionalParameters @{
                ServerUrl = 'https://dvls.example.test'
                AppKey    = 'app-key'
                AppSecret = 'app-secret'
                VaultId   = 'vault-1'
            }

            $credential.UserName | Should -Be 'svc-sql@existing.test'
        }
    }

    It 'falls back to direct GUID lookup when no name match exists' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            $entryId = '11111111-1111-1111-1111-111111111111'
            Mock Invoke-RestMethod {
                Set-Variable -Name $StatusCodeVariable -Scope 1 -Value 200
                Switch -Wildcard ($Uri) {
                    '*/login'          { Return [pscustomobject]@{ tokenId = 'token-value' } }
                    '*/logout'         { Return [pscustomobject]@{} }
                    "*/entry/$entryId*" { Return [pscustomobject]@{ data = [pscustomobject]@{ id = $entryId; type = 'Credential'; username = 'svc-api'; password = 'Secret1!'; domain = '' } } }
                    '*vault/vault-1/entry*' { Return [pscustomobject]@{ currentPage = 1; totalPage = 1; data = @() } }
                }
            }

            $credential = Get-Secret -Name $entryId -VaultName 'DVLS' -AdditionalParameters @{
                ServerUrl = 'https://dvls.example.test'
                AppKey    = 'app-key'
                AppSecret = 'app-secret'
                VaultId   = 'vault-1'
            }

            $credential.UserName | Should -Be 'svc-api'
        }
    }

    It 'returns SecretInformation objects and applies wildcard filters' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            Mock Invoke-RestMethod {
                Set-Variable -Name $StatusCodeVariable -Scope 1 -Value 200
                Switch -Wildcard ($Uri) {
                    '*/login'  { Return [pscustomobject]@{ tokenId = 'token-value' } }
                    '*/logout' { Return [pscustomobject]@{} }
                    '*entry*'  {
                        Return [pscustomobject]@{
                            currentPage = 1
                            totalPage   = 1
                            data        = @(
                                [pscustomobject]@{ id = 'credential-1'; name = 'SqlProd'; type = 'Credential' },
                                [pscustomobject]@{ id = 'credential-2'; name = 'ApiDev'; type = 'Credential' }
                            )
                        }
                    }
                }
            }

            $info = @(Get-SecretInfo -Filter '*Prod' -VaultName 'DVLS' -AdditionalParameters @{
                ServerUrl = 'https://dvls.example.test'
                AppKey    = 'app-key'
                AppSecret = 'app-secret'
                VaultId   = 'vault-1'
            })

            $info | Should -HaveCount 1
            $info[0].Name | Should -Be 'SqlProd'
            $info[0].Type | Should -Be ([Microsoft.PowerShell.SecretManagement.SecretType]::PSCredential)
            $info[0].VaultName | Should -Be 'DVLS'
        }
    }

    It 'returns exactly one Boolean from Test-SecretVault' {
        InModuleScope SecretManagement.DevolutionsServer.Extension {
            Mock Invoke-RestMethod {
                Set-Variable -Name $StatusCodeVariable -Scope 1 -Value 200
                Switch -Wildcard ($Uri) {
                    '*/login'  { Return [pscustomobject]@{ tokenId = 'token-value' } }
                    '*/logout' { Return [pscustomobject]@{} }
                    '*entry*'  { Return [pscustomobject]@{ currentPage = 1; totalPage = 1; data = @() } }
                }
            }

            $result = @(Test-SecretVault -VaultName 'DVLS' -AdditionalParameters @{
                ServerUrl = 'https://dvls.example.test'
                AppKey    = 'app-key'
                AppSecret = 'app-secret'
                VaultId   = 'vault-1'
            })

            $result | Should -HaveCount 1
            $result[0] | Should -BeTrue
        }
    }
}

Describe 'PowerShell source documentation' {
    BeforeAll {
        $script:ProjectRoot = Split-Path -Parent $PSScriptRoot
    }

    It 'documents module manifests and exported SecretManagement commands in source' {
        $parentManifest = Get-Content -Raw (Join-Path $script:ProjectRoot 'SecretManagement.DevolutionsServer.psd1')
        $extensionManifest = Get-Content -Raw (Join-Path $script:ProjectRoot 'SecretManagement.DevolutionsServer.Extension/SecretManagement.DevolutionsServer.Extension.psd1')
        $moduleSource = Get-Content -Raw (Join-Path $script:ProjectRoot 'SecretManagement.DevolutionsServer.Extension/SecretManagement.DevolutionsServer.Extension.psm1')

        $parentManifest | Should -Match 'Public module manifest'
        $extensionManifest | Should -Match 'SecretManagement extension manifest'
        $moduleSource | Should -Match 'Configuration parser for SecretManagement VaultParameters'
        $moduleSource | Should -Match '\.PARAMETER AdditionalParameters'
        $moduleSource | Should -Match 'Called by Microsoft\.PowerShell\.SecretManagement'
        $moduleSource | Should -Match 'Future mutable operations'
        $moduleSource | Should -Match 'SuppressMessageAttribute'
    }

    It 'keeps positive integer validation inline with vault configuration parsing' {
        $moduleSource = Get-Content -Raw (Join-Path $script:ProjectRoot 'SecretManagement.DevolutionsServer.Extension/SecretManagement.DevolutionsServer.Extension.psm1')

        $moduleSource | Should -Not -Match 'Function ConvertTo-DVLSPositiveInt'
    }

    It 'uses analyzer-friendly private helper names where the SecretManagement contract allows it' {
        $moduleSource = Get-Content -Raw (Join-Path $script:ProjectRoot 'SecretManagement.DevolutionsServer.Extension/SecretManagement.DevolutionsServer.Extension.psm1')

        $moduleSource | Should -Match 'Function Join-DVLSApiUri'
        $moduleSource | Should -Match 'Function Connect-DVLSSession'
        $moduleSource | Should -Match 'Function ConvertTo-DVLSSecretInformation'
        $moduleSource | Should -Not -Match 'Function New-DVLSApiUri'
        $moduleSource | Should -Not -Match 'Function New-DVLSSession'
        $moduleSource | Should -Not -Match 'Function New-DVLSSecretInformation'
    }
}

Describe 'project documentation' {
    BeforeAll {
        $script:ProjectRoot = Split-Path -Parent $PSScriptRoot
    }

    It 'documents read-only PowerShell Universal usage in README.md' {
        $readmePath = Join-Path $script:ProjectRoot 'README.md'

        $readmePath | Should -Exist
        $content = Get-Content -Raw $readmePath
        $content | Should -Match 'read-only'
        $content | Should -Match 'PowerShell Universal'
        $content | Should -Match 'Register-SecretVault'
        $content | Should -Match 'Invoke-Pester'
        $content | Should -Match 'Repository\\Modules'
        $content | Should -Match '\.universal\\vaults\.ps1'
        $content | Should -Match 'Create a PSU test script'
        $content | Should -Match 'bootstrap'
        $content | Should -Match 'inline credentials'
        $content | Should -Match 'View password'
        $content | Should -Match 'View sensitive information'
        $content | Should -Match 'integrated environment'
        $content | Should -Match 'Settings > Environments'
        $content | Should -Match 'Future Mutable Operations'
        $content | Should -Match 'SupportsShouldProcess'
        $content | Should -Not -Match 'Save-Module Microsoft.PowerShell.SecretManagement'
    }

    It 'documents agent guidance in AGENTS.md' {
        $agentsPath = Join-Path $script:ProjectRoot 'AGENTS.md'

        $agentsPath | Should -Exist
        $content = Get-Content -Raw $agentsPath
        $content | Should -Match 'SecretManagement'
        $content | Should -Match 'read-only'
        $content | Should -Match 'Invoke-Pester'
        $content | Should -Match 'Do not log'
        $content | Should -Match '\.universal\\vaults\.ps1'
        $content | Should -Match 'View password'
        $content | Should -Match 'integrated environment'
        $content | Should -Match 'Settings > Environments'
        $content | Should -Match 'Future Mutable Operations'
        $content | Should -Match 'SupportsShouldProcess'
    }
}
