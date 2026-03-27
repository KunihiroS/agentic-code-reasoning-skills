# SKILL.md v2 Self-Evaluation Report

**Date:** 2025-03-27
**Target:** `/SKILL.md` v2 (400 lines)
**Rubric:** `docs/evaluation/rubric-v1.md`
**Baseline:** v1 scored 62/100

---

## Score Summary

| ID | Criterion | v1 | v2 | Δ | Key Change |
|----|-----------|---:|---:|--:|------------|
| A1 | Certificate-as-Reasoning | 3 | 4 | +1 | Sequential gating language in Core Method + per-mode gates |
| A2 | Premises-First | 4 | 5 | +1 | Numbered premises (P[N]) + "every claim must reference a premise" |
| A3 | Interprocedural Tracing | 2 | 4 | +2 | Dedicated Step 4 with VERIFIED/UNVERIFIED trace table |
| A4 | Refutation Obligation | 3 | 5 | +2 | "mandatory, not optional" + both directions explicit |
| B1 | Patch Equiv Template | 3 | 5 | +2 | Full certificate: D1/D2, per-test iteration, EDGE CASES, P2P, both COUNTEREXAMPLE paths |
| B2 | Fault Local Template | 3 | 5 | +2 | PREMISE T[N], per-method table, CLAIM D[N]→PREMISE cross-ref, ranked with citations |
| B3 | Code QA Template | 3 | 5 | +2 | 5-column trace table, data flow format, semantic properties with evidence |
| B4 | Per-Item Exhaustive | 2 | 4 | +2 | "For each relevant test:", per-method table rows, "Repeat for each key variable" |
| C1 | Name Guessing Prevention | 3 | 5 | +2 | Structural: Step 4 VERIFIED column + Guardrail #1 with Django example |
| C2 | Symptom vs Root Cause | 4 | 5 | +1 | Localize goal, Phase 4 root-cause/symptom field, indirection check |
| C3 | Incomplete Chain | 2 | 4 | +2 | Guardrail #5 + Explain checklist: verify downstream handling |
| C4 | Third-Party Library | 1 | 4 | +3 | Step 4 UNVERIFIED protocol + Guardrail #6 with fallback strategy |
| C5 | Subtle Diff Dismissal | 2 | 4 | +2 | Guardrail #4 + Compare checklist: trace test through difference |
| D1 | Language Independence | 5 | 5 | 0 | Maintained |
| D2 | Task Extensibility | 4 | 5 | +1 | Audit-Improve: per-finding structure F[N], reachability check, R[N] |
| D3 | Exploration Protocol | 4 | 5 | +1 | H[N]/O[N] numbering in Core Method Step 3 |
| E1 | Trigger Precision | 3 | 4 | +1 | Concrete intent phrases in description + mode selection table |
| E2 | Mode Selection Clarity | 4 | 5 | +1 | Trigger→Mode table + "if unsure, prefer explain" |
| E3 | Response Contract | 4 | 5 | +1 | Table format with per-mode requirements including per-item analysis |
| E4 | Guardrail Coverage | 3 | 5 | +2 | 9 guardrails (was 6), all paper failure modes covered |
| **Total** | | **62** | **93** | **+31** | |

## Category Averages

| Category | v1 | v2 | Δ |
|----------|---:|---:|--:|
| A: Philosophy Fidelity | 3.00 | 4.50 | +1.50 |
| B: Template Precision | 2.75 | 4.75 | +2.00 |
| C: Failure Mode Coverage | 2.40 | 4.40 | +2.00 |
| D: Generalization | 4.33 | 5.00 | +0.67 |
| E: Skill Implementation | 3.50 | 4.75 | +1.25 |

---

## What Improved Most

1. **B1-B3 (Template Fidelity): 3→5 each** — All three mode templates now closely mirror the paper's appendix templates with full structural detail.
2. **C4 (Third-Party Library): 1→4** — From zero coverage to a concrete protocol (UNVERIFIED marking + fallback strategy).
3. **A3 (Interprocedural Tracing): 2→4** — From a guardrail-only rule to a dedicated Core Method step with structural enforcement via VERIFIED column.
4. **A4 (Refutation Obligation): 3→5** — From soft language to explicit "mandatory, not optional" with both directions covered.

## Remaining Gaps (items not at 5/5)

| ID | Score | Why not 5 | Possible path to 5 |
|----|------:|-----------|---------------------|
| A1 | 4 | Full gating (prevent next section if previous is empty) is beyond document-level enforcement | Would require tool-level integration (e.g., a validator that checks section completeness) |
| B4 | 4 | "For each" loops are present but lack "you must cover ALL items, leaving no row empty" | Add explicit: "Fill a row for every relevant test/method/variable. An incomplete table invalidates the certificate." |
| C3 | 4 | Preventing confident-but-wrong answers from partial analysis is inherently meta-cognitive | Could add a "completeness self-check" step: "List code paths NOT traced and justify why they are irrelevant" |
| C4 | 4 | Protocol exists but no concrete UNVERIFIED example in the template | Add an example row: `| requests.get | UNVERIFIED | Assumed: HTTP GET. Source unavailable. Secondary evidence: test_api.py:45 uses it with URL param. |` |
| C5 | 4 | Rule exists in guardrails and checklist but not structurally embedded in the Compare template | Could add a mandatory section: "DIFFERENCES FOUND: For each, state whether test-impacting: YES/NO with trace" |
| E1 | 4 | Description may be slightly long for some skill platforms | Could split into a short description + extended description pattern |

---

## Verdict

**SKILL.md v2 achieves 93/100**, a +31 point improvement from v1 (62/100).

The most significant transformation is from **topic coverage** (v1) to **structural enforcement** (v2). The paper's three core mechanisms — per-item iteration, interprocedural tracing, and mandatory refutation — are now embedded as template structures rather than checklist items.

The remaining 7 points are at the boundary of what a Markdown skill document can enforce. Further improvement would likely require:
- Tool-level integration for certificate completeness validation (A1)
- Explicit "completeness gate" language for exhaustive analysis (B4)
- Worked examples showing the skill in action (new dimension not in current rubric)
