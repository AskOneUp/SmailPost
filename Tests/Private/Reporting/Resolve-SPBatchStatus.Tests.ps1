Describe 'Resolve-SPBatchStatus' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Reporting\Resolve-SPBatchStatus.ps1')
    }

    It 'Returns Empty when results are null' {
        $result = Resolve-SPBatchStatus -Results $null
        $result | Should -Be 'Empty'
    }

    It 'Returns Empty when results are empty' {
        $result = Resolve-SPBatchStatus -Results @()
        $result | Should -Be 'Empty'
    }

    It 'Returns Sent when all results succeeded' {
        $results = @(
            [pscustomobject]@{ Success = $true },
            [pscustomobject]@{ Success = $true }
        )

        $result = Resolve-SPBatchStatus -Results $results
        $result | Should -Be 'Sent'
    }

    It 'Returns Failed when all results failed' {
        $results = @(
            [pscustomobject]@{ Success = $false },
            [pscustomobject]@{ Success = $false }
        )

        $result = Resolve-SPBatchStatus -Results $results
        $result | Should -Be 'Failed'
    }

    It 'Returns Partial when results are mixed' {
        $results = @(
            [pscustomobject]@{ Success = $true },
            [pscustomobject]@{ Success = $false }
        )

        $result = Resolve-SPBatchStatus -Results $results
        $result | Should -Be 'Partial'
    }
}
