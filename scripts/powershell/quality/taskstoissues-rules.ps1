function Get-TaskIds {
    param([string]$TasksContent)
    return @([regex]::Matches(
        $TasksContent,
        '(?m)^- \[[ xX]\] (T\d{3})\b'
    ) | ForEach-Object { $_.Groups[1].Value })
}

function Get-IssueTaskIds {
    param([string]$Body)
    if ($null -eq $Body) { return @() }
    return @([regex]::Matches(
        $Body,
        '<!--\s*speckit-task-id:(T\d{3})\s*-->'
    ) | ForEach-Object { $_.Groups[1].Value })
}

function Get-IssueFeatureNames {
    param([string]$Body)
    if ($null -eq $Body) { return @() }
    return @([regex]::Matches(
        $Body,
        '<!--\s*speckit-feature:([A-Za-z0-9][A-Za-z0-9._-]*)\s*-->'
    ) | ForEach-Object { $_.Groups[1].Value })
}

function Test-TaskIssueCoverage {
    param(
        [string[]]$TaskIds,
        [object[]]$Issues,
        [string]$FeatureName
    )
    $errors = [System.Collections.Generic.List[string]]::new()
    $mapping = [System.Collections.Generic.List[object]]::new()
    $byTask = @{}
    foreach ($issue in $Issues) {
        $features = @(Get-IssueFeatureNames ([string]$issue.body))
        if ($features.Count -ne 1 -or $features[0] -ne $FeatureName) {
            continue
        }
        $ids = @(Get-IssueTaskIds ([string]$issue.body))
        if ($ids.Count -gt 1) {
            $errors.Add("issue #$($issue.number) maps multiple tasks")
        }
        foreach ($id in $ids) {
            if (-not $byTask.ContainsKey($id)) { $byTask[$id] = @() }
            $byTask[$id] += $issue
        }
    }
    foreach ($id in $TaskIds) {
        $matches = @($byTask[$id])
        if ($matches.Count -eq 0) { $errors.Add("missing issue for $id") }
        elseif ($matches.Count -gt 1) { $errors.Add("duplicate issues for $id") }
        elseif ([string]::IsNullOrWhiteSpace(
            [string]$matches[0].html_url
        )) {
            $errors.Add("issue for $id has no confirmed URL")
        }
        else {
            $mapping.Add([PSCustomObject]@{
                task_id = $id
                issue_number = [int]$matches[0].number
                url = [string]$matches[0].html_url
            })
        }
    }
    return [PSCustomObject]@{
        Errors = $errors
        Mapping = $mapping
    }
}
