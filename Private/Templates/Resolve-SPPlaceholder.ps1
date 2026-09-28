function Resolve-SPPlaceholder {

    <#
.SYNOPSIS
Resolves placeholders in text using values from a CSV row.

.DESCRIPTION
Scans the supplied text for SmailPost placeholders and replaces them
with values from the provided row object.

Supported syntax:
- {HeaderName}

Resolution rules:
- Placeholder matching is case-insensitive.
- If a matching row value is null or empty, the placeholder is replaced
  with an empty string.
- If no matching row property exists, the placeholder is left unchanged.
- Replacement values are inserted literally without regex escaping.

This function is used by preview rendering and send preparation after
placeholder validation has already completed successfully.

.PARAMETER Text
The template text containing placeholders.

.PARAMETER Values
The row values object used for placeholder replacement.

.OUTPUTS
PSCustomObject

Returns an object containing:
- OriginalText
- ResolvedText
- ResolvedPlaceholders
- UnresolvedPlaceholders

.NOTES
Private SmailPost function.
Used by preview rendering and final mail preparation.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [psobject]$Values
    )

    $propertyLookup = @{}

    foreach ($property in $Values.PSObject.Properties) {
        $propertyLookup[$property.Name.ToLowerInvariant()] = [string]$property.Value
    }

    $pattern = '\{([^{}]+)\}'
    $regexMatches = [regex]::Matches($Text, $pattern)

    $resolvedPlaceholders = @()
    $unresolvedPlaceholders = @()
    $resolvedText = $Text

    foreach ($regexMatch in $regexMatches) {
        $placeholderName = $regexMatch.Groups[1].Value
        $lookupKey = $placeholderName.ToLowerInvariant()
        $escapedPlaceholder = [regex]::Escape($regexMatch.Value)

        if ($propertyLookup.ContainsKey($lookupKey)) {
            $resolvedPlaceholders += $placeholderName

            $replacementValue = $propertyLookup[$lookupKey]

            if ([string]::IsNullOrEmpty($replacementValue)) {
                $replacementValue = ''
            }

            $literalReplacement = $replacementValue

            $resolvedText = [regex]::Replace(
                $resolvedText,
                $escapedPlaceholder,
                [System.Text.RegularExpressions.MatchEvaluator]{
                    param($match)

                    $null = $match
                    return $literalReplacement
                }
            )
        }
        else {
            $unresolvedPlaceholders += $placeholderName
        }
    }

    return [pscustomobject]@{
        OriginalText           = $Text
        ResolvedText           = $resolvedText
        ResolvedPlaceholders   = @($resolvedPlaceholders | Select-Object -Unique)
        UnresolvedPlaceholders = @($unresolvedPlaceholders | Select-Object -Unique)
    }
}
