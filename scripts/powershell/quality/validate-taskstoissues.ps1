[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/quality-common.ps1"
. "$PSScriptRoot/artifact-rules.ps1"
. "$PSScriptRoot/analyze-receipt.ps1"
. "$PSScriptRoot/github-repository.ps1"
. "$PSScriptRoot/taskstoissues-rules.ps1"
. "$PSScriptRoot/taskstoissues-receipt.ps1"

$context = Get-QualityFeatureContext
$gitDir = Get-SpecKitGitDir $context.RepoRoot
$repository = Get-OriginGitHubRepository $context.RepoRoot
$tasks = Get-Content $context.Tasks -Raw
$taskIds = @(Get-TaskIds $tasks)
$featureName = Split-Path $context.FeatureDir -Leaf
$tasksHash = Get-SpecArtifactHash @($context.Tasks)
$errors = [System.Collections.Generic.List[string]]::new()

foreach ($message in Test-TasksContent $tasks) {
    $errors.Add("tasks.md: $message")
}

$raw = gh api --paginate --slurp `
    "repos/$repository/issues?state=all&per_page=100"
if ($LASTEXITCODE -ne 0) { throw "GitHub issue query failed" }
$pages = $raw | ConvertFrom-Json
$issues = @($pages | ForEach-Object { $_ } |
    Where-Object { $null -eq $_.pull_request })
$coverage = Test-TaskIssueCoverage $taskIds $issues $featureName
foreach ($message in $coverage.Errors) { $errors.Add($message) }
if ($errors.Count -eq 0) {
    Write-TasksToIssuesReceipt $gitDir $tasksHash `
        $repository $coverage.Mapping
}

$status = if ($errors.Count) { "BLOCKED" } else { "PASS" }
Write-GateResult "AfterTasksToIssues" $status `
    @("tasks", "github-remote", "issue-mapping") $errors
if ($status -eq "BLOCKED") { exit 1 }
