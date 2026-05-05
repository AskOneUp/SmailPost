function Resolve-SPBatchStatus {

    <#
.SYNOPSIS
Determines the overall batch status from per-row send results.

.DESCRIPTION
Evaluates a collection of batch send result objects and determines the
overall batch state.

Rules:
- If no results exist, the result is 'Empty'.
- If all results succeeded, the result is 'Sent'.
- If all results failed, the result is 'Failed'.
- If some succeeded and some failed, the result is 'Partial'.

.PARAMETER Results
The collection of batch send result objects.

.OUTPUTS
System.String

Returns one of the following values:
- Empty
- Sent
- Failed
- Partial

.NOTES
Private SmailPost function.
Used by Send-SPMailBatch.
#>

    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object[]]$Results
    )

    if ($null -eq $Results -or $Results.Count -eq 0) {
        return 'Empty'
    }

    $successfulResults = @($Results | Where-Object { $_.Success -eq $true })
    $failedResults = @($Results | Where-Object { $_.Success -eq $false })

    if ($successfulResults.Count -eq $Results.Count) {
        return 'Sent'
    }

    if ($failedResults.Count -eq $Results.Count) {
        return 'Failed'
    }

    return 'Partial'
}
