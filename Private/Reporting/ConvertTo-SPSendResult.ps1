function ConvertTo-SPSendResult {

    <#
.SYNOPSIS
Creates a standardized batch send result object.

.DESCRIPTION
Builds one result object for one rendered mail item processed by the
batch sender.

This function is used to normalize send outcomes so batch reporting,
console review, export, and future UI binding all work with the same
stable object shape.

.PARAMETER RowNumber
The 1-based row number from the imported CSV data.

.PARAMETER Recipient
The normalized recipient email address.

.PARAMETER SenderAddress
The sender mailbox used for the send attempt.

.PARAMETER Subject
The resolved subject used for the send attempt.

.PARAMETER Success
Indicates whether the send attempt succeeded.

.PARAMETER Status
The human-readable batch status for this row.

.PARAMETER ErrorMessage
The error message for failed send attempts.

.PARAMETER AttemptedOn
The timestamp when the send attempt occurred.

.PARAMETER AttachmentCount
The number of attachments included in the message.

.PARAMETER BatchId
The identifier of the current batch run.

.OUTPUTS
PSCustomObject

Returns an object containing:
- RowNumber
- Recipient
- SenderAddress
- Subject
- Success
- Status
- ErrorMessage
- AttemptedOn
- AttachmentCount
- BatchId

.NOTES
Private SmailPost function.
Used by Send-SPMailBatch.
#>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'This function only creates and returns an in-memory object.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$RowNumber,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Recipient = '',

        [Parameter(Mandatory)]
        [string]$SenderAddress,

        [Parameter(Mandatory)]
        [string]$Subject,

        [Parameter(Mandatory)]
        [bool]$Success,

        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter()]
        [AllowEmptyString()]
        [string]$ErrorMessage = '',

        [Parameter(Mandatory)]
        [datetime]$AttemptedOn,

        [Parameter()]
        [int]$AttachmentCount = 0,

        [Parameter(Mandatory)]
        [string]$BatchId
    )

    if ($RowNumber -lt 1) {
        throw 'RowNumber must be greater than or equal to 1.'
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
        RowNumber       = $RowNumber
        Recipient       = $Recipient.Trim()
        SenderAddress   = $SenderAddress.Trim()
        Subject         = $Subject
        Success         = $Success
        Status          = $Status
        ErrorMessage    = $ErrorMessage
        AttemptedOn     = $AttemptedOn
        AttachmentCount = $AttachmentCount
        BatchId         = $BatchId
    }
}
