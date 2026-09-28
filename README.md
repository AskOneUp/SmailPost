# SmailPost

[![Quality Checks](https://github.com/AskOneUp/SmailPost/actions/workflows/quality.yml/badge.svg)](https://github.com/AskOneUp/SmailPost/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PowerShell 7+](https://img.shields.io/badge/PowerShell-7%2B-5391FE)](#)

SmailPost is a PowerShell module for sending bulk emails through Microsoft Graph.

It provides a structured pipeline:

```
CSV → Validation → Rendering → Sending → Reporting
```

---

## Quick Start

```powershell
Import-Module ./SmailPost.psd1

Install-SPDependency
Invoke-SPSetup
Invoke-SPStoreSecret
Invoke-SPSetup
```

Send a test email:

```powershell
Send-SPMail `
    -SenderAddress "no-reply@contoso.com" `
    -To "user@contoso.com" `
    -Subject "Test" `
    -HtmlBody "<p>Hello from SmailPost.</p>"
```

---

## Features

- Bulk email via Microsoft Graph
- CSV-driven mail jobs
- Template support with `{{Placeholders}}`
- Per-recipient send results
- JSON and CSV reporting
- Secure credential storage with SecretStore
- Sender allow-list through the `C-S-mailPost-Senders` group
- Full Pester test coverage

---

## Core Commands

| Command | Description |
|--------|------------|
| Install-SPDependency | Installs required PowerShell modules |
| Invoke-SPSetup | Prepares and validates the environment |
| Invoke-SPStoreSecret | Stores Microsoft Graph credentials |
| Reset-SPSecretStoreState | Resets SecretStore state |
| Test-SPEnvironment | Checks PowerShell compatibility |
| Test-SPPrerequisite | Checks Graph reachability |
| Test-SPGraphConnection | Validates Graph authentication |
| Get-SPAllowedSender | Lists allowed sender mailboxes |
| Import-SPCsv | Imports CSV input |
| Send-SPMail | Sends one email per recipient |
| Invoke-SPMailJob | Runs a full CSV mail job |
| Export-SPMailJobReport | Exports a job report |
| Show-SPMailJobSummary | Displays a job summary |

---

## CSV Example

```csv
Email,FirstName
john@contoso.com,John
jane@contoso.com,Jane
```

Template example:

```
Hello {{FirstName}}
```

CSV job example:

```powershell
$report = Invoke-SPMailJob `
    -CsvPath "C:\Data\Recipients.csv" `
    -RecipientColumn "Email" `
    -SenderAddress "no-reply@contoso.com" `
    -SubjectTemplate "Hello {{FirstName}}" `
    -HtmlBodyTemplate "<p>Hello {{FirstName}},</p><p>This message was sent with SmailPost.</p>"

Show-SPMailJobSummary -Report $report
```

---

## Reports

Export as JSON:

```powershell
Export-SPMailJobReport `
    -Report $report `
    -Path "C:\Reports\SmailPostReport.json"
```

Export as CSV:

```powershell
Export-SPMailJobReport `
    -Report $report `
    -Path "C:\Reports\SmailPostReport.csv" `
    -Format Csv
```

---

## Requirements

- PowerShell 7.2 or newer
- Microsoft Graph application permissions:
  - Mail.Send
  - GroupMember.Read.All
  - User.Read.All
- Microsoft Entra group:

```
C-S-mailPost-Senders
```

Only mail-enabled users in this group are allowed senders.

---

## Development

Run tests:

```powershell
Invoke-Pester -Path .\Tests
```

Run Script Analyzer:

```powershell
Invoke-ScriptAnalyzer `
    -Path . `
    -Recurse `
    -Settings .\PSScriptAnalyzerSettings.psd1 `
    -Severity Warning
```

---

## Project Structure

```
Public/      Public commands
Private/     Internal helpers
Tests/       Pester tests
Docs/        Documentation
Examples/    Example scripts
```

---

## Documentation

Full manual available in the `Docs/` folder.

---

## License

MIT License.
