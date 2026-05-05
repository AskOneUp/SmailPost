Describe "Test-SPPlaceholder" {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Validation\Test-SPPlaceholder.ps1')
    }

    It "Returns valid when all placeholders exist in headers" {
        $placeholders = @('FirstName', 'Company')
        $headers = @('Email', 'FirstName', 'Company')

        $result = Test-SPPlaceholder -Placeholders $placeholders -Headers $headers

        $result.IsValid | Should -BeTrue
        $result.ValidPlaceholders.Count | Should -Be 2
        $result.UnknownPlaceholders.Count | Should -Be 0
        $result.MalformedPlaceholders.Count | Should -Be 0
    }

    It "Matches placeholders case-insensitively" {
        $placeholders = @('firstname', 'company')
        $headers = @('Email', 'FirstName', 'Company')

        $result = Test-SPPlaceholder -Placeholders $placeholders -Headers $headers

        $result.IsValid | Should -BeTrue
        $result.ValidPlaceholders[0] | Should -Be 'FirstName'
        $result.ValidPlaceholders[1] | Should -Be 'Company'
    }

    It "Returns unknown placeholders when no matching header exists" {
        $placeholders = @('FirstName', 'PlanetX')
        $headers = @('Email', 'FirstName', 'Company')

        $result = Test-SPPlaceholder -Placeholders $placeholders -Headers $headers

        $result.IsValid | Should -BeFalse
        $result.ValidPlaceholders.Count | Should -Be 1
        $result.UnknownPlaceholders.Count | Should -Be 1
        $result.UnknownPlaceholders[0] | Should -Be 'PlanetX'
    }

    It "Returns malformed placeholders when outer padding exists" {
        $placeholders = @(' FirstName ', 'Company')
        $headers = @('Email', 'FirstName', 'Company')

        $result = Test-SPPlaceholder -Placeholders $placeholders -Headers $headers

        $result.IsValid | Should -BeFalse
        $result.MalformedPlaceholders.Count | Should -Be 1
        $result.MalformedPlaceholders[0] | Should -Be ' FirstName '
    }

    It "Allows placeholders with spaces when header exists" {
        $placeholders = @('First Name')
        $headers = @('Email', 'First Name', 'Company')

        $result = Test-SPPlaceholder -Placeholders $placeholders -Headers $headers

        $result.IsValid | Should -BeTrue
        $result.ValidPlaceholders.Count | Should -Be 1
        $result.ValidPlaceholders[0] | Should -Be 'First Name'
    }

    It "Returns valid when no placeholders are present" {
        $placeholders = @()
        $headers = @('Email', 'FirstName', 'Company')

        $result = Test-SPPlaceholder -Placeholders $placeholders -Headers $headers

        $result.IsValid | Should -BeTrue
        $result.ValidPlaceholders.Count | Should -Be 0
        $result.UnknownPlaceholders.Count | Should -Be 0
        $result.MalformedPlaceholders.Count | Should -Be 0
    }

}
