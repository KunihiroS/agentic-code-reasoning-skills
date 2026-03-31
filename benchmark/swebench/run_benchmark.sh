#!/usr/bin/env bash
# SWE-bench Patch Equivalence Benchmark
# Usage:
#   bash benchmark/swebench/run_benchmark.sh                          # all pairs, both variants
#   bash benchmark/swebench/run_benchmark.sh --offset 0 --limit 5     # batch 1
#   bash benchmark/swebench/run_benchmark.sh --variant with_skill      # one variant only
#   bash benchmark/swebench/run_benchmark.sh --instance django__django-11490
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_PATH="$REPO_ROOT/SKILL.md"
PAIRS_JSON="$REPO_ROOT/benchmark/swebench/data/pairs.json"
TEMPLATE="$REPO_ROOT/benchmark/swebench/data/prompt_template.md"
RUNS_DIR="$REPO_ROOT/benchmark/swebench/runs/iter-1"
DJANGO_REPO="/tmp/bench_workspace/django"

MODEL="haiku"
VARIANT_FILTER=""
LIMIT=0
OFFSET=0
INSTANCE_FILTER=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --variant) VARIANT_FILTER="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --offset) OFFSET="$2"; shift 2 ;;
    --instance) INSTANCE_FILTER="$2"; shift 2 ;;
    --runs-dir) RUNS_DIR="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# Ensure django clone exists
if [ ! -d "$DJANGO_REPO" ]; then
  echo "=== Cloning django ==="
  git clone --quiet https://github.com/django/django.git "$DJANGO_REPO"
fi

run_single() {
  local INSTANCE="$1"
  local VARIANT="$2"
  local BASE_COMMIT="$3"
  local PROMPT_BODY="$4"
  local OUT_DIR="$RUNS_DIR/$INSTANCE/$VARIANT"

  if [ -f "$OUT_DIR/output.json" ]; then
    echo "[SKIP] $INSTANCE / $VARIANT"
    return
  fi
  mkdir -p "$OUT_DIR"

  # Checkout via worktree
  local WORK_DIR="/tmp/bench_workspace/worktrees/$INSTANCE"
  if [ ! -d "$WORK_DIR" ]; then
    git -C "$DJANGO_REPO" worktree add --quiet "$WORK_DIR" "$BASE_COMMIT" --detach 2>/dev/null || {
      git -C "$DJANGO_REPO" fetch --quiet origin "$BASE_COMMIT" 2>/dev/null || true
      git -C "$DJANGO_REPO" worktree add --quiet "$WORK_DIR" "$BASE_COMMIT" --detach
    }
  fi

  local FULL_PROMPT
  if [[ "$VARIANT" == "with_skill" ]]; then
    FULL_PROMPT="まず以下のスキルを読み、その手順に厳密に従って分析してください。スキルの 'compare' モードを使用してください。

---SKILL START---
$(cat "$SKILL_PATH")
---SKILL END---

$PROMPT_BODY"
  else
    FULL_PROMPT="$PROMPT_BODY"
  fi

  echo "[START] $INSTANCE / $VARIANT  $(date '+%H:%M:%S')"
  local START_SEC=$(date +%s)

  cd "$WORK_DIR"
  echo "$FULL_PROMPT" | claude --model "$MODEL" \
    --print \
    --output-format json \
    --permission-mode bypassPermissions \
    --max-turns 30 \
    > "$OUT_DIR/output.json" 2> "$OUT_DIR/stderr.log" || true
  cd "$REPO_ROOT"

  local END_SEC=$(date +%s)
  local DURATION=$(( END_SEC - START_SEC ))

  # Extract text from JSON
  python3 -c "
import json
try:
    d = json.load(open('$OUT_DIR/output.json'))
    print(d.get('result', ''))
except: print(open('$OUT_DIR/output.json').read())
" > "$OUT_DIR/output.md" 2>/dev/null || true

  # Step 5.5: External Audit Gate (with_skill only)
  local REVIEWER_SCRIPT="$REPO_ROOT/benchmark/swebench/invoke_reviewer.sh"
  if [[ "$VARIANT" == "with_skill" ]] && [[ -f "$REVIEWER_SCRIPT" ]]; then
    bash "$REVIEWER_SCRIPT" "$OUT_DIR/output.md" \
      > "$OUT_DIR/review.md" 2>> "$OUT_DIR/stderr.log" || true
  fi

  printf '{"instance":"%s","variant":"%s","model":"%s","duration_sec":%d}\n' \
    "$INSTANCE" "$VARIANT" "$MODEL" "$DURATION" > "$OUT_DIR/timing.json"

  echo "[DONE]  $INSTANCE / $VARIANT  ${DURATION}s"
}

# Build prompts from pairs.json and run
source "$REPO_ROOT/.venv/bin/activate" 2>/dev/null || true

python3 -c "
import signal, sys
signal.signal(signal.SIGPIPE, signal.SIG_DFL)
import json
pairs = json.load(open('$PAIRS_JSON'))
template = open('$TEMPLATE').read()
for i, p in enumerate(pairs):
    prompt = template.format(
        repo=p['repo'],
        version=p['version'],
        base_commit=p['base_commit'],
        problem_statement=p['problem_statement'],
        gold_patch=p['gold_patch'],
        agent_patch=p['agent_patch'],
        fail_to_pass=json.dumps(p['fail_to_pass']),
    )
    print(json.dumps({
        'index': i,
        'instance_id': p['instance_id'],
        'base_commit': p['base_commit'],
        'ground_truth': p['ground_truth'],
        'prompt': prompt,
    }))
" | {
  COUNT=0
  while IFS= read -r line; do
    IDX=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['index'])")
    INSTANCE=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['instance_id'])")
    BASE_COMMIT=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['base_commit'])")
    GT=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['ground_truth'])")
    PROMPT_BODY=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['prompt'])")

    # Apply offset
    if [[ $IDX -lt $OFFSET ]]; then continue; fi

    # Apply instance filter
    if [[ -n "$INSTANCE_FILTER" && "$INSTANCE" != "$INSTANCE_FILTER" ]]; then continue; fi

    VARIANTS=("without_skill" "with_skill")
    if [[ -n "$VARIANT_FILTER" ]]; then VARIANTS=("$VARIANT_FILTER"); fi

    echo "--- [$((IDX+1))] $INSTANCE ($GT) ---"
    for V in "${VARIANTS[@]}"; do
      run_single "$INSTANCE" "$V" "$BASE_COMMIT" "$PROMPT_BODY"
    done

    COUNT=$((COUNT + 1))
    if [[ $LIMIT -gt 0 && $COUNT -ge $LIMIT ]]; then break; fi
  done

  echo ""
  echo "=== Benchmark complete: $COUNT instances ==="
}
