function Invoke-SPSetup {
    <#
        .SYNOPSIS
        Runs the automated installer setup/doctor for SmailPost: checks environment, installs dependencies,
        validates Microsoft Graph reachability, configures SecretStore, and prints a clear summary.

        .DESCRIPTION
        Invoke-SPSetup is designed to check and prepare the environment for SmailPost.
        By default, it runs in an interactive, guided mode with clear prompts and feedback.
        When the -Unattended switch is used, it runs silently without prompts, suitable for CI/CD
        or automated scripts. In unattended mode, if a blocking condition is encountered
        (such as a locked password-protected SecretStore), the command stops and provides
        one clear instruction to resolve the issue before rerunning.

        .PARAMETER Unattended
        When present, skips prompts and runs in unattended mode. This is intended for automation
        scenarios such as CI/CD. If a blocking condition is detected (like a locked password store),
        the command stops and prints one explicit instruction to resolve it.

        .PARAMETER Force
        Reinstalls or repairs modules and reconfigures items where it is safe to do so.

        .PARAMETER SkipDependencies
        Skips the dependency installation and verification step.

        .PARAMETER SkipGraphCheck
        Skips the Microsoft Graph reachability check.

        .PARAMETER SkipSecretStore
        Skips SecretStore detection and verification.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param (
        # Default to automated behavior so new users get a smooth experience.
        [switch]$Unattended,
        # Allow repairs/reinstalls of modules or reconfiguration where it's safe.
        [switch]$Force,
        # Let advanced users skip pieces if they know what they're doing.
        [switch]$SkipDependencies,
        [switch]$SkipGraphCheck,
        [switch]$SkipSecretStore
    )
    begin {
        # Build an ordered hashtable to collect status/notes per section for a clean summary object.
        $summary = [ordered]@{
            Environment     = [ordered]@{ Status = ''; Notes = @() }      # Environment check result.
            Dependencies    = [ordered]@{ Status = ''; Notes = @() }      # Module install/verify results.
            Graph           = [ordered]@{ Status = ''; Notes = @() }      # Graph reachability.
            SecretStore     = [ordered]@{ Status = ''; Notes = @() }      # Secret vault status.
            GraphConnection = [ordered]@{ Status = ''; Notes = @() }      # Test connection with Get-MgUser (requires auth).
            AllowedSenders  = [ordered]@{ Status = ''; Notes = @() }      # Placeholder for future sender allowlist checks.
            Notes           = @()                                         # Any general notes across steps.
            OverallStatus   = ''                                          # Final traffic-light result.
            NextStep        = ''                                          # Optional field to suggest next step if setup is incomplete.
        }
        # Decide where to store the transcript/log file (ProgramData avoids user profile variance).
        $logRoot = Join-Path -Path $env:ProgramData -ChildPath 'SmailPost\logs'   # e.g. C:\ProgramData\SmailPost\logs.
        # Compose a timestamped log filename so multiple runs don't collide.
        $logFile = Join-Path $logRoot ("setup-{0:ddMMyyyy_HHmm}.txt" -f (Get-Date))  # setup-01012025_2359.txt.
        # Keep track of transcript is needed
        $transcriptStarted = $false
        # Only create folder & start transcript when ShouldProcess approves (honors -WhatIf)
        if ($PSCmdlet.ShouldProcess($logRoot, 'Create log folder & start transcript')) {
            try {
                if (-not (Test-Path $logRoot)) {
                    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
                }
            }
            catch {
                $summary.Notes += ("Failed to create log folder {0}: {1}. Running without transcript." -f $logRoot, $_.Exception.Message)
            }
            try {
                Start-Transcript -Path $logFile -ErrorAction Stop | Out-Null
                $transcriptStarted = $true
                Write-Information -MessageData "Logging to: $logFile." -InformationAction Continue
            }
            catch {
                $summary.Notes += "Transcript not started: $($_.Exception.Message)."
            }
        }
        else {
            # -WhatIf path: tell the user where we WOULD log, but touch nothing
            Write-Information -MessageData "WhatIf: would log to: $logFile. Dry run: no transcript started." -InformationAction Continue
        }
        function Set-SectionStatus {
            # Suppress PSScriptAnalyzer warning: this helper only updates memory,
            # the top-level cmdlet already uses ShouldProcess for state changes.
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '',
                Justification = 'Local helper only mutates in-memory summary; top-level cmdlet uses ShouldProcess.'
            )]
            param(
                [string]$Name,      # Section key in $summary (e.g., 'Environment').
                [string]$Status,    # Emoji or text status (✅/⚠️/❌/⏭️).
                [string[]]$Notes    # Additional notes to append to the section
            )
            # Guard: if the section key doesn’t exist in $summary, exit safely.
            if (-not $summary.Contains($Name)) { return }
            # Update the section’s Status field with the provided marker.
            $summary[$Name]['Status'] = $Status        # Set the status in the summary
            # If Notes were passed, append them to the section’s Notes array.
            if ($Notes) {
                $summary[$Name]['Notes'] += $Notes
            }
        }
        # Helper for Verbose trace (toggle with -Verbose at call site).
        function Note {
            param($msg)             # Message to print.
            Write-Verbose $msg      # Standard Verbose pipeline.
        }
    }
    process {
        #----------------------------
        #   ENVIRONMENT CHECK
        #----------------------------
        try {
            Note "Running Test-SPEnvironment..."            # Trace: what we are about to do.
            $null = Test-SPEnvironment                              # Ensure PS 7+ or throw.
            Set-SectionStatus -Name 'Environment' -Status '✅' -Notes @("PowerShell version OK: $($PSVersionTable.PSVersion).")    # Mark success
        }
        catch {
            # If PowerShell < 7 (or other environment issues), fail fast; continuing would cause noisy errors downstream.
            Set-SectionStatus -Name 'Environment' -Status '❌' -Notes @("PowerShell 7+ required: $($_.Exception.Message). Setup aborted.")
            throw       # Stop pipeline execution.
        }
        #----------------------------
        #   DEPENDENCIES MODULES
        #----------------------------
        if (-not $SkipDependencies) {
            try {
                Note "Installing/upgrading dependencies (latest stable)…"
                if ($PSCmdlet.ShouldProcess("Dependencies", "Install/Verify")) {
                    # Pull latest stable; honor -Force for repair. Verbose flows through.
                    Install-SPDependency -PreferLatest:$true -Force:$Force
                }
                Set-SectionStatus -Name 'Dependencies' -Status '✅' -Notes @("Modules verified (latest stable enforced).")
            }
            catch {
                Set-SectionStatus -Name 'Dependencies' -Status '⚠️' -Notes @("Dependency install issue: $($_.Exception.Message). This may impact later steps.")
            }
        }
        else {
            Set-SectionStatus -Name 'Dependencies' -Status '⏭️' -Notes @("Skipped by user.")
        }
        #----------------------------
        #   Graph reachability
        #----------------------------
        if (-not $SkipGraphCheck) {
            try {
                Note "Checking Microsoft Graph reachability…"
                $r = Test-SPPrerequisite
                if (-not $r) {
                    Set-SectionStatus -Name 'Graph' -Status '⚠️' -Notes @("Prerequisite check returned no result.")
                }
                else {
                    # keep only Graph-related notes
                    $graphNotes = @($r.Notes) | Where-Object {
                        $_ -match '(?i)microsoft graph endpoint' -or
                        $_ -match 'proxy requires authentication' -or
                        $_ -match 'throttling' -or
                        $_ -match 'cannot reach Microsoft Graph endpoint'
                    }

                    if ($r.GraphReachable) {
                        Set-SectionStatus -Name 'Graph' -Status '✅' -Notes $graphNotes
                    }
                    else {
                        Set-SectionStatus -Name 'Graph' -Status '❌' -Notes ($graphNotes + @(
                                "Graph not reachable. Check proxy/allowlist for graph.microsoft.com:443.",
                                "Rerun with -SkipGraphCheck to proceed."
                            ))
                    }
                }
            }
            catch {
                Set-SectionStatus -Name 'Graph' -Status '⚠️' -Notes @("Graph check error: $($_.Exception.Message).")
            }
        }
        else {
            Set-SectionStatus -Name 'Graph' -Status '⏭️' -Notes @("Skipped by user.")
        }
        #----------------------------
        #  SECRETSTORE (Vault)
        #----------------------------
        if (-not $SkipSecretStore) {
            try {
                Note "Configuring SecretStore vault 'SmailPost'..."

                # Guard: SecretManagement not available (e.g., WhatIf dry-run or missing modules)
                if (-not (Get-Command Get-SecretVault -ErrorAction SilentlyContinue)) {
                    Set-SectionStatus -Name 'SecretStore' -Status '⏭️' -Notes @(
                        "Skipped SecretStore check: SecretManagement/SecretStore modules not loaded (WhatIf or missing)."
                    )
                }
                else {
                    # Read config/status (safe even if locked)
                    $cfg = Get-SecretStoreConfiguration -ErrorAction SilentlyContinue
                    $vault = Get-SecretVault -Name 'SmailPost' -ErrorAction SilentlyContinue

                    # Determine lock state without a status cmdlet (SecretStore 1.0.6 compatible)
                    $locked = $false
                    if ($cfg -and $cfg.Authentication -eq 'Password') {
                        if ($vault) {
                            try {
                                # If this succeeds, store is unlocked; errors that mention “locked” imply locked state.
                                Get-SecretInfo -Vault 'SmailPost' -Name '*' -ErrorAction Stop | Out-Null
                            }
                            catch {
                                if ($_.Exception.Message -match 'locked|Unlock-SecretStore|password') {
                                    $locked = $true
                                }
                            }
                        }
                        else {
                            # No vault yet and password mode → assume locked in unattended runs.
                            $locked = $Unattended
                        }
                    }

                    if ($locked) {
                        if ($Unattended) {
                            Set-SectionStatus -Name 'SecretStore' -Status '❌' -Notes @(
                                "SecretStore is password-protected and locked.",
                                "Run: Unlock-SecretStore (interactive) and rerun."
                            )
                            throw "Locked SecretStore in unattended mode."
                        }
                        else {
                            Note "SecretStore locked — prompting for unlock…"
                            try {
                                _UnlockSecretStore
                                Set-SectionStatus -Name 'SecretStore' -Status '✅' -Notes @(
                                    "SecretStore unlocked."
                                )
                            }
                            catch {
                                Set-SectionStatus -Name 'SecretStore' -Status '⚠️' -Notes @(
                                    "Unlock failed: $($_.Exception.Message)",
                                    "Run Unlock-SecretStore and rerun Invoke-SPSetup."
                                )
                                throw "Unlock-SecretStore failed."
                            }
                        }
                    }

                    # If here: either Authentication=None OR password mode but already unlocked → proceed.
                    $vault = Get-SecretVault -Name 'SmailPost' -ErrorAction SilentlyContinue

                    if (-not $vault) {
                        Note "Creating vault..."
                        if ($PSCmdlet.ShouldProcess("SecretStore", "Create SmailPost vault")) {
                            # If no global store config yet, prefer non-password (hands-off) in unattended runs.
                            if (-not $cfg -and $Unattended) {
                                Initialize-SecretStore -Authentication None -Interaction None -ErrorAction Stop
                            }

                            if ($Unattended) {
                                Register-SecretVault -Name 'SmailPost' -ModuleName Microsoft.PowerShell.SecretStore -ErrorAction Stop -Confirm:$false
                            }
                            else {
                                Register-SecretVault -Name 'SmailPost' -ModuleName Microsoft.PowerShell.SecretStore -ErrorAction Stop
                            }

                            Set-SectionStatus -Name 'SecretStore' -Status '✅' -Notes @(
                                "Vault 'SmailPost' created.",
                                "Next step: Invoke-SPStoreSecret to add credentials."
                            )
                        }
                    }
                    else {
                        # Vault already present and usable. Check whether SmailPost credentials are already stored.
                        $secretState = Get-SPStoredSecretState

                        $notes = @(
                            "Vault present and usable."
                        )

                        if ($secretState.SecretComplete) {
                            $notes += "Stored Graph credentials found."
                        }
                        else {
                            $notes += "Next step: Invoke-SPStoreSecret to add credentials."
                        }

                        $notes += $secretState.Notes

                        Set-SectionStatus -Name 'SecretStore' -Status '✅' -Notes $notes
                    }
                }
            }
            catch {
                if ($summary -and $summary.SecretStore.Status -eq '') {
                    Set-SectionStatus -Name 'SecretStore' -Status '⚠️' -Notes @(
                        "SecretStore setup error: $($_.Exception.Message)"
                    )
                }
            }
        }
        else {
            Set-SectionStatus -Name 'SecretStore' -Status '⏭️' -Notes @(
                "Skipped by user."
            )
        }
        #----------------------------
        #  GraphConnection
        #----------------------------
        try {
            Note "Checking stored secrets for Microsoft Graph connection test..."

            $secretState = Get-SPStoredSecretState

            if (-not $secretState.SecretComplete) {
                Set-SectionStatus -Name 'GraphConnection' -Status '⏭️' -Notes (
                    @("Credentials not yet stored. Run Invoke-SPStoreSecret first.") + $secretState.Notes
                )
            }
            else {
                Note "Running Test-SPGraphConnection..."
                $graphConnectionResult = Test-SPGraphConnection

                if ($graphConnectionResult.Success) {
                    $notes = @(
                        "Microsoft Graph app-only connection validated successfully."
                    )

                    if ($graphConnectionResult.TokenExpiresOn) {
                        $notes += "Token expires on: $($graphConnectionResult.TokenExpiresOn)."
                    }

                    $notes += $graphConnectionResult.Notes

                    Set-SectionStatus -Name 'GraphConnection' -Status '✅' -Notes $notes
                }
                else {
                    Set-SectionStatus -Name 'GraphConnection' -Status '❌' -Notes (
                        @("Microsoft Graph app-only connection test failed.") + $graphConnectionResult.Notes
                    )
                }
            }
        }
        catch {
            Set-SectionStatus -Name 'GraphConnection' -Status '⚠️' -Notes @(
                "Graph connection check error: $($_.Exception.Message)."
            )
        }
        #========================
        #  AllowedSenders
        #========================
        try {
            Note "Checking allowed senders..."

            if ($summary.GraphConnection.Status -ne '✅') {
                Set-SectionStatus -Name 'AllowedSenders' -Status '⏭️' -Notes @(
                    "Sender validation skipped until Microsoft Graph connection is working."
                )
            }
            else {
                $allowedSenders = @(Get-SPAllowedSender)

                if ($allowedSenders.Count -gt 0) {
                    $senderPreview = @(
                        $allowedSenders |
                        Select-Object -First 3 -ExpandProperty Mail
                    ) -join ', '

                    $notes = @(
                        "Allowed sender validation succeeded.",
                        "Found $($allowedSenders.Count) valid sender(s) in group 'SmailPost-Senders'."
                    )

                    if (-not [string]::IsNullOrWhiteSpace($senderPreview)) {
                        $notes += "Sender preview: $senderPreview."
                    }

                    Set-SectionStatus -Name 'AllowedSenders' -Status '✅' -Notes $notes
                }
                else {
                    Set-SectionStatus -Name 'AllowedSenders' -Status '⏭️' -Notes @(
                        "Group 'SmailPost-Senders' is reachable, but no valid senders were found.",
                        "Only users with a populated mail attribute are accepted.",
                        "Add one or more valid sender accounts to the group and rerun Invoke-SPSetup."
                    )
                }
            }
        }
        catch {
            Set-SectionStatus -Name 'AllowedSenders' -Status '⚠️' -Notes @(
                "Allowed sender lookup failed: $($_.Exception.Message)."
            )
        }
    }
    end {
        # Compute an overall status: ❌ dominates, then ⚠️, then ⏭️, else ✅.
        $statuses = @(
            $summary.Environment.Status,
            $summary.Dependencies.Status,
            $summary.Graph.Status,
            $summary.SecretStore.Status,
            $summary.GraphConnection.Status,
            $summary.AllowedSenders.Status
        )

        if ($statuses -contains '❌') {
            $summary.OverallStatus = '❌'
        }
        elseif ($statuses -contains '⚠️') {
            $summary.OverallStatus = '⚠️'
        }
        elseif ($statuses -contains '⏭️') {
            $summary.OverallStatus = '⏭️'
        }
        else {
            $summary.OverallStatus = '✅'
        }

        if ($summary.SecretStore.Status -eq '⏭️') {
            $summary.NextStep = 'Run Invoke-SPSetup'
        }
        elseif ($summary.GraphConnection.Status -eq '⏭️') {
            $summary.NextStep = 'Run Invoke-SPStoreSecret'
        }
        elseif ($summary.GraphConnection.Status -eq '❌') {
            $summary.NextStep = 'Verify the stored Graph credentials and rerun Invoke-SPStoreSecret'
        }
        elseif (
            $summary.GraphConnection.Status -eq '✅' -and
            $summary.AllowedSenders.Status -eq '⏭️'
        ) {
            $summary.NextStep = 'Add users with valid mail addresses to the SmailPost-Senders group'
        }
        elseif ($summary.OverallStatus -eq '✅') {
            $summary.NextStep = 'None'
        }
        else {
            $summary.NextStep = 'Resolve warnings or errors and rerun Invoke-SPSetup'
        }

        # Print a concise "doctor note" at-a-glance result.
        if (-not $Unattended) {
            Write-Information -MessageData "" -InformationAction Continue                             # Blank line for readability.
            Write-Information -MessageData "=== Setup summary ===" -InformationAction Continue        # Section header.
            foreach ($k in 'Environment', 'Dependencies', 'Graph', 'SecretStore', 'GraphConnection', 'AllowedSenders') {
                $sec = $summary[$k]
                if (-not $sec) { continue }

                Write-Information -MessageData ("{0,-16}: {1}" -f $k, $sec.Status) -InformationAction Continue

                foreach ($n in ($sec.Notes ?? @())) {
                    Write-Information -MessageData "- $n" -InformationAction Continue
                }
            }

            Write-Information -MessageData ("Overall    : {0}" -f $summary.OverallStatus) -InformationAction Continue

            if ($summary.OverallStatus -eq '✅') {

                if ($summary.GraphConnection.Status -eq '✅' -and $summary.AllowedSenders.Status -eq '✅') {
                    Write-Information -MessageData "All green: SmailPost setup is complete. You are ready to use SmailPost." -InformationAction Continue
                }
            }
            elseif ($summary.OverallStatus -eq '⏭️') {

                if ($summary.SecretStore.Status -eq '✅' -and $summary.GraphConnection.Status -eq '⏭️') {
                    Write-Information -MessageData "Setup mostly complete: vault is ready, but Graph credentials still need to be stored." -InformationAction Continue
                }
                else {
                    Write-Information -MessageData "Setup is not fully complete yet. Finish the skipped steps and rerun Invoke-SPSetup." -InformationAction Continue
                }

            }
            Write-Information -MessageData ("Next step  : {0}" -f $summary.NextStep) -InformationAction Continue
        }

        # Stop transcript (best-effort) so the log is flushed and closed properly.
        try {
            if ($transcriptStarted) { Stop-Transcript | Out-Null }
        }
        catch {
            Write-Verbose "Stop-Transcript issue: $($_.Exception.Message)"
        }

        # Return the summary as a PSCustomobject so scripts/CI can parse it easily
        [pscustomobject]$summary
    }

}
