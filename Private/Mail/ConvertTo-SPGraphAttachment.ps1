function ConvertTo-SPGraphAttachment {
    <#
        .SYNOPSIS
        Converts a file into a Microsoft Graph fileAttachment payload object.

        .DESCRIPTION
        ConvertTo-SPGraphAttachment reads a single file from disk, detects its MIME type,
        converts the file content to Base64, and returns a hashtable shaped for the
        Microsoft Graph fileAttachment model.

        When ContentId is supplied, the attachment is configured as an inline attachment
        that can be referenced from an HTML message body by using cid:<ContentId>.

        This helper is intended for internal SmailPost usage when building the sendMail
        request payload.

        .PARAMETER Path
        The full path to the file that should be converted into a Graph attachment object.

        .PARAMETER ContentId
        Optional content ID used to expose the attachment as an inline resource.

        The HTML message body can reference the inline attachment by using
        cid:<ContentId>.

        .OUTPUTS
        Hashtable
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [string]$ContentId
    )

    begin {
        function Get-SPMimeType {
            param (
                [Parameter(Mandatory = $true)]
                [string]$FilePath
            )

            $extension = [System.IO.Path]::GetExtension($FilePath)

            if ([string]::IsNullOrWhiteSpace($extension)) {
                return 'application/octet-stream'
            }

            switch ($extension.ToLowerInvariant()) {
                '.pdf' { return 'application/pdf' }
                '.txt' { return 'text/plain' }
                '.csv' { return 'text/csv' }
                '.htm' { return 'text/html' }
                '.html' { return 'text/html' }
                '.json' { return 'application/json' }
                '.xml' { return 'application/xml' }
                '.zip' { return 'application/zip' }
                '.doc' { return 'application/msword' }
                '.docx' { return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' }
                '.xls' { return 'application/vnd.ms-excel' }
                '.xlsx' { return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }
                '.ppt' { return 'application/vnd.ms-powerpoint' }
                '.pptx' { return 'application/vnd.openxmlformats-officedocument.presentationml.presentation' }
                '.png' { return 'image/png' }
                '.jpg' { return 'image/jpeg' }
                '.jpeg' { return 'image/jpeg' }
                '.gif' { return 'image/gif' }
                '.bmp' { return 'image/bmp' }
                '.svg' { return 'image/svg+xml' }
                default { return 'application/octet-stream' }
            }
        }
    }

    process {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw 'Attachment path cannot be null, empty, or whitespace.'
        }

        $resolvedPath = (Resolve-Path -Path $Path -ErrorAction Stop).ProviderPath
        $fileInfo = Get-Item -LiteralPath $resolvedPath -ErrorAction Stop

        if ($fileInfo.PSIsContainer) {
            throw ("Attachment path '{0}' points to a folder, not a file." -f $resolvedPath)
        }

        $fileBytes = [System.IO.File]::ReadAllBytes($resolvedPath)
        $base64Content = [System.Convert]::ToBase64String($fileBytes)
        $mimeType = Get-SPMimeType -FilePath $resolvedPath

        $attachment = @{
            '@odata.type' = '#microsoft.graph.fileAttachment'
            name          = $fileInfo.Name
            contentType   = $mimeType
            contentBytes  = $base64Content
        }

        # Configure the attachment as an inline resource when a content ID is supplied.
        if (-not [string]::IsNullOrWhiteSpace($ContentId)) {
            $attachment.isInline = $true
            $attachment.contentId = $ContentId.Trim()
        }

        return $attachment
    }
}
