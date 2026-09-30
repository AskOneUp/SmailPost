Describe 'ConvertTo-SPMailJobReport' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Reporting\ConvertTo-SPMailJobReport.ps1')
    }

    It 'Returns a complete report object when all stages succeed' {
        $jobSetupResult = [pscustomobject]@{
            Status = 'Valid'
            Issues = @()
        }

        $rowValidationResults = @(
            [pscustomobject]@{
                Status = 'Valid'
                Issues = @()
            },
            [pscustomobject]@{
                Status = 'Valid'
                Issues = @()
            }
        )

        $renderResults = @(
            [pscustomobject]@{
                Status = 'Valid'
                Issues = @()
            },
            [pscustomobject]@{
                Status = 'Valid'
                Issues = @()
            }
        )

        $batchSendResult = [pscustomobject]@{
            BatchId     = 'batch-001'
            Status      = 'Sent'
            SentCount   = 2
            FailedCount = 0
            Results     = @(
                [pscustomobject]@{
                    RowNumber = 1
                    Notes     = @(
                        'Microsoft Graph throttled sendMail attempt 1.'
                        'Microsoft Graph accepted the sendMail request.'
                    )
                }
            )
        }

        $result = ConvertTo-SPMailJobReport `
            -JobSetupResult $jobSetupResult `
            -RowValidationResults $rowValidationResults `
            -RenderResults $renderResults `
            -BatchSendResult $batchSendResult

        $result.JobSetupStatus | Should -Be 'Valid'
        $result.RowValidationStatus | Should -Be 'Valid'
        $result.RenderStatus | Should -Be 'Valid'
        $result.BatchStatus | Should -Be 'Sent'
        $result.OverallStatus | Should -Be 'Sent'
        $result.TotalRows | Should -Be 2
        $result.ValidRowCount | Should -Be 2
        $result.InvalidRowCount | Should -Be 0
        $result.RenderedCount | Should -Be 2
        $result.SentCount | Should -Be 2
        $result.FailedCount | Should -Be 0
        $result.BatchId | Should -Be 'batch-001'
        $null -eq $result.BatchSendResult | Should -BeFalse
        $result.BatchSendResult.Results.Count | Should -Be 1
        $null -eq $result.BatchSendResult.Results[0].Notes | Should -BeFalse
        $result.BatchSendResult.Results[0].Notes.Count | Should -Be 2
        $result.BatchSendResult.Results[0].Notes[0] | Should -Be 'Microsoft Graph throttled sendMail attempt 1.'
        $result.BatchSendResult.Results[0].Notes[1] | Should -Be 'Microsoft Graph accepted the sendMail request.'
    }

    It 'Returns Invalid overall status when job setup is invalid' {
        $jobSetupResult = [pscustomobject]@{
            Status = 'Invalid'
            Issues = @(
                [pscustomobject]@{ Code = 'Setup.Invalid' }
            )
        }

        $result = ConvertTo-SPMailJobReport -JobSetupResult $jobSetupResult

        $result.JobSetupStatus | Should -Be 'Invalid'
        $result.OverallStatus | Should -Be 'Invalid'
        $result.SetupIssueCount | Should -Be 1
    }

    It 'Returns Partial row validation status when row results are mixed' {
        $jobSetupResult = [pscustomobject]@{
            Status = 'Valid'
            Issues = @()
        }

        $rowValidationResults = @(
            [pscustomobject]@{
                Status = 'Valid'
                Issues = @()
            },
            [pscustomobject]@{
                Status = 'Invalid'
                Issues = @(
                    [pscustomobject]@{ Code = 'Row.Invalid' }
                )
            }
        )

        $result = ConvertTo-SPMailJobReport `
            -JobSetupResult $jobSetupResult `
            -RowValidationResults $rowValidationResults

        $result.RowValidationStatus | Should -Be 'Partial'
        $result.TotalRows | Should -Be 2
        $result.ValidRowCount | Should -Be 1
        $result.InvalidRowCount | Should -Be 1
        $result.RowIssueCount | Should -Be 1
        $result.OverallStatus | Should -Be 'Partial'
    }

    It 'Returns Invalid render status when all render results are invalid' {
        $jobSetupResult = [pscustomobject]@{
            Status = 'Valid'
            Issues = @()
        }

        $renderResults = @(
            [pscustomobject]@{
                Status = 'Invalid'
                Issues = @(
                    [pscustomobject]@{ Code = 'Render.Invalid1' }
                )
            },
            [pscustomobject]@{
                Status = 'Invalid'
                Issues = @(
                    [pscustomobject]@{ Code = 'Render.Invalid2' }
                )
            }
        )

        $result = ConvertTo-SPMailJobReport `
            -JobSetupResult $jobSetupResult `
            -RenderResults $renderResults

        $result.RenderStatus | Should -Be 'Invalid'
        $result.RenderIssueCount | Should -Be 2
        $result.RenderedCount | Should -Be 2
        $result.OverallStatus | Should -Be 'Invalid'
    }

    It 'Returns Failed overall status when batch send failed' {
        $jobSetupResult = [pscustomobject]@{
            Status = 'Valid'
            Issues = @()
        }

        $batchSendResult = [pscustomobject]@{
            BatchId     = 'batch-002'
            Status      = 'Failed'
            SentCount   = 0
            FailedCount = 3
        }

        $result = ConvertTo-SPMailJobReport `
            -JobSetupResult $jobSetupResult `
            -BatchSendResult $batchSendResult

        $result.BatchStatus | Should -Be 'Failed'
        $result.OverallStatus | Should -Be 'Failed'
        $result.SentCount | Should -Be 0
        $result.FailedCount | Should -Be 3
        $result.BatchId | Should -Be 'batch-002'
    }

    It 'Throws when JobSetupResult is null' {
        {
            ConvertTo-SPMailJobReport -JobSetupResult $null
        } | Should -Throw 'JobSetupResult cannot be null.'
    }
}
