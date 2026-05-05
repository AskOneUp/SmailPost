Describe 'Send-SPMail' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        if (-not (Get-Command Test-SPMailReady -ErrorAction SilentlyContinue)) {
            function Test-SPMailReady {
                [pscustomobject]@{}
            }
        }

        if (-not (Get-Command Test-SPSenderAllowed -ErrorAction SilentlyContinue)) {
            function Test-SPSenderAllowed {
                param (
                    $SenderAddress
                )

                $null = $SenderAddress
                [pscustomobject]@{}
            }
        }

        if (-not (Get-Command Test-SPAttachmentSet -ErrorAction SilentlyContinue)) {
            function Test-SPAttachmentSet {
                param (
                    $AttachmentPath
                )

                $null = $AttachmentPath
                [pscustomobject]@{}
            }
        }

        if (-not (Get-Command ConvertTo-SPGraphAttachmentSet -ErrorAction SilentlyContinue)) {
            function ConvertTo-SPGraphAttachmentSet {
                param (
                    $AttachmentPath
                )

                $null = $AttachmentPath
                [pscustomobject]@{}
            }
        }

        if (-not (Get-Command Test-SPRecipientAddress -ErrorAction SilentlyContinue)) {
            function Test-SPRecipientAddress {
                param (
                    $Recipient
                )

                $null = $Recipient
                [pscustomobject]@{}
            }
        }

        if (-not (Get-Command ConvertTo-SPGraphMailPayload -ErrorAction SilentlyContinue)) {
            function ConvertTo-SPGraphMailPayload {
                param (
                    $Recipient,
                    $Subject,
                    $HtmlBody,
                    $Attachments,
                    $SaveToSentItems
                )

                $null = $Recipient
                $null = $Subject
                $null = $HtmlBody
                $null = $Attachments
                $null = $SaveToSentItems

                @{}
            }
        }

        if (-not (Get-Command Send-SPGraphMailRequest -ErrorAction SilentlyContinue)) {
            function Send-SPGraphMailRequest {
                param (
                    $SenderAddress,
                    $Payload
                )

                $null = $SenderAddress
                $null = $Payload
                [pscustomobject]@{}
            }
        }

        if (-not (Get-Command ConvertTo-SPMailResult -ErrorAction SilentlyContinue)) {
            function ConvertTo-SPMailResult {
                param (
                    $Recipient,
                    $RecipientIndex,
                    $SenderAddress,
                    $Subject,
                    $Success,
                    $Status,
                    $ErrorMessage,
                    $AttemptedOn,
                    $SaveToSentItems,
                    $AttachmentCount,
                    $AttachmentTotalBytes,
                    $BatchId
                )

                $null = $Recipient
                $null = $RecipientIndex
                $null = $SenderAddress
                $null = $Subject
                $null = $Success
                $null = $Status
                $null = $ErrorMessage
                $null = $AttemptedOn
                $null = $SaveToSentItems
                $null = $AttachmentCount
                $null = $AttachmentTotalBytes
                $null = $BatchId

                [pscustomobject]@{}
            }
        }

        . (Join-Path $script:ModuleRoot 'Public\Mail\Send-SPMail.ps1')
    }

    BeforeEach {
        Mock Test-SPMailReady {
            [pscustomobject]@{
                Ready               = $true
                SecretReady         = $true
                GraphReady          = $true
                AllowedSendersReady = $true
                AllowedSenderCount  = 2
                Notes               = @('Ready.')
            }
        }

        Mock Test-SPSenderAllowed {
            param (
                $SenderAddress
            )

            [pscustomobject]@{
                SenderAddress = $SenderAddress
                Allowed       = $true
                MatchedSender = [pscustomobject]@{
                    DisplayName       = 'AskOneUp'
                    Mail              = 'AskOneUp@AskOneUp.com'
                    UserPrincipalName = 'AskOneUp@askoneup.com'
                    Id                = 'c9c569d8-24b0-4945-b89a-ad557d746dd8'
                }
                Notes         = @("Sender '$SenderAddress' is allowed.")
            }
        }

        Mock Test-SPAttachmentSet {
            [pscustomobject]@{
                Valid                = $true
                AttachmentCount      = 0
                AttachmentTotalBytes = 0L
                MaxTotalBytes        = 8MB
                ValidPaths           = @()
                InvalidPaths         = @()
                Notes                = @('No attachments supplied.')
            }
        }

        Mock ConvertTo-SPGraphAttachmentSet {
            [pscustomobject]@{
                Attachments          = @()
                AttachmentCount      = 0
                AttachmentTotalBytes = 0L
                Notes                = @('No attachments supplied.')
            }
        }

        Mock Test-SPRecipientAddress {
            param (
                $Recipient
            )

            [pscustomobject]@{
                Recipient           = $Recipient
                NormalizedRecipient = $Recipient
                Valid               = $true
                Notes               = @("Recipient address '$Recipient' is valid.")
            }
        }

        Mock ConvertTo-SPGraphMailPayload {
            param(
                $Recipient,
                $Subject,
                $HtmlBody,
                $Attachments,
                $SaveToSentItems
            )

            $null = $Attachments

            @{
                message         = @{
                    subject      = $Subject
                    body         = @{
                        contentType = 'HTML'
                        content     = $HtmlBody
                    }
                    toRecipients = @(
                        @{
                            emailAddress = @{
                                address = $Recipient
                            }
                        }
                    )
                }
                saveToSentItems = $SaveToSentItems
            }
        }

        Mock Send-SPGraphMailRequest {
            param(
                $SenderAddress,
                $Payload
            )

            $null = $SenderAddress
            $null = $Payload

            [pscustomobject]@{
                Success      = $true
                StatusCode   = 202
                ErrorMessage = ''
                RequestUri   = 'https://graph.microsoft.com/v1.0/users/askoneup@askoneup.com/sendMail'
                Notes        = @('Accepted.')
            }
        }

        Mock ConvertTo-SPMailResult {
            param(
                $Recipient,
                $RecipientIndex,
                $SenderAddress,
                $Subject,
                $Success,
                $Status,
                $ErrorMessage,
                $AttemptedOn,
                $SaveToSentItems,
                $AttachmentCount,
                $AttachmentTotalBytes,
                $BatchId
            )

            [pscustomobject]@{
                Recipient            = $Recipient
                RecipientIndex       = $RecipientIndex
                SenderAddress        = $SenderAddress
                Subject              = $Subject
                Success              = $Success
                Status               = $Status
                ErrorMessage         = $ErrorMessage
                AttemptedOn          = $AttemptedOn
                SaveToSentItems      = $SaveToSentItems
                AttachmentCount      = $AttachmentCount
                AttachmentTotalBytes = $AttachmentTotalBytes
                BatchId              = $BatchId
            }
        }
    }

    It 'Throws when SmailPost is not ready' {
        Mock Test-SPMailReady {
            [pscustomobject]@{
                Ready               = $false
                SecretReady         = $false
                GraphReady          = $false
                AllowedSendersReady = $false
                AllowedSenderCount  = 0
                Notes               = @('SmailPost is not ready.')
            }
        }

        {
            Send-SPMail `
                -SenderAddress 'AskOneUp@outlook.com' `
                -To @('user@example.com') `
                -Subject 'Test subject' `
                -HtmlBody '<p>Hello</p>' `
                -Confirm:$false
        } | Should -Throw '*SmailPost is not ready.*'
    }

    It 'Returns a failed result row for an invalid recipient' {
        Mock Test-SPRecipientAddress {
            param (
                $Recipient
            )

            [pscustomobject]@{
                Recipient           = $Recipient
                NormalizedRecipient = ''
                Valid               = $false
                Notes               = @("Recipient address '$Recipient' is invalid.")
            }
        }

        $results = Send-SPMail `
            -SenderAddress 'AskOneUp@outlook.com' `
            -To @('broken@@mail') `
            -Subject 'Test subject' `
            -HtmlBody '<p>Hello</p>' `
            -Confirm:$false

        $results | Should -HaveCount 1
        $results[0].Recipient | Should -Be 'broken@@mail'
        $results[0].Success | Should -BeFalse
        $results[0].Status | Should -Be 'Failed'
        $results[0].ErrorMessage | Should -Match 'invalid'
    }

    It 'Returns a sent result row for a valid recipient' {
        $results = Send-SPMail `
            -SenderAddress 'AskOneUp@outlook.com' `
            -To @('user@example.com') `
            -Subject 'Test subject' `
            -HtmlBody '<p>Hello</p>' `
            -SaveToSentItems $true `
            -Confirm:$false

        $results | Should -HaveCount 1
        $results[0].Recipient | Should -Be 'user@example.com'
        $results[0].Success | Should -BeTrue
        $results[0].Status | Should -Be 'Sent'
        $results[0].ErrorMessage | Should -Be ''
    }

    It 'Throws when attachment validation fails' {
        Mock Test-SPAttachmentSet {
            [pscustomobject]@{
                Valid                = $false
                AttachmentCount      = 0
                AttachmentTotalBytes = 0L
                MaxTotalBytes        = 8MB
                ValidPaths           = @()
                InvalidPaths         = @('C:\Bad\Missing.pdf')
                Notes                = @('Attachment validation failed.')
            }
        }

        {
            Send-SPMail `
                -SenderAddress 'AskOneUp@askoneup.com' `
                -To @('AskOneUp@outlook.com') `
                -Subject 'SmailPost test' `
                -HtmlBody '<h1>Hello</h1>' `
                -AttachmentPath 'C:\Temp\Test.txt' `
                -Confirm:$false
        } | Should -Throw '*Attachment validation failed.*'
    }
}
