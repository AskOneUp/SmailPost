function Get-SPStringSha256 {
    <#
        .SYNOPSIS
        Returns a short fingerprint for a SecureString without printing the secret.

        .DESCRIPTION
        Computes a SHA-256 hash of the provided SecureString and returns a short fingerprint
        (first 4 and last 4 hex characters) without exposing the secret value.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # Accept a SecureString and validate it is not null.
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Security.SecureString]
        $Secure
    )

    # Marshal SecureString to plaintext briefly, hash it, then zero sensitive memory.
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try {
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($plain)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { $hash = $sha.ComputeHash($bytes) } finally { $sha.Dispose() }
        $hex = -join ($hash | ForEach-Object { $_.ToString('x2') })
        return "$($hex.Substring(0,4))....$($hex.Substring($hex.Length - 4,4))"
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        if ($bytes) { [array]::Clear($bytes, 0, $bytes.Length) | Out-Null }
        $plain = $null
    }
}
