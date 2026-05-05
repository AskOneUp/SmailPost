function Get-SPStoredSecretState {
    <#
        .SYNOPSIS
        Checks whether the stored SmailPost Graph secret exists and contains required metadata.

        .DESCRIPTION
        Looks for the Graph client secret record in the specified SecretManagement vault and
        validates that the required metadata fields are present. This helper does not prompt,
        unlock, or modify anything. It only reports state.

        .PARAMETER VaultName
        The SecretManagement vault name. Defaults to 'SmailPost'.

        .PARAMETER SecretName
        The name of the stored Graph client secret. Defaults to 'SmailPost-GraphClientSecret'.

        .OUTPUTS
        PSCustomObject with presence and completeness details.
    #>

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$VaultName = 'SmailPost',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SecretName = 'SmailPost-GraphClientSecret'
    )

    $requiredMetadata = @(
        'TenantID',
        'AppID'
    )

    $notes = @()
    $missingMetadata = @()
    $secretPresent = $false
    $metadataPresent = $false

    # Check whether the vault exists first.
    $vault = Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue
    if (-not $vault) {
        return [pscustomobject]@{
            SecretPresent   = $false
            MetadataPresent = $false
            SecretComplete  = $false
            MissingMetadata = $requiredMetadata
            Notes           = @("Vault '$VaultName' not found.")
        }
    }

    # Check whether the secret record exists.
    try {
        $secretInfo = Get-SecretInfo -Vault $VaultName -Name $SecretName -ErrorAction Stop
        $secretPresent = $true
    }
    catch {
        return [pscustomobject]@{
            SecretPresent   = $false
            MetadataPresent = $false
            SecretComplete  = $false
            MissingMetadata = $requiredMetadata
            Notes           = @("Secret '$SecretName' not found in vault '$VaultName'.")
        }
    }

    # Read metadata from the secret record.
    $metadata = $secretInfo.Metadata
    if (-not $metadata) {
        $notes += "Secret '$SecretName' exists but has no metadata."
        $missingMetadata = $requiredMetadata
    }
    else {
        foreach ($key in $requiredMetadata) {
            if (-not $metadata.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$metadata[$key])) {
                $missingMetadata += $key
                $notes += "Metadata field '$key' is missing or empty on secret '$SecretName'."
            }
        }
    }

    if ($missingMetadata.Count -eq 0) {
        $metadataPresent = $true
        $notes += "Secret '$SecretName' exists and required metadata is present."
    }

    return [pscustomobject]@{
        SecretPresent   = $secretPresent
        MetadataPresent = $metadataPresent
        SecretComplete  = ($secretPresent -and $metadataPresent)
        MissingMetadata = $missingMetadata
        Notes           = $notes
    }
}
