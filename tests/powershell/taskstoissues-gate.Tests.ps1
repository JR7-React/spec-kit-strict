. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/analyze-receipt.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/github-repository.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/taskstoissues-rules.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/taskstoissues-receipt.ps1"

Assert-Equal "owner/repo" (
    ConvertTo-GitHubRepository "https://github.com/owner/repo.git"
) "https remote normalized"
Assert-Equal "owner/repo" (
    ConvertTo-GitHubRepository "git@github.com:owner/repo.git"
) "ssh remote normalized"
Assert-Equal $null (
    ConvertTo-GitHubRepository "https://gitlab.com/owner/repo.git"
) "non GitHub remote rejected"

$tasks = "## Phase 1: Setup`n- [ ] T001 First`n- [ ] T002 Second"
Assert-Equal 2 (Get-TaskIds $tasks).Count "task ids extracted"

$mapping = @(
    [PSCustomObject]@{
        task_id = "T001"
        issue_number = 10
        url = "https://github.com/owner/repo/issues/10"
    }
)

$temp = Join-Path ([IO.Path]::GetTempPath()) ("issues-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    Write-TasksToIssuesReceipt $temp "hash" "owner/repo" $mapping
    $receipt = Read-TasksToIssuesReceipt $temp
    Assert-True (Test-TasksToIssuesReceipt $receipt "hash" "owner/repo") (
        "current taskstoissues receipt blocks duplicate conversion"
    )
    Assert-True (-not (
        Test-TasksToIssuesReceipt $receipt "changed" "owner/repo"
    )) "stale taskstoissues receipt permits new conversion"
}
finally {
    Remove-Item $temp -Recurse -Force
}

$transition = Get-Content (
    "$PSScriptRoot/../../scripts/powershell/quality/validate-transition.ps1"
) -Raw
Assert-True ($transition -match '"TasksToIssues"') (
    "common transition gate owns before_taskstoissues"
)
$prerequisites = Get-Content (
    "$PSScriptRoot/../../scripts/powershell/quality/taskstoissues-prerequisites.ps1"
) -Raw
foreach ($forbidden in @(
    "Set-Content",
    "Add-Content",
    "New-Item",
    "gh api",
    "git add",
    "git commit"
)) {
    Assert-True ($prerequisites -notmatch [regex]::Escape($forbidden)) (
        "taskstoissues prerequisites remain read-only: $forbidden"
    )
}
