Describe 'Test-SPSenderAllowed' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Public\Identity\Get-SPAllowedSender.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Validation\Test-SPSenderAllowed.ps1')
    }

    It 'Returns not allowed when SenderAddress is empty or whitespace' {
        Mock Get-SPAllowedSender {}

        $result = Test-SPSenderAllowed -SenderAddress '   '

        $result.SenderAddress | Should -Be '   '
        $result.Allowed | Should -BeFalse
        $result.MatchedSender | Should -BeNullOrEmpty
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be 'SenderAddress value is empty.'
        Should -Invoke Get-SPAllowedSender -Times 0
    }

    It 'Returns not allowed when no allowed senders are returned' {
        Mock Get-SPAllowedSender {
            @()
        }

        $result = Test-SPSenderAllowed -SenderAddress 'sender@example.com'

        $result.SenderAddress | Should -Be 'sender@example.com'
        $result.Allowed | Should -BeFalse
        $result.MatchedSender | Should -BeNullOrEmpty
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be 'No allowed senders were returned from the SmailPost-Senders group.'
        Should -Invoke Get-SPAllowedSender -Times 1 -Exactly
    }

    It 'Returns allowed when Mail matches sender address case-insensitively' {
        Mock Get-SPAllowedSender {
            @(
                [pscustomobject]@{
                    Mail              = 'AskOneUp@Outlook.com'
                    UserPrincipalName = 'donald@tenant.onmicrosoft.com'
                    DisplayName       = 'Donald'
                }
            )
        }

        $result = Test-SPSenderAllowed -SenderAddress '  askoneup@outlook.com  '

        $result.Allowed | Should -BeTrue
        $result.MatchedSender | Should -Not -BeNullOrEmpty
        $result.MatchedSender.Mail | Should -Be 'AskOneUp@Outlook.com'
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be "SenderAddress '  askoneup@outlook.com  ' is allowed."
        Should -Invoke Get-SPAllowedSender -Times 1 -Exactly
    }

    It 'Returns allowed when UserPrincipalName matches sender address case-insensitively' {
        Mock Get-SPAllowedSender {
            @(
                [pscustomobject]@{
                    Mail              = $null
                    UserPrincipalName = 'Donald@AskOneUpOutlook.onmicrosoft.com'
                    DisplayName       = 'Donald'
                }
            )
        }

        $result = Test-SPSenderAllowed -SenderAddress 'donald@askoneupoutlook.onmicrosoft.com'

        $result.Allowed | Should -BeTrue
        $result.MatchedSender | Should -Not -BeNullOrEmpty
        $result.MatchedSender.UserPrincipalName | Should -Be 'Donald@AskOneUpOutlook.onmicrosoft.com'
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be "SenderAddress 'donald@askoneupoutlook.onmicrosoft.com' is allowed."
        Should -Invoke Get-SPAllowedSender -Times 1 -Exactly
    }

    It 'Returns not allowed when sender address does not match any allowed sender' {
        Mock Get-SPAllowedSender {
            @(
                [pscustomobject]@{
                    Mail              = 'someoneelse@example.com'
                    UserPrincipalName = 'someoneelse@tenant.onmicrosoft.com'
                    DisplayName       = 'Someone Else'
                }
            )
        }

        $result = Test-SPSenderAllowed -SenderAddress 'sender@example.com'

        $result.Allowed | Should -BeFalse
        $result.MatchedSender | Should -BeNullOrEmpty
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be "SenderAddress 'sender@example.com' is not in the SmailPost-Senders group."
        Should -Invoke Get-SPAllowedSender -Times 1 -Exactly
    }

    It 'Returns not allowed and note when Get-SPAllowedSender throws' {
        Mock Get-SPAllowedSender {
            throw 'Graph took a coffee break.'
        }

        $result = Test-SPSenderAllowed -SenderAddress 'sender@example.com'

        $result.Allowed | Should -BeFalse
        $result.MatchedSender | Should -BeNullOrEmpty
        $result.Notes.Count | Should -Be 1
        $result.Notes[0] | Should -Be 'Sender validation failed: Graph took a coffee break.'
        Should -Invoke Get-SPAllowedSender -Times 1 -Exactly
    }
}
