function _UnlockSecretStore {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseCmdletCorrectly', '',
        Justification = 'Cmdlet is interactive by design; no params needed.')]
    param()

    Invoke-SPSecretStoreUnlock
}
