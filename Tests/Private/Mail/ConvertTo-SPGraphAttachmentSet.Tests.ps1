Describe 'ConvertTo-SPGraphAttachmentSet' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        # Create a stub so the Mock does not fail during discovery
        if (-not (Get-Command ConvertTo-SPGraphAttachment -ErrorAction SilentlyContinue)) {
            function ConvertTo-SPGraphAttachment {
                param (
                    $Path
                )
                $null = $Path
            }
        }

        . (Join-Path $script:ModuleRoot 'Private\Mail\ConvertTo-SPGraphAttachmentSet.ps1')
    }
    Context 'When no attachments are supplied' {
        It 'Returns an empty result with a note' {
            # Proves the function returns an empty result when no paths are supplied.
            $result = ConvertTo-SPGraphAttachmentSet

            $result | Should -Not -BeNullOrEmpty
            $result.AttachmentCount | Should -Be 0
            $result.AttachmentTotalBytes | Should -Be 0L
            $result.Attachments.Count | Should -Be 0
            $result.Notes | Should -Contain 'No attachments supplied.'
        }

        It 'Returns an empty result with a note when AttachmentPath is an empty array' {
            # Proves the function handles an explicit empty array like no input.
            $result = ConvertTo-SPGraphAttachmentSet -AttachmentPath @()

            $result | Should -Not -BeNullOrEmpty
            $result.AttachmentCount | Should -Be 0
            $result.AttachmentTotalBytes | Should -Be 0L
            $result.Attachments.Count | Should -Be 0
            $result.Notes | Should -Contain 'No attachments supplied.'
        }
    }

    Context 'When valid files are supplied' {
        BeforeAll {
            Mock ConvertTo-SPGraphAttachment {
                param (
                    $Path
                )

                return @{
                    name = [System.IO.Path]::GetFileName($Path)
                }
            }
        }

        It 'Builds a result for one attachment' {
            # Proves the function converts one file and increments the count.
            $filePath = Join-Path $TestDrive 'one.txt'
            'test' | Out-File -FilePath $filePath

            $expectedLength = [long](Get-Item -LiteralPath $filePath).Length

            $result = ConvertTo-SPGraphAttachmentSet -AttachmentPath $filePath

            $result.AttachmentCount | Should -Be 1
            $result.AttachmentTotalBytes | Should -Be $expectedLength
            $result.Attachments.Count | Should -Be 1
            $result.Attachments[0].name | Should -Be 'one.txt'
            $result.Notes | Should -Contain 'Built 1 Graph attachment object(s).'
            $result.Notes | Should -Contain ("Combined attachment size: {0} bytes." -f $expectedLength)
        }

        It 'Builds a result for multiple attachments' {
            # Proves the function converts multiple files and sums the total size.
            $fileOnePath = Join-Path $TestDrive 'one.txt'
            $fileTwoPath = Join-Path $TestDrive 'two.txt'

            'abc' | Out-File -FilePath $fileOnePath
            'hello' | Out-File -FilePath $fileTwoPath

            $expectedTotalBytes = [long](Get-Item -LiteralPath $fileOnePath).Length + [long](Get-Item -LiteralPath $fileTwoPath).Length

            $result = ConvertTo-SPGraphAttachmentSet -AttachmentPath @($fileOnePath, $fileTwoPath)

            $result.AttachmentCount | Should -Be 2
            $result.AttachmentTotalBytes | Should -Be $expectedTotalBytes
            $result.Attachments.Count | Should -Be 2
            $result.Attachments[0].name | Should -Be 'one.txt'
            $result.Attachments[1].name | Should -Be 'two.txt'
            $result.Notes | Should -Contain 'Built 2 Graph attachment object(s).'
            $result.Notes | Should -Contain ("Combined attachment size: {0} bytes." -f $expectedTotalBytes)
        }

        It 'Resolves relative paths before converting attachments' {
            # Proves relative paths are resolved correctly.
            $currentLocation = Get-Location

            try {
                Set-Location -Path $TestDrive

                $fileName = 'relative.txt'
                'relative' | Out-File -FilePath (Join-Path $TestDrive $fileName)

                $result = ConvertTo-SPGraphAttachmentSet -AttachmentPath ".\$fileName"

                $result.AttachmentCount | Should -Be 1
                $result.Attachments.Count | Should -Be 1
                $result.Attachments[0].name | Should -Be 'relative.txt'
            }
            finally {
                Set-Location -Path $currentLocation
            }
        }
    }

    Context 'When AttachmentPath contains invalid values' {
        It 'Throws when AttachmentPath contains whitespace' {
            # Proves the function rejects whitespace-only path entries.
            {
                ConvertTo-SPGraphAttachmentSet -AttachmentPath @('   ')
            } | Should -Throw 'Attachment path cannot be null, empty, or whitespace.'
        }

        It 'Throws when a supplied path does not exist' {
            # Proves the function fails when a path cannot be resolved.
            $missingFilePath = Join-Path $TestDrive 'missing.txt'

            {
                ConvertTo-SPGraphAttachmentSet -AttachmentPath @($missingFilePath)
            } | Should -Throw
        }

        It 'Throws when a supplied path points to a folder' {
            # Proves the function rejects directory paths.
            $folderPath = Join-Path $TestDrive 'FolderTarget'
            $null = New-Item -Path $folderPath -ItemType Directory

            {
                ConvertTo-SPGraphAttachmentSet -AttachmentPath @($folderPath)
            } | Should -Throw ("Attachment path '{0}' points to a folder, not a file." -f $folderPath)
        }
    }
}
