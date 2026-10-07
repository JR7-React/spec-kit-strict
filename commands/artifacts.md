---
description: "Hook de Spec Kit: valida spec, plan, tasks y checklists de la feature activa"
---

Run from the repository root:

```powershell
pwsh -NoProfile -File .specify/extensions/strict/scripts/powershell/quality/validate-artifacts.ps1
```

Surface stdout and stderr verbatim. A non-zero exit or
`SPECKIT_GATE=BLOCKED` stops the parent SpecKit phase.
