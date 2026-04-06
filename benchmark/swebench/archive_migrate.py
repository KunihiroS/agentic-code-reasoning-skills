#!/usr/bin/env python3
"""
archive_migrate.py — 既存の iter-{N}/ ディレクトリから archive.jsonl を構築する。

各ノード:
  {
    "genid": N,
    "parent_genid": M or null,
    "skill_snapshot": "runs/iter-N/SKILL.md.snapshot" or null,
    "scores": {"overall": int, "equiv": "a/b", "not_eq": "a/b", "unknown": int, "correct": int, "total": int},
    "valid_parent": bool,
    "timestamp": ISO8601
  }

iter-1 はベースライン。SKILL.md.snapshot が無いので main の SKILL.md を参照する扱いにする。
iter-6..N は auto-improve ループからのエントリ。
"""
import json, argparse, datetime
from pathlib import Path

def compute_scores(grades_path):
    d = json.load(open(grades_path))
    ws = [x for x in d if x.get("variant") == "with_skill"]
    if not ws:
        return None
    correct = sum(1 for x in ws if x.get("correct"))
    total = len(ws)
    eq_total = sum(1 for x in ws if x.get("ground_truth") == "EQUIVALENT")
    neq_total = sum(1 for x in ws if x.get("ground_truth") == "NOT_EQUIVALENT")
    eq_ok = sum(1 for x in ws if x.get("ground_truth") == "EQUIVALENT" and x.get("correct"))
    neq_ok = sum(1 for x in ws if x.get("ground_truth") == "NOT_EQUIVALENT" and x.get("correct"))
    unk = sum(1 for x in ws if x.get("predicted") in (None, "UNKNOWN"))
    return {
        "overall": int(100 * correct / total) if total else 0,
        "equiv_ok": eq_ok,
        "equiv_total": eq_total,
        "not_eq_ok": neq_ok,
        "not_eq_total": neq_total,
        "unknown": unk,
        "correct": correct,
        "total": total,
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs-dir", default="benchmark/swebench/runs")
    ap.add_argument("--out", default="benchmark/swebench/runs/archive.jsonl")
    ap.add_argument("--start", type=int, default=1)
    ap.add_argument("--end", type=int, default=100)
    args = ap.parse_args()

    runs = Path(args.runs_dir)
    entries = []

    # iter-1: baseline, use scores from grades.json, no snapshot (fallback to main's SKILL.md)
    for i in range(args.start, args.end + 1):
        it = runs / f"iter-{i}"
        if not it.is_dir():
            continue

        grades = it / "grades.json"
        scores_file = it / "scores.json"
        snap = it / "SKILL.md.snapshot"

        # Prefer scores.json (newer), fallback to grades.json
        src = scores_file if scores_file.exists() else grades
        if not src.exists():
            continue

        scores = compute_scores(src)
        if scores is None:
            continue

        # parent: for iter-1, no parent. For others, previous iter in the archive.
        parent_genid = entries[-1]["genid"] if entries else None

        entry = {
            "genid": i,
            "parent_genid": parent_genid,
            "skill_snapshot": str(snap.relative_to(runs.parent.parent)) if snap.exists() else None,
            "scores": scores,
            "valid_parent": snap.exists(),  # Only iterations with snapshot can be restored
            "timestamp": datetime.datetime.fromtimestamp(src.stat().st_mtime).isoformat(),
        }
        entries.append(entry)

    # Write archive
    out = Path(args.out)
    with open(out, "w") as f:
        for e in entries:
            f.write(json.dumps(e, ensure_ascii=False) + "\n")

    print(f"Wrote {len(entries)} entries to {out}")
    valid = sum(1 for e in entries if e["valid_parent"])
    print(f"  Valid parents (with snapshot): {valid}")
    print(f"  Top scores:")
    for e in sorted(entries, key=lambda x: -x["scores"]["overall"])[:10]:
        print(f"    iter-{e['genid']}: {e['scores']['overall']}% (EQ {e['scores']['equiv_ok']}/{e['scores']['equiv_total']}, NEQ {e['scores']['not_eq_ok']}/{e['scores']['not_eq_total']}) snapshot={'yes' if e['valid_parent'] else 'NO'}")

if __name__ == "__main__":
    main()
