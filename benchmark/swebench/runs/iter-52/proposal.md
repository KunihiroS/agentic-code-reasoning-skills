# iter-52 改善提案

## 親イテレーション (iter-35) の選定理由

iter-35 はスコア 85%（17/20）で、現在の最高スコアを記録しているイテレーション。CONTRACT DELTA
セクションの追加（カテゴリ C: 比較の枠組みを変える）により、iter-34（75%）から+10pp を達成した。
残存する失敗は 3 件:

| ケース | 真値 | 予測 | 特徴 |
|--------|------|------|------|
| django__django-15368 | EQUIV | NOT_EQUIVALENT | コード差異が発見されたがテスト結果は同じ |
| django__django-13821 | EQUIV | NOT_EQUIVALENT | コード差異が発見されたがテスト結果は同じ |
| django__django-11433 | NOT_EQ | UNKNOWN | 31 ターン内に収束できず |

## Exploration Framework カテゴリの選択

**カテゴリ E: 表現・フォーマットを改善する**（曖昧な指示をより具体的な言い回しに変える）

iter-35 はカテゴリ C を使用した。今回はカテゴリ E を選択する。

**理由**: 残存する EQUIV 誤判定（15368, 13821）の失敗パターンは「コード差異を発見 →
テスト観測点に届く前に中間 caller によって吸収・正規化されるにもかかわらず NOT_EQUIV と即断」
という不完全な推論チェーンである。Guardrail 5 は「不完全な推論チェーン」を警告するが、
その例示が `compare` モード特有の形（差異の吸収パターン）を明示していないため、
モデルがこのパターンを認識しにくい。既存の Guardrail 5 の本文に 1 文を追加して
`compare` モードにおける典型的な不完全チェーンの形を具体化することで、
既存の抽象的注意を具体的認識へ結びつける。

カテゴリ A（BL-12, BL-14）・B（BL-17, BL-22）・C（iter-35 使用済み）・D（BL-9）・F（BL-8, BL-10）
はそれぞれ失敗実績があるか iter-35 で使用済みである。カテゴリ E の「既存文言の精緻化」は
BL-11, BL-16 等の失敗事例と異なり、新しいアンカーを作らない宣言的な情報追加に留める。

## 改善仮説

**仮説**: Guardrail 5 の「不完全な推論チェーン」の注意に対し、`compare` モードにおける
典型形——「変更されたコード内に意味論的差異は存在するが、その差異が中間 caller に吸収・
正規化されて test assertion に到達しない」——を 1 文で明示することで、モデルが
コード差異を発見した後に「その差異が本当に PASS/FAIL に繋がるか」を既存 checklist 項目
（"Do not conclude NOT EQUIVALENT from a code difference alone"）と連動して意識しやすくなり、
EQUIV の偽陰性を減らせる。

## SKILL.md のどこをどう変えるか

### 変更箇所

`## Guardrails > From the paper's error analysis` 内の Guardrail 5 の末尾に 1 文を追記。

### 変更前（既存行）

```
5. **Do not trust incomplete chains.** After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified. Confident-but-wrong answers often come from thorough-but-incomplete analysis.
```

### 変更後（1 文追記）

```
5. **Do not trust incomplete chains.** After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified. Confident-but-wrong answers often come from thorough-but-incomplete analysis. In `compare` mode, a common form of incomplete chain: a semantic difference exists in the changed code but is neutralized by intermediate callers before reaching the test assertion.
```

### 変更規模の宣言

- 追加行数: 1（Guardrail 5 の本文末尾への 1 文追記、既存行への付加として実装するため行カウント上は 0〜1）
- 削除行数: 0
- 新規ステップ・新規フィールド・新規セクション・新規テンプレート要素: なし

## EQUIV / NOT_EQ への影響予測

| カテゴリ | 現状 | 予測 | 根拠 |
|----------|------|------|------|
| EQUIV (10件) | 80% (8/10) | 80〜90% (8〜9/10) | コード差異→吸収パターンの認識促進により偽陰性が 0〜1 件改善する可能性 |
| NOT_EQ (10件) | 90% (9/10) | 90% (9/10) | 宣言的な情報追加で新たな立証義務を課さないため回帰リスク低 |
| 全体 | 85% (17/20) | 85〜90% (17〜18/20) | |

**回帰リスクについて**: 今回の追記は「〜という不完全なチェーンが存在する」という事実の
記述であり、"verify" 等の強い義務語を用いない。既存 checklist 項目 5（"Do not conclude
NOT EQUIVALENT from a code difference alone"）を Guardrail レベルで補強するものであり、
新たな立証ハードルを設けない。NOT_EQ の正答ケースがこの文を読んでも「差異は吸収されず
assertion に到達している」という自分のトレースに確信を持ち続けられるため、
UNKNOWN への流出は想定しにくい。

## failed-approaches.md ブラックリスト・共通原則との照合

| 照合項目 | 判定 | 根拠 |
|----------|------|------|
| BL-6: Guardrail 4 の対称化 | 非該当 | BL-6 は trace 義務を両方向に課した。今回は宣言的情報追加であり義務を加えない |
| BL-9: メタ認知的自己チェック | 非該当 | 自己評価を求めない |
| BL-23: nearest consumer 伝播/吸収確認義務化 | 非該当 | 手続き的義務でなく概念的説明 |
| BL-25/26: エンドツーエンド完全立証義務 | 非該当 | 完全証明を要求しない |
| BL-10: 条件分岐ゲート追加 | 非該当 | 新規ゲートを追加しない |
| 原則 #1: 判定の非対称操作 | ✓ PASS | 両方向に対称な事実記述 |
| 原則 #2: 出力側の制約 | ✓ PASS | 結論を誘導しない |
| 原則 #3: 探索量削減 | ✓ PASS | 探索を減らさない |
| 原則 #5: 入力テンプレートの過剰規定 | ✓ PASS | テンプレート記録フィールドを追加しない |
| 原則 #8: 受動的記録フィールド | ✓ PASS | 記録義務を課さない |
| 原則 #14: 特例探索の追加 | ✓ PASS | 条件付き特例処理を追加しない |

## 変更規模の宣言（重要）

- **追加行数**: 1 行以内（hard limit 5 行に対し十分な余裕あり）
- **既存行への付加**: Guardrail 5 の末尾への 1 文追記のみ
- **新規ステップ・フィールド・セクション・テンプレート要素**: なし
