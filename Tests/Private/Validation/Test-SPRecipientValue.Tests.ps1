Describe "Test-SPRecipientValue" {

    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Validation\Test-SPRecipientValue.ps1')
    }

    It "Returns valid for a correct email address" {
        $result = Test-SPRecipientValue -Value 'donald@askoneup.com'

        $result.IsValid | Should -BeTrue
        $result.NormalizedValue | Should -Be 'donald@askoneup.com'
        $result.ErrorCode | Should -Be ''
    }

    It "Trims whitespace before validation" {
        $result = Test-SPRecipientValue -Value '  donald@askoneup.com  '

        $result.IsValid | Should -BeTrue
        $result.NormalizedValue | Should -Be 'donald@askoneup.com'
    }

    It "Returns invalid when value is empty" {
        $result = Test-SPRecipientValue -Value ''

        $result.IsValid | Should -BeFalse
        $result.ErrorCode | Should -Be 'RECIPIENT_EMPTY'
    }

    It "Returns invalid when value is whitespace only" {
        $result = Test-SPRecipientValue -Value '   '

        $result.IsValid | Should -BeFalse
        $result.ErrorCode | Should -Be 'RECIPIENT_EMPTY'
    }

    It "Returns invalid when value is null" {
        $result = Test-SPRecipientValue -Value $null

        $result.IsValid | Should -BeFalse
        $result.ErrorCode | Should -Be 'RECIPIENT_EMPTY'
    }

    It "Returns invalid for malformed email address" {
        $result = Test-SPRecipientValue -Value 'not-an-email'

        $result.IsValid | Should -BeFalse
        $result.ErrorCode | Should -Be 'RECIPIENT_INVALID_EMAIL'
    }

}
