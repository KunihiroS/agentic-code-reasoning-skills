# SKILL.md v1 Evaluation Report

**Date:** 2025-03-27
**Evaluator:** Cascade (deep paper analysis)
**Target:** `/SKILL.md` (first draft, 255 lines)
**Rubric:** `docs/evaluation/rubric-v1.md`

---

## Score Summary

| ID | Criterion | Score | Grade |
|----|-----------|------:|-------|
| A1 | Certificate-as-Reasoning | 3/5 | △ |
| A2 | Premises-First | 4/5 | ○ |
| A3 | Interprocedural Tracing | 2/5 | ✗ |
| A4 | Refutation Obligation | 3/5 | △ |
| B1 | Patch Equiv Template | 3/5 | △ |
| B2 | Fault Local Template | 3/5 | △ |
| B3 | Code QA Template | 3/5 | △ |
| B4 | Per-Item Exhaustive | 2/5 | ✗ |
| C1 | Name Guessing Prevention | 3/5 | △ |
| C2 | Symptom vs Root Cause | 4/5 | ○ |
| C3 | Incomplete Chain | 2/5 | ✗ |
| C4 | Third-Party Library | 1/5 | ✗✗ |
| C5 | Subtle Diff Dismissal | 2/5 | ✗ |
| D1 | Language Independence | 5/5 | ◎ |
| D2 | Task Extensibility | 4/5 | ○ |
| D3 | Exploration Protocol | 4/5 | ○ |
| E1 | Trigger Precision | 3/5 | △ |
| E2 | Mode Selection Clarity | 4/5 | ○ |
| E3 | Response Contract | 4/5 | ○ |
| E4 | Guardrail Coverage | 3/5 | △ |
| **Total** | | **62/100** | |

**Category averages:**
- A (Philosophy Fidelity): **3.00/5**
- B (Template Precision): **2.75/5**
- C (Failure Mode Coverage): **2.40/5**
- D (Generalization): **4.33/5**
- E (Skill Implementation): **3.50/5**

---

## Detailed Findings

### Strengths

#### S1: Excellent generalization (D: 4.33/5)
The skill is fully language- and framework-independent. The paper's reasoning patterns are abstracted into universal terms ("functions, methods, data flow, conditionals") without any language-specific syntax. This is a strong design choice that aligns with the paper's vision of "task-specific formats that generalize across languages and frameworks" (main.tex L561).

#### S2: Good mode unification
Merging the paper's three tasks + future-work extensions into four modes with a shared core method is a sound architectural decision. The exploration protocol (Core Method Step 3) correctly generalizes the fault-localization-specific exploration format into a cross-mode capability.

#### S3: Strong symptom-vs-root-cause handling (C2: 4/5)
The Localize checklist item "Distinguish symptom site from root cause if they differ" and the guardrail "Do not treat a crash site as the root cause" directly reflect the Mockito_8 case study lesson. This is one of the best-translated insights from the paper.

#### S4: Clean mode selection (E2: 4/5)
The four-mode selection criteria are intuitive and mostly unambiguous.

---

### Weaknesses (ordered by impact)

#### W1: Per-item exhaustive analysis is nearly absent (B4: 2/5) — CRITICAL

**Problem:** The paper's most important anti-skip mechanism is the "for each X, do Y" loop structure. In the paper:

- Patch equivalence: "For each test: Claim 1.1 (Patch 1 outcome)… Claim 1.2 (Patch 2 outcome)… Comparison" (main.tex L610-616)
- Fault localization: "For each significant method call, document: METHOD / LOCATION / BEHAVIOR / RELEVANT" (main.tex L750-755)
- Code QA: Each row in the function trace table (main.tex L957-959)

These loops are what prevent the agent from skipping cases. Without them, the template is a checklist of sections, not a certificate.

**In SKILL.md v1:** The Compare mode says "Trace both paths separately" (L128) and the Localize mode says "Note every meaningful method with file:line" (L153), but neither defines the **per-item record format** that must be repeated for each item.

**Impact:** An agent could write "Both patches produce the same output" without tracing each test individually. This is exactly the failure mode the paper was designed to prevent.

#### W2: Interprocedural tracing is not structurally enforced (A3: 2/5) — CRITICAL

**Problem:** The paper's insight is that the template structure *itself* forces interprocedural reasoning — not just a rule saying "don't guess." The FUNCTION TRACE TABLE with its "Behavior (VERIFIED)" column (main.tex L957-959) forces the agent to read each function and record what it actually does. The Localize template's "For each significant method call, document: METHOD / LOCATION / BEHAVIOR / RELEVANT" (main.tex L750-755) does the same.

**In SKILL.md v1:** The guardrail "Do not assume a function's behavior from its name alone" (L235) is present but is a negative rule, not a structural enforcement. The Explain mode lists "FUNCTION TRACE TABLE" (L169) but doesn't define its columns. Without the explicit "Behavior (VERIFIED)" column, there is no structural pressure to actually verify behavior.

**Impact:** The agent can claim it traced a function without recording its verified behavior, defeating the paper's core mechanism.

#### W3: Third-party library semantics — zero coverage (C4: 1/5) — HIGH

**Problem:** The paper documents a specific failure mode: "The agent guessed behavior from function names when source code was unavailable" (main.tex L350). This happens when code calls into third-party libraries where the source is not in the repository.

**In SKILL.md v1:** No mention of this scenario. No guidance on what to do when a function's source cannot be found (e.g., mark as UNVERIFIED, search for documentation, test with a probe script as the paper allows in main.tex L167).

**Impact:** A known failure class is completely unaddressed.

#### W4: Certificate gating is weak (A1: 3/5) — HIGH

**Problem:** The paper's templates work as certificates because each section depends on the previous one. You cannot write a FORMAL CONCLUSION without first completing the ANALYSIS OF TEST BEHAVIOR, which requires PREMISES. This sequential dependency is the enforcement mechanism.

**In SKILL.md v1:** The Core Method lists 6 steps, and each mode lists required sections, but the dependency between them is implicit. There is no explicit statement like "Do not write ANALYSIS before completing PREMISES" or "FORMAL CONCLUSION must reference numbered claims from ANALYSIS."

**Impact:** The agent might fill sections out of order or skip upstream sections while still producing a conclusion.

#### W5: Incomplete reasoning chain prevention is weak (C3: 2/5) — MEDIUM

**Problem:** The paper documents that semi-formal reasoning can produce *more confident wrong answers* when the agent follows a plausible-but-incomplete chain: "the agent thoroughly traced five functions but missed that downstream code already handled the edge case it identified" (main.tex L1069).

**In SKILL.md v1:** The Explain checklist says "State uncertainty when downstream behavior is not fully proven" (L180), which is directionally correct but vague. There is no concrete instruction like "After identifying an edge case, verify whether downstream code already handles it before reporting it as a finding."

#### W6: Subtle difference dismissal prevention is weak (C5: 2/5) — MEDIUM

**Problem:** "The agent identified semantic differences but incorrectly concluded they were irrelevant to test outcomes" (main.tex L352).

**In SKILL.md v1:** No direct mitigation. The Compare counterexample check is indirect at best. Missing: "When a semantic difference is found between compared items, you must trace at least one relevant test through the differing code path before concluding the difference is irrelevant."

#### W7: Template concrete formats are too abstract (B1-B3: each 3/5) — MEDIUM

**Problem:** The paper provides very specific template structures with field names, table columns, and numbered references. SKILL.md v1 summarizes these into section headings without the internal structure.

Examples of what is missing:
- **Compare:** No "D1: Two patches are EQUIVALENT MODULO TESTS iff…" formal definition format
- **Compare:** No per-test iterative structure with Claim numbering
- **Compare:** No EDGE CASES section, no PASS_TO_PASS analysis
- **Localize:** No PREMISE T[N] numbering, no CLAIM D[N] cross-referencing
- **Localize:** No per-method record format (METHOD / LOCATION / BEHAVIOR / RELEVANT)
- **Explain:** No function trace table column definitions
- **Explain:** No data flow variable tracking format (Created at / Modified at / Used at)

#### W8: Refutation obligation could be stronger (A4: 3/5) — LOW

**Problem:** The paper uses "required" explicitly for both counterexample and no-counterexample. SKILL.md v1 says "required if claiming they differ" (L122) for counterexample but uses softer language "explain why no relevant counterexample was found" (L131) for the equivalence case.

---

## Priority Improvement Recommendations

### P0 (Must fix — undermines the paper's core mechanism)

1. **Add per-item loop structures to each mode template**
   - Compare: "For each relevant test: { Claim: Patch A outcome because [trace]… Claim: Patch B outcome because [trace]… Comparison: SAME / DIFFERENT }"
   - Localize: "For each method in the call path: { METHOD: … LOCATION: file:line … BEHAVIOR: … RELEVANT: … }"
   - Explain: Define function trace table columns explicitly

2. **Add interprocedural tracing as a structural requirement**
   - In Compare: "For each function called in the changed code, record: Function | Definition Location | Verified Behavior"
   - In Explain: Specify the full table format from the paper
   - In Localize: Require per-method records with BEHAVIOR field

### P1 (Should fix — addresses documented failure modes)

3. **Add third-party library guidance**
   - When a function's source is not in the repository: mark as UNVERIFIED in trace tables, search for documentation or type signatures, note the risk of assumption, optionally probe with an independent script

4. **Strengthen certificate gating language**
   - Add: "Complete each section in order. Do not write a conclusion before completing the analysis. The conclusion must reference specific numbered claims from the analysis."

5. **Add subtle-difference dismissal prevention**
   - In Compare guardrails: "When a semantic difference is found, trace at least one relevant test through the differing path before concluding the difference has no impact."

6. **Add incomplete-chain prevention**
   - In Explain/Audit guardrails: "After identifying an edge case or risk, verify whether downstream code already handles it before reporting it as a finding."

### P2 (Nice to have — improves precision)

7. **Add numbered reference system**
   - Premises: P1, P2… / Claims: C1, C2… / Hypotheses: H1, H2…
   - Require conclusions to cite specific premise/claim numbers

8. **Add EDGE CASES section to Compare**
   - Per the paper's template: "Only analyze edge cases that the ACTUAL tests exercise"

9. **Add PASS_TO_PASS awareness to Compare**
   - The paper distinguishes F2P and P2P tests explicitly

10. **Improve trigger description**
    - Add concrete intent phrases: "compare two patches", "find the bug", "explain what this code does", "review for security issues"

---

## Verdict

**SKILL.md v1 is a solid first-draft architecture** with excellent generalization (D: 4.33) and clean mode design. However, it translates the paper's **"what to think about"** more than **"how to think about it."** The paper's power comes from structural enforcement — per-item loops, numbered cross-references, mandatory fields — that prevent case-skipping and guessing. SKILL.md v1 captures the topics but not yet the enforcement mechanisms.

The most impactful improvement would be adding per-item exhaustive analysis structures (W1) and interprocedural tracing requirements (W2) to each mode template. These two changes alone would move the score from 62/100 to an estimated 75+/100.
