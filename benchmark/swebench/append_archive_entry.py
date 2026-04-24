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

# Template version tracking (Phase 3)
import hashlib
import glob

prompts_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "prompts")
version_file = os.path.join(prompts_dir, ".version")
template_version = 0
if os.path.isfile(version_file):
    try:
        template_version = int(open(version_file).read().strip())
    except (ValueError, IOError):
        pass

template_hash = ""
tpl_files = sorted(glob.glob(os.path.join(prompts_dir, "*.txt")))
if tpl_files:
    h = hashlib.sha256()
    for tf in tpl_files:
        h.update(open(tf, "rb").read())
    template_hash = h.hexdigest()[:16]

entry = {
    "genid": genid,
    "parent_genid": parent_genid,
    "skill_snapshot": snap_path if snap_exists else None,
    "scores": {
        "compare": compare_score,
        "audit": audit_score,
        "overall": compare_score if audit_score == 0 else min(compare_score, audit_score),
    },
    "valid_parent": (valid_parent == "true") and snap_exists,
    "template_version": template_version,
    "template_hash": template_hash,
    "timestamp": datetime.datetime.now().isoformat(),
}

with open(archive_file, "a") as f:
    f.write(json.dumps(entry, ensure_ascii=False) + "\n")
