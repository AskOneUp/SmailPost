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
                    $AttachmentPath,
                    $MaxTotalBytes
                )

                $null = $AttachmentPath
                $null = $MaxTotalBytes
                [pscustomobject]@{}
            }
        }

        if (-not (Get-Command ConvertTo-SPGraphAttachmentSet -ErrorAction SilentlyContinue)) {
            function ConvertTo-SPGraphAttachmentSet {
                param (
                    $AttachmentPath,
                    $InlineImage
                )

                $null = $AttachmentPath
                $null = $InlineImage
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
            param (
                $AttachmentPath,
                $MaxTotalBytes
            )

            $paths = @($AttachmentPath)

            [pscustomobject]@{
                Valid                = $true
                AttachmentCount      = $paths.Count
                AttachmentTotalBytes = 0L
                MaxTotalBytes        = $MaxTotalBytes
                ValidPaths           = $paths
                InvalidPaths         = @()
                Notes                = @('Attachment validation succeeded.')
            }
        }

        Mock ConvertTo-SPGraphAttachmentSet {
            param (
                $AttachmentPath,
                $InlineImage
            )

            $attachments = @()

            foreach ($path in @($AttachmentPath)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$path)) {
                    $attachments += @{
                        '@odata.type' = '#microsoft.graph.fileAttachment'
                        name          = [System.IO.Path]::GetFileName([string]$path)
                    }
                }
            }

            foreach ($inlineItem in @($InlineImage)) {
                if ($null -eq $inlineItem) {
                    continue
                }

                $attachments += @{
                    '@odata.type' = '#microsoft.graph.fileAttachment'
                    name          = [System.IO.Path]::GetFileName([string]$inlineItem.Path)
                    isInline      = $true
                    contentId     = [string]$inlineItem.ContentId
                }
            }

            $inlineCount = @(
                $attachments |
                Where-Object {
                    $_.ContainsKey('isInline') -and
                    $_.isInline -eq $true
                }
            ).Count

            [pscustomobject]@{
                Attachments          = $attachments
                AttachmentCount      = $attachments.Count
                AttachmentTotalBytes = 0L
                InlineImageCount     = $inlineCount
                Notes                = @('Graph attachments built.')
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
            param (
                $Recipient,
                $Subject,
                $HtmlBody,
                $Attachments,
                $SaveToSentItems
            )

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
                    attachments  = @($Attachments)
                }
                saveToSentItems = $SaveToSentItems
            }
        }

        Mock Send-SPGraphMailRequest {
            param (
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

    It 'Sends an ordinary attachment through the existing attachment contract' {
        Mock Test-SPAttachmentSet {
            param (
                $AttachmentPath,
                $MaxTotalBytes
            )

            $paths = @($AttachmentPath)

            [pscustomobject]@{
                Valid                = $true
                AttachmentCount      = $paths.Count
                AttachmentTotalBytes = if ($paths.Count -gt 0) { 100L } else { 0L }
                MaxTotalBytes        = $MaxTotalBytes
                ValidPaths           = $paths
                InvalidPaths         = @()
                Notes                = @('Attachment validation succeeded.')
            }
        }

        $results = Send-SPMail `
            -SenderAddress 'AskOneUp@outlook.com' `
            -To @('user@example.com') `
            -Subject 'Test subject' `
            -HtmlBody '<p>Hello</p>' `
            -AttachmentPath 'C:\Temp\manual.pdf' `
            -Confirm:$false

        $results | Should -HaveCount 1
        $results[0].Success | Should -BeTrue
        $results[0].AttachmentCount | Should -Be 1

        Should -Invoke ConvertTo-SPGraphAttachmentSet -Times 1 -ParameterFilter {
            @($AttachmentPath).Count -eq 1 -and
            $AttachmentPath[0] -eq 'C:\Temp\manual.pdf' -and
            @($InlineImage).Count -eq 0
        }
    }

    It 'Passes an inline image and ContentId to the Graph attachment set' {
        $inlineImage = [pscustomobject]@{
            Path      = 'C:\Temp\connected-logo.png'
            ContentId = 'connected-logo'
        }

        $results = Send-SPMail `
            -SenderAddress 'AskOneUp@outlook.com' `
            -To @('user@example.com') `
            -Subject 'Test subject' `
            -HtmlBody '<img src="cid:connected-logo">' `
            -InlineImage @($inlineImage) `
            -Confirm:$false

        $results | Should -HaveCount 1
        $results[0].Success | Should -BeTrue
        $results[0].AttachmentCount | Should -Be 1

        Should -Invoke ConvertTo-SPGraphAttachmentSet -Times 1 -ParameterFilter {
            @($AttachmentPath).Count -eq 0 -and
            @($InlineImage).Count -eq 1 -and
            $InlineImage[0].Path -eq 'C:\Temp\connected-logo.png' -and
            $InlineImage[0].ContentId -eq 'connected-logo'
        }
    }

    It 'Combines ordinary attachments and inline images' {
        $inlineImage = [pscustomobject]@{
            Path      = 'C:\Temp\connected-logo.png'
            ContentId = 'connected-logo'
        }

        $results = Send-SPMail `
            -SenderAddress 'AskOneUp@outlook.com' `
            -To @('user@example.com') `
            -Subject 'Test subject' `
            -HtmlBody '<img src="cid:connected-logo">' `
            -AttachmentPath 'C:\Temp\manual.pdf' `
            -InlineImage @($inlineImage) `
            -Confirm:$false

        $results | Should -HaveCount 1
        $results[0].Success | Should -BeTrue
        $results[0].AttachmentCount | Should -Be 2

        Should -Invoke ConvertTo-SPGraphAttachmentSet -Times 1 -ParameterFilter {
            @($AttachmentPath).Count -eq 1 -and
            $AttachmentPath[0] -eq 'C:\Temp\manual.pdf' -and
            @($InlineImage).Count -eq 1 -and
            $InlineImage[0].ContentId -eq 'connected-logo'
        }
    }

    It 'Passes the inline Graph attachment to the mail payload' {
        $inlineImage = [pscustomobject]@{
            Path      = 'C:\Temp\connected-logo.png'
            ContentId = 'connected-logo'
        }

        Send-SPMail `
            -SenderAddress 'AskOneUp@outlook.com' `
            -To @('user@example.com') `
            -Subject 'Test subject' `
            -HtmlBody '<img src="cid:connected-logo">' `
            -InlineImage @($inlineImage) `
            -Confirm:$false

        Should -Invoke ConvertTo-SPGraphMailPayload -Times 1 -ParameterFilter {
            @($Attachments).Count -eq 1 -and
            $Attachments[0].isInline -eq $true -and
            $Attachments[0].contentId -eq 'connected-logo'
        }
    }

    It 'Throws when inline image ContentId is whitespace' {
        $inlineImage = [pscustomobject]@{
            Path      = 'C:\Temp\connected-logo.png'
            ContentId = '   '
        }

        {
            Send-SPMail `
                -SenderAddress 'AskOneUp@outlook.com' `
                -To @('user@example.com') `
                -Subject 'Test subject' `
                -HtmlBody '<p>Hello</p>' `
                -InlineImage @($inlineImage) `
                -Confirm:$false
        } | Should -Throw 'Inline image ContentId cannot be null, empty, or whitespace.'
    }

    It 'Throws when combined ordinary and inline attachment size exceeds the maximum' {
        Mock Test-SPAttachmentSet {
            param (
                $AttachmentPath,
                $MaxTotalBytes
            )

            $paths = @($AttachmentPath)
            $totalBytes = 0L

            if ($paths.Count -gt 0) {
                $totalBytes = 600L
            }

            [pscustomobject]@{
                Valid                = $true
                AttachmentCount      = $paths.Count
                AttachmentTotalBytes = $totalBytes
                MaxTotalBytes        = $MaxTotalBytes
                ValidPaths           = $paths
                InvalidPaths         = @()
                Notes                = @('Attachment validation succeeded.')
            }
        }

        $inlineImage = [pscustomobject]@{
            Path      = 'C:\Temp\connected-logo.png'
            ContentId = 'connected-logo'
        }

        {
            Send-SPMail `
                -SenderAddress 'AskOneUp@outlook.com' `
                -To @('user@example.com') `
                -Subject 'Test subject' `
                -HtmlBody '<img src="cid:connected-logo">' `
                -AttachmentPath 'C:\Temp\manual.pdf' `
                -InlineImage @($inlineImage) `
                -MaxTotalAttachmentBytes 1000 `
                -Confirm:$false
        } | Should -Throw '*Combined attachment size exceeds the maximum allowed size of 1000 bytes.*'
    }

    It 'Throws when attachment validation fails' {
        Mock Test-SPAttachmentSet {
            param (
                $AttachmentPath,
                $MaxTotalBytes
            )

            if (@($AttachmentPath).Count -gt 0) {
                return [pscustomobject]@{
                    Valid                = $false
                    AttachmentCount      = 0
                    AttachmentTotalBytes = 0L
                    MaxTotalBytes        = $MaxTotalBytes
                    ValidPaths           = @()
                    InvalidPaths         = @('C:\Bad\Missing.pdf')
                    Notes                = @('Attachment validation failed.')
                }
            }

            [pscustomobject]@{
                Valid                = $true
                AttachmentCount      = 0
                AttachmentTotalBytes = 0L
                MaxTotalBytes        = $MaxTotalBytes
                ValidPaths           = @()
                InvalidPaths         = @()
                Notes                = @('No attachments supplied.')
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
