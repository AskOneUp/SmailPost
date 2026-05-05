function ConvertTo-SPMailJobReport {

    <#
.SYNOPSIS
Creates a standardized report for a complete SmailPost mail job.

.DESCRIPTION
Builds one canonical report object for the entire SmailPost run.

The report combines:
- job setup validation
- row validation
- render preparation
- batch send results

This object is intended for console review, export, logging, and future UI binding.

.PARAMETER JobSetupResult
The result from Test-SPMailJobSetup.

.PARAMETER RowValidationResults
The collection of row validation results from Test-SPMailRow.

.PARAMETER RenderResults
The collection of rendered mail results from ConvertTo-SPMailRender.

.PARAMETER BatchSendResult
The result from Send-SPMailBatch.

.OUTPUTS
PSCustomObject

Returns an object containing:
- CreatedOn
- JobSetupStatus
- RowValidationStatus
- RenderStatus
- BatchStatus
- OverallStatus
- SetupIssueCount
- RowIssueCount
- RenderIssueCount
- TotalRows
- ValidRowCount
- InvalidRowCount
- RenderedCount
- SentCount
- FailedCount
- BatchId
- JobSetupResult
- RowValidationResults
- RenderResults
- BatchSendResult

.NOTES
Private SmailPost function.
Used as the final canonical result of a SmailPost run.
#>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'This function only creates and returns an in-memory object.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [psobject]$JobSetupResult,

        [Parameter()]
        [AllowNull()]
        [object[]]$RowValidationResults = @(),

        [Parameter()]
        [AllowNull()]
        [object[]]$RenderResults = @(),

        [Parameter()]
        [AllowNull()]
        [psobject]$BatchSendResult = $null
    )

    $createdOn = Get-Date

    $jobSetupStatus = 'Unknown'
    $rowValidationStatus = 'Empty'
    $renderStatus = 'Empty'
    $batchStatus = 'Empty'
    $overallStatus = 'Unknown'
    $setupIssueCount = 0
    $rowIssueCount = 0
    $renderIssueCount = 0
    $totalRows = 0
    $validRowCount = 0
    $invalidRowCount = 0
    $renderedCount = 0
    $sentCount = 0
    $failedCount = 0
    $batchId = ''

    if ($null -eq $JobSetupResult) {
        throw 'JobSetupResult cannot be null.'
    }

    if ($null -ne $JobSetupResult.Status) {
        $jobSetupStatus = [string]$JobSetupResult.Status
    }

    if ($null -ne $JobSetupResult.Issues) {
        $setupIssueCount = @($JobSetupResult.Issues).Count
    }

    $rowValidationResults = @($RowValidationResults)
    $renderResults = @($RenderResults)

    $totalRows = $rowValidationResults.Count

    if ($rowValidationResults.Count -eq 0) {
        $rowValidationStatus = 'Empty'
    }
    else {
        $rowIssueCount = @(
            foreach ($rowValidationResult in $rowValidationResults) {
                @($rowValidationResult.Issues).Count
            }
        ) | Measure-Object -Sum | Select-Object -ExpandProperty Sum

        $validRowCount = @($rowValidationResults | Where-Object { $_.Status -eq 'Valid' }).Count
        $invalidRowCount = @($rowValidationResults | Where-Object { $_.Status -ne 'Valid' }).Count

        if ($validRowCount -eq $rowValidationResults.Count) {
            $rowValidationStatus = 'Valid'
        }
        elseif ($invalidRowCount -eq $rowValidationResults.Count) {
            $rowValidationStatus = 'Invalid'
        }
        else {
            $rowValidationStatus = 'Partial'
        }
    }

    if ($renderResults.Count -eq 0) {
        $renderStatus = 'Empty'
    }
    else {
        $renderIssueCount = @(
            foreach ($renderResult in $renderResults) {
                @($renderResult.Issues).Count
            }
        ) | Measure-Object -Sum | Select-Object -ExpandProperty Sum

        $renderedCount = $renderResults.Count

        $validRenderCount = @($renderResults | Where-Object { $_.Status -eq 'Valid' }).Count
        $invalidRenderCount = @($renderResults | Where-Object { $_.Status -ne 'Valid' }).Count

        if ($validRenderCount -eq $renderResults.Count) {
            $renderStatus = 'Valid'
        }
        elseif ($invalidRenderCount -eq $renderResults.Count) {
            $renderStatus = 'Invalid'
        }
        else {
            $renderStatus = 'Partial'
        }
    }

    if ($null -ne $BatchSendResult) {
        if ($null -ne $BatchSendResult.Status) {
            $batchStatus = [string]$BatchSendResult.Status
        }

        if ($null -ne $BatchSendResult.SentCount) {
            $sentCount = [int]$BatchSendResult.SentCount
        }

        if ($null -ne $BatchSendResult.FailedCount) {
            $failedCount = [int]$BatchSendResult.FailedCount
        }

        if ($null -ne $BatchSendResult.BatchId) {
            $batchId = [string]$BatchSendResult.BatchId
        }
    }

    if ($jobSetupStatus -eq 'Invalid') {
        $overallStatus = 'Invalid'
    }
    elseif ($batchStatus -eq 'Sent') {
        $overallStatus = 'Sent'
    }
    elseif ($batchStatus -eq 'Partial') {
        $overallStatus = 'Partial'
    }
    elseif ($batchStatus -eq 'Failed') {
        $overallStatus = 'Failed'
    }
    elseif ($renderStatus -eq 'Invalid' -or $rowValidationStatus -eq 'Invalid') {
        $overallStatus = 'Invalid'
    }
    elseif ($renderStatus -eq 'Partial' -or $rowValidationStatus -eq 'Partial') {
        $overallStatus = 'Partial'
    }
    else {
        $overallStatus = $jobSetupStatus
    }

    return [pscustomobject][ordered]@{
        CreatedOn            = $createdOn
        JobSetupStatus       = $jobSetupStatus
        RowValidationStatus  = $rowValidationStatus
        RenderStatus         = $renderStatus
        BatchStatus          = $batchStatus
        OverallStatus        = $overallStatus
        SetupIssueCount      = $setupIssueCount
        RowIssueCount        = $rowIssueCount
        RenderIssueCount     = $renderIssueCount
        TotalRows            = $totalRows
        ValidRowCount        = $validRowCount
        InvalidRowCount      = $invalidRowCount
        RenderedCount        = $renderedCount
        SentCount            = $sentCount
        FailedCount          = $failedCount
        BatchId              = $batchId
        JobSetupResult       = $JobSetupResult
        RowValidationResults = $rowValidationResults
        RenderResults        = $renderResults
        BatchSendResult      = $BatchSendResult
    }
}
