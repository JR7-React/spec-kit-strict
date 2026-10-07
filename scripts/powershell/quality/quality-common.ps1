. "$PSScriptRoot/../import-speckit-core.ps1"

function Read-QualityGateConfig {
    $root = Get-RepoRoot
    $path = Join-Path $root ".specify/extensions/strict/strict-config.yml"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw ("Missing strict config: $path. Copy " +
            ".specify/extensions/strict/config-template.yml to strict-config.yml " +
            "and set this project's frontend and backend roots.")
    }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

# Spec Kit 1.x removed this helper from common.ps1; the strict gates still
# compare "<user>/<feature>" branches by their last segment.
if (-not (Get-Command Get-SpecKitEffectiveBranchName -ErrorAction SilentlyContinue)) {
    function Get-SpecKitEffectiveBranchName {
        param([string]$Branch)
        if ($Branch -match '^([^/]+)/([^/]+)$') {
            return $Matches[2]
        }
        return $Branch
    }
}

# Spec Kit 1.x reports CURRENT_BRANCH from SPECIFY_FEATURE or the feature
# directory name, which would make the branch-match gates tautological.
# Gates compare against the real git branch, as Spec Kit 0.9 did.
function Get-QualityCurrentBranch {
    param(
        [string]$RepoRoot,
        [string]$Fallback
    )
    if ($env:SPECIFY_FEATURE) { return $env:SPECIFY_FEATURE }
    $branch = git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $branch) { return "$branch".Trim() }
    return $Fallback
}

function Get-QualityFeatureContext {
    $paths = Get-FeaturePathsEnv
    $featureRoot = [System.IO.Path]::GetFullPath($paths.FEATURE_DIR)
    $repoRoot = [System.IO.Path]::GetFullPath($paths.REPO_ROOT)
    $comparison = if ($IsWindows -or $null -eq $IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }
    $prefix = $repoRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $featureRoot.StartsWith($prefix, $comparison)) {
        throw "Feature directory escapes repository root: $featureRoot"
    }
    return [PSCustomObject]@{
        RepoRoot = $repoRoot
        Branch = Get-QualityCurrentBranch $repoRoot $paths.CURRENT_BRANCH
        FeatureDir = $featureRoot
        Spec = $paths.FEATURE_SPEC
        Plan = $paths.IMPL_PLAN
        Tasks = $paths.TASKS
        Checklists = Join-Path $featureRoot "checklists"
    }
}

function Write-GateResult {
    param(
        [string]$Phase,
        [string]$Status,
        [string[]]$Checks,
        [string[]]$Errors
    )

    Write-Output "SPECKIT_GATE=$Status"
    Write-Output "PHASE=$Phase"
    Write-Output "CHECKS=$($Checks -join ',')"
    Write-Output "ERRORS=$($Errors.Count)"
    foreach ($errorMessage in $Errors) {
        [Console]::Error.WriteLine("ERROR: $errorMessage")
    }
}

function Get-RepoRelativePath {
    param([string]$RepoRoot, [string]$Path)

    $relative = [System.IO.Path]::GetRelativePath($RepoRoot, $Path)
    return $relative.Replace('\', '/')
}

function Get-SpecKitGitDir {
    param([string]$RepoRoot = (Get-RepoRoot))

    $gitDir = (git -C $RepoRoot rev-parse --git-dir).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $gitDir) {
        throw "Unable to resolve git directory"
    }
    if (-not [System.IO.Path]::IsPathRooted($gitDir)) {
        $gitDir = Join-Path $RepoRoot $gitDir
    }
    return [System.IO.Path]::GetFullPath($gitDir)
}
