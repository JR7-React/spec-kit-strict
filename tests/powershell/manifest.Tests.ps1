. "$PSScriptRoot/test-support.ps1"

$root = (Resolve-Path "$PSScriptRoot/../..").Path
$manifest = Get-Content (Join-Path $root "extension.yml") -Raw

Assert-True ($manifest -match '(?m)^  id: "strict"$') "extension id is strict"
Assert-True ($manifest -match 'speckit_version: ">=1\.1\.0"') "requires Spec Kit 1.1+"

$commands = [regex]::Matches(
    $manifest, '(?m)^    - name: "(speckit\.[^"]+)"\r?\n      file: "([^"]+)"'
)
Assert-Equal 14 $commands.Count "manifest declares 14 commands"
foreach ($command in $commands) {
    $name = $command.Groups[1].Value
    $file = $command.Groups[2].Value
    Assert-True ($name -match '^speckit\.strict\.[a-z0-9-]+$') "$name uses the strict namespace"
    Assert-True (Test-Path -LiteralPath (Join-Path $root $file)) "$file exists"
    $body = Get-Content -LiteralPath (Join-Path $root $file) -Raw
    Assert-True ($body -match '(?s)^---\r?\ndescription: ".+"\r?\n---') "$file has a description"
    Assert-True ($body -notmatch 'HOOK_ARGUMENTS') "$file uses native arguments"
    Assert-True ($body -notmatch '\.specify/scripts/powershell/(quality|git)/') (
        "$file points to the installed extension scripts"
    )
}

$prompt = Get-Content (Join-Path $root "prompts/record-analyze.md") -Raw
foreach ($required in @(
    ".specify/extensions/strict/scripts/powershell/quality/record-analyze-receipt.ps1",
    "Do not rerun analysis",
    "-Critical",
    "SPECKIT_GATE=BLOCKED"
)) {
    Assert-True ($prompt -match [regex]::Escape($required)) (
        "record analyze prompt requires $required"
    )
}
