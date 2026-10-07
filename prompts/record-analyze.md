# Record Analyze Result

Use only the Specification Analysis Report produced immediately before this
hook. Do not rerun analysis and do not edit artifacts.

1. Count report findings by CRITICAL, HIGH, MEDIUM, and LOW.
2. Run:

```powershell
pwsh -NoProfile -File .specify/extensions/strict/scripts/powershell/quality/record-analyze-receipt.ps1 -Critical <critical> -High <high> -Medium <medium> -Low <low>
```

3. Surface stdout and stderr verbatim.
4. A non-zero exit or `SPECKIT_GATE=BLOCKED` stops the analyze phase.

If the report cannot be counted unambiguously, do not guess. Run the command
with `-Critical 1 -High 0 -Medium 0 -Low 0` and explain that receipt creation
was blocked by an invalid report.
