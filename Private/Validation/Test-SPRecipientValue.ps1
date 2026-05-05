function Test-SPRecipientValue {

    <#
.SYNOPSIS
Validates a recipient email value.

.DESCRIPTION
Checks whether a recipient value is present, not empty after trimming,
and in a valid email address format.

This function is used during row-level preflight validation after the
user has selected the recipient column.

.PARAMETER Value
The recipient value to validate.

.OUTPUTS
PSCustomObject

Returns an object containing:
- OriginalValue
- NormalizedValue
- IsValid
- ErrorCode
- ErrorMessage

.NOTES
Private SmailPost function.
Used by row-level validation before preview or sending.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value
    )

    $normalizedValue = ''

    if ($null -ne $Value) {
        $normalizedValue = $Value.Trim()
    }

    if ([string]::IsNullOrWhiteSpace($normalizedValue)) {
        return [pscustomobject]@{
            OriginalValue   = $Value
            NormalizedValue = $normalizedValue
            IsValid         = $false
            ErrorCode       = 'RECIPIENT_EMPTY'
            ErrorMessage    = 'Recipient value is empty.'
        }
    }

    $isValidEmail = $false

    try {
        $mailAddress = [System.Net.Mail.MailAddress]::new($normalizedValue)

        if ($mailAddress.Address -eq $normalizedValue) {
            $isValidEmail = $true
        }
    }
    catch {
        $isValidEmail = $false
    }

    if (-not $isValidEmail) {
        return [pscustomobject]@{
            OriginalValue   = $Value
            NormalizedValue = $normalizedValue
            IsValid         = $false
            ErrorCode       = 'RECIPIENT_INVALID_EMAIL'
            ErrorMessage    = 'Recipient value is not a valid email address.'
        }
    }

    return [pscustomobject]@{
        OriginalValue   = $Value
        NormalizedValue = $normalizedValue
        IsValid         = $true
        ErrorCode       = ''
        ErrorMessage    = ''
    }
}
