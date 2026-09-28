Describe 'Test-SPMailReady' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        if (-not (Get-Command Get-SPStoredSecretState -ErrorAction SilentlyContinue)) {
            function Get-SPStoredSecretState {
            }
        }

        if (-not (Get-Command Test-SPGraphConnection -ErrorAction SilentlyContinue)) {
            function Test-SPGraphConnection {
            }
        }

        if (-not (Get-Command Get-SPAllowedSender -ErrorAction SilentlyContinue)) {
            function Get-SPAllowedSender {
            }
        }

        . (Join-Path $script:ModuleRoot 'Private\Environment\Test-SPMailReady.ps1')
    }

    BeforeEach {
        Mock Get-SPStoredSecretState {
            [pscustomobject]@{
                SecretComplete = $true
                Notes          = @()
            }
        }

        Mock Test-SPGraphConnection {
            [pscustomobject]@{
                Success = $true
                Notes   = @()
            }
        }

        Mock Get-SPAllowedSender {
            @(
                [pscustomobject]@{
                    DisplayName = 'Donald'
                    Mail        = 'askoneup@askoneup.com'
                }
            )
        }
    }

    It 'Returns ready when all readiness checks succeed' {
        $result = Test-SPMailReady

        $result.Ready | Should -BeTrue
        $result.SecretReady | Should -BeTrue
        $result.GraphReady | Should -BeTrue
        $result.AllowedSendersReady | Should -BeTrue
        $result.AllowedSenderCount | Should -Be 1
        $result.Notes | Should -Contain 'Stored Graph credentials are present.'
        $result.Notes | Should -Contain 'Microsoft Graph app-only connection is valid.'
        $result.Notes | Should -Contain 'Found 1 valid allowed sender(s).'

        Should -Invoke Get-SPStoredSecretState -Times 1 -Exactly
        Should -Invoke Test-SPGraphConnection -Times 1 -Exactly
        Should -Invoke Get-SPAllowedSender -Times 1 -Exactly
    }

    It 'Returns not ready when stored secret is incomplete' {
        Mock Get-SPStoredSecretState {
            [pscustomobject]@{
                SecretComplete = $false
                Notes          = @(
                    'ClientId is missing.',
                    'TenantId is missing.'
                )
            }
        }

        $result = Test-SPMailReady

        $result.Ready | Should -BeFalse
        $result.SecretReady | Should -BeFalse
        $result.GraphReady | Should -BeFalse
        $result.AllowedSendersReady | Should -BeFalse
        $result.AllowedSenderCount | Should -Be 0
        $result.Notes | Should -Contain 'Stored Graph credentials are incomplete.'
        $result.Notes | Should -Contain 'ClientId is missing.'
        $result.Notes | Should -Contain 'TenantId is missing.'

        Should -Invoke Get-SPStoredSecretState -Times 1 -Exactly
        Should -Invoke Test-SPGraphConnection -Times 0 -Exactly
        Should -Invoke Get-SPAllowedSender -Times 0 -Exactly
    }

    It 'Returns not ready when reading stored secret throws' {
        Mock Get-SPStoredSecretState {
            throw 'Vault unavailable.'
        }

        $result = Test-SPMailReady

        $result.Ready | Should -BeFalse
        $result.SecretReady | Should -BeFalse
        $result.GraphReady | Should -BeFalse
        $result.AllowedSendersReady | Should -BeFalse
        $result.AllowedSenderCount | Should -Be 0
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be 'Failed to read stored Graph credentials: Vault unavailable.'

        Should -Invoke Get-SPStoredSecretState -Times 1 -Exactly
        Should -Invoke Test-SPGraphConnection -Times 0 -Exactly
        Should -Invoke Get-SPAllowedSender -Times 0 -Exactly
    }

    It 'Returns not ready when graph connection fails' {
        Mock Test-SPGraphConnection {
            [pscustomobject]@{
                Success = $false
                Notes   = @(
                    'Token request failed.'
                )
            }
        }

        $result = Test-SPMailReady

        $result.Ready | Should -BeFalse
        $result.SecretReady | Should -BeTrue
        $result.GraphReady | Should -BeFalse
        $result.AllowedSendersReady | Should -BeFalse
        $result.AllowedSenderCount | Should -Be 0
        $result.Notes | Should -Contain 'Stored Graph credentials are present.'
        $result.Notes | Should -Contain 'Microsoft Graph app-only connection test failed.'
        $result.Notes | Should -Contain 'Token request failed.'

        Should -Invoke Get-SPStoredSecretState -Times 1 -Exactly
        Should -Invoke Test-SPGraphConnection -Times 1 -Exactly
        Should -Invoke Get-SPAllowedSender -Times 0 -Exactly
    }

    It 'Returns not ready when graph connection check throws' {
        Mock Test-SPGraphConnection {
            throw 'Graph exploded dramatically.'
        }

        $result = Test-SPMailReady

        $result.Ready | Should -BeFalse
        $result.SecretReady | Should -BeTrue
        $result.GraphReady | Should -BeFalse
        $result.AllowedSendersReady | Should -BeFalse
        $result.AllowedSenderCount | Should -Be 0
        $result.Notes | Should -Contain 'Stored Graph credentials are present.'
        $result.Notes | Should -Contain 'Graph readiness check failed: Graph exploded dramatically.'

        Should -Invoke Get-SPStoredSecretState -Times 1 -Exactly
        Should -Invoke Test-SPGraphConnection -Times 1 -Exactly
        Should -Invoke Get-SPAllowedSender -Times 0 -Exactly
    }

    It 'Returns not ready when no allowed senders are found' {
        Mock Get-SPAllowedSender {
            @()
        }

        $result = Test-SPMailReady

        $result.Ready | Should -BeFalse
        $result.SecretReady | Should -BeTrue
        $result.GraphReady | Should -BeTrue
        $result.AllowedSendersReady | Should -BeFalse
        $result.AllowedSenderCount | Should -Be 0
        $result.Notes | Should -Contain 'Stored Graph credentials are present.'
        $result.Notes | Should -Contain 'Microsoft Graph app-only connection is valid.'
        $result.Notes | Should -Contain "No valid allowed senders were found in group 'C-S-mailPost-Senders'."

        Should -Invoke Get-SPStoredSecretState -Times 1 -Exactly
        Should -Invoke Test-SPGraphConnection -Times 1 -Exactly
        Should -Invoke Get-SPAllowedSender -Times 1 -Exactly
    }

    It 'Returns not ready when allowed sender lookup throws' {
        Mock Get-SPAllowedSender {
            throw 'Group lookup failed.'
        }

        $result = Test-SPMailReady

        $result.Ready | Should -BeFalse
        $result.SecretReady | Should -BeTrue
        $result.GraphReady | Should -BeTrue
        $result.AllowedSendersReady | Should -BeFalse
        $result.AllowedSenderCount | Should -Be 0
        $result.Notes | Should -Contain 'Stored Graph credentials are present.'
        $result.Notes | Should -Contain 'Microsoft Graph app-only connection is valid.'
        $result.Notes | Should -Contain 'Allowed sender readiness check failed: Group lookup failed.'

        Should -Invoke Get-SPStoredSecretState -Times 1 -Exactly
        Should -Invoke Test-SPGraphConnection -Times 1 -Exactly
        Should -Invoke Get-SPAllowedSender -Times 1 -Exactly
    }

    It 'Sets AllowedSenderCount when multiple allowed senders are returned' {
        Mock Get-SPAllowedSender {
            @(
                [pscustomobject]@{
                    DisplayName = 'Donald'
                    Mail        = 'askoneup@askoneup.com'
                },
                [pscustomobject]@{
                    DisplayName = 'Vince'
                    Mail        = 'vincent@outlook.com'
                }
            )
        }

        $result = Test-SPMailReady

        $result.Ready | Should -BeTrue
        $result.AllowedSendersReady | Should -BeTrue
        $result.AllowedSenderCount | Should -Be 2
        $result.Notes | Should -Contain 'Found 2 valid allowed sender(s).'
    }
}
