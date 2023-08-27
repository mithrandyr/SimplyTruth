#dotsource private functions
foreach($file in (Get-ChildItem -File -Path (Join-Path $PSScriptRoot "Private") -Filter "*.ps1" -Recurse)) {
    . $file.FullName
}

#dotsource public functions and export
foreach($file in (Get-ChildItem -File -Path (Join-Path $PSScriptRoot "Public") -Filter "*.ps1" -Recurse)) {
    . $file.FullName
    Export-ModuleMember -Function $file.BaseName
}