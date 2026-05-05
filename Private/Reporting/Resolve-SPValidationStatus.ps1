function Resolve-SPValidationStatus {

    <#
.SYNOPSIS
Determines the overall validation status from validation issues.

.DESCRIPTION
Evaluates a collection of validation issues and determines the
overall validation state.

Rules:
- If any issue has Severity = 'Error', the result is 'Invalid'.
- If no errors exist but warnings are present, the result is 'ValidWithWarnings'.
- If no issues exist, the result is 'Valid'.

.PARAMETER Issues
The collection of validation issue objects.

.OUTPUTS
System.String

Returns one of the following values:
- Valid
- ValidWithWarnings
- Invalid

.NOTES
Private SmailPost function.
Used by preflight validation to determine overall job validity.
#>

    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object[]]$Issues
    )

    if ($null -eq $Issues -or $Issues.Count -eq 0) {
        return 'Valid'
    }

    $hasErrors = $Issues | Where-Object { $_.Severity -eq 'Error' }

    if ($hasErrors) {
        return 'Invalid'
    }

    $hasWarnings = $Issues | Where-Object { $_.Severity -eq 'Warning' }

    if ($hasWarnings) {
        return 'ValidWithWarnings'
    }

    return 'Valid'
}
