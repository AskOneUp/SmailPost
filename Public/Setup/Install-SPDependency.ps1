function Install-SPDependency {
    <#
        .SYNOPSIS
        Install and import SmailPost dependency modules for the current user. Defaults to the latest stable from PSGallery; falls back to minimum tested versions if needed.
        .DESCRIPTION
        Installs required modules into the current user scope, prefers the latest stable from PSGallery, and falls back to pinned minimums if the gallery is unavailable. Idempotent and supports -WhatIf and -Confirm.
        .PARAMETER PreferLatest
        Prefer the latest stable from PSGallery. Defaults to true. Use -PreferLatest:$false to pin minimum versions.
        .PARAMETER CleanOld
        Remove older installed versions after installing the target version.
        .PARAMETER Force
        Reinstall even if the target version is already present.
        .PARAMETER Unattended
        Suppress prompts. Accept licenses automatically where supported; otherwise fail or fall back.
        .EXAMPLE
        Install-SPDependency -Verbose
        .EXAMPLE
        Install-SPDependency -PreferLatest:$false -Verbose
        .EXAMPLE
        Install-SPDependency -CleanOld -Force -Verbose
        .EXAMPLE
        Install-SPDependency -Unattended -PreferLatest:$false -Verbose
        .EXAMPLE
        Install-SPDependency -WhatIf
        .OUTPUTS
        System.Void
    #>
    # Enable -WhatIf and -Confirm semantics.
    [CmdletBinding(SupportsShouldProcess = $true)]
    # Declare that this function emits no pipeline output (System.Void).
    [OutputType([void])]
    param(
        # Prefer the latest stable from PSGallery unless caller explicitly opts out later in code.
        [switch]$PreferLatest,
        # Remove older installed versions after a successful install/import.
        [switch]$CleanOld,
        # Reinstall/repair even if the desired version is already present.
        [switch]$Force,
        # Suppress prompts; auto-accept licenses where supported.
        [switch]$Unattended
    )

    # Establish default for PreferLatest without violating the switch-default rule. If the caller
    # did not explicitly pass -PreferLatest (true/false), default it to $true.
    if (-not $PSBoundParameters.ContainsKey('PreferLatest')) {
        $PreferLatest = $true
    }

    # Cache PSGallery repository details; returns $null if the repository is not registered.
    $repo = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue

    # Ensure PSGallery is available and trusted (idempotent).
    if (-not $repo) {
        if ($PSCmdlet.ShouldProcess('PSGallery', 'Register-PSRepository')) {
            try {
                Register-PSRepository -Name 'PSGallery' -SourceLocation 'https://www.powershellgallery.com/api/v2' `
                    -InstallationPolicy Trusted -ErrorAction Stop
                Write-Verbose "PSGallery registered and trusted."
            }
            catch {
                throw "Failed to register PSGallery repository. $($_.Exception.Message)."
            }
        }
        else {
            Write-Verbose "WhatIf: would register PSGallery (trusted)."
        }
    }
    elseif ($repo.InstallationPolicy -ne 'Trusted') {
        if ($PSCmdlet.ShouldProcess('PSGallery', 'Set-PSRepository InstallationPolicy=Trusted')) {
            try {
                Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction Stop
                Write-Verbose "Set PSGallery InstallationPolicy to Trusted."
            }
            catch {
                throw "Failed to set PSGallery InstallationPolicy to Trusted. $($_.Exception.Message)."
            }
        }
        else {
            Write-Verbose "WhatIf: would set PSGallery InstallationPolicy to Trusted."
        }
    }
    else {
        Write-Verbose "PSGallery already trusted."
    }

    # Define minimum tested versions used as a floor when PSGallery is unavailable or when -PreferLatest:$false.
    $minVersions = [ordered]@{
        'Microsoft.Graph.Authentication'        = '2.11.0'
        'Microsoft.Graph.Users.Actions'         = '2.11.0'
        'Microsoft.PowerShell.SecretManagement' = '1.1.2'
        'Microsoft.PowerShell.SecretStore'      = '1.0.6' # Works on Server 2019/2022; newer also OK.
    }

    # Iterate over each required module and ensure the desired version is installed and imported.
    foreach ($m in $minVersions.Keys) {
        # Discover the highest installed version (if any) to decide install/upgrade/skip.
        $installed = Get-Module -ListAvailable -Name $m | Sort-Object Version -Descending | Select-Object -First 1

        # Pick the desired target version, starting from our minimum and optionally preferring latest stable from PSGallery.
        $targetVersion = [version]$minVersions[$m]
        if ($PreferLatest) {
            try {
                $fm = Find-Module -Name $m -Repository 'PSGallery' -AllowPrerelease:$false -ErrorAction Stop
                $targetVersion = [version]$fm.Version
                Write-Verbose "Latest stable on PSGallery for $m is $targetVersion."
            }
            catch {
                Write-Warning "Find-Module failed for $m ($($_.Exception.Message)). Falling back to minimum $($minVersions[$m])."
                if ($Unattended) { Write-Warning "Falling back due to unattended mode." }
                Write-Warning "If you're behind a proxy, configure your proxy and retry."
            }
        }

        # Enforce the floor: never pick below our tested minimum.
        if ($targetVersion -lt [version]$minVersions[$m]) {
            Write-Verbose "Target for $m ($targetVersion) is below minimum $($minVersions[$m]); pinning to minimum."
            $targetVersion = [version]$minVersions[$m]
        }

        # Decide whether we need to install or upgrade, and track which version to import.
        $needInstall = (-not $installed) -or ($installed.Version -lt $targetVersion) -or $Force
        $useVersion = $null

        # Ensure the target version is installed (CurrentUser scope).
        if ($needInstall) {
            try {
                if ($PSCmdlet.ShouldProcess("$m $targetVersion", 'Install-Module')) {
                    Install-Module -Name $m -RequiredVersion $targetVersion -Scope CurrentUser `
                        -Force -AllowClobber -Repository 'PSGallery' -AllowPrerelease:$false -ErrorAction Stop -AcceptLicense:$Unattended
                    Write-Verbose "Installed $m $targetVersion."
                }
                $useVersion = $targetVersion
            }
            catch {
                if ($installed) {
                    Write-Warning "Could not install $m $targetVersion ($($_.Exception.Message)). Keeping $($installed.Version)."
                    $useVersion = $installed.Version
                }
                else {
                    Write-Warning "Failed to install required module $m; no fallback available."
                    throw
                }
            }
        }
        else {
            # Already at desired (or newer) version; reuse the installed version.
            $useVersion = $installed.Version
            Write-Verbose "$m already at desired version ($useVersion)."
        }

        # Import the exact version chosen for this session using ShouldProcess (respects -WhatIf/-Confirm).
        if ($PSCmdlet.ShouldProcess('Session', "Import $m $useVersion")) {
            try {
                Import-Module $m -RequiredVersion $useVersion.ToString() -Force -ErrorAction Stop
                Write-Verbose "Imported module $m (version $useVersion)."
            }
            catch {
                # Rare: RequiredVersion import can fail if multiple side-by-side copies conflict.
                Write-Warning ("Import-Module failed for {0} {1}: {2}. Retrying without -RequiredVersion." -f $m, $useVersion, $_.Exception.Message)
                Import-Module $m -Force -ErrorAction Stop
                $loaded = (Get-Module -Name $m | Select-Object -First 1).Version
                Write-Verbose "Imported module $m (fallback version $loaded)."
            }
        }
        else {
            # -WhatIf path: show intent and the latest available version on disk.
            Write-Verbose "WhatIf: would import $m $useVersion."
            $avail = Get-Module -ListAvailable -Name $m | Sort-Object Version -Descending | Select-Object -First 1
            if ($avail) { Write-Verbose "WhatIf: latest available on disk is $($avail.Version)." }
        }

        # Optional cleanup: remove older versions in CurrentUser paths only, using ShouldProcess.
        if ($CleanOld) {
            $currentRoots = @(
                (Join-Path $HOME 'Documents\PowerShell\Modules'),
                (Join-Path $HOME 'Documents\WindowsPowerShell\Modules')
            )
            Get-Module -ListAvailable -Name $m |
            Where-Object { $_.Version -ne $useVersion } |
            ForEach-Object {
                $path = Split-Path $_.Path
                $isUserPath = $false
                foreach ($root in $currentRoots) {
                    if ($path.StartsWith($root, [System.StringComparison]::InvariantCultureIgnoreCase)) { $isUserPath = $true; break }
                }
                if ($isUserPath) {
                    if ($PSCmdlet.ShouldProcess($path, "Remove $m $($_.Version)")) {
                        try {
                            Remove-Item -Recurse -Force -Path $path -ErrorAction Stop
                            Write-Verbose "Removed old $m $($_.Version) at $path."
                        }
                        catch {
                            Write-Warning ("Could not remove {0} {1} at {2}: {3}" -f $m, $_.Version, $path, $_.Exception.Message)
                        }
                    }
                }
                else {
                    Write-Verbose "Skipping removal outside CurrentUser scope: $path."
                }
            }
        }
    }

    # 6) Sanity check: ensure key commands are available (gives clear error early).
    $requiredCommands = @('Connect-MgGraph', 'Send-MgUserMail', 'Get-SecretVault', 'Set-Secret', 'Get-Secret')
    foreach ($cmd in $requiredCommands) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            if ($WhatIfPreference) {
                Write-Verbose "WhatIf: would expect '$cmd' after install/import."
            }
            else {
                throw "Missing required command: $cmd. Re-run with -Verbose for details."
            }
        }
    }

    # 7) Done.
    Write-Verbose "Dependencies installed and imported successfully."
}
