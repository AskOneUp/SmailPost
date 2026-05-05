Describe '_UnlockSecretStore' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Secrets\Invoke-SPSecretStoreUnlock.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Secrets\_UnlockSecretStore.ps1')
    }

    It 'Calls Invoke-SPSecretStoreUnlock exactly once' {
        Mock Invoke-SPSecretStoreUnlock {}

        _UnlockSecretStore

        Should -Invoke Invoke-SPSecretStoreUnlock -Times 1 -Exactly
    }

    It 'Does not throw when unlock succeeds' {
        Mock Invoke-SPSecretStoreUnlock {}

        { _UnlockSecretStore } | Should -Not -Throw
    }

    It 'Propagates exception when unlock fails' {
        Mock Invoke-SPSecretStoreUnlock {
            throw 'Vault locked tighter than a dragon''s hoard.'
        }

        {
            _UnlockSecretStore
        } | Should -Throw 'Vault locked tighter than a dragon''s hoard.'
    }
}
