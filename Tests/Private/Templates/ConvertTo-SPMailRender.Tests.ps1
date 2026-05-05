Describe "ConvertTo-SPMailRender" {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Reporting\ConvertTo-SPValidationIssue.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Reporting\Resolve-SPValidationStatus.ps1')

        . (Join-Path $script:ModuleRoot 'Private\Templates\Resolve-SPPlaceholder.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Templates\ConvertTo-SPMailRender.ps1')

        . (Join-Path $script:ModuleRoot 'Private\Validation\Test-SPRecipientValue.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Validation\Test-SPAttachmentPath.ps1')
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
    }

    It 'Returns Valid and renders recipient subject body and attachments when input is correct' {
        $row = [pscustomobject]@{
            Email     = '  donald@example.com  '
            FirstName = 'Donald'
            Company   = 'AskOneUp'
        }

        $testDriveAttachmentPath = Join-Path -Path $TestDrive -ChildPath 'Attachment.txt'
        Set-Content -Path $testDriveAttachmentPath -Value 'hello'

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 1 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}' `
            -AttachmentPaths @($testDriveAttachmentPath)

        $result.Status | Should -Be 'Valid'
        $result.Issues.Count | Should -Be 0
        $result.Recipient | Should -Be 'donald@example.com'
        $result.Subject | Should -Be 'Hello Donald'
        $result.Body | Should -Be 'Welcome to AskOneUp'
        $result.Attachments.Count | Should -Be 1
        $result.Attachments[0] | Should -Be $testDriveAttachmentPath
    }

    It 'Returns Invalid when recipient column is missing on the row' {
        $row = [pscustomobject]@{
            FirstName = 'Donald'
            Company   = 'AskOneUp'
        }

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 2 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRender.RecipientColumn.NotFound'
    }

    It 'Returns Invalid when recipient value is not a valid email address' {
        $row = [pscustomobject]@{
            Email     = 'not-an-email'
            FirstName = 'Donald'
            Company   = 'AskOneUp'
        }

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 3 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRender.RECIPIENT_INVALID_EMAIL'
    }

    It 'Returns Invalid when a subject placeholder cannot be resolved' {
        $row = [pscustomobject]@{
            Email   = 'donald@example.com'
            Company = 'AskOneUp'
        }

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 4 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRender.Subject.PlaceholderUnresolved'
    }

    It 'Returns Invalid when a body placeholder cannot be resolved' {
        $row = [pscustomobject]@{
            Email     = 'donald@example.com'
            FirstName = 'Donald'
        }

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 5 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRender.Body.PlaceholderUnresolved'
    }

    It 'Returns Invalid when an attachment path is not valid' {
        $row = [pscustomobject]@{
            Email     = 'donald@example.com'
            FirstName = 'Donald'
            Company   = 'AskOneUp'
        }

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 6 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}' `
            -AttachmentPaths @('C:\Nope\ghost.pdf')

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRender.ATTACHMENT_NOT_FOUND'
    }
}
