function Test-SPPrerequisite {
    <#
        .SYNOPSIS
        Lightweight network prerequisite check for Microsoft Graph reachability.

        .DESCRIPTION
        Performs a fast HEAD probe to the specified Graph endpoint and interprets common results:
        200/401/403 → reachable; 405 → method blocked, falls back to GET via Test-SPGraphGetFallback;
        407 → proxy auth required; 429 → throttled; other codes/errors add diagnostic notes.
        Returns an object with GraphReachable (bool) and Notes (string[]).

        .PARAMETER Uri
        The endpoint to probe. Defaults to 'https://graph.microsoft.com/v1.0/'.

        .PARAMETER OperationTimeoutSeconds
        Timeout (seconds) for the HEAD request. Defaults to 10.

        .EXAMPLE
        Test-SPPrerequisite -Verbose.
        .EXAMPLE
        Test-SPPrerequisite -Uri 'https://graph.microsoft.com/v1.0/' -OperationTimeoutSeconds 10 -Verbose.
        .OUTPUTS
        System.Object.
    #>
    # Enable common parameters like -Verbose.
    [CmdletBinding()]
    # Declare that this function returns a PSCustomObject with status and notes.
    [OutputType([pscustomobject])]
    param(
        [Parameter()][ValidateNotNullOrEmpty()][string]$Uri = 'https://graph.microsoft.com/v1.0/',
        [Parameter()][ValidateRange(1, 120)][int]$OperationTimeoutSeconds = 10
    )

    # Prepare result structure.
    $result = [ordered]@{
        GraphReachable = $false
        Notes          = @()
    }

    Write-Verbose "Probing Microsoft Graph with HEAD $Uri."
    try {
        # Perform a HEAD request to quickly test reachability.
        $resp = Invoke-WebRequest -Uri $Uri -Method Head -OperationTimeoutSeconds $OperationTimeoutSeconds -ErrorAction Stop

        # Success path: treat expected codes as reachable.
        $code = [int]$resp.StatusCode
        if ($code -in 200, 401, 403) {
            $result.GraphReachable = $true
            $result.Notes += "Microsoft Graph endpoint reachable (HEAD $code)."
            Write-Verbose "HEAD returned $code (reachable)."
        }
        elseif ($code -eq 405) {
            # Method not allowed: some appliances block HEAD → fallback to GET.
            Write-Verbose "HEAD returned 405; attempting GET fallback."
            $ref = [ref]([ordered]@{ GraphReachable = $false; Notes = @() })
            Test-SPGraphGetFallback -Uri $Uri -Result $ref -PrevCode 405
            $result.GraphReachable = $ref.Value.GraphReachable
            $result.Notes += $ref.Value.Notes
        }
        elseif ($code -eq 407) {
            $result.Notes += "Proxy requires authentication (HTTP 407). Configure system proxy/credentials."
            Write-Verbose "HEAD returned 407 (proxy authentication required)."
        }
        elseif ($code -eq 429) {
            $result.Notes += "Microsoft Graph endpoint is throttling requests (HTTP 429). Wait and retry later."
            Write-Verbose "HEAD returned 429 (throttled)."
        }
        else {
            $result.Notes += "HEAD probe returned unexpected HTTP $code. Consider network, DNS, or proxy issues."
            Write-Verbose "HEAD returned unexpected HTTP $code."
        }
    }
    catch {
        # Examine the web response if present; otherwise inspect transport error.
        $resp = $_.Exception.Response
        if ($resp) {
            $code = [int]$resp.StatusCode
            if ($code -eq 405) {
                Write-Verbose "HEAD threw with 405; attempting GET fallback."
                $ref = [ref]([ordered]@{ GraphReachable = $false; Notes = @() })
                Test-SPGraphGetFallback -Uri $Uri -Result $ref -PrevCode 405
                $result.GraphReachable = $ref.Value.GraphReachable
                $result.Notes += $ref.Value.Notes
            }
            elseif ($code -in 401, 403) {
                $result.GraphReachable = $true
                $result.Notes += "Microsoft Graph endpoint reachable (HEAD $code)."
                Write-Verbose "HEAD returned $code (reachable)."
            }
            elseif ($code -eq 407) {
                $result.Notes += "Proxy requires authentication (HTTP 407). Configure system proxy/credentials (e.g., 'netsh winhttp import proxy source=ie' or use PowerShell -Proxy/-ProxyUseDefaultCredentials)."
                Write-Verbose "HEAD returned 407 (proxy authentication required)."
            }
            elseif ($code -eq 429) {
                $result.Notes += "Microsoft Graph endpoint is throttling requests (HTTP 429). Wait and retry later."
                Write-Verbose "HEAD returned 429 (throttled)."
            }
            else {
                $result.Notes += "HEAD probe returned unexpected HTTP $code. Consider network, DNS, or proxy issues."
                Write-Verbose "HEAD returned unexpected HTTP $code."
            }
        }
        else {
            $msg = $_.Exception.Message
            if ($msg -match 'NameResolution|No such host|Name or service not known') {
                $result.Notes += "Cannot reach Microsoft Graph endpoint. DNS resolution failed."
                Write-Verbose "HEAD failed: DNS resolution issue."
            }
            elseif ($msg -match 'timed out|Timeout') {
                $result.Notes += "Cannot reach Microsoft Graph endpoint. Connection timed out (firewall or proxy may be blocking)."
                Write-Verbose "HEAD failed: request timed out."
            }
            else {
                $result.Notes += "HEAD probe failed: $msg."
                Write-Verbose "HEAD failed with error: $msg."
            }

            # For transport errors (no HTTP code), a GET fallback might still succeed.
            Write-Verbose "Attempting GET fallback after transport error."
            $ref = [ref]([ordered]@{ GraphReachable = $false; Notes = @() })
            Test-SPGraphGetFallback -Uri $Uri -Result $ref -PrevCode 0
            # Merge fallback outcome.
            if ($ref.Value.Notes) { $result.Notes += $ref.Value.Notes }
            if ($ref.Value.GraphReachable) { $result.GraphReachable = $true }
        }
    }

    # Return a simple, parseable object.
    [pscustomobject]$result
}
