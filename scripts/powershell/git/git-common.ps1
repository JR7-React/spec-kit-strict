#!/usr/bin/env pwsh
# Vendored from github/spec-kit v1.1.1, extensions/git/scripts/powershell/git-common.ps1.
# Copyright GitHub, Inc. MIT License: see THIRD_PARTY_NOTICES.md.
# Kept inside this extension so speckit.strict.branch does not depend on the
# bundled 'git' extension (its id and speckit.git.commit collide).
# Git-specific common functions for the git extension.
# Extracted from scripts/powershell/common.ps1 -- contains only git-specific
# branch validation and detection logic.

function Test-HasGit {
    param([string]$RepoRoot = (Get-Location))
    try {
        if (-not (Test-Path (Join-Path $RepoRoot '.git'))) { return $false }
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $false }
        git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Get-SpecKitEffectiveBranchName {
    param([string]$Branch)
    if ($Branch -match '^([^/]+)/([^/]+)$') {
        return $Matches[2]
    }
    return $Branch
}

function Test-FeatureBranch {
    param(
        [string]$Branch,
        [bool]$HasGit = $true
    )

    # For non-git repos, we can't enforce branch naming but still provide output
    if (-not $HasGit) {
        Write-Warning "[specify] Warning: Git repository not detected; skipped branch validation"
        return $true
    }

    $raw = $Branch
    $Branch = Get-SpecKitEffectiveBranchName $raw
    $featureSegment = ($Branch -split '/')[-1]

    # Accept sequential prefix (3+ digits), at the start or after namespace
    # segments, but exclude malformed timestamps.
    $hasMalformedTimestamp = ($featureSegment -match '^[0-9]{7}-[0-9]{6}-') -or ($featureSegment -match '^(?:\d{7}|\d{8})-\d{6}$')
    $isSequential = ($featureSegment -match '^[0-9]{3,}-') -and (-not $hasMalformedTimestamp)
    if (-not $isSequential -and $featureSegment -notmatch '^\d{8}-\d{6}-') {
        [Console]::Error.WriteLine("ERROR: Not on a feature branch. Current branch: $raw")
        [Console]::Error.WriteLine("Feature branches should be named like: 001-feature-name, 1234-feature-name, 20260319-143022-feature-name, or <prefix>/001-feature-name")
        return $false
    }
    return $true
}
