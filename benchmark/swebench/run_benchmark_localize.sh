#!/usr/bin/env bash
# SWE-bench Localize Benchmark
# Usage:
#   bash benchmark/swebench/run_benchmark_localize.sh
#   bash benchmark/swebench/run_benchmark_localize.sh --variant with_skill
#   bash benchmark/swebench/run_benchmark_localize.sh --fast-subset
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_PATH="$REPO_ROOT/SKILL.md"
TASKS_JSON="$REPO_ROOT/benchmark/swebench/data/localize_tasks.json"
TEMPLATE="$REPO_ROOT/benchmark/swebench/data/prompt_template_localize.md"
RUNS_DIR="$REPO_ROOT/benchmark/swebench/runs/iter-1"
DJANGO_REPO="/tmp/bench_workspace/django"

MODEL="claude-haiku-4.5"
PROVIDER="github-copilot"
VARIANT_FILTER=""
LIMIT=0
OFFSET=0
INSTANCE_FILTER=""
FAST_SUBSET=0

# Staged eval subset (same instances as compare for consistency)
FAST_SUBSET_INSTANCES="django__django-15368 django__django-14089 django__django-15315 django__django-13417 django__django-11999"

while [[ $# -gt 0 ]]; do
  case $1 in
    --variant) VARIANT_FILTER="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --offset) OFFSET="$2"; shift 2 ;;
    --instance) INSTANCE_FILTER="$2"; shift 2 ;;
    --runs-dir) RUNS_DIR="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --fast-subset) FAST_SUBSET=1; shift ;;
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
    FULL_PROMPT="まず以下のスキルを読み、その手順に厳密に従って分析してください。スキルの 'localize' モードを使用してください。

---SKILL START---
$(cat "$SKILL_PATH")
---SKILL END---

$PROMPT_BODY"
  else
    FULL_PROMPT="$PROMPT_BODY"
  fi

  echo "[START] $INSTANCE / $VARIANT  $(date '+%H:%M:%S')"
  local START_SEC=$(date +%s)

  echo "$FULL_PROMPT" > "$OUT_DIR/prompt.txt"

  cd "$WORK_DIR"
  pi -p --no-session \
    --provider "$PROVIDER" \
    --model "$MODEL" \
    --max-turns 30 \
    "@$OUT_DIR/prompt.txt" \
    < /dev/null \
    > "$OUT_DIR/output.md" 2> "$OUT_DIR/stderr.log" || true
  cd "$REPO_ROOT"

  local END_SEC=$(date +%s)
  local DURATION=$(( END_SEC - START_SEC ))

  # Stub output.json for grade compatibility
  python3 -c "
import json
try:
    text = open('$OUT_DIR/output.md').read()
except:
    text = ''
json.dump({'total_cost_usd': 0, 'num_turns': 0, 'duration_seconds': $DURATION, 'output_length': len(text)},
          open('$OUT_DIR/output.json', 'w'), indent=2)
"
  echo "[DONE]  $INSTANCE / $VARIANT  ${DURATION}s"
}

# Build prompts from localize_tasks.json and run
source "$REPO_ROOT/.venv/bin/activate" 2>/dev/null || true

python3 -c "
import signal, sys
signal.signal(signal.SIGPIPE, signal.SIG_DFL)
import json
tasks = json.load(open('$TASKS_JSON'))
template = open('$TEMPLATE').read()
for i, t in enumerate(tasks):
    prompt = template.format(
        repo=t['repo'],
        version=t['version'],
        base_commit=t['base_commit'],
        problem_statement=t['problem_statement'],
        fail_to_pass=json.dumps(t['fail_to_pass']),
    )
    print(json.dumps({
        'index': i,
        'instance_id': t['instance_id'],
        'base_commit': t['base_commit'],
        'prompt': prompt,
    }))
" | {
  COUNT=0
  while IFS= read -r line; do
    IDX=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['index'])")
    INSTANCE=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['instance_id'])")
    BASE_COMMIT=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['base_commit'])")
    PROMPT_BODY=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['prompt'])")

    if [[ $IDX -lt $OFFSET ]]; then continue; fi
    if [[ -n "$INSTANCE_FILTER" && "$INSTANCE" != "$INSTANCE_FILTER" ]]; then continue; fi
    if [[ "$FAST_SUBSET" -eq 1 ]]; then
      if ! [[ " $FAST_SUBSET_INSTANCES " == *" $INSTANCE "* ]]; then continue; fi
    fi

    VARIANTS=("without_skill" "with_skill")
    if [[ -n "$VARIANT_FILTER" ]]; then VARIANTS=("$VARIANT_FILTER"); fi

    echo "--- [$((IDX+1))] $INSTANCE ---"
    for V in "${VARIANTS[@]}"; do
      run_single "$INSTANCE" "$V" "$BASE_COMMIT" "$PROMPT_BODY"
    done

    COUNT=$((COUNT + 1))
    if [[ $LIMIT -gt 0 && $COUNT -ge $LIMIT ]]; then break; fi
  done

  echo ""
  echo "=== Localize Benchmark complete: $COUNT instances ==="
}
