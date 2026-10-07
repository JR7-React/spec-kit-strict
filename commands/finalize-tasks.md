---
description: "Commitea tasks.md tras un receipt de implementacion vigente"
---

Run from the repository root:

```powershell
pwsh -NoProfile -File .specify/extensions/strict/scripts/powershell/git/finalize-tasks.ps1
```

This command verifies the implementation receipt and commits only the final
`tasks.md` state. Surface failures verbatim; never bypass a stale or blocked
receipt.
