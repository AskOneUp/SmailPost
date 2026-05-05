Describe "ConvertTo-SPValidationIssue" {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Reporting\ConvertTo-SPValidationIssue.ps1')
    }

    It "Creates an error issue with required fields" {
        $result = ConvertTo-SPValidationIssue `
            -Severity 'Error' `
            -Code 'RECIPIENT_INVALID_EMAIL' `
            -Category 'Recipient' `
            -Message 'Recipient value is not a valid email address.'

        $result.Severity | Should -Be 'Error'
        $result.Code | Should -Be 'RECIPIENT_INVALID_EMAIL'
        $result.Category | Should -Be 'Recipient'
        $result.Message | Should -Be 'Recipient value is not a valid email address.'
        $result.Target | Should -Be ''
        $result.RowNumber | Should -BeNullOrEmpty
        $result.ColumnName | Should -Be ''
        $result.Details | Should -Be ''
    }

    It "Creates a warning issue with optional fields" {
        $result = ConvertTo-SPValidationIssue `
            -Severity 'Warning' `
            -Code 'RECIPIENT_DUPLICATE' `
            -Category 'Recipient' `
            -Message 'Recipient appears more than once.' `
            -Target 'donald@askoneup.com' `
            -RowNumber 12 `
            -ColumnName 'Email' `
            -Details 'Duplicate found in another row.'

        $result.Severity | Should -Be 'Warning'
        $result.Code | Should -Be 'RECIPIENT_DUPLICATE'
        $result.Category | Should -Be 'Recipient'
        $result.Message | Should -Be 'Recipient appears more than once.'
        $result.Target | Should -Be 'donald@askoneup.com'
        $result.RowNumber | Should -Be 12
        $result.ColumnName | Should -Be 'Email'
        $result.Details | Should -Be 'Duplicate found in another row.'
    }

    It "Rejects unsupported severity values" {
        {
            ConvertTo-SPValidationIssue `
                -Severity 'Info' `
                -Code 'TEST_CODE' `
                -Category 'Job' `
                -Message 'Test message.'
        } | Should -Throw
    }

}
