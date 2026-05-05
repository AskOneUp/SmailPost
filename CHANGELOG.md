# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic Versioning.

---

## [1.0.0] - 2026-05-05

### Added

* Full SmailPost mail pipeline:

  * CSV import
  * Row validation
  * Template rendering
  * Microsoft Graph sending
  * Structured reporting

* Public command set:

  * Install-SPDependency
  * Invoke-SPSetup
  * Invoke-SPStoreSecret
  * Reset-SPSecretStoreState
  * Test-SPEnvironment
  * Test-SPPrerequisite
  * Test-SPGraphConnection
  * Get-SPAllowedSender
  * Import-SPCsv
  * Send-SPMail
  * Invoke-SPMailJob
  * Export-SPMailJobReport
  * Show-SPMailJobSummary

* SecretStore integration for secure credential handling

* Microsoft Graph app-only authentication

* CSV + template placeholder system

* Full Pester test suite (300+ tests)

* Documentation:

  * Full operator manual
  * README with quick start

### Changed

* Standardized module structure (Public / Private separation)
* Improved validation and error reporting (no silent failures)
* Consistent output model across all commands

### Fixed

* Module loading issues with nested folders
* Export surface restricted to public functions only
* Multiple validation edge cases (recipients, attachments, templates)

---

## [0.1.0] - 2025-09-09

### Added

* Initial project structure
* Base configuration files
* GitHub Actions quality workflow
