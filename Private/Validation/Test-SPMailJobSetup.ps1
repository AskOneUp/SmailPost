function Test-SPMailJobSetup {
    <#
    .SYNOPSIS
    Validates the mail job setup before row-level validation begins.

    .DESCRIPTION
    Performs preflight validation for the mail job configuration, including
    CSV availability, recipient column selection, sender selection, template
    presence, placeholder and header alignment, and attachment path validation.

    .PARAMETER CsvImportResult
    The imported CSV result object.

    .PARAMETER RecipientColumn
    The name of the CSV column that contains recipient email addresses.

    .PARAMETER SenderAddress
    The sender email address to use for the mail job.

    .PARAMETER SubjectTemplate
    The subject template for the mail job.

    .PARAMETER BodyTemplate
    The body template for the mail job.

    .PARAMETER AttachmentPaths
    Optional attachment file paths to validate.

    .OUTPUTS
    PSCustomObject with:
    - Issues
    - Status
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [psobject]$CsvImportResult,

        [Parameter()]
        [string]$RecipientColumn,

        [Parameter()]
        [string]$SenderAddress,

        [Parameter()]
        [string]$SubjectTemplate,

        [Parameter()]
        [string]$BodyTemplate,

        [Parameter()]
        [string[]]$AttachmentPaths = @()
    )

    $issues = [System.Collections.Generic.List[object]]::new()

    # ========================
    # Validate CSV object.
    # ========================

    if ($null -eq $CsvImportResult) {
        $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'JobSetup.Csv.Missing' -Category 'Csv' -Message 'CSV import result is required.' -Target 'CsvImportResult'))
    }
    else {
        if ($null -eq $CsvImportResult.Headers -or $CsvImportResult.Headers.Count -eq 0) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'JobSetup.Csv.HeadersMissing' -Category 'Csv' -Message 'CSV headers are required.' -Target 'Headers'))
        }

        if ($null -eq $CsvImportResult.Rows -or $CsvImportResult.Rows.Count -eq 0) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'JobSetup.Csv.RowsMissing' -Category 'Csv' -Message 'CSV rows are required.' -Target 'Rows'))
        }
    }

    # ========================
    # Validate recipient column.
    # ========================

    if ([string]::IsNullOrWhiteSpace($RecipientColumn)) {
        $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'JobSetup.RecipientColumn.Missing' -Category 'Configuration' -Message 'Recipient column is required.' -Target 'RecipientColumn'))
    }
    elseif ($null -ne $CsvImportResult -and $null -ne $CsvImportResult.Headers -and $CsvImportResult.Headers.Count -gt 0) {
        if ($RecipientColumn -notin $CsvImportResult.Headers) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'JobSetup.RecipientColumn.NotFound' -Category 'Configuration' -Message "Recipient column '$RecipientColumn' was not found in the CSV headers." -Target 'RecipientColumn' -Details @{ RecipientColumn = $RecipientColumn }))
        }
    }

    # ========================
    # Validate sender.
    # ========================

    if ([string]::IsNullOrWhiteSpace($SenderAddress)) {
        $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'JobSetup.Sender.Missing' -Category 'Sender' -Message 'Sender address is required.' -Target 'SenderAddress'))
    }
    else {
        $allowedSenders = @(Get-SPAllowedSender)
        $normalizedSenderAddress = $SenderAddress.Trim().ToLowerInvariant()

        $matchingSender = $allowedSenders | Where-Object {
            ($_.Mail -and $_.Mail.Trim().ToLowerInvariant() -eq $normalizedSenderAddress) -or
            ($_.UserPrincipalName -and $_.UserPrincipalName.Trim().ToLowerInvariant() -eq $normalizedSenderAddress)
        }

        if ($allowedSenders.Count -eq 0 -or -not $matchingSender) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'JobSetup.Sender.NotAllowed' -Category 'Sender' -Message "Sender address '$SenderAddress' is not allowed." -Target 'SenderAddress' -Details @{ SenderAddress = $SenderAddress }))
        }
    }

    # ========================
    # Validate templates.
    # ========================

    if ([string]::IsNullOrWhiteSpace($SubjectTemplate)) {
        $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'JobSetup.Subject.Missing' -Category 'Template' -Message 'Subject template is required.' -Target 'SubjectTemplate'))
    }

    if ([string]::IsNullOrWhiteSpace($BodyTemplate)) {
        $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'JobSetup.Body.Missing' -Category 'Template' -Message 'Body template is required.' -Target 'BodyTemplate'))
    }

    # ========================
    # Validate placeholders against CSV headers.
    # ========================

    if ($null -ne $CsvImportResult -and $null -ne $CsvImportResult.Headers -and $CsvImportResult.Headers.Count -gt 0) {
        $headers = @($CsvImportResult.Headers)

        $subjectPlaceholders = @(Get-SPPlaceholder -Text $SubjectTemplate).UniquePlaceholders

        foreach ($placeholder in $subjectPlaceholders) {
            if ($placeholder -notin $headers) {
                $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'JobSetup.Subject.PlaceholderNotFound' -Category 'Template' -Message "Subject placeholder '$placeholder' was not found in the CSV headers." -Target 'SubjectTemplate' -Details @{ Placeholder = $placeholder }))
            }
        }

        $bodyPlaceholders = @(Get-SPPlaceholder -Text $BodyTemplate).UniquePlaceholders

        foreach ($placeholder in $bodyPlaceholders) {
            if ($placeholder -notin $headers) {
                $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'JobSetup.Body.PlaceholderNotFound' -Category 'Template' -Message "Body placeholder '$placeholder' was not found in the CSV headers." -Target 'BodyTemplate' -Details @{ Placeholder = $placeholder }))
            }
        }
    }

    # ========================
    # Validate attachments.
    # ========================

    foreach ($attachmentPath in @($AttachmentPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $attachmentIssues = @(Test-SPAttachmentPath -Path $attachmentPath)

        foreach ($issue in $attachmentIssues) {
            $issues.Add($issue)
        }
    }

    $status = Resolve-SPValidationStatus -Issues $issues

    return [pscustomobject]@{
        Issues = @($issues)
        Status = $status
    }
}
