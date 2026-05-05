function Test-SPMailRow {

    <#
.SYNOPSIS
Validates a single CSV row for mail sending.

.DESCRIPTION
Performs row-level validation after job-level setup has already passed.

Checks include:
- recipient column exists on the row
- recipient value is valid
- subject placeholders can be resolved from the row
- body placeholders can be resolved from the row
- required placeholder values are not empty

This function validates only. It does not render or send mail.

.PARAMETER Row
The CSV row object to validate.

.PARAMETER RowNumber
The 1-based row number from the imported CSV data.

.PARAMETER RecipientColumn
The name of the row property that contains the recipient email address.

.PARAMETER SubjectTemplate
The subject template to validate against the row.

.PARAMETER BodyTemplate
The body template to validate against the row.

.OUTPUTS
PSCustomObject

Returns an object containing:
- Issues
- Status

.NOTES
Private SmailPost function.
Used after Test-SPMailJobSetup and before rendering or sending.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Row,

        [Parameter(Mandatory)]
        [int]$RowNumber,

        [Parameter(Mandatory)]
        [string]$RecipientColumn,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$SubjectTemplate,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$BodyTemplate
    )

    $issues = [System.Collections.Generic.List[object]]::new()

    $propertyLookup = @{}
    $propertyNameLookup = @{}
    $rowValueSource = $Row

    if ($null -ne $Row.PSObject.Properties['Values'] -and $null -ne $Row.Values) {
        $rowValueSource = $Row.Values
    }

    foreach ($property in $rowValueSource.PSObject.Properties) {
        $lookupKey = $property.Name.ToLowerInvariant()

        $propertyLookup[$lookupKey] = $property.Value
        $propertyNameLookup[$lookupKey] = $property.Name
    }

    # ========================
    # Validate recipient column presence.
    # ========================

    $recipientLookupKey = $RecipientColumn.ToLowerInvariant()

    if (-not $propertyLookup.ContainsKey($recipientLookupKey)) {
        $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'MailRow.RecipientColumn.NotFound' -Category 'Row' -Message "Recipient column '$RecipientColumn' was not found on the row." -Target 'RecipientColumn' -RowNumber $RowNumber -ColumnName $RecipientColumn -Details @{ RecipientColumn = $RecipientColumn }))
    }
    else {
        # ========================
        # Validate recipient value.
        # ========================

        $recipientValue = [string]$propertyLookup[$recipientLookupKey]
        $recipientValidation = Test-SPRecipientValue -Value $recipientValue

        if (-not $recipientValidation.IsValid) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code "MailRow.$($recipientValidation.ErrorCode)" -Category 'Recipient' -Message $recipientValidation.ErrorMessage -Target 'Recipient' -RowNumber $RowNumber -ColumnName $propertyNameLookup[$recipientLookupKey] -Details @{ OriginalValue = $recipientValidation.OriginalValue; NormalizedValue = $recipientValidation.NormalizedValue }))
        }
    }

    # ========================
    # Validate subject placeholders.
    # ========================

    $subjectPlaceholderResult = Get-SPPlaceholder -Text $SubjectTemplate

    foreach ($placeholder in $subjectPlaceholderResult.UniquePlaceholders) {
        $placeholderLookupKey = $placeholder.ToLowerInvariant()

        if (-not $propertyLookup.ContainsKey($placeholderLookupKey)) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'MailRow.Subject.PlaceholderUnresolved' -Category 'Template' -Message "Subject placeholder '$placeholder' could not be resolved for row $RowNumber." -Target 'SubjectTemplate' -RowNumber $RowNumber -ColumnName $placeholder -Details @{ Placeholder = $placeholder }))
            continue
        }

        $placeholderValue = [string]$propertyLookup[$placeholderLookupKey]

        if ([string]::IsNullOrWhiteSpace($placeholderValue)) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'MailRow.Subject.PlaceholderValueMissing' -Category 'Template' -Message "Subject placeholder '$placeholder' resolved to an empty value for row $RowNumber." -Target 'SubjectTemplate' -RowNumber $RowNumber -ColumnName $propertyNameLookup[$placeholderLookupKey] -Details @{ Placeholder = $placeholder }))
        }
    }

    # ========================
    # Validate body placeholders.
    # ========================

    $bodyPlaceholderResult = Get-SPPlaceholder -Text $BodyTemplate

    foreach ($placeholder in $bodyPlaceholderResult.UniquePlaceholders) {
        $placeholderLookupKey = $placeholder.ToLowerInvariant()

        if (-not $propertyLookup.ContainsKey($placeholderLookupKey)) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'MailRow.Body.PlaceholderUnresolved' -Category 'Template' -Message "Body placeholder '$placeholder' could not be resolved for row $RowNumber." -Target 'BodyTemplate' -RowNumber $RowNumber -ColumnName $placeholder -Details @{ Placeholder = $placeholder }))
            continue
        }

        $placeholderValue = [string]$propertyLookup[$placeholderLookupKey]

        if ([string]::IsNullOrWhiteSpace($placeholderValue)) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'MailRow.Body.PlaceholderValueMissing' -Category 'Template' -Message "Body placeholder '$placeholder' resolved to an empty value for row $RowNumber." -Target 'BodyTemplate' -RowNumber $RowNumber -ColumnName $propertyNameLookup[$placeholderLookupKey] -Details @{ Placeholder = $placeholder }))
        }
    }

    $status = Resolve-SPValidationStatus -Issues $issues

    return [pscustomobject]@{
        Issues = @($issues)
        Status = $status
    }
}
