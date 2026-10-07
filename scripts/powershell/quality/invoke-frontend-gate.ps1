[CmdletBinding()]
param(
    [string[]]$ChangedPaths = @(),
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/quality-common.ps1"
. "$PSScriptRoot/targeted-tests.ps1"

$config = Read-QualityGateConfig
$frontendRoot = Join-Path (Get-RepoRoot) $config.frontend.root

Push-Location $frontendRoot
try {
    foreach ($name in @("lint", "typecheck", "build")) {
        $command = @($config.frontend.commands.$name)
        $executable = $command[0]
        $arguments = @($command | Select-Object -Skip 1)
        & $executable @arguments
        if ($LASTEXITCODE -ne 0) { throw "frontend $name failed" }
    }

    if (-not $SkipTests) {
        $targets = @(Get-FrontendFocusedTestTargets $ChangedPaths `
            (Get-RepoRoot) $config.frontend.root)
        if ($targets.Count -gt 0) {
            Write-Output "frontend targeted tests: $($targets -join ', ')"
            & pnpm exec vitest run @targets
            if ($LASTEXITCODE -ne 0) {
                throw "frontend targeted tests failed"
            }
        }
        else {
            Write-Output "frontend targeted tests: none"
        }
    }
}
finally {
    Pop-Location
}
