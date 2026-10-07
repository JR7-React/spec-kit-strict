---
description: "Exige analysis vigente y remoto GitHub valido"
---

Run from the repository root:

```powershell
pwsh -NoProfile -File .specify/extensions/strict/scripts/powershell/quality/validate-transition.ps1 -Target TasksToIssues
```

Surface stdout and stderr verbatim. Stop on failure. When creating each issue,
include exactly one marker `<!-- speckit-task-id:T### -->` and the active
feature marker `<!-- speckit-feature:NNN-feature-name -->`.
