You are evaluating whether two code patches produce the same test outcomes.

## Task
Given two patches (Patch A = gold reference, Patch B = agent-generated) that both attempt to fix the same bug in {repo}, determine whether they are **EQUIVALENT MODULO TESTS** — i.e., whether applying either patch would produce identical pass/fail outcomes on the repository's test suite.

## Bug Report (Problem Statement)
{problem_statement}

## Repository Information
- Repository: {repo}
- Version: {version}
- Base commit: {base_commit}

## Patch A (Gold Reference)
```diff
{gold_patch}
```

## Patch B (Agent-Generated)
```diff
{agent_patch}
```

## Relevant Tests
- FAIL_TO_PASS: {fail_to_pass}

## Instructions
1. Read the relevant source file(s) that both patches modify.
2. Analyze both patches to understand what each one changes.
3. Determine if both patches would cause the FAIL_TO_PASS tests to pass.
4. Determine if either patch could break any existing tests.

## Required Output
End your analysis with a clear verdict on the LAST line:
ANSWER: YES (equivalent) or NO (not equivalent)
