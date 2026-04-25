#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_PATH="$REPO_ROOT/SKILL.md"
TASKS_JSON="$REPO_ROOT/benchmark/swebench/data/explain_tasks.json"
TEMPLATE="$REPO_ROOT/benchmark/swebench/data/prompt_template_explain.md"
JUDGE_RUBRIC="$REPO_ROOT/benchmark/swebench/data/judge_rubric_explain.md"
RUNS_DIR="$REPO_ROOT/benchmark/swebench/runs/explain-1"
WORKSPACE="$HOME/bench_workspace"

# Benchmark model
MODEL="gpt-5.4-mini"
PROVIDER="openai-codex"

# Judge model
JUDGE_MODEL="gpt-5.4"
JUDGE_PROVIDER="openai-codex"

VARIANT_FILTER=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --runs-dir) RUNS_DIR="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --provider) PROVIDER="$2"; shift 2 ;;
    --variant) VARIANT_FILTER="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

mkdir -p "$RUNS_DIR"

TASK_COUNT=$(python3 -c "import json; print(len(json.load(open('$TASKS_JSON'))))")
echo "Running explain benchmark: $TASK_COUNT tasks, model=$MODEL"

run_task() {
  local idx="$1"
  local task_json
  task_json=$(python3 -c "
import json
tasks = json.load(open('$TASKS_JSON'))
t = tasks[$idx]
print(json.dumps(t))
")

  local TASK_ID=$(echo "$task_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['task_id'])")
  local REPO=$(echo "$task_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo'])")
  local REPO_LANG=$(echo "$task_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_language'])")
  local BASE_COMMIT=$(echo "$task_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['base_commit'])")
  local QUESTION=$(echo "$task_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['question'])")
  local GT=$(echo "$task_json" | python3 -c "
import json,sys
t = json.load(sys.stdin)
files = t.get('ground_truth_files', [])
funcs = t.get('ground_truth_functions', [])
if files:
    print('Files: ' + ', '.join(files))
if funcs:
    print('Functions: ' + ', '.join(funcs))
if not files and not funcs:
    print('(not available)')
")

  local REPO_DIR="$WORKSPACE/repos/$(echo "$REPO" | tr '/' '_')"
  local WORK_DIR="$WORKSPACE/worktrees/$TASK_ID"

  echo ""
  echo "--- [$((idx+1))/$TASK_COUNT] $TASK_ID ($REPO) ---"

  # Checkout worktree
  if [ ! -d "$WORK_DIR" ]; then
    git -C "$REPO_DIR" worktree add --quiet "$WORK_DIR" "$BASE_COMMIT" --detach 2>/dev/null || {
      git -C "$REPO_DIR" worktree prune
      git -C "$REPO_DIR" worktree add --quiet "$WORK_DIR" "$BASE_COMMIT" --detach
    }
  fi

  for VARIANT in without_skill with_skill; do
    if [ -n "$VARIANT_FILTER" ] && [ "$VARIANT" != "$VARIANT_FILTER" ]; then
      continue
    fi

    local OUT_DIR="$RUNS_DIR/$TASK_ID/$VARIANT"
    if [ -f "$OUT_DIR/output.md" ]; then
      echo "[SKIP] $TASK_ID / $VARIANT (already exists)"
      continue
    fi
    mkdir -p "$OUT_DIR"

    # Build prompt
    local PROMPT_CONTENT
    PROMPT_CONTENT=$(sed \
      -e "s|{repo}|$REPO|g" \
      -e "s|{repo_language}|$REPO_LANG|g" \
      -e "s|{base_commit}|$BASE_COMMIT|g" \
      "$TEMPLATE")
    PROMPT_CONTENT=$(echo "$PROMPT_CONTENT" | python3 -c "
import sys
content = sys.stdin.read()
question = '''$QUESTION'''
print(content.replace('{question}', question))
")

    {
      if [ "$VARIANT" = "with_skill" ]; then
        echo "---SKILL START---"
        cat "$SKILL_PATH"
        echo "---SKILL END---"
        echo ""
      fi
      echo "$PROMPT_CONTENT"
    } > "$OUT_DIR/prompt.txt"

    echo -n "[START] $TASK_ID / $VARIANT  $(date +%H:%M:%S)"
    local START_T=$SECONDS

    pi -p --no-session \
      --provider "$PROVIDER" \
      --model "$MODEL" \
      "@$OUT_DIR/prompt.txt" \
      --cwd "$WORK_DIR" \
      < /dev/null > "$OUT_DIR/output.md" 2>"$OUT_DIR/stderr.log" || true

    local ELAPSED=$((SECONDS - START_T))
    echo "  [DONE] ${ELAPSED}s"
  done
}

# Run all tasks
for idx in $(seq 0 $((TASK_COUNT - 1))); do
  run_task "$idx"
done

echo ""
echo "=== All tasks complete. Running judge... ==="

# Judge phase
python3 - "$RUNS_DIR" "$TASKS_JSON" "$JUDGE_RUBRIC" "$JUDGE_MODEL" "$JUDGE_PROVIDER" << 'PYEOF'
import json, sys, os, subprocess, re

runs_dir = sys.argv[1]
tasks_json = sys.argv[2]
rubric_path = sys.argv[3]
judge_model = sys.argv[4]
judge_provider = sys.argv[5]

tasks = json.load(open(tasks_json))
rubric_template = open(rubric_path).read()

results = []

for t in tasks:
    task_id = t["task_id"]
    gt_files = t.get("ground_truth_files", [])
    gt_funcs = t.get("ground_truth_functions", [])
    gt_str = ""
    if gt_files:
        gt_str += "Files: " + ", ".join(gt_files) + "\n"
    if gt_funcs:
        gt_str += "Functions: " + ", ".join(gt_funcs)
    if not gt_str:
        gt_str = "(not available)"

    for variant in ["without_skill", "with_skill"]:
        out_file = os.path.join(runs_dir, task_id, variant, "output.md")
        if not os.path.isfile(out_file):
            print(f"[SKIP] {task_id}/{variant} - no output")
            continue

        answer = open(out_file).read()
        if len(answer.strip()) < 10:
            print(f"[SKIP] {task_id}/{variant} - empty output")
            results.append({"task_id": task_id, "variant": variant, "scores": None, "error": "empty"})
            continue

        prompt = rubric_template.replace("{question}", t["question"])
        prompt = prompt.replace("{repo}", t["repo"])
        prompt = prompt.replace("{repo_language}", t["repo_language"])
        prompt = prompt.replace("{base_commit}", t["base_commit"])
        prompt = prompt.replace("{ground_truth}", gt_str)
        prompt = prompt.replace("{answer}", answer[:8000])

        judge_file = os.path.join(runs_dir, task_id, variant, "judge_prompt.txt")
        with open(judge_file, "w") as f:
            f.write(prompt)

        print(f"[JUDGE] {task_id}/{variant}...", end=" ", flush=True)

        try:
            result = subprocess.run(
                ["hermes", "chat", "-Q", "-q", prompt,
                 "--provider", judge_provider, "-m", judge_model],
                capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL
            )
            raw = result.stdout.strip()

            # Extract JSON from response
            m = re.search(r'\{[^}]+\}', raw)
            if m:
                scores = json.loads(m.group())
                print(f"total={scores.get('total', '?')}")
                results.append({"task_id": task_id, "variant": variant, "scores": scores})
            else:
                print(f"no JSON found")
                results.append({"task_id": task_id, "variant": variant, "scores": None, "error": "no_json", "raw": raw[:200]})
        except Exception as e:
            print(f"error: {e}")
            results.append({"task_id": task_id, "variant": variant, "scores": None, "error": str(e)})

# Save results
out_path = os.path.join(runs_dir, "grades_explain.json")
with open(out_path, "w") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)

# Summary
print("\n=== Summary ===")
for variant in ["without_skill", "with_skill"]:
    scored = [r for r in results if r["variant"] == variant and r.get("scores")]
    if not scored:
        print(f"{variant}: no results")
        continue
    totals = [r["scores"]["total"] for r in scored]
    avg = sum(totals) / len(totals)
    print(f"{variant}: avg={avg:.1f}/15 ({len(scored)} tasks)")
    for key in ["R1", "R2", "R3", "R4", "R5"]:
        vals = [r["scores"][key] for r in scored]
        print(f"  {key}: avg={sum(vals)/len(vals):.2f}")

PYEOF

echo "Done."
