"""Generate localize benchmark tasks from existing pairs.json.

Extracts ground truth file paths and function names from gold_patch diffs.
Output: benchmark/swebench/data/localize_tasks.json
"""
import json
import re
import sys
from pathlib import Path

def extract_ground_truth(gold_patch: str) -> dict:
    """Extract files and functions modified by the gold patch."""
    files = re.findall(r"^diff --git a/(\S+)", gold_patch, re.MULTILINE)
    # Hunk headers often contain the enclosing function/class name
    funcs = re.findall(r"^@@.*@@\s+(?:def|class)\s+(\w+)", gold_patch, re.MULTILINE)
    # Also extract added/modified def/class names from the patch body
    # (catches cases where the hunk header shows the parent but the actual
    #  change is a new method or class being added)
    added_defs = re.findall(r"^\+\s*(?:def|class)\s+(\w+)", gold_patch, re.MULTILINE)
    funcs = list(dict.fromkeys(funcs + added_defs))
    # Deduplicate
    files = list(dict.fromkeys(files))
    return {"files": files, "functions": funcs}

def main():
    repo_root = Path(__file__).resolve().parent.parent
    pairs_path = repo_root / "benchmark" / "swebench" / "data" / "pairs.json"
    out_path = repo_root / "benchmark" / "swebench" / "data" / "localize_tasks.json"

    pairs = json.loads(pairs_path.read_text())
    tasks = []
    for p in pairs:
        gt = extract_ground_truth(p["gold_patch"])
        tasks.append({
            "instance_id": p["instance_id"],
            "repo": p["repo"],
            "version": p["version"],
            "base_commit": p["base_commit"],
            "problem_statement": p["problem_statement"],
            "fail_to_pass": p["fail_to_pass"],
            "ground_truth_files": gt["files"],
            "ground_truth_functions": gt["functions"],
        })

    out_path.write_text(json.dumps(tasks, indent=2, ensure_ascii=False))
    print(f"Generated {len(tasks)} localize tasks → {out_path}")
    for t in tasks:
        print(f"  {t['instance_id']}: files={t['ground_truth_files']}, funcs={t['ground_truth_functions']}")

if __name__ == "__main__":
    main()
