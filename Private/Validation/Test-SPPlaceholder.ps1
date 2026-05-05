function Test-SPPlaceholder {

    <#
.SYNOPSIS
Validates placeholders against CSV headers.

.DESCRIPTION
Checks extracted placeholders against the available CSV headers and
classifies them as valid, unknown, or malformed.

Validation rules:
- Placeholder matching is case-insensitive.
- Placeholder names may contain spaces if the matching CSV header does.
- Leading or trailing whitespace inside the placeholder name is not allowed.
- Unknown placeholders are reported separately.

This function performs validation only. It does not render or replace
placeholders in text.

.PARAMETER Placeholders
The placeholder names extracted from text.

.PARAMETER Headers
The available CSV headers to validate against.

.OUTPUTS
PSCustomObject

Returns an object containing:
- AllPlaceholders
- ValidPlaceholders
- UnknownPlaceholders
- MalformedPlaceholders
- IsValid

.NOTES
Private SmailPost function.
Used by preflight validation before preview or sending.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Placeholders,

        [Parameter(Mandatory)]
        [string[]]$Headers
    )

    $validPlaceholders = @()
    $unknownPlaceholders = @()
    $malformedPlaceholders = @()

    $headerLookup = @{}
    foreach ($header in $Headers) {
        $headerLookup[$header.ToLowerInvariant()] = $header
    }

    foreach ($placeholder in $Placeholders) {
        $trimmedPlaceholder = $placeholder.Trim()

        if ($trimmedPlaceholder.Length -eq 0) {
            $malformedPlaceholders += $placeholder
            continue
        }

        if ($trimmedPlaceholder -ne $placeholder) {
            $malformedPlaceholders += $placeholder
            continue
        }

        $lookupKey = $trimmedPlaceholder.ToLowerInvariant()

        if ($headerLookup.ContainsKey($lookupKey)) {
            $validPlaceholders += $headerLookup[$lookupKey]
            continue
        }

        $unknownPlaceholders += $placeholder
    }

    $validPlaceholders = @($validPlaceholders | Select-Object -Unique)
    $unknownPlaceholders = @($unknownPlaceholders | Select-Object -Unique)
    $malformedPlaceholders = @($malformedPlaceholders | Select-Object -Unique)

    return [pscustomobject]@{
        AllPlaceholders       = @($Placeholders)
        ValidPlaceholders     = $validPlaceholders
        UnknownPlaceholders   = $unknownPlaceholders
        MalformedPlaceholders = $malformedPlaceholders
        IsValid               = ($unknownPlaceholders.Count -eq 0 -and $malformedPlaceholders.Count -eq 0)
    }
}
