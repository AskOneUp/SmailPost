@{
    # Core module identity.
    RootModule        = 'SmailPost.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a1e3b0f1-6e9d-4a6e-9a53-2d9f1afc2d8b'
    Author            = 'OneUp!'
    CompanyName       = 'AskOneUp'
    Copyright         = '© 2026 AskOneUp. All rights reserved.'
    Description       = 'PowerShell module for sending bulk email through Microsoft Graph.'

    # PowerShell requirements.
    PowerShellVersion = '7.2'

    # Public module interface.
    FunctionsToExport = @(
        'Export-SPMailJobReport'
        'Get-SPAllowedSender'
        'Import-SPCsv'
        'Install-SPDependency'
        'Invoke-SPMailJob'
        'Invoke-SPSetup'
        'Invoke-SPStoreSecret'
        'Reset-SPSecretStoreState'
        'Send-SPMail'
        'Show-SPMailJobSummary'
        'Test-SPEnvironment'
        'Test-SPGraphConnection'
        'Test-SPPrerequisite'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Module metadata.
    PrivateData       = @{
        PSData = @{
            Tags       = @(
                'MicrosoftGraph'
                'Email'
                'BulkMail'
                'PowerShell'
            )

            LicenseUri = 'https://github.com/AskOneUp/SmailPost/blob/main/LICENSE'
            ProjectUri = 'https://github.com/AskOneUp/SmailPost'
        }
    }
}
