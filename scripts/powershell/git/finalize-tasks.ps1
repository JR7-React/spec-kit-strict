$ErrorActionPreference = "Stop"
. "$PSScriptRoot/../quality/quality-common.ps1"
. "$PSScriptRoot/../quality/change-scope.ps1"

$context = Get-QualityFeatureContext
$config = Read-QualityGateConfig
$files = Get-ChangedFiles $context.RepoRoot $config.base_branch
$fingerprint = Get-ChangeFingerprint $context.RepoRoot $files
$gitDir = Get-SpecKitGitDir $context.RepoRoot
$receiptPath = Join-Path $gitDir "speckit/implementation-gate.json"
if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) {
    throw "implementation gate receipt is missing"
}
$receipt = Get-Content $receiptPath -Raw | ConvertFrom-Json
if ($receipt.status -ne "PASS" -or $receipt.fingerprint -ne $fingerprint) {
    throw "implementation gate receipt is blocked or stale"
}

$tasks = Get-Content $context.Tasks -Raw
if ($tasks -match '(?m)^- \[ \] T\d{3}\b') {
    throw "tasks.md has incomplete tasks"
}

& "$PSScriptRoot/commit-spec-artifacts.ps1" `
    -RepoRoot $context.RepoRoot -Phase Tasks
Remove-Item -LiteralPath $receiptPath -Force
