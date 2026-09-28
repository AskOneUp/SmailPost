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
        # Proves the existing render workflow remains unchanged.

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
        $result.InlineImages.Count | Should -Be 0
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

    It 'Returns an empty inline image collection when no inline images are supplied' {
        # Proves the new property is present without changing the default workflow.

        $row = [pscustomobject]@{
            Email     = 'donald@example.com'
            FirstName = 'Donald'
            Company   = 'AskOneUp'
        }

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 7 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}'

        $result.Status | Should -Be 'Valid'
        $result.InlineImages.Count | Should -Be 0
    }

    It 'Returns a resolved inline image with its ContentId' {
        # Proves a valid inline image is carried into the render result.

        $row = [pscustomobject]@{
            Email     = 'donald@example.com'
            FirstName = 'Donald'
            Company   = 'AskOneUp'
        }

        $imagePath = Join-Path $TestDrive 'connected-logo.png'
        [System.IO.File]::WriteAllBytes(
            $imagePath,
            [byte[]](1, 2, 3, 4)
        )

        $inlineImage = [pscustomobject]@{
            Path      = $imagePath
            ContentId = 'connected-logo'
        }

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 8 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate '<img src="cid:connected-logo">' `
            -InlineImages @($inlineImage)

        $result.Status | Should -Be 'Valid'
        $result.Issues.Count | Should -Be 0
        $result.InlineImages.Count | Should -Be 1
        $result.InlineImages[0].Path | Should -Be $imagePath
        $result.InlineImages[0].ContentId | Should -Be 'connected-logo'
    }

    It 'Trims whitespace around inline image ContentId' {
        # Proves ContentId is normalized before entering the send workflow.

        $row = [pscustomobject]@{
            Email = 'donald@example.com'
        }

        $imagePath = Join-Path $TestDrive 'trim-logo.png'
        [System.IO.File]::WriteAllBytes(
            $imagePath,
            [byte[]](1, 2, 3)
        )

        $inlineImage = [pscustomobject]@{
            Path      = $imagePath
            ContentId = '  connected-logo  '
        }

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 9 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Test' `
            -BodyTemplate '<img src="cid:connected-logo">' `
            -InlineImages @($inlineImage)

        $result.Status | Should -Be 'Valid'
        $result.InlineImages.Count | Should -Be 1
        $result.InlineImages[0].ContentId | Should -Be 'connected-logo'
    }

    It 'Returns ordinary attachments and inline images together' {
        # Proves both resource types can coexist in one render object.

        $row = [pscustomobject]@{
            Email = 'donald@example.com'
        }

        $attachmentPath = Join-Path $TestDrive 'manual.pdf'
        $imagePath = Join-Path $TestDrive 'mixed-logo.png'

        [System.IO.File]::WriteAllBytes(
            $attachmentPath,
            [byte[]](1, 2, 3)
        )

        [System.IO.File]::WriteAllBytes(
            $imagePath,
            [byte[]](4, 5, 6)
        )

        $inlineImage = [pscustomobject]@{
            Path      = $imagePath
            ContentId = 'connected-logo'
        }

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 10 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Test' `
            -BodyTemplate '<img src="cid:connected-logo">' `
            -AttachmentPaths @($attachmentPath) `
            -InlineImages @($inlineImage)

        $result.Status | Should -Be 'Valid'
        $result.Attachments.Count | Should -Be 1
        $result.Attachments[0] | Should -Be $attachmentPath
        $result.InlineImages.Count | Should -Be 1
        $result.InlineImages[0].Path | Should -Be $imagePath
        $result.InlineImages[0].ContentId | Should -Be 'connected-logo'
    }

    It 'Returns Invalid when an inline image definition is null' {
        # Proves null inline image definitions become render validation issues.

        $row = [pscustomobject]@{
            Email = 'donald@example.com'
        }

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 11 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Test' `
            -BodyTemplate 'Test' `
            -InlineImages @($null)

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRender.InlineImage.Null'
        $result.InlineImages.Count | Should -Be 0
    }

    It 'Returns Invalid when inline image Path is whitespace' {
        # Proves every inline image requires a usable path.

        $row = [pscustomobject]@{
            Email = 'donald@example.com'
        }

        $inlineImage = [pscustomobject]@{
            Path      = '   '
            ContentId = 'connected-logo'
        }

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 12 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Test' `
            -BodyTemplate 'Test' `
            -InlineImages @($inlineImage)

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRender.InlineImage.Path.Empty'
        $result.InlineImages.Count | Should -Be 0
    }

    It 'Returns Invalid when inline image ContentId is whitespace' {
        # Proves every inline image requires a usable CID.

        $row = [pscustomobject]@{
            Email = 'donald@example.com'
        }

        $imagePath = Join-Path $TestDrive 'missing-cid.png'
        [System.IO.File]::WriteAllBytes(
            $imagePath,
            [byte[]](1, 2, 3)
        )

        $inlineImage = [pscustomobject]@{
            Path      = $imagePath
            ContentId = '   '
        }

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 13 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Test' `
            -BodyTemplate 'Test' `
            -InlineImages @($inlineImage)

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRender.InlineImage.ContentId.Empty'
        $result.InlineImages.Count | Should -Be 0
    }

    It 'Returns Invalid when an inline image path does not exist' {
        # Proves inline images use the existing attachment-path validation.

        $row = [pscustomobject]@{
            Email = 'donald@example.com'
        }

        $inlineImage = [pscustomobject]@{
            Path      = (Join-Path $TestDrive 'ghost-logo.png')
            ContentId = 'connected-logo'
        }

        $result = ConvertTo-SPMailRender `
            -Row $row `
            -RowNumber 14 `
            -RecipientColumn 'Email' `
            -SubjectTemplate 'Test' `
            -BodyTemplate 'Test' `
            -InlineImages @($inlineImage)

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'MailRender.ATTACHMENT_NOT_FOUND'
        $result.InlineImages.Count | Should -Be 0
    }
}
