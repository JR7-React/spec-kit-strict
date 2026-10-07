. "$PSScriptRoot/test-support.ps1"

$repo = Join-Path ([System.IO.Path]::GetTempPath()) (
    "speckit-git-" + [guid]::NewGuid()
)
New-Item -ItemType Directory -Path "$repo/.specify" -Force | Out-Null
New-Item -ItemType Directory -Path (
    "$repo/specs/001-demo/checklists"
) -Force | Out-Null
New-Item -ItemType Directory -Path "$repo/frontend/src" -Force |
    Out-Null

try {
    git -C $repo init -q
    git -C $repo config user.email "tests@example.com"
    git -C $repo config user.name "SpecKit Tests"
    "baseline" | Set-Content "$repo/README.md"
    # Spec Kit 1.x ignores the per-checkout feature pointer.
    "feature.json" | Set-Content "$repo/.specify/.gitignore"
    git -C $repo add -- README.md .specify/.gitignore
    git -C $repo commit -q -m "test: baseline"

    '{"feature_directory":"specs/001-demo"}' |
        Set-Content "$repo/.specify/feature.json"
    "# Spec" | Set-Content "$repo/specs/001-demo/spec.md"
    "- [x] Requirement" |
        Set-Content "$repo/specs/001-demo/checklists/requirements.md"
    "export const dirty = true;" |
        Set-Content "$repo/frontend/src/dirty.ts"
    git -C $repo add -- "frontend/src/dirty.ts"

    & "$PSScriptRoot/../../scripts/powershell/git/commit-spec-artifacts.ps1" `
        -RepoRoot $repo -Phase Specify
    Assert-Equal 0 $LASTEXITCODE "spec commit succeeds"
    $committed = @(git -C $repo show --name-only --pretty=format: HEAD)
    Assert-True ($committed -contains "specs/001-demo/spec.md") (
        "spec committed"
    )
    Assert-True ($committed -notcontains "frontend/src/dirty.ts") (
        "code excluded"
    )
    Assert-True ($committed -notcontains ".specify/feature.json") (
        "ignored feature pointer is skipped instead of failing the commit"
    )
    $stillStaged = @(git -C $repo diff --cached --name-only)
    Assert-True ($stillStaged -contains "frontend/src/dirty.ts") (
        "existing staged code preserved"
    )
}
finally {
    Remove-Item -LiteralPath $repo -Recurse -Force
}
