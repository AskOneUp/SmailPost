Describe "Resolve-SPValidationStatus" {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Reporting\Resolve-SPValidationStatus.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Reporting\ConvertTo-SPValidationIssue.ps1')
    }

    It "Returns Valid when no issues exist" {
        $result = Resolve-SPValidationStatus -Issues @()

        $result | Should -Be 'Valid'
    }

    It "Returns ValidWithWarnings when warnings exist but no errors" {

        $issues = @(
            (ConvertTo-SPValidationIssue -Severity Warning -Code 'TEST' -Category 'Job' -Message 'Warning')
        )

        $result = Resolve-SPValidationStatus -Issues $issues

        $result | Should -Be 'ValidWithWarnings'
    }

    It "Returns Invalid when any error exists" {

        $issues = @(
            (ConvertTo-SPValidationIssue -Severity Warning -Code 'TEST' -Category 'Job' -Message 'Warning')
            (ConvertTo-SPValidationIssue -Severity Error -Code 'TEST' -Category 'Job' -Message 'Error')
        )

        $result = Resolve-SPValidationStatus -Issues $issues

        $result | Should -Be 'Invalid'
    }

}
