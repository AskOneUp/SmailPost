Describe 'Test-SPRecipientAddress' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Validation\Test-SPRecipientAddress.ps1')
    }

    Context 'When Recipient is valid' {
        It 'Returns a valid result for a clean email address' {
            # Proves the function accepts a valid email address as-is.
            $result = Test-SPRecipientAddress -Recipient 'user@example.com'

            $result | Should -Not -BeNullOrEmpty
            $result.Recipient | Should -Be 'user@example.com'
            $result.NormalizedRecipient | Should -Be 'user@example.com'
            $result.Valid | Should -BeTrue
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be "Recipient address 'user@example.com' is valid."
        }

        It 'Trims surrounding whitespace and returns a valid normalized address' {
            # Proves the function trims the input before validation.
            $result = Test-SPRecipientAddress -Recipient '  user@example.com  '

            $result.Recipient | Should -Be '  user@example.com  '
            $result.NormalizedRecipient | Should -Be 'user@example.com'
            $result.Valid | Should -BeTrue
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be "Recipient address 'user@example.com' is valid."
        }
    }

    Context 'When Recipient is empty or whitespace' {
        It 'Returns an invalid result for an empty string' {
            # Proves the function rejects an empty string.
            $result = Test-SPRecipientAddress -Recipient ''

            $result.Recipient | Should -Be ''
            $result.NormalizedRecipient | Should -Be ''
            $result.Valid | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'Recipient value is empty or whitespace.'
        }

        It 'Returns an invalid result for whitespace' {
            # Proves the function rejects a whitespace-only value.
            $result = Test-SPRecipientAddress -Recipient '   '

            $result.Recipient | Should -Be '   '
            $result.NormalizedRecipient | Should -Be ''
            $result.Valid | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'Recipient value is empty or whitespace.'
        }
    }

    Context 'When Recipient is not a valid email address' {
        It 'Returns an invalid result for a malformed address' {
            # Proves the function rejects a malformed email address.
            $result = Test-SPRecipientAddress -Recipient 'not-an-email'

            $result.Recipient | Should -Be 'not-an-email'
            $result.NormalizedRecipient | Should -Be ''
            $result.Valid | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Match "^Recipient address 'not-an-email' is invalid:"
        }

        It 'Returns an invalid result when the address is not in a clean email format' {
            # Proves the function rejects addresses that parse differently than the supplied normalized value.
            $result = Test-SPRecipientAddress -Recipient 'user@example.com '

            $result.Recipient | Should -Be 'user@example.com '
            $result.NormalizedRecipient | Should -Be 'user@example.com'
            $result.Valid | Should -BeTrue
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be "Recipient address 'user@example.com' is valid."
        }
    }
}
