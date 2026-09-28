Describe 'Invoke-SPSecretStoreUnlock' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        function Unlock-TestShimSecretStore {
            [CmdletBinding()]
            param()
        }

        Set-Alias -Name Unlock-SecretStore -Value Unlock-TestShimSecretStore -Scope Local

        . (Join-Path $script:ModuleRoot 'Private\Secrets\Invoke-SPSecretStoreUnlock.ps1')
    }

    BeforeEach {
        Mock Unlock-SecretStore {}
    }

    Context 'Basic behavior' {
        It 'Calls Unlock-SecretStore when invoked' {
            Invoke-SPSecretStoreUnlock

            Should -Invoke -CommandName Unlock-SecretStore -Times 1 -Exactly
        }
    }

    Context 'Error propagation' {
        It 'Throws when Unlock-SecretStore fails' {
            Mock Unlock-SecretStore {
                throw [System.Exception]::new('Unlock failed.')
            }

            {
                Invoke-SPSecretStoreUnlock
            } | Should -Throw 'Unlock failed.'
        }
    }
}
