# Rules for the project around the installed extension: Spec Kit's registry
# must keep strict enabled at the installed version, and the project's CI must
# run the shared gates for every root declared in strict-config.yml.

function Read-ExtensionVersion {
    param([string]$ManifestPath)

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw
    if ($manifest -match '(?m)^  version: "([^"]+)"') { return $Matches[1] }
    throw "No extension version in $ManifestPath"
}

function Test-StrictRegistry {
    param([string]$RepoRoot, [string]$ExpectedVersion)

    $registryPath = Join-Path $RepoRoot ".specify/extensions/.registry"
    if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
        return @("Spec Kit extension registry not found: $registryPath")
    }
    $strict = (Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json).extensions.strict
    if ($null -eq $strict) { return @("strict is not registered in .specify/extensions/.registry") }

    $errors = [System.Collections.Generic.List[string]]::new()
    if ($strict.enabled -ne $true) { $errors.Add("strict is disabled in the extension registry") }
    if ($strict.version -ne $ExpectedVersion) {
        $errors.Add("registry version $($strict.version) does not match installed version $ExpectedVersion")
    }
    return $errors
}

function Get-WorkflowText {
    param([string]$RepoRoot)

    $workflowDir = Join-Path $RepoRoot ".github/workflows"
    if (-not (Test-Path -LiteralPath $workflowDir -PathType Container)) { return "" }
    $files = Get-ChildItem -LiteralPath $workflowDir -File |
        Where-Object { $_.Extension -in @(".yml", ".yaml") }
    return ($files | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
}

function Test-CiGateContract {
    param([string]$RepoRoot, [object]$Config)

    $workflows = Get-WorkflowText $RepoRoot
    $requiredGates = @()
    if ($Config.frontend) { $requiredGates += "invoke-frontend-gate.ps1" }
    if ($Config.backend) { $requiredGates += "invoke-backend-gate.ps1" }

    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($gate in $requiredGates) {
        if (-not $workflows.Contains($gate)) {
            $errors.Add("no workflow in .github/workflows runs $gate")
        }
    }
    return $errors
}
