Describe 'Send-SPMailBatch' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        if (-not (Get-Command Send-SPMail -ErrorAction SilentlyContinue)) {
            function Send-SPMail {
                param (
                    $SenderAddress,
                    $RecipientAddress,
                    $Subject,
                    $Body,
                    $Attachments
                )
                $null = $SenderAddress
                $null = $RecipientAddress
                $null = $Subject
                $null = $Body
                $null = $Attachments
            }
        }

        . (Join-Path $script:ModuleRoot 'Private\Reporting\ConvertTo-SPSendResult.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Reporting\Resolve-SPBatchStatus.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Mail\Send-SPMailBatch.ps1')
    }
    BeforeEach {
        Mock ConvertTo-SPSendResult {
            param (
                $RowNumber,
                $Recipient,
                $SenderAddress,
                $Subject,
                $Success,
                $Status,
                $ErrorMessage,
                $AttemptedOn,
                $AttachmentCount,
                $BatchId
            )

            [pscustomobject]@{
                RowNumber       = $RowNumber
                Recipient       = $Recipient
                SenderAddress   = $SenderAddress
                Subject         = $Subject
                Success         = $Success
                Status          = $Status
                ErrorMessage    = $ErrorMessage
                AttemptedOn     = $AttemptedOn
                AttachmentCount = $AttachmentCount
                BatchId         = $BatchId
            }
        }

        Mock Resolve-SPBatchStatus {
            param ($Results)

            $successfulResults = @($Results | Where-Object { $_.Success -eq $true })
            $failedResults = @($Results | Where-Object { $_.Success -eq $false })

            if ($Results.Count -eq 0) {
                return 'Empty'
            }

            if ($successfulResults.Count -eq $Results.Count) {
                return 'Sent'
            }

            if ($failedResults.Count -eq $Results.Count) {
                return 'Failed'
            }

            return 'Partial'
        }

        Mock Send-SPMail {
            param (
                $To
            )

            return @(
                [pscustomobject]@{
                    Recipient    = $To[0]
                    Success      = $true
                    Status       = 'Sent'
                    ErrorMessage = ''
                    AttemptedOn  = Get-Date
                }
            )
        }
    }

    It 'Returns Sent when all render items are sent successfully' {
        $renderItems = @(
            [pscustomobject]@{
                RowNumber   = 1
                Recipient   = 'user1@example.com'
                Subject     = 'Hello One'
                Body        = '<p>Body 1</p>'
                Attachments = @()
                Status      = 'Valid'
            },
            [pscustomobject]@{
                RowNumber   = 2
                Recipient   = 'user2@example.com'
                Subject     = 'Hello Two'
                Body        = '<p>Body 2</p>'
                Attachments = @('C:\Temp\File.txt')
                Status      = 'Valid'
            }
        )

        $result = Send-SPMailBatch `
            -RenderItems $renderItems `
            -SenderAddress 'askoneup@askoneup.com' `
            -SaveToSentItems $true

        $result.Status | Should -Be 'Sent'
        $result.TotalCount | Should -Be 2
        $result.SentCount | Should -Be 2
        $result.FailedCount | Should -Be 0
        $result.Results.Count | Should -Be 2
    }

    It 'Returns Failed for render items that are not valid' {
        $renderItems = @(
            [pscustomobject]@{
                RowNumber   = 3
                Recipient   = 'broken@example.com'
                Subject     = 'Broken'
                Body        = '<p>Broken</p>'
                Attachments = @()
                Status      = 'Invalid'
            }
        )

        $result = Send-SPMailBatch `
            -RenderItems $renderItems `
            -SenderAddress 'askoneup@askoneup.com'

        $result.Status | Should -Be 'Failed'
        $result.TotalCount | Should -Be 1
        $result.SentCount | Should -Be 0
        $result.FailedCount | Should -Be 1
        $result.Results[0].ErrorMessage | Should -Be 'Render item is not valid for sending.'
    }

    It 'Returns Failed when Send-SPMail returns no result' {
        Mock Send-SPMail {
            return @()
        }

        $renderItems = @(
            [pscustomobject]@{
                RowNumber   = 4
                Recipient   = 'user@example.com'
                Subject     = 'Hello'
                Body        = '<p>Body</p>'
                Attachments = @()
                Status      = 'Valid'
            }
        )

        $result = Send-SPMailBatch `
            -RenderItems $renderItems `
            -SenderAddress 'askoneup@askoneup.com'

        $result.Status | Should -Be 'Failed'
        $result.TotalCount | Should -Be 1
        $result.SentCount | Should -Be 0
        $result.FailedCount | Should -Be 1
        $result.Results[0].ErrorMessage | Should -Be 'Send-SPMail returned no result.'
    }

    It 'Returns Partial when some items succeed and some fail' {
        Mock Send-SPMail {
            param (
                $To
            )

            if ($To[0] -eq 'user1@example.com') {
                return @(
                    [pscustomobject]@{
                        Recipient    = 'user1@example.com'
                        Success      = $true
                        Status       = 'Sent'
                        ErrorMessage = ''
                        AttemptedOn  = Get-Date
                    }
                )
            }

            return @(
                [pscustomobject]@{
                    Recipient    = 'user2@example.com'
                    Success      = $false
                    Status       = 'Failed'
                    ErrorMessage = 'Transport failed.'
                    AttemptedOn  = Get-Date
                }
            )
        }

        $renderItems = @(
            [pscustomobject]@{
                RowNumber   = 1
                Recipient   = 'user1@example.com'
                Subject     = 'Hello One'
                Body        = '<p>Body 1</p>'
                Attachments = @()
                Status      = 'Valid'
            },
            [pscustomobject]@{
                RowNumber   = 2
                Recipient   = 'user2@example.com'
                Subject     = 'Hello Two'
                Body        = '<p>Body 2</p>'
                Attachments = @()
                Status      = 'Valid'
            }
        )

        $result = Send-SPMailBatch `
            -RenderItems $renderItems `
            -SenderAddress 'askoneup@askoneup.com'

        $result.Status | Should -Be 'Partial'
        $result.TotalCount | Should -Be 2
        $result.SentCount | Should -Be 1
        $result.FailedCount | Should -Be 1
    }

    It 'Throws when SenderAddress is empty' {
        {
            Send-SPMailBatch `
                -RenderItems @() `
                -SenderAddress '   '
        } | Should -Throw 'SenderAddress cannot be null, empty, or whitespace.'
    }
}
