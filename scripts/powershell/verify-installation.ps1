# Verifies that this project still runs the strict extension as released:
# hooks registered and mandatory, extension enabled at the installed version,
# installed files untouched, and CI running the shared gates. Read-only; meant
# for the project's CI. Run from anywhere inside the project.
$ErrorActionPreference = "Stop"
. "$PSScriptRoot/quality/quality-common.ps1"
. "$PSScriptRoot/installation/hook-registration.ps1"
. "$PSScriptRoot/installation/install-checksums.ps1"
. "$PSScriptRoot/installation/project-contract.ps1"

$repoRoot = Get-RepoRoot
$extensionDir = (Resolve-Path "$PSScriptRoot/../..").Path
$manifest = Join-Path $extensionDir "extension.yml"
$extensionsYml = Join-Path $repoRoot ".specify/extensions.yml"

$entries = @()
if (Test-Path -LiteralPath $extensionsYml -PathType Leaf) {
    $entries = @(Read-ProjectHookEntries (Get-Content -LiteralPath $extensionsYml -Raw))
}

$errors = [System.Collections.Generic.List[string]]::new()
$findings = @(
    Test-StrictHookRegistration @(Read-ExtensionHookPlan $manifest) $entries
    Test-StrictRegistry $repoRoot (Read-ExtensionVersion $manifest)
    Test-InstallChecksums $extensionDir
    Test-CiGateContract $repoRoot (Read-QualityGateConfig)
)
foreach ($finding in $findings) {
    if ($finding) { $errors.Add($finding) }
}

$status = if ($errors.Count -eq 0) { "PASS" } else { "BLOCKED" }
Write-GateResult "Installation" $status @("hooks", "registry", "checksums", "ci") $errors
if ($status -ne "PASS") { exit 1 }
exit 0
