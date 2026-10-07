. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/targeted-tests.ps1"

$config = Get-Content "$PSScriptRoot/../../config-template.yml" -Raw |
    ConvertFrom-Json
$frontendOnly = @([PSCustomObject]@{
    Status = "M"
    Path = "frontend/src/features/forms/editor.tsx"
})
$backendOnly = @([PSCustomObject]@{
    Status = "M"
    Path = "backend/apps/forms/services/demo.py"
})

Assert-Equal 1 (
    Get-TestTargets $frontendOnly $config.frontend.test_rules
).Count "one frontend target"
Assert-Equal 0 (
    Get-TestTargets $frontendOnly $config.backend.test_rules
).Count "no backend target"
Assert-Equal 1 (
    Get-TestTargets $backendOnly $config.backend.test_rules
).Count "one backend target"

$entrypoint = Join-Path $PSScriptRoot (
    "../../scripts/powershell/quality/invoke-implementation-gate.ps1"
)
Assert-True (Test-Path -LiteralPath $entrypoint -PathType Leaf) (
    "implementation gate entrypoint exists"
)
