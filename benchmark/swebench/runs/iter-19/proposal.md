1) 過去提案との差異: 直近却下が「compare の早期 NOT_EQUIV 条件の具体化/境界への還元」だったのに対し、本提案は全モード共通の Step 3 における“次に何を読むか”の優先順位付け（情報取得）を改善する。
2) Target: 両方（偽 EQUIV と偽 NOT_EQUIV を同時に下げる）
3) Mechanism (抽象): 複数の探索候補があるとき、最も“仮説を分離する（反証しやすい）”次アクションを選ぶよう、Step 3 の記録テンプレに 1 行だけ明示する。
4) Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件（S1/S2 の扱い）や、判定ゲートの追加/強化は行わない。

禁止方向（failed-approaches.md + 直近却下履歴の要約）
- 既存判定基準を「特定の観測境界」だけに還元して条件を狭める（構造差→境界写像、VERIFIED/可視オラクル依存など）。
- 反証優先順位や探索経路を、特定観点へ寄せたり半固定する（読解順序の固定、最小分岐候補への寄せ等）。
- 新しい必須メタ判断/ゲートの純増（UNVERIFIED を専用トリガ化、結論萎縮を招く追加チェック等）。

カテゴリ B 内での具体的メカニズム選択理由
- B は「何を探すか」ではなく「どう探すか / 優先順位」を扱う。ここでは“探索の入口を半固定”せず、都度の候補集合の中で選択基準だけを改善する。
- Step 3 には既に「NEXT ACTION RATIONALE」があるが、正当化の文章化に留まりやすく、確認バイアス（都合の良い証拠だけを積む）を抑える選択規準が弱い。そこで“弁明を書く”から“識別力の高い一手を選ぶ”へ、記録欄の意味を寄せる。

改善仮説（1 つ）
- 仮説: 次アクションを「最も正しそうな説明を補強する読解」ではなく「現に競合している 2 つの仮説を最短で分離（少なくとも一方を反証）できる読解」に寄せると、(a) 早期の偽 EQUIV（反例探索が弱い）と (b) 早期の偽 NOT_EQUIV（表層差分への過剰適応）の双方を減らせる。

SKILL.md 該当箇所（短い引用）と変更
- 該当（Step 3 の探索ジャーナル末尾）:
  "NEXT ACTION RATIONALE: [why the next file or step is justified]"
- 変更: 同じ 1 行を「競合仮説を分離する（反証しやすい）次アクション」を明示する書き方に置換し、探索優先順位の基準をテンプレ内に埋め込む。

Decision-point delta（IF/THEN 2 行）
Before: IF 次に読む/検索する候補が複数ある THEN 直感的に“関係がありそう”なものを選ぶ because 正当化（NEXT ACTION RATIONALE）を後付けで書ける。
After:  IF 次に読む/検索する候補が複数ある THEN 競合する上位 2 仮説を最も強く分離（少なくとも一方を反証）できる候補を選ぶ because 最小の追加読解で誤判定（偽 EQUIV/偽 NOT_EQ）を同時に減らせる。

変更差分プレビュー（Before/After, 3–10 行）
Before:
  UNRESOLVED:
    - [remaining questions]

  NEXT ACTION RATIONALE: [why the next file or step is justified]
After:
  UNRESOLVED:
    - [remaining questions]

  NEXT ACTION RATIONALE: [which two live hypotheses this next action best discriminates (can refute), and why it is the highest-information next step]

failed-approaches.md との照合（整合 1–2 点）
- 「証拠の種類をテンプレで事前固定しすぎる変更は避ける」に整合: 何を探すかの固定ではなく、“候補が複数あるときの選び方”のみを与える（候補集合は都度の仮説から自然に生じる）。
- 「探索の自由度を削りすぎない／読解順序の半固定を避ける」に整合: “常に A→B→C を読め”のような経路固定はせず、その場の分岐で情報利得の高い一手を選ぶだけで探索幅を温存する。

変更規模の宣言
- SKILL.md の置換 1 行のみ（5 行以内、必須ゲートの純増なし）。
