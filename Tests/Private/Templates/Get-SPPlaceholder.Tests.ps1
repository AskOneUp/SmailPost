Describe "Get-SPPlaceholder" {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Templates\Get-SPPlaceholder.ps1')
    }

    It "Returns no placeholders when text contains none" {
        $result = Get-SPPlaceholder -Text 'Hello world.'

        $result.Count | Should -Be 0
        $result.AllPlaceholders.Count | Should -Be 0
        $result.UniquePlaceholders.Count | Should -Be 0
    }

    It "Extracts a single placeholder" {
        $result = Get-SPPlaceholder -Text 'Hello {FirstName}.'

        $result.Count | Should -Be 1
        $result.AllPlaceholders[0] | Should -Be 'FirstName'
        $result.UniquePlaceholders[0] | Should -Be 'FirstName'
    }

    It "Extracts multiple placeholders in order" {
        $result = Get-SPPlaceholder -Text 'Hello {FirstName} from {Company}.'

        $result.Count | Should -Be 2
        $result.AllPlaceholders[0] | Should -Be 'FirstName'
        $result.AllPlaceholders[1] | Should -Be 'Company'
    }

    It "Returns unique placeholders without duplicates" {
        $result = Get-SPPlaceholder -Text 'Hello {FirstName}, yes you {FirstName}.'

        $result.Count | Should -Be 2
        $result.AllPlaceholders.Count | Should -Be 2
        $result.UniquePlaceholders.Count | Should -Be 1
        $result.UniquePlaceholders[0] | Should -Be 'FirstName'
    }

    It "Supports placeholders with spaces in the name" {
        $result = Get-SPPlaceholder -Text 'Hello {First Name}.'

        $result.Count | Should -Be 1
        $result.AllPlaceholders[0] | Should -Be 'First Name'
    }

}
