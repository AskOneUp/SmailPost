Describe 'Invoke-SPMailJob' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        if (-not (Get-Command Import-SPCsv -ErrorAction SilentlyContinue)) {
            function Import-SPCsv {
                param (
                    $Path
                )

                $null = $Path
            }
        }

        if (-not (Get-Command Test-SPMailJobSetup -ErrorAction SilentlyContinue)) {
            function Test-SPMailJobSetup {
                param (
                    $CsvImportResult,
                    $RecipientColumn,
                    $SenderAddress,
                    $SubjectTemplate,
                    $BodyTemplate,
                    $AttachmentPaths,
                    $InlineImages
                )

                $null = $CsvImportResult
                $null = $RecipientColumn
                $null = $SenderAddress
                $null = $SubjectTemplate
                $null = $BodyTemplate
                $null = $AttachmentPaths
                $null = $InlineImages
            }
        }

        if (-not (Get-Command Test-SPMailRow -ErrorAction SilentlyContinue)) {
            function Test-SPMailRow {
                param (
                    $Row,
                    $RowNumber,
                    $RecipientColumn,
                    $SubjectTemplate,
                    $BodyTemplate
                )

                $null = $Row
                $null = $RowNumber
                $null = $RecipientColumn
                $null = $SubjectTemplate
                $null = $BodyTemplate
            }
        }

        if (-not (Get-Command ConvertTo-SPMailRender -ErrorAction SilentlyContinue)) {
            function ConvertTo-SPMailRender {
                param (
                    $Row,
                    $RowNumber,
                    $RecipientColumn,
                    $SubjectTemplate,
                    $BodyTemplate,
                    $AttachmentPaths,
                    $InlineImages
                )

                $null = $Row
                $null = $RowNumber
                $null = $RecipientColumn
                $null = $SubjectTemplate
                $null = $BodyTemplate
                $null = $AttachmentPaths
                $null = $InlineImages
            }
        }

        if (-not (Get-Command Send-SPMailBatch -ErrorAction SilentlyContinue)) {
            function Send-SPMailBatch {
                param (
                    $RenderItems,
                    $SenderAddress,
                    $SaveToSentItems
                )

                $null = $RenderItems
                $null = $SenderAddress
                $null = $SaveToSentItems
            }
        }

        if (-not (Get-Command ConvertTo-SPMailJobReport -ErrorAction SilentlyContinue)) {
            function ConvertTo-SPMailJobReport {
                param (
                    $JobSetupResult,
                    $RowValidationResults,
                    $RenderResults,
                    $BatchSendResult
                )

                $null = $JobSetupResult
                $null = $RowValidationResults
                $null = $RenderResults
                $null = $BatchSendResult
            }
        }

        . (Join-Path $script:ModuleRoot 'Public\Mail\Invoke-SPMailJob.ps1')
    }

    BeforeEach {
        Mock Import-SPCsv {
            [pscustomobject]@{
                Path      = 'C:\Temp\input.csv'
                Delimiter = ','
                Headers   = @('Email', 'FirstName', 'Company')
                Rows      = @(
                    [pscustomobject]@{
                        Email     = 'user1@example.com'
                        FirstName = 'Donald'
                        Company   = 'AskOneUp'
                    },
                    [pscustomobject]@{
                        Email     = 'user2@example.com'
                        FirstName = 'Vince'
                        Company   = 'AskOneUp'
                    }
                )
                RowCount  = 2
            }
        }

        Mock Test-SPMailJobSetup {
            [pscustomobject]@{
                Issues = @()
                Status = 'Valid'
            }
        }

        Mock Test-SPMailRow {
            [pscustomobject]@{
                Issues = @()
                Status = 'Valid'
            }
        }

        Mock ConvertTo-SPMailRender {
            [pscustomobject]@{
                RowNumber    = $RowNumber
                Recipient    = $Row.Email
                Subject      = 'Hello'
                Body         = '<p>Hello</p>'
                Attachments  = @($AttachmentPaths)
                InlineImages = @($InlineImages)
                Issues       = @()
                Status       = 'Valid'
            }
        }

        Mock Send-SPMailBatch {
            [pscustomobject]@{
                BatchId     = 'batch-001'
                Status      = 'Sent'
                TotalCount  = 2
                SentCount   = 2
                FailedCount = 0
                Results     = @()
            }
        }

        Mock ConvertTo-SPMailJobReport {
            [pscustomobject]@{
                JobSetupStatus       = $JobSetupResult.Status
                RowValidationStatus  = 'Valid'
                RenderStatus         = 'Valid'
                BatchStatus          = if ($null -ne $BatchSendResult) { $BatchSendResult.Status } else { 'Empty' }
                OverallStatus        = if ($null -ne $BatchSendResult) { $BatchSendResult.Status } else { $JobSetupResult.Status }
                JobSetupResult       = $JobSetupResult
                RowValidationResults = $RowValidationResults
                RenderResults        = $RenderResults
                BatchSendResult      = $BatchSendResult
            }
        }
    }

    It 'Returns a final report when the full job succeeds' {
        $result = Invoke-SPMailJob `
            -CsvPath 'C:\Temp\input.csv' `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello {FirstName}' `
            -HtmlBodyTemplate '<p>Hello {FirstName}</p>' `
            -AttachmentPaths @() `
            -SaveToSentItems $true

        $result.JobSetupStatus | Should -Be 'Valid'
        $result.BatchStatus | Should -Be 'Sent'
        $result.OverallStatus | Should -Be 'Sent'

        Should -Invoke Import-SPCsv -Times 1 -Exactly
        Should -Invoke Test-SPMailJobSetup -Times 1 -Exactly
        Should -Invoke Test-SPMailRow -Times 2 -Exactly
        Should -Invoke ConvertTo-SPMailRender -Times 2 -Exactly
        Should -Invoke Send-SPMailBatch -Times 1 -Exactly
        Should -Invoke ConvertTo-SPMailJobReport -Times 1 -Exactly
    }

    It 'Skips row processing and batch sending when job setup is invalid' {
        Mock Test-SPMailJobSetup {
            [pscustomobject]@{
                Issues = @(
                    [pscustomobject]@{ Code = 'JobSetup.Invalid' }
                )
                Status = 'Invalid'
            }
        }

        $result = Invoke-SPMailJob `
            -CsvPath 'C:\Temp\input.csv' `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello {FirstName}' `
            -HtmlBodyTemplate '<p>Hello {FirstName}</p>'

        $result.JobSetupStatus | Should -Be 'Invalid'
        $result.BatchStatus | Should -Be 'Empty'
        $result.OverallStatus | Should -Be 'Invalid'

        Should -Invoke Import-SPCsv -Times 1 -Exactly
        Should -Invoke Test-SPMailJobSetup -Times 1 -Exactly
        Should -Invoke Test-SPMailRow -Times 0 -Exactly
        Should -Invoke ConvertTo-SPMailRender -Times 0 -Exactly
        Should -Invoke Send-SPMailBatch -Times 0 -Exactly
        Should -Invoke ConvertTo-SPMailJobReport -Times 1 -Exactly
    }

    It 'Skips rendering and sending for invalid rows' {
        Mock Test-SPMailRow {
            if ($RowNumber -eq 1) {
                return [pscustomobject]@{
                    Issues = @()
                    Status = 'Valid'
                }
            }

            return [pscustomobject]@{
                Issues = @(
                    [pscustomobject]@{ Code = 'Row.Invalid' }
                )
                Status = 'Invalid'
            }
        }

        Mock Send-SPMailBatch {
            [pscustomobject]@{
                BatchId     = 'batch-002'
                Status      = 'Sent'
                TotalCount  = 1
                SentCount   = 1
                FailedCount = 0
                Results     = @()
            }
        }

        $result = Invoke-SPMailJob `
            -CsvPath 'C:\Temp\input.csv' `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello {FirstName}' `
            -HtmlBodyTemplate '<p>Hello {FirstName}</p>'

        $result.BatchStatus | Should -Be 'Sent'

        Should -Invoke Test-SPMailRow -Times 2 -Exactly
        Should -Invoke ConvertTo-SPMailRender -Times 1 -Exactly
        Should -Invoke Send-SPMailBatch -Times 1 -Exactly
    }

    It 'Skips batch sending when no valid render items exist' {
        Mock Test-SPMailRow {
            [pscustomobject]@{
                Issues = @()
                Status = 'Valid'
            }
        }

        Mock ConvertTo-SPMailRender {
            [pscustomobject]@{
                RowNumber    = $RowNumber
                Recipient    = $Row.Email
                Subject      = 'Hello'
                Body         = '<p>Hello</p>'
                Attachments  = @()
                InlineImages = @()
                Issues       = @(
                    [pscustomobject]@{ Code = 'Render.Invalid' }
                )
                Status       = 'Invalid'
            }
        }

        $result = Invoke-SPMailJob `
            -CsvPath 'C:\Temp\input.csv' `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello {FirstName}' `
            -HtmlBodyTemplate '<p>Hello {FirstName}</p>'

        $result.BatchStatus | Should -Be 'Empty'

        Should -Invoke Test-SPMailRow -Times 2 -Exactly
        Should -Invoke ConvertTo-SPMailRender -Times 2 -Exactly
        Should -Invoke Send-SPMailBatch -Times 0 -Exactly
    }

    It 'Passes inline images to job setup validation' {
        $inlineImages = @(
            [pscustomobject]@{
                Path      = 'C:\Temp\connected-logo.png'
                ContentId = 'connected-logo'
            }
        )

        $null = Invoke-SPMailJob `
            -CsvPath 'C:\Temp\input.csv' `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello {FirstName}' `
            -HtmlBodyTemplate '<img src="cid:connected-logo">' `
            -InlineImages $inlineImages

        Should -Invoke Test-SPMailJobSetup -Times 1 -Exactly -ParameterFilter {
            $InlineImages.Count -eq 1 -and
            $InlineImages[0].Path -eq 'C:\Temp\connected-logo.png' -and
            $InlineImages[0].ContentId -eq 'connected-logo'
        }
    }

    It 'Passes inline images to every valid mail render' {
        $inlineImages = @(
            [pscustomobject]@{
                Path      = 'C:\Temp\connected-logo.png'
                ContentId = 'connected-logo'
            }
        )

        $null = Invoke-SPMailJob `
            -CsvPath 'C:\Temp\input.csv' `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello {FirstName}' `
            -HtmlBodyTemplate '<img src="cid:connected-logo">' `
            -InlineImages $inlineImages

        Should -Invoke ConvertTo-SPMailRender -Times 2 -Exactly -ParameterFilter {
            $InlineImages.Count -eq 1 -and
            $InlineImages[0].Path -eq 'C:\Temp\connected-logo.png' -and
            $InlineImages[0].ContentId -eq 'connected-logo'
        }
    }

    It 'Uses an empty inline image collection when no inline images are supplied' {
        $null = Invoke-SPMailJob `
            -CsvPath 'C:\Temp\input.csv' `
            -RecipientColumn 'Email' `
            -SenderAddress 'askoneup@askoneup.com' `
            -SubjectTemplate 'Hello {FirstName}' `
            -HtmlBodyTemplate '<p>Hello {FirstName}</p>'

        Should -Invoke Test-SPMailJobSetup -Times 1 -Exactly -ParameterFilter {
            @($InlineImages).Count -eq 0
        }

        Should -Invoke ConvertTo-SPMailRender -Times 2 -Exactly -ParameterFilter {
            @($InlineImages).Count -eq 0
        }
    }
}
