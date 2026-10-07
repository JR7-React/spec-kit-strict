. "$PSScriptRoot/identifier-rules.ps1"

function Get-UnresolvedMarkers {
    param([string]$Content)

    $pattern = @(
        '\[NEEDS CLARIFICATION\]',
        '\[(?:FEATURE(?: NAME)?|DATE|###-[^\]]+|INSERT[^\]]*|TODO[^\]]*)\]',
        '\bTBD\b',
        '\bTKTK\b',
        '\?\?\?'
    ) -join '|'
    return [regex]::Matches($Content, $pattern) |
        ForEach-Object Value | Sort-Object -Unique
}

function Test-SpecContent {
    param(
        [string]$Content,
        [switch]$AllowUnresolvedMarkers
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($heading in @("User Scenarios", "Requirements", "Success Criteria")) {
        if ($Content -notmatch "(?m)^## .*${heading}") {
            $errors.Add("missing section: $heading")
        }
    }
    foreach ($id in Get-DuplicateIds $Content '\*\*(FR-\d+)\*\*') {
        $errors.Add("duplicate FR identifier: $id")
    }
    foreach ($id in Get-DuplicateIds $Content '\*\*(SC-\d+)\*\*') {
        $errors.Add("duplicate SC identifier: $id")
    }
    if (-not $AllowUnresolvedMarkers) {
        foreach ($marker in Get-UnresolvedMarkers $Content) {
            $errors.Add("unresolved marker: $marker")
        }
    }
    return $errors
}

function Test-TasksContent {
    param([string]$Content)

    $errors = [System.Collections.Generic.List[string]]::new()
    $pattern = '(?m)^- \[[ xX]\] T(\d{3})\b'
    if ($Content -notmatch '(?m)^## Phase \d+:') {
        $errors.Add("tasks have no phases")
    }
    if ($Content -notmatch $pattern) {
        $errors.Add("tasks have no T### items")
    }
    foreach ($id in Get-DuplicateIds $Content '(?m)^- \[[ xX]\] (T\d{3})\b') {
        $errors.Add("duplicate task identifier: $id")
    }
    foreach ($message in Test-StrictlyIncreasingIds $Content $pattern `
        "task identifiers are not strictly increasing") {
        $errors.Add($message)
    }
    return $errors
}

function Test-ChecklistContent {
    param([string]$Content, [bool]$RequireIds = $true)

    $errors = [System.Collections.Generic.List[string]]::new()
    if (-not $RequireIds) { return $errors }
    $pattern = '(?m)^- \[[ xX]\] CHK(\d{3})\b'
    if ($Content -notmatch $pattern) {
        $errors.Add("custom checklist has no CHK### items")
        return $errors
    }
    foreach ($id in Get-DuplicateIds $Content '(?m)^- \[[ xX]\] (CHK\d{3})\b') {
        $errors.Add("duplicate checklist identifier: $id")
    }
    foreach ($message in Test-StrictlyIncreasingIds $Content $pattern `
        "checklist identifiers are not strictly increasing") {
        $errors.Add($message)
    }
    $items = @([regex]::Matches($Content, '(?m)^- \[[ xX]\] CHK\d{3}.+$'))
    $traced = @($items | Where-Object {
        $_.Value -match '\[(?:Spec\s+[^]]+|Gap|Ambiguity|Conflict|Assumption)'
    })
    if ($items.Count -gt 0 -and ($traced.Count / $items.Count) -lt 0.8) {
        $errors.Add("checklist traceability below 80 percent")
    }
    return $errors
}
