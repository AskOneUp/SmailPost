function Test-SPRecipientAddress {
    <#
        .SYNOPSIS
        Validates and normalizes a recipient email address.

        .DESCRIPTION
        Test-SPRecipientAddress trims the supplied recipient value, checks that it is not
        null, empty, or whitespace, and performs a basic email address validation.

        The function returns a structured result that indicates whether the address is valid
        and provides the normalized recipient value when validation succeeds.

        .PARAMETER Recipient
        The recipient email address to validate.

        .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Recipient
    )

    $notes = @()

    $result = [ordered]@{
        Recipient           = $Recipient
        NormalizedRecipient = ''
        Valid               = $false
        Notes               = @()
    }

    if ($null -eq $Recipient) {
        $notes += 'Recipient value is null.'
        $result.Notes = $notes
        return [pscustomobject]$result
    }

    $normalizedRecipient = $Recipient.Trim()

    if ([string]::IsNullOrWhiteSpace($normalizedRecipient)) {
        $notes += 'Recipient value is empty or whitespace.'
        $result.Notes = $notes
        return [pscustomobject]$result
    }

    try {
        $mailAddress = [System.Net.Mail.MailAddress]::new($normalizedRecipient)

        if ($mailAddress.Address -ne $normalizedRecipient) {
            $notes += ("Recipient address '{0}' is not in a clean email format." -f $normalizedRecipient)
            $result.Notes = $notes
            return [pscustomobject]$result
        }

        $result.NormalizedRecipient = $mailAddress.Address
        $result.Valid = $true
        $notes += ("Recipient address '{0}' is valid." -f $mailAddress.Address)
    }
    catch {
        $notes += ("Recipient address '{0}' is invalid: {1}" -f $normalizedRecipient, $_.Exception.Message)
    }

    $result.Notes = $notes
    return [pscustomobject]$result
}
