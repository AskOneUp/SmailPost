Describe "Import-SPCsv" {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Csv\Get-SPCsvDelimiter.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Csv\Test-SPCsvHeader.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Csv\Convert-SPCsvRow.ps1')
        . (Join-Path $script:ModuleRoot 'Public\Csv\Import-SPCsv.ps1')
    }

    It "Imports a valid comma-separated CSV file" {
        $file = New-TemporaryFile

        @(
            "Email,FirstName,Company"
            "john@x.com,John,Acme"
            "jane@x.com,Jane,Contoso"
        ) | Set-Content -Path $file

        $result = Import-SPCsv -Path $file

        $result.Delimiter | Should -Be ','
        $result.Headers.Count | Should -Be 3
        $result.RowCount | Should -Be 2
        $result.Rows[0].Values.Email | Should -Be 'john@x.com'
        $result.Rows[1].Values.FirstName | Should -Be 'Jane'
    }

    It "Skips empty lines in the CSV file" {
        $file = New-TemporaryFile

        @(
            "Email,FirstName,Company"
            ""
            "john@x.com,John,Acme"
            ""
            "jane@x.com,Jane,Contoso"
            ""
        ) | Set-Content -Path $file

        $result = Import-SPCsv -Path $file

        $result.RowCount | Should -Be 2
    }

    It "Throws when the CSV file does not exist" {
        { Import-SPCsv -Path "C:\DoesNotExist.csv" } | Should -Throw
    }

    It "Throws when the CSV file is empty" {
        $file = New-TemporaryFile
        Set-Content -Path $file -Value ""

        { Import-SPCsv -Path $file } | Should -Throw
    }

}

