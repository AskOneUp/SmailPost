function Reset-SPSecretStoreState {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    # ========================
    # Define fixed names and initialize the result object.
    # ========================
    $vaultName = 'SmailPost'
    $secretName = 'SmailPost-GraphClientSecret'
    $notes = [System.Collections.Generic.List[string]]::new()

    $result = [PSCustomObject]@{
        Success       = $false
        VaultExisted  = $false
        SecretExisted = $false
        SecretRemoved = $false
        VaultRemoved  = $false
        Notes         = @()
    }

    try {
        # ========================
        # Guard: SecretManagement command availability.
        # ========================
        if (-not (Get-Command Get-SecretVault -ErrorAction SilentlyContinue)) {
            $notes.Add('SecretManagement commands are not available.')
            $result.Notes = $notes.ToArray()
            return $result
        }

        $vault = Get-SecretVault -Name $vaultName -ErrorAction SilentlyContinue

        if ($null -eq $vault) {
            $notes.Add("Vault '$vaultName' does not exist.")
            $notes.Add('Nothing to reset.')
            $result.Success = $true
            $result.Notes = $notes.ToArray()
            return $result
        }

        $result.VaultExisted = $true
        $notes.Add("Vault '$vaultName' exists.")

        # ========================
        # Attempt to determine whether the secret exists.
        # ========================
        try {
            $secretInfo = Get-SecretInfo -Vault $vaultName -Name $secretName -ErrorAction Stop
        }
        catch {
            $secretInfo = $null
        }

        if ($null -ne $secretInfo) {
            $result.SecretExisted = $true
            $notes.Add("Secret '$secretName' exists.")

            if ($PSCmdlet.ShouldProcess($secretName, "Remove secret from vault '$vaultName'")) {
                Remove-Secret -Vault $vaultName -Name $secretName -ErrorAction Stop
                $result.SecretRemoved = $true
                $notes.Add("Secret '$secretName' removed.")
            }
        }
        else {
            $notes.Add("Secret '$secretName' does not exist.")
        }

        # ========================
        # Unregister the SmailPost vault.
        # ========================
        if ($PSCmdlet.ShouldProcess($vaultName, 'Unregister SecretStore vault')) {
            Unregister-SecretVault -Name $vaultName -ErrorAction Stop
            $result.VaultRemoved = $true
            $notes.Add("Vault '$vaultName' unregistered.")
        }

        $result.Success = $true
        $result.Notes = $notes.ToArray()
        return $result
    }
    catch {
        $notes.Add("Reset failed: $($_.Exception.Message)")
        $result.Notes = $notes.ToArray()
        return $result
    }
}
