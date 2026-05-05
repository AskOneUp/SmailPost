# SmailPost

[![Quality Checks](https://github.com/OWNER/REPO/actions/workflows/quality.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PowerShell 7+](https://img.shields.io/badge/PowerShell-7%2B-5391FE)](#)

SmailPost is a PowerShell module for sending mass emails.
It is designed with a clean structure, automated quality checks, and support for testing.

---

## Features
- Send bulk emails from PowerShell.
- Structured as a proper module (`.psm1`, `.psd1`).
- Built-in code quality checks with **PSScriptAnalyzer**.
- Ready for automated testing with **Pester**.
- Cross-platform support via **PowerShell 7 (pwsh)**.


## Installation

Clone this repository and import the module:

```powershell
Import-Module ./SmailPost.psd1
```

## Usage

Basic example:

Send-Mail -To "user@example.com" -Subject "Hello" -Body "World"

## Development

Code Quality

Run PSScriptAnalyzer to check coding standards:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning
```

## Tests

Run Pester tests in the Tests/ folder:

```powershell
Invoke-Pester
```

## Project Structure

SmailPost/
│
├─ Public/                 # Exported commands
├─ Private/                # Internal helpers
├─ Examples/               # Example usage scripts
├─ Docs/                   # Documentation
├─ Tests/                  # Pester tests
│
├─ SmailPost.psd1          # Module manifest
├─ SmailPost.psm1          # Module entry point
├─ .editorconfig
├─ .gitattributes
├─ .gitignore
├─ .vscode/settings.json   # Workspace settings
├─ .github/workflows/quality.yml
│
├─ CHANGELOG.md
├─ LICENSE
└─ README.md

## Contributing

Pull requests are welcome.

For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License
