[CmdletBinding()]
param(
    [string[]]$ChangedPaths = @(),
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/quality-common.ps1"
. "$PSScriptRoot/targeted-tests.ps1"

$config = Read-QualityGateConfig
$root = Get-RepoRoot
$compose = Join-Path $root $config.backend.compose_file

& docker compose -f $compose run --build --rm --no-deps django `
    python scripts/run_backend_checks.py
if ($LASTEXITCODE -ne 0) { throw "canonical backend checks failed" }

$migrationCheck = $false
foreach ($path in $ChangedPaths) {
    if (Test-PathMatchesAny $path $config.backend.migration_patterns) {
        $migrationCheck = $true
    }
}
if ($migrationCheck) {
    & docker compose -f $compose run --rm django `
        python manage.py makemigrations --check --dry-run
    if ($LASTEXITCODE -ne 0) { throw "migration drift check failed" }
}

if (-not $SkipTests) {
    $targets = @(Get-BackendFocusedTestTargets $ChangedPaths $root "backend")
    if ($targets.Count -gt 0) {
        Write-Output "backend targeted tests: $($targets -join ', ')"
        & docker compose -f $compose run --rm django pytest -q --create-db @targets
        if ($LASTEXITCODE -ne 0) { throw "backend targeted tests failed" }
    }
    else {
        Write-Output "backend targeted tests: none"
    }
}
