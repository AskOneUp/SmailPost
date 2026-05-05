Describe "Test-SPCsvHeader" {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Csv\Test-SPCsvHeader.ps1')
    }

    It "Parses valid comma-separated header" {

        $result = Test-SPCsvHeader -HeaderLine "Email,FirstName,Company" -Delimiter ','

        $result.Count | Should -Be 3
        $result[0] | Should -Be "Email"
        $result[1] | Should -Be "FirstName"
        $result[2] | Should -Be "Company"
    }

    It "Trims whitespace around header names" {

        $result = Test-SPCsvHeader -HeaderLine " Email , FirstName , Company " -Delimiter ','

        $result[0] | Should -Be "Email"
        $result[1] | Should -Be "FirstName"
        $result[2] | Should -Be "Company"
    }

    It "Throws when header contains empty column name" {

        { Test-SPCsvHeader -HeaderLine "Email,,Company" -Delimiter ',' } | Should -Throw
    }

    It "Throws when duplicate headers exist" {

        { Test-SPCsvHeader -HeaderLine "Email,FirstName,Email" -Delimiter ',' } | Should -Throw
    }

}
