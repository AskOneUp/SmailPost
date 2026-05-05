Describe 'Get-SPStoredSecretState' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        if (-not (Get-Command Get-SecretVault -ErrorAction SilentlyContinue)) {
            function Get-SecretVault {
            }
        }

        if (-not (Get-Command Get-SecretInfo -ErrorAction SilentlyContinue)) {
            function Get-SecretInfo {
            }
        }

        . (Join-Path $script:ModuleRoot 'Private\Secrets\Get-SPStoredSecretState.ps1')
    }

    BeforeEach {
        Mock Get-SecretVault {
            [pscustomobject]@{
                Name = 'SmailPost'
            }
        }

        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = 'tenant-123'
                    AppID    = 'app-456'
                }
            }
        }
    }

    It 'Returns incomplete state when vault does not exist' {
        Mock Get-SecretVault {
            $null
        }

        $result = Get-SPStoredSecretState

        $result.SecretPresent | Should -BeFalse
        $result.MetadataPresent | Should -BeFalse
        $result.SecretComplete | Should -BeFalse
        $result.MissingMetadata.Count | Should -Be 2
        $result.MissingMetadata | Should -Contain 'TenantID'
        $result.MissingMetadata | Should -Contain 'AppID'
        $result.Notes | Should -Contain "Vault 'SmailPost' not found."

        Should -Invoke Get-SecretVault -Times 1 -Exactly
        Should -Invoke Get-SecretInfo -Times 0 -Exactly
    }

    It 'Returns incomplete state when secret does not exist in vault' {
        Mock Get-SecretInfo {
            throw 'Secret not found.'
        }

        $result = Get-SPStoredSecretState

        $result.SecretPresent | Should -BeFalse
        $result.MetadataPresent | Should -BeFalse
        $result.SecretComplete | Should -BeFalse
        $result.MissingMetadata.Count | Should -Be 2
        $result.MissingMetadata | Should -Contain 'TenantID'
        $result.MissingMetadata | Should -Contain 'AppID'
        $result.Notes | Should -Contain "Secret 'SmailPost-GraphClientSecret' not found in vault 'SmailPost'."

        Should -Invoke Get-SecretVault -Times 1 -Exactly
        Should -Invoke Get-SecretInfo -Times 1 -Exactly
    }

    It 'Returns incomplete state when secret exists but has no metadata' {
        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = $null
            }
        }

        $result = Get-SPStoredSecretState

        $result.SecretPresent | Should -BeTrue
        $result.MetadataPresent | Should -BeFalse
        $result.SecretComplete | Should -BeFalse
        $result.MissingMetadata.Count | Should -Be 2
        $result.MissingMetadata | Should -Contain 'TenantID'
        $result.MissingMetadata | Should -Contain 'AppID'
        $result.Notes | Should -Contain "Secret 'SmailPost-GraphClientSecret' exists but has no metadata."
    }

    It 'Returns incomplete state when required metadata fields are missing or empty' {
        Mock Get-SecretInfo {
            [pscustomobject]@{
                Metadata = @{
                    TenantID = ''
                    AppID    = 'app-456'
                }
            }
        }

        $result = Get-SPStoredSecretState

        $result.SecretPresent | Should -BeTrue
        $result.MetadataPresent | Should -BeFalse
        $result.SecretComplete | Should -BeFalse
        $result.MissingMetadata.Count | Should -Be 1
        $result.MissingMetadata | Should -Contain 'TenantID'
        $result.Notes | Should -Contain "Metadata field 'TenantID' is missing or empty on secret 'SmailPost-GraphClientSecret'."
    }

    It 'Returns complete state when secret exists and required metadata is present' {
        $result = Get-SPStoredSecretState

        $result.SecretPresent | Should -BeTrue
        $result.MetadataPresent | Should -BeTrue
        $result.SecretComplete | Should -BeTrue
        $result.MissingMetadata.Count | Should -Be 0
        $result.Notes | Should -Contain "Secret 'SmailPost-GraphClientSecret' exists and required metadata is present."

        Should -Invoke Get-SecretVault -Times 1 -Exactly
        Should -Invoke Get-SecretInfo -Times 1 -Exactly
    }

    It 'Uses supplied VaultName and SecretName values' {
        $null = Get-SPStoredSecretState -VaultName 'CustomVault' -SecretName 'CustomSecret'

        Should -Invoke Get-SecretVault -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'CustomVault'
        }

        Should -Invoke Get-SecretInfo -Times 1 -Exactly -ParameterFilter {
            $Vault -eq 'CustomVault' -and $Name -eq 'CustomSecret'
        }
    }
}
