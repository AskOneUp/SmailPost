Describe 'ConvertTo-SPGraphAttachment' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Mail\ConvertTo-SPGraphAttachment.ps1')
    }

    Context 'When Path is valid' {

        It 'Builds a Graph attachment for a txt file' {
            # Proves the function reads a file, encodes it as Base64, and assigns the expected MIME type.

            $testFilePath = Join-Path -Path $TestDrive -ChildPath 'sample.txt'
            $testContent = 'Hello attachment world.'
            [System.IO.File]::WriteAllText($testFilePath, $testContent)

            $result = ConvertTo-SPGraphAttachment -Path $testFilePath

            $expectedBase64 = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($testFilePath))

            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType ([hashtable])

            $result.'@odata.type' | Should -Be '#microsoft.graph.fileAttachment'
            $result.name | Should -Be 'sample.txt'
            $result.contentType | Should -Be 'text/plain'
            $result.contentBytes | Should -Be $expectedBase64
        }

        It 'Builds a Graph attachment for a pdf file' {
            # Proves known file extensions map to the expected MIME type.

            $testFilePath = Join-Path -Path $TestDrive -ChildPath 'document.pdf'
            [System.IO.File]::WriteAllBytes($testFilePath, [byte[]](1, 2, 3, 4))

            $result = ConvertTo-SPGraphAttachment -Path $testFilePath

            $result.name | Should -Be 'document.pdf'
            $result.contentType | Should -Be 'application/pdf'
            $result.contentBytes | Should -Not -BeNullOrEmpty
        }

        It 'Uses application/octet-stream for an unknown file extension' {
            # Proves unknown extensions fall back to the default MIME type.

            $testFilePath = Join-Path -Path $TestDrive -ChildPath 'archive.weirdthing'
            [System.IO.File]::WriteAllText($testFilePath, 'mystery')

            $result = ConvertTo-SPGraphAttachment -Path $testFilePath

            $result.name | Should -Be 'archive.weirdthing'
            $result.contentType | Should -Be 'application/octet-stream'
        }

        It 'Uses application/octet-stream when the file has no extension' {
            # Proves files without an extension use the default MIME type.

            $testFilePath = Join-Path -Path $TestDrive -ChildPath 'README'
            [System.IO.File]::WriteAllText($testFilePath, 'plain content')

            $result = ConvertTo-SPGraphAttachment -Path $testFilePath

            $result.name | Should -Be 'README'
            $result.contentType | Should -Be 'application/octet-stream'
        }

        It 'Resolves a relative path correctly' {
            # Proves the function works with relative paths after location change.

            $currentLocation = Get-Location

            try {
                Set-Location -Path $TestDrive

                $relativeFileName = 'relative.txt'
                [System.IO.File]::WriteAllText((Join-Path -Path $TestDrive -ChildPath $relativeFileName), 'relative content')

                $result = ConvertTo-SPGraphAttachment -Path ".\$relativeFileName"

                $result.name | Should -Be 'relative.txt'
                $result.contentType | Should -Be 'text/plain'
            }
            finally {
                Set-Location -Path $currentLocation
            }
        }
    }

    Context 'When Path is invalid' {

        It 'Throws binding error when Path is empty' {
            # Proves PowerShell parameter binding rejects an empty path string.

            {
                ConvertTo-SPGraphAttachment -Path ''
            } | Should -Throw "Cannot bind argument to parameter 'Path' because it is an empty string."
        }

        It 'Throws when Path is whitespace' {
            # Proves the function rejects a whitespace-only path.

            {
                ConvertTo-SPGraphAttachment -Path '   '
            } | Should -Throw 'Attachment path cannot be null, empty, or whitespace.'
        }

        It 'Throws when Path does not exist' {
            # Proves the function fails when the target file cannot be resolved.

            $missingFilePath = Join-Path -Path $TestDrive -ChildPath 'missing.txt'

            {
                ConvertTo-SPGraphAttachment -Path $missingFilePath
            } | Should -Throw
        }

        It 'Throws when Path points to a folder' {
            # Proves the function rejects directories.

            $folderPath = Join-Path -Path $TestDrive -ChildPath 'FolderTarget'
            $null = New-Item -Path $folderPath -ItemType Directory

            {
                ConvertTo-SPGraphAttachment -Path $folderPath
            } | Should -Throw ("Attachment path '{0}' points to a folder, not a file." -f $folderPath)
        }
    }
}
