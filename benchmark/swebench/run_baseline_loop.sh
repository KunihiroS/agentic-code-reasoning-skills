#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
BASELINE_DIR="benchmark/swebench/runs/baseline-gpt54"
mkdir -p "$BASELINE_DIR"

run=1
while true; do
  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] === Run $run START ==="

  RUN_DIR="$BASELINE_DIR/run-$run"
  mkdir -p "$RUN_DIR"

  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] Compare Pro..."
  bash benchmark/swebench/run_benchmark_compare_pro.sh --runs-dir "$RUN_DIR/compare" > "$RUN_DIR/compare.log" 2>&1 || true
  python3 benchmark/swebench/grade_compare_pro.py "$RUN_DIR/compare" benchmark/swebench/data/pro_compare/pairs_pro.json > "$RUN_DIR/grade-compare.log" 2>&1 || true

  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] === Run $run DONE ==="
  cat "$RUN_DIR/grade-compare.log" 2>/dev/null
  echo

  # worktree cleanup
  rm -rf "$HOME/bench_workspace/worktrees/"* "$HOME/bench_workspace/worktrees_compare/"* 2>/dev/null || true
  for _repo in "$HOME/bench_workspace/repos/"*/; do
    git -C "$_repo" worktree prune 2>/dev/null || true
  done

  run=$((run + 1))
done
