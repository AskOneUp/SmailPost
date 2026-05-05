Describe "Get-SPStringSha256" {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Utility\Get-SPStringSha256.ps1')

        function ConvertTo-TestSecureString {
            param(
                [Parameter(Mandatory)]
                [string]$Value
            )

            $secureString = [System.Security.SecureString]::new()

            foreach ($character in $Value.ToCharArray()) {
                $secureString.AppendChar($character)
            }

            $secureString.MakeReadOnly()
            return $secureString
        }
    }

    It "Returns a fingerprint string for a SecureString" {
        # Proves the function returns a formatted fingerprint string.
        $secure = ConvertTo-TestSecureString -Value "secret123"

        $result = Get-SPStringSha256 -Secure $secure

        $result | Should -BeOfType ([string])
        $result | Should -Match '^[a-f0-9]{4}\.\.\.\.[a-f0-9]{4}$'
    }

    It "Produces the same fingerprint for the same input" {
        # Proves identical secure values produce identical fingerprints.
        $secure1 = ConvertTo-TestSecureString -Value "same-secret"
        $secure2 = ConvertTo-TestSecureString -Value "same-secret"

        $hash1 = Get-SPStringSha256 -Secure $secure1
        $hash2 = Get-SPStringSha256 -Secure $secure2

        $hash1 | Should -Be $hash2
    }

    It "Produces different fingerprints for different inputs" {
        # Proves different secure values produce different fingerprints.
        $secure1 = ConvertTo-TestSecureString -Value "alpha"
        $secure2 = ConvertTo-TestSecureString -Value "beta"

        $hash1 = Get-SPStringSha256 -Secure $secure1
        $hash2 = Get-SPStringSha256 -Secure $secure2

        $hash1 | Should -Not -Be $hash2
    }

    It "Throws when SecureString parameter is null" {
        # Proves the mandatory non-null parameter guard is enforced.
        { Get-SPStringSha256 -Secure $null } | Should -Throw
    }
}
