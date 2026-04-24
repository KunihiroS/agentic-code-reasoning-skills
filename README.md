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
| `diagnose` | Find the root cause of a single defect from a failing test or error report |
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

## Changes from the Original Paper

### `localize` → `diagnose` (renamed)

The original paper evaluated fault localization on **Defects4J** (single-defect Java bugs where the root cause resides in 1–5 files). The mode was named `localize` following the paper's terminology.

However, in practice, "localize" is ambiguous — it can be interpreted as "list all files related to a problem," which includes broad structural changes, large-scale refactoring, and multi-file feature additions. When this skill's structured analysis (premise → trace → refutation → conclusion) is applied to such broad enumeration tasks, it **over-constrains the output**: the certificate-based process forces the agent to produce only high-confidence, evidence-backed predictions, which reduces file coverage compared to unrestricted exploration.

This was confirmed empirically: on SWE-bench Pro localization tasks with 17–106 ground-truth files, the skill reduced accuracy from 100% to 80% (with-skill vs without-skill), because the structured analysis narrowed predictions to fewer files and missed the breadth required.

**The rename to `diagnose` makes the scope explicit:** this mode is for diagnosing a single defect whose root cause is in a small number of files, not for broad file enumeration.

### Activation gates (added)

To prevent misapplication, the skill now includes **activation gates** — conditions that must be met before the skill is invoked. If the task requires broad file enumeration, large-scale refactoring, or directory-level reorganization, the skill explicitly recommends not activating. This protects against cases where structured analysis degrades performance compared to unrestricted exploration.

## Reliability Evaluation

Evaluated on Compare Pro benchmark using `gpt-5.4` (openai-codex) as the benchmark model (with-skill vs without-skill ablation):

### Compare Pro (SWE-bench Pro, 20 pairs, multi-language)

20 patch pairs from Go/JS/TS/Python repositories (10 EQUIVALENT + 10 NOT_EQUIVALENT).

| | without skill | with skill | Delta |
|---|---|---|---|
| **Overall** (avg of 5 runs) | 59.0% | **69.0%** | **+10.0pp** |

### Key findings
- The skill provides consistent improvement on patch equivalence verification (+10.0pp).
- Primary improvement is in EQUIVALENT detection: without-skill models tend to over-predict NOT_EQUIVALENT.
- 46 iterations of automated self-improvement with genetic selection (score_prop) and meta-agent template evolution.
- The NO COUNTEREXAMPLE EXISTS template improvement (iter-46) was the most effective change, anchoring equivalence claims to observed semantic differences.

Raw outputs: [`benchmark/swebench/`](benchmark/swebench/)

## Repository Structure

```
├── SKILL.md                    # The skill (install this)
├── auto-improve.sh             # Automated self-improvement loop (Phase 1-3)
├── prompts/                    # Externalized prompt templates (Phase 3)
│   ├── manifest.json           # Template registry (vars, roles)
│   ├── propose-normal.txt      # Proposal prompt (normal mode)
│   ├── propose-escape.txt      # Proposal prompt (structural reform mode)
│   ├── discuss.txt             # Discussion/review prompt
│   ├── implement.txt           # Implementation prompt
│   ├── audit.txt               # Audit prompt
│   ├── revise.txt              # Revision prompt
│   ├── update-bl.txt           # Failed-approaches update prompt
│   └── meta-propose.txt        # Meta-agent prompt (edits other templates)
├── benchmark/
│   └── swebench/               # SWE-bench benchmark suite
│       ├── data/               # Benchmark inputs (pairs, tasks)
│       ├── runs/               # Results and archive.jsonl
│       ├── select_parent.py    # score_prop parent selection (HyperAgents)
│       ├── detect_stagnation.py # Stagnation detection for meta-agent trigger
│       └── append_archive_entry.py # Archive writer with template versioning
├── docs/
│   ├── design.md               # Design rationale
│   └── reference/              # Original paper PDF
├── Objective.md                # Experiment objectives and audit rubric
├── failed-approaches.md        # Accumulated failure principles
└── LICENSE
```

## License

See [LICENSE](LICENSE).
