. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/analyze-receipt.ps1"

$temp = Join-Path ([System.IO.Path]::GetTempPath()) (
    "speckit-" + [guid]::NewGuid()
)
New-Item -ItemType Directory -Path $temp | Out-Null

try {
    $artifact = Join-Path $temp "spec.md"
    Set-Content -LiteralPath $artifact -Value "version one"
    $artifactHash = Get-SpecArtifactHash @($artifact)

    Write-AnalyzeReceipt -GitDir $temp -ArtifactHash $artifactHash `
        -Critical 0 -High 0 -Medium 2 -Low 1
    $receipt = Read-AnalyzeReceipt -GitDir $temp

    Assert-Equal $artifactHash $receipt.artifact_hash (
        "receipt stores artifact hash"
    )
    Assert-Equal 0 $receipt.high "receipt stores high count"
    Assert-True (Test-AnalyzeReceipt $receipt $artifactHash) (
        "passing receipt accepted"
    )
    Assert-True (-not (Test-AnalyzeReceipt $receipt "changed")) (
        "stale receipt rejected"
    )

    Write-AnalyzeReceipt -GitDir $temp -ArtifactHash $artifactHash `
        -Critical 0 -High 1 -Medium 0 -Low 0
    $blocked = Read-AnalyzeReceipt -GitDir $temp
    Assert-True (-not (Test-AnalyzeReceipt $blocked $artifactHash)) (
        "high finding blocks receipt"
    )

    Set-Content -LiteralPath $artifact -Value "version two"
    Assert-True ((Get-SpecArtifactHash @($artifact)) -ne $artifactHash) (
        "artifact changes invalidate hash"
    )
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force
}

$readiness = Get-Content (
    "$PSScriptRoot/../../scripts/powershell/quality/validate-readiness.ps1"
) -Raw
Assert-True ($readiness -notmatch 'quality-analyze-gate|speckit-analyze') (
    "readiness does not rerun semantic analysis"
)
Assert-True ($readiness -match 'Test-AnalyzeReceipt') (
    "readiness requires analyze receipt"
)
Assert-True ($readiness -match 'Get-SpecKitGitDir') (
    "readiness uses the shared Git directory resolver"
)
