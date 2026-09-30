# SmailPost

[![Quality Checks](https://github.com/AskOneUp/SmailPost/actions/workflows/quality.yml/badge.svg)](https://github.com/AskOneUp/SmailPost/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PowerShell 7+](https://img.shields.io/badge/PowerShell-7%2B-5391FE)](#)

SmailPost is a PowerShell module for sending bulk emails through Microsoft Graph.

It provides a structured and validated mail processing pipeline:

```text
CSV
 ↓
Validation
 ↓
Template Rendering
 ↓
Attachment Processing
 ↓
Microsoft Graph Sending
 ↓
Retry Handling
 ↓
Reporting
```

---

# Status

SmailPost **1.0.0** is a stable release.

The current release supports:

- CSV-driven bulk mail jobs
- Microsoft Graph app-only authentication
- HTML mail templates
- CSV placeholder replacement
- Attachments
- Inline images
- Sender validation
- Batch processing
- Structured job reporting
- Microsoft Graph throttling detection and automatic retry handling

---

# Quick Start

## Install and configure

```powershell
Import-Module ./SmailPost.psd1

Install-SPDependency

Invoke-SPSetup

Invoke-SPStoreSecret
```

The setup process prepares:

- required PowerShell dependencies;
- SecretStore configuration;
- Microsoft Graph authentication requirements.

---

# Send a single email

```powershell
Send-SPMail `
    -SenderAddress "no-reply@contoso.com" `
    -To "user@contoso.com" `
    -Subject "Test" `
    -HtmlBody "<p>Hello from SmailPost.</p>"
```

---

# Features

- Bulk email sending through Microsoft Graph
- CSV-driven mail workflows
- HTML templates with `{{Placeholders}}`
- Per-recipient validation
- Attachments and inline images
- Structured batch reports
- Secure credential storage using SecretStore
- Sender allow-list validation through the `C-S-mailPost-Senders` group
- Microsoft Graph throttling handling using `Retry-After`
- Full Pester test coverage

---

# Core Commands

| Command | Description |
|---|---|
| Install-SPDependency | Installs required PowerShell modules |
| Invoke-SPSetup | Prepares and validates the environment |
| Invoke-SPStoreSecret | Stores Microsoft Graph credentials |
| Reset-SPSecretStoreState | Resets SecretStore state |
| Test-SPEnvironment | Checks PowerShell compatibility |
| Test-SPPrerequisite | Checks required prerequisites |
| Test-SPGraphConnection | Validates Graph authentication |
| Get-SPAllowedSender | Lists allowed sender mailboxes |
| Import-SPCsv | Imports and validates CSV input |
| Send-SPMail | Sends a single email |
| Invoke-SPMailJob | Executes a complete CSV mail workflow |
| Export-SPMailJobReport | Exports job results |
| Show-SPMailJobSummary | Displays job summary |

---

# CSV Workflow

SmailPost uses CSV files as the source for bulk mail jobs.

Example:

```csv
Email,Naam,Stamnummer,Paswoord,Subject
john@contoso.com,John Doe,123456,password,Welcome
jane@contoso.com,Jane Doe,987654,password,Welcome
```

CSV values can be used inside templates:

```text
Beste {{Naam}},

Je gebruikersnaam is {{Stamnummer}}.
Je tijdelijk paswoord is {{Paswoord}}.
```

---

# Running a Mail Job

Example:

```powershell
$Report = Invoke-SPMailJob `
    -CsvPath "C:\Data\Recipients.csv" `
    -RecipientColumn "Email" `
    -SenderAddress "no-reply@contoso.com" `
    -SubjectTemplate "{{Subject}}" `
    -HtmlBodyTemplate $HtmlBody
```

A mail job performs:

1. CSV import
2. Job configuration validation
3. Row validation
4. Template rendering
5. Attachment processing
6. Microsoft Graph sending
7. Result reporting

---

# Microsoft Graph Throttling

SmailPost automatically handles Microsoft Graph throttling.

When Microsoft Graph returns a throttling response:

- HTTP 429 responses are detected;
- the `Retry-After` value is respected;
- the send operation is retried;
- processing continues without losing the batch.

Example:

```text
Microsoft Graph throttled sendMail attempt 1.
Retrying after 120 second(s) as requested by Retry-After.

Microsoft Graph accepted the sendMail request.
```

---

# Reports

Every mail job returns a structured report.

Example:

```text
OverallStatus        : Sent
TotalRows            : 76
ValidRowCount        : 76
RenderedCount        : 76
SentCount            : 76
FailedCount          : 0
```

Reports contain:

- overall job status;
- setup validation results;
- row validation results;
- rendered mail results;
- sent and failed counters;
- transport diagnostics from Microsoft Graph communication.

---

# Export Reports

## Export JSON

```powershell
Export-SPMailJobReport `
    -Report $Report `
    -Path "C:\Reports\SmailPostReport.json"
```

---

## Export CSV

```powershell
Export-SPMailJobReport `
    -Report $Report `
    -Path "C:\Reports\SmailPostReport.csv" `
    -Format Csv
```

---

# Requirements

- PowerShell 7.2 or newer

Microsoft Graph application permissions:

```text
Mail.Send
GroupMember.Read.All
User.Read.All
```

Microsoft Entra group:

```text
C-S-mailPost-Senders
```

Only mail-enabled users in this group are allowed as senders.

---

# Known Limitations

- Long-running unattended jobs require additional credential lifecycle handling.
- SecretStore must remain available during execution.

---

# Development

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

# Project Structure

```text
Public/       Exported commands
Private/      Internal implementation
Tests/        Pester tests
Docs/         Documentation
Examples/     Example scripts
.github/      CI workflows
```

---

# Documentation

Full documentation is available in the `Docs/` folder.

---

# License

MIT License.
