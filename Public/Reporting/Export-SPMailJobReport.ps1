function Export-SPMailJobReport {
    <#
        .SYNOPSIS
        Exports a SmailPost mail job report to disk.

        .DESCRIPTION
        Export-SPMailJobReport writes a canonical SmailPost job report to a file
        for audit, troubleshooting, and later review.

        Version 1 supports JSON and CSV export.

        .PARAMETER Report
        The canonical SmailPost job report created by ConvertTo-SPMailJobReport or
        returned by Invoke-SPMailJob.

        .PARAMETER Path
        The output file path.

        .PARAMETER Format
        The export format. Supported values are Json and Csv.

        .PARAMETER Depth
        The JSON serialization depth.

        .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(PositionalBinding = $false, SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [psobject]$Report,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [ValidateSet('Json', 'Csv')]
        [string]$Format = 'Json',

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$Depth = 20
    )

    if ($null -eq $Report) {
        throw 'Report cannot be null.'
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Path cannot be null, empty, or whitespace.'
    }

    $resolvedPath = $Path.Trim()
    $parentPath = Split-Path -Path $resolvedPath -Parent

    if (-not [string]::IsNullOrWhiteSpace($parentPath) -and -not (Test-Path -LiteralPath $parentPath)) {
        New-Item -Path $parentPath -ItemType Directory -Force | Out-Null
    }

    if (-not $PSCmdlet.ShouldProcess($resolvedPath, "Export SmailPost report as $Format")) {
        return [pscustomobject]@{
            Path      = $resolvedPath
            Format    = $Format
            Exported  = $false
            Cancelled = $true
        }
    }

    switch ($Format) {
        'Json' {
            $content = $Report | ConvertTo-Json -Depth $Depth
            Set-Content -LiteralPath $resolvedPath -Value $content -Encoding UTF8
        }

        'Csv' {
            $createdOn = ''
            if ($null -ne $Report.CreatedOn) {
                $createdOn = [datetime]$Report.CreatedOn
            }

            $batchId = ''
            if ($null -ne $Report.BatchId) {
                $batchId = [string]$Report.BatchId
            }

            $overallStatus = ''
            if ($null -ne $Report.OverallStatus) {
                $overallStatus = [string]$Report.OverallStatus
            }

            $rows = [System.Collections.Generic.List[object]]::new()
            $batchResults = @()

            if ($null -ne $Report.BatchSendResult -and $null -ne $Report.BatchSendResult.Results) {
                $batchResults = @($Report.BatchSendResult.Results)
            }

            if ($batchResults.Count -eq 0) {
                $rows.Add([pscustomobject][ordered]@{
                    BatchId         = $batchId
                    CreatedOn       = $createdOn
                    OverallStatus   = $overallStatus
                    RowNumber       = $null
                    Recipient       = ''
                    SenderAddress   = ''
                    Subject         = ''
                    Success         = $null
                    Status          = ''
                    ErrorMessage    = ''
                    AttemptedOn     = $null
                    AttachmentCount = $null
                })
            }
            else {
                foreach ($batchResult in $batchResults) {
                    $rows.Add([pscustomobject][ordered]@{
                        BatchId         = $batchId
                        CreatedOn       = $createdOn
                        OverallStatus   = $overallStatus
                        RowNumber       = $batchResult.RowNumber
                        Recipient       = $batchResult.Recipient
                        SenderAddress   = $batchResult.SenderAddress
                        Subject         = $batchResult.Subject
                        Success         = $batchResult.Success
                        Status          = $batchResult.Status
                        ErrorMessage    = $batchResult.ErrorMessage
                        AttemptedOn     = $batchResult.AttemptedOn
                        AttachmentCount = $batchResult.AttachmentCount
                    })
                }
            }

            $rows | Export-Csv -LiteralPath $resolvedPath -NoTypeInformation -Encoding UTF8
        }

        default {
            throw "Unsupported export format '$Format'."
        }
    }

    return [pscustomobject]@{
        Path      = $resolvedPath
        Format    = $Format
        Exported  = $true
        Cancelled = $false
    }
}
