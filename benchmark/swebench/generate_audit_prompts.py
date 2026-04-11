"""Generate per-task prompt files for audit benchmark."""
import json
import sys
from pathlib import Path

tasks_json = sys.argv[1]
template_path = sys.argv[2]
output_dir = sys.argv[3]

tasks = json.loads(Path(tasks_json).read_text())
template = Path(template_path).read_text()

Path(output_dir).mkdir(parents=True, exist_ok=True)

for i, t in enumerate(tasks):
    prompt = template.format(
        repo=t["repo"],
        repo_language=t["repo_language"],
        base_commit=t["base_commit"],
        problem_statement=t["problem_statement"],
        fail_to_pass=json.dumps(t["fail_to_pass"]),
    )
    prompt_file = Path(output_dir) / f"prompt_{i:03d}.txt"
    prompt_file.write_text(prompt)

    manifest = {
        "index": i,
        "instance_id": t["instance_id"],
        "base_commit": t["base_commit"],
        "repo": t["repo"],
        "prompt_file": str(prompt_file),
    }
    manifest_file = Path(output_dir) / f"task_{i:03d}.json"
    manifest_file.write_text(json.dumps(manifest))

print(f"Generated {len(tasks)} prompt files in {output_dir}")
