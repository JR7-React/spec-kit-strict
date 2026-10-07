. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/analyze-receipt.ps1"

$script = "$PSScriptRoot/../../scripts/powershell/quality/record-analyze-receipt.ps1"
Assert-True (Test-Path $script) "record analyze entrypoint exists"

$temp = Join-Path ([IO.Path]::GetTempPath()) ("analyze-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path "$temp/.git" -Force | Out-Null
try {
    $artifact = Join-Path $temp "tasks.md"
    Set-Content $artifact "- [ ] T001 Demo"
    $hash = Get-SpecArtifactHash @($artifact)

    & pwsh -NoProfile -File $script `
        -GitDir "$temp/.git" -ArtifactHash $hash `
        -Critical 0 -High 0 -Medium 2 -Low 1 *> $null
    Assert-Equal 0 $LASTEXITCODE "medium and low pass"
    $passing = Read-AnalyzeReceipt "$temp/.git"
    Assert-True (Test-AnalyzeReceipt $passing $hash) "passing receipt accepted"

    & pwsh -NoProfile -File $script `
        -GitDir "$temp/.git" -ArtifactHash $hash `
        -Critical 0 -High 1 -Medium 0 -Low 0 *> $null
    Assert-Equal 1 $LASTEXITCODE "high blocks"
    $blocked = Read-AnalyzeReceipt "$temp/.git"
    Assert-Equal 1 $blocked.high "blocked receipt is still recorded"

    & pwsh -NoProfile -NonInteractive -File $script `
        -GitDir "$temp/.git" -ArtifactHash $hash `
        -Critical 0 -High 0 -Medium 0 *> $null
    Assert-True ($LASTEXITCODE -ne 0) "all finding counts are required"
}
finally {
    Remove-Item $temp -Recurse -Force
}
