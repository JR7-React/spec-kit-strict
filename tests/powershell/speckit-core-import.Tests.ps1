. "$PSScriptRoot/test-support.ps1"

$importer = (Resolve-Path "$PSScriptRoot/../../scripts/powershell/import-speckit-core.ps1").Path
# The space in the sandbox name pins paths like "C:\Users\Juan Perez\...".
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("core import-" + [guid]::NewGuid())
$savedCoreDir = $env:SPECKIT_CORE_DIR

function New-FakeCore {
    param([string]$Dir, [string]$Marker)
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    "function Get-ProbeMarker { '$Marker' }" |
        Set-Content -LiteralPath (Join-Path $Dir "common.ps1")
}

function Copy-Importer {
    param([string]$Dir)
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    Copy-Item -LiteralPath $importer -Destination $Dir
    return Join-Path $Dir "import-speckit-core.ps1"
}

function Invoke-Importer {
    param([string]$Path, [string]$CoreDir)
    $env:SPECKIT_CORE_DIR = $CoreDir
    $output = pwsh -NoProfile -Command ". '$Path'; Get-ProbeMarker" 2>&1
    return [PSCustomObject]@{ Code = $LASTEXITCODE; Output = "$output" }
}

try {
    $project = Join-Path $sandbox "project"
    New-FakeCore (Join-Path $project ".specify/scripts/powershell") "project-core"
    $installed = Copy-Importer (
        Join-Path $project ".specify/extensions/strict/scripts/powershell"
    )
    $devCore = Join-Path $sandbox "devcore"
    New-FakeCore $devCore "env-core"
    $lonely = Copy-Importer (Join-Path $sandbox "lonely/scripts/powershell")

    $result = Invoke-Importer $installed $null
    Assert-Equal 0 $result.Code "installed copy loads"
    Assert-Equal "project-core" $result.Output "installed copy finds the project core"

    $result = Invoke-Importer $installed $devCore
    Assert-Equal "project-core" $result.Output "project core wins over SPECKIT_CORE_DIR"

    $result = Invoke-Importer $lonely $devCore
    Assert-Equal "env-core" $result.Output "SPECKIT_CORE_DIR is the dev fallback"

    $result = Invoke-Importer $lonely $null
    Assert-True ($result.Code -ne 0) "missing core fails"
    Assert-True ($result.Output -match "Spec Kit core not found") (
        "missing core explains the failure"
    )
}
finally {
    $env:SPECKIT_CORE_DIR = $savedCoreDir
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}
