. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/artifact-rules.ps1"

$validSpec = @"
# Feature Specification: Demo
## User Scenarios & Testing
### User Story 1 - Demo [US1]
## Requirements
### Functional Requirements
- **FR-001**: Demo.
## Success Criteria
- **SC-001**: Demo medible.
"@
$invalidSpec = $validSpec + @"

- **FR-001**: Duplicado.
[NEEDS CLARIFICATION]
"@

Assert-Equal 0 (Test-SpecContent $validSpec).Count "valid spec passes"
$specErrors = Test-SpecContent $invalidSpec
Assert-True ($specErrors -contains "duplicate FR identifier: FR-001") (
    "duplicate FR blocks"
)
Assert-True ($specErrors -contains "unresolved marker: [NEEDS CLARIFICATION]") (
    "clarification marker blocks"
)

$validTasks = "## Phase 1: Setup`n- [ ] T001 Create file x.ps1"
$invalidTasks = $validTasks + "`n- [ ] T001 Duplicate"
Assert-Equal 0 (Test-TasksContent $validTasks).Count "valid tasks pass"
Assert-True ((Test-TasksContent $invalidTasks).Count -gt 0) (
    "duplicate task blocks"
)

$checklist = @"
- [ ] CHK001 Validar regla. [Spec §FR-001]
- [ ] CHK002 Resolver ambiguedad. [Ambiguity]
"@
Assert-Equal 0 (Test-ChecklistContent $checklist $true).Count (
    "traced checklist passes"
)
$unorderedChecklist = @"
- [ ] CHK002 Segunda regla. [Spec FR-002]
- [ ] CHK001 Primera regla. [Spec FR-001]
"@
Assert-True (
    (Test-ChecklistContent $unorderedChecklist $true) -contains
    "checklist identifiers are not strictly increasing"
) "unordered checklist blocks"
Assert-Equal 0 (Test-ChecklistContent "- [ ] requisito base" $false).Count (
    "base requirements checklist is exempt from CHK ids"
)
