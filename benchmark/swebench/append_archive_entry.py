"""Append an entry to archive.jsonl with dual scores."""
import json
import datetime
import os.path
import sys

archive_file = sys.argv[1]
genid = int(sys.argv[2])
parent_genid = int(sys.argv[3]) if sys.argv[3] else None
compare_json = sys.argv[4] if len(sys.argv) > 4 else ""
audit_json = sys.argv[5] if len(sys.argv) > 5 else ""
valid_parent = sys.argv[6] if len(sys.argv) > 6 else "false"


def calc_score(path):
    if not path or not os.path.isfile(path):
        return 0
    try:
        data = json.load(open(path))
    except Exception:
        return 0
    ws = [x for x in data if x.get("variant") == "with_skill"]
    if not ws:
        return 0
    correct = sum(1 for x in ws if x.get("correct"))
    return int(100 * correct / len(ws))


compare_score = calc_score(compare_json)
audit_score = calc_score(audit_json)

snap_path = f"benchmark/swebench/runs/iter-{genid}/SKILL.md.snapshot"
snap_exists = os.path.isfile(snap_path)

entry = {
    "genid": genid,
    "parent_genid": parent_genid,
    "skill_snapshot": snap_path if snap_exists else None,
    "scores": {
        "compare": compare_score,
        "audit": audit_score,
        "overall": min(compare_score, audit_score),
    },
    "valid_parent": (valid_parent == "true") and snap_exists,
    "timestamp": datetime.datetime.now().isoformat(),
}

with open(archive_file, "a") as f:
    f.write(json.dumps(entry, ensure_ascii=False) + "\n")
