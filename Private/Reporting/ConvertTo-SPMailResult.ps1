function ConvertTo-SPMailResult {
    <#
        .SYNOPSIS
        Builds a standardized SmailPost send result object for one recipient.

        .DESCRIPTION
        ConvertTo-SPMailResult creates a single, stable result object for one recipient send attempt.
        The returned object is designed for console review, CSV export, and future UI binding.

        .PARAMETER Recipient
        The recipient email address for this send attempt.

        .PARAMETER RecipientIndex
        The position of the recipient in the current batch.

        .PARAMETER SenderAddress
        The sender mailbox used for the send attempt.

        .PARAMETER Subject
        The subject used for the send attempt.

        .PARAMETER Success
        Indicates whether the send attempt succeeded.

        .PARAMETER Status
        The human-readable status of the send attempt. For version 1 this is expected to be
        values such as 'Sent' or 'Failed'.

        .PARAMETER ErrorMessage
        A short error message for failed send attempts. Leave empty for successful sends.

        .PARAMETER AttemptedOn
        The timestamp when the send attempt was made.

        .PARAMETER SaveToSentItems
        Indicates whether the message was configured to be saved to Sent Items.

        .PARAMETER AttachmentCount
        The number of attachments included in the message.

        .PARAMETER AttachmentTotalBytes
        The combined size of all attachments in bytes.

        .PARAMETER BatchId
        The identifier of the current send batch.

        .PARAMETER Notes
        Optional diagnostic notes associated with the send attempt.

        .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Recipient,

        [Parameter(Mandatory = $true)]
        [int]$RecipientIndex,

        [Parameter(Mandatory = $true)]
        [string]$SenderAddress,

        [Parameter(Mandatory = $true)]
        [string]$Subject,

        [Parameter(Mandatory = $true)]
        [bool]$Success,

        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter()]
        [string]$ErrorMessage = '',

        [Parameter(Mandatory = $true)]
        [datetime]$AttemptedOn,

        [Parameter(Mandatory = $true)]
        [bool]$SaveToSentItems,

        [Parameter()]
        [int]$AttachmentCount = 0,

        [Parameter()]
        [long]$AttachmentTotalBytes = 0L,

        [Parameter(Mandatory = $true)]
        [string]$BatchId,

        [Parameter()]
        [string[]]$Notes = @()
    )

    process {
        if ([string]::IsNullOrWhiteSpace($Recipient)) {
            throw 'Recipient cannot be null, empty, or whitespace.'
        }

        if ($RecipientIndex -lt 1) {
            throw 'RecipientIndex must be greater than or equal to 1.'
        }

        if ([string]::IsNullOrWhiteSpace($SenderAddress)) {
            throw 'SenderAddress cannot be null, empty, or whitespace.'
        }

        if ([string]::IsNullOrWhiteSpace($Subject)) {
            throw 'Subject cannot be null, empty, or whitespace.'
        }

        if ([string]::IsNullOrWhiteSpace($Status)) {
            throw 'Status cannot be null, empty, or whitespace.'
        }

        if ([string]::IsNullOrWhiteSpace($BatchId)) {
            throw 'BatchId cannot be null, empty, or whitespace.'
        }

        return [pscustomobject][ordered]@{
            Recipient            = $Recipient.Trim()
            RecipientIndex       = $RecipientIndex
            SenderAddress        = $SenderAddress.Trim()
            Subject              = $Subject
            Success              = $Success
            Status               = $Status
            ErrorMessage         = $ErrorMessage
            AttemptedOn          = $AttemptedOn
            SaveToSentItems      = $SaveToSentItems
            AttachmentCount      = $AttachmentCount
            AttachmentTotalBytes = $AttachmentTotalBytes
            BatchId              = $BatchId
            Notes                = @($Notes)
        }
    }
}
