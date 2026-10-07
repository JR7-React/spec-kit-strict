function Write-TasksToIssuesReceipt {
    param(
        [string]$GitDir,
        [string]$TasksHash,
        [string]$Repository,
        [object[]]$Mapping
    )
    $directory = Join-Path $GitDir "speckit"
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    [PSCustomObject]@{
        tasks_hash = $TasksHash
        repository = $Repository
        issues = @($Mapping)
        recorded_at = [DateTime]::UtcNow.ToString("o")
    } | ConvertTo-Json -Depth 5 | Set-Content (
        Join-Path $directory "taskstoissues-gate.json"
    ) -Encoding utf8
}

function Read-TasksToIssuesReceipt {
    param([string]$GitDir)
    $path = Join-Path $GitDir "speckit/taskstoissues-gate.json"
    if (-not (Test-Path $path -PathType Leaf)) { return $null }
    return Get-Content $path -Raw | ConvertFrom-Json
}

function Test-TasksToIssuesReceipt {
    param($Receipt, [string]$TasksHash, [string]$Repository)
    return $null -ne $Receipt -and
        $Receipt.tasks_hash -eq $TasksHash -and
        $Receipt.repository -eq $Repository -and
        @($Receipt.issues).Count -gt 0
}
