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
        The Retry-After response header is respected when available. A maximum of five
        request attempts is made before the request is returned as failed.

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
            $maxAttempts = 5
            $attempt = 0
            $requestCompleted = $false

            while (-not $requestCompleted -and $attempt -lt $maxAttempts) {
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
                    # Retry throttled requests when attempts remain.
                    # ========================
                    if ($statusCode -eq 429 -and $attempt -lt $maxAttempts) {
                        $retryAfterSeconds = 1

                        try {
                            $retryAfterValue = $requestError.Exception.Response.Headers['Retry-After']

                            if (-not [string]::IsNullOrWhiteSpace([string]$retryAfterValue)) {
                                $parsedRetryAfter = 0

                                if (
                                    [int]::TryParse(
                                        [string]$retryAfterValue,
                                        [ref]$parsedRetryAfter
                                    ) -and
                                    $parsedRetryAfter -gt 0
                                ) {
                                    $retryAfterSeconds = $parsedRetryAfter
                                }
                            }
                        }
                        catch {
                            $retryAfterSeconds = 1
                        }

                        Add-TransportNote -Message (
                            "Microsoft Graph throttled sendMail attempt {0} of {1}. Retrying after {2} second(s)." -f
                            $attempt,
                            $maxAttempts,
                            $retryAfterSeconds
                        )

                        Start-Sleep -Seconds $retryAfterSeconds
                        continue
                    }

                    throw $requestError
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
