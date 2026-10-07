. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/taskstoissues-rules.ps1"

function New-TestIssue {
    param(
        [int]$Number,
        [string]$TaskId,
        [string]$Feature = "001-demo",
        [string]$Url = "https://github.com/owner/repo/issues/$Number",
        [int]$MarkerCount = 1
    )
    $taskMarkers = @(
        1..$MarkerCount | ForEach-Object {
            "<!-- speckit-task-id:$TaskId -->"
        }
    ) -join "`n"
    return [PSCustomObject]@{
        number = $Number
        html_url = $Url
        body = "$taskMarkers`n<!-- speckit-feature:$Feature -->"
    }
}

$tasks = "## Phase 1: Setup`n- [ ] T001 First`n- [ ] T002 Second"
$taskIds = Get-TaskIds $tasks
$issues = @(
    New-TestIssue 10 "T001"
    New-TestIssue 11 "T002"
)
$result = Test-TaskIssueCoverage $taskIds $issues "001-demo"
Assert-Equal 0 $result.Errors.Count "complete issue mapping passes"
Assert-Equal 2 $result.Mapping.Count "mapping contains every task"

$duplicate = @($issues + (New-TestIssue 12 "T001"))
Assert-True (
    (Test-TaskIssueCoverage $taskIds $duplicate "001-demo").Errors.Count -gt 0
) "duplicate task issue blocks"

$missingUrl = @(
    New-TestIssue 10 "T001" -Url ""
    $issues[1]
)
Assert-True (
    (Test-TaskIssueCoverage $taskIds $missingUrl "001-demo").Errors.Count -gt 0
) "task issue without confirmed URL blocks"

$otherFeature = @($issues + (New-TestIssue 13 "T001" "002-other"))
Assert-Equal 0 (
    Test-TaskIssueCoverage $taskIds $otherFeature "001-demo"
).Errors.Count "other feature task markers are ignored"

$repeatedMarker = @(
    New-TestIssue 10 "T001" -MarkerCount 2
    $issues[1]
)
Assert-True (
    (Test-TaskIssueCoverage $taskIds $repeatedMarker "001-demo").Errors.Count -gt 0
) "repeated task marker in one issue blocks"
