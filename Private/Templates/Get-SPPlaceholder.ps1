function Get-SPPlaceholder {

    <#
.SYNOPSIS
Extracts placeholders from text.

.DESCRIPTION
Scans a text value for SmailPost placeholders using the supported syntax:

{HeaderName}

The function returns all placeholders found in the order they appear,
as well as a unique list of placeholder names.

This function performs extraction only. It does not validate whether
the placeholders exist in CSV headers. Validation is handled separately
by Test-SPPlaceholder.

.PARAMETER Text
The text to inspect for placeholders.

.OUTPUTS
PSCustomObject

Returns an object containing:
- Text
- AllPlaceholders
- UniquePlaceholders
- Count

.NOTES
Private SmailPost function.
Used by validation, preview rendering, and send preparation.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    $pattern = '\{([^{}]+)\}'
    $regexMatches = [regex]::Matches($Text, $pattern)

    $allPlaceholders = @()

    foreach ($match in $regexMatches) {
        $allPlaceholders += $match.Groups[1].Value
    }

    $uniquePlaceholders = @(
        $allPlaceholders | Select-Object -Unique
    )

    return [pscustomobject]@{
        Text               = $Text
        AllPlaceholders    = $allPlaceholders
        UniquePlaceholders = $uniquePlaceholders
        Count              = $allPlaceholders.Count
    }
}
