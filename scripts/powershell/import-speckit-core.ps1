# Loads the Spec Kit core helpers (common.ps1) of the project that installed
# this extension. Installed copies live in .specify/extensions/strict/, so the
# core is found by walking up to the project root. SPECKIT_CORE_DIR is only a
# fallback for developing and testing the extension outside a project.

function Find-SpecKitCoreScript {
    param([string]$StartDir)

    $dir = $StartDir
    while ($dir) {
        $candidate = Join-Path $dir ".specify/scripts/powershell/common.ps1"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Resolve-SpecKitCoreScript {
    param([string]$StartDir)

    $projectCore = Find-SpecKitCoreScript $StartDir
    if ($projectCore) { return $projectCore }
    if (-not $env:SPECKIT_CORE_DIR) { return $null }
    $devCore = Join-Path $env:SPECKIT_CORE_DIR "common.ps1"
    if (Test-Path -LiteralPath $devCore -PathType Leaf) { return $devCore }
    return $null
}

$speckitCoreScript = Resolve-SpecKitCoreScript $PSScriptRoot
if (-not $speckitCoreScript) {
    throw ("Spec Kit core not found: no .specify/scripts/powershell/common.ps1 " +
        "above $PSScriptRoot. Install the extension in a Spec Kit project or set " +
        "SPECKIT_CORE_DIR for extension development.")
}
. $speckitCoreScript
