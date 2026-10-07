. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/speckit-test-project.ps1"

$extensionRoot = (Resolve-Path "$PSScriptRoot/../..").Path
$expected = @(
    "before_specify|speckit.strict.branch",
    "after_specify|speckit.strict.artifacts", "after_specify|speckit.strict.commit",
    "before_clarify|speckit.strict.before-clarify",
    "after_clarify|speckit.strict.artifacts", "after_clarify|speckit.strict.commit",
    "before_plan|speckit.strict.before-plan",
    "after_plan|speckit.strict.artifacts", "after_plan|speckit.strict.commit",
    "before_tasks|speckit.strict.before-tasks",
    "after_tasks|speckit.strict.artifacts", "after_tasks|speckit.strict.commit",
    "before_checklist|speckit.strict.before-checklist",
    "after_checklist|speckit.strict.artifacts", "after_checklist|speckit.strict.commit",
    "before_analyze|speckit.strict.before-analyze",
    "after_analyze|speckit.strict.after-analyze",
    "before_taskstoissues|speckit.strict.before-taskstoissues",
    "after_taskstoissues|speckit.strict.after-taskstoissues",
    "before_implement|speckit.strict.readiness",
    "after_implement|speckit.strict.implementation-gate",
    "after_implement|speckit.strict.finalize-tasks"
)

function Get-RegisteredHooks {
    param([string]$ExtensionsYml)
    $hooks = [System.Collections.Generic.List[string]]::new()
    $phase = $null
    foreach ($line in (Get-Content -LiteralPath $ExtensionsYml)) {
        if ($line -match '^  ([a-z_]+):\s*$') { $phase = $Matches[1]; continue }
        if ($line -match '^\s+command: (\S+)') { $hooks.Add("$phase|$($Matches[1].Trim('"'))") }
    }
    return $hooks
}

function Install-Extension {
    param([string]$Project, [switch]$Force)
    Push-Location $Project
    try {
        $arguments = @("extension", "add", $extensionRoot, "--dev")
        if ($Force) { $arguments += "--force" }
        specify @arguments | Out-Null
        return $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}

$project = New-SpecKitTestProject "strict-install"
$savedCoreDir = $env:SPECKIT_CORE_DIR
try {
    Assert-Equal 0 (Install-Extension $project) "specify extension add --dev succeeds"
    $installed = Join-Path $project ".specify/extensions/strict"
    Assert-True (Test-Path "$installed/extension.yml") "extension copied"
    Assert-True (-not (Test-Path "$installed/tests")) "tests are not installed"
    Assert-True (-not (Test-Path "$installed/.git")) (
        "the extension repo git metadata is not installed"
    )
    Assert-True (Test-Path "$installed/strict-config.yml") (
        "strict-config.yml scaffolded from the template"
    )
    $skills = @(Get-ChildItem "$project/.claude/skills" -Directory -Filter "speckit-strict-*")
    Assert-Equal 14 $skills.Count "14 strict skills registered for Claude"
    $registered = Get-RegisteredHooks "$project/.specify/extensions.yml"
    Assert-Equal ($expected -join ";") ($registered -join ";") (
        "22 hooks registered in the exact order"
    )

    # Review Focus 1: an installed gate loads the project core and fails for a
    # business reason (no active feature), never for a missing core.
    $env:SPECKIT_CORE_DIR = $null
    Push-Location $project
    $gateOutput = pwsh -NoProfile -File "$installed/scripts/powershell/quality/validate-artifacts.ps1" 2>&1
    $gateExit = $LASTEXITCODE
    Pop-Location
    Assert-True ("$gateOutput" -notmatch "Spec Kit core not found") (
        "installed gate finds the project core"
    )
    Assert-True ($gateExit -ne 0) "installed gate blocks without an active feature"
    Assert-True ("$gateOutput" -match "Feature directory not found") (
        "installed gate fails for the business reason, not another error"
    )

    # verify-installation: green for an intact project, blocked when hooks or
    # installed files drift.
    $workflowDir = Join-Path $project ".github/workflows"
    New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
    @(
        "steps:",
        "  - run: pwsh .specify/extensions/strict/scripts/powershell/quality/invoke-frontend-gate.ps1 -SkipTests",
        "  - run: pwsh .specify/extensions/strict/scripts/powershell/quality/invoke-backend-gate.ps1 -SkipTests"
    ) | Set-Content (Join-Path $workflowDir "quality.yml")
    $verify = "$installed/scripts/powershell/verify-installation.ps1"
    function Invoke-Verify {
        Push-Location $project
        $output = pwsh -NoProfile -File $verify 2>&1
        $code = $LASTEXITCODE
        Pop-Location
        return [PSCustomObject]@{ Code = $code; Output = "$output" }
    }
    $result = Invoke-Verify
    Assert-Equal 0 $result.Code "verify-installation passes on an intact project"
    Assert-True ($result.Output -match "SPECKIT_GATE=PASS") "verify-installation reports PASS"

    $extensionsYml = Join-Path $project ".specify/extensions.yml"
    $registered = Get-Content -LiteralPath $extensionsYml -Raw
    $registered.Replace("optional: false", "optional: true") | Set-Content $extensionsYml
    $result = Invoke-Verify
    Assert-True ($result.Code -ne 0 -and $result.Output -match "optional") (
        "verify-installation blocks optional strict hooks"
    )
    $registered | Set-Content $extensionsYml

    $readiness = "$installed/scripts/powershell/quality/validate-readiness.ps1"
    $original = Get-Content -LiteralPath $readiness -Raw
    Add-Content -LiteralPath $readiness -Value "# local edit"
    $result = Invoke-Verify
    Assert-True ($result.Code -ne 0 -and $result.Output -match "was edited") (
        "verify-installation blocks edited installed scripts"
    )
    [IO.File]::WriteAllText($readiness, $original)

    # Review Focus 4: updating with --force keeps the project's config.
    $configPath = "$installed/strict-config.yml"
    (Get-Content $configPath -Raw).Replace('"root": "frontend"', '"root": "web"') |
        Set-Content $configPath
    Assert-Equal 0 (Install-Extension $project -Force) "reinstall with --force succeeds"
    Assert-True ((Get-Content $configPath -Raw) -match '"root": "web"') (
        "project config survives an update"
    )
}
finally {
    $env:SPECKIT_CORE_DIR = $savedCoreDir
    Remove-Item -LiteralPath $project -Recurse -Force -ErrorAction SilentlyContinue
}
