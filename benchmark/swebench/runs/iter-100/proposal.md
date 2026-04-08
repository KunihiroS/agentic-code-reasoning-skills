# Iter-100 Proposal

## Exploration Framework カテゴリと選定理由

**カテゴリ E: 表現・フォーマットを改善する**（論文の定義との整合性強化を兼ねてカテゴリ F にも関連）

`compare` テンプレートの ANALYSIS セクションにある per-test Claim のトレース指示が
「trace through code — cite file:line」という曖昧な表現に留まっており、
モデルがコード変更箇所を見つけた段階でトレースを打ち切り、
テストアサーションへの影響を未確認のまま PASS/FAIL を宣言しやすい。
「コードをたどれ」という指示は、たどりの**起点（変更箇所）**と**終点（アサーション結果）**を明示していない。
これを明確化することは、既存行の精緻化として 2 行で実現できる。

---

## 改善仮説

**仮説**: per-test Claim のトレース指示に「変更箇所 → … → アサーション結果」という
方向性を付加することで、モデルが変更の影響をアサーションまで追跡することが
明示的に求められ、途中で打ち切られる不完全なトレースを減らせる。

これは SKILL.md の核心概念である「observational equivalence = テストの
pass/fail が一致するかどうか」を per-test Claim の記述フォーマットに直接反映させる
表現の精緻化である。変更箇所を見つけることとテスト結果に差が出ることは別問題であり、
両者を繋ぐトレースの明示的な義務化が判定精度に寄与する。

---

## SKILL.md の変更内容

変更対象: `compare` テンプレートの ANALYSIS OF TEST BEHAVIOR セクション

```
【変更前】
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]

【変更後】
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace: change point → ... → assertion outcome — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace: change point → ... → assertion outcome — cite file:line]
```

変更箇所: SKILL.md の compare テンプレート内、`because [trace through code — cite file:line]`
の 2 行をそれぞれ `because [trace: change point → ... → assertion outcome — cite file:line]`
に書き換える。

---

## 期待効果

### 減少が期待される失敗パターン

1. **変更箇所の確認でトレースを打ち切るパターン（EQUIV / NOT EQUIV 両方向に誤判定）**  
   変更箇所を発見して「この関数の挙動が変わった」と述べるだけで  
   PASS/FAIL を宣言するケースが減る。  
   アサーション結果まで繋ぐことが形式上必要になるため、
   中間ノードで推論が止まりにくくなる。

2. **微細な差分の影響を未確認で棄却するパターン（Guardrail #4 相当）**  
   変更点がテストのアサーションに到達しないと「証明」するには、
   アサーションまでのトレースが必要になる。
   現在の「trace through code」では到達性を曖昧に処理できたが、
   「→ assertion outcome」を明示することで到達性の確認が明示的になる。

### 影響しないパターン

- pass-to-pass tests の Claim 形式（`behavior is [description]`）は変更しないため、
  そちらの判定には影響しない。
- COUNTEREXAMPLE / NO COUNTEREXAMPLE EXISTS セクションはそのままなので、
  反証プロセスの強度は変わらない。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 照合結果 |
|------|----------|
| #1 判定の非対称操作は失敗する | **抵触なし**: Change A / Change B の両 Claim に同一の変更を適用。非対称性なし。 |
| #2 出力側の制約は効果がない | **抵触なし**: 出力フォーマットではなく、推論の探索方向（入力/処理側）を明確化。 |
| #3 探索量の削減は有害 | **抵触なし**: 探索の打ち切りを防ぐ方向の変更。探索量は増加方向。 |
| #5 入力テンプレートの過剰規定は探索視野を狭める | **抵触なし**: 「何を記録するか」ではなく、既存のトレース指示の終点を明示するのみ。新規フィールド追加なし。 |
| #7 分析前の中間ラベル生成はアンカリングを導入 | **抵触なし**: 分析前ではなく、分析中のトレース指示の精緻化。 |
| #8 受動的な記録フィールドの追加は検証を誘発しない | **抵触なし**: 新規フィールドの追加ではなく、既存のプレースホルダーの書き換え。 |
| #9 メタ認知的自己チェックは機能しない | **抵触なし**: 自己評価を求めていない。構造的なトレース指示の明確化。 |
| #15 意味論的な観測境界を固定長の局所追跡ルールで近似してはならない | **抵触なし**: 「...」で中間ステップ数を固定しない。意味論的な終点（assertion outcome）を指定している。 |
| #17 中間ノードの局所的な分析義務化はエンドツーエンド追跡を阻害する | **抵触なし**: 中間ノードではなく終点（assertion outcome）を指定している。 |
| #18/#19 過剰な物理的証拠要求は探索予算を枯渇させる | **抵触なし**: `file:line` の要求は既存と同じ。新規の証拠要件を追加していない。 |
| #22 具体物の例示は物理的探索目標として過剰適応される | **抵触なし**: 「assertion outcome」は特定のコード要素ではなく状態・性質の記述。 |

---

## 変更規模の宣言

- **変更行数**: 2 行（既存の `because [trace through code — cite file:line]` × 2 を書き換え）
- **削除行数**: 0 行（変更行は削除としてカウントしない）
- **新規ステップ・新規フィールド・新規セクション**: なし
- **合計**: 2 行 ≤ 5 行（hard limit 内）
