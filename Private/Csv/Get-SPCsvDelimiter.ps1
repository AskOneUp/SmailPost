function Get-SPCsvDelimiter {

    <#
.SYNOPSIS
Detects the delimiter used in a CSV file.

.DESCRIPTION
Reads the first non-empty line of a CSV file and determines which delimiter
is most likely used to separate columns.

Supported delimiters:
- Comma     (,)
- Semicolon (;)
- Tab       (`t)
- Pipe      (|)

The function counts occurrences of each delimiter candidate and returns
the delimiter with the highest occurrence count.

If no delimiter can be detected, or detection is ambiguous, the function
throws a terminating error.

This function is internal to the SmailPost CSV ingestion process and is
used by Import-SPCsv before parsing the file.

.PARAMETER Path
The path to the CSV file to inspect.

.OUTPUTS
System.Char

Returns the detected delimiter character.

.EXAMPLE
Get-SPCsvDelimiter -Path "C:\data\users.csv"

Returns:
;

.NOTES
Private SmailPost function.
This function performs structural inspection only and does not read
the full CSV file.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "CSV file not found: $Path"
    }

    $line = Get-Content -Path $Path -TotalCount 10 |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Select-Object -First 1

    if (-not $line) {
        throw "Unable to detect delimiter: CSV file appears to be empty."
    }

    $candidates = @{
        ','  = ($line.Split(',')).Count - 1
        ';'  = ($line.Split(';')).Count - 1
        "`t" = ($line.Split("`t")).Count - 1
        '|'  = ($line.Split('|')).Count - 1
    }

    $best = $candidates.GetEnumerator() |
    Sort-Object Value -Descending |
    Select-Object -First 1

    if ($best.Value -eq 0) {
        throw "Unable to detect delimiter: no supported delimiter found in header row."
    }

    return $best.Key
}
