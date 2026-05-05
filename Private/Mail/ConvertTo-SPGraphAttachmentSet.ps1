function ConvertTo-SPGraphAttachmentSet {
    <#
        .SYNOPSIS
        Builds a Microsoft Graph attachment collection for SmailPost.

        .DESCRIPTION
        ConvertTo-SPGraphAttachmentSet converts one or more validated file paths into Microsoft Graph
        fileAttachment payload objects by calling ConvertTo-SPGraphAttachment for each file.

        The function returns both the Graph attachment objects and summary information that can
        be reused in send results.

        .PARAMETER AttachmentPath
        One or more validated file paths.

        .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = 'Default')] # Voeg DefaultParameterSetName toe
    [OutputType([pscustomobject])]
    param (
        [Parameter(ParameterSetName = 'Default')] # Koppel de parameter aan de set
        [string[]]$AttachmentPath = @()
    )

    $attachments = @()
    $notes = @()

    $result = [ordered]@{
        Attachments          = @()
        AttachmentCount      = 0
        AttachmentTotalBytes = 0L
        Notes                = @()
    }

    if ($null -eq $AttachmentPath -or $AttachmentPath.Count -eq 0) {
        $notes += 'No attachments supplied.'
        $result.Notes = $notes
        return [pscustomobject]$result
    }

    foreach ($path in $AttachmentPath) {
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

    $result.Attachments = $attachments
    $notes += ("Built {0} Graph attachment object(s)." -f $result.AttachmentCount)
    $notes += ("Combined attachment size: {0} bytes." -f $result.AttachmentTotalBytes)
    $result.Notes = $notes

    return [pscustomobject]$result
}
