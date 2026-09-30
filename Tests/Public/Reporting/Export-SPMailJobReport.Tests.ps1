Describe 'Export-SPMailJobReport' {

    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Csv\Convert-SPCsvRow.ps1')
        . (Join-Path $script:ModuleRoot 'Public\Reporting\Export-SPMailJobReport.ps1')
    }

    It 'Exports a report to JSON successfully' {
        $report = [pscustomobject]@{
            BatchId       = 'batch-001'
            OverallStatus = 'Sent'
            SentCount     = 2
            FailedCount   = 0
        }

        $path = Join-Path -Path $TestDrive -ChildPath 'report.json'

        $result = Export-SPMailJobReport `
            -Report $report `
            -Path $path `
            -Format Json `
            -Confirm:$false

        $result.Exported | Should -BeTrue
        $result.Cancelled | Should -BeFalse
        $result.Path | Should -Be $path
        $result.Format | Should -Be 'Json'

        Test-Path -LiteralPath $path | Should -BeTrue

        $content = Get-Content -LiteralPath $path -Raw
        $content | Should -Match '"BatchId"\s*:\s*"batch-001"'
        $content | Should -Match '"OverallStatus"\s*:\s*"Sent"'
    }

    It 'Exports a report to CSV successfully' {
        $report = [pscustomobject]@{
            CreatedOn       = [datetime]'2026-03-13 23:00:00'
            BatchId         = 'batch-010'
            OverallStatus   = 'Partial'
            BatchSendResult = [pscustomobject]@{
                Results = @(
                    [pscustomobject]@{
                        RowNumber       = 1
                        Recipient       = 'user1@example.com'
                        SenderAddress   = 'askoneup@askoneup.com'
                        Subject         = 'Hello One'
                        Success         = $true
                        Status          = 'Sent'
                        ErrorMessage    = ''
                        AttemptedOn     = [datetime]'2026-03-13 23:01:00'
                        AttachmentCount = 1
                        Notes           = @(
                            'Microsoft Graph throttled sendMail attempt 1.'
                            'Microsoft Graph accepted the sendMail request.'
                        )
                    },
                    [pscustomobject]@{
                        RowNumber       = 2
                        Recipient       = 'user2@example.com'
                        SenderAddress   = 'askoneup@askoneup.com'
                        Subject         = 'Hello Two'
                        Success         = $false
                        Status          = 'Failed'
                        ErrorMessage    = 'Transport failed.'
                        AttemptedOn     = [datetime]'2026-03-13 23:02:00'
                        AttachmentCount = 0
                        Notes           = @(
                            'Microsoft Graph throttled sendMail attempt 1.'
                            'Microsoft Graph throttled sendMail attempt 2.'
                        )
                    }
                )
            }
        }

        $path = Join-Path -Path $TestDrive -ChildPath 'report.csv'

        $result = Export-SPMailJobReport `
            -Report $report `
            -Path $path `
            -Format Csv `
            -Confirm:$false

        $result.Exported | Should -BeTrue
        $result.Cancelled | Should -BeFalse
        $result.Path | Should -Be $path
        $result.Format | Should -Be 'Csv'

        Test-Path -LiteralPath $path | Should -BeTrue

        $rows = Import-Csv -LiteralPath $path
        $rows.Count | Should -Be 2
        $rows[0].BatchId | Should -Be 'batch-010'
        $rows[0].Recipient | Should -Be 'user1@example.com'
        $rows[0].Status | Should -Be 'Sent'
        $rows[0].Notes | Should -Be 'Microsoft Graph throttled sendMail attempt 1. | Microsoft Graph accepted the sendMail request.'

        $rows[1].Recipient | Should -Be 'user2@example.com'
        $rows[1].Status | Should -Be 'Failed'
        $rows[1].ErrorMessage | Should -Be 'Transport failed.'
        $rows[1].Notes | Should -Be 'Microsoft Graph throttled sendMail attempt 1. | Microsoft Graph throttled sendMail attempt 2.'
    }

    It 'Exports an empty-shape CSV when no batch results exist' {
        $report = [pscustomobject]@{
            CreatedOn       = [datetime]'2026-03-13 23:00:00'
            BatchId         = 'batch-011'
            OverallStatus   = 'Invalid'
            BatchSendResult = $null
        }

        $path = Join-Path -Path $TestDrive -ChildPath 'empty-report.csv'

        $result = Export-SPMailJobReport `
            -Report $report `
            -Path $path `
            -Format Csv `
            -Confirm:$false

        $result.Exported | Should -BeTrue
        Test-Path -LiteralPath $path | Should -BeTrue

        $rows = Import-Csv -LiteralPath $path
        $rows.Count | Should -Be 1
        $rows[0].BatchId | Should -Be 'batch-011'
        $rows[0].OverallStatus | Should -Be 'Invalid'
        $rows[0].Recipient | Should -Be ''
        $rows[0].Status | Should -Be ''

        $null -eq $rows[0].PSObject.Properties['Notes'] | Should -BeFalse
        $rows[0].Notes | Should -Be ''
    }

    It 'Creates the parent directory when it does not exist' {
        $report = [pscustomobject]@{
            BatchId       = 'batch-002'
            OverallStatus = 'Failed'
        }

        $folderPath = Join-Path -Path $TestDrive -ChildPath 'Reports'
        $path = Join-Path -Path $folderPath -ChildPath 'report.json'

        $result = Export-SPMailJobReport `
            -Report $report `
            -Path $path `
            -Confirm:$false

        $result.Exported | Should -BeTrue
        Test-Path -LiteralPath $folderPath | Should -BeTrue
        Test-Path -LiteralPath $path | Should -BeTrue
    }

    It 'Throws when Report is null' {
        {
            Export-SPMailJobReport `
                -Report $null `
                -Path (Join-Path -Path $TestDrive -ChildPath 'report.json') `
                -Confirm:$false
        } | Should -Throw 'Report cannot be null.'
    }

    It 'Throws when Path is empty' {
        $report = [pscustomobject]@{
            BatchId = 'batch-003'
        }

        {
            Export-SPMailJobReport `
                -Report $report `
                -Path '   ' `
                -Confirm:$false
        } | Should -Throw 'Path cannot be null, empty, or whitespace.'
    }

    It 'Returns a cancelled result when ShouldProcess declines the export' {
        $report = [pscustomobject]@{
            BatchId = 'batch-004'
        }

        $path = Join-Path -Path $TestDrive -ChildPath 'cancelled.json'

        $result = Export-SPMailJobReport `
            -Report $report `
            -Path $path `
            -WhatIf

        $result.Exported | Should -BeFalse
        $result.Cancelled | Should -BeTrue
        Test-Path -LiteralPath $path | Should -BeFalse
    }
}
