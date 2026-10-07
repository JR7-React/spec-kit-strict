param([string]$Filter = "")

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/speckit-test-project.ps1"

$coreProject = New-SpecKitTestProject "strict-core"
$env:SPECKIT_CORE_DIR = Join-Path $coreProject ".specify/scripts/powershell"
try {
    $tests = Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*$Filter*.Tests.ps1" |
        Sort-Object Name
    if ($tests.Count -eq 0) { throw "No tests match filter '$Filter'" }
    foreach ($test in $tests) {
        Write-Output "RUN: $($test.Name)"
        & $test.FullName
    }
    Write-Output "PASS: all strict extension tests"
}
finally {
    Remove-Item -LiteralPath $coreProject -Recurse -Force -ErrorAction SilentlyContinue
}
