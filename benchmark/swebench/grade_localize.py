"""Grade localize benchmark outputs against ground truth.

Scoring:
  - file_match: predicted file path matches any ground truth file (partial path OK)
  - function_match: predicted function name matches any ground truth function
  - correct: file_match (primary metric for localization)
  - function_match is reported separately as a secondary precision metric
"""
import json
import re
import sys
from pathlib import Path


def extract_localization(text: str) -> dict:
    """Extract FILE: and FUNCTION: lines from model output.

    Handles various markdown formats:
      FILE: path
      **FILE**: path
      **FILE:** path
      - FILE: path
    """
    files = re.findall(
        r"^\s*(?:\*{0,2}|-)\s*FILE\s*\*{0,2}\s*:\s*(.+?)$",
        text, re.MULTILINE | re.IGNORECASE
    )
    funcs = re.findall(
        r"^\s*(?:\*{0,2}|-)\s*FUNCTION\s*\*{0,2}\s*:\s*(.+?)$",
        text, re.MULTILINE | re.IGNORECASE
    )
    # Clean up whitespace, backticks, markdown bold, trailing parens
    def clean(s):
        s = s.strip().strip("`").strip("*").strip()
        # Remove trailing parenthetical like "(add __reversed__ method)"
        s = re.sub(r"\s*\(.*\)\s*$", "", s)
        return s
    files = [clean(f) for f in files if clean(f)]
    funcs = [clean(f) for f in funcs if clean(f)]
    return {"files": files, "functions": funcs}


def file_matches(predicted_files: list, gt_files: list) -> bool:
    """Check if any predicted file matches any ground truth file.

    Allows partial path matching: if gt is 'django/utils/datastructures.py',
    predicting 'utils/datastructures.py' or 'datastructures.py' also counts.
    """
    for pred in predicted_files:
        pred_norm = pred.strip("/")
        for gt in gt_files:
            gt_norm = gt.strip("/")
            if gt_norm.endswith(pred_norm) or pred_norm.endswith(gt_norm):
                return True
    return False


def function_matches(predicted_funcs: list, gt_funcs: list) -> bool:
    """Check if any predicted function matches any ground truth function.

    Handles 'ClassName.method_name' format — matches if either the full
    dotted name or just the method/function name matches.
    """
    if not gt_funcs:
        return True  # No ground truth functions → skip function check

    gt_names = set()
    for f in gt_funcs:
        gt_names.add(f)
        # Also add the last component (method name without class)
        if "." in f:
            gt_names.add(f.split(".")[-1])

    for pred in predicted_funcs:
        pred_clean = pred.strip()
        if pred_clean in gt_names:
            return True
        if "." in pred_clean and pred_clean.split(".")[-1] in gt_names:
            return True
    return False


def grade_run(runs_dir: str, tasks_json: str) -> list:
    tasks = json.loads(Path(tasks_json).read_text())
    gt_map = {t["instance_id"]: t for t in tasks}

    results = []
    for instance_id, task in gt_map.items():
        for variant in ["without_skill", "with_skill"]:
            output_md = Path(runs_dir) / instance_id / variant / "output.md"
            output_json = Path(runs_dir) / instance_id / variant / "output.json"

            if not output_md.exists():
                continue

            text = output_md.read_text()
            loc = extract_localization(text)

            fm = file_matches(loc["files"], task["ground_truth_files"])
            fnm = function_matches(loc["functions"], task["ground_truth_functions"])
            correct = fm  # file-level localization is the primary metric

            cost = 0.0
            turns = 0
            if output_json.exists():
                try:
                    meta = json.loads(output_json.read_text())
                    cost = meta.get("total_cost_usd", 0.0)
                    turns = meta.get("num_turns", 0)
                except Exception:
                    pass

            results.append({
                "instance_id": instance_id,
                "variant": variant,
                "ground_truth_files": task["ground_truth_files"],
                "ground_truth_functions": task["ground_truth_functions"],
                "predicted_files": loc["files"],
                "predicted_functions": loc["functions"],
                "file_match": fm,
                "function_match": fnm,
                "correct": correct,
                "cost_usd": cost,
                "turns": turns,
            })

    return results


def print_summary(results: list):
    for variant in ["without_skill", "with_skill"]:
        vr = [r for r in results if r["variant"] == variant]
        if not vr:
            continue
        correct = sum(1 for r in vr if r["correct"])
        file_ok = sum(1 for r in vr if r["file_match"])
        func_ok = sum(1 for r in vr if r["function_match"])
        total = len(vr)
        print(f"\n{variant}:")
        print(f"  Overall (file+func): {correct}/{total} = {correct/total:.1%}" if total else "  No data")
        print(f"  File match:          {file_ok}/{total} = {file_ok/total:.1%}" if total else "")
        print(f"  Function match:      {func_ok}/{total} = {func_ok/total:.1%}" if total else "")
        no_pred = sum(1 for r in vr if not r["predicted_files"])
        if no_pred:
            print(f"  No prediction:       {no_pred}")


def main():
    runs_dir = sys.argv[1] if len(sys.argv) > 1 else "benchmark/swebench/runs/iter-1"
    tasks_json = sys.argv[2] if len(sys.argv) > 2 else "benchmark/swebench/data/localize_tasks.json"

    results = grade_run(runs_dir, tasks_json)
    out_path = Path(runs_dir) / "grades_localize.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(results, indent=2))
    print(f"Graded {len(results)} localize results → {out_path}")
    print_summary(results)


if __name__ == "__main__":
    main()
