#!/usr/bin/env bash
# SWE-bench Localize Benchmark — Multi-project version
# Clones repos on demand based on the "repo" field in tasks JSON
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_PATH="$REPO_ROOT/SKILL.md"
TASKS_JSON="$REPO_ROOT/benchmark/swebench/data/localize_tasks_multiproject.json"
TEMPLATE="$REPO_ROOT/benchmark/swebench/data/prompt_template_localize_medium.md"
RUNS_DIR="$REPO_ROOT/benchmark/swebench/runs/iter-1"
WORKSPACE="/tmp/bench_workspace"

MODEL="claude-haiku-4.5"
PROVIDER="github-copilot"
VARIANT_FILTER=""
LIMIT=0
OFFSET=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --variant) VARIANT_FILTER="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --offset) OFFSET="$2"; shift 2 ;;
    --runs-dir) RUNS_DIR="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --tasks) TASKS_JSON="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

ensure_repo() {
  local REPO_SLUG="$1"  # e.g. "sympy/sympy"
  local REPO_NAME="${REPO_SLUG//\//__}"  # e.g. "sympy__sympy"
  local REPO_DIR="$WORKSPACE/$REPO_NAME"
  if [ ! -d "$REPO_DIR" ]; then
    echo "=== Cloning $REPO_SLUG ===" >&2
    git clone --quiet "https://github.com/$REPO_SLUG.git" "$REPO_DIR"
  fi
  echo "$REPO_DIR"
}

run_single() {
  local INSTANCE="$1"
  local VARIANT="$2"
  local BASE_COMMIT="$3"
  local PROMPT_BODY="$4"
  local REPO_DIR="$5"
  local OUT_DIR="$RUNS_DIR/$INSTANCE/$VARIANT"

  if [ -f "$OUT_DIR/output.json" ]; then
    echo "[SKIP] $INSTANCE / $VARIANT"
    return
  fi
  mkdir -p "$OUT_DIR"

  local WORK_DIR="$WORKSPACE/worktrees/$INSTANCE"
  if [ ! -d "$WORK_DIR" ]; then
    git -C "$REPO_DIR" worktree add --quiet "$WORK_DIR" "$BASE_COMMIT" --detach 2>/dev/null || {
      git -C "$REPO_DIR" fetch --quiet origin "$BASE_COMMIT" 2>/dev/null || true
      git -C "$REPO_DIR" worktree add --quiet "$WORK_DIR" "$BASE_COMMIT" --detach
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

mkdir -p "$WORKSPACE"

# Build prompts and run
python3 -c "
import json, sys
tasks = json.load(open('$TASKS_JSON'))
template = open('$TEMPLATE').read()
for i, t in enumerate(tasks):
    prompt = template.format(
        repo=t['repo'],
        version=t['version'],
        base_commit=t['base_commit'],
        problem_statement=t['problem_statement'],
    )
    print(json.dumps({
        'index': i,
        'instance_id': t['instance_id'],
        'repo': t['repo'],
        'base_commit': t['base_commit'],
        'prompt': prompt,
    }))
" | {
  COUNT=0
  while IFS= read -r line; do
    IDX=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['index'])")
    INSTANCE=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['instance_id'])")
    REPO_SLUG=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['repo'])")
    BASE_COMMIT=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['base_commit'])")
    PROMPT_BODY=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['prompt'])")

    if [[ $IDX -lt $OFFSET ]]; then continue; fi

    REPO_DIR=$(ensure_repo "$REPO_SLUG")

    VARIANTS=("without_skill" "with_skill")
    if [[ -n "$VARIANT_FILTER" ]]; then VARIANTS=("$VARIANT_FILTER"); fi

    echo "--- [$((IDX+1))] $INSTANCE ($REPO_SLUG) ---"
    for V in "${VARIANTS[@]}"; do
      run_single "$INSTANCE" "$V" "$BASE_COMMIT" "$PROMPT_BODY" "$REPO_DIR"
    done

    COUNT=$((COUNT + 1))
    if [[ $LIMIT -gt 0 && $COUNT -ge $LIMIT ]]; then break; fi
  done

  echo ""
  echo "=== Multi-project Localize Benchmark complete: $COUNT instances ==="
}
