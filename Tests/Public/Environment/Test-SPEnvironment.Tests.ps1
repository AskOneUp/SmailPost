Describe 'Test-SPEnvironment' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot
        . (Join-Path $script:ModuleRoot 'Public\Environment\Test-SPEnvironment.ps1')
    }

    It 'Returns true when current PowerShell major version meets the default minimum' {
        $result = Test-SPEnvironment

        $result | Should -BeTrue
    }

    It 'Returns true when current PowerShell major version meets a custom minimum' {
        $result = Test-SPEnvironment -MinimumMajor 5

        $result | Should -BeTrue
    }

    It 'Throws when current PowerShell major version is lower than the required minimum' {
        $currentMajor = $PSVersionTable.PSVersion.Major
        $minimumMajor = $currentMajor + 1

        {
            Test-SPEnvironment -MinimumMajor $minimumMajor
        } | Should -Throw "SmailPost requires PowerShell $minimumMajor+*"
    }

    It 'Throws when MinimumMajor is below the allowed validation range' {
        {
            Test-SPEnvironment -MinimumMajor 0
        } | Should -Throw
    }

    It 'Throws when MinimumMajor is above the allowed validation range' {
        {
            Test-SPEnvironment -MinimumMajor 100
        } | Should -Throw
    }
}
