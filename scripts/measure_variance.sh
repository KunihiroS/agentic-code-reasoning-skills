#!/usr/bin/env bash
# Reproducibility / variance measurement for SKILL.md
#
# iter-80 の SKILL.md.snapshot を使って、同じスキルで N 回ベンチマークを回し、
# overall accuracy のブレ幅 (ノイズ床) を測る。
#
# §8.2 ホールドアウトセット導入の前提検証。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

BASELINE_SNAPSHOT="benchmark/swebench/runs/iter-80/SKILL.md.snapshot"
BACKUP="/tmp/SKILL.md.premeasure"
N_RUNS=3
VARIANCE_DIR_PREFIX="$REPO_ROOT/benchmark/swebench/runs/variance"
SUMMARY="$REPO_ROOT/benchmark/swebench/runs/variance-summary.json"

if [ ! -f "$BASELINE_SNAPSHOT" ]; then
  echo "ERROR: baseline snapshot not found: $BASELINE_SNAPSHOT" >&2
  exit 1
fi

echo "=== variance measurement ==="
echo "  baseline: $BASELINE_SNAPSHOT"
echo "  runs: $N_RUNS"
echo "  variant: with_skill only"
date

# 1. Backup current SKILL.md
cp SKILL.md "$BACKUP"
echo "[1] current SKILL.md backed up to $BACKUP"

# 2. Restore baseline
cp "$BASELINE_SNAPSHOT" SKILL.md
echo "[2] restored iter-80 snapshot to SKILL.md (md5: $(md5sum SKILL.md | cut -c1-12))"

# 3. Run benchmark N times
for i in $(seq 1 "$N_RUNS"); do
  runs_dir="${VARIANCE_DIR_PREFIX}-${i}"
  echo ""
  echo "=== run $i / $N_RUNS → $runs_dir ==="
  date

  rm -rf "$runs_dir"
  mkdir -p "$runs_dir"

  bash benchmark/swebench/run_benchmark.sh \
    --variant with_skill \
    --runs-dir "$runs_dir" \
    2>&1 | tail -30

  # Grade
  python3 benchmark/swebench/grade.py "$runs_dir" \
    benchmark/swebench/data/pairs.json \
    2>&1 | tail -5 || true

  if [ -f "$runs_dir/grades.json" ]; then
    python3 -c "
import json, pathlib
g = json.loads(pathlib.Path('$runs_dir/grades.json').read_text())
ws = [r for r in g if r['variant']=='with_skill']
c = sum(1 for r in ws if r['correct'])
t = len(ws)
print(f'  result: {c}/{t} = {c/t:.1%}' if t else '  result: no data')
"
  else
    echo "  WARN: no grades.json produced"
  fi
done

# 4. Restore original SKILL.md
cp "$BACKUP" SKILL.md
echo ""
echo "[4] restored original SKILL.md"

# 5. Summary
echo ""
echo "=== SUMMARY ==="
python3 <<PYEOF
import json, pathlib, statistics
rows = []
for i in range(1, $N_RUNS + 1):
    gp = pathlib.Path(f"${VARIANCE_DIR_PREFIX}-{i}/grades.json")
    if not gp.exists():
        continue
    g = json.loads(gp.read_text())
    ws = [r for r in g if r["variant"]=="with_skill"]
    per = {r["instance_id"]: r["correct"] for r in ws}
    c = sum(1 for r in ws if r["correct"])
    t = len(ws)
    rows.append({"run": i, "correct": c, "total": t, "acc_pct": round(100*c/t,1) if t else None, "per_case": per})

if rows:
    accs = [r["acc_pct"] for r in rows if r["acc_pct"] is not None]
    print(f"runs: {len(rows)}")
    for r in rows:
        print(f"  run {r['run']}: {r['correct']}/{r['total']} = {r['acc_pct']}%")
    if len(accs) >= 2:
        print(f"mean:  {statistics.mean(accs):.2f}%")
        print(f"stdev: {statistics.stdev(accs):.2f}%")
        print(f"min:   {min(accs)}%")
        print(f"max:   {max(accs)}%")
        print(f"range: {max(accs)-min(accs):.1f}pp")

    # per-case flip analysis
    all_cases = sorted(set().union(*[set(r["per_case"]) for r in rows]))
    flips = []
    for case in all_cases:
        vals = [r["per_case"].get(case) for r in rows]
        if None in vals: continue
        if len(set(vals)) > 1:
            flips.append((case, vals))
    print(f"flipping cases (不安定ケース): {len(flips)}/{len(all_cases)}")
    for case, vals in flips:
        print(f"  {case}: {['✓' if v else '✗' for v in vals]}")

pathlib.Path("$SUMMARY").write_text(json.dumps(rows, indent=2))
print(f"\nsaved: $SUMMARY")
PYEOF

echo ""
echo "=== DONE ==="
date
