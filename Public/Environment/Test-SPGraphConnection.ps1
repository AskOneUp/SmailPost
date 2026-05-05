function Test-SPGraphConnection {
    <#
        .SYNOPSIS
        Validates Microsoft Graph app-only connectivity for SmailPost.

        .DESCRIPTION
        Reads the SmailPost Graph client secret from the SecretManagement vault,
        retrieves TenantID and AppID from the secret metadata, requests an app-only
        Microsoft Graph access token, checks required roles in the token, and performs
        a lightweight Graph API call to confirm tenant connectivity.

        .OUTPUTS
        PSCustomObject with connection status details.
    #>

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $vaultName = 'SmailPost'
    $secretName = 'SmailPost-GraphClientSecret'

    $requiredRoles = @(
        'Mail.Send',
        'GroupMember.Read.All',
        'User.Read.All'
    )

    $result = [ordered]@{
        Success           = $false
        TokenAcquired     = $false
        GraphConnected    = $false
        TenantId          = ''
        TenantDisplayName = ''
        RolesPresent      = @()
        MissingRoles      = @()
        TokenExpiresOn    = $null
        Notes             = @()
    }

    function ConvertFrom-SPBase64Url {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Value
        )

        $padded = $Value.Replace('-', '+').Replace('_', '/')
        switch ($padded.Length % 4) {
            2 { $padded += '==' }
            3 { $padded += '=' }
            0 { }
            default { throw "Invalid Base64Url string length." }
        }

        $bytes = [System.Convert]::FromBase64String($padded)
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    }

    function ConvertTo-SPPlainText {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory)]
            [SecureString]$SecureValue
        )

        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
        try {
            return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        }
        finally {
            if ($bstr -ne [IntPtr]::Zero) {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
        }
    }

    try {
        Write-Verbose "Reading secret info for '$secretName' from vault '$vaultName'."
        $secretInfo = Get-SecretInfo -Vault $vaultName -Name $secretName -ErrorAction Stop

        if (-not $secretInfo) {
            $result.Notes += "Secret '$secretName' not found in vault '$vaultName'."
            return [pscustomobject]$result
        }

        $metadata = $secretInfo.Metadata
        if (-not $metadata) {
            $result.Notes += "Secret '$secretName' exists but metadata is missing."
            return [pscustomobject]$result
        }

        $tenantId = [string]$metadata['TenantID']
        $appId = [string]$metadata['AppID']

        if ([string]::IsNullOrWhiteSpace($tenantId)) {
            $result.Notes += "Metadata field 'TenantID' is missing or empty on secret '$secretName'."
        }

        if ([string]::IsNullOrWhiteSpace($appId)) {
            $result.Notes += "Metadata field 'AppID' is missing or empty on secret '$secretName'."
        }

        if ([string]::IsNullOrWhiteSpace($tenantId) -or [string]::IsNullOrWhiteSpace($appId)) {
            return [pscustomobject]$result
        }

        $result.TenantId = $tenantId

        Write-Verbose "Reading secure secret value from vault."
        $secureSecret = Get-Secret -Vault $vaultName -Name $secretName -ErrorAction Stop

        if (-not ($secureSecret -is [SecureString])) {
            $result.Notes += "Secret '$secretName' is not stored as a SecureString."
            return [pscustomobject]$result
        }

        $plainClientSecret = ConvertTo-SPPlainText -SecureValue $secureSecret
        if ([string]::IsNullOrWhiteSpace($plainClientSecret)) {
            $result.Notes += "Secret '$secretName' exists but the value is empty."
            return [pscustomobject]$result
        }

        $tokenUri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

        $tokenBody = @{
            client_id     = $appId
            client_secret = $plainClientSecret
            scope         = 'https://graph.microsoft.com/.default'
            grant_type    = 'client_credentials'
        }

        Write-Verbose "Requesting Microsoft Graph app-only token."
        $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUri -Body $tokenBody -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace($tokenResponse.access_token)) {
            $result.Notes += "Token endpoint returned no access token."
            return [pscustomobject]$result
        }

        $result.TokenAcquired = $true
        $result.Notes += "Access token acquired successfully."

        if ($tokenResponse.expires_in) {
            $result.TokenExpiresOn = (Get-Date).AddSeconds([int]$tokenResponse.expires_in)
        }

        $tokenParts = $tokenResponse.access_token -split '\.'
        if ($tokenParts.Count -lt 2) {
            $result.Notes += "Access token format is invalid."
            return [pscustomobject]$result
        }

        $payloadJson = ConvertFrom-SPBase64Url -Value $tokenParts[1]
        $payload = $payloadJson | ConvertFrom-Json -ErrorAction Stop

        $tokenRoles = @($payload.roles)
        $result.RolesPresent = $tokenRoles

        $missingRoles = $requiredRoles | Where-Object { $_ -notin $tokenRoles }
        $result.MissingRoles = $missingRoles

        if ($missingRoles.Count -gt 0) {
            $result.Notes += "Token is missing required application roles: $($missingRoles -join ', ')."
        }
        else {
            $result.Notes += "All required application roles are present in the token."
        }

        $graphHeaders = @{
            Authorization = "Bearer $($tokenResponse.access_token)"
        }

        $orgUri = 'https://graph.microsoft.com/v1.0/organization?$select=id,displayName'

        Write-Verbose "Calling Microsoft Graph organization endpoint."
        $orgResponse = Invoke-RestMethod -Method Get -Uri $orgUri -Headers $graphHeaders -ErrorAction Stop

        if ($orgResponse.value -and $orgResponse.value.Count -ge 1) {
            $result.GraphConnected = $true
            $result.TenantDisplayName = [string]$orgResponse.value[0].displayName
            $result.Notes += "Connected to Microsoft Graph tenant '$($result.TenantDisplayName)'."
        }
        else {
            $result.Notes += "Organization call succeeded but returned no tenant data."
        }

        if ($result.TokenAcquired -and $result.GraphConnected -and $result.MissingRoles.Count -eq 0) {
            $result.Success = $true
        }

        return [pscustomobject]$result
    }
    catch {
        $message = $_.Exception.Message

        if ($_.Exception.Response) {
            try {
                $statusCode = [int]$_.Exception.Response.StatusCode
                $result.Notes += "Graph connection test failed with HTTP $statusCode : $message"
            }
            catch {
                $result.Notes += "Graph connection test failed: $message"
            }
        }
        else {
            $result.Notes += "Graph connection test failed: $message"
        }

        return [pscustomobject]$result
    }
    finally {
        if (Get-Variable -Name plainClientSecret -ErrorAction SilentlyContinue) {
            $plainClientSecret = $null
        }
        if (Get-Variable -Name secureSecret -ErrorAction SilentlyContinue) {
            $secureSecret = $null
        }
    }
}
