# Iteration 11 — 変更理由

## 前イテレーションの分析

- 前回スコア: 80% (16/20)
- 失敗ケース: django__django-15368, django__django-11179, django__django-15382, django__django-11433
- 失敗原因の分析:
  - **15368（持続的失敗）**: EQUIVALENT なのに NOT_EQUIVALENT と誤判定（12 ターン）。Patch B がテストメソッドを削除するケース。iter-10 の D2 注記（削除されたテストには結果がない）を経ても改善されず。
  - **11179（新規失敗）**: EQUIVALENT なのに NOT_EQUIVALENT と誤判定（10 ターン）。差分はあるが試験結果には影響しないケースを、エージェントが過剰に保守的に NOT_EQUIVALENT と結論づけた可能性がある。
  - **15382（持続的失敗）**: EQUIVALENT なのに NOT_EQUIVALENT と誤判定（29 ターン）。ループ制御フローのトレース誤りによる過剰コスト。
  - **11433（新規失敗）**: NOT_EQUIVALENT なのに **UNKNOWN** と回答（31 ターン）。エージェントが大量のターンを費やしたにもかかわらず二値の結論にコミットできず、UNKNOWN という無効な回答を返した。これは4つの失敗ケースの中で唯一の「判断放棄」パターンであり、明確に異なる失敗モードである。

## 改善仮説

**SKILL.md の Compare チェックリストに「UNKNOWN は有効な回答ではない」という明示的な指示を追加することで、11433 のような「判断放棄」型の失敗を汎用的に排除できる。**

根拠:
- 現在の SKILL.md の `compare` モードテンプレートには、ANSWER のプレースホルダーとして `[YES equivalent / NO not equivalent]` と書かれており、二値の答えのみが想定されている。しかし、エージェントが長大な探索の末に確信を持てない場合、テンプレートに縛られずに UNKNOWN を返す逸脱が起きた（11433: 31 ターン）。
- 11433 は NOT_EQUIVALENT の正解ケースであるため、エージェントは差分の証拠を何らかの形で見つけていたはずだが、確信が持てずにコミットを回避した可能性が高い。
- チェックリストに「UNKNOWN は無効。証拠が曖昧な場合は最も支持される答えにコミットし、CONFIDENCE を LOW にすること」と明記することで、エージェントはコミット回避ではなく低信頼度での結論表明に誘導される。
- この変更は特定のケースに依存しない汎用的な推論規律の強化であり、あらゆる compare タスクで「判断放棄」を防ぐ。UNKNOWN は本来 Step 6 の「Assigns a confidence level: HIGH / MEDIUM / LOW」という既存構造と矛盾しており、その矛盾を明示的に解消するものである。

## 変更内容

`compare` モードの Compare checklist に 1 行追加:

```
- UNKNOWN is not a valid answer — if evidence is genuinely ambiguous after full exploration, commit to the best-supported conclusion (YES or NO) and set CONFIDENCE to LOW
```

変更規模: 1 行追加（≤ 20 行の制約内）。

## 期待効果

- **11433**: チェックリストの指示により、エージェントが UNKNOWN を返す代わりに、見つけた差分の証拠に基づいて NO（NOT_EQUIVALENT）にコミットすることを期待する。これにより 1 件が incorrect → correct となり、スコアが 16/20 → 17/20（85%）になることを期待する。
- **15368, 11179, 15382**: 本イテレーションの主仮説ではなく、これらは「過保守的な NOT_EQUIVALENT 判定」という別の失敗モードであるため、今回の変更では改善を期待しない。
- **回帰リスク**: チェックリストへの追加は compare モードの探索プロセス・反証プロセスに影響しない。正常に判定できている 16 件は YES/NO のいずれかを明確に返しており、UNKNOWN 禁止の制約は影響しない。回帰リスクは極めて低い。
