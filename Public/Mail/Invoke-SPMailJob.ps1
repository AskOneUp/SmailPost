function Invoke-SPMailJob {
    <#
        .SYNOPSIS
        Executes a complete SmailPost CSV-driven mail job.

        .DESCRIPTION
        Invoke-SPMailJob is the main public workflow command for SmailPost.

        The function performs the full job pipeline:
        - imports the CSV
        - validates job setup
        - validates each row
        - renders valid rows
        - sends rendered rows
        - builds the final canonical job report

        .PARAMETER CsvPath
        The path to the CSV file that contains the mail job input rows.

        .PARAMETER RecipientColumn
        The CSV column that contains the recipient email addresses.

        .PARAMETER SenderAddress
        The allowed sender mailbox address used for the mail job.

        .PARAMETER SubjectTemplate
        The subject template to use for each mail item.

        .PARAMETER HtmlBodyTemplate
        The HTML body template to use for each mail item.

        .PARAMETER AttachmentPaths
        Optional attachment file paths to include with each message.

        .PARAMETER InlineImages
        Optional inline image definitions to include with each message.


        .PARAMETER BccAddress
        Optional BCC email address that receives a blind copy of each message in the mail job.

        Each inline image definition must contain:
        - Path
        - ContentId

        The ContentId can be referenced from the HTML body by using
        cid:<ContentId>.

        .PARAMETER SaveToSentItems
        Indicates whether sent messages should be stored in Sent Items.

        .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$CsvPath,

        [Parameter(Mandatory = $true)]
        [string]$RecipientColumn,

        [Parameter(Mandatory = $true)]
        [string]$SenderAddress,

        [Parameter(Mandatory = $true)]
        [string]$SubjectTemplate,

        [Parameter(Mandatory = $true)]
        [string]$HtmlBodyTemplate,

        [Parameter()]
        [string[]]$AttachmentPaths = @(),

        [Parameter()]
        [object[]]$InlineImages = @(),

        [Parameter()]
        [string]$BccAddress,

        [Parameter()]
        [bool]$SaveToSentItems = $true
    )

    # ========================
    # Import CSV.
    # ========================

    $csvImportResult = Import-SPCsv -Path $CsvPath

    # ========================
    # Validate job setup.
    # ========================

    $jobSetupResult = Test-SPMailJobSetup `
        -CsvImportResult $csvImportResult `
        -RecipientColumn $RecipientColumn `
        -SenderAddress $SenderAddress `
        -BccAddress $BccAddress `
        -SubjectTemplate $SubjectTemplate `
        -BodyTemplate $HtmlBodyTemplate `
        -AttachmentPaths $AttachmentPaths `
        -InlineImages $InlineImages

    $rowValidationResults = [System.Collections.Generic.List[object]]::new()
    $renderResults = [System.Collections.Generic.List[object]]::new()
    $validRenderItems = [System.Collections.Generic.List[object]]::new()
    $batchSendResult = $null

    # ========================
    # Process rows only when job setup is valid.
    # ========================

    if ($jobSetupResult.Status -eq 'Valid') {
        $rowNumber = 0

        foreach ($row in $csvImportResult.Rows) {
            $rowNumber += 1

            $rowValidationResult = Test-SPMailRow `
                -Row $row `
                -RowNumber $rowNumber `
                -RecipientColumn $RecipientColumn `
                -SubjectTemplate $SubjectTemplate `
                -BodyTemplate $HtmlBodyTemplate

            $rowValidationResults.Add($rowValidationResult)

            if ($rowValidationResult.Status -ne 'Valid') {
                continue
            }

            $renderResult = ConvertTo-SPMailRender `
                -Row $row `
                -RowNumber $rowNumber `
                -RecipientColumn $RecipientColumn `
                -SubjectTemplate $SubjectTemplate `
                -BodyTemplate $HtmlBodyTemplate `
                -AttachmentPaths $AttachmentPaths `
                -InlineImages $InlineImages

            $renderResults.Add($renderResult)

            if ($renderResult.Status -eq 'Valid') {
                $validRenderItems.Add($renderResult)
            }
        }

        # ========================
        # Send valid rendered items.
        # ========================

        if ($validRenderItems.Count -gt 0) {
            $batchSendResult = Send-SPMailBatch `
                -RenderItems @($validRenderItems) `
                -SenderAddress $SenderAddress `
                -BccAddress $BccAddress `
                -SaveToSentItems $SaveToSentItems
        }
    }

    # ========================
    # Build final report.
    # ========================

    return ConvertTo-SPMailJobReport `
        -JobSetupResult $jobSetupResult `
        -RowValidationResults @($rowValidationResults) `
        -RenderResults @($renderResults) `
        -BatchSendResult $batchSendResult
}
