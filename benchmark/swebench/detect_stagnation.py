"""Detect stagnation in archive.jsonl scores."""
import json
import sys

archive_file = sys.argv[1]
window = int(sys.argv[2]) if len(sys.argv) > 2 else 5

entries = []
with open(archive_file) as f:
    for line in f:
        line = line.strip()
        if line:
            entries.append(json.loads(line))

# Only consider valid entries with scores
scored = [e for e in entries if e.get("valid_parent") and e["scores"].get("audit", 0) > 0]

if len(scored) < window:
    print("insufficient_data")
    sys.exit(1)

recent = scored[-window:]
all_scored = scored

# Best audit score ever achieved
best_audit_ever = max(e["scores"].get("audit", 0) for e in all_scored)
# Best audit in recent window
best_audit_recent = max(e["scores"].get("audit", 0) for e in recent)

# Stagnation: recent best doesn't exceed historical best
stagnant = best_audit_recent <= best_audit_ever and len(all_scored) > window

if stagnant:
    print("stagnant")
    sys.exit(0)
else:
    print("improving")
    sys.exit(1)
