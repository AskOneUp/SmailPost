
Describe "Resolve-SPPlaceholder" {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Templates\Resolve-SPPlaceholder.ps1')
    }

    It "Replaces a single placeholder" {
        $values = [pscustomobject]@{
            FirstName = 'Donald'
        }

        $result = Resolve-SPPlaceholder -Text 'Hello {FirstName}.' -Values $values

        $result.ResolvedText | Should -Be 'Hello Donald.'
        $result.ResolvedPlaceholders.Count | Should -Be 1
        $result.UnresolvedPlaceholders.Count | Should -Be 0
    }

    It "Replaces multiple placeholders" {
        $values = [pscustomobject]@{
            FirstName = 'Donald'
            Company   = 'AskOneUp'
        }

        $result = Resolve-SPPlaceholder -Text 'Hello {FirstName} from {Company}.' -Values $values

        $result.ResolvedText | Should -Be 'Hello Donald from AskOneUp.'
    }

    It "Matches placeholder names case-insensitively" {
        $values = [pscustomobject]@{
            FirstName = 'Donald'
        }

        $result = Resolve-SPPlaceholder -Text 'Hello {firstname}.' -Values $values

        $result.ResolvedText | Should -Be 'Hello Donald.'
    }

    It "Replaces empty values with empty string" {
        $values = [pscustomobject]@{
            FirstName = ''
        }

        $result = Resolve-SPPlaceholder -Text 'Hello {FirstName}.' -Values $values

        $result.ResolvedText | Should -Be 'Hello .'
    }

    It "Leaves unknown placeholders unchanged" {
        $values = [pscustomobject]@{
            FirstName = 'Donald'
        }

        $result = Resolve-SPPlaceholder -Text 'Hello {PlanetX}.' -Values $values

        $result.ResolvedText | Should -Be 'Hello {PlanetX}.'
        $result.UnresolvedPlaceholders.Count | Should -Be 1
        $result.UnresolvedPlaceholders[0] | Should -Be 'PlanetX'
    }

    It "Replaces repeated placeholders everywhere they appear" {
        $values = [pscustomobject]@{
            FirstName = 'Donald'
        }

        $result = Resolve-SPPlaceholder -Text '{FirstName} says hello to {FirstName}.' -Values $values

        $result.ResolvedText | Should -Be 'Donald says hello to Donald.'
    }
        It "Preserves spaces in replacement values without regex escaping" {
        $values = [pscustomobject]@{
            Naam = 'Donald Daemers'
        }

        $result = Resolve-SPPlaceholder -Text 'Beste {Naam},' -Values $values

        $result.ResolvedText | Should -Be 'Beste Donald Daemers,'
    }

}
