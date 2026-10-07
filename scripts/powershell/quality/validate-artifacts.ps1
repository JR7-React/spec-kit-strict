[CmdletBinding()]
param(
    [ValidateSet("Auto", "Specify", "Plan", "Tasks", "Checklist")]
    [string]$Phase = "Auto"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/quality-common.ps1"
. "$PSScriptRoot/artifact-rules.ps1"

$context = Get-QualityFeatureContext
$featurePath = Get-RepoRelativePath $context.RepoRoot $context.FeatureDir
$changed = @(git -C $context.RepoRoot status --short -- $featurePath)
if ($Phase -eq "Auto") {
    if ($changed -match 'tasks\.md') { $Phase = "Tasks" }
    elseif ($changed -match '(plan|research|data-model|quickstart)\.md|contracts/') {
        $Phase = "Plan"
    }
    elseif ($changed -match 'checklists/' -and $changed -notmatch 'spec\.md') {
        $Phase = "Checklist"
    }
    elseif (Test-Path -LiteralPath $context.Tasks -PathType Leaf) {
        $Phase = "Tasks"
    }
    elseif (Test-Path -LiteralPath $context.Plan -PathType Leaf) {
        $Phase = "Plan"
    }
    else { $Phase = "Specify" }
}

$errors = [System.Collections.Generic.List[string]]::new()
$checks = [System.Collections.Generic.List[string]]::new()
if (-not (Test-Path -LiteralPath $context.Spec -PathType Leaf)) {
    $errors.Add("missing spec.md")
}
else {
    $checks.Add("spec")
    foreach ($message in Test-SpecContent (Get-Content $context.Spec -Raw)) {
        $errors.Add("spec.md: $message")
    }
}

if ($Phase -in @("Plan", "Tasks")) {
    if (-not (Test-Path -LiteralPath $context.Plan -PathType Leaf)) {
        $errors.Add("missing plan.md")
    }
    else {
        $plan = Get-Content $context.Plan -Raw
        $checks.Add("plan")
        foreach ($heading in @("Technical Context", "Constitution Check", "Project Structure")) {
            if ($plan -notmatch "(?m)^## ${heading}") {
                $errors.Add("plan.md: missing section $heading")
            }
        }
        if ($plan -match '(?im)(?:\|\s*FAIL\s*\||gate status.*FAIL)') {
            $errors.Add("plan.md: unresolved constitution or design failure")
        }
        foreach ($artifact in @("research.md", "data-model.md", "quickstart.md")) {
            if ($plan -match [regex]::Escape($artifact)) {
                if (-not (Test-Path (Join-Path $context.FeatureDir $artifact))) {
                    $errors.Add("plan.md declares missing $artifact")
                }
            }
        }
    }
}

if ($Phase -eq "Tasks") {
    if (-not (Test-Path -LiteralPath $context.Tasks -PathType Leaf)) {
        $errors.Add("missing tasks.md")
    }
    else {
        $checks.Add("tasks")
        foreach ($message in Test-TasksContent (Get-Content $context.Tasks -Raw)) {
            $errors.Add("tasks.md: $message")
        }
    }
}

$files = @(Get-ChildItem $context.Checklists -Filter "*.md" -ErrorAction SilentlyContinue)
if ($files.Count -eq 0) { $errors.Add("missing checklist markdown") }
foreach ($file in $files) {
    $checks.Add("checklist:$($file.Name)")
    $requireIds = $file.Name -ne "requirements.md"
    foreach ($message in Test-ChecklistContent (Get-Content $file.FullName -Raw) $requireIds) {
        $errors.Add("$($file.Name): $message")
    }
}

$status = if ($errors.Count -eq 0) { "PASS" } else { "BLOCKED" }
Write-GateResult $Phase $status $checks $errors
if ($status -eq "BLOCKED") { exit 1 }
