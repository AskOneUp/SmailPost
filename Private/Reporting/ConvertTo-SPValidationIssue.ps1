function ConvertTo-SPValidationIssue {

    <#
.SYNOPSIS
Creates a standardized SmailPost validation issue object.
#>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'This function only creates and returns an in-memory object.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Error', 'Warning')]
        [string]$Severity,

        [Parameter(Mandatory)]
        [string]$Code,

        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Target = '',

        [Parameter()]
        [AllowNull()]
        [Nullable[int]]$RowNumber = $null,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ColumnName = '',

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Details = ''
    )

    return [pscustomobject]@{
        Severity   = $Severity
        Code       = $Code
        Category   = $Category
        Message    = $Message
        Target     = $Target
        RowNumber  = $RowNumber
        ColumnName = $ColumnName
        Details    = $Details
    }
}
