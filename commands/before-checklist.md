---
description: "Hook de Spec Kit: valida la specification antes del checklist"
---

Run from the repository root:

```powershell
pwsh -NoProfile -File .specify/extensions/strict/scripts/powershell/quality/validate-transition.ps1 -Target Checklist
```

Surface stdout and stderr verbatim. This hook is read-only. A non-zero exit or
`SPECKIT_GATE=BLOCKED` stops the parent SpecKit phase.
