Describe 'Invoke-SPStoreSecret' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        function Get-SPStringSha256 {
            [CmdletBinding()]
            param(
                [SecureString]$Secure
            )

            $null = $Secure
        }

        function Unlock-TestShimSecretStore {
            [CmdletBinding()]
            param(
                [SecureString]$Password
            )

            $null = $Password
        }

        Set-Alias -Name Unlock-SecretStore -Value Unlock-TestShimSecretStore -Scope Local

        . (Join-Path $script:ModuleRoot 'Public\Setup\Invoke-SPStoreSecret.ps1')
    }

    BeforeEach {
        $script:SetSecretCalls = 0
        $script:Metadata = $null

        $script:SecureSecret = [System.Security.SecureString]::new()
        $script:SecureSecret.AppendChar('s')
        $script:SecureSecret.AppendChar('e')
        $script:SecureSecret.AppendChar('c')
        $script:SecureSecret.AppendChar('r')
        $script:SecureSecret.AppendChar('e')
        $script:SecureSecret.AppendChar('t')
        $script:SecureSecret.MakeReadOnly()

        Mock Get-Module {
            [pscustomobject]@{
                Name = $Name
            }
        } -ParameterFilter {
            $ListAvailable -and $Name -in @(
                'Microsoft.PowerShell.SecretManagement',
                'Microsoft.PowerShell.SecretStore'
            )
        }

        Mock Get-SecretVault {
            [pscustomobject]@{
                Name       = 'SmailPost'
                ModuleName = 'Microsoft.PowerShell.SecretStore'
            }
        }

        Mock Get-SecretStoreConfiguration {
            [pscustomobject]@{
                Authentication  = 'Password'
                PasswordTimeout = 900
            }
        }

        Mock Get-SPStringSha256 {
            'hash-value'
        }

        Mock Get-SecretInfo {
            $null
        }

        Mock Unlock-SecretStore {}

        Mock Set-Secret {
            $script:SetSecretCalls++
            $script:Metadata = $Metadata
        }

        Mock Get-Secret {
            $script:SecureSecret
        }

        Mock Read-Host {}
    }

    Context 'Prerequisite validation' {
        It 'Throws when required secret modules are missing' {
            Mock Get-Module {
                if ($Name -eq 'Microsoft.PowerShell.SecretManagement') {
                    return $null
                }

                if ($Name -eq 'Microsoft.PowerShell.SecretStore') {
                    return $null
                }
            } -ParameterFilter {
                $ListAvailable -and
                $Name -in @(
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            {
                Invoke-SPStoreSecret -Unattended -TenantId 'tenant' -AppId 'app' -Secret $script:SecureSecret -Force
            } | Should -Throw 'Secret modules missing. Please run Test-SPEnvironment or Install-SPDependency first.'
        }

        It 'Returns during WhatIf when the vault is missing' {
            Mock Get-SecretVault {
                $null
            }

            Invoke-SPStoreSecret -Unattended -TenantId 'tenant' -AppId 'app' -Secret $script:SecureSecret -Force -WhatIf

            Assert-MockCalled Set-Secret -Times 0
        }

        It 'Throws when the vault is missing outside WhatIf' {
            Mock Get-SecretVault {
                $null
            }

            {
                Invoke-SPStoreSecret -Unattended -TenantId 'tenant' -AppId 'app' -Secret $script:SecureSecret -Force
            } | Should -Throw "*Vault 'SmailPost' not found.*"
        }

        It 'Throws when the vault is not SecretStore-backed' {
            Mock Get-SecretVault {
                [pscustomobject]@{
                    Name       = 'SmailPost'
                    ModuleName = 'Other.Backend'
                }
            }

            {
                Invoke-SPStoreSecret -Unattended -TenantId 'tenant' -AppId 'app' -Secret $script:SecureSecret -Force
            } | Should -Throw "Vault 'SmailPost' is not using SecretStore backend. Aborting."
        }

        It 'Throws when SecretStore is not in Password mode' {
            Mock Get-SecretStoreConfiguration {
                [pscustomobject]@{
                    Authentication = 'None'
                }
            }

            {
                Invoke-SPStoreSecret -Unattended -TenantId 'tenant' -AppId 'app' -Secret $script:SecureSecret -Force
            } | Should -Throw 'SecretStore is not in Password mode.*'
        }
    }

    Context 'Unattended validation' {
        It 'Throws when unattended mode is missing TenantId' {
            {
                Invoke-SPStoreSecret -Unattended -AppId 'app' -Secret $script:SecureSecret -Force
            } | Should -Throw 'Unattended mode requires TenantId, AppId, and Secret to be provided.'
        }

        It 'Throws when unattended mode is missing AppId' {
            {
                Invoke-SPStoreSecret -Unattended -TenantId 'tenant' -Secret $script:SecureSecret -Force
            } | Should -Throw 'Unattended mode requires TenantId, AppId, and Secret to be provided.'
        }

        It 'Throws when unattended mode is missing Secret' {
            {
                Invoke-SPStoreSecret -Unattended -TenantId 'tenant' -AppId 'app' -Force
            } | Should -Throw 'Unattended mode requires TenantId, AppId, and Secret to be provided.'
        }
    }

    Context 'Overwrite behavior' {
        It 'Throws when secret exists in unattended mode without Force' {
            Mock Get-SecretInfo {
                [pscustomobject]@{
                    Name = 'SmailPost-GraphClientSecret'
                }
            } -ParameterFilter {
                $Name -eq 'SmailPost-GraphClientSecret'
            }

            {
                Invoke-SPStoreSecret -Unattended -TenantId 'tenant' -AppId 'app' -Secret $script:SecureSecret
            } | Should -Throw "Secret 'SmailPost-GraphClientSecret' already exists. Use -Force to overwrite in unattended mode."
        }

        It 'Stores the secret when secret exists and Force is used' {
            Mock Get-SecretInfo {
                if ($Name -eq 'SmailPost-GraphClientSecret') {
                    [pscustomobject]@{
                        Name = 'SmailPost-GraphClientSecret'
                    }
                }
            }

            Invoke-SPStoreSecret -Unattended -TenantId 'tenant' -AppId 'app' -Secret $script:SecureSecret -Force

            $script:SetSecretCalls | Should -Be 1
        }
    }

    Context 'Lock handling' {
        It 'Throws when SecretStore is locked in unattended mode' {
            Mock Get-SecretInfo {
                throw [System.Exception]::new('SecretStore is locked. Run Unlock-SecretStore.')
            } -ParameterFilter {
                $Name -eq '*'
            }

            {
                Invoke-SPStoreSecret -Unattended -TenantId 'tenant' -AppId 'app' -Secret $script:SecureSecret -Force
            } | Should -Throw 'SecretStore is locked. Unlock the store before running with -Unattended.'
        }

        It 'Unlocks SecretStore when locked in interactive mode' {
            Mock Get-SecretInfo {
                throw [System.Exception]::new('SecretStore is locked. Run Unlock-SecretStore.')
            } -ParameterFilter {
                $Name -eq '*'
            }

            Mock Read-Host {
                if ($Prompt -like '*Tenant*') { return 'tenant' }
                if ($Prompt -like '*Client*') { return 'app' }
                return 'Y'
            }

            Invoke-SPStoreSecret -Secret $script:SecureSecret -Force

            Assert-MockCalled Unlock-SecretStore -Times 1
            $script:SetSecretCalls | Should -Be 1
        }
    }

    Context 'Store behavior' {
        It 'Stores secret with expected metadata in unattended mode' {
            Invoke-SPStoreSecret -Unattended -TenantId 'tenant-id' -AppId 'app-id' -Secret $script:SecureSecret -Force

            $script:SetSecretCalls | Should -Be 1

            $script:Metadata.Purpose | Should -Be 'Graph Mail.Send'
            $script:Metadata.TenantID | Should -Be 'tenant-id'
            $script:Metadata.AppID | Should -Be 'app-id'
            $null -eq $script:Metadata.CreatedOn | Should -BeFalse
            $null -eq $script:Metadata.CreatedBy | Should -BeFalse
        }

        It 'Does not store secret during WhatIf' {
            Invoke-SPStoreSecret -Unattended -TenantId 'tenant-id' -AppId 'app-id' -Secret $script:SecureSecret -Force -WhatIf

            $script:SetSecretCalls | Should -Be 0
        }
    }
}
