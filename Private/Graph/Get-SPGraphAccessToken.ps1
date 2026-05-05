function Get-SPGraphAccessToken {
    [CmdletBinding()]
    param()

    # ========================
    # Define fixed names and initialize the default result object.
    # ========================
    $vaultName = 'SmailPost'
    $secretName = 'SmailPost-GraphClientSecret'
    $notes = [System.Collections.Generic.List[string]]::new()

    $result = [PSCustomObject]@{
        Success          = $false
        AccessToken      = $null
        TokenType        = $null
        ExpiresOn        = $null
        ExpiresInSeconds = 0
        TenantId         = $null
        AppId            = $null
        Audience         = $null
        Issuer           = $null
        Roles            = @()
        SecretPresent    = $false
        MetadataPresent  = $false
        MetadataComplete = $false
        Notes            = @()
    }

    try {
        # ========================
        # Read the stored secret state first so we can fail early with a stable object shape.
        # ========================
        $secretState = Get-SPStoredSecretState

        if ($null -eq $secretState) {
            $notes.Add('Stored secret state could not be determined.')
            $result.Notes = $notes.ToArray()
            return $result
        }

        $result.SecretPresent = [bool]$secretState.SecretPresent
        $result.MetadataPresent = [bool]$secretState.MetadataPresent
        $result.MetadataComplete = [bool]$secretState.MetadataComplete

        if (-not $result.SecretPresent) {
            $notes.Add('Stored secret was not found.')
            $result.Notes = $notes.ToArray()
            return $result
        }

        $notes.Add('Stored secret found.')

        if (-not $result.MetadataPresent) {
            $notes.Add('Secret metadata was not found.')
            $result.Notes = $notes.ToArray()
            return $result
        }

        $notes.Add('Secret metadata found.')

        # ========================
        # Read the secret info including metadata from SecretManagement.
        # ========================
        $secretInfo = Get-SecretInfo -Vault $vaultName -Name $secretName -ErrorAction Stop

        if ($null -eq $secretInfo) {
            $notes.Add('Secret info could not be retrieved.')
            $result.Notes = $notes.ToArray()
            return $result
        }

        $metadata = $secretInfo.Metadata

        if ($null -eq $metadata) {
            $notes.Add('Metadata is missing from the stored secret.')
            $result.Notes = $notes.ToArray()
            return $result
        }

        $tenantId = [string]$metadata.TenantID
        $appId = [string]$metadata.AppID

        $result.TenantId = $tenantId
        $result.AppId = $appId

        # ========================
        # Validate only the metadata required for token acquisition.
        # ========================
        $missingRequiredMetadata = [System.Collections.Generic.List[string]]::new()

        if ([string]::IsNullOrWhiteSpace($tenantId)) {
            $missingRequiredMetadata.Add('TenantID')
        }

        if ([string]::IsNullOrWhiteSpace($appId)) {
            $missingRequiredMetadata.Add('AppID')
        }

        if ($missingRequiredMetadata.Count -gt 0) {
            $result.MetadataComplete = $false
            $notes.Add('Metadata is present but incomplete.')

            foreach ($field in $missingRequiredMetadata) {
                $notes.Add("Required metadata field $field is missing.")
            }

            $notes.Add('Access token request was not attempted.')
            $result.Notes = $notes.ToArray()
            return $result
        }

        $result.MetadataComplete = $true
        $notes.Add('Required metadata present.')

        # ========================
        # Retrieve the stored client secret as SecureString.
        # ========================
        $secureClientSecret = Get-Secret -Vault $vaultName -Name $secretName -AsPlainText:$false -ErrorAction Stop

        if ($null -eq $secureClientSecret) {
            $notes.Add('Stored client secret could not be retrieved.')
            $result.Notes = $notes.ToArray()
            return $result
        }

        if ($secureClientSecret -isnot [securestring]) {
            $notes.Add('Stored client secret is not a SecureString.')
            $result.Notes = $notes.ToArray()
            return $result
        }

        # ========================
        # Convert the SecureString to plain text only for the token request.
        # ========================
        $plainClientSecret = $null
        $bstr = [System.IntPtr]::Zero

        try {
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureClientSecret)
            $plainClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        }
        finally {
            if ($bstr -ne [System.IntPtr]::Zero) {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
        }

        if ([string]::IsNullOrWhiteSpace($plainClientSecret)) {
            $notes.Add('Stored client secret is empty after conversion.')
            $result.Notes = $notes.ToArray()
            return $result
        }

        # ========================
        # Request an app-only access token for Microsoft Graph.
        # ========================
        $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

        $body = @{
            client_id     = $appId
            client_secret = $plainClientSecret
            scope         = 'https://graph.microsoft.com/.default'
            grant_type    = 'client_credentials'
        }

        $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop

        if ($null -eq $tokenResponse) {
            $notes.Add('Token endpoint returned no response.')
            $result.Notes = $notes.ToArray()
            return $result
        }

        $result.AccessToken = [string]$tokenResponse.access_token
        $result.TokenType = [string]$tokenResponse.token_type

        if ($tokenResponse.expires_in) {
            $result.ExpiresInSeconds = [int]$tokenResponse.expires_in
        }

        if ([string]::IsNullOrWhiteSpace($result.AccessToken)) {
            $notes.Add('Token endpoint did not return an access token.')
            $result.Notes = $notes.ToArray()
            return $result
        }

        $notes.Add('Access token acquired successfully.')

        # ========================
        # Decode the JWT payload so downstream callers can inspect claims without another request.
        # ========================
        $tokenParts = $result.AccessToken -split '\.'

        if ($tokenParts.Count -lt 2) {
            $notes.Add('Access token was acquired but is not a valid JWT format.')
            $result.Success = $true
            $result.Notes = $notes.ToArray()
            return $result
        }

        $payloadPart = $tokenParts[1]
        $payloadPart = $payloadPart.Replace('-', '+').Replace('_', '/')

        switch ($payloadPart.Length % 4) {
            2 {
                $payloadPart += '=='
            }
            3 {
                $payloadPart += '='
            }
        }

        $payloadBytes = [System.Convert]::FromBase64String($payloadPart)
        $payloadJson = [System.Text.Encoding]::UTF8.GetString($payloadBytes)
        $payload = $payloadJson | ConvertFrom-Json -ErrorAction Stop

        $notes.Add('Token payload decoded successfully.')

        if (-not [string]::IsNullOrWhiteSpace([string]$payload.tid)) {
            $result.TenantId = [string]$payload.tid
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$payload.appid)) {
            $result.AppId = [string]$payload.appid
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$payload.aud)) {
            $result.Audience = [string]$payload.aud
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$payload.iss)) {
            $result.Issuer = [string]$payload.iss
        }

        if ($null -ne $payload.exp) {
            $epoch = [datetime]'1970-01-01T00:00:00Z'
            $result.ExpiresOn = $epoch.AddSeconds([double]$payload.exp).ToLocalTime()
        }
        elseif ($result.ExpiresInSeconds -gt 0) {
            $result.ExpiresOn = (Get-Date).AddSeconds($result.ExpiresInSeconds)
        }

        if ($null -ne $payload.roles) {
            if ($payload.roles -is [System.Array]) {
                $result.Roles = @($payload.roles | ForEach-Object { [string]$_ })
            }
            else {
                $result.Roles = @([string]$payload.roles)
            }
        }
        else {
            $result.Roles = @()
            $notes.Add('Token does not contain a roles claim.')
        }

        $result.Success = $true
        $result.Notes = $notes.ToArray()
        return $result
    }
    catch {
        # ========================
        # Return a stable failure object with a readable error note.
        # ========================
        $notes.Add("Access token request failed: $($_.Exception.Message)")
        $result.Notes = $notes.ToArray()
        return $result
    }
    finally {
        # ========================
        # Clear plain text secret material as best effort.
        # ========================
        if (Get-Variable -Name plainClientSecret -Scope Local -ErrorAction SilentlyContinue) {
            $plainClientSecret = $null
        }
    }
}
