Describe "Get-SPCsvDelimiter" {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Csv\Get-SPCsvDelimiter.ps1')
    }

    It "Detects comma delimiter" {

        $file = New-TemporaryFile
        Set-Content $file "Email,FirstName,Company"

        $result = Get-SPCsvDelimiter -Path $file

        $result | Should -Be ","
    }

    It "Detects semicolon delimiter" {

        $file = New-TemporaryFile
        Set-Content $file "Email;FirstName;Company"

        $result = Get-SPCsvDelimiter -Path $file

        $result | Should -Be ";"
    }

    It "Detects tab delimiter" {

        $file = New-TemporaryFile
        Set-Content $file "Email`tFirstName`tCompany"

        $result = Get-SPCsvDelimiter -Path $file

        $result | Should -Be "`t"
    }

    It "Throws if file is empty" {

        $file = New-TemporaryFile
        Set-Content $file ""

        { Get-SPCsvDelimiter -Path $file } | Should -Throw
    }

    It "Throws if file does not exist" {

        { Get-SPCsvDelimiter -Path "C:\DoesNotExist.csv" } | Should -Throw
    }

}
