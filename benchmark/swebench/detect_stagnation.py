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

# Only consider new-format entries (with template_version) that have scores
scored = [
    e for e in entries
    if "template_version" in e
    and e.get("valid_parent")
    and e["scores"].get("compare", 0) > 0
]

if len(scored) < window:
    print("insufficient_data")
    sys.exit(1)

recent = scored[-window:]

# Best scores across all new-format scored entries
best_compare_ever = max(e["scores"].get("compare", 0) for e in scored)
best_compare_recent = max(e["scores"].get("compare", 0) for e in recent)

# Stagnation: compare has not improved in the recent window
stagnant = (
    best_compare_recent < best_compare_ever
    and len(scored) > window
)

if stagnant:
    print("stagnant")
    sys.exit(0)
else:
    print("improving")
    sys.exit(1)
