#!/usr/bin/env python3
"""
select_parent.py — archive.jsonl から score_prop アルゴリズムで親イテレーションを選択。

HyperAgents (arXiv:2603.19461) の score_prop アルゴリズム:
  mid_point = mean(top 3 scores)
  weight_i  = sigmoid(steepness * (normalized_score_i - normalized_mid_point))

HyperAgents のデフォルト steepness=10 は 0-1 スコア向け。本プロジェクトは 0-100
パーセントスコアで、かつ変動幅が 65-85 と狭いため、steepness=20 (実効的に 2x) を
デフォルトにして 85% 版の選択確率を高める。
"""
import json, argparse, math, random, sys
from pathlib import Path

def load_archive(path):
    nodes = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                nodes.append(json.loads(line))
    return nodes

def compute_weights(candidates, score_key, steepness):
    scores = [c["scores"].get(score_key, 0) for c in candidates]
    top3 = sorted(scores, reverse=True)[:3]
    mid_point = sum(top3) / len(top3)
    weights = [1 / (1 + math.exp(-steepness * ((s - mid_point) / 100.0))) for s in scores]
    return scores, mid_point, weights

def score_prop(candidates, score_key, steepness):
    _, _, weights = compute_weights(candidates, score_key, steepness)
    total = sum(weights)
    if total == 0:
        return random.choice(candidates)
    probs = [w / total for w in weights]
    return random.choices(candidates, weights=probs, k=1)[0]

def best(candidates, score_key="overall"):
    return max(candidates, key=lambda n: n["scores"].get(score_key, 0))

def latest(candidates, score_key="overall"):
    return candidates[-1]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--archive", required=True)
    ap.add_argument("--method", default="score_prop", choices=["score_prop", "best", "latest"])
    ap.add_argument("--score-key", default="overall")
    ap.add_argument("--steepness", type=float, default=20.0)
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    nodes = load_archive(args.archive)
    candidates = [n for n in nodes if n.get("valid_parent", False)]
    if not candidates:
        sys.exit("No valid candidates")

    if args.dry_run:
        scores, mid_point, weights = compute_weights(candidates, args.score_key, args.steepness)
        total = sum(weights)
        probs = [w / total for w in weights]
        print(f"steepness: {args.steepness}")
        print(f"mid_point (top-3 mean): {mid_point:.1f}")
        print(f"{'iter':<8} {'score':<7} {'prob':<8}")
        pairs = sorted(zip(candidates, probs), key=lambda x: -x[1])
        by_score = {}
        for c, p in pairs:
            s = c["scores"][args.score_key]
            by_score.setdefault(s, []).append(p)
        print()
        print("Summary by score:")
        for s in sorted(by_score.keys(), reverse=True):
            ps = by_score[s]
            print(f"  {s}%: count={len(ps)}, individual={ps[0]*100:.2f}%, combined={sum(ps)*100:.2f}%")
        print()
        print("Top 15 candidates:")
        for c, p in pairs[:15]:
            print(f"  iter-{c['genid']:<4} {c['scores'][args.score_key]:<6} {p*100:.2f}%")
        return

    if args.method == "score_prop":
        parent = score_prop(candidates, args.score_key, args.steepness)
    elif args.method == "best":
        parent = best(candidates, args.score_key)
    elif args.method == "latest":
        parent = latest(candidates, args.score_key)

    print(parent["genid"])

if __name__ == "__main__":
    main()
