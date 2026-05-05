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
                    $SenderAddress,
                    $CsvData,
                    $Template,
                    $Attachments
                )

                $null = $SenderAddress
                $null = $CsvData
                $null = $Template
                $null = $Attachments
            }
        }

        if (-not (Get-Command Test-SPMailRow -ErrorAction SilentlyContinue)) {
            function Test-SPMailRow {
                param (
                    $Row,
                    $Headers,
                    $Template,
                    $Attachments
                )

                $null = $Row
                $null = $Headers
                $null = $Template
                $null = $Attachments
            }
        }

        if (-not (Get-Command ConvertTo-SPMailRender -ErrorAction SilentlyContinue)) {
            function ConvertTo-SPMailRender {
                param (
                    $Row,
                    $Template,
                    $Attachments
                )

                $null = $Row
                $null = $Template
                $null = $Attachments
            }
        }

        if (-not (Get-Command Send-SPMailBatch -ErrorAction SilentlyContinue)) {
            function Send-SPMailBatch {
                param (
                    $SenderAddress,
                    $RenderItems
                )

                $null = $SenderAddress
                $null = $RenderItems
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
                RowNumber   = $RowNumber
                Recipient   = $Row.Email
                Subject     = 'Hello'
                Body        = '<p>Hello</p>'
                Attachments = @()
                Issues      = @()
                Status      = 'Valid'
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
                RowNumber   = $RowNumber
                Recipient   = $Row.Email
                Subject     = 'Hello'
                Body        = '<p>Hello</p>'
                Attachments = @()
                Issues      = @(
                    [pscustomobject]@{ Code = 'Render.Invalid' }
                )
                Status      = 'Invalid'
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
}
