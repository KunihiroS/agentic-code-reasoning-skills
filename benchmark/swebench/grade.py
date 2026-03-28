"""Grade benchmark outputs against ground truth."""
import json
import re
import sys
from pathlib import Path


def extract_answer(text):
    """Extract YES/NO answer from model output."""
    match = re.search(r"ANSWER:\s*(YES|NO)", text, re.IGNORECASE)
    if match:
        return match.group(1).upper()
    matches = re.findall(r"\b(YES|NO)\b", text, re.IGNORECASE)
    return matches[-1].upper() if matches else "UNKNOWN"


def grade_run(runs_dir, pairs_json):
    pairs = json.loads(Path(pairs_json).read_text())
    gt_map = {p["instance_id"]: p["ground_truth"] for p in pairs}

    results = []
    for instance_id, gt in gt_map.items():
        for variant in ["without_skill", "with_skill"]:
            output_md = Path(runs_dir) / instance_id / variant / "output.md"
            output_json = Path(runs_dir) / instance_id / variant / "output.json"

            if not output_md.exists():
                continue

            text = output_md.read_text()
            answer = extract_answer(text)

            predicted = (
                "EQUIVALENT"
                if answer == "YES"
                else "NOT_EQUIVALENT" if answer == "NO" else "UNKNOWN"
            )
            correct = predicted == gt

            cost = 0.0
            turns = 0
            if output_json.exists():
                try:
                    meta = json.loads(output_json.read_text())
                    cost = meta.get("total_cost_usd", 0.0)
                    turns = meta.get("num_turns", 0)
                except Exception:
                    pass

            results.append(
                {
                    "instance_id": instance_id,
                    "variant": variant,
                    "ground_truth": gt,
                    "predicted": predicted,
                    "raw_answer": answer,
                    "correct": correct,
                    "cost_usd": cost,
                    "turns": turns,
                }
            )

    return results


def print_summary(results):
    for variant in ["without_skill", "with_skill"]:
        vr = [r for r in results if r["variant"] == variant]
        if not vr:
            continue
        correct = sum(1 for r in vr if r["correct"])
        total = len(vr)
        acc = correct / total if total else 0
        eq = [r for r in vr if r["ground_truth"] == "EQUIVALENT"]
        neq = [r for r in vr if r["ground_truth"] == "NOT_EQUIVALENT"]
        eq_acc = sum(1 for r in eq if r["correct"]) / len(eq) if eq else 0
        neq_acc = sum(1 for r in neq if r["correct"]) / len(neq) if neq else 0
        unknown = sum(1 for r in vr if r["predicted"] == "UNKNOWN")
        cost = sum(r["cost_usd"] for r in vr)
        print(f"\n{variant}:")
        print(f"  Overall:  {correct}/{total} = {acc:.1%}")
        if eq:
            print(
                f"  EQUIV:    {sum(1 for r in eq if r['correct'])}/{len(eq)} = {eq_acc:.1%}"
            )
        if neq:
            print(
                f"  NOT_EQ:   {sum(1 for r in neq if r['correct'])}/{len(neq)} = {neq_acc:.1%}"
            )
        if unknown:
            print(f"  UNKNOWN:  {unknown}")
        print(f"  Cost:     ${cost:.2f}")


def main():
    runs_dir = sys.argv[1] if len(sys.argv) > 1 else "benchmark/swebench/runs/iter-1"
    pairs_json = (
        sys.argv[2] if len(sys.argv) > 2 else "benchmark/swebench/data/pairs.json"
    )

    results = grade_run(runs_dir, pairs_json)
    out_path = Path(runs_dir) / "grades.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(results, indent=2))
    print(f"Graded {len(results)} results → {out_path}")
    print_summary(results)


if __name__ == "__main__":
    main()
