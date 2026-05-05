function Get-SPTestProjectRoot {
    <#
        .SYNOPSIS
        Finds the SmailPost project root for tests.

        .DESCRIPTION
        Get-SPTestProjectRoot walks upward from a starting path until it finds
        the project root that contains the Private, Public, and Tests folders.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$StartPath
    )

    $currentPath = $StartPath

    while ($true) {
        $hasPrivate = Test-Path -Path (Join-Path -Path $currentPath -ChildPath 'Private')
        $hasPublic = Test-Path -Path (Join-Path -Path $currentPath -ChildPath 'Public')
        $hasTests = Test-Path -Path (Join-Path -Path $currentPath -ChildPath 'Tests')

        if ($hasPrivate -and $hasPublic -and $hasTests) {
            return $currentPath
        }

        $parentPath = Split-Path -Path $currentPath -Parent

        if ([string]::IsNullOrWhiteSpace($parentPath) -or $parentPath -eq $currentPath) {
            throw 'Could not locate the SmailPost project root from the test path.'
        }

        $currentPath = $parentPath
    }
}
