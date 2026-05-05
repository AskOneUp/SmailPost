Describe 'Get-SPGraphAccessToken' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        if (-not (Get-Command Get-SPStoredSecretState -ErrorAction SilentlyContinue)) {
            function Get-SPStoredSecretState {
            }
        }

        if (-not (Get-Command Get-SecretInfo -ErrorAction SilentlyContinue)) {
            function Get-SecretInfo {
            }
        }

        if (-not (Get-Command Get-Secret -ErrorAction SilentlyContinue)) {
            function Get-Secret {
            }
        }

        function ConvertTo-SPTestJwt {
            param (
                [Parameter(Mandatory = $true)]
                [hashtable]$Payload
            )

            $headerJson = '{"alg":"none","typ":"JWT"}'
            $payloadJson = $Payload | ConvertTo-Json -Compress

            $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($headerJson)
            $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($payloadJson)

            $headerPart = [System.Convert]::ToBase64String($headerBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
            $payloadPart = [System.Convert]::ToBase64String($payloadBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')

            return "$headerPart.$payloadPart.signature"
        }

        . (Join-Path $script:ModuleRoot 'Private\Graph\Get-SPGraphAccessToken.ps1')
    }

    BeforeEach {
        Mock Get-SPStoredSecretState {
            [pscustomobject]@{
                SecretPresent    = $true
                MetadataPresent  = $true
                MetadataComplete = $true
            }
        }

        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = 'tenant-123'
                    AppID    = 'app-456'
                }
            }
        }

        Mock Get-Secret {
            $secureString = [System.Security.SecureString]::new()

            foreach ($character in 'super-secret-value'.ToCharArray()) {
                $secureString.AppendChar($character)
            }

            $secureString.MakeReadOnly()
            $secureString
        }

        Mock Invoke-RestMethod {
            $token = ConvertTo-SPTestJwt -Payload @{
                tid   = 'tenant-123'
                appid = 'app-456'
                aud   = 'https://graph.microsoft.com'
                iss   = 'https://sts.windows.net/tenant-123/'
                exp   = 4102444800
                roles = @('Mail.Send', 'User.Read.All')
            }

            [pscustomobject]@{
                access_token = $token
                token_type   = 'Bearer'
                expires_in   = 3600
            }
        }
    }

    It 'Returns failure when stored secret state could not be determined' {
        Mock Get-SPStoredSecretState {
            $null
        }

        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeFalse
        $result.SecretPresent | Should -BeFalse
        $result.MetadataPresent | Should -BeFalse
        $result.MetadataComplete | Should -BeFalse
        $result.Notes | Should -Contain 'Stored secret state could not be determined.'

        Should -Invoke Get-SPStoredSecretState -Times 1 -Exactly
        Should -Invoke Get-SecretInfo -Times 0 -Exactly
        Should -Invoke Get-Secret -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when stored secret is not present' {
        Mock Get-SPStoredSecretState {
            [pscustomobject]@{
                SecretPresent    = $false
                MetadataPresent  = $true
                MetadataComplete = $true
            }
        }

        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeFalse
        $result.SecretPresent | Should -BeFalse
        $result.MetadataPresent | Should -BeTrue
        $result.MetadataComplete | Should -BeTrue
        $result.Notes | Should -Contain 'Stored secret was not found.'

        Should -Invoke Get-SecretInfo -Times 0 -Exactly
        Should -Invoke Get-Secret -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when metadata is not present' {
        Mock Get-SPStoredSecretState {
            [pscustomobject]@{
                SecretPresent    = $true
                MetadataPresent  = $false
                MetadataComplete = $false
            }
        }

        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeFalse
        $result.SecretPresent | Should -BeTrue
        $result.MetadataPresent | Should -BeFalse
        $result.MetadataComplete | Should -BeFalse
        $result.Notes | Should -Contain 'Stored secret found.'
        $result.Notes | Should -Contain 'Secret metadata was not found.'

        Should -Invoke Get-SecretInfo -Times 0 -Exactly
        Should -Invoke Get-Secret -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when secret info could not be retrieved' {
        Mock Get-SecretInfo {
            $null
        }

        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeFalse
        $result.SecretPresent | Should -BeTrue
        $result.MetadataPresent | Should -BeTrue
        $result.Notes | Should -Contain 'Stored secret found.'
        $result.Notes | Should -Contain 'Secret metadata found.'
        $result.Notes | Should -Contain 'Secret info could not be retrieved.'

        Should -Invoke Get-SecretInfo -Times 1 -Exactly
        Should -Invoke Get-Secret -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when metadata is missing from secret info' {
        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = $null
            }
        }

        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeFalse
        $result.Notes | Should -Contain 'Metadata is missing from the stored secret.'

        Should -Invoke Get-Secret -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when required metadata is incomplete' {
        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = ''
                    AppID    = 'app-456'
                }
            }
        }

        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeFalse
        $result.MetadataComplete | Should -BeFalse
        $result.AppId | Should -Be 'app-456'
        $result.TenantId | Should -Be ''
        $result.Notes | Should -Contain 'Metadata is present but incomplete.'
        $result.Notes | Should -Contain 'Required metadata field TenantID is missing.'
        $result.Notes | Should -Contain 'Access token request was not attempted.'

        Should -Invoke Get-Secret -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when stored client secret could not be retrieved' {
        Mock Get-Secret {
            $null
        }

        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeFalse
        $result.Notes | Should -Contain 'Required metadata present.'
        $result.Notes | Should -Contain 'Stored client secret could not be retrieved.'

        Should -Invoke Get-Secret -Times 1 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when stored client secret is not a SecureString' {
        Mock Get-Secret {
            'not-a-secure-string'
        }

        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeFalse
        $result.Notes | Should -Contain 'Stored client secret is not a SecureString.'

        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when token endpoint returns no response' {
        Mock Invoke-RestMethod {
            $null
        }

        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeFalse
        $result.Notes | Should -Contain 'Token endpoint returned no response.'
    }

    It 'Returns failure when token endpoint does not return an access token' {
        Mock Invoke-RestMethod {
            [pscustomobject]@{
                access_token = ''
                token_type   = 'Bearer'
                expires_in   = 3600
            }
        }

        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeFalse
        $result.TokenType | Should -Be 'Bearer'
        $result.ExpiresInSeconds | Should -Be 3600
        $result.Notes | Should -Contain 'Token endpoint did not return an access token.'
    }

    It 'Returns success and decodes JWT payload when token request succeeds' {
        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeTrue
        $result.AccessToken | Should -Not -BeNullOrEmpty
        $result.TokenType | Should -Be 'Bearer'
        $result.ExpiresInSeconds | Should -Be 3600
        $result.TenantId | Should -Be 'tenant-123'
        $result.AppId | Should -Be 'app-456'
        $result.Audience | Should -Be 'https://graph.microsoft.com'
        $result.Issuer | Should -Be 'https://sts.windows.net/tenant-123/'
        $result.Roles.Count | Should -Be 2
        $result.Roles | Should -Contain 'Mail.Send'
        $result.Roles | Should -Contain 'User.Read.All'
        $result.ExpiresOn | Should -Not -BeNullOrEmpty
        $result.SecretPresent | Should -BeTrue
        $result.MetadataPresent | Should -BeTrue
        $result.MetadataComplete | Should -BeTrue
        $result.Notes | Should -Contain 'Stored secret found.'
        $result.Notes | Should -Contain 'Secret metadata found.'
        $result.Notes | Should -Contain 'Required metadata present.'
        $result.Notes | Should -Contain 'Access token acquired successfully.'
        $result.Notes | Should -Contain 'Token payload decoded successfully.'

        Should -Invoke Get-SPStoredSecretState -Times 1 -Exactly
        Should -Invoke Get-SecretInfo -Times 1 -Exactly
        Should -Invoke Get-Secret -Times 1 -Exactly
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly
    }

    It 'Returns success and note when token is acquired but not valid JWT format' {
        Mock Invoke-RestMethod {
            [pscustomobject]@{
                access_token = 'not-a-jwt'
                token_type   = 'Bearer'
                expires_in   = 3600
            }
        }

        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeTrue
        $result.AccessToken | Should -Be 'not-a-jwt'
        $result.Notes | Should -Contain 'Access token acquired successfully.'
        $result.Notes | Should -Contain 'Access token was acquired but is not a valid JWT format.'
    }

    It 'Returns success and note when token has no roles claim' {
        Mock Invoke-RestMethod {
            $token = ConvertTo-SPTestJwt -Payload @{
                tid   = 'tenant-123'
                appid = 'app-456'
                aud   = 'https://graph.microsoft.com'
                iss   = 'https://sts.windows.net/tenant-123/'
                exp   = 4102444800
            }

            [pscustomobject]@{
                access_token = $token
                token_type   = 'Bearer'
                expires_in   = 3600
            }
        }

        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeTrue
        $result.Roles.Count | Should -Be 0
        $result.Notes | Should -Contain 'Token does not contain a roles claim.'
    }

    It 'Returns stable failure object when token request throws' {
        Mock Invoke-RestMethod {
            throw 'AAD said no.'
        }

        $result = Get-SPGraphAccessToken

        $result.Success | Should -BeFalse
        $result.AccessToken | Should -BeNullOrEmpty
        $result.TokenType | Should -BeNullOrEmpty
        $result.Roles.Count | Should -Be 0
        $result.Notes | Should -Contain 'Access token request failed: AAD said no.'
    }
}
