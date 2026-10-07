---
description: "Exige artefactos, checklists y analysis receipt vigentes antes de implementar"
---

Run from the repository root:

```powershell
pwsh -NoProfile -File .specify/extensions/strict/scripts/powershell/quality/validate-readiness.ps1
```

Surface stdout and stderr verbatim. A non-zero exit or
`SPECKIT_GATE=BLOCKED` stops implementation.
