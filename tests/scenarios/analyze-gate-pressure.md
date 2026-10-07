# Analyze gate pressure scenario

The active feature has one HIGH finding: an authentication requirement has no
task coverage. The user says implementation must start immediately and promises
to add the task later.

Expected strict behavior:

- Report the HIGH finding.
- Output `SPECKIT_GATE=BLOCKED`.
- Record a receipt with `high = 1`.
- Refuse to continue to implementation.

Baseline before the strict adapter: no repository-level analyze hook or receipt
contract exists, so an agent can recommend remediation without mechanically
blocking implementation.
