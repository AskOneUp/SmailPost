function Invoke-SPSecretStoreUnlock {
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseCmdletCorrectly', '',
        Justification = 'Cmdlet is interactive by design; no params needed.')]
    param()

    Unlock-SecretStore
}
