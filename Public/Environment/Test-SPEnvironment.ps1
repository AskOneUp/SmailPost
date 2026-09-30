function Test-SPEnvironment {
    <#
        .SYNOPSIS
        Checks that the current PowerShell meets a minimum major version.
        .DESCRIPTION
        Validates that $PSVersionTable.PSVersion.Major is >= MinimumMajor; throws on failure and returns $true on success.
        .PARAMETER MinimumMajor
        Minimum required major version; defaults to 7.
        .EXAMPLE
        Test-SPEnvironment -Verbose.
        .EXAMPLE
        Test-SPEnvironment -MinimumMajor 7 -Verbose.
        .OUTPUTS
        System.Boolean.
    #>
    # Enable common parameters like -Verbose.
    [CmdletBinding()]
    # Declare that this function emits a boolean.
    [OutputType([bool])]
    param(
        [Parameter()]
        [ValidateRange(1, 99)]
        [int]$MinimumMajor = 7      # Default to requiring PowerShell 7+.
    )
    # Announce the check.
    Write-Verbose "Checking PowerShell version…."
    # Get the current PowerShell version object.
    $ver = $PSVersionTable.PSVersion
    # Log the detected version for traceability.
    Write-Verbose "Detected PowerShell version: $ver."
    # Compare major version and fail if too low.
    if ($ver.Major -lt $MinimumMajor) {
        # Stop execution with a clear error.
        throw "SmailPost requires PowerShell $MinimumMajor+ (detected $ver)."
    }
    # Confirm success via verbose output.
    Write-Verbose "PowerShell version OK (>= $MinimumMajor)."
    return $true
}
