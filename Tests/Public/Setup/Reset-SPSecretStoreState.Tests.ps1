Describe 'Reset-SPSecretStoreState' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        function Get-TestShimSecretVault {
            [CmdletBinding()]
            param([string]$Name)

            $null = $Name
        }

        function Get-TestShimSecretInfo {
            [CmdletBinding()]
            param(
                [string]$Vault,
                [string]$Name
            )

            $null = $Vault
            $null = $Name
        }

        function Remove-TestShimSecret {
            [CmdletBinding(SupportsShouldProcess = $true)]
            param(
                [string]$Vault,
                [string]$Name
            )

            $null = $Vault
            $null = $Name
            $null = $PSCmdlet.ShouldProcess('TestShim', 'Remove')
        }

        function Unregister-TestShimSecretVault {
            [CmdletBinding(SupportsShouldProcess = $true)]
            param([string]$Name)

            $null = $Name
            $null = $PSCmdlet.ShouldProcess('TestShim', 'Unregister')
        }

        Set-Alias -Name Get-SecretVault -Value Get-TestShimSecretVault -Scope Local
        Set-Alias -Name Get-SecretInfo -Value Get-TestShimSecretInfo -Scope Local
        Set-Alias -Name Remove-Secret -Value Remove-TestShimSecret -Scope Local
        Set-Alias -Name Unregister-SecretVault -Value Unregister-TestShimSecretVault -Scope Local

        . (Join-Path $script:ModuleRoot 'Public\Setup\Reset-SPSecretStoreState.ps1')
    }

    BeforeEach {
        Mock Get-Command {
            [pscustomobject]@{
                Name = 'Get-SecretVault'
            }
        } -ParameterFilter {
            $Name -eq 'Get-SecretVault'
        }

        Mock Get-SecretVault {
            [pscustomobject]@{
                Name       = 'SmailPost'
                ModuleName = 'Microsoft.PowerShell.SecretStore'
            }
        }

        Mock Get-SecretInfo {
            [pscustomobject]@{
                Name = 'SmailPost-GraphClientSecret'
            }
        }

        Mock Remove-Secret {}
        Mock Unregister-SecretVault {}
    }

    Context 'Command availability' {
        It 'Returns failure when SecretManagement commands are not available' {
            Mock Get-Command {
                $null
            } -ParameterFilter {
                $Name -eq 'Get-SecretVault'
            }

            $result = Reset-SPSecretStoreState

            $result.Success | Should -BeFalse
            $result.VaultExisted | Should -BeFalse
            $result.SecretExisted | Should -BeFalse
            $result.SecretRemoved | Should -BeFalse
            $result.VaultRemoved | Should -BeFalse

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'SecretManagement commands are not available.'
        }
    }

    Context 'Vault handling' {
        It 'Returns success when the vault does not exist' {
            Mock Get-SecretVault {
                $null
            }

            $result = Reset-SPSecretStoreState

            $result.Success | Should -BeTrue
            $result.VaultExisted | Should -BeFalse
            $result.SecretExisted | Should -BeFalse
            $result.SecretRemoved | Should -BeFalse
            $result.VaultRemoved | Should -BeFalse

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 2
            $result.Notes[0] | Should -Be "Vault 'SmailPost' does not exist."
            $result.Notes[1] | Should -Be 'Nothing to reset.'
        }

        It 'Removes vault when it exists and secret does not exist' {
            Mock Get-SecretInfo {
                $null
            }

            $result = Reset-SPSecretStoreState

            $result.Success | Should -BeTrue
            $result.VaultExisted | Should -BeTrue
            $result.SecretExisted | Should -BeFalse
            $result.SecretRemoved | Should -BeFalse
            $result.VaultRemoved | Should -BeTrue

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 3
            $result.Notes[0] | Should -Be "Vault 'SmailPost' exists."
            $result.Notes[1] | Should -Be "Secret 'SmailPost-GraphClientSecret' does not exist."
            $result.Notes[2] | Should -Be "Vault 'SmailPost' unregistered."

            Should -Invoke -CommandName Remove-Secret -Times 0
            Should -Invoke -CommandName Unregister-SecretVault -Times 1
        }
    }

    Context 'Secret handling' {
        It 'Removes secret and vault when both exist' {
            $result = Reset-SPSecretStoreState

            $result.Success | Should -BeTrue
            $result.VaultExisted | Should -BeTrue
            $result.SecretExisted | Should -BeTrue
            $result.SecretRemoved | Should -BeTrue
            $result.VaultRemoved | Should -BeTrue

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 4
            $result.Notes[0] | Should -Be "Vault 'SmailPost' exists."
            $result.Notes[1] | Should -Be "Secret 'SmailPost-GraphClientSecret' exists."
            $result.Notes[2] | Should -Be "Secret 'SmailPost-GraphClientSecret' removed."
            $result.Notes[3] | Should -Be "Vault 'SmailPost' unregistered."

            Should -Invoke -CommandName Remove-Secret -Times 1
            Should -Invoke -CommandName Unregister-SecretVault -Times 1
        }

        It 'Treats secret lookup errors as secret missing' {
            Mock Get-SecretInfo {
                throw [System.Exception]::new('Vault locked.')
            }

            $result = Reset-SPSecretStoreState

            $result.Success | Should -BeTrue
            $result.VaultExisted | Should -BeTrue
            $result.SecretExisted | Should -BeFalse
            $result.SecretRemoved | Should -BeFalse
            $result.VaultRemoved | Should -BeTrue

            ($result.Notes -join '|') | Should -Match "Secret 'SmailPost-GraphClientSecret' does not exist."
        }
    }

    Context 'Failure handling' {
        It 'Returns failure when removing secret throws' {
            Mock Remove-Secret {
                throw [System.Exception]::new('Remove failed.')
            }

            $result = Reset-SPSecretStoreState

            $result.Success | Should -BeFalse
            $result.VaultExisted | Should -BeTrue
            $result.SecretExisted | Should -BeTrue
            $result.SecretRemoved | Should -BeFalse
            $result.VaultRemoved | Should -BeFalse

            ($result.Notes -join '|') | Should -Match 'Reset failed: Remove failed.'
        }

        It 'Returns failure when unregistering vault throws' {
            Mock Unregister-SecretVault {
                throw [System.Exception]::new('Unregister failed.')
            }

            $result = Reset-SPSecretStoreState

            $result.Success | Should -BeFalse
            $result.VaultExisted | Should -BeTrue
            $result.SecretExisted | Should -BeTrue
            $result.SecretRemoved | Should -BeTrue
            $result.VaultRemoved | Should -BeFalse

            ($result.Notes -join '|') | Should -Match 'Reset failed: Unregister failed.'
        }
    }

    Context 'WhatIf behavior' {
        It 'Does not remove secret or vault during WhatIf' {
            $result = Reset-SPSecretStoreState -WhatIf

            $result.Success | Should -BeTrue
            $result.VaultExisted | Should -BeTrue
            $result.SecretExisted | Should -BeTrue
            $result.SecretRemoved | Should -BeFalse
            $result.VaultRemoved | Should -BeFalse

            Should -Invoke -CommandName Remove-Secret -Times 0
            Should -Invoke -CommandName Unregister-SecretVault -Times 0
        }
    }
}
