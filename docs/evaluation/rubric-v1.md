# Agentic Code Reasoning Skill — Evaluation Rubric v1

## Overview
This rubric evaluates how faithfully and effectively a skill translates the core philosophy of the **Agentic Code Reasoning** paper (arXiv:2603.01896v2) into a practical, generalized agent skill.

The rubric has **5 categories, 20 criteria**, each scored 1–5.

| Score | Meaning |
|-------|---------|
| 1 | Not addressed |
| 2 | Partially mentioned but insufficient |
| 3 | Basically addressed with clear room for improvement |
| 4 | Well addressed |
| 5 | Exceeds the paper's intent with excellent implementation |

---

## Category A: Philosophy Fidelity (哲学的忠実性)
Does the skill correctly translate the paper's core ideas?

### A1: Certificate-as-Reasoning
> Does the template function as a **reasoning enforcer**, not merely an output format?

The paper's central claim: semi-formal templates act as *certificates* — "the agent cannot skip cases or make unsupported claims" (§1, Abstract). The template structures the **reasoning process**, not just the output.

**5-point check:**
- The template has sequential dependencies (field N requires field N-1)
- The agent cannot jump to a conclusion without filling prior fields
- The structure forces evidence gathering before judgment

**Paper references:** main.tex L43, L64, L79-80, L209

### A2: Premises-First Principle
> Are explicit premises **required** before any conclusion?

"By structuring the reasoning process… we force the agent to gather evidence before concluding, preventing the premature judgments common in unconstrained reasoning" (§3).

**5-point check:**
- Premises are a mandatory first step
- Premises must be grounded in facts, not guesses
- Conclusions must reference specific premises

**Paper references:** main.tex L209, L602-606, L724

### A3: Interprocedural Tracing Induction
> Does the template structure **naturally force** the agent to read actual definitions rather than guess from names?

"The structured format naturally encourages interprocedural reasoning, as tracing program paths requires the agent to follow function calls rather than guess their behavior" (§1). The Django `format()` shadowing example is the canonical illustration.

**5-point check:**
- The template requires recording function definitions with file:line
- There is a specific field for "verified behavior" (not assumed)
- The structure makes it harder to skip reading a definition than to read it

**Paper references:** main.tex L65, L210, L263-266, L653-719, L957-959

### A4: Refutation Obligation
> Is counterexample / alternative-hypothesis checking **required**, not optional?

The paper mandates: "COUNTEREXAMPLE (required if claiming NOT EQUIVALENT)" and "NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT)" (Appendix A). For Code QA: "ALTERNATIVE HYPOTHESIS CHECK" is a required section.

**5-point check:**
- Refutation is labeled "required", not "recommended"
- Both directions are covered (proving and disproving)
- The check must produce concrete evidence, not just a statement

**Paper references:** main.tex L249-255, L630-645, L637, L971-975

---

## Category B: Template Structural Precision (テンプレート構造の精度)
How accurately do the mode-specific templates reflect the paper's concrete structures?

### B1: Patch Equivalence Template Fidelity
> Does the Compare mode reflect the full certificate structure?

The paper's complete template (Appendix A) has: DEFINITIONS → PREMISES (P1-P4) → ANALYSIS OF TEST BEHAVIOR (per-test) → EDGE CASES → COUNTEREXAMPLE or NO COUNTEREXAMPLE → FORMAL CONCLUSION → ANSWER.

**5-point check:**
- Formal definitions section (D1, D2) present
- Per-test iterative analysis ("For each test: Claim 1.1, Claim 1.2, Comparison")
- Edge cases section for test-exercised edge cases
- Pass-to-Pass test analysis (not just Fail-to-Pass)
- Both counterexample and no-counterexample paths

**Paper references:** main.tex L594-648

### B2: Fault Localization Template Fidelity
> Does the Localize mode reflect the full 4-phase + exploration protocol structure?

The paper defines: Phase 1 (Test Semantics with formal PREMISE T[N]) → Phase 2 (Code Path Tracing with METHOD/LOCATION/BEHAVIOR/RELEVANT) → Phase 3 (Divergence Analysis with CLAIM D[N] referencing PREMISE T[N]) → Phase 4 (Ranked Predictions citing CLAIM). Plus a Structured Exploration Protocol: HYPOTHESIS H[N] → OBSERVATIONS O[N] → HYPOTHESIS UPDATE → NEXT ACTION RATIONALE.

**5-point check:**
- Formal premises with numbering (PREMISE T1, T2…)
- Per-method structured records (METHOD/LOCATION/BEHAVIOR/RELEVANT)
- Claims must reference specific premises ("contradicts PREMISE T[N]")
- Exploration protocol with hypothesis tracking (H[N], O[N])
- Ranked predictions with claim citations

**Paper references:** main.tex L738-806, L724

### B3: Code QA Template Fidelity
> Does the Explain mode reflect the full structured template?

The paper requires: FUNCTION TRACE TABLE (with columns: Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED)) → DATA FLOW ANALYSIS (Variable → Created at → Modified at → Used at) → SEMANTIC PROPERTIES (Property → Evidence: file:line) → ALTERNATIVE HYPOTHESIS CHECK → FINAL ANSWER.

**5-point check:**
- Function trace table with explicit column definitions
- Data flow analysis with creation/modification/usage tracking
- Semantic properties with per-property evidence
- Alternative hypothesis with search-and-result structure
- All sections required, not optional

**Paper references:** main.tex L955-977

### B4: Per-Item Exhaustive Analysis
> Do the templates enforce "for each X, do Y" iteration?

The paper's core mechanism against case-skipping: "For each test: Claim… Claim… Comparison" (patch equivalence), "For each significant method call, document: METHOD/LOCATION/BEHAVIOR/RELEVANT" (fault localization), function trace table rows (code QA).

**5-point check:**
- Explicit "for each" loop structure in Compare (per-test)
- Explicit "for each" loop structure in Localize (per-method)
- Explicit "for each" loop structure in Explain (per-function)
- The loop body has a fixed format that must be filled for every item
- Skipping an item would leave a visible gap in the output

**Paper references:** main.tex L242-247, L610-620, L750-755, L957-959

---

## Category C: Failure Mode Coverage (失敗モード対策)
Does the skill address the paper's documented failure patterns?

### C1: Function Name Guessing Prevention
> Is there structural protection against inferring behavior from names?

Error analysis: "The agent guessed behavior from function names when source code was unavailable" (§4.1.1). The Django `format()` example is the canonical case.

**Paper references:** main.tex L350, L495-497, L809

### C2: Symptom vs Root Cause Distinction
> Does the skill force upstream tracing beyond crash sites?

Mockito_8 case study: standard reasoning "stopped at the symptom" (crash site), while semi-formal traced back to the root cause (registration overwrite at line 80).

**Paper references:** main.tex L819-821, L936-937

### C3: Incomplete Reasoning Chain Prevention
> Does the skill guard against confident-but-wrong answers from partial analysis?

"Semi-formal reasoning can fail when agents construct elaborate but incomplete reasoning chains" (§4.3 Error Analysis). The py_5 case: agent traced five functions but missed downstream handling.

**Paper references:** main.tex L348, L500, L1069

### C4: Third-Party Library Semantics
> Does the skill address the case where source code is unavailable?

Explicit failure mode: "Third-party library semantics: The agent guessed behavior from function names when source code was unavailable" (§4.1.1).

**Paper references:** main.tex L350

### C5: Subtle Difference Dismissal Prevention
> Does the skill prevent the agent from finding a difference and then dismissing it?

"The agent identified semantic differences but incorrectly concluded they were irrelevant to test outcomes" (§4.1.1).

**Paper references:** main.tex L352

---

## Category D: Generalization & Extensibility (汎化と拡張性)
Does the skill generalize beyond the paper's three tasks?

### D1: Language and Framework Independence
> Is the skill free from language-specific constructs?

The paper emphasizes: "task-specific formats that generalize across languages and frameworks" (§5).

**Paper references:** main.tex L154, L561

### D2: Task Extensibility
> Can the skill naturally accommodate new task types beyond the paper's three?

The paper's future work explicitly names "security vulnerability detection, code smell identification, and API misuse detection" (§5).

**Paper references:** main.tex L571

### D3: Exploration Protocol Generality
> Is the hypothesis-driven exploration protocol available across all modes?

The exploration protocol (HYPOTHESIS → OBSERVATIONS → UPDATE) was developed for fault localization but applies to all investigative code reasoning.

**Paper references:** main.tex L773-809

---

## Category E: Skill Implementation Quality (スキル実装品質)
Is the skill well-designed as a practical agent skill?

### E1: Trigger Precision
> Will the skill description cause it to be invoked at the right times?

The description should match concrete user intents, not just abstract capabilities.

### E2: Mode Selection Clarity
> Can the agent reliably pick the correct mode?

Mode boundaries must be unambiguous, with guidance for edge cases.

### E3: Minimal Response Contract
> Are mandatory output elements clearly defined per mode?

Every invocation should produce a predictable minimum set of outputs.

### E4: Guardrail Specificity and Coverage
> Are guardrails derived from the paper's error analysis and sufficiently concrete?

Guardrails should map to documented failure modes with actionable instructions.

---

## Scoring Summary Template

| ID | Criterion | Score | Notes |
|----|-----------|-------|-------|
| A1 | Certificate-as-Reasoning | /5 | |
| A2 | Premises-First | /5 | |
| A3 | Interprocedural Tracing | /5 | |
| A4 | Refutation Obligation | /5 | |
| B1 | Patch Equiv Template | /5 | |
| B2 | Fault Local Template | /5 | |
| B3 | Code QA Template | /5 | |
| B4 | Per-Item Exhaustive | /5 | |
| C1 | Name Guessing Prevention | /5 | |
| C2 | Symptom vs Root Cause | /5 | |
| C3 | Incomplete Chain | /5 | |
| C4 | Third-Party Library | /5 | |
| C5 | Subtle Diff Dismissal | /5 | |
| D1 | Language Independence | /5 | |
| D2 | Task Extensibility | /5 | |
| D3 | Exploration Protocol | /5 | |
| E1 | Trigger Precision | /5 | |
| E2 | Mode Selection Clarity | /5 | |
| E3 | Response Contract | /5 | |
| E4 | Guardrail Coverage | /5 | |
| **Total** | | **/100** | |
