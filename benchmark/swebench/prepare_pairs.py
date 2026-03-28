"""Prepare patch equivalence pairs from SWE-bench-Verified + experiments."""
import json
import random
import urllib.request
from pathlib import Path

from datasets import load_dataset

DATA_DIR = Path(__file__).parent / "data"
DATA_DIR.mkdir(exist_ok=True)

AGENT = "20240620_sweagent_claude3.5sonnet"
S3_BASE = "https://swe-bench-submissions.s3.amazonaws.com/verified"
N_EQUIV = 10
N_NOT_EQUIV = 10


def fetch_resolved_list():
    url = (
        "https://raw.githubusercontent.com/SWE-bench/experiments/main/"
        f"evaluation/verified/{AGENT}/results/results.json"
    )
    with urllib.request.urlopen(url) as r:
        return set(json.loads(r.read())["resolved"])


def fetch_agent_patch(instance_id):
    url = f"{S3_BASE}/{AGENT}/logs/{instance_id}/patch.diff"
    try:
        with urllib.request.urlopen(url) as r:
            return r.read().decode()
    except Exception:
        return None


def strip_reproduce_script(patch_text):
    """Remove reproduce.py additions from agent patches."""
    lines = patch_text.split("\n")
    result = []
    in_reproduce = False
    for line in lines:
        if line.startswith("diff --git") and "reproduce" in line.lower():
            in_reproduce = True
        elif line.startswith("diff --git"):
            in_reproduce = False
        if not in_reproduce:
            result.append(line)
    return "\n".join(result).strip()


def main():
    ds = load_dataset("princeton-nlp/SWE-bench_Verified", split="test")
    resolved = fetch_resolved_list()

    equiv_candidates = []
    not_equiv_candidates = []

    for item in ds:
        iid = item["instance_id"]
        patch_lines = item["patch"].count("\n")
        if item["repo"] != "django/django":
            continue
        if not (3 <= patch_lines <= 30):
            continue

        entry = {
            "instance_id": iid,
            "repo": item["repo"],
            "version": item["version"],
            "base_commit": item["base_commit"],
            "problem_statement": item["problem_statement"],
            "gold_patch": item["patch"],
            "fail_to_pass": json.loads(item["FAIL_TO_PASS"]),
        }

        if iid in resolved:
            equiv_candidates.append(entry)
        else:
            not_equiv_candidates.append(entry)

    print(f"EQUIV candidates: {len(equiv_candidates)}")
    print(f"NOT_EQUIV candidates: {len(not_equiv_candidates)}")

    random.seed(42)
    random.shuffle(equiv_candidates)
    random.shuffle(not_equiv_candidates)

    pairs = []
    for label, candidates, n in [
        ("EQUIVALENT", equiv_candidates, N_EQUIV),
        ("NOT_EQUIVALENT", not_equiv_candidates, N_NOT_EQUIV),
    ]:
        count = 0
        for entry in candidates:
            if count >= n:
                break
            agent_patch = fetch_agent_patch(entry["instance_id"])
            if agent_patch is None:
                continue
            entry["agent_patch"] = strip_reproduce_script(agent_patch)
            entry["ground_truth"] = label
            pairs.append(entry)
            count += 1
            print(f"  [{label}] {entry['instance_id']}")

    out = DATA_DIR / "pairs.json"
    out.write_text(json.dumps(pairs, indent=2, ensure_ascii=False))
    print(f"\nSaved {len(pairs)} pairs to {out}")


if __name__ == "__main__":
    main()
