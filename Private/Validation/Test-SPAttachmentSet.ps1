function Test-SPAttachmentSet {
    <#
        .SYNOPSIS
        Validates a set of attachment files for SmailPost.

        .DESCRIPTION
        Test-SPAttachmentSet validates the supplied attachment paths before mail sending starts.
        It checks whether each path exists, confirms that each path points to a file, verifies
        that each file can be opened for reading, and calculates the combined attachment size.

        The function also enforces a configurable safe total-size limit so SmailPost can fail
        early with a clear message before attempting to send mail through Microsoft Graph.

        .PARAMETER AttachmentPath
        One or more file paths to validate. This parameter is optional. When no paths are
        supplied, the function returns a valid result with zero attachments.

        .PARAMETER MaxTotalBytes
        The maximum combined attachment size in bytes allowed for the validation run.

        .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param (
        [Parameter()]
        [string[]]$AttachmentPath,

        [Parameter()]
        [long]$MaxTotalBytes = 8MB
    )

    $notes = @()

    $result = [ordered]@{
        Valid                = $false
        AttachmentCount      = 0
        AttachmentTotalBytes = 0L
        MaxTotalBytes        = $MaxTotalBytes
        ValidPaths           = @()
        InvalidPaths         = @()
        Notes                = @()
    }

    #========================
    # No attachments supplied
    #========================
    if (-not $AttachmentPath -or $AttachmentPath.Count -eq 0) {
        $result.Valid = $true
        $notes += 'No attachments supplied.'
        $result.Notes = $notes
        return [pscustomobject]$result
    }

    foreach ($path in $AttachmentPath) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            $result.InvalidPaths += $path
            $notes += 'An attachment path is empty or whitespace.'
            continue
        }

        $resolvedPath = $null

        try {
            $resolvedPath = (Resolve-Path -Path $path -ErrorAction Stop).ProviderPath
        }
        catch {
            $result.InvalidPaths += $path
            $notes += ("Attachment path not found: {0}" -f $path)
            continue
        }

        try {
            $item = Get-Item -LiteralPath $resolvedPath -ErrorAction Stop

            if ($item.PSIsContainer) {
                $result.InvalidPaths += $resolvedPath
                $notes += ("Attachment path is a folder, not a file: {0}" -f $resolvedPath)
                continue
            }

            $stream = $null

            try {
                $stream = [System.IO.File]::Open(
                    $resolvedPath,
                    [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read,
                    [System.IO.FileShare]::Read
                )
                $null = $stream.Length
            }
            catch {
                $result.InvalidPaths += $resolvedPath
                $notes += ("Attachment file is not readable: {0}" -f $resolvedPath)
                continue
            }
            finally {
                if ($stream) {
                    $stream.Dispose()
                }
            }

            $result.ValidPaths += $resolvedPath
            $result.AttachmentCount += 1
            $result.AttachmentTotalBytes += [long]$item.Length
        }
        catch {
            $result.InvalidPaths += $resolvedPath
            $notes += ("Attachment validation failed for '{0}': {1}" -f $resolvedPath, $_.Exception.Message)
        }
    }

    #========================
    # Final validation result
    #========================
    if ($result.InvalidPaths.Count -gt 0) {
        $notes += 'One or more attachment files are invalid.'
        $result.Notes = $notes
        return [pscustomobject]$result
    }

    if ($result.AttachmentTotalBytes -gt $MaxTotalBytes) {
        $notes += (
            "Combined attachment size {0} bytes exceeds the configured limit of {1} bytes." -f
            $result.AttachmentTotalBytes,
            $MaxTotalBytes
        )

        $result.Notes = $notes
        return [pscustomobject]$result
    }

    $result.Valid = $true
    $notes += ("Validated {0} attachment file(s)." -f $result.AttachmentCount)
    $notes += ("Combined attachment size: {0} bytes." -f $result.AttachmentTotalBytes)
    $result.Notes = $notes

    return [pscustomobject]$result
}
