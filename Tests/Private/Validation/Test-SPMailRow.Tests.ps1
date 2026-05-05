Describe 'Test-SPMailRow' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Reporting\ConvertTo-SPValidationIssue.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Reporting\Resolve-SPValidationStatus.ps1')

        . (Join-Path $script:ModuleRoot 'Private\Templates\Get-SPPlaceholder.ps1')

        . (Join-Path $script:ModuleRoot 'Private\Validation\Test-SPRecipientValue.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Validation\Test-SPMailRow.ps1')
    }

    BeforeEach {
        Mock ConvertTo-SPValidationIssue {
            param (
                $Severity,
                $Code,
                $Category,
                $Message,
                $Target,
                $RowNumber,
                $ColumnName,
                $Details
            )

            [pscustomobject]@{
                Severity   = $Severity
                Code       = $Code
                Category   = $Category
                Message    = $Message
                Target     = $Target
                RowNumber  = $RowNumber
                ColumnName = $ColumnName
                Details    = $Details
            }
        }

        Mock Resolve-SPValidationStatus {
            param ($Issues)

            if ($Issues.Where({ $_.Severity -eq 'Error' }).Count -gt 0) {
                return 'Invalid'
            }

            if ($Issues.Where({ $_.Severity -eq 'Warning' }).Count -gt 0) {
                return 'ValidWithWarnings'
            }

            return 'Valid'
        }

        Mock Get-SPPlaceholder {
            param ([string]$Text)

            if ([string]::IsNullOrWhiteSpace($Text)) {
                return [pscustomobject]@{
                    Text               = $Text
                    AllPlaceholders    = @()
                    UniquePlaceholders = @()
                    Count              = 0
                }
            }

            $placeholderMatches = [regex]::Matches($Text, '\{([^}]+)\}')
            $allPlaceholders = @()

            foreach ($placeholderMatch in $placeholderMatches) {
                $allPlaceholders += $placeholderMatch.Groups[1].Value
            }

            $uniquePlaceholders = @(
                $allPlaceholders | Select-Object -Unique
            )

            return [pscustomobject]@{
                Text               = $Text
                AllPlaceholders    = $allPlaceholders
                UniquePlaceholders = $uniquePlaceholders
                Count              = $allPlaceholders.Count
            }
        }
    }

    It 'Returns Valid when the row is complete and correct' {
        $row = [pscustomobject]@{
            Email     = 'donald@example.com'
            FirstName = 'Donald'
            Company   = 'AskOneUp'
        }

        $result = Test-SPMailRow `
            -Row $row `
            -RowNumber 1 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}'

        $result.Status | Should -Be 'Valid'
        $result.Issues.Count | Should -Be 0
    }

    It 'Returns Invalid when the recipient column is missing on the row' {
        $row = [pscustomobject]@{
            FirstName = 'Donald'
            Company   = 'AskOneUp'
        }

        $result = Test-SPMailRow `
            -Row $row `
            -RowNumber 2 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRow.RecipientColumn.NotFound'
    }

    It 'Returns Invalid when the recipient email is empty' {
        $row = [pscustomobject]@{
            Email     = '   '
            FirstName = 'Donald'
            Company   = 'AskOneUp'
        }

        $result = Test-SPMailRow `
            -Row $row `
            -RowNumber 3 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRow.RECIPIENT_EMPTY'
    }

    It 'Returns Invalid when the recipient email is not valid' {
        $row = [pscustomobject]@{
            Email     = 'not-an-email'
            FirstName = 'Donald'
            Company   = 'AskOneUp'
        }

        $result = Test-SPMailRow `
            -Row $row `
            -RowNumber 4 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRow.RECIPIENT_INVALID_EMAIL'
    }

    It 'Returns Invalid when a subject placeholder cannot be resolved' {
        $row = [pscustomobject]@{
            Email   = 'donald@example.com'
            Company = 'AskOneUp'
        }

        $result = Test-SPMailRow `
            -Row $row `
            -RowNumber 5 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRow.Subject.PlaceholderUnresolved'
    }

    It 'Returns Invalid when a body placeholder resolves to an empty value' {
        $row = [pscustomobject]@{
            Email     = 'donald@example.com'
            FirstName = 'Donald'
            Company   = ''
        }

        $result = Test-SPMailRow `
            -Row $row `
            -RowNumber 6 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRow.Body.PlaceholderValueMissing'
    }
}
