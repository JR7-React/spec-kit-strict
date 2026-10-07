. "$PSScriptRoot/test-support.ps1"
. "$PSScriptRoot/../../scripts/powershell/quality/quality-common.ps1"

$project = Join-Path ([IO.Path]::GetTempPath()) ("strict-config-" + [guid]::NewGuid())
$extensionDir = Join-Path $project ".specify/extensions/strict"
New-Item -ItemType Directory -Path $extensionDir -Force | Out-Null
$savedInitDir = $env:SPECIFY_INIT_DIR
try {
    $env:SPECIFY_INIT_DIR = $project
    Assert-Throws { Read-QualityGateConfig } "config-template\.yml" (
        "missing strict-config.yml explains how to create it"
    )

    Copy-Item "$PSScriptRoot/../../config-template.yml" (
        Join-Path $extensionDir "strict-config.yml"
    )
    $config = Read-QualityGateConfig
    Assert-Equal "frontend" $config.frontend.root (
        "reads strict-config.yml from the installed extension"
    )
}
finally {
    $env:SPECIFY_INIT_DIR = $savedInitDir
    Remove-Item -LiteralPath $project -Recurse -Force
}
