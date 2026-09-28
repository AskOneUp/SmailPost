function Test-SPMailReady {
    <#
        .SYNOPSIS
        Checks whether SmailPost is ready to send mail.

        .DESCRIPTION
        Test-SPMailReady performs a lightweight readiness check for the SmailPost mail engine.
        It verifies that stored Graph credentials are complete, confirms that Microsoft Graph
        app-only authentication works, and confirms that at least one allowed sender can be
        retrieved from the C-S-mailPost-Senders group.

        This command does not install, repair, or configure anything. It only reports whether
        the current environment is ready to send mail.

        .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param ()

    begin {
        # Keep a mutable notes list so helper calls always update the same collection.
        $notes = [System.Collections.Generic.List[string]]::new()

        # Build a stable result object shape so UI, CSV export, and future code can rely on it.
        $result = [ordered]@{
            Ready               = $false
            SecretReady         = $false
            GraphReady          = $false
            AllowedSendersReady = $false
            AllowedSenderCount  = 0
            Notes               = @()
        }

        # Track whether execution should stop early while still letting End emit one final object.
        $stopProcessing = $false

        function Add-ReadyNote {
            param (
                [Parameter(Mandatory = $true)]
                [string]$Message
            )

            $notes.Add($Message)
        }
    }

    process {
        #========================
        # Secret readiness
        #========================
        try {
            $secretState = Get-SPStoredSecretState

            if (-not $secretState.SecretComplete) {
                Add-ReadyNote -Message 'Stored Graph credentials are incomplete.'

                if ($secretState.Notes) {
                    foreach ($note in $secretState.Notes) {
                        Add-ReadyNote -Message $note
                    }
                }

                $stopProcessing = $true
            }
            else {
                $result.SecretReady = $true
                Add-ReadyNote -Message 'Stored Graph credentials are present.'
            }
        }
        catch {
            Add-ReadyNote -Message ("Failed to read stored Graph credentials: {0}" -f $_.Exception.Message)
            $stopProcessing = $true
        }

        if ($stopProcessing) {
            return
        }

        #========================
        # Graph readiness
        #========================
        try {
            $graphConnectionResult = Test-SPGraphConnection

            if (-not $graphConnectionResult.Success) {
                Add-ReadyNote -Message 'Microsoft Graph app-only connection test failed.'

                if ($graphConnectionResult.Notes) {
                    foreach ($note in $graphConnectionResult.Notes) {
                        Add-ReadyNote -Message $note
                    }
                }

                $stopProcessing = $true
            }
            else {
                $result.GraphReady = $true
                Add-ReadyNote -Message 'Microsoft Graph app-only connection is valid.'
            }
        }
        catch {
            Add-ReadyNote -Message ("Graph readiness check failed: {0}" -f $_.Exception.Message)
            $stopProcessing = $true
        }

        if ($stopProcessing) {
            return
        }

        #========================
        # Allowed sender readiness
        #========================
        try {
            $allowedSenders = @(Get-SPAllowedSender)

            $result.AllowedSenderCount = $allowedSenders.Count

            if ($allowedSenders.Count -le 0) {
                Add-ReadyNote -Message "No valid allowed senders were found in group 'C-S-mailPost-Senders'."
                $stopProcessing = $true
            }
            else {
                $result.AllowedSendersReady = $true
                Add-ReadyNote -Message ("Found {0} valid allowed sender(s)." -f $allowedSenders.Count)
            }
        }
        catch {
            Add-ReadyNote -Message ("Allowed sender readiness check failed: {0}" -f $_.Exception.Message)
            $stopProcessing = $true
        }
    }

    end {
        # Only mark the system ready when all three gates are green.
        if (
            $result.SecretReady -and
            $result.GraphReady -and
            $result.AllowedSendersReady
        ) {
            $result.Ready = $true
        }

        $result.Notes = @($notes)
        [pscustomobject]$result
    }
}
