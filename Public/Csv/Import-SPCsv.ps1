function Import-SPCsv {

    <#
.SYNOPSIS
Imports a CSV file into a structured SmailPost CSV result.

.DESCRIPTION
Reads a CSV file, detects the delimiter, validates the header row,
and converts each non-empty data row into a structured row object.

The function performs the following actions:

- Verifies the CSV file exists.
- Detects the delimiter by inspecting the first non-empty line.
- Reads and validates the header row.
- Skips empty data rows.
- Converts data rows into structured row objects.

This function is the public entry point for CSV ingestion in SmailPost
and prepares CSV data for validation, preview, and send preparation.

.PARAMETER Path
The path to the CSV file to import.

.OUTPUTS
PSCustomObject

Returns an import result object containing file metadata, headers, and rows.

.EXAMPLE
Import-SPCsv -Path "C:\Data\Recipients.csv"

.NOTES
Public SmailPost function.
This function relies on internal CSV helper functions.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "CSV file not found: $Path"
    }

    $lines = Get-Content -Path $Path

    $nonEmptyLines = $lines | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    }

    if (-not $nonEmptyLines -or $nonEmptyLines.Count -eq 0) {
        throw "CSV file appears to be empty."
    }

    $delimiter = Get-SPCsvDelimiter -Path $Path
    $headerLine = $nonEmptyLines[0]
    $headers = Test-SPCsvHeader -HeaderLine $headerLine -Delimiter $delimiter

    $rows = @()
    $rowNumber = 2

    foreach ($line in ($nonEmptyLines | Select-Object -Skip 1)) {
        $rows += Convert-SPCsvRow -Line $line -Headers $headers -Delimiter $delimiter -RowNumber $rowNumber
        $rowNumber++
    }

    return [pscustomobject]@{
        Path      = $Path
        Delimiter = $delimiter
        Headers   = $headers
        Rows      = $rows
        RowCount  = $rows.Count
    }
}
