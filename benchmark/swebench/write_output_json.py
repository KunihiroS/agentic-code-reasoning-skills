import json, sys
out_dir = sys.argv[1]
duration = int(sys.argv[2])
try:
    text = open(f"{out_dir}/output.md").read()
except:
    text = ""
json.dump({"total_cost_usd": 0, "num_turns": 0, "duration_seconds": duration, "output_length": len(text)},
          open(f"{out_dir}/output.json", "w"), indent=2)
