# Iteration 7 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（iter-6 scores.json 未参照）
- 失敗ケース: 詳細は scores.json 参照
- 失敗原因の分析: 仮説が REFINED（未解決）のまま次ファイルへ移る際に、
  何を探しに行くかの方針が曖昧なため探索がドリフトしやすい状態だった。
  NEXT ACTION RATIONALE フィールドは「なぜ次のファイルを開くか」は問うが、
  「どのシグナルを探しに行くか」を明示する指示を欠いていた。

## 改善仮説

NEXT ACTION RATIONALE に「探しに行く証拠の種類（仮説を確認/反証するための
具体的なシグナル）」を明示させることで、ファイル探索がその仮説に対して
必要な情報に絞り込まれ、見落としと冗長な探索の両方が減る。

## 変更内容

SKILL.md Step 3 の HYPOTHESIS UPDATE ブロック内にある
NEXT ACTION RATIONALE の行（1行）を以下のように精緻化した。

変更前:
  NEXT ACTION RATIONALE: [why the next file or step is justified]

変更後:
  NEXT ACTION RATIONALE: [why the next file or step is justified — and what
  specific signal (presence/absence of a call, a value, a branch) you are
  looking for to confirm or refute the active hypothesis]

変更規模: 1行（既存行への文言追加）。新規ステップ・フィールド・セクションなし。

## 期待効果

1. 探索ドリフトの抑制
   仮説が REFINED のまま次ファイルへ移る際、読むべきシグナルを事前に宣言
   することで、関連性の低いコードへの迷い込みが減り文脈の膨張を防ぐ。

2. 微妙な差異の見落とし低減（Guardrail #4 に相当する失敗パターン）
   差異がありそうなコードパスへ遷移するとき、どのシグナル（呼び出し経路の
   有無・分岐条件の値・戻り値の型）を確認すべきかを先に宣言させることで、
   読んだ後に「確認した証拠」と「確認すべきだったが見なかった証拠」が
   区別しやすくなり、見落としを抑える。

3. 推論チェーンの網羅性向上
   次の探索で何を確認するかを先に宣言することが、後続の OBSERVATIONS と
   HYPOTHESIS UPDATE の網羅性に対する自己チェックとして機能する。
