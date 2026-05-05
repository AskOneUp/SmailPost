Describe 'Get-SPAllowedSender' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot
        . (Join-Path $script:ModuleRoot 'Private\Graph\Get-SPGraphAccessToken.ps1')
        . (Join-Path $script:ModuleRoot 'Public\Identity\Get-SPAllowedSender.ps1')
    }

    Context 'When access token acquisition fails' {
        It 'Throws when token result is null' {
            Mock Get-SPGraphAccessToken {
                $null
            }

            {
                Get-SPAllowedSender
            } | Should -Throw 'Unable to acquire Microsoft Graph access token.'
        }

        It 'Throws when token result indicates failure' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $false
                    AccessToken = 'token'
                    TokenType   = 'Bearer'
                }
            }

            {
                Get-SPAllowedSender
            } | Should -Throw 'Unable to acquire Microsoft Graph access token.'
        }

        It 'Throws when access token is blank' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $true
                    AccessToken = '   '
                    TokenType   = 'Bearer'
                }
            }

            {
                Get-SPAllowedSender
            } | Should -Throw 'Unable to acquire Microsoft Graph access token.'
        }
    }

    Context 'When group lookup fails' {
        It 'Throws when group lookup request throws' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $true
                    AccessToken = 'token-value'
                    TokenType   = 'Bearer'
                }
            }

            Mock Invoke-RestMethod {
                throw [System.Exception]::new('Graph exploded.')
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups?*'
            }

            {
                Get-SPAllowedSender
            } | Should -Throw "Failed to retrieve sender group 'SmailPost-Senders'. Graph exploded."
        }

        It 'Throws when group lookup returns null' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $true
                    AccessToken = 'token-value'
                    TokenType   = 'Bearer'
                }
            }

            Mock Invoke-RestMethod {
                $null
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups?*'
            }

            {
                Get-SPAllowedSender
            } | Should -Throw "Failed to retrieve sender group 'SmailPost-Senders'."
        }

        It 'Throws when no sender group is found' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $true
                    AccessToken = 'token-value'
                    TokenType   = 'Bearer'
                }
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value = @()
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups?*'
            }

            {
                Get-SPAllowedSender
            } | Should -Throw "Sender group 'SmailPost-Senders' was not found."
        }

        It 'Throws when multiple sender groups are found' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $true
                    AccessToken = 'token-value'
                    TokenType   = 'Bearer'
                }
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{
                            id          = 'group-1'
                            displayName = 'SmailPost-Senders'
                        },
                        [pscustomobject]@{
                            id          = 'group-2'
                            displayName = 'SmailPost-Senders'
                        }
                    )
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups?*'
            }

            {
                Get-SPAllowedSender
            } | Should -Throw "Multiple groups named 'SmailPost-Senders' were found. Use a unique group name or switch to GroupId-based lookup."
        }

        It 'Throws when the sender group id is missing' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $true
                    AccessToken = 'token-value'
                    TokenType   = 'Bearer'
                }
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{
                            id          = '   '
                            displayName = 'SmailPost-Senders'
                        }
                    )
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups?*'
            }

            {
                Get-SPAllowedSender
            } | Should -Throw "Sender group 'SmailPost-Senders' was found, but its Id is missing."
        }
    }

    Context 'When member lookup fails' {
        It 'Throws when member lookup request throws' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $true
                    AccessToken = 'token-value'
                    TokenType   = 'Bearer'
                }
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{
                            id          = 'group-1'
                            displayName = 'SmailPost-Senders'
                        }
                    )
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups?*'
            }

            Mock Invoke-RestMethod {
                throw [System.Exception]::new('Members endpoint failed.')
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups/group-1/members?*'
            }

            {
                Get-SPAllowedSender
            } | Should -Throw "Failed to retrieve members for sender group 'SmailPost-Senders'. Members endpoint failed."
        }

        It 'Throws when member lookup returns null' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $true
                    AccessToken = 'token-value'
                    TokenType   = 'Bearer'
                }
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{
                            id          = 'group-1'
                            displayName = 'SmailPost-Senders'
                        }
                    )
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups?*'
            }

            Mock Invoke-RestMethod {
                $null
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups/group-1/members?*'
            }

            {
                Get-SPAllowedSender
            } | Should -Throw "Failed to retrieve members for sender group 'SmailPost-Senders'."
        }
    }

    Context 'When no valid members are present' {
        It 'Returns an empty array when the group has no members' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $true
                    AccessToken = 'token-value'
                    TokenType   = 'Bearer'
                }
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{
                            id          = 'group-1'
                            displayName = 'SmailPost-Senders'
                        }
                    )
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups?*'
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value             = @()
                    '@odata.nextLink' = $null
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups/group-1/members?*'
            }

            $result = Get-SPAllowedSender

            $null -eq $result.Count | Should -BeFalse
            $result.Count | Should -Be 0
        }

        It 'Returns an empty array when all members are filtered out' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $true
                    AccessToken = 'token-value'
                    TokenType   = 'Bearer'
                }
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{
                            id          = 'group-1'
                            displayName = 'SmailPost-Senders'
                        }
                    )
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups?*'
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value             = @(
                        [pscustomobject]@{
                            '@odata.type'     = '#microsoft.graph.group'
                            id                = 'ignored-1'
                            displayName       = 'Nested Group'
                            mail              = 'nested@contoso.com'
                            userPrincipalName = ''
                        },
                        [pscustomobject]@{
                            '@odata.type'     = '#microsoft.graph.user'
                            id                = 'ignored-2'
                            displayName       = 'No Mail'
                            mail              = ''
                            userPrincipalName = 'nomail@contoso.com'
                        },
                        [pscustomobject]@{
                            '@odata.type'     = '#microsoft.graph.user'
                            id                = '   '
                            displayName       = 'No Id'
                            mail              = 'noid@contoso.com'
                            userPrincipalName = 'noid@contoso.com'
                        }
                    )
                    '@odata.nextLink' = $null
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups/group-1/members?*'
            }

            $result = Get-SPAllowedSender

            $null -eq $result.Count | Should -BeFalse
            $result.Count | Should -Be 0
        }
    }

    Context 'When valid members are returned' {
        It 'Returns only valid mail-enabled users in sorted order' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $true
                    AccessToken = 'token-value'
                    TokenType   = 'Bearer'
                }
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{
                            id          = 'group-1'
                            displayName = 'SmailPost-Senders'
                        }
                    )
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups?*'
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value             = @(
                        [pscustomobject]@{
                            '@odata.type'     = '#microsoft.graph.user'
                            id                = 'user-2'
                            displayName       = 'Zulu User'
                            mail              = 'zulu@contoso.com'
                            userPrincipalName = 'zulu@contoso.com'
                        },
                        [pscustomobject]@{
                            '@odata.type'     = '#microsoft.graph.group'
                            id                = 'ignored-1'
                            displayName       = 'Nested Group'
                            mail              = 'nested@contoso.com'
                            userPrincipalName = ''
                        },
                        [pscustomobject]@{
                            '@odata.type'     = '#microsoft.graph.user'
                            id                = 'user-1'
                            displayName       = 'Alpha User'
                            mail              = 'alpha@contoso.com'
                            userPrincipalName = 'alpha@contoso.com'
                        },
                        [pscustomobject]@{
                            '@odata.type'     = '#microsoft.graph.user'
                            id                = 'ignored-2'
                            displayName       = 'No Mail'
                            mail              = ''
                            userPrincipalName = 'nomail@contoso.com'
                        }
                    )
                    '@odata.nextLink' = $null
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups/group-1/members?*'
            }

            $result = Get-SPAllowedSender

            $null -eq $result | Should -BeFalse
            $null -eq $result.Count | Should -BeFalse
            $result.Count | Should -Be 2

            $result[0].DisplayName | Should -Be 'Alpha User'
            $result[0].Mail | Should -Be 'alpha@contoso.com'
            $result[0].UserPrincipalName | Should -Be 'alpha@contoso.com'
            $result[0].Id | Should -Be 'user-1'

            $result[1].DisplayName | Should -Be 'Zulu User'
            $result[1].Mail | Should -Be 'zulu@contoso.com'
            $result[1].UserPrincipalName | Should -Be 'zulu@contoso.com'
            $result[1].Id | Should -Be 'user-2'
        }

        It 'Supports paging across multiple member responses' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $true
                    AccessToken = 'token-value'
                    TokenType   = 'Bearer'
                }
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{
                            id          = 'group-1'
                            displayName = 'SmailPost-Senders'
                        }
                    )
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups?*'
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value             = @(
                        [pscustomobject]@{
                            '@odata.type'     = '#microsoft.graph.user'
                            id                = 'user-2'
                            displayName       = 'Bravo User'
                            mail              = 'bravo@contoso.com'
                            userPrincipalName = 'bravo@contoso.com'
                        }
                    )
                    '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/groups/group-1/members?$skiptoken=page2'
                }
            } -ParameterFilter {
                $Uri -eq 'https://graph.microsoft.com/v1.0/groups/group-1/members?$select=id,displayName,mail,userPrincipalName'
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value             = @(
                        [pscustomobject]@{
                            '@odata.type'     = '#microsoft.graph.user'
                            id                = 'user-1'
                            displayName       = 'Alpha User'
                            mail              = 'alpha@contoso.com'
                            userPrincipalName = 'alpha@contoso.com'
                        }
                    )
                    '@odata.nextLink' = $null
                }
            } -ParameterFilter {
                $Uri -eq 'https://graph.microsoft.com/v1.0/groups/group-1/members?$skiptoken=page2'
            }

            $result = Get-SPAllowedSender

            $null -eq $result | Should -BeFalse
            $null -eq $result.Count | Should -BeFalse
            $result.Count | Should -Be 2

            $result[0].DisplayName | Should -Be 'Alpha User'
            $result[0].Mail | Should -Be 'alpha@contoso.com'
            $result[0].Id | Should -Be 'user-1'

            $result[1].DisplayName | Should -Be 'Bravo User'
            $result[1].Mail | Should -Be 'bravo@contoso.com'
            $result[1].Id | Should -Be 'user-2'
        }

        It 'Builds the authorization header from token type and access token' {
            Mock Get-SPGraphAccessToken {
                [pscustomobject]@{
                    Success     = $true
                    AccessToken = 'abc123'
                    TokenType   = 'Bearer'
                }
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{
                            id          = 'group-1'
                            displayName = 'SmailPost-Senders'
                        }
                    )
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups?*' -and
                $Headers.Authorization -eq 'Bearer abc123'
            }

            Mock Invoke-RestMethod {
                [pscustomobject]@{
                    value             = @()
                    '@odata.nextLink' = $null
                }
            } -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/groups/group-1/members?*' -and
                $Headers.Authorization -eq 'Bearer abc123'
            }

            $result = Get-SPAllowedSender

            $null -eq $result.Count | Should -BeFalse
            $result.Count | Should -Be 0
        }
    }
}
