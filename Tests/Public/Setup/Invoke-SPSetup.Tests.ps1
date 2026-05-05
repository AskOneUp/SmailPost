Describe 'Invoke-SPSetup' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Public\Environment\Test-SPEnvironment.ps1')
        . (Join-Path $script:ModuleRoot 'Public\Setup\Install-SPDependency.ps1')
        . (Join-Path $script:ModuleRoot 'Public\Environment\Test-SPPrerequisite.ps1')
        . (Join-Path $script:ModuleRoot 'Private\Secrets\Get-SPStoredSecretState.ps1')
        . (Join-Path $script:ModuleRoot 'Public\Environment\Test-SPGraphConnection.ps1')
        . (Join-Path $script:ModuleRoot 'Public\Identity\Get-SPAllowedSender.ps1')

        function Get-TestShimSecretVault { [CmdletBinding()] param([string]$Name) $null = $Name }
        function Get-TestShimSecretStoreConfiguration { [CmdletBinding()] param() }
        function Get-TestShimSecretInfo { [CmdletBinding()] param([string]$Vault, [string]$Name) $null = $Vault; $null = $Name }
        function Initialize-TestShimSecretStore {
            [CmdletBinding(SupportsShouldProcess = $true)]
            param([string]$Authentication, [string]$Interaction)
            $null = $Authentication
            $null = $Interaction
            $null = $PSCmdlet.ShouldProcess('TestShim', 'Initialize')
        }
        function Register-TestShimSecretVault {
            [CmdletBinding(SupportsShouldProcess = $true)]
            param([string]$Name, [string]$ModuleName)
            $null = $Name
            $null = $ModuleName
            $null = $PSCmdlet.ShouldProcess('TestShim', 'Register')
        }

        Set-Alias -Name Get-SecretVault -Value Get-TestShimSecretVault -Scope Local
        Set-Alias -Name Get-SecretStoreConfiguration -Value Get-TestShimSecretStoreConfiguration -Scope Local
        Set-Alias -Name Get-SecretInfo -Value Get-TestShimSecretInfo -Scope Local
        Set-Alias -Name Initialize-SecretStore -Value Initialize-TestShimSecretStore -Scope Local
        Set-Alias -Name Register-SecretVault -Value Register-TestShimSecretVault -Scope Local

        . (Join-Path $script:ModuleRoot 'Public\Setup\Invoke-SPSetup.ps1')
    }

    BeforeEach {
        $script:SecretComplete = $true
        $script:SecretNotes = [string[]]@()
        $script:GraphConnectionSuccess = $true
        $script:GraphConnectionNotes = [string[]]@()
        $script:AllowedSenderMode = 'Success'

        Mock Test-Path { $true }
        Mock New-Item {}
        Mock Start-Transcript {}
        Mock Stop-Transcript {}

        Mock Test-SPEnvironment {}
        Mock Install-SPDependency {}

        Mock Test-SPPrerequisite {
            [pscustomobject]@{
                GraphReachable = $true
                Notes          = [string[]]@('Microsoft Graph endpoint reachable (HEAD 200).')
            }
        }

        Mock Get-Command {
            [pscustomobject]@{ Name = $Name }
        } -ParameterFilter {
            $Name -eq 'Get-SecretVault'
        }

        Mock Get-SecretStoreConfiguration {
            [pscustomobject]@{ Authentication = 'None' }
        }

        Mock Get-SecretVault {
            [pscustomobject]@{ Name = 'SmailPost' }
        }

        Mock Get-SecretInfo {}
        Mock Initialize-SecretStore {}
        Mock Register-SecretVault {}

        Mock Get-SPStoredSecretState {
            [pscustomobject]@{
                SecretComplete = $script:SecretComplete
                Notes          = $script:SecretNotes
            }
        }

        Mock Test-SPGraphConnection {
            [pscustomobject]@{
                Success        = $script:GraphConnectionSuccess
                TokenExpiresOn = $null
                Notes          = $script:GraphConnectionNotes
            }
        }

        Mock Get-SPAllowedSender {
            if ($script:AllowedSenderMode -eq 'Empty') {
                return @()
            }

            if ($script:AllowedSenderMode -eq 'Throw') {
                throw [System.Exception]::new('Sender group missing.')
            }

            @(
                [pscustomobject]@{
                    DisplayName       = 'Alpha User'
                    Mail              = 'alpha@contoso.com'
                    UserPrincipalName = 'alpha@contoso.com'
                    Id                = 'user-1'
                }
            )
        }
    }

    Context 'Successful setup' {
        It 'Returns a fully successful setup summary when all checks pass' {
            $result = Invoke-SPSetup -Unattended

            $result.Environment.Status | Should -Be '✅'
            $result.Dependencies.Status | Should -Be '✅'
            $result.Graph.Status | Should -Be '✅'
            $result.SecretStore.Status | Should -Be '✅'
            $result.GraphConnection.Status | Should -Be '✅'
            $result.AllowedSenders.Status | Should -Be '✅'
            $result.OverallStatus | Should -Be '✅'
            $result.NextStep | Should -Be 'None'
        }
    }

    Context 'Environment handling' {
        It 'Throws when the environment check fails' {
            Mock Test-SPEnvironment {
                throw [System.Exception]::new('PowerShell too old.')
            }

            {
                Invoke-SPSetup -Unattended
            } | Should -Throw
        }
    }

    Context 'Dependency handling' {
        It 'Skips dependency installation when requested' {
            $result = Invoke-SPSetup -Unattended -SkipDependencies

            $result.Dependencies.Status | Should -Be '⏭️'
            $result.Dependencies.Notes[0] | Should -Be 'Skipped by user.'

            Assert-MockCalled Install-SPDependency -Times 0
        }

        It 'Marks dependencies as warning when installation fails' {
            Mock Install-SPDependency {
                throw [System.Exception]::new('Dependency failure.')
            }

            $result = Invoke-SPSetup -Unattended

            $result.Dependencies.Status | Should -Be '⚠️'
            $result.OverallStatus | Should -Be '⚠️'
            $result.Dependencies.Notes[0] | Should -Be 'Dependency install issue: Dependency failure.. This may impact later steps.'
        }
    }

    Context 'Graph reachability handling' {
        It 'Marks Graph as failed when Microsoft Graph is not reachable' {
            Mock Test-SPPrerequisite {
                [pscustomobject]@{
                    GraphReachable = $false
                    Notes          = @('Cannot reach Microsoft Graph endpoint. DNS resolution failed.')
                }
            }

            $result = Invoke-SPSetup -Unattended

            $result.Graph.Status | Should -Be '❌'
            $result.OverallStatus | Should -Be '❌'
            ($result.Graph.Notes -join '|') | Should -Match 'Graph not reachable'
        }

        It 'Skips Graph reachability when requested' {
            $result = Invoke-SPSetup -Unattended -SkipGraphCheck

            $result.Graph.Status | Should -Be '⏭️'
            $result.Graph.Notes[0] | Should -Be 'Skipped by user.'
        }
    }

    Context 'SecretStore handling' {
        It 'Skips SecretStore when requested' {
            $result = Invoke-SPSetup -Unattended -SkipSecretStore

            $result.SecretStore.Status | Should -Be '⏭️'
            $result.NextStep | Should -Be 'Run Invoke-SPSetup'
        }

        It 'Skips SecretStore when SecretManagement commands are missing' {
            Mock Get-Command {
                $null
            } -ParameterFilter {
                $Name -eq 'Get-SecretVault'
            }

            $result = Invoke-SPSetup -Unattended

            $result.SecretStore.Status | Should -Be '⏭️'
            $result.SecretStore.Notes[0] | Should -Be 'Skipped SecretStore check: SecretManagement/SecretStore modules not loaded (WhatIf or missing).'
        }

        It 'Creates the SmailPost vault when no vault exists in unattended mode' {
            Mock Get-SecretStoreConfiguration {
                $null
            }

            Mock Get-SecretVault {
                $null
            }

            $result = Invoke-SPSetup -Unattended

            $result.SecretStore.Status | Should -Be '✅'
            ($result.SecretStore.Notes -join '|') | Should -Match "Vault 'SmailPost' created"
            Assert-MockCalled Initialize-SecretStore -Times 1
            Assert-MockCalled Register-SecretVault -Times 1
        }

        It 'Marks SecretStore as failed when locked in unattended mode' {
            Mock Get-SecretStoreConfiguration {
                [pscustomobject]@{
                    Authentication = 'Password'
                }
            }

            Mock Get-SecretVault {
                [pscustomobject]@{
                    Name = 'SmailPost'
                }
            }

            Mock Get-SecretInfo {
                throw [System.Exception]::new('SecretStore is locked. Run Unlock-SecretStore.')
            }

            $result = Invoke-SPSetup -Unattended

            $result.SecretStore.Status | Should -Be '❌'
            $result.OverallStatus | Should -Be '❌'
            ($result.SecretStore.Notes -join '|') | Should -Match 'SecretStore is password-protected and locked'
        }
    }

    Context 'Graph connection handling' {
        It 'Skips Graph connection when stored credentials are incomplete' {
            $script:SecretComplete = $false
            $script:SecretNotes = [string[]]@('Missing tenant id.')

            $result = Invoke-SPSetup -Unattended

            $result.GraphConnection.Status | Should -Be '⏭️'
            $result.NextStep | Should -Be 'Run Invoke-SPStoreSecret'
            ($result.GraphConnection.Notes -join '|') | Should -Match 'Missing tenant id'
        }

        It 'Marks Graph connection as failed when connection validation fails' {
            $script:GraphConnectionSuccess = $false
            $script:GraphConnectionNotes = [string[]]@('Role missing.')

            $result = Invoke-SPSetup -Unattended

            $result.GraphConnection.Status | Should -Be '❌'
            $result.OverallStatus | Should -Be '❌'
            ($result.GraphConnection.Notes -join '|') | Should -Match 'Role missing'
        }
    }

    Context 'Allowed sender handling' {
        It 'Skips allowed sender validation when no valid senders are found' {
            $script:AllowedSenderMode = 'Empty'

            $result = Invoke-SPSetup -Unattended

            $result.AllowedSenders.Status | Should -Be '⏭️'
            $result.NextStep | Should -Be 'Add users with valid mail addresses to the SmailPost-Senders group'
        }

        It 'Marks allowed sender lookup as warning when lookup fails' {
            $script:AllowedSenderMode = 'Throw'

            $result = Invoke-SPSetup -Unattended

            $result.AllowedSenders.Status | Should -Be '⚠️'
            $result.OverallStatus | Should -Be '⚠️'
            ($result.AllowedSenders.Notes -join '|') | Should -Match 'Sender group missing'
        }
    }

    Context 'WhatIf behavior' {
        It 'Does not create log folder or start transcript during WhatIf' {
            $result = Invoke-SPSetup -Unattended -WhatIf

            $result | Should -Not -BeNullOrEmpty

            Assert-MockCalled New-Item -Times 0
            Assert-MockCalled Start-Transcript -Times 0
        }
    }
}
