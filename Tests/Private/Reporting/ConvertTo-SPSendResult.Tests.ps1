Describe 'ConvertTo-SPSendResult' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Reporting\ConvertTo-SPSendResult.ps1')
    }
    It 'Returns a standardized result object when input is valid' {
        $attemptedOn = Get-Date

        $result = ConvertTo-SPSendResult `
            -RowNumber 1 `
            -Recipient ' user@example.com ' `
            -SenderAddress 'askoneup@askoneup.com' `
            -Subject 'Hello Donald' `
            -Success $true `
            -Status 'Sent' `
            -ErrorMessage '' `
            -AttemptedOn $attemptedOn `
            -AttachmentCount 2 `
            -BatchId 'batch-001'

        $result.RowNumber | Should -Be 1
        $result.Recipient | Should -Be 'user@example.com'
        $result.SenderAddress | Should -Be 'askoneup@askoneup.com'
        $result.Subject | Should -Be 'Hello Donald'
        $result.Success | Should -BeTrue
        $result.Status | Should -Be 'Sent'
        $result.ErrorMessage | Should -Be ''
        $result.AttemptedOn | Should -Be $attemptedOn
        $result.AttachmentCount | Should -Be 2
        $result.BatchId | Should -Be 'batch-001'
    }

    It 'Throws when RowNumber is less than 1' {
        {
            ConvertTo-SPSendResult `
                -RowNumber 0 `
                -Recipient 'user@example.com' `
                -SenderAddress 'askoneup@askoneup.com' `
                -Subject 'Hello Donald' `
                -Success $true `
                -Status 'Sent' `
                -AttemptedOn (Get-Date) `
                -BatchId 'batch-001'
        } | Should -Throw 'RowNumber must be greater than or equal to 1.'
    }

    It 'Throws when SenderAddress is empty' {
        {
            ConvertTo-SPSendResult `
                -RowNumber 1 `
                -Recipient 'user@example.com' `
                -SenderAddress '   ' `
                -Subject 'Hello Donald' `
                -Success $true `
                -Status 'Sent' `
                -AttemptedOn (Get-Date) `
                -BatchId 'batch-001'
        } | Should -Throw 'SenderAddress cannot be null, empty, or whitespace.'
    }

    It 'Throws when Subject is empty' {
        {
            ConvertTo-SPSendResult `
                -RowNumber 1 `
                -Recipient 'user@example.com' `
                -SenderAddress 'askoneup@askoneup.com' `
                -Subject '   ' `
                -Success $true `
                -Status 'Sent' `
                -AttemptedOn (Get-Date) `
                -BatchId 'batch-001'
        } | Should -Throw 'Subject cannot be null, empty, or whitespace.'
    }

    It 'Throws when Status is empty' {
        {
            ConvertTo-SPSendResult `
                -RowNumber 1 `
                -Recipient 'user@example.com' `
                -SenderAddress 'askoneup@askoneup.com' `
                -Subject 'Hello Donald' `
                -Success $true `
                -Status '   ' `
                -AttemptedOn (Get-Date) `
                -BatchId 'batch-001'
        } | Should -Throw 'Status cannot be null, empty, or whitespace.'
    }

    It 'Throws when BatchId is empty' {
        {
            ConvertTo-SPSendResult `
                -RowNumber 1 `
                -Recipient 'user@example.com' `
                -SenderAddress 'askoneup@askoneup.com' `
                -Subject 'Hello Donald' `
                -Success $true `
                -Status 'Sent' `
                -AttemptedOn (Get-Date) `
                -BatchId '   '
        } | Should -Throw 'BatchId cannot be null, empty, or whitespace.'
    }
}
