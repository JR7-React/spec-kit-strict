# Loads the Spec Kit core helpers (common.ps1) of the project that installed
# this extension. Installed copies live in .specify/extensions/strict/, so the
# walk stops at the first ancestor that is a Spec Kit project: the project root.
# It never goes past that root, so a common.ps1 in a parent folder is never run.
# SPECKIT_CORE_DIR is only a fallback for developing and testing the extension
# outside any project.

# A project root holds the state `specify init` writes. A bare .specify folder is
# not enough: ~/.specify is Spec Kit's user auth folder, not a project.
function Test-SpecKitProjectRoot {
    param([string]$Dir)

    foreach ($marker in @("init-options.json", "integration.json")) {
        $markerPath = Join-Path $Dir ".specify/$marker"
        if (Test-Path -LiteralPath $markerPath -PathType Leaf) { return $true }
    }
    return $false
}

function Find-SpecKitProjectRoot {
    param([string]$StartDir)

    $dir = $StartDir
    while ($dir) {
        if (Test-SpecKitProjectRoot $dir) { return $dir }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Resolve-SpecKitCoreScript {
    param([string]$StartDir)

    $projectRoot = Find-SpecKitProjectRoot $StartDir
    if ($projectRoot) {
        $projectCore = Join-Path $projectRoot ".specify/scripts/powershell/common.ps1"
        if (Test-Path -LiteralPath $projectCore -PathType Leaf) { return $projectCore }
        return $null
    }
    if (-not $env:SPECKIT_CORE_DIR) { return $null }
    $devCore = Join-Path $env:SPECKIT_CORE_DIR "common.ps1"
    if (Test-Path -LiteralPath $devCore -PathType Leaf) { return $devCore }
    return $null
}

$speckitCoreScript = Resolve-SpecKitCoreScript $PSScriptRoot
if (-not $speckitCoreScript) {
    throw ("Spec Kit core not found: no .specify/scripts/powershell/common.ps1 " +
        "in the project that contains $PSScriptRoot. Initialize the project with " +
        "PowerShell scripts (specify init --script ps), or set SPECKIT_CORE_DIR " +
        "when developing the extension outside a project.")
}
. $speckitCoreScript
