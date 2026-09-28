Describe 'ConvertTo-SPGraphAttachmentSet' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        # Create a stub so the Mock does not fail during discovery.
        if (-not (Get-Command ConvertTo-SPGraphAttachment -ErrorAction SilentlyContinue)) {
            function ConvertTo-SPGraphAttachment {
                param (
                    $Path,
                    $ContentId
                )

                $null = $Path
                $null = $ContentId
            }
        }

        . (Join-Path $script:ModuleRoot 'Private\Mail\ConvertTo-SPGraphAttachmentSet.ps1')
    }

    Context 'When no attachments are supplied' {
        It 'Returns an empty result with a note' {
            # Proves the function returns an empty result when no attachments are supplied.

            $result = ConvertTo-SPGraphAttachmentSet

            $result | Should -Not -BeNullOrEmpty
            $result.AttachmentCount | Should -Be 0
            $result.InlineImageCount | Should -Be 0
            $result.AttachmentTotalBytes | Should -Be 0L
            $result.Attachments.Count | Should -Be 0
            $result.Notes | Should -Contain 'No attachments supplied.'
        }

        It 'Returns an empty result when empty arrays are supplied' {
            # Proves explicit empty collections behave like no input.

            $result = ConvertTo-SPGraphAttachmentSet `
                -AttachmentPath @() `
                -InlineImage @()

            $result.AttachmentCount | Should -Be 0
            $result.InlineImageCount | Should -Be 0
            $result.AttachmentTotalBytes | Should -Be 0L
            $result.Attachments.Count | Should -Be 0
            $result.Notes | Should -Contain 'No attachments supplied.'
        }
    }

    Context 'When valid ordinary attachments are supplied' {
        BeforeAll {
            Mock ConvertTo-SPGraphAttachment {
                param (
                    $Path,
                    $ContentId
                )

                $attachment = @{
                    name = [System.IO.Path]::GetFileName($Path)
                }

                if (-not [string]::IsNullOrWhiteSpace($ContentId)) {
                    $attachment.isInline = $true
                    $attachment.contentId = $ContentId
                }

                return $attachment
            }
        }

        It 'Builds a result for one attachment' {
            # Proves the function converts one ordinary file and increments the count.

            $filePath = Join-Path $TestDrive 'one.txt'
            'test' | Out-File -FilePath $filePath

            $expectedLength = [long](Get-Item -LiteralPath $filePath).Length

            $result = ConvertTo-SPGraphAttachmentSet -AttachmentPath $filePath

            $result.AttachmentCount | Should -Be 1
            $result.InlineImageCount | Should -Be 0
            $result.AttachmentTotalBytes | Should -Be $expectedLength
            $result.Attachments.Count | Should -Be 1
            $result.Attachments[0].name | Should -Be 'one.txt'
            $result.Notes | Should -Contain 'Built 1 Graph attachment object(s).'
            $result.Notes | Should -Contain 'Inline images: 0.'
            $result.Notes | Should -Contain ("Combined attachment size: {0} bytes." -f $expectedLength)
        }

        It 'Builds a result for multiple attachments' {
            # Proves the function converts multiple ordinary files and sums their size.

            $fileOnePath = Join-Path $TestDrive 'one.txt'
            $fileTwoPath = Join-Path $TestDrive 'two.txt'

            'abc' | Out-File -FilePath $fileOnePath
            'hello' | Out-File -FilePath $fileTwoPath

            $expectedTotalBytes =
            [long](Get-Item -LiteralPath $fileOnePath).Length +
            [long](Get-Item -LiteralPath $fileTwoPath).Length

            $result = ConvertTo-SPGraphAttachmentSet `
                -AttachmentPath @($fileOnePath, $fileTwoPath)

            $result.AttachmentCount | Should -Be 2
            $result.InlineImageCount | Should -Be 0
            $result.AttachmentTotalBytes | Should -Be $expectedTotalBytes
            $result.Attachments.Count | Should -Be 2
            $result.Attachments[0].name | Should -Be 'one.txt'
            $result.Attachments[1].name | Should -Be 'two.txt'
            $result.Notes | Should -Contain 'Built 2 Graph attachment object(s).'
            $result.Notes | Should -Contain 'Inline images: 0.'
            $result.Notes | Should -Contain ("Combined attachment size: {0} bytes." -f $expectedTotalBytes)
        }

        It 'Resolves relative paths before converting attachments' {
            # Proves relative ordinary attachment paths are resolved correctly.

            $currentLocation = Get-Location

            try {
                Set-Location -Path $TestDrive

                $fileName = 'relative.txt'
                'relative' | Out-File -FilePath (Join-Path $TestDrive $fileName)

                $result = ConvertTo-SPGraphAttachmentSet `
                    -AttachmentPath ".\$fileName"

                $result.AttachmentCount | Should -Be 1
                $result.Attachments.Count | Should -Be 1
                $result.Attachments[0].name | Should -Be 'relative.txt'
            }
            finally {
                Set-Location -Path $currentLocation
            }
        }
    }

    Context 'When valid inline images are supplied' {
        BeforeAll {
            Mock ConvertTo-SPGraphAttachment {
                param (
                    $Path,
                    $ContentId
                )

                $attachment = @{
                    name = [System.IO.Path]::GetFileName($Path)
                }

                if (-not [string]::IsNullOrWhiteSpace($ContentId)) {
                    $attachment.isInline = $true
                    $attachment.contentId = $ContentId
                }

                return $attachment
            }
        }

        It 'Builds an inline attachment with the supplied ContentId' {
            # Proves an inline image is converted with its CID information.

            $imagePath = Join-Path $TestDrive 'connected-logo.png'
            [System.IO.File]::WriteAllBytes(
                $imagePath,
                [byte[]](1, 2, 3, 4)
            )

            $inlineImage = [pscustomobject]@{
                Path      = $imagePath
                ContentId = 'connected-logo'
            }

            $expectedLength = [long](Get-Item -LiteralPath $imagePath).Length

            $result = ConvertTo-SPGraphAttachmentSet `
                -InlineImage @($inlineImage)

            $result.AttachmentCount | Should -Be 1
            $result.InlineImageCount | Should -Be 1
            $result.AttachmentTotalBytes | Should -Be $expectedLength
            $result.Attachments.Count | Should -Be 1
            $result.Attachments[0].name | Should -Be 'connected-logo.png'
            $result.Attachments[0].isInline | Should -BeTrue
            $result.Attachments[0].contentId | Should -Be 'connected-logo'
            $result.Notes | Should -Contain 'Built 1 Graph attachment object(s).'
            $result.Notes | Should -Contain 'Inline images: 1.'
        }

        It 'Combines ordinary attachments and inline images' {
            # Proves both attachment types can coexist in one Graph attachment collection.

            $documentPath = Join-Path $TestDrive 'manual.pdf'
            $imagePath = Join-Path $TestDrive 'connected-logo.png'

            [System.IO.File]::WriteAllBytes(
                $documentPath,
                [byte[]](1, 2, 3)
            )

            [System.IO.File]::WriteAllBytes(
                $imagePath,
                [byte[]](4, 5, 6, 7)
            )

            $inlineImage = [pscustomobject]@{
                Path      = $imagePath
                ContentId = 'connected-logo'
            }

            $expectedTotalBytes =
            [long](Get-Item -LiteralPath $documentPath).Length +
            [long](Get-Item -LiteralPath $imagePath).Length

            $result = ConvertTo-SPGraphAttachmentSet `
                -AttachmentPath @($documentPath) `
                -InlineImage @($inlineImage)

            $result.AttachmentCount | Should -Be 2
            $result.InlineImageCount | Should -Be 1
            $result.AttachmentTotalBytes | Should -Be $expectedTotalBytes
            $result.Attachments.Count | Should -Be 2

            $result.Attachments[0].name | Should -Be 'manual.pdf'
            $result.Attachments[0].ContainsKey('contentId') | Should -BeFalse

            $result.Attachments[1].name | Should -Be 'connected-logo.png'
            $result.Attachments[1].isInline | Should -BeTrue
            $result.Attachments[1].contentId | Should -Be 'connected-logo'

            $result.Notes | Should -Contain 'Built 2 Graph attachment object(s).'
            $result.Notes | Should -Contain 'Inline images: 1.'
            $result.Notes | Should -Contain ("Combined attachment size: {0} bytes." -f $expectedTotalBytes)
        }

        It 'Resolves a relative inline image path' {
            # Proves relative inline image paths are resolved correctly.

            $currentLocation = Get-Location

            try {
                Set-Location -Path $TestDrive

                $imageName = 'relative-logo.png'
                [System.IO.File]::WriteAllBytes(
                    (Join-Path $TestDrive $imageName),
                    [byte[]](1, 2, 3)
                )

                $inlineImage = [pscustomobject]@{
                    Path      = ".\$imageName"
                    ContentId = 'relative-logo'
                }

                $result = ConvertTo-SPGraphAttachmentSet `
                    -InlineImage @($inlineImage)

                $result.AttachmentCount | Should -Be 1
                $result.InlineImageCount | Should -Be 1
                $result.Attachments[0].name | Should -Be 'relative-logo.png'
                $result.Attachments[0].contentId | Should -Be 'relative-logo'
            }
            finally {
                Set-Location -Path $currentLocation
            }
        }
    }

    Context 'When AttachmentPath contains invalid values' {
        It 'Throws when AttachmentPath contains whitespace' {
            # Proves the function rejects whitespace-only ordinary attachment paths.

            {
                ConvertTo-SPGraphAttachmentSet `
                    -AttachmentPath @('   ')
            } | Should -Throw 'Attachment path cannot be null, empty, or whitespace.'
        }

        It 'Throws when a supplied path does not exist' {
            # Proves the function fails when an ordinary attachment cannot be resolved.

            $missingFilePath = Join-Path $TestDrive 'missing.txt'

            {
                ConvertTo-SPGraphAttachmentSet `
                    -AttachmentPath @($missingFilePath)
            } | Should -Throw
        }

        It 'Throws when a supplied path points to a folder' {
            # Proves the function rejects directory paths for ordinary attachments.

            $folderPath = Join-Path $TestDrive 'FolderTarget'
            $null = New-Item -Path $folderPath -ItemType Directory

            {
                ConvertTo-SPGraphAttachmentSet `
                    -AttachmentPath @($folderPath)
            } | Should -Throw ("Attachment path '{0}' points to a folder, not a file." -f $folderPath)
        }
    }

    Context 'When InlineImage contains invalid values' {
        It 'Throws when an inline image definition is null' {
            # Proves null inline image definitions are rejected.

            {
                ConvertTo-SPGraphAttachmentSet `
                    -InlineImage @($null)
            } | Should -Throw 'Inline image definition cannot be null.'
        }

        It 'Throws when inline image Path is whitespace' {
            # Proves every inline image requires a usable file path.

            $inlineImage = [pscustomobject]@{
                Path      = '   '
                ContentId = 'connected-logo'
            }

            {
                ConvertTo-SPGraphAttachmentSet `
                    -InlineImage @($inlineImage)
            } | Should -Throw 'Inline image path cannot be null, empty, or whitespace.'
        }

        It 'Throws when inline image ContentId is whitespace' {
            # Proves every inline image requires a usable ContentId.

            $imagePath = Join-Path $TestDrive 'logo-no-cid.png'
            [System.IO.File]::WriteAllBytes(
                $imagePath,
                [byte[]](1, 2, 3)
            )

            $inlineImage = [pscustomobject]@{
                Path      = $imagePath
                ContentId = '   '
            }

            {
                ConvertTo-SPGraphAttachmentSet `
                    -InlineImage @($inlineImage)
            } | Should -Throw 'Inline image ContentId cannot be null, empty, or whitespace.'
        }

        It 'Throws when inline image path does not exist' {
            # Proves an inline image file must exist.

            $inlineImage = [pscustomobject]@{
                Path      = (Join-Path $TestDrive 'missing-logo.png')
                ContentId = 'connected-logo'
            }

            {
                ConvertTo-SPGraphAttachmentSet `
                    -InlineImage @($inlineImage)
            } | Should -Throw
        }

        It 'Throws when inline image path points to a folder' {
            # Proves directories cannot be used as inline image resources.

            $folderPath = Join-Path $TestDrive 'InlineFolder'
            $null = New-Item -Path $folderPath -ItemType Directory

            $inlineImage = [pscustomobject]@{
                Path      = $folderPath
                ContentId = 'connected-logo'
            }

            {
                ConvertTo-SPGraphAttachmentSet `
                    -InlineImage @($inlineImage)
            } | Should -Throw ("Inline image path '{0}' points to a folder, not a file." -f $folderPath)
        }
    }
}
