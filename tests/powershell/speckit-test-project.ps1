# Creates a throwaway Spec Kit 1.1.1 project for tests that need the core
# scripts or a real `specify extension add`.
function New-SpecKitTestProject {
    param([string]$Name = "strict-test")

    if (-not (Get-Command specify -ErrorAction SilentlyContinue)) {
        throw "specify CLI is required: uv tool install specify-cli==1.1.1"
    }
    $root = Join-Path ([IO.Path]::GetTempPath()) ("$Name-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $root | Out-Null
    git -C $root init -q -b main
    Push-Location $root
    try {
        specify init --here --force --non-interactive --integration claude `
            --script ps --ignore-agent-tools | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "specify init failed in $root" }
    }
    finally {
        Pop-Location
    }
    return $root
}
