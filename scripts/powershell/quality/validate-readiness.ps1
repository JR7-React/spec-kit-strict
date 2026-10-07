$ErrorActionPreference = "Stop"
. "$PSScriptRoot/quality-common.ps1"
. "$PSScriptRoot/analyze-receipt.ps1"

$context = Get-QualityFeatureContext
$errors = [System.Collections.Generic.List[string]]::new()
$checks = @("artifacts", "checklists", "analysis-receipt", "branch")

& pwsh -NoProfile -File "$PSScriptRoot/validate-artifacts.ps1" -Phase Tasks
if ($LASTEXITCODE -ne 0) {
    $errors.Add("artifact validation failed")
}

$incomplete = [System.Collections.Generic.List[string]]::new()
Get-ChildItem $context.Checklists -Filter "*.md" -ErrorAction SilentlyContinue |
    ForEach-Object {
        $matches = Select-String -Path $_.FullName -Pattern '^\s*- \[ \]'
        foreach ($match in $matches) {
            $incomplete.Add("$($_.Name):$($match.LineNumber)")
        }
    }
if ($incomplete.Count -gt 0) {
    $errors.Add("incomplete checklists: $($incomplete -join ', ')")
}

$constitution = Join-Path $context.RepoRoot ".specify/memory/constitution.md"
$artifactHash = Get-SpecArtifactHash @(
    $context.Spec,
    $context.Plan,
    $context.Tasks,
    $constitution
)
$gitDir = Get-SpecKitGitDir $context.RepoRoot
$receipt = Read-AnalyzeReceipt $gitDir
if (-not (Test-AnalyzeReceipt $receipt $artifactHash)) {
    $errors.Add("missing, blocked, or stale analyze-gate receipt")
}

$featureName = Split-Path $context.FeatureDir -Leaf
$effectiveBranch = Get-SpecKitEffectiveBranchName $context.Branch
if ($effectiveBranch -ne $featureName) {
    $errors.Add(
        "branch '$($context.Branch)' does not match feature '$featureName'"
    )
}

$status = if ($errors.Count -eq 0) { "PASS" } else { "BLOCKED" }
Write-GateResult "Readiness" $status $checks $errors
if ($status -eq "BLOCKED") { exit 1 }
