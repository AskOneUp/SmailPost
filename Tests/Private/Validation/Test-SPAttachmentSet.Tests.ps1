Describe 'Test-SPAttachmentSet' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Validation\Test-SPAttachmentSet.ps1')
    }

    Context 'When no attachments are supplied' {
        It 'Returns a valid result with zero attachments' {
            # Proves the function accepts missing attachment input as valid.
            $result = Test-SPAttachmentSet

            $result | Should -Not -BeNullOrEmpty
            $result.Valid | Should -BeTrue
            $result.AttachmentCount | Should -Be 0
            $result.AttachmentTotalBytes | Should -Be 0L
            $result.ValidPaths.Count | Should -Be 0
            $result.InvalidPaths.Count | Should -Be 0
            $result.Notes | Should -Contain 'No attachments supplied.'
        }

        It 'Returns a valid result when AttachmentPath is an empty array' {
            # Proves the function handles an explicit empty array as valid.
            $result = Test-SPAttachmentSet -AttachmentPath @()

            $result.Valid | Should -BeTrue
            $result.AttachmentCount | Should -Be 0
            $result.AttachmentTotalBytes | Should -Be 0L
            $result.ValidPaths.Count | Should -Be 0
            $result.InvalidPaths.Count | Should -Be 0
            $result.Notes | Should -Contain 'No attachments supplied.'
        }
    }

    Context 'When valid attachment files are supplied' {
        It 'Returns a valid result for one readable file' {
            # Proves the function validates one readable attachment file.
            $filePath = Join-Path $TestDrive 'one.txt'
            'test' | Out-File -FilePath $filePath

            $expectedLength = [long](Get-Item -LiteralPath $filePath).Length

            $result = Test-SPAttachmentSet -AttachmentPath $filePath

            $result.Valid | Should -BeTrue
            $result.AttachmentCount | Should -Be 1
            $result.AttachmentTotalBytes | Should -Be $expectedLength
            $result.ValidPaths.Count | Should -Be 1
            $result.ValidPaths[0] | Should -Be (Resolve-Path -Path $filePath).ProviderPath
            $result.InvalidPaths.Count | Should -Be 0
            $result.Notes | Should -Contain 'Validated 1 attachment file(s).'
            $result.Notes | Should -Contain ("Combined attachment size: {0} bytes." -f $expectedLength)
        }

        It 'Returns a valid result for multiple readable files' {
            # Proves the function validates multiple files and sums their size.
            $fileOnePath = Join-Path $TestDrive 'one.txt'
            $fileTwoPath = Join-Path $TestDrive 'two.txt'

            'abc' | Out-File -FilePath $fileOnePath
            'hello' | Out-File -FilePath $fileTwoPath

            $resolvedOnePath = (Resolve-Path -Path $fileOnePath).ProviderPath
            $resolvedTwoPath = (Resolve-Path -Path $fileTwoPath).ProviderPath
            $expectedTotalBytes = [long](Get-Item -LiteralPath $fileOnePath).Length + [long](Get-Item -LiteralPath $fileTwoPath).Length

            $result = Test-SPAttachmentSet -AttachmentPath @($fileOnePath, $fileTwoPath)

            $result.Valid | Should -BeTrue
            $result.AttachmentCount | Should -Be 2
            $result.AttachmentTotalBytes | Should -Be $expectedTotalBytes
            $result.ValidPaths.Count | Should -Be 2
            $result.ValidPaths[0] | Should -Be $resolvedOnePath
            $result.ValidPaths[1] | Should -Be $resolvedTwoPath
            $result.InvalidPaths.Count | Should -Be 0
            $result.Notes | Should -Contain 'Validated 2 attachment file(s).'
            $result.Notes | Should -Contain ("Combined attachment size: {0} bytes." -f $expectedTotalBytes)
        }
    }

    Context 'When attachment paths are invalid' {
        It 'Returns an invalid result for a whitespace path' {
            # Proves the function rejects a whitespace-only attachment path.
            $result = Test-SPAttachmentSet -AttachmentPath @('   ')

            $result.Valid | Should -BeFalse
            $result.AttachmentCount | Should -Be 0
            $result.ValidPaths.Count | Should -Be 0
            $result.InvalidPaths.Count | Should -Be 1
            $result.InvalidPaths[0] | Should -Be '   '
            $result.Notes | Should -Contain 'An attachment path is empty or whitespace.'
            $result.Notes | Should -Contain 'One or more attachment files are invalid.'
        }

        It 'Returns an invalid result for a missing file' {
            # Proves the function rejects a path that does not exist.
            $missingFilePath = Join-Path $TestDrive 'missing.txt'

            $result = Test-SPAttachmentSet -AttachmentPath @($missingFilePath)

            $result.Valid | Should -BeFalse
            $result.AttachmentCount | Should -Be 0
            $result.ValidPaths.Count | Should -Be 0
            $result.InvalidPaths.Count | Should -Be 1
            $result.InvalidPaths[0] | Should -Be $missingFilePath
            $result.Notes | Should -Contain ("Attachment path not found: {0}" -f $missingFilePath)
            $result.Notes | Should -Contain 'One or more attachment files are invalid.'
        }

        It 'Returns an invalid result for a folder path' {
            # Proves the function rejects a directory path.
            $folderPath = Join-Path $TestDrive 'FolderTarget'
            $null = New-Item -Path $folderPath -ItemType Directory

            $resolvedFolderPath = (Resolve-Path -Path $folderPath).ProviderPath

            $result = Test-SPAttachmentSet -AttachmentPath @($folderPath)

            $result.Valid | Should -BeFalse
            $result.AttachmentCount | Should -Be 0
            $result.ValidPaths.Count | Should -Be 0
            $result.InvalidPaths.Count | Should -Be 1
            $result.InvalidPaths[0] | Should -Be $resolvedFolderPath
            $result.Notes | Should -Contain ("Attachment path is a folder, not a file: {0}" -f $resolvedFolderPath)
            $result.Notes | Should -Contain 'One or more attachment files are invalid.'
        }
    }

    Context 'When combined attachment size exceeds the limit' {
        It 'Returns an invalid result when total bytes exceed MaxTotalBytes' {
            # Proves the function rejects otherwise valid files when the total size is too large.
            $fileOnePath = Join-Path $TestDrive 'one.txt'
            $fileTwoPath = Join-Path $TestDrive 'two.txt'

            'abc' | Out-File -FilePath $fileOnePath
            'hello' | Out-File -FilePath $fileTwoPath

            $totalBytes = [long](Get-Item -LiteralPath $fileOnePath).Length + [long](Get-Item -LiteralPath $fileTwoPath).Length
            $maxTotalBytes = $totalBytes - 1

            $result = Test-SPAttachmentSet -AttachmentPath @($fileOnePath, $fileTwoPath) -MaxTotalBytes $maxTotalBytes

            $result.Valid | Should -BeFalse
            $result.AttachmentCount | Should -Be 2
            $result.AttachmentTotalBytes | Should -Be $totalBytes
            $result.ValidPaths.Count | Should -Be 2
            $result.InvalidPaths.Count | Should -Be 0
            $result.Notes | Should -Contain (
                "Combined attachment size {0} bytes exceeds the configured limit of {1} bytes." -f
                $totalBytes,
                $maxTotalBytes
            )
        }
    }
}
