function Test-SPCsvHeader {

    <#
.SYNOPSIS
Validates and normalizes the CSV header row.

.DESCRIPTION
Splits the header row using the detected delimiter and performs
basic structural validation.

The function performs the following checks:

- Ensures headers exist.
- Trims whitespace from header names.
- Detects empty header names.
- Detects duplicate headers.

If validation passes, the function returns a normalized list of
header names in the original order.

This function is part of the SmailPost CSV ingestion pipeline and
is used by Import-SPCsv before row processing begins.

.PARAMETER HeaderLine
The header line from the CSV file.

.PARAMETER Delimiter
The delimiter character used by the CSV file.

.OUTPUTS
System.String[]

Returns the validated and normalized header names.

.EXAMPLE
Test-SPCsvHeader -HeaderLine "Email,FirstName,Company" -Delimiter ','

.NOTES
Private SmailPost function.
Ensures CSV structure is safe before row parsing begins.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HeaderLine,

        [Parameter(Mandatory)]
        [char]$Delimiter
    )

    $headers = $HeaderLine.Split($Delimiter) | ForEach-Object {
        $_.Trim()
    }

    if (-not $headers -or $headers.Count -eq 0) {
        throw "CSV header row could not be parsed."
    }

    $emptyHeaders = $headers | Where-Object {
        [string]::IsNullOrWhiteSpace($_)
    }

    if ($emptyHeaders.Count -gt 0) {
        throw "CSV header contains empty column names."
    }

    $duplicates = $headers |
    Group-Object |
    Where-Object { $_.Count -gt 1 }

    if ($duplicates) {
        $names = $duplicates.Name -join ", "
        throw "CSV header contains duplicate column names: $names"
    }

    return $headers
}
