function Send-SPMail {
    <#
        .SYNOPSIS
        Sends one email per recipient through Microsoft Graph using an allowed sender.

        .DESCRIPTION
        Send-SPMail validates the current SmailPost environment, verifies the sender,
        validates the optional attachment set, and sends one individual email per recipient.

        Ordinary file attachments can be supplied through AttachmentPath.

        Inline images can be supplied through InlineImage. Each inline image definition
        must contain a Path and ContentId property. The ContentId can be referenced from
        the HTML message body by using cid:<ContentId>.

        Each recipient produces one result object so bulk sends can be reviewed, exported,
        or shown in a user interface.

        Transport diagnostic notes returned by Microsoft Graph are preserved in the
        result object.

        .PARAMETER SenderAddress
        The allowed sender mailbox address that will be used with Microsoft Graph.

        .PARAMETER To
        One or more recipient email addresses. SmailPost sends one email per recipient.

        .PARAMETER Subject
        The subject of the email message.

        .PARAMETER HtmlBody
        The HTML body of the email message.

        .PARAMETER BccAddress
        Optional BCC email address that receives a blind copy of each message.

        .PARAMETER AttachmentPath
        Optional file paths to include as ordinary attachments.

        .PARAMETER InlineImage
        Optional inline image definitions.

        Each object must contain:
        - Path
        - ContentId

        .PARAMETER SaveToSentItems
        Indicates whether sent messages should be stored in Sent Items.

        .PARAMETER MaxTotalAttachmentBytes
        The maximum combined attachment size allowed for this send operation.

        Ordinary attachments and inline images both count toward this limit.

        .OUTPUTS
        PSCustomObject

        Returns one result object per recipient. Transport diagnostic information is
        available through the Notes property.
    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        PositionalBinding = $false,
        ConfirmImpact = 'Medium'
    )]
    [OutputType([pscustomobject[]])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SenderAddress,

        [Parameter(Mandatory = $true)]
        [string[]]$To,

        [Parameter(Mandatory = $true)]
        [string]$Subject,

        [Parameter(Mandatory = $true)]
        [string]$HtmlBody,

        [Parameter()]
        [string]$BccAddress,

        [Parameter()]
        [string[]]$AttachmentPath = @(),

        [Parameter()]
        [object[]]$InlineImage = @(),

        [Parameter()]
        [bool]$SaveToSentItems = $true,

        [Parameter()]
        [long]$MaxTotalAttachmentBytes = 8MB
    )

    begin {
        $batchId = [System.Guid]::NewGuid().ToString()
        $results = @()
        $attachmentCount = 0
        $attachmentTotalBytes = 0L
        $graphAttachments = @()

        $normalizedSenderAddress = $SenderAddress.Trim()
        $normalizedSubject = $Subject.Trim()
        $normalizedHtmlBody = $HtmlBody.Trim()

        function ThrowCombinedNotes {
            param (
                [string[]]$Notes,

                [Parameter(Mandatory = $true)]
                [string]$FallbackMessage
            )

            $message = (
                $Notes |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                }
            ) -join ' '

            if ([string]::IsNullOrWhiteSpace($message)) {
                throw $FallbackMessage
            }

            throw $message
        }
    }

    process {
        # ========================
        # Top-level input validation.
        # ========================

        if ([string]::IsNullOrWhiteSpace($normalizedSenderAddress)) {
            throw 'SenderAddress cannot be null, empty, or whitespace.'
        }

        if ($null -eq $To -or $To.Count -eq 0) {
            throw 'At least one recipient must be supplied.'
        }

        if ([string]::IsNullOrWhiteSpace($normalizedSubject)) {
            throw 'Subject cannot be null, empty, or whitespace.'
        }

        if ([string]::IsNullOrWhiteSpace($normalizedHtmlBody)) {
            throw 'HtmlBody cannot be null, empty, or whitespace.'
        }

        # ========================
        # Readiness check.
        # ========================

        $mailReadyResult = Test-SPMailReady

        if (-not $mailReadyResult.Ready) {
            ThrowCombinedNotes `
                -Notes $mailReadyResult.Notes `
                -FallbackMessage 'SmailPost is not ready to send mail.'
        }

        # ========================
        # Sender validation.
        # ========================

        $senderValidationResult = Test-SPSenderAllowed `
            -SenderAddress $normalizedSenderAddress

        if (-not $senderValidationResult.Allowed) {
            ThrowCombinedNotes `
                -Notes $senderValidationResult.Notes `
                -FallbackMessage 'Sender is not allowed.'
        }

        $resolvedSenderIdentity = $normalizedSenderAddress

        if ($null -ne $senderValidationResult.MatchedSender) {
            if (
                -not [string]::IsNullOrWhiteSpace(
                    $senderValidationResult.MatchedSender.Id
                )
            ) {
                $resolvedSenderIdentity =
                $senderValidationResult.MatchedSender.Id
            }
            elseif (
                -not [string]::IsNullOrWhiteSpace(
                    $senderValidationResult.MatchedSender.UserPrincipalName
                )
            ) {
                $resolvedSenderIdentity =
                $senderValidationResult.MatchedSender.UserPrincipalName
            }
            elseif (
                -not [string]::IsNullOrWhiteSpace(
                    $senderValidationResult.MatchedSender.Mail
                )
            ) {
                $resolvedSenderIdentity =
                $senderValidationResult.MatchedSender.Mail
            }
        }

        # ========================
        # Ordinary attachment validation.
        # ========================

        $attachmentValidationResult = Test-SPAttachmentSet `
            -AttachmentPath $AttachmentPath `
            -MaxTotalBytes $MaxTotalAttachmentBytes

        if (-not $attachmentValidationResult.Valid) {
            ThrowCombinedNotes `
                -Notes $attachmentValidationResult.Notes `
                -FallbackMessage 'Attachment validation failed.'
        }

        # ========================
        # Inline image validation.
        # ========================

        $inlineImagePaths = @()

        foreach ($inlineItem in @($InlineImage)) {
            if ($null -eq $inlineItem) {
                throw 'Inline image definition cannot be null.'
            }

            $inlinePath = [string]$inlineItem.Path
            $contentId = [string]$inlineItem.ContentId

            if ([string]::IsNullOrWhiteSpace($inlinePath)) {
                throw 'Inline image path cannot be null, empty, or whitespace.'
            }

            if ([string]::IsNullOrWhiteSpace($contentId)) {
                throw 'Inline image ContentId cannot be null, empty, or whitespace.'
            }

            $inlineImagePaths += $inlinePath
        }

        $inlineValidationResult = Test-SPAttachmentSet `
            -AttachmentPath $inlineImagePaths `
            -MaxTotalBytes $MaxTotalAttachmentBytes

        if (-not $inlineValidationResult.Valid) {
            ThrowCombinedNotes `
                -Notes $inlineValidationResult.Notes `
                -FallbackMessage 'Inline image validation failed.'
        }

        # ========================
        # Combined attachment limit.
        # ========================

        $ordinaryTotalBytes = 0L

        if ($null -ne $attachmentValidationResult.AttachmentTotalBytes) {
            $ordinaryTotalBytes = [long](
                @($attachmentValidationResult.AttachmentTotalBytes)[0]
            )
        }

        $inlineTotalBytes = 0L

        if ($null -ne $inlineValidationResult.AttachmentTotalBytes) {
            $inlineTotalBytes = [long](
                @($inlineValidationResult.AttachmentTotalBytes)[0]
            )
        }

        $attachmentTotalBytes =
        $ordinaryTotalBytes + $inlineTotalBytes

        if ($attachmentTotalBytes -gt $MaxTotalAttachmentBytes) {
            throw (
                "Combined attachment size exceeds the maximum allowed size of {0} bytes." `
                    -f $MaxTotalAttachmentBytes
            )
        }

        # ========================
        # Graph attachment preparation.
        # ========================

        $attachmentSetResult = ConvertTo-SPGraphAttachmentSet `
            -AttachmentPath @($attachmentValidationResult.ValidPaths) `
            -InlineImage @($InlineImage)

        $graphAttachments = @($attachmentSetResult.Attachments)
        $attachmentCount = [int]$attachmentSetResult.AttachmentCount
        $attachmentTotalBytes =
        [long]$attachmentSetResult.AttachmentTotalBytes

        # ========================
        # Recipient loop.
        # ========================

        $recipientIndex = 0

        foreach ($recipient in $To) {
            $recipientIndex += 1
            $attemptedOn = Get-Date

            $recipientValidationResult =
            Test-SPRecipientAddress -Recipient $recipient

            if (-not $recipientValidationResult.Valid) {
                $results += ConvertTo-SPMailResult `
                    -Recipient $recipient `
                    -RecipientIndex $recipientIndex `
                    -SenderAddress $normalizedSenderAddress `
                    -Subject $normalizedSubject `
                    -Success $false `
                    -Status 'Failed' `
                    -ErrorMessage (
                    ($recipientValidationResult.Notes -join ' ').Trim()
                ) `
                    -AttemptedOn $attemptedOn `
                    -SaveToSentItems $SaveToSentItems `
                    -AttachmentCount $attachmentCount `
                    -AttachmentTotalBytes $attachmentTotalBytes `
                    -BatchId $batchId

                continue
            }

            $normalizedRecipient =
            $recipientValidationResult.NormalizedRecipient

            $payload = ConvertTo-SPGraphMailPayload `
                -Recipient $normalizedRecipient `
                -Subject $normalizedSubject `
                -HtmlBody $normalizedHtmlBody `
                -BccAddress $BccAddress `
                -Attachments $graphAttachments `
                -SaveToSentItems $SaveToSentItems

            if (
                -not $PSCmdlet.ShouldProcess(
                    $normalizedRecipient,
                    "Send mail from '$normalizedSenderAddress'"
                )
            ) {
                $results += ConvertTo-SPMailResult `
                    -Recipient $normalizedRecipient `
                    -RecipientIndex $recipientIndex `
                    -SenderAddress $normalizedSenderAddress `
                    -Subject $normalizedSubject `
                    -Success $false `
                    -Status 'Failed' `
                    -ErrorMessage 'Send operation cancelled by ShouldProcess.' `
                    -AttemptedOn $attemptedOn `
                    -SaveToSentItems $SaveToSentItems `
                    -AttachmentCount $attachmentCount `
                    -AttachmentTotalBytes $attachmentTotalBytes `
                    -BatchId $batchId

                continue
            }

            $transportResult = Send-SPGraphMailRequest `
                -SenderAddress $resolvedSenderIdentity `
                -Payload $payload

            if ($transportResult.Success) {
                $results += ConvertTo-SPMailResult `
                    -Recipient $normalizedRecipient `
                    -RecipientIndex $recipientIndex `
                    -SenderAddress $normalizedSenderAddress `
                    -Subject $normalizedSubject `
                    -Success $true `
                    -Status 'Sent' `
                    -ErrorMessage '' `
                    -AttemptedOn $attemptedOn `
                    -SaveToSentItems $SaveToSentItems `
                    -AttachmentCount $attachmentCount `
                    -AttachmentTotalBytes $attachmentTotalBytes `
                    -BatchId $batchId `
                    -Notes @($transportResult.Notes)
            }
            else {
                $results += ConvertTo-SPMailResult `
                    -Recipient $normalizedRecipient `
                    -RecipientIndex $recipientIndex `
                    -SenderAddress $normalizedSenderAddress `
                    -Subject $normalizedSubject `
                    -Success $false `
                    -Status 'Failed' `
                    -ErrorMessage $transportResult.ErrorMessage `
                    -AttemptedOn $attemptedOn `
                    -SaveToSentItems $SaveToSentItems `
                    -AttachmentCount $attachmentCount `
                    -AttachmentTotalBytes $attachmentTotalBytes `
                    -BatchId $batchId `
                    -Notes @($transportResult.Notes)
            }
        }
    }

    end {
        return $results
    }
}
