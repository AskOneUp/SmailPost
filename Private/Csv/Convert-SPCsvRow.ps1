function Convert-SPCsvRow {

    <#
.SYNOPSIS
Converts a raw CSV data line into a structured row object.

.DESCRIPTION
Splits a CSV data line using the provided delimiter and maps the resulting
values to the supplied header list.

The function performs the following actions:

- Splits the raw line by delimiter.
- Trims whitespace from each value.
- Pads missing trailing values with empty strings.
- Throws if the row contains more values than headers.
- Returns a structured object containing the row number, raw line, and
  a value map of header-to-value pairs.

This function is part of the SmailPost CSV ingestion pipeline and is
used by Import-SPCsv to convert raw data rows into a normalized format.

.PARAMETER Line
The raw CSV data line.

.PARAMETER Headers
The validated header list in original order.

.PARAMETER Delimiter
The delimiter character used by the CSV file.

.PARAMETER RowNumber
The source row number in the CSV file.

.OUTPUTS
PSCustomObject

Returns a row object with RowNumber, RawLine, and Values.

.EXAMPLE
Convert-SPCsvRow -Line "john@x.com,John,Acme" -Headers $headers -Delimiter ',' -RowNumber 2

.NOTES
Private SmailPost function.
This function expects headers to already be validated.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Line,

        [Parameter(Mandatory)]
        [string[]]$Headers,

        [Parameter(Mandatory)]
        [char]$Delimiter,

        [Parameter(Mandatory)]
        [int]$RowNumber
    )

    $values = $Line.Split($Delimiter) | ForEach-Object {
        $_.Trim()
    }

    if ($values.Count -gt $Headers.Count) {
        throw "CSV row $RowNumber contains more values than headers."
    }

    while ($values.Count -lt $Headers.Count) {
        $values += ''
    }

    $valueMap = [ordered]@{}

    for ($index = 0; $index -lt $Headers.Count; $index++) {
        $valueMap[$Headers[$index]] = $values[$index]
    }

    return [pscustomobject]@{
        RowNumber = $RowNumber
        RawLine   = $Line
        Values    = [pscustomobject]$valueMap
    }
}
