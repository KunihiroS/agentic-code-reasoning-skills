# Agentic Code Reasoning Skills

An agent skill that translates the **Agentic Code Reasoning** paper into a practical, unified workflow for evidence-based code analysis without executing repository code.

For design rationale and a deeper explanation of how the paper was translated into the skill, see [`docs/design.md`](docs/design.md).

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

The goal is to make code reasoning more reliable by forcing evidence gathering before judgment. The skill is intended for static code analysis tasks where careful tracing matters more than quick intuition.

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

## Reliability Evaluation

This skill has been evaluated on [SWE-bench-Verified](https://github.com/princeton-nlp/SWE-bench) patch equivalence tasks.

Setup summary: 20 patch pairs from `django/django` (10 equivalent + 10 not equivalent), comparing with-skill vs without-skill accuracy.

| | without skill | with skill | Delta |
|---|---|---|---|
| **Overall** | 75.0% | **85.0%** | **+10pp** |
| Equivalent pairs | 60.0% | **80.0%** | +20pp |
| Not-equivalent pairs | 90.0% | 90.0% | 0pp |

**Key finding:** The skill most clearly improves equivalent-pair judgments by enforcing a structured refutation step before concluding that two changes differ.

Full results and raw outputs: [`benchmark/swebench/`](benchmark/swebench/)

## Repository Structure

```
├── SKILL.md                    # The skill (install this)
├── benchmark/
│   └── swebench/               # SWE-bench patch equivalence benchmark
│       ├── prepare_pairs.py    # Generate patch pairs from SWE-bench data
│       ├── run_benchmark.sh    # Run with-skill / without-skill evaluation
│       ├── grade.py            # Grade agent outputs against ground truth
│       ├── report.py           # Generate summary report
│       ├── data/               # Benchmark input (pairs.json, prompt template)
│       └── runs/iter-1/        # Results (report.md, grades.json)
├── docs/
│   └── design.md               # Design rationale and paper-to-skill interpretation
└── LICENSE
```

## License

See [LICENSE](LICENSE).
