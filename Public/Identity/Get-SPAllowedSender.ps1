function Get-SPAllowedSender {
    <#
        .SYNOPSIS
        Retrieves the allowed sender mailboxes from the C-S-mailPost-Senders Entra group.

        .DESCRIPTION
        Uses app-only Microsoft Graph authentication to locate the C-S-mailPost-Senders group,
        retrieves its members, filters to mail-enabled user objects, and returns a clean,
        UI-friendly sender list.

        .OUTPUTS
        System.Object[]

        .NOTES
        Returns an empty array when the group exists but contains no valid mail-enabled users.
        Throws terminating errors for token, group lookup, or Graph retrieval failures.
    #>

    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param()

    # ========================
    # Define fixed values for sender group discovery.
    # ========================
    $groupDisplayName = 'C-S-mailPost-Senders'

    Write-Verbose "Acquiring Microsoft Graph access token."
    $tokenResult = Get-SPGraphAccessToken

    if ($null -eq $tokenResult) {
        throw "Unable to acquire Microsoft Graph access token."
    }

    if (-not $tokenResult.Success) {
        throw "Unable to acquire Microsoft Graph access token."
    }

    if ([string]::IsNullOrWhiteSpace($tokenResult.AccessToken)) {
        throw "Unable to acquire Microsoft Graph access token."
    }

    $headers = @{
        Authorization = "$($tokenResult.TokenType) $($tokenResult.AccessToken)"
    }

    # ========================
    # Find the sender group by display name.
    # ========================
    $groupFilter = "displayName eq '$groupDisplayName'"
    $groupUri = "https://graph.microsoft.com/v1.0/groups?`$filter=$([System.Uri]::EscapeDataString($groupFilter))&`$select=id,displayName"

    Write-Verbose "Looking up sender group '$groupDisplayName'."

    try {
        $groupResponse = Invoke-RestMethod -Method Get -Uri $groupUri -Headers $headers -ErrorAction Stop
    }
    catch {
        throw "Failed to retrieve sender group '$groupDisplayName'. $($_.Exception.Message)"
    }

    if ($null -eq $groupResponse) {
        throw "Failed to retrieve sender group '$groupDisplayName'."
    }

    $groups = @($groupResponse.value)

    if ($groups.Count -eq 0) {
        throw "Sender group '$groupDisplayName' was not found."
    }

    if ($groups.Count -gt 1) {
        throw "Multiple groups named '$groupDisplayName' were found. Use a unique group name or switch to GroupId-based lookup."
    }

    $groupId = [string]$groups[0].id

    if ([string]::IsNullOrWhiteSpace($groupId)) {
        throw "Sender group '$groupDisplayName' was found, but its Id is missing."
    }

    # ========================
    # Retrieve all group members with simple paging support.
    # ========================
    $memberUri = "https://graph.microsoft.com/v1.0/groups/$groupId/members?`$select=id,displayName,mail,userPrincipalName"
    $members = [System.Collections.Generic.List[object]]::new()

    Write-Verbose "Retrieving members for sender group '$groupDisplayName'."

    while (-not [string]::IsNullOrWhiteSpace($memberUri)) {
        try {
            $memberResponse = Invoke-RestMethod -Method Get -Uri $memberUri -Headers $headers -ErrorAction Stop
        }
        catch {
            throw "Failed to retrieve members for sender group '$groupDisplayName'. $($_.Exception.Message)"
        }

        if ($null -eq $memberResponse) {
            throw "Failed to retrieve members for sender group '$groupDisplayName'."
        }

        foreach ($member in @($memberResponse.value)) {
            $members.Add($member)
        }

        $memberUri = [string]$memberResponse.'@odata.nextLink'
    }

    # ========================
    # Filter to mail-enabled user objects only.
    # ========================
    $validSenders = foreach ($member in $members) {
        $odataType = [string]$member.'@odata.type'
        $mail = [string]$member.mail
        $id = [string]$member.id

        if ($odataType -ne '#microsoft.graph.user') {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($mail)) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($id)) {
            continue
        }

        [PSCustomObject]@{
            DisplayName       = [string]$member.displayName
            Mail              = $mail
            UserPrincipalName = [string]$member.userPrincipalName
            Id                = $id
        }
    }

    $sortedSenders = @(
        $validSenders |
            Sort-Object -Property DisplayName, Mail
    )

    Write-Verbose "Retrieved $($sortedSenders.Count) valid sender entries."
    return $sortedSenders
}
