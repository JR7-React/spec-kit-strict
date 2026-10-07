. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/quality-common.ps1"

Assert-Equal "001-demo" (Get-SpecKitEffectiveBranchName "jdoe/001-demo") (
    "effective branch drops the user prefix"
)
Assert-Equal "001-demo" (Get-SpecKitEffectiveBranchName "001-demo") (
    "effective branch keeps a plain feature branch"
)

$savedFeature = $env:SPECIFY_FEATURE
$repo = Join-Path ([IO.Path]::GetTempPath()) ("branch-ctx-" + [guid]::NewGuid())
$plain = Join-Path ([IO.Path]::GetTempPath()) ("plain-ctx-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $repo, $plain | Out-Null
try {
    git -C $repo init -q
    git -C $repo checkout -q -b "007-demo"
    git -C $repo -c user.name=t -c user.email=t@example.org commit -q `
        --allow-empty -m "init"

    $env:SPECIFY_FEATURE = $null
    Assert-Equal "007-demo" (Get-QualityCurrentBranch $repo "fallback") (
        "gates read the real git branch, not the feature directory"
    )
    Assert-Equal "fallback" (Get-QualityCurrentBranch $plain "fallback") (
        "outside git the feature directory name is used"
    )

    $env:SPECIFY_FEATURE = "009-override"
    Assert-Equal "009-override" (Get-QualityCurrentBranch $repo "fallback") (
        "SPECIFY_FEATURE keeps precedence like Spec Kit 0.9"
    )
}
finally {
    $env:SPECIFY_FEATURE = $savedFeature
    Remove-Item $repo, $plain -Recurse -Force
}
