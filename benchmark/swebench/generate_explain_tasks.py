"""Generate explain benchmark tasks from existing SWE-bench data."""
import json
import random
import hashlib

random.seed(42)

audit = json.load(open("/home/kunihiros/agentic-code-reasoning-skills/benchmark/swebench/data/audit_tasks_security.json"))
compare = json.load(open("/home/kunihiros/agentic-code-reasoning-skills/benchmark/swebench/data/pro_compare/pairs_pro.json"))

tasks = []

# Question templates for variety
Q_TEMPLATES = [
    "What is the root cause of the following issue, and how does the codebase's current implementation lead to this behavior?\n\n{problem}",
    "Explain why the following bug occurs. Trace the code path that leads to the problematic behavior.\n\n{problem}",
    "A user reported the following issue. What specific code paths and logic are responsible for this behavior?\n\n{problem}",
]

# From audit tasks - these have clear bugs with known file+function ground truth
for i, t in enumerate(audit):
    q_template = Q_TEMPLATES[i % len(Q_TEMPLATES)]
    task = {
        "task_id": f"explain_audit_{i+1:02d}",
        "repo": t["repo"],
        "repo_language": t["repo_language"],
        "base_commit": t["base_commit"],
        "question": q_template.format(problem=t["problem_statement"]),
        "source": "audit_tasks_security",
        "ground_truth_files": t.get("ground_truth_files", []),
        "ground_truth_functions": t.get("ground_truth_functions", []),
        "issue_categories": t.get("issue_categories", []),
    }
    tasks.append(task)

# From compare pairs - use gold_patch as ground truth context
# Select only unique instances (some have both EQUIV and NOT_EQUIV pairs)
seen_instances = set()
for i, p in enumerate(compare):
    inst = p["instance_id"].split("-v")[0] if "-v" in p["instance_id"] else p["instance_id"]
    if inst in seen_instances:
        continue
    seen_instances.add(inst)
    
    q_template = Q_TEMPLATES[i % len(Q_TEMPLATES)]
    task = {
        "task_id": f"explain_compare_{i+1:02d}",
        "repo": p["repo"],
        "repo_language": p["repo_language"],
        "base_commit": p["base_commit"],
        "question": q_template.format(problem=p["problem_statement"]),
        "source": "pro_compare",
        "gold_patch_preview": p["gold_patch"][:500] if p.get("gold_patch") else None,
    }
    tasks.append(task)

# Shuffle and select 20, ensuring repo diversity
random.shuffle(tasks)

# Ensure at least 1 from each repo
repos = list(set(t["repo"] for t in tasks))
selected = []
for repo in repos:
    candidates = [t for t in tasks if t["repo"] == repo]
    selected.append(candidates[0])
    
# Fill remaining slots
remaining = [t for t in tasks if t not in selected]
random.shuffle(remaining)
for t in remaining:
    if len(selected) >= 20:
        break
    selected.append(t)

# Sort by task_id for consistency
selected.sort(key=lambda x: x["task_id"])

out_path = "/home/kunihiros/agentic-code-reasoning-skills/benchmark/swebench/data/explain_tasks.json"
with open(out_path, "w") as f:
    json.dump(selected, f, indent=2, ensure_ascii=False)

print(f"Generated {len(selected)} explain tasks")
print(f"Repos: {sorted(set(t['repo'] for t in selected))}")
print(f"Sources: audit={sum(1 for t in selected if t['source']=='audit_tasks_security')}, compare={sum(1 for t in selected if t['source']=='pro_compare')}")
print(f"\nSample questions:")
for t in selected[:3]:
    print(f"  [{t['task_id']}] {t['repo']} ({t['repo_language']})")
    print(f"    {t['question'][:100]}...")
    print()
