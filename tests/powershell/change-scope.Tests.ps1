. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/targeted-tests.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/line-policy.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/change-scope.ps1"

$config = Get-Content "$PSScriptRoot/../../config-template.yml" -Raw |
    ConvertFrom-Json
$files = @(
    [PSCustomObject]@{
        Status = "M"
        Path = "frontend/src/features/forms/a.ts"
    },
    [PSCustomObject]@{
        Status = "A"
        Path = "backend/apps/forms/service.py"
    }
)
$frontendTargets = Get-TestTargets $files $config.frontend.test_rules
$backendTargets = Get-TestTargets $files $config.backend.test_rules
Assert-True ($frontendTargets -contains "src/features/forms") (
    "frontend domain selected"
)
Assert-True ($backendTargets -contains "apps/forms/tests") (
    "backend app selected"
)

$renamed = @(Convert-NameStatus @("R100`told.ps1`tnew.ps1"))
Assert-Equal "M" $renamed[0].Status "rename becomes modified"
Assert-Equal "new.ps1" $renamed[0].Path "rename keeps destination path"

$temp = Join-Path ([System.IO.Path]::GetTempPath()) (
    "speckit-" + [guid]::NewGuid() + ".ps1"
)
try {
    1..101 | ForEach-Object { "line $_" } | Set-Content $temp
    $source = @([PSCustomObject]@{
        Status = "A"
        Path = $temp
    })
    $violations = Test-LinePolicy $source 100 199 @(".ps1")
    Assert-Equal 1 $violations.Count "new 101-line source is blocked"
}
finally {
    Remove-Item -LiteralPath $temp -Force
}
