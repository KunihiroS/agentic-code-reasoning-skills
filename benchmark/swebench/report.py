"""Generate markdown report from graded results."""
import json
import sys
from pathlib import Path


def generate_report(runs_dir):
    grades_path = Path(runs_dir) / "grades.json"
    results = json.loads(grades_path.read_text())

    lines = ["# SWE-bench Patch Equivalence Benchmark Report\n"]
    lines.append(f"**Runs directory:** `{runs_dir}`\n")

    for variant in ["without_skill", "with_skill"]:
        vr = [r for r in results if r["variant"] == variant]
        if not vr:
            continue
        correct = sum(1 for r in vr if r["correct"])
        total = len(vr)
        eq = [r for r in vr if r["ground_truth"] == "EQUIVALENT"]
        neq = [r for r in vr if r["ground_truth"] == "NOT_EQUIVALENT"]

        lines.append(f"\n## {variant}\n")
        lines.append("| Metric | Value |")
        lines.append("|---|---|")
        lines.append(f"| Overall Accuracy | {correct}/{total} = {correct/total:.1%} |")
        if eq:
            ec = sum(1 for r in eq if r["correct"])
            lines.append(f"| EQUIV Accuracy | {ec}/{len(eq)} = {ec/len(eq):.1%} |")
        if neq:
            nc = sum(1 for r in neq if r["correct"])
            lines.append(
                f"| NOT_EQUIV Accuracy | {nc}/{len(neq)} = {nc/len(neq):.1%} |"
            )
        lines.append(f"| Total Cost | ${sum(r['cost_usd'] for r in vr):.2f} |")
        lines.append(f"| Avg Turns | {sum(r['turns'] for r in vr)/len(vr):.1f} |")

    # Comparison table
    ws = [r for r in results if r["variant"] == "without_skill"]
    sk = [r for r in results if r["variant"] == "with_skill"]
    if ws and sk:
        ws_acc = sum(1 for r in ws if r["correct"]) / len(ws)
        sk_acc = sum(1 for r in sk if r["correct"]) / len(sk)
        delta = sk_acc - ws_acc
        lines.append("\n## Comparison\n")
        lines.append("| | without_skill | with_skill | Delta |")
        lines.append("|---|---|---|---|")
        lines.append(f"| Accuracy | {ws_acc:.1%} | {sk_acc:.1%} | {delta:+.1%} |")

    # Per-instance detail
    lines.append("\n## Per-Instance Results\n")
    lines.append("| Instance | GT | without_skill | with_skill |")
    lines.append("|---|---|---|---|")

    instances = sorted(set(r["instance_id"] for r in results))
    for iid in instances:
        gt = next(r["ground_truth"] for r in results if r["instance_id"] == iid)
        gt_short = "EQ" if gt == "EQUIVALENT" else "NEQ"
        ws_r = next(
            (
                r
                for r in results
                if r["instance_id"] == iid and r["variant"] == "without_skill"
            ),
            None,
        )
        sk_r = next(
            (
                r
                for r in results
                if r["instance_id"] == iid and r["variant"] == "with_skill"
            ),
            None,
        )
        ws_mark = (
            ("✓" if ws_r["correct"] else "✗ " + ws_r["raw_answer"]) if ws_r else "-"
        )
        sk_mark = (
            ("✓" if sk_r["correct"] else "✗ " + sk_r["raw_answer"]) if sk_r else "-"
        )
        lines.append(f"| {iid} | {gt_short} | {ws_mark} | {sk_mark} |")

    report = "\n".join(lines) + "\n"
    out = Path(runs_dir) / "report.md"
    out.write_text(report)
    print(f"Report saved to {out}")


if __name__ == "__main__":
    generate_report(
        sys.argv[1] if len(sys.argv) > 1 else "benchmark/swebench/runs/iter-1"
    )
