. "$PSScriptRoot/test-support.ps1"

$root = (Resolve-Path "$PSScriptRoot/../..").Path
$manifest = Get-Content (Join-Path $root "extension.yml") -Raw

Assert-True ($manifest -match '(?m)^  id: "strict"$') "extension id is strict"
Assert-True ($manifest -match 'speckit_version: ">=1\.1\.0"') "requires Spec Kit 1.1+"

$commands = [regex]::Matches(
    $manifest,
    '(?m)^    - name: "(speckit\.[^"]+)"\r?\n      file: "([^"]+)"\r?\n      description: "([^"]+)"'
)
Assert-Equal 14 $commands.Count "manifest declares 14 commands"
# Hook commands are dispatched by Spec Kit; the prefix keeps agents from
# picking them for ordinary requests such as "commit this".
$hookPrefix = "Hook de Spec Kit: "
foreach ($command in $commands) {
    $name = $command.Groups[1].Value
    $file = $command.Groups[2].Value
    $description = $command.Groups[3].Value
    Assert-True ($name -match '^speckit\.strict\.[a-z0-9-]+$') "$name uses the strict namespace"
    Assert-True ($description.StartsWith($hookPrefix)) "$name description marks it as a hook"
    Assert-True (Test-Path -LiteralPath (Join-Path $root $file)) "$file exists"
    $body = Get-Content -LiteralPath (Join-Path $root $file) -Raw
    Assert-True ($body -match '(?s)^---\r?\ndescription: ".+"\r?\n---') "$file has a description"
    Assert-True ($body.Contains("description: `"$description`"")) (
        "$file description matches the manifest"
    )
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

# Vendored github/spec-kit scripts must keep their MIT copyright and permission
# notice when the extension is redistributed.
$notices = Join-Path $root "THIRD_PARTY_NOTICES.md"
Assert-True (Test-Path -LiteralPath $notices) "THIRD_PARTY_NOTICES.md exists"
$noticeText = Get-Content -LiteralPath $notices -Raw
foreach ($required in @(
    "Copyright GitHub, Inc.",
    "Permission is hereby granted, free of charge",
    "scripts/powershell/git/create-new-feature-branch.ps1",
    "scripts/powershell/git/git-common.ps1"
)) {
    Assert-True ($noticeText -match [regex]::Escape($required)) "notices include $required"
}
foreach ($vendored in @("create-new-feature-branch.ps1", "git-common.ps1")) {
    $header = (Get-Content (Join-Path $root "scripts/powershell/git/$vendored") -TotalCount 6) -join "`n"
    Assert-True ($header -match "THIRD_PARTY_NOTICES\.md") "$vendored points to the license notice"
}
