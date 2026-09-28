function ConvertTo-SPGraphAttachmentSet {
    <#
        .SYNOPSIS
        Builds a Microsoft Graph attachment collection for SmailPost.

        .DESCRIPTION
        ConvertTo-SPGraphAttachmentSet converts ordinary attachment paths and optional
        inline image definitions into Microsoft Graph fileAttachment payload objects.

        Ordinary attachments are supplied through AttachmentPath.

        Inline images are supplied through InlineImage and must contain a Path and
        ContentId property. The ContentId can be referenced from the HTML message body
        by using cid:<ContentId>.

        The function returns the combined Graph attachment collection and summary
        information that can be reused in send results.

        .PARAMETER AttachmentPath
        One or more validated file paths that should be included as ordinary attachments.

        .PARAMETER InlineImage
        One or more inline image definitions.

        Each object must contain:
        - Path
        - ContentId

        .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param (
        [Parameter()]
        [string[]]$AttachmentPath = @(),

        [Parameter()]
        [object[]]$InlineImage = @()
    )

    $attachments = @()
    $notes = @()

    $result = [ordered]@{
        Attachments          = @()
        AttachmentCount      = 0
        AttachmentTotalBytes = 0L
        InlineImageCount     = 0
        Notes                = @()
    }

    # Process ordinary attachments.
    foreach ($path in @($AttachmentPath)) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            throw 'Attachment path cannot be null, empty, or whitespace.'
        }

        $resolvedPath = (Resolve-Path -Path $path -ErrorAction Stop).ProviderPath
        $fileInfo = Get-Item -LiteralPath $resolvedPath -ErrorAction Stop

        if ($fileInfo.PSIsContainer) {
            throw ("Attachment path '{0}' points to a folder, not a file." -f $resolvedPath)
        }

        $attachments += ConvertTo-SPGraphAttachment -Path $resolvedPath

        $result.AttachmentCount += 1
        $result.AttachmentTotalBytes += [long]$fileInfo.Length
    }

    # Process inline images.
    foreach ($inlineItem in @($InlineImage)) {
        if ($null -eq $inlineItem) {
            throw 'Inline image definition cannot be null.'
        }

        $path = [string]$inlineItem.Path
        $contentId = [string]$inlineItem.ContentId

        if ([string]::IsNullOrWhiteSpace($path)) {
            throw 'Inline image path cannot be null, empty, or whitespace.'
        }

        if ([string]::IsNullOrWhiteSpace($contentId)) {
            throw 'Inline image ContentId cannot be null, empty, or whitespace.'
        }

        $resolvedPath = (Resolve-Path -Path $path -ErrorAction Stop).ProviderPath
        $fileInfo = Get-Item -LiteralPath $resolvedPath -ErrorAction Stop

        if ($fileInfo.PSIsContainer) {
            throw ("Inline image path '{0}' points to a folder, not a file." -f $resolvedPath)
        }

        $attachments += ConvertTo-SPGraphAttachment `
            -Path $resolvedPath `
            -ContentId $contentId

        $result.AttachmentCount += 1
        $result.InlineImageCount += 1
        $result.AttachmentTotalBytes += [long]$fileInfo.Length
    }

    # Build summary information.
    $result.Attachments = $attachments

    if ($result.AttachmentCount -eq 0) {
        $notes += 'No attachments supplied.'
    }
    else {
        $notes += ("Built {0} Graph attachment object(s)." -f $result.AttachmentCount)
        $notes += ("Inline images: {0}." -f $result.InlineImageCount)
        $notes += ("Combined attachment size: {0} bytes." -f $result.AttachmentTotalBytes)
    }

    $result.Notes = $notes

    return [pscustomobject]$result
}
