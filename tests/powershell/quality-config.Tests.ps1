. "$PSScriptRoot/test-support.ps1"

$configPath = Join-Path $PSScriptRoot "../../config-template.yml"
Assert-True (Test-Path -LiteralPath $configPath) "config-template.yml exists"

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
Assert-Equal 1 $config.schema_version "schema version"
Assert-Equal "main" $config.base_branch "base branch"
Assert-Equal 100 $config.line_limits.new "new-file limit"
Assert-Equal 199 $config.line_limits.modified "modified-file limit"
Assert-Equal "frontend" $config.frontend.root "generic frontend root"
Assert-Equal "backend" $config.backend.root "generic backend root"
Assert-True ($config.frontend.test_rules.Count -ge 3) (
    "frontend test rules exist"
)
Assert-True ($config.backend.test_rules.Count -ge 1) (
    "backend test rules exist"
)
