# Agentic Code Reasoning Skills

An agent skill that translates the **Agentic Code Reasoning** paper into a practical, unified workflow for evidence-based code analysis without executing repository code.

## Original Paper

**Agentic Code Reasoning** by Shubham Ugare and Satish Chandra (Meta)
- arXiv: https://arxiv.org/abs/2603.01896
- Key results: semi-formal reasoning improves accuracy by 5–12 percentage points across patch equivalence verification, fault localization, and code question answering tasks

## Installation

Copy `SKILL.md` into your project's Claude Code skills directory:

```bash
# Create the skills directory if it doesn't exist
mkdir -p .claude/skills

# Option 1: Download directly from GitHub
curl -o .claude/skills/agentic-code-reasoning.md \
  https://raw.githubusercontent.com/KunihiroS/agentic-code-reasoning-skills/main/SKILL.md

# Option 2: Clone and copy
git clone https://github.com/KunihiroS/agentic-code-reasoning-skills.git
cp agentic-code-reasoning-skills/SKILL.md .claude/skills/agentic-code-reasoning.md
```

The skill activates automatically when Claude Code detects code reasoning tasks (e.g., "are these equivalent?", "where is the bug?", "what does this code do?").

## What This Is

This repository contains a single agent skill (`SKILL.md`) that implements **semi-formal reasoning** — a structured prompting methodology where the agent must state explicit premises, trace concrete code paths with file:line evidence, and derive formal conclusions before making any claim.

The skill supports four modes:

| Mode | Purpose |
|------|---------|
| `compare` | Determine if two code changes produce the same behavioral outcome |
| `localize` | Find the root cause of a bug from a failing test or error report |
| `explain` | Answer a code question with verified semantic evidence |
| `audit-improve` | Review code for security vulnerabilities, API misuse, or maintainability issues |

## How It Works

Each mode follows a shared **certificate-based reasoning process**:

1. **Numbered premises** — state known facts before exploring
2. **Hypothesis-driven exploration** — form expectations before reading files, record observations after
3. **Interprocedural tracing** — read actual function definitions, never infer from names
4. **Mandatory refutation** — try to disprove the conclusion before finalizing
5. **Formal conclusion** — reference specific premises and claims by number

The key idea from the paper: structured templates act as *certificates* that prevent the agent from skipping cases or making unsupported claims.

## Paper → Skill: Design Interpretation

### The paper's core insight

The paper defines **semi-formal reasoning** as a middle ground between unstructured chain-of-thought and fully formal verification. The key finding: when you give an agent a structured template that requires explicit premises, per-item code tracing, and a formal conclusion, accuracy improves by 5–12 percentage points across all three tasks — not because the model becomes smarter, but because the template **prevents it from skipping steps**.

The paper phrases this as: templates act as *certificates* — "the agent cannot skip cases or make unsupported claims" (§1).

### What we extracted from the paper

The paper evaluates three tasks, each with its own appendix template:

| Paper Task | Appendix | What the template enforces |
|------------|----------|---------------------------|
| Patch Equivalence Verification | Appendix A | Per-test iteration (trace each test through both patches separately), formal definitions of equivalence, counterexample obligation |
| Fault Localization | Appendix B | 4-phase pipeline (Premises → Code Path Tracing → Divergence Analysis → Ranked Predictions), hypothesis-driven exploration protocol |
| Code Question Answering | Appendix D | Function trace table with VERIFIED behavior column, data flow tracking, alternative hypothesis check |

Beyond these templates, the paper provides detailed **error analysis** for each task — specific failure patterns that semi-formal reasoning was designed to prevent:

| Failure Pattern | Paper Section | How it manifests |
|-----------------|---------------|------------------|
| Function name guessing | §4.1.1 | Agent assumes `format()` is Python's builtin when a module-level function shadows it |
| Symptom vs root cause confusion | Case Study §C | Agent identifies the crash site (StackOverflowError) instead of tracing upstream to where the bad state was created |
| Incomplete reasoning chains | §4.3 Error Analysis | Agent traces five functions but misses that downstream code already handles the edge case |
| Third-party library guessing | §4.1.1 | Agent guesses library behavior from function names when source is unavailable |
| Subtle difference dismissal | §4.1.1 | Agent finds a semantic difference but incorrectly concludes it is irrelevant to test outcomes |

### How we translated this into one skill

**Observation 1: The three templates share a common structure.**
All three appendix templates follow the same pattern: state premises → gather evidence iteratively → check for counterexamples or alternative hypotheses → derive formal conclusion. We extracted this as the shared **Core Method** (Steps 1–6).

**Observation 2: Per-item iteration is the key anti-skip mechanism.**
Each paper template has a "for each X, do Y" loop — per-test in patch equivalence, per-method in fault localization, per-function in code QA. This is what prevents the agent from jumping to conclusions. We preserved these loops as explicit iteration structures inside each mode's certificate template.

**Observation 3: Interprocedural tracing is structural, not just a rule.**
The paper notes that "the structured format naturally encourages interprocedural reasoning" (§1). The function trace table with its "Behavior (VERIFIED)" column forces the agent to actually read definitions rather than guess. We made this a dedicated Core Method step (Step 4) with VERIFIED/UNVERIFIED markers.

**Observation 4: The paper's future work directly suggests the fourth mode.**
Section 5 explicitly names "security vulnerability detection, code smell identification, and API misuse detection" as future applications of the same reasoning approach. We created `audit-improve` as a mode that applies the identical certificate discipline to these tasks, with per-finding structure (F[N]) and reachability verification.

**Observation 5: Error analysis should become guardrails.**
The paper's failure patterns are not random — they are systematic and predictable. We translated each documented failure mode into a specific, actionable guardrail with concrete examples (e.g., the Django `format()` shadowing case for name guessing).

### What we intentionally did NOT do

- **No language-specific templates.** The paper evaluates on Python, Java, and C++ but the reasoning process is language-agnostic. The skill uses universal terms ("functions, methods, data flow") to generalize across languages and frameworks, as the paper envisions (§5).
- **No execution reliance.** The paper's core constraint is that the agent cannot run repository code. The skill preserves this as a design principle, though it permits probing general language behavior with independent scripts (as the paper allows in §2.1).
- **No post-hoc verification.** The paper distinguishes its "input-side" approach (improving what the agent is asked to do) from "output-side" approaches like Datalog-based proof checking. The skill operates purely on the input side — structuring the reasoning process, not verifying the output.

## Reliability Evaluation

This skill has been evaluated on [SWE-bench-Verified](https://github.com/princeton-nlp/SWE-bench) patch equivalence tasks — the same benchmark used in the original paper (Section 4.1). The evaluation measures whether the skill improves an agent's ability to correctly determine if two code patches produce the same test outcomes.

**Setup:** 20 patch pairs from django/django (10 equivalent + 10 not equivalent), Claude Code CLI with Haiku (weakest model, to maximize skill effect), comparing with-skill vs without-skill accuracy.

| | without skill | with skill | Delta |
|---|---|---|---|
| **Overall** | 75.0% | **85.0%** | **+10pp** |
| Equivalent pairs | 60.0% | **80.0%** | +20pp |
| Not-equivalent pairs | 90.0% | 90.0% | 0pp |

**Key finding:** The skill's structured refutation check prevents the agent from incorrectly concluding that equivalent patches are different (+20pp on equivalent pairs). On not-equivalent pairs, performance is the same — the agent detects differences reliably with or without the skill.

*Note: The sample size is limited to 20 pairs due to computational resource constraints (each pair requires two full Claude Code agent runs). Larger-scale evaluation is planned.*

Full results and raw outputs: [`benchmark/swebench/`](benchmark/swebench/)

## Repository Structure

```
├── SKILL.md                    # The skill (install this)
└── benchmark/
    └── swebench/               # SWE-bench patch equivalence benchmark
        ├── prepare_pairs.py    # Generate patch pairs from SWE-bench data
        ├── run_benchmark.sh    # Run with-skill / without-skill evaluation
        ├── grade.py            # Grade agent outputs against ground truth
        ├── report.py           # Generate summary report
        ├── data/               # Benchmark input (pairs.json, prompt template)
        └── runs/iter-1/        # Results (report.md, grades.json)
```

## License

See [LICENSE](LICENSE).
