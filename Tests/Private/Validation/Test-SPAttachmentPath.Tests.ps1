Describe "Test-SPAttachmentPath" {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Validation\Test-SPAttachmentPath.ps1')
    }

    It "Returns valid for an existing readable file" {
        $file = New-TemporaryFile

        $result = Test-SPAttachmentPath -Path $file.FullName

        $result.IsValid | Should -BeTrue
        $result.ResolvedPath | Should -Be $file.FullName
        $result.ErrorCode | Should -Be ''
    }

    It "Trims whitespace before validation" {
        $file = New-TemporaryFile
        $pathWithSpaces = "  $($file.FullName)  "

        $result = Test-SPAttachmentPath -Path $pathWithSpaces

        $result.IsValid | Should -BeTrue
        $result.ResolvedPath | Should -Be $file.FullName
    }

    It "Returns invalid when path is empty" {
        $result = Test-SPAttachmentPath -Path ''

        $result.IsValid | Should -BeFalse
        $result.ErrorCode | Should -Be 'ATTACHMENT_PATH_EMPTY'
    }

    It "Returns invalid when path is null" {
        $result = Test-SPAttachmentPath -Path $null

        $result.IsValid | Should -BeFalse
        $result.ErrorCode | Should -Be 'ATTACHMENT_PATH_EMPTY'
    }

    It "Returns invalid when file does not exist" {
        $result = Test-SPAttachmentPath -Path 'C:\Does\Not\Exist\ghost.pdf'

        $result.IsValid | Should -BeFalse
        $result.ErrorCode | Should -Be 'ATTACHMENT_NOT_FOUND'
    }

}
