function Send-SPMailBatch {

    <#
.SYNOPSIS
Sends a batch of rendered SmailPost mail items.

.DESCRIPTION
Processes rendered mail items one by one and sends each item through
Send-SPMail.

This function:
- validates the rendered item collection
- sends one rendered item at a time
- collects standardized per-row send results
- determines the overall batch status

This function does not perform rendering. It only sends already prepared
mail items.

.PARAMETER RenderItems
The rendered mail items to send.

.PARAMETER SenderAddress
The sender mailbox address used for the batch.

.PARAMETER SaveToSentItems
Indicates whether sent messages should be stored in Sent Items.

.OUTPUTS
PSCustomObject

Returns an object containing:
- BatchId
- Status
- TotalCount
- SentCount
- FailedCount
- Results

.NOTES
Private SmailPost function.
Used after ConvertTo-SPMailRender and before reporting or export.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$RenderItems,

        [Parameter(Mandatory)]
        [string]$SenderAddress,

        [Parameter()]
        [bool]$SaveToSentItems = $true
    )

    if ([string]::IsNullOrWhiteSpace($SenderAddress)) {
        throw 'SenderAddress cannot be null, empty, or whitespace.'
    }

    $batchId = [System.Guid]::NewGuid().ToString()
    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($renderItem in $RenderItems) {
        $attemptedOn = Get-Date

        if ($null -eq $renderItem) {
            continue
        }

        if ($renderItem.Status -ne 'Valid') {
            $results.Add((
                    ConvertTo-SPSendResult `
                        -RowNumber $renderItem.RowNumber `
                        -Recipient $renderItem.Recipient `
                        -SenderAddress $SenderAddress `
                        -Subject $renderItem.Subject `
                        -Success $false `
                        -Status 'Failed' `
                        -ErrorMessage 'Render item is not valid for sending.' `
                        -AttemptedOn $attemptedOn `
                        -AttachmentCount $renderItem.Attachments.Count `
                        -BatchId $batchId
                ))

            continue
        }

        $sendResults = @(Send-SPMail `
                -SenderAddress $SenderAddress `
                -To @($renderItem.Recipient) `
                -Subject $renderItem.Subject `
                -HtmlBody $renderItem.Body `
                -AttachmentPath @($renderItem.Attachments) `
                -SaveToSentItems $SaveToSentItems `
                -Confirm:$false)

        if ($sendResults.Count -eq 0) {
            $results.Add((
                    ConvertTo-SPSendResult `
                        -RowNumber $renderItem.RowNumber `
                        -Recipient $renderItem.Recipient `
                        -SenderAddress $SenderAddress `
                        -Subject $renderItem.Subject `
                        -Success $false `
                        -Status 'Failed' `
                        -ErrorMessage 'Send-SPMail returned no result.' `
                        -AttemptedOn $attemptedOn `
                        -AttachmentCount $renderItem.Attachments.Count `
                        -BatchId $batchId
                ))

            continue
        }

        $sendResult = $sendResults[0]

        $results.Add((
                ConvertTo-SPSendResult `
                    -RowNumber $renderItem.RowNumber `
                    -Recipient $sendResult.Recipient `
                    -SenderAddress $SenderAddress `
                    -Subject $renderItem.Subject `
                    -Success $sendResult.Success `
                    -Status $sendResult.Status `
                    -ErrorMessage $sendResult.ErrorMessage `
                    -AttemptedOn $sendResult.AttemptedOn `
                    -AttachmentCount $renderItem.Attachments.Count `
                    -BatchId $batchId
            ))
    }

    $resultArray = @($results)
    $status = Resolve-SPBatchStatus -Results $resultArray
    $sentCount = @($resultArray | Where-Object { $_.Success -eq $true }).Count
    $failedCount = @($resultArray | Where-Object { $_.Success -eq $false }).Count

    return [pscustomobject]@{
        BatchId     = $batchId
        Status      = $status
        TotalCount  = $resultArray.Count
        SentCount   = $sentCount
        FailedCount = $failedCount
        Results     = $resultArray
    }
}
