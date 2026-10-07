. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/installation/project-contract.ps1"

$root = (Resolve-Path "$PSScriptRoot/../..").Path
$version = Read-ExtensionVersion (Join-Path $root "extension.yml")
Assert-True ($version -match '^\d+\.\d+\.\d+$') "extension.yml declares a semantic version"

$project = Join-Path ([IO.Path]::GetTempPath()) ("contract-" + [guid]::NewGuid())
$registryPath = Join-Path $project ".specify/extensions/.registry"
$workflows = Join-Path $project ".github/workflows"

function Set-Registry {
    param([object]$Strict)
    $extensions = @{ bug = @{ version = "1.0.0"; enabled = $true } }
    if ($null -ne $Strict) { $extensions.strict = $Strict }
    @{ schema_version = "1.0"; extensions = $extensions } | ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath $registryPath
}

try {
    New-Item -ItemType Directory -Path (Split-Path -Parent $registryPath), $workflows -Force |
        Out-Null

    Set-Registry @{ version = "9.9.9"; enabled = $true }
    Assert-Equal 0 @(Test-StrictRegistry $project "9.9.9").Count "enabled strict passes"
    Assert-True ("$(Test-StrictRegistry $project '1.0.0')" -match "version") (
        "a version different from the installed manifest is reported"
    )
    Set-Registry @{ version = "9.9.9"; enabled = $false }
    Assert-True ("$(Test-StrictRegistry $project '9.9.9')" -match "disabled") (
        "a disabled extension is reported"
    )
    Set-Registry $null
    Assert-True ("$(Test-StrictRegistry $project '9.9.9')" -match "not registered") (
        "a missing registry entry is reported"
    )

    $both = '{"frontend": {"root": "web"}, "backend": {"root": "api"}}' | ConvertFrom-Json
    $frontendOnly = '{"frontend": {"root": "web"}}' | ConvertFrom-Json
    Assert-True ("$(Test-CiGateContract $project $both)" -match "invoke-frontend-gate") (
        "missing CI gates are reported"
    )
    "steps: [run: pwsh .specify/extensions/strict/scripts/powershell/quality/invoke-frontend-gate.ps1 -SkipTests]" |
        Set-Content (Join-Path $workflows "frontend.yml")
    Assert-Equal 0 @(Test-CiGateContract $project $frontendOnly).Count (
        "a project without backend only needs the frontend gate"
    )
    Assert-True ("$(Test-CiGateContract $project $both)" -match "invoke-backend-gate") (
        "a declared backend needs its CI gate"
    )
    "steps: [run: pwsh .specify/extensions/strict/scripts/powershell/quality/invoke-backend-gate.ps1 -SkipTests]" |
        Set-Content (Join-Path $workflows "backend.yaml")
    Assert-Equal 0 @(Test-CiGateContract $project $both).Count "both CI gates pass"
}
finally {
    Remove-Item -LiteralPath $project -Recurse -Force -ErrorAction SilentlyContinue
}
