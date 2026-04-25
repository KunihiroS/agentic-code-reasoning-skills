"""Run judge on explain benchmark outputs."""
import json, sys, os, subprocess, re, tempfile

runs_dir = sys.argv[1]
tasks_json = sys.argv[2]
rubric_path = sys.argv[3]
judge_model = sys.argv[4] if len(sys.argv) > 4 else "gpt-5.4"
judge_provider = sys.argv[5] if len(sys.argv) > 5 else "openai-codex"

tasks = json.load(open(tasks_json))
rubric_template = open(rubric_path).read()

MAX_ANSWER_CHARS = 4000
TIMEOUT = 300

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

        # Truncate answer
        if len(answer) > MAX_ANSWER_CHARS:
            answer = answer[:MAX_ANSWER_CHARS] + "\n\n[... truncated for judge evaluation ...]"

        # Build prompt with truncated question too
        question = t["question"]
        if len(question) > 2000:
            question = question[:2000] + "\n[... truncated ...]"

        prompt = rubric_template.replace("{question}", question)
        prompt = prompt.replace("{repo}", t["repo"])
        prompt = prompt.replace("{repo_language}", t["repo_language"])
        prompt = prompt.replace("{base_commit}", t["base_commit"])
        prompt = prompt.replace("{ground_truth}", gt_str)
        prompt = prompt.replace("{answer}", answer)

        # Write prompt to temp file to avoid command line length issues
        prompt_file = os.path.join(runs_dir, task_id, variant, "judge_prompt.txt")
        with open(prompt_file, "w") as f:
            f.write(prompt)

        print(f"[JUDGE] {task_id}/{variant}...", end=" ", flush=True)

        try:
            # Use file input instead of -q to avoid arg length limit
            result = subprocess.run(
                ["hermes", "chat", "-Q", "-q", prompt,
                 "--provider", judge_provider, "-m", judge_model],
                capture_output=True, text=True, timeout=TIMEOUT,
                stdin=subprocess.DEVNULL
            )
            raw = result.stdout.strip()

            # Try to extract JSON - handle multiline and markdown code blocks
            # First try: find {...} pattern
            m = re.search(r'\{[^{}]*"R1"[^{}]*\}', raw, re.DOTALL)
            if not m:
                m = re.search(r'\{[^{}]*"total"[^{}]*\}', raw, re.DOTALL)
            if m:
                try:
                    scores = json.loads(m.group())
                    print(f"total={scores.get('total', '?')}")
                    results.append({"task_id": task_id, "variant": variant, "scores": scores})
                    continue
                except json.JSONDecodeError:
                    pass

            # Fallback: try to parse individual scores from text
            r_scores = {}
            for key in ["R1", "R2", "R3", "R4", "R5"]:
                m2 = re.search(rf'"{key}":\s*(\d)', raw)
                if not m2:
                    m2 = re.search(rf'{key}[:\s]+(\d)', raw)
                if m2:
                    r_scores[key] = int(m2.group(1))
            if len(r_scores) == 5:
                r_scores["total"] = sum(r_scores.values())
                print(f"total={r_scores['total']} (parsed)")
                results.append({"task_id": task_id, "variant": variant, "scores": r_scores})
            else:
                print(f"parse failed (got {len(r_scores)}/5 scores)")
                results.append({"task_id": task_id, "variant": variant, "scores": None,
                               "error": "parse_failed", "raw": raw[:300]})

        except subprocess.TimeoutExpired:
            print(f"timeout ({TIMEOUT}s)")
            results.append({"task_id": task_id, "variant": variant, "scores": None, "error": "timeout"})
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

# Paired comparison
print("\n=== Paired comparison ===")
task_ids = set(r["task_id"] for r in results)
pairs = []
for tid in sorted(task_ids):
    wo = next((r for r in results if r["task_id"]==tid and r["variant"]=="without_skill" and r.get("scores")), None)
    ws = next((r for r in results if r["task_id"]==tid and r["variant"]=="with_skill" and r.get("scores")), None)
    if wo and ws:
        delta = ws["scores"]["total"] - wo["scores"]["total"]
        pairs.append((tid, wo["scores"]["total"], ws["scores"]["total"], delta))
        sign = "+" if delta > 0 else ""
        print(f"  {tid:30s} wo={wo['scores']['total']:>2} ws={ws['scores']['total']:>2} delta={sign}{delta}")

if pairs:
    wo_avg = sum(p[1] for p in pairs) / len(pairs)
    ws_avg = sum(p[2] for p in pairs) / len(pairs)
    print(f"\n  Paired avg: wo={wo_avg:.1f} ws={ws_avg:.1f} delta={ws_avg-wo_avg:+.1f} (n={len(pairs)})")
