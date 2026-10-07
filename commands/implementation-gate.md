---
description: "Ejecuta los gates locales selectivos tras implementar"
---

Run from the repository root:

```powershell
pwsh -NoProfile -File .specify/extensions/strict/scripts/powershell/quality/invoke-implementation-gate.ps1
```

Surface stdout and stderr verbatim. A non-zero exit or
`SPECKIT_GATE=BLOCKED` prevents final task commit and phase completion.
