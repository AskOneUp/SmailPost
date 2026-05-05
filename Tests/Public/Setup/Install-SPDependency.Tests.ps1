Describe 'Install-SPDependency' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        function Get-TestShimPSRepository {
            [CmdletBinding()]
            param(
                [string]$Name
            )

            $null = $Name
        }

        function Register-TestShimPSRepository {
            [CmdletBinding(SupportsShouldProcess = $true)]
            param(
                [string]$Name,
                [string]$SourceLocation,
                [string]$InstallationPolicy
            )

            $null = $Name
            $null = $SourceLocation
            $null = $InstallationPolicy
            $null = $PSCmdlet.ShouldProcess('TestShim', 'Register')
        }

        function Set-TestShimPSRepository {
            [CmdletBinding(SupportsShouldProcess = $true)]
            param(
                [string]$Name,
                [string]$InstallationPolicy
            )

            $null = $Name
            $null = $InstallationPolicy
            $null = $PSCmdlet.ShouldProcess('TestShim', 'Set')
        }

        function Find-TestShimModule {
            [CmdletBinding()]
            param(
                [string]$Name,
                [string]$Repository,
                [switch]$AllowPrerelease
            )

            $null = $Name
            $null = $Repository
            $null = $AllowPrerelease
        }

        function Install-TestShimModule {
            [CmdletBinding(SupportsShouldProcess = $true)]
            param(
                [string]$Name,
                [version]$RequiredVersion,
                [string]$Scope,
                [switch]$Force,
                [switch]$AllowClobber,
                [string]$Repository,
                [switch]$AllowPrerelease,
                [switch]$AcceptLicense
            )

            $null = $Name
            $null = $RequiredVersion
            $null = $Scope
            $null = $Force
            $null = $AllowClobber
            $null = $Repository
            $null = $AllowPrerelease
            $null = $AcceptLicense
            $null = $PSCmdlet.ShouldProcess('TestShim', 'Install')
        }

        Set-Alias -Name Get-PSRepository -Value Get-TestShimPSRepository -Scope Local
        Set-Alias -Name Register-PSRepository -Value Register-TestShimPSRepository -Scope Local
        Set-Alias -Name Set-PSRepository -Value Set-TestShimPSRepository -Scope Local
        Set-Alias -Name Find-Module -Value Find-TestShimModule -Scope Local
        Set-Alias -Name Install-Module -Value Install-TestShimModule -Scope Local

        . (Join-Path $script:ModuleRoot 'Public\Setup\Install-SPDependency.ps1')
    }

    Context 'Repository handling' {
        It 'Registers PSGallery when the repository is missing' {
            Mock Get-PSRepository {
                $null
            }

            Mock Register-PSRepository {}
            Mock Set-PSRepository {}
            Mock Get-Module {
                [pscustomobject]@{
                    Version = [version]'2.11.0'
                    Path    = 'C:\Users\Test\Documents\PowerShell\Modules\Module\2.11.0\Module.psd1'
                }
            } -ParameterFilter {
                $ListAvailable -and $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {
                [pscustomobject]@{
                    Version = '2.11.0'
                }
            }

            Mock Install-Module {}
            Mock Import-Module {}
            Mock Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            }

            Install-SPDependency

            Assert-MockCalled Register-PSRepository -Times 1 -Exactly
            Assert-MockCalled Set-PSRepository -Times 0
        }

        It 'Sets PSGallery to trusted when repository is present but not trusted' {
            Mock Get-PSRepository {
                [pscustomobject]@{
                    Name               = 'PSGallery'
                    InstallationPolicy = 'Untrusted'
                }
            }

            Mock Register-PSRepository {}
            Mock Set-PSRepository {}
            Mock Get-Module {
                [pscustomobject]@{
                    Version = [version]'2.11.0'
                    Path    = 'C:\Users\Test\Documents\PowerShell\Modules\Module\2.11.0\Module.psd1'
                }
            } -ParameterFilter {
                $ListAvailable -and $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {
                [pscustomobject]@{
                    Version = '2.11.0'
                }
            }

            Mock Install-Module {}
            Mock Import-Module {}
            Mock Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            }

            Install-SPDependency

            Assert-MockCalled Set-PSRepository -Times 1 -Exactly
            Assert-MockCalled Register-PSRepository -Times 0
        }

        It 'Throws when PSGallery registration fails' {
            Mock Get-PSRepository {
                $null
            }

            Mock Register-PSRepository {
                throw [System.Exception]::new('No route to gallery.')
            }

            {
                Install-SPDependency
            } | Should -Throw 'Failed to register PSGallery repository. No route to gallery..'
        }

        It 'Throws when setting PSGallery trust fails' {
            Mock Get-PSRepository {
                [pscustomobject]@{
                    Name               = 'PSGallery'
                    InstallationPolicy = 'Untrusted'
                }
            }

            Mock Set-PSRepository {
                throw [System.Exception]::new('Policy write denied.')
            }

            {
                Install-SPDependency
            } | Should -Throw 'Failed to set PSGallery InstallationPolicy to Trusted. Policy write denied..'
        }
    }

    Context 'Version selection and install behavior' {
        It 'Defaults PreferLatest to true when not specified' {
            $script:findCalls = 0

            Mock Get-PSRepository {
                [pscustomobject]@{
                    Name               = 'PSGallery'
                    InstallationPolicy = 'Trusted'
                }
            }

            Mock Get-Module {
                [pscustomobject]@{
                    Version = [version]'2.11.0'
                    Path    = 'C:\Users\Test\Documents\PowerShell\Modules\Module\2.11.0\Module.psd1'
                }
            } -ParameterFilter {
                $ListAvailable -and $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {
                $script:findCalls++
                [pscustomobject]@{
                    Version = '2.20.0'
                }
            }

            Mock Install-Module {}
            Mock Import-Module {}
            Mock Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            }

            Install-SPDependency

            $script:findCalls | Should -Be 4
        }

        It 'Skips Find-Module when PreferLatest is false' {
            Mock Get-PSRepository {
                [pscustomobject]@{
                    Name               = 'PSGallery'
                    InstallationPolicy = 'Trusted'
                }
            }

            Mock Get-Module {
                [pscustomobject]@{
                    Version = [version]'2.11.0'
                    Path    = 'C:\Users\Test\Documents\PowerShell\Modules\Module\2.11.0\Module.psd1'
                }
            } -ParameterFilter {
                $ListAvailable -and $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {}
            Mock Install-Module {}
            Mock Import-Module {}
            Mock Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            }

            Install-SPDependency -PreferLatest:$false

            Assert-MockCalled Find-Module -Times 0
        }

        It 'Pins to minimum when gallery returns a lower version' {
            $script:installedVersions = [System.Collections.Generic.List[string]]::new()

            Mock Get-PSRepository {
                [pscustomobject]@{
                    Name               = 'PSGallery'
                    InstallationPolicy = 'Trusted'
                }
            }

            Mock Get-Module {
                $null
            } -ParameterFilter {
                $ListAvailable -and $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {
                [pscustomobject]@{
                    Version = '1.0.0'
                }
            }

            Mock Install-Module {
                $script:installedVersions.Add($RequiredVersion.ToString())
            }

            Mock Import-Module {}
            Mock Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            }

            Install-SPDependency

            $null -eq $script:installedVersions.Count | Should -BeFalse
            $script:installedVersions.Count | Should -Be 4
            $script:installedVersions[0] | Should -Be '2.11.0'
            $script:installedVersions[1] | Should -Be '2.11.0'
            $script:installedVersions[2] | Should -Be '1.1.2'
            $script:installedVersions[3] | Should -Be '1.0.6'
        }

        It 'Installs missing modules using CurrentUser scope' {
            $script:installNames = [System.Collections.Generic.List[string]]::new()

            Mock Get-PSRepository {
                [pscustomobject]@{
                    Name               = 'PSGallery'
                    InstallationPolicy = 'Trusted'
                }
            }

            Mock Get-Module {
                $null
            } -ParameterFilter {
                $ListAvailable -and $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {
                [pscustomobject]@{
                    Version = '9.9.9'
                }
            }

            Mock Install-Module {
                $script:installNames.Add($Name)

                $Scope | Should -Be 'CurrentUser'
                $Repository | Should -Be 'PSGallery'
                $Force | Should -BeTrue
                $AllowClobber | Should -BeTrue
            }

            Mock Import-Module {}
            Mock Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            }

            Install-SPDependency

            $null -eq $script:installNames.Count | Should -BeFalse
            $script:installNames.Count | Should -Be 4
        }

        It 'Does not install when desired version is already present and Force is not used' {
            Mock Get-PSRepository {
                [pscustomobject]@{
                    Name               = 'PSGallery'
                    InstallationPolicy = 'Trusted'
                }
            }

            Mock Get-Module {
                [pscustomobject]@{
                    Version = [version]'9.9.9'
                    Path    = 'C:\Users\Test\Documents\PowerShell\Modules\Module\9.9.9\Module.psd1'
                }
            } -ParameterFilter {
                $ListAvailable -and $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {
                [pscustomobject]@{
                    Version = '9.9.9'
                }
            }

            Mock Install-Module {}
            Mock Import-Module {}
            Mock Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            }

            Install-SPDependency

            Assert-MockCalled Install-Module -Times 0
        }

        It 'Installs even when desired version is already present when Force is used' {
            Mock Get-PSRepository {
                [pscustomobject]@{
                    Name               = 'PSGallery'
                    InstallationPolicy = 'Trusted'
                }
            }

            Mock Get-Module {
                [pscustomobject]@{
                    Version = [version]'9.9.9'
                    Path    = 'C:\Users\Test\Documents\PowerShell\Modules\Module\9.9.9\Module.psd1'
                }
            } -ParameterFilter {
                $ListAvailable -and $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {
                [pscustomobject]@{
                    Version = '9.9.9'
                }
            }

            Mock Install-Module {}
            Mock Import-Module {}
            Mock Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            }

            Install-SPDependency -Force

            Assert-MockCalled Install-Module -Times 4
        }

        It 'Keeps installed version when installation fails but a fallback version exists' {
            $script:importVersions = [System.Collections.Generic.List[string]]::new()

            Mock Get-PSRepository {
                [pscustomobject]@{
                    Name               = 'PSGallery'
                    InstallationPolicy = 'Trusted'
                }
            }

            Mock Get-Module {
                [pscustomobject]@{
                    Version = [version]'2.11.0'
                    Path    = 'C:\Users\Test\Documents\PowerShell\Modules\Module\2.11.0\Module.psd1'
                }
            } -ParameterFilter {
                $ListAvailable -and $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {
                [pscustomobject]@{
                    Version = '9.9.9'
                }
            }

            Mock Install-Module {
                throw [System.Exception]::new('Gallery unavailable.')
            }

            Mock Import-Module {
                $script:importVersions.Add([string]$RequiredVersion)
            } -ParameterFilter {
                $null -ne $RequiredVersion
            }

            Mock Import-Module {} -ParameterFilter {
                $null -eq $RequiredVersion
            }

            Mock Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            }

            Install-SPDependency

            $null -eq $script:importVersions.Count | Should -BeFalse
            $script:importVersions.Count | Should -Be 4
            $script:importVersions[0] | Should -Be '2.11.0'
        }

        It 'Throws when installation fails and no installed fallback exists' {
            Mock Get-PSRepository {
                [pscustomobject]@{
                    Name               = 'PSGallery'
                    InstallationPolicy = 'Trusted'
                }
            }

            Mock Get-Module {
                $null
            } -ParameterFilter {
                $ListAvailable -and $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {
                [pscustomobject]@{
                    Version = '9.9.9'
                }
            }

            Mock Install-Module {
                throw [System.Exception]::new('No package source available.')
            }

            {
                Install-SPDependency
            } | Should -Throw
        }
    }

    Context 'Import and cleanup behavior' {
        It 'Falls back to Import-Module without RequiredVersion when exact import fails' {
            $script:exactImports = 0
            $script:fallbackImports = 0

            Mock Get-PSRepository {
                [pscustomobject]@{
                    Name               = 'PSGallery'
                    InstallationPolicy = 'Trusted'
                }
            }

            Mock Get-Module {
                if ($ListAvailable) {
                    [pscustomobject]@{
                        Version = [version]'2.11.0'
                        Path    = 'C:\Users\Test\Documents\PowerShell\Modules\Module\2.11.0\Module.psd1'
                    }
                }
                else {
                    [pscustomobject]@{
                        Version = [version]'2.11.0'
                    }
                }
            } -ParameterFilter {
                $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {
                [pscustomobject]@{
                    Version = '2.11.0'
                }
            }

            Mock Install-Module {}

            Mock Import-Module {
                $script:exactImports++
                throw [System.Exception]::new('Side-by-side conflict.')
            } -ParameterFilter {
                $null -ne $RequiredVersion
            }

            Mock Import-Module {
                $script:fallbackImports++
            } -ParameterFilter {
                $null -eq $RequiredVersion
            }

            Mock Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            }

            Install-SPDependency

            $script:exactImports | Should -Be 4
            $script:fallbackImports | Should -Be 4
        }

        It 'Removes older versions only from CurrentUser paths when CleanOld is used' {
            $script:removedPaths = [System.Collections.Generic.List[string]]::new()

            Mock Get-PSRepository {
                [pscustomobject]@{
                    Name               = 'PSGallery'
                    InstallationPolicy = 'Trusted'
                }
            }

            Mock Get-Module {
                if ($ListAvailable -and $Name -eq 'Microsoft.Graph.Authentication') {
                    @(
                        [pscustomobject]@{
                            Name    = 'Microsoft.Graph.Authentication'
                            Version = [version]'2.20.0'
                            Path    = (Join-Path $HOME 'Documents\PowerShell\Modules\Microsoft.Graph.Authentication\2.20.0\Microsoft.Graph.Authentication.psd1')
                        },
                        [pscustomobject]@{
                            Name    = 'Microsoft.Graph.Authentication'
                            Version = [version]'2.11.0'
                            Path    = (Join-Path $HOME 'Documents\PowerShell\Modules\Microsoft.Graph.Authentication\2.11.0\Microsoft.Graph.Authentication.psd1')
                        },
                        [pscustomobject]@{
                            Name    = 'Microsoft.Graph.Authentication'
                            Version = [version]'2.0.0'
                            Path    = 'C:\Program Files\PowerShell\Modules\Microsoft.Graph.Authentication\2.0.0\Microsoft.Graph.Authentication.psd1'
                        }
                    )
                }
                elseif ($ListAvailable) {
                    [pscustomobject]@{
                        Name    = $Name
                        Version = [version]'9.9.9'
                        Path    = (Join-Path $HOME "Documents\PowerShell\Modules\$Name\9.9.9\$Name.psd1")
                    }
                }
            } -ParameterFilter {
                $ListAvailable -and $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {
                [pscustomobject]@{
                    Version = '9.9.9'
                }
            }

            Mock Install-Module {}
            Mock Import-Module {}

            Mock Remove-Item {
                $script:removedPaths.Add($Path)
            }

            Mock Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            }

            Install-SPDependency -CleanOld

            $null -eq $script:removedPaths.Count | Should -BeFalse
            $script:removedPaths.Count | Should -Be 2
            ($script:removedPaths -join '|') | Should -Match '2\.20\.0'
            ($script:removedPaths -join '|') | Should -Match '2\.11\.0'
            ($script:removedPaths -join '|') | Should -Not -Match 'C:\\Program Files\\PowerShell\\Modules'
        }
    }

    Context 'WhatIf and sanity validation' {
        It 'Does not install or import when WhatIf is used' {
            Mock Get-PSRepository {
                $null
            }

            Mock Register-PSRepository {}
            Mock Set-PSRepository {}

            Mock Get-Module {
                [pscustomobject]@{
                    Version = [version]'2.11.0'
                    Path    = 'C:\Users\Test\Documents\PowerShell\Modules\Module\2.11.0\Module.psd1'
                }
            } -ParameterFilter {
                $ListAvailable -and $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {
                [pscustomobject]@{
                    Version = '9.9.9'
                }
            }

            Mock Install-Module {}
            Mock Import-Module {}
            Mock Get-Command {
                $null
            }

            Install-SPDependency -WhatIf

            Assert-MockCalled Register-PSRepository -Times 0
            Assert-MockCalled Set-PSRepository -Times 0
            Assert-MockCalled Install-Module -Times 0
            Assert-MockCalled Import-Module -Times 0
        }

        It 'Throws when a required command is still missing after install and import' {
            Mock Get-PSRepository {
                [pscustomobject]@{
                    Name               = 'PSGallery'
                    InstallationPolicy = 'Trusted'
                }
            }

            Mock Get-Module {
                [pscustomobject]@{
                    Version = [version]'9.9.9'
                    Path    = 'C:\Users\Test\Documents\PowerShell\Modules\Module\9.9.9\Module.psd1'
                }
            } -ParameterFilter {
                $ListAvailable -and $Name -in @(
                    'Microsoft.Graph.Authentication',
                    'Microsoft.Graph.Users.Actions',
                    'Microsoft.PowerShell.SecretManagement',
                    'Microsoft.PowerShell.SecretStore'
                )
            }

            Mock Find-Module {
                [pscustomobject]@{
                    Version = '9.9.9'
                }
            }

            Mock Install-Module {}
            Mock Import-Module {}

            Mock Get-Command {
                if ($Name -eq 'Connect-MgGraph') {
                    $null
                }
                else {
                    [pscustomobject]@{
                        Name = $Name
                    }
                }
            }

            {
                Install-SPDependency
            } | Should -Throw 'Missing required command: Connect-MgGraph. Re-run with -Verbose for details.'
        }
    }
}
