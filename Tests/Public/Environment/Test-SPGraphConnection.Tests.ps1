Describe 'Test-SPGraphConnection' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Public\Environment\Test-SPGraphConnection.ps1')

        function ConvertTo-TestSecureString {
            [CmdletBinding()]
            [OutputType([System.Security.SecureString])]
            param(
                [Parameter(Mandatory = $true)]
                [AllowEmptyString()]
                [string]$Value
            )

            $secureString = [System.Security.SecureString]::new()

            foreach ($character in $Value.ToCharArray()) {
                $secureString.AppendChar($character)
            }

            $secureString.MakeReadOnly()
            return $secureString
        }

        function ConvertTo-TestJwtToken {
            [CmdletBinding()]
            [OutputType([string])]
            param(
                [Parameter(Mandatory = $true)]
                [string[]]$Roles
            )

            $headerJson = '{"alg":"none"}'
            $payloadJson = @{
                roles = $Roles
            } | ConvertTo-Json -Compress

            $header = [System.Convert]::ToBase64String(
                [System.Text.Encoding]::UTF8.GetBytes($headerJson)
            ).TrimEnd('=').Replace('+', '-').Replace('/', '_')

            $payload = [System.Convert]::ToBase64String(
                [System.Text.Encoding]::UTF8.GetBytes($payloadJson)
            ).TrimEnd('=').Replace('+', '-').Replace('/', '_')

            return "$header.$payload.signature"
        }
    }

    BeforeEach {
        $script:SecureSecret = $null
        $script:AccessToken = $null
    }

    It 'Returns failure when secret info is not found' {
        Mock Get-SecretInfo { $null }
        Mock Get-Secret { throw 'Should not be called.' }
        Mock Invoke-RestMethod { throw 'Should not be called.' }

        $result = Test-SPGraphConnection

        $result.Success | Should -BeFalse
        $result.TokenAcquired | Should -BeFalse
        $result.GraphConnected | Should -BeFalse
        $result.TenantId | Should -Be ''
        $result.TenantDisplayName | Should -Be ''

        $null -eq $result.RolesPresent | Should -BeFalse
        $result.RolesPresent.Count | Should -Be 0

        $null -eq $result.MissingRoles | Should -BeFalse
        $result.MissingRoles.Count | Should -Be 0

        $result.TokenExpiresOn | Should -BeNullOrEmpty
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be "Secret 'SmailPost-GraphClientSecret' not found in vault 'SmailPost'."
    }

    It 'Returns failure when secret metadata is missing' {
        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = $null
            }
        }
        Mock Get-Secret { throw 'Should not be called.' }
        Mock Invoke-RestMethod { throw 'Should not be called.' }

        $result = Test-SPGraphConnection

        $result.Success | Should -BeFalse
        $result.TokenAcquired | Should -BeFalse
        $result.GraphConnected | Should -BeFalse
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be "Secret 'SmailPost-GraphClientSecret' exists but metadata is missing."

        Assert-MockCalled Get-SecretInfo -Times 1 -Exactly
        Assert-MockCalled Get-Secret -Times 0 -Exactly
        Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when TenantID metadata is missing' {
        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = ''
                    AppID    = 'app-id-123'
                }
            }
        }
        Mock Get-Secret { throw 'Should not be called.' }
        Mock Invoke-RestMethod { throw 'Should not be called.' }

        $result = Test-SPGraphConnection

        $result.Success | Should -BeFalse
        $result.TenantId | Should -Be ''
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be "Metadata field 'TenantID' is missing or empty on secret 'SmailPost-GraphClientSecret'."

        Assert-MockCalled Get-SecretInfo -Times 1 -Exactly
        Assert-MockCalled Get-Secret -Times 0 -Exactly
        Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when AppID metadata is missing' {
        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = 'tenant-id-123'
                    AppID    = ''
                }
            }
        }
        Mock Get-Secret { throw 'Should not be called.' }
        Mock Invoke-RestMethod { throw 'Should not be called.' }

        $result = Test-SPGraphConnection

        $result.Success | Should -BeFalse
        $result.TenantId | Should -Be ''
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be "Metadata field 'AppID' is missing or empty on secret 'SmailPost-GraphClientSecret'."

        Assert-MockCalled Get-SecretInfo -Times 1 -Exactly
        Assert-MockCalled Get-Secret -Times 0 -Exactly
        Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when both TenantID and AppID metadata are missing' {
        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = ''
                    AppID    = ''
                }
            }
        }
        Mock Get-Secret { throw 'Should not be called.' }
        Mock Invoke-RestMethod { throw 'Should not be called.' }

        $result = Test-SPGraphConnection

        $result.Success | Should -BeFalse
        $result.TenantId | Should -Be ''
        $result.Notes.Count | Should -Be 2
        $result.Notes[0] | Should -Be "Metadata field 'TenantID' is missing or empty on secret 'SmailPost-GraphClientSecret'."
        $result.Notes[1] | Should -Be "Metadata field 'AppID' is missing or empty on secret 'SmailPost-GraphClientSecret'."

        Assert-MockCalled Get-SecretInfo -Times 1 -Exactly
        Assert-MockCalled Get-Secret -Times 0 -Exactly
        Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when secret value is not a SecureString' {
        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = 'tenant-id-123'
                    AppID    = 'app-id-123'
                }
            }
        }
        Mock Get-Secret { 'plain-text-secret' }
        Mock Invoke-RestMethod { throw 'Should not be called.' }

        $result = Test-SPGraphConnection

        $result.Success | Should -BeFalse
        $result.TenantId | Should -Be 'tenant-id-123'
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be "Secret 'SmailPost-GraphClientSecret' is not stored as a SecureString."

        Assert-MockCalled Get-SecretInfo -Times 1 -Exactly
        Assert-MockCalled Get-Secret -Times 1 -Exactly
        Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when secret value is an empty SecureString' {
        $script:SecureSecret = ConvertTo-TestSecureString -Value ''

        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = 'tenant-id-123'
                    AppID    = 'app-id-123'
                }
            }
        }
        Mock Get-Secret { $script:SecureSecret }
        Mock Invoke-RestMethod { throw 'Should not be called.' }

        $result = Test-SPGraphConnection

        $result.Success | Should -BeFalse
        $result.TenantId | Should -Be 'tenant-id-123'
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be "Secret 'SmailPost-GraphClientSecret' exists but the value is empty."

        Assert-MockCalled Get-SecretInfo -Times 1 -Exactly
        Assert-MockCalled Get-Secret -Times 1 -Exactly
        Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure when token endpoint returns no access token' {
        $script:SecureSecret = ConvertTo-TestSecureString -Value 'client-secret-value'

        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = 'tenant-id-123'
                    AppID    = 'app-id-123'
                }
            }
        }
        Mock Get-Secret { $script:SecureSecret }
        Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } {
            [pscustomobject]@{
                access_token = ''
                expires_in   = 3600
            }
        }
        Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } {
            throw 'Should not be called.'
        }

        $result = Test-SPGraphConnection

        $result.Success | Should -BeFalse
        $result.TokenAcquired | Should -BeFalse
        $result.GraphConnected | Should -BeFalse
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be 'Token endpoint returned no access token.'

        Assert-MockCalled Get-SecretInfo -Times 1 -Exactly
        Assert-MockCalled Get-Secret -Times 1 -Exactly
        Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -Times 1 -Exactly
        Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } -Times 0 -Exactly
    }

    It 'Returns failure when access token format is invalid' {
        $script:SecureSecret = ConvertTo-TestSecureString -Value 'client-secret-value'

        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = 'tenant-id-123'
                    AppID    = 'app-id-123'
                }
            }
        }
        Mock Get-Secret { $script:SecureSecret }
        Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } {
            [pscustomobject]@{
                access_token = 'not-a-jwt'
                expires_in   = 3600
            }
        }
        Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } {
            throw 'Should not be called.'
        }

        $result = Test-SPGraphConnection

        $result.Success | Should -BeFalse
        $result.TokenAcquired | Should -BeTrue
        $result.GraphConnected | Should -BeFalse
        $result.Notes.Count | Should -Be 2
        $result.Notes[0] | Should -Be 'Access token acquired successfully.'
        $result.Notes[1] | Should -Be 'Access token format is invalid.'

        Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -Times 1 -Exactly
        Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } -Times 0 -Exactly
    }

    It 'Returns success when token contains required roles and organization lookup succeeds' {
        $script:SecureSecret = ConvertTo-TestSecureString -Value 'client-secret-value'
        $script:AccessToken = ConvertTo-TestJwtToken -Roles @(
            'Mail.Send',
            'GroupMember.Read.All',
            'User.Read.All'
        )

        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = 'tenant-id-123'
                    AppID    = 'app-id-123'
                }
            }
        }

        Mock Get-Secret { $script:SecureSecret }

        Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } {
            [pscustomobject]@{
                access_token = $script:AccessToken
                expires_in   = 3600
            }
        }

        Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } {
            [pscustomobject]@{
                value = @(
                    [pscustomobject]@{
                        id          = 'org-id-123'
                        displayName = 'AskOneUp Empire'
                    }
                )
            }
        }

        $result = Test-SPGraphConnection

        $result.Success | Should -BeTrue
        $result.TokenAcquired | Should -BeTrue
        $result.GraphConnected | Should -BeTrue
        $result.TenantId | Should -Be 'tenant-id-123'
        $result.TenantDisplayName | Should -Be 'AskOneUp Empire'

        $null -eq $result.RolesPresent | Should -BeFalse
        $result.RolesPresent.Count | Should -Be 3
        $result.RolesPresent | Should -Contain 'Mail.Send'
        $result.RolesPresent | Should -Contain 'GroupMember.Read.All'
        $result.RolesPresent | Should -Contain 'User.Read.All'

        $null -eq $result.MissingRoles.Count | Should -BeFalse
        $result.MissingRoles.Count | Should -Be 0

        $result.TokenExpiresOn | Should -Not -BeNullOrEmpty
        $result.Notes.Count | Should -Be 3
        $result.Notes[0] | Should -Be 'Access token acquired successfully.'
        $result.Notes[1] | Should -Be 'All required application roles are present in the token.'
        $result.Notes[2] | Should -Be "Connected to Microsoft Graph tenant 'AskOneUp Empire'."
    }

    It 'Returns failure when token is missing required roles even when Graph connection succeeds' {
        $script:SecureSecret = ConvertTo-TestSecureString -Value 'client-secret-value'
        $script:AccessToken = ConvertTo-TestJwtToken -Roles @(
            'Mail.Send'
        )

        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = 'tenant-id-123'
                    AppID    = 'app-id-123'
                }
            }
        }
        Mock Get-Secret { $script:SecureSecret }
        Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } {
            [pscustomobject]@{
                access_token = $script:AccessToken
                expires_in   = 3600
            }
        }
        Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } {
            [pscustomobject]@{
                value = @(
                    [pscustomobject]@{
                        id          = 'org-id-123'
                        displayName = 'AskOneUp Empire'
                    }
                )
            }
        }

        $result = Test-SPGraphConnection

        $result.Success | Should -BeFalse
        $result.TokenAcquired | Should -BeTrue
        $result.GraphConnected | Should -BeTrue
        $result.MissingRoles.Count | Should -Be 2
        $result.MissingRoles | Should -Contain 'GroupMember.Read.All'
        $result.MissingRoles | Should -Contain 'User.Read.All'
        $result.Notes.Count | Should -Be 3
        $result.Notes[0] | Should -Be 'Access token acquired successfully.'
        $result.Notes[1] | Should -Be 'Token is missing required application roles: GroupMember.Read.All, User.Read.All.'
        $result.Notes[2] | Should -Be "Connected to Microsoft Graph tenant 'AskOneUp Empire'."

        Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -Times 1 -Exactly
        Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } -Times 1 -Exactly
    }

    It 'Returns failure when organization lookup succeeds but returns no tenant data' {
    $script:SecureSecret = ConvertTo-TestSecureString -Value 'client-secret-value'
    $script:AccessToken = ConvertTo-TestJwtToken -Roles @(
        'Mail.Send',
        'GroupMember.Read.All',
        'User.Read.All'
    )

    Mock Get-SecretInfo {
        [pscustomobject]@{
            Metadata = @{
                TenantID = 'tenant-id-123'
                AppID    = 'app-id-123'
            }
        }
    }

    Mock Get-Secret { $script:SecureSecret }

    Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } {
        [pscustomobject]@{
            access_token = $script:AccessToken
            expires_in   = 3600
        }
    }

    Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } {
        [pscustomobject]@{
            value = @()
        }
    }

    $result = Test-SPGraphConnection

    $result.Success | Should -BeFalse
    $result.TokenAcquired | Should -BeTrue
    $result.GraphConnected | Should -BeFalse
    $result.TenantDisplayName | Should -Be ''

    $null -eq $result.MissingRoles.Count | Should -BeFalse
    $result.MissingRoles.Count | Should -Be 0

    $result.Notes.Count | Should -Be 3
    $result.Notes[0] | Should -Be 'Access token acquired successfully.'
    $result.Notes[1] | Should -Be 'All required application roles are present in the token.'
    $result.Notes[2] | Should -Be 'Organization call succeeded but returned no tenant data.'
}

    It 'Returns failure note when secret info lookup throws' {
        Mock Get-SecretInfo {
            throw 'Vault is having a dramatic episode.'
        }
        Mock Get-Secret { throw 'Should not be called.' }
        Mock Invoke-RestMethod { throw 'Should not be called.' }

        $result = Test-SPGraphConnection

        $result.Success | Should -BeFalse
        $result.TokenAcquired | Should -BeFalse
        $result.GraphConnected | Should -BeFalse
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be 'Graph connection test failed: Vault is having a dramatic episode.'

        Assert-MockCalled Get-SecretInfo -Times 1 -Exactly
        Assert-MockCalled Get-Secret -Times 0 -Exactly
        Assert-MockCalled Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Returns failure note when Graph token request throws' {
        $script:SecureSecret = ConvertTo-TestSecureString -Value 'client-secret-value'

        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = 'tenant-id-123'
                    AppID    = 'app-id-123'
                }
            }
        }
        Mock Get-Secret { $script:SecureSecret }
        Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } {
            throw 'Token endpoint exploded.'
        }
        Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } {
            throw 'Should not be called.'
        }

        $result = Test-SPGraphConnection

        $result.Success | Should -BeFalse
        $result.TokenAcquired | Should -BeFalse
        $result.GraphConnected | Should -BeFalse
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be 'Graph connection test failed: Token endpoint exploded.'

        Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Method -eq 'Post' } -Times 1 -Exactly
        Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' } -Times 0 -Exactly
    }
}
