Describe 'Test-SPMailJobSetup' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Reporting\ConvertTo-SPValidationIssue.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Reporting\Resolve-SPValidationStatus.ps1')

        . (Join-Path $script:ModuleRoot 'Private\Templates\Get-SPPlaceholder.ps1')

        . (Join-Path $script:ModuleRoot 'Public\Identity\Get-SPAllowedSender.ps1')

        . (Join-Path $script:ModuleRoot 'Private\Validation\Test-SPAttachmentPath.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Validation\Test-SPRecipientAddress.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Validation\Test-SPMailJobSetup.ps1')
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

        Mock Get-SPAllowedSender {
            return @(
                [pscustomobject]@{
                    DisplayName       = 'AskOneUp'
                    Mail              = 'askoneup@askoneup.com'
                    UserPrincipalName = 'askoneup@askoneup.com'
                    Id                = 'test-id-001'
                }
            )
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

        Mock Test-SPAttachmentPath {
            return @()
        }
    }

    It 'Returns Valid when setup is complete and correct' {
        $csvImportResult = [pscustomobject]@{
            Headers = @('Email', 'FirstName', 'Company')
            Rows    = @(
                [pscustomobject]@{
                    Email     = 'donald@example.com'
                    FirstName = 'Donald'
                    Company   = 'AskOneUp'
                }
            )
        }

        $result = Test-SPMailJobSetup `
            -CsvImportResult $csvImportResult `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}' `
            -AttachmentPaths @()

        $result.Status | Should -Be 'Valid'
        $result.Issues.Count | Should -Be 0
    }

    It 'Returns Invalid when CSV import result is missing' {
        $result = Test-SPMailJobSetup `
            -CsvImportResult $null `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello' `
            -BodyTemplate 'Body'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'JobSetup.Csv.Missing'
    }

    It 'Returns Invalid when recipient column is missing from headers' {
        $csvImportResult = [pscustomobject]@{
            Headers = @('FirstName', 'Company')
            Rows    = @(
                [pscustomobject]@{
                    FirstName = 'Donald'
                    Company   = 'AskOneUp'
                }
            )
        }

        $result = Test-SPMailJobSetup `
            -CsvImportResult $csvImportResult `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'JobSetup.RecipientColumn.NotFound'
    }

    It 'Returns Invalid when sender is not allowed' {
        $csvImportResult = [pscustomobject]@{
            Headers = @('Email', 'FirstName')
            Rows    = @(
                [pscustomobject]@{
                    Email     = 'donald@example.com'
                    FirstName = 'Donald'
                }
            )
        }

        $result = Test-SPMailJobSetup `
            -CsvImportResult $csvImportResult `
            -RecipientColumn 'Email' `
            -SenderAddress 'nobody@example.com' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Body'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'JobSetup.Sender.NotAllowed'
    }

    It 'Returns Invalid when subject placeholder is missing from headers' {
        $csvImportResult = [pscustomobject]@{
            Headers = @('Email', 'Company')
            Rows    = @(
                [pscustomobject]@{
                    Email   = 'donald@example.com'
                    Company = 'AskOneUp'
                }
            )
        }

        $result = Test-SPMailJobSetup `
            -CsvImportResult $csvImportResult `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello {FirstName}' `
            -BodyTemplate 'Welcome to {Company}'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'JobSetup.Subject.PlaceholderNotFound'
    }

    It 'Returns Invalid when attachment validation returns issues' {
        Mock Test-SPAttachmentPath {
            param ([string]$Path)

            return @(
                [pscustomobject]@{
                    Severity = 'Error'
                    Code     = 'Attachment.Invalid'
                    Category = 'Attachment'
                    Message  = 'Attachment path is invalid.'
                    Target   = $Path
                }
            )
        }

        $csvImportResult = [pscustomobject]@{
            Headers = @('Email')
            Rows    = @(
                [pscustomobject]@{
                    Email = 'donald@example.com'
                }
            )
        }

        $result = Test-SPMailJobSetup `
            -CsvImportResult $csvImportResult `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello' `
            -BodyTemplate 'Body' `
            -AttachmentPaths @('C:\Nope\ghost.pdf')

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'Attachment.Invalid'
    }

    It 'Returns Valid when inline image definition is correct' {
        $csvImportResult = [pscustomobject]@{
            Headers = @('Email')
            Rows    = @(
                [pscustomobject]@{
                    Email = 'donald@example.com'
                }
            )
        }

        $inlineImage = [pscustomobject]@{
            Path      = 'C:\Temp\connected-logo.png'
            ContentId = 'connected-logo'
        }

        $result = Test-SPMailJobSetup `
            -CsvImportResult $csvImportResult `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello' `
            -BodyTemplate '<img src="cid:connected-logo">' `
            -InlineImages @($inlineImage)

        $result.Status | Should -Be 'Valid'
        $result.Issues.Count | Should -Be 0

        Should -Invoke Test-SPAttachmentPath -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'C:\Temp\connected-logo.png'
        }
    }

    It 'Returns Invalid when inline image definition is null' {
        $csvImportResult = [pscustomobject]@{
            Headers = @('Email')
            Rows    = @(
                [pscustomobject]@{
                    Email = 'donald@example.com'
                }
            )
        }

        $result = Test-SPMailJobSetup `
            -CsvImportResult $csvImportResult `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello' `
            -BodyTemplate 'Body' `
            -InlineImages @($null)

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'JobSetup.InlineImage.Null'
    }

    It 'Returns Invalid when inline image Path is whitespace' {
        $csvImportResult = [pscustomobject]@{
            Headers = @('Email')
            Rows    = @(
                [pscustomobject]@{
                    Email = 'donald@example.com'
                }
            )
        }

        $inlineImage = [pscustomobject]@{
            Path      = '   '
            ContentId = 'connected-logo'
        }

        $result = Test-SPMailJobSetup `
            -CsvImportResult $csvImportResult `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello' `
            -BodyTemplate 'Body' `
            -InlineImages @($inlineImage)

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'JobSetup.InlineImage.Path.Empty'

        Should -Invoke Test-SPAttachmentPath -Times 0
    }

    It 'Returns Invalid when inline image ContentId is whitespace' {
        $csvImportResult = [pscustomobject]@{
            Headers = @('Email')
            Rows    = @(
                [pscustomobject]@{
                    Email = 'donald@example.com'
                }
            )
        }

        $inlineImage = [pscustomobject]@{
            Path      = 'C:\Temp\connected-logo.png'
            ContentId = '   '
        }

        $result = Test-SPMailJobSetup `
            -CsvImportResult $csvImportResult `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello' `
            -BodyTemplate 'Body' `
            -InlineImages @($inlineImage)

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'JobSetup.InlineImage.ContentId.Empty'
    }

    It 'Returns Invalid when inline image ContentId is duplicated regardless of casing' {
        $csvImportResult = [pscustomobject]@{
            Headers = @('Email')
            Rows    = @(
                [pscustomobject]@{
                    Email = 'donald@example.com'
                }
            )
        }

        $inlineImages = @(
            [pscustomobject]@{
                Path      = 'C:\Temp\logo-one.png'
                ContentId = 'connected-logo'
            },
            [pscustomobject]@{
                Path      = 'C:\Temp\logo-two.png'
                ContentId = 'CONNECTED-LOGO'
            }
        )

        $result = Test-SPMailJobSetup `
            -CsvImportResult $csvImportResult `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello' `
            -BodyTemplate 'Body' `
            -InlineImages $inlineImages

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'JobSetup.InlineImage.ContentId.Duplicate'

        Should -Invoke Test-SPAttachmentPath -Times 2 -Exactly
    }
    It 'Returns Valid when BCC address is valid' {
        $csvImportResult = [pscustomobject]@{
            Headers = @('Email')
            Rows    = @(
                [pscustomobject]@{
                    Email = 'donald@example.com'
                }
            )
        }

        $result = Test-SPMailJobSetup `
            -CsvImportResult $csvImportResult `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -BccAddress 'audit@example.com' `
            -SubjectTemplate 'Hello' `
            -BodyTemplate 'Body'

        $result.Status | Should -Be 'Valid'
        $result.Issues.Count | Should -Be 0
    }

    It 'Returns Invalid when BCC address is invalid' {
        $csvImportResult = [pscustomobject]@{
            Headers = @('Email')
            Rows    = @(
                [pscustomobject]@{
                    Email = 'donald@example.com'
                }
            )
        }

        $result = Test-SPMailJobSetup `
            -CsvImportResult $csvImportResult `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -BccAddress 'not-an-email-address' `
            -SubjectTemplate 'Hello' `
            -BodyTemplate 'Body'

        $result.Status | Should -Be 'Invalid'
        $result.Issues.Code | Should -Contain 'JobSetup.Bcc.Invalid'
    }

}
