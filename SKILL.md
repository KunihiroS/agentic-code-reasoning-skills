---
name: agentic-code-reasoning
description: Use when you need to compare two code changes for behavioral equivalence, localize a bug from a failing test or report, answer a question about code semantics with verified evidence, or audit code for security vulnerabilities, API misuse, or maintainability issues — all without executing repository code.
---

# Agentic Code Reasoning

## Purpose
Reason about code behavior using structured semi-formal analysis without executing repository code.

This skill enforces a certificate-based reasoning process: you must state premises, trace concrete code paths with file:line evidence, and derive formal conclusions. You cannot skip sections or make unsupported claims.

## Modes
- `compare` — determine if two changes produce the same behavior
- `localize` — find the root cause of a bug
- `explain` — answer a code question with verified evidence
- `audit-improve` — review code for security, API misuse, or maintainability

Choose a mode before exploring files. If unsure, prefer `explain`.

### Mode selection guide
| Trigger | Mode |
|---------|------|
| "Are these two patches/implementations equivalent?" | `compare` |
| "Where is the bug?" / failing test / error report | `localize` |
| "What does this code do?" / "Why does X happen?" | `explain` |
| "Is this code secure?" / "Review for issues" | `audit-improve` |

---

## Core Method
Apply this process in every mode. **Complete each section in order. Do not write a later section before completing earlier ones.**

### Step 1: Task and constraints
Write a short task statement and list constraints (e.g., no repository execution, static inspection only, file:line evidence required).

### Step 2: Numbered premises
Before concluding anything, write numbered premises grounded in known facts.

```
P1: [fact about the task, inputs, or expected behavior]
P2: [fact about relevant files, tests, or specifications]
P3: ...
```

Do not treat guesses as premises. Every later claim must reference a premise by number.

### Step 3: Hypothesis-driven exploration
Before opening any file, write:

```
HYPOTHESIS H[N]: [what you expect to find and why]
EVIDENCE: [what supports this hypothesis — cite premises or prior observations]
CONFIDENCE: high / medium / low
```

After reading, record:

```
OBSERVATIONS from [filename]:
  O[N]: [finding with file:line]
  O[N]: [another finding with file:line]

HYPOTHESIS UPDATE:
  H[M]: CONFIRMED / REFUTED / REFINED — [explanation]

UNRESOLVED:
  - [remaining questions]

NEXT ACTION RATIONALE: [why the next file or step is justified]
```

### Step 4: Interprocedural tracing
For every function or method encountered on a relevant code path, record:

| Function/Method | File:Line | Behavior (VERIFIED) |
|-----------------|-----------|---------------------|
| [name] | [file:N] | [actual behavior after reading the definition] |

**Rules:**
- Read the actual definition. Do not infer behavior from the name.
- Mark the Behavior column VERIFIED only after reading the source.
- If source is unavailable (third-party library), mark UNVERIFIED and note the assumption. Search for type signatures, documentation, or test usage as secondary evidence. Optionally probe language behavior with an independent script.
- Trace through conditionals, mapping tables, and configuration — not just the happy path.

### Step 5: Refutation check (required)
This step is **mandatory**, not optional.

For `compare` and `audit-improve`:
```
COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: [what]
- Found: [what — cite file:line]
- Result: REFUTED / NOT FOUND
```

For `explain` and `localize`:
```
ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, what evidence would exist?
- Searched for: [what]
- Found: [what — cite file:line]
- Conclusion: REFUTED / SUPPORTED
```

### Step 6: Formal conclusion
Write a conclusion that:
- References specific numbered premises and claims (e.g., "By P1 and C2…")
- States what was established
- States what remains uncertain or unverified
- Assigns a confidence level: HIGH / MEDIUM / LOW

---

## Compare

Goal: determine whether two changes produce the same relevant behavior.

### Certificate template

Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS.

```
DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant
    test suite produces identical pass/fail outcomes for both.
D2: The relevant tests are [list of test categories — e.g., fail-to-pass,
    pass-to-pass, integration, etc.]

PREMISES:
P1: Change A modifies [file(s)] by [specific description]
P2: Change B modifies [file(s)] by [specific description]
P3: The fail-to-pass tests check [specific behavior]
P4: The pass-to-pass tests check [specific behavior, if relevant]

ANALYSIS OF TEST BEHAVIOR:

For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome

For pass-to-pass tests (if changes could affect them differently):
  Test: [name]
  Claim C[N].1: With Change A, behavior is [description]
  Claim C[N].2: With Change B, behavior is [description]
  Comparison: SAME / DIFFERENT outcome

EDGE CASES RELEVANT TO EXISTING TESTS:
(Only analyze edge cases that the ACTUAL tests exercise)
  E[N]: [edge case]
    - Change A behavior: [specific output/behavior]
    - Change B behavior: [specific output/behavior]
    - Test outcome same: YES / NO

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
  Test [name] will [PASS/FAIL] with Change A because [reason]
  Test [name] will [FAIL/PASS] with Change B because [reason]
  Therefore changes produce DIFFERENT test outcomes.

NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT):
  All existing tests produce identical outcomes because [reason with evidence]

FORMAL CONCLUSION:
By Definition D1:
  - Test outcomes with Change A: [PASS/FAIL for each test]
  - Test outcomes with Change B: [PASS/FAIL for each test]
  - Since outcomes are [IDENTICAL/DIFFERENT], changes are
    [EQUIVALENT/NOT EQUIVALENT] modulo the existing tests.

ANSWER: [YES equivalent / NO not equivalent]
CONFIDENCE: [HIGH / MEDIUM / LOW]
```

### Compare checklist
- Identify changed files for both sides
- Identify fail-to-pass AND pass-to-pass tests
- For each function called in changed code, read its definition and record in the interprocedural trace table (Step 4)
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)

---

## Localize

Goal: identify the root cause of a bug, not just the crash site.

### Certificate template

Complete phases in order. Each phase depends on the previous one.

```
PHASE 1: TEST / SYMPTOM SEMANTICS

What does the failing test or bug report describe?
State as formal premises:
  PREMISE T1: The test calls [X.method(args)] and expects [behavior]
  PREMISE T2: The test asserts [condition]
  PREMISE T3: The observed failure is [error type / wrong output / hang]
  ...

PHASE 2: CODE PATH TRACING

Trace the execution path from the test entry point into production code.
For each significant method call, record:

| # | METHOD | LOCATION | BEHAVIOR | RELEVANT |
|---|--------|----------|----------|----------|
| 1 | ClassName.method(params) | file:line | [verified behavior] | [why it matters to PREMISE T[N]] |
| 2 | ... | ... | ... | ... |

Build the call sequence: test → method1 → method2 → ...

PHASE 3: DIVERGENCE ANALYSIS

For each code path traced, identify where the implementation diverges
from the test's expectations. State as formal claims:

  CLAIM D1: At [file:line], [code] produces [behavior]
            which contradicts PREMISE T[N] because [reason]
  CLAIM D2: ...

Each claim MUST reference a specific PREMISE and a specific code location.

PHASE 4: RANKED PREDICTIONS

Based on divergence claims, produce ranked predictions:
  Rank 1 ([confidence]): [file:line range] — [description]
    Supporting claim(s): D[N]
    Root cause / symptom: [which one]
  Rank 2 ([confidence]): ...
```

### Exploration protocol
Use the hypothesis-driven format from Step 3 during exploration. Number hypotheses H1, H2… and observations O1, O2… for traceability.

### Localize checklist
- State what the failing behavior expects (Phase 1)
- Trace from entry point toward production code with per-method records (Phase 2)
- Every divergence claim must reference a specific premise (Phase 3)
- Rank candidates and cite supporting claims (Phase 4)
- Distinguish symptom site from root cause — if the crash site differs from the origin of incorrect state, investigate upstream
- Check for indirection: is the bug in a class not directly called by the test?

---

## Explain

Goal: answer a code question with verified semantic evidence.

### Certificate template

Complete every section. Do not write FINAL ANSWER before ALTERNATIVE HYPOTHESIS CHECK.

```
QUESTION: [restate the question]

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| [function1]     | [file:N]  | [param types]   | [ret type]  | [ACTUAL behavior]   |
| [function2]     | [file:N]  | [param types]   | [ret type]  | [ACTUAL behavior]   |

DATA FLOW ANALYSIS:
Variable: [key variable name]
  - Created at: [file:line]
  - Modified at: [file:line(s), or NEVER MODIFIED]
  - Used at: [file:line(s)]

(Repeat for each key variable)

SEMANTIC PROPERTIES:
Property 1: [e.g., "map is immutable after initialization"]
  - Evidence: [specific file:line]
Property 2: ...
  - Evidence: [specific file:line]

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, what evidence would exist?
  - Searched for: [what you looked for]
  - Found: [what you found — cite file:line]
  - Conclusion: REFUTED / SUPPORTED

FINAL ANSWER:
[answer with explicit evidence citations]

CONFIDENCE: [HIGH / MEDIUM / LOW]
```

### Explain checklist
- Read actual definitions — do not infer behavior from names
- Fill every row in the function trace table with VERIFIED behavior
- Track key variables from creation through modification to usage
- Identify semantic properties with per-property file:line evidence
- Check the opposite answer before finalizing
- After identifying an edge case, verify whether downstream code already handles it before reporting it as a finding
- State uncertainty when downstream behavior is not fully verified

---

## Audit-Improve

Goal: inspect code for risks or improvement opportunities, grounded in traced evidence.

### Sub-modes
- `security-audit` — injection, auth bypass, path traversal, secrets, unsafe defaults
- `refactor-review` — oversized units, duplication, mixed responsibilities, fragile flow
- `code-smell-check` — hidden coupling, dead branches, poor naming, hard-to-test design
- `api-misuse-check` — incorrect API usage, wrong assumptions about library semantics

### Certificate template

```
REVIEW TARGET: [file(s) / module / component]
AUDIT SCOPE: [which sub-mode(s) and what property is being checked]

PREMISES:
P1: [fact about the code's purpose or expected security properties]
P2: [fact about the API contract or framework requirements]
...

FINDINGS:

For each finding:
  Finding F[N]: [title]
    Category: security / refactor / smell / api-misuse
    Status: CONFIRMED / PLAUSIBLE (needs more evidence)
    Location: [file:line range]
    Trace: [code path that leads to this issue — cite file:line at each step]
    Impact: [what can go wrong and under what conditions]
    Evidence: [specific file:line proof]

COUNTEREXAMPLE CHECK:
For each confirmed finding, did you verify it is reachable?
  F[N]: Reachable via [call path] — YES / UNVERIFIED

RECOMMENDATIONS:
R[N] (for F[N]): [specific fix or mitigation]
  Risk of change: [what could break]
  Minimal safe change: [smallest effective fix]

UNVERIFIED CONCERNS:
- [issues that need more context or are speculative]

CONFIDENCE: [HIGH / MEDIUM / LOW]
```

### Audit-Improve checklist
- Define the review target and scope clearly
- State the risk or quality property being checked as a premise
- Trace the relevant code path — do not flag isolated lines without context
- Separate CONFIRMED from PLAUSIBLE findings
- For each confirmed finding, verify it is reachable via a concrete call path
- For refactoring, propose the safest minimal change first
- Do not report speculative security issues as confirmed vulnerabilities
- For API misuse, read the actual API definition or documentation before claiming misuse

---

## Guardrails

### From the paper's error analysis
1. **Do not assume behavior from names.** Read the actual function definition. The canonical failure: assuming Python's builtin `format()` when a module-level function with different semantics shadows it.
2. **Do not claim test outcomes without tracing.** Trace each test through the relevant code path before asserting PASS or FAIL.
3. **Do not confuse symptom with root cause.** A crash site (e.g., StackOverflowError in a recursive method) may not be the origin of incorrect state. Trace upstream to find where the bad state was created.
4. **Do not dismiss subtle differences.** If you find a semantic difference between compared items, trace at least one relevant test through the differing code path before concluding the difference has no impact.
5. **Do not trust incomplete chains.** After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified. Confident-but-wrong answers often come from thorough-but-incomplete analysis.
6. **Handle unavailable source explicitly.** When a function's source is not in the repository (third-party library), mark it UNVERIFIED in trace tables. Search for type signatures, documentation, or test usage as secondary evidence. Do not guess behavior from the function name.

### General
7. Do not treat style preferences as findings unless they affect maintainability or correctness.
8. Do not hide uncertainty — state what is unverified.
9. Do not skip the refutation check. It is mandatory in every mode.

---

## Minimal Response Contract

Every response using this skill must include:

| Element | Required in |
|---------|-------------|
| Selected mode | All |
| Numbered premises | All |
| Interprocedural trace table | All (when functions are on the code path) |
| Per-item analysis (per-test, per-method, or per-function) | compare, localize, explain |
| Refutation / alternative-hypothesis check | All |
| Formal conclusion with premise/claim references | All |
| Confidence level | All |

---

## Design Intent
This skill translates the Agentic Code Reasoning paper's semi-formal reasoning into one unified, mode-selected workflow. The certificate templates enforce structured evidence gathering — per-item iteration, interprocedural tracing, and mandatory refutation — to prevent the premature judgments and case-skipping that unstructured reasoning allows. The `audit-improve` mode extends the same reasoning discipline into security analysis, refactoring review, and API misuse detection, as indicated by the paper's future-work directions.
