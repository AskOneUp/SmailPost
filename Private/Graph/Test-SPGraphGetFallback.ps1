function Test-SPGraphGetFallback {
    <#
        .SYNOPSIS
        GET fallback check for Microsoft Graph reachability.

        .DESCRIPTION
        Used after a failed/blocked HEAD probe. Sends a lightweight GET to the provided Uri
        (default used by caller is https://graph.microsoft.com/v1.0/). Updates the supplied
        [ref] hashtable with:
        - GraphReachable (bool)
        - Notes (string[])
        Considers 200/401/403 as “reachable”. Uses -OperationTimeoutSeconds for reliability.

        .PARAMETER Uri
        The endpoint to probe (e.g. 'https://graph.microsoft.com/v1.0/').

        .PARAMETER Result
        [ref] to an ordered hashtable with keys GraphReachable (bool) and Notes (string[]).
        This function mutates that object instead of returning a value.

        .PARAMETER PrevCode
        Optional prior HEAD status code to include in notes.

        .EXAMPLE
        $r = [ordered]@{ GraphReachable = $false; Notes = @() }
        Test-SPGraphGetFallback -Uri 'https://graph.microsoft.com/v1.0/' -Result ([ref]$r) -Verbose
        $r

        .OUTPUTS
        None. Updates the referenced hashtable.

        .NOTES
        Uses Invoke-WebRequest -Method GET -OperationTimeoutSeconds 10.
    #>

    # Enable common parameters like -Verbose.
    [CmdletBinding()]
    # Declare that this function emits no pipeline output (updates the referenced hashtable).
    [OutputType([void])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Uri,   # The endpoint to GET.
        [Parameter(Mandatory)][ref]$Result,                             # Reference to the result hashtable.
        [int]$PrevCode                                                  # Optional prior HEAD status to mention.
    )

    # Ensure the Notes list exists to safely append messages.
    if (-not $Result.Value.Notes) { $Result.Value.Notes = @() }

    Write-Verbose "Attempting GET $Uri as fallback."
    try {
        # Attempt GET on /v1.0/ – should return 200 (public) or 401/403 (unauthorized/forbidden) if reachable.
        Invoke-WebRequest -Uri $Uri -Method Get -OperationTimeoutSeconds 10 -ErrorAction Stop | Out-Null

        # Success path: mark reachable and record a concise note.
        $Result.Value.GraphReachable = $true
        $Result.Value.Notes += "Microsoft Graph endpoint reachable (GET fallback succeeded)."
        Write-Verbose "GET fallback succeeded."
    }
    catch {
        # Inspect HTTP response if available.
        $resp2 = $_.Exception.Response
        if ($resp2) {
            $code2 = [int]$resp2.StatusCode

            if ($code2 -in 401, 403) {
                # Expected unauthenticated responses still prove reachability.
                $Result.Value.GraphReachable = $true
                $Result.Value.Notes += "Microsoft Graph endpoint reachable (GET fallback returned $code2)."
                Write-Verbose "GET fallback returned $code2 (reachable via expected response)."
            }
            elseif ($code2 -eq 407) {
                # Proxy demands authentication.
                $Result.Value.Notes += "Proxy requires authentication (HTTP 407). Configure system proxy/credentials (e.g. run 'netsh winhttp import proxy source=ie' or use PowerShell -Proxy/-ProxyUseDefaultCredentials)."
                Write-Verbose "GET fallback returned 407 (proxy authentication required)."
            }
            elseif ($code2 -eq 429) {
                # Service is throttling requests.
                $Result.Value.Notes += "Microsoft Graph endpoint is throttling requests (HTTP 429). Wait and retry later."
                Write-Verbose "GET fallback returned 429 (throttled by Microsoft Graph)."
            }
            else {
                # Unexpected HTTP status (e.g., 500/502/503/504).
                $Result.Value.Notes += "Cannot reach Microsoft Graph endpoint. HEAD HTTP $PrevCode → GET fallback HTTP $code2. Check network, DNS, or proxy."
                Write-Verbose "GET fallback returned unexpected HTTP $code2."
            }
        }
        else {
            # Transport-level errors without an HTTP response.
            $msg = $_.Exception.Message
            if ($msg -match 'NameResolution|No such host|Name or service not known') {
                $Result.Value.Notes += "Cannot reach Microsoft Graph endpoint. DNS resolution failed."
                Write-Verbose "GET fallback failed: DNS resolution issue."
            }
            elseif ($msg -match 'timed out|Timeout') {
                $Result.Value.Notes += "Cannot reach Microsoft Graph endpoint. Connection timed out (firewall or proxy may be blocking)."
                Write-Verbose "GET fallback failed: Request timed out."
            }
            else {
                $Result.Value.Notes += "Cannot reach Microsoft Graph endpoint. Details (GET fallback): $msg."
                Write-Verbose "GET fallback failed with error: $msg."
            }
        }
    }
}
