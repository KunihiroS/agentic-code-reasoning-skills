"""Grade Pro compare benchmark outputs."""
import json
import re
import sys
from pathlib import Path


def extract_answer(text: str) -> str:
    """Extract ANSWER: YES/NO from model output.

    Handles various formats:
      ANSWER: YES equivalent
      ANSWER: **NO, not equivalent**
      ## ANSWER\n**NO not equivalent**
      ANSWER: NO not equivalent
    """
    # Primary: ANSWER line with YES/NO (allow markdown bold, commas, etc.)
    match = re.search(r"ANSWER[:\s]*\*{0,2}\s*(YES|NO)\b", text, re.IGNORECASE)
    if match:
        return "EQUIVALENT" if match.group(1).upper() == "YES" else "NOT_EQUIVALENT"
    # Secondary: "## ANSWER" header followed by YES/NO on the next line
    match = re.search(r"#+\s*ANSWER\s*\n+\s*\*{0,2}\s*(YES|NO)\b", text, re.IGNORECASE)
    if match:
        return "EQUIVALENT" if match.group(1).upper() == "YES" else "NOT_EQUIVALENT"
    # Fallback: look for "equivalent" or "not equivalent" near end
    last_500 = text[-500:]
    if re.search(r"not\s+equivalent", last_500, re.IGNORECASE):
        return "NOT_EQUIVALENT"
    if re.search(r"\bequivalent\b", last_500, re.IGNORECASE):
        return "EQUIVALENT"
    return "UNKNOWN"


def grade_run(runs_dir: str, pairs_json: str) -> list:
    pairs = json.loads(Path(pairs_json).read_text())
    results = []

    for p in pairs:
        iid = p["instance_id"]
        gt = p["ground_truth"]
        for variant in ["without_skill", "with_skill"]:
            output_md = Path(runs_dir) / iid / variant / "output.md"
            output_json_path = Path(runs_dir) / iid / variant / "output.json"

            if not output_md.exists():
                continue

            text = output_md.read_text()
            predicted = extract_answer(text)
            correct = (predicted == gt)

            cost = 0.0
            duration = 0
            if output_json_path.exists():
                try:
                    meta = json.loads(output_json_path.read_text())
                    cost = meta.get("total_cost_usd", 0.0)
                    duration = meta.get("duration_seconds", 0)
                except Exception:
                    pass

            results.append({
                "instance_id": iid,
                "variant": variant,
                "ground_truth": gt,
                "predicted": predicted,
                "correct": correct,
                "cost_usd": cost,
                "duration_seconds": duration,
            })

    return results


def print_summary(results: list):
    for variant in ["without_skill", "with_skill"]:
        vr = [r for r in results if r["variant"] == variant]
        if not vr:
            continue
        correct = sum(1 for r in vr if r["correct"])
        total = len(vr)
        eq_r = [r for r in vr if r["ground_truth"] == "EQUIVALENT"]
        neq_r = [r for r in vr if r["ground_truth"] == "NOT_EQUIVALENT"]
        eq_correct = sum(1 for r in eq_r if r["correct"])
        neq_correct = sum(1 for r in neq_r if r["correct"])
        unknown = sum(1 for r in vr if r["predicted"] == "UNKNOWN")
        avg_dur = sum(r["duration_seconds"] for r in vr) / len(vr) if vr else 0

        print(f"\n{variant}:")
        print(f"  Overall:        {correct}/{total} = {correct/total:.1%}")
        if eq_r:
            print(f"  EQUIVALENT:     {eq_correct}/{len(eq_r)} = {eq_correct/len(eq_r):.1%}")
        if neq_r:
            print(f"  NOT_EQUIVALENT: {neq_correct}/{len(neq_r)} = {neq_correct/len(neq_r):.1%}")
        if unknown:
            print(f"  UNKNOWN:        {unknown}")
        print(f"  Avg duration:   {avg_dur:.0f}s")


def main():
    runs_dir = sys.argv[1] if len(sys.argv) > 1 else "benchmark/swebench/runs/compare-pro-1"
    pairs_json = sys.argv[2] if len(sys.argv) > 2 else "benchmark/swebench/data/pro_compare/pairs_pro.json"

    results = grade_run(runs_dir, pairs_json)
    out_path = Path(runs_dir) / "grades_compare.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(results, indent=2))
    print(f"Graded {len(results)} compare results → {out_path}")
    print_summary(results)


if __name__ == "__main__":
    main()
