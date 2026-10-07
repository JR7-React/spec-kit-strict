---
description: "Hook de Spec Kit: verifica una issue unica por cada T###"
---

Run from the repository root:

```powershell
pwsh -NoProfile -File .specify/extensions/strict/scripts/powershell/quality/validate-taskstoissues.ps1
```

Surface stdout and stderr verbatim. A non-zero exit or
`SPECKIT_GATE=BLOCKED` means the conversion is incomplete and stops the phase.
