function Show-SPMailJobSummary {
    <#
        .SYNOPSIS
        Displays a human-readable summary for a SmailPost mail job report.

        .DESCRIPTION
        Show-SPMailJobSummary formats the canonical SmailPost job report into a
        compact console summary for quick review.

        The function writes summary lines to the pipeline as strings so the output
        can be displayed, captured, logged, or redirected.

        .PARAMETER Report
        The canonical SmailPost job report created by ConvertTo-SPMailJobReport or
        returned by Invoke-SPMailJob.

        .OUTPUTS
        System.String[]
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([object[]])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [psobject]$Report
    )

    if ($null -eq $Report) {
        throw 'Report cannot be null.'
    }

    $lines = [System.Collections.Generic.List[string]]::new()

    $createdOnText = ''
    if ($null -ne $Report.CreatedOn) {
        $createdOnText = ([datetime]$Report.CreatedOn).ToString('yyyy-MM-dd HH:mm:ss')
    }

    $batchIdText = ''
    if ($null -ne $Report.BatchId) {
        $batchIdText = [string]$Report.BatchId
    }

    $lines.Add('SmailPost Mail Job Summary')
    $lines.Add('========================')
    $lines.Add(('CreatedOn: {0}' -f $createdOnText))
    $lines.Add(('BatchId: {0}' -f $batchIdText))
    $lines.Add(('OverallStatus: {0}' -f $Report.OverallStatus))
    $lines.Add(('JobSetupStatus: {0}' -f $Report.JobSetupStatus))
    $lines.Add(('RowValidationStatus: {0}' -f $Report.RowValidationStatus))
    $lines.Add(('RenderStatus: {0}' -f $Report.RenderStatus))
    $lines.Add(('BatchStatus: {0}' -f $Report.BatchStatus))
    $lines.Add(('SetupIssueCount: {0}' -f $Report.SetupIssueCount))
    $lines.Add(('RowIssueCount: {0}' -f $Report.RowIssueCount))
    $lines.Add(('RenderIssueCount: {0}' -f $Report.RenderIssueCount))
    $lines.Add(('TotalRows: {0}' -f $Report.TotalRows))
    $lines.Add(('ValidRowCount: {0}' -f $Report.ValidRowCount))
    $lines.Add(('InvalidRowCount: {0}' -f $Report.InvalidRowCount))
    $lines.Add(('RenderedCount: {0}' -f $Report.RenderedCount))
    $lines.Add(('SentCount: {0}' -f $Report.SentCount))
    $lines.Add(('FailedCount: {0}' -f $Report.FailedCount))

    $failedResults = @()

    if ($null -ne $Report.BatchSendResult -and $null -ne $Report.BatchSendResult.Results) {
        $failedResults = @($Report.BatchSendResult.Results | Where-Object { $_.Success -eq $false })
    }

    if ($failedResults.Count -gt 0) {
        $lines.Add('')
        $lines.Add('Failed Rows')
        $lines.Add('-----------')

        foreach ($failedResult in $failedResults) {
            $lines.Add(
                ('Row {0}: Recipient={1}; Status={2}; Error={3}' -f
                $failedResult.RowNumber,
                $failedResult.Recipient,
                $failedResult.Status,
                $failedResult.ErrorMessage)
            )
        }
    }

    return @($lines)
}
