function Test-SPAttachmentPath {

    <#
.SYNOPSIS
Validates an attachment file path.

.DESCRIPTION
Checks whether an attachment path is present, points to an existing file,
and can be opened for reading.

This function is used during preflight validation to ensure that selected
attachments are available before preview or sending begins.

.PARAMETER Path
The attachment file path to validate.

.OUTPUTS
PSCustomObject

Returns an object containing:
- OriginalPath
- ResolvedPath
- IsValid
- ErrorCode
- ErrorMessage

.NOTES
Private SmailPost function.
Used by job-level validation before preview or sending.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Path
    )

    $resolvedPath = ''

    if ($null -ne $Path) {
        $resolvedPath = $Path.Trim()
    }

    if ([string]::IsNullOrWhiteSpace($resolvedPath)) {
        return [pscustomobject]@{
            OriginalPath = $Path
            ResolvedPath = $resolvedPath
            IsValid      = $false
            ErrorCode    = 'ATTACHMENT_PATH_EMPTY'
            ErrorMessage = 'Attachment path is empty.'
        }
    }

    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        return [pscustomobject]@{
            OriginalPath = $Path
            ResolvedPath = $resolvedPath
            IsValid      = $false
            ErrorCode    = 'ATTACHMENT_NOT_FOUND'
            ErrorMessage = 'Attachment file was not found.'
        }
    }

    try {
        $fileStream = [System.IO.File]::Open(
            $resolvedPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )

        $fileStream.Dispose()
    }
    catch {
        return [pscustomobject]@{
            OriginalPath = $Path
            ResolvedPath = $resolvedPath
            IsValid      = $false
            ErrorCode    = 'ATTACHMENT_UNREADABLE'
            ErrorMessage = 'Attachment file could not be opened for reading.'
        }
    }

    return [pscustomobject]@{
        OriginalPath = $Path
        ResolvedPath = $resolvedPath
        IsValid      = $true
        ErrorCode    = ''
        ErrorMessage = ''
    }
}
