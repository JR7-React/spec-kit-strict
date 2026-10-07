[CmdletBinding()]
param(
    [ValidateSet("Auto", "Specify", "Clarify", "Plan", "Tasks", "Checklist")]
    [string]$Phase = "Auto",
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/git-artifact-common.ps1"

if (-not $RepoRoot) {
    . "$PSScriptRoot/../import-speckit-core.ps1"
    $RepoRoot = Get-RepoRoot
}
$RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
$featureConfig = Get-Content "$RepoRoot/.specify/feature.json" -Raw |
    ConvertFrom-Json
$configured = [string]$featureConfig.feature_directory
$featurePath = Resolve-FeatureArtifactPath $RepoRoot $configured
$featureDir = $featurePath.FullPath
$featureRel = $featurePath.RelativePath
$status = @(git -C $RepoRoot status --short -- `
    $featureRel ".specify/feature.json")

if ($Phase -eq "Auto") {
    if ($status -match 'tasks\.md') { $Phase = "Tasks" }
    elseif ($status -match '(plan|research|data-model|quickstart)\.md|contracts/') {
        $Phase = "Plan"
    }
    elseif ($status -match 'spec\.md') {
        $history = git -C $RepoRoot log -1 --format=%H -- "$featureRel/spec.md"
        $Phase = if ($history) { "Clarify" } else { "Specify" }
    }
    else { $Phase = "Checklist" }
}

$paths = switch ($Phase) {
    "Specify" { @("$featureRel/spec.md", "$featureRel/checklists",
        ".specify/feature.json") }
    "Clarify" { @("$featureRel/spec.md", "$featureRel/checklists") }
    "Plan" {
        $selected = @("$featureRel/plan.md", "$featureRel/research.md",
            "$featureRel/data-model.md", "$featureRel/quickstart.md",
            "$featureRel/contracts")
        foreach ($contextFile in @("CLAUDE.md", "GEMINI.md")) {
            if (Test-SafeContextChange $RepoRoot $contextFile) {
                $selected += $contextFile
            }
        }
        $selected
    }
    "Tasks" { @("$featureRel/tasks.md") }
    "Checklist" { @("$featureRel/checklists") }
}
# Spec Kit 1.x ignores .specify/feature.json; staging an ignored path makes
# `git add` / `git commit --only` fail, so ignored artifacts are skipped.
$existing = @($paths | Where-Object {
    Test-Path -LiteralPath (Join-Path $RepoRoot $_)
} | Where-Object {
    git -C $RepoRoot check-ignore -q -- $_
    $LASTEXITCODE -ne 0
})
if ($existing.Count -eq 0) { Write-Output "sin artefactos para commit"; return }
git -C $RepoRoot add -- $existing
git -C $RepoRoot diff --cached --quiet -- $existing
if ($LASTEXITCODE -eq 0) { Write-Output "sin artefactos nuevos"; return }

$name = Split-Path $featureDir -Leaf
$message = switch ($Phase) {
    "Specify" { "docs(spec): especificacion de la feature $name" }
    "Clarify" { "docs(spec): clarificaciones de la feature $name" }
    "Plan" { "docs(spec): plan tecnico de la feature $name" }
    "Tasks" { "docs(spec): tasks de la feature $name" }
    "Checklist" { "docs(spec): checklist de la feature $name" }
}
git -C $RepoRoot commit --only -m $message -- $existing
if ($LASTEXITCODE -ne 0) { throw "SpecKit artifact commit failed" }
