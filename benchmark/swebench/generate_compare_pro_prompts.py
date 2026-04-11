"""Generate per-pair prompt files for Pro compare benchmark."""
import json
import sys
from pathlib import Path

pairs_json = sys.argv[1]
output_dir = sys.argv[2]

pairs = json.loads(Path(pairs_json).read_text())
Path(output_dir).mkdir(parents=True, exist_ok=True)

TEMPLATE = """You are comparing two code patches that attempt to fix the same bug.

## Task
Determine whether Change A (gold patch) and Change B (agent patch) produce the same behavioral outcome — specifically, whether they would cause the same tests to pass or fail.

## Bug Report (Problem Statement)
{problem_statement}

## Repository Information
- Repository: {repo}
- Language: {repo_language}
- Base commit: {base_commit}

## Failing Tests
These tests currently FAIL and should PASS after the fix:
{fail_to_pass}

## Change A (Gold Patch)
```diff
{gold_patch}
```

## Change B (Agent Patch)
```diff
{agent_patch}
```

## Instructions
1. Read the bug report to understand what needs to be fixed.
2. Analyze Change A to understand its approach.
3. Analyze Change B to understand its approach.
4. Determine whether both changes would cause the same test outcomes.
5. Consider edge cases that the tests exercise.

## Required Output
End your analysis with:

ANSWER: YES equivalent
or
ANSWER: NO not equivalent

CONFIDENCE: HIGH / MEDIUM / LOW
"""

for i, p in enumerate(pairs):
    prompt = TEMPLATE.format(
        repo=p["repo"],
        repo_language=p["repo_language"],
        base_commit=p["base_commit"],
        problem_statement=p["problem_statement"],
        fail_to_pass=json.dumps(p["fail_to_pass"]),
        gold_patch=p["gold_patch"],
        agent_patch=p["agent_patch"],
    )
    prompt_file = Path(output_dir) / f"prompt_{i:03d}.txt"
    prompt_file.write_text(prompt)

    manifest = {
        "index": i,
        "instance_id": p["instance_id"],
        "base_commit": p["base_commit"],
        "repo": p["repo"],
        "prompt_file": str(prompt_file),
    }
    manifest_file = Path(output_dir) / f"task_{i:03d}.json"
    manifest_file.write_text(json.dumps(manifest))

print(f"Generated {len(pairs)} prompt files in {output_dir}")
