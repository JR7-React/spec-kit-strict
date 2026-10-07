$ErrorActionPreference = "Stop"
. "$PSScriptRoot/quality-common.ps1"
. "$PSScriptRoot/change-scope.ps1"
. "$PSScriptRoot/line-policy.ps1"
. "$PSScriptRoot/targeted-tests.ps1"

$context = Get-QualityFeatureContext
$config = Read-QualityGateConfig
$gitDir = Get-SpecKitGitDir $context.RepoRoot
$receiptDir = Join-Path $gitDir "speckit"
$receiptPath = Join-Path $receiptDir "implementation-gate.json"
Remove-Item -LiteralPath $receiptPath -Force -ErrorAction SilentlyContinue

$files = Get-ChangedFiles $context.RepoRoot $config.base_branch
$fingerprint = Get-ChangeFingerprint $context.RepoRoot $files
$errors = [System.Collections.Generic.List[string]]::new()
$baseRef = Resolve-BaseReference $context.RepoRoot $config.base_branch
$base = (git -C $context.RepoRoot merge-base HEAD $baseRef).Trim()

git -C $context.RepoRoot diff --check "$base...HEAD"
if ($LASTEXITCODE -ne 0) { $errors.Add("committed diff check failed") }
git -C $context.RepoRoot diff --check
if ($LASTEXITCODE -ne 0) { $errors.Add("working diff check failed") }
git -C $context.RepoRoot diff --cached --check
if ($LASTEXITCODE -ne 0) { $errors.Add("staged diff check failed") }

$exemptPats = @($config.line_exempt_patterns)
foreach ($violation in Test-LinePolicy $files $config.line_limits.new `
    $config.line_limits.modified @($config.source_extensions) `
    $context.RepoRoot $exemptPats) {
    $errors.Add($violation)
}

$tasksContent = Get-Content $context.Tasks -Raw
if ($tasksContent -match '(?m)^- \[ \] T\d{3}\b') {
    $errors.Add("tasks.md has incomplete tasks")
}
foreach ($file in $files) {
    if (Test-PathMatchesAny $file.Path $config.scope_exemptions) { continue }
    if ($tasksContent -notmatch [regex]::Escape($file.Path)) {
        $errors.Add("changed path not declared in tasks.md: $($file.Path)")
    }
}

if ($errors.Count -eq 0) {
    try {
        $frontend = @($files.Path | Where-Object {
            $_ -like "$($config.frontend.root)/*"
        })
        $backend = @($files.Path | Where-Object {
            $_ -like "$($config.backend.root)/*"
        })
        if ($frontend.Count -gt 0) {
            & "$PSScriptRoot/invoke-frontend-gate.ps1" -ChangedPaths $frontend
        }
        if ($backend.Count -gt 0) {
            & "$PSScriptRoot/invoke-backend-gate.ps1" -ChangedPaths $backend
        }
    }
    catch {
        $errors.Add($_.Exception.Message)
    }
}

$status = if ($errors.Count -eq 0) { "PASS" } else { "BLOCKED" }
New-Item -ItemType Directory -Path $receiptDir -Force | Out-Null
[PSCustomObject]@{
    status = $status
    fingerprint = $fingerprint
    recorded_at = [DateTime]::UtcNow.ToString("o")
} | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8
Write-GateResult "Implementation" $status `
    @("diff", "lines", "tasks", "frontend", "backend") $errors
if ($status -eq "BLOCKED") { exit 1 }
