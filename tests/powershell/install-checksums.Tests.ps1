. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/installation/install-checksums.ps1"
. "$PSScriptRoot/../../tools/install-file-list.ps1"

$root = (Resolve-Path "$PSScriptRoot/../..").Path

# The released checksums must match the files that get installed; run
# tools/write-install-checksums.ps1 after changing any of them.
$expected = Get-InstallChecksumMap $root
$committed = (Get-Content (Join-Path $root "install-checksums.json") -Raw | ConvertFrom-Json).files
$committedPaths = @($committed.PSObject.Properties.Name | Sort-Object)
Assert-Equal (($expected.Keys | Sort-Object) -join ";") ($committedPaths -join ";") (
    "install-checksums.json lists every installed file"
)
foreach ($path in $expected.Keys) {
    Assert-Equal $expected[$path] $committed.$path "checksum of $path is current"
}
Assert-True ($expected.Keys -notcontains "tests/powershell/run-tests.ps1") "tests are not installed"
Assert-True ($expected.Keys -contains "THIRD_PARTY_NOTICES.md") "license notices are installed"

$copy = Join-Path ([IO.Path]::GetTempPath()) ("checksums-" + [guid]::NewGuid())
try {
    foreach ($path in @($expected.Keys) + "install-checksums.json") {
        $target = Join-Path $copy $path
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $root $path) -Destination $target
    }
    Assert-Equal 0 @(Test-InstallChecksums $copy).Count "an untouched copy passes"

    $readme = Join-Path $copy "README.md"
    $crlf = (Get-Content -LiteralPath $readme -Raw) -replace "(?<!`r)`n", "`r`n"
    [IO.File]::WriteAllText($readme, $crlf)
    Assert-Equal 0 @(Test-InstallChecksums $copy).Count "CRLF line endings are not an edit"

    $script = Join-Path $copy "scripts/powershell/quality/validate-readiness.ps1"
    Add-Content -LiteralPath $script -Value "# local edit"
    $errors = @(Test-InstallChecksums $copy)
    Assert-True ("$errors" -match "validate-readiness\.ps1") "an edited script is reported"

    Remove-Item -LiteralPath (Join-Path $copy "commands/commit.md")
    $errors = @(Test-InstallChecksums $copy)
    Assert-True ("$errors" -match "missing.*commit\.md") "a deleted file is reported"
}
finally {
    Remove-Item -LiteralPath $copy -Recurse -Force -ErrorAction SilentlyContinue
}
