function ConvertTo-SPMailRender {

    <#
.SYNOPSIS
Creates a rendered mail object for a single CSV row.

.DESCRIPTION
Builds a ready-to-send mail render from a validated CSV row.

The function:
- normalizes the recipient value
- resolves placeholders in subject and body
- validates attachment paths and returns resolved paths
- validates inline image paths and preserves their content IDs
- returns a standardized render object including validation issues and status

This function does not send mail. It only prepares the rendered output.

.PARAMETER Row
The CSV row object used for rendering.

.PARAMETER RowNumber
The 1-based row number from the imported CSV data.

.PARAMETER RecipientColumn
The name of the row property that contains the recipient email address.

.PARAMETER SubjectTemplate
The subject template to resolve.

.PARAMETER BodyTemplate
The body template to resolve.

.PARAMETER AttachmentPaths
Optional attachment file paths to validate and include.

.PARAMETER InlineImages
Optional inline image definitions to validate and include.

Each inline image definition must contain:
- Path
- ContentId

The ContentId can later be referenced from the HTML message body by using
cid:<ContentId>.

.OUTPUTS
PSCustomObject

Returns an object containing:
- Row
- RowNumber
- Recipient
- Subject
- Body
- Attachments
- InlineImages
- Issues
- Status

.NOTES
Private SmailPost function.
Used after row-level validation and before batch sending.
#>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'This function only creates and returns an in-memory object.'
    )]
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
        [string]$BodyTemplate,

        [Parameter()]
        [string[]]$AttachmentPaths = @(),

        [Parameter()]
        [object[]]$InlineImages = @()
    )

    $issues = [System.Collections.Generic.List[object]]::new()
    $resolvedAttachmentPaths = [System.Collections.Generic.List[string]]::new()
    $resolvedInlineImages = [System.Collections.Generic.List[object]]::new()

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

    $recipient = ''
    $subject = $SubjectTemplate
    $body = $BodyTemplate

    # ========================
    # Resolve recipient.
    # ========================

    $recipientLookupKey = $RecipientColumn.ToLowerInvariant()

    if (-not $propertyLookup.ContainsKey($recipientLookupKey)) {
        $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'MailRender.RecipientColumn.NotFound' -Category 'Render' -Message "Recipient column '$RecipientColumn' was not found on the row." -Target 'RecipientColumn' -RowNumber $RowNumber -ColumnName $RecipientColumn))
    }
    else {
        $recipientValidation = Test-SPRecipientValue -Value ([string]$propertyLookup[$recipientLookupKey])

        if (-not $recipientValidation.IsValid) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code "MailRender.$($recipientValidation.ErrorCode)" -Category 'Render' -Message $recipientValidation.ErrorMessage -Target 'Recipient' -RowNumber $RowNumber -ColumnName $propertyNameLookup[$recipientLookupKey]))
        }
        else {
            $recipient = $recipientValidation.NormalizedValue
        }
    }

    # ========================
    # Resolve subject.
    # ========================

    $subjectResolution = Resolve-SPPlaceholder -Text $SubjectTemplate -Values $rowValueSource
    $subject = $subjectResolution.ResolvedText

    foreach ($placeholder in $subjectResolution.UnresolvedPlaceholders) {
        $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'MailRender.Subject.PlaceholderUnresolved' -Category 'Render' -Message "Subject placeholder '$placeholder' could not be resolved for row $RowNumber." -Target 'SubjectTemplate' -RowNumber $RowNumber -ColumnName $placeholder))
    }

    # ========================
    # Resolve body.
    # ========================

    $bodyResolution = Resolve-SPPlaceholder -Text $BodyTemplate -Values $rowValueSource
    $body = $bodyResolution.ResolvedText

    foreach ($placeholder in $bodyResolution.UnresolvedPlaceholders) {
        $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'MailRender.Body.PlaceholderUnresolved' -Category 'Render' -Message "Body placeholder '$placeholder' could not be resolved for row $RowNumber." -Target 'BodyTemplate' -RowNumber $RowNumber -ColumnName $placeholder))
    }

    # ========================
    # Resolve attachments.
    # ========================

    foreach ($attachmentPath in @($AttachmentPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $attachmentValidation = Test-SPAttachmentPath -Path $attachmentPath

        if (-not $attachmentValidation.IsValid) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code "MailRender.$($attachmentValidation.ErrorCode)" -Category 'Render' -Message $attachmentValidation.ErrorMessage -Target 'AttachmentPaths' -RowNumber $RowNumber))
        }
        else {
            $resolvedAttachmentPaths.Add($attachmentValidation.ResolvedPath)
        }
    }

    # ========================
    # Resolve inline images.
    # ========================

    foreach ($inlineImage in @($InlineImages)) {
        if ($null -eq $inlineImage) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'MailRender.InlineImage.Null' -Category 'Render' -Message "Inline image definition cannot be null for row $RowNumber." -Target 'InlineImages' -RowNumber $RowNumber))
            continue
        }

        $inlinePath = [string]$inlineImage.Path
        $contentId = [string]$inlineImage.ContentId

        if ([string]::IsNullOrWhiteSpace($inlinePath)) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'MailRender.InlineImage.Path.Empty' -Category 'Render' -Message "Inline image path cannot be null, empty, or whitespace for row $RowNumber." -Target 'InlineImages' -RowNumber $RowNumber))
            continue
        }

        if ([string]::IsNullOrWhiteSpace($contentId)) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code 'MailRender.InlineImage.ContentId.Empty' -Category 'Render' -Message "Inline image ContentId cannot be null, empty, or whitespace for row $RowNumber." -Target 'InlineImages' -RowNumber $RowNumber))
            continue
        }

        $inlineValidation = Test-SPAttachmentPath -Path $inlinePath

        if (-not $inlineValidation.IsValid) {
            $issues.Add((ConvertTo-SPValidationIssue -Severity 'Error' -Code "MailRender.$($inlineValidation.ErrorCode)" -Category 'Render' -Message $inlineValidation.ErrorMessage -Target 'InlineImages' -RowNumber $RowNumber))
            continue
        }

        $resolvedInlineImages.Add(
            [pscustomobject]@{
                Path      = $inlineValidation.ResolvedPath
                ContentId = $contentId.Trim()
            }
        )
    }

    # ========================
    # Resolve render status.
    # ========================

    $status = Resolve-SPValidationStatus -Issues $issues

    return [pscustomobject]@{
        Row          = $Row
        RowNumber    = $RowNumber
        Recipient    = $recipient
        Subject      = $subject
        Body         = $body
        Attachments  = @($resolvedAttachmentPaths)
        InlineImages = @($resolvedInlineImages)
        Issues       = @($issues)
        Status       = $status
    }
}
