---
description: "Commitea solo los artefactos SpecKit de la fase actual"
---

Optional phase hint:

```text
$ARGUMENTS
```

Run from the repository root. When the hint is one of
`Specify|Clarify|Plan|Tasks|Checklist`, pass it as `-Phase`; otherwise use
automatic detection:

```powershell
pwsh -NoProfile -File .specify/extensions/strict/scripts/powershell/git/commit-spec-artifacts.ps1
```

Surface the resulting commit output. Never stage, commit, amend, or push paths
outside the script's explicit artifact scope.
