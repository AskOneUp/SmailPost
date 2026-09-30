function ConvertTo-SPGraphMailPayload {
    <#
        .SYNOPSIS
        Builds the Microsoft Graph sendMail payload for one recipient.

        .DESCRIPTION
        ConvertTo-SPGraphMailPayload creates the PowerShell object that will later be converted to JSON
        and sent to the Microsoft Graph sendMail endpoint.

        The payload is built for exactly one recipient and can optionally include a BCC recipient
        and file attachments.

        .PARAMETER Recipient
        The email address of the recipient.

        .PARAMETER Subject
        The subject of the email message.

        .PARAMETER HtmlBody
        The HTML body of the email message.

        .PARAMETER BccAddress
        Optional BCC email address that receives a blind copy of the message.

        .PARAMETER Attachments
        Optional Microsoft Graph attachment objects.

        .PARAMETER SaveToSentItems
        Indicates whether the sent message should be saved in Sent Items.

        .OUTPUTS
        Hashtable
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Recipient,

        [Parameter(Mandatory = $true)]
        [string]$Subject,

        [Parameter(Mandatory = $true)]
        [string]$HtmlBody,

        [Parameter()]
        [string]$BccAddress,

        [Parameter()]
        [object[]]$Attachments = @(),

        [Parameter()]
        [bool]$SaveToSentItems = $true
    )

    process {
        if ([string]::IsNullOrWhiteSpace($Recipient)) {
            throw 'Recipient cannot be null, empty, or whitespace.'
        }

        if ([string]::IsNullOrWhiteSpace($Subject)) {
            throw 'Subject cannot be null, empty, or whitespace.'
        }

        if ([string]::IsNullOrWhiteSpace($HtmlBody)) {
            throw 'HtmlBody cannot be null, empty, or whitespace.'
        }

        $message = @{
            subject      = $Subject
            body         = @{
                contentType = 'HTML'
                content     = $HtmlBody
            }
            toRecipients = @(
                @{
                    emailAddress = @{
                        address = $Recipient.Trim()
                    }
                }
            )
        }

        # Add the BCC recipient only when an address was supplied.
        if (-not [string]::IsNullOrWhiteSpace($BccAddress)) {
            $message.bccRecipients = @(
                @{
                    emailAddress = @{
                        address = $BccAddress.Trim()
                    }
                }
            )
        }

        # Add attachments only when attachments were supplied.
        if ($Attachments -and $Attachments.Count -gt 0) {
            $message.attachments = @($Attachments)
        }

        return @{
            message         = $message
            saveToSentItems = $SaveToSentItems
        }
    }
}
