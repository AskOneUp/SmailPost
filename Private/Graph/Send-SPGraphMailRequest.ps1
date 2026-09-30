function Send-SPGraphMailRequest {
    <#
        .SYNOPSIS
        Sends a prepared mail payload to Microsoft Graph.

        .DESCRIPTION
        Send-SPGraphMailRequest sends an already prepared Microsoft Graph sendMail payload
        for a specific sender mailbox. The function acquires an app-only access token,
        converts the payload to JSON, submits the request to Microsoft Graph, and returns
        a structured result describing whether the request was accepted.

        Microsoft Graph throttling responses with status code 429 are retried automatically.
        When Microsoft Graph supplies a valid Retry-After value, that delay is respected
        and the request is retried. When no usable Retry-After value is available, the
        function uses exponential backoff delays of 2, 4, 8, 16, 32, and 64 seconds.
        After the fallback sequence is exhausted, one final request is made before the
        request is returned as failed.

        .PARAMETER SenderAddress
        The sender mailbox address used in the Graph /users/{sender}/sendMail endpoint.

        .PARAMETER Payload
        The prepared PowerShell payload object for Microsoft Graph sendMail.

        .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SenderAddress,

        [Parameter(Mandatory = $true)]
        [hashtable]$Payload
    )

    begin {
        $result = [ordered]@{
            Success      = $false
            StatusCode   = 0
            ErrorMessage = ''
            RequestUri   = ''
            Notes        = @()
        }

        function Add-TransportNote {
            param (
                [Parameter(Mandatory = $true)]
                [string]$Message
            )

            $result.Notes += $Message
        }
    }

    process {
        if ([string]::IsNullOrWhiteSpace($SenderAddress)) {
            throw 'SenderAddress cannot be null, empty, or whitespace.'
        }

        if ($null -eq $Payload -or $Payload.Count -eq 0) {
            throw 'Payload cannot be null or empty.'
        }

        $normalizedSenderAddress = $SenderAddress.Trim()
        $encodedSenderAddress = [System.Uri]::EscapeDataString($normalizedSenderAddress)
        $requestUri = "https://graph.microsoft.com/v1.0/users/$encodedSenderAddress/sendMail"

        $result.RequestUri = $requestUri

        try {
            # ========================
            # Acquire and validate the structured token result.
            # ========================
            $tokenResult = Get-SPGraphAccessToken

            if ($null -eq $tokenResult) {
                throw 'Failed to acquire a Microsoft Graph access token result.'
            }

            if (-not $tokenResult.Success) {
                $tokenNotes = (@($tokenResult.Notes) | Where-Object {
                        -not [string]::IsNullOrWhiteSpace($_)
                    }) -join ' '

                if ([string]::IsNullOrWhiteSpace($tokenNotes)) {
                    throw 'Failed to acquire a Microsoft Graph access token.'
                }

                throw "Failed to acquire a Microsoft Graph access token. $tokenNotes"
            }

            $accessToken = [string]$tokenResult.AccessToken

            if ([string]::IsNullOrWhiteSpace($accessToken)) {
                throw 'Token result did not contain an access token.'
            }

            Add-TransportNote -Message ("RequestUri: {0}" -f $requestUri)
            Add-TransportNote -Message ("SenderAddress input: {0}" -f $normalizedSenderAddress)
            Add-TransportNote -Message ("Token audience: {0}" -f $tokenResult.Audience)
            Add-TransportNote -Message ("Token app id: {0}" -f $tokenResult.AppId)
            Add-TransportNote -Message ("Token roles: {0}" -f (($tokenResult.Roles -join ', ')))

            # ========================
            # Prepare the Graph request.
            # ========================
            $jsonBody = $Payload | ConvertTo-Json -Depth 10

            $headers = @{
                Authorization  = "Bearer $accessToken"
                'Content-Type' = 'application/json'
            }

            # ========================
            # Send the Graph request with throttling retry support.
            # ========================
            $fallbackDelays = @(2, 4, 8, 16, 32, 64)
            $fallbackIndex = 0
            $attempt = 0
            $requestCompleted = $false

            while (-not $requestCompleted) {
                $attempt++

                try {
                    $response = Invoke-WebRequest `
                        -Method Post `
                        -Uri $requestUri `
                        -Headers $headers `
                        -Body $jsonBody `
                        -ErrorAction Stop

                    $result.Success = $true
                    $result.StatusCode = [int]$response.StatusCode
                    $result.ErrorMessage = ''
                    $requestCompleted = $true

                    Add-TransportNote -Message (
                        "Microsoft Graph accepted the sendMail request for sender '{0}'." -f
                        $normalizedSenderAddress
                    )
                }
                catch {
                    $requestError = $_
                    $statusCode = 0

                    if ($requestError.Exception.Response) {
                        try {
                            $statusCode = [int]$requestError.Exception.Response.StatusCode
                        }
                        catch {
                            $statusCode = 0
                        }
                    }

                    # ========================
                    # Only status code 429 is retryable.
                    # ========================
                    if ($statusCode -ne 429) {
                        throw $requestError
                    }

                    $retryAfterSeconds = 0
                    $hasValidRetryAfter = $false
                    $retryAfterValues = $null

                    # ========================
                    # Read Retry-After from HttpResponseHeaders.
                    # ========================
                    try {
                        $hasRetryAfterHeader =
                        $requestError.Exception.Response.Headers.TryGetValues(
                            'Retry-After',
                            [ref]$retryAfterValues
                        )

                        if ($hasRetryAfterHeader) {
                            $retryAfterValue = @($retryAfterValues)[0]
                            $parsedRetryAfter = 0

                            if (
                                [int]::TryParse(
                                    [string]$retryAfterValue,
                                    [ref]$parsedRetryAfter
                                ) -and
                                $parsedRetryAfter -gt 0
                            ) {
                                $retryAfterSeconds = $parsedRetryAfter
                                $hasValidRetryAfter = $true
                            }
                        }
                    }
                    catch {
                        $hasValidRetryAfter = $false
                    }

                    # ========================
                    # Graph supplied a usable Retry-After.
                    # Respect it without consuming the fallback sequence.
                    # ========================
                    if ($hasValidRetryAfter) {
                        Add-TransportNote -Message (
                            "Microsoft Graph throttled sendMail attempt {0}. Retrying after {1} second(s) as requested by Retry-After." -f
                            $attempt,
                            $retryAfterSeconds
                        )

                        Start-Sleep -Seconds $retryAfterSeconds
                        continue
                    }

                    # ========================
                    # No usable Retry-After.
                    # Use the finite exponential fallback sequence.
                    # ========================
                    if ($fallbackIndex -ge $fallbackDelays.Count) {
                        Add-TransportNote -Message (
                            "Microsoft Graph throttled sendMail attempt {0}. The fallback retry sequence is exhausted." -f
                            $attempt
                        )

                        throw $requestError
                    }

                    $retryAfterSeconds = $fallbackDelays[$fallbackIndex]
                    $fallbackIndex++

                    Add-TransportNote -Message (
                        "Microsoft Graph throttled sendMail attempt {0}. No usable Retry-After value was supplied. Retrying after {1} second(s)." -f
                        $attempt,
                        $retryAfterSeconds
                    )

                    Start-Sleep -Seconds $retryAfterSeconds
                }
            }
        }
        catch {
            $statusCode = 0
            $errorMessage = $_.Exception.Message
            $responseBody = ''

            if ($_.Exception.Response) {
                try {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }
                catch {
                    $statusCode = 0
                }

                try {
                    $streamReader = [System.IO.StreamReader]::new(
                        $_.Exception.Response.GetResponseStream()
                    )

                    $responseBody = $streamReader.ReadToEnd()
                    $streamReader.Dispose()
                }
                catch {
                    $responseBody = ''
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($responseBody)) {
                $errorMessage = "$errorMessage Response body: $responseBody"
            }

            $result.StatusCode = $statusCode
            $result.ErrorMessage = $errorMessage

            Add-TransportNote -Message (
                "Microsoft Graph sendMail request failed for sender '{0}'." -f
                $normalizedSenderAddress
            )

            if (-not [string]::IsNullOrWhiteSpace($errorMessage)) {
                Add-TransportNote -Message $errorMessage
            }
        }
    }

    end {
        [pscustomobject]$result
    }
}
