Describe 'ConvertTo-SPMailResult' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Reporting\ConvertTo-SPMailResult.ps1')
    }

    It 'Returns a standardized mail result object when input is valid' {
        $attemptedOn = [datetime]'2026-03-25 21:30:00'
        $notes = @(
            'Microsoft Graph throttled sendMail attempt 1.'
            'Microsoft Graph accepted the sendMail request.'
        )

        $result = ConvertTo-SPMailResult `
            -Recipient ' user@example.com ' `
            -RecipientIndex 1 `
            -SenderAddress ' askoneup@askoneup.com ' `
            -Subject 'Hello World' `
            -Success $true `
            -Status 'Sent' `
            -AttemptedOn $attemptedOn `
            -SaveToSentItems $true `
            -AttachmentCount 2 `
            -AttachmentTotalBytes 12345 `
            -BatchId 'batch-001' `
            -Notes $notes

        $result.Recipient | Should -Be 'user@example.com'
        $result.RecipientIndex | Should -Be 1
        $result.SenderAddress | Should -Be 'askoneup@askoneup.com'
        $result.Subject | Should -Be 'Hello World'
        $result.Success | Should -BeTrue
        $result.Status | Should -Be 'Sent'
        $result.ErrorMessage | Should -Be ''
        $result.AttemptedOn | Should -Be $attemptedOn
        $result.SaveToSentItems | Should -BeTrue
        $result.AttachmentCount | Should -Be 2
        $result.AttachmentTotalBytes | Should -Be 12345
        $result.BatchId | Should -Be 'batch-001'

        $null -eq $result.Notes | Should -BeFalse
        $result.Notes.Count | Should -Be 2
        $result.Notes[0] | Should -Be $notes[0]
        $result.Notes[1] | Should -Be $notes[1]
    }

    It 'Uses default values for optional parameters when they are not supplied' {
        $attemptedOn = [datetime]'2026-03-25 21:35:00'

        $result = ConvertTo-SPMailResult `
            -Recipient 'user@example.com' `
            -RecipientIndex 2 `
            -SenderAddress 'askoneup@askoneup.com' `
            -Subject 'Hello Again' `
            -Success $false `
            -Status 'Failed' `
            -AttemptedOn $attemptedOn `
            -SaveToSentItems $false `
            -BatchId 'batch-002'

        $result.ErrorMessage | Should -Be ''
        $result.AttachmentCount | Should -Be 0
        $result.AttachmentTotalBytes | Should -Be 0
        $null -eq $result.Notes | Should -BeFalse
        $result.Notes.Count | Should -Be 0
    }

    It 'Throws when Recipient is null, empty, or whitespace' {
        {
            ConvertTo-SPMailResult `
                -Recipient '   ' `
                -RecipientIndex 1 `
                -SenderAddress 'askoneup@askoneup.com' `
                -Subject 'Hello' `
                -Success $true `
                -Status 'Sent' `
                -AttemptedOn (Get-Date) `
                -SaveToSentItems $true `
                -BatchId 'batch-003'
        } | Should -Throw 'Recipient cannot be null, empty, or whitespace.'
    }

    It 'Throws when RecipientIndex is less than 1' {
        {
            ConvertTo-SPMailResult `
                -Recipient 'user@example.com' `
                -RecipientIndex 0 `
                -SenderAddress 'askoneup@askoneup.com' `
                -Subject 'Hello' `
                -Success $true `
                -Status 'Sent' `
                -AttemptedOn (Get-Date) `
                -SaveToSentItems $true `
                -BatchId 'batch-004'
        } | Should -Throw 'RecipientIndex must be greater than or equal to 1.'
    }

    It 'Throws when SenderAddress is null, empty, or whitespace' {
        {
            ConvertTo-SPMailResult `
                -Recipient 'user@example.com' `
                -RecipientIndex 1 `
                -SenderAddress '   ' `
                -Subject 'Hello' `
                -Success $true `
                -Status 'Sent' `
                -AttemptedOn (Get-Date) `
                -SaveToSentItems $true `
                -BatchId 'batch-005'
        } | Should -Throw 'SenderAddress cannot be null, empty, or whitespace.'
    }

    It 'Throws when Subject is null, empty, or whitespace' {
        {
            ConvertTo-SPMailResult `
                -Recipient 'user@example.com' `
                -RecipientIndex 1 `
                -SenderAddress 'askoneup@askoneup.com' `
                -Subject '   ' `
                -Success $true `
                -Status 'Sent' `
                -AttemptedOn (Get-Date) `
                -SaveToSentItems $true `
                -BatchId 'batch-006'
        } | Should -Throw 'Subject cannot be null, empty, or whitespace.'
    }

    It 'Throws when Status is null, empty, or whitespace' {
        {
            ConvertTo-SPMailResult `
                -Recipient 'user@example.com' `
                -RecipientIndex 1 `
                -SenderAddress 'askoneup@askoneup.com' `
                -Subject 'Hello' `
                -Success $true `
                -Status '   ' `
                -AttemptedOn (Get-Date) `
                -SaveToSentItems $true `
                -BatchId 'batch-007'
        } | Should -Throw 'Status cannot be null, empty, or whitespace.'
    }

    It 'Throws when BatchId is null, empty, or whitespace' {
        {
            ConvertTo-SPMailResult `
                -Recipient 'user@example.com' `
                -RecipientIndex 1 `
                -SenderAddress 'askoneup@askoneup.com' `
                -Subject 'Hello' `
                -Success $true `
                -Status 'Sent' `
                -AttemptedOn (Get-Date) `
                -SaveToSentItems $true `
                -BatchId '   '
        } | Should -Throw 'BatchId cannot be null, empty, or whitespace.'
    }
}
