# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic Versioning.

---

## [1.0.0] - 2026-09-30

### Added

* Full SmailPost mail pipeline:

  * CSV import
  * Row validation
  * Template rendering
  * Attachment processing
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

* Microsoft Graph app-only authentication

* SecretStore integration for secure credential handling

* CSV-driven template system with placeholder replacement

* Support for:

  * Attachments
  * Inline images
  * BCC recipients

* Microsoft Graph throttling handling:

  * HTTP 429 detection
  * Retry-After support
  * Automatic retry processing

* Structured job reporting:

  * Setup validation results
  * Row validation results
  * Rendering results
  * Batch send results
  * Transport diagnostics

* Full Pester test suite

* Documentation:

  * Operator manual
  * README
  * Development documentation

### Changed

* Standardized module structure:

  * Public / Private separation
  * Controlled export surface

* Improved validation and error reporting:

  * No silent failures
  * Structured result objects
  * Consistent status reporting

* Improved mail processing pipeline:

  * Validation before sending
  * Rendering before transport
  * Detailed batch results

### Fixed

* Module loading issues with nested folders

* Export surface restricted to public functions only

* Multiple validation edge cases:

  * Recipients
  * Attachments
  * Templates
  * CSV input

* Microsoft Graph throttling scenarios during batch processing

---

## [0.1.0] - 2025-09-09

### Added

* Initial project structure
* Base configuration files
* GitHub Actions quality workflow
