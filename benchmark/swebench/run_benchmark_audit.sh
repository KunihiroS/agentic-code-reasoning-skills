#!/usr/bin/env bash
# SWE-bench Audit-Improve Benchmark (security_bug subset)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_PATH="$REPO_ROOT/SKILL.md"
TASKS_JSON="$REPO_ROOT/benchmark/swebench/data/audit_tasks_security.json"
TEMPLATE="$REPO_ROOT/benchmark/swebench/data/prompt_template_audit.md"
RUNS_DIR="$REPO_ROOT/benchmark/swebench/runs/audit-security-1"
WORKSPACE="$HOME/bench_workspace"

MODEL="gpt-5.4"
PROVIDER="openai-codex"
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
    --runs-dir) RUNS_DIR="$(cd "$REPO_ROOT" && realpath "$2")"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

clone_repo() {
  local REPO="$1"
  local REPO_DIR="$WORKSPACE/repos/$(echo "$REPO" | tr "/" "_")"
  if [ ! -d "$REPO_DIR" ]; then
    echo "=== Cloning $REPO ===" >&2
    mkdir -p "$WORKSPACE/repos"
    git clone --quiet "https://github.com/$REPO.git" "$REPO_DIR"
  fi
  printf '%s' "$REPO_DIR"
}

run_single() {
  local INSTANCE="$1"
  local VARIANT="$2"
  local BASE_COMMIT="$3"
  local PROMPT_FILE="$4"
  local REPO="$5"
  local OUT_DIR="$RUNS_DIR/$INSTANCE/$VARIANT"

  if [ -f "$OUT_DIR/output.json" ]; then
    echo "[SKIP] $INSTANCE / $VARIANT"
    return
  fi
  mkdir -p "$OUT_DIR"

  local REPO_DIR
  REPO_DIR=$(clone_repo "$REPO")
  local WORK_DIR="$WORKSPACE/worktrees/$INSTANCE"
  if [ ! -d "$WORK_DIR" ]; then
    git -C "$REPO_DIR" worktree add --quiet "$WORK_DIR" "$BASE_COMMIT" --detach 2>/dev/null || {
      git -C "$REPO_DIR" fetch --quiet origin "$BASE_COMMIT" 2>/dev/null || true
      git -C "$REPO_DIR" worktree add --quiet "$WORK_DIR" "$BASE_COMMIT" --detach
    }
  fi

  # Build prompt file
  if [[ "$VARIANT" == "with_skill" ]]; then
    {
      echo "まず以下のスキルを読み、その手順に厳密に従って分析してください。スキルの 'audit-improve' モードの 'security-audit' サブモードを使用してください。"
      echo ""
      echo "---SKILL START---"
      cat "$SKILL_PATH"
      echo "---SKILL END---"
      echo ""
      cat "$PROMPT_FILE"
    } > "$OUT_DIR/prompt.txt"
  else
    cp "$PROMPT_FILE" "$OUT_DIR/prompt.txt"
  fi

  echo "[START] $INSTANCE / $VARIANT  $(date '+%H:%M:%S')"
  local START_SEC=$(date +%s)

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

  python3 "$REPO_ROOT/benchmark/swebench/write_output_json.py" "$OUT_DIR" "$DURATION"
  echo "[DONE]  $INSTANCE / $VARIANT  ${DURATION}s"
}

# Generate per-task prompt files, then run
PROMPT_TMPDIR=$(mktemp -d)
python3 "$REPO_ROOT/benchmark/swebench/generate_audit_prompts.py" \
  "$TASKS_JSON" "$TEMPLATE" "$PROMPT_TMPDIR"

COUNT=0
TOTAL_START=$(date +%s)

for MANIFEST in "$PROMPT_TMPDIR"/*.json; do
  IDX=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(d['index'])")
  INSTANCE=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(d['instance_id'])")
  BASE_COMMIT=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(d['base_commit'])")
  REPO=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(d['repo'])")
  PROMPT_FILE=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(d['prompt_file'])")

  if [[ $IDX -lt $OFFSET ]]; then continue; fi
  if [[ -n "$INSTANCE_FILTER" && "$INSTANCE" != "$INSTANCE_FILTER" ]]; then continue; fi

  VARIANTS=("without_skill" "with_skill")
  if [[ -n "$VARIANT_FILTER" ]]; then VARIANTS=("$VARIANT_FILTER"); fi

  echo ""
  echo "--- [$((COUNT+1))] $INSTANCE ($REPO) ---"
  for V in "${VARIANTS[@]}"; do
    run_single "$INSTANCE" "$V" "$BASE_COMMIT" "$PROMPT_FILE" "$REPO"
  done

  COUNT=$((COUNT + 1))
  if [[ $LIMIT -gt 0 && $COUNT -ge $LIMIT ]]; then break; fi
done

rm -rf "$PROMPT_TMPDIR"

TOTAL_END=$(date +%s)
TOTAL_DURATION=$(( TOTAL_END - TOTAL_START ))
echo ""
echo "=== Audit Benchmark complete: $COUNT instances, ${TOTAL_DURATION}s total ==="
