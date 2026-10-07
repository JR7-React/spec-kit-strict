. "$PSScriptRoot/test-support.ps1"

$manifest = Get-Content "$PSScriptRoot/../../extension.yml" -Raw
$expected = @(
    "before_specify|speckit.strict.branch",
    "after_specify|speckit.strict.artifacts",
    "after_specify|speckit.strict.commit",
    "before_clarify|speckit.strict.before-clarify",
    "after_clarify|speckit.strict.artifacts",
    "after_clarify|speckit.strict.commit",
    "before_plan|speckit.strict.before-plan",
    "after_plan|speckit.strict.artifacts",
    "after_plan|speckit.strict.commit",
    "before_tasks|speckit.strict.before-tasks",
    "after_tasks|speckit.strict.artifacts",
    "after_tasks|speckit.strict.commit",
    "before_checklist|speckit.strict.before-checklist",
    "after_checklist|speckit.strict.artifacts",
    "after_checklist|speckit.strict.commit",
    "before_analyze|speckit.strict.before-analyze",
    "after_analyze|speckit.strict.after-analyze",
    "before_taskstoissues|speckit.strict.before-taskstoissues",
    "after_taskstoissues|speckit.strict.after-taskstoissues",
    "before_implement|speckit.strict.readiness",
    "after_implement|speckit.strict.implementation-gate",
    "after_implement|speckit.strict.finalize-tasks"
)

$hooksSection = ($manifest -split '(?m)^hooks:\r?\n', 2)[1]
$hooksSection = ($hooksSection -split '(?m)^\S', 2)[0]
$actual = [System.Collections.Generic.List[string]]::new()
$phase = $null
foreach ($line in ($hooksSection -split '\r?\n')) {
    if ($line -match '^  ([a-z_]+):\s*$') { $phase = $Matches[1]; continue }
    if ($line -match '^\s+- command: "([^"]+)"') { $actual.Add("$phase|$($Matches[1])") }
}
Assert-Equal ($expected -join ";") ($actual -join ";") "22 hooks in the exact order"
Assert-Equal 22 ([regex]::Matches($hooksSection, 'optional: false')).Count (
    "every hook is mandatory"
)
Assert-True ($hooksSection -notmatch 'optional:\s*true') "no optional hooks"
