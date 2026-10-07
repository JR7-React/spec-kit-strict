# Regenerates install-checksums.json from the files a release installs.
# Run it after changing any installed file; the test suite rejects stale sums.
$ErrorActionPreference = "Stop"
. "$PSScriptRoot/install-file-list.ps1"

$root = (Resolve-Path "$PSScriptRoot/..").Path
$document = [ordered]@{
    schema_version = 1
    files = Get-InstallChecksumMap $root
}
$json = ($document | ConvertTo-Json -Depth 3).Replace("`r`n", "`n")
[IO.File]::WriteAllText((Join-Path $root "install-checksums.json"), "$json`n")
Write-Output "install-checksums.json: $($document.files.Count) files"
