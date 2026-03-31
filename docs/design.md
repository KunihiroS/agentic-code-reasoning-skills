# Paper to Skill Design Interpretation

## The paper's core insight

The paper defines **semi-formal reasoning** as a middle ground between unstructured chain-of-thought and fully formal verification. The key finding is that when an agent is given a structured template requiring explicit premises, per-item code tracing, and a formal conclusion, accuracy improves by 5–12 percentage points across all three tasks.

The central idea is that these templates act as *certificates*: they make it harder for the agent to skip steps or make unsupported claims.

## What was extracted from the paper

The paper evaluates three tasks, each with its own appendix template:

| Paper Task | Appendix | What the template enforces |
|------------|----------|---------------------------|
| Patch Equivalence Verification | Appendix A | Per-test iteration, formal definitions of equivalence, counterexample obligation |
| Fault Localization | Appendix B | 4-phase pipeline (Premises → Code Path Tracing → Divergence Analysis → Ranked Predictions), hypothesis-driven exploration |
| Code Question Answering | Appendix D | Function trace table with VERIFIED behavior, data flow tracking, alternative hypothesis check |

Beyond the templates, the paper also documents recurring failure patterns that semi-formal reasoning is designed to prevent:

| Failure Pattern | Paper Section | How it manifests |
|-----------------|---------------|------------------|
| Function name guessing | §4.1.1 | The agent assumes a familiar meaning from the name instead of reading the real definition |
| Symptom vs root cause confusion | Case Study §C | The agent stops at the crash site instead of tracing upstream to the bad state origin |
| Incomplete reasoning chains | §4.3 Error Analysis | The agent traces multiple functions but misses downstream handling |
| Third-party library guessing | §4.1.1 | The agent guesses library behavior when source is unavailable |
| Subtle difference dismissal | §4.1.1 | The agent finds a semantic difference but incorrectly decides it will not affect outcomes |

## How this repository translates the paper into one skill

### Shared core method

The appendix templates share the same high-level pattern:

1. state premises
2. gather evidence iteratively
3. check counterexamples or alternative hypotheses
4. derive a formal conclusion

This repository extracts that common structure into a shared core method used by all modes.

### Per-item iteration as the anti-skip mechanism

Each task in the paper forces the agent to iterate over concrete items:

- per-test in patch equivalence
- per-method in fault localization
- per-function in code QA

That loop structure is the main mechanism that prevents premature conclusions, so it is preserved explicitly in the skill templates.

### Interprocedural tracing as structure, not advice

The paper argues that structured templates naturally encourage interprocedural reasoning. In practice, this means the skill should not merely say “read the definitions”; it should require verified behavior records that make skipping definitions visibly incomplete.

### Why there is a fourth mode

The paper's future work explicitly points to related tasks such as:

- security vulnerability detection
- code smell identification
- API misuse detection

This repository adds `audit-improve` as a practical extension of the same reasoning discipline.

### Turning error analysis into guardrails

The paper's failure analysis is treated here as a design input, not just an observation. Each recurring error mode is translated into a concrete guardrail so the skill addresses the known weaknesses directly.

## What this repository intentionally does not do

- It does not use language-specific templates.
- It does not rely on executing repository code.
- It does not use post-hoc proof checking or external verification layers.

The design goal is to improve reasoning on the input side by constraining the analysis process itself.
