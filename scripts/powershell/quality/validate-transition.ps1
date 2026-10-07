[CmdletBinding()]
param(
    [ValidateSet(
        "Plan", "Tasks", "Clarify", "Checklist", "Analyze", "TasksToIssues"
    )]
    [string]$Target
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/quality-common.ps1"
. "$PSScriptRoot/artifact-rules.ps1"
. "$PSScriptRoot/transition-rules.ps1"
. "$PSScriptRoot/analyze-receipt.ps1"
. "$PSScriptRoot/github-repository.ps1"
. "$PSScriptRoot/taskstoissues-receipt.ps1"
. "$PSScriptRoot/taskstoissues-prerequisites.ps1"

$context = Get-QualityFeatureContext
$errors = [System.Collections.Generic.List[string]]::new()
$checks = [System.Collections.Generic.List[string]]::new()
foreach ($message in Test-FeatureBranchMatch $context.Branch $context.FeatureDir) {
    $errors.Add($message)
}
$checks.Add("branch")

if (-not (Test-Path $context.Spec -PathType Leaf)) {
    $errors.Add("missing spec.md")
}
else {
    $spec = Get-Content $context.Spec -Raw
    $allowMarkers = $Target -in @("Clarify", "Checklist")
    foreach ($message in Test-SpecContent $spec `
        -AllowUnresolvedMarkers:$allowMarkers) {
        $errors.Add("spec.md: $message")
    }
    $checks.Add("spec")
}

if ($Target -in @("Plan", "Tasks", "Analyze", "TasksToIssues")) {
    $requirements = Join-Path $context.Checklists "requirements.md"
    if (-not (Test-Path $requirements -PathType Leaf)) {
        $errors.Add("missing requirements.md")
    }
    else {
        $pending = Get-IncompleteChecklistItems (Get-Content $requirements -Raw)
        if ($pending.Count) { $errors.Add("requirements.md is incomplete") }
        $checks.Add("requirements")
    }
}

if ($Target -in @("Tasks", "Analyze", "TasksToIssues")) {
    if (-not (Test-Path $context.Plan -PathType Leaf)) {
        $errors.Add("missing plan.md")
    }
    else {
        foreach ($message in Test-PlanContent `
            (Get-Content $context.Plan -Raw) $context.FeatureDir) {
            $errors.Add("plan.md: $message")
        }
        $checks.Add("plan")
    }
}

if ($Target -in @("Analyze", "TasksToIssues")) {
    if (-not (Test-Path $context.Tasks -PathType Leaf)) {
        $errors.Add("missing tasks.md")
    }
    else {
        foreach ($message in Test-TasksContent (Get-Content $context.Tasks -Raw)) {
            $errors.Add("tasks.md: $message")
        }
        $checks.Add("tasks")
    }
    $checklistFiles = @(Get-ChildItem $context.Checklists `
        -Filter "*.md" -ErrorAction SilentlyContinue)
    if ($checklistFiles.Count -eq 0) {
        $errors.Add("no checklist files found")
    }
    foreach ($file in $checklistFiles) {
        if ((Get-IncompleteChecklistItems (
            Get-Content $file.FullName -Raw
        )).Count) {
            $errors.Add("$($file.Name) is incomplete")
        }
    }
    $checks.Add("checklists")
}

if ($Target -eq "TasksToIssues") {
    foreach ($message in Test-TasksToIssuesPrerequisites $context) {
        $errors.Add($message)
    }
    $checks.Add("analyze-receipt")
    $checks.Add("github-remote")
    $checks.Add("taskstoissues-receipt")
}

$status = if ($errors.Count) { "BLOCKED" } else { "PASS" }
Write-GateResult "Before$Target" $status $checks $errors
if ($status -eq "BLOCKED") { exit 1 }
