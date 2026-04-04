# Benchmark Progression Record

**Purpose**: External-audit-ready record of all SWE-bench equivalence benchmark iterations.
**Task**: Given two Django patches A and B, determine if they produce identical test outcomes (EQUIVALENT / NOT_EQUIVALENT).
**Dataset**: 20 pairs — 10 EQUIVALENT, 10 NOT_EQUIVALENT. Source: `benchmark/swebench/data/pairs.json`.
**Model**: Claude (claude-3-5-sonnet or equivalent) via `claude --print` CLI.
**Variants**: `without_skill` (bare prompt) vs `with_skill` (SKILL.md injected).
**Grading**: YES→EQUIVALENT, NO→NOT_EQUIVALENT; partial credit = 0.

---

## Summary Table

| iter | SKILL.md change | ws_acc | ws_cost | ns_acc | ns_cost | skill_Δ |
|------|-----------------|--------|---------|--------|---------|---------|
| iter-1 | Baseline (self-check Step 5.5) | **85%** (17/20) | $3.45 | 75% (15/20) | $3.36 | **+10%** |
| iter-2† | External Audit Gate added (AI skipped reviewer) | 75% (15/20) | $3.49 | 75% (15/20) | $3.18 | 0% |
| iter-3† | EAG advisor design (invoke_reviewer.sh, FAIL→Step 6) | 75% (15/20) | $5.35 | 85% (17/20) | $3.61 | **-10%** |
| iter-4 | 6 structural improvements (dual-structure, D2, Step5.5 checklist, Step3/4 overlap, audit-improve sub-modes, Design Intent removed) | 80% (16/20) | $3.02 | 80% (16/20) | $3.48 | 0% |
| iter-5 | Counterfactual reasoning extended throughout analysis | **85%** (17/20) | $2.95 | 80% (16/20) | $2.70 | **+5%** |

ws = with_skill, ns = without_skill. † = run data deleted locally; numbers from session records.

---

## Iteration Details

### iter-1 — Baseline

**Date**: 2025 Q1
**SKILL.md commit**: `b4ce57d` (fix: make skill frontmatter YAML valid)
**Step 5.5**: Single yes/no self-check question

**Results**:

| Metric | without_skill | with_skill |
|--------|--------------|------------|
| Overall | 15/20 = 75% | 17/20 = 85% |
| EQUIV | 6/10 = 60% | 8/10 = 80% |
| NOT_EQ | 9/10 = 90% | 9/10 = 90% |
| Cost | $3.36 | $3.45 |
| Avg turns | 11.8 | 11.8 |

**Finding**: Skill adds +10%. Strongest on EQUIV cases (+20pp). Establishes baseline.

---

### iter-2 — External Audit Gate (invoke not working)

**Date**: 2025 Q1
**SKILL.md commit**: `c9a13e1`
**Change**: Step 5.5 replaced with External Audit Gate calling external CLI reviewers (codex/copilot/claude).

**Results**:

| Metric | without_skill | with_skill |
|--------|--------------|------------|
| Overall | 15/20 = 75% | 15/20 = 75% |
| EQUIV | 6/10 = 60% | 7/10 = 70% |
| NOT_EQ | 9/10 = 90% | 8/10 = 80% |
| Cost | $3.18 | $3.49 |

**Finding**: Skill effect = 0%. AI skipped the reviewer invocation step. No behavioral change despite SKILL.md change.

---

### iter-3 — External Audit Gate (advisor design)

**Date**: 2025 Q1
**SKILL.md commit**: `62fd3ee`
**Change**: Reviewer called via `invoke_reviewer.sh`; FAIL no longer triggers loop-back but instead proceeds to Step 6 with findings incorporated.

**Results**:

| Metric | without_skill | with_skill |
|--------|--------------|------------|
| Overall | 17/20 = 85% | 15/20 = 75% |
| EQUIV | 8/10 = 80% | 7/10 = 70% |
| NOT_EQ | 9/10 = 90% | 8/10 = 80% |
| Cost | $3.61 | **$5.35** |
| Avg turns | ~11 | **15.7** |

**Finding**: Skill effect = -10%. Reviewer feedback actively degraded accuracy on 2 cases (11433, 14373). Cost +55%, turns +57%. Decision: abandon External Audit Gate approach, revert to iter-1 baseline.

---

### iter-4 — Structural Improvements (6 items)

**Date**: 2026-04-04
**SKILL.md commit**: `4a13811`
**Changes made** (from critique analysis):
1. Core Method ↔ Certificate Template dual-structure resolved (Template is primary guide)
2. D2 (relevant tests) made explicit: fail-to-pass always relevant; pass-to-pass only if in call path
3. Step 5.5 strengthened: 1 yes/no → 4-item checklist
4. Step 3/4 overlap clarified: Step 4 updated in real time during Step 3
5. `audit-improve` sub-mode focus table added
6. `Design Intent` section removed

**Results**:

| Metric | without_skill | with_skill |
|--------|--------------|------------|
| Overall | 16/20 = 80% | 16/20 = 80% |
| EQUIV | 7/10 = 70% | 7/10 = 70% |
| NOT_EQ | 9/10 = 90% | 9/10 = 90% |
| Cost | $3.48 | **$3.02** |
| Avg turns | 10.9 | **9.6** |

**Finding**: Skill effect = 0%. Cost reduced (-12%). Structural cleanup removed noise but didn't fix accuracy vs iter-1. New regression: 13821.

**Root cause analysis of persistent failures**:
- `14787` (NOT_EQ, AI said EQ): AI found semantic difference but concluded "no test exercises it" without exhaustive search
- `15368` (EQ, AI said NOT_EQ): AI misinterpreted test deletion as "test failure"
- `15382` (EQ, AI said NOT_EQ): AI's loop+exception control flow trace was incorrect

---

### iter-5 — Counterfactual Reasoning Extended

**Date**: 2026-04-04
**SKILL.md commit**: `fba6dbd`
**Theoretical basis**: All 3 persistent failures shared a root cause — absence of counterfactual reasoning at intermediate claims. Step 5 (refutation) was a one-time final gate; failures occurred during intermediate claim formation.

**Changes made**:
1. **Step 4 Rules**: Added rule for exception handling in loops — after inferring behavior, ask "if this trace were wrong, what concrete input shows it?" and verify.
2. **Step 5 Scope extended**: Counterfactual obligation now explicitly covers intermediate claims: "no test exercises this difference", "this behavior is X", "these outcomes are identical/different"
3. **Compare template `NO COUNTEREXAMPLE EXISTS`**: Replaced `All existing tests produce identical outcomes because [reason]` with a structured 3-part form: (a) what would a counterexample look like? (b) show you searched for exactly that pattern; (c) state NONE FOUND with details.

**Results**:

| Metric | without_skill | with_skill |
|--------|--------------|------------|
| Overall | 16/20 = 80% | **17/20 = 85%** |
| EQUIV | 6/10 = 60% | 7/10 = 70% |
| NOT_EQ | 10/10 = 100% | 10/10 = 100% |
| Cost | $2.70 | **$2.95** |
| Avg turns | 8.0 | 8.7 |

**Finding**: Skill effect = +5%. NOT_EQ accuracy reached 100% for both variants. `14787` fixed by counterfactual improvement. Cost continued declining ($3.45→$2.95, -15% from baseline). New regression: 13821 still fails; 15368/15382 persistent.

---

## Per-Instance Results (with_skill)

| Instance | GT | iter-1 | iter-4 | iter-5 | Stable? |
|---|---|---|---|---|---|
| django__django-10999 | NEQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-11179 | EQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-11433 | NEQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-11603 | NEQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-11999 | NEQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-12262 | NEQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-12276 | EQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-12663 | NEQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-13417 | NEQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-13821 | EQ | ✓ | ✗ | ✗ | ⚠️ regressed at iter-4 |
| django__django-14089 | EQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-14122 | NEQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-14311 | NEQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-14373 | EQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-14672 | EQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-14765 | EQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-14787 | NEQ | ✗ | ✗ | **✓** | 🔧 fixed at iter-5 |
| django__django-15315 | EQ | ✓ | ✓ | ✓ | ✅ stable correct |
| django__django-15368 | EQ | ✗ | ✗ | ✗ | ❌ persistent failure |
| django__django-15382 | EQ | ✗ | ✗ | ✗ | ❌ persistent failure |

---

## Persistent Failure Analysis

### django__django-13821 (EQ → regressed at iter-4)
- Correct in iter-1, broken since iter-4
- Hypothesis: structural changes to D2 (relevant tests) definition caused over-scoping; AI now applies stricter pass-to-pass test scrutiny and finds a difference that isn't impactful
- Status: under investigation

### django__django-15368 (EQ, AI consistently says NOT_EQ)
- AI finds that Patch B deletes pass-to-pass test methods
- Treats "test deleted = test not running = different outcome" as NOT_EQ
- Root cause: AI's definition of equivalence includes test file modifications, not just behavioral outcomes
- SKILL fix attempted: none yet (D2 clarification is generalized, not benchmark-specific)
- Status: requires deeper investigation of whether this is a test-scope or reasoning error

### django__django-15382 (EQ, AI consistently says NOT_EQ)
- AI traces Patch B's WhereNode loop+exception handling and concludes it produces "WHERE 1=0" instead of correct WHERE clause
- Ground truth is EQ, meaning AI's trace was wrong
- Root cause: complex exception-in-loop control flow trace error
- SKILL fix attempted: Step 4 counterfactual rule for exception paths (iter-5), but not yet effective
- Status: trace accuracy improvement needed

---

## Current SKILL.md State (iter-5 / commit fba6dbd)

**Key structural decisions:**
- Certificate Templates are the primary guide (Core Method = meta-structure)
- Step 5 counterfactual obligation is continuous (intermediate claims, not just final)
- `NO COUNTEREXAMPLE EXISTS` requires explicit construction + targeted search
- `audit-improve` has sub-mode focus table
- External Audit Gate removed after iter-3 experiment

**Metrics vs baseline (iter-1)**:
- Accuracy: 85% → 85% (maintained)
- Cost: $3.45 → $2.95 (-15%)
- NOT_EQ accuracy: 90% → 100% (+10pp)
- EQUIV accuracy: 80% → 70% (-10pp, driven by 13821 regression)

