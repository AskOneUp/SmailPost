Describe 'Show-SPMailJobSummary' {

    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Public\Reporting\Show-SPMailJobSummary.ps1')
    }

    It 'Returns summary lines for a complete successful report' {
        $report = [pscustomobject]@{
            CreatedOn           = [datetime]'2026-03-13 22:45:00'
            BatchId             = 'batch-001'
            OverallStatus       = 'Sent'
            JobSetupStatus      = 'Valid'
            RowValidationStatus = 'Valid'
            RenderStatus        = 'Valid'
            BatchStatus         = 'Sent'
            SetupIssueCount     = 0
            RowIssueCount       = 0
            RenderIssueCount    = 0
            TotalRows           = 2
            ValidRowCount       = 2
            InvalidRowCount     = 0
            RenderedCount       = 2
            SentCount           = 2
            FailedCount         = 0
            BatchSendResult     = [pscustomobject]@{
                Results = @()
            }
        }

        $result = Show-SPMailJobSummary -Report $report

        $result | Should -Not -BeNullOrEmpty
        $result | Should -Contain 'SmailPost Mail Job Summary'
        $result | Should -Contain '========================'
        $result | Should -Contain 'BatchId: batch-001'
        $result | Should -Contain 'OverallStatus: Sent'
        $result | Should -Contain 'SentCount: 2'
        $result | Should -Contain 'FailedCount: 0'
    }

    It 'Includes failed row details when batch results contain failures' {
        $report = [pscustomobject]@{
            CreatedOn           = [datetime]'2026-03-13 22:45:00'
            BatchId             = 'batch-002'
            OverallStatus       = 'Partial'
            JobSetupStatus      = 'Valid'
            RowValidationStatus = 'Valid'
            RenderStatus        = 'Valid'
            BatchStatus         = 'Partial'
            SetupIssueCount     = 0
            RowIssueCount       = 0
            RenderIssueCount    = 0
            TotalRows           = 2
            ValidRowCount       = 2
            InvalidRowCount     = 0
            RenderedCount       = 2
            SentCount           = 1
            FailedCount         = 1
            BatchSendResult     = [pscustomobject]@{
                Results = @(
                    [pscustomobject]@{
                        RowNumber    = 2
                        Recipient    = 'broken@example.com'
                        Success      = $false
                        Status       = 'Failed'
                        ErrorMessage = 'Transport failed.'
                    }
                )
            }
        }

        $result = Show-SPMailJobSummary -Report $report

        $result | Should -Contain 'Failed Rows'
        $result | Should -Contain '-----------'
        $result | Should -Contain 'Row 2: Recipient=broken@example.com; Status=Failed; Error=Transport failed.'
    }

    It 'Throws when Report is null' {
        {
            Show-SPMailJobSummary -Report $null
        } | Should -Throw 'Report cannot be null.'
    }
}
