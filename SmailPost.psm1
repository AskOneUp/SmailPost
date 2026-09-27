# Load all private functions.
Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Recurse -Filter '*.ps1' |
Sort-Object FullName |
ForEach-Object {
    . $_.FullName
}

# Load all public functions.
$PublicFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Recurse -Filter '*.ps1' |
Sort-Object FullName |
ForEach-Object {
    . $_.FullName
    $_.BaseName
}

# Export only the public functions.
Export-ModuleMember -Function $PublicFunctions
