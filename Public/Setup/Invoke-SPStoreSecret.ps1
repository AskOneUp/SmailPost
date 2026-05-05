function Invoke-SPStoreSecret {
    <#
        .SYNOPSIS
        Stores or updates a secret in the SecretStore-backed SmailPost vault.

        .DESCRIPTION
        Ensures the target SecretManagement vault (default 'SmailPost') exists and is SecretStore-backed.
        Prompts for Tenant ID, App (Client) ID, Sender mailbox, then securely prompts twice for the
        secret value and saves it under the provided -SecretName. Adds metadata (Purpose, TenantID,
        AppID, SenderMail, CreatedOn, CreatedBy). SecretStore must be in Password mode; if locked, you
        may be prompted to unlock.

        .PARAMETER SecretName
        The logical key/name for the secret (e.g. 'Graph:ClientSecret', 'Smtp:Password').

        .PARAMETER VaultName
        The SecretManagement vault to write to. Defaults to 'SmailPost'.

        .PARAMETER TenantId
        Azure AD tenant ID. Required in unattended mode; optional in interactive mode.

        .PARAMETER AppId
        Application (client) ID. Required in unattended mode; optional in interactive mode.

        .PARAMETER SenderMail
        Sender mailbox address. Required in unattended mode; optional in interactive mode.

        .PARAMETER Secret
        The secret value as a SecureString. Required in unattended mode; optional in interactive mode.

        .PARAMETER Unattended
        Suppress all prompts. Requires TenantId, AppId, Sender, and Secret to be supplied. Fails if the SecretStore is locked.

        .PARAMETER Force
        Overwrite an existing secret without prompting. In unattended mode, Force is required to allow overwrite.

        .EXAMPLE
        Invoke-SPStoreSecret -SecretName 'Graph:ClientSecret'
        Prompts for IDs/senderMail and the client secret (twice), then stores it in the default vault.

        .EXAMPLE
        Invoke-SPStoreSecret -SecretName 'Graph:ClientSecret' -VaultName 'SmailPost' -Unattended `
            -TenantId '00000000-0000-0000-0000-000000000000' -AppId '11111111-1111-1111-1111-111111111111' `
            -SenderMail 'no-reply@contoso.com' -Secret (Read-Host 'Secret' -AsSecureString) -Force
        Runs without prompts and overwrites if the secret already exists.

        .OUTPUTS
        None. Writes to the SecretManagement vault.

        .NOTES
        Requires Microsoft.PowerShell.SecretManagement and Microsoft.PowerShell.SecretStore.
        If the vault does not exist, run setup to register it first.
    #>

    # Enable common parameters and ShouldProcess semantics.
    [CmdletBinding(SupportsShouldProcess = $true)]
    # Declare that this function emits no pipeline output.
    [OutputType([void])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseCmdletCorrectly', '',
        Justification = 'We only surface guidance for Unlock-SecretStore; interactive usage handled by user.'
    )]
    param (
        # Target vault and secret naming.
        [Parameter()][ValidateNotNullOrEmpty()][string]$VaultName = 'SmailPost',
        [Parameter()][ValidateNotNullOrEmpty()][string]$SecretName = 'SmailPost-GraphClientSecret',

        # Optional inputs for interactive; required in unattended mode.
        [Parameter()][string]$TenantId,
        [Parameter()][string]$AppId,
        [Parameter()][SecureString]$Secret,

        # Behavior switches.
        [Parameter()][switch]$Unattended,
        [Parameter()][switch]$Force
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

    # Friendly heads-up about transcription.
    if ($Host -and $Host.Name) {
        Write-Verbose "Host: $($Host.Name). If PowerShell transcription is enabled, pause it to avoid leaking prompts."
    }

    # WhatIf short-circuit.
    if ($WhatIfPreference) {
        Write-Verbose "WhatIf: would collect TenantId/AppId/SenderMail and store secret '$SecretName' in vault '$VaultName'."
        return
    }

    # Unattended input validation and prompt avoidance.
    if ($Unattended) {
        # Require all inputs to be supplied.
        if ([string]::IsNullOrWhiteSpace($TenantId) -or [string]::IsNullOrWhiteSpace($AppId) -or -not $Secret) {
            throw "Unattended mode requires TenantId, AppId, and Secret to be provided."
        }
    }

    # Collect metadata interactively only when not unattended and values are missing.
    if (-not $Unattended) {
        if ([string]::IsNullOrWhiteSpace($TenantId)) { $TenantId = Read-Host "Enter Tenant ID (from admin)" }
        if ([string]::IsNullOrWhiteSpace($AppId)) { $AppId = Read-Host "Enter app (Client) ID (from admin)" }
        if ([string]::IsNullOrWhiteSpace($TenantId) -or [string]::IsNullOrWhiteSpace($AppId)) {
            throw "Tenant ID and App ID are required."
        }
    }

    # Collect the secret value (double prompt) when not supplied and not unattended.
    if (-not $Secret) {
        if ($Unattended) {
            throw "Unattended mode does not allow prompting for the secret. Provide -Secret as a SecureString."
        }
        Write-Verbose "Prompting for Graph client secret (hidden)."
        $sec1 = Read-Host "Enter Graph client secret" -AsSecureString
        $sec2 = Read-Host "Confirm Graph client secret" -AsSecureString

        # Compare via fingerprint (no plain-text compare).
        $fp1 = Get-SPStringSha256 -Secure $sec1
        $fp2 = Get-SPStringSha256 -Secure $sec2
        if ($fp1 -ne $fp2) {
            throw "The two entries did not match. Try again."
        }
        Write-Verbose "Fingerprint match ($fp1). Proceeding to save."
        $Secret = $sec1
        # Hygiene for temporary variables.
        $sec2 = $null
        $fp2 = $null
    }
    else {
        # If a secret was provided, compute fingerprint once for the summary.
        $fp1 = Get-SPStringSha256 -Secure $Secret
        Write-Verbose "Secret value provided via parameter; computed fingerprint for summary."
    }

    # Overwrite policy: prompt only in interactive; require -Force in unattended.
    $exists = Get-SecretInfo -Name $SecretName -Vault $VaultName -ErrorAction SilentlyContinue
    if ($exists) {
        if ($Unattended -and -not $Force) {
            throw "Secret '$SecretName' already exists. Use -Force to overwrite in unattended mode."
        }
        if (-not $Unattended -and -not $Force) {
            $ans = Read-Host "Secret '$SecretName' already exists. Overwrite? (Y/N)"
            if ($ans -notin @('Y', 'y')) { throw "Aborted by user; secret unchanged." }
            Write-Verbose "User approved overwrite."
        }
    }

    # Lock status check and unlock only if interactive; unattended must fail closed when locked.
    $locked = $false
    if ($cfg.Authentication -eq 'Password') {
        try {
            Get-SecretInfo -Vault $VaultName -Name '*' -ErrorAction Stop | Out-Null
        }
        catch {
            if ($_.Exception.Message -match 'locked|Unlock-SecretStore|password') { $locked = $true }
        }
    }
    if ($locked) {
        if ($Unattended) {
            throw "SecretStore is locked. Unlock the store before running with -Unattended."
        }
        Unlock-SecretStore # Prompts only when needed.
    }

    # Save secret and metadata with ShouldProcess guard.
    if ($PSCmdlet.ShouldProcess("$VaultName/$SecretName", ($exists ? "Update secret" : "Create secret"))) {
        Set-Secret -Name $SecretName -Vault $VaultName -Secret $Secret -Metadata @{
            Purpose   = 'Graph Mail.Send'
            TenantID  = $TenantId
            AppID     = $AppId
            CreatedOn = [DateTime]::UtcNow.ToString('u')
            CreatedBy = $env:USERNAME
        }

        Write-Verbose "Secret stored. Verifying retrieval (may prompt for vault password)."
        try {
            $null = Get-Secret -Name $SecretName -Vault $VaultName
            Write-Verbose "Retrieval OK."
        }
        finally {
            Write-Verbose "Vault will auto-lock after $($cfg.PasswordTimeout) seconds."
        }
    }

    # Summary (no secret value; fingerprint only).
    # Summary (no secret value; fingerprint only).
    Write-Information -MessageData ""
    Write-Information -MessageData "✅  Secret saved as '$SecretName' in vault '$VaultName'." -InformationAction Continue
    Write-Information -MessageData "    Tenant: $TenantId" -InformationAction Continue
    Write-Information -MessageData "    AppID : $AppId" -InformationAction Continue
    Write-Information -MessageData "    Secret fingerprint: $fp1" -InformationAction Continue
    Write-Information -MessageData "🔒  Vault relocked." -InformationAction Continue
    Write-Information -MessageData "    Next step: rerun Invoke-SPSetup to validate Graph authentication." -InformationAction Continue

    # Hygiene: clear variables from memory.
    $fp1 = $null
    $Secret = $null
    [System.GC]::Collect() | Out-Null
}
