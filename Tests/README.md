# SmailPost Tests

SmailPost uses Pester for automated testing.

The test structure mirrors the module source structure:

- `Public/` contains tests for public commands.
- `Private/` contains tests for internal helper functions.

## Run All Tests

From the SmailPost project root:

```powershell
Invoke-Pester -Path .\Tests
