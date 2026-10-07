[CmdletBinding()]
param(
    [string]$GitDir,
    [string]$ArtifactHash,
    [Parameter(Mandatory)]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Critical,
    [Parameter(Mandatory)]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$High,
    [Parameter(Mandatory)]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Medium,
    [Parameter(Mandatory)]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Low
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/quality-common.ps1"
. "$PSScriptRoot/analyze-receipt.ps1"

if (-not $GitDir -or -not $ArtifactHash) {
    $context = Get-QualityFeatureContext
    $constitution = Join-Path $context.RepoRoot (
        ".specify/memory/constitution.md"
    )
    $ArtifactHash = Get-SpecArtifactHash @(
        $context.Spec,
        $context.Plan,
        $context.Tasks,
        $constitution
    )
    $GitDir = Get-SpecKitGitDir $context.RepoRoot
}

Write-AnalyzeReceipt $GitDir $ArtifactHash `
    $Critical $High $Medium $Low
$errors = [System.Collections.Generic.List[string]]::new()
if ($Critical -gt 0) { $errors.Add("$Critical CRITICAL findings") }
if ($High -gt 0) { $errors.Add("$High HIGH findings") }
$status = if ($errors.Count) { "BLOCKED" } else { "PASS" }
Write-GateResult "AfterAnalyze" $status `
    @("report-counts", "analysis-receipt") $errors
if ($status -eq "BLOCKED") { exit 1 }
