# Iteration 56 — 改善案 (proposal)

## 親イテレーション選定理由

親イテレーションとして **iter-35（85%, 17/20）** を選定した。理由は以下の通り:

- iter-35 は直近の安定したベースラインとして最高スコアを記録しており、その後の試行（iter-36〜55）は API 制限・認知負荷増・回帰のいずれかで悪化または評価不能に終わった
- iter-35 の実際の変更（`because` 節に「to the assertion or exception — cite file:line」を追加）は、テンプレートの証拠品質を向上させ、75% → 85% の改善をもたらした
- 残る 3 つの失敗ケース（15368, 13821: EQUIV→NOT_EQ, 11433: NOT_EQ→UNKNOWN）は異なるメカニズムで発生しており、改善余地が明確に残っている

## 選択した Exploration Framework カテゴリ

**カテゴリ E: 表現・フォーマットを改善する**

> 曖昧な指示をより具体的な言い回しに変える

選択理由:

- iter-35 はカテゴリ E に相当する変更（`because` 節の文言精緻化）で成功した。同一カテゴリ内でも、今回は**異なる場所（Claim テンプレートではなくチェックリスト）・異なるメカニズム（証拠の記録方法ではなく判定基準の明確化）**を対象とする
- カテゴリ A（順序）= BL-12/14 で失敗、カテゴリ B（探索方法）= BL-17/22 で失敗、カテゴリ C（比較枠組み）= BL-7/11/16 等で失敗、カテゴリ D（メタ認知）= BL-9/10 で失敗、カテゴリ F（論文未活用）= BL-24/25/26 等で失敗または評価不能。カテゴリ E の「既存行文言の精緻化」は今イテレーションの親（iter-35）が使用し成功した唯一のカテゴリ
- 5 行以内制約のもとで、既存テキストの修正によって意味的な改善が可能であるため実装可能

## 改善仮説

**チェックリスト項目 6 の「observable test outcome」という表現の曖昧さが EQUIV 偽陽性（NOT_EQ 誤判定）を引き起こしている。エージェントは「コード実行経路が異なる（intermediate observable が違う）」を「テストの PASS/FAIL 結果が異なる」と混同している可能性がある。「observable test outcome」を「PASS/FAIL result」に精緻化し、「not merely the internal execution path」という対比句を加えることで、コード差分からテスト結果への短絡（jumps-to-conclusion）を抑制できる。**

根拠:
- 15368・13821 はともに EQUIV であるにも関わらず NOT_EQ と誤判定される。エージェントはコード差分を発見し、それをもとに COUNTEREXAMPLE を構成するが、テストの assert 条件に対して A/B の最終的な PASS/FAIL を正確に区別できていない
- 現行チェックリスト: "verify that the difference produces a different **observable test outcome**"
- 「observable outcome」はコード実行中の任意の観測可能な値（中間変数、返り値等）と解釈できる。エージェントは「Change B の返り値が Change A と異なる → observable outcome が異なる → NOT_EQ」という誤った連鎖を形成しやすい
- 「PASS/FAIL result of at least one relevant test, not merely the internal execution path」に変更することで、エージェントが検証すべきゴールポストが「テストの実行合否」に固定される
- iter-35 の変更（`because` 節への trace 義務）は「どこまでトレースするか」を指定した。今回の変更は「何を証明したとみなすか」を指定する。異なるメカニズムであり、BL-25（assertion/exception まで全 trace 義務）とも異なる（チェックリストの判断基準の明確化であり、template の obligation ではない）

## SKILL.md のどこをどう変えるか

**変更箇所**: `## Compare` セクションの `### Compare checklist` 内

**変更前（現行）**:
```
- Do not conclude NOT EQUIVALENT from a code difference alone — verify that the difference produces a different observable test outcome by tracing through at least one test
```

**変更後（提案）**:
```
- Do not conclude NOT EQUIVALENT from a code difference alone — verify that the difference changes the PASS/FAIL result of at least one relevant test, not merely the internal execution path
```

**変更の説明**:
- `produces a different observable test outcome by tracing through at least one test` → `changes the PASS/FAIL result of at least one relevant test, not merely the internal execution path`
- 新規追加行: **0 行**（既存行の文言修正のみ）
- ポイント 1: "observable test outcome" → "PASS/FAIL result" — 「テストが pass するか fail するか」という明確な二値の結果を目標に固定する
- ポイント 2: "by tracing through at least one test" の削除（"relevant test" という語が引き継ぐため情報量は維持）
- ポイント 3: "not merely the internal execution path" の追加 — 「コード実行経路の差異」と「テスト合否の差異」を明示的に区別させる対比句

## EQUIV と NOT_EQ の正答率への予測影響

### EQUIV（現状 8/10 = 80%）→ 予測 9〜10/10 = 90〜100%

- 15368・13821: エージェントがコード差分から PASS/FAIL 差分を導出しようとする際、"not merely the internal execution path" という対比句が「コード経路の差 ≠ テスト結果の差」という意識を喚起する。これによりエージェントは NO COUNTEREXAMPLE EXISTS セクションでより厳密に「テストが実際に FAIL に変わるか」を確認するよう誘導される可能性がある
- 他の EQUIV ケース（現状正答済み）: チェックリスト項目は advisory であり、既に PASS/FAIL を正しくトレースしているケースに悪影響を与えない

### NOT_EQ（現状 9/10 = 90%）→ 予測 9/10 = 90%

- 11433 UNKNOWN（31 turns）: 今回の変更はチェックリスト 1 行の修正であり、認知負荷の増加はほぼない。11433 のターン消費は変更コードの複雑さに起因すると推測されるため、この変更では直接的な改善・悪化は見込みにくい
- "not merely the internal execution path" という文言は NOT_EQ 方向への制約ではなく、PASS/FAIL を証拠として提示できれば条件を満たすという意味で、真の NOT_EQ ケースの立証ハードルは変わらない
- **懸念**: "changes the PASS/FAIL result" という表現が NOT_EQ の立証をより厳密に求めると受け取られた場合、BL-2 に近い効果（NOT_EQ 閾値の引き上げ）を生む可能性がある。ただし現行文言の「verify that the difference produces a different observable test outcome」も同等の要求をしており、delta は表現の明確化のみであるため、この懸念は小さいと判断する

## failed-approaches.md ブラックリストおよび共通原則との照合

| チェック項目 | 評価 |
|---|---|
| BL-2（NOT_EQ 証拠閾値・厳格化）| 今回は「何が証拠か」を明確化するのみで、証拠量の要求は変えない。「PASS/FAIL 結果を示せ」は元の「observable test outcome を示せ」と同等の要求。ただし境界上のリスクあり（後述） |
| BL-5（前提収集テンプレートの具体化）| 対象は checklist（処理方針）であり、PREMISES テンプレート（前提収集形式）の変更ではない ✓ |
| BL-9（メタ認知自己チェック）| チェックリスト項目の文言精緻化であり、「自分は〜をしたか？」という自己評価を求めるものではない ✓ |
| BL-14（非対称なアドバイザリ指示）| 変更は NOT_EQ 結論を出す際の基準明確化。元の文言も同じ非対称性を持っており、delta は「observable」→「PASS/FAIL result, not merely execution path」という精緻化のみ。非対称性は変えていない（既存の非対称性を継承） |
| BL-25（because 節への assertion/exception 追加）| 対象は checklist であり Claim テンプレートではない。また BL-25 は全 Claim に対する完全トレース義務（高コスト）だったが、今回はチェックリストの判断基準の精緻化（低コスト） ✓ |
| 共通原則 #1（判定の非対称操作）| 既存の項目 6 も NOT_EQ 方向にのみ述べる非対称な記述。今回の変更は同じ非対称性を維持しつつ表現を精緻化するもので、新たな非対称性を追加しない ✓（既存と同等）|
| 共通原則 #5（入力テンプレートの過剰規定）| "PASS/FAIL result" という明確化は、探索視野を「PASS/FAIL に関係するテスト」に絞るものではなく、最終的な検証のゴールを定めるものであるため過剰規定には当たらない ✓ |
| 共通原則 #6（対称化は差分で評価）| 変更の実効差分: "observable test outcome" → "PASS/FAIL result of at least one relevant test, not merely internal execution path"。差分は「observable」の定義明確化のみ。方向性は既存と同じ（NOT_EQ 方向への慎重さを求める）✓ |
| 特定ケースの狙い撃ち | 変更は特定ケース ID を参照せず、汎用的なコード推論の誤りパターン（コード差分とテスト結果差分の混同）に対処する ✓ |

**境界上のリスク（BL-2 との類似性）**:
- 変更後の "changes the PASS/FAIL result" は "produces a different observable test outcome" よりも厳密に見える可能性があり、これが NOT_EQ の立証ハードルを実質的に上げる（BL-2 の Fail Core: 閾値の移動）リスクが存在する
- ただし: BL-2 は「カウンター例にアサーションまでのトレースを要求」「仮想環境での反例を禁止」等の**探索行動への新しい制約**を追加したものであり、今回は既存行の「observable test outcome」を「PASS/FAIL result」に言い換えるのみ。semantic な要求は同等であり、探索行動への新しい制約は追加しない

## 変更規模の宣言

- **新規追加行数**: 0 行（hard limit 5 行以内を大きく下回る）
- **変更対象**: 既存チェックリスト項目 1 行の文言精緻化のみ
- **削除行数**: 0 行
- **変更規模**: 最小（single-line modification）
