. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/artifact-rules.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/transition-rules.ps1"

$specWithMarker = @"
# Feature Specification: Demo
## User Scenarios & Testing
### User Story 1 - Demo
## Requirements
### Functional Requirements
- **FR-001**: [NEEDS CLARIFICATION] Definir alcance.
## Success Criteria
- **SC-001**: Resultado medible.
"@
$strictErrors = Test-SpecContent $specWithMarker
$structuralErrors = Test-SpecContent $specWithMarker -AllowUnresolvedMarkers
Assert-True ($strictErrors.Count -gt 0) "strict spec blocks marker"
Assert-Equal 0 $structuralErrors.Count "structural spec permits marker"

$completeChecklist = "- [x] Requisito definido"
$incompleteChecklist = "- [ ] Requisito pendiente"
Assert-Equal 0 (Get-IncompleteChecklistItems $completeChecklist).Count (
    "complete checklist passes"
)
Assert-Equal 1 (Get-IncompleteChecklistItems $incompleteChecklist).Count (
    "incomplete checklist is detected"
)

$validPlan = @"
## Technical Context
## Constitution Check
## Project Structure
Research output: research.md
"@
$temp = Join-Path ([IO.Path]::GetTempPath()) ("transition-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $missing = Test-PlanContent -Content $validPlan -FeatureDir $temp
    Assert-True ($missing -contains "plan declares missing research.md") (
        "declared artifact is required"
    )
    Set-Content (Join-Path $temp "research.md") "# Research"
    Assert-Equal 0 (Test-PlanContent $validPlan $temp).Count (
        "existing declared artifact passes"
    )
}
finally {
    Remove-Item $temp -Recurse -Force
}

$entrypoint = Get-Content (
    "$PSScriptRoot/../../scripts/powershell/quality/validate-transition.ps1"
) -Raw
foreach ($forbidden in @(
    "Set-Content",
    "Add-Content",
    "New-Item",
    "git add",
    "git commit",
    "Write-AnalyzeReceipt"
)) {
    Assert-True ($entrypoint -notmatch [regex]::Escape($forbidden)) (
        "before transition remains read-only: $forbidden"
    )
}
