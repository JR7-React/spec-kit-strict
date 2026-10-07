---
description: "Hook de Spec Kit: crea o reutiliza la rama de la feature antes de especificar"
---

Use the feature description from:

```text
$ARGUMENTS
```

If the caller provides `GIT_BRANCH_NAME`, set it as an environment variable
before running the script below; the script then switches to that exact branch,
creating it when needed, and skips short-name generation.

Otherwise generate a concise 2-4 word kebab-case short name from the feature
description. Preserve technical terms and prefer action-noun wording.

Run from the repository root:

```powershell
pwsh -NoProfile -File .specify/extensions/strict/scripts/powershell/git/create-new-feature-branch.ps1 -Json -AllowExistingBranch -ShortName "<short-name>" "<feature description>"
```

The script only creates or switches the git branch and reports `BRANCH_NAME`
and `FEATURE_NUM`. Surface the JSON output verbatim. The caller must use
`specs/<BRANCH_NAME>/` as `SPECIFY_FEATURE_DIRECTORY` so the spec directory and
the branch keep the same name. A non-zero exit stops the specify phase; never
continue on the wrong branch.
