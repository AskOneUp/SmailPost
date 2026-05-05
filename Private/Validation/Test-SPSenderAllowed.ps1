function Test-SPSenderAllowed {
    <#
        .SYNOPSIS
        Validates whether a sender address is allowed to send mail via SmailPost.

        .DESCRIPTION
        Test-SPSenderAllowed checks if the provided sender email address exists in the
        SmailPost-Senders group retrieved through Get-SPAllowedSender.

        The function returns a structured result indicating whether the sender is valid.

        .PARAMETER SenderAddress
        The email address that should be validated against the allowed sender list.

        .OUTPUTS
        PSCustomObject
    #>

    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SenderAddress
    )

    begin {
        $notes = [System.Collections.Generic.List[string]]::new()

        $result = [ordered]@{
            SenderAddress = $SenderAddress
            Allowed       = $false
            MatchedSender = $null
            Notes         = @()
        }

        $normalizedSenderAddress = $SenderAddress.Trim().ToLowerInvariant()
    }

    process {
        if ([string]::IsNullOrWhiteSpace($normalizedSenderAddress)) {
            $notes.Add('SenderAddress value is empty.')
            return
        }

        try {
            $allowedSenders = @(Get-SPAllowedSender)

            if ($allowedSenders.Count -eq 0) {
                $notes.Add('No allowed senders were returned from the SmailPost-Senders group.')
                return
            }

            $match = $allowedSenders | Where-Object {
                ($_.Mail -and $_.Mail.Trim().ToLowerInvariant() -eq $normalizedSenderAddress) -or
                ($_.UserPrincipalName -and $_.UserPrincipalName.Trim().ToLowerInvariant() -eq $normalizedSenderAddress)
            } | Select-Object -First 1

            if ($null -ne $match) {
                $result.Allowed = $true
                $result.MatchedSender = $match
                $notes.Add("SenderAddress '$SenderAddress' is allowed.")
            }
            else {
                $notes.Add("SenderAddress '$SenderAddress' is not in the SmailPost-Senders group.")
            }
        }
        catch {
            $notes.Add(("Sender validation failed: {0}" -f $_.Exception.Message))
        }
    }

    end {
        $result.Notes = @($notes)
        [pscustomobject]$result
    }
}
