function Invoke-SPStoreSecret {
    <#
        .SYNOPSIS
        Stores or updates a secret in the SecretStore-backed SmailPost vault.

        .DESCRIPTION
        Ensures the target SecretManagement vault (default 'SmailPost') exists and is SecretStore-backed.
        Prompts for Tenant ID and App (Client) ID, then allows the Graph client secret to be pasted once
        before immediately converting it to a SecureString. Adds metadata (Purpose, TenantID, AppID,
        CreatedOn, CreatedBy). SecretStore must be in Password mode; if locked, you may be prompted
        to unlock.

        .PARAMETER SecretName
        The logical key/name for the secret. Defaults to 'SmailPost-GraphClientSecret'.

        .PARAMETER VaultName
        The SecretManagement vault to write to. Defaults to 'SmailPost'.

        .PARAMETER TenantId
        Azure AD tenant ID. Required in unattended mode; optional in interactive mode.

        .PARAMETER AppId
        Application (client) ID. Required in unattended mode; optional in interactive mode.

        .PARAMETER Secret
        The secret value as a SecureString. Required in unattended mode; optional in interactive mode.

        .PARAMETER Unattended
        Suppresses all prompts. Requires TenantId, AppId, and Secret to be supplied.
        Fails if the SecretStore is locked.

        .PARAMETER Force
        Overwrites an existing secret without prompting. In unattended mode, Force is required
        to allow overwrite.

        .EXAMPLE
        Invoke-SPStoreSecret

        Prompts for Tenant ID and App ID, then allows the Graph client secret to be pasted once
        before storing it in the default vault.

        .EXAMPLE
        Invoke-SPStoreSecret -SecretName 'SmailPost-GraphClientSecret' -VaultName 'SmailPost' -Unattended `
            -TenantId '00000000-0000-0000-0000-000000000000' `
            -AppId '11111111-1111-1111-1111-111111111111' `
            -Secret (Read-Host 'Secret' -AsSecureString) -Force

        Runs without prompts and overwrites if the secret already exists.

        .OUTPUTS
        None. Writes to the SecretManagement vault.

        .NOTES
        Requires Microsoft.PowerShell.SecretManagement and Microsoft.PowerShell.SecretStore.
        If the vault does not exist, run setup to register it first.
    #>

    # Enable common parameters and ShouldProcess semantics.
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseCmdletCorrectly', '',
        Justification = 'We only surface guidance for Unlock-SecretStore; interactive usage handled by user.'
    )]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'Interactive client secret entry intentionally accepts pasted plaintext and immediately converts it to SecureString.'
    )]
    param (
        # Target vault and secret naming.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$VaultName = 'SmailPost',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SecretName = 'SmailPost-GraphClientSecret',

        # Optional inputs for interactive use; required in unattended mode.
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [string]$AppId,

        [Parameter()]
        [SecureString]$Secret,

        # Behavior switches.
        [Parameter()]
        [switch]$Unattended,

        [Parameter()]
        [switch]$Force
    )

    # Check module prerequisites early.
    Write-Verbose "Checking SecretManagement modules."
    $smok = Get-Module -ListAvailable Microsoft.PowerShell.SecretManagement
    $ssok = Get-Module -ListAvailable Microsoft.PowerShell.SecretStore

    if (-not $smok -or -not $ssok) {
        throw "Secret modules missing. Please run Test-SPEnvironment or Install-SPDependency first."
    }

    # Verify vault registration and backend.
    Write-Verbose "Checking whether vault '$VaultName' exists and is SecretStore-backed."
    $vault = Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue

    if (-not $vault) {
        if ($WhatIfPreference) {
            Write-Verbose "WhatIf: vault '$VaultName' not registered; would fail here. Run Invoke-SPSetup without -WhatIf."
            return
        }

        throw @"
Vault '$VaultName' not found.
→ If your SecretStore is in Password mode: first run Unlock-SecretStore, then rerun Invoke-SPSetup to auto-register the vault.
→ Or register it manually with:
Register-SecretVault -Name '$VaultName' -ModuleName Microsoft.PowerShell.SecretStore
"@
    }

    if ($vault.ModuleName -ne 'Microsoft.PowerShell.SecretStore') {
        throw "Vault '$VaultName' is not using SecretStore backend. Aborting."
    }

    # Ensure SecretStore is in password mode.
    Write-Verbose "Checking SecretStore configuration (must be Password mode)."
    $cfg = Get-SecretStoreConfiguration

    if ($cfg.Authentication -ne 'Password') {
        throw "SecretStore is not in Password mode. Set it with: Set-SecretStoreConfiguration -Authentication Password -Interaction Required."
    }

    # Provide a transcription warning without exposing secret data.
    if ($Host -and $Host.Name) {
        Write-Verbose "Host: $($Host.Name). If PowerShell transcription is enabled, pause it before entering credentials."
    }

    # Short-circuit WhatIf before collecting credentials.
    if ($WhatIfPreference) {
        Write-Verbose "WhatIf: would collect TenantId/AppId and store secret '$SecretName' in vault '$VaultName'."
        return
    }

    # Validate unattended input before any prompting can occur.
    if ($Unattended) {
        if (
            [string]::IsNullOrWhiteSpace($TenantId) -or
            [string]::IsNullOrWhiteSpace($AppId) -or
            -not $Secret
        ) {
            throw "Unattended mode requires TenantId, AppId, and Secret to be provided."
        }
    }

    # Collect identifiers interactively when they were not supplied.
    if (-not $Unattended) {
        if ([string]::IsNullOrWhiteSpace($TenantId)) {
            $TenantId = Read-Host "Enter Tenant ID (from admin)"
        }

        if ([string]::IsNullOrWhiteSpace($AppId)) {
            $AppId = Read-Host "Enter app (Client) ID (from admin)"
        }

        if (
            [string]::IsNullOrWhiteSpace($TenantId) -or
            [string]::IsNullOrWhiteSpace($AppId)
        ) {
            throw "Tenant ID and App ID are required."
        }
    }

    # Collect the Graph client secret interactively when it was not supplied.
    if (-not $Secret) {
        if ($Unattended) {
            throw "Unattended mode does not allow prompting for the secret. Provide -Secret as a SecureString."
        }

        Write-Information -MessageData "" -InformationAction Continue
        Write-Information -MessageData "Paste the Graph client secret below." -InformationAction Continue
        Write-Information -MessageData "The value will be converted to a SecureString immediately after entry." -InformationAction Continue

        # Read the generated Entra client secret once so clipboard paste works normally.
        $plainSecret = Read-Host "Graph client secret"

        if ([string]::IsNullOrWhiteSpace($plainSecret)) {
            throw "Graph client secret cannot be empty."
        }

        try {
            # Convert the pasted value immediately to a SecureString.
            $Secret = ConvertTo-SecureString -String $plainSecret -AsPlainText -Force
        }
        finally {
            # Remove the temporary plaintext reference as soon as conversion is complete.
            $plainSecret = $null
        }

        # Compute a fingerprint for confirmation without displaying the secret.
        $fp1 = Get-SPStringSha256 -Secure $Secret
        Write-Verbose "Secret converted to SecureString; fingerprint computed for summary."
    }
    else {
        # Compute the fingerprint when a SecureString was supplied directly.
        $fp1 = Get-SPStringSha256 -Secure $Secret
        Write-Verbose "Secret value provided via parameter; computed fingerprint for summary."
    }

    # Apply overwrite policy.
    $exists = Get-SecretInfo -Name $SecretName -Vault $VaultName -ErrorAction SilentlyContinue

    if ($exists) {
        if ($Unattended -and -not $Force) {
            throw "Secret '$SecretName' already exists. Use -Force to overwrite in unattended mode."
        }

        if (-not $Unattended -and -not $Force) {
            $ans = Read-Host "Secret '$SecretName' already exists. Overwrite? (Y/N)"

            if ($ans -notin @('Y', 'y')) {
                throw "Aborted by user; secret unchanged."
            }

            Write-Verbose "User approved overwrite."
        }
    }

    # Determine whether the SecretStore is currently locked.
    $locked = $false

    if ($cfg.Authentication -eq 'Password') {
        try {
            Get-SecretInfo -Vault $VaultName -Name '*' -ErrorAction Stop | Out-Null
        }
        catch {
            if ($_.Exception.Message -match 'locked|Unlock-SecretStore|password') {
                $locked = $true
            }
        }
    }

    # Unlock interactively when required; unattended execution fails closed.
    if ($locked) {
        if ($Unattended) {
            throw "SecretStore is locked. Unlock the store before running with -Unattended."
        }

        Unlock-SecretStore
    }

    # Save the secret and its metadata.
    if ($PSCmdlet.ShouldProcess(
            "$VaultName/$SecretName",
            ($exists ? "Update secret" : "Create secret")
        )) {
        Set-Secret -Name $SecretName -Vault $VaultName -Secret $Secret -Metadata @{
            Purpose   = 'Graph Mail.Send'
            TenantID  = $TenantId
            AppID     = $AppId
            CreatedOn = [DateTime]::UtcNow.ToString('u')
            CreatedBy = $env:USERNAME
        }

        # Verify that the stored secret can be retrieved.
        Write-Verbose "Secret stored. Verifying retrieval (may prompt for vault password)."

        try {
            $null = Get-Secret -Name $SecretName -Vault $VaultName
            Write-Verbose "Retrieval OK."
        }
        finally {
            Write-Verbose "Vault will auto-lock after $($cfg.PasswordTimeout) seconds."
        }
    }

    # Display a safe summary without exposing the secret value.
    Write-Information -MessageData ""
    Write-Information -MessageData "✅  Secret saved as '$SecretName' in vault '$VaultName'." -InformationAction Continue
    Write-Information -MessageData "    Tenant: $TenantId" -InformationAction Continue
    Write-Information -MessageData "    AppID : $AppId" -InformationAction Continue
    Write-Information -MessageData "    Secret fingerprint: $fp1" -InformationAction Continue
    Write-Information -MessageData "🔒  Vault relocked." -InformationAction Continue
    Write-Information -MessageData "    Next step: rerun Invoke-SPSetup to validate Graph authentication." -InformationAction Continue

    # Clear temporary credential references from the function scope.
    $fp1 = $null
    $Secret = $null
    [System.GC]::Collect() | Out-Null
}
